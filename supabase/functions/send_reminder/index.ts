import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { google } from "https://esm.sh/googleapis@121";

type ReminderType = "RESERVATION_REMINDER_1H" | "RESERVATION_REMINDER_24H";

type ReminderCandidate = {
  reservation_id: string;
  user_id: string;
  title: string;
  message: string;
  type: ReminderType;
  court_name: string | null;
};

Deno.serve(async () => {
  try {
    const supabase = createServiceClient();
    const now = new Date();

    const { data: upcoming, error } = await supabase
      .from("reservations")
      .select("id,user_id,date,start_time,status,courts(name),categories(name)")
      .in("status", ["APPROVED", "ADMIN"]);

    if (error) {
      return json({ error: error.message }, 500);
    }
    if (!upcoming || upcoming.length == 0) {
      return json({ inserted: 0, pushed: 0, skipped_duplicates: 0 });
    }

    const candidates: ReminderCandidate[] = [];
    for (const r of upcoming) {
      const reservationId = r.id?.toString() ?? "";
      const userId = r.user_id?.toString() ?? "";
      const dateStr = r.date?.toString() ?? "";
      const startTimeRaw = r.start_time?.toString() ?? "";
      const startTime = startTimeRaw.length >= 5
        ? startTimeRaw.substring(0, 5)
        : startTimeRaw;
      if (
        reservationId === "" || userId === "" || dateStr === "" ||
        startTime === ""
      ) {
        continue;
      }
      const reservationStart = new Date(`${dateStr}T${startTime}:00`);
      if (Number.isNaN(reservationStart.getTime())) continue;
      if (reservationStart.getTime() <= now.getTime()) continue;

      const diffMinutes = (reservationStart.getTime() - now.getTime()) /
        (60 * 1000);
      const reminderType = classifyReminder(diffMinutes);
      if (reminderType == null) continue;

      const categoryName = (r.categories as { name?: string } | null)?.name ??
        "Reservation";
      const courtName = (r.courts as { name?: string } | null)?.name ?? "Court";
      const whenText =
        `${dateStr} at ${startTime} (${courtName} · ${categoryName})`;
      const title = reminderType === "RESERVATION_REMINDER_1H"
        ? "Reservation in 1 hour"
        : "Reservation in 24 hours";
      const message = reminderType === "RESERVATION_REMINDER_1H"
        ? `Reminder: your booking is at ${whenText}.`
        : `Reminder: your booking is tomorrow at ${whenText}.`;

      candidates.push({
        reservation_id: reservationId,
        user_id: userId,
        title,
        message,
        type: reminderType,
        court_name: courtName,
      });
    }

    if (candidates.length === 0) {
      return json({ inserted: 0, pushed: 0, skipped_duplicates: 0 });
    }

    const reservationIds = [...new Set(candidates.map((x) => x.reservation_id))];
    const { data: existingRows } = await supabase
      .from("notifications")
      .select("reservation_id,type")
      .in("reservation_id", reservationIds)
      .in("type", ["RESERVATION_REMINDER_1H", "RESERVATION_REMINDER_24H"]);

    const existing = new Set(
      (existingRows ?? []).map((row) =>
        `${row.reservation_id?.toString()}:${row.type?.toString()}`
      ),
    );

    const toInsert = candidates.filter((c) =>
      !existing.has(`${c.reservation_id}:${c.type}`)
    );
    if (toInsert.length === 0) {
      return json({
        inserted: 0,
        pushed: 0,
        skipped_duplicates: candidates.length,
      });
    }

    await supabase.from("notifications").insert(
      toInsert.map((n) => ({
        user_id: n.user_id,
        title: n.title,
        message: n.message,
        type: n.type,
        reservation_id: n.reservation_id,
        court_name: n.court_name,
      })),
    );

    const pushed = await pushReminderNotifications(supabase, toInsert);
    return json({
      inserted: toInsert.length,
      pushed,
      skipped_duplicates: candidates.length - toInsert.length,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return json({ error: message }, 500);
  }
});

function createServiceClient() {
  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // deno-lint-ignore no-explicit-any
  const { createClient }: any = (globalThis as any).supabase;

  return createClient(url, serviceKey);
}

function classifyReminder(diffMinutes: number): ReminderType | null {
  // Run this function every 15 min: 24h and 1h windows with tolerance.
  if (diffMinutes >= 45 && diffMinutes <= 75) {
    return "RESERVATION_REMINDER_1H";
  }
  if (diffMinutes >= (24 * 60 - 15) && diffMinutes <= (24 * 60 + 15)) {
    return "RESERVATION_REMINDER_24H";
  }
  return null;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function pushReminderNotifications(
  supabase: any,
  reminders: ReminderCandidate[],
): Promise<number> {
  const userIds = [...new Set(reminders.map((r) => r.user_id))];
  const { data: tokenRows } = await supabase
    .from("user_push_tokens")
    .select("token,user_id")
    .in("user_id", userIds);
  if (!tokenRows || tokenRows.length === 0) return 0;

  const serviceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!serviceAccountRaw) return 0;
  const serviceAccount = JSON.parse(serviceAccountRaw);

  const auth = new google.auth.JWT(
    serviceAccount.client_email,
    undefined,
    serviceAccount.private_key,
    ["https://www.googleapis.com/auth/firebase.messaging"],
  );
  await auth.authorize();
  const accessToken = auth.credentials.access_token;
  if (!accessToken) return 0;

  const tokensByUser = new Map<string, string[]>();
  for (const row of tokenRows) {
    const uid = row.user_id?.toString() ?? "";
    const token = row.token?.toString() ?? "";
    if (uid === "" || token === "") continue;
    const list = tokensByUser.get(uid) ?? [];
    list.push(token);
    tokensByUser.set(uid, list);
  }

  let sent = 0;
  for (const reminder of reminders) {
    const tokens = tokensByUser.get(reminder.user_id) ?? [];
    for (const token of tokens) {
      const payload = {
        message: {
          token,
          notification: {
            title: reminder.title,
            body: reminder.message,
          },
          data: {
            type: reminder.type,
            reservation_id: reminder.reservation_id,
          },
          android: { priority: "HIGH" },
        },
      };
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify(payload),
        },
      );
      if (res.ok) sent += 1;
    }
  }

  return sent;
}

