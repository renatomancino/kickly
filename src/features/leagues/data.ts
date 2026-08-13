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

interface MembershipRow {
  id: string;
  league_id: string;
  user_id: string;
  role: LeagueRole;
  joined_at: string;
}

interface ProfilePreviewRow {
  id: string;
  first_name: string | null;
  last_name: string | null;
  username: string;
  avatar_path: string | null;
  primary_position: FootballRole | null;
}

export const getUserLeagues = cache(async (): Promise<LeagueSummary[]> => {
  const user = await requireUser();
  const supabase = await createClient();
  const { data: memberships, error: membershipError } = await supabase
    .from("league_members")
    .select("id, league_id, user_id, role, joined_at")
    .eq("user_id", user.id)
    .eq("status", "active")
    .order("joined_at", { ascending: false });

  if (membershipError) throw new Error("Impossibile caricare le leghe.");
  const ownMemberships = (memberships ?? []) as MembershipRow[];
  if (!ownMemberships.length) return [];

  const leagueIds = ownMemberships.map((membership) => membership.league_id);
  const [{ data: leagues, error: leaguesError }, { data: memberRows }] =
    await Promise.all([
      supabase
        .from("leagues")
        .select(
          "id, owner_id, name, slug, description, logo_url, city, country, visibility, football_format, max_members, invite_code",
        )
        .in("id", leagueIds),
      supabase
        .from("league_members")
        .select("league_id")
        .in("league_id", leagueIds)
        .eq("status", "active"),
    ]);

  if (leaguesError) throw new Error("Impossibile caricare le leghe.");
  const roleByLeague = new Map(
    ownMemberships.map((membership) => [membership.league_id, membership.role]),
  );
  const countByLeague = new Map<string, number>();
  (memberRows ?? []).forEach((row: { league_id: string }) => {
    countByLeague.set(row.league_id, (countByLeague.get(row.league_id) ?? 0) + 1);
  });

  return ((leagues ?? []) as LeagueRow[])
    .map((league) => mapLeagueSummary(league, roleByLeague.get(league.id) ?? "member", countByLeague.get(league.id) ?? 0))
    .sort((a, b) => a.name.localeCompare(b.name, "it"));
});

export const getLeagueBySlug = cache(
  async (slug: string): Promise<LeagueDetail | null> => {
    const user = await requireUser();
    const supabase = await createClient();
    const { data: leagueData, error: leagueError } = await supabase
      .from("leagues")
      .select(
        "id, owner_id, name, slug, description, logo_url, city, country, visibility, football_format, max_members, invite_code",
      )
      .eq("slug", slug)
      .maybeSingle();

    if (leagueError || !leagueData) return null;
    const league = leagueData as LeagueRow;
    const { data: currentMembership } = await supabase
      .from("league_members")
      .select("role")
      .eq("league_id", league.id)
      .eq("user_id", user.id)
      .eq("status", "active")
      .maybeSingle();
    if (!currentMembership) return null;

    const { data: memberships, error: membersError } = await supabase
      .from("league_members")
      .select("id, league_id, user_id, role, joined_at")
      .eq("league_id", league.id)
      .eq("status", "active")
      .order("joined_at");
    if (membersError) throw new Error("Impossibile caricare i membri.");

    const activeMemberships = (memberships ?? []) as MembershipRow[];
    const profileIds = activeMemberships.map((membership) => membership.user_id);
    const { data: profiles, error: profilesError } = profileIds.length
      ? await supabase
          .from("profiles")
          .select("id, first_name, last_name, username, avatar_path, primary_position")
          .in("id", profileIds)
      : { data: [], error: null };
    if (profilesError) throw new Error("Impossibile caricare i profili.");

    const profileById = new Map(
      ((profiles ?? []) as ProfilePreviewRow[]).map((profile) => [profile.id, profile]),
    );
    const members: LeagueMember[] = activeMemberships.map((membership) => {
      const profile = profileById.get(membership.user_id);
      const avatarUrl = profile?.avatar_path
        ? supabase.storage.from("avatars").getPublicUrl(profile.avatar_path).data.publicUrl
        : null;
      return {
        id: membership.id,
        userId: membership.user_id,
        firstName: profile?.first_name ?? null,
        lastName: profile?.last_name ?? null,
        username: profile?.username ?? "giocatore",
        avatarUrl,
        footballRole: profile?.primary_position ?? null,
        leagueRole: membership.role,
        joinedAt: membership.joined_at,
      };
    });

    const currentRole = (currentMembership as { role: LeagueRole }).role;
    return {
      ...mapLeagueSummary(league, currentRole, members.length),
      ownerId: league.owner_id,
      inviteCode: league.invite_code,
      members: members.sort((a, b) => roleOrder(a.leagueRole) - roleOrder(b.leagueRole)),
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

function roleOrder(role: LeagueRole) {
  return role === "owner" ? 0 : role === "admin" ? 1 : 2;
}
