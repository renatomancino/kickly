"use client";

import { useState } from "react";
import { Crown, MoreHorizontal, ShieldCheck, Trash2, UserRoundCog } from "lucide-react";
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
} from "@/components/ui/alert-dialog";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { roleLabels } from "@/features/profile/schema";

import { RoleBadge } from "./role-badge";
import type { LeagueMember, LeagueRole } from "./types";

type MemberAction = "promote" | "demote" | "remove" | "transfer";

export function MembersList({
  leagueId,
  currentUserId,
  currentUserRole,
  initialMembers,
}: {
  leagueId: string;
  currentUserId: string;
  currentUserRole: LeagueRole;
  initialMembers: LeagueMember[];
}) {
  const router = useRouter();
  const [members, setMembers] = useState(initialMembers);
  const [pending, setPending] = useState<{ member: LeagueMember; action: MemberAction } | null>(null);
  const [working, setWorking] = useState(false);

  async function executeAction() {
    if (!pending) return;
    const selected = pending;
    setWorking(true);
    try {
      const response = await fetch(`/api/leagues/${leagueId}/members/${selected.member.userId}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: selected.action }),
      });
      const result = (await response.json().catch(() => ({}))) as { message?: string };
      if (!response.ok) {
        toast.error(result.message ?? "Operazione non riuscita.");
        return;
      }
      setMembers((current) => {
        if (selected.action === "remove") return current.filter((member) => member.userId !== selected.member.userId);
        if (selected.action === "transfer") {
          return current.map((member) =>
            member.userId === selected.member.userId
              ? { ...member, leagueRole: "owner" }
              : member.userId === currentUserId
                ? { ...member, leagueRole: "admin" }
                : member,
          );
        }
        return current.map((member) =>
          member.userId === selected.member.userId
            ? { ...member, leagueRole: selected.action === "promote" ? "admin" : "member" }
            : member,
        );
      });
      toast.success(actionSuccess(selected.action));
      setPending(null);
      router.refresh();
    } catch {
      toast.error("Connessione non disponibile. Riprova.");
    } finally {
      setWorking(false);
    }
  }

  return (
    <>
      <div className="divide-y overflow-hidden rounded-2xl border bg-card/60">
        {members.map((member) => {
          const canOwnerManage = currentUserRole === "owner" && member.userId !== currentUserId && member.leagueRole !== "owner";
          const canAdminRemove = currentUserRole === "admin" && member.leagueRole === "member" && member.userId !== currentUserId;
          return (
            <div className="flex items-center gap-3 p-4" key={member.id}>
              <Avatar className="size-11"><AvatarImage alt="" src={member.avatarUrl ?? undefined} /><AvatarFallback>{initials(member)}</AvatarFallback></Avatar>
              <div className="min-w-0 flex-1"><div className="flex flex-wrap items-center gap-2"><p className="truncate font-semibold">{displayName(member)}</p><RoleBadge role={member.leagueRole} /></div><p className="mt-1 truncate text-xs text-muted-foreground">@{member.username}{member.footballRole ? ` · ${roleLabels[member.footballRole]}` : ""}</p></div>
              {canOwnerManage || canAdminRemove ? (
                <DropdownMenu>
                  <DropdownMenuTrigger asChild><Button aria-label={`Gestisci ${displayName(member)}`} size="icon" variant="ghost"><MoreHorizontal /></Button></DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    {canOwnerManage && member.leagueRole === "member" ? <DropdownMenuItem onSelect={() => setPending({ member, action: "promote" })}><ShieldCheck />Promuovi ad admin</DropdownMenuItem> : null}
                    {canOwnerManage && member.leagueRole === "admin" ? <DropdownMenuItem onSelect={() => setPending({ member, action: "demote" })}><UserRoundCog />Rimuovi da admin</DropdownMenuItem> : null}
                    {canOwnerManage ? <DropdownMenuItem onSelect={() => setPending({ member, action: "transfer" })}><Crown />Trasferisci proprietà</DropdownMenuItem> : null}
                    <DropdownMenuSeparator />
                    <DropdownMenuItem className="text-destructive" onSelect={() => setPending({ member, action: "remove" })}><Trash2 />Rimuovi dalla lega</DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              ) : null}
            </div>
          );
        })}
      </div>

      <AlertDialog open={Boolean(pending)} onOpenChange={(open) => !open && !working && setPending(null)}>
        <AlertDialogContent>
          <AlertDialogHeader><AlertDialogTitle>{pending ? actionTitle(pending.action) : "Conferma azione"}</AlertDialogTitle><AlertDialogDescription>{pending ? actionDescription(pending.member, pending.action) : ""}</AlertDialogDescription></AlertDialogHeader>
          <AlertDialogFooter><AlertDialogCancel disabled={working}>Annulla</AlertDialogCancel><AlertDialogAction disabled={working} onClick={(event) => { event.preventDefault(); void executeAction(); }}>{working ? "Salvataggio…" : "Conferma"}</AlertDialogAction></AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}

function displayName(member: LeagueMember) {
  return [member.firstName, member.lastName].filter(Boolean).join(" ") || member.username;
}
function initials(member: LeagueMember) {
  return `${member.firstName?.[0] ?? ""}${member.lastName?.[0] ?? member.username[0] ?? "K"}`.toUpperCase();
}
function actionTitle(action: MemberAction) {
  return action === "promote" ? "Promuovere ad admin?" : action === "demote" ? "Rimuovere dagli admin?" : action === "transfer" ? "Trasferire la proprietà?" : "Rimuovere il membro?";
}
function actionDescription(member: LeagueMember, action: MemberAction) {
  const name = displayName(member);
  if (action === "transfer") return `${name} diventerà owner. Tu passerai automaticamente al ruolo admin.`;
  if (action === "remove") return `${name} perderà subito l’accesso alla lega.`;
  return `Il ruolo di ${name} verrà aggiornato immediatamente.`;
}
function actionSuccess(action: MemberAction) {
  return action === "promote" ? "Membro promosso ad admin." : action === "demote" ? "Admin riportato a membro." : action === "transfer" ? "Proprietà trasferita." : "Membro rimosso.";
}
