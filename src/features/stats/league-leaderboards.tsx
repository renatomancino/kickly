"use client";

import Link from "next/link";
import { Trophy } from "lucide-react";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import type { LeaderboardPlayer, LeagueLeaderboards } from "./types";

export function LeagueLeaderboardsView({ boards, preview = false }: { boards: LeagueLeaderboards; preview?: boolean }) {
  if (preview) return <div className="grid gap-4 md:grid-cols-3"><MiniBoard title="Top marcatori" players={boards.goals.slice(0, 3)} field="goals" /><MiniBoard title="Top assist" players={boards.assists.slice(0, 3)} field="assists" /><MiniBoard title="MVP" players={boards.mvp.slice(0, 3)} field="mvp" /></div>;
  return <Tabs defaultValue="goals"><div className="overflow-x-auto [scrollbar-width:none]"><TabsList className="w-max min-w-full"><TabsTrigger value="goals">Marcatori</TabsTrigger><TabsTrigger value="assists">Assist</TabsTrigger><TabsTrigger value="mvp">MVP</TabsTrigger><TabsTrigger value="appearances">Presenze</TabsTrigger><TabsTrigger value="overall">Overall</TabsTrigger></TabsList></div><BoardTab value="goals" players={boards.goals} field="goals" /><BoardTab value="assists" players={boards.assists} field="assists" /><BoardTab value="mvp" players={boards.mvp} field="mvp" /><BoardTab value="appearances" players={boards.appearances} field="matches" /><BoardTab value="overall" players={boards.overall} field="overall" /></Tabs>;
}

function BoardTab({ value, players, field }: { value: string; players: LeaderboardPlayer[]; field: "goals" | "assists" | "mvp" | "matches" | "overall" }) { return <TabsContent className="mt-4" value={value}><Card><CardContent className="space-y-2">{players.length ? players.map((player, index) => <PlayerRow key={player.userId} player={player} index={index} field={field} />) : <Empty />}</CardContent></Card></TabsContent>; }
function MiniBoard({ title, players, field }: { title: string; players: LeaderboardPlayer[]; field: "goals" | "assists" | "mvp" }) { return <Card><CardHeader><CardTitle>{title}</CardTitle></CardHeader><CardContent className="space-y-2">{players.length ? players.map((player, index) => <PlayerRow compact key={player.userId} player={player} index={index} field={field} />) : <Empty />}</CardContent></Card>; }
function PlayerRow({ player, index, field, compact = false }: { player: LeaderboardPlayer; index: number; field: "goals" | "assists" | "mvp" | "matches" | "overall"; compact?: boolean }) { const value = player[field]; const rateField = field === "goals" || field === "assists"; return <Link className="flex items-center gap-3 rounded-xl bg-muted/35 p-2.5 transition hover:bg-muted/60" href={`/player/${player.username}`}><span className={index < 3 ? "w-6 text-center font-black text-primary" : "w-6 text-center font-bold text-muted-foreground"}>#{index + 1}</span><Avatar className="size-9"><AvatarImage src={player.avatarUrl ?? undefined} /><AvatarFallback>{player.username.slice(0, 2)}</AvatarFallback></Avatar><div className="min-w-0 flex-1"><p className="truncate font-semibold">{player.name}</p>{!compact ? <p className="text-xs text-muted-foreground">{player.matches} partite{rateField ? ` · ${(value / Math.max(1, player.matches)).toFixed(2)}/partita` : ""}</p> : null}</div><Badge className="min-w-12 justify-center" variant={index === 0 ? "default" : "secondary"}>{field === "overall" ? Math.round(value) : value}</Badge></Link>; }
function Empty() { return <div className="py-8 text-center text-sm text-muted-foreground"><Trophy className="mx-auto mb-3 size-5 text-primary" />La classifica si popolerà dopo la prima partita.</div>; }
