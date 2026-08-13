"use client";

import Link from "next/link";
import { CalendarDays, MapPin, UsersRound } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/utils";

import { matchShortDate, matchStatusLabel, matchTimeLabel } from "./format";
import type { MatchSummary } from "./types";

export function MatchCard({ match, showLeague = true }: { match: MatchSummary; showLeague?: boolean }) {
  const status = matchStatusLabel(match.status, match.registrationClosedAt);
  return (
    <Link className="block min-w-0" href={`/matches/${match.id}`}>
      <Card className="overflow-hidden transition-colors hover:border-primary/25 hover:bg-card/80">
        <CardContent className="flex min-w-0 gap-3 sm:gap-4">
          <div className="grid size-14 shrink-0 place-items-center rounded-2xl bg-primary/10 text-center text-primary sm:size-16">
            <div><p className="text-xs font-bold uppercase">{matchShortDate(match.startsAt)}</p><p className="mt-0.5 text-lg font-black">{matchTimeLabel(match.startsAt)}</p></div>
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex items-start justify-between gap-2"><div className="min-w-0"><h3 className="truncate font-bold">{match.title}</h3>{showLeague ? <p className="mt-0.5 truncate text-xs text-muted-foreground">{match.leagueName}</p> : null}</div><Badge className={cn(status === "Aperta" && "bg-primary/12 text-primary", status === "Annullata" && "bg-destructive/12 text-destructive")} variant="secondary">{status}</Badge></div>
            <div className="mt-3 flex min-w-0 flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground"><span className="flex min-w-0 items-center gap-1"><MapPin className="size-3.5 shrink-0" /><span className="truncate">{match.locationName}</span></span><span className="flex items-center gap-1"><UsersRound className="size-3.5" />{match.goingCount}/{match.maxPlayers}</span><span className="flex items-center gap-1"><CalendarDays className="size-3.5" />{match.footballFormat}</span></div>
            {match.currentResponse ? <p className="mt-2 text-xs font-semibold text-primary">{responseLabel(match.currentResponse)}</p> : null}
            {!match.isLeagueMember ? <p className="mt-2 text-xs font-semibold text-primary">Entra nella lega per partecipare →</p> : null}
          </div>
        </CardContent>
      </Card>
    </Link>
  );
}

function responseLabel(response: MatchSummary["currentResponse"]) {
  if (response === "going") return "✓ Partecipi";
  if (response === "waitlist") return "In lista d’attesa";
  if (response === "maybe") return "Forse partecipi";
  return "Non partecipi";
}
