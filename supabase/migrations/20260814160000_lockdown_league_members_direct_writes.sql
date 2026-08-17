-- Rimuove due policy RLS su public.league_members che permettevano INSERT/
-- UPDATE diretti a qualunque utente autenticato col solo vincolo
-- `user_id = auth.uid()`, senza controllare `role` né `status`. Introdotte da
-- una migration di setup per i test E2E (20260813000000_phase7_e2e_setup.sql,
-- commento originale: "Fixes RLS policies and configures test infrastructure")
-- e poi ri-applicate identiche in 20260813141108_optimize_realtime_performance
-- (lì solo per avvolgere auth.uid() in una subquery, per il performance
-- advisor — il gap di sicurezza non è stato notato in nessuna delle due).
--
-- Il join legittimo a una lega passa SEMPRE dalla funzione SECURITY DEFINER
-- `join_league_by_invite` (valida il codice invito e forza esplicitamente
-- role='member', status='active'), non da un insert diretto sulla tabella:
-- l'app Flutter non scrive mai direttamente su league_members, solo query di
-- lettura (vedi mobile/lib/data/kickly_repository.dart). Quindi queste due
-- policy non servono a nessun flusso reale dell'app.
--
-- Sono rimaste inerti solo perché milestone_2_leagues.sql fa
-- `revoke insert, update, delete on public.league_members from authenticated`
-- e nessuna migration successiva lo ha mai rigrantato: in Postgres senza il
-- GRANT a livello di tabella la policy RLS non viene nemmeno valutata. Il
-- rischio era latente, non attivo: sarebbe bastato un futuro
-- `grant insert, update on league_members to authenticated` (magari per
-- "far funzionare" queste policy percepite erroneamente come parte del
-- flusso normale) per permettere a chiunque autenticato di auto-inserirsi
-- come owner di una lega qualsiasi, o auto-promuoversi nella propria riga
-- esistente da member/banned a owner/admin.
drop policy if exists "Users can insert league membership requests" on public.league_members;
drop policy if exists "Users can update own league membership" on public.league_members;

-- Ribadisce esplicitamente il blocco (già in vigore dai tempi di
-- milestone_2_leagues.sql): renderlo esplicito qui documenta l'intento e
-- resiste a un domani in cui qualcuno rimuovesse quella revoke pensando
-- fosse superflua o dimenticasse perché è lì.
revoke insert, update, delete on public.league_members from authenticated;
