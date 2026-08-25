alter table public.department_settings add column if not exists abbreviation text not null default 'Merino VFD';
update public.department_settings set abbreviation='Merino VFD' where abbreviation is null or abbreviation='';
