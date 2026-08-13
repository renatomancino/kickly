-- Reduce frontend round trips for the most frequently rendered league views.
-- These functions are SECURITY INVOKER so the caller's existing RLS policies
-- remain authoritative.

create or replace function public.get_user_league_summaries()
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
  member_count bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    league.id,
    league.owner_id,
    league.name,
    league.slug::text,
    league.description,
    league.logo_url,
    league.city,
    league.country,
    league.visibility,
    league.football_format,
    league.max_members,
    league.invite_code,
    membership.role,
    count(roster.id) filter (where roster.status = 'active')
  from public.league_members membership
  join public.leagues league on league.id = membership.league_id
  left join public.league_members roster on roster.league_id = league.id
  where membership.user_id = (select auth.uid())
    and membership.status = 'active'
  group by
    league.id,
    membership.role,
    membership.joined_at
  order by membership.joined_at desc;
$$;

revoke all on function public.get_user_league_summaries() from public;
grant execute on function public.get_user_league_summaries() to authenticated;

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

create or replace function public.get_league_match_summaries(target_league uuid)
returns table (
  id uuid,
  league_id uuid,
  title text,
  starts_at timestamptz,
  location_name text,
  city text,
  football_format public.match_format,
  max_players smallint,
  visibility public.match_visibility,
  status public.match_status,
  registration_closed_at timestamptz,
  going_count bigint,
  current_response public.attendance_status
)
language sql
stable
security invoker
set search_path = ''
as $$
  select
    match.id,
    match.league_id,
    match.title,
    match.starts_at,
    match.location_name,
    match.city,
    match.football_format,
    match.max_players,
    match.visibility,
    match.status,
    match.registration_closed_at,
    coalesce(participants.going_count, 0),
    participants.current_response
  from public.matches match
  left join lateral (
    select
      count(*) filter (where participant.response = 'going') as going_count,
      (array_agg(participant.response) filter (
        where participant.user_id = (select auth.uid())
      ))[1] as current_response
    from public.match_participants participant
    where participant.match_id = match.id
  ) participants on true
  where match.league_id = target_league
  order by match.starts_at;
$$;

revoke all on function public.get_league_match_summaries(uuid) from public;
grant execute on function public.get_league_match_summaries(uuid) to authenticated;

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
    and stats.season_id is null;
$$;

revoke all on function public.get_league_leaderboard_rows(uuid) from public;
grant execute on function public.get_league_leaderboard_rows(uuid) to authenticated;

-- Index foreign keys used by joins, cascade deletes, and RLS lookups.
create index if not exists league_invites_created_by_idx on public.league_invites (created_by);
create index if not exists leagues_owner_idx on public.leagues (owner_id);
create index if not exists match_events_created_by_idx on public.match_events (created_by);
create index if not exists match_events_player_idx on public.match_events (player_id);
create index if not exists match_events_team_idx on public.match_events (team_id);
create index if not exists match_team_players_user_idx on public.match_team_players (user_id);
create index if not exists matches_created_by_idx on public.matches (created_by);
create index if not exists matches_season_idx on public.matches (season_id);
create index if not exists mvp_votes_voted_player_idx on public.mvp_votes (voted_player_id);
create index if not exists mvp_votes_voter_idx on public.mvp_votes (voter_id);
create index if not exists player_match_stats_team_idx on public.player_match_stats (team_id);
create index if not exists player_rating_history_match_idx on public.player_rating_history (match_id);
create index if not exists player_stats_season_idx on public.player_stats (season_id);
create index if not exists push_deliveries_subscription_idx on public.push_deliveries (subscription_id);

-- Avoid evaluating auth.uid() once per row in the policies flagged by the
-- Supabase performance advisor.
drop policy if exists "Users can insert league membership requests" on public.league_members;
create policy "Users can insert league membership requests"
on public.league_members
for insert
to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists "Users can update own league membership" on public.league_members;
create policy "Users can update own league membership"
on public.league_members
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "Users insert own rating history" on public.player_rating_history;
create policy "Users insert own rating history"
on public.player_rating_history
for insert
to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists "Users read rating history" on public.player_rating_history;
drop policy if exists "Visible rating history is readable" on public.player_rating_history;

create policy "Anonymous users read visible rating history"
on public.player_rating_history
for select
to anon
using ((select private.can_view_profile(user_id)));

create policy "Authenticated users read visible rating history"
on public.player_rating_history
for select
to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1
    from public.matches match
    where match.id = player_rating_history.match_id
      and match.visibility = 'public'
  )
  or (select private.can_view_profile(user_id))
);

drop policy if exists "Public profiles are readable" on public.profiles;
drop policy if exists "Users read own and league profiles" on public.profiles;

create policy "Public profiles are readable"
on public.profiles
for select
to anon
using (profile_public);

create policy "Authenticated profiles are readable"
on public.profiles
for select
to authenticated
using (
  profile_public
  or id = (select auth.uid())
  or (select private.shares_active_league(id))
);

-- Enable the league data streams used by the frontend. Keep this idempotent
-- so preview/local environments can replay the migration safely.
do $$
declare
  target_table text;
begin
  foreach target_table in array array[
    'matches',
    'match_participants',
    'league_members',
    'player_stats'
  ]
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = target_table
    ) then
      execute format('alter publication supabase_realtime add table public.%I', target_table);
    end if;
  end loop;
end;
$$;
