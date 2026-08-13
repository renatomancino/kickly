import type { Metadata } from "next";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ProfileForm } from "@/features/profile/profile-form";
import { getPlayerProfile } from "@/features/profile/data";
import { PlayerProfileView } from "@/features/profile/player-profile-view";
import { getCurrentUser } from "@/lib/auth";
import { hasSupabaseEnv } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";
import type { ProfileRow } from "@/types/database";
import { getNotificationPreferences } from "@/features/notifications/data";
import { NotificationSettings, PushSettings } from "@/features/notifications/notification-settings";
import { defaultNotificationPreferences } from "@/features/notifications/types";

export const metadata: Metadata = { title: "Profilo" };

export default async function ProfilePage() {
  const user = await getCurrentUser();
  let profile: ProfileRow | null = null;
  if (hasSupabaseEnv() && user) {
    const supabase = await createClient();
    profile = (await supabase.from("profiles").select("*").eq("id", user.id).maybeSingle()).data;
  }
  const data = profile ? await getPlayerProfile(profile.username) : null;
  const notificationPreferences = user ? await getNotificationPreferences(user.id) : defaultNotificationPreferences;

  if (!data) return null;
  return <PlayerProfileView data={data}><Card><CardHeader><CardTitle>Modifica profilo</CardTitle></CardHeader><CardContent><ProfileForm mode="edit" profile={profile} /></CardContent></Card><NotificationSettings initial={notificationPreferences} /><PushSettings initiallyEnabled={notificationPreferences.push_enabled} /></PlayerProfileView>;
}
