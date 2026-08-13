create or replace function private.notify_league_member_joined()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recipient record;
  joined_username text;
  league_name text;
  league_slug text;
begin
  if new.status <> 'active' or new.role = 'owner' or (tg_op = 'UPDATE' and old.status = 'active') then
    return new;
  end if;

  select profile.username into joined_username from public.profiles profile where profile.id = new.user_id;
  select league.name, league.slug::text into league_name, league_slug from public.leagues league where league.id = new.league_id;

  for recipient in
    select member.user_id
    from public.league_members member
    where member.league_id = new.league_id
      and member.status = 'active'
      and member.role in ('owner', 'admin')
      and member.user_id <> new.user_id
  loop
    perform private.enqueue_notification(
      recipient.user_id,
      'league_invite',
      'Nuovo giocatore nella lega',
      '@' || coalesce(joined_username, 'giocatore') || ' è entrato in ' || coalesce(league_name, 'questa lega') || '.',
      '/leagues/' || league_slug,
      jsonb_build_object('league_id', new.league_id, 'member_id', new.user_id),
      'league.member_joined:' || new.league_id::text || ':' || new.user_id::text
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists notify_league_member_joined on public.league_members;
create trigger notify_league_member_joined
after insert or update of status on public.league_members
for each row execute function private.notify_league_member_joined();

-- Backfill recent joins so managers immediately see the event that exposed this gap.
do $$
declare
  membership record;
  recipient record;
begin
  for membership in
    select member.*, profile.username, league.name league_name, league.slug::text league_slug
    from public.league_members member
    join public.profiles profile on profile.id = member.user_id
    join public.leagues league on league.id = member.league_id
    where member.status = 'active' and member.role <> 'owner' and member.created_at > now() - interval '7 days'
  loop
    for recipient in
      select manager.user_id from public.league_members manager
      where manager.league_id = membership.league_id
        and manager.status = 'active'
        and manager.role in ('owner', 'admin')
        and manager.user_id <> membership.user_id
    loop
      perform private.enqueue_notification(
        recipient.user_id, 'league_invite', 'Nuovo giocatore nella lega',
        '@' || membership.username || ' è entrato in ' || membership.league_name || '.',
        '/leagues/' || membership.league_slug,
        jsonb_build_object('league_id', membership.league_id, 'member_id', membership.user_id),
        'league.member_joined:' || membership.league_id::text || ':' || membership.user_id::text
      );
    end loop;
  end loop;
end;
$$;

drop policy if exists "League members read matches" on public.matches;
create policy "Members and authenticated users read visible matches" on public.matches for select
to authenticated using (
  (select private.is_league_member(league_id))
  or (
    visibility = 'public'
    and exists (select 1 from public.leagues league where league.id = matches.league_id and league.visibility = 'public')
  )
);

create or replace function public.get_visible_match_counts(target_matches uuid[])
returns table (match_id uuid, going_count bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select match.id, count(participant.id) filter (where participant.response = 'going')
  from public.matches match
  left join public.match_participants participant on participant.match_id = match.id
  where (select auth.uid()) is not null
    and match.id = any(target_matches)
    and (
      private.is_league_member(match.league_id)
      or (
        match.visibility = 'public'
        and exists (select 1 from public.leagues league where league.id = match.league_id and league.visibility = 'public')
      )
    )
  group by match.id;
$$;

create or replace function public.join_public_league(target_league uuid)
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
  if caller is null then raise exception 'authentication_required'; end if;
  select * into target from public.leagues where id = target_league for update;
  if target.id is null or target.visibility <> 'public' then raise exception 'public_league_not_found'; end if;

  select * into existing from public.league_members where league_id = target.id and user_id = caller;
  if existing.id is not null and existing.status = 'active' then return target.slug::text; end if;
  if existing.id is not null and existing.status = 'banned' then raise exception 'membership_banned'; end if;

  select count(*) into active_members from public.league_members where league_id = target.id and status = 'active';
  if active_members >= target.max_members then raise exception 'league_full'; end if;

  insert into public.league_members (league_id, user_id, role, status)
  values (target.id, caller, 'member', 'active')
  on conflict (league_id, user_id) do update set status = 'active', role = 'member', joined_at = now();
  return target.slug::text;
end;
$$;

revoke all on function private.notify_league_member_joined() from public, anon, authenticated;
revoke all on function public.get_visible_match_counts(uuid[]) from public, anon;
revoke all on function public.join_public_league(uuid) from public, anon;
grant execute on function public.get_visible_match_counts(uuid[]) to authenticated;
grant execute on function public.join_public_league(uuid) to authenticated;
