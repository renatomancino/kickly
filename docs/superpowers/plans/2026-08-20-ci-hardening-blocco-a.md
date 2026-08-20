# CI Hardening — Blocco A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aggiungere alla CI esistente sei controlli gratuiti (CODEOWNERS, lint del titolo PR, dependency review, coverage Flutter, smoke test delle migrazioni Supabase, toggle nativi di sicurezza) senza toccare i job gia' esistenti in `.github/workflows/ci.yml`.

**Architecture:** Nuovi job aggiunti a `.github/workflows/ci.yml` seguendo lo stile gia' in uso nel file (commenti in italiano che spiegano il "perche'", permessi minimi espliciti, `timeout-minutes` su ogni job, `if: github.event_name == 'pull_request'` sui job che hanno senso solo su una PR); un nuovo file `.github/CODEOWNERS`; un aggiornamento di `.github/BRANCH_PROTECTION.md` per documentare il toggle nativo (impostazione manuale, non automatizzabile da codice) e i nuovi check nella tabella dei controlli obbligatori.

**Tech Stack:** GitHub Actions, `actions/dependency-review-action@v4`, `amannn/action-semantic-pull-request@v6`, `supabase/setup-cli@v1`, Flutter/Dart, awk (per il riepilogo coverage, per non introdurre una dipendenza su `lcov` che non e' preinstallato sui runner `ubuntu-latest`).

Riferimento: `docs/superpowers/specs/2026-08-20-github-cicd-agents-design.md`, sezioni A1, A2, A3, A5, A6, A7.

---

### Task 1: CODEOWNERS (A2)

**Files:**
- Create: `.github/CODEOWNERS`

- [ ] **Step 1: Crea il file**

```
# Con un team di due persone non serve dividere per area: entrambi devono
# rivedere tutto. Aggiungere righe piu' specifiche qui se il progetto cresce
# (es. "mobile/ @mariocelzo" per assegnare la parte Flutter a una persona sola).
* @mariocelzo @renatomancino
```

- [ ] **Step 2: Verifica locale del formato**

Run: `cat .github/CODEOWNERS`
Expected: il contenuto sopra, nessun errore di sintassi visibile (righe vuote
o che iniziano con `#` sono commenti, il resto e' `pattern owner1 owner2`).

- [ ] **Step 3: Commit**

```bash
git add .github/CODEOWNERS
git commit -m "ci: aggiunge CODEOWNERS per richiedere review su ogni PR"
```

- [ ] **Step 4 (dopo il push, verifica manuale su GitHub — non automatizzabile in locale)**

Apri `https://github.com/mariocelzo/kickly/blob/<branch>/.github/CODEOWNERS`
su GitHub: la pagina del file mostra un banner "This is your CODEOWNERS
file!" con un segno di spunta verde se la sintassi e' valida, o l'elenco
degli errori riga per riga se non lo e'.

---

### Task 2: Lint del titolo PR — conventional commits (A7)

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Aggiungi il job**

Aggiungi in coda a `.github/workflows/ci.yml` (dopo il job `migrations-check`,
stessa indentazione a 2 spazi degli altri job):

```yaml
  # ---------------------------------------------------------------------------
  # Intercetta: titoli di PR che non seguono un formato riconoscibile. Non
  # cambia nulla oggi, ma e' il prerequisito per generare un changelog
  # automatico in futuro senza dover riscrivere la storia delle PR passate.
  # Legge il titolo dal payload dell'evento pull_request, quindi non serve
  # nessun permesso di scrittura sul token.
  # ---------------------------------------------------------------------------
  pr-title-lint:
    name: Titolo PR (conventional commits)
    runs-on: ubuntu-latest
    timeout-minutes: 5
    if: github.event_name == 'pull_request'
    steps:
      - name: Verifica il formato del titolo
        uses: amannn/action-semantic-pull-request@v6
```

- [ ] **Step 2: Verifica sintattica locale del file YAML**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo OK`
Expected: `OK` (nessuna eccezione di parsing).

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: aggiunge il lint del titolo PR in stile conventional commits"
```

- [ ] **Step 4 (verifica reale, quando si apre la PR di questo stesso lavoro)**

La PR che raccoglie questi task e' il primo test reale: dalle al titolo un
prefisso conventional-commit, es. `ci: aggiunge controlli gratuiti alla
pipeline` — il job `pr-title-lint` deve comparire verde nei check della PR.

---

### Task 3: Dependency Review (A1)

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Aggiungi il job**

Aggiungi dopo il job `pr-title-lint` creato nel Task 2:

```yaml
  # ---------------------------------------------------------------------------
  # Intercetta: dipendenze vulnerabili o con licenza incompatibile introdotte
  # dal DIFF della PR. `npm audit` (job sopra) controlla l'intero lockfile ma
  # solo quando gira, non il delta introdotto: questo job guarda esattamente
  # cosa cambia in questa PR rispetto alla base. Nessun permesso di scrittura:
  # legge solo i manifest delle dipendenze, non esegue nulla del codice della PR.
  # ---------------------------------------------------------------------------
  dependency-review:
    name: Dependency review
    runs-on: ubuntu-latest
    timeout-minutes: 5
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v7

      - name: Analizza le dipendenze introdotte dalla PR
        uses: actions/dependency-review-action@v4
        with:
          fail-on-severity: high
          comment-summary-in-pr: never
```

- [ ] **Step 2: Verifica sintattica locale**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: aggiunge dependency review sul diff delle PR"
```

- [ ] **Step 4 (verifica reale sulla PR)**

Il job deve comparire verde sulla PR di questo lavoro (nessuna dipendenza
vulnerabile viene introdotta da questi task). Per verificare che il job
*sappia* fallire, facoltativo: in un branch scratch a parte aggiungere
temporaneamente una dipendenza npm con una CVE nota di severita' alta (es.
una versione vecchia di `lodash`), aprire una PR di prova, osservare il rosso,
poi chiudere la PR di prova senza mergiarla.

---

### Task 4: Coverage tracking Flutter (A6)

**Files:**
- Modify: `.github/workflows/ci.yml` (job `flutter`, step `Test`)

- [ ] **Step 1: Verifica in locale che `flutter test --coverage` produca il file**

Run (dalla root del repo):
```bash
cd mobile && flutter test --coverage && ls coverage/
```
Expected: il comando termina con i test verdi (stesso esito di `flutter test`
oggi) e la directory `coverage/` contiene `lcov.info`.

- [ ] **Step 2: Verifica in locale il calcolo del riepilogo**

Run (sempre da `mobile/`):
```bash
awk -F',' '/^DA:/{total++; if ($2>0) covered++} END{printf "Righe coperte: %d/%d (%.1f%%)\n", covered, total, (covered/total)*100}' coverage/lcov.info
```
Expected: una riga tipo `Righe coperte: 842/910 (92.5%)` (i numeri reali
dipendono dallo stato attuale dei test, l'importante e' che non dia errore
e produca una percentuale plausibile fra 0 e 100).

- [ ] **Step 3: Applica la modifica al workflow**

In `.github/workflows/ci.yml`, nel job `flutter`, sostituisci lo step `Test`
esistente:

```yaml
      - name: Test
        working-directory: mobile
        run: flutter test
```

con:

```yaml
      - name: Test
        working-directory: mobile
        run: flutter test --coverage

      # Solo un riepilogo nella UI di Actions, non un gate: l'obiettivo e'
      # rendere visibile il trend nel tempo, non bloccare la PR su una soglia
      # arbitraria di copertura. `awk` invece di `lcov` perche' quest'ultimo
      # non e' preinstallato sui runner ubuntu-latest e non vale la pena
      # installarlo per un conteggio a una riga.
      - name: Riepilogo copertura
        working-directory: mobile
        run: |
          echo "### Copertura test Flutter" >> "$GITHUB_STEP_SUMMARY"
          awk -F',' '/^DA:/{total++; if ($2>0) covered++} END{printf "Righe coperte: %d/%d (%.1f%%)\n", covered, total, (covered/total)*100}' coverage/lcov.info >> "$GITHUB_STEP_SUMMARY"
```

- [ ] **Step 4: Verifica sintattica locale**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo OK`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: aggiunge il riepilogo di coverage al job Flutter"
```

- [ ] **Step 6 (verifica reale sulla PR)**

Sulla PR, aprire il run del job `Flutter (analyze, test, format)` e
verificare che compaia la sezione "Copertura test Flutter" nel Job Summary.

---

### Task 5: Smoke test sulle migrazioni Supabase (A5)

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Verifica in locale che lo stack si avvii e applichi le migrazioni**

Run (dalla root del repo, richiede Docker attivo):
```bash
supabase start
supabase db reset
```
Expected: `supabase start` scarica/avvia i container e stampa le credenziali
locali; `supabase db reset` ricrea il database da zero e applica in ordine
tutti i file in `supabase/migrations/`, terminando con `Finished supabase db
reset` senza errori SQL. Se una migrazione ha un errore di sintassi, questo
comando fallisce qui — esattamente il caso che il job CI deve intercettare.

- [ ] **Step 2: Ferma lo stack locale**

Run: `supabase stop`
Expected: i container si fermano senza errori.

- [ ] **Step 3: Aggiungi il job**

Aggiungi dopo il job `dependency-review` creato nel Task 3:

```yaml
  # ---------------------------------------------------------------------------
  # Intercetta: errori SQL o problemi di ordine/dipendenza nelle migrazioni
  # NUOVE introdotte da questa PR. `migrations-check` (sopra) verifica solo
  # che le migrazioni GIA' esistenti non vengano toccate — non dice nulla
  # sulla validita' di quelle nuove. Qui si applica l'intera sequenza di
  # migrazioni su un Postgres locale vero (via Docker, gratuito sui runner
  # pubblici): un errore di sintassi o un vincolo violato fa fallire il job
  # invece di scoprirsi al primo deploy sul progetto Supabase reale.
  # Gira solo sulle PR: l'obiettivo e' validare cio' che la PR aggiunge, non
  # ri-validare ogni volta lo storico gia' verificato in main.
  # ---------------------------------------------------------------------------
  supabase-migrations-apply:
    name: Migrazioni Supabase (apply pulito)
    runs-on: ubuntu-latest
    timeout-minutes: 10
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v7

      - uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Avvia lo stack locale e applica tutte le migrazioni
        run: |
          supabase start
          supabase db reset

      - name: Ferma lo stack
        if: always()
        run: supabase stop
```

- [ ] **Step 4: Verifica sintattica locale**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo OK`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: aggiunge lo smoke test di apply delle migrazioni Supabase"
```

- [ ] **Step 6 (verifica reale sulla PR)**

Il job deve comparire verde sulla PR di questo lavoro. Per verificare che
sappia fallire, facoltativo: su un branch scratch aggiungere temporaneamente
un file in `supabase/migrations/` con un errore SQL deliberato (es.
`SELECT FROM;`), aprire una PR di prova, osservare il rosso, poi chiudere
senza mergiare.

---

### Task 6: Documentazione — toggle nativi e aggiornamento tabella check (A3)

**Files:**
- Modify: `.github/BRANCH_PROTECTION.md`

- [ ] **Step 1: Aggiungi la sezione sui toggle nativi**

In `.github/BRANCH_PROTECTION.md`, subito dopo la sezione `## L'altro
interruttore da accendere, mentre sei nelle impostazioni` (quella sui
Dependabot alerts) e prima di `## Cosa NON serve`, inserisci una nuova
sezione:

```markdown
## Secret scanning e push protection nativi

Un terzo interruttore nello stesso posto (`Settings` → `Advanced Security` /
`Code security`): **Secret scanning** e **Push protection**.

Non sostituiscono gitleaks (il job `Secret scan (gitleaks)` gia' nella CI):
lo completano. gitleaks scandisce il working tree ad ogni PR — utile, ma
arriva dopo che il segreto e' gia' stato pushato. Push protection blocca il
push stesso, prima che il segreto entri nella storia del repository; secret
scanning nativo copre anche superfici che gitleaks non guarda, come issue e
commenti di PR.

Attivarli non richiede nessuna modifica a `ci.yml`: sono interamente lato
GitHub, gratuiti sui repository pubblici.
```

- [ ] **Step 2: Aggiorna la tabella dei controlli obbligatori**

Nella sezione `## Passi`, punto 3, aggiungi due righe alla tabella esistente
(dopo la riga `CodeQL (JavaScript/TypeScript)`):

```markdown
   | `Dependency review` | dipendenze vulnerabili o con licenza incompatibile introdotte dal diff della PR |
   | `Migrazioni Supabase (apply pulito)` | migrazioni nuove con errori SQL che oggi si scoprirebbero solo al deploy |
```

E aggiungi, subito dopo il paragrafo che spiega perche' non rendere
obbligatorio `copilot-pull-request-reviewer`, una nota sul lint del titolo:

```markdown
   **Facoltativo, non obbligatorio**: `Titolo PR (conventional commits)`.
   Utile per abilitare un changelog automatico in futuro, ma non vale la
   pena bloccare il merge di una PR solo per un titolo mal formattato.
```

- [ ] **Step 3: Aggiungi il passo per Require review from Code Owners**

Nella sezione `## Passi`, dopo il punto 5 (`Require a pull request before
merging`), aggiungi:

```markdown
6. Attiva **Require review from Code Owners**: usa il file `.github/CODEOWNERS`
   gia' nel repository per richiedere automaticamente la review di
   @mariocelzo e @renatomancino su ogni PR, senza doverli aggiungere a mano
   ogni volta.
```

- [ ] **Step 4: Verifica di lettura**

Run: `cat .github/BRANCH_PROTECTION.md`
Expected: il documento si legge in ordine logico, senza sezioni duplicate o
numerazione dei passi interrotta.

- [ ] **Step 5: Commit**

```bash
git add .github/BRANCH_PROTECTION.md
git commit -m "docs: documenta i toggle nativi e i nuovi check obbligatori"
```

---

## Nota finale per chi esegue il piano

Dopo il Task 6, tutti i job del Blocco A sono nel branch. Prima di aprire la
PR verso `renatomancino/kickly`, esegui in locale — se possibile — almeno:
`cd mobile && flutter analyze && flutter test --coverage` e, se Docker e'
disponibile, `supabase start && supabase db reset && supabase stop`. Questo
non sostituisce la CI reale ma evita di scoprire un problema banale solo dopo
aver aperto la PR.
