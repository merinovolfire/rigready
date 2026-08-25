-- Link deficiencies to the originating equipment inspection and replace the submit function.
alter table public.deficiencies add column if not exists equipment_inspection_id uuid references public.equipment_inspections;
create or replace function public.submit_equipment_inspection(p_equipment_id uuid,p_template_id uuid,p_signature_name text,p_notes text,p_responses jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare v_inspection uuid; v_item jsonb; v_question text; v_condition text:='good';
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 insert into equipment_inspections(equipment_id,template_id,inspector_id,signature_name,notes) values(p_equipment_id,p_template_id,auth.uid(),p_signature_name,p_notes) returning id into v_inspection;
 for v_item in select * from jsonb_array_elements(p_responses) loop
  if (v_item->>'response') in ('fail','attention') and coalesce(v_item->>'note','')='' then raise exception 'Failed items require a note'; end if;
  insert into equipment_inspection_responses(inspection_id,question_id,response,note) values(v_inspection,(v_item->>'question_id')::uuid,(v_item->>'response')::answer_status,nullif(v_item->>'note',''));
  if (v_item->>'response') in ('fail','attention') then
   select question into v_question from equipment_check_questions where id=(v_item->>'question_id')::uuid;
   insert into deficiencies(equipment_id,equipment_inspection_id,title,description,severity,status,created_by) values(p_equipment_id,v_inspection,v_question,v_item->>'note',case when v_item->>'response'='fail' then 'high' else 'medium' end,'open',auth.uid());
   v_condition:=case when v_item->>'response'='fail' then 'failed' else case when v_condition='failed' then 'failed' else 'attention' end end;
  end if;
 end loop;
 update equipment set condition=v_condition where id=p_equipment_id;
 insert into audit_log(actor_id,action,entity_type,entity_id,detail) values(auth.uid(),'submit','equipment_inspection',v_inspection,jsonb_build_object('equipment_id',p_equipment_id));
 return v_inspection;
end $$;
grant execute on function public.submit_equipment_inspection(uuid,uuid,text,text,jsonb) to authenticated;
notify pgrst,'reload schema';
