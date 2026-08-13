"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  CalendarDays,
  ChevronLeft,
  Clock3,
  Coins,
  ExternalLink,
  LockKeyhole,
  MapPin,
  Pencil,
  Trophy,
  UsersRound,
} from "lucide-react";
import { toast } from "sonner";

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { Separator } from "@/components/ui/separator";
import { cn } from "@/lib/utils";
import type { AttendanceStatus, MatchStatus } from "@/types/database";

import { mapsUrl, matchDateLabel, matchStatusLabel, matchTimeLabel } from "./format";
import type { MatchDetail, MatchParticipantView } from "./types";
import { MatchLineupBoard } from "./match-lineup-board";
import { MatchReminderDialog } from "./match-reminder-dialog";
import { PostGameSummary } from "./post-game-summary";

interface RsvpResult {
  actual_response: AttendanceStatus;
  going_count: number;
  waitlist_position: number | null;
  match_status: MatchStatus;
  message?: string;
}

export function MatchDetailView({ match }: { match: MatchDetail }) {
  const router = useRouter();
  const [response, setResponse] = useState(match.currentResponse);
  const [going, setGoing] = useState(match.goingCount);
  const [status, setStatus] = useState(match.status);
  const [closedAt, setClosedAt] = useState(match.registrationClosedAt);
  const [waitlistPosition, setWaitlistPosition] = useState(initialWaitlistPosition(match));
  const [pending, setPending] = useState<AttendanceStatus | "admin" | null>(null);
  const canManage = match.currentUserRole === "owner" || match.currentUserRole === "admin";
  const canRsvp = match.isLeagueMember && (status === "open" || status === "full") && !closedAt;
  const spots = Math.max(0, match.maxPlayers - going);

  async function setRsvp(next: "going" | "maybe" | "not_going") {
    const previous = { response, going, status, waitlistPosition };
    const predictedResponse: AttendanceStatus = next === "going" && response !== "going" && spots === 0
      ? "waitlist"
      : next;
    const wasGoing = response === "going";
    const willBeGoing = predictedResponse === "going";

    setPending(next);
    setResponse(predictedResponse);
    setGoing((current) => Math.max(0, current + Number(willBeGoing) - Number(wasGoing)));
    setWaitlistPosition(predictedResponse === "waitlist" ? waitlistPosition ?? 1 : null);

    try {
      const request = await fetch(`/api/matches/${match.id}/rsvp`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ response: next }),
      });
      const result = (await request.json().catch(() => ({}))) as Partial<RsvpResult>;
      if (!request.ok || !result.actual_response || result.going_count === undefined || !result.match_status) {
        throw new Error(result.message ?? "Risposta non salvata.");
      }
      setResponse(result.actual_response);
      setGoing(Number(result.going_count));
      setStatus(result.match_status);
      setWaitlistPosition(result.waitlist_position ? Number(result.waitlist_position) : null);
      toast.success(result.actual_response === "waitlist" ? "Sei in lista d’attesa." : "Risposta aggiornata.");
      router.refresh();
    } catch (error) {
      setResponse(previous.response);
      setGoing(previous.going);
      setStatus(previous.status);
      setWaitlistPosition(previous.waitlistPosition);
      toast.error(error instanceof Error ? error.message : "Risposta non salvata.");
    } finally {
      setPending(null);
    }
  }

  async function adminAction(action: "cancel" | "close" | "reopen") {
    setPending("admin");
    const request = await fetch(`/api/matches/${match.id}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action }),
    });
    const result = (await request.json()) as { state?: { match_status: MatchStatus; closed_at: string | null }; message?: string };
    setPending(null);
    if (!request.ok || !result.state) {
      toast.error(result.message ?? "Azione non riuscita.");
      return;
    }
    setStatus(result.state.match_status);
    setClosedAt(result.state.closed_at);
    toast.success(action === "cancel" ? "Partita annullata." : action === "close" ? "Iscrizioni chiuse." : "Iscrizioni riaperte.");
    router.refresh();
  }

  async function joinLeagueAndPlay() {
    setPending("going");
    const joinRequest = await fetch("/api/leagues/public-join", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ leagueId: match.leagueId }),
    });
    const joinResult = await joinRequest.json() as { message?: string };
    if (!joinRequest.ok) {
      setPending(null);
      toast.error(joinResult.message ?? "Ingresso nella lega non riuscito.");
      return;
    }
    const rsvpRequest = await fetch(`/api/matches/${match.id}/rsvp`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ response: "going" }),
    });
    const rsvpResult = await rsvpRequest.json() as RsvpResult;
    setPending(null);
    if (!rsvpRequest.ok) {
      toast.success(`Sei entrato in ${match.leagueName}.`);
      toast.error(rsvpResult.message ?? "Ora puoi riprovare a partecipare.");
      router.refresh();
      return;
    }
    setResponse(rsvpResult.actual_response);
    setGoing(Number(rsvpResult.going_count));
    setStatus(rsvpResult.match_status);
    toast.success(rsvpResult.actual_response === "waitlist" ? "Sei entrato nella lega e nella lista d’attesa." : "Sei entrato nella lega e parteciperai alla partita.");
    router.refresh();
  }

  const lists = useMemo(() => ({
    going: match.participants.filter((participant) => participant.response === "going"),
    maybe: match.participants.filter((participant) => participant.response === "maybe"),
    waitlist: match.participants.filter((participant) => participant.response === "waitlist"),
    notGoing: match.participants.filter((participant) => participant.response === "not_going"),
  }), [match.participants]);

  return (
    <main className="py-5 sm:py-8">
      <Button asChild className="-ms-2 mb-4" variant="ghost"><Link href="/matches"><ChevronLeft />Partite</Link></Button>
      <section className="relative overflow-hidden rounded-3xl border bg-card p-5 sm:p-8">
        <div aria-hidden className="absolute -end-20 -top-20 size-64 rounded-full bg-primary/10 blur-3xl" />
        <div className="relative">
          <div className="flex flex-wrap items-center gap-2"><Badge className={cn(status === "open" && !closedAt && "bg-primary/12 text-primary", status === "cancelled" && "bg-destructive/12 text-destructive")} variant="secondary">{matchStatusLabel(status, closedAt)}</Badge><Badge variant="outline">{match.footballFormat.replace("v", " vs ")}</Badge><Link className="text-xs font-semibold text-muted-foreground hover:text-primary" href={`/leagues/${match.leagueSlug}`}>{match.leagueName}</Link></div>
          <h1 className="mt-4 text-3xl font-black tracking-tight sm:text-4xl">{match.title}</h1>
          <div className="mt-6 grid gap-4 sm:grid-cols-2">
            <div className="rounded-2xl border bg-background/40 p-4"><p className="flex items-center gap-2 text-sm font-semibold capitalize"><CalendarDays className="size-4 text-primary" />{matchDateLabel(match.startsAt)}</p><p className="mt-2 flex items-center gap-2 text-2xl font-black"><Clock3 className="size-5 text-primary" />{matchTimeLabel(match.startsAt)}</p></div>
            <div className="rounded-2xl border bg-background/40 p-4"><p className="flex items-center gap-2 font-semibold"><MapPin className="size-4 text-primary" />{match.locationName}</p><p className="mt-2 text-sm text-muted-foreground">{[match.address, match.city].filter(Boolean).join(", ")}</p><a className="mt-3 inline-flex items-center gap-1 text-xs font-bold text-primary" href={mapsUrl(match.locationName, match.address, match.city)} rel="noreferrer" target="_blank">Apri nelle mappe <ExternalLink className="size-3" /></a></div>
          </div>
        </div>
      </section>

      {status === "completed" ? <PostGameSummary match={match} /> : null}
      {match.isLeagueMember && status !== "completed" ? <MatchLineupBoard
        canManage={canManage}
        currentResponse={response}
        currentUserId={match.currentUserId}
        format={match.footballFormat}
        initialLineup={match.lineup}
        matchId={match.id}
        participants={match.participants}
        status={status}
      /> : null}

      <div className="mt-5 grid gap-5 lg:grid-cols-[1.2fr_.8fr]">
        <div className="space-y-5">
          {status !== "completed" ? <Card className="border-primary/15"><CardContent>
            <div className="flex items-end justify-between gap-3"><div><p className="text-xs font-semibold tracking-wider text-muted-foreground uppercase">Disponibilità</p><p className="mt-1 text-2xl font-black">{going} / {match.maxPlayers} <span className="text-base font-semibold text-muted-foreground">confermati</span></p></div><Badge variant="outline">{spots ? `${spots} posti` : "Tutto esaurito"}</Badge></div>
            <Progress className="mt-4" value={Math.min(100, (going / match.maxPlayers) * 100)} />
            {!match.isLeagueMember ? <div className="mt-5 rounded-2xl border border-primary/20 bg-primary/5 p-4"><p className="font-bold">Vuoi partecipare?</p><p className="mt-1 text-sm text-muted-foreground">Per partecipare alla partita devi prima entrare in {match.leagueName}.</p><AlertDialog><AlertDialogTrigger asChild><Button className="mt-4 w-full">Partecipa alla partita</Button></AlertDialogTrigger><AlertDialogContent><AlertDialogHeader><AlertDialogTitle>Entrare in {match.leagueName}?</AlertDialogTitle><AlertDialogDescription>Confermando entrerai nella lega e la tua partecipazione verrà registrata automaticamente.</AlertDialogDescription></AlertDialogHeader><AlertDialogFooter><AlertDialogCancel>No, non ora</AlertDialogCancel><AlertDialogAction disabled={pending !== null} onClick={joinLeagueAndPlay}>Sì, entra e partecipa</AlertDialogAction></AlertDialogFooter></AlertDialogContent></AlertDialog></div> : canRsvp ? <div className="mt-5 grid grid-cols-3 gap-2">
              <RsvpButton active={response === "going" || response === "waitlist"} disabled={pending !== null} label="Partecipo" onClick={() => setRsvp("going")} />
              <RsvpButton active={response === "maybe"} disabled={pending !== null} label="Forse" onClick={() => setRsvp("maybe")} variant="outline" />
              <RsvpButton active={response === "not_going"} disabled={pending !== null} label="Non posso" onClick={() => setRsvp("not_going")} variant="outline" />
            </div> : <div className="mt-5 flex items-center gap-2 rounded-xl bg-muted/50 p-4 text-sm text-muted-foreground"><LockKeyhole className="size-4" />Gli RSVP non sono più modificabili.</div>}
            {response === "waitlist" ? <p className="mt-4 rounded-xl bg-amber-500/10 p-3 text-center text-sm font-bold text-amber-400">Lista d’attesa {waitlistPosition ? `#${waitlistPosition}` : ""}</p> : null}
            {response === "going" ? <p className="mt-4 text-center text-sm font-semibold text-primary">✓ Sei confermato per questa partita</p> : null}
          </CardContent></Card> : null}

          <Card><CardHeader><CardTitle>Giocatori</CardTitle></CardHeader><CardContent className="space-y-6"><ParticipantGroup participants={lists.going} title="Confermati" /><ParticipantGroup participants={lists.maybe} title="Forse" /><ParticipantGroup participants={lists.waitlist} showPosition title="Lista d’attesa" /><details className="group"><summary className="cursor-pointer list-none text-xs font-bold tracking-wider text-muted-foreground uppercase">Non partecipano ({lists.notGoing.length})</summary><div className="mt-3"><ParticipantGroup hideTitle participants={lists.notGoing} title="Non partecipano" /></div></details></CardContent></Card>
        </div>

        <aside className="space-y-5">
          {canManage && status !== "cancelled" && status !== "completed" ? <MatchReminderDialog matchId={match.id} matchTitle={match.title} /> : null}
          <Card><CardHeader><CardTitle>Dettagli</CardTitle></CardHeader><CardContent className="space-y-4 text-sm"><Detail icon={<UsersRound />} label="Formato" value={match.footballFormat.replace("v", " vs ")} /><Detail icon={<MapPin />} label="Città" value={match.city} />{match.costTotal !== null ? <><Detail icon={<Coins />} label="Costo campo" value={`${formatMoney(match.costTotal)} €`} /><Detail icon={<Coins />} label="Circa a giocatore" value={going ? `${formatMoney(match.costTotal / going)} €` : "—"} /></> : null}{match.description ? <><Separator /><div><p className="text-xs text-muted-foreground">Note</p><p className="mt-2 leading-6">{match.description}</p></div></> : null}</CardContent></Card>
          {canManage ? <Card><CardHeader><CardTitle>Gestione partita</CardTitle></CardHeader><CardContent className="grid gap-2">{status !== "cancelled" && status !== "completed" ? <Button asChild><Link href={`/matches/${match.id}/manage-result`}><Trophy />Gestisci risultato</Link></Button> : null}<Button asChild variant="outline"><Link href={`/matches/${match.id}/edit`}><Pencil />Modifica partita</Link></Button>{status !== "cancelled" && status !== "completed" ? <Button disabled={pending !== null} onClick={() => adminAction(closedAt ? "reopen" : "close")} variant="outline"><LockKeyhole />{closedAt ? "Riapri iscrizioni" : "Chiudi iscrizioni"}</Button> : null}{status !== "cancelled" && status !== "completed" ? <AlertDialog><AlertDialogTrigger asChild><Button variant="destructive">Annulla partita</Button></AlertDialogTrigger><AlertDialogContent><AlertDialogHeader><AlertDialogTitle>Annullare la partita?</AlertDialogTitle><AlertDialogDescription>Gli RSVP verranno bloccati, ma la partita resterà nello storico.</AlertDialogDescription></AlertDialogHeader><AlertDialogFooter><AlertDialogCancel>Indietro</AlertDialogCancel><AlertDialogAction onClick={() => adminAction("cancel")} variant="destructive">Annulla partita</AlertDialogAction></AlertDialogFooter></AlertDialogContent></AlertDialog> : null}</CardContent></Card> : null}
        </aside>
      </div>
    </main>
  );
}

function RsvpButton({ active, disabled, label, onClick, variant = "default" }: { active: boolean; disabled: boolean; label: string; onClick: () => void; variant?: "default" | "outline" }) {
  return <Button className={cn("h-12 px-2 text-xs font-black uppercase", active && variant === "outline" && "border-primary text-primary", active && variant === "default" && "ring-2 ring-primary/30")} disabled={disabled} onClick={onClick} type="button" variant={variant}>{label}</Button>;
}

function ParticipantGroup({ title, participants, showPosition = false, hideTitle = false }: { title: string; participants: MatchParticipantView[]; showPosition?: boolean; hideTitle?: boolean }) {
  if (!participants.length) return hideTitle ? null : <div><p className="text-xs font-bold tracking-wider text-muted-foreground uppercase">{title} · 0</p><p className="mt-2 text-sm text-muted-foreground">Nessun giocatore.</p></div>;
  return <section>{hideTitle ? null : <p className="text-xs font-bold tracking-wider text-muted-foreground uppercase">{title} · {participants.length}</p>}<div className={hideTitle ? "space-y-2" : "mt-3 space-y-2"}>{participants.map((participant, index) => <div className="flex items-center gap-3 rounded-xl bg-muted/35 p-2.5" key={participant.id}>{showPosition ? <span className="w-6 text-center text-xs font-black text-primary">#{index + 1}</span> : null}<Avatar className="size-9"><AvatarImage alt="" src={participant.avatarUrl ?? undefined} /><AvatarFallback>{initials(participant)}</AvatarFallback></Avatar><div className="min-w-0"><p className="truncate text-sm font-semibold">{displayName(participant)}</p><p className="truncate text-xs text-muted-foreground">@{participant.username}</p></div></div>)}</div></section>;
}

function Detail({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) { return <div className="flex items-center justify-between gap-3"><span className="flex items-center gap-2 text-muted-foreground [&_svg]:size-4 [&_svg]:text-primary">{icon}{label}</span><span className="font-semibold">{value}</span></div>; }
function displayName(player: MatchParticipantView) { return [player.firstName, player.lastName].filter(Boolean).join(" ") || `@${player.username}`; }
function initials(player: MatchParticipantView) { return `${player.firstName?.[0] ?? ""}${player.lastName?.[0] ?? player.username[0] ?? "K"}`.toUpperCase(); }
function formatMoney(value: number) { return new Intl.NumberFormat("it-IT", { maximumFractionDigits: 2 }).format(value); }
function initialWaitlistPosition(match: MatchDetail) { const waiting = match.participants.filter((participant) => participant.response === "waitlist"); const own = waiting.findIndex((participant) => participant.userId === match.currentUserId); return match.currentResponse === "waitlist" && own >= 0 ? own + 1 : null; }
