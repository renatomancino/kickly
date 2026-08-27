-- Cancellazione account: tombstone + RPC di richiesta.
--
-- PERCHE' NON UNA DELETE: leagues.owner_id, matches.created_by e
-- match_events.recorded_by referenziano profiles(id) con ON DELETE RESTRICT
-- (20260812173126_initial_schema.sql, 20260812173135_milestone_2_leagues.sql).
-- Cancellare la riga in auth.users fallirebbe per qualunque admin di lega o
-- utente che abbia creato una partita/evento, cioe' la maggioranza degli
-- utenti attivi. Il commento in 20260814170000_lockdown_profiles_sensitive_
-- columns.sql assumeva una cascata pulita che oggi non esiste piu' per
-- questi casi. Si usa invece un tombstone (deleted_at) + anonimizzazione:
-- la riga profilo resta, le referenze restano valide, e lo storico
-- condiviso (classifiche, partite, statistiche) resta intatto per gli
-- altri membri delle leghe.
alter table public.profiles
  add column deleted_at timestamptz null;

-- Preview di sola lettura: leghe di cui il chiamante e' owner E che hanno
-- ALTRI membri attivi oltre a lui stesso (having count > 1, perche' l'owner
-- e' sempre lui stesso un membro attivo grazie al trigger
-- private.handle_new_league()). L'app la chiama PRIMA di mostrare la
-- conferma di eliminazione, cosi' puo' mostrare subito la schermata
-- "risolvi prima di continuare" invece di far scoprire il blocco solo dopo
-- un tentativo fallito. Stesso pattern "preview read-only separata
-- dall'azione" gia' usato per get_league_invite_preview / join_league_by_code.
create or replace function public.get_account_deletion_blockers()
returns table (
  league_id uuid,
  league_slug text,
  league_name text,
  active_member_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  select l.id, l.slug::text, l.name, count(lm.user_id)::integer
  from public.leagues l
  join public.league_members lm
    on lm.league_id = l.id and lm.status = 'active'
  where l.owner_id = (select auth.uid())
  group by l.id, l.slug, l.name
  having count(lm.user_id) > 1;
$$;

-- RPC azione: anonimizza il profilo del chiamante invece di cancellarlo.
--
-- Ricontrolla lo stesso blocco di get_account_deletion_blockers() invece di
-- fidarsi del client: la preview potrebbe essere stata mostrata minuti
-- prima, e nel frattempo l'utente potrebbe essere tornato owner unico (o
-- aver riacquisito membri in un'altra lega) — la preview e' solo UX, questa
-- funzione resta la fonte di verita'.
create or replace function public.request_account_deletion()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  current_avatar_path text;
  new_username text;
begin
  if caller is null then raise exception 'authentication_required'; end if;

  -- Blocca sulle leghe di cui il chiamante e' owner PRIMA di leggere i
  -- blocker: get_account_deletion_blockers() e' una stable select senza
  -- lock, quindi senza questo lock join_league_by_code (che fa "select ...
  -- for update" sulla stessa riga leagues, 20260820100000_rate_limit_
  -- invite_code_attempts.sql) potrebbe inserire un nuovo membro attivo nella
  -- finestra tra il controllo e l'update sottostante, lasciando la lega con
  -- un owner anonimizzato e nessun percorso di recupero.
  perform 1 from public.leagues where owner_id = caller for update;

  if exists (
    select 1 from public.profiles where id = caller and deleted_at is not null
  ) then
    raise exception 'account_already_deleted';
  end if;

  if exists (select 1 from public.get_account_deletion_blockers()) then
    raise exception 'account_has_blocking_leagues';
  end if;

  select avatar_path into current_avatar_path
  from public.profiles where id = caller;

  -- Hash casuale, non un contatore: evita di dover interrogare quanti
  -- "utente_eliminato_N" esistono gia' solo per scegliere il prossimo.
  -- 8 caratteri esadecimali (32 bit di entropia) rendono una collisione
  -- sull'unique constraint di username praticamente impossibile ai volumi
  -- di quest'app, quindi qui non serve un ciclo di retry come invece fa
  -- private.generate_invite_code() (li' il codice e' mostrato all'utente e
  -- deve restare corto e leggibile; qui e' solo un placeholder invisibile).
  new_username := 'utente_eliminato_' ||
    substr(encode(extensions.gen_random_bytes(8), 'hex'), 1, 8);

  update public.profiles
  set first_name = null,
      last_name = null,
      birth_date = null,
      city = null,
      avatar_path = null,
      username = new_username,
      profile_public = false,
      deleted_at = now()
  where id = caller;

  -- Dati puramente operativi: nessun motivo di tenerli per un account
  -- disattivato. Non tocchiamo match_participants, player_match_stats,
  -- match_events, player_stats, player_rating_history, mvp_votes: restano
  -- agganciati alla riga profilo (ora anonima) per preservare classifiche e
  -- storico condiviso con gli altri membri delle leghe.
  delete from public.push_subscriptions where user_id = caller;
  delete from public.notifications where user_id = caller;

  if current_avatar_path is not null then
    -- storage.objects ha un trigger BEFORE DELETE (storage.protect_delete,
    -- installato dallo storage-api di Supabase stesso, non da una nostra
    -- migrazione) che rifiuta qualunque DELETE diretto a meno che la GUC
    -- storage.allow_delete_query non sia 'true' nella transazione corrente.
    -- Verificato empiricamente: senza questa riga request_account_deletion()
    -- fallisce con "Direct deletion from storage tables is not allowed" e
    -- l'intera funzione va in rollback (incluso l'update su profiles sopra).
    -- "set local" vale solo per la transazione della chiamata RPC corrente,
    -- quindi non allenta la protezione altrove. Cancelliamo solo la riga di
    -- metadata: e' accettabile qui perche' il path e' quello dell'avatar
    -- dell'utente che si sta cancellando, non un oggetto condiviso.
    set local storage.allow_delete_query = 'true';
    delete from storage.objects
    where bucket_id = 'avatars'
      and (storage.foldername(name))[1] = caller::text;
  end if;
end;
$$;

revoke all on function public.get_account_deletion_blockers() from public, anon;
revoke all on function public.request_account_deletion() from public, anon;
grant execute on function public.get_account_deletion_blockers() to authenticated;
grant execute on function public.request_account_deletion() to authenticated;
