import { NextResponse } from "next/server";
import webpush from "web-push";
import { z } from "zod";

import { getCurrentUser } from "@/lib/auth";
import { asciiJsonStringify } from "@/lib/push-payload";
import { createClient } from "@/lib/supabase/server";

const testPushSchema = z.object({
  title: z.string().trim().min(1).max(120),
  body: z.string().trim().min(1).max(500),
  url: z.string().trim().max(500).refine((value) => value.startsWith("/") && !value.startsWith("//")),
});

export async function POST(request: Request) {
  try {
    const user = await getCurrentUser();
    if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

    const parsed = testPushSchema.safeParse(await request.json().catch(() => null));
    if (!parsed.success) return NextResponse.json({ error: "INVALID_TEST_PAYLOAD" }, { status: 400 });

    const supabase = await createClient();
    const { data: subscriptions, error: subscriptionError } = await supabase
      .from("push_subscriptions")
      .select("endpoint, p256dh, auth")
      .eq("user_id", user.id)
      .is("disabled_at", null);

    if (subscriptionError || !subscriptions?.length) {
      return NextResponse.json(
        { error: "NO_ACTIVE_IOS_SUBSCRIPTION", status: "NO_ACTIVE_IOS_SUBSCRIPTION" },
        { status: 404 },
      );
    }

    const vapidPublicKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
    const vapidPrivateKey = process.env.VAPID_PRIVATE_KEY;
    const vapidSubject = process.env.VAPID_SUBJECT;
    if (!vapidPublicKey || !vapidPrivateKey || !vapidSubject) {
      return NextResponse.json(
        { error: "VAPID_CONFIGURATION_ERROR", status: "VAPID_CONFIGURATION_ERROR" },
        { status: 500 },
      );
    }

    webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);
    const id = `test-${Date.now()}`;
    const payload = asciiJsonStringify({
      id,
      title: parsed.data.title,
      body: parsed.data.body,
      link: parsed.data.url,
      icon: "/icons/kickly-icon-192.png",
      badge: "/icons/badge-72x72.png",
    });

    const results = await Promise.all(
      subscriptions.map(async (subscription) => {
        try {
          await webpush.sendNotification(
            {
              endpoint: subscription.endpoint,
              keys: { p256dh: subscription.p256dh, auth: subscription.auth },
            },
            payload,
            { TTL: 60 * 60, urgency: "high" },
          );
          return { sent: true, status: "PROVIDER_SENT_AWAITING_DEVICE_CONFIRMATION" } as const;
        } catch (error) {
          const statusCode = webPushStatus(error);
          if (statusCode === 404 || statusCode === 410) {
            await supabase.from("push_subscriptions").delete().eq("endpoint", subscription.endpoint);
            return { sent: false, status: "NO_ACTIVE_IOS_SUBSCRIPTION" } as const;
          }
          if (statusCode === 401 || statusCode === 403) {
            return { sent: false, status: "VAPID_CONFIGURATION_ERROR" } as const;
          }
          return { sent: false, status: "PROVIDER_FAILED" } as const;
        }
      }),
    );

    const successCount = results.filter((result) => result.sent).length;
    if (!successCount) {
      const status = results[0]?.status ?? "PROVIDER_FAILED";
      return NextResponse.json({ error: status, status }, { status: 400 });
    }

    return NextResponse.json({
      success: true,
      status: "PROVIDER_SENT_AWAITING_DEVICE_CONFIRMATION",
      subscriptionsProcessed: subscriptions.length,
      successCount,
    });
  } catch (error) {
    console.error("Send test push error:", error);
    return NextResponse.json(
      { error: "PROVIDER_FAILED", status: "PROVIDER_FAILED" },
      { status: 500 },
    );
  }
}

function webPushStatus(error: unknown) {
  if (!error || typeof error !== "object" || !("statusCode" in error)) return 0;
  const statusCode = Number((error as { statusCode?: unknown }).statusCode);
  return Number.isFinite(statusCode) ? statusCode : 0;
}
