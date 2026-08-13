import "server-only";

import { cache } from "react";

import { requireUser } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import type { FootballRole, MatchFormat } from "@/types/database";

import type {
  InvitePreview,
  LeagueDetail,
  LeagueMember,
  LeagueRole,
  LeagueSummary,
  LeagueVisibility,
} from "./types";

interface LeagueRow {
  id: string;
  owner_id: string;
  name: string;
  slug: string;
  description: string | null;
  logo_url: string | null;
  city: string;
  country: string;
  visibility: LeagueVisibility;
  football_format: MatchFormat;
  max_members: number;
  invite_code: string;
}

interface LeagueSummaryRpcRow extends LeagueRow {
  current_user_role: LeagueRole;
  member_count: number;
}

interface LeagueMemberRpcRow {
  id: string;
  user_id: string;
  role: LeagueRole;
  joined_at: string;
  first_name: string | null;
  last_name: string | null;
  username: string | null;
  avatar_path: string | null;
  football_role: FootballRole | null;
}

interface LeagueDetailRpcRow extends LeagueRow {
  current_user_role: LeagueRole;
  members: LeagueMemberRpcRow[];
}

export const getUserLeagues = cache(async (): Promise<LeagueSummary[]> => {
  await requireUser();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("get_user_league_summaries");
  if (error) throw new Error("Impossibile caricare le leghe.");

  return ((data ?? []) as LeagueSummaryRpcRow[])
    .map((league) => mapLeagueSummary(
      league,
      league.current_user_role,
      Number(league.member_count),
    ))
    .sort((a, b) => a.name.localeCompare(b.name, "it"));
});

export const getLeagueBySlug = cache(
  async (slug: string): Promise<LeagueDetail | null> => {
    await requireUser();
    const supabase = await createClient();
    const { data, error } = await supabase
      .rpc("get_league_detail", { target_slug: slug })
      .maybeSingle();

    if (error || !data) return null;
    const league = data as LeagueDetailRpcRow;
    const members: LeagueMember[] = league.members.map((member) => {
      const avatarUrl = member.avatar_path
        ? supabase.storage.from("avatars").getPublicUrl(member.avatar_path).data.publicUrl
        : null;
      return {
        id: member.id,
        userId: member.user_id,
        firstName: member.first_name,
        lastName: member.last_name,
        username: member.username ?? "giocatore",
        avatarUrl,
        footballRole: member.football_role,
        leagueRole: member.role,
        joinedAt: member.joined_at,
      };
    });

    return {
      ...mapLeagueSummary(league, league.current_user_role, members.length),
      ownerId: league.owner_id,
      inviteCode: league.invite_code,
      members,
    };
  },
);

export async function getInvitePreview(code: string): Promise<InvitePreview | null> {
  await requireUser();
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("get_league_invite_preview", {
    invite: code,
  });
  if (error || !Array.isArray(data) || !data[0]) return null;
  const preview = data[0] as {
    id: string;
    name: string;
    slug: string;
    logo_url: string | null;
    city: string;
    country: string;
    visibility: LeagueVisibility;
    football_format: MatchFormat;
    max_members: number;
    member_count: number;
    already_member: boolean;
  };
  return {
    id: preview.id,
    name: preview.name,
    slug: preview.slug,
    logoUrl: preview.logo_url,
    city: preview.city,
    country: preview.country,
    visibility: preview.visibility,
    footballFormat: preview.football_format,
    maxMembers: preview.max_members,
    memberCount: Number(preview.member_count),
    alreadyMember: preview.already_member,
  };
}

function mapLeagueSummary(
  league: LeagueRow,
  currentUserRole: LeagueRole,
  memberCount: number,
): LeagueSummary {
  return {
    id: league.id,
    name: league.name,
    slug: league.slug,
    description: league.description,
    logoUrl: league.logo_url,
    city: league.city,
    country: league.country,
    visibility: league.visibility,
    footballFormat: league.football_format,
    maxMembers: league.max_members,
    memberCount,
    currentUserRole,
  };
}
