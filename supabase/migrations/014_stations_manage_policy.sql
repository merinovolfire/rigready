-- Allow command / apparatus officers to add and edit stations from the app.
-- SQL Editor runs as postgres and does not need this; the RigReady UI does.

drop policy if exists "officers manage stations" on public.stations;
create policy "officers manage stations" on public.stations
  for all to authenticated
  using (public.current_role() in ('administrator', 'chief_officer', 'apparatus_officer'))
  with check (public.current_role() in ('administrator', 'chief_officer', 'apparatus_officer'));
