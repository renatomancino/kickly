import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { getLeagueBySlug, getLeagueCommunications } from "@/features/leagues/data";
import { LeaguePageView } from "@/features/leagues/league-page-view";
import { getLeagueMatches } from "@/features/matches/data";
import { requireUser } from "@/lib/auth";
import { getLeagueLeaderboards } from "@/features/stats/data";

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const league = await getLeagueBySlug(slug);
  return { title: league?.name ?? "Lega" };
}

export default async function LeaguePage({ params, searchParams }: { params: Promise<{ slug: string }>; searchParams: Promise<{ tab?: string }> }) {
  const [{ slug }, query] = await Promise.all([params, searchParams]);
  const [user, league] = await Promise.all([requireUser(), getLeagueBySlug(slug)]);
  if (!league) notFound();
  const [matches, leaderboards, communications] = await Promise.all([getLeagueMatches(league), getLeagueLeaderboards(league.id), getLeagueCommunications(league.id)]);
  return <LeaguePageView communications={communications} currentUserId={user.id} initialTab={query.tab === "communications" ? "communications" : "home"} league={league} leaderboards={leaderboards} matches={matches} />;
}
