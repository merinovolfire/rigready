-- Checklist-based equipment inspections. Templates may be category-specific or general (category_id null).
create table if not exists public.equipment_check_templates(id uuid primary key default gen_random_uuid(),name text not null,frequency text not null check(frequency in('daily','weekly','monthly','annual')),category_id uuid references public.equipment_categories,active boolean not null default true,created_at timestamptz default now());
create table if not exists public.equipment_check_questions(id uuid primary key default gen_random_uuid(),template_id uuid not null references public.equipment_check_templates on delete cascade,question text not null,section text,display_order integer not null,required boolean not null default true,unique(template_id,display_order));
create table if not exists public.equipment_inspections(id uuid primary key default gen_random_uuid(),equipment_id uuid not null references public.equipment,template_id uuid not null references public.equipment_check_templates,inspector_id uuid not null references public.profiles,submitted_at timestamptz default now(),signature_name text not null,notes text);
create table if not exists public.equipment_inspection_responses(id uuid primary key default gen_random_uuid(),inspection_id uuid not null references public.equipment_inspections on delete cascade,question_id uuid not null references public.equipment_check_questions,response public.answer_status not null,note text,photo_path text,unique(inspection_id,question_id),check(response not in('fail','attention') or note is not null));
alter table public.equipment_check_templates enable row level security; alter table public.equipment_check_questions enable row level security; alter table public.equipment_inspections enable row level security; alter table public.equipment_inspection_responses enable row level security;
create policy "authenticated read equipment check templates" on public.equipment_check_templates for select to authenticated using(true);
create policy "authenticated read equipment check questions" on public.equipment_check_questions for select to authenticated using(true);
create policy "staff inspect equipment" on public.equipment_inspections for select to authenticated using(public.is_command() or inspector_id=auth.uid() or equipment_id in(select id from public.equipment));
create policy "staff read equipment responses" on public.equipment_inspection_responses for select to authenticated using(inspection_id in(select id from public.equipment_inspections));
create or replace function public.submit_equipment_inspection(p_equipment_id uuid,p_template_id uuid,p_signature_name text,p_notes text,p_responses jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare v_inspection uuid; v_item jsonb; v_response uuid; v_question text; v_bad boolean:=false;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 insert into equipment_inspections(equipment_id,template_id,inspector_id,signature_name,notes) values(p_equipment_id,p_template_id,auth.uid(),p_signature_name,p_notes) returning id into v_inspection;
 for v_item in select * from jsonb_array_elements(p_responses) loop
  if (v_item->>'response') in ('fail','attention') and coalesce(v_item->>'note','')='' then raise exception 'Failed items require a note'; end if;
  insert into equipment_inspection_responses(inspection_id,question_id,response,note) values(v_inspection,(v_item->>'question_id')::uuid,(v_item->>'response')::answer_status,nullif(v_item->>'note','')) returning id into v_response;
  if (v_item->>'response') in ('fail','attention') then v_bad:=true; select question into v_question from equipment_check_questions where id=(v_item->>'question_id')::uuid; insert into deficiencies(equipment_id,response_id,title,description,severity,created_by) values(p_equipment_id,null,v_question,v_item->>'note',case when v_item->>'response'='fail' then 'high' else 'medium' end,auth.uid()); end if;
 end loop;
 update equipment set condition=case when v_bad then 'attention' else 'good' end where id=p_equipment_id;
 insert into audit_log(actor_id,action,entity_type,entity_id) values(auth.uid(),'submit','equipment_inspection',v_inspection);
 return v_inspection;
end $$;
grant execute on function public.submit_equipment_inspection(uuid,uuid,text,text,jsonb) to authenticated;
insert into public.equipment_check_templates(name,frequency,category_id) select 'General Equipment Readiness','daily',null where not exists(select 1 from public.equipment_check_templates where name='General Equipment Readiness');
insert into public.equipment_check_questions(template_id,question,section,display_order) select t.id,x.question,x.section,x.ord from public.equipment_check_templates t cross join(values(1,'Item is present, clean, and free of visible damage','Condition'),(2,'Item operates as intended and all controls function','Operation'),(3,'Required accessories, seals, labels, and expiration dates are current','Readiness'))x(ord,question,section) where t.name='General Equipment Readiness' and not exists(select 1 from public.equipment_check_questions q where q.template_id=t.id and q.display_order=x.ord);
notify pgrst,'reload schema';
