alter type public.match_visibility rename value 'league' to 'league_only';
alter type public.match_status rename value 'scheduled' to 'open';
alter type public.match_status rename value 'in_progress' to 'full';
alter type public.match_status add value if not exists 'draft' before 'open';

alter table public.matches rename column venue_name to location_name;
alter table public.matches rename column match_format to football_format;
alter table public.matches rename column notes to description;
alter table public.matches rename column field_cost to cost_total;
alter table public.matches add column city text;
alter table public.matches add column registration_closed_at timestamptz;

update public.matches m
set city = l.city
from public.leagues l
where l.id = m.league_id and m.city is null;

alter table public.matches alter column city set not null;
alter table public.matches add constraint matches_city_length check (char_length(btrim(city)) between 2 and 80);

alter table public.match_participants rename column status to response;
alter table public.match_participants rename column responded_at to joined_at;
alter table public.match_participants add column id uuid default gen_random_uuid();
update public.match_participants set id = gen_random_uuid() where id is null;
alter table public.match_participants alter column id set not null;
alter table public.match_participants drop constraint match_participants_pkey;
alter table public.match_participants add constraint match_participants_pkey primary key (id);
alter table public.match_participants add constraint match_participants_match_user_key unique (match_id, user_id);

drop index if exists public.matches_public_starts_idx;
create index matches_public_starts_idx on public.matches (starts_at)
where visibility = 'public' and status in ('open', 'full');
create index match_participants_waitlist_idx
on public.match_participants (match_id, joined_at, id)
where response = 'waitlist';

create or replace function private.is_match_participant(target_match uuid)
returns boolean
language sql stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.match_participants
    where match_id = target_match
      and user_id = (select auth.uid())
      and response = 'going'
  );
$$;

create or replace function private.rebalance_match(target_match uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  target public.matches%rowtype;
  confirmed_count integer;
  free_slots integer;
begin
  select * into target
  from public.matches
  where id = target_match
  for update;

  if target.id is null or target.status in ('cancelled', 'completed') then
    return;
  end if;

  select count(*) into confirmed_count
  from public.match_participants
  where match_id = target_match and response = 'going';

  free_slots := greatest(target.max_players - confirmed_count, 0);
  if free_slots > 0 then
    update public.match_participants participant
    set response = 'going', joined_at = now()
    where participant.id in (
      select queued.id
      from public.match_participants queued
      where queued.match_id = target_match and queued.response = 'waitlist'
      order by queued.joined_at, queued.id
      limit free_slots
      for update skip locked
    );
  end if;

  select count(*) into confirmed_count
  from public.match_participants
  where match_id = target_match and response = 'going';

  update public.matches
  set status = case when confirmed_count >= max_players then 'full'::public.match_status else 'open'::public.match_status end
  where id = target_match and status in ('open', 'full');
end;
$$;

create or replace function public.create_match(
  target_league uuid,
  match_title text,
  match_description text,
  match_starts_at timestamptz,
  match_location_name text,
  match_address text,
  match_city text,
  match_football_format public.match_format,
  match_max_players integer,
  match_cost_total numeric,
  match_visibility public.match_visibility
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  created_id uuid;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  if not exists (
    select 1 from public.league_members
    where league_id = target_league and user_id = caller
      and status = 'active' and role in ('owner', 'admin')
  ) then raise exception 'admin_required'; end if;
  if char_length(btrim(match_title)) not between 3 and 100 then raise exception 'invalid_title'; end if;
  if char_length(btrim(match_location_name)) not between 2 and 120 then raise exception 'invalid_location'; end if;
  if char_length(btrim(match_city)) not between 2 and 80 then raise exception 'invalid_city'; end if;
  if match_max_players not between 4 and 30 then raise exception 'invalid_max_players'; end if;
  if match_cost_total is not null and match_cost_total < 0 then raise exception 'invalid_cost'; end if;

  insert into public.matches (
    league_id, created_by, title, description, starts_at, location_name,
    address, city, football_format, max_players, cost_total, visibility, status
  ) values (
    target_league, caller, btrim(match_title), nullif(btrim(match_description), ''),
    match_starts_at, btrim(match_location_name), nullif(btrim(match_address), ''),
    btrim(match_city), match_football_format, match_max_players,
    match_cost_total, match_visibility, 'open'
  ) returning id into created_id;

  return created_id;
end;
$$;

create or replace function public.update_match_details(
  target_match uuid,
  match_title text,
  match_description text,
  match_starts_at timestamptz,
  match_location_name text,
  match_address text,
  match_city text,
  match_football_format public.match_format,
  match_max_players integer,
  match_cost_total numeric,
  match_visibility public.match_visibility
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
  confirmed_count integer;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  select * into target from public.matches where id = target_match for update;
  if target.id is null then raise exception 'match_not_found'; end if;
  if not exists (
    select 1 from public.league_members
    where league_id = target.league_id and user_id = caller
      and status = 'active' and role in ('owner', 'admin')
  ) then raise exception 'admin_required'; end if;
  if target.status in ('cancelled', 'completed') then raise exception 'match_locked'; end if;
  if char_length(btrim(match_title)) not between 3 and 100 then raise exception 'invalid_title'; end if;
  if char_length(btrim(match_location_name)) not between 2 and 120 then raise exception 'invalid_location'; end if;
  if char_length(btrim(match_city)) not between 2 and 80 then raise exception 'invalid_city'; end if;
  if match_max_players not between 4 and 30 then raise exception 'invalid_max_players'; end if;
  if match_cost_total is not null and match_cost_total < 0 then raise exception 'invalid_cost'; end if;

  select count(*) into confirmed_count
  from public.match_participants
  where match_id = target_match and response = 'going';
  if match_max_players < confirmed_count then raise exception 'max_below_confirmed'; end if;

  update public.matches set
    title = btrim(match_title),
    description = nullif(btrim(match_description), ''),
    starts_at = match_starts_at,
    location_name = btrim(match_location_name),
    address = nullif(btrim(match_address), ''),
    city = btrim(match_city),
    football_format = match_football_format,
    max_players = match_max_players,
    cost_total = match_cost_total,
    visibility = match_visibility
  where id = target_match;

  perform private.rebalance_match(target_match);
end;
$$;

create or replace function public.set_match_admin_state(target_match uuid, target_action text)
returns table (match_status public.match_status, closed_at timestamptz)
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
  if not exists (
    select 1 from public.league_members
    where league_id = target.league_id and user_id = caller
      and status = 'active' and role in ('owner', 'admin')
  ) then raise exception 'admin_required'; end if;

  if target_action = 'cancel' then
    if target.status = 'completed' then raise exception 'match_locked'; end if;
    update public.matches set status = 'cancelled', registration_closed_at = coalesce(registration_closed_at, now())
    where id = target_match;
  elsif target_action = 'close' then
    if target.status in ('cancelled', 'completed') then raise exception 'match_locked'; end if;
    update public.matches set registration_closed_at = now() where id = target_match;
  elsif target_action = 'reopen' then
    if target.status in ('cancelled', 'completed') then raise exception 'match_locked'; end if;
    update public.matches set registration_closed_at = null where id = target_match;
  else
    raise exception 'invalid_action';
  end if;

  return query select m.status, m.registration_closed_at from public.matches m where m.id = target_match;
end;
$$;

create or replace function public.set_match_response(
  target_match uuid,
  target_response public.attendance_status
)
returns table (
  actual_response public.attendance_status,
  going_count bigint,
  waitlist_position bigint,
  match_status public.match_status
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  target public.matches%rowtype;
  previous_response public.attendance_status;
  chosen_response public.attendance_status;
  confirmed_count bigint;
  own_joined_at timestamptz;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  if target_response = 'waitlist' then raise exception 'invalid_response'; end if;

  select * into target from public.matches where id = target_match for update;
  if target.id is null then raise exception 'match_not_found'; end if;
  if target.status not in ('open', 'full') then raise exception 'match_locked'; end if;
  if target.registration_closed_at is not null then raise exception 'registrations_closed'; end if;
  if not exists (
    select 1 from public.league_members
    where league_id = target.league_id and user_id = caller and status = 'active'
  ) then raise exception 'membership_required'; end if;

  select response into previous_response
  from public.match_participants
  where match_id = target_match and user_id = caller
  for update;

  select count(*) into confirmed_count
  from public.match_participants
  where match_id = target_match and response = 'going';

  chosen_response := target_response;
  if target_response = 'going' and previous_response is distinct from 'going' and confirmed_count >= target.max_players then
    chosen_response := 'waitlist';
  end if;

  insert into public.match_participants (match_id, user_id, response, joined_at)
  values (target_match, caller, chosen_response, now())
  on conflict (match_id, user_id) do update
  set response = excluded.response,
      joined_at = case
        when public.match_participants.response = excluded.response then public.match_participants.joined_at
        else now()
      end;

  perform private.rebalance_match(target_match);

  select p.response, p.joined_at into chosen_response, own_joined_at
  from public.match_participants p
  where p.match_id = target_match and p.user_id = caller;

  select count(*) into confirmed_count
  from public.match_participants
  where match_id = target_match and response = 'going';

  return query
  select
    chosen_response,
    confirmed_count,
    case when chosen_response = 'waitlist' then (
      select count(*)
      from public.match_participants queued
      where queued.match_id = target_match
        and queued.response = 'waitlist'
        and (queued.joined_at, queued.id) <= (
          own_joined_at,
          (select mine.id from public.match_participants mine
           where mine.match_id = target_match and mine.user_id = caller)
        )
    ) else null::bigint end,
    (select m.status from public.matches m where m.id = target_match);
end;
$$;

create or replace function private.remove_future_match_responses()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  affected_match uuid;
begin
  for affected_match in
    select participant.match_id
    from public.match_participants participant
    join public.matches match on match.id = participant.match_id
    where participant.user_id = old.user_id
      and match.league_id = old.league_id
      and match.starts_at >= now()
      and match.status not in ('cancelled', 'completed')
  loop
    delete from public.match_participants
    where match_id = affected_match and user_id = old.user_id;
    perform private.rebalance_match(affected_match);
  end loop;
  return old;
end;
$$;

drop trigger if exists remove_future_match_responses on public.league_members;
create trigger remove_future_match_responses
after delete on public.league_members
for each row execute function private.remove_future_match_responses();

create or replace function private.validate_mvp_vote()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  vote_deadline timestamptz;
  current_status public.match_status;
begin
  select m.mvp_deadline, m.status into vote_deadline, current_status
  from public.matches m where m.id = new.match_id;
  if current_status <> 'completed' or vote_deadline is null or now() > vote_deadline then raise exception 'MVP voting is closed'; end if;
  if new.voter_id <> (select auth.uid()) then raise exception 'Voter must match authenticated user'; end if;
  if not exists (select 1 from public.match_participants where match_id = new.match_id and user_id = new.voter_id and response = 'going') then raise exception 'Voter did not participate'; end if;
  if not exists (select 1 from public.match_participants where match_id = new.match_id and user_id = new.candidate_id and response = 'going') then raise exception 'Candidate did not participate'; end if;
  return new;
end;
$$;

drop policy if exists "Visible matches are readable" on public.matches;
drop policy if exists "League managers create matches" on public.matches;
drop policy if exists "League managers update matches" on public.matches;
drop policy if exists "League managers delete matches" on public.matches;
create policy "League members read matches" on public.matches for select
to authenticated using ((select private.is_league_member(league_id)));

drop policy if exists "Match participants are readable" on public.match_participants;
drop policy if exists "Users respond to matches" on public.match_participants;
drop policy if exists "Users update their response" on public.match_participants;
drop policy if exists "Users remove their response" on public.match_participants;
create policy "League members read match responses" on public.match_participants for select
to authenticated using (
  exists (
    select 1 from public.matches m
    where m.id = match_id and (select private.is_league_member(m.league_id))
  )
);

revoke insert, update, delete on public.matches from authenticated;
revoke insert, update, delete on public.match_participants from authenticated;
revoke select on public.matches from anon;

revoke all on function private.rebalance_match(uuid) from public, anon, authenticated;
revoke all on function private.remove_future_match_responses() from public, anon, authenticated;

revoke all on function public.create_match(uuid, text, text, timestamptz, text, text, text, public.match_format, integer, numeric, public.match_visibility) from public, anon;
revoke all on function public.update_match_details(uuid, text, text, timestamptz, text, text, text, public.match_format, integer, numeric, public.match_visibility) from public, anon;
revoke all on function public.set_match_admin_state(uuid, text) from public, anon;
revoke all on function public.set_match_response(uuid, public.attendance_status) from public, anon;
grant execute on function public.create_match(uuid, text, text, timestamptz, text, text, text, public.match_format, integer, numeric, public.match_visibility) to authenticated;
grant execute on function public.update_match_details(uuid, text, text, timestamptz, text, text, text, public.match_format, integer, numeric, public.match_visibility) to authenticated;
grant execute on function public.set_match_admin_state(uuid, text) to authenticated;
grant execute on function public.set_match_response(uuid, public.attendance_status) to authenticated;
