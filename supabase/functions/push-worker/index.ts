import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import webpush from "npm:web-push@3.6.7";

interface Delivery {
  delivery_id: string;
  endpoint: string;
  p256dh: string;
  auth: string;
  title: string;
  body: string;
  link: string | null;
  metadata: Record<string, unknown> | null;
  vapid_public: string;
  vapid_private: string;
  vapid_subject: string;
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json({ message: "Method not allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ message: "Missing runtime configuration" }, 500);

  const supabase = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data, error } = await supabase.rpc("claim_push_deliveries", { batch_size: 50 });
  if (error) return json({ message: error.message }, 500);

  let sent = 0;
  let failed = 0;
  for (const delivery of (data ?? []) as Delivery[]) {
    try {
      webpush.setVapidDetails(delivery.vapid_subject, delivery.vapid_public, delivery.vapid_private);
      await webpush.sendNotification({ endpoint: delivery.endpoint, keys: { p256dh: delivery.p256dh, auth: delivery.auth } }, JSON.stringify({
        id: delivery.delivery_id,
        title: delivery.title,
        body: delivery.body,
        link: delivery.link ?? "/notifications",
        metadata: delivery.metadata ?? {},
      }), { TTL: 60 * 60 * 12, urgency: "normal" });
      await supabase.rpc("complete_push_delivery", { target_delivery: delivery.delivery_id, delivered: true, terminal_failure: false, delivery_error: null });
      sent += 1;
    } catch (cause) {
      const statusCode = typeof cause === "object" && cause && "statusCode" in cause ? Number(cause.statusCode) : 0;
      const message = cause instanceof Error ? cause.message : "Push delivery failed";
      await supabase.rpc("complete_push_delivery", { target_delivery: delivery.delivery_id, delivered: false, terminal_failure: statusCode === 404 || statusCode === 410, delivery_error: message });
      failed += 1;
    }
  }
  return json({ claimed: (data ?? []).length, sent, failed });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } });
}
