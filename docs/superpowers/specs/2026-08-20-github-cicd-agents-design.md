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
- **Lighthouse CI sulla PWA** — non incluso: i punteggi su runner condivisi
  sono rumorosi, rischia di diventare un check che si ignora. Riconsiderabile
  in futuro come check puramente informativo, non bloccante.
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
pacchetti con CVE note di severita' alta. Complementa `npm audit`, che oggi
controlla l'intero lockfile ma solo su push/PR gia' aperte, non il diff
incrementale. Nessun permesso in scrittura necessario, funziona anche su PR
da fork perche' legge solo i manifest, non esegue nulla.

**Corretto in fase di implementazione (code review, 2026-08-20):** niente
controllo licenze incompatibili nella v1. L'action lo supporterebbe
(`allow-licenses`/`deny-licenses`), ma richiede una policy di licenze che il
team non ha ancora deciso — inventarne una in un job CI non e' una decisione
implementativa. Da aggiungere quando quella policy esiste.

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

### A4. iOS build (debug, `--no-codesign`)

Nuovo job, stesso pattern di `android-build` ma su `macos-latest` e con
`flutter build ios --no-codesign --dart-define-from-file=config.local.json`
(stessa configurazione fittizia gia' usata per Android). A differenza di
Android, il trigger e' **solo `push` su `main`**, non anche `pull_request`:
e' un job nuovo e non ancora verificato, quindi meglio catturare le rotture
subito dopo il merge invece di allungare il feedback loop di ogni PR fin da
subito. Si puo' allargare alle PR piu' avanti se si dimostra stabile e
sufficientemente veloce.

Nota di rischio: se il progetto Xcode ha capability che richiedono un
profilo di provisioning (push notification, associated domains, ecc.),
`--no-codesign` potrebbe non bastare a far passare il build. Da verificare
con una prova pratica, non e' garantito a priori.

### A5. Smoke test sulle migrazioni Supabase

A differenza di A4, questo **deve** girare sulle PR (non solo su main): lo
scopo e' validare le migrazioni *nuove* introdotte dalla PR stessa, non
quelle gia' in main. Estende concettualmente `migrations-check` (che oggi
verifica solo che le migrazioni esistenti non siano state toccate, non che
quelle nuove siano valide). Usa la CLI Supabase (gratuita) per avviare uno
stack locale via Docker e applicare tutte le migrazioni in sequenza: un
errore SQL o un ordine di dipendenza sbagliato fa fallire il job invece di
scoprirsi al primo deploy reale.

### A6. Coverage tracking

Aggiunge `--coverage` al comando `flutter test` gia' presente nel job
`flutter`, e un passo che riassume il delta di copertura nel job (commento
sulla PR o solo summary nella UI di Actions, da decidere in implementazione).
Nessun nuovo job, nessun trigger nuovo: stessa cadenza del job esistente.

### A7. PR title lint (conventional commits)

Nuovo job leggero, trigger `pull_request`, verifica che il titolo della PR
segua un formato conventional-commit (`feat:`, `fix:`, `chore:`, ecc.). Non
cambia nulla oggi, ma rende possibile generare changelog automatico in
futuro senza retrofitting.

## Design — Blocco B: fallimento CI su main -> issue -> triage euristico -> Copilot

**Revisione 2026-08-20 (post-ricerca):** la v1 di questa sezione prevedeva un
passo di classificazione via GitHub Models. Verificato durante la scrittura
del piano di implementazione che **GitHub Models e' stato ritirato
definitivamente il 30 luglio 2026** (playground, catalogo modelli e API di
inferenza non esistono piu' per nessun cliente). Il passo di classificazione
e' stato quindi ridisegnato come euristica statica (nessuna chiamata esterna,
nessuna dipendenza da un prodotto che potrebbe sparire di nuovo) — vedi sotto.

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
  1. Legge quali job del run sono falliti (nomi, non serve il contenuto del
     log per classificare — vedi tabella euristica sotto)
  2. Classifica in base al NOME del job fallito, con una tabella statica:
     TRIVIAL per i job che segnalano problemi meccanici (formattazione, lint,
     tipo, titolo PR), NEEDS_HUMAN per i job che toccano nativo, sicurezza o
     schema dati. Nessuna chiamata esterna: e' un lookup in una mappa fissa
     dentro il workflow stesso.
  3. Apre una issue con: job fallito, link al run, un estratto del log
     (ultime N righe dello step fallito, solo come contesto per chi legge),
     classificazione ed etichetta (`ci-failure` + `agent-triage` o
     `needs-human` a seconda dell'esito)
  4a. Se TRIVIAL -> assegna l'issue al Copilot coding agent
      (`copilot-swe-agent[bot]`, via PAT — vedi sotto)
  4b. Se NEEDS_HUMAN -> assegna l'issue a @mariocelzo e @renatomancino
     |
     v
Copilot (solo caso 4a) lavora in background, apre una PR
     |
     v
La PR passa dalla CI normale (ci.yml + Blocco A) prima che chiunque la guardi
```

### Tabella euristica job -> classificazione

La colonna "Job fallito" qui sotto usa gli id YAML per brevita'. L'API di
GitHub restituisce pero' il **nome visualizzato** del job (il valore di
`name:`, es. `Flutter (analyze, test, format)`), non l'id: e' quella stringa
completa che lo script di classificazione confronta davvero — vedi
`docs/superpowers/plans/2026-08-20-ci-failure-triage-pipeline.md` per il
dettaglio implementativo.

| Job fallito (id YAML) | Classificazione | Perche' |
|---|---|---|
| `flutter` | TRIVIAL | analyze/test/format: spesso un test flaky o una riga da riformattare |
| `pwa` | TRIVIAL | lint/typecheck/build: spesso un errore di tipo puntuale |
| `pr-title-lint` | TRIVIAL | e' solo un formato di stringa |
| `secret-scan` | NEEDS_HUMAN | un segreto trovato va sempre valutato da una persona, mai "auto-risolto" |
| `npm-audit` | NEEDS_HUMAN | una CVE richiede leggere l'advisory, non solo bumpare |
| `dependency-review` | NEEDS_HUMAN | stesso motivo di npm-audit |
| `migrations-check` | NEEDS_HUMAN | tocca lo schema dati gia' in produzione |
| `supabase-migrations-apply` | NEEDS_HUMAN | idem: errori di schema, non di codice applicativo |
| `android-build` | NEEDS_HUMAN | storicamente la classe di bug piu' profonda del repo (dipendenze native) |
| `ios-build` | NEEDS_HUMAN | stesso motivo di android-build, ancora meno rodato |

Limite noto e accettato: la tabella guarda *quale* job e' fallito, non *perche'*
— un fallimento raro-ma-profondo dentro `flutter` verrebbe comunque instradato
a Copilot come TRIVIAL. Non e' pericoloso (nulla passa senza CI verde), nel
caso peggiore Copilot ci prova, fallisce, e la PR resta rossa finche' un
umano non la guarda. Rivedibile in futuro se si rivela troppo grossolana.

### Assegnazione a Copilot: requisiti confermati

Verificato via ricerca (non e' piu' un'incognita):

- Il `GITHUB_TOKEN` automatico di Actions **non** puo' assegnare una issue a
  Copilot: l'API rifiuta i token di tipo GitHub App/installation
  indipendentemente dai permessi dichiarati, perche' il consumo Copilot e'
  fatturato a livello di account personale.
- Serve un **fine-grained Personal Access Token** con permessi read/write su
  Issues, Pull requests, Contents, Actions, generato dall'account che user in
  questo progetto ha la licenza Copilot: **Renato** (deciso il 2026-08-20),
  salvato come secret del repository (es. `COPILOT_ASSIGN_PAT`). Le
  assegnazioni automatiche consumano la quota Copilot dell'account di Renato,
  non quella di Mario.
- Login esatto da usare come assignee: `copilot-swe-agent[bot]` (altre varianti
  del nome causano un errore 422).
- Via `gh` CLI: `gh issue edit <numero> --add-assignee copilot-swe-agent`
  (autenticato con il PAT, non con il token di default di Actions).

### Perche' solo push su `main`

Come gia' discusso: le PR falliscono gia' visibilmente per chi le ha aperte
(non serve un'altra issue), e `main` e' protetto da branch protection quindi
un fallimento li' e' raro e sempre un segnale reale (conflitto semantico fra
due PR mergiate in sequenza verde, test flaky sfuggito). Restringere il
trigger a `push` su `main` (via `workflow_run` che osserva il completamento
di `ci.yml`, non un trigger diretto su evento PR) evita anche di dover dare
permessi privilegiati (`issues: write`) a un workflow raggiungibile da un
fork.

### Permessi e secret necessari (nuovo workflow, separato da `ci.yml`)

```yaml
permissions:
  contents: read
  actions: read      # per leggere quali job del run sono falliti
  issues: write       # per aprire la issue e assegnarla ai casi NEEDS_HUMAN
```

Piu' un secret a livello di repository, non un permesso del `GITHUB_TOKEN`:
`COPILOT_ASSIGN_PAT`, il fine-grained PAT dell'account di Renato descritto
sopra, usato SOLO nello step che assegna l'issue a Copilot nel ramo TRIVIAL
(il resto del workflow — leggere il run fallito, aprire la issue, assegnarla
agli umani nel ramo NEEDS_HUMAN — usa il `GITHUB_TOKEN` normale).

Nessuno di questi tocca `ci.yml` esistente: e' un workflow nuovo, separato,
che si attiva solo a valle di un run completato su `main` — mai su un evento
proveniente da un fork.

### Deduplica

Prima di aprire una issue, il workflow controlla se esiste gia' una issue
aperta con lo stesso SHA di commit nel titolo/corpo (via ricerca sulle issue
con label `ci-failure`), per evitare duplicati in caso di re-run dello stesso
workflow fallito.

## Rischi noti (risolti in fase di ricerca, non piu' incognite)

Entrambi i rischi originariamente segnalati come "da verificare" sono stati
chiariti prima di scrivere il piano di implementazione:

1. **GitHub Models e' stato ritirato** (30 luglio 2026) — risolto sostituendo
   il passo di classificazione con l'euristica statica descritta sopra,
   invece che con una prova pratica di un'API che non esiste piu'.
2. **Assegnazione Copilot via API** — confermato che serve un PAT
   fine-grained (non il `GITHUB_TOKEN` di default), login esatto
   `copilot-swe-agent[bot]`, legato all'account di Renato. Vedi la sezione
   dedicata sopra per i dettagli.

Resta un punto minore, non bloccante, riguardo ad A4: se il build iOS senza
firma non bastasse a causa di capability che richiedono un profilo di
provisioning — ma questo e' gia' stato escluso con un test pratico (vedi
`docs/superpowers/plans/2026-08-20-ci-ios-build.md`).

## Piano di rollout

1. Blocco A "sicuro" (A1 dependency-review, A2 CODEOWNERS, A3 toggle nativi,
   A5 smoke test migrazioni, A6 coverage, A7 PR title lint) — una PR sola,
   basso rischio, pronta rapidamente.
2. A4 iOS build — PR a se', gia' verificata in locale (vedi piano dedicato).
3. Blocco B, pipeline completa (nessuno spike separato: i due rischi tecnici
   sono stati chiariti in fase di ricerca, il piano puo' essere scritto
   direttamente in modo completo).

## Testing / verifica

- Blocco A1-A3, A5-A7: verificare che `dependency-review-action` giri su una
  PR di prova che introduce volutamente una dipendenza con CVE nota, e che
  fallisca come atteso; verificare che CODEOWNERS richieda review dove
  previsto; verificare che il job A5 fallisca su una migrazione con un errore
  SQL introdotto apposta e passi su una valida.
- A4: gia' verificato in locale (Flutter 3.47.0 + Xcode 26.6, build
  completata con successo) — resta da confermare il primo run reale su
  `main` dopo il merge.
- Blocco B: simulare un fallimento su `main` (es. un job che fallisce di
  proposito su un branch di test rinominato temporaneamente, o un dry-run del
  solo workflow di triage con un run id gia' fallito in passato) e verificare
  che l'issue venga aperta, classificata secondo la tabella euristica, e
  assegnata correttamente in entrambi i rami (TRIVIAL -> Copilot via PAT,
  NEEDS_HUMAN -> @mariocelzo e @renatomancino).
