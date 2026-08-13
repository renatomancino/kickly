create type public.match_result as enum ('win', 'draw', 'loss');

drop trigger if exists validate_mvp_vote on public.mvp_votes;
drop function if exists private.validate_mvp_vote();

drop table if exists public.mvp_votes cascade;
drop table if exists public.player_match_stats cascade;
drop table if exists public.match_events cascade;
drop table if exists public.match_teams cascade;

alter table public.matches
  add column if not exists mvp_voting_ends_at timestamptz,
  add column if not exists mvp_finalized_at timestamptz;

create table public.match_teams (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 40),
  team_number smallint not null check (team_number in (1, 2)),
  created_at timestamptz not null default now(),
  unique (match_id, team_number)
);

create table public.match_team_players (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  team_id uuid not null references public.match_teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (match_id, user_id),
  unique (team_id, user_id)
);

create table public.match_events (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  team_id uuid not null references public.match_teams(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  event_type public.match_event_type not null check (event_type in ('goal', 'assist')),
  quantity smallint not null default 1 check (quantity between 1 and 99),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.player_match_stats (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  team_id uuid not null references public.match_teams(id) on delete cascade,
  goals smallint not null default 0 check (goals >= 0),
  assists smallint not null default 0 check (assists >= 0),
  result public.match_result not null,
  is_mvp boolean not null default false,
  match_rating numeric(3,1) check (match_rating between 1 and 10),
  previous_overall numeric(4,1) check (previous_overall between 40 and 99),
  new_overall numeric(4,1) check (new_overall between 40 and 99),
  rating_delta numeric(3,1) not null default 0 check (rating_delta between -1.5 and 1.5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (match_id, user_id)
);

create table public.mvp_votes (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  voter_id uuid not null references public.profiles(id) on delete cascade,
  voted_player_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (match_id, voter_id),
  check (voter_id <> voted_player_id)
);

alter table public.player_rating_history rename column player_id to user_id;
alter table public.player_rating_history rename column rating to new_rating;
alter table public.player_rating_history rename column recorded_at to created_at;
alter table public.player_rating_history add column previous_rating numeric(4,1);
update public.player_rating_history set previous_rating = new_rating where previous_rating is null;
alter table public.player_rating_history alter column previous_rating set not null;
alter table public.player_rating_history drop constraint if exists player_rating_history_rating_check;
alter table public.player_rating_history add constraint player_rating_history_new_rating_check check (new_rating between 40 and 99);
alter table public.player_rating_history add constraint player_rating_history_previous_rating_check check (previous_rating between 40 and 99);
alter table public.player_rating_history drop constraint if exists player_rating_history_delta_check;
alter table public.player_rating_history add constraint player_rating_history_delta_check check (delta between -1.5 and 1.5);

drop index if exists public.rating_history_player_idx;
create index rating_history_user_idx on public.player_rating_history (user_id, created_at desc);
create index match_teams_match_idx on public.match_teams (match_id, team_number);
create index match_team_players_match_idx on public.match_team_players (match_id, team_id);
create index match_events_match_idx on public.match_events (match_id);
create index player_match_stats_user_idx on public.player_match_stats (user_id, match_id);
create index mvp_votes_match_idx on public.mvp_votes (match_id, voted_player_id);

create trigger match_events_updated_at before update on public.match_events
for each row execute function private.set_updated_at();
create trigger player_match_stats_updated_at before update on public.player_match_stats
for each row execute function private.set_updated_at();

create or replace function private.validate_team_player()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.match_teams team
    where team.id = new.team_id and team.match_id = new.match_id
  ) then
    raise exception 'team_match_mismatch';
  end if;
  return new;
end;
$$;

create trigger validate_team_player before insert or update on public.match_team_players
for each row execute function private.validate_team_player();

create or replace function private.recalculate_user_rating(target_user uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  player_role public.football_role;
  current_rating numeric(4,1);
  next_rating numeric(4,1);
  change numeric(3,1);
  performance numeric;
  row_stats record;
begin
  select primary_position into player_role from public.profiles where id = target_user;
  select coalesce((
    select history.new_rating
    from public.player_rating_history history
    where history.user_id = target_user and history.match_id is null
    order by history.created_at, history.id limit 1
  ), 70)::numeric(4,1) into current_rating;

  delete from public.player_rating_history
  where user_id = target_user and match_id is not null;

  for row_stats in
    select stats.*, match.completed_at
    from public.player_match_stats stats
    join public.matches match on match.id = stats.match_id
    where stats.user_id = target_user and match.status = 'completed'
    order by match.completed_at, match.id
  loop
    performance := case row_stats.result
      when 'win' then 0.35
      when 'draw' then 0.10
      else -0.25
    end + 0.05;

    performance := performance + case coalesce(player_role, 'midfielder'::public.football_role)
      when 'forward' then row_stats.goals * 0.22 + row_stats.assists * 0.12
      when 'midfielder' then row_stats.goals * 0.14 + row_stats.assists * 0.20
      when 'defender' then row_stats.goals * 0.10 + row_stats.assists * 0.12
      when 'goalkeeper' then row_stats.goals * 0.04 + row_stats.assists * 0.05
    end;
    if row_stats.is_mvp then performance := performance + 0.35; end if;

    change := round(greatest(-1.5, least(1.5, performance))::numeric, 1);
    next_rating := round(greatest(40, least(99, current_rating + change))::numeric, 1);

    update public.player_match_stats set
      previous_overall = current_rating,
      new_overall = next_rating,
      rating_delta = round((next_rating - current_rating)::numeric, 1),
      match_rating = round(greatest(1, least(10,
        6 + case row_stats.result when 'win' then 0.8 when 'draw' then 0.2 else -0.4 end
          + row_stats.goals * 0.55 + row_stats.assists * 0.35
          + case when row_stats.is_mvp then 0.5 else 0 end
      ))::numeric, 1)
    where id = row_stats.id;

    insert into public.player_rating_history (
      user_id, match_id, previous_rating, new_rating, delta, reason, created_at
    ) values (
      target_user, row_stats.match_id, current_rating, next_rating,
      round((next_rating - current_rating)::numeric, 1),
      case when row_stats.is_mvp then 'Prestazione partita + MVP' else 'Prestazione partita' end,
      coalesce(row_stats.completed_at, now())
    );
    current_rating := next_rating;
  end loop;

  update public.profiles set overall = current_rating where id = target_user;
end;
$$;

create or replace function private.recalculate_user_aggregates(target_user uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  current_overall numeric(4,1);
begin
  select overall into current_overall from public.profiles where id = target_user;
  delete from public.player_stats where user_id = target_user;

  insert into public.player_stats (
    user_id, league_id, season_id, matches_played, wins, draws, losses,
    goals, assists, mvp_awards, current_streak, overall
  )
  select target_user, null, null, count(*)::integer,
    count(*) filter (where stats.result = 'win')::integer,
    count(*) filter (where stats.result = 'draw')::integer,
    count(*) filter (where stats.result = 'loss')::integer,
    coalesce(sum(stats.goals), 0)::integer,
    coalesce(sum(stats.assists), 0)::integer,
    count(*) filter (where stats.is_mvp)::integer,
    0, coalesce(current_overall, 70)
  from public.player_match_stats stats
  where stats.user_id = target_user;

  insert into public.player_stats (
    user_id, league_id, season_id, matches_played, wins, draws, losses,
    goals, assists, mvp_awards, current_streak, overall
  )
  select target_user, match.league_id, null, count(*)::integer,
    count(*) filter (where stats.result = 'win')::integer,
    count(*) filter (where stats.result = 'draw')::integer,
    count(*) filter (where stats.result = 'loss')::integer,
    coalesce(sum(stats.goals), 0)::integer,
    coalesce(sum(stats.assists), 0)::integer,
    count(*) filter (where stats.is_mvp)::integer,
    0, coalesce(current_overall, 70)
  from public.player_match_stats stats
  join public.matches match on match.id = stats.match_id
  where stats.user_id = target_user
  group by match.league_id;

  insert into public.player_stats (
    user_id, league_id, season_id, matches_played, wins, draws, losses,
    goals, assists, mvp_awards, current_streak, overall
  )
  select target_user, match.league_id, match.season_id, count(*)::integer,
    count(*) filter (where stats.result = 'win')::integer,
    count(*) filter (where stats.result = 'draw')::integer,
    count(*) filter (where stats.result = 'loss')::integer,
    coalesce(sum(stats.goals), 0)::integer,
    coalesce(sum(stats.assists), 0)::integer,
    count(*) filter (where stats.is_mvp)::integer,
    0, coalesce(current_overall, 70)
  from public.player_match_stats stats
  join public.matches match on match.id = stats.match_id
  where stats.user_id = target_user and match.season_id is not null
  group by match.league_id, match.season_id;
end;
$$;

create or replace function public.finalize_match(
  target_match uuid,
  team_a_players uuid[],
  team_b_players uuid[],
  score_a integer,
  score_b integer,
  player_totals jsonb
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  target public.matches%rowtype;
  team_a uuid;
  team_b uuid;
  confirmed_count integer;
  stats_count integer;
  assigned_goals_a integer;
  assigned_goals_b integer;
  player uuid;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  select * into target from public.matches where id = target_match for update;
  if target.id is null then raise exception 'match_not_found'; end if;
  if target.status = 'cancelled' then raise exception 'match_locked'; end if;
  if not exists (
    select 1 from public.league_members
    where league_id = target.league_id and user_id = caller
      and status = 'active' and role in ('owner', 'admin')
  ) then raise exception 'admin_required'; end if;
  if score_a < 0 or score_b < 0 or score_a > 99 or score_b > 99 then raise exception 'invalid_score'; end if;
  if coalesce(array_length(team_a_players, 1), 0) = 0 or coalesce(array_length(team_b_players, 1), 0) = 0 then
    raise exception 'teams_required';
  end if;
  if exists (select 1 from unnest(team_a_players) a join unnest(team_b_players) b on a = b) then
    raise exception 'duplicate_team_player';
  end if;

  select count(*) into confirmed_count from public.match_participants
  where match_id = target_match and response = 'going';
  if confirmed_count <> coalesce(array_length(team_a_players, 1), 0) + coalesce(array_length(team_b_players, 1), 0)
    or exists (
      select participant.user_id from public.match_participants participant
      where participant.match_id = target_match and participant.response = 'going'
      except select unnest(team_a_players) union select unnest(team_b_players)
    )
    or exists (
      (select unnest(team_a_players) union select unnest(team_b_players))
      except select participant.user_id from public.match_participants participant
      where participant.match_id = target_match and participant.response = 'going'
    )
  then raise exception 'all_confirmed_players_required'; end if;

  if jsonb_typeof(player_totals) <> 'array' then raise exception 'invalid_player_totals'; end if;
  select count(distinct (item->>'user_id')::uuid) into stats_count
  from jsonb_array_elements(player_totals) item;
  if stats_count <> confirmed_count then raise exception 'player_totals_required'; end if;
  if exists (
    select 1 from jsonb_array_elements(player_totals) item
    where (item->>'user_id') is null
      or coalesce((item->>'goals')::integer, -1) < 0
      or coalesce((item->>'assists')::integer, -1) < 0
      or not ((item->>'user_id')::uuid = any(team_a_players) or (item->>'user_id')::uuid = any(team_b_players))
  ) then raise exception 'invalid_player_totals'; end if;

  select coalesce(sum((item->>'goals')::integer), 0) into assigned_goals_a
  from jsonb_array_elements(player_totals) item where (item->>'user_id')::uuid = any(team_a_players);
  select coalesce(sum((item->>'goals')::integer), 0) into assigned_goals_b
  from jsonb_array_elements(player_totals) item where (item->>'user_id')::uuid = any(team_b_players);
  if assigned_goals_a <> score_a then raise exception 'team_a_goals_mismatch:%:%', score_a, assigned_goals_a; end if;
  if assigned_goals_b <> score_b then raise exception 'team_b_goals_mismatch:%:%', score_b, assigned_goals_b; end if;

  insert into public.match_teams (match_id, name, team_number) values (target_match, 'Team A', 1)
  on conflict (match_id, team_number) do update set name = excluded.name returning id into team_a;
  insert into public.match_teams (match_id, name, team_number) values (target_match, 'Team B', 2)
  on conflict (match_id, team_number) do update set name = excluded.name returning id into team_b;

  delete from public.mvp_votes where match_id = target_match;
  delete from public.player_match_stats where match_id = target_match;
  delete from public.match_events where match_id = target_match;
  delete from public.match_team_players where match_id = target_match;

  insert into public.match_team_players (match_id, team_id, user_id)
  select target_match, team_a, unnest(team_a_players)
  union all
  select target_match, team_b, unnest(team_b_players);

  insert into public.match_events (match_id, team_id, player_id, event_type, quantity, created_by)
  select target_match,
    case when (item->>'user_id')::uuid = any(team_a_players) then team_a else team_b end,
    (item->>'user_id')::uuid, 'goal', (item->>'goals')::smallint, caller
  from jsonb_array_elements(player_totals) item where (item->>'goals')::integer > 0;
  insert into public.match_events (match_id, team_id, player_id, event_type, quantity, created_by)
  select target_match,
    case when (item->>'user_id')::uuid = any(team_a_players) then team_a else team_b end,
    (item->>'user_id')::uuid, 'assist', (item->>'assists')::smallint, caller
  from jsonb_array_elements(player_totals) item where (item->>'assists')::integer > 0;

  insert into public.player_match_stats (match_id, user_id, team_id, goals, assists, result)
  select target_match, assignment.user_id, assignment.team_id,
    coalesce((totals.item->>'goals')::smallint, 0),
    coalesce((totals.item->>'assists')::smallint, 0),
    case
      when score_a = score_b then 'draw'::public.match_result
      when assignment.team_id = team_a and score_a > score_b then 'win'::public.match_result
      when assignment.team_id = team_b and score_b > score_a then 'win'::public.match_result
      else 'loss'::public.match_result
    end
  from public.match_team_players assignment
  join lateral (
    select item from jsonb_array_elements(player_totals) item
    where (item->>'user_id')::uuid = assignment.user_id limit 1
  ) totals on true
  where assignment.match_id = target_match;

  update public.matches set
    team_a_score = score_a,
    team_b_score = score_b,
    status = 'completed',
    completed_at = now(),
    registration_closed_at = coalesce(registration_closed_at, now()),
    mvp_deadline = now() + interval '24 hours',
    mvp_voting_ends_at = now() + interval '24 hours',
    mvp_finalized_at = null
  where id = target_match;

  for player in select user_id from public.player_match_stats where match_id = target_match loop
    perform private.recalculate_user_rating(player);
    perform private.recalculate_user_aggregates(player);
  end loop;
end;
$$;

create or replace function public.cast_mvp_vote(target_match uuid, target_player uuid)
returns void
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
  if target.status <> 'completed' or target.mvp_voting_ends_at is null or now() >= target.mvp_voting_ends_at then
    raise exception 'mvp_voting_closed';
  end if;
  if caller = target_player then raise exception 'cannot_vote_self'; end if;
  if not exists (select 1 from public.player_match_stats where match_id = target_match and user_id = caller) then
    raise exception 'participant_required';
  end if;
  if not exists (select 1 from public.player_match_stats where match_id = target_match and user_id = target_player) then
    raise exception 'invalid_mvp_candidate';
  end if;
  insert into public.mvp_votes (match_id, voter_id, voted_player_id)
  values (target_match, caller, target_player);
end;
$$;

create or replace function public.finalize_match_mvp(target_match uuid)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  target public.matches%rowtype;
  winner uuid;
  player uuid;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  select * into target from public.matches where id = target_match for update;
  if target.id is null then raise exception 'match_not_found'; end if;
  if not exists (
    select 1 from public.league_members
    where league_id = target.league_id and user_id = caller and status = 'active'
  ) then raise exception 'membership_required'; end if;
  if target.status <> 'completed' or target.mvp_voting_ends_at is null or now() < target.mvp_voting_ends_at then
    raise exception 'mvp_voting_open';
  end if;
  if target.mvp_finalized_at is not null then
    return (select user_id from public.player_match_stats where match_id = target_match and is_mvp limit 1);
  end if;

  select stats.user_id into winner
  from public.player_match_stats stats
  left join public.mvp_votes vote on vote.match_id = stats.match_id and vote.voted_player_id = stats.user_id
  where stats.match_id = target_match
  group by stats.id, stats.user_id, stats.goals, stats.assists, stats.previous_overall
  order by count(vote.id) desc, stats.goals desc, stats.assists desc,
    stats.previous_overall asc nulls last, stats.user_id asc
  limit 1;
  if winner is null then raise exception 'no_mvp_candidates'; end if;

  update public.player_match_stats set is_mvp = (user_id = winner) where match_id = target_match;
  update public.matches set mvp_finalized_at = now() where id = target_match;
  for player in select user_id from public.player_match_stats where match_id = target_match loop
    perform private.recalculate_user_rating(player);
    perform private.recalculate_user_aggregates(player);
  end loop;
  return winner;
end;
$$;

alter table public.match_teams enable row level security;
alter table public.match_team_players enable row level security;
alter table public.match_events enable row level security;
alter table public.player_match_stats enable row level security;
alter table public.mvp_votes enable row level security;

create policy "League members read match teams" on public.match_teams for select to authenticated
using (exists (select 1 from public.matches match where match.id = match_id and (select private.is_league_member(match.league_id))));
create policy "League members read team players" on public.match_team_players for select to authenticated
using (exists (select 1 from public.matches match where match.id = match_id and (select private.is_league_member(match.league_id))));
create policy "League members read match events" on public.match_events for select to authenticated
using (exists (select 1 from public.matches match where match.id = match_id and (select private.is_league_member(match.league_id))));
create policy "League members read player match stats" on public.player_match_stats for select to authenticated
using (exists (select 1 from public.matches match where match.id = match_id and (select private.is_league_member(match.league_id))));
create policy "Participants read own MVP vote" on public.mvp_votes for select to authenticated
using (voter_id = (select auth.uid()));

revoke insert, update, delete on public.match_teams from authenticated;
revoke insert, update, delete on public.match_team_players from authenticated;
revoke insert, update, delete on public.match_events from authenticated;
revoke insert, update, delete on public.player_match_stats from authenticated;
revoke insert, update, delete on public.mvp_votes from authenticated;
revoke insert, update, delete on public.player_rating_history from authenticated;
revoke update on public.player_stats from authenticated;

revoke all on function private.validate_team_player() from public, anon, authenticated;
revoke all on function private.recalculate_user_rating(uuid) from public, anon, authenticated;
revoke all on function private.recalculate_user_aggregates(uuid) from public, anon, authenticated;
revoke all on function public.finalize_match(uuid, uuid[], uuid[], integer, integer, jsonb) from public, anon;
revoke all on function public.cast_mvp_vote(uuid, uuid) from public, anon;
revoke all on function public.finalize_match_mvp(uuid) from public, anon;
grant execute on function public.finalize_match(uuid, uuid[], uuid[], integer, integer, jsonb) to authenticated;
grant execute on function public.cast_mvp_vote(uuid, uuid) to authenticated;
grant execute on function public.finalize_match_mvp(uuid) to authenticated;
