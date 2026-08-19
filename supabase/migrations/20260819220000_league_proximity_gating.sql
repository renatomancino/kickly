-- Leghe pubbliche joinabili solo da chi e' vicino, non da chiunque.
--
-- PERCHE': oggi join_public_league lascia entrare QUALSIASI utente
-- autenticato in QUALSIASI lega pubblica, senza nessun controllo di
-- distanza. Per una lega di calcetto locale non e' mai stato utile: chi e'
-- a 400km non giochera' mai una partita, e "pubblica" cosi' com'e' oggi
-- significa "aperta a tutta Italia" invece di "aperta a chi puo' davvero
-- presentarsi in campo". Aggiungere una posizione alla lega e vincolare
-- l'ingresso a quella distanza e' il modo minimo per rendere "pubblica"
-- utile senza inventare un terzo stato (aperta/chiusa) parallelo a
-- pubblica/privata che esiste gia': sarebbero due assi quasi identici e
-- chi legge il codice fra sei mesi non saprebbe piu' quale controllare.
--
-- Retrocompatibile di proposito: la posizione e' nullable. Una lega
-- pubblica creata prima di questa migrazione (o senza posizione impostata
-- di proposito) mantiene il comportamento di oggi, nessuno resta escluso
-- da un giorno all'altro. Il gate scatta solo quando la lega HA una
-- posizione.
alter table public.leagues
  add column if not exists province text,
  add column if not exists latitude numeric(9,6) check (latitude between 35 and 48),
  add column if not exists longitude numeric(9,6) check (longitude between 6 and 19),
  add constraint leagues_coordinates_pair
    check (
      (latitude is null and longitude is null)
      or (latitude is not null and longitude is not null)
    );

-- Stesso indice parziale gia' usato su matches per lo stesso motivo: le
-- query "leghe pubbliche vicine" filtrano sempre su questi tre predicati
-- insieme, mai su latitude/longitude da soli.
create index if not exists leagues_nearby_idx
on public.leagues (visibility, latitude, longitude)
where visibility = 'public' and latitude is not null;

create or replace function public.create_league(
  league_name text,
  league_slug text,
  league_description text,
  league_city text,
  league_country text,
  league_visibility public.league_privacy,
  league_format public.match_format,
  league_max_members integer,
  -- Tre parametri nuovi, tutti default null: le chiamate esistenti dal
  -- client vecchio (prima di questo deploy) restano valide senza modifiche.
  league_province text default null,
  league_latitude numeric default null,
  league_longitude numeric default null
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
  -- Stesso vincolo "entrambe o nessuna" della colonna, controllato qui
  -- prima dell'insert cosi' l'errore arriva col codice giusto invece del
  -- messaggio generico del vincolo del database.
  if (league_latitude is null) <> (league_longitude is null) then
    raise exception 'invalid_coordinates';
  end if;

  insert into public.leagues (
    owner_id, name, slug, description, city, country,
    visibility, football_format, max_members,
    province, latitude, longitude
  ) values (
    caller, btrim(league_name), league_slug, nullif(btrim(league_description), ''),
    btrim(league_city), upper(league_country), league_visibility,
    league_format, league_max_members,
    nullif(btrim(coalesce(league_province, '')), ''), league_latitude, league_longitude
  ) returning * into created;

  return query select created.id, created.slug::text, created.invite_code;
end;
$$;

-- Il gate di distanza vive qui, non in una funzione a parte: e' l'UNICO
-- punto da cui un utente entra da solo in una lega pubblica (l'invito con
-- codice, join_league_by_code, resta un canale distinto e non tocca la
-- distanza di proposito — chi riceve un codice a mano l'ha gia' ricevuto
-- da qualcuno che lo conosce, la lega non e' "scoperta" a caso).
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
  caller_latitude numeric;
  caller_longitude numeric;
  distance_km numeric;
begin
  if caller is null then raise exception 'authentication_required'; end if;
  select * into target from public.leagues where id = target_league for update;
  if target.id is null or target.visibility <> 'public' then raise exception 'public_league_not_found'; end if;

  select * into existing from public.league_members where league_id = target.id and user_id = caller;
  if existing.id is not null and existing.status = 'active' then return target.slug::text; end if;
  if existing.id is not null and existing.status = 'banned' then raise exception 'membership_banned'; end if;

  select count(*) into active_members from public.league_members where league_id = target.id and status = 'active';
  if active_members >= target.max_members then raise exception 'league_full'; end if;

  -- Gate di distanza: solo se la lega ha una posizione impostata. Senza,
  -- comportamento identico a prima di questa migrazione.
  if target.latitude is not null then
    select loc.latitude, loc.longitude into caller_latitude, caller_longitude
    from public.profile_locations loc where loc.user_id = caller;
    if caller_latitude is null then raise exception 'location_required'; end if;

    distance_km := private.haversine_km(caller_latitude, caller_longitude, target.latitude, target.longitude);
    -- 50km fisso e non un parametro della funzione: stesso raggio di
    -- default usato ovunque nell'app (tab "Vicino a me",
    -- get_nearby_open_slot_matches). Se in futuro serve differenziarlo per
    -- lega, e' un campo nuovo su leagues, non un parametro qui: lasciarlo
    -- passabile dal chiamante permetterebbe a chiunque di aggirare il
    -- limite dichiarando un raggio enorme.
    if distance_km > 50 then
      -- Distanza arrotondata appesa al codice, stesso schema gia' usato da
      -- finalize_match per team_a_goals_mismatch: il client la legge per
      -- dire "sei a X km" invece del generico "troppo lontano".
      raise exception 'league_too_far:%', round(distance_km)::int;
    end if;
  end if;

  insert into public.league_members (league_id, user_id, role, status)
  values (target.id, caller, 'member', 'active')
  on conflict (league_id, user_id) do update set status = 'active', role = 'member', joined_at = now();
  return target.slug::text;
end;
$$;
