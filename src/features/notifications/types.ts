import type { Json } from "@/types/database";

export type NotificationKind = "match_created" | "match_updated" | "match_cancelled" | "match_reminder" | "waitlist_promoted" | "mvp_voting_open" | "mvp_winner" | "rating_changed" | "league_invite" | "league_role_changed";

export interface NotificationItem {
  id: string;
  type: NotificationKind | string;
  title: string;
  body: string;
  link: string | null;
  metadata: Json;
  read_at: string | null;
  created_at: string;
}

export interface NotificationPreferences {
  match_created: boolean;
  match_updates: boolean;
  match_reminders: boolean;
  waitlist: boolean;
  mvp: boolean;
  rating: boolean;
  league_updates: boolean;
  push_enabled: boolean;
}

export const defaultNotificationPreferences: NotificationPreferences = {
  match_created: true,
  match_updates: true,
  match_reminders: true,
  waitlist: true,
  mvp: true,
  rating: true,
  league_updates: true,
  push_enabled: false,
};
