import "server-only";

import { hasSupabaseEnv } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";
import { getUserLeagues } from "@/features/leagues/data";

import { demoDashboardData } from "./demo-data";
import type { DashboardData, DashboardMatch } from "./types";

export async function getDashboardData(userId?: string): Promise<DashboardData> {
  if (!hasSupabaseEnv() || !userId) return demoDashboardData;

  const supabase = await createClient();
  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("first_name, username, primary_position, avatar_path, overall, timezone")
    .eq("id", userId)
    .single();

  if (profileError) return demoDashboardData;

  const userLeagues = await getUserLeagues();

  const [{ data: stats }, { count: unreadNotifications }, { data: lastStatsData }] =
    await Promise.all([
      supabase
        .from("player_stats")
        .select("matches_played, goals, assists, mvp_awards, overall")
        .eq("user_id", userId)
        .is("league_id", null)
        .is("season_id", null)
        .maybeSingle(),
      supabase
        .from("notifications")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId)
        .is("read_at", null),
      supabase
        .from("player_match_stats")
        .select("match_id, goals, assists, match_rating, result, is_mvp, created_at")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle(),
    ]);

  const leagueIds = userLeagues.map((league) => league.id);
  const { data: nextMatches } = leagueIds.length
    ? await supabase
        .from("matches")
        .select("id, league_id, title, starts_at, location_name, football_format, max_players")
        .in("league_id", leagueIds)
        .in("status", ["open", "full"])
        .gte("starts_at", new Date().toISOString())
        .order("starts_at")
        .limit(8)
    : { data: [] };
  const otherMatches = (nextMatches ?? []).slice(1, 5);

  const allMatches = nextMatches ?? [];
  const matchIds = [...new Set(allMatches.map((match) => match.id))];
  const { data: participantRows } =
    matchIds.length
      ? await supabase
          .from("match_participants")
          .select("match_id, user_id, response")
          .in("match_id", matchIds)
      : { data: [] };

  const leagueMap = new Map(
    userLeagues.map((league) => [league.id, { id: league.id, name: league.name, city: league.city }]),
  );
  const participantCount = new Map<string, number>();
  const participation = new Map<string, DashboardMatch["participation"]>();
  participantRows?.forEach((row) => {
    if (row.response === "going") {
      participantCount.set(row.match_id, (participantCount.get(row.match_id) ?? 0) + 1);
    }
    if (row.user_id === userId) participation.set(row.match_id, row.response);
  });

  const toDashboardMatch = (match: NonNullable<typeof nextMatches>[number]): DashboardMatch => {
    const league = leagueMap.get(match.league_id);
    return {
      id: match.id,
      leagueName: league?.name ?? "Lega Kickly",
      title: match.title,
      startsAt: match.starts_at,
      venueName: match.location_name,
      city: league?.city ?? "",
      format: match.football_format,
      going: participantCount.get(match.id) ?? 0,
      maxPlayers: match.max_players,
      participation: participation.get(match.id) ?? null,
    };
  };

  const next = nextMatches?.[0] ? toDashboardMatch(nextMatches[0]) : null;
  const lastStats = lastStatsData as { match_id: string; goals: number; assists: number; match_rating: number | null; result: "win" | "draw" | "loss"; is_mvp: boolean } | null;
  const { data: lastMatchData } = lastStats
    ? await supabase.from("matches").select("id, league_id, title, team_a_score, team_b_score").eq("id", lastStats.match_id).maybeSingle()
    : { data: null };
  const avatarUrl = profile.avatar_path
    ? supabase.storage.from("avatars").getPublicUrl(profile.avatar_path).data.publicUrl
    : null;

  return {
    source: "live",
    firstName: profile.first_name ?? profile.username,
    username: profile.username,
    role: profile.primary_position,
    avatarUrl,
    timezone: profile.timezone,
    unreadNotifications: unreadNotifications ?? 0,
    nextMatch: next,
    lastMatch: lastStats && lastMatchData ? {
      id: lastMatchData.id,
      title: lastMatchData.title,
      leagueName: leagueMap.get(lastMatchData.league_id)?.name ?? "Lega Kickly",
      teamAScore: Number(lastMatchData.team_a_score ?? 0),
      teamBScore: Number(lastMatchData.team_b_score ?? 0),
      goals: Number(lastStats.goals), assists: Number(lastStats.assists),
      rating: lastStats.match_rating === null ? null : Number(lastStats.match_rating),
      result: lastStats.result, isMvp: lastStats.is_mvp,
    } : null,
    leagues: userLeagues.slice(0, 4).map((league) => {
      const nextLeagueMatch = nextMatches?.find((match) => match.league_id === league.id);
      return {
        id: league.id,
        name: league.name,
        slug: league.slug,
        logoUrl: league.logoUrl,
        city: league.city,
        members: league.memberCount,
        format: league.footballFormat,
        role: league.currentUserRole,
        nextMatchAt: nextLeagueMatch?.starts_at ?? null,
      };
    }),
    stats: {
      matches: stats?.matches_played ?? 0,
      goals: stats?.goals ?? 0,
      assists: stats?.assists ?? 0,
      mvp: stats?.mvp_awards ?? 0,
      overall: stats?.overall ?? profile.overall,
    },
    nearby: otherMatches.map(toDashboardMatch),
  };
}
