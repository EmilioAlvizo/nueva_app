-- Private purpose-change OUT for an already updated active animal. No CRUD, return or closure.
create function economics_v2.move_group_meat_to_holding_nonclosing(
  p_granja_id uuid,p_operation_id uuid,p_animal_id uuid,p_effective_on date,
  p_group_id uuid,p_purpose_id uuid,p_payload jsonb
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_stored jsonb;
  v_prepared jsonb;
  v_source_id uuid;
  v_animal public.animales%rowtype;
  v_group public.grupos%rowtype;
  v_purpose public.cat_proposito_animal%rowtype;
  v_source economics_v2.group_occupancy_periods%rowtype;
  v_member economics_v2.group_occupancy_memberships%rowtype;
  v_basis economics_v2.group_animal_acquisition_basis%rowtype;
  v_position bigint;
  v_pair uuid;
  v_event uuid;
  v_out_entry uuid;
  v_in_entry uuid;
  v_result jsonb;
begin
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  -- Recover the ORIGINAL source before replay: a successful OUT has no current meat membership.
  select result into v_stored from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=p_operation_id;
  if found then
    if jsonb_typeof(v_stored) is distinct from 'object' or not v_stored ?& array[
      'contract_version','operation_id','action','animal_id','source_period_id','destination_period_id',
      'membership_event_ids','effective_on','event_position','source_end_position','destination_start_position',
      'basis_entry_ids','basis_before','basis_after','source_status','destination_status','snapshot_id','state_version','replayed'] then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    v_source_id:=(v_stored->>'source_period_id')::uuid;
  else
    select period_id into v_source_id from economics_v2.group_occupancy_memberships
      where granja_id=p_granja_id and animal_id=p_animal_id and end_position is null;
  end if;
  v_prepared:=economics_v2.prepare_group_operation(p_granja_id,p_operation_id,jsonb_build_object(
    'action','purpose_change','animal_id',p_animal_id,'source_period_id',v_source_id,
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
  select * into v_source from economics_v2.group_occupancy_periods where granja_id=p_granja_id and id=v_source_id;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  perform economics_v2.lock_group_writer_scope(p_granja_id,
    array(select g from unnest(array[v_source.group_id,p_group_id,v_animal.grupo_id]) g where g is not null),
    array[p_animal_id],array[v_source.id],p_effective_on);
  -- Reread locked state. The mutable public cost is deliberately never used.
  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  select * into v_member from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and animal_id=p_animal_id and end_position is null;
  if v_member.period_id is distinct from v_source.id then
    perform economics_v2.raise_group_writer_error('40001','stale_write','animal_id',p_animal_id);
  end if;
  select * into v_group from public.grupos where granja_id=p_granja_id and id=p_group_id;
  if v_group.tipo_animal_id is distinct from v_animal.tipo_animal_id
    or not exists(select 1 from public.grupos where granja_id=p_granja_id and id=v_source.group_id
      and tipo_animal_id=v_animal.tipo_animal_id) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','group_id',p_group_id);
  end if;
  if not exists(select 1 from public.tipo_animal where granja_id=p_granja_id and id=v_animal.tipo_animal_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','tipo_animal_id',v_animal.tipo_animal_id);
  end if;
  select * into v_purpose from public.cat_proposito_animal where granja_id=p_granja_id and id=p_purpose_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',p_purpose_id);
  end if;
  if v_purpose.codigo_calculo is null or v_purpose.codigo_calculo not in ('postura','ornamental') then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','purpose_id',p_purpose_id);
  end if;
  if v_animal.proposito_id is distinct from p_purpose_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',p_purpose_id);
  end if;
  if v_animal.grupo_id is distinct from p_group_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',p_group_id);
  end if;
  select * into v_basis from economics_v2.group_animal_acquisition_basis where granja_id=p_granja_id and animal_id=p_animal_id;
  if not found or not v_animal.activo or v_animal.baja_id is not null
    or v_basis.status<>'active' or v_basis.current_account_kind<>'period' or v_basis.current_period_id is distinct from v_source.id
    or v_basis.remaining_basis<>v_basis.initial_basis or v_basis.initial_basis<>v_basis.source_cost or v_basis.disposed_event_id is not null
    or not exists(select 1 from public.cat_proposito_animal where granja_id=p_granja_id
      and id=v_source.purpose_id and codigo_calculo='carne') then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if (select count(*) from economics_v2.group_occupancy_memberships
      where granja_id=p_granja_id and period_id=v_source.id and end_position is null)<=1 then
    perform economics_v2.raise_group_writer_error('23514','period_close_unfinalized_facts','source_period_id',v_source.id);
  end if;

  -- All validation and missing-closure refusal precede sequence issuance and every business write.
  v_position:=nextval('economics_v2.group_economics_event_position_seq');
  v_pair:=gen_random_uuid();
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result,event_position)
    values(p_granja_id,p_operation_id,v_prepared->>'payload_hash','{}',v_position);
  update economics_v2.group_occupancy_memberships set end_position=v_position where id=v_member.id;
  insert into economics_v2.group_occupancy_events(granja_id,period_id,membership_id,animal_id,
    event_position,effective_on,action,operation_id,basis_transfer_id)
    values(p_granja_id,v_source.id,v_member.id,p_animal_id,v_position,p_effective_on,'purpose_change',p_operation_id,v_pair)
    returning id into v_event;
  insert into economics_v2.group_acquisition_basis_entries(granja_id,animal_id,operation_id,event_id,
    entry_pair_id,entry_kind,account_kind,period_id,signed_amount)
    values(p_granja_id,p_animal_id,p_operation_id,v_event,v_pair,'purpose_out','period',v_source.id,-v_basis.remaining_basis)
    returning id into v_out_entry;
  insert into economics_v2.group_acquisition_basis_entries(granja_id,animal_id,operation_id,event_id,
    entry_pair_id,entry_kind,account_kind,period_id,signed_amount)
    values(p_granja_id,p_animal_id,p_operation_id,v_event,v_pair,'purpose_in','holding',null,v_basis.remaining_basis)
    returning id into v_in_entry;
  update economics_v2.group_animal_acquisition_basis set current_account_kind='holding',current_period_id=null,version=version+1
    where granja_id=p_granja_id and animal_id=p_animal_id returning * into v_basis;
  v_result:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'action','purpose_change','animal_id',p_animal_id,'source_period_id',v_source.id,'destination_period_id',null,
    'membership_event_ids',jsonb_build_array(v_event),'effective_on',p_effective_on,'event_position',v_position,
    'source_end_position',v_position,'destination_start_position',null,'basis_entry_ids',jsonb_build_array(v_out_entry,v_in_entry),
    'basis_before',v_basis.remaining_basis,'basis_after',v_basis.remaining_basis,'source_status','open',
    'destination_status',null,'snapshot_id',null,'state_version',v_basis.version,'replayed',false);
  update economics_v2.group_occupancy_operations set result=v_result where granja_id=p_granja_id and operation_id=p_operation_id;
  return v_result;
end;
$$;

revoke all on function economics_v2.move_group_meat_to_holding_nonclosing(uuid,uuid,uuid,date,uuid,uuid,jsonb) from public,anon,authenticated;
