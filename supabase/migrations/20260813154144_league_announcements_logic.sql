create table public.league_communications (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  match_id uuid references public.matches(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  kind text not null default 'announcement'
    check (kind in ('announcement', 'match_reminder')),
  title text not null check (char_length(title) between 1 and 120),
  body text not null check (char_length(body) between 1 and 500),
  pinned boolean not null default false,
  created_at timestamptz not null default now(),
  constraint league_communications_kind_match_check check (
    (kind = 'announcement' and match_id is null)
    or (kind = 'match_reminder' and match_id is not null)
  )
);

create index league_communications_feed_idx
on public.league_communications (league_id, pinned desc, created_at desc);

create index league_communications_rate_limit_idx
on public.league_communications (league_id, created_by, kind, created_at desc);

create index league_communications_match_idx
on public.league_communications (match_id, created_at desc)
where match_id is not null;

create or replace function private.is_league_manager(
  target_league uuid,
  target_user uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.league_members member
    where member.league_id = target_league
      and member.user_id = target_user
      and member.status = 'active'
      and member.role in ('owner', 'admin')
  );
$$;

create or replace function private.notification_preference_enabled(
  target_user uuid,
  event_type public.notification_type
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select case
      when event_type in ('match_created', 'new_match') then preferences.match_created
      when event_type in ('match_updated', 'match_cancelled') then preferences.match_updates
      when event_type in ('match_reminder', 'reminder') then preferences.match_reminders
      when event_type = 'waitlist_promoted' then preferences.waitlist
      when event_type in ('mvp_voting_open', 'mvp_winner', 'mvp_vote') then preferences.mvp
      when event_type in ('rating_changed', 'result') then preferences.rating
      when event_type in ('league_invite', 'league_role_changed', 'league_announcement', 'join_request') then preferences.league_updates
      else true
    end
    from public.notification_preferences preferences
    where preferences.user_id = target_user
  ), true);
$$;

create or replace function private.notify_league_communication()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recipient record;
  league_slug text;
  notification_link text;
  event_type public.notification_type;
  recipient_count integer := 0;
begin
  select league.slug into league_slug
  from public.leagues league
  where league.id = new.league_id;

  event_type := case
    when new.kind = 'match_reminder' then 'match_reminder'::public.notification_type
    else 'league_announcement'::public.notification_type
  end;
  notification_link := case
    when new.match_id is not null then '/matches/' || new.match_id::text
    else '/leagues/' || league_slug || '?tab=communications#communication-' || new.id::text
  end;

  for recipient in
    select member.user_id
    from public.league_members member
    where member.league_id = new.league_id
      and member.status = 'active'
      and member.user_id <> new.created_by
      and (
        new.kind = 'announcement'
        or exists (
          select 1
          from public.match_participants participant
          where participant.match_id = new.match_id
            and participant.user_id = member.user_id
            and participant.response in ('going', 'maybe', 'waitlist')
        )
      )
  loop
    perform private.enqueue_notification(
      recipient.user_id,
      event_type,
      new.title,
      new.body,
      notification_link,
      jsonb_build_object(
        'source', 'league_communication',
        'communication_id', new.id,
        'league_id', new.league_id,
        'match_id', new.match_id,
        'kind', new.kind
      ),
      'league.communication:' || new.id::text || ':' || recipient.user_id::text
    );
    recipient_count := recipient_count + 1;
  end loop;

  if recipient_count > 0 then
    perform private.invoke_push_worker();
  end if;
  return new;
end;
$$;

create trigger notify_league_communication
after insert on public.league_communications
for each row execute function private.notify_league_communication();

create or replace function public.publish_league_communication(
  target_league uuid,
  communication_title text,
  communication_body text,
  communication_pinned boolean default false
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  communication_id uuid;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  if not private.is_league_manager(target_league, caller) then raise exception 'admin_required'; end if;
  if char_length(trim(communication_title)) not between 3 and 120
    or char_length(trim(communication_body)) not between 3 and 500 then
    raise exception 'invalid_communication';
  end if;
  if exists (
    select 1
    from public.league_communications communication
    where communication.league_id = target_league
      and communication.created_by = caller
      and communication.kind = 'announcement'
      and communication.created_at > now() - interval '30 seconds'
  ) then raise exception 'communication_rate_limited'; end if;

  insert into public.league_communications (
    league_id, created_by, kind, title, body, pinned
  ) values (
    target_league,
    caller,
    'announcement',
    private.repair_utf8_mojibake(trim(communication_title)),
    private.repair_utf8_mojibake(trim(communication_body)),
    communication_pinned
  ) returning id into communication_id;

  return communication_id;
end;
$$;

create or replace function public.send_match_reminder(
  target_match uuid,
  reminder_body text
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
  communication_id uuid;
  recipient_count integer;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  if char_length(trim(reminder_body)) not between 3 and 500 then raise exception 'invalid_reminder'; end if;

  select * into target
  from public.matches match
  where match.id = target_match
  for update;
  if target.id is null then raise exception 'match_not_found'; end if;
  if target.status in ('cancelled', 'completed') then raise exception 'match_locked'; end if;
  if not private.is_league_manager(target.league_id, caller) then raise exception 'admin_required'; end if;
  if exists (
    select 1
    from public.league_communications communication
    where communication.match_id = target_match
      and communication.kind = 'match_reminder'
      and communication.created_at > now() - interval '5 minutes'
  ) then raise exception 'reminder_rate_limited'; end if;

  select count(*)::integer into recipient_count
  from public.match_participants participant
  join public.league_members member
    on member.league_id = target.league_id
   and member.user_id = participant.user_id
   and member.status = 'active'
  where participant.match_id = target_match
    and participant.user_id <> caller
    and participant.response in ('going', 'maybe', 'waitlist');
  if recipient_count = 0 then raise exception 'no_reminder_recipients'; end if;

  insert into public.league_communications (
    league_id, match_id, created_by, kind, title, body
  ) values (
    target.league_id,
    target.id,
    caller,
    'match_reminder',
    private.repair_utf8_mojibake('Promemoria - ' || target.title),
    private.repair_utf8_mojibake(trim(reminder_body))
  ) returning id into communication_id;

  return jsonb_build_object(
    'communication_id', communication_id,
    'recipient_count', recipient_count
  );
end;
$$;

create or replace function public.delete_league_communication(
  target_communication uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  target public.league_communications%rowtype;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  select * into target
  from public.league_communications communication
  where communication.id = target_communication
  for update;
  if target.id is null then raise exception 'communication_not_found'; end if;
  if not private.is_league_manager(target.league_id, caller) then raise exception 'admin_required'; end if;

  delete from public.notifications notification
  where notification.metadata ->> 'communication_id' = target.id::text;
  delete from public.league_communications communication
  where communication.id = target.id;
end;
$$;

alter table public.league_communications enable row level security;

create policy "Active league members read communications"
on public.league_communications for select to authenticated
using ((select private.is_league_member(league_id)));

revoke all on table public.league_communications from public, anon;
revoke insert, update, delete on table public.league_communications from authenticated;
grant select on table public.league_communications to authenticated;

revoke all on function private.is_league_manager(uuid, uuid) from public, anon, authenticated;
revoke all on function private.notify_league_communication() from public, anon, authenticated;
revoke all on function public.publish_league_communication(uuid, text, text, boolean) from public, anon;
revoke all on function public.send_match_reminder(uuid, text) from public, anon;
revoke all on function public.delete_league_communication(uuid) from public, anon;
grant execute on function public.publish_league_communication(uuid, text, text, boolean) to authenticated;
grant execute on function public.send_match_reminder(uuid, text) to authenticated;
grant execute on function public.delete_league_communication(uuid) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'league_communications'
  ) then
    alter publication supabase_realtime add table public.league_communications;
  end if;
end;
$$;
