create schema if not exists private;
create extension if not exists citext with schema extensions;
create extension if not exists pgcrypto with schema extensions;

create type public.football_role as enum ('goalkeeper', 'defender', 'midfielder', 'forward');
create type public.preferred_foot as enum ('left', 'right', 'both');
create type public.skill_level as enum ('beginner', 'amateur', 'intermediate', 'advanced');
create type public.league_privacy as enum ('private', 'public');
create type public.league_role as enum ('owner', 'admin', 'member');
create type public.membership_status as enum ('pending', 'active', 'removed');
create type public.match_format as enum ('5v5', '7v7', '8v8', '11v11');
create type public.match_visibility as enum ('league', 'public');
create type public.match_status as enum ('scheduled', 'in_progress', 'completed', 'cancelled');
create type public.attendance_status as enum ('going', 'not_going', 'maybe', 'waitlist');
create type public.team_side as enum ('A', 'B');
create type public.match_event_type as enum ('goal', 'assist', 'own_goal', 'yellow_card', 'red_card');
create type public.notification_type as enum (
  'new_match', 'match_updated', 'match_cancelled', 'reminder', 'mvp_vote',
  'mvp_winner', 'result', 'league_invite', 'join_request'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  last_name text,
  username extensions.citext not null unique,
  birth_date date,
  city text,
  avatar_path text,
  primary_position public.football_role,
  secondary_position public.football_role,
  preferred_foot public.preferred_foot,
  skill_level public.skill_level,
  overall numeric(4,1) not null default 70 check (overall between 1 and 99),
  onboarding_completed boolean not null default false,
  profile_public boolean not null default true,
  timezone text not null default 'Europe/Rome',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint distinct_positions check (
    secondary_position is null or secondary_position <> primary_position
  )
);

create table public.leagues (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  name text not null check (char_length(name) between 3 and 80),
  slug extensions.citext not null unique,
  description text,
  logo_path text,
  city text not null,
  privacy public.league_privacy not null default 'private',
  sport text not null default 'football' check (sport = 'football'),
  match_format public.match_format not null default '5v5',
  max_players smallint not null default 10 check (max_players between 4 and 30),
  invite_code text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.league_members (
  league_id uuid not null references public.leagues(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.league_role not null default 'member',
  status public.membership_status not null default 'active',
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (league_id, user_id)
);

create table public.league_invites (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  code text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)),
  created_by uuid not null references public.profiles(id) on delete cascade,
  expires_at timestamptz,
  max_uses integer check (max_uses is null or max_uses > 0),
  uses integer not null default 0 check (uses >= 0),
  created_at timestamptz not null default now()
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  name text not null,
  starts_on date not null,
  ends_on date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint valid_season_dates check (ends_on is null or ends_on >= starts_on)
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  season_id uuid references public.seasons(id) on delete set null,
  created_by uuid not null references public.profiles(id) on delete restrict,
  title text not null check (char_length(title) between 3 and 100),
  starts_at timestamptz not null,
  venue_name text not null,
  address text,
  latitude numeric(9,6) check (latitude between -90 and 90),
  longitude numeric(9,6) check (longitude between -180 and 180),
  match_format public.match_format not null,
  max_players smallint not null check (max_players between 4 and 30),
  notes text,
  field_cost numeric(8,2) check (field_cost is null or field_cost >= 0),
  visibility public.match_visibility not null default 'league',
  status public.match_status not null default 'scheduled',
  team_a_score smallint check (team_a_score is null or team_a_score >= 0),
  team_b_score smallint check (team_b_score is null or team_b_score >= 0),
  mvp_deadline timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint coordinates_together check (
    (latitude is null and longitude is null) or (latitude is not null and longitude is not null)
  ),
  constraint scores_together check (
    (team_a_score is null and team_b_score is null) or
    (team_a_score is not null and team_b_score is not null)
  )
);

create table public.match_participants (
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status public.attendance_status not null,
  checked_in boolean not null default false,
  responded_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (match_id, user_id)
);

create table public.match_teams (
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  team public.team_side not null,
  assigned_at timestamptz not null default now(),
  primary key (match_id, user_id)
);

create table public.match_events (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  assist_player_id uuid references public.profiles(id) on delete set null,
  event_type public.match_event_type not null,
  quantity smallint not null default 1 check (quantity between 1 and 99),
  minute smallint check (minute is null or minute between 0 and 180),
  recorded_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint different_assist_player check (assist_player_id is null or assist_player_id <> player_id)
);

create table public.player_match_stats (
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  team public.team_side,
  played boolean not null default true,
  won boolean,
  draw boolean not null default false,
  goals smallint not null default 0 check (goals >= 0),
  assists smallint not null default 0 check (assists >= 0),
  clean_sheet boolean not null default false,
  goals_conceded smallint not null default 0 check (goals_conceded >= 0),
  defensive_rating numeric(3,1) check (defensive_rating between 1 and 10),
  goalkeeper_rating numeric(3,1) check (goalkeeper_rating between 1 and 10),
  rating_delta numeric(3,2) not null default 0 check (rating_delta between -2 and 2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (match_id, user_id)
);

create table public.mvp_votes (
  match_id uuid not null references public.matches(id) on delete cascade,
  voter_id uuid not null references public.profiles(id) on delete cascade,
  candidate_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (match_id, voter_id),
  constraint cannot_vote_self check (voter_id <> candidate_id)
);

create table public.player_stats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  league_id uuid references public.leagues(id) on delete cascade,
  season_id uuid references public.seasons(id) on delete cascade,
  matches_played integer not null default 0 check (matches_played >= 0),
  wins integer not null default 0 check (wins >= 0),
  draws integer not null default 0 check (draws >= 0),
  losses integer not null default 0 check (losses >= 0),
  goals integer not null default 0 check (goals >= 0),
  assists integer not null default 0 check (assists >= 0),
  mvp_awards integer not null default 0 check (mvp_awards >= 0),
  current_streak integer not null default 0,
  overall numeric(4,1) not null default 70 check (overall between 1 and 99),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (user_id, league_id, season_id),
  constraint valid_match_record check (wins + draws + losses <= matches_played)
);

create table public.player_rating_history (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  match_id uuid references public.matches(id) on delete set null,
  rating numeric(4,1) not null check (rating between 1 and 99),
  delta numeric(3,2) not null default 0 check (delta between -2 and 2),
  reason text not null,
  recorded_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type public.notification_type not null,
  title text not null,
  body text not null,
  read boolean not null default false,
  link text,
  created_at timestamptz not null default now()
);

create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_username_idx on public.profiles (username);
create index league_members_user_idx on public.league_members (user_id, status);
create index league_invites_league_idx on public.league_invites (league_id);
create index seasons_league_idx on public.seasons (league_id, is_active);
create index matches_league_starts_idx on public.matches (league_id, starts_at desc);
create index matches_public_starts_idx on public.matches (starts_at) where visibility = 'public' and status = 'scheduled';
create index matches_coordinates_idx on public.matches (latitude, longitude) where latitude is not null;
create index match_participants_user_idx on public.match_participants (user_id, status);
create index match_events_match_idx on public.match_events (match_id);
create index player_match_stats_user_idx on public.player_match_stats (user_id);
create index mvp_votes_candidate_idx on public.mvp_votes (match_id, candidate_id);
create index player_stats_leaderboard_idx on public.player_stats (league_id, overall desc);
create index rating_history_player_idx on public.player_rating_history (player_id, recorded_at desc);
create index notifications_user_idx on public.notifications (user_id, read, created_at desc);
create index push_subscriptions_user_idx on public.push_subscriptions (user_id);

create or replace function private.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at before update on public.profiles for each row execute function private.set_updated_at();
create trigger leagues_updated_at before update on public.leagues for each row execute function private.set_updated_at();
create trigger league_members_updated_at before update on public.league_members for each row execute function private.set_updated_at();
create trigger seasons_updated_at before update on public.seasons for each row execute function private.set_updated_at();
create trigger matches_updated_at before update on public.matches for each row execute function private.set_updated_at();
create trigger match_participants_updated_at before update on public.match_participants for each row execute function private.set_updated_at();
create trigger match_events_updated_at before update on public.match_events for each row execute function private.set_updated_at();
create trigger player_match_stats_updated_at before update on public.player_match_stats for each row execute function private.set_updated_at();
create trigger mvp_votes_updated_at before update on public.mvp_votes for each row execute function private.set_updated_at();
create trigger player_stats_updated_at before update on public.player_stats for each row execute function private.set_updated_at();
create trigger push_subscriptions_updated_at before update on public.push_subscriptions for each row execute function private.set_updated_at();

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, username)
  values (new.id, 'player_' || substr(replace(new.id::text, '-', ''), 1, 12))
  on conflict (id) do nothing;
  insert into public.player_stats (user_id) values (new.id)
  on conflict (user_id, league_id, season_id) do nothing;
  insert into public.player_rating_history (player_id, rating, reason)
  values (new.id, 70, 'Valutazione iniziale');
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

create or replace function private.handle_new_league()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.league_members (league_id, user_id, role, status)
  values (new.id, new.owner_id, 'owner', 'active')
  on conflict (league_id, user_id) do update set role = 'owner', status = 'active';
  return new;
end;
$$;

create trigger on_league_created
after insert on public.leagues
for each row execute function private.handle_new_league();

create or replace function private.is_league_member(target_league uuid)
returns boolean
language sql stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.league_members
    where league_id = target_league
      and user_id = (select auth.uid())
      and status = 'active'
  );
$$;

create or replace function private.can_manage_league(target_league uuid)
returns boolean
language sql stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.league_members
    where league_id = target_league
      and user_id = (select auth.uid())
      and status = 'active'
      and role in ('owner', 'admin')
  );
$$;

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
      and status = 'going'
  );
$$;

create or replace function private.can_view_profile(target_user uuid)
returns boolean
language sql stable
security definer
set search_path = ''
as $$
  select target_user = (select auth.uid()) or exists (
    select 1 from public.profiles where id = target_user and profile_public = true
  );
$$;

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

  if current_status <> 'completed' or vote_deadline is null or now() > vote_deadline then
    raise exception 'MVP voting is closed';
  end if;
  if new.voter_id <> (select auth.uid()) then
    raise exception 'Voter must match authenticated user';
  end if;
  if not exists (
    select 1 from public.match_participants
    where match_id = new.match_id and user_id = new.voter_id and status = 'going'
  ) then
    raise exception 'Voter did not participate';
  end if;
  if not exists (
    select 1 from public.match_participants
    where match_id = new.match_id and user_id = new.candidate_id and status = 'going'
  ) then
    raise exception 'Candidate did not participate';
  end if;
  return new;
end;
$$;

create trigger validate_mvp_vote
before insert or update on public.mvp_votes
for each row execute function private.validate_mvp_vote();

create or replace function private.notify_new_match()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notifications (user_id, type, title, body, link)
  select lm.user_id, 'new_match', '⚽ Nuova partita nella tua lega', new.title,
         '/matches/' || new.id::text
  from public.league_members lm
  where lm.league_id = new.league_id
    and lm.status = 'active'
    and lm.user_id <> new.created_by;
  return new;
end;
$$;

create trigger notify_members_on_match
after insert on public.matches
for each row execute function private.notify_new_match();

revoke all on schema private from public;
grant usage on schema private to authenticated;
revoke execute on all functions in schema private from public;
grant execute on function private.is_league_member(uuid) to authenticated;
grant execute on function private.can_manage_league(uuid) to authenticated;
grant execute on function private.is_match_participant(uuid) to authenticated;
grant execute on function private.can_view_profile(uuid) to anon, authenticated;

alter table public.profiles enable row level security;
alter table public.leagues enable row level security;
alter table public.league_members enable row level security;
alter table public.league_invites enable row level security;
alter table public.seasons enable row level security;
alter table public.matches enable row level security;
alter table public.match_participants enable row level security;
alter table public.match_teams enable row level security;
alter table public.match_events enable row level security;
alter table public.player_match_stats enable row level security;
alter table public.mvp_votes enable row level security;
alter table public.player_stats enable row level security;
alter table public.player_rating_history enable row level security;
alter table public.notifications enable row level security;
alter table public.push_subscriptions enable row level security;

create policy "Public or own profiles are readable" on public.profiles for select
to anon, authenticated using (profile_public or id = (select auth.uid()));
create policy "Users create own profile" on public.profiles for insert
to authenticated with check (id = (select auth.uid()));
create policy "Users update own profile" on public.profiles for update
to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "Visible leagues are readable" on public.leagues for select
to anon, authenticated using (privacy = 'public' or (select private.is_league_member(id)));
create policy "Users create owned leagues" on public.leagues for insert
to authenticated with check (owner_id = (select auth.uid()));
create policy "League managers update leagues" on public.leagues for update
to authenticated using ((select private.can_manage_league(id)))
with check ((select private.can_manage_league(id)));
create policy "League owners delete leagues" on public.leagues for delete
to authenticated using (owner_id = (select auth.uid()));

create policy "League members read rosters" on public.league_members for select
to authenticated using (user_id = (select auth.uid()) or (select private.is_league_member(league_id)));
create policy "Users request membership" on public.league_members for insert
to authenticated with check (user_id = (select auth.uid()) and role = 'member');
create policy "League managers update memberships" on public.league_members for update
to authenticated using ((select private.can_manage_league(league_id)))
with check ((select private.can_manage_league(league_id)));
create policy "League managers remove memberships" on public.league_members for delete
to authenticated using ((select private.can_manage_league(league_id)) and role <> 'owner');

create policy "League members read invites" on public.league_invites for select
to authenticated using ((select private.is_league_member(league_id)));
create policy "League managers create invites" on public.league_invites for insert
to authenticated with check ((select private.can_manage_league(league_id)) and created_by = (select auth.uid()));
create policy "League managers update invites" on public.league_invites for update
to authenticated using ((select private.can_manage_league(league_id)))
with check ((select private.can_manage_league(league_id)));
create policy "League managers delete invites" on public.league_invites for delete
to authenticated using ((select private.can_manage_league(league_id)));

create policy "League members read seasons" on public.seasons for select
to authenticated using ((select private.is_league_member(league_id)));
create policy "League managers create seasons" on public.seasons for insert
to authenticated with check ((select private.can_manage_league(league_id)));
create policy "League managers update seasons" on public.seasons for update
to authenticated using ((select private.can_manage_league(league_id)))
with check ((select private.can_manage_league(league_id)));
create policy "League managers delete seasons" on public.seasons for delete
to authenticated using ((select private.can_manage_league(league_id)));

create policy "Visible matches are readable" on public.matches for select
to anon, authenticated using (visibility = 'public' or (select private.is_league_member(league_id)));
create policy "League managers create matches" on public.matches for insert
to authenticated with check ((select private.can_manage_league(league_id)) and created_by = (select auth.uid()));
create policy "League managers update matches" on public.matches for update
to authenticated using ((select private.can_manage_league(league_id)))
with check ((select private.can_manage_league(league_id)));
create policy "League managers delete matches" on public.matches for delete
to authenticated using ((select private.can_manage_league(league_id)));

create policy "Match participants are readable" on public.match_participants for select
to authenticated using (
  user_id = (select auth.uid()) or exists (
    select 1 from public.matches m where m.id = match_id
      and (m.visibility = 'public' or (select private.is_league_member(m.league_id)))
  )
);
create policy "Users respond to matches" on public.match_participants for insert
to authenticated with check (
  user_id = (select auth.uid()) or exists (
    select 1 from public.matches m where m.id = match_id and (select private.can_manage_league(m.league_id))
  )
);
create policy "Users update their response" on public.match_participants for update
to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Users remove their response" on public.match_participants for delete
to authenticated using (user_id = (select auth.uid()));

create policy "Visible teams are readable" on public.match_teams for select
to authenticated using (exists (
  select 1 from public.matches m where m.id = match_id
    and (m.visibility = 'public' or (select private.is_league_member(m.league_id)))
));
create policy "League managers manage teams" on public.match_teams for all
to authenticated using (exists (
  select 1 from public.matches m where m.id = match_id and (select private.can_manage_league(m.league_id))
)) with check (exists (
  select 1 from public.matches m where m.id = match_id and (select private.can_manage_league(m.league_id))
));

create policy "Visible events are readable" on public.match_events for select
to authenticated using (exists (
  select 1 from public.matches m where m.id = match_id
    and (m.visibility = 'public' or (select private.is_league_member(m.league_id)))
));
create policy "League managers manage events" on public.match_events for all
to authenticated using (exists (
  select 1 from public.matches m where m.id = match_id and (select private.can_manage_league(m.league_id))
)) with check (exists (
  select 1 from public.matches m where m.id = match_id and (select private.can_manage_league(m.league_id))
));

create policy "Visible match stats are readable" on public.player_match_stats for select
to authenticated using (exists (
  select 1 from public.matches m where m.id = match_id
    and (m.visibility = 'public' or (select private.is_league_member(m.league_id)))
));
create policy "League managers manage match stats" on public.player_match_stats for all
to authenticated using (exists (
  select 1 from public.matches m where m.id = match_id and (select private.can_manage_league(m.league_id))
)) with check (exists (
  select 1 from public.matches m where m.id = match_id and (select private.can_manage_league(m.league_id))
));

create policy "Participants read MVP votes" on public.mvp_votes for select
to authenticated using ((select private.is_match_participant(match_id)));
create policy "Participants cast one MVP vote" on public.mvp_votes for insert
to authenticated with check (voter_id = (select auth.uid()) and (select private.is_match_participant(match_id)));
create policy "Participants update open MVP vote" on public.mvp_votes for update
to authenticated using (voter_id = (select auth.uid())) with check (voter_id = (select auth.uid()));

create policy "Visible player stats are readable" on public.player_stats for select
to anon, authenticated using ((select private.can_view_profile(user_id)));
create policy "Visible rating history is readable" on public.player_rating_history for select
to anon, authenticated using ((select private.can_view_profile(player_id)));

create policy "Users read own notifications" on public.notifications for select
to authenticated using (user_id = (select auth.uid()));
create policy "Users update own notifications" on public.notifications for update
to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Users delete own notifications" on public.notifications for delete
to authenticated using (user_id = (select auth.uid()));

create policy "Users read own push subscriptions" on public.push_subscriptions for select
to authenticated using (user_id = (select auth.uid()));
create policy "Users create own push subscriptions" on public.push_subscriptions for insert
to authenticated with check (user_id = (select auth.uid()));
create policy "Users update own push subscriptions" on public.push_subscriptions for update
to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Users delete own push subscriptions" on public.push_subscriptions for delete
to authenticated using (user_id = (select auth.uid()));

grant select on public.profiles, public.leagues, public.matches, public.player_stats, public.player_rating_history to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('league-logos', 'league-logos', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Users upload own avatar" on storage.objects for insert
to authenticated with check (
  bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
);
create policy "Users read own avatar objects" on storage.objects for select
to authenticated using (
  bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
);
create policy "Users update own avatar" on storage.objects for update
to authenticated using (
  bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
) with check (
  bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
);
create policy "Users delete own avatar" on storage.objects for delete
to authenticated using (
  bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "League managers upload logos" on storage.objects for insert
to authenticated with check (
  bucket_id = 'league-logos'
  and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
  and (select private.can_manage_league(((storage.foldername(name))[1])::uuid))
);
create policy "League managers read logo objects" on storage.objects for select
to authenticated using (
  bucket_id = 'league-logos'
  and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
  and (select private.can_manage_league(((storage.foldername(name))[1])::uuid))
);
create policy "League managers update logos" on storage.objects for update
to authenticated using (
  bucket_id = 'league-logos'
  and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
  and (select private.can_manage_league(((storage.foldername(name))[1])::uuid))
) with check (
  bucket_id = 'league-logos'
  and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
  and (select private.can_manage_league(((storage.foldername(name))[1])::uuid))
);
create policy "League managers delete logos" on storage.objects for delete
to authenticated using (
  bucket_id = 'league-logos'
  and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
  and (select private.can_manage_league(((storage.foldername(name))[1])::uuid))
);
