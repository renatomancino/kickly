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
  insert into public.player_rating_history (
    user_id, previous_rating, new_rating, delta, reason
  ) values (new.id, 70, 70, 0, 'Valutazione iniziale');
  return new;
end;
$$;

drop policy if exists "Participants read own MVP vote" on public.mvp_votes;
create policy "Participants read MVP votes" on public.mvp_votes for select to authenticated
using (
  voter_id = (select auth.uid()) or exists (
    select 1 from public.matches match
    where match.id = match_id
      and match.mvp_finalized_at is not null
      and (select private.is_league_member(match.league_id))
  )
);
