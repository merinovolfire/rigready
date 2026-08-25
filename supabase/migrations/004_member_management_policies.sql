-- Command staff can maintain display name, role, station assignment, and active state.
drop policy if exists "command staff manage member profiles" on public.profiles;
create policy "command staff manage member profiles"
on public.profiles
for update
to authenticated
using (public.current_role() in ('administrator','chief_officer'))
with check (public.current_role() in ('administrator','chief_officer'));
