import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req) => {
  let dryRun = false;
  let limit = 100;
  try {
    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      dryRun = body?.dry_run === true;
      const bodyLimit = Number(body?.limit);
      if (Number.isFinite(bodyLimit) && bodyLimit > 0) {
        limit = Math.min(Math.floor(bodyLimit), 500);
      }
    }
  } catch {
    dryRun = false;
  }
  const url = new URL(req.url);
  if (url.searchParams.get("dry_run") === "true") {
    dryRun = true;
  }
  const qLimit = Number(url.searchParams.get("limit"));
  if (Number.isFinite(qLimit) && qLimit > 0) {
    limit = Math.min(Math.floor(qLimit), 500);
  }

  const service = createServiceClient();
  const nowIso = new Date().toISOString();

  const { data: dueRows, error } = await service
    .from("reservations")
    .select("id,user_id,payment_due_at,payment_status,status")
    .in("status", ["APPROVED", "ADMIN"])
    .in("payment_status", ["UNPAID", "INVALID"])
    .not("payment_due_at", "is", null)
    .lt("payment_due_at", nowIso)
    .order("payment_due_at", { ascending: true })
    .limit(limit);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  const rows = dueRows ?? [];
  if (rows.length == 0) {
    return new Response(JSON.stringify({ expired: 0, dry_run: dryRun, limit }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const ids = rows.map((r) => r.id as string);
  if (dryRun) {
    return new Response(
      JSON.stringify({
        dry_run: true,
        limit,
        would_expire: ids.length,
        reservation_ids: ids,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  }

  await service.from("reservations").update({ status: "EXPIRED" }).in("id", ids);

  const notifications = rows.map((r) => ({
    user_id: r.user_id,
    title: "Reservation expired",
    message:
      "Your reservation expired because payment was not completed before the deadline.",
    type: "RESERVATION_EXPIRED",
    reservation_id: r.id,
  }));
  await service.from("notifications").insert(notifications);

  return new Response(
    JSON.stringify({ expired: ids.length, dry_run: false, limit }),
    {
    headers: { "Content-Type": "application/json" },
  },
  );
});

function createServiceClient() {
  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  // deno-lint-ignore no-explicit-any
  const { createClient }: any = (globalThis as any).supabase;
  return createClient(url, serviceKey);
}
