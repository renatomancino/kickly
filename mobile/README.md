# Kickly Mobile

App Flutter nativa per Android e iOS collegata allo stesso progetto Supabase della web app.

La versione mobile mantiene la parità funzionale con la PWA: dashboard, profili e player card pubbliche, leghe e inviti/deep link, comunicazioni, classifiche, gestione membri e impostazioni, partite pubbliche e vicine, RSVP, formazioni, strumenti admin, promemoria, risultati, statistiche e votazione MVP.

## Stack

- Flutter 3.47 / Dart 3.13
- `supabase_flutter` per Auth, Database, Storage e sessioni persistenti
- `go_router` per routing e deep link
- accesso diretto alle RPC Supabase già protette da RLS

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

Le notifiche in-app sono operative tramite la stessa tabella `notifications` della PWA. Flutter mostra quindi lo stesso titolo, lo stesso messaggio e apre lo stesso link; gli inserimenti vengono ascoltati anche in Realtime. Su Android sono già configurati il permesso notifiche, il marchio Kickly e il colore `#C7FF3D` da usare come icona/colore predefiniti.

Le notifiche push di sistema quando l'app è chiusa richiedono un canale mobile diverso dal Web Push della PWA: occorrono `google-services.json`/credenziali FCM per Android e APNs per iOS, più il relativo sender server-side. Questi segreti appartengono agli account Google e Apple del proprietario e non devono essere inseriti nel repository. Finché non vengono forniti, restano operative le notifiche in-app e Realtime, non il banner di sistema a processo terminato.
