drop policy if exists "Visible leagues are readable" on public.leagues;

create policy "Public leagues are readable anonymously"
on public.leagues for select
to anon
using (visibility = 'public');

create policy "Visible leagues are readable by users"
on public.leagues for select
to authenticated
using (
  visibility = 'public' or (select private.is_league_member(id))
);
