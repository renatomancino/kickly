"use client";

import { useState } from "react";
import Link from "next/link";
import { CalendarPlus } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";

import { MatchCard } from "./match-card";
import type { MatchSummary } from "./types";

type Filter = "all" | "upcoming" | "past";

export function MatchList({ matches, canCreate = false, createHref = "/matches/new", showLeague = true }: { matches: MatchSummary[]; canCreate?: boolean; createHref?: string; showLeague?: boolean }) {
  const [filter, setFilter] = useState<Filter>("all");
  const [now] = useState(() => Date.now());
  const visible = matches.filter((match) => {
    const past = new Date(match.startsAt).getTime() < now || match.status === "completed";
    return filter === "all" || (filter === "past" ? past : !past);
  }).sort((a, b) => filter === "past" ? b.startsAt.localeCompare(a.startsAt) : a.startsAt.localeCompare(b.startsAt));

  if (!matches.length) return <EmptyMatches canCreate={canCreate} createHref={createHref} />;
  return (
    <div>
      <Tabs onValueChange={(value) => setFilter(value as Filter)} value={filter}><TabsList className="w-full"><TabsTrigger value="all">Tutte</TabsTrigger><TabsTrigger value="upcoming">Prossime</TabsTrigger><TabsTrigger value="past">Passate</TabsTrigger></TabsList></Tabs>
      <div className="mt-4 grid gap-3 lg:grid-cols-2">{visible.length ? visible.map((match) => <MatchCard key={match.id} match={match} showLeague={showLeague} />) : <Card className="border-dashed lg:col-span-2"><CardContent className="py-8 text-center text-sm text-muted-foreground">Nessuna partita in questa sezione.</CardContent></Card>}</div>
    </div>
  );
}

export function LeagueMatches({ matches, canCreate, leagueId }: { matches: MatchSummary[]; canCreate: boolean; leagueId: string }) {
  const createHref = `/matches/new?league=${leagueId}`;
  const [now] = useState(() => Date.now());
  if (!matches.length) return <EmptyMatches canCreate={canCreate} createHref={createHref} />;
  const upcoming = matches.filter((match) => new Date(match.startsAt).getTime() >= now && match.status !== "completed").sort((a, b) => a.startsAt.localeCompare(b.startsAt));
  const past = matches.filter((match) => new Date(match.startsAt).getTime() < now || match.status === "completed").sort((a, b) => b.startsAt.localeCompare(a.startsAt));
  return <div className="space-y-8"><MatchSection matches={upcoming} title="Prossime" /><MatchSection matches={past} title="Passate" /></div>;
}

function MatchSection({ title, matches }: { title: string; matches: MatchSummary[] }) {
  return <section><p className="mb-3 text-xs font-bold tracking-[0.16em] text-muted-foreground uppercase">{title}</p>{matches.length ? <div className="grid gap-3 lg:grid-cols-2">{matches.map((match) => <MatchCard key={match.id} match={match} showLeague={false} />)}</div> : <p className="rounded-xl border border-dashed p-5 text-center text-sm text-muted-foreground">Nessuna partita.</p>}</section>;
}

function EmptyMatches({ canCreate, createHref }: { canCreate: boolean; createHref: string }) {
  return <Card className="border-dashed"><CardContent className="py-12 text-center"><div className="mx-auto grid size-12 place-items-center rounded-2xl bg-primary/10 text-primary"><CalendarPlus className="size-5" /></div><h2 className="mt-4 font-bold">Nessuna partita in programma</h2><p className="mx-auto mt-2 max-w-sm text-sm text-muted-foreground">{canCreate ? "Organizza la prima partita della lega." : "Gli admin non hanno ancora organizzato una partita."}</p>{canCreate ? <Button asChild className="mt-5"><Link href={createHref}>Crea la prima partita</Link></Button> : null}</CardContent></Card>;
}
