import "server-only";

import { createClient } from "@/lib/supabase/server";
import type { LeagueLeaderboards, LeaderboardPlayer } from "./types";

export async function getLeagueLeaderboards(leagueId: string): Promise<LeagueLeaderboards> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("get_league_leaderboard_rows", {
    target_league: leagueId,
  });
  if (error) throw new Error("Impossibile caricare le classifiche della lega.");
  const rows = (data ?? []) as Array<{
    user_id: string;
    first_name: string | null;
    last_name: string | null;
    username: string;
    avatar_path: string | null;
    matches_played: number;
    goals: number;
    assists: number;
    mvp_awards: number;
    overall: number;
  }>;
  const players: LeaderboardPlayer[] = rows.map((row) => {
    return {
      userId: row.user_id,
      username: row.username,
      name: [row.first_name, row.last_name].filter(Boolean).join(" ") || `@${row.username}`,
      avatarUrl: row.avatar_path ? supabase.storage.from("avatars").getPublicUrl(row.avatar_path).data.publicUrl : null,
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
