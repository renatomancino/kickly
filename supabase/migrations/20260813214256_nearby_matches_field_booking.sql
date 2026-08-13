alter table public.profiles
  add column if not exists province text;

create table public.profile_locations (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  city text not null check (char_length(btrim(city)) between 2 and 80),
  province text not null check (char_length(btrim(province)) between 2 and 100),
  latitude numeric(9,6) not null check (latitude between 35 and 48),
  longitude numeric(9,6) not null check (longitude between 6 and 19),
  updated_at timestamptz not null default now()
);

alter table public.profile_locations enable row level security;

create policy "Users read own location"
on public.profile_locations for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Users create own location"
on public.profile_locations for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users update own location"
on public.profile_locations for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on table public.profile_locations from public, anon;
grant select, insert, update on table public.profile_locations to authenticated;

alter table public.matches
  add column if not exists province text,
  add column if not exists cover_image_url text,
  add column if not exists venue_image_url text,
  add column if not exists venue_phone text,
  add column if not exists field_booked_at timestamptz,
  add column if not exists field_booked_by uuid references public.profiles(id) on delete set null;

update public.matches
set province = coalesce(nullif(province, ''), 'Provincia non indicata')
where province is null or btrim(province) = '';

alter table public.matches
  alter column province set not null;

alter table public.matches
  add constraint matches_province_length
    check (char_length(btrim(province)) between 2 and 100),
  add constraint matches_venue_phone_format
    check (venue_phone is null or venue_phone ~ '^[0-9+() .-]{6,30}$'),
  add constraint matches_field_booking_pair
    check (
      (field_booked_at is null and field_booked_by is null)
      or (field_booked_at is not null and field_booked_by is not null)
    );

create index matches_nearby_idx
on public.matches (visibility, starts_at, latitude, longitude)
where visibility = 'public' and status in ('open', 'full');

drop function if exists public.create_match(
  uuid, text, text, timestamptz, text, text, text,
  public.match_format, integer, numeric, public.match_visibility
);

create or replace function public.create_match(
  target_league uuid,
  match_title text,
  match_description text,
  match_starts_at timestamptz,
  match_location_name text,
  match_address text,
  match_city text,
  match_province text,
  match_latitude numeric,
  match_longitude numeric,
  match_venue_phone text,
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
  if char_length(btrim(match_province)) not between 2 and 100 then raise exception 'invalid_province'; end if;
  if match_latitude not between 35 and 48 or match_longitude not between 6 and 19 then raise exception 'invalid_coordinates'; end if;
  if coalesce(btrim(match_venue_phone), '') !~ '^[0-9+() .-]{6,30}$' then raise exception 'invalid_venue_phone'; end if;
  if match_max_players not between 4 and 30 then raise exception 'invalid_max_players'; end if;
  if match_cost_total is not null and match_cost_total < 0 then raise exception 'invalid_cost'; end if;

  insert into public.matches (
    league_id, created_by, title, description, starts_at, location_name,
    address, city, province, latitude, longitude, venue_phone,
    football_format, max_players, cost_total, visibility, status
  ) values (
    target_league, caller, btrim(match_title), nullif(btrim(match_description), ''),
    match_starts_at, btrim(match_location_name), nullif(btrim(match_address), ''),
    btrim(match_city), btrim(match_province), match_latitude, match_longitude,
    nullif(btrim(match_venue_phone), ''), match_football_format,
    match_max_players, match_cost_total, match_visibility, 'open'
  ) returning id into created_id;

  return created_id;
end;
$$;

drop function if exists public.update_match_details(
  uuid, text, text, timestamptz, text, text, text,
  public.match_format, integer, numeric, public.match_visibility
);

create or replace function public.update_match_details(
  target_match uuid,
  match_title text,
  match_description text,
  match_starts_at timestamptz,
  match_location_name text,
  match_address text,
  match_city text,
  match_province text,
  match_latitude numeric,
  match_longitude numeric,
  match_venue_phone text,
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
  if char_length(btrim(match_province)) not between 2 and 100 then raise exception 'invalid_province'; end if;
  if match_latitude not between 35 and 48 or match_longitude not between 6 and 19 then raise exception 'invalid_coordinates'; end if;
  if coalesce(btrim(match_venue_phone), '') !~ '^[0-9+() .-]{6,30}$' then raise exception 'invalid_venue_phone'; end if;
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
    province = btrim(match_province),
    latitude = match_latitude,
    longitude = match_longitude,
    venue_phone = nullif(btrim(match_venue_phone), ''),
    football_format = match_football_format,
    max_players = match_max_players,
    cost_total = match_cost_total,
    visibility = match_visibility
  where id = target_match;

  perform private.rebalance_match(target_match);
end;
$$;

create or replace function public.set_match_media(
  target_match uuid,
  match_cover_image_url text,
  match_venue_image_url text
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
begin
  if caller is null then raise exception 'authentication_required'; end if;
  select * into target from public.matches where id = target_match for update;
  if target.id is null then raise exception 'match_not_found'; end if;
  if not exists (
    select 1 from public.league_members
    where league_id = target.league_id and user_id = caller
      and status = 'active' and role in ('owner', 'admin')
  ) then raise exception 'admin_required'; end if;

  update public.matches set
    cover_image_url = coalesce(nullif(btrim(match_cover_image_url), ''), cover_image_url),
    venue_image_url = coalesce(nullif(btrim(match_venue_image_url), ''), venue_image_url)
  where id = target_match;
end;
$$;

create or replace function public.confirm_field_booking(target_match uuid)
returns timestamptz
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  target public.matches%rowtype;
  caller_name text;
  booked_time timestamptz := now();
  recipient record;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  select * into target from public.matches where id = target_match for update;
  if target.id is null then raise exception 'match_not_found'; end if;
  if target.status in ('cancelled', 'completed') then raise exception 'match_locked'; end if;
  if target.venue_phone is null then raise exception 'venue_phone_required'; end if;
  if target.field_booked_at is not null then return target.field_booked_at; end if;
  if not (
    exists (
      select 1 from public.match_participants
      where match_id = target_match and user_id = caller and response = 'going'
    )
    or exists (
      select 1 from public.league_members
      where league_id = target.league_id and user_id = caller
        and status = 'active' and role in ('owner', 'admin')
    )
  ) then raise exception 'confirmed_participant_required'; end if;

  update public.matches
  set field_booked_at = booked_time, field_booked_by = caller
  where id = target_match;

  select coalesce(nullif(btrim(first_name || ' ' || last_name), ''), '@' || username::text)
  into caller_name
  from public.profiles where id = caller;

  for recipient in
    select participant.user_id
    from public.match_participants participant
    where participant.match_id = target_match and participant.response = 'going'
    union
    select target.created_by
  loop
    perform private.enqueue_notification(
      recipient.user_id,
      'match_updated',
      private.repair_utf8_mojibake('Campo prenotato'),
      private.repair_utf8_mojibake(
        caller_name || ' ha confermato la prenotazione di ' || target.location_name ||
        ' per ' || target.title || '.'
      ),
      '/matches/' || target.id::text,
      jsonb_build_object('match_id', target.id, 'field_booked_by', caller),
      'match.field-booked:' || target.id::text || ':' || recipient.user_id::text
    );
  end loop;

  return booked_time;
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'match-media', 'match-media', true, 8388608,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function private.can_manage_match_media(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select object_name ~ '^[0-9a-f-]{36}/'
    and exists (
      select 1
      from public.matches match
      join public.league_members member on member.league_id = match.league_id
      where match.id = split_part(object_name, '/', 1)::uuid
        and member.user_id = (select auth.uid())
        and member.status = 'active'
        and member.role in ('owner', 'admin')
    );
$$;

create policy "League managers upload match media"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'match-media'
  and (select private.can_manage_match_media(name))
);

create policy "League managers read match media objects"
on storage.objects for select to authenticated
using (
  bucket_id = 'match-media'
  and (select private.can_manage_match_media(name))
);

create policy "League managers update match media"
on storage.objects for update to authenticated
using (
  bucket_id = 'match-media'
  and (select private.can_manage_match_media(name))
)
with check (
  bucket_id = 'match-media'
  and (select private.can_manage_match_media(name))
);

create policy "League managers delete match media"
on storage.objects for delete to authenticated
using (
  bucket_id = 'match-media'
  and (select private.can_manage_match_media(name))
);

revoke all on function private.can_manage_match_media(text) from public, anon, authenticated;
revoke all on function public.create_match(uuid, text, text, timestamptz, text, text, text, text, numeric, numeric, text, public.match_format, integer, numeric, public.match_visibility) from public, anon;
revoke all on function public.update_match_details(uuid, text, text, timestamptz, text, text, text, text, numeric, numeric, text, public.match_format, integer, numeric, public.match_visibility) from public, anon;
revoke all on function public.set_match_media(uuid, text, text) from public, anon;
revoke all on function public.confirm_field_booking(uuid) from public, anon;

grant execute on function public.create_match(uuid, text, text, timestamptz, text, text, text, text, numeric, numeric, text, public.match_format, integer, numeric, public.match_visibility) to authenticated;
grant execute on function public.update_match_details(uuid, text, text, timestamptz, text, text, text, text, numeric, numeric, text, public.match_format, integer, numeric, public.match_visibility) to authenticated;
grant execute on function public.set_match_media(uuid, text, text) to authenticated;
grant execute on function public.confirm_field_booking(uuid) to authenticated;
