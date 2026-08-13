"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowLeftRight, ChevronLeft, LoaderCircle, Minus, Plus, Scale, Trophy } from "lucide-react";
import { toast } from "sonner";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import type { MatchDetail, MatchParticipantView } from "./types";

type Totals = Record<string, { goals: number; assists: number }>;

export function PostGameManager({ match }: { match: MatchDetail }) {
  const router = useRouter();
  const confirmed = useMemo(() => match.participants.filter((player) => player.response === "going"), [match.participants]);
  const savedA = match.postGame?.teams.find((team) => team.teamNumber === 1)?.playerIds;
  const [teamA, setTeamA] = useState<string[]>(() => savedA ?? preMatchTeamA(match, confirmed));
  const [scoreA, setScoreA] = useState(match.postGame?.teamAScore ?? 0);
  const [scoreB, setScoreB] = useState(match.postGame?.teamBScore ?? 0);
  const [pending, setPending] = useState(false);
  const [totals, setTotals] = useState<Totals>(() => Object.fromEntries(confirmed.map((player) => {
    const stats = match.postGame?.playerStats.find((row) => row.userId === player.userId);
    return [player.userId, { goals: stats?.goals ?? 0, assists: stats?.assists ?? 0 }];
  })));
  const teamB = confirmed.filter((player) => !teamA.includes(player.userId)).map((player) => player.userId);

  function balanceTeams() {
    const sorted = [...confirmed].sort((a, b) => b.overall - a.overall);
    const a: string[] = [];
    const b: string[] = [];
    let totalA = 0;
    let totalB = 0;
    sorted.forEach((player) => {
      if (totalA <= totalB) { a.push(player.userId); totalA += player.overall; }
      else { b.push(player.userId); totalB += player.overall; }
    });
    if (!b.length && a.length > 1) b.push(a.pop()!);
    setTeamA(a);
    toast.success(`Squadre bilanciate: OVR medio ${average(a, confirmed)} / ${average(b, confirmed)}`);
  }

  function move(userId: string) {
    setTeamA((current) => current.includes(userId) ? current.filter((id) => id !== userId) : [...current, userId]);
  }

  function change(userId: string, field: "goals" | "assists", delta: number) {
    setTotals((current) => ({ ...current, [userId]: { ...current[userId], [field]: Math.max(0, current[userId][field] + delta) } }));
  }

  async function submit() {
    if (!teamA.length || !teamB.length) return toast.error("Assegna almeno un giocatore a ogni squadra.");
    setPending(true);
    const response = await fetch(`/api/matches/${match.id}/result`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        team_a_players: teamA,
        team_b_players: teamB,
        score_a: scoreA,
        score_b: scoreB,
        player_totals: confirmed.map((player) => ({ user_id: player.userId, ...totals[player.userId] })),
      }),
    });
    const result = await response.json() as { message?: string };
    setPending(false);
    if (!response.ok) return toast.error(result.message ?? "Risultato non salvato.");
    toast.success(match.postGame ? "Risultato ricalcolato." : "Partita completata.");
    router.push(`/matches/${match.id}`);
    router.refresh();
  }

  if (confirmed.length < 2) return <main className="py-6"><Button asChild variant="ghost"><Link href={`/matches/${match.id}`}><ChevronLeft />Partita</Link></Button><Card className="mt-5 border-dashed"><CardContent className="py-10 text-center"><p className="font-bold">Servono almeno due partecipanti confermati</p><p className="mt-2 text-sm text-muted-foreground">Conferma gli RSVP prima di chiudere la partita.</p></CardContent></Card></main>;

  return <main className="py-6 sm:py-9">
    <Button asChild className="-ms-2" variant="ghost"><Link href={`/matches/${match.id}`}><ChevronLeft />Partita</Link></Button>
    <div className="mt-4 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between"><div><p className="text-xs font-bold tracking-[.16em] text-primary uppercase">Post partita</p><h1 className="mt-2 text-3xl font-black">{match.postGame ? "Modifica risultato" : "Chiudi la partita"}</h1><p className="mt-2 text-sm text-muted-foreground">Assegna squadre, punteggio, goal e assist.</p></div><Button onClick={balanceTeams} variant="outline"><Scale />Bilancia squadre</Button></div>
    <section className="mt-7 grid gap-4 md:grid-cols-2">
      <TeamCard name="Team A" players={confirmed.filter((p) => teamA.includes(p.userId))} onMove={move} average={average(teamA, confirmed)} />
      <TeamCard name="Team B" players={confirmed.filter((p) => teamB.includes(p.userId))} onMove={move} average={average(teamB, confirmed)} />
    </section>
    <Card className="mt-5 border-primary/25"><CardHeader><CardTitle>Risultato finale</CardTitle></CardHeader><CardContent><div className="mx-auto grid max-w-md grid-cols-[1fr_auto_1fr] items-center gap-4"><ScoreInput label="Team A" value={scoreA} onChange={setScoreA} /><span className="pt-6 text-3xl font-black text-muted-foreground">–</span><ScoreInput label="Team B" value={scoreB} onChange={setScoreB} /></div></CardContent></Card>
    <Card className="mt-5"><CardHeader><CardTitle>Goal e assist</CardTitle></CardHeader><CardContent className="space-y-3">{confirmed.map((player) => <div className="grid grid-cols-[1fr_auto] gap-3 rounded-2xl border bg-muted/20 p-3 sm:grid-cols-[1fr_auto_auto] sm:items-center" key={player.userId}><Player player={player} /><Counter label="Gol" value={totals[player.userId].goals} onChange={(delta) => change(player.userId, "goals", delta)} /><Counter label="Assist" value={totals[player.userId].assists} onChange={(delta) => change(player.userId, "assists", delta)} /></div>)}</CardContent></Card>
    <Card className="mt-5 border-primary/25 bg-primary/5"><CardContent className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between"><div><p className="font-bold">{match.postGame ? "Ricalcola tutti i dati" : "Completa e aggiorna le statistiche"}</p><p className="mt-1 text-xs leading-5 text-muted-foreground">L’operazione aggiorna in un’unica transazione risultato, classifiche, rating e overall.</p></div><Button disabled={pending} onClick={submit} size="lg">{pending ? <LoaderCircle className="animate-spin" /> : <Trophy />}{match.postGame ? "Salva correzione" : "Chiudi partita"}</Button></CardContent></Card>
  </main>;
}

function TeamCard({ name, players, onMove, average: ovr }: { name: string; players: MatchParticipantView[]; onMove: (id: string) => void; average: number }) { return <Card><CardHeader><div className="flex items-center justify-between"><CardTitle>{name} · {players.length}</CardTitle><Badge variant="outline">OVR {ovr}</Badge></div></CardHeader><CardContent className="space-y-2">{players.map((player) => <button className="flex w-full items-center gap-3 rounded-xl bg-muted/40 p-2 text-start transition hover:bg-muted" key={player.userId} onClick={() => onMove(player.userId)} type="button"><Player player={player} /><ArrowLeftRight className="ms-auto size-4 text-primary" /></button>)}</CardContent></Card>; }
function Player({ player }: { player: MatchParticipantView }) { return <div className="flex min-w-0 items-center gap-3"><Avatar className="size-9"><AvatarImage src={player.avatarUrl ?? undefined} /><AvatarFallback>{player.username.slice(0, 2).toUpperCase()}</AvatarFallback></Avatar><div className="min-w-0"><p className="truncate font-semibold">{[player.firstName, player.lastName].filter(Boolean).join(" ") || `@${player.username}`}</p><p className="text-xs text-muted-foreground">OVR {Math.round(player.overall)}</p></div></div>; }
function ScoreInput({ label, value, onChange }: { label: string; value: number; onChange: (value: number) => void }) { return <label className="text-center"><span className="text-xs font-bold uppercase text-muted-foreground">{label}</span><Input className="mt-2 h-20 text-center text-4xl font-black" max={99} min={0} onChange={(event) => onChange(Number(event.target.value))} type="number" value={value} /></label>; }
function Counter({ label, value, onChange }: { label: string; value: number; onChange: (delta: number) => void }) { return <div className="col-span-2 flex items-center justify-between gap-2 rounded-xl bg-background/60 p-1 sm:col-span-1"><span className="ps-2 text-xs font-bold uppercase text-muted-foreground sm:hidden">{label}</span><Button aria-label={`Riduci ${label}`} onClick={() => onChange(-1)} size="icon-sm" type="button" variant="ghost"><Minus /></Button><div className="min-w-10 text-center"><p className="text-lg font-black">{value}</p><p className="hidden text-[9px] text-muted-foreground uppercase sm:block">{label}</p></div><Button aria-label={`Aumenta ${label}`} onClick={() => onChange(1)} size="icon-sm" type="button" variant="ghost"><Plus /></Button></div>; }
function average(ids: string[], players: MatchParticipantView[]) { return ids.length ? Math.round(ids.reduce((sum, id) => sum + (players.find((player) => player.userId === id)?.overall ?? 70), 0) / ids.length) : 0; }
function preMatchTeamA(match: MatchDetail, confirmed: MatchParticipantView[]) {
  const assignedA = match.lineup.players.filter((player) => player.teamNumber === 1).map((player) => player.userId);
  const assigned = new Set(match.lineup.players.map((player) => player.userId));
  if (!assigned.size) return confirmed.filter((_, index) => index % 2 === 0).map((player) => player.userId);
  const teamA = [...assignedA];
  let teamBSize = match.lineup.players.filter((player) => player.teamNumber === 2).length;
  confirmed.filter((player) => !assigned.has(player.userId)).forEach((player) => {
    if (teamA.length <= teamBSize) teamA.push(player.userId);
    else teamBSize += 1;
  });
  return teamA;
}
