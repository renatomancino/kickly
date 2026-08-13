-- Demo password for every seeded account: KicklyDemo123!
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token
)
select
  '00000000-0000-0000-0000-000000000000',
  demo.id,
  'authenticated',
  'authenticated',
  demo.email,
  extensions.crypt('KicklyDemo123!', extensions.gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  now(), now(), '', ''
from (values
  ('10000000-0000-0000-0000-000000000001'::uuid, 'marco@kickly.local'),
  ('10000000-0000-0000-0000-000000000002'::uuid, 'luca@kickly.local'),
  ('10000000-0000-0000-0000-000000000003'::uuid, 'andrea@kickly.local'),
  ('10000000-0000-0000-0000-000000000004'::uuid, 'davide@kickly.local'),
  ('10000000-0000-0000-0000-000000000005'::uuid, 'matteo@kickly.local'),
  ('10000000-0000-0000-0000-000000000006'::uuid, 'simone@kickly.local'),
  ('10000000-0000-0000-0000-000000000007'::uuid, 'lorenzo@kickly.local'),
  ('10000000-0000-0000-0000-000000000008'::uuid, 'alessio@kickly.local'),
  ('10000000-0000-0000-0000-000000000009'::uuid, 'federico@kickly.local'),
  ('10000000-0000-0000-0000-000000000010'::uuid, 'gabriele@kickly.local'),
  ('10000000-0000-0000-0000-000000000011'::uuid, 'nicolo@kickly.local'),
  ('10000000-0000-0000-0000-000000000012'::uuid, 'stefano@kickly.local')
) as demo(id, email)
on conflict (id) do nothing;

insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select
  u.email,
  u.id,
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  'email', now(), now(), now()
from auth.users u
where u.email like '%@kickly.local'
on conflict (provider_id, provider) do nothing;

update public.profiles p set
  first_name = demo.first_name,
  last_name = demo.last_name,
  username = demo.username,
  city = 'Milano',
  primary_position = demo.position::public.football_role,
  preferred_foot = demo.foot::public.preferred_foot,
  skill_level = demo.level::public.skill_level,
  overall = demo.overall,
  onboarding_completed = true
from (values
  ('10000000-0000-0000-0000-000000000001'::uuid, 'Marco', 'Rossi', 'marcor10', 'midfielder', 'right', 'intermediate', 76.4),
  ('10000000-0000-0000-0000-000000000002'::uuid, 'Luca', 'Bianchi', 'lukaku7', 'forward', 'left', 'advanced', 79.2),
  ('10000000-0000-0000-0000-000000000003'::uuid, 'Andrea', 'Romano', 'andre_wall', 'goalkeeper', 'right', 'intermediate', 74.8),
  ('10000000-0000-0000-0000-000000000004'::uuid, 'Davide', 'Esposito', 'dave_4', 'defender', 'right', 'intermediate', 75.1),
  ('10000000-0000-0000-0000-000000000005'::uuid, 'Matteo', 'Ricci', 'teo10', 'midfielder', 'both', 'advanced', 78.6),
  ('10000000-0000-0000-0000-000000000006'::uuid, 'Simone', 'Marino', 'simo9', 'forward', 'right', 'amateur', 72.7),
  ('10000000-0000-0000-0000-000000000007'::uuid, 'Lorenzo', 'Greco', 'lore3', 'defender', 'left', 'intermediate', 73.9),
  ('10000000-0000-0000-0000-000000000008'::uuid, 'Alessio', 'Gallo', 'ale_box', 'goalkeeper', 'right', 'amateur', 71.8),
  ('10000000-0000-0000-0000-000000000009'::uuid, 'Federico', 'Costa', 'fede8', 'midfielder', 'right', 'intermediate', 74.2),
  ('10000000-0000-0000-0000-000000000010'::uuid, 'Gabriele', 'Fontana', 'gabri11', 'forward', 'left', 'amateur', 72.1),
  ('10000000-0000-0000-0000-000000000011'::uuid, 'Nicolò', 'Conti', 'nico5', 'defender', 'right', 'advanced', 77.3),
  ('10000000-0000-0000-0000-000000000012'::uuid, 'Stefano', 'Serra', 'ste_6', 'midfielder', 'both', 'amateur', 71.9)
) as demo(id, first_name, last_name, username, position, foot, level, overall)
where p.id = demo.id;

insert into public.leagues (
  id, owner_id, name, slug, description, city, visibility, football_format, max_members, invite_code
) values (
  '20000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  'Calcetto del Giovedì',
  'calcetto-del-giovedi',
  'La lega demo di Kickly: agonismo quanto basta, terzo tempo obbligatorio.',
  'Milano', 'public', '5v5', 10, 'KICKLY25'
) on conflict (id) do nothing;

insert into public.league_members (league_id, user_id, role, status)
select
  '20000000-0000-0000-0000-000000000001',
  id,
  case when id = '10000000-0000-0000-0000-000000000001' then 'owner'::public.league_role else 'member'::public.league_role end,
  'active'
from public.profiles
where id::text like '10000000-0000-0000-0000-%'
on conflict (league_id, user_id) do nothing;

insert into public.seasons (id, league_id, name, starts_on, is_active)
values (
  '30000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  'Stagione 2026', current_date - 90, true
) on conflict (id) do nothing;

insert into public.matches (
  id, league_id, season_id, created_by, title, starts_at, location_name, address, city,
  latitude, longitude, football_format, max_players, visibility, status,
  team_a_score, team_b_score, completed_at, mvp_deadline
) values
  (
    '40000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'Giovedì sotto le luci', now() + interval '3 days', 'Centro Sportivo Aurora',
    'Via Savona 35, Milano', 'Milano', 45.451200, 9.157800, '5v5', 10, 'public', 'open',
    null, null, null, null
  ),
  (
    '40000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'Classica del giovedì', now() - interval '7 days', 'Centro Sportivo Aurora',
    'Via Savona 35, Milano', 'Milano', 45.451200, 9.157800, '5v5', 10, 'league_only', 'completed',
    7, 5, now() - interval '7 days', now() - interval '6 days'
  ),
  (
    '40000000-0000-0000-0000-000000000003',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'Rivincita indoor', now() - interval '14 days', 'Arena Milano',
    'Viale Certosa 12, Milano', 'Milano', 45.502100, 9.147600, '5v5', 10, 'league_only', 'completed',
    4, 4, now() - interval '14 days', now() - interval '13 days'
  )
on conflict (id) do nothing;

insert into public.match_participants (match_id, user_id, response, checked_in)
select m.id, p.id, 'going', m.status = 'completed'
from public.matches m
cross join lateral (
  select id from public.profiles
  where id::text like '10000000-0000-0000-0000-%'
  order by id limit 10
) p
where m.id in (
  '40000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000002',
  '40000000-0000-0000-0000-000000000003'
)
on conflict (match_id, user_id) do nothing;

insert into public.player_match_stats (match_id, user_id, team, played, won, draw, goals, assists, rating_delta)
select
  m.id,
  p.id,
  case when right(p.id::text, 1)::int % 2 = 1 then 'A'::public.team_side else 'B'::public.team_side end,
  true,
  case when m.id = '40000000-0000-0000-0000-000000000002'
    then right(p.id::text, 1)::int % 2 = 1 else null end,
  m.id = '40000000-0000-0000-0000-000000000003',
  case when right(p.id::text, 1)::int in (1, 2, 5, 6) then 1 else 0 end,
  case when right(p.id::text, 1)::int in (1, 4, 9) then 1 else 0 end,
  case when m.id = '40000000-0000-0000-0000-000000000002' then 0.3 else 0.1 end
from public.matches m
cross join lateral (
  select id from public.profiles
  where id::text like '10000000-0000-0000-0000-%'
  order by id limit 10
) p
where m.status = 'completed'
on conflict (match_id, user_id) do nothing;

update public.player_stats stats set
  matches_played = 2,
  wins = case when right(stats.user_id::text, 1)::int % 2 = 1 then 1 else 0 end,
  draws = 1,
  losses = case when right(stats.user_id::text, 1)::int % 2 = 0 then 1 else 0 end,
  goals = case when right(stats.user_id::text, 1)::int in (1, 2, 5, 6) then 2 else 0 end,
  assists = case when right(stats.user_id::text, 1)::int in (1, 4, 9) then 2 else 0 end,
  mvp_awards = case when stats.user_id = '10000000-0000-0000-0000-000000000002' then 1 else 0 end,
  current_streak = case when right(stats.user_id::text, 1)::int % 2 = 1 then 2 else 1 end,
  overall = p.overall
from public.profiles p
where stats.user_id = p.id and stats.league_id is null and stats.season_id is null;

insert into public.player_rating_history (player_id, match_id, rating, delta, reason, recorded_at)
select
  p.id,
  '40000000-0000-0000-0000-000000000002',
  p.overall,
  least(0.8, greatest(-0.8, p.overall - 70)),
  'Prestazione partita',
  now() - interval '7 days'
from public.profiles p
where p.id::text like '10000000-0000-0000-0000-%';

update public.match_participants
set response = 'maybe'
where match_id = '40000000-0000-0000-0000-000000000001'
  and user_id in (
    '10000000-0000-0000-0000-000000000009',
    '10000000-0000-0000-0000-000000000010'
  );
