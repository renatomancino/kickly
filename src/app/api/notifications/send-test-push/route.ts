import { NextResponse } from "next/server";
import { z } from "zod";

import { getCurrentUser } from "@/lib/auth";
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
    const { data: notificationId, error } = await supabase.rpc("request_test_push", {
      notification_title: parsed.data.title,
      notification_body: parsed.data.body,
      notification_link: parsed.data.url,
    });

    if (error || !notificationId) {
      const message = error?.message ?? "test_push_failed";
      if (message.includes("no_active_push_subscription")) {
        return NextResponse.json(
          { error: "NO_ACTIVE_PUSH_SUBSCRIPTION", status: "NO_ACTIVE_PUSH_SUBSCRIPTION" },
          { status: 404 },
        );
      }
      if (message.includes("test_push_rate_limited")) {
        return NextResponse.json(
          { error: "TEST_PUSH_RATE_LIMITED", status: "TEST_PUSH_RATE_LIMITED" },
          { status: 429 },
        );
      }
      console.error("Queue test push error:", { code: error?.code });
      return NextResponse.json(
        { error: "TEST_PUSH_QUEUE_FAILED", status: "TEST_PUSH_QUEUE_FAILED" },
        { status: 500 },
      );
    }

    return NextResponse.json({
      success: true,
      status: "QUEUED_FOR_PROVIDER",
      notificationId,
    }, { status: 202 });
  } catch (error) {
    console.error("Send test push error:", error);
    return NextResponse.json(
      { error: "PROVIDER_FAILED", status: "PROVIDER_FAILED" },
      { status: 500 },
    );
  }
}

const statusQuerySchema = z.object({ notificationId: z.string().uuid() });

export async function GET(request: Request) {
  const user = await getCurrentUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const parsed = statusQuerySchema.safeParse({
    notificationId: new URL(request.url).searchParams.get("notificationId"),
  });
  if (!parsed.success) return NextResponse.json({ error: "INVALID_NOTIFICATION_ID" }, { status: 400 });

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("get_test_push_delivery_status", {
    target_notification: parsed.data.notificationId,
  });
  const result = Array.isArray(data) ? data[0] : null;
  if (error || !result) return NextResponse.json({ error: "TEST_PUSH_NOT_FOUND" }, { status: 404 });
  return NextResponse.json(result);
}
