"use client";

import { useMemo, useState } from "react";
import { Check, Copy, LoaderCircle, MessageCircle, RefreshCw, Share2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";

import type { LeagueRole } from "./types";

export function InviteDialog({
  leagueId,
  leagueName,
  footballFormat,
  initialCode,
  role,
}: {
  leagueId: string;
  leagueName: string;
  footballFormat: string;
  initialCode: string;
  role: LeagueRole;
}) {
  const router = useRouter();
  const [code, setCode] = useState(initialCode);
  const [copied, setCopied] = useState(false);
  const [rotating, setRotating] = useState(false);
  const [origin, setOrigin] = useState("");
  const link = useMemo(() => `${origin}/join/${code}`, [origin, code]);

  function opened(open: boolean) {
    if (open) setOrigin(window.location.origin);
  }

  async function copyLink() {
    await navigator.clipboard.writeText(link);
    setCopied(true);
    toast.success("Link copiato.");
    window.setTimeout(() => setCopied(false), 1800);
  }

  async function shareInvite() {
    const text = `⚽ Entra nella nostra lega su Kickly!\n\n${leagueName}\n${footballFormat.replace("v", " vs ")}\n\n${link}`;
    if (navigator.share) {
      try {
        await navigator.share({ title: `Invito ${leagueName}`, text, url: link });
        return;
      } catch {
        // A cancelled native share should not block the clipboard fallback.
      }
    }
    await copyLink();
  }

  async function rotateCode() {
    setRotating(true);
    const response = await fetch(`/api/leagues/${leagueId}/invite`, { method: "POST" });
    const result = (await response.json()) as { code?: string; message?: string };
    setRotating(false);
    if (!response.ok || !result.code) {
      toast.error(result.message ?? "Rigenerazione non riuscita.");
      return;
    }
    setCode(result.code);
    toast.success("Nuovo codice generato. Il precedente non è più valido.");
    router.refresh();
  }

  const whatsappText = encodeURIComponent(`⚽ Entra nella nostra lega su Kickly!\n\n${leagueName}\n${footballFormat.replace("v", " vs ")}\n\n${link}`);

  return (
    <Dialog onOpenChange={opened}>
      <DialogTrigger asChild><Button className="rounded-xl"><Share2 />Invita giocatori</Button></DialogTrigger>
      <DialogContent className="max-w-md">
        <DialogHeader><DialogTitle>Invita giocatori</DialogTitle><DialogDescription>Condividi il codice o il link. L’ingresso viene salvato direttamente nella lega.</DialogDescription></DialogHeader>
        <div className="mt-2 rounded-2xl border bg-muted/30 p-5 text-center"><p className="text-xs font-semibold tracking-[0.16em] text-muted-foreground uppercase">Codice lega</p><p className="mt-2 font-mono text-3xl font-black tracking-[0.2em] text-primary">{code}</p></div>
        <div className="flex gap-2"><Input className="h-11 min-w-0 font-mono text-xs" readOnly value={link} /><Button className="size-11" onClick={copyLink} size="icon-lg" variant="outline">{copied ? <Check /> : <Copy />}<span className="sr-only">Copia link</span></Button></div>
        <div className="grid grid-cols-2 gap-2"><Button onClick={shareInvite} variant="secondary"><Share2 />Condividi</Button><Button asChild variant="secondary"><a href={`https://wa.me/?text=${whatsappText}`} rel="noreferrer" target="_blank"><MessageCircle />WhatsApp</a></Button></div>
        {role === "owner" ? <Button disabled={rotating} onClick={rotateCode} variant="ghost">{rotating ? <LoaderCircle className="animate-spin" /> : <RefreshCw />}Rigenera codice</Button> : null}
      </DialogContent>
    </Dialog>
  );
}
