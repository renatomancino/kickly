import type { Metadata } from "next";
import Link from "next/link";
import { CalendarPlus } from "lucide-react";

import { Button } from "@/components/ui/button";
import { getManagedLeagues, getUserMatches } from "@/features/matches/data";
import { MatchList } from "@/features/matches/match-list";

export const metadata: Metadata = { title: "Partite" };

export default async function MatchesPage() {
  const [matches, managedLeagues] = await Promise.all([getUserMatches(), getManagedLeagues()]);
  const createHref = managedLeagues.length === 1 ? `/matches/new?league=${managedLeagues[0].id}` : "/matches/new";
  return <main className="py-5 sm:py-8"><header className="mb-6 flex items-end justify-between gap-4"><div><p className="text-xs font-semibold tracking-[0.16em] text-primary uppercase">Calendario</p><h1 className="mt-1 text-3xl font-black">Partite</h1><p className="mt-2 text-sm text-muted-foreground">Tutte le partite delle tue leghe.</p></div>{managedLeagues.length ? <Button asChild className="shrink-0"><Link href={createHref}><CalendarPlus />Crea</Link></Button> : null}</header><MatchList canCreate={managedLeagues.length > 0} createHref={createHref} matches={matches} /></main>;
}
