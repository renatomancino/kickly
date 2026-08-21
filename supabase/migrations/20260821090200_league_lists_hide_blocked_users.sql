-- Le liste "membri lega" e "classifica" non passano da una singola query
-- sulla tabella profiles: sono RPC SECURITY INVOKER che aggregano
-- league_members/player_stats con un JOIN a profiles
-- (20260813141108_optimize_realtime_performance.sql). Aggiornare solo la
-- policy di profiles (migrazione precedente) non basta a farne sparire un
-- utente bloccato, per due motivi distinti, verificati leggendo entrambe le
-- query:
--
-- 1. get_league_detail usa un LEFT JOIN verso profiles per costruire
--    l'array "members": se la riga di profiles viene negata dalla RLS, il
--    LEFT JOIN non elimina la riga di membership, la lascia con i campi
--    del profilo a null. L'utente bloccato "sparirebbe" solo di nome, non
--    dalla lista: resterebbe una voce fantasma con lo user_id ancora
--    visibile.
-- 2. get_league_leaderboard_rows fa un JOIN (inner) a profiles, quindi in
--    teoria la RLS aggiornata basterebbe — MA solo per il ramo
--    "shares_active_league" della policy. Se il profilo bloccato e' anche
--    profile_public = true, quel ramo della policy lo lascia visibile (per
--    design, vedi la migrazione precedente), e riapparirebbe in classifica
--    nonostante il blocco. La spec chiede che le liste membri/classifiche
--    nascondano l'utente bloccato senza eccezioni, indipendentemente da
--    profile_public.
--
-- Quindi entrambe le RPC ricevono un filtro esplicito e incondizionato su
-- private.is_blocked_pair, invece di affidarsi solo alla RLS di profiles.
-- Corpo altrimenti identico, byte per byte, a
-- 20260813141108_optimize_realtime_performance.sql:57-236.
create or replace function public.get_league_detail(target_slug text)
returns table (
  id uuid,
  owner_id uuid,
  name text,
  slug text,
  description text,
  logo_url text,
  city text,
  country text,
  visibility public.league_privacy,
  football_format public.match_format,
  max_members smallint,
  invite_code text,
  current_user_role public.league_role,
  members jsonb
)
language sql
stable
security invoker
set search_path = ''
as $$
  with target as (
    select
      league.*,
      current_membership.role as current_user_role
    from public.leagues league
    join public.league_members current_membership
      on current_membership.league_id = league.id
     and current_membership.user_id = (select auth.uid())
     and current_membership.status = 'active'
    where league.slug = target_slug::extensions.citext
    limit 1
  )
  select
    target.id,
    target.owner_id,
    target.name,
    target.slug::text,
    target.description,
    target.logo_url,
    target.city,
    target.country,
    target.visibility,
    target.football_format,
    target.max_members,
    target.invite_code,
    target.current_user_role,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', membership.id,
          'user_id', membership.user_id,
          'role', membership.role,
          'joined_at', membership.joined_at,
          'first_name', profile.first_name,
          'last_name', profile.last_name,
          'username', profile.username,
          'avatar_path', profile.avatar_path,
          'football_role', profile.primary_position
        )
        order by
          case membership.role when 'owner' then 0 when 'admin' then 1 else 2 end,
          membership.joined_at
      ) filter (where membership.id is not null),
      '[]'::jsonb
    ) as members
  from target
  left join public.league_members membership
    on membership.league_id = target.id
   and membership.status = 'active'
   -- Il filtro che manca oggi: senza, un membro bloccato resta nell'array
   -- come voce con user_id ma senza nome/avatar invece di sparire (vedi
   -- commento in testa al file).
   and not (select private.is_blocked_pair((select auth.uid()), membership.user_id))
  left join public.profiles profile on profile.id = membership.user_id
  group by
    target.id,
    target.owner_id,
    target.name,
    target.slug,
    target.description,
    target.logo_url,
    target.city,
    target.country,
    target.visibility,
    target.football_format,
    target.max_members,
    target.invite_code,
    target.current_user_role;
$$;

revoke all on function public.get_league_detail(text) from public;
grant execute on function public.get_league_detail(text) to authenticated;

create or replace function public.get_league_leaderboard_rows(target_league uuid)
returns table (
  user_id uuid,
  first_name text,
  last_name text,
  username text,
  avatar_path text,
  matches_played integer,
  goals integer,
  assists integer,
  mvp_awards integer,
  overall numeric
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    stats.user_id,
    profile.first_name,
    profile.last_name,
    profile.username::text,
    profile.avatar_path,
    stats.matches_played,
    stats.goals,
    stats.assists,
    stats.mvp_awards,
    stats.overall
  from public.player_stats stats
  join public.profiles profile on profile.id = stats.user_id
  where stats.league_id = target_league
    and stats.season_id is null
    -- Stesso motivo di get_league_detail sopra: senza questo filtro un
    -- profilo pubblico bloccato resterebbe in classifica nonostante il
    -- blocco (la RLS di profiles, per design, non nega il ramo
    -- profile_public per un blocco).
    and not (select private.is_blocked_pair((select auth.uid()), stats.user_id));
$$;

revoke all on function public.get_league_leaderboard_rows(uuid) from public;
grant execute on function public.get_league_leaderboard_rows(uuid) to authenticated;
