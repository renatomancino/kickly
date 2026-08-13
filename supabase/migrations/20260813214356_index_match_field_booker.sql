create index matches_field_booked_by_idx
on public.matches (field_booked_by)
where field_booked_by is not null;
