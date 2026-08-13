import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { getMatchById } from "@/features/matches/data";
import { MatchDetailView } from "@/features/matches/match-detail-view";

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  const match = await getMatchById(id);
  return { title: match?.title ?? "Partita" };
}

export default async function MatchPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const match = await getMatchById(id);
  if (!match) notFound();
  return <MatchDetailView match={match} />;
}
