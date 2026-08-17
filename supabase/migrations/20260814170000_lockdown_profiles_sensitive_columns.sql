-- Blocca la scrittura diretta di colonne sensibili su public.profiles.
--
-- Il grant iniziale (`grant select, insert, update, delete on all tables
-- in schema public to authenticated`, in 20260812173126_initial_schema.sql)
-- non e mai stato ristretto per questa tabella, a differenza di
-- public.leagues (vedi 20260812173135_milestone_2_leagues.sql, che limita
-- l'UPDATE alle sole colonne non sensibili con un grant per-colonna). La
-- policy UPDATE di profiles controlla correttamente la proprieta della riga
-- (`id = auth.uid()`, sia in USING che WITH CHECK), ma non i singoli campi:
-- qualunque utente autenticato puo quindi eseguire, ad es. via supabase-js,
--   update profiles set overall = 99 where id = auth.uid()
-- e falsificare il proprio rating, bypassando completamente il calcolo
-- ufficiale in private.recalculate_user_rating() (invocato da
-- finalize_match / finalize_match_mvp dopo ogni partita). Il valore
-- falsificato resterebbe visibile ovunque (profilo, leaderboard) finche
-- l'utente non completa un'altra partita che lo ricalcoli da zero.
--
-- L'inserimento della riga profilo e gia gestito da
-- private.handle_new_user() (SECURITY DEFINER, trigger su auth.users), che
-- bypassa RLS/grant girando con i privilegi del proprietario della
-- funzione: il client non ha mai avuto bisogno del grant INSERT. L'upsert()
-- usato da saveProfile() in kickly_repository.dart trova quindi sempre la
-- riga gia esistente (creata al signup) e passa dal ramo UPDATE
-- dell'upsert, mai da un vero INSERT. La cancellazione dell'account passa
-- dall'eliminazione della riga in auth.users (cascata automatica su
-- profiles via `on delete cascade`), non da una DELETE diretta del client.
revoke insert, delete on public.profiles from authenticated;
revoke update on public.profiles from authenticated;
grant update (
  username,
  first_name,
  last_name,
  primary_position,
  secondary_position,
  preferred_foot,
  skill_level,
  birth_date,
  city,
  province,
  profile_public,
  onboarding_completed,
  avatar_path
) on public.profiles to authenticated;

-- Stesso identico pattern gia bonificato per league_members in
-- 20260814160000_lockdown_league_members_direct_writes.sql: policy INSERT
-- "morta" mai ripulita. Il grant INSERT su questa tabella e gia stato
-- revocato da 20260812174152_milestone_4_post_match.sql e nessuna
-- migrazione successiva lo ha piu concesso, quindi la policy non viene
-- valutata oggi — ma resta pronta a diventare sfruttabile se in futuro
-- qualcuno ripristinasse per errore il grant pensando servisse a "far
-- funzionare" questa policy percepita come parte del flusso normale.
drop policy if exists "Users insert own rating history" on public.player_rating_history;

-- Igiene minore: INSERT/DELETE non sono mai stati revocati esplicitamente
-- da player_stats (solo UPDATE lo e stato in
-- 20260812174152_milestone_4_post_match.sql). Restano innocui oggi perche
-- non esiste alcuna policy INSERT/DELETE per authenticated su questa
-- tabella (RLS nega per default in assenza di policy), ma li revochiamo
-- comunque per coerenza con il resto dello schema e per non lasciare un
-- grant "vestito" senza una policy che lo giustifichi.
revoke insert, delete on public.player_stats from authenticated;
