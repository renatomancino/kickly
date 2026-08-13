create extension if not exists pg_cron;
create extension if not exists pg_net;

drop trigger if exists notify_members_on_match on public.matches;
drop function if exists private.notify_new_match();

alter table public.notifications alter column type type text using type::text;
drop type public.notification_type;
create type public.notification_type as enum (
  'match_created', 'match_updated', 'match_cancelled', 'match_reminder',
  'waitlist_promoted', 'mvp_voting_open', 'mvp_winner', 'rating_changed',
  'league_invite', 'league_role_changed',
  'new_match', 'reminder', 'mvp_vote', 'result', 'join_request'
);
alter table public.notifications alter column type type public.notification_type using type::public.notification_type;

alter table public.notifications
  add column metadata jsonb not null default '{}'::jsonb,
  add column read_at timestamptz,
  add column dedupe_key text,
  add column push_sent_at timestamptz;
update public.notifications set read_at = created_at where read = true;
alter table public.notifications drop column read;
alter table public.notifications add constraint notification_link_internal
  check (link is null or (link like '/%' and link not like '//%'));
create unique index notifications_dedupe_idx on public.notifications (user_id, dedupe_key)
where dedupe_key is not null;
drop index if exists public.notifications_user_idx;
create index notifications_user_unread_idx on public.notifications (user_id, created_at desc)
where read_at is null;

alter table public.push_subscriptions
  add column device_name text,
  add column last_used_at timestamptz,
  add column disabled_at timestamptz;

create table public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  match_created boolean not null default true,
  match_updates boolean not null default true,
  match_reminders boolean not null default true,
  waitlist boolean not null default true,
  mvp boolean not null default true,
  rating boolean not null default true,
  league_updates boolean not null default true,
  push_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.push_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  subscription_id uuid not null references public.push_subscriptions(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'processing', 'sent', 'failed', 'dead')),
  attempts smallint not null default 0 check (attempts between 0 and 10),
  next_attempt_at timestamptz not null default now(),
  last_error text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (notification_id, subscription_id)
);
create index push_deliveries_pending_idx on public.push_deliveries (next_attempt_at, created_at)
where status in ('pending', 'failed', 'processing');

create trigger notification_preferences_updated_at before update on public.notification_preferences
for each row execute function private.set_updated_at();
create trigger push_deliveries_updated_at before update on public.push_deliveries
for each row execute function private.set_updated_at();

insert into public.notification_preferences (user_id)
select id from public.profiles on conflict (user_id) do nothing;

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
      when event_type in ('league_invite', 'league_role_changed', 'join_request') then preferences.league_updates
      else true
    end
    from public.notification_preferences preferences
    where preferences.user_id = target_user
  ), true);
$$;

create or replace function private.enqueue_notification(
  target_user uuid,
  event_type public.notification_type,
  notification_title text,
  notification_body text,
  notification_link text default null,
  notification_metadata jsonb default '{}'::jsonb,
  notification_dedupe_key text default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  notification_id uuid;
begin
  if not private.notification_preference_enabled(target_user, event_type) then
    return null;
  end if;
  if notification_link is not null and (notification_link not like '/%' or notification_link like '//%') then
    raise exception 'invalid_notification_link';
  end if;

  insert into public.notifications (user_id, type, title, body, link, metadata, dedupe_key)
  values (
    target_user, event_type, left(notification_title, 120), left(notification_body, 500),
    notification_link, coalesce(notification_metadata, '{}'::jsonb), notification_dedupe_key
  )
  on conflict (user_id, dedupe_key) where dedupe_key is not null do update
  set title = excluded.title,
      body = excluded.body,
      link = excluded.link,
      metadata = excluded.metadata,
      created_at = now()
  returning id into notification_id;
  return notification_id;
end;
$$;

create or replace function private.create_push_deliveries()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  insert into public.push_deliveries (notification_id, subscription_id)
  select new.id, subscription.id
  from public.push_subscriptions subscription
  join public.notification_preferences preferences on preferences.user_id = subscription.user_id
  where subscription.user_id = new.user_id
    and subscription.disabled_at is null
    and preferences.push_enabled = true
  on conflict (notification_id, subscription_id) do nothing;
  return new;
end;
$$;

create trigger create_push_deliveries after insert on public.notifications
for each row execute function private.create_push_deliveries();

create or replace function private.notify_new_match()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  member record;
  league_name text;
begin
  select name into league_name from public.leagues where id = new.league_id;
  for member in
    select user_id from public.league_members
    where league_id = new.league_id and status = 'active' and user_id <> new.created_by
  loop
    perform private.enqueue_notification(
      member.user_id, 'match_created', '⚽ Nuova partita',
      new.title || ' · ' || coalesce(league_name, 'Lega Kickly') || ' · ' ||
        to_char(new.starts_at at time zone 'Europe/Rome', 'DD/MM HH24:MI'),
      '/matches/' || new.id::text,
      jsonb_build_object('match_id', new.id, 'league_id', new.league_id),
      'match.created:' || new.id::text || ':' || member.user_id::text
    );
  end loop;
  return new;
end;
$$;

create trigger notify_members_on_match after insert on public.matches
for each row execute function private.notify_new_match();

create or replace function private.notify_match_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recipient record;
  bucket text := floor(extract(epoch from now()) / 300)::bigint::text;
begin
  if old.status is distinct from new.status and new.status = 'cancelled' then
    for recipient in
      select user_id from public.match_participants
      where match_id = new.id and response in ('going', 'maybe', 'waitlist')
    loop
      perform private.enqueue_notification(
        recipient.user_id, 'match_cancelled', '❌ Partita annullata',
        new.title || ' non si giocherà.', '/matches/' || new.id::text,
        jsonb_build_object('match_id', new.id),
        'match.cancelled:' || new.id::text || ':' || recipient.user_id::text
      );
    end loop;
  elsif new.status not in ('cancelled', 'completed') and (
    old.starts_at is distinct from new.starts_at or
    old.location_name is distinct from new.location_name or
    old.address is distinct from new.address or
    old.city is distinct from new.city
  ) then
    for recipient in
      select user_id from public.match_participants
      where match_id = new.id and response in ('going', 'maybe', 'waitlist')
    loop
      perform private.enqueue_notification(
        recipient.user_id, 'match_updated', '⚠️ Partita modificata',
        new.title || ' · ' || to_char(new.starts_at at time zone 'Europe/Rome', 'DD/MM HH24:MI') ||
          ' · ' || new.location_name,
        '/matches/' || new.id::text,
        jsonb_build_object('match_id', new.id),
        'match.updated:' || new.id::text || ':' || recipient.user_id::text || ':' || bucket
      );
    end loop;
  end if;
  return new;
end;
$$;

create trigger notify_match_change after update of starts_at, location_name, address, city, status on public.matches
for each row execute function private.notify_match_change();

create or replace function private.notify_waitlist_promotion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  match_title text;
begin
  if old.response = 'waitlist' and new.response = 'going' then
    select title into match_title from public.matches where id = new.match_id;
    perform private.enqueue_notification(
      new.user_id, 'waitlist_promoted', '🔥 Sei dentro!',
      'Si è liberato un posto per ' || coalesce(match_title, 'la partita') || '.',
      '/matches/' || new.match_id::text,
      jsonb_build_object('match_id', new.match_id),
      'waitlist.promoted:' || new.match_id::text || ':' || new.user_id::text
    );
  end if;
  return new;
end;
$$;

create trigger notify_waitlist_promotion after update of response on public.match_participants
for each row execute function private.notify_waitlist_promotion();

create or replace function private.notify_mvp_opened()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  participant record;
begin
  if old.status is distinct from new.status and new.status = 'completed' then
    for participant in select user_id from public.player_match_stats where match_id = new.id loop
      perform private.enqueue_notification(
        participant.user_id, 'mvp_voting_open', '🏆 Vota l''MVP',
        'Chi è stato il migliore in campo?', '/matches/' || new.id::text || '#mvp',
        jsonb_build_object('match_id', new.id, 'ends_at', new.mvp_voting_ends_at),
        'mvp.opened:' || new.id::text || ':' || participant.user_id::text
      );
    end loop;
  end if;
  return new;
end;
$$;

create trigger notify_mvp_opened after update of status on public.matches
for each row execute function private.notify_mvp_opened();

create or replace function private.notify_mvp_winner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  participant record;
  winner_id uuid;
  winner_name text;
begin
  if old.mvp_finalized_at is null and new.mvp_finalized_at is not null then
    select stats.user_id, coalesce(nullif(btrim(profile.first_name || ' ' || profile.last_name), ''), profile.username::text)
      into winner_id, winner_name
    from public.player_match_stats stats
    join public.profiles profile on profile.id = stats.user_id
    where stats.match_id = new.id and stats.is_mvp limit 1;
    if winner_id is not null then
      for participant in select user_id from public.player_match_stats where match_id = new.id loop
        perform private.enqueue_notification(
          participant.user_id, 'mvp_winner', '🏆 MVP DELLA PARTITA',
          case when participant.user_id = winner_id then 'Sei stato votato come migliore in campo.'
            else winner_name || ' è stato eletto MVP.' end,
          '/matches/' || new.id::text || '#mvp',
          jsonb_build_object('match_id', new.id, 'winner_id', winner_id),
          'mvp.winner:' || new.id::text || ':' || participant.user_id::text
        );
      end loop;
    end if;
  end if;
  return new;
end;
$$;

create trigger notify_mvp_winner after update of mvp_finalized_at on public.matches
for each row execute function private.notify_mvp_winner();

create or replace function private.notify_rating_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.match_id is not null and round(new.previous_rating) <> round(new.new_rating) then
    perform private.enqueue_notification(
      new.user_id, 'rating_changed',
      case when new.new_rating > new.previous_rating then '📈 Overall aumentato' else '📉 Overall aggiornato' end,
      round(new.previous_rating)::text || ' → ' || round(new.new_rating)::text,
      '/profile',
      jsonb_build_object('match_id', new.match_id, 'previous', new.previous_rating, 'current', new.new_rating),
      'rating.changed:' || new.match_id::text || ':' || new.user_id::text || ':' || round(new.new_rating)::text
    );
  end if;
  return new;
end;
$$;

create trigger notify_rating_change after insert on public.player_rating_history
for each row execute function private.notify_rating_change();

create or replace function private.notify_league_role_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  league_name text;
begin
  if old.role is distinct from new.role then
    select name into league_name from public.leagues where id = new.league_id;
    perform private.enqueue_notification(
      new.user_id, 'league_role_changed',
      case when new.role = 'admin' then '🛡️ Sei diventato Admin' else 'Ruolo lega aggiornato' end,
      case when new.role = 'admin' then 'Ora puoi gestire le partite di ' || coalesce(league_name, 'questa lega') || '.'
        else 'Ora sei membro di ' || coalesce(league_name, 'questa lega') || '.' end,
      (select '/leagues/' || slug::text from public.leagues where id = new.league_id),
      jsonb_build_object('league_id', new.league_id, 'role', new.role),
      'league.role:' || new.league_id::text || ':' || new.user_id::text || ':' || new.role::text
    );
  end if;
  return new;
end;
$$;

create trigger notify_league_role_change after update of role on public.league_members
for each row execute function private.notify_league_role_change();

create or replace function private.process_notification_schedule()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  due record;
begin
  for due in
    select match.id match_id, match.title, match.starts_at, participant.user_id, reminder.kind
    from public.matches match
    join public.match_participants participant on participant.match_id = match.id and participant.response = 'going'
    cross join lateral (
      values
        ('24h'::text, interval '24 hours', interval '23 hours 30 minutes'),
        ('2h'::text, interval '2 hours', interval '1 hour 30 minutes')
    ) reminder(kind, upper_bound, lower_bound)
    where match.status in ('open', 'full')
      and match.starts_at <= now() + reminder.upper_bound
      and match.starts_at > now() + reminder.lower_bound
  loop
    perform private.enqueue_notification(
      due.user_id, 'match_reminder',
      case when due.kind = '24h' then '⚽ Si gioca domani' else '⚽ Ci siamo quasi' end,
      due.title || ' · ' || to_char(due.starts_at at time zone 'Europe/Rome', 'HH24:MI'),
      '/matches/' || due.match_id::text,
      jsonb_build_object('match_id', due.match_id, 'reminder', due.kind),
      'match.reminder:' || due.kind || ':' || due.match_id::text || ':' || due.user_id::text
    );
  end loop;

  for due in
    select match.id match_id, stats.user_id
    from public.matches match
    join public.player_match_stats stats on stats.match_id = match.id
    left join public.mvp_votes vote on vote.match_id = match.id and vote.voter_id = stats.user_id
    where match.status = 'completed'
      and match.mvp_finalized_at is null
      and match.mvp_voting_ends_at <= now() + interval '3 hours'
      and match.mvp_voting_ends_at > now()
      and vote.id is null
  loop
    perform private.enqueue_notification(
      due.user_id, 'mvp_voting_open', '🏆 Ultime ore per votare',
      'La votazione MVP sta per terminare.', '/matches/' || due.match_id::text || '#mvp',
      jsonb_build_object('match_id', due.match_id, 'reminder', true),
      'mvp.reminder:' || due.match_id::text || ':' || due.user_id::text
    );
  end loop;
end;
$$;

create or replace function public.register_push_subscription(
  subscription_endpoint text,
  subscription_p256dh text,
  subscription_auth text,
  subscription_user_agent text default null,
  subscription_device_name text default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  subscription_id uuid;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  if subscription_endpoint not like 'https://%' or char_length(subscription_endpoint) > 2048 then raise exception 'invalid_endpoint'; end if;
  if char_length(subscription_p256dh) not between 20 and 255 or char_length(subscription_auth) not between 8 and 255 then raise exception 'invalid_subscription_keys'; end if;
  insert into public.push_subscriptions (user_id, endpoint, p256dh, auth, user_agent, device_name, last_used_at, disabled_at)
  values (caller, subscription_endpoint, subscription_p256dh, subscription_auth,
    left(subscription_user_agent, 500), left(subscription_device_name, 80), now(), null)
  on conflict (endpoint) do update set
    user_id = caller, p256dh = excluded.p256dh, auth = excluded.auth,
    user_agent = excluded.user_agent, device_name = excluded.device_name,
    last_used_at = now(), disabled_at = null
  returning id into subscription_id;
  insert into public.notification_preferences (user_id, push_enabled) values (caller, true)
  on conflict (user_id) do update set push_enabled = true;
  return subscription_id;
end;
$$;

create or replace function public.remove_push_subscription(subscription_endpoint text)
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
  delete from public.push_subscriptions where user_id = caller and endpoint = subscription_endpoint;
  if not exists (select 1 from public.push_subscriptions where user_id = caller and disabled_at is null) then
    update public.notification_preferences set push_enabled = false where user_id = caller;
  end if;
end;
$$;

create or replace function public.get_push_public_key()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then raise exception 'authentication_required'; end if;
  return (select decrypted_secret from vault.decrypted_secrets where name = 'kickly_vapid_public_key' limit 1);
end;
$$;

create or replace function public.claim_push_deliveries(batch_size integer default 50)
returns table (
  delivery_id uuid,
  endpoint text,
  p256dh text,
  auth text,
  title text,
  body text,
  link text,
  metadata jsonb,
  vapid_public text,
  vapid_private text,
  vapid_subject text
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if coalesce((select auth.jwt() ->> 'role'), '') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  return query
  with claimed as (
    select delivery.id
    from public.push_deliveries delivery
    join public.push_subscriptions subscription on subscription.id = delivery.subscription_id
    where subscription.disabled_at is null
      and delivery.attempts < 5
      and delivery.next_attempt_at <= now()
      and (delivery.status in ('pending', 'failed') or (delivery.status = 'processing' and delivery.updated_at < now() - interval '10 minutes'))
    order by delivery.created_at
    limit greatest(1, least(batch_size, 100))
    for update of delivery skip locked
  ), updated as (
    update public.push_deliveries delivery
    set status = 'processing', attempts = attempts + 1, updated_at = now()
    from claimed where delivery.id = claimed.id
    returning delivery.*
  )
  select updated.id, subscription.endpoint, subscription.p256dh, subscription.auth,
    notification.title, notification.body, notification.link, notification.metadata,
    (select decrypted_secret from vault.decrypted_secrets where name = 'kickly_vapid_public_key' limit 1),
    (select decrypted_secret from vault.decrypted_secrets where name = 'kickly_vapid_private_key' limit 1),
    coalesce((select decrypted_secret from vault.decrypted_secrets where name = 'kickly_vapid_subject' limit 1), 'mailto:notifications@kickly.app')
  from updated
  join public.push_subscriptions subscription on subscription.id = updated.subscription_id
  join public.notifications notification on notification.id = updated.notification_id;
end;
$$;

create or replace function public.complete_push_delivery(
  target_delivery uuid,
  delivered boolean,
  terminal_failure boolean default false,
  delivery_error text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  target_notification uuid;
  target_subscription uuid;
begin
  if coalesce((select auth.jwt() ->> 'role'), '') <> 'service_role' then
    raise exception 'service_role_required';
  end if;
  select notification_id, subscription_id into target_notification, target_subscription
  from public.push_deliveries where id = target_delivery for update;
  if target_notification is null then return; end if;
  update public.push_deliveries set
    status = case when delivered then 'sent' when terminal_failure then 'dead' else 'failed' end,
    sent_at = case when delivered then now() else null end,
    last_error = left(delivery_error, 500),
    next_attempt_at = case when delivered or terminal_failure then now() else now() + interval '5 minutes' end
  where id = target_delivery;
  if terminal_failure then update public.push_subscriptions set disabled_at = now() where id = target_subscription; end if;
  if not exists (
    select 1 from public.push_deliveries
    where notification_id = target_notification and status not in ('sent', 'dead')
  ) then update public.notifications set push_sent_at = now() where id = target_notification; end if;
end;
$$;

create or replace function private.invoke_push_worker()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  project_url text;
  publishable_key text;
begin
  select decrypted_secret into project_url from vault.decrypted_secrets where name = 'kickly_project_url' limit 1;
  select decrypted_secret into publishable_key from vault.decrypted_secrets where name = 'kickly_publishable_key' limit 1;
  if project_url is null or publishable_key is null then return; end if;
  perform net.http_post(
    url := project_url || '/functions/v1/push-worker',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || publishable_key),
    body := '{}'::jsonb,
    timeout_milliseconds := 10000
  );
end;
$$;

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
  insert into public.player_rating_history (user_id, previous_rating, new_rating, delta, reason)
  values (new.id, 70, 70, 0, 'Valutazione iniziale');
  insert into public.notification_preferences (user_id) values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

alter table public.notification_preferences enable row level security;
alter table public.push_deliveries enable row level security;

drop policy if exists "Users read own notifications" on public.notifications;
drop policy if exists "Users update own notifications" on public.notifications;
drop policy if exists "Users delete own notifications" on public.notifications;
create policy "Users read own notifications" on public.notifications for select to authenticated
using (user_id = (select auth.uid()));
create policy "Users mark own notifications" on public.notifications for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "Users read own notification preferences" on public.notification_preferences for select to authenticated
using (user_id = (select auth.uid()));
create policy "Users create own notification preferences" on public.notification_preferences for insert to authenticated
with check (user_id = (select auth.uid()));
create policy "Users update own notification preferences" on public.notification_preferences for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

revoke all on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;
grant select, insert, update, delete on public.push_subscriptions to authenticated;
grant select, insert, update on public.notification_preferences to authenticated;
revoke all on public.push_deliveries from anon, authenticated;

revoke all on function private.notification_preference_enabled(uuid, public.notification_type) from public, anon, authenticated;
revoke all on function private.enqueue_notification(uuid, public.notification_type, text, text, text, jsonb, text) from public, anon, authenticated;
revoke all on function private.create_push_deliveries() from public, anon, authenticated;
revoke all on function private.notify_new_match() from public, anon, authenticated;
revoke all on function private.notify_match_change() from public, anon, authenticated;
revoke all on function private.notify_waitlist_promotion() from public, anon, authenticated;
revoke all on function private.notify_mvp_opened() from public, anon, authenticated;
revoke all on function private.notify_mvp_winner() from public, anon, authenticated;
revoke all on function private.notify_rating_change() from public, anon, authenticated;
revoke all on function private.notify_league_role_change() from public, anon, authenticated;
revoke all on function private.process_notification_schedule() from public, anon, authenticated;
revoke all on function private.invoke_push_worker() from public, anon, authenticated;

revoke all on function public.register_push_subscription(text, text, text, text, text) from public, anon;
revoke all on function public.remove_push_subscription(text) from public, anon;
revoke all on function public.get_push_public_key() from public, anon;
revoke all on function public.claim_push_deliveries(integer) from public, anon, authenticated;
revoke all on function public.complete_push_delivery(uuid, boolean, boolean, text) from public, anon, authenticated;
grant execute on function public.register_push_subscription(text, text, text, text, text) to authenticated;
grant execute on function public.remove_push_subscription(text) to authenticated;
grant execute on function public.get_push_public_key() to authenticated;
grant execute on function public.claim_push_deliveries(integer) to service_role;
grant execute on function public.complete_push_delivery(uuid, boolean, boolean, text) to service_role;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications'
  ) then alter publication supabase_realtime add table public.notifications; end if;
end;
$$;

do $$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job where jobname = 'kickly-notification-reminders';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;
  perform cron.schedule('kickly-notification-reminders', '*/5 * * * *', 'select private.process_notification_schedule();');
  select jobid into existing_job from cron.job where jobname = 'kickly-push-worker';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;
  perform cron.schedule('kickly-push-worker', '* * * * *', 'select private.invoke_push_worker();');
end;
$$;
