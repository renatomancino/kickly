# Template email di autenticazione — Kickly

Tre template HTML brandizzati per le email transazionali di Supabase Auth.
Sono file "pronti da incollare": non richiedono build, non hanno dipendenze
esterne, vanno copiati così come sono nel campo giusto della dashboard.

## Come applicarli

Supabase Dashboard → **Authentication → Email Templates** → seleziona il tipo
di email → incolla il contenuto del file nel campo **"Message body"** →
imposta il **Subject heading** suggerito qui sotto → Save.

| File | Tipo di email nella dashboard | Subject suggerito |
|---|---|---|
| `confirm-signup.html` | **Confirm signup** | Conferma la tua email per Kickly |
| `invite-user.html` | **Invite user** | Sei stato invitato a unirti a Kickly |
| `reset-password.html` | **Reset Password** (a volte etichettato *Recovery*) | Reimposta la password di Kickly |

Ogni template usa `{{ .ConfirmationURL }}` come link di azione: è la variabile
verificata sulla documentazione ufficiale
(`supabase.com/docs/guides/auth/auth-email-templates`) per tutti e tre questi
tipi di email — Supabase la costruisce già con token, redirect e tipo corretti,
quindi non serve comporre l'URL a mano con `{{ .TokenHash }}` (quella via è
utile solo se si sta scrivendo un endpoint di verifica custom lato server,
cosa che Kickly non fa: la conferma avviene tramite il link diretto).

## Perché sono fatti così (scelte non ovvie)

- **Tabelle invece di flexbox/grid, stili inline invece di un `<style>` in
  `<head>`**: molti client email (Outlook desktop su Word engine, Gmail su
  alcune viste) ignorano o rimuovono i fogli di stile esterni e il CSS
  moderno. Le tabelle con `style=""` su ogni tag sono l'unico modo per avere
  un layout che si vede uguale ovunque, non solo nell'anteprima del browser.

- **Font di sistema (`Helvetica, Arial, sans-serif`) invece di Geist**: Geist
  è il font dell'app (impacchettato come asset locale in Flutter e caricato
  come webfont nella PWA), ma le email non possono contare su un `@font-face`
  caricato in modo affidabile — molti client email lo bloccano o lo
  ignorano. Uno stack di font di sistema è la scelta sicura per non rischiare
  testo invisibile o layout rotto.

- **Il "bottone" è una cella di tabella con sfondo verde, non un `<button>` o
  un'immagine**: i `<button>` HTML hanno supporto incoerente nei client
  email, e le immagini vengono spesso bloccate di default (l'utente
  vedrebbe un rettangolo vuoto senza call-to-action visibile). Una cella
  `<td bgcolor>` con un `<a>` dentro ("bulletproof button") è la tecnica
  standard per avere un pulsante che si vede sempre, anche a immagini
  disattivate.

- **Sotto al bottone c'è anche il link testuale in chiaro**: se per qualche
  motivo il pulsante non fosse cliccabile in un client particolare, il link
  raw resta comunque disponibile da copiare — è un fallback, non una
  ridondanza inutile.

- **Il testo verde neon (`#C7FF3D`) è solo su tagline, titolo del bottone e
  logo — mai sui paragrafi**: verde acceso su nero puro è d'impatto per un
  accento breve, ma diventa faticoso da leggere su un testo lungo. I
  paragrafi usano un bianco/grigio chiaro (`#D7DDD7`) per restare leggibili,
  esattamente come fa l'app (il tema Flutter usa il verde solo per accenti,
  mai come colore di testo del corpo).

- **Logo "K" testuale invece dell'icona PNG**: `kickly-icon.png` non è
  hostato su un URL pubblico raggiungibile dai client email (che caricano le
  immagini via HTTP, non possono leggere file locali del repo), quindi
  incorporarlo avrebbe richiesto caricarlo da qualche parte prima. Il
  wordmark testuale replica `KicklyMark` (il widget Flutter in
  `mobile/lib/app.dart`: quadrato verde arrotondato con "K" nero) e funziona
  ovunque senza dipendere da un hosting esterno.

- **Blocco "preheader" nascosto in cima a ogni file** (`display:none` +
  `mso-hide:all`): è il testo che Gmail/Apple Mail mostrano come anteprima
  accanto all'oggetto nella lista email. Senza, il client userebbe le prime
  parole visibili della email (spesso il logo/tagline), che è meno utile
  di una vera anteprima del contenuto.

## Limite di invio email — importante prima di andare in produzione

Supabase, **senza un provider SMTP custom configurato**, usa un servizio email
interno pensato solo per sviluppo/test: il rate limit di default è molto
basso (nel progetto locale, `supabase/config.toml` → `[auth.rate_limit]` →
`email_sent = 2` email **all'ora** — sul progetto hosted il limite di default
è nello stesso ordine di grandezza). Questi template possono essere incollati
e provati subito, ma **non sono utilizzabili in produzione così** finché non
si configura un provider SMTP vero in Authentication → Settings → SMTP
Settings (es. Resend, Postmark, SendGrid, Amazon SES).

Questo passaggio richiede credenziali (account sul provider scelto, API key
o utente/password SMTP, dominio verificato per il mittente) che deve
procurarsi il proprietario del progetto Supabase — non è qualcosa che si può
inventare o configurare da qui senza accesso a quell'account.

## Nota per lo sviluppo locale (CLI)

Il file `supabase/config.toml` supporta anche il caricamento diretto di un
template da file, senza passare dalla dashboard:

```toml
[auth.email.template.invite]
subject = "Sei stato invitato a unirti a Kickly"
content_path = "./supabase/email-templates/invite-user.html"
```

Utile solo per test in locale con `supabase start` (Inbucket) — il progetto
Supabase reale (hosted) si configura sempre dalla dashboard, quella sezione
del `config.toml` non si applica al progetto in produzione.
