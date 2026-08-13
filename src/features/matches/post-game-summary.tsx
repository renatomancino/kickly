"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Clock3, Medal, Target, Trophy } from "lucide-react";
import { toast } from "sonner";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { MatchDetail, MatchParticipantView } from "./types";

export function PostGameSummary({ match }: { match: MatchDetail }) {
  const router = useRouter();
  const postGame = match.postGame;
  const [pending, setPending] = useState(false);
  const [referenceTime] = useState(() => Date.now());
  const canManage = match.currentUserRole === "owner" || match.currentUserRole === "admin";
  const votingOpen = postGame ? new Date(postGame.mvpVotingEndsAt).getTime() > referenceTime : false;
  const ownStats = postGame?.playerStats.find((stats) => stats.userId === match.currentUserId);

  useEffect(() => {
    if (!postGame || votingOpen || postGame.mvpFinalizedAt) return;
    void fetch(`/api/matches/${match.id}/mvp`, { method: "PUT" }).then((response) => { if (response.ok) router.refresh(); });
  }, [match.id, postGame, router, votingOpen]);

  if (!postGame) return null;
  const mvpStats = postGame.playerStats.find((stats) => stats.isMvp);
  const mvp = mvpStats ? player(match, mvpStats.userId) : null;

  async function vote(userId: string) {
    setPending(true);
    const response = await fetch(`/api/matches/${match.id}/mvp`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ player_id: userId }) });
    const result = await response.json() as { message?: string };
    setPending(false);
    if (!response.ok) return toast.error(result.message ?? "Voto non salvato.");
    toast.success("Voto MVP registrato.");
    router.refresh();
  }

  return <section className="mt-5 space-y-5">
    <Card className="relative overflow-hidden border-primary/35 bg-[radial-gradient(circle_at_top,color-mix(in_oklch,var(--primary)_14%,transparent),transparent_55%)]"><CardContent className="py-8 text-center"><p className="text-xs font-bold tracking-[.2em] text-primary uppercase">Risultato finale</p><div className="mt-5 grid grid-cols-[1fr_auto_1fr] items-center gap-3"><TeamName name="Team A" /><p className="text-5xl font-black tabular-nums sm:text-7xl">{postGame.teamAScore}<span className="mx-3 text-muted-foreground">–</span>{postGame.teamBScore}</p><TeamName name="Team B" /></div>{ownStats ? <div className="mt-6 flex flex-wrap justify-center gap-2"><Badge variant="secondary">{ownStats.result === "win" ? "Vittoria" : ownStats.result === "draw" ? "Pareggio" : "Sconfitta"}</Badge><Badge variant="outline">{ownStats.goals} gol</Badge><Badge variant="outline">{ownStats.assists} assist</Badge><Badge className="bg-primary/12 text-primary">Rating {ownStats.matchRating?.toFixed(1) ?? "–"}</Badge></div> : null}</CardContent></Card>
    <div className="grid gap-4 md:grid-cols-2">{postGame.teams.map((team) => <Card key={team.id}><CardHeader><CardTitle>{team.name}</CardTitle></CardHeader><CardContent className="space-y-2">{team.playerIds.map((id) => { const member = player(match, id); const stats = postGame.playerStats.find((row) => row.userId === id); return member && stats ? <PlayerLine key={id} player={member} stats={stats} /> : null; })}</CardContent></Card>)}</div>
    <Card className={mvp ? "border-amber-400/30 bg-amber-400/5" : "border-primary/20"}><CardHeader><CardTitle className="flex items-center gap-2"><Trophy className="text-amber-400" />MVP della partita</CardTitle></CardHeader><CardContent>{mvp && mvpStats ? <div className="flex items-center gap-4"><Avatar className="size-14 ring-2 ring-amber-400/30"><AvatarImage src={mvp.avatarUrl ?? undefined} /><AvatarFallback>{mvp.username.slice(0, 2).toUpperCase()}</AvatarFallback></Avatar><div><p className="text-xl font-black">{name(mvp)}</p><p className="text-sm text-muted-foreground">{mvpStats.goals} gol · {mvpStats.assists} assist · {postGame.mvpVotes ?? 0} voti</p></div><Medal className="ms-auto size-8 text-amber-400" /></div> : votingOpen ? <div><p className="flex items-center gap-2 text-sm text-muted-foreground"><Clock3 className="size-4 text-primary" />Votazioni aperte ancora per {timeLeft(postGame.mvpVotingEndsAt, referenceTime)}</p>{postGame.ownVotePlayerId ? <p className="mt-4 rounded-xl bg-primary/10 p-3 text-center font-bold text-primary">Hai votato · risultato nascosto fino alla scadenza</p> : ownStats ? <div className="mt-4 grid gap-2 sm:grid-cols-2">{postGame.playerStats.filter((stats) => stats.userId !== match.currentUserId).map((stats) => { const candidate = player(match, stats.userId); return candidate ? <Button className="h-auto justify-start py-3" disabled={pending} key={stats.userId} onClick={() => vote(stats.userId)} variant="outline"><Avatar className="size-8"><AvatarImage src={candidate.avatarUrl ?? undefined} /><AvatarFallback>{candidate.username.slice(0, 2)}</AvatarFallback></Avatar>Vota {name(candidate)}</Button> : null; })}</div> : <p className="mt-3 text-sm text-muted-foreground">Solo chi ha partecipato può votare.</p>}</div> : <p className="text-sm text-muted-foreground">Calcolo MVP in corso…</p>}</CardContent></Card>
    {canManage ? <Button asChild className="w-full" variant="outline"><Link href={`/matches/${match.id}/manage-result`}>Modifica risultato e ricalcola</Link></Button> : null}
  </section>;
}

function PlayerLine({ player: member, stats }: { player: MatchParticipantView; stats: NonNullable<MatchDetail["postGame"]>["playerStats"][number] }) { return <Link className="flex items-center gap-3 rounded-xl bg-muted/35 p-3 transition hover:bg-muted/60" href={`/player/${member.username}`}><Avatar className="size-9"><AvatarImage src={member.avatarUrl ?? undefined} /><AvatarFallback>{member.username.slice(0, 2)}</AvatarFallback></Avatar><div className="min-w-0 flex-1"><p className="truncate font-semibold">{name(member)}</p><p className="text-xs text-muted-foreground">OVR {stats.previousOverall ?? member.overall} → {stats.newOverall ?? member.overall}</p></div><div className="text-end"><p className="font-black text-primary">{stats.matchRating?.toFixed(1) ?? "–"}</p><p className="flex gap-2 text-xs text-muted-foreground"><span>{stats.goals} ⚽</span><span>{stats.assists} 🎯</span></p></div></Link>; }
function TeamName({ name: value }: { name: string }) { return <div className="hidden sm:block"><Target className="mx-auto size-6 text-primary" /><p className="mt-2 font-black uppercase">{value}</p></div>; }
function player(match: MatchDetail, id: string) { return match.participants.find((participant) => participant.userId === id); }
function name(member: MatchParticipantView) { return [member.firstName, member.lastName].filter(Boolean).join(" ") || `@${member.username}`; }
function timeLeft(value: string, referenceTime: number) { const hours = Math.max(1, Math.ceil((new Date(value).getTime() - referenceTime) / 3_600_000)); return `${hours}h`; }
