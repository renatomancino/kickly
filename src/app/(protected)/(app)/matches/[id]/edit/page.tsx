import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ChevronLeft } from "lucide-react";

import { Button } from "@/components/ui/button";
import { getManagedLeagues, getMatchById } from "@/features/matches/data";
import { MatchForm } from "@/features/matches/match-form";

export const metadata: Metadata = { title: "Modifica partita" };

export default async function EditMatchPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [match, leagues] = await Promise.all([getMatchById(id), getManagedLeagues()]);
  if (!match || (match.currentUserRole !== "owner" && match.currentUserRole !== "admin")) notFound();
  const managedLeague = leagues.find((league) => league.id === match.leagueId);
  if (!managedLeague) notFound();
  return <main className="mx-auto max-w-2xl py-5 sm:py-8"><Button asChild className="-ms-2 mb-4" variant="ghost"><Link href={`/matches/${match.id}`}><ChevronLeft />Partita</Link></Button><div className="mb-7"><p className="text-xs font-semibold tracking-[0.16em] text-primary uppercase">Gestione</p><h1 className="mt-1 text-3xl font-black">Modifica partita</h1></div><MatchForm defaults={{ id: match.id, leagueId: match.leagueId, title: match.title, description: match.description ?? "", startsAt: match.startsAt, locationName: match.locationName, address: match.address ?? "", city: match.city, footballFormat: match.footballFormat, maxPlayers: match.maxPlayers, costTotal: match.costTotal, visibility: match.visibility }} leagues={[managedLeague]} /></main>;
}
