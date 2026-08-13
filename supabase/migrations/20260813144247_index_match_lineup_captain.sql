create index match_lineup_teams_captain_idx
  on public.match_lineup_teams (captain_user_id)
  where captain_user_id is not null;
