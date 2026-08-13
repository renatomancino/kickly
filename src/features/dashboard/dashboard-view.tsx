import Link from "next/link";
import {
  CalendarDays,
  ChevronRight,
  Clock3,
  MapPin,
  Sparkles,
  Trophy,
  UsersRound,
} from "lucide-react";

import { BrandMark } from "@/components/brand-mark";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { LeagueLogo } from "@/features/leagues/league-logo";
import type { DashboardData, DashboardMatch } from "./types";
import { NotificationBell } from "@/features/notifications/notification-bell";

export function DashboardView({ data }: { data: DashboardData }) {
  return (
    <main className="py-5 sm:py-8">
      <header className="mb-7 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <BrandMark className="size-10" />
          <div>
            <p className="text-xs text-muted-foreground">Bentornato,</p>
            <h1 className="font-bold">{data.firstName}</h1>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {data.source === "demo" ? <Badge variant="outline" className="hidden border-primary/25 text-primary sm:inline-flex">Demo locale</Badge> : null}
          <NotificationBell unread={data.unreadNotifications} />
        </div>
      </header>

      <section aria-labelledby="next-match-heading">
        <div className="mb-3 flex items-center justify-between">
          <div>
            <p className="text-xs font-semibold tracking-[0.18em] text-primary uppercase">Next up</p>
            <h2 className="mt-1 text-xl font-bold" id="next-match-heading">Prossima partita</h2>
          </div>
          <CalendarDays className="size-5 text-muted-foreground" />
        </div>
        {data.nextMatch ? <NextMatchCard match={data.nextMatch} timezone={data.timezone} /> : <EmptyNextMatch />}
      </section>

      {data.lastMatch ? <section className="mt-5"><Card className="border-primary/20"><CardContent className="flex flex-col gap-4 sm:flex-row sm:items-center"><div className="flex-1"><p className="text-xs font-bold tracking-wider text-primary uppercase">Ultima partita</p><h2 className="mt-1 text-lg font-bold">{data.lastMatch.title}</h2><p className="text-xs text-muted-foreground">{data.lastMatch.leagueName}</p></div><p className="text-4xl font-black tabular-nums">{data.lastMatch.teamAScore} – {data.lastMatch.teamBScore}</p><div className="flex flex-wrap gap-2"><Badge variant="secondary">{data.lastMatch.result === "win" ? "W" : data.lastMatch.result === "draw" ? "D" : "L"}</Badge><Badge variant="outline">{data.lastMatch.goals} ⚽</Badge><Badge variant="outline">{data.lastMatch.assists} 🎯</Badge><Badge className="bg-primary/12 text-primary">{data.lastMatch.rating?.toFixed(1) ?? "–"}</Badge>{data.lastMatch.isMvp ? <Badge className="bg-amber-400/15 text-amber-300">MVP</Badge> : null}</div><Button asChild size="sm" variant="outline"><Link href={`/matches/${data.lastMatch.id}`}>Riepilogo</Link></Button></CardContent></Card></section> : null}

      <section className="mt-9" aria-labelledby="quick-stats-heading">
        <SectionHeading title="Il tuo momento" eyebrow="Statistiche rapide" id="quick-stats-heading" />
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
          <StatCard label="Partite" value={data.stats.matches} />
          <StatCard label="Goal" value={data.stats.goals} />
          <StatCard label="Assist" value={data.stats.assists} />
          <StatCard label="MVP" value={data.stats.mvp} icon={<Trophy className="size-4" />} />
          <Card className="col-span-2 min-h-28 border-primary/15 bg-primary text-primary-foreground sm:col-span-1">
            <CardContent className="flex h-full items-end justify-between">
              <div><p className="text-xs font-bold opacity-70">OVERALL</p><p className="mt-1 text-4xl font-black tabular-nums">{Math.round(data.stats.overall)}</p></div>
              <Sparkles className="size-5 opacity-70" />
            </CardContent>
          </Card>
        </div>
      </section>

      <section className="mt-9 scroll-mt-6" id="leagues" aria-labelledby="leagues-heading">
        <div className="mb-4 flex items-end justify-between"><SectionHeading compact title="Le mie leghe" eyebrow={`${data.leagues.length} attive`} id="leagues-heading" /><Button asChild size="sm" variant="ghost"><Link href="/leagues">Vedi tutte <ChevronRight /></Link></Button></div>
        <div className="grid gap-3 md:grid-cols-2">
          {data.leagues.length ? data.leagues.map((league) => (
            <Link href={`/leagues/${league.slug}`} key={league.id}>
            <Card className="h-full transition-colors hover:border-primary/20 hover:bg-card/80">
              <CardContent className="flex items-center gap-4">
                <LeagueLogo className="size-12 rounded-2xl" name={league.name} url={league.logoUrl} />
                <div className="min-w-0 flex-1">
                  <h3 className="truncate font-semibold">{league.name}</h3>
                  <div className="mt-1 flex gap-3 text-xs text-muted-foreground"><span className="flex items-center gap-1"><MapPin className="size-3" />{league.city}</span><span className="flex items-center gap-1"><UsersRound className="size-3" />{league.members || "—"} membri</span></div>
                </div>
                <ChevronRight className="size-5 text-muted-foreground" />
              </CardContent>
            </Card>
            </Link>
          )) : <Card className="border-dashed"><CardContent className="py-8 text-center"><p className="font-semibold">Nessuna lega</p><p className="mx-auto mt-2 max-w-sm text-sm text-muted-foreground">Crea il tuo gruppo oppure entra con un codice.</p><div className="mt-5 flex justify-center gap-2"><Button asChild size="sm"><Link href="/leagues/new">Crea la tua prima lega</Link></Button><Button asChild size="sm" variant="outline"><Link href="/leagues/join">Entra con un codice</Link></Button></div></CardContent></Card>}
        </div>
      </section>

      <section className="mt-9 scroll-mt-6" id="upcoming" aria-labelledby="upcoming-heading">
        <div className="mb-4 flex items-end justify-between">
          <SectionHeading title="In programma" eyebrow="Le tue prossime partite" id="upcoming-heading" compact />
          <Button asChild size="sm" variant="ghost"><Link href="/matches">Vedi tutte <ChevronRight /></Link></Button>
        </div>
        <div className="grid gap-3 md:grid-cols-2">
          {data.nearby.length ? data.nearby.map((match) => <NearbyMatchCard key={match.id} match={match} timezone={data.timezone} />) : <EmptyCard title="Nessun altro appuntamento" body="Le nuove partite delle tue leghe compariranno qui." />}
        </div>
      </section>
    </main>
  );
}

function NextMatchCard({ match, timezone }: { match: DashboardMatch; timezone: string }) {
  const percent = Math.min(100, (match.going / match.maxPlayers) * 100);
  return (
    <Card className="relative overflow-hidden border-primary/20 bg-[linear-gradient(135deg,color-mix(in_oklch,var(--card)_100%,transparent),color-mix(in_oklch,var(--primary)_8%,var(--card)))] py-0">
      <div aria-hidden className="absolute -end-16 -top-20 size-52 rounded-full bg-primary/10 blur-3xl" />
      <CardContent className="relative p-5 sm:p-7">
        <div className="flex items-start justify-between gap-3">
          <div><Badge className="bg-primary/12 text-primary">{match.format.replace("v", " vs ")}</Badge><p className="mt-4 text-xs font-medium text-muted-foreground">{match.leagueName}</p><h3 className="mt-1 text-2xl font-bold tracking-tight">{match.title}</h3></div>
          {match.participation === "going" ? <Badge variant="outline" className="border-primary/30 text-primary"><span className="size-1.5 rounded-full bg-primary" /> Confermato</Badge> : null}
        </div>
        <div className="mt-5 grid gap-2 text-sm text-muted-foreground sm:grid-cols-2">
          <p className="flex items-center gap-2"><Clock3 className="size-4 text-primary" />{formatDashboardDate(match.startsAt, timezone)}</p>
          <p className="flex items-center gap-2"><MapPin className="size-4 text-primary" />{match.venueName}</p>
        </div>
        <div className="mt-6 rounded-xl border bg-background/40 p-4">
          <div className="mb-2 flex items-center justify-between text-xs"><span className="font-semibold">{match.going} / {match.maxPlayers} giocatori</span><span className="text-muted-foreground">{match.maxPlayers - match.going} posti</span></div>
          <Progress value={percent} />
        </div>
        <Button asChild className="mt-5 h-11 w-full rounded-xl font-bold"><Link href={`/matches/${match.id}`}>Visualizza partita</Link></Button>
      </CardContent>
    </Card>
  );
}

function NearbyMatchCard({ match, timezone }: { match: DashboardMatch; timezone: string }) {
  return (
    <Card>
      <CardContent>
        <div className="flex items-start justify-between gap-3"><div><Badge variant="outline">{match.format.replace("v", " vs ")}</Badge><h3 className="mt-3 font-semibold">{match.title}</h3><p className="mt-1 text-xs text-muted-foreground">{match.leagueName}</p></div>{match.distanceKm ? <span className="text-xs font-semibold text-primary">{match.distanceKm} km</span> : null}</div>
        <div className="mt-4 flex flex-wrap gap-x-4 gap-y-2 text-xs text-muted-foreground"><span className="flex items-center gap-1.5"><Clock3 className="size-3.5" />{formatDashboardDate(match.startsAt, timezone)}</span><span className="flex items-center gap-1.5"><UsersRound className="size-3.5" />{match.going}/{match.maxPlayers}</span></div>
        <Button asChild className="mt-4 h-9 w-full" variant="secondary"><Link href={`/matches/${match.id}`}>Vedi partita</Link></Button>
      </CardContent>
    </Card>
  );
}

function StatCard({ label, value, icon }: { label: string; value: number; icon?: React.ReactNode }) {
  return <Card className="min-h-28"><CardContent className="flex h-full items-end justify-between"><div><p className="text-xs text-muted-foreground">{label}</p><p className="mt-1 text-3xl font-bold tabular-nums">{value}</p></div><span className="text-primary">{icon}</span></CardContent></Card>;
}

function SectionHeading({ title, eyebrow, id, compact = false }: { title: string; eyebrow: string; id: string; compact?: boolean }) {
  return <div className={compact ? "" : "mb-4"}><p className="text-xs font-semibold tracking-[0.14em] text-muted-foreground uppercase">{eyebrow}</p><h2 className="mt-1 text-xl font-bold" id={id}>{title}</h2></div>;
}

function EmptyNextMatch() {
  return <EmptyCard title="Il calendario è libero" body="Quando un admin crea una partita, la troverai subito qui." />;
}

function EmptyCard({ title, body }: { title: string; body: string }) {
  return <Card className="border-dashed"><CardContent className="py-8 text-center"><p className="font-semibold">{title}</p><p className="mx-auto mt-2 max-w-sm text-sm text-muted-foreground">{body}</p></CardContent></Card>;
}

function formatDashboardDate(value: string, timezone: string) {
  return new Intl.DateTimeFormat("it-IT", { weekday: "short", day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit", timeZone: timezone }).format(new Date(value));
}
