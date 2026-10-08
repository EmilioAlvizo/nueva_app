-- Private RETURN for an already updated active animal. No CRUD, recapture, disposition or closure.
create function economics_v2.move_holding_to_group_meat(
  p_granja_id uuid,p_operation_id uuid,p_animal_id uuid,p_effective_on date,
  p_group_id uuid,p_purpose_id uuid,p_payload jsonb
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_keys text[]:=array['contract_version','operation_id','action','animal_id','source_period_id','destination_period_id',
    'membership_event_ids','effective_on','event_position','source_end_position','destination_start_position',
    'basis_entry_ids','basis_before','basis_after','source_status','destination_status','snapshot_id','state_version','replayed'];
  v_stored jsonb;
  v_prepared jsonb;
  v_animal public.animales%rowtype;
  v_group public.grupos%rowtype;
  v_purpose public.cat_proposito_animal%rowtype;
  v_destination economics_v2.group_occupancy_periods%rowtype;
  v_basis economics_v2.group_animal_acquisition_basis%rowtype;
  v_out economics_v2.group_occupancy_events%rowtype;
  v_out_result jsonb;
  v_position bigint;
  v_membership uuid;
  v_pair uuid;
  v_event uuid;
  v_out_entry uuid;
  v_in_entry uuid;
  v_result jsonb;
begin
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  select result into v_stored from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=p_operation_id;
  if found then
    if jsonb_typeof(v_stored) is distinct from 'object' or not v_stored ?& v_keys then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
  end if;
  -- Original RETURN identity has no source period, even after a later movement creates one.
  v_prepared:=economics_v2.prepare_group_operation(p_granja_id,p_operation_id,jsonb_build_object(
    'action','purpose_change','animal_id',p_animal_id,'source_period_id',null,
    'destination_group_id',p_group_id,'destination_purpose_id',p_purpose_id,
    'sale_id',null,'effective_on',p_effective_on,'payload',p_payload));
  if (v_prepared->>'replayed')::boolean then return v_prepared->'result'; end if;
  if p_group_id is null or p_purpose_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','destination',null);
  end if;
  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','animal_id',p_animal_id);
  end if;
  select * into v_destination from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and group_id=p_group_id and purpose_id=p_purpose_id and end_position is null;
  -- Historical OUT provenance is read-only: NEVER pass that period to the mutable F2A scope.
  perform economics_v2.lock_group_writer_scope(p_granja_id,
    array(select g from unnest(array[p_group_id,v_animal.grupo_id]) g where g is not null),array[p_animal_id],
    case when v_destination.id is null then '{}'::uuid[] else array[v_destination.id] end,p_effective_on);
  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  select * into v_destination from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and group_id=p_group_id and purpose_id=p_purpose_id and end_position is null;
  select * into v_group from public.grupos where granja_id=p_granja_id and id=p_group_id;
  if v_group.tipo_animal_id is distinct from v_animal.tipo_animal_id then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','group_id',p_group_id);
  end if;
  if not exists(select 1 from public.tipo_animal where granja_id=p_granja_id and id=v_animal.tipo_animal_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','tipo_animal_id',v_animal.tipo_animal_id);
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
  if v_animal.grupo_id is distinct from p_group_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',p_group_id);
  end if;
  select * into v_basis from economics_v2.group_animal_acquisition_basis where granja_id=p_granja_id and animal_id=p_animal_id;
  if not found or not v_animal.activo or v_animal.baja_id is not null or v_basis.status<>'active'
    or v_basis.current_account_kind<>'holding' or v_basis.current_period_id is not null or v_basis.disposed_event_id is not null
    or v_basis.remaining_basis<>v_basis.initial_basis or v_basis.source_cost<>v_basis.initial_basis
    or exists(select 1 from economics_v2.group_occupancy_memberships where granja_id=p_granja_id and animal_id=p_animal_id and end_position is null) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;

  -- The latest real animal event must be the completed OUT that established the current holding state.
  select * into v_out from economics_v2.group_occupancy_events
    where granja_id=p_granja_id and animal_id=p_animal_id order by event_position desc limit 1;
  if not found or v_out.action<>'purpose_change' or v_out.basis_transfer_id is null
    or not exists(select 1 from economics_v2.group_occupancy_memberships m
      join economics_v2.group_occupancy_periods t on t.id=m.period_id and t.granja_id=m.granja_id
      join public.cat_proposito_animal q on q.id=t.purpose_id and q.granja_id=t.granja_id
      join public.grupos g on g.id=t.group_id and g.granja_id=t.granja_id
      where m.id=v_out.membership_id and m.granja_id=p_granja_id and m.animal_id=p_animal_id
        and m.period_id=v_out.period_id and m.end_position=v_out.event_position
        and q.codigo_calculo='carne' and g.tipo_animal_id=v_animal.tipo_animal_id) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select result into v_out_result from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=v_out.operation_id;
  if not found or jsonb_typeof(v_out_result) is distinct from 'object' or not v_out_result ?& v_keys
    or jsonb_typeof(v_out_result->'basis_entry_ids') is distinct from 'array'
    or not v_out_result @> jsonb_build_object('contract_version','group-economics.forward.v3','action','purpose_change',
      'operation_id',v_out.operation_id,'animal_id',p_animal_id,'source_period_id',v_out.period_id,'source_status','open',
      'destination_period_id',null,'destination_status',null,'destination_start_position',null,'snapshot_id',null,
      'source_end_position',v_out.event_position,'event_position',v_out.event_position,'effective_on',v_out.effective_on,
      'basis_before',v_basis.remaining_basis,'basis_after',v_basis.remaining_basis,'state_version',v_basis.version,
      'membership_event_ids',jsonb_build_array(v_out.id),'replayed',false) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if (select count(*)=2 and count(*) filter(where entry_kind='purpose_out' and account_kind='period')=1
      and count(*) filter(where entry_kind='purpose_in' and account_kind='holding')=1
      and bool_and(animal_id=p_animal_id and coalesce(event_id=v_out.id,false) and coalesce(entry_pair_id=v_out.basis_transfer_id,false)
        and ((entry_kind='purpose_out' and account_kind='period' and period_id=v_out.period_id and signed_amount=-v_basis.remaining_basis)
          or (entry_kind='purpose_in' and account_kind='holding' and period_id is null and signed_amount=v_basis.remaining_basis)))
      and (select array_agg(x order by x) from jsonb_array_elements_text(v_out_result->'basis_entry_ids') x)=array_agg(id::text order by id::text)
      from economics_v2.group_acquisition_basis_entries where granja_id=p_granja_id and operation_id=v_out.operation_id) is distinct from true
    or (select coalesce(sum(signed_amount),0) from economics_v2.group_acquisition_basis_entries
      where granja_id=p_granja_id and animal_id=p_animal_id and account_kind='holding')<>v_basis.remaining_basis then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
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

  -- Every refusal precedes sequence issuance and business writes. Initial entry is NOT called.
  v_position:=nextval('economics_v2.group_economics_event_position_seq');
  v_pair:=gen_random_uuid();
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result,event_position)
    values(p_granja_id,p_operation_id,v_prepared->>'payload_hash','{}',v_position);
  if v_destination.id is null then
    insert into economics_v2.group_occupancy_periods(granja_id,group_id,purpose_id,starts_on,start_position)
      values(p_granja_id,p_group_id,p_purpose_id,p_effective_on,v_position) returning * into v_destination;
  end if;
  insert into economics_v2.group_occupancy_memberships(granja_id,period_id,animal_id,start_position)
    values(p_granja_id,v_destination.id,p_animal_id,v_position) returning id into v_membership;
  insert into economics_v2.group_occupancy_events(granja_id,period_id,membership_id,animal_id,
    event_position,effective_on,action,operation_id,basis_transfer_id)
    values(p_granja_id,v_destination.id,v_membership,p_animal_id,v_position,p_effective_on,'purpose_change',p_operation_id,v_pair)
    returning id into v_event;
  insert into economics_v2.group_acquisition_basis_entries(granja_id,animal_id,operation_id,event_id,
    entry_pair_id,entry_kind,account_kind,period_id,signed_amount)
    values(p_granja_id,p_animal_id,p_operation_id,v_event,v_pair,'purpose_out','holding',null,-v_basis.remaining_basis)
    returning id into v_out_entry;
  insert into economics_v2.group_acquisition_basis_entries(granja_id,animal_id,operation_id,event_id,
    entry_pair_id,entry_kind,account_kind,period_id,signed_amount)
    values(p_granja_id,p_animal_id,p_operation_id,v_event,v_pair,'purpose_in','period',v_destination.id,v_basis.remaining_basis)
    returning id into v_in_entry;
  update economics_v2.group_animal_acquisition_basis set current_account_kind='period',current_period_id=v_destination.id,version=version+1
    where granja_id=p_granja_id and animal_id=p_animal_id returning * into v_basis;
  v_result:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'action','purpose_change','animal_id',p_animal_id,'source_period_id',null,'destination_period_id',v_destination.id,
    'membership_event_ids',jsonb_build_array(v_event),'effective_on',p_effective_on,'event_position',v_position,
    'source_end_position',null,'destination_start_position',v_destination.start_position,'basis_entry_ids',jsonb_build_array(v_out_entry,v_in_entry),
    'basis_before',v_basis.remaining_basis,'basis_after',v_basis.remaining_basis,'source_status',null,
    'destination_status','open','snapshot_id',null,'state_version',v_basis.version,'replayed',false);
  update economics_v2.group_occupancy_operations set result=v_result where granja_id=p_granja_id and operation_id=p_operation_id;
  return v_result;
end;
$$;

revoke all on function economics_v2.move_holding_to_group_meat(uuid,uuid,uuid,date,uuid,uuid,jsonb) from public,anon,authenticated;
