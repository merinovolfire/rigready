-- Allows authorized department officers to manage reusable checklist definitions.
alter table public.inspection_templates enable row level security;
alter table public.inspection_questions enable row level security;
drop policy if exists "officers manage templates" on public.inspection_templates;
create policy "officers manage templates" on public.inspection_templates for all to authenticated using (public.current_role() in ('administrator','chief_officer','apparatus_officer')) with check (public.current_role() in ('administrator','chief_officer','apparatus_officer'));
drop policy if exists "officers manage questions" on public.inspection_questions;
create policy "officers manage questions" on public.inspection_questions for all to authenticated using (public.current_role() in ('administrator','chief_officer','apparatus_officer')) with check (public.current_role() in ('administrator','chief_officer','apparatus_officer'));
