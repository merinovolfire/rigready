-- RigReady / Merino Volunteer Fire Department
-- Real apparatus fleet. Safe to re-run (idempotent).
-- Replaces demo unit E-101 / DEMO-REPLACE-BEFORE-USE.
-- Run in Supabase Dashboard → SQL Editor → New query → Run.

-- 1) Station name the department uses
update public.stations
set name = 'Merino Station',
    address = coalesce(nullif(address, ''), 'Merino, Colorado')
where name in ('Merino Volunteer Fire Department', 'Merino station', 'Merino Station');

insert into public.stations(name, address)
values ('Merino Station', 'Merino, Colorado')
on conflict (name) do update set address = excluded.address;

-- 2) Apparatus types used by this fleet
insert into public.apparatus_types(name)
values ('Engine'), ('Tender'), ('Brush'), ('Rescue'), ('Ladder'), ('Command')
on conflict (name) do nothing;

-- 3) Equipment categories (kept from starter seed)
insert into public.equipment_categories(name)
values ('SCBA'), ('Medical'), ('Hose'), ('Hand Tools')
on conflict (name) do nothing;

-- 4) Starter daily checklists per type (only created if missing)
-- Engine
with t as (
  insert into public.inspection_templates(name, frequency, apparatus_type_id, active)
  select 'Engine Daily Readiness', 'daily', id, true
  from public.apparatus_types where name = 'Engine'
  and not exists (select 1 from public.inspection_templates where name = 'Engine Daily Readiness')
  returning id
)
insert into public.inspection_questions(template_id, question, section, display_order)
select t.id, x.question, x.section, x.ord
from t
cross join (values
  (1, 'Cab, warning lights, and audible warning devices', 'Cab'),
  (2, 'Pump panel, gauges, and controls', 'Pump'),
  (3, 'SCBA inventory and cylinder pressure', 'Safety'),
  (4, 'Tires, fluids, leaks, and exterior condition', 'Walk-around'),
  (5, 'Fuel level and DEF', 'Walk-around'),
  (6, 'Water tank level and foam system (if equipped)', 'Pump'),
  (7, 'Hose loads, nozzles, and appliances secure', 'Hose')
) as x(ord, question, section);

-- Brush / Squad
with t as (
  insert into public.inspection_templates(name, frequency, apparatus_type_id, active)
  select 'Brush / Squad Daily Readiness', 'daily', id, true
  from public.apparatus_types where name = 'Brush'
  and not exists (select 1 from public.inspection_templates where name = 'Brush / Squad Daily Readiness')
  returning id
)
insert into public.inspection_questions(template_id, question, section, display_order)
select t.id, x.question, x.section, x.ord
from t
cross join (values
  (1, 'Cab, lights, siren, and radio', 'Cab'),
  (2, '4x4 / drivetrain engagement and tire condition', 'Chassis'),
  (3, 'Pump, reel, and tank level', 'Pump'),
  (4, 'Hand tools, rakes, and wildland packs secured', 'Tools'),
  (5, 'Fuel level', 'Walk-around'),
  (6, 'Fluids, belts, leaks, and exterior condition', 'Walk-around')
) as x(ord, question, section);

-- Tender
with t as (
  insert into public.inspection_templates(name, frequency, apparatus_type_id, active)
  select 'Tender Daily Readiness', 'daily', id, true
  from public.apparatus_types where name = 'Tender'
  and not exists (select 1 from public.inspection_templates where name = 'Tender Daily Readiness')
  returning id
)
insert into public.inspection_questions(template_id, question, section, display_order)
select t.id, x.question, x.section, x.ord
from t
cross join (values
  (1, 'Cab, lights, siren, and radio', 'Cab'),
  (2, 'Tank level and tank integrity', 'Tank'),
  (3, 'Dump valve, ports, and fill connections', 'Tank'),
  (4, 'Pump operation and gauges (if equipped)', 'Pump'),
  (5, 'Tires, brakes, fluids, leaks', 'Walk-around'),
  (6, 'Fuel level', 'Walk-around')
) as x(ord, question, section);

-- Rescue
with t as (
  insert into public.inspection_templates(name, frequency, apparatus_type_id, active)
  select 'Rescue Daily Readiness', 'daily', id, true
  from public.apparatus_types where name = 'Rescue'
  and not exists (select 1 from public.inspection_templates where name = 'Rescue Daily Readiness')
  returning id
)
insert into public.inspection_questions(template_id, question, section, display_order)
select t.id, x.question, x.section, x.ord
from t
cross join (values
  (1, 'Cab, lights, siren, and radio', 'Cab'),
  (2, 'Rescue tool power units and batteries charged', 'Tools'),
  (3, 'Extrication tools, cribbing, and straps inventoried', 'Tools'),
  (4, 'Medical / trauma bag present and sealed', 'Medical'),
  (5, 'Scene lighting operational', 'Electrical'),
  (6, 'Tires, fluids, leaks, and exterior condition', 'Walk-around'),
  (7, 'Fuel level', 'Walk-around')
) as x(ord, question, section);

-- Command
with t as (
  insert into public.inspection_templates(name, frequency, apparatus_type_id, active)
  select 'Command Daily Readiness', 'daily', id, true
  from public.apparatus_types where name = 'Command'
  and not exists (select 1 from public.inspection_templates where name = 'Command Daily Readiness')
  returning id
)
insert into public.inspection_questions(template_id, question, section, display_order)
select t.id, x.question, x.section, x.ord
from t
cross join (values
  (1, 'Cab, lights, siren, and radio(s)', 'Cab'),
  (2, 'Command boards, maps, and ICS supplies', 'Command'),
  (3, 'Mobile data / tablet / charger present', 'Electronics'),
  (4, 'Scene lighting and electrical', 'Electrical'),
  (5, 'Tires, fluids, leaks, and exterior condition', 'Walk-around'),
  (6, 'Fuel level', 'Walk-around')
) as x(ord, question, section);

-- 5) Remove fictional demo apparatus E-101 (and anything hanging off it).
-- Order matters: notification_log → repair_records → deficiencies →
-- inspection responses → inspections → equipment inspections → equipment → apparatus.
do $$
declare
  demo_ids uuid[];
  equip_ids uuid[];
  def_ids uuid[];
  insp_ids uuid[];
  eq_insp_ids uuid[];
begin
  select array_agg(id) into demo_ids
  from public.apparatus
  where unit_number = 'E-101'
     or vin = 'DEMO-REPLACE-BEFORE-USE'
     or name ilike 'Training Engine%';

  if demo_ids is null then
    return;
  end if;

  select array_agg(id) into equip_ids
  from public.equipment
  where apparatus_id = any(demo_ids);

  select array_agg(id) into insp_ids
  from public.inspections
  where apparatus_id = any(demo_ids);

  if equip_ids is not null then
    select array_agg(id) into eq_insp_ids
    from public.equipment_inspections
    where equipment_id = any(equip_ids);
  end if;

  -- All deficiencies tied to the demo apparatus OR its equipment OR its inspections
  select array_agg(id) into def_ids
  from public.deficiencies
  where apparatus_id = any(demo_ids)
     or (equip_ids is not null and equipment_id = any(equip_ids))
     or (insp_ids is not null and inspection_id = any(insp_ids))
     or (eq_insp_ids is not null and equipment_inspection_id = any(eq_insp_ids));

  if def_ids is not null then
    delete from public.notification_log where deficiency_id = any(def_ids);
    delete from public.repair_records where deficiency_id = any(def_ids);
    delete from public.deficiencies where id = any(def_ids);
  end if;

  if insp_ids is not null then
    delete from public.inspection_responses where inspection_id = any(insp_ids);
    delete from public.inspections where id = any(insp_ids);
  end if;

  if eq_insp_ids is not null then
    delete from public.equipment_inspection_responses where inspection_id = any(eq_insp_ids);
    delete from public.equipment_inspections where id = any(eq_insp_ids);
  end if;

  if equip_ids is not null then
    delete from public.equipment where id = any(equip_ids);
  end if;

  delete from public.apparatus where id = any(demo_ids);
end $$;

-- 6) Insert / update the real Merino fleet
-- unit_number is unique; re-running updates name/type/station/checklist.
with station as (
  select id from public.stations where name = 'Merino Station' limit 1
),
fleet as (
  select * from (values
    ('E27', 'Engine 27', 'Engine',  'Engine Daily Readiness'),
    ('E21', 'Engine 21', 'Engine',  'Engine Daily Readiness'),
    ('S22', 'Squad 22',  'Brush',   'Brush / Squad Daily Readiness'),
    ('S23', 'Squad 23',  'Brush',   'Brush / Squad Daily Readiness'),
    ('S24', 'Squad 24',  'Brush',   'Brush / Squad Daily Readiness'),
    ('S25', 'Squad 25',  'Brush',   'Brush / Squad Daily Readiness'),
    ('T26', 'Tender 26', 'Tender',  'Tender Daily Readiness'),
    ('T28', 'Tender 28', 'Tender',  'Tender Daily Readiness'),
    ('R29', 'Rescue 29', 'Rescue',  'Rescue Daily Readiness'),
    ('F20', 'Fire 20',   'Command', 'Command Daily Readiness')
  ) as v(unit_number, name, type_name, checklist_name)
)
insert into public.apparatus as a (
  unit_number, name, station_id, type_id, checklist_id,
  mileage, fuel_level, status, in_service
)
select
  f.unit_number,
  f.name,
  station.id,
  t.id,
  c.id,
  0,
  100,
  'available',
  true
from fleet f
cross join station
join public.apparatus_types t on t.name = f.type_name
left join public.inspection_templates c on c.name = f.checklist_name and c.active = true
on conflict (unit_number) do update set
  name = excluded.name,
  station_id = excluded.station_id,
  type_id = excluded.type_id,
  checklist_id = coalesce(excluded.checklist_id, a.checklist_id),
  status = excluded.status,
  in_service = excluded.in_service,
  updated_at = now();

-- 7) Verification (results show in the SQL Editor bottom panel)
select a.unit_number, a.name, s.name as station, t.name as type, c.name as checklist, a.status, a.in_service
from public.apparatus a
join public.stations s on s.id = a.station_id
left join public.apparatus_types t on t.id = a.type_id
left join public.inspection_templates c on c.id = a.checklist_id
order by a.unit_number;
