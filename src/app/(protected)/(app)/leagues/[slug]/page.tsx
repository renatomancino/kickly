import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { getLeagueBySlug } from "@/features/leagues/data";
import { LeaguePageView } from "@/features/leagues/league-page-view";
import { getLeagueMatches } from "@/features/matches/data";
import { requireUser } from "@/lib/auth";
import { getLeagueLeaderboards } from "@/features/stats/data";

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const league = await getLeagueBySlug(slug);
  return { title: league?.name ?? "Lega" };
}

export default async function LeaguePage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const [user, league] = await Promise.all([requireUser(), getLeagueBySlug(slug)]);
  if (!league) notFound();
  const [matches, leaderboards] = await Promise.all([getLeagueMatches(league), getLeagueLeaderboards(league.id)]);
  return <LeaguePageView currentUserId={user.id} league={league} leaderboards={leaderboards} matches={matches} />;
}
