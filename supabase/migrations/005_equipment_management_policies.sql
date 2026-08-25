-- Equipment inventory and category management for authorized department staff.
alter table public.equipment enable row level security;
alter table public.equipment_categories enable row level security;
drop policy if exists "equipment managers write equipment" on public.equipment;
create policy "equipment managers write equipment" on public.equipment for all to authenticated using (public.current_role() in ('administrator','chief_officer','apparatus_officer','maintenance_user')) with check (public.current_role() in ('administrator','chief_officer','apparatus_officer','maintenance_user'));
drop policy if exists "authenticated read equipment categories" on public.equipment_categories;
create policy "authenticated read equipment categories" on public.equipment_categories for select to authenticated using (true);
drop policy if exists "equipment managers write categories" on public.equipment_categories;
create policy "equipment managers write categories" on public.equipment_categories for all to authenticated using (public.current_role() in ('administrator','chief_officer','apparatus_officer','maintenance_user')) with check (public.current_role() in ('administrator','chief_officer','apparatus_officer','maintenance_user'));
