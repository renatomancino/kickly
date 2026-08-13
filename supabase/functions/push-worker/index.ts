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
      await webpush.sendNotification({ endpoint: delivery.endpoint, keys: { p256dh: delivery.p256dh, auth: delivery.auth } }, asciiJsonStringify({
        id: delivery.delivery_id,
        title: repairUtf8Mojibake(delivery.title),
        body: repairUtf8Mojibake(delivery.body),
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
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" } });
}

function asciiJsonStringify(value: unknown) {
  return JSON.stringify(value).replace(/[\u007f-\uffff]/g, (character) =>
    `\\u${character.charCodeAt(0).toString(16).padStart(4, "0")}`,
  );
}

function repairUtf8Mojibake(value: string) {
  const windows1252Bytes = new Map<number, number>([
    [0x20ac, 0x80], [0x201a, 0x82], [0x0192, 0x83], [0x201e, 0x84], [0x2026, 0x85],
    [0x2020, 0x86], [0x2021, 0x87], [0x02c6, 0x88], [0x2030, 0x89], [0x0160, 0x8a],
    [0x2039, 0x8b], [0x0152, 0x8c], [0x017d, 0x8e], [0x2018, 0x91], [0x2019, 0x92],
    [0x201c, 0x93], [0x201d, 0x94], [0x2022, 0x95], [0x2013, 0x96], [0x2014, 0x97],
    [0x02dc, 0x98], [0x2122, 0x99], [0x0161, 0x9a], [0x203a, 0x9b], [0x0153, 0x9c],
    [0x017e, 0x9e], [0x0178, 0x9f],
  ]);
  const markers = new Set([0x00c2, 0x00c3, 0x00e2, 0x00ef, 0x00f0]);
  const score = (text: string) => [...text].filter((character) => markers.has(character.codePointAt(0) ?? 0)).length;
  let candidate = value;
  for (let pass = 0; pass < 3; pass += 1) {
    const candidateScore = score(candidate);
    if (!candidateScore) break;
    const bytes: number[] = [];
    let convertible = true;
    for (const character of candidate) {
      const codePoint = character.codePointAt(0) ?? 0;
      const byte = codePoint <= 0xff ? codePoint : windows1252Bytes.get(codePoint);
      if (byte === undefined) { convertible = false; break; }
      bytes.push(byte);
    }
    if (!convertible) break;
    try {
      const decoded = new TextDecoder("utf-8", { fatal: true }).decode(Uint8Array.from(bytes));
      if (score(decoded) >= candidateScore) break;
      candidate = decoded;
    } catch { break; }
  }
  return candidate;
}
