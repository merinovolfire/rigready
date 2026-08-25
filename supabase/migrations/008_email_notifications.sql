create table if not exists public.notification_log(id uuid primary key default gen_random_uuid(),deficiency_id uuid references public.deficiencies,recipient_email text not null,event_type text not null,status text not null default 'sent',provider_id text,error text,created_at timestamptz default now());
alter table public.notification_log enable row level security;
create policy "command view notification log" on public.notification_log for select to authenticated using(public.is_command());
