## Cosa cambia

<!-- Una o due righe: cosa fa questa PR e perche' serve. Il "perche'" e' la parte che
     fra sei mesi nessuno riesce piu' a ricostruire dal diff. -->

## Come l'ho verificato

<!-- Cosa hai provato davvero, non cosa dovrebbe funzionare. Es: "creata una lega,
     invitato un secondo utente, verificata la notifica su Android fisico". -->

## Checklist

- [ ] Testato a mano sul percorso che tocca (PWA e/o app mobile)
- [ ] Nessuna chiave o credenziale nel diff (`mobile/config.local.json`, `.env*`, `key.properties` restano fuori dal repo)
- [ ] Le migrazioni gia' presenti in `supabase/migrations/` non sono state modificate: se lo schema cambia, c'e' una migrazione **nuova**
- [ ] Se la modifica tocca lo schema o le policy RLS, l'ho applicata anche sul progetto Supabase reale (la CI non lo fa)
- [ ] Se ho cambiato dipendenze native Flutter, la CI ha completato il job `Android (APK debug)`

<!-- La CI gira da sola su questa PR: Flutter (analyze/test/format), PWA (lint/typecheck/
     build), build APK Android, secret scan, npm audit e controllo migrazioni.
     Non serve chiedere nulla: se e' verde, quei controlli sono passati.
     Nota: la CI NON tocca il database e NON fa deploy — quelli restano manuali. -->
