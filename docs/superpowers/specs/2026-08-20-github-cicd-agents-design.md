# CI/CD: automazioni GitHub gratuite + agent Copilot su fallimenti in main

Data: 2026-08-20
Autori: Mario, Renato (via sessione Claude Code)
Stato: approvato per l'implementazione

## Contesto

La CI attuale (`.github/workflows/ci.yml`, `.github/workflows/codeql.yml`,
`.github/dependabot.yml`) e' gia' matura: 7 job indipendenti (Flutter
analyze/test/format, PWA lint/typecheck/build, Android debug build, gitleaks,
npm audit, migrazioni immutabili) piu' CodeQL settimanale, il tutto progettato
esplicitamente intorno al modello fork -> upstream (`mariocelzo/kickly` come
fork di lavoro, `renatomancino/kickly` come upstream) senza mai usare
`pull_request_target` su codice non fidato.

Questa spec copre due filoni, entrambi vincolati a **costo zero**:

- **Blocco A**: irrobustimenti alla CI esistente con strumenti nativi GitHub,
  gratuiti su repository pubblico, nessuna dipendenza da licenze a pagamento.
- **Blocco B**: una pipeline che trasforma un fallimento della CI su `main` in
  un'issue, la fa classificare gratuitamente, e assegna il fix al Copilot
  coding agent (incluso nel GitHub Student Developer Pack di Mario e Renato)
  solo quando il fallimento e' meccanico/banale — altrimenti la issue resta
  per un umano.

## Obiettivo

Ridurre il lavoro manuale di manutenzione (dipendenze vulnerabili scoperte
tardi, fallimenti di CI su `main` che nessuno nota subito, piccoli fix che
richiedono comunque il contesto di aprire l'editor) sfruttando cio' che
GitHub offre gratis su repository pubblici, piu' la quota Copilot gratuita
degli account studenti finche' dura.

## Non-obiettivi (scartati durante il brainstorming, e perche')

- **Claude Code Action / autenticazione via abbonamento Claude** — scartato:
  il vincolo e' costo zero assoluto, e l'uso via OAuth consumerebbe la quota
  degli abbonamenti personali di Mario/Renato condivisa con le sessioni
  interattive.
- **Scanner TODO/FIXME nel codice per aprire issue** — scartato: richiede
  disciplina nello scrivere TODO con criteri di accettazione verificabili
  (poco realistico), e una scansione a tappeto della repo ad ogni run e'
  spreco di tempo/risorse rispetto a un trigger event-driven.
- **Copilot Autofix su alert CodeQL** — non incluso in questa spec: non e'
  stato possibile verificare con certezza se richieda una licenza Copilot
  distinta dalla sola GHAS gratuita su repo pubblici. Da rivalutare a parte.
- **Build iOS in CI** — fuori scope: indipendente dal resto di questa spec,
  eventualmente un task a se' in futuro.
- **Pipeline Blocco B estesa ai fallimenti sulle singole PR** (non solo
  push su `main`) — fuori scope per la v1: chi apre la PR vede gia' il
  fallimento da solo, e triggerare su PR da fork riaprirebbe esattamente il
  problema di sicurezza che `ci.yml` evita deliberatamente (permessi
  privilegiati su un evento che un fork puo' influenzare). Si puo'
  riconsiderare in futuro solo per push sullo stesso repo (non da fork).

## Design — Blocco A: irrobustimenti CI (solo config/workflow, nessun rischio)

### A1. Dependency Review Action

Nuovo job in `ci.yml` (o workflow separato), trigger `pull_request`, usa
`actions/dependency-review-action`. Analizza il *diff* di dipendenze
introdotto dalla PR (npm, e se supportato anche pub) e fallisce se introduce
pacchetti con CVE note di severita' alta o licenze incompatibili. Complementa
`npm audit`, che oggi controlla l'intero lockfile ma solo su push/PR gia'
aperte, non il diff incrementale. Nessun permesso in scrittura necessario,
funziona anche su PR da fork perche' legge solo i manifest, non esegue nulla.

### A2. CODEOWNERS

Nuovo file `.github/CODEOWNERS` con un default globale (`* @mariocelzo
@renatomancino`, entrambi review-required su tutto): con un team di due
persone non serve una suddivisione per area, e resta comunque facile
aggiungere righe piu' specifiche in futuro se il progetto cresce.

### A3. Secret scanning + push protection nativi di GitHub

Non e' codice: e' un toggle in `Settings -> Advanced Security -> Secret
scanning` e `Push protection`, sullo stesso modello di quanto gia'
documentato in `.github/BRANCH_PROTECTION.md` per i Dependabot alerts.
Complementa gitleaks (che scandisce il working tree ad ogni PR): il
push protection nativo blocca il push stesso prima che il segreto entri nella
storia, e la scansione nativa copre anche issue/PR/commenti, non solo i file.
Documentato come aggiunta a `BRANCH_PROTECTION.md` durante l'implementazione.

## Design — Blocco B: fallimento CI su main -> issue -> triage gratuito -> Copilot

### Panoramica del flusso

```
push su main
     |
     v
ci.yml gira (i job esistenti, invariati)
     |
     v (conclusion = failure)
workflow_run "CI" completato con failure, ref = main
     |
     v
[nuovo workflow] Triage fallimento
  1. Legge il job/i job falliti del run e ne estrae un estratto del log
     (ultime N righe dello step fallito, non l'intero log)
  2. Chiama un modello gratuito via GitHub Models (permesso `models: read`,
     incluso gratis sui repo pubblici) con un prompt di classificazione:
     "TRIVIAL" (fix meccanico: test flaky, formattazione, tipo ovvio,
     dipendenza minore) vs "NEEDS_HUMAN" (tocca auth/migrazioni/RLS, causa
     non ovvia dal log, richiede una decisione di design)
  3. Apre una issue con: job fallito, link al run, estratto del log,
     classificazione e motivazione del modello, label `ci-failure` +
     (`agent-triage` o `needs-human` a seconda dell'esito)
  4a. Se TRIVIAL -> assegna l'issue al Copilot coding agent
  4b. Se NEEDS_HUMAN -> assegna l'issue a @mariocelzo e @renatomancino
     |
     v
Copilot (solo caso 4a) lavora in background, apre una PR
     |
     v
La PR passa dalla CI normale (ci.yml + Blocco A) prima che chiunque la guardi
```

### Perche' solo push su `main`

Come gia' discusso: le PR falliscono gia' visibilmente per chi le ha aperte
(non serve un'altra issue), e `main` e' protetto da branch protection quindi
un fallimento li' e' raro e sempre un segnale reale (conflitto semantico fra
due PR mergiate in sequenza verde, test flaky sfuggito). Restringere il
trigger a `push` su `main` (via `workflow_run` che osserva il completamento
di `ci.yml`, non un trigger diretto su evento PR) evita anche di dover dare
permessi privilegiati (`issues: write`, `models: read`) a un workflow
raggiungibile da un fork.

### Permessi necessari (nuovo workflow, separato da `ci.yml`)

```yaml
permissions:
  contents: read
  actions: read      # per leggere i log del run fallito
  issues: write       # per aprire/assegnare la issue
  models: read        # per la chiamata di classificazione gratuita
```

Nessuno di questi tocca `ci.yml` esistente: e' un workflow nuovo, separato,
che si attiva solo a valle di un run completato su `main` — mai su un evento
proveniente da un fork.

### Deduplica

Prima di aprire una issue, il workflow controlla se esiste gia' una issue
aperta con lo stesso SHA di commit nel titolo/corpo (via ricerca sulle issue
con label `ci-failure`), per evitare duplicati in caso di re-run dello stesso
workflow fallito.

## Rischi e cose da verificare in fase di implementazione

Questi due punti sono incerti e vanno confermati con una prova pratica prima
di considerare la pipeline pronta, non sono dettagli implementativi scontati:

1. **Meccanismo esatto per assegnare programmaticamente una issue al Copilot
   coding agent via API/Action** — da verificare se esiste un login/bot
   assegnabile via API (`assignees`) o se serve un passaggio manuale/comando
   specifico. Se non e' automatizzabile al 100%, il fallback e' che il
   workflow apra comunque la issue con l'etichetta corretta e Mario/Renato la
   assegnino a mano a Copilot con un click finche' non si trova la via
   automatica.
2. **Endpoint e formato esatto dell'API GitHub Models da Actions** (nome
   dell'action ufficiale o chiamata REST diretta, modelli disponibili nel
   tier gratuito, rate limit reali) — da verificare con un run di prova
   isolato prima di integrarlo nella pipeline.

Nessuno dei due rischi blocca Blocco A, che e' indipendente e puo' partire
subito.

## Piano di rollout

1. Blocco A (A1 dependency-review, A2 CODEOWNERS, A3 toggle nativi) — una PR
   sola, basso rischio, pronta rapidamente.
2. Blocco B, prova isolata dei due punti a rischio (assegnazione Copilot via
   API, chiamata GitHub Models) su un workflow minimo di test.
3. Blocco B, pipeline completa una volta confermati i due punti sopra.

## Testing / verifica

- Blocco A: verificare che `dependency-review-action` giri su una PR di
  prova che introduce volutamente una dipendenza con CVE nota, e che fallisca
  come atteso; verificare che CODEOWNERS richieda review dove previsto.
- Blocco B: simulare un fallimento su `main` (es. un job che fallisce di
  proposito su un branch di test rinominato temporaneamente, o un dry-run del
  solo workflow di triage con un run id gia' fallito in passato) e verificare
  che l'issue venga aperta, classificata e assegnata correttamente in
  entrambi i rami (TRIVIAL / NEEDS_HUMAN).
