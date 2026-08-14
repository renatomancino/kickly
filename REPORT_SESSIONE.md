# Report sessione autonoma — Affidabilità BE/FE

Continuazione autonoma su richiesta esplicita dell'utente: "continua a fare migliorie lato BE ed FE fino ad esaurimento dei tkn senza domandare nulla [...] genera un report e cerca di portare le task a termine [...] altrimenti scrivi nel report quello che manca". Nessuna domanda posta.

## ⚠️ AZIONE MANUALE RICHIESTA — unica cosa rimasta da fare

**Ho trovato una vulnerabilità di sicurezza reale e attiva (non teorica) sul database di produzione, ma NON ho potuto applicare la fix dal vivo**: il classificatore di sicurezza della modalità autonoma ha bloccato l'esecuzione di SQL di REVOKE/DROP POLICY su produzione senza supervisione (giustamente — è la categoria di azione giusta da bloccare in autonomia, tocca dati di produzione). La fix è scritta e committata nel repo, ma **serve che tu la esegua manualmente**:

1. Apri il [SQL Editor di Supabase](https://supabase.com/dashboard/project/rluxuylutaervjbtexgq/sql/new)
2. Incolla ed esegui il contenuto di [`supabase/migrations/20260814170000_lockdown_profiles_sensitive_columns.sql`](supabase/migrations/20260814170000_lockdown_profiles_sensitive_columns.sql)
3. Verifica (opzionale) che sia andata a buon fine:
   ```sql
   select column_name from information_schema.column_privileges
   where table_name = 'profiles' and grantee = 'authenticated' and privilege_type = 'UPDATE';
   ```
   Deve restituire solo le colonne elencate nella migrazione (non `overall`, `id`, `created_at`, `timezone`).

**Qual è il problema**: qualunque utente autenticato può oggi eseguire (es. da supabase-js o da un client HTTP qualsiasi, non serve passare dall'app) `update profiles set overall = 99 where id = auth.uid()` e falsificare il proprio rating (1-99) a piacere, bypassando completamente il calcolo ufficiale che avviene dopo ogni partita. Il valore falso resta visibile su profilo e classifiche finché quell'utente non gioca un'altra partita vera. È lo stesso tipo di falla già trovata e corretta questa sessione su `league_members` (grant ampio mai ristretto per questa tabella specifica), ma qui è **attualmente sfruttabile**, non solo latente. **Questo è l'unico elemento rimasto in sospeso di tutta la sessione.**

---

## Riassunto: tutto il resto è stato completato e pushato

### Redesign profilo (prima di questa fase BE/FE)
- Area profilo (privato, pubblico, editor) rifatta in stile Apple: header a scomparsa, overall come anello di progresso, tab switch Panoramica/Andamento, grafico dell'andamento rating, barra risultati. Include due giri di correzione su feedback diretto: un overflow di layout e un bug del titolo della testata, poi un secondo giro perché il selettore di tab non combaciava con i bordi delle card sotto.
- PR [renatomancino/kickly#2](https://github.com/renatomancino/kickly/pull/2) aperta e aggiornata con screenshot e testo.
- SMTP/email: tornato al default Supabase (no dominio necessario), confermato che "Confirm email" era già disattivato — l'unica mail che l'app invia davvero è il reset password.

### Backend / Supabase
- **Sicurezza — `profiles.overall`**: vedi sezione rossa sopra, unico elemento non completabile in autonomia.
- **Sicurezza — pulizia RLS minore**: policy morta su `player_rating_history` (stesso pattern di `league_members`, non sfruttabile oggi perché il grant è già revocato, ma ripulita per non poter tornare viva per errore) e grant INSERT/DELETE ridondanti su `player_stats` senza policy corrispondente (igiene, nessun rischio reale). Stessa migrazione di cui sopra, quindi anche questi due punti aspettano l'esecuzione manuale.
- **Sicurezza — password**: alzato il minimo lato server da 6 a 8 caratteri (era già richiesto lato client senza che il server lo garantisse davvero) — applicato e verificato live. La protezione contro password compromesse (HaveIBeenPwned) è disponibile solo sul piano Supabase Pro (il progetto è su Free) — non toccabile senza upgrade a pagamento, decisione che spetta a te.
- **Advisor**: controllati Security Advisor (0 errori; 32 warning, quasi tutti "funzione SECURITY DEFINER eseguibile da utenti loggati" — verificato che ognuna controlla `auth.uid()` internamente, nessuna si fida di parametri esterni; nessuna azione necessaria) e Performance Advisor (0 errori, 0 warning, 20 "Unused Index" — normale per un'app giovane con poco traffico).
- **Audit RLS completo**: lette tutte le 22 migrazioni per ogni tabella con RLS attivo. Tutte le tabelle diverse da `profiles`/`player_rating_history`/`player_stats` risultano già corrette (scritture solo via RPC `SECURITY DEFINER` con controllo esplicito di `auth.uid()`).

### Frontend / Flutter
- **Crash potenziali**: audit sistematico di tutto `mobile/lib/` (32 file) per il pattern "await poi `setState`/`context` senza controllo `mounted`" — la stessa classe di bug del crash "Duplicate GlobalKey" già risolto in una fase precedente della sessione, semplicemente non era stata cercata sistematicamente ovunque. Trovati e corretti **12 casi reali** in 7 file (`league_form_page.dart`, `auth_page.dart`, `join_league_page.dart`, `match_form_page.dart`, `profile_editor_page.dart`, `league_settings_page.dart`, `notifications_page.dart`).
- **Gestione errori/resilienza**: audit dedicato di `kickly_repository.dart` e delle pagine che lo chiamano. Corretto tutto quello che è emerso:
  - "Elimina lega" e "Lascia lega" non avevano try/catch né stato di caricamento — su un fallimento il bottone sembrava morto, senza alcun feedback. Ora entrambi mostrano l'errore e si disabilitano durante l'operazione.
  - "Trasferisci proprietà" nel menu membri di una lega era l'unica azione distruttiva senza dialog di conferma — un tap accidentale trasferiva la proprietà in modo irreversibile. Aggiunta conferma.
  - I bottoni di conferma presenza (Ci sono/Forse/Non posso) restavano visibili e cliccabili anche dopo che un admin chiudeva le iscrizioni, causando un errore generico invece di sparire con una spiegazione chiara.
  - Tre schermate (profilo pubblico, impostazioni lega, chiusura partita) non distinguevano un errore di rete da "non trovato"/"accesso negato" — il caso peggiore era un admin legittimo a cui veniva detto che non aveva i permessi, quando in realtà la richiesta era solo caduta. Ora tutte e tre hanno un vero ramo di errore con "Riprova".
  - Aprire una notifica o "Leggi tutte" con rete instabile non faceva nulla, senza messaggio — ora gestito.
  - Aggiunte ~18 voci mancanti in `friendlyError()` (i messaggi comprensibili per gli errori delle RPC), trovate confrontando ogni `raise exception` nelle migrazioni con quelle già gestite: soprattutto i codici di `finalize_match` (chiusura partita — un admin che sbaglia i gol dei singoli giocatori ora sa cosa correggere invece di vedere "Qualcosa non ha funzionato"), voto MVP, iscrizioni chiuse, capienza.
  - Nessuna chiamata di rete nell'app aveva un timeout esplicito — su rete capitiva/assente lo spinner girava indefinitamente. Aggiunto un timeout centralizzato di 15s su tutte le richieste Supabase (REST/RPC/Storage/Auth) via un `http.Client` custom passato a `Supabase.initialize()`, invece di dover toccare ogni singola chiamata nel repository.
- **Dipendenze**: `cupertino_icons` e `supabase_flutter` aggiornati all'ultima patch (nessun rischio, nessuna API cambiata). `flutter_secure_storage` e `flutter_local_notifications` lasciati pinnati alle versioni attuali — entrambi erano stati fissati deliberatamente in una fase precedente della sessione per risolvere build Android realmente rotte, e un salto di versione (specie i 3 major di flutter_local_notifications) richiederebbe un test reale su device che non è disponibile ora che sei via.

### PWA (Next.js, `src/`)
- Non toccata (il focus di questa sessione, come tutta la sessione precedente, è sempre stato l'app mobile), ma verificata per sicurezza: `npm install` + `npm run lint` + `npm run typecheck` + `npm run build` tutti puliti, 0 vulnerabilità nelle dipendenze. Nessuna azione necessaria.

## Verifiche eseguite su tutto il lavoro sopra
- `flutter analyze` pulito dopo ogni gruppo di modifiche.
- `flutter test` pulito (16/16) dopo ogni gruppo di modifiche.
- Verifica live su iOS Simulator dopo le modifiche più rischiose (fix del layout del profilo, fix della logica RSVP `registrationClosedAt`) per confermare che non avessero rotto il caso normale.
- Tutti i commit pushati su `claude/flutter-app-improvements-3973bd` (branch della PR #2), con messaggi che spiegano il "perché" di ogni fix.

## Da fare
Solo l'esecuzione manuale della migrazione `profiles` descritta in cima a questo file. Tutto il resto identificato in questa sessione è stato completato.
