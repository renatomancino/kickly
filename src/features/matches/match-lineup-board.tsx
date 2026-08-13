"use client";

import { useEffect, useMemo, useState } from "react";
import { Crown, LoaderCircle, Shield, Sparkles, UserRoundX } from "lucide-react";
import { toast } from "sonner";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";
import type { AttendanceStatus, MatchFormat, MatchStatus } from "@/types/database";

import { buildLineupSlots, defaultFormation, formationOptions } from "./lineup-config";
import type { MatchLineup, MatchParticipantView } from "./types";

interface ApiResult {
  lineup?: MatchLineup;
  message?: string;
}

interface RealtimeTeamRow {
  team_number: 1 | 2;
  formation: string;
  captain_user_id: string | null;
}

interface RealtimePlayerRow {
  user_id: string;
  team_number: 1 | 2;
  slot_key: string;
}

export function MatchLineupBoard({
  matchId,
  format,
  currentUserId,
  currentResponse,
  status,
  participants,
  initialLineup,
  canManage,
}: {
  matchId: string;
  format: MatchFormat;
  currentUserId: string;
  currentResponse: AttendanceStatus | null;
  status: MatchStatus;
  participants: MatchParticipantView[];
  initialLineup: MatchLineup;
  canManage: boolean;
}) {
  const [lineup, setLineup] = useState(initialLineup);
  const [pending, setPending] = useState<string | null>(null);
  const [wantsCaptain, setWantsCaptain] = useState(false);
  const [activeMobileTeam, setActiveMobileTeam] = useState<1 | 2>(
    initialLineup.players.find((player) => player.userId === currentUserId)?.teamNumber ?? 1,
  );
  const confirmed = useMemo(
    () => new Map(participants.filter((player) => player.response === "going").map((player) => [player.userId, player])),
    [participants],
  );
  const ownAssignment = lineup.players.find((player) => player.userId === currentUserId);
  const ownIsCaptain = lineup.teams.some((team) => team.captainUserId === currentUserId);
  const canChoose = currentResponse === "going" && status !== "cancelled" && status !== "completed";

  useEffect(() => {
    const supabase = createClient();
    let refreshTimer: ReturnType<typeof setTimeout> | undefined;

    const refresh = () => {
      clearTimeout(refreshTimer);
      refreshTimer = setTimeout(async () => {
        const [{ data: teams }, { data: players }] = await Promise.all([
          supabase.from("match_lineup_teams").select("team_number, formation, captain_user_id").eq("match_id", matchId).order("team_number"),
          supabase.from("match_lineup_players").select("user_id, team_number, slot_key").eq("match_id", matchId),
        ]);
        setLineup(normalizeRealtime(format, teams, players));
      }, 140);
    };

    const channel = supabase
      .channel(`match-lineup:${matchId}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "match_lineup_teams", filter: `match_id=eq.${matchId}` }, refresh)
      .on("postgres_changes", { event: "*", schema: "public", table: "match_lineup_players", filter: `match_id=eq.${matchId}` }, refresh)
      .subscribe();

    return () => {
      clearTimeout(refreshTimer);
      void supabase.removeChannel(channel);
    };
  }, [format, matchId]);

  async function runAction(body: Record<string, unknown>, key: string, successMessage: string) {
    setPending(key);
    try {
      const response = await fetch(`/api/matches/${matchId}/lineup`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const result = await response.json().catch(() => ({})) as ApiResult;
      if (!response.ok || !result.lineup) throw new Error(result.message ?? "Formazione non aggiornata.");
      setLineup(result.lineup);
      setWantsCaptain(false);
      toast.success(successMessage);
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Formazione non aggiornata.");
    } finally {
      setPending(null);
    }
  }

  function claim(teamNumber: 1 | 2, slotKey: string) {
    if (!canChoose) return;
    if (lineup.players.some((player) => player.teamNumber === teamNumber && player.slotKey === slotKey && player.userId !== currentUserId)) return;
    setActiveMobileTeam(teamNumber);
    void runAction({
      action: "claim",
      team_number: teamNumber,
      slot_key: slotKey,
      wants_captain: ownIsCaptain || wantsCaptain,
    }, `${teamNumber}:${slotKey}`, ownAssignment ? "Posizione aggiornata." : "Sei in formazione.");
  }

  function toggleCaptain() {
    if (!ownAssignment) {
      setWantsCaptain((current) => !current);
      return;
    }
    void runAction({
      action: "claim",
      team_number: ownAssignment.teamNumber,
      slot_key: ownAssignment.slotKey,
      wants_captain: !ownIsCaptain,
    }, "captain", ownIsCaptain ? "Non sei più capitano." : "Ora sei il capitano.");
  }

  function release() {
    void runAction({ action: "release" }, "release", "Posizione liberata.");
  }

  function changeFormation(teamNumber: 1 | 2, formation: string) {
    void runAction({ action: "formation", team_number: teamNumber, formation }, `formation:${teamNumber}`, `Modulo Team ${teamNumber === 1 ? "A" : "B"} aggiornato.`);
  }

  return (
    <Card className="mt-5 overflow-hidden border-primary/20 bg-[radial-gradient(circle_at_top,color-mix(in_oklch,var(--primary)_8%,transparent),transparent_42%)]">
      <CardHeader className="gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="flex items-center gap-2 text-xs font-black tracking-[.16em] text-primary uppercase"><Sparkles className="size-3.5" />Formazione pre-partita</p>
          <CardTitle className="mt-2 text-2xl">Team A contro Team B</CardTitle>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-muted-foreground">
            {canChoose ? "Tocca una posizione libera. Puoi spostarti finché la partita non viene chiusa." : "Le posizioni sono visibili ai membri della lega; conferma Partecipo per sceglierne una."}
          </p>
        </div>
        {canChoose ? <div className="flex flex-wrap gap-2">
          <Button disabled={pending !== null} onClick={toggleCaptain} size="sm" variant={ownIsCaptain || wantsCaptain ? "default" : "outline"}>
            {pending === "captain" ? <LoaderCircle className="animate-spin" /> : <Crown />}
            {ownIsCaptain ? "Sei capitano" : wantsCaptain ? "Capitano al prossimo slot" : "Candidati capitano"}
          </Button>
          {ownAssignment ? <Button disabled={pending !== null} onClick={release} size="sm" variant="ghost"><UserRoundX />Libera posizione</Button> : null}
        </div> : null}
      </CardHeader>
      <CardContent className="px-3 sm:px-6">
        <div aria-label="Scegli la squadra da visualizzare" className="mb-4 grid grid-cols-2 rounded-2xl border bg-background/45 p-1 xl:hidden" role="tablist">
          {([1, 2] as const).map((teamNumber) => {
            const playerCount = lineup.players.filter((player) => player.teamNumber === teamNumber).length;
            const selected = activeMobileTeam === teamNumber;
            return (
              <button
                aria-controls={`lineup-team-${teamNumber}`}
                aria-selected={selected}
                className={cn(
                  "flex min-h-11 items-center justify-center gap-2 rounded-xl px-3 text-sm font-black transition",
                  selected
                    ? teamNumber === 1 ? "bg-primary text-primary-foreground shadow-sm" : "bg-sky-400 text-slate-950 shadow-sm"
                    : "text-muted-foreground",
                )}
                key={teamNumber}
                onClick={() => setActiveMobileTeam(teamNumber)}
                role="tab"
                type="button"
              >
                Team {teamNumber === 1 ? "A" : "B"}
                <span className={cn("text-[10px]", selected ? "opacity-80" : "opacity-60")}>{playerCount}/{Number(format.split("v")[0])}</span>
              </button>
            );
          })}
        </div>
        <div className="grid gap-5 xl:grid-cols-2">
          {([1, 2] as const).map((teamNumber) => {
            const team = lineup.teams.find((item) => item.teamNumber === teamNumber) ?? {
              teamNumber,
              formation: defaultFormation[format],
              captainUserId: null,
            };
            const teamPlayers = lineup.players.filter((player) => player.teamNumber === teamNumber);
            const playerViews = teamPlayers.map((assignment) => confirmed.get(assignment.userId)).filter((player): player is MatchParticipantView => Boolean(player));
            const average = playerViews.length
              ? Math.round(playerViews.reduce((total, player) => total + player.overall, 0) / playerViews.length)
              : 0;
            const canChangeFormation = canManage || team.captainUserId === currentUserId;

            return <section
              aria-labelledby={`lineup-team-${teamNumber}-title`}
              className={cn(
                "rounded-3xl border p-2.5 sm:p-4 xl:block",
                activeMobileTeam !== teamNumber && "hidden",
                teamNumber === 1 ? "bg-primary/[.035]" : "bg-sky-400/[.035]",
              )}
              id={`lineup-team-${teamNumber}`}
              key={teamNumber}
              role="tabpanel"
            >
              <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <span className={cn("grid size-9 place-items-center rounded-xl font-black", teamNumber === 1 ? "bg-primary text-primary-foreground" : "bg-sky-400 text-slate-950")}>{teamNumber === 1 ? "A" : "B"}</span>
                  <div><p className="font-black" id={`lineup-team-${teamNumber}-title`}>Team {teamNumber === 1 ? "A" : "B"}</p><p className="text-xs text-muted-foreground">{teamPlayers.length}/{Number(format.split("v")[0])} in campo</p></div>
                </div>
                <div className="flex items-center gap-2">
                  <Badge variant="outline">OVR {average || "—"}</Badge>
                  {team.captainUserId ? <Badge className="gap-1 bg-amber-400/15 text-amber-300"><Crown className="size-3" />Capitano</Badge> : null}
                </div>
              </div>
              <div className="mb-3 flex items-center justify-between gap-3">
                <span className="text-xs font-bold text-muted-foreground">Modulo</span>
                {canChangeFormation && status !== "completed" && status !== "cancelled" ? (
                  <Select disabled={pending !== null} onValueChange={(value) => changeFormation(teamNumber, value)} value={team.formation}>
                    <SelectTrigger className="h-9 w-32"><SelectValue /></SelectTrigger>
                    <SelectContent>{formationOptions[format].map((formation) => <SelectItem key={formation} value={formation}>{formation}</SelectItem>)}</SelectContent>
                  </Select>
                ) : <Badge variant="secondary">{team.formation}</Badge>}
              </div>
              <FootballPitch
                assignments={teamPlayers}
                captainUserId={team.captainUserId}
                canChoose={canChoose}
                format={format}
                formation={team.formation}
                onClaim={(slotKey) => claim(teamNumber, slotKey)}
                participants={confirmed}
                pending={pending}
                teamNumber={teamNumber}
              />
            </section>;
          })}
        </div>
        <div className="mt-4 flex flex-wrap items-center gap-x-5 gap-y-2 text-xs text-muted-foreground">
          <span className="flex items-center gap-1.5"><span className="size-2 rounded-full bg-primary" />Team A</span>
          <span className="flex items-center gap-1.5"><span className="size-2 rounded-full bg-sky-400" />Team B</span>
          <span className="flex items-center gap-1.5"><Crown className="size-3 text-amber-300" />Il capitano sceglie il modulo</span>
        </div>
      </CardContent>
    </Card>
  );
}

function FootballPitch({
  format,
  formation,
  teamNumber,
  assignments,
  participants,
  captainUserId,
  canChoose,
  pending,
  onClaim,
}: {
  format: MatchFormat;
  formation: string;
  teamNumber: 1 | 2;
  assignments: MatchLineup["players"];
  participants: Map<string, MatchParticipantView>;
  captainUserId: string | null;
  canChoose: boolean;
  pending: string | null;
  onClaim: (slotKey: string) => void;
}) {
  const slots = buildLineupSlots(format, formation);
  return <div className="relative mx-auto aspect-[7/10] w-full max-w-[30rem] overflow-hidden rounded-2xl border-2 border-white/45 bg-[linear-gradient(90deg,rgba(255,255,255,.035)_50%,transparent_50%)] bg-[length:28%_100%] shadow-inner">
    <div aria-hidden className="absolute inset-x-0 top-1/2 border-t-2 border-white/40" />
    <div aria-hidden className="absolute left-1/2 top-1/2 size-[24%] -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white/40" />
    <div aria-hidden className="absolute inset-x-[24%] bottom-0 h-[16%] border-x-2 border-t-2 border-white/40" />
    <div aria-hidden className="absolute inset-x-[38%] bottom-0 h-[7%] border-x-2 border-t-2 border-white/40" />
    <div aria-hidden className="absolute inset-x-[24%] top-0 h-[16%] border-x-2 border-b-2 border-white/40" />
    {slots.map((slot) => {
      const assignment = assignments.find((player) => player.slotKey === slot.key);
      const player = assignment ? participants.get(assignment.userId) : null;
      const isCaptain = Boolean(player && player.userId === captainUserId);
      const isPending = pending === `${teamNumber}:${slot.key}`;
      return <button
        aria-label={player ? `${displayName(player)}, ${slot.roleLabel}${isCaptain ? ", capitano" : ""}` : `Posizione ${slot.roleLabel} libera`}
        className={cn("absolute z-10 flex w-14 -translate-x-1/2 -translate-y-1/2 flex-col items-center text-center transition", !player && canChoose && "hover:scale-105", (!canChoose || player) && "cursor-default")}
        disabled={!canChoose || Boolean(player) || pending !== null}
        key={slot.key}
        onClick={() => onClaim(slot.key)}
        style={{ left: `${slot.x}%`, top: `${slot.y}%` }}
        type="button"
      >
        <span className={cn(
          "relative grid size-10 place-items-center overflow-hidden rounded-full border-2 shadow-lg",
          player ? teamNumber === 1 ? "border-primary bg-card" : "border-sky-400 bg-card" : "border-dashed border-white/60 bg-black/20 text-xs font-black text-white/85",
        )}>
          {isPending ? <LoaderCircle className="size-4 animate-spin" /> : player ? <Avatar className="size-full"><AvatarImage alt="" src={player.avatarUrl ?? undefined} /><AvatarFallback className="text-[10px] font-black">{initials(player)}</AvatarFallback></Avatar> : <span>{slot.roleLabel}</span>}
          {isCaptain ? <span className="absolute -right-0.5 -top-0.5 grid size-4 place-items-center rounded-full bg-amber-300 text-black"><Crown className="size-2.5" /></span> : null}
        </span>
        <span className={cn("mt-1 max-w-16 truncate rounded-md px-1.5 py-0.5 text-[9px] font-black shadow", player ? "bg-card/95 text-foreground" : "bg-black/30 text-white/80")}>{player ? shortName(player) : "Libero"}</span>
      </button>;
    })}
    <div className="absolute bottom-2 left-2 flex items-center gap-1 rounded-md bg-black/25 px-1.5 py-1 text-[9px] font-bold text-white/70"><Shield className="size-2.5" />{formation}</div>
  </div>;
}

function normalizeRealtime(
  format: MatchFormat,
  teamRows: RealtimeTeamRow[] | null,
  playerRows: RealtimePlayerRow[] | null,
): MatchLineup {
  return {
    teams: ([1, 2] as const).map((teamNumber) => {
      const row = teamRows?.find((team) => team.team_number === teamNumber);
      return { teamNumber, formation: row?.formation ?? defaultFormation[format], captainUserId: row?.captain_user_id ?? null };
    }),
    players: (playerRows ?? []).map((player) => ({ userId: player.user_id, teamNumber: player.team_number, slotKey: player.slot_key })),
  };
}

function displayName(player: MatchParticipantView) {
  return [player.firstName, player.lastName].filter(Boolean).join(" ") || `@${player.username}`;
}

function shortName(player: MatchParticipantView) {
  return player.firstName ?? player.username;
}

function initials(player: MatchParticipantView) {
  return `${player.firstName?.[0] ?? ""}${player.lastName?.[0] ?? player.username[0] ?? "K"}`.toUpperCase();
}
