import { NextResponse } from "next/server";

export function apiError(message: string, status = 400) {
  return NextResponse.json({ message }, { status });
}

export function leagueRpcMessage(message: string) {
  if (message.includes("public_league_not_found")) return "Questa lega richiede un codice invito.";
  if (message.includes("invalid_invite_code")) return "Codice invito non valido.";
  if (message.includes("already_member")) return "Fai già parte di questa lega.";
  if (message.includes("league_full")) return "La lega ha raggiunto il numero massimo di membri.";
  if (message.includes("membership_banned")) return "Non puoi entrare in questa lega.";
  if (message.includes("owner_required")) return "Questa azione è riservata all’owner.";
  if (message.includes("admin_required")) return "Non hai i permessi per questa azione.";
  if (message.includes("cannot_remove_owner")) return "L’owner non può essere rimosso.";
  if (message.includes("owner_cannot_leave")) return "Trasferisci prima la proprietà oppure elimina la lega.";
  if (message.includes("member_not_found")) return "Membro non trovato.";
  if (message.includes("invalid_communication")) return "Controlla titolo e testo della comunicazione.";
  if (message.includes("communication_rate_limited")) return "Attendi qualche secondo prima di pubblicare un altro messaggio.";
  if (message.includes("communication_not_found")) return "Comunicazione non trovata.";
  return "Operazione non riuscita. Riprova.";
}
