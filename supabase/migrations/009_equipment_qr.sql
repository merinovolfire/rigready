alter table public.equipment add column if not exists qr_token uuid not null default gen_random_uuid();
create unique index if not exists equipment_qr_token_unique on public.equipment(qr_token);
