import "server-only";

import { createClient } from "@/lib/supabase/server";
import type { LeagueLeaderboards, LeaderboardPlayer } from "./types";

export async function getLeagueLeaderboards(leagueId: string): Promise<LeagueLeaderboards> {
  const supabase = await createClient();
  const { data } = await supabase.from("player_stats").select("user_id, matches_played, goals, assists, mvp_awards, overall").eq("league_id", leagueId).is("season_id", null);
  const rows = (data ?? []) as { user_id: string; matches_played: number; goals: number; assists: number; mvp_awards: number; overall: number }[];
  const ids = rows.map((row) => row.user_id);
  const { data: profiles } = ids.length ? await supabase.from("profiles").select("id, first_name, last_name, username, avatar_path").in("id", ids) : { data: [] };
  const profileMap = new Map(((profiles ?? []) as { id: string; first_name: string | null; last_name: string | null; username: string; avatar_path: string | null }[]).map((profile) => [profile.id, profile]));
  const players: LeaderboardPlayer[] = rows.map((row) => {
    const profile = profileMap.get(row.user_id);
    return {
      userId: row.user_id,
      username: profile?.username ?? "giocatore",
      name: [profile?.first_name, profile?.last_name].filter(Boolean).join(" ") || `@${profile?.username ?? "giocatore"}`,
      avatarUrl: profile?.avatar_path ? supabase.storage.from("avatars").getPublicUrl(profile.avatar_path).data.publicUrl : null,
      matches: Number(row.matches_played), goals: Number(row.goals), assists: Number(row.assists), mvp: Number(row.mvp_awards), overall: Number(row.overall),
    };
  });
  const rate = (value: number, matches: number) => matches ? value / matches : 0;
  return {
    goals: [...players].sort((a, b) => b.goals - a.goals || rate(b.goals, b.matches) - rate(a.goals, a.matches) || a.username.localeCompare(b.username)),
    assists: [...players].sort((a, b) => b.assists - a.assists || rate(b.assists, b.matches) - rate(a.assists, a.matches) || a.username.localeCompare(b.username)),
    mvp: [...players].sort((a, b) => b.mvp - a.mvp || b.goals - a.goals || a.username.localeCompare(b.username)),
    appearances: [...players].sort((a, b) => b.matches - a.matches || a.username.localeCompare(b.username)),
    overall: [...players].sort((a, b) => b.overall - a.overall || a.username.localeCompare(b.username)),
  };
}
