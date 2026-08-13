import type { FootballRole, MatchFormat } from "@/types/database";

export type LeagueRole = "owner" | "admin" | "member";
export type LeagueVisibility = "private" | "public";

export interface LeagueSummary {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  logoUrl: string | null;
  city: string;
  country: string;
  visibility: LeagueVisibility;
  footballFormat: MatchFormat;
  maxMembers: number;
  memberCount: number;
  currentUserRole: LeagueRole;
}

export interface LeagueMember {
  id: string;
  userId: string;
  firstName: string | null;
  lastName: string | null;
  username: string;
  avatarUrl: string | null;
  footballRole: FootballRole | null;
  leagueRole: LeagueRole;
  joinedAt: string;
}

export interface LeagueDetail extends LeagueSummary {
  ownerId: string;
  inviteCode: string;
  members: LeagueMember[];
}

export interface InvitePreview {
  id: string;
  name: string;
  slug: string;
  logoUrl: string | null;
  city: string;
  country: string;
  visibility: LeagueVisibility;
  footballFormat: MatchFormat;
  maxMembers: number;
  memberCount: number;
  alreadyMember: boolean;
}
