import { Shield, Sparkles, Trophy } from "lucide-react";
import Image from "next/image";

import { roleLabels } from "./schema";
import type { FootballRole } from "@/types/database";

export function PlayerCard({
  username,
  role,
  overall,
  stats,
  name,
  avatarUrl,
  attributes,
}: {
  username: string;
  role: FootballRole | null;
  overall: number;
  stats: { matches: number; goals: number; assists: number; mvp: number };
  name?: string;
  avatarUrl?: string | null;
  attributes?: { pace: number; shooting: number; passing: number; dribbling: number; defending: number; physical: number };
}) {
  const cardStats = attributes ?? deriveAttributes(overall, role);
  return (
    <div className="relative mx-auto aspect-[0.72] w-full max-w-[310px] overflow-hidden rounded-[2rem] border border-primary/35 bg-[linear-gradient(155deg,#18250f_0%,#10130d_42%,#080908_100%)] p-6 shadow-[0_30px_80px_-30px_color-mix(in_oklch,var(--primary)_45%,transparent)]">
      <div aria-hidden className="absolute inset-x-8 top-12 h-44 rounded-full bg-primary/10 blur-3xl" />
      <div className="relative flex items-start justify-between"><div><p className="text-5xl font-black tracking-tighter text-primary">{Math.round(overall)}</p><p className="mt-1 text-xs font-bold tracking-wider uppercase">{role ? roleLabels[role] : "Player"}</p></div><Shield className="size-8 text-primary" /></div>
      <div className="relative mt-8 grid h-32 place-items-center overflow-hidden rounded-3xl border border-white/8 bg-white/4">{avatarUrl ? <Image alt="" className="object-cover" fill sizes="310px" src={avatarUrl} unoptimized /> : <span className="text-7xl font-black text-white/10">K</span>}<Sparkles className="absolute end-4 top-4 size-5 text-primary" /></div>
      <div className="relative mt-5 text-center"><p className="truncate text-xl font-black tracking-wide uppercase">{name || username}</p><p className="mt-1 text-xs text-primary">@{username}</p><div className="mx-auto mt-3 h-px w-20 bg-primary/50" /></div>
      <div className="relative mt-4 grid grid-cols-3 gap-x-3 gap-y-2 text-center">{[["PAC", cardStats.pace], ["SHO", cardStats.shooting], ["PAS", cardStats.passing], ["DRI", cardStats.dribbling], ["DEF", cardStats.defending], ["PHY", cardStats.physical]].map(([label, value]) => <div className="flex items-baseline justify-center gap-1" key={label}><p className="text-base font-black">{value}</p><p className="text-[9px] font-semibold text-muted-foreground">{label}</p></div>)}</div>
      <p className="relative mt-3 text-center text-[9px] font-bold tracking-wide text-muted-foreground uppercase">{stats.matches} match · {stats.goals} gol · {stats.assists} assist · {stats.mvp} MVP</p>
      <Trophy className="absolute bottom-4 end-5 size-4 text-primary/60" />
    </div>
  );
}

export function deriveAttributes(overall: number, role: FootballRole | null) {
  const base = Math.round(overall);
  const offsets = role === "forward" ? [5, 7, 0, 4, -10, 1] : role === "midfielder" ? [1, 0, 7, 5, 0, 0] : role === "defender" ? [-1, -8, 1, -2, 8, 5] : role === "goalkeeper" ? [-8, -12, 0, -6, 9, 3] : [0, 0, 0, 0, 0, 0];
  const values = offsets.map((offset) => Math.max(1, Math.min(99, base + offset)));
  return { pace: values[0], shooting: values[1], passing: values[2], dribbling: values[3], defending: values[4], physical: values[5] };
}
