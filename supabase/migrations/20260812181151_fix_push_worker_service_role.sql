create or replace function public.claim_push_deliveries(batch_size integer default 50)
returns table (
  delivery_id uuid, endpoint text, p256dh text, auth text, title text, body text,
  link text, metadata jsonb, vapid_public text, vapid_private text, vapid_subject text
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

revoke all on function public.claim_push_deliveries(integer) from public, anon, authenticated;
revoke all on function public.complete_push_delivery(uuid, boolean, boolean, text) from public, anon, authenticated;
grant execute on function public.claim_push_deliveries(integer) to service_role;
grant execute on function public.complete_push_delivery(uuid, boolean, boolean, text) to service_role;
