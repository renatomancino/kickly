alter type public.membership_status rename value 'removed' to 'banned';

alter table public.leagues rename column privacy to visibility;
alter table public.leagues rename column match_format to football_format;
alter table public.leagues rename column max_players to max_members;
alter table public.leagues rename column logo_path to logo_url;
alter table public.leagues add column country text not null default 'IT';
alter table public.leagues drop constraint if exists leagues_max_players_check;
alter table public.leagues add constraint leagues_max_members_check
  check (max_members between 2 and 500);

alter table public.league_members add column id uuid not null default gen_random_uuid();
alter table public.league_members add column created_at timestamptz not null default now();
alter table public.league_members drop constraint league_members_pkey;
alter table public.league_members add constraint league_members_pkey primary key (id);
alter table public.league_members add constraint league_members_league_user_key unique (league_id, user_id);

create index league_members_league_status_idx
  on public.league_members (league_id, status, role);

create or replace function private.generate_invite_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  candidate text;
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  entropy bytea;
  position integer;
begin
  loop
    candidate := '';
    entropy := extensions.gen_random_bytes(10);
    for position in 0..9 loop
      candidate := candidate || substr(
        alphabet,
        (get_byte(entropy, position) % char_length(alphabet)) + 1,
        1
      );
    end loop;
    exit when not exists (
      select 1 from public.leagues where invite_code = candidate
    );
  end loop;
  return candidate;
end;
$$;

alter table public.leagues alter column invite_code drop default;
update public.leagues set invite_code = private.generate_invite_code();

create or replace function private.set_league_invite_code()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.invite_code is null or btrim(new.invite_code) = '' then
    new.invite_code := private.generate_invite_code();
  end if;
  return new;
end;
$$;

create trigger set_league_invite_code
before insert on public.leagues
for each row execute function private.set_league_invite_code();

drop policy if exists "Users request membership" on public.league_members;
drop policy if exists "League managers update memberships" on public.league_members;
drop policy if exists "League managers remove memberships" on public.league_members;

revoke insert, update, delete on public.league_members from authenticated;
revoke insert on public.leagues from authenticated;
revoke update on public.leagues from authenticated;
grant update (name, description, city, country, visibility, football_format, max_members, logo_url)
  on public.leagues to authenticated;

create or replace function public.create_league(
  league_name text,
  league_slug text,
  league_description text,
  league_city text,
  league_country text,
  league_visibility public.league_privacy,
  league_format public.match_format,
  league_max_members integer
)
returns table (id uuid, slug text, invite_code text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  created public.leagues%rowtype;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  if char_length(btrim(league_name)) not between 3 and 80 then raise exception 'invalid_name'; end if;
  if char_length(btrim(league_city)) not between 2 and 80 then raise exception 'invalid_city'; end if;
  if league_country !~ '^[A-Za-z]{2}$' then raise exception 'invalid_country'; end if;
  if league_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then raise exception 'invalid_slug'; end if;
  if league_max_members not between 2 and 500 then raise exception 'invalid_max_members'; end if;

  insert into public.leagues (
    owner_id, name, slug, description, city, country,
    visibility, football_format, max_members
  ) values (
    caller, btrim(league_name), league_slug, nullif(btrim(league_description), ''),
    btrim(league_city), upper(league_country), league_visibility,
    league_format, league_max_members
  ) returning * into created;

  return query select created.id, created.slug::text, created.invite_code;
end;
$$;

create or replace function public.get_league_invite_preview(invite text)
returns table (
  id uuid,
  name text,
  slug text,
  logo_url text,
  city text,
  country text,
  visibility public.league_privacy,
  football_format public.match_format,
  max_members integer,
  member_count bigint,
  already_member boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
begin
  if caller is null then
    raise exception 'authentication_required';
  end if;

  return query
  select
    l.id,
    l.name,
    l.slug::text,
    l.logo_url,
    l.city,
    l.country,
    l.visibility,
    l.football_format,
    l.max_members::integer,
    count(lm.id) filter (where lm.status = 'active') as member_count,
    exists (
      select 1 from public.league_members mine
      where mine.league_id = l.id and mine.user_id = caller and mine.status = 'active'
    ) as already_member
  from public.leagues l
  left join public.league_members lm on lm.league_id = l.id
  where upper(l.invite_code) = upper(btrim(invite))
  group by l.id;
end;
$$;

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
begin
  if caller is null then
    raise exception 'authentication_required';
  end if;

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

create or replace function public.set_league_member_role(
  target_league uuid,
  target_user uuid,
  target_role public.league_role
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
begin
  if caller is null then raise exception 'authentication_required'; end if;
  if target_role not in ('admin', 'member') then raise exception 'invalid_role'; end if;
  if not exists (
    select 1 from public.leagues where id = target_league and owner_id = caller
  ) then raise exception 'owner_required'; end if;
  if target_user = caller then raise exception 'cannot_change_owner_role'; end if;

  update public.league_members
  set role = target_role
  where league_id = target_league
    and user_id = target_user
    and status = 'active'
    and role <> 'owner';

  if not found then raise exception 'member_not_found'; end if;
end;
$$;

create or replace function public.remove_league_member(
  target_league uuid,
  target_user uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  caller_role public.league_role;
  member_role public.league_role;
begin
  if caller is null then raise exception 'authentication_required'; end if;

  select role into caller_role from public.league_members
  where league_id = target_league and user_id = caller and status = 'active';
  select role into member_role from public.league_members
  where league_id = target_league and user_id = target_user and status = 'active';

  if caller_role is null or caller_role not in ('owner', 'admin') then raise exception 'admin_required'; end if;
  if member_role is null then raise exception 'member_not_found'; end if;
  if member_role = 'owner' then raise exception 'cannot_remove_owner'; end if;
  if caller_role = 'admin' and member_role <> 'member' then
    raise exception 'owner_required';
  end if;

  delete from public.league_members
  where league_id = target_league and user_id = target_user;
end;
$$;

create or replace function public.leave_league(target_league uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  caller_role public.league_role;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  select role into caller_role from public.league_members
  where league_id = target_league and user_id = caller and status = 'active';
  if caller_role is null then raise exception 'member_not_found'; end if;
  if caller_role = 'owner' then raise exception 'owner_cannot_leave'; end if;
  delete from public.league_members where league_id = target_league and user_id = caller;
end;
$$;

create or replace function public.transfer_league_ownership(
  target_league uuid,
  target_user uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
begin
  if caller is null then raise exception 'authentication_required'; end if;
  if not exists (
    select 1 from public.leagues where id = target_league and owner_id = caller
  ) then raise exception 'owner_required'; end if;
  if target_user = caller then raise exception 'already_owner'; end if;
  if not exists (
    select 1 from public.league_members
    where league_id = target_league and user_id = target_user and status = 'active'
  ) then raise exception 'member_not_found'; end if;

  update public.league_members set role = 'admin'
  where league_id = target_league and user_id = caller;
  update public.league_members set role = 'owner'
  where league_id = target_league and user_id = target_user;
  update public.leagues set owner_id = target_user
  where id = target_league;
end;
$$;

create or replace function public.rotate_league_invite_code(target_league uuid)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  new_code text;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  if not exists (
    select 1 from public.leagues where id = target_league and owner_id = caller
  ) then raise exception 'owner_required'; end if;
  new_code := private.generate_invite_code();
  update public.leagues set invite_code = new_code where id = target_league;
  return new_code;
end;
$$;

revoke all on function public.get_league_invite_preview(text) from public, anon;
revoke all on function public.create_league(text, text, text, text, text, public.league_privacy, public.match_format, integer) from public, anon;
revoke all on function public.join_league_by_code(text) from public, anon;
revoke all on function public.set_league_member_role(uuid, uuid, public.league_role) from public, anon;
revoke all on function public.remove_league_member(uuid, uuid) from public, anon;
revoke all on function public.leave_league(uuid) from public, anon;
revoke all on function public.transfer_league_ownership(uuid, uuid) from public, anon;
revoke all on function public.rotate_league_invite_code(uuid) from public, anon;

grant execute on function public.get_league_invite_preview(text) to authenticated;
grant execute on function public.create_league(text, text, text, text, text, public.league_privacy, public.match_format, integer) to authenticated;
grant execute on function public.join_league_by_code(text) to authenticated;
grant execute on function public.set_league_member_role(uuid, uuid, public.league_role) to authenticated;
grant execute on function public.remove_league_member(uuid, uuid) to authenticated;
grant execute on function public.leave_league(uuid) to authenticated;
grant execute on function public.transfer_league_ownership(uuid, uuid) to authenticated;
grant execute on function public.rotate_league_invite_code(uuid) to authenticated;

create or replace function private.shares_active_league(target_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.league_members mine
    join public.league_members theirs on theirs.league_id = mine.league_id
    where mine.user_id = (select auth.uid())
      and mine.status = 'active'
      and theirs.user_id = target_user
      and theirs.status = 'active'
  );
$$;

grant execute on function private.shares_active_league(uuid) to authenticated;
drop policy if exists "Public or own profiles are readable" on public.profiles;
create policy "Public profiles are readable" on public.profiles for select
to anon, authenticated using (profile_public);
create policy "Users read own and league profiles" on public.profiles for select
to authenticated using (
  id = (select auth.uid()) or (select private.shares_active_league(id))
);
