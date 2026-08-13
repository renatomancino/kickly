"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { createClient } from "@/lib/supabase/client";
import { repairUtf8Mojibake } from "@/lib/text-encoding";

export function NotificationRuntime({ userId, unread }: { userId: string; unread: number }) {
  const router = useRouter();
  useEffect(() => {
    if ("serviceWorker" in navigator) navigator.serviceWorker.register("/sw.js").catch(() => undefined);
    if ("setAppBadge" in navigator) navigator.setAppBadge(unread).catch(() => undefined);
  }, [unread]);

  useEffect(() => {
    const supabase = createClient();
    const channel = supabase.channel(`notifications:${userId}`).on("postgres_changes", { event: "INSERT", schema: "public", table: "notifications" }, (payload) => {
      const notification = payload.new as { user_id?: string; title?: string; body?: string };
      if (notification.user_id !== userId) return;
      toast(repairUtf8Mojibake(notification.title ?? "Nuova notifica"), {
        description: notification.body ? repairUtf8Mojibake(notification.body) : undefined,
      });
      router.refresh();
    }).subscribe();
    return () => { void supabase.removeChannel(channel); };
  }, [router, userId]);
  return null;
}
