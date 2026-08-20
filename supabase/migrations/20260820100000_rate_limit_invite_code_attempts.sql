-- Rate limiting sui tentativi di ingresso con codice invito.
--
-- PERCHE': join_league_by_code non aveva alcun limite di tentativi. Il
-- codice e' 8 caratteri esadecimali (vedi initial_schema.sql:
-- upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))), quindi
-- ~4.3 miliardi di combinazioni: il rischio pratico di indovinarne uno per
-- forza bruta e' basso ai volumi attuali, ma resta il tipo di endpoint che
-- un controllo di sicurezza segnala sempre — ed e' economico da chiudere.
--
-- A differenza di publish_league_communication / send_match_reminder (che
-- riusano una riga che l'azione lascia comunque, riuscita o no, per
-- controllare "quando l'ho fatta l'ultima volta"), un tentativo con
-- codice SBAGLIATO non lascia traccia da nessuna parte in questo schema:
-- serve una tabella dedicata solo a questo, non riusabile da un'altra già
-- esistente.
create table public.league_invite_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  attempted_at timestamptz not null default now()
);

-- Nessun accesso diretto dal client, in nessuna direzione: solo
-- join_league_by_code (SECURITY DEFINER) scrive e legge qui. Stesso
-- pattern "tabella di solo servizio, mai nello schema esposto ai grant di
-- authenticated" già usato altrove in questo progetto.
alter table public.league_invite_attempts enable row level security;
revoke all on table public.league_invite_attempts from public, anon, authenticated;

-- Serve alla query "quanti tentativi di questo utente nell'ultima finestra",
-- eseguita a ogni chiamata di join_league_by_code.
create index league_invite_attempts_user_idx
on public.league_invite_attempts (user_id, attempted_at desc);

create or replace function public.join_league_by_code(invite text)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  target public.leagues%rowtype;
  existing public.league_members%rowtype;
  active_members integer;
  recent_attempts integer;
begin
  if caller is null then
    raise exception 'authentication_required';
  end if;

  -- Contati e registrati PRIMA di cercare il codice, cosi' anche i
  -- tentativi che poi risultano "codice non valido" contano verso il
  -- limite — e' esattamente quello che deve fermare un tentativo di forza
  -- bruta, non solo i tentativi riusciti. 10 in 5 minuti e' largo
  -- abbastanza da non intralciare chi sbaglia a ricopiare il codice un
  -- paio di volte, stretto abbastanza da rendere impraticabile scandire
  -- anche solo una piccola frazione dello spazio delle combinazioni.
  select count(*) into recent_attempts
  from public.league_invite_attempts
  where user_id = caller and attempted_at > now() - interval '5 minutes';

  if recent_attempts >= 10 then
    raise exception 'invite_attempts_rate_limited';
  end if;

  insert into public.league_invite_attempts (user_id) values (caller);

  select * into target
  from public.leagues
  where upper(invite_code) = upper(btrim(invite))
  for update;

  if target.id is null then
    raise exception 'invalid_invite_code';
  end if;

  select * into existing
  from public.league_members
  where league_id = target.id and user_id = caller;

  if existing.id is not null and existing.status = 'active' then
    raise exception 'already_member';
  end if;
  if existing.id is not null and existing.status = 'banned' then
    raise exception 'membership_banned';
  end if;

  select count(*) into active_members
  from public.league_members
  where league_id = target.id and status = 'active';

  if active_members >= target.max_members then
    raise exception 'league_full';
  end if;

  insert into public.league_members (league_id, user_id, role, status)
  values (target.id, caller, 'member', 'active')
  on conflict (league_id, user_id) do update
    set status = 'active', role = 'member', joined_at = now();

  return target.slug::text;
end;
$$;

-- Senza pulizia la tabella cresce senza fine: a 1 giorno di ritenzione basta
-- ampiamente per la finestra di 5 minuti sopra, e chi volesse un log più
-- lungo dei tentativi di ingresso non è comunque lo scopo di questa tabella.
create or replace function private.cleanup_league_invite_attempts()
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  delete from public.league_invite_attempts where attempted_at < now() - interval '1 day';
$$;

-- Stesso pattern idempotente già usato per i job esistenti (vedi
-- milestone_6_notifications_pwa.sql): disiscrive prima di ri-schedulare,
-- così ri-applicare questa migrazione non crea job duplicati.
do $$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job where jobname = 'kickly-cleanup-invite-attempts';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;
  perform cron.schedule('kickly-cleanup-invite-attempts', '0 3 * * *', 'select private.cleanup_league_invite_attempts();');
end;
$$;
