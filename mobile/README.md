# Kickly Mobile

App Flutter nativa per Android e iOS collegata allo stesso progetto Supabase della web app.

La versione mobile mantiene la parità funzionale con la PWA: dashboard, profili e player card pubbliche, leghe e inviti/deep link, comunicazioni, classifiche, gestione membri e impostazioni, partite pubbliche e vicine, RSVP, formazioni, strumenti admin, promemoria, risultati, statistiche e votazione MVP.

## Stack

- Flutter 3.47 / Dart 3.13
- `supabase_flutter` per Auth, Database, Storage e sessioni persistenti
- `go_router` per routing e deep link
- `flutter_local_notifications` + `workmanager` per i banner di sistema
- accesso diretto alle RPC Supabase già protette da RLS

Il font è **Geist**, lo stesso della PWA. Non essendo nel catalogo Google Fonts,
i TTF statici del release ufficiale `vercel/geist-font` sono impacchettati in
`assets/fonts/` (licenza SIL OFL 1.1 in `assets/fonts/LICENSE.txt`).

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
flutter build appbundle --release --dart-define-from-file=config.local.json --obfuscate --split-debug-info=build/debug-info
```

Build iOS (da macOS con Xcode):

```bash
flutter build ipa --release --dart-define-from-file=config.local.json --obfuscate --split-debug-info=build/debug-info
```

`--obfuscate` rinomina simboli e classi Dart nel binario compilato (più
difficile da decompilare/reverse-engineerare); `--split-debug-info` sposta le
mappe di simboli fuori dal pacchetto distribuito, in `build/debug-info`
(ignorato da git — vanno conservate da parte per poter poi decodificare gli
stack trace dei crash in produzione, altrimenti sono illeggibili).

Senza configurazione Supabase l'app offre una modalità demo locale dal login.

## Accesso con Google e Apple

Il codice è pronto (`lib/data/kickly_repository.dart`: `signInWithGoogle`,
`signInWithApple`), ma i due pulsanti restano nascosti o non funzionanti finché
non vengono configurate credenziali che appartengono agli account Google Cloud
e Apple Developer del proprietario — esattamente come già succede per FCM/APNs
nella sezione Notifiche. Nessuna di queste credenziali va mai messa nel
repository: solo in `config.local.json` (Google, già gitignorato) o nella
dashboard Supabase (Apple).

### Google

Il pulsante Google resta nascosto finché `GOOGLE_SERVER_CLIENT_ID` non è
valorizzato in `config.local.json`: è lo stesso pattern con cui la demo locale
si attiva quando Supabase non è configurato.

1. In [Google Cloud Console](https://console.cloud.google.com/apis/credentials),
   nello stesso progetto (o in uno collegato) al progetto Supabase, crea due
   **OAuth Client ID**:
   - tipo **Web application** → questo è `GOOGLE_SERVER_CLIENT_ID`. Determina
     l'audience dell'ID token, quindi è anche quello da incollare in Supabase
     Dashboard → Authentication → Providers → Google → *Authorized Client
     IDs*.
   - tipo **iOS**, con bundle ID `com.kickly.app` → questo è
     `GOOGLE_IOS_CLIENT_ID`.
   - Per Android **non** serve un terzo Client ID separato da inserire nel
     codice: Google riconosce l'app dal **nome del pacchetto** (`com.kickly.app`)
     e dallo **SHA-1 del certificato di firma**. Vanno registrati nella stessa
     console (Credentials → Create credentials → OAuth client ID → Android),
     una voce per lo SHA-1 di debug (`cd ios/.. && cd android && ./gradlew
     signingReport`, o `keytool -list -v -keystore
     ~/.android/debug.keystore -alias androiddebugkey -storepass android`) e
     una per quello di release (dal keystore in `android/key.properties`, vedi
     sotto).
2. In Supabase Dashboard → Authentication → Providers → **Google**: attiva il
   provider e incolla il Client ID Web al punto sopra.
3. In `config.local.json` aggiungi `GOOGLE_SERVER_CLIENT_ID` e
   `GOOGLE_IOS_CLIENT_ID` (vedi `config.example.json`).
4. In `ios/Runner/Info.plist`, dentro `CFBundleURLTypes`, sostituisci
   `com.googleusercontent.apps.REPLACE_WITH_IOS_CLIENT_ID` con il
   `REVERSED_CLIENT_ID` del Client ID iOS (è il Client ID con i segmenti in
   ordine inverso, es. `com.googleusercontent.apps.861823949799-abc123`). Su
   Android non serve toccare nulla lato manifest.

### Apple

Il pulsante Sign in with Apple compare solo su iOS (le linee guida App Store lo
rendono obbligatorio quando l'app offre anche un altro login social; su
Android il flusso via webview esiste ma non è collegato, dato che è raro che
serva davvero).

1. In [Apple Developer](https://developer.apple.com/account/resources/identifiers/list),
   abilita la capability **Sign In with Apple** sull'App ID `com.kickly.app`
   (il file `ios/Runner/Runner.entitlements` è già pronto lato codice, ma la
   capability va dichiarata anche lì).
2. Crea un **Services ID** (un identificatore separato dall'App ID, es.
   `com.kickly.app.signin`) e una **chiave privata** per Sign in with Apple
   (Certificates, Identifiers & Profiles → Keys).
3. In Supabase Dashboard → Authentication → Providers → **Apple**: attiva il
   provider e inserisci Services ID, Team ID, Key ID e la chiave privata
   generata al passo precedente.
4. Nessuna chiave va copiata nel codice mobile: su iOS il flusso è
   interamente nativo (`ASAuthorizationController`) e non richiede client ID
   né redirect URI lato app.

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

## Sicurezza

- **Sessione in Keychain/Keystore.** `supabase_flutter` di default persiste
  access e refresh token in `SharedPreferences`/`NSUserDefaults`, in chiaro.
  `lib/core/security/secure_session_storage.dart` li fa passare invece per
  `flutter_secure_storage` (Android Keystore con AES-GCM + wrapping RSA,
  iOS Keychain con `first_unlock`). Effetto collaterale voluto: chi aveva già
  una sessione salvata col vecchio storage viene disconnesso una volta sola
  al primo avvio dopo l'aggiornamento, perché il nuovo storage parte vuoto.
- **Nessun backup automatico.** `android:allowBackup="false"` in
  `AndroidManifest.xml`: l'app non finisce nel backup Google Drive né nel
  trasferimento dati fra dispositivi Android.
- **Signing di release vero, non la chiave di debug.** Il template Flutter
  firma i build di release con la chiave di debug finché non gli si dice
  altrimenti. `android/app/build.gradle.kts` ora legge un
  `android/key.properties` locale (vedi `key.properties.example`, gitignorato)
  e usa quella chiave se presente; senza, ricade sul comportamento di prima.
  Un APK/AAB firmato con la chiave di debug non è comunque distribuibile su
  Play Store.
- **Nonce anti-replay su Apple.** `lib/core/security/oauth_nonce.dart` genera
  il nonce con `Random.secure()` (CSPRNG, non un `Random()` qualsiasi) e lo
  invia hashato ad Apple, in chiaro a Supabase: previene il riutilizzo di un
  ID token intercettato per un'altra sessione.
- **RLS e funzioni `security definer`** sono già la base delle migrazioni in
  `../supabase/migrations`: ogni tabella sensibile ha RLS abilitata, le RPC
  che bypassano RLS sono `set search_path = ''` (evita l'hijack dello schema
  di risoluzione) e concedono `execute` solo a `authenticated`, mai a `anon`.
  Non è cambiato nulla qui, ma vale la pena saperlo prima di aggiungerne di
  nuove.
- **Build di release offuscate.** `--obfuscate --split-debug-info` (vedi sopra)
  su Android e iOS: senza, chiunque può decompilare l'APK/IPA e leggere nomi
  di classi/metodi/stringhe quasi come nel sorgente originale.

Cosa manca volutamente, e perché: niente certificate pinning (aggiunge
fragilità ad ogni rotazione del certificato TLS, senza un threat model
specifico che lo richieda qui) e nessun lock biometrico dell'app (è una
feature a sé — schermata di blocco, impostazione per attivarla/disattivarla —
non un hardening puntuale; va discussa a parte se serve davvero).
