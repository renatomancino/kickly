# iOS Debug Build in CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aggiungere un job `ios-build` a `.github/workflows/ci.yml` che compila l'app in modalita' debug senza firma, solo su push a `main`, sullo stesso schema del job `android-build` esistente.

**Architecture:** Nuovo job su `runs-on: macos-latest`, trigger ristretto a `push` su `main` (non sulle PR: e' un job nuovo, non ancora rodato in produzione, meglio non allungare il feedback loop di ogni PR finche' non si dimostra stabile). Riusa lo stesso pattern di configurazione fittizia gia' in uso nel job `android-build` per `mobile/config.local.json`.

**Tech Stack:** Flutter/Xcode, `flutter build ios --no-codesign`.

Riferimento: `docs/superpowers/specs/2026-08-20-github-cicd-agents-design.md`, sezione A4.

**Nota importante, gia' verificata prima di scrivere questo piano:** il rischio
segnalato nella spec (l'entitlement `com.apple.developer.applesignin` in
`mobile/ios/Runner/Runner.entitlements`, richiesto da `sign_in_with_apple`,
potrebbe far fallire un build senza firma) e' stato testato **in locale** con
Flutter 3.47.0 + Xcode 26.6: `flutter build ios --debug --no-codesign
--dart-define-from-file=config.local.json` completa con successo
(`✓ Built build/ios/iphoneos/Runner.app`, ~70s di build Xcode). Il job puo'
quindi essere scritto senza clausole di fallback per questo rischio.

---

### Task 1: Job `ios-build`

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Aggiungi il job**

Aggiungi subito dopo il job `android-build` esistente in
`.github/workflows/ci.yml` (stessa indentazione a 2 spazi):

```yaml
  # ---------------------------------------------------------------------------
  # Build iOS di debug, senza firma. Stesso spirito del job Android sopra:
  # una build vera intercetta rotture che `flutter analyze`/`flutter test`
  # non vedono (Swift Package Manager, CocoaPods, configurazione Xcode).
  # Verificato in locale (Flutter 3.47.0 + Xcode 26.6) che
  # `--no-codesign` completa con successo anche con l'entitlement Sign In
  # with Apple presente in Runner.entitlements: la validazione delle
  # capability avviene in fase di firma, che qui e' disattivata.
  # Trigger SOLO push su main, non sulle PR: e' un job nuovo, non ancora
  # rodato in produzione. Si allarga alle PR in futuro se si dimostra
  # stabile e sufficientemente veloce da non allungare il feedback loop.
  # I runner macOS sono gratuiti quanto quelli Linux sui repository
  # pubblici (il moltiplicatore di costo Actions vale solo sui privati).
  # ---------------------------------------------------------------------------
  ios-build:
    name: iOS (debug, no-codesign)
    runs-on: macos-latest
    timeout-minutes: 25
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v7

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true

      # Stessa configurazione fittizia usata nel job android-build: al
      # compilatore serve solo che i valori esistano e siano stringhe, non
      # che puntino a un backend raggiungibile (vedi commento esteso nel
      # job android-build per il ragionamento completo).
      - name: Genera una configurazione fittizia per la compilazione
        working-directory: mobile
        run: |
          cat > config.local.json <<'JSON'
          {
            "SUPABASE_URL": "https://ci-placeholder-not-a-real-project.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_ci_placeholder_value_not_a_real_key",
            "GOOGLE_SERVER_CLIENT_ID": "000000000000-ciplaceholderserver.apps.googleusercontent.com",
            "GOOGLE_IOS_CLIENT_ID": "000000000000-ciplaceholderios.apps.googleusercontent.com"
          }
          JSON

      - name: Risolvi le dipendenze
        working-directory: mobile
        run: flutter pub get

      - name: Build iOS di debug (senza firma)
        working-directory: mobile
        run: flutter build ios --debug --no-codesign --dart-define-from-file=config.local.json
```

- [ ] **Step 2: Verifica sintattica locale**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo OK`
Expected: `OK`

- [ ] **Step 3: Riverifica in locale che la build passi ancora (facoltativo ma consigliato, e' gia' stato provato una volta)**

Run (dalla root del repo):
```bash
cd mobile
cat > config.local.json <<'JSON'
{
  "SUPABASE_URL": "https://ci-placeholder-not-a-real-project.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_ci_placeholder_value_not_a_real_key",
  "GOOGLE_SERVER_CLIENT_ID": "000000000000-ciplaceholderserver.apps.googleusercontent.com",
  "GOOGLE_IOS_CLIENT_ID": "000000000000-ciplaceholderios.apps.googleusercontent.com"
}
JSON
flutter pub get
flutter build ios --debug --no-codesign --dart-define-from-file=config.local.json
rm -f config.local.json
rm -rf build/ios
```
Expected: ultima riga `✓ Built build/ios/iphoneos/Runner.app`. Lo step finale
rimuove sia il config fittizio sia l'output di build (`config.local.json` e
`build/` sono gia' in `.gitignore`, quindi non compaiono in `git status`, ma
ripulirli evita di lasciare artefatti inutili nella working copy).

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: aggiunge la build iOS di debug (solo push su main)"
```

- [ ] **Step 5 (verifica reale, solo dopo il merge in main)**

Questo job non gira sulla PR (trigger `push` + `ref == main`), quindi la
prima esecuzione reale avviene solo dopo il merge. Dopo il merge, controllare
su GitHub Actions che il run su `main` includa il job `iOS (debug,
no-codesign)` e che sia verde.

---

## Nota finale per chi esegue il piano

Se in futuro emergesse un motivo per allargare questo job anche alle PR
(es. dopo qualche settimana senza rotture), la modifica e' minima: cambiare
la condizione `if` da `github.event_name == 'push' && github.ref ==
'refs/heads/main'` a nessuna condizione (girerebbe sugli stessi trigger di
`android-build`). Non c'e' bisogno di riscrivere il job.
