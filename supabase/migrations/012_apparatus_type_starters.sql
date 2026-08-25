insert into public.apparatus_types(name) values ('Engine'),('Tender'),('Brush'),('Rescue'),('Ladder'),('Command') on conflict(name) do nothing;
