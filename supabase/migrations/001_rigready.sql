-- RigReady / Merino Volunteer Fire Department
-- Run using Supabase CLI migration or SQL Editor. Auth users live in auth.users;
-- profiles supplies department-specific role and station access.
create extension if not exists pgcrypto;
create type public.user_role as enum ('administrator','chief_officer','apparatus_officer','firefighter','maintenance_user');
create type public.apparatus_status as enum ('available','limited','out_of_service');
create type public.inspection_status as enum ('draft','submitted');
create type public.answer_status as enum ('pass','fail','na','attention');
create type public.deficiency_status as enum ('open','assigned','in_progress','completed','deferred');
create table public.stations(id uuid primary key default gen_random_uuid(), name text not null unique, address text, created_at timestamptz default now());
create table public.profiles(id uuid primary key references auth.users(id) on delete cascade, display_name text not null, role public.user_role not null default 'firefighter', station_id uuid references public.stations, active boolean not null default true, created_at timestamptz default now());
create table public.apparatus_types(id uuid primary key default gen_random_uuid(), name text not null unique);
create table public.inspection_templates(id uuid primary key default gen_random_uuid(), name text not null, frequency text not null check(frequency in('daily','weekly','monthly','annual')), apparatus_type_id uuid references public.apparatus_types, active boolean not null default true);
create table public.apparatus(id uuid primary key default gen_random_uuid(), unit_number text not null unique, name text not null, station_id uuid not null references public.stations, type_id uuid references public.apparatus_types, vin text unique, mileage integer not null default 0 check(mileage>=0), fuel_level numeric(5,2) check(fuel_level between 0 and 100), status public.apparatus_status not null default 'available', in_service boolean not null default true, checklist_id uuid references public.inspection_templates, qr_token uuid not null default gen_random_uuid() unique, created_at timestamptz default now(), updated_at timestamptz default now());
create table public.equipment_categories(id uuid primary key default gen_random_uuid(), name text not null unique);
create table public.equipment(id uuid primary key default gen_random_uuid(), name text not null, category_id uuid references public.equipment_categories, serial_number text unique, manufacturer text, model text, apparatus_id uuid references public.apparatus, station_id uuid references public.stations, required_quantity integer not null default 1 check(required_quantity>0), inspection_frequency text check(inspection_frequency in('daily','weekly','monthly','annual')), expiration_date date, condition text not null default 'good' check(condition in('good','attention','failed','out_of_service')), replacement_cost numeric(12,2), photo_path text, created_at timestamptz default now(), check(apparatus_id is not null or station_id is not null));
create table public.inspection_questions(id uuid primary key default gen_random_uuid(), template_id uuid not null references public.inspection_templates on delete cascade, question text not null, section text, display_order integer not null, required boolean not null default true, unique(template_id,display_order));
create table public.inspections(id uuid primary key default gen_random_uuid(), apparatus_id uuid not null references public.apparatus, template_id uuid not null references public.inspection_templates, inspector_id uuid not null references public.profiles, started_at timestamptz default now(), submitted_at timestamptz, status public.inspection_status not null default 'draft', signature_name text, notes text);
create table public.inspection_responses(id uuid primary key default gen_random_uuid(), inspection_id uuid not null references public.inspections on delete cascade, question_id uuid not null references public.inspection_questions, response public.answer_status not null, note text, photo_path text, unique(inspection_id,question_id), check(response not in('fail','attention') or note is not null));
create table public.deficiencies(id uuid primary key default gen_random_uuid(), apparatus_id uuid references public.apparatus, equipment_id uuid references public.equipment, inspection_id uuid references public.inspections, response_id uuid references public.inspection_responses, title text not null, description text not null, severity text not null default 'medium' check(severity in('low','medium','high','critical')), status public.deficiency_status not null default 'open', assigned_to uuid references public.profiles, due_date date, created_by uuid not null references public.profiles, completed_at timestamptz, created_at timestamptz default now(), check(apparatus_id is not null or equipment_id is not null));
create table public.repair_records(id uuid primary key default gen_random_uuid(), deficiency_id uuid not null references public.deficiencies, performed_by uuid references public.profiles, repair_notes text not null, parts text, cost numeric(12,2) not null default 0, completed_at timestamptz, created_at timestamptz default now());
create table public.attachments(id uuid primary key default gen_random_uuid(), entity_type text not null, entity_id uuid not null, file_name text not null, storage_path text not null, uploaded_by uuid references public.profiles, created_at timestamptz default now());
create table public.audit_log(id bigint generated always as identity primary key, actor_id uuid references public.profiles, action text not null, entity_type text not null, entity_id uuid, detail jsonb not null default '{}'::jsonb, created_at timestamptz default now());
create or replace function public.current_role() returns public.user_role language sql stable security definer set search_path=public as $$select role from public.profiles where id=auth.uid() and active$$;
create or replace function public.current_station() returns uuid language sql stable security definer set search_path=public as $$select station_id from public.profiles where id=auth.uid() and active$$;
create or replace function public.is_command() returns boolean language sql stable security definer set search_path=public as $$select public.current_role() in ('administrator','chief_officer')$$;
alter table public.profiles enable row level security; alter table public.stations enable row level security; alter table public.apparatus enable row level security; alter table public.equipment enable row level security; alter table public.inspections enable row level security; alter table public.inspection_responses enable row level security; alter table public.deficiencies enable row level security; alter table public.repair_records enable row level security; alter table public.audit_log enable row level security;
create policy "authenticated profiles visible" on public.profiles for select to authenticated using(true);
create policy "own profile update" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "department stations" on public.stations for select to authenticated using(true);
create policy "apparatus by station or command" on public.apparatus for select to authenticated using(public.is_command() or station_id=public.current_station());
create policy "officers manage apparatus" on public.apparatus for all to authenticated using(public.current_role() in ('administrator','chief_officer','apparatus_officer')) with check(public.current_role() in ('administrator','chief_officer','apparatus_officer'));
create policy "equipment by station or command" on public.equipment for select to authenticated using(public.is_command() or station_id=public.current_station() or apparatus_id in(select id from public.apparatus));
create policy "staff inspect accessible apparatus" on public.inspections for all to authenticated using(public.is_command() or inspector_id=auth.uid() or apparatus_id in(select id from public.apparatus)) with check(inspector_id=auth.uid());
create policy "staff responses" on public.inspection_responses for all to authenticated using(inspection_id in(select id from public.inspections)) with check(inspection_id in(select id from public.inspections));
create policy "deficiency access" on public.deficiencies for select to authenticated using(public.is_command() or assigned_to=auth.uid() or apparatus_id in(select id from public.apparatus));
create policy "officer maintenance deficiency work" on public.deficiencies for all to authenticated using(public.current_role() in('administrator','chief_officer','apparatus_officer','maintenance_user')) with check(public.current_role() in('administrator','chief_officer','apparatus_officer','maintenance_user'));
create policy "repair access" on public.repair_records for all to authenticated using(public.current_role() in('administrator','chief_officer','maintenance_user')) with check(public.current_role() in('administrator','chief_officer','maintenance_user'));
create policy "audit command view" on public.audit_log for select to authenticated using(public.is_command());
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values ('inspection-photos','inspection-photos',false,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy "users upload inspection photos" on storage.objects for insert to authenticated with check(bucket_id='inspection-photos' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "users view permitted photos" on storage.objects for select to authenticated using(bucket_id='inspection-photos');

-- Create every authenticated member as a firefighter profile. Command staff promote
-- users from the Supabase SQL Editor or an administrator management screen.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,display_name) values(new.id,coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1))); return new; end; $$;
create or replace trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- Atomic submission is security-definer so a firefighter can create system-owned deficiencies
-- without being granted broad deficiency write access.
create or replace function public.submit_inspection(p_apparatus_id uuid,p_template_id uuid,p_signature_name text,p_notes text,p_responses jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_inspection uuid; v_item jsonb; v_response uuid; v_question text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 insert into inspections(apparatus_id,template_id,inspector_id,status,submitted_at,signature_name,notes) values(p_apparatus_id,p_template_id,auth.uid(),'submitted',now(),p_signature_name,p_notes) returning id into v_inspection;
 for v_item in select * from jsonb_array_elements(p_responses) loop
  if (v_item->>'response') in ('fail','attention') and coalesce(v_item->>'note','')='' then raise exception 'Failed items require a note'; end if;
  insert into inspection_responses(inspection_id,question_id,response,note,photo_path) values(v_inspection,(v_item->>'question_id')::uuid,(v_item->>'response')::answer_status,nullif(v_item->>'note',''),nullif(v_item->>'photo_path','')) returning id into v_response;
  if (v_item->>'response') in ('fail','attention') then
   select question into v_question from inspection_questions where id=(v_item->>'question_id')::uuid;
   insert into deficiencies(apparatus_id,inspection_id,response_id,title,description,severity,created_by) values(p_apparatus_id,v_inspection,v_response,v_question,v_item->>'note',case when v_item->>'response'='fail' then 'high' else 'medium' end,auth.uid());
  end if;
 end loop;
 insert into audit_log(actor_id,action,entity_type,entity_id) values(auth.uid(),'submit','inspection',v_inspection);
 return v_inspection;
end $$;
grant execute on function public.submit_inspection(uuid,uuid,text,text,jsonb) to authenticated;
