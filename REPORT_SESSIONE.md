# Report sessione autonoma — Affidabilità BE/FE, CI, qualità codice

Continuazione autonoma su richiesta esplicita dell'utente. Nessuna domanda posta salvo
un caso (scope della CI, con risposta ricevuta e implementata).

## Stato: tutto fatto, un solo passo manuale resta

Ogni cosa trovata in questa sessione è stata **corretta, verificata e pushata**. L'unica
cosa che non posso fare da qui è attivare la branch protection su GitHub (serve admin
sull'upstream `renatomancino/kickly`, io ho solo READ lì). Istruzioni pronte in
[`.github/BRANCH_PROTECTION.md`](.github/BRANCH_PROTECTION.md) — cinque minuti, una volta sola.

---

## Backend / Supabase

- **Falla di sicurezza chiusa e verificata in produzione**: `profiles.overall` (il rating
  del giocatore) era scrivibile direttamente da qualunque utente autenticato, bypassando
  il calcolo ufficiale post-partita. Stesso tipo di falla già trovata su `league_members`
  (grant ampio mai ristretto per colonna), ma questa era **attivamente sfruttabile**, non
  solo latente. Migrazione `20260814170000_lockdown_profiles_sensitive_columns.sql`
  applicata: verificato via query su `information_schema.column_privileges` che restano
  scrivibili solo le 13 colonne che l'app aggiorna davvero.
- Nella stessa migrazione, due pulizie minori: una policy morta su `player_rating_history`
  (stesso pattern, non sfruttabile perché il grant è già revocato, ma ripulita perché non
  torni viva per errore) e grant INSERT/DELETE ridondanti su `player_stats` senza policy
  corrispondente.
- Minimo password lato server alzato da 6 a 8 caratteri, allineandolo a quanto il client
  richiedeva già senza che il server lo garantisse davvero. Applicato e verificato live.
- Protezione contro password compromesse (HaveIBeenPwned): **non attivabile**, è una
  funzionalità del piano Supabase Pro e il progetto è su Free. Serve un upgrade a
  pagamento — decisione che spetta a te, non l'ho toccata.
- Security Advisor (0 errori, 32 warning — verificati uno a uno: sono tutte funzioni
  `SECURITY DEFINER` che controllano `auth.uid()` internamente, nessuna si fida di
  parametri esterni) e Performance Advisor (0 errori, 0 warning, solo indici non ancora
  usati — normale per un'app con poco traffico) passati in rassegna.
- Audit RLS completo su tutte le 22 migrazioni: ogni altra tabella risulta corretta,
  scritture solo via RPC `SECURITY DEFINER` con controllo esplicito del chiamante.

## Frontend mobile (Flutter)

- **12 crash potenziali corretti**: audit sistematico di tutto `mobile/lib/` per il
  pattern "`await`, poi `setState`/`BuildContext` su un widget ormai smontato" — la stessa
  causa del crash `Duplicate GlobalKey` già risolto in una fase precedente, semplicemente
  non era stato cercato ovunque. 7 file coinvolti.
- **Gestione errori sistemata** in tutto il data layer e nelle pagine che lo chiamano:
  azioni distruttive senza feedback ("Elimina lega", "Lascia lega" — il bottone sembrava
  morto su un fallimento), un'azione irreversibile senza conferma ("Trasferisci
  proprietà"), tre schermate che confondevano un errore di rete con "non
  trovato"/"accesso negato" (il caso peggiore: un admin legittimo a cui veniva detto che
  non aveva permessi), i bottoni di conferma presenza rimasti attivi dopo la chiusura
  iscrizioni, ~18 codici di errore RPC senza messaggio comprensibile (soprattutto sulla
  chiusura partita), nessun timeout di rete da nessuna parte — ora 15s centralizzati su
  ogni richiesta Supabase.
- **Lint Dart irrigidite**: `analysis_options.yaml` era ancora il template stock. Aggiunte
  7 regole, scelte una alla volta verificando che intercettassero bug veri e non rumore
  stilistico (`unawaited_futures`, `cancel_subscriptions`, `close_sinks`,
  `avoid_dynamic_calls`, ecc.). **Verificato con una prova concreta, non assunto**: il set
  di lint disponibile in Dart NON copre il pattern `setState` dopo `await` senza
  `if (mounted)` — ripristinando i file pre-fix e rilanciando l'analisi con tutte le
  regole nuove, zero segnalazioni sui bug reali. Il file lo dice esplicitamente, così chi
  lo legge non si illude di essere coperto.
- **Redesign area profilo** (privato, pubblico, editor) in stile Apple: header a
  scomparsa, overall come anello di progresso, tab Panoramica/Andamento, grafico
  dell'andamento rating, barra risultati. Due giri di correzione su feedback diretto.
- **Redesign pagina Leghe**: pillole al posto dei `Chip` Material, raggio d'angolo
  allineato al token del tema, ruolo (owner/admin) come unico elemento accentato — è
  l'unico dato che dice cosa puoi *fare*, non solo com'è fatta la lega. Corretto anche un
  allineamento verticale del logo scoperto solo guardando lo screenshot reale.
- `ProfileInfoPill` spostata da `features/profile/` a `core/widgets/common.dart` come
  `InfoPill`, condivisa ora da profilo e leghe invece di essere duplicata.
- Dipendenze: `cupertino_icons` e `supabase_flutter` aggiornate all'ultima patch.
  `flutter_secure_storage` e `flutter_local_notifications` lasciate pinnate: entrambe
  erano state fissate deliberatamente per risolvere build Android realmente rotte, un
  salto di versione richiederebbe un test reale su device.

## Frontend web (PWA Next.js) e SEO/privacy

- **Chiusa un'esposizione di privacy**: `/join/[code]` (il link di invito a una lega) era
  pubblica e senza alcun `robots.txt` — se un solo invito fosse finito indicizzato,
  chiunque avrebbe potuto cercarlo e infilarsi in una lega privata. Aggiunti tre strati:
  `robots.ts` (i crawler educati non richiedono nemmeno la pagina), meta `robots: noindex`
  di pagina, e header `X-Robots-Tag` in `next.config.ts` per `/api`, `/auth` e
  `/join` — quest'ultimo necessario perché `/join/[code]` risponde con un redirect a un
  visitatore anonimo, e un redirect non ha corpo HTML dove mettere un `<meta>`.
  `sitemap.ts` lista solo la landing, l'unica pagina pubblica che ha senso indicizzare.
- Da tenere presente: i profili pubblici (`player/[username]`) stanno dietro
  autenticazione, quindi non c'è contenuto indicizzabile da posizionare. Per un'app
  mobile-first la leva di scoperta è l'App Store Optimization, non la SEO — questo
  intervento è per l'esposizione dei codici invito, non per il traffico.

## CI/CD (nuova)

- Prima pipeline GitHub Actions del repo, 6 job in parallelo: `Flutter (analyze, test,
  format)`, `PWA (lint, typecheck, build)`, `Android (APK debug)`, `Secret scan
  (gitleaks)`, `npm audit`, `Migrazioni immutabili`.
- Vincolo di design: le PR arrivano dal fork `mariocelzo/kickly`, quindi girano senza
  secret e con token in sola lettura. Ogni job funziona a secchio vuoto;
  deliberatamente **non** uso `pull_request_target` (è il vettore noto per far rubare
  secret a una PR ostile da un fork).
- Il job Android è quello che vale di più: entrambe le rotture di build già viste in
  questa sessione (`flutter_secure_storage` su un'API Android inesistente, `workmanager`
  incompatibile con AGP 9) erano invisibili ad `analyze` e ai test, visibili solo a una
  build vera.
- **Il primo run reale ha trovato due bug veri**, che è esattamente il punto di eseguirla
  invece di limitarsi a scriverla:
  1. Il typecheck girava prima della build: i tipi generati da Next (`LayoutProps`) non
     esistevano ancora su un checkout pulito. Bug presente anche nello script
     `npm run check` del repo — rotto su qualunque clone vergine. Corretto l'ordine in
     entrambi, verificato con `rm -rf .next && npm run check` da zero.
  2. 17 file Dart mai passati per `dart format`. Formattati, isolati in un commit a parte
     perché il diff resti leggibile.
  3. `dart format` ha spezzato tre `if` su più righe, facendo scattare la regola che
     richiede le graffe. Corretto.
- Secondo run: verde su tutti e 6 i job, nessun avviso residuo (bump anche di
  `actions/cache` alla v5, ultima action rimasta sul runtime Node deprecato).
- `.github/pull_request_template.md` aggiunto.

## Verifiche eseguite

- `flutter analyze` e `flutter test` (16/16) puliti dopo ogni gruppo di modifiche.
- `npm run check` (lint + build + typecheck) pulito da checkout vergine.
- CI verde su un run reale di GitHub Actions, non solo YAML sintatticamente valido.
- Verifica live su iOS Simulator per le modifiche più rischiose (layout profilo, RSVP
  dopo chiusura iscrizioni, redesign Leghe) — uno degli allineamenti scorretti nella card
  Leghe è stato trovato proprio guardando lo screenshot, non nel codice.
- Migrazioni RLS (`league_members`, `profiles`) verificate in produzione con query di
  controllo, non solo "il file esiste".

## Da fare

Un solo passo, manuale per forza (richiede permessi che non ho): attivare la branch
protection sull'upstream seguendo [`.github/BRANCH_PROTECTION.md`](.github/BRANCH_PROTECTION.md).
