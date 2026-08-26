-- Record fuel level on every apparatus inspection and update the unit.
-- Run in Supabase → SQL Editor → New query → Run.

alter table public.inspections
  add column if not exists fuel_level numeric(5,2)
  check (fuel_level is null or fuel_level between 0 and 100);

-- Recreate submit_inspection with optional fuel level parameter.
-- (CREATE OR REPLACE cannot change the argument list.)
drop function if exists public.submit_inspection(uuid, uuid, text, text, jsonb);

create or replace function public.submit_inspection(
  p_apparatus_id uuid,
  p_template_id uuid,
  p_signature_name text,
  p_notes text,
  p_responses jsonb,
  p_fuel_level numeric default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inspection uuid;
  v_item jsonb;
  v_response uuid;
  v_question text;
  v_fuel numeric(5,2);
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_fuel_level is not null and p_fuel_level not in (0, 25, 50, 75, 100) then
    raise exception 'Fuel level must be Full, 3/4, 1/2, 1/4, or Empty';
  end if;

  v_fuel := p_fuel_level;

  insert into inspections(
    apparatus_id, template_id, inspector_id, status,
    submitted_at, signature_name, notes, fuel_level
  ) values (
    p_apparatus_id, p_template_id, auth.uid(), 'submitted',
    now(), p_signature_name, p_notes, v_fuel
  ) returning id into v_inspection;

  for v_item in select * from jsonb_array_elements(p_responses) loop
    if (v_item->>'response') in ('fail', 'attention')
       and coalesce(v_item->>'note', '') = '' then
      raise exception 'Failed items require a note';
    end if;

    insert into inspection_responses(
      inspection_id, question_id, response, note, photo_path
    ) values (
      v_inspection,
      (v_item->>'question_id')::uuid,
      (v_item->>'response')::answer_status,
      nullif(v_item->>'note', ''),
      nullif(v_item->>'photo_path', '')
    ) returning id into v_response;

    if (v_item->>'response') in ('fail', 'attention') then
      select question into v_question
      from inspection_questions
      where id = (v_item->>'question_id')::uuid;

      insert into deficiencies(
        apparatus_id, inspection_id, response_id,
        title, description, severity, created_by
      ) values (
        p_apparatus_id, v_inspection, v_response,
        v_question, v_item->>'note',
        case when v_item->>'response' = 'fail' then 'high' else 'medium' end,
        auth.uid()
      );
    end if;
  end loop;

  -- Keep apparatus fuel current when the inspector records it
  if v_fuel is not null then
    update apparatus
    set fuel_level = v_fuel,
        updated_at = now()
    where id = p_apparatus_id;
  end if;

  insert into audit_log(actor_id, action, entity_type, entity_id, detail)
  values (
    auth.uid(), 'submit', 'inspection', v_inspection,
    jsonb_build_object('fuel_level', v_fuel)
  );

  return v_inspection;
end;
$$;

grant execute on function public.submit_inspection(uuid, uuid, text, text, jsonb, numeric)
  to authenticated;

notify pgrst, 'reload schema';
