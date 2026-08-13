import "server-only";

import { createClient } from "@/lib/supabase/server";
import type { MatchResult, ProfileRow } from "@/types/database";

export interface PlayerProfileData {
  profile: Pick<ProfileRow, "id" | "first_name" | "last_name" | "username" | "avatar_path" | "primary_position" | "skill_level" | "overall">;
  avatarUrl: string | null;
  stats: { matches: number; wins: number; draws: number; losses: number; goals: number; assists: number; mvp: number; overall: number; winRate: number };
  trend: number;
  history: { id: string; previous: number; rating: number; delta: number; createdAt: string }[];
  form: MatchResult[];
}

export async function getPlayerProfile(username: string): Promise<PlayerProfileData | null> {
  const supabase = await createClient();
  const { data: profileData, error } = await supabase.from("profiles").select("id, first_name, last_name, username, avatar_path, primary_position, skill_level, overall").eq("username", username).maybeSingle();
  if (error || !profileData) return null;
  const profile = profileData as PlayerProfileData["profile"];
  const [{ data: statsData }, { data: historyData }, { data: formData }] = await Promise.all([
    supabase.from("player_stats").select("matches_played, wins, draws, losses, goals, assists, mvp_awards, overall").eq("user_id", profile.id).is("league_id", null).is("season_id", null).maybeSingle(),
    supabase.from("player_rating_history").select("id, previous_rating, new_rating, delta, created_at").eq("user_id", profile.id).not("match_id", "is", null).order("created_at", { ascending: false }).limit(10),
    supabase.from("player_match_stats").select("result, created_at").eq("user_id", profile.id).order("created_at", { ascending: false }).limit(5),
  ]);
  const stats = statsData as { matches_played?: number; wins?: number; draws?: number; losses?: number; goals?: number; assists?: number; mvp_awards?: number; overall?: number } | null;
  const history = ((historyData ?? []) as { id: string; previous_rating: number; new_rating: number; delta: number; created_at: string }[]).map((row) => ({ id: row.id, previous: Number(row.previous_rating), rating: Number(row.new_rating), delta: Number(row.delta), createdAt: row.created_at })).reverse();
  const recent = history.slice(-5);
  const matches = Number(stats?.matches_played ?? 0);
  return {
    profile,
    avatarUrl: profile.avatar_path ? supabase.storage.from("avatars").getPublicUrl(profile.avatar_path).data.publicUrl : null,
    stats: { matches, wins: Number(stats?.wins ?? 0), draws: Number(stats?.draws ?? 0), losses: Number(stats?.losses ?? 0), goals: Number(stats?.goals ?? 0), assists: Number(stats?.assists ?? 0), mvp: Number(stats?.mvp_awards ?? 0), overall: Number(stats?.overall ?? profile.overall), winRate: matches ? Math.round((Number(stats?.wins ?? 0) / matches) * 100) : 0 },
    trend: recent.length ? Number((recent.at(-1)!.rating - recent[0].previous).toFixed(1)) : 0,
    history,
    form: ((formData ?? []) as { result: MatchResult }[]).map((row) => row.result),
  };
}
