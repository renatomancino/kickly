# Report sessione autonoma — Affidabilità BE/FE

Report vivo, aggiornato man mano mentre lavoro. Nessuna domanda posta salvo blocchi reali (vedi sotto).

## Contesto
Continuazione autonoma su richiesta esplicita dell'utente: "continua a fare migliorie lato BE ed FE fino ad esaurimento dei tkn senza domandare nulla [...] genera un report e cerca di portare le task a termine [...] altrimenti scrivi nel report quello che manca". L'utente non è raggiungibile.

## ⚠️ AZIONE MANUALE RICHIESTA — leggere per prima cosa

**Ho trovato una vulnerabilità di sicurezza reale e attiva (non teorica) sul database di produzione, ma NON ho potuto applicare la fix dal vivo**: il classificatore di sicurezza della modalità autonoma ha bloccato l'esecuzione di SQL di REVOKE/DROP POLICY su produzione senza supervisione (correttamente — è la categoria di azione giusta da bloccare in autonomia). La fix è scritta, testata a livello di logica e committata nel repo, ma **serve che tu la esegua manualmente**:

1. Apri il [SQL Editor di Supabase](https://supabase.com/dashboard/project/rluxuylutaervjbtexgq/sql/new)
2. Incolla ed esegui il contenuto di [`supabase/migrations/20260814170000_lockdown_profiles_sensitive_columns.sql`](supabase/migrations/20260814170000_lockdown_profiles_sensitive_columns.sql)
3. Verifica (opzionale) che sia andata a buon fine: `select grantee, column_name, privilege_type from information_schema.column_privileges where table_name = 'profiles' and grantee = 'authenticated' and privilege_type = 'UPDATE';` deve restituire solo le colonne elencate nella migrazione (non `overall`, `id`, `created_at`, `timezone`).

**Qual è il problema**: qualunque utente autenticato può oggi eseguire (es. da supabase-js o da un client HTTP qualsiasi, non serve l'app) `update profiles set overall = 99 where id = auth.uid()` e falsificare il proprio rating (1-99) a piacere, bypassando completamente il calcolo ufficiale che avviene dopo ogni partita. Il valore falso resta visibile su profilo e classifiche finché quell'utente non gioca un'altra partita vera. È lo stesso tipo di falla già trovata e corretta questa sessione su `league_members` (grant ampio mai ristretto per questa tabella specifica), ma qui è **attualmente sfruttabile**, non solo latente.

## Fatto in questa sessione (prima di questo report)
- Redesign completo area profilo (privato, pubblico, editor) stile Apple: header a scomparsa, anello overall, tab switch custom, grafico andamento, results bar. PR [renatomancino/kickly#2](https://github.com/renatomancino/kickly/pull/2) aperta e aggiornata.
- Fix SMTP/email: tornato al default Supabase (no dominio), confermato "Confirm email" già disattivato.

## Fatto in questa fase (migliorie BE/FE autonome)

### Backend / Supabase
- ✅ Attivata protezione contro password compromesse... **no, questa NO**: è disponibile solo sul piano Pro (il progetto è su Free). Non toccata, nessuna azione possibile senza upgrade a pagamento — decisione che spetta a te.
- ✅ Alzato il minimo password lato server da 6 a 8 caratteri (Auth → Providers → Email), per allinearlo a quello già richiesto lato client (che imponeva già 8 senza che il server lo garantisse davvero). Applicato e verificato live.
- ✅ Controllati Performance Advisor (0 errori, 0 warning, 20 "Unused Index" — normale per un'app giovane con poco traffico, nessuna azione necessaria) e Security Advisor (0 errori, 32 warning quasi tutti "funzione SECURITY DEFINER eseguibile da utenti loggati" — verificati tutti dall'agente di audit, sono tutti legittimi e controllano `auth.uid()` internamente).
- ✅ Audit completo RLS di tutte le tabelle (agente dedicato, ha letto tutte le 22 migrazioni). Trovati e scritti i fix per:
  - **`profiles.overall` scrivibile direttamente — vedi sezione "AZIONE MANUALE RICHIESTA" sopra, non applicato dal vivo.**
  - Policy morta su `player_rating_history` (stesso pattern di `league_members`, non sfruttabile oggi ma da ripulire) — nella stessa migrazione, stesso blocco.
  - Grant INSERT/DELETE ridondanti su `player_stats` senza policy corrispondente — igiene, nessun rischio reale, stessa migrazione.
  - Tutte le altre tabelle verificate a posto (scritture solo via RPC `SECURITY DEFINER` con controllo `auth.uid()` esplicito, nessuna si fida di parametri esterni).
- ✅ Migrazione `supabase/migrations/20260814170000_lockdown_profiles_sensitive_columns.sql` scritta e committata, **da eseguire manualmente** (vedi sopra).

### Frontend / Flutter
- ✅ Audit sistematico "await poi setState/context senza controllo mounted" su tutto `mobile/lib/` (32 file scansionati). Trovati e corretti **12 casi reali** in 7 file — stessa classe di bug del crash "Duplicate GlobalKey" già risolto in una fase precedente di questa sessione, semplicemente non era stata cercata sistematicamente ovunque:
  - `league_form_page.dart`, `auth_page.dart`, `join_league_page.dart`, `match_form_page.dart`, `profile_editor_page.dart`, `league_settings_page.dart`, `notifications_page.dart`.
  - Committato e pushato (`fix: guard setState/context with mounted after async gaps`).
- ✅ Audit gestione errori/resilienza in `kickly_repository.dart` e nelle pagine che lo chiamano (agente dedicato). Risultati sotto, in coda di lavorazione.

## In corso / prossimi passi (in ordine di priorità, dall'audit gestione errori)

**Alta priorità — azioni distruttive/importanti senza gestione errori:**
- [ ] `league_settings_page.dart`, funzione `delete()` (elimina lega): nessun try/catch né stato di caricamento — se fallisce, il bottone sembra "morto", nessun feedback.
- [ ] `league_detail_page.dart`, funzione `_leave()` (lascia lega): stesso problema.
- [ ] `match_result_page.dart`: mancano in `friendlyError()` i codici errore realistici della RPC `finalize_match` (`team_a_goals_mismatch`, `team_b_goals_mismatch`, `invalid_player_totals`, `player_totals_required`, `duplicate_team_player`, `teams_required`, `all_confirmed_players_required`) — un admin che sbaglia a inserire i gol dei singoli giocatori vede solo "Qualcosa non ha funzionato" invece di sapere cosa correggere.
- [ ] `match_detail_page.dart`: i bottoni RSVP (Ci sono/Forse/Non posso) restano visibili e cliccabili anche dopo che un admin chiude le iscrizioni (`registrationClosedAt`), causando un errore server generico invece che nascondere i bottoni o mostrare un messaggio chiaro. Manca anche l'entry `registrations_closed` in `friendlyError()`.

**Media priorità:**
- [ ] `notifications_page.dart`: `_open()` e `_markAll()` senza try/catch — con rete instabile toccare una notifica non fa nulla, senza messaggio.
- [ ] Tre `FutureBuilder` senza ramo `snapshot.hasError` (mostrano messaggi fuorvianti su errori di rete invece che un vero errore + retry): `player_profile_page.dart` ("profilo privato" invece di "errore di rete"), `league_settings_page.dart` ("accesso negato" invece di "errore di rete" — grave, dice a un admin legittimo che non ha i permessi), `match_result_page.dart` ("partita non trovata").
- [ ] Due codici RPC mancanti in `friendlyError()`: `mvp_voting_closed`, `max_below_confirmed`.
- [ ] Nessun timeout di rete esplicito da nessuna parte nel repository — su rete lenta/instabile lo spinner gira indefinitamente invece di fallire con un messaggio chiaro.

**Bassa priorità:**
- [ ] `league_detail_page.dart`: "Trasferisci proprietà" nel menu membro non ha dialog di conferma (a differenza di "Lascia lega"/"Elimina lega" che ce l'hanno) — un tap accidentale trasferisce irreversibilmente la proprietà della lega.

## Da fare / non completato
Aggiornato a fine sessione se il lavoro sopra non viene completato per esaurimento token.
