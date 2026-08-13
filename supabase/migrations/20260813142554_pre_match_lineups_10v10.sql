alter type public.match_format add value if not exists '10v10' before '11v11';

create table public.match_lineup_teams (
  match_id uuid not null references public.matches(id) on delete cascade,
  team_number smallint not null check (team_number in (1, 2)),
  formation text not null,
  captain_user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (match_id, team_number)
);

create table public.match_lineup_players (
  match_id uuid not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  team_number smallint not null check (team_number in (1, 2)),
  slot_key text not null check (slot_key ~ '^(gk|p([1-9]|10))$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (match_id, user_id),
  unique (match_id, team_number, slot_key),
  foreign key (match_id, team_number)
    references public.match_lineup_teams(match_id, team_number) on delete cascade
);

create index match_lineup_players_user_idx
  on public.match_lineup_players (user_id, match_id);

create trigger match_lineup_teams_updated_at
before update on public.match_lineup_teams
for each row execute function private.set_updated_at();

create trigger match_lineup_players_updated_at
before update on public.match_lineup_players
for each row execute function private.set_updated_at();

create or replace function private.lineup_side_size(target_format public.match_format)
returns smallint
language sql
immutable
set search_path = ''
as $$
  select case target_format::text
    when '5v5' then 5
    when '7v7' then 7
    when '8v8' then 8
    when '10v10' then 10
    when '11v11' then 11
    else 5
  end::smallint;
$$;

create or replace function private.default_lineup_formation(target_format public.match_format)
returns text
language sql
immutable
set search_path = ''
as $$
  select case target_format::text
    when '5v5' then '1-2-1'
    when '7v7' then '2-3-1'
    when '8v8' then '3-3-1'
    when '10v10' then '3-4-2'
    when '11v11' then '4-3-3'
    else '1-2-1'
  end;
$$;

create or replace function private.is_valid_lineup_formation(
  target_format public.match_format,
  target_formation text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case target_format::text
    when '5v5' then target_formation in ('1-2-1', '2-1-1', '1-1-2')
    when '7v7' then target_formation in ('2-3-1', '3-2-1', '2-2-2')
    when '8v8' then target_formation in ('3-3-1', '2-3-2', '3-2-2')
    when '10v10' then target_formation in ('3-4-2', '4-3-2', '4-4-1')
    when '11v11' then target_formation in ('4-3-3', '4-4-2', '3-5-2')
    else false
  end;
$$;

create or replace function private.is_valid_lineup_slot(
  target_format public.match_format,
  target_slot text
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  slot_number integer;
begin
  if target_slot = 'gk' then return true; end if;
  if target_slot !~ '^p([1-9]|10)$' then return false; end if;
  slot_number := substring(target_slot from 2)::integer;
  return slot_number < private.lineup_side_size(target_format);
end;
$$;

create or replace function private.initialize_match_lineups()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.match_lineup_teams (match_id, team_number, formation)
  values
    (new.id, 1, private.default_lineup_formation(new.football_format)),
    (new.id, 2, private.default_lineup_formation(new.football_format))
  on conflict (match_id, team_number) do nothing;
  return new;
end;
$$;

create trigger initialize_match_lineups
after insert on public.matches
for each row execute function private.initialize_match_lineups();

insert into public.match_lineup_teams (match_id, team_number, formation)
select match.id, team_number.number, private.default_lineup_formation(match.football_format)
from public.matches match
cross join (values (1::smallint), (2::smallint)) as team_number(number)
on conflict (match_id, team_number) do nothing;

create or replace function private.sync_lineups_after_format_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.football_format is not distinct from old.football_format then return new; end if;

  update public.match_lineup_teams
  set formation = private.default_lineup_formation(new.football_format)
  where match_id = new.id;

  delete from public.match_lineup_players
  where match_id = new.id
    and not private.is_valid_lineup_slot(new.football_format, slot_key);

  update public.match_lineup_teams team
  set captain_user_id = null
  where team.match_id = new.id
    and team.captain_user_id is not null
    and not exists (
      select 1 from public.match_lineup_players player
      where player.match_id = team.match_id
        and player.team_number = team.team_number
        and player.user_id = team.captain_user_id
    );

  return new;
end;
$$;

create trigger sync_lineups_after_format_change
after update of football_format on public.matches
for each row execute function private.sync_lineups_after_format_change();

create or replace function private.cleanup_match_lineup_participant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_match uuid;
  affected_user uuid;
  should_cleanup boolean;
begin
  if tg_op = 'DELETE' then
    affected_match := old.match_id;
    affected_user := old.user_id;
    should_cleanup := true;
  else
    affected_match := new.match_id;
    affected_user := new.user_id;
    should_cleanup := new.response <> 'going';
  end if;

  if should_cleanup then
    update public.match_lineup_teams
    set captain_user_id = null
    where match_id = affected_match and captain_user_id = affected_user;

    delete from public.match_lineup_players
    where match_id = affected_match and user_id = affected_user;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger cleanup_match_lineup_participant
after update of response or delete on public.match_participants
for each row execute function private.cleanup_match_lineup_participant();

create or replace function private.match_lineup_snapshot(target_match uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'teams', coalesce((
      select jsonb_agg(jsonb_build_object(
        'team_number', team.team_number,
        'formation', team.formation,
        'captain_user_id', team.captain_user_id
      ) order by team.team_number)
      from public.match_lineup_teams team
      where team.match_id = target_match
    ), '[]'::jsonb),
    'players', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', player.user_id,
        'team_number', player.team_number,
        'slot_key', player.slot_key
      ) order by player.team_number, player.slot_key)
      from public.match_lineup_players player
      where player.match_id = target_match
    ), '[]'::jsonb)
  );
$$;

create or replace function public.set_match_lineup_slot(
  target_match uuid,
  target_team smallint,
  target_slot text,
  wants_captain boolean default false
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  target public.matches%rowtype;
  occupying_user uuid;
  current_captain uuid;
begin
  if caller is null then raise exception 'authentication_required'; end if;

  select * into target from public.matches where id = target_match for update;
  if target.id is null then raise exception 'match_not_found'; end if;
  if target.status in ('cancelled', 'completed') then raise exception 'match_locked'; end if;
  if target_team not in (1, 2) then raise exception 'invalid_team'; end if;
  if not private.is_valid_lineup_slot(target.football_format, target_slot) then
    raise exception 'invalid_lineup_slot';
  end if;
  if not exists (
    select 1 from public.match_participants participant
    where participant.match_id = target_match
      and participant.user_id = caller
      and participant.response = 'going'
  ) then raise exception 'confirmed_participant_required'; end if;

  select player.user_id into occupying_user
  from public.match_lineup_players player
  where player.match_id = target_match
    and player.team_number = target_team
    and player.slot_key = target_slot;
  if occupying_user is not null and occupying_user <> caller then
    raise exception 'lineup_slot_taken';
  end if;

  select team.captain_user_id into current_captain
  from public.match_lineup_teams team
  where team.match_id = target_match and team.team_number = target_team;
  if wants_captain and current_captain is not null and current_captain <> caller then
    raise exception 'lineup_captain_taken';
  end if;

  update public.match_lineup_teams
  set captain_user_id = null
  where match_id = target_match
    and captain_user_id = caller
    and (team_number <> target_team or not wants_captain);

  insert into public.match_lineup_players (match_id, user_id, team_number, slot_key)
  values (target_match, caller, target_team, target_slot)
  on conflict (match_id, user_id) do update
  set team_number = excluded.team_number,
      slot_key = excluded.slot_key;

  if wants_captain then
    update public.match_lineup_teams
    set captain_user_id = caller
    where match_id = target_match and team_number = target_team;
  end if;

  return private.match_lineup_snapshot(target_match);
end;
$$;

create or replace function public.leave_match_lineup(target_match uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  target public.matches%rowtype;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  select * into target from public.matches where id = target_match for update;
  if target.id is null then raise exception 'match_not_found'; end if;
  if target.status in ('cancelled', 'completed') then raise exception 'match_locked'; end if;

  update public.match_lineup_teams
  set captain_user_id = null
  where match_id = target_match and captain_user_id = caller;

  delete from public.match_lineup_players
  where match_id = target_match and user_id = caller;

  return private.match_lineup_snapshot(target_match);
end;
$$;

create or replace function public.set_match_lineup_formation(
  target_match uuid,
  target_team smallint,
  target_formation text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  target public.matches%rowtype;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  select * into target from public.matches where id = target_match for update;
  if target.id is null then raise exception 'match_not_found'; end if;
  if target.status in ('cancelled', 'completed') then raise exception 'match_locked'; end if;
  if target_team not in (1, 2) then raise exception 'invalid_team'; end if;
  if not private.is_valid_lineup_formation(target.football_format, target_formation) then
    raise exception 'invalid_lineup_formation';
  end if;
  if not exists (
    select 1 from public.match_lineup_teams team
    where team.match_id = target_match
      and team.team_number = target_team
      and team.captain_user_id = caller
  ) and not exists (
    select 1 from public.league_members member
    where member.league_id = target.league_id
      and member.user_id = caller
      and member.status = 'active'
      and member.role in ('owner', 'admin')
  ) then raise exception 'lineup_captain_required'; end if;

  update public.match_lineup_teams
  set formation = target_formation
  where match_id = target_match and team_number = target_team;

  return private.match_lineup_snapshot(target_match);
end;
$$;

alter table public.match_lineup_teams enable row level security;
alter table public.match_lineup_players enable row level security;

create policy "League members read lineup teams"
on public.match_lineup_teams for select to authenticated
using (
  exists (
    select 1 from public.matches match
    where match.id = match_id
      and (select private.is_league_member(match.league_id))
  )
);

create policy "League members read lineup players"
on public.match_lineup_players for select to authenticated
using (
  exists (
    select 1 from public.matches match
    where match.id = match_id
      and (select private.is_league_member(match.league_id))
  )
);

revoke all on table public.match_lineup_teams from public, anon;
revoke all on table public.match_lineup_players from public, anon;
revoke insert, update, delete on table public.match_lineup_teams from authenticated;
revoke insert, update, delete on table public.match_lineup_players from authenticated;
grant select on table public.match_lineup_teams to authenticated;
grant select on table public.match_lineup_players to authenticated;

revoke all on function private.lineup_side_size(public.match_format) from public, anon, authenticated;
revoke all on function private.default_lineup_formation(public.match_format) from public, anon, authenticated;
revoke all on function private.is_valid_lineup_formation(public.match_format, text) from public, anon, authenticated;
revoke all on function private.is_valid_lineup_slot(public.match_format, text) from public, anon, authenticated;
revoke all on function private.initialize_match_lineups() from public, anon, authenticated;
revoke all on function private.sync_lineups_after_format_change() from public, anon, authenticated;
revoke all on function private.cleanup_match_lineup_participant() from public, anon, authenticated;
revoke all on function private.match_lineup_snapshot(uuid) from public, anon, authenticated;

revoke all on function public.set_match_lineup_slot(uuid, smallint, text, boolean) from public, anon;
revoke all on function public.leave_match_lineup(uuid) from public, anon;
revoke all on function public.set_match_lineup_formation(uuid, smallint, text) from public, anon;
grant execute on function public.set_match_lineup_slot(uuid, smallint, text, boolean) to authenticated;
grant execute on function public.leave_match_lineup(uuid) to authenticated;
grant execute on function public.set_match_lineup_formation(uuid, smallint, text) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'match_lineup_teams'
  ) then
    alter publication supabase_realtime add table public.match_lineup_teams;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'match_lineup_players'
  ) then
    alter publication supabase_realtime add table public.match_lineup_players;
  end if;
end;
$$;
