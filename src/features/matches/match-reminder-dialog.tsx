"use client";

import { useState } from "react";
import { BellRing } from "lucide-react";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

export function MatchReminderDialog({ matchId, matchTitle }: { matchId: string; matchTitle: string }) {
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [body, setBody] = useState("Ricordati della partita: controlla orario, luogo e disponibilità su Kickly.");

  async function send() {
    setPending(true);
    try {
      const request = await fetch(`/api/matches/${matchId}/reminder`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body }),
      });
      const result = await request.json().catch(() => ({})) as { recipientCount?: number; message?: string };
      if (!request.ok) throw new Error(result.message ?? "Promemoria non inviato.");
      toast.success(`Promemoria inviato a ${result.recipientCount ?? 0} partecipanti.`);
      setOpen(false);
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Promemoria non inviato.");
    } finally {
      setPending(false);
    }
  }

  return (
    <Dialog onOpenChange={setOpen} open={open}>
      <DialogTrigger asChild><Button className="w-full" variant="outline"><BellRing />Invia promemoria</Button></DialogTrigger>
      <DialogContent>
        <DialogHeader><DialogTitle>Promemoria partita</DialogTitle><DialogDescription>Verrà salvato nelle comunicazioni della lega e notificato solo a confermati, forse e lista d’attesa per “{matchTitle}”.</DialogDescription></DialogHeader>
        <div className="space-y-2"><div className="flex items-center justify-between gap-3"><Label htmlFor="match-reminder">Messaggio</Label><span className="text-xs text-muted-foreground">{body.length}/500</span></div><Textarea className="min-h-32 resize-y" id="match-reminder" maxLength={500} onChange={(event) => setBody(event.target.value)} value={body} /></div>
        <DialogFooter><Button disabled={pending || body.trim().length < 3} onClick={() => void send()}><BellRing />{pending ? "Invio..." : "Invia ai partecipanti"}</Button></DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
