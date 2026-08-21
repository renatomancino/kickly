-- Funzione di supporto per il filtro anti-blocco lato RLS, piu'
-- l'aggiornamento della policy che oggi espone i profili ai membri della
-- stessa lega.
--
-- PERCHE' qui e non nella migrazione precedente: private.is_blocked_pair
-- deve esistere prima di poter essere referenziata da una policy, e tenerla
-- in un file a parte rende il diff di ogni singola migrazione piu' piccolo
-- da rivedere (tabelle, poi funzione+policy, poi le due RPC di lista, Task 3).
--
-- SECURITY DEFINER (non INVOKER): la policy "Users read own blocks" su
-- user_blocks limita la SELECT diretta a blocker_id = auth.uid(), quindi un
-- utente A non potrebbe MAI leggere la riga "B ha bloccato A" (blocker_id =
-- B) restando SECURITY INVOKER. La funzione gira con i privilegi del
-- proprietario per poter controllare ENTRAMBE le direzioni indipendentemente
-- da chi chiama, esattamente come private.shares_active_league
-- (20260812173135_milestone_2_leagues.sql).
create or replace function private.is_blocked_pair(user_a uuid, user_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_blocks
    where (blocker_id = user_a and blocked_id = user_b)
       or (blocker_id = user_b and blocked_id = user_a)
  );
$$;

-- A differenza di private.shares_active_league (che resta eseguibile da
-- PUBLIC per una svista pre-esistente, non oggetto di questa migrazione),
-- qui la revoke e' esplicita: Postgres concede EXECUTE a PUBLIC su ogni
-- funzione appena creata per default, e senza questa riga anche `anon`
-- potrebbe interrogare chi ha bloccato chi.
revoke all on function private.is_blocked_pair(uuid, uuid) from public;
grant execute on function private.is_blocked_pair(uuid, uuid) to authenticated;

-- Sostituisce "Authenticated profiles are readable"
-- (20260813141108_optimize_realtime_performance.sql:311-319): stesse tre
-- condizioni di prima, ma il ramo "condivido una lega attiva" ora e' negato
-- quando le due parti si sono bloccate a vicenda. Il ramo profile_public
-- resta intatto di proposito: un profilo che l'utente ha scelto di rendere
-- pubblico a chiunque non si nasconde per un blocco, che riguarda
-- specificamente "sei un mio compagno di lega sconosciuto", non la
-- visibilita' pubblica generale (vedi Design — Sezione 2 della spec:
-- "all'interno della lega condivisa").
drop policy if exists "Authenticated profiles are readable" on public.profiles;

create policy "Authenticated profiles are readable"
on public.profiles
for select
to authenticated
using (
  profile_public
  or id = (select auth.uid())
  or (
    (select private.shares_active_league(id))
    and not (select private.is_blocked_pair((select auth.uid()), id))
  )
);
