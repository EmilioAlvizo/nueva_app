-- Private initial entry only; authoritative callers and every exit/closure are deferred.
create function economics_v2.enter_group_meat_initial(
  p_granja_id uuid,p_operation_id uuid,p_animal_id uuid,p_effective_on date,
  p_group_id uuid,p_purpose_id uuid,p_payload jsonb
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_prepared jsonb;
  v_animal public.animales%rowtype;
  v_group public.grupos%rowtype;
  v_purpose public.cat_proposito_animal%rowtype;
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_position bigint;
  v_membership uuid;
  v_event uuid;
  v_entry uuid;
  v_cost numeric;
  v_result jsonb;
begin
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  if p_group_id is null or p_purpose_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','destination',null);
  end if;
  v_prepared:=economics_v2.prepare_group_operation(p_granja_id,p_operation_id,jsonb_build_object(
    'action','enter','animal_id',p_animal_id,'source_period_id',null,
    'destination_group_id',p_group_id,'destination_purpose_id',p_purpose_id,
    'sale_id',null,'effective_on',p_effective_on,'payload',p_payload));
  if (v_prepared->>'replayed')::boolean then return v_prepared->'result'; end if;

  -- The farm lock from preparation precedes scope discovery and the ordered row locks.
  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','animal_id',p_animal_id);
  end if;
  select * into v_period from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and group_id=p_group_id and purpose_id=p_purpose_id and end_position is null;
  perform economics_v2.lock_group_writer_scope(p_granja_id,array[p_group_id],array[p_animal_id],
    case when v_period.id is null then '{}'::uuid[] else array[v_period.id] end,p_effective_on);
  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  select * into v_group from public.grupos where granja_id=p_granja_id and id=p_group_id;
  if v_group.tipo_animal_id<>v_animal.tipo_animal_id then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','group_id',p_group_id);
  end if;
  if not exists(select 1 from public.tipo_animal where granja_id=p_granja_id and id=v_animal.tipo_animal_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','tipo_animal_id',v_animal.tipo_animal_id);
  end if;
  if v_animal.grupo_id is distinct from p_group_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',p_group_id);
  end if;
  select * into v_purpose from public.cat_proposito_animal where granja_id=p_granja_id and id=p_purpose_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',p_purpose_id);
  end if;
  if v_purpose.codigo_calculo is distinct from 'carne' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','purpose_id',p_purpose_id);
  end if;
  if v_animal.proposito_id is distinct from p_purpose_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',p_purpose_id);
  end if;
  if not v_animal.activo or v_animal.baja_id is not null
    or exists(select 1 from economics_v2.group_animal_acquisition_basis where granja_id=p_granja_id and animal_id=p_animal_id)
    or exists(select 1 from economics_v2.group_occupancy_memberships where granja_id=p_granja_id and animal_id=p_animal_id)
    or exists(select 1 from economics_v2.group_occupancy_events where granja_id=p_granja_id and animal_id=p_animal_id) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  v_cost:=v_animal.costo_adquisicion;
  if v_cost is null then
    perform economics_v2.raise_group_writer_error('23514','incomplete_acquisition_basis','costo_adquisicion',p_animal_id);
  end if;
  if v_cost<0 or v_cost in ('NaN','Infinity','-Infinity') then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','costo_adquisicion',p_animal_id);
  end if;
  if exists(select 1 from economics_v2.group_occupancy_periods t
    left join economics_v2.group_occupancy_events e on e.period_id=t.id and e.granja_id=t.granja_id
    where t.granja_id=p_granja_id and t.group_id=p_group_id and t.purpose_id=p_purpose_id
      and (t.starts_on>p_effective_on or t.closed_on>p_effective_on or e.effective_on>p_effective_on)) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;
  if exists(select 1 from economics_v2.group_occupancy_periods t
    where t.granja_id=p_granja_id and t.group_id=p_group_id and t.purpose_id=p_purpose_id
      and t.end_position is not null and not exists(select 1 from economics_v2.group_meat_snapshots s
        where s.granja_id=t.granja_id and s.period_id=t.id and s.snapshot_version='group-meat-snapshot.forward.v3')) then
    perform economics_v2.raise_group_writer_error('23514','missing_closed_snapshot','group_id',p_group_id);
  end if;

  -- All validation, including unknown acquisition cost, precedes position issuance and writes.
  v_position:=nextval('economics_v2.group_economics_event_position_seq');
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result,event_position)
    values(p_granja_id,p_operation_id,v_prepared->>'payload_hash','{}',v_position);
  if v_period.id is null then
    insert into economics_v2.group_occupancy_periods(granja_id,group_id,purpose_id,starts_on,start_position)
      values(p_granja_id,p_group_id,p_purpose_id,p_effective_on,v_position) returning * into v_period;
  end if;
  insert into economics_v2.group_occupancy_memberships(granja_id,period_id,animal_id,start_position)
    values(p_granja_id,v_period.id,p_animal_id,v_position) returning id into v_membership;
  insert into economics_v2.group_occupancy_events(granja_id,period_id,membership_id,animal_id,
    event_position,effective_on,action,operation_id)
    values(p_granja_id,v_period.id,v_membership,p_animal_id,v_position,p_effective_on,'enter',p_operation_id)
    returning id into v_event;
  insert into economics_v2.group_animal_acquisition_basis(granja_id,animal_id,initial_basis,remaining_basis,
    status,current_account_kind,current_period_id,source_cost)
    values(p_granja_id,p_animal_id,v_cost,v_cost,'active','period',v_period.id,v_cost);
  insert into economics_v2.group_acquisition_basis_entries(granja_id,animal_id,operation_id,event_id,
    entry_kind,account_kind,period_id,signed_amount)
    values(p_granja_id,p_animal_id,p_operation_id,v_event,'initial','period',v_period.id,v_cost) returning id into v_entry;
  v_result:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'action','enter','animal_id',p_animal_id,'source_period_id',null,'destination_period_id',v_period.id,
    'membership_event_ids',jsonb_build_array(v_event),'effective_on',p_effective_on,'event_position',v_position,
    'source_end_position',null,'destination_start_position',v_period.start_position,
    'basis_entry_ids',jsonb_build_array(v_entry),'basis_before',0,'basis_after',v_cost,
    'source_status',null,'destination_status','open','snapshot_id',null,'state_version',0,'replayed',false);
  update economics_v2.group_occupancy_operations set result=v_result
    where granja_id=p_granja_id and operation_id=p_operation_id;
  return v_result;
end;
$$;

revoke all on function economics_v2.enter_group_meat_initial(uuid,uuid,uuid,date,uuid,uuid,jsonb) from public,anon,authenticated;
