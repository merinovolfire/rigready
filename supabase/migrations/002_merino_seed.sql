-- Merino Volunteer Fire Department starter data.
-- Real fleet is applied by 013_merino_fleet.sql (preferred for live DB).
-- This file remains safe for fresh installs.

insert into public.stations(name, address)
values ('Merino Station', 'Merino, Colorado')
on conflict (name) do nothing;

insert into public.apparatus_types(name)
values ('Engine'), ('Tender'), ('Brush'), ('Rescue'), ('Ladder'), ('Command')
on conflict (name) do nothing;

insert into public.equipment_categories(name)
values ('SCBA'), ('Medical'), ('Hose'), ('Hand Tools')
on conflict (name) do nothing;

-- Starter daily checklists (idempotent)
with e as (select id from apparatus_types where name = 'Engine')
insert into public.inspection_templates(name, frequency, apparatus_type_id)
select 'Engine Daily Readiness', 'daily', id from e
where not exists (select 1 from inspection_templates where name = 'Engine Daily Readiness');

with t as (select id from inspection_templates where name = 'Engine Daily Readiness')
insert into public.inspection_questions(template_id, question, section, display_order)
select t.id, x.question, x.section, x.ord from t
cross join (values
  (1, 'Cab, warning lights, and audible warning devices', 'Cab'),
  (2, 'Pump panel, gauges, and controls', 'Pump'),
  (3, 'SCBA inventory and cylinder pressure', 'Safety'),
  (4, 'Tires, fluids, leaks, and exterior condition', 'Walk-around'),
  (5, 'Fuel level and DEF', 'Walk-around'),
  (6, 'Water tank level and foam system (if equipped)', 'Pump'),
  (7, 'Hose loads, nozzles, and appliances secure', 'Hose')
) as x(ord, question, section)
where not exists (select 1 from inspection_questions q where q.template_id = t.id and q.display_order = x.ord);

with e as (select id from apparatus_types where name = 'Brush')
insert into public.inspection_templates(name, frequency, apparatus_type_id)
select 'Brush / Squad Daily Readiness', 'daily', id from e
where not exists (select 1 from inspection_templates where name = 'Brush / Squad Daily Readiness');

with t as (select id from inspection_templates where name = 'Brush / Squad Daily Readiness')
insert into public.inspection_questions(template_id, question, section, display_order)
select t.id, x.question, x.section, x.ord from t
cross join (values
  (1, 'Cab, lights, siren, and radio', 'Cab'),
  (2, '4x4 / drivetrain engagement and tire condition', 'Chassis'),
  (3, 'Pump, reel, and tank level', 'Pump'),
  (4, 'Hand tools, rakes, and wildland packs secured', 'Tools'),
  (5, 'Fuel level', 'Walk-around'),
  (6, 'Fluids, belts, leaks, and exterior condition', 'Walk-around')
) as x(ord, question, section)
where not exists (select 1 from inspection_questions q where q.template_id = t.id and q.display_order = x.ord);

with e as (select id from apparatus_types where name = 'Tender')
insert into public.inspection_templates(name, frequency, apparatus_type_id)
select 'Tender Daily Readiness', 'daily', id from e
where not exists (select 1 from inspection_templates where name = 'Tender Daily Readiness');

with t as (select id from inspection_templates where name = 'Tender Daily Readiness')
insert into public.inspection_questions(template_id, question, section, display_order)
select t.id, x.question, x.section, x.ord from t
cross join (values
  (1, 'Cab, lights, siren, and radio', 'Cab'),
  (2, 'Tank level and tank integrity', 'Tank'),
  (3, 'Dump valve, ports, and fill connections', 'Tank'),
  (4, 'Pump operation and gauges (if equipped)', 'Pump'),
  (5, 'Tires, brakes, fluids, leaks', 'Walk-around'),
  (6, 'Fuel level', 'Walk-around')
) as x(ord, question, section)
where not exists (select 1 from inspection_questions q where q.template_id = t.id and q.display_order = x.ord);

with e as (select id from apparatus_types where name = 'Rescue')
insert into public.inspection_templates(name, frequency, apparatus_type_id)
select 'Rescue Daily Readiness', 'daily', id from e
where not exists (select 1 from inspection_templates where name = 'Rescue Daily Readiness');

with t as (select id from inspection_templates where name = 'Rescue Daily Readiness')
insert into public.inspection_questions(template_id, question, section, display_order)
select t.id, x.question, x.section, x.ord from t
cross join (values
  (1, 'Cab, lights, siren, and radio', 'Cab'),
  (2, 'Rescue tool power units and batteries charged', 'Tools'),
  (3, 'Extrication tools, cribbing, and straps inventoried', 'Tools'),
  (4, 'Medical / trauma bag present and sealed', 'Medical'),
  (5, 'Scene lighting operational', 'Electrical'),
  (6, 'Tires, fluids, leaks, and exterior condition', 'Walk-around'),
  (7, 'Fuel level', 'Walk-around')
) as x(ord, question, section)
where not exists (select 1 from inspection_questions q where q.template_id = t.id and q.display_order = x.ord);

with e as (select id from apparatus_types where name = 'Command')
insert into public.inspection_templates(name, frequency, apparatus_type_id)
select 'Command Daily Readiness', 'daily', id from e
where not exists (select 1 from inspection_templates where name = 'Command Daily Readiness');

with t as (select id from inspection_templates where name = 'Command Daily Readiness')
insert into public.inspection_questions(template_id, question, section, display_order)
select t.id, x.question, x.section, x.ord from t
cross join (values
  (1, 'Cab, lights, siren, and radio(s)', 'Cab'),
  (2, 'Command boards, maps, and ICS supplies', 'Command'),
  (3, 'Mobile data / tablet / charger present', 'Electronics'),
  (4, 'Scene lighting and electrical', 'Electrical'),
  (5, 'Tires, fluids, leaks, and exterior condition', 'Walk-around'),
  (6, 'Fuel level', 'Walk-around')
) as x(ord, question, section)
where not exists (select 1 from inspection_questions q where q.template_id = t.id and q.display_order = x.ord);

-- Real Merino fleet (no demo E-101)
with station as (select id from stations where name = 'Merino Station' limit 1),
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
  f.unit_number, f.name, station.id, t.id, c.id,
  0, 100, 'available', true
from fleet f
cross join station
join apparatus_types t on t.name = f.type_name
left join inspection_templates c on c.name = f.checklist_name and c.active = true
on conflict (unit_number) do nothing;
