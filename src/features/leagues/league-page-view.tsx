"use client";

import Link from "next/link";
import {
  BarChart3,
  CalendarPlus,
  ChevronLeft,
  LockKeyhole,
  MapPin,
  Megaphone,
  Shield,
  UsersRound,
} from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

import { InviteDialog } from "./invite-dialog";
import { LeagueCommunications } from "./league-communications";
import { LeagueLogo } from "./league-logo";
import { LeagueRealtimeSync } from "./league-realtime-sync";
import { LeagueSettings } from "./league-settings";
import { MembersList } from "./members-list";
import { RoleBadge } from "./role-badge";
import type { LeagueCommunication, LeagueDetail } from "./types";
import { LeagueMatches } from "@/features/matches/match-list";
import type { MatchSummary } from "@/features/matches/types";
import { LeagueLeaderboardsView } from "@/features/stats/league-leaderboards";
import type { LeagueLeaderboards } from "@/features/stats/types";

export function LeaguePageView({ league, currentUserId, matches, leaderboards, communications, initialTab }: { league: LeagueDetail; currentUserId: string; matches: MatchSummary[]; leaderboards: LeagueLeaderboards; communications: LeagueCommunication[]; initialTab: "home" | "communications" }) {
  const admins = league.members.filter((member) => member.leagueRole === "admin");
  const owner = league.members.find((member) => member.leagueRole === "owner");
  const canManage = league.currentUserRole === "owner" || league.currentUserRole === "admin";

  return (
    <main className="py-5 sm:py-9">
      <LeagueRealtimeSync leagueId={league.id} matchIds={matches.map((match) => match.id)} />
      <Button asChild className="-ms-2 mb-5" variant="ghost"><Link href="/leagues"><ChevronLeft />Le mie leghe</Link></Button>
      <header className="relative overflow-hidden rounded-3xl border bg-card p-5 sm:p-8">
        <div aria-hidden className="absolute -end-20 -top-24 size-72 rounded-full bg-primary/8 blur-3xl" />
        <div className="relative flex flex-col gap-6 sm:flex-row sm:items-center">
          <LeagueLogo className="size-24 rounded-3xl ring-1 ring-white/10" name={league.name} url={league.logoUrl} />
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2"><Badge variant="secondary">{league.footballFormat.replace("v", " vs ")}</Badge><Badge variant="outline">{league.visibility === "private" ? <LockKeyhole /> : <Shield />}{league.visibility === "private" ? "Privata" : "Pubblica"}</Badge><RoleBadge role={league.currentUserRole} /></div>
            <h1 className="mt-3 break-words text-3xl font-black tracking-tight sm:text-4xl">{league.name}</h1>
            <div className="mt-3 flex flex-wrap gap-x-5 gap-y-2 text-sm text-muted-foreground"><span className="flex items-center gap-1.5"><MapPin className="size-4 text-primary" />{league.city}, {league.country}</span><span className="flex items-center gap-1.5"><UsersRound className="size-4 text-primary" />{league.memberCount}/{league.maxMembers} membri</span></div>
          </div>
          {canManage ? <InviteDialog footballFormat={league.footballFormat} initialCode={league.inviteCode} leagueId={league.id} leagueName={league.name} role={league.currentUserRole} /> : null}
        </div>
      </header>

      <Tabs className="mt-7" defaultValue={initialTab}>
        <TabsList aria-label="Sezioni della lega" className="flex h-auto! w-full justify-start gap-1 overflow-x-auto p-1"><TabsTrigger className="h-9 shrink-0 text-xs sm:text-sm" value="home">Home</TabsTrigger><TabsTrigger className="h-9 shrink-0 text-xs sm:text-sm" value="communications"><Megaphone />Comunicazioni</TabsTrigger><TabsTrigger className="h-9 shrink-0 text-xs sm:text-sm" value="matches">Partite</TabsTrigger><TabsTrigger className="h-9 shrink-0 text-xs sm:text-sm" value="rankings">Classifiche</TabsTrigger><TabsTrigger className="h-9 shrink-0 text-xs sm:text-sm" value="players">Giocatori</TabsTrigger><TabsTrigger className="h-9 shrink-0 text-xs sm:text-sm" value="stats">Statistiche</TabsTrigger><TabsTrigger className="h-9 shrink-0 text-xs sm:text-sm" value="info">Info</TabsTrigger></TabsList>

        <TabsContent className="mt-6" value="home">
          <div className="grid gap-4 lg:grid-cols-[1.35fr_.65fr]">
            <Card><CardHeader><CardTitle>Dentro la lega</CardTitle></CardHeader><CardContent><p className="text-sm leading-6 text-muted-foreground">{league.description || "Una lega Kickly pronta per vivere nuove partite e rivalità."}</p><Separator className="my-5" /><div className="grid grid-cols-3 gap-3"><Metric label="Membri" value={league.memberCount} /><Metric label="Admin" value={admins.length} /><Metric label="Formato" value={league.footballFormat} /></div></CardContent></Card>
            <Card><CardHeader><CardTitle>Gestione</CardTitle></CardHeader><CardContent><p className="text-xs text-muted-foreground">Owner</p><p className="mt-1 font-semibold">{owner ? displayName(owner) : "—"}</p><p className="mt-5 text-xs text-muted-foreground">Admin</p><p className="mt-1 text-sm">{admins.length ? admins.map(displayName).join(", ") : "Nessun admin"}</p></CardContent></Card>
            <div className="lg:col-span-2"><div className="mb-4 flex items-center justify-between"><h2 className="text-lg font-bold">Leader della lega</h2><Button onClick={() => document.querySelector<HTMLButtonElement>('[data-value=rankings]')?.click()} size="sm" variant="ghost">Vedi classifiche</Button></div><LeagueLeaderboardsView boards={leaderboards} preview /></div>
          </div>
        </TabsContent>
        <TabsContent className="mt-6" value="communications"><LeagueCommunications canManage={canManage} communications={communications} leagueId={league.id} /></TabsContent>
        <TabsContent className="mt-6 min-w-0" value="matches"><div className="mb-4 flex flex-col items-stretch gap-3 sm:flex-row sm:items-end sm:justify-between"><div><h2 className="text-xl font-bold">Partite</h2><p className="mt-1 text-sm text-muted-foreground">Prossime e passate della lega.</p></div>{canManage ? <Button asChild size="sm"><Link href={`/matches/new?league=${league.id}`}><CalendarPlus />Crea partita</Link></Button> : null}</div><LeagueMatches canCreate={canManage} leagueId={league.id} matches={matches} /></TabsContent>
        <TabsContent className="mt-6" value="rankings"><LeagueLeaderboardsView boards={leaderboards} /></TabsContent>
        <TabsContent className="mt-6" value="players"><div className="mb-4"><h2 className="text-xl font-bold">Giocatori</h2><p className="mt-1 text-sm text-muted-foreground">{league.memberCount} membri attivi</p></div><MembersList currentUserId={currentUserId} currentUserRole={league.currentUserRole} initialMembers={league.members} leagueId={league.id} /></TabsContent>
        <TabsContent className="mt-6" value="stats"><FeatureEmpty icon={<BarChart3 />} title="Statistiche non disponibili" body="Saranno calcolate automaticamente dopo le prime partite concluse." /></TabsContent>
        <TabsContent className="mt-6" value="info"><Card><CardHeader><CardTitle>Informazioni lega</CardTitle></CardHeader><CardContent className="space-y-5"><InfoRow label="Città" value={`${league.city}, ${league.country}`} /><InfoRow label="Formato" value={league.footballFormat.replace("v", " vs ")} /><InfoRow label="Visibilità" value={league.visibility === "private" ? "Privata · accesso con invito" : "Pubblica"} /><InfoRow label="Capienza" value={`${league.memberCount} di ${league.maxMembers} membri`} /><Separator /><LeagueSettings league={league} />{league.currentUserRole === "owner" ? <p className="text-xs leading-5 text-muted-foreground">Per lasciare la lega devi prima trasferire la proprietà a un altro membro oppure eliminare la lega.</p> : null}</CardContent></Card></TabsContent>
      </Tabs>
    </main>
  );
}

function Metric({ label, value }: { label: string; value: string | number }) { return <div className="rounded-xl bg-muted/40 p-3"><p className="text-xl font-black">{value}</p><p className="mt-1 text-[10px] text-muted-foreground uppercase">{label}</p></div>; }
function InfoRow({ label, value }: { label: string; value: string }) { return <div className="flex items-start justify-between gap-4 text-sm"><span className="text-muted-foreground">{label}</span><span className="text-end font-medium">{value}</span></div>; }
function FeatureEmpty({ icon, title, body }: { icon: React.ReactNode; title: string; body: string }) { return <Card className="border-dashed"><CardContent className="py-12 text-center"><div className="mx-auto grid size-12 place-items-center rounded-2xl bg-primary/10 text-primary [&_svg]:size-5">{icon}</div><h2 className="mt-4 font-bold">{title}</h2><p className="mx-auto mt-2 max-w-sm text-sm text-muted-foreground">{body}</p></CardContent></Card>; }
function displayName(member: LeagueDetail["members"][number]) { return [member.firstName, member.lastName].filter(Boolean).join(" ") || `@${member.username}`; }
