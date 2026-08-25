create table if not exists public.department_settings(id boolean primary key default true check(id),department_name text not null default 'Merino Volunteer Fire Department',logo_path text,updated_at timestamptz default now());
insert into public.department_settings(id) values(true) on conflict(id) do nothing;
alter table public.department_settings enable row level security;
create policy "authenticated read department settings" on public.department_settings for select to authenticated using(true);
create policy "command manage department settings" on public.department_settings for all to authenticated using(public.current_role() in ('administrator','chief_officer')) with check(public.current_role() in ('administrator','chief_officer'));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('department-branding','department-branding',true,2097152,array['image/jpeg','image/png','image/webp','image/svg+xml']) on conflict(id) do update set public=true;
create policy "command upload department branding" on storage.objects for insert to authenticated with check(bucket_id='department-branding' and public.current_role() in ('administrator','chief_officer'));
create policy "command update department branding" on storage.objects for update to authenticated using(bucket_id='department-branding' and public.current_role() in ('administrator','chief_officer'));
create policy "public read department branding" on storage.objects for select using(bucket_id='department-branding');
