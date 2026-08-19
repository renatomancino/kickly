-- "Cercano un decimo vicino a te": sezione automatica in home.
--
-- PERCHE' automatica e non un annuncio scritto a mano: un posto libero in
-- una partita pubblica e' gia' di per se' l'informazione che serve, non va
-- composta da un admin. Restare automatica evita anche che una lega debba
-- ricordarsi di "pubblicare" ogni volta: il buco nella formazione la rende
-- visibile da sola, e si nasconde da sola appena si riempie o chiude le
-- iscrizioni.
--
-- Riusa la formula di distanza gia' impiegata lato client in
-- kickly_repository.dart (_distanceKm): stessa formula server-side, cosi'
-- il raggio scelto nella tab "Vicino a me" e quello di questa sezione
-- restano coerenti fra loro invece di scostarsi per un dettaglio di calcolo.
create or replace function private.haversine_km(
  lat1 numeric, lon1 numeric, lat2 numeric, lon2 numeric
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select 6371.0 * 2 * atan2(
    sqrt(
      sin(radians(lat2 - lat1) / 2) ^ 2
      + cos(radians(lat1)) * cos(radians(lat2)) * sin(radians(lon2 - lon1) / 2) ^ 2
    ),
    sqrt(
      1 - (
        sin(radians(lat2 - lat1) / 2) ^ 2
        + cos(radians(lat1)) * cos(radians(lat2)) * sin(radians(lon2 - lon1) / 2) ^ 2
      )
    )
  );
$$;

-- SECURITY DEFINER e' necessario qui: senza, un chiamante che non e' ancora
-- membro non potrebbe leggere match_participants delle leghe altrui per
-- contare i "going" (la RLS su quella tabella e' "solo membri"), esattamente
-- come per get_visible_match_counts che risolve lo stesso problema. Per
-- restare un endpoint pubblico sicuro (ogni funzione SECURITY DEFINER in
-- public e' eseguibile da chiunque sia autenticato, per default di Postgres)
-- il filtro a "solo partite pubbliche di leghe pubbliche" e' scritto nella
-- query stessa, non lasciato al chiamante: non esiste alcun parametro che
-- possa allargare la visibilita' oltre quella.
create or replace function public.get_nearby_open_slot_matches(radius_km numeric default 50)
returns table (
  match_id uuid,
  league_id uuid,
  league_name text,
  league_slug text,
  title text,
  starts_at timestamptz,
  location_name text,
  city text,
  province text,
  football_format text,
  max_players int,
  going_count bigint,
  cover_image_url text,
  status text,
  distance_km numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    m.id,
    m.league_id,
    league.name,
    league.slug,
    m.title,
    m.starts_at,
    m.location_name,
    m.city,
    m.province,
    m.football_format,
    m.max_players,
    count(participant.id) filter (where participant.response = 'going') as going_count,
    m.cover_image_url,
    m.status,
    private.haversine_km(loc.latitude, loc.longitude, m.latitude, m.longitude) as distance_km
  from public.matches m
  join public.leagues league on league.id = m.league_id
  -- join, non subquery su un valore scalare: se l'utente non ha ancora
  -- impostato la zona (niente riga in profile_locations) la funzione
  -- restituisce zero righe invece di sollevare un errore. E' lo stesso
  -- comportamento gia' scelto lato client per la tab "Vicino a me": chi non
  -- ha una posizione semplicemente non vede la sezione, non un messaggio
  -- d'errore in home.
  join public.profile_locations loc on loc.user_id = (select auth.uid())
  left join public.match_participants participant on participant.match_id = m.id
  where (select auth.uid()) is not null
    and m.visibility = 'public'
    and league.visibility = 'public'
    and m.status in ('open', 'full')
    and m.registration_closed_at is null
    -- Finestra di 7 giorni: un posto libero fra tre mesi non e' urgente e
    -- affollerebbe la home senza motivo. La stessa soglia usata altrove in
    -- app per raggruppare "Questa settimana".
    and m.starts_at between now() and now() + interval '7 days'
    and m.latitude is not null and m.longitude is not null
    -- Chi e' gia' membro la vede comunque in "In programma": ripeterla qui
    -- sarebbe un doppione, non una scoperta.
    and not private.is_league_member(m.league_id)
    -- Raggio clampato lato server (1-200 km) indipendentemente da cosa
    -- passa il chiamante: e' l'unico parametro esposto da questa funzione
    -- SECURITY DEFINER, e senza un tetto un valore assurdo trasformerebbe
    -- il filtro in una scansione pressoche' completa della tabella.
    and private.haversine_km(loc.latitude, loc.longitude, m.latitude, m.longitude)
        <= greatest(least(coalesce(radius_km, 50), 200), 1)
  group by m.id, league.name, league.slug, m.status, loc.latitude, loc.longitude
  -- "Posti liberi" e' l'unico motivo per cui la partita compare in questa
  -- sezione (a differenza della tab "Vicino a me", che mostra tutto): una
  -- partita gia' al completo non e' piu' un'opportunita' per chi la legge.
  having count(participant.id) filter (where participant.response = 'going') < m.max_players
  order by distance_km asc
  limit 20;
$$;

revoke all on function public.get_nearby_open_slot_matches(numeric) from public, anon;
grant execute on function public.get_nearby_open_slot_matches(numeric) to authenticated;
