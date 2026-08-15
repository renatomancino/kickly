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

   > I nomi compaiono nell'elenco solo dopo che il workflow è girato almeno una
   > volta sul repository. Se la lista è vuota, apri una PR qualsiasi, aspetta
   > che la CI parta e poi torna qui.

4. Attiva anche **Require branches to be up to date before merging**: senza
   questa, una PR può risultare verde su una base ormai vecchia e rompere `main`
   una volta unita.
5. Consigliato: **Require a pull request before merging**, così nessuno spinge
   direttamente su `main` scavalcando del tutto la CI.

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
