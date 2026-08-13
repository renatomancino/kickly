import type {
  AttendanceStatus,
  FootballRole,
  MatchFormat,
  MatchStatus,
  MatchVisibility,
  MatchResult,
} from "@/types/database";
import type { LeagueRole } from "@/features/leagues/types";

export interface ManagedLeague {
  id: string;
  name: string;
  slug: string;
  city: string;
  footballFormat: MatchFormat;
}

export interface MatchSummary {
  id: string;
  leagueId: string;
  leagueName: string;
  leagueSlug: string;
  title: string;
  startsAt: string;
  locationName: string;
  city: string;
  footballFormat: MatchFormat;
  maxPlayers: number;
  goingCount: number;
  status: MatchStatus;
  visibility: MatchVisibility;
  registrationClosedAt: string | null;
  currentResponse: AttendanceStatus | null;
  isLeagueMember: boolean;
}

export interface MatchParticipantView {
  id: string;
  userId: string;
  firstName: string | null;
  lastName: string | null;
  username: string;
  avatarUrl: string | null;
  footballRole: FootballRole | null;
  overall: number;
  response: AttendanceStatus;
  joinedAt: string;
}

export interface MatchPlayerStatsView {
  userId: string;
  teamId: string;
  goals: number;
  assists: number;
  result: MatchResult;
  isMvp: boolean;
  matchRating: number | null;
  previousOverall: number | null;
  newOverall: number | null;
  ratingDelta: number;
}

export interface MatchTeamView {
  id: string;
  name: string;
  teamNumber: 1 | 2;
  playerIds: string[];
}

export interface MatchLineupTeam {
  teamNumber: 1 | 2;
  formation: string;
  captainUserId: string | null;
}

export interface MatchLineupPlayer {
  userId: string;
  teamNumber: 1 | 2;
  slotKey: string;
}

export interface MatchLineup {
  teams: MatchLineupTeam[];
  players: MatchLineupPlayer[];
}

export interface MatchPostGame {
  teamAScore: number;
  teamBScore: number;
  completedAt: string;
  mvpVotingEndsAt: string;
  mvpFinalizedAt: string | null;
  teams: MatchTeamView[];
  playerStats: MatchPlayerStatsView[];
  ownVotePlayerId: string | null;
  mvpVotes: number | null;
}

export interface MatchDetail extends MatchSummary {
  currentUserId: string;
  createdBy: string;
  description: string | null;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
  costTotal: number | null;
  currentUserRole: LeagueRole | null;
  participants: MatchParticipantView[];
  lineup: MatchLineup;
  postGame: MatchPostGame | null;
}

export interface MatchFormDefaults {
  id?: string;
  leagueId: string;
  title: string;
  description: string;
  startsAt?: string;
  locationName: string;
  address: string;
  city: string;
  footballFormat: MatchFormat;
  maxPlayers: number;
  costTotal: number | null;
  visibility: MatchVisibility;
}
