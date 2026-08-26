-- RigReady / Merino VFD
-- Exactly ONE inspection checklist per apparatus type.
-- Removes daily + monthly duplicates. Keeps inspection history safe.
-- Run in Supabase → SQL Editor → New query → Run.

-- Preferred keeper name for each type
create temporary table _preferred (
  type_name text primary key,
  checklist_name text not null
);
insert into _preferred(type_name, checklist_name) values
  ('Engine',  'Engine Inspection'),
  ('Brush',   'Brush / Squad Inspection'),
  ('Tender',  'Tender Inspection'),
  ('Rescue',  'Rescue Inspection'),
  ('Command', 'Command Inspection'),
  ('Ladder',  'Ladder Inspection');

-- Older names from earlier seeds also count as the preferred keeper
create temporary table _alias (
  type_name text not null,
  old_name text not null
);
insert into _alias(type_name, old_name) values
  ('Engine',  'Engine Daily Readiness'),
  ('Engine',  'Engine Monthly Readiness'),
  ('Engine',  'Engine Weekly Readiness'),
  ('Engine',  'Engine Annual Readiness'),
  ('Brush',   'Brush / Squad Daily Readiness'),
  ('Brush',   'Brush Daily Readiness'),
  ('Brush',   'Brush Monthly Readiness'),
  ('Brush',   'Brush Weekly Readiness'),
  ('Brush',   'Squad Daily Readiness'),
  ('Tender',  'Tender Daily Readiness'),
  ('Tender',  'Tender Monthly Readiness'),
  ('Tender',  'Tender Weekly Readiness'),
  ('Rescue',  'Rescue Daily Readiness'),
  ('Rescue',  'Rescue Monthly Readiness'),
  ('Rescue',  'Rescue Weekly Readiness'),
  ('Command', 'Command Daily Readiness'),
  ('Command', 'Command Monthly Readiness'),
  ('Command', 'Command Weekly Readiness'),
  ('Ladder',  'Ladder Daily Readiness'),
  ('Ladder',  'Ladder Monthly Readiness');

-- Attach untyped templates whose name matches a known type alias / preferred name
update public.inspection_templates it
set apparatus_type_id = at.id
from public.apparatus_types at
join _preferred p on p.type_name = at.name
where it.apparatus_type_id is null
  and (it.name = p.checklist_name or it.name in (select old_name from _alias a where a.type_name = at.name));

update public.inspection_templates it
set apparatus_type_id = at.id
from public.apparatus_types at
join _alias a on a.type_name = at.name and a.old_name = it.name
where it.apparatus_type_id is null;

-- Ensure each type has at least one template (create preferred if missing entirely)
insert into public.inspection_templates(name, frequency, apparatus_type_id, active)
select p.checklist_name, 'daily', at.id, true
from _preferred p
join public.apparatus_types at on at.name = p.type_name
where not exists (
  select 1 from public.inspection_templates it
  where it.apparatus_type_id = at.id
);

-- Choose ONE keeper per type:
-- 1) preferred new name
-- 2) preferred old "Daily Readiness" name
-- 3) most-used by apparatus
-- 4) any remaining (stable by name/id)
create temporary table _keepers as
with typed as (
  select
    it.id as template_id,
    it.name as template_name,
    it.apparatus_type_id as type_id,
    at.name as type_name,
    (select count(*)::int from public.apparatus a where a.checklist_id = it.id) as use_count,
    case
      when it.name = p.checklist_name then 0
      when it.name in (select old_name from _alias a where a.type_name = at.name and a.old_name ilike '%Daily%') then 1
      when it.name in (select old_name from _alias a where a.type_name = at.name) then 2
      else 3
    end as pref_rank
  from public.inspection_templates it
  join public.apparatus_types at on at.id = it.apparatus_type_id
  left join _preferred p on p.type_name = at.name
),
ranked as (
  select *,
    row_number() over (
      partition by type_id
      order by pref_rank asc, use_count desc, template_name asc, template_id asc
    ) as rn
  from typed
)
select type_id, type_name, template_id as keeper_id, template_name as keeper_name
from ranked
where rn = 1;

-- Rename keepers to the clean single name (Engine Inspection, etc.)
update public.inspection_templates it
set
  name = p.checklist_name,
  frequency = 'daily',
  active = true,
  apparatus_type_id = k.type_id
from _keepers k
join _preferred p on p.type_name = k.type_name
where it.id = k.keeper_id;

-- Point every apparatus of that type at the single keeper
update public.apparatus a
set checklist_id = k.keeper_id,
    updated_at = now()
from _keepers k
where a.type_id = k.type_id
  and a.checklist_id is distinct from k.keeper_id;

-- Deactivate ALL non-keeper templates that belong to a type
update public.inspection_templates it
set active = false
from _keepers k
where it.apparatus_type_id = k.type_id
  and it.id <> k.keeper_id;

-- Deactivate general/orphan active templates (no type) — department wants type-based only
update public.inspection_templates
set active = false
where apparatus_type_id is null
  and active = true;

-- Delete unused inactive duplicates (no inspections, not assigned)
delete from public.inspection_questions q
using public.inspection_templates it
where q.template_id = it.id
  and it.active = false
  and not exists (select 1 from public.inspections i where i.template_id = it.id)
  and not exists (select 1 from public.apparatus a where a.checklist_id = it.id);

delete from public.inspection_templates it
where it.active = false
  and not exists (select 1 from public.inspections i where i.template_id = it.id)
  and not exists (select 1 from public.apparatus a where a.checklist_id = it.id);

-- Enforce going forward: only one ACTIVE checklist per apparatus type
drop index if exists public.one_active_checklist_per_type;
create unique index one_active_checklist_per_type
  on public.inspection_templates (apparatus_type_id)
  where active = true and apparatus_type_id is not null;

-- ========== Verification ==========
-- Table 1: should show active_checklists = 1 for every type that has apparatus
select
  at.name as apparatus_type,
  count(it.id) filter (where it.active) as active_checklists,
  max(it.name) filter (where it.active) as checklist_name,
  count(it.id) filter (where not coalesce(it.active, false)) as inactive_leftover
from public.apparatus_types at
left join public.inspection_templates it on it.apparatus_type_id = at.id
group by at.name
order by at.name;

-- Table 2: every unit on its single checklist
select
  a.unit_number,
  a.name,
  t.name as type,
  c.name as checklist,
  c.frequency,
  c.active as checklist_active
from public.apparatus a
left join public.apparatus_types t on t.id = a.type_id
left join public.inspection_templates c on c.id = a.checklist_id
order by a.unit_number;

-- Table 3: full remaining template list (should be ~1 active per type)
select it.name, it.frequency, it.active, at.name as type
from public.inspection_templates it
left join public.apparatus_types at on at.id = it.apparatus_type_id
order by it.active desc, at.name nulls last, it.name;
