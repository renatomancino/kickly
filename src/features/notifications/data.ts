import "server-only";

import { createClient } from "@/lib/supabase/server";
import { defaultNotificationPreferences, type NotificationItem, type NotificationPreferences } from "./types";

export async function getNotifications(userId: string) {
  const supabase = await createClient();
  const { data } = await supabase.from("notifications").select("id, type, title, body, link, metadata, read_at, created_at").eq("user_id", userId).order("created_at", { ascending: false }).limit(80);
  return (data ?? []) as NotificationItem[];
}

export async function getUnreadNotificationCount(userId: string) {
  const supabase = await createClient();
  const { count } = await supabase.from("notifications").select("id", { count: "exact", head: true }).eq("user_id", userId).is("read_at", null);
  return count ?? 0;
}

export async function getNotificationPreferences(userId: string): Promise<NotificationPreferences> {
  const supabase = await createClient();
  const { data } = await supabase.from("notification_preferences").select("match_created, match_updates, match_reminders, waitlist, mvp, rating, league_updates, push_enabled").eq("user_id", userId).maybeSingle();
  return data ? { ...defaultNotificationPreferences, ...data } : defaultNotificationPreferences;
}
