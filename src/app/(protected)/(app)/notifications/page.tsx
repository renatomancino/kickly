import type { Metadata } from "next";
import { NotificationCenter } from "@/features/notifications/notification-center";
import { getNotificationPreferences, getNotifications } from "@/features/notifications/data";
import { requireUser } from "@/lib/auth";
import { PushSettings } from "@/features/notifications/notification-settings";

export const metadata: Metadata = { title: "Notifiche" };

export default async function NotificationsPage() {
  const user = await requireUser();
  const [items, preferences] = await Promise.all([getNotifications(user.id), getNotificationPreferences(user.id)]);
  return <><NotificationCenter initialItems={items} />{!preferences.push_enabled ? <div className="pb-8"><PushSettings initiallyEnabled={false} /></div> : null}</>;
}
