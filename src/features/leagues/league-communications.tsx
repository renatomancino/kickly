"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { BellRing, Megaphone, Pin, Send, Trash2 } from "lucide-react";
import { toast } from "sonner";

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

import type { LeagueCommunication } from "./types";

export function LeagueCommunications({
  canManage,
  communications,
  leagueId,
}: {
  canManage: boolean;
  communications: LeagueCommunication[];
  leagueId: string;
}) {
  const router = useRouter();
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [pinned, setPinned] = useState(false);
  const [pending, setPending] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  async function publish(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    try {
      const request = await fetch(`/api/leagues/${leagueId}/communications`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title, body, pinned }),
      });
      const result = await request.json().catch(() => ({})) as { message?: string };
      if (!request.ok) throw new Error(result.message ?? "Comunicazione non pubblicata.");
      setTitle("");
      setBody("");
      setPinned(false);
      toast.success("Comunicazione pubblicata e notificata ai membri.");
      router.refresh();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Comunicazione non pubblicata.");
    } finally {
      setPending(false);
    }
  }

  async function remove(communicationId: string) {
    if (!window.confirm("Eliminare questa comunicazione dalla bacheca?")) return;
    setDeletingId(communicationId);
    try {
      const request = await fetch(`/api/leagues/${leagueId}/communications/${communicationId}`, {
        method: "DELETE",
      });
      const result = await request.json().catch(() => ({})) as { message?: string };
      if (!request.ok) throw new Error(result.message ?? "Comunicazione non eliminata.");
      toast.success("Comunicazione eliminata.");
      router.refresh();
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Comunicazione non eliminata.");
    } finally {
      setDeletingId(null);
    }
  }

  return (
    <div className="grid gap-5 lg:grid-cols-[.78fr_1.22fr]">
      {canManage ? (
        <Card className="h-fit lg:sticky lg:top-24">
          <CardHeader>
            <CardTitle className="flex items-center gap-2"><Megaphone className="size-5 text-primary" />Nuova comunicazione</CardTitle>
          </CardHeader>
          <CardContent>
            <form className="space-y-4" onSubmit={publish}>
              <div className="space-y-2">
                <Label htmlFor="communication-title">Titolo</Label>
                <Input id="communication-title" maxLength={120} onChange={(event) => setTitle(event.target.value)} placeholder="Es. Cambio campo di gioco" required value={title} />
              </div>
              <div className="space-y-2">
                <div className="flex items-center justify-between gap-3"><Label htmlFor="communication-body">Messaggio</Label><span className="text-xs text-muted-foreground">{body.length}/500</span></div>
                <Textarea className="min-h-32 resize-y" id="communication-body" maxLength={500} onChange={(event) => setBody(event.target.value)} placeholder="Scrivi l'aggiornamento per i membri della lega..." required value={body} />
              </div>
              <label className="flex cursor-pointer items-center gap-3 rounded-xl border p-3 text-sm">
                <input checked={pinned} className="size-4 accent-primary" onChange={(event) => setPinned(event.target.checked)} type="checkbox" />
                <span><span className="block font-semibold">Metti in evidenza</span><span className="text-xs text-muted-foreground">Resta in cima alla bacheca.</span></span>
              </label>
              <Button className="w-full" disabled={pending} type="submit"><Send />{pending ? "Pubblicazione..." : "Pubblica e notifica"}</Button>
              <p className="text-xs leading-5 text-muted-foreground">Tutti i membri attivi la vedranno qui e riceveranno una notifica secondo le proprie preferenze.</p>
            </form>
          </CardContent>
        </Card>
      ) : null}

      <section aria-label="Bacheca della lega" className={canManage ? "min-w-0" : "min-w-0 lg:col-span-2"}>
        <div className="mb-4">
          <h2 className="text-xl font-bold">Bacheca della lega</h2>
          <p className="mt-1 text-sm text-muted-foreground">Avvisi e promemoria in ordine cronologico.</p>
        </div>
        {communications.length ? (
          <div className="space-y-3">
            {communications.map((item) => {
              const name = [item.author.firstName, item.author.lastName].filter(Boolean).join(" ") || `@${item.author.username}`;
              return (
                <Card className={item.pinned ? "border-primary/30 bg-primary/[0.035]" : ""} id={`communication-${item.id}`} key={item.id}>
                  <CardContent className="p-4 sm:p-5">
                    <div className="flex items-start gap-3">
                      <Avatar className="size-10 shrink-0"><AvatarImage alt="" src={item.author.avatarUrl ?? undefined} /><AvatarFallback>{initials(item.author)}</AvatarFallback></Avatar>
                      <div className="min-w-0 flex-1">
                        <div className="flex flex-wrap items-center gap-2">
                          <Badge variant={item.kind === "match_reminder" ? "secondary" : "outline"}>{item.kind === "match_reminder" ? <BellRing /> : <Megaphone />}{item.kind === "match_reminder" ? "Promemoria partita" : "Comunicazione"}</Badge>
                          {item.pinned ? <Badge><Pin />In evidenza</Badge> : null}
                        </div>
                        <h3 className="mt-3 break-words text-lg font-bold">{item.title}</h3>
                        <p className="mt-2 whitespace-pre-wrap break-words text-sm leading-6 text-muted-foreground">{item.body}</p>
                        <div className="mt-4 flex flex-wrap items-center justify-between gap-3 border-t pt-3">
                          <p className="text-xs text-muted-foreground">{name} · {formatDate(item.createdAt)}</p>
                          <div className="flex items-center gap-1">
                            {item.matchId ? <Button asChild size="sm" variant="ghost"><Link href={`/matches/${item.matchId}`}>Apri partita</Link></Button> : null}
                            {canManage ? <Button aria-label="Elimina comunicazione" disabled={deletingId === item.id} onClick={() => void remove(item.id)} size="icon-sm" type="button" variant="ghost"><Trash2 /></Button> : null}
                          </div>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        ) : (
          <Card className="border-dashed"><CardContent className="py-12 text-center"><Megaphone className="mx-auto size-8 text-primary" /><h3 className="mt-4 font-bold">Nessuna comunicazione</h3><p className="mx-auto mt-2 max-w-sm text-sm text-muted-foreground">Gli aggiornamenti della lega e i promemoria partita compariranno qui.</p></CardContent></Card>
        )}
      </section>
    </div>
  );
}

function initials(author: LeagueCommunication["author"]) {
  return `${author.firstName?.[0] ?? ""}${author.lastName?.[0] ?? author.username[0] ?? "K"}`.toUpperCase();
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat("it-IT", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value));
}
