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
   Trattalo come una credenziale sensibile quanto una password: chi lo
   possiede puo' scrivere su questo repository e lanciare i suoi workflow
   (i permessi coprono anche Contents e Actions in scrittura, non solo
   l'assegnazione a Copilot). Se sospetti che sia trapelato, revocalo subito
   da `https://github.com/settings/personal-access-tokens` e rigeneralo.
7. Vai su `https://github.com/renatomancino/kickly/settings/secrets/actions`
   -> "New repository secret".
8. Nome: `COPILOT_ASSIGN_PAT`. Valore: il token copiato allo step 6. Salva.

## Come verificare che funzioni

Dopo aver salvato il secret, la verifica reale avviene al primo fallimento
di `main` classificato come banale (o con un dry-run manuale — vedi il piano
di implementazione, Task 4). Se l'assegnazione fallisce con un errore 401/403
nei log del job, il token non ha i permessi giusti o e' scaduto: rigenera
seguendo di nuovo questi passi. Controlla anche i commenti/la timeline della
issue creata: un permesso insufficiente puo' far fallire l'avvio del lavoro
di Copilot in modo asincrono, con un commento sulla issue invece che con un
errore visibile nei log del job di triage.

## Cosa NON serve

Nessun costo: il PAT e' solo una credenziale, non introduce billing
aggiuntivo. Le assegnazioni a Copilot fatte tramite questo token consumano
la quota Copilot personale di Renato (inclusa nel GitHub Student Developer
Pack), non quella di Mario.
