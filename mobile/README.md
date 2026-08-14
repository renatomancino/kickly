# Kickly Mobile

App Flutter nativa per Android e iOS collegata allo stesso progetto Supabase della web app.

La versione mobile mantiene la parità funzionale con la PWA: dashboard, profili e player card pubbliche, leghe e inviti/deep link, comunicazioni, classifiche, gestione membri e impostazioni, partite pubbliche e vicine, RSVP, formazioni, strumenti admin, promemoria, risultati, statistiche e votazione MVP.

## Stack

- Flutter 3.47 / Dart 3.13
- `supabase_flutter` per Auth, Database, Storage e sessioni persistenti
- `go_router` per routing e deep link
- `flutter_local_notifications` + `workmanager` per i banner di sistema
- `google_fonts` (Inter) per avvicinare la tipografia a quella della PWA
- accesso diretto alle RPC Supabase già protette da RLS

Android richiede il core library desugaring (già abilitato in
`android/app/build.gradle.kts`), necessario a `flutter_local_notifications`.

## Configurazione

1. Copia `config.example.json` in `config.local.json`.
2. Inserisci URL e **publishable key** del progetto Supabase. Non usare mai `service_role` nell'app.
3. In Supabase Dashboard > Authentication > URL Configuration aggiungi:
   `io.kickly.app://login-callback/`

Avvio:

```powershell
flutter pub get
flutter run --dart-define-from-file=config.local.json
```

Build Android:

```powershell
flutter build appbundle --release --dart-define-from-file=config.local.json
```

Build iOS (da macOS con Xcode):

```bash
flutter build ipa --release --dart-define-from-file=config.local.json
```

Senza configurazione Supabase l'app offre una modalità demo locale dal login.

## Backend

Il client mobile riusa tabelle, Storage, trigger, RLS e RPC già presenti in `../supabase` senza duplicare la logica di business nel telefono.

La migrazione `20260813214256_nearby_matches_field_booking.sql` aggiunge:

- località italiane verificate con comune, provincia e coordinate private del profilo;
- distanza delle partite pubbliche dalla località dell'utente;
- copertina della partita, foto del campo e bucket Storage protetto;
- telefono e conferma della prenotazione del campo con notifica ai partecipanti;
- quota individuale calcolata dal costo totale e dal numero di giocatori.

Prima di usare queste funzioni su un progetto remoto, applica le migrazioni Supabase con la normale procedura di link e `supabase db push`. Le coordinate personali sono conservate in `profile_locations`, protetta da RLS e leggibile soltanto dal proprietario.

## Notifiche

Le notifiche vivono nella stessa tabella `notifications` della PWA, quindi titolo,
messaggio e link sono identici sui due client. La consegna avviene su tre livelli:

1. **App in primo piano** — il canale Realtime su `notifications` mostra una
   SnackBar in-app con azione "Apri" verso il link della notifica.
2. **App in background ma viva** — la stessa notifica Realtime viene pubblicata
   come banner di sistema tramite `flutter_local_notifications`, sul canale
   `kickly_notifications` (importanza alta, colore `#C7FF3D`). Toccando il banner
   l'app apre il link della notifica, anche se era stata chiusa.
3. **App terminata** — un task periodico `workmanager`
   (`lib/core/notifications/background_sync.dart`) rilegge le notifiche non lette
   da Supabase e le pubblica come banner. Un cursore in `SharedPreferences` evita
   che la stessa notifica venga mostrata due volte.

Limiti del terzo livello, da conoscere:

- su Android WorkManager non scende sotto i 15 minuti di intervallo e il task non
  gira se l'utente forza la chiusura dell'app dalle impostazioni di sistema;
- su iOS `BGAppRefreshTask` è opportunistico: il sistema decide quando concederlo
  in base a quanto l'app viene usata, quindi l'attesa può essere molto più lunga.
  L'identificatore `kickly-notification-poll-unique` è dichiarato in
  `ios/Runner/Info.plist` e registrato in `AppDelegate.swift`.

Per un avviso **immediato** ad app chiusa serve un canale push vero: FCM per
Android e APNs per iOS, più il sender server-side. Servono `google-services.json`
e le credenziali APNs, che appartengono agli account Google e Apple del
proprietario e non vanno messe nel repository. Finché non ci sono, valgono i tre
livelli sopra.
