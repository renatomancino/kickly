# CI Failure Triage Pipeline (Blocco B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Task 2 richiede un'azione umana** (Renato deve generare un token sul suo
> account GitHub): nessun agente puo' eseguirla al posto suo. Segnalarla
> come blocco e aspettare conferma prima di considerare il piano completo.

**Goal:** Quando un run del workflow "CI" fallisce su un push a `main`, aprire automaticamente una issue classificata (in base al nome del job fallito, nessuna IA) e assegnarla al Copilot coding agent se banale, o a Mario e Renato se da investigare.

**Architecture:** Un nuovo workflow `.github/workflows/ci-failure-triage.yml`, triggerato da `workflow_run` (osserva il completamento di "CI", non un evento diretto — mai raggiungibile da un fork) piu' un trigger manuale `workflow_dispatch` per rigiocare un run passato senza dover rompere `main` apposta per testare. La classificazione e' uno script bash testabile in isolamento (`.github/scripts/classify-ci-failure.sh`), non una chiamata esterna. L'assegnazione a Copilot usa un fine-grained PAT dedicato (account di Renato) perche' il `GITHUB_TOKEN` automatico non e' accettato dall'API di assegnazione Copilot.

**Tech Stack:** GitHub Actions (`workflow_run`, `workflow_dispatch`), `gh` CLI (gia' autenticato di default nei runner Actions), `jq` (preinstallato su `ubuntu-latest`), bash.

Riferimento: `docs/superpowers/specs/2026-08-20-github-cicd-agents-design.md`, sezione "Design — Blocco B" (rivista il 2026-08-20 dopo la scoperta del ritiro di GitHub Models).

**Precondizione:** questo piano presuppone che Blocco A sia gia' stato
implementato (`docs/superpowers/plans/2026-08-20-ci-hardening-blocco-a.md`):
la tabella euristica del Task 1 elenca anche i job `dependency-review`,
`supabase-migrations-apply` e `pr-title-lint` introdotti li'.

---

### Task 1: Script di classificazione (con test)

**Files:**
- Create: `.github/scripts/classify-ci-failure.sh`
- Create: `.github/scripts/test-classify-ci-failure.sh`

**Nota sul formato dell'input**: l'API "list jobs for a workflow run" di
GitHub restituisce il **nome visualizzato** del job (il valore di `name:`
nello YAML, es. `Flutter (analyze, test, format)`), non l'id YAML
(`flutter`). Questi nomi contengono spazi e virgole, quindi non possono
essere passati come argomenti separati da spazio: lo script legge un nome
di job per riga da stdin, non da `argv`.

- [ ] **Step 1: Scrivi il test (fallira', lo script non esiste ancora)**

Crea `.github/scripts/test-classify-ci-failure.sh`:

```bash
#!/usr/bin/env bash
# Test manuale per classify-ci-failure.sh. Niente framework di test per
# bash nel repo: uno script con asserzioni e output leggibile basta per
# una funzione di ~20 righe che non cambia spesso.
set -euo pipefail
cd "$(dirname "$0")"

fail=0

# $1 = atteso, resto = nomi di job (uno per riga su stdin dello script)
check() {
  local expected="$1"; shift
  local actual
  actual="$(printf '%s\n' "$@" | ./classify-ci-failure.sh)"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: classify-ci-failure.sh <<< '$*' -> atteso '$expected', ottenuto '$actual'"
    fail=1
  else
    echo "OK: classify-ci-failure.sh <<< '$*' -> $actual"
  fi
}

check "TRIVIAL" "Flutter (analyze, test, format)"
check "TRIVIAL" "PWA (lint, typecheck, build)"
check "TRIVIAL" "Titolo PR (conventional commits)"
check "TRIVIAL" "Flutter (analyze, test, format)" "PWA (lint, typecheck, build)"
check "NEEDS_HUMAN" "Android (APK debug)"
check "NEEDS_HUMAN" "iOS (debug, no-codesign)"
check "NEEDS_HUMAN" "Secret scan (gitleaks)"
check "NEEDS_HUMAN" "npm audit"
check "NEEDS_HUMAN" "Dependency review"
check "NEEDS_HUMAN" "Migrazioni immutabili"
check "NEEDS_HUMAN" "Migrazioni Supabase (apply pulito)"
check "NEEDS_HUMAN" "Flutter (analyze, test, format)" "Android (APK debug)"

# Nessun job in input (edge case difensivo)
actual="$(printf '' | ./classify-ci-failure.sh)"
if [ "$actual" != "NEEDS_HUMAN" ]; then
  echo "FAIL: nessun input -> atteso 'NEEDS_HUMAN', ottenuto '$actual'"
  fail=1
else
  echo "OK: nessun input -> $actual"
fi

exit $fail
```

- [ ] **Step 2: Rendi eseguibili entrambi gli script e verifica che il test fallisca**

Run:
```bash
chmod +x .github/scripts/test-classify-ci-failure.sh
.github/scripts/test-classify-ci-failure.sh
```
Expected: fallisce con un errore tipo "No such file or directory" perche'
`classify-ci-failure.sh` non esiste ancora.

- [ ] **Step 3: Scrivi lo script di classificazione**

Crea `.github/scripts/classify-ci-failure.sh`:

```bash
#!/usr/bin/env bash
# Classifica un fallimento CI in TRIVIAL o NEEDS_HUMAN in base al NOME
# VISUALIZZATO dei job falliti, uno per riga su stdin (non argv: i nomi
# contengono spazi e virgole, es. "Flutter (analyze, test, format)").
# Nessuna chiamata esterna: GitHub Models (l'alternativa originariamente
# prevista) e' stato ritirato il 30/07/2026. NEEDS_HUMAN vince: se anche un
# solo job fallito tocca nativo/sicurezza/schema, l'intero fallimento va a
# un umano. Se un nome di job cambia in ci.yml senza aggiornare questa
# lista, il confronto smette di trovare un match e la classificazione
# ripiega su NEEDS_HUMAN — fail-safe per costruzione, non un bug silente.
#
# Limite noto e accettato: guarda quale job e' fallito, non perche' — un
# fallimento raro-ma-profondo dentro un job "banale" verrebbe comunque
# instradato a Copilot. Non e' pericoloso: nulla passa senza CI verde, nel
# caso peggiore Copilot ci prova e fallisce, la PR resta rossa finche' un
# umano non la guarda.
set -euo pipefail

TRIVIAL_JOBS=(
  "Flutter (analyze, test, format)"
  "PWA (lint, typecheck, build)"
  "Titolo PR (conventional commits)"
)

classification="TRIVIAL"
any_job="no"
while IFS= read -r job; do
  [ -z "$job" ] && continue
  any_job="yes"
  is_trivial="no"
  for t in "${TRIVIAL_JOBS[@]}"; do
    if [ "$job" = "$t" ]; then
      is_trivial="yes"
      break
    fi
  done
  if [ "$is_trivial" = "no" ]; then
    classification="NEEDS_HUMAN"
    break
  fi
done

if [ "$any_job" = "no" ]; then
  echo "NEEDS_HUMAN"
  exit 0
fi

echo "$classification"
```

- [ ] **Step 4: Rendi eseguibile e verifica che il test passi**

Run:
```bash
chmod +x .github/scripts/classify-ci-failure.sh
.github/scripts/test-classify-ci-failure.sh
```
Expected: tutte le righe `OK: ...`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add .github/scripts/classify-ci-failure.sh .github/scripts/test-classify-ci-failure.sh
git commit -m "ci: aggiunge lo script di classificazione euristica dei fallimenti CI"
```

---

### Task 2: Setup del PAT per l'assegnazione a Copilot (azione umana — Renato)

**Files:**
- Create: `.github/COPILOT_AGENT_SETUP.md`

**Questo task non e' automatizzabile da un agente**: richiede che Renato
generi un token sul proprio account GitHub, dato che l'assegnazione via API
al Copilot coding agent viene fatturata a livello di account personale e il
`GITHUB_TOKEN` automatico di Actions viene rifiutato dall'endpoint. Chi
esegue questo piano deve scrivere il documento (step 1), poi fermarsi e
chiedere a Renato di completare gli step 2-4 prima di considerare il Task
concluso.

- [ ] **Step 1: Scrivi le istruzioni**

Crea `.github/COPILOT_AGENT_SETUP.md`:

```markdown
# Setup del PAT per l'assegnazione automatica a Copilot

Il workflow `.github/workflows/ci-failure-triage.yml` assegna issue al
Copilot coding agent quando classifica un fallimento CI come banale. Questo
richiede un secret di repository, `COPILOT_ASSIGN_PAT`, che **solo Renato
puo' generare** (l'account con la licenza Copilot in questo progetto): il
token automatico di Actions non basta, l'API di assegnazione Copilot rifiuta
i token di tipo GitHub App/installation indipendentemente dai permessi
dichiarati, perche' il consumo Copilot va attribuito a un account personale.

## Passi (solo Renato, cinque minuti)

1. Vai su `https://github.com/settings/personal-access-tokens/new`
   (Personal access tokens -> Fine-grained tokens -> Generate new token).
2. **Resource owner**: il tuo account personale.
3. **Repository access**: "Only select repositories" -> `renatomancino/kickly`.
   Non dare accesso a tutti i repository: questo token deve poter toccare
   solo questo progetto.
4. **Permissions** -> Repository permissions, imposta *Read and write* su:
   - Issues
   - Pull requests
   - Contents
   - Actions
5. **Expiration**: scegli la scadenza massima consentita (tipicamente 1 anno).
   Segnati un promemoria per rigenerarlo prima che scada — quando scade, il
   ramo "banale" della pipeline smette silenziosamente di funzionare (le
   issue restano aperte senza assegnazione, il resto della pipeline continua
   a funzionare normalmente).
6. Genera il token e **copialo subito** (non sara' piu' visibile dopo).
7. Vai su `https://github.com/renatomancino/kickly/settings/secrets/actions`
   -> "New repository secret".
8. Nome: `COPILOT_ASSIGN_PAT`. Valore: il token copiato allo step 6. Salva.

## Come verificare che funzioni

Dopo aver salvato il secret, la verifica reale avviene al primo fallimento
di `main` classificato come banale (o con un dry-run manuale — vedi il piano
di implementazione, Task 4). Se l'assegnazione fallisce con un errore 401/403
nei log del job, il token non ha i permessi giusti o e' scaduto: rigenera
seguendo di nuovo questi passi.

## Cosa NON serve

Nessun costo: il PAT e' solo una credenziale, non introduce billing
aggiuntivo. Le assegnazioni a Copilot fatte tramite questo token consumano
la quota Copilot personale di Renato (inclusa nel GitHub Student Developer
Pack), non quella di Mario.
```

- [ ] **Step 2 (Renato): genera il PAT**

Segui i passi 1-6 del documento appena scritto.

- [ ] **Step 3 (Renato): salva il secret**

Segui i passi 7-8 del documento.

- [ ] **Step 4: Commit del documento** (puo' farlo chi scrive il codice, non serve aspettare Renato per questo commit — il documento e' utile a prescindere da quando il secret viene effettivamente creato)

```bash
git add .github/COPILOT_AGENT_SETUP.md
git commit -m "docs: istruzioni per generare il PAT di assegnazione Copilot"
```

---

### Task 3: Il workflow di triage

**Files:**
- Create: `.github/workflows/ci-failure-triage.yml`

- [ ] **Step 1: Scrivi il workflow**

```yaml
# Trasforma un fallimento del workflow "CI" su un push a main in una issue,
# classificata e assegnata automaticamente. Legge solo il verdetto e i nomi
# dei job del run appena completato: nessuna chiamata a modelli esterni
# (GitHub Models e' stato ritirato il 30/07/2026), nessuna esecuzione di
# codice del branch che ha fallito.
#
# Trigger `workflow_run`: osserva il completamento di "CI", non e' un evento
# diretto su push/pull_request. Per questo tipo di trigger GitHub esegue
# SEMPRE la definizione del workflow presente sul branch di default (main),
# mai quella di un branch/fork che ha causato il run osservato — motivo per
# cui e' sicuro dargli issues: write senza riaprire il problema che ci.yml
# evita deliberatamente con pull_request_target. Il filtro sotto (evento
# "push", branch "main") restringe comunque il caso reale ai soli fallimenti
# di main, escludendo i run delle PR.
#
# Il trigger workflow_dispatch permette di rigiocare manualmente un run gia'
# completato (utile per testare questo stesso workflow, o per rielaborare
# un fallimento vecchio) passando il suo run id.
name: Triage fallimento CI

on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]
  workflow_dispatch:
    inputs:
      run_id:
        description: "ID di un run gia' completato di CI da (ri)processare manualmente"
        required: true

permissions:
  contents: read
  actions: read
  issues: write

concurrency:
  group: ci-failure-triage-${{ github.event.workflow_run.head_sha || github.event.inputs.run_id }}
  cancel-in-progress: true

jobs:
  triage:
    name: Apri e assegna la issue
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v7

      # Un solo step decide se procedere, invece di spargere condizioni su
      # ogni step successivo: normalizza i due trigger diversi (workflow_run
      # vs workflow_dispatch) in un'unica fonte di verita', e fa anche la
      # deduplica (una issue aperta per lo stesso commit basta).
      - name: Determina il run da processare e se procedere
        id: run
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            RUN_ID="${{ github.event.inputs.run_id }}"
          else
            RUN_ID="${{ github.event.workflow_run.id }}"
          fi
          echo "run_id=${RUN_ID}" >> "$GITHUB_OUTPUT"

          RUN_JSON="$(gh api "repos/${{ github.repository }}/actions/runs/${RUN_ID}")"
          CONCLUSION="$(echo "$RUN_JSON" | jq -r '.conclusion')"
          EVENT="$(echo "$RUN_JSON" | jq -r '.event')"
          HEAD_BRANCH="$(echo "$RUN_JSON" | jq -r '.head_branch')"
          HEAD_SHA="$(echo "$RUN_JSON" | jq -r '.head_sha')"
          HTML_URL="$(echo "$RUN_JSON" | jq -r '.html_url')"
          echo "head_sha=${HEAD_SHA}" >> "$GITHUB_OUTPUT"
          echo "html_url=${HTML_URL}" >> "$GITHUB_OUTPUT"

          if [ "${{ github.event_name }}" != "workflow_dispatch" ]; then
            if [ "$CONCLUSION" != "failure" ] || [ "$EVENT" != "push" ] || [ "$HEAD_BRANCH" != "main" ]; then
              echo "should_run=false" >> "$GITHUB_OUTPUT"
              exit 0
            fi
          elif [ "$CONCLUSION" != "failure" ]; then
            echo "::warning::Il run scelto non e' fallito (conclusion=$CONCLUSION), non apro nessuna issue."
            echo "should_run=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          EXISTING="$(gh issue list --repo "${{ github.repository }}" --label ci-failure --state open --search "${HEAD_SHA} in:title" --json number --jq 'length')"
          if [ "$EXISTING" -gt 0 ]; then
            echo "::notice::Esiste gia' una issue aperta per il commit ${HEAD_SHA}, salto."
            echo "should_run=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          echo "should_run=true" >> "$GITHUB_OUTPUT"

      # L'API restituisce il nome VISUALIZZATO del job (es. "Flutter
      # (analyze, test, format)"), non l'id YAML. Va scritto su file, non in
      # un output a riga singola: contiene spazi e virgole che spezzerebbero
      # un join-by-space. `names_summary` (separatore " | ", senza virgole
      # interne fra i job) e' solo per titolo/corpo leggibili da un umano.
      - name: Recupera i job falliti del run
        if: steps.run.outputs.should_run == 'true'
        id: jobs
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          JOBS_JSON="$(gh api "repos/${{ github.repository }}/actions/runs/${{ steps.run.outputs.run_id }}/jobs" --jq '[.jobs[] | select(.conclusion=="failure") | .name]')"
          echo "$JOBS_JSON" | jq -r '.[]' > failed-jobs.txt
          echo "names_summary=$(echo "$JOBS_JSON" | jq -r 'join(" | ")')" >> "$GITHUB_OUTPUT"

      - name: Classifica il fallimento
        if: steps.run.outputs.should_run == 'true'
        id: classify
        run: |
          RESULT="$(.github/scripts/classify-ci-failure.sh < failed-jobs.txt)"
          echo "result=${RESULT}" >> "$GITHUB_OUTPUT"

      - name: Estrai un estratto del log dei job falliti
        if: steps.run.outputs.should_run == 'true'
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh run view "${{ steps.run.outputs.run_id }}" --repo "${{ github.repository }}" --log-failed > full-log.txt || true
          {
            echo '```'
            tail -n 150 full-log.txt
            echo '```'
          } > excerpt.md

      - name: Prepara il corpo della issue
        if: steps.run.outputs.should_run == 'true'
        run: |
          cat > body.md <<'BODYEOF'
          Job falliti: ${{ steps.jobs.outputs.names_summary }}
          Run: ${{ steps.run.outputs.html_url }}
          Commit: ${{ steps.run.outputs.head_sha }}

          Classificazione automatica: **${{ steps.classify.outputs.result }}** (in base al nome del job fallito, non al contenuto del log -- vedi `.github/scripts/classify-ci-failure.sh`).

          ## Estratto log
          BODYEOF
          cat excerpt.md >> body.md

      - name: Crea le label se non esistono ancora
        if: steps.run.outputs.should_run == 'true'
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh label create ci-failure --repo "${{ github.repository }}" --color B60205 --description "Fallimento CI su main aperto automaticamente" --force
          gh label create agent-triage --repo "${{ github.repository }}" --color 0E8A16 --description "Classificato banale, assegnato a Copilot" --force
          gh label create needs-human --repo "${{ github.repository }}" --color FBCA04 --description "Classificato da investigare, assegnato a un umano" --force

      # Usa il PAT (non il GITHUB_TOKEN di default): l'API di assegnazione
      # Copilot rifiuta i token GitHub App/installation. Vedi
      # .github/COPILOT_AGENT_SETUP.md.
      - name: Apri la issue (banale -> Copilot)
        if: steps.run.outputs.should_run == 'true' && steps.classify.outputs.result == 'TRIVIAL'
        env:
          GH_TOKEN: ${{ secrets.COPILOT_ASSIGN_PAT }}
        run: |
          gh issue create --repo "${{ github.repository }}" \
            --title "CI rotta su main (${{ steps.run.outputs.head_sha }}): ${{ steps.jobs.outputs.names_summary }}" \
            --label "ci-failure,agent-triage" \
            --assignee "@copilot" \
            --body-file body.md

      - name: Apri la issue (da investigare -> Mario e Renato)
        if: steps.run.outputs.should_run == 'true' && steps.classify.outputs.result == 'NEEDS_HUMAN'
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh issue create --repo "${{ github.repository }}" \
            --title "CI rotta su main (${{ steps.run.outputs.head_sha }}): ${{ steps.jobs.outputs.names_summary }}" \
            --label "ci-failure,needs-human" \
            --assignee "mariocelzo,renatomancino" \
            --body-file body.md
```

- [ ] **Step 2: Verifica sintattica locale**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci-failure-triage.yml'))" && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci-failure-triage.yml
git commit -m "ci: aggiunge la pipeline di triage automatico dei fallimenti su main"
```

---

### Task 4: Verifica end-to-end (dopo il merge, richiede il secret del Task 2)

Questo job non puo' essere verificato in isolamento in locale (dipende da
`gh api`, dal contesto di un run reale, e dal secret `COPILOT_ASSIGN_PAT`).
Verifica in due parti dopo il merge in main:

- [ ] **Parte 1 — ramo NEEDS_HUMAN, senza serve il PAT**

Trova un run passato di "CI" fallito su main (se non ce n'e' uno recente, e'
accettabile aspettare il primo fallimento reale invece di provocarne uno
apposta su main). Prendi il suo run id:

```bash
gh run list --repo renatomancino/kickly --workflow=CI --status=failure --branch=main --limit 5
```

Poi rigioca manualmente il triage su quel run id:

```bash
gh workflow run ci-failure-triage.yml --repo renatomancino/kickly -f run_id=<RUN_ID>
```

Expected: entro un minuto compare una nuova issue con label `ci-failure` +
(`needs-human` o `agent-triage` a seconda dei job falliti in quel run
specifico), assegnata di conseguenza. Controlla anche che rilanciandolo una
seconda volta sullo stesso `run_id` NON crei una seconda issue (deduplica).

- [ ] **Parte 2 — ramo TRIVIAL, richiede `COPILOT_ASSIGN_PAT` gia' salvato (Task 2 completato)**

Stesso comando di sopra ma puntato a un run in cui e' fallito solo un job fra
`flutter`, `pwa`, `pr-title-lint`. Expected: la issue viene creata E
assegnata a Copilot (visibile come assignee `copilot-swe-agent` nella issue).
Se questo step fallisce con un errore di permessi nei log del job "Apri la
issue (banale -> Copilot)", il PAT del Task 2 non e' configurato correttamente
o e' scaduto — rivedi `.github/COPILOT_AGENT_SETUP.md`.

---

## Nota finale per chi esegue il piano

Il Task 2 e' l'unico che richiede un'azione umana specifica (Renato). Se
questo piano viene eseguito da un agente autonomo, il Task 2 va segnalato
come checkpoint bloccante: scrivere il documento e fare il commit va bene,
ma il PAT vero deve generarlo Renato. Il resto del piano (Task 1, 3, e la
Parte 1 del Task 4) puo' procedere ed essere verificato senza aspettare.
