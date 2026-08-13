import { NextResponse } from "next/server";

export function matchApiError(message: string, status = 400) {
  return NextResponse.json({ message }, { status });
}

export function matchRpcMessage(message: string) {
  if (message.includes("authentication_required")) return "Accedi per continuare.";
  if (message.includes("admin_required")) return "Solo owner e admin possono eseguire questa azione.";
  if (message.includes("membership_required")) return "Non fai più parte di questa lega.";
  if (message.includes("match_not_found")) return "Partita non trovata.";
  if (message.includes("registrations_closed")) return "Le iscrizioni sono chiuse.";
  if (message.includes("match_locked")) return "La partita non accetta più modifiche.";
  if (message.includes("max_below_confirmed")) return "Il numero massimo non può essere inferiore ai partecipanti già confermati.";
  if (message.includes("invalid_max_players")) return "Il numero di giocatori deve essere compreso tra 4 e 30.";
  if (message.includes("teams_required")) return "Assegna almeno un giocatore a ciascuna squadra.";
  if (message.includes("all_confirmed_players_required")) return "Assegna tutti e solo i partecipanti confermati.";
  if (message.includes("player_totals_required")) return "Inserisci goal e assist per tutti i giocatori.";
  if (message.includes("team_a_goals_mismatch")) {
    const [, expected, assigned] = message.match(/team_a_goals_mismatch:(\d+):(\d+)/) ?? [];
    return expected ? `Il Team A ha segnato ${expected} gol, ma ne hai assegnati ${assigned}.` : "I gol del Team A non coincidono col risultato.";
  }
  if (message.includes("team_b_goals_mismatch")) {
    const [, expected, assigned] = message.match(/team_b_goals_mismatch:(\d+):(\d+)/) ?? [];
    return expected ? `Il Team B ha segnato ${expected} gol, ma ne hai assegnati ${assigned}.` : "I gol del Team B non coincidono col risultato.";
  }
  if (message.includes("cannot_vote_self")) return "Non puoi votare te stesso.";
  if (message.includes("participant_required")) return "Solo i partecipanti possono votare l’MVP.";
  if (message.includes("mvp_voting_closed")) return "La votazione MVP è terminata.";
  if (message.includes("duplicate key")) return "Hai già votato per questa partita.";
  return "Operazione non riuscita. Riprova.";
}
