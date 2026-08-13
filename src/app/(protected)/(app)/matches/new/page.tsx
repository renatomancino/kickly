import type { Metadata } from "next";
import Link from "next/link";
import { ChevronLeft } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { getManagedLeagues } from "@/features/matches/data";
import { MatchForm } from "@/features/matches/match-form";

export const metadata: Metadata = { title: "Crea partita" };

export default async function NewMatchPage({ searchParams }: { searchParams: Promise<{ league?: string }> }) {
  const [{ league: leagueId }, leagues] = await Promise.all([searchParams, getManagedLeagues()]);
  if (!leagues.length) return <main className="py-8"><Card className="border-dashed"><CardContent className="py-12 text-center"><h1 className="text-xl font-bold">Nessuna lega gestibile</h1><p className="mt-2 text-sm text-muted-foreground">Devi essere owner o admin per creare una partita.</p><Button asChild className="mt-5"><Link href="/leagues">Vai alle leghe</Link></Button></CardContent></Card></main>;
  const selected = leagues.find((league) => league.id === leagueId) ?? leagues[0];
  return <main className="mx-auto max-w-2xl py-5 sm:py-8"><Button asChild className="-ms-2 mb-4" variant="ghost"><Link href="/matches"><ChevronLeft />Partite</Link></Button><div className="mb-7"><p className="text-xs font-semibold tracking-[0.16em] text-primary uppercase">Nuovo evento</p><h1 className="mt-1 text-3xl font-black">Crea partita</h1><p className="mt-2 text-sm text-muted-foreground">Organizza il prossimo calcio d’inizio.</p></div><MatchForm defaults={{ leagueId: selected.id, title: "", description: "", locationName: "", address: "", city: selected.city, footballFormat: selected.footballFormat, maxPlayers: Number(selected.footballFormat.split("v")[0]) * 2, costTotal: null, visibility: "league_only" }} leagues={leagues} /></main>;
}
