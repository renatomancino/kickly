"use client";

import { useState } from "react";
import { LogOut, Settings, Trash2 } from "lucide-react";
import { useRouter } from "next/navigation";
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
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { LeagueForm } from "./league-form";
import type { LeagueDetail } from "./types";

export function LeagueSettings({ league }: { league: LeagueDetail }) {
  const router = useRouter();
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [confirmation, setConfirmation] = useState("");
  const [working, setWorking] = useState(false);
  const canManage = league.currentUserRole === "owner" || league.currentUserRole === "admin";

  async function leave() {
    setWorking(true);
    const response = await fetch(`/api/leagues/${league.id}/leave`, { method: "POST" });
    const result = (await response.json()) as { message?: string };
    setWorking(false);
    if (!response.ok) return toast.error(result.message ?? "Operazione non riuscita.");
    toast.success("Hai lasciato la lega.");
    router.push("/leagues");
    router.refresh();
  }

  async function removeLeague() {
    setWorking(true);
    const response = await fetch(`/api/leagues/${league.id}`, {
      method: "DELETE",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ confirmation }),
    });
    const result = (await response.json()) as { message?: string };
    setWorking(false);
    if (!response.ok) return toast.error(result.message ?? "Eliminazione non riuscita.");
    toast.success("Lega eliminata.");
    router.push("/leagues");
    router.refresh();
  }

  return (
    <div className="flex flex-wrap gap-2">
      {canManage ? (
        <Dialog onOpenChange={setSettingsOpen} open={settingsOpen}>
          <DialogTrigger asChild><Button variant="outline"><Settings />Impostazioni lega</Button></DialogTrigger>
          <DialogContent className="max-h-[90dvh] max-w-2xl overflow-y-auto"><DialogHeader><DialogTitle>Impostazioni lega</DialogTitle></DialogHeader><LeagueForm league={league} onSaved={() => setSettingsOpen(false)} /></DialogContent>
        </Dialog>
      ) : null}

      {league.currentUserRole !== "owner" ? (
        <AlertDialog>
          <AlertDialogTrigger asChild><Button variant="outline"><LogOut />Lascia lega</Button></AlertDialogTrigger>
          <AlertDialogContent><AlertDialogHeader><AlertDialogTitle>Lasciare la lega?</AlertDialogTitle><AlertDialogDescription>Non comparirai più tra i membri. Per rientrare servirà un nuovo invito.</AlertDialogDescription></AlertDialogHeader><AlertDialogFooter><AlertDialogCancel>Annulla</AlertDialogCancel><AlertDialogAction disabled={working} onClick={(event) => { event.preventDefault(); void leave(); }}>Lascia lega</AlertDialogAction></AlertDialogFooter></AlertDialogContent>
        </AlertDialog>
      ) : null}

      {league.currentUserRole === "owner" ? (
        <AlertDialog>
          <AlertDialogTrigger asChild><Button variant="destructive"><Trash2 />Elimina lega</Button></AlertDialogTrigger>
          <AlertDialogContent><AlertDialogHeader><AlertDialogTitle>Eliminare definitivamente la lega?</AlertDialogTitle><AlertDialogDescription>Questa azione cancella lega e membership. Digita <strong>{league.name}</strong> per confermare.</AlertDialogDescription></AlertDialogHeader><Input onChange={(event) => setConfirmation(event.target.value)} placeholder={league.name} value={confirmation} /><AlertDialogFooter><AlertDialogCancel>Annulla</AlertDialogCancel><AlertDialogAction disabled={working || confirmation !== league.name} onClick={(event) => { event.preventDefault(); void removeLeague(); }}>Elimina definitivamente</AlertDialogAction></AlertDialogFooter></AlertDialogContent>
        </AlertDialog>
      ) : null}
    </div>
  );
}
