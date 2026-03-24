import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { google } from "https://esm.sh/googleapis@121";

function getCorsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "*";
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, accept, origin",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
}

function jsonResponse(
  req: Request,
  body: unknown,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...getCorsHeaders(req),
      "Content-Type": "application/json",
    },
  });
}

function textResponse(req: Request, text: string, status: number): Response {
  return new Response(text, {
    status,
    headers: getCorsHeaders(req),
  });
}

type PushPayload = {
  user_id?: string;
  user_ids?: string[];
  title: string;
  message: string;
  data?: Record<string, string>;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: getCorsHeaders(req) });
  }
  if (req.method !== "POST") {
    return textResponse(req, "Method not allowed", 405);
  }
  try {
    const caller = createClientFromReq(req);
    const authUser = await getAuthUser(caller);
    if (!authUser) {
      return jsonResponse(req, { error: "Unauthorized" }, 401);
    }

    const body: PushPayload = await req.json();
    if (!body.title || !body.message) {
      return jsonResponse(req, { error: "Missing title/message" }, 400);
    }

    const userIds = new Set<string>();
    if (body.user_id) userIds.add(body.user_id);
    for (const uid of body.user_ids ?? []) {
      if (uid) userIds.add(uid);
    }
    if (userIds.size === 0) {
      return jsonResponse(req, { sent: 0, reason: "no-target-users" });
    }

    const service = createServiceClient();
    const { data: tokenRows, error: tokenErr } = await service
      .from("user_push_tokens")
      .select("token,user_id")
      .in("user_id", [...userIds]);

    if (tokenErr) {
      return jsonResponse(req, { error: tokenErr.message }, 500);
    }

    const serviceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
    if (!serviceAccountRaw) {
      return jsonResponse(req, { error: "FCM_SERVICE_ACCOUNT not configured" }, 500);
    }

    let serviceAccount: {
      client_email: string;
      private_key: string;
      project_id: string;
    };
    try {
      serviceAccount = JSON.parse(serviceAccountRaw);
    } catch {
      return jsonResponse(req, { error: "FCM_SERVICE_ACCOUNT is not valid JSON" }, 500);
    }

    const auth = new google.auth.JWT(
      serviceAccount.client_email,
      undefined,
      serviceAccount.private_key,
      ["https://www.googleapis.com/auth/firebase.messaging"],
    );
    await auth.authorize();
    const accessToken = auth.credentials.access_token;
    if (!accessToken) {
      return jsonResponse(req, { error: "Could not obtain Firebase access token" }, 500);
    }

    let sent = 0;
    const invalidTokens: string[] = [];
    const rows = tokenRows ?? [];
    for (const row of rows) {
      const token = row.token as string;
      const data = body.data ?? {};
      const fcmPayload = {
        message: {
          token,
          notification: {
            title: body.title,
            body: body.message,
          },
          data,
          android: {
            priority: "HIGH",
          },
        },
      };

      const fcmRes = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(fcmPayload),
        },
      );
      const fcmJson = await fcmRes.json().catch(() => ({}));
      const fcmErrorStatus = fcmJson?.error?.status as string | undefined;
      if (fcmRes.ok && !fcmErrorStatus) {
        sent += 1;
      } else if (fcmErrorStatus === "UNREGISTERED") {
        invalidTokens.push(token);
      }
    }

    if (invalidTokens.length > 0) {
      await service.from("user_push_tokens").delete().in("token", invalidTokens);
    }

    return jsonResponse(req, { sent, tokens: rows.length });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return jsonResponse(req, { error: message }, 500);
  }
});

function createClientFromReq(req: Request) {
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const authHeader = req.headers.get("Authorization");
  // deno-lint-ignore no-explicit-any
  const { createClient }: any = (globalThis as any).supabase;
  const globalHeaders: Record<string, string> = {};
  if (authHeader && authHeader.toLowerCase().startsWith("bearer ")) {
    globalHeaders.Authorization = authHeader;
  }
  return createClient(url, anonKey, {
    global: { headers: globalHeaders },
  });
}

function createServiceClient() {
  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  // deno-lint-ignore no-explicit-any
  const { createClient }: any = (globalThis as any).supabase;
  return createClient(url, serviceKey);
}

async function getAuthUser(client: any) {
  const { data, error } = await client.auth.getUser();
  if (error) return null;
  return data.user ?? null;
}
