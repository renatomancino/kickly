create or replace function public.request_test_push(
  notification_title text,
  notification_body text,
  notification_link text default '/settings/push-debug'
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  caller uuid := (select auth.uid());
  created_notification_id uuid;
begin
  if caller is null then
    raise exception 'authentication_required';
  end if;
  if char_length(trim(notification_title)) not between 1 and 120
    or char_length(trim(notification_body)) not between 1 and 500 then
    raise exception 'invalid_test_payload';
  end if;
  if notification_link is null
    or notification_link not like '/%'
    or notification_link like '//%'
    or char_length(notification_link) > 500 then
    raise exception 'invalid_notification_link';
  end if;
  if not exists (
    select 1
    from public.push_subscriptions subscription
    join public.notification_preferences preferences on preferences.user_id = subscription.user_id
    where subscription.user_id = caller
      and subscription.disabled_at is null
      and preferences.push_enabled = true
  ) then
    raise exception 'no_active_push_subscription';
  end if;
  if exists (
    select 1
    from public.notifications notification
    where notification.user_id = caller
      and notification.metadata ->> 'source' = 'manual_push_test'
      and notification.created_at > now() - interval '10 seconds'
  ) then
    raise exception 'test_push_rate_limited';
  end if;

  insert into public.notifications (user_id, type, title, body, link, metadata)
  values (
    caller,
    'reminder',
    private.repair_utf8_mojibake(trim(notification_title)),
    private.repair_utf8_mojibake(trim(notification_body)),
    notification_link,
    jsonb_build_object('source', 'manual_push_test')
  )
  returning id into created_notification_id;

  if not exists (
    select 1 from public.push_deliveries delivery
    where delivery.notification_id = created_notification_id
  ) then
    raise exception 'test_push_delivery_not_created';
  end if;

  perform private.invoke_push_worker();
  return created_notification_id;
end;
$$;

create or replace function public.get_test_push_delivery_status(target_notification uuid)
returns table (
  delivery_status text,
  delivery_count integer,
  sent_count integer,
  failed_count integer,
  dead_count integer
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
  if not exists (
    select 1
    from public.notifications notification
    where notification.id = target_notification
      and notification.user_id = caller
      and notification.metadata ->> 'source' = 'manual_push_test'
  ) then
    raise exception 'test_push_not_found';
  end if;

  return query
  select
    case
      when count(*) filter (where delivery.status = 'sent') > 0 then 'SENT'
      when count(*) > 0 and count(*) filter (where delivery.status = 'dead') = count(*) then 'DEAD'
      when count(*) filter (where delivery.status = 'processing') > 0 then 'PROCESSING'
      when count(*) filter (where delivery.status = 'failed') > 0 then 'RETRYING'
      when count(*) > 0 then 'QUEUED'
      else 'NO_DELIVERY'
    end,
    count(*)::integer,
    count(*) filter (where delivery.status = 'sent')::integer,
    count(*) filter (where delivery.status = 'failed')::integer,
    count(*) filter (where delivery.status = 'dead')::integer
  from public.push_deliveries delivery
  where delivery.notification_id = target_notification;
end;
$$;

revoke all on function public.request_test_push(text, text, text) from public, anon;
revoke all on function public.get_test_push_delivery_status(uuid) from public, anon;
grant execute on function public.request_test_push(text, text, text) to authenticated;
grant execute on function public.get_test_push_delivery_status(uuid) to authenticated;
