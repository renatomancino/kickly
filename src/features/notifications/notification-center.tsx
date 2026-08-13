"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Bell, CalendarDays, CheckCheck, Shield, Sparkles, Star, TrendingUp } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import type { NotificationItem } from "./types";

export function NotificationCenter({ initialItems }: { initialItems: NotificationItem[] }) {
  const [items, setItems] = useState(initialItems);
  const router = useRouter();
  const unread = items.filter((item) => !item.read_at).length;

  async function open(item: NotificationItem) {
    if (!item.read_at) {
      setItems((current) => current.map((entry) => entry.id === item.id ? { ...entry, read_at: new Date().toISOString() } : entry));
      await fetch(`/api/notifications/${item.id}`, { method: "POST" });
    }
    if (item.link) router.push(item.link);
  }

  async function readAll() {
    const now = new Date().toISOString();
    setItems((current) => current.map((item) => ({ ...item, read_at: item.read_at ?? now })));
    const response = await fetch("/api/notifications/read-all", { method: "POST" });
    if (!response.ok) toast.error("Non è stato possibile aggiornare le notifiche.");
  }

  return <main className="py-6 sm:py-10"><div className="mb-6 flex items-end justify-between gap-4"><div><p className="text-xs font-bold tracking-[.18em] text-primary uppercase">Centro attività</p><h1 className="mt-2 text-3xl font-black">Notifiche</h1><p className="mt-1 text-sm text-muted-foreground">{unread ? `${unread} da leggere` : "Sei in pari"}</p></div>{unread ? <Button onClick={readAll} size="sm" variant="outline"><CheckCheck />Segna tutte</Button> : null}</div>{items.length ? <div className="space-y-2">{items.map((item) => <button className="block w-full text-left" key={item.id} onClick={() => open(item)} type="button"><Card className={cn("transition-colors hover:bg-card/80", !item.read_at && "border-primary/20 bg-primary/[.035]")}><CardContent className="flex gap-3"><span className={cn("mt-0.5 grid size-10 shrink-0 place-items-center rounded-xl bg-muted text-muted-foreground", !item.read_at && "bg-primary/12 text-primary")}>{iconFor(item.type)}</span><span className="min-w-0 flex-1"><span className="flex items-start justify-between gap-3"><span className="font-bold">{item.title}</span>{!item.read_at ? <span className="mt-1.5 size-2 shrink-0 rounded-full bg-primary" /> : null}</span><span className="mt-1 block text-sm text-muted-foreground">{item.body}</span><span className="mt-2 block text-[11px] text-muted-foreground">{formatRelative(item.created_at)}</span></span></CardContent></Card></button>)}</div> : <Card className="border-dashed"><CardContent className="py-16 text-center"><Bell className="mx-auto size-8 text-muted-foreground"/><p className="mt-4 font-bold">Nessuna notifica</p><p className="mt-1 text-sm text-muted-foreground">Gli aggiornamenti delle tue leghe compariranno qui.</p></CardContent></Card>}</main>;
}

function iconFor(type: string) {
  if (type.includes("mvp")) return <Star className="size-5" />;
  if (type.includes("rating")) return <TrendingUp className="size-5" />;
  if (type.includes("league")) return <Shield className="size-5" />;
  if (type.includes("waitlist")) return <Sparkles className="size-5" />;
  return <CalendarDays className="size-5" />;
}

function formatRelative(value: string) {
  const minutes = Math.max(0, Math.round((Date.now() - new Date(value).getTime()) / 60000));
  if (minutes < 1) return "Adesso";
  if (minutes < 60) return `${minutes} min fa`;
  if (minutes < 1440) return `${Math.floor(minutes / 60)} h fa`;
  return new Intl.DateTimeFormat("it-IT", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" }).format(new Date(value));
}
