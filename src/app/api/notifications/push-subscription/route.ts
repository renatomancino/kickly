import { NextResponse } from "next/server";

import { getCurrentUser } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

export async function GET() {
  try {
    const user = await getCurrentUser();
    if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

    const supabase = await createClient();
    const { data, error } = await supabase
      .from("push_subscriptions")
      .select("endpoint, p256dh, auth, created_at")
      .eq("user_id", user.id)
      .is("disabled_at", null)
      .order("last_used_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      console.error("Error fetching subscription:", error);
      return NextResponse.json({ subscription: null });
    }

    return NextResponse.json({
      subscription: data
        ? {
            hasEndpoint: Boolean(data.endpoint),
            hasP256dh: Boolean(data.p256dh),
            hasAuth: Boolean(data.auth),
            createdAt: data.created_at,
          }
        : null,
    });
  } catch (error) {
    console.error("Push subscription GET error:", error);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
