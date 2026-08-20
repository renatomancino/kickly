# Rendere la CI bloccante (per chi ha admin su `renatomancino/kickly`)

I workflow in `.github/workflows/ci.yml` girano già e mostrano verde o rosso su
ogni PR. Ma **un check rosso da solo non impedisce il merge**: GitHub lo segnala
e basta. Per trasformarlo in un cancello vero serve una regola di *branch
protection*, che può creare solo chi ha permessi di admin sul repository di
destinazione.

Sono cinque minuti, una volta sola.

## Passi

1. `Settings` → `Rules` → `Rulesets` → `New branch ruleset`
   (in alternativa, la vecchia interfaccia: `Settings` → `Branches` → `Add branch
   protection rule`).
2. Nome: `main`. In *Target branches* aggiungi `main` come *Include by pattern*.
3. Attiva **Require status checks to pass**, poi cerca e aggiungi questi sei
   controlli, esattamente con questi nomi:

   | Check | Cosa impedisce che finisca in main |
   |---|---|
   | `Flutter (analyze, test, format)` | codice Dart che non compila, test rotti, file non formattati |
   | `PWA (lint, typecheck, build)` | errori di tipo TypeScript e rotture che si vedono solo a build time |
   | `Android (APK debug)` | dipendenze native incompatibili — la classe di bug che ha già rotto la build due volte |
   | `Secret scan (gitleaks)` | chiavi e credenziali committate per sbaglio |
   | `npm audit` | dipendenze npm con vulnerabilità di livello alto |
   | `Migrazioni immutabili` | modifiche a migrazioni Supabase già applicate in produzione |
   | `CodeQL (JavaScript/TypeScript)` | vulnerabilità nel codice della PWA: input non validato che arriva a una query, un redirect o una risposta |
   | `Dependency review` | dipendenze vulnerabili introdotte dal diff della PR |
   | `Migrazioni Supabase (apply pulito)` | migrazioni nuove con errori SQL che oggi si scoprirebbero solo al deploy |

   > I nomi qui sopra sono quelli **verificati** che compaiono nell'elenco di
   > GitHub: la CI ha già girato su questo repository (PR #3), quindi la lista
   > non è più vuota e i check si possono selezionare subito.

   **Da NON rendere obbligatorio**: `copilot-pull-request-reviewer`. La review di
   Copilot lascia commenti di merito, non un esito verde/rosso: renderla
   bloccante significherebbe non poter unire una PR finché un giudizio
   soggettivo non viene risolto. Vale come parere, non come cancello — e
   funziona già da sola su ogni PR, senza configurazione.

   **Facoltativo, non obbligatorio**: `Titolo PR (conventional commits)`.
   Utile per abilitare un changelog automatico in futuro, ma non vale la
   pena bloccare il merge di una PR solo per un titolo mal formattato.

4. Attiva anche **Require branches to be up to date before merging**: senza
   questa, una PR può risultare verde su una base ormai vecchia e rompere `main`
   una volta unita.
5. Consigliato: **Require a pull request before merging**, così nessuno spinge
   direttamente su `main` scavalcando del tutto la CI.
6. Attiva **Require review from Code Owners**: usa il file `.github/CODEOWNERS`
   gia' nel repository per richiedere automaticamente la review di
   @mariocelzo e @renatomancino su ogni PR, senza doverli aggiungere a mano
   ogni volta.

## L'altro interruttore da accendere, mentre sei nelle impostazioni

`Settings` → `Advanced Security` (o `Code security`) → **Dependabot alerts**.

È una cosa diversa dal file `.github/dependabot.yml` già nel repository: quel
file governa gli *aggiornamenti di versione* programmati, questo interruttore
attiva gli *avvisi* quando salta fuori una vulnerabilità nota in una dipendenza
che stiamo già usando. Il primo è manutenzione ordinaria, il secondo è l'allarme.

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

## Cosa NON serve

- Nessun secret da configurare. La pipeline è progettata per girare a secchio
  vuoto, perché le PR che arrivano da un fork non hanno comunque accesso ai
  secrets (vedi il commento in testa a `ci.yml`).
- Nessun costo. Entrambi i repository sono pubblici, quindi i minuti di GitHub
  Actions sono gratuiti e illimitati.

## Se un check diventa rumoroso

Meglio sistemare la causa che togliere il cancello. L'unico con una soglia
discutibile è `npm audit`: è impostato su `--audit-level=high`, e capita che una
vulnerabilità venga pubblicata su una dipendenza transitiva senza che esista
ancora una versione corretta. In quel caso la scelta onesta è alzare
temporaneamente la soglia **con un commento che dice quale CVE e fino a quando**,
non rimuovere il job.
