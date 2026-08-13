import "server-only";

import { cache } from "react";

import { getUserLeagues } from "@/features/leagues/data";
import type { LeagueRole, LeagueSummary } from "@/features/leagues/types";
import { requireUser } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import type {
  AttendanceStatus,
  FootballRole,
  MatchFormat,
  MatchStatus,
  MatchVisibility,
} from "@/types/database";

import type {
  ManagedLeague,
  MatchDetail,
  MatchParticipantView,
  MatchSummary,
} from "./types";

interface MatchRow {
  id: string;
  league_id: string;
  created_by: string;
  title: string;
  description: string | null;
  starts_at: string;
  location_name: string;
  address: string | null;
  city: string;
  latitude: number | null;
  longitude: number | null;
  football_format: MatchFormat;
  max_players: number;
  cost_total: number | null;
  visibility: MatchVisibility;
  status: MatchStatus;
  registration_closed_at: string | null;
  team_a_score: number | null;
  team_b_score: number | null;
  completed_at: string | null;
  mvp_voting_ends_at: string | null;
  mvp_finalized_at: string | null;
}

interface ParticipantRow {
  id: string;
  match_id: string;
  user_id: string;
  response: AttendanceStatus;
  joined_at: string;
}

interface ParticipantProfileRow {
  id: string;
  first_name: string | null;
  last_name: string | null;
  username: string;
  avatar_path: string | null;
  primary_position: FootballRole | null;
  overall: number;
}

const matchSelect =
  "id, league_id, created_by, title, description, starts_at, location_name, address, city, latitude, longitude, football_format, max_players, cost_total, visibility, status, registration_closed_at, team_a_score, team_b_score, completed_at, mvp_voting_ends_at, mvp_finalized_at";

export const getManagedLeagues = cache(async (): Promise<ManagedLeague[]> => {
  const leagues = await getUserLeagues();
  return leagues
    .filter((league) => league.currentUserRole === "owner" || league.currentUserRole === "admin")
    .map((league) => ({
      id: league.id,
      name: league.name,
      slug: league.slug,
      city: league.city,
      footballFormat: league.footballFormat,
    }));
});

export const getUserMatches = cache(async (): Promise<MatchSummary[]> => {
  const user = await requireUser();
  const supabase = await createClient();
  const leagues = await getUserLeagues();
  const { data, error } = await supabase
    .from("matches")
    .select(matchSelect)
    .order("starts_at", { ascending: true });
  if (error) throw new Error("Impossibile caricare le partite.");
  const rows = (data ?? []) as MatchRow[];
  const knownLeagueIds = new Set(leagues.map((league) => league.id));
  const missingLeagueIds = [...new Set(rows.map((row) => row.league_id).filter((id) => !knownLeagueIds.has(id)))];
  const { data: publicLeagues } = missingLeagueIds.length
    ? await supabase.from("leagues").select("id, name, slug").in("id", missingLeagueIds).eq("visibility", "public")
    : { data: [] };
  const leagueLabels = [
    ...leagues.map((league) => ({ id: league.id, name: league.name, slug: league.slug })),
    ...((publicLeagues ?? []) as { id: string; name: string; slug: string }[]),
  ];
  return hydrateSummaries(rows, leagueLabels, user.id, knownLeagueIds);
});

export async function getLeagueMatches(league: LeagueSummary): Promise<MatchSummary[]> {
  const user = await requireUser();
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("matches")
    .select(matchSelect)
    .eq("league_id", league.id)
    .order("starts_at", { ascending: true });
  if (error) throw new Error("Impossibile caricare le partite della lega.");
  return hydrateSummaries((data ?? []) as MatchRow[], [league], user.id, new Set([league.id]));
}

export const getMatchById = cache(async (id: string): Promise<MatchDetail | null> => {
  const user = await requireUser();
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("matches")
    .select(matchSelect)
    .eq("id", id)
    .maybeSingle();
  if (error || !data) return null;
  const match = data as MatchRow;

  const [{ data: leagueData }, { data: membership }, { data: participantData }] = await Promise.all([
    supabase.from("leagues").select("id, name, slug").eq("id", match.league_id).maybeSingle(),
    supabase
      .from("league_members")
      .select("role")
      .eq("league_id", match.league_id)
      .eq("user_id", user.id)
      .eq("status", "active")
      .maybeSingle(),
    supabase
      .from("match_participants")
      .select("id, match_id, user_id, response, joined_at")
      .eq("match_id", match.id)
      .order("joined_at", { ascending: true }),
  ]);
  if (!leagueData) return null;
  const isLeagueMember = Boolean(membership);

  const participants = (participantData ?? []) as ParticipantRow[];
  const userIds = participants.map((participant) => participant.user_id);
  const { data: profileData } = userIds.length
    ? await supabase
        .from("profiles")
        .select("id, first_name, last_name, username, avatar_path, primary_position, overall")
        .in("id", userIds)
    : { data: [] };
  const profiles = new Map(
    ((profileData ?? []) as ParticipantProfileRow[]).map((profile) => [profile.id, profile]),
  );
  const participantViews: MatchParticipantView[] = participants.map((participant) => {
    const profile = profiles.get(participant.user_id);
    return {
      id: participant.id,
      userId: participant.user_id,
      firstName: profile?.first_name ?? null,
      lastName: profile?.last_name ?? null,
      username: profile?.username ?? "giocatore",
      avatarUrl: profile?.avatar_path
        ? supabase.storage.from("avatars").getPublicUrl(profile.avatar_path).data.publicUrl
        : null,
      footballRole: profile?.primary_position ?? null,
      overall: Number(profile?.overall ?? 70),
      response: participant.response,
      joinedAt: participant.joined_at,
    };
  });
  const currentResponse = participants.find((participant) => participant.user_id === user.id)?.response ?? null;
  const league = leagueData as { name: string; slug: string };
  const postGame = isLeagueMember && match.status === "completed" && match.completed_at && match.team_a_score !== null && match.team_b_score !== null
    ? await loadPostGame(supabase, match, user.id)
    : null;

  return {
    ...mapSummary(match, league.name, league.slug, participants, currentResponse, isLeagueMember),
    currentUserId: user.id,
    createdBy: match.created_by,
    description: match.description,
    address: match.address,
    latitude: match.latitude,
    longitude: match.longitude,
    costTotal: match.cost_total === null ? null : Number(match.cost_total),
    currentUserRole: membership ? (membership as { role: LeagueRole }).role : null,
    participants: participantViews,
    postGame,
  };
});

async function loadPostGame(
  supabase: Awaited<ReturnType<typeof createClient>>,
  match: MatchRow,
  userId: string,
) {
  const [{ data: teamRows }, { data: assignmentRows }, { data: statsRows }, { data: voteRow }] = await Promise.all([
    supabase.from("match_teams").select("id, name, team_number").eq("match_id", match.id).order("team_number"),
    supabase.from("match_team_players").select("team_id, user_id").eq("match_id", match.id),
    supabase.from("player_match_stats").select("user_id, team_id, goals, assists, result, is_mvp, match_rating, previous_overall, new_overall, rating_delta").eq("match_id", match.id),
    supabase.from("mvp_votes").select("voted_player_id").eq("match_id", match.id).eq("voter_id", userId).maybeSingle(),
  ]);
  const teams = ((teamRows ?? []) as { id: string; name: string; team_number: 1 | 2 }[]).map((team) => ({
    id: team.id,
    name: team.name,
    teamNumber: team.team_number,
    playerIds: ((assignmentRows ?? []) as { team_id: string; user_id: string }[])
      .filter((assignment) => assignment.team_id === team.id)
      .map((assignment) => assignment.user_id),
  }));
  const winnerId = ((statsRows ?? []) as { user_id: string; is_mvp: boolean }[]).find((stats) => stats.is_mvp)?.user_id;
  const { count: voteCount } = winnerId && match.mvp_finalized_at
    ? await supabase.from("mvp_votes").select("id", { count: "exact", head: true }).eq("match_id", match.id).eq("voted_player_id", winnerId)
    : { count: null };
  return {
    teamAScore: Number(match.team_a_score),
    teamBScore: Number(match.team_b_score),
    completedAt: match.completed_at!,
    mvpVotingEndsAt: match.mvp_voting_ends_at ?? match.completed_at!,
    mvpFinalizedAt: match.mvp_finalized_at,
    teams,
    playerStats: ((statsRows ?? []) as {
      user_id: string; team_id: string; goals: number; assists: number; result: "win" | "draw" | "loss";
      is_mvp: boolean; match_rating: number | null; previous_overall: number | null; new_overall: number | null; rating_delta: number;
    }[]).map((stats) => ({
      userId: stats.user_id,
      teamId: stats.team_id,
      goals: Number(stats.goals),
      assists: Number(stats.assists),
      result: stats.result,
      isMvp: stats.is_mvp,
      matchRating: stats.match_rating === null ? null : Number(stats.match_rating),
      previousOverall: stats.previous_overall === null ? null : Number(stats.previous_overall),
      newOverall: stats.new_overall === null ? null : Number(stats.new_overall),
      ratingDelta: Number(stats.rating_delta),
    })),
    ownVotePlayerId: (voteRow as { voted_player_id?: string } | null)?.voted_player_id ?? null,
    mvpVotes: voteCount,
  };
}

async function hydrateSummaries(
  rows: MatchRow[],
  leagues: Array<Pick<LeagueSummary, "id" | "name" | "slug">>,
  userId: string,
  ownLeagueIds: Set<string>,
) {
  if (!rows.length) return [];
  const supabase = await createClient();
  const [{ data, error }, { data: countRows }] = await Promise.all([
    supabase.from("match_participants").select("id, match_id, user_id, response, joined_at").in("match_id", rows.map((row) => row.id)),
    supabase.rpc("get_visible_match_counts", { target_matches: rows.map((row) => row.id) }),
  ]);
  if (error) throw new Error("Impossibile caricare le partecipazioni.");
  const participants = (data ?? []) as ParticipantRow[];
  const leagueMap = new Map(leagues.map((league) => [league.id, league]));
  const publicCounts = new Map(((countRows ?? []) as { match_id: string; going_count: number }[]).map((row) => [row.match_id, Number(row.going_count)]));

  return rows.map((row) => {
    const league = leagueMap.get(row.league_id);
    const matchParticipants = participants.filter((participant) => participant.match_id === row.id);
    const currentResponse = matchParticipants.find((participant) => participant.user_id === userId)?.response ?? null;
    return mapSummary(row, league?.name ?? "Lega Kickly", league?.slug ?? "", matchParticipants, currentResponse, ownLeagueIds.has(row.league_id), publicCounts.get(row.id));
  });
}

function mapSummary(
  row: MatchRow,
  leagueName: string,
  leagueSlug: string,
  participants: ParticipantRow[],
  currentResponse: AttendanceStatus | null,
  isLeagueMember: boolean,
  goingCount?: number,
): MatchSummary {
  return {
    id: row.id,
    leagueId: row.league_id,
    leagueName,
    leagueSlug,
    title: row.title,
    startsAt: row.starts_at,
    locationName: row.location_name,
    city: row.city,
    footballFormat: row.football_format,
    maxPlayers: row.max_players,
    goingCount: goingCount ?? participants.filter((participant) => participant.response === "going").length,
    status: row.status,
    visibility: row.visibility,
    registrationClosedAt: row.registration_closed_at,
    currentResponse,
    isLeagueMember,
  };
}
