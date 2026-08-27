-- Report e blocco utenti nelle leghe pubbliche.
--
-- PERCHE': l'auto-join entro 50km su leghe pubbliche
-- (20260819220000_league_proximity_gating.sql, join_public_league) rende
-- "membro della lega" equivalente a "sconosciuto": la policy
-- "Authenticated profiles are readable" su public.profiles espone il
-- profilo completo di ogni membro della stessa lega a ogni altro membro,
-- bypassando profile_public (vedi private.shares_active_league,
-- 20260812173135_milestone_2_leagues.sql). Apple 1.2 (User Generated
-- Content) richiede un modo di segnalare/bloccare quando estranei vedono
-- profili di altri estranei. Nessuna traccia nel repo di moderazione prima
-- di questa migrazione.
--
-- Niente coda di moderazione in-app (scartata nella spec di sicurezza,
-- sezione Non-obiettivi: YAGNI finche' il volume di segnalazioni non la
-- giustifica): i report finiscono in una tabella consultabile solo via
-- SQL/dashboard da chi amministra il progetto, nessuna policy SELECT per
-- authenticated/anon.
--
-- A differenza di league_invite_attempts (tabella di solo servizio, scritta
-- e letta esclusivamente da una RPC SECURITY DEFINER perche' serve un
-- conteggio aggregato atomico), qui l'accesso e' diretto dal client Flutter
-- via RLS: non serve nessuna RPC intermedia perche' l'unica logica di
-- validazione (niente auto-segnalazione/auto-blocco, motivo da un elenco
-- chiuso) e' esprimibile per intero con vincoli CHECK sulla tabella stessa,
-- esattamente come gia' fatto per profile_locations
-- (20260813214256_nearby_matches_field_booking.sql).

create table public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid not null references public.profiles(id) on delete cascade,
  -- Nullable di proposito (vedi spec): un report puo' nascere fuori da una
  -- lega, non tutte le segnalazioni sono legate a una lega specifica.
  league_id uuid references public.leagues(id) on delete set null,
  reason text not null,
  details text,
  created_at timestamptz not null default now(),
  constraint user_reports_no_self_report check (reporter_id <> reported_user_id),
  -- Elenco chiuso: la UI mobile propone solo questi motivi (vedi
  -- reportReasons in mobile/lib/data/models.dart, Task 5). Il CHECK impedisce
  -- a una chiamata REST diretta di inserire un motivo arbitrario.
  constraint user_reports_reason_check check (
    reason in ('inappropriate_content', 'harassment', 'spam', 'fake_profile', 'other')
  ),
  constraint user_reports_details_length check (
    details is null or char_length(btrim(details)) <= 500
  )
);

-- Serve alla query "tutti i report contro questo utente", eseguita da chi
-- amministra il progetto via SQL/dashboard (nessuna UI in-app, vedi sopra).
create index user_reports_reported_user_idx
on public.user_reports (reported_user_id, created_at desc);

alter table public.user_reports enable row level security;
revoke all on table public.user_reports from public, anon;

-- Solo INSERT, e solo su se stessi come reporter: nessuna policy SELECT per
-- authenticated ne' anon, quindi un report inserito non e' rileggibile da
-- nessun ruolo client, solo da chi ha accesso diretto al database
-- (service_role/dashboard bypassano RLS di norma).
create policy "Users create own reports"
on public.user_reports for insert
to authenticated
with check (reporter_id = (select auth.uid()));

grant insert on table public.user_reports to authenticated;

create table public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self_block check (blocker_id <> blocked_id)
);

-- La chiave primaria (blocker_id, blocked_id) copre gia' "i blocchi che ho
-- fatto io"; questo indice copre la direzione simmetrica ("chi mi ha
-- bloccato"), che private.is_blocked_pair interroga sempre insieme
-- all'altra (vedi Task 2).
create index user_blocks_blocked_idx
on public.user_blocks (blocked_id, blocker_id);

alter table public.user_blocks enable row level security;
revoke all on table public.user_blocks from public, anon;

-- Il blocco e' bidirezionale nell'EFFETTO (private.is_blocked_pair guarda
-- entrambe le direzioni, Task 2) ma non nella riga: solo chi ha bloccato
-- puo' vedere/creare/rimuovere la propria riga. La parte bloccata non ha
-- alcuna visibilita' su questa tabella, nemmeno per sapere di essere stata
-- bloccata.
create policy "Users read own blocks"
on public.user_blocks for select
to authenticated
using (blocker_id = (select auth.uid()));

create policy "Users create own blocks"
on public.user_blocks for insert
to authenticated
with check (blocker_id = (select auth.uid()));

create policy "Users delete own blocks"
on public.user_blocks for delete
to authenticated
using (blocker_id = (select auth.uid()));

grant select, insert, delete on table public.user_blocks to authenticated;
