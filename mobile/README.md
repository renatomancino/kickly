# Kickly Mobile

App Flutter nativa per Android e iOS collegata allo stesso progetto Supabase della web app.

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

Il client mobile riusa tabelle, Storage, trigger, RLS e RPC già presenti in `../supabase`. Le notifiche in-app sono operative tramite la tabella `notifications`. Le notifiche push di sistema richiedono inoltre le credenziali APNs/FCM del proprietario degli account Apple e Google; non vengono inserite nel client né nel repository.
