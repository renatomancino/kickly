create or replace function private.repair_utf8_mojibake(input_value text)
returns text
language plpgsql
immutable
strict
security invoker
set search_path = ''
as $$
declare
  candidate text := input_value;
  converted text;
  candidate_score integer;
  converted_score integer;
begin
  for pass in 1..3 loop
    candidate_score :=
      char_length(candidate) - char_length(replace(candidate, chr(194), '')) +
      char_length(candidate) - char_length(replace(candidate, chr(195), '')) +
      char_length(candidate) - char_length(replace(candidate, chr(226), '')) +
      char_length(candidate) - char_length(replace(candidate, chr(240), ''));

    if candidate_score = 0 then
      exit;
    end if;

    begin
      converted := convert_from(convert_to(candidate, 'WIN1252'), 'UTF8');
    exception when others then
      exit;
    end;

    converted_score :=
      char_length(converted) - char_length(replace(converted, chr(194), '')) +
      char_length(converted) - char_length(replace(converted, chr(195), '')) +
      char_length(converted) - char_length(replace(converted, chr(226), '')) +
      char_length(converted) - char_length(replace(converted, chr(240), ''));

    if converted_score >= candidate_score then
      exit;
    end if;
    candidate := converted;
  end loop;

  return candidate;
end;
$$;

revoke all on function private.repair_utf8_mojibake(text) from public, anon, authenticated;

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
    target_user,
    event_type,
    left(private.repair_utf8_mojibake(notification_title), 120),
    left(private.repair_utf8_mojibake(notification_body), 500),
    notification_link,
    coalesce(notification_metadata, '{}'::jsonb),
    notification_dedupe_key
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

revoke all on function private.enqueue_notification(uuid, public.notification_type, text, text, text, jsonb, text)
from public, anon, authenticated;

update public.notifications
set title = private.repair_utf8_mojibake(title),
    body = private.repair_utf8_mojibake(body);

do $$
begin
  if private.repair_utf8_mojibake(chr(195) || chr(168)) <> chr(232) then
    raise exception 'notification_encoding_repair_failed';
  end if;
  if private.repair_utf8_mojibake(chr(194) || chr(183)) <> chr(183) then
    raise exception 'notification_separator_repair_failed';
  end if;
end;
$$;
