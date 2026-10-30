-- Private FIRST RETURN after real ordinary exit/reactivation/ONE transfer/OUT; no public activation.
-- Trusted caller locks mutable scope before staging public meat pins in this SAME transaction.
-- Core owns locks and TRUE reread; it never accepts supplied context or impersonates a prior actor.
-- Original source is NULL. Provenance alone never adds historical periods to mutable scope.
create function economics_v2.return_reactivated_holding_to_group_meat(
  p_granja_id uuid,p_operation_id uuid,p_animal_id uuid,p_effective_on date,p_group_id uuid,p_purpose_id uuid,
  p_reactivation_operation_id uuid,p_transfer_operation_id uuid,p_out_operation_id uuid,p_payload jsonb
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_prepared jsonb;
  v_envelope jsonb;
  v_context jsonb;
  v_result jsonb;
  v_stored economics_v2.group_occupancy_operations%rowtype;
  v_animal public.animales%rowtype;
  v_destination economics_v2.group_occupancy_periods%rowtype;
  v_basis economics_v2.group_animal_acquisition_basis%rowtype;
  v_purpose public.cat_proposito_animal%rowtype;
  v_destination_id uuid;
  v_version bigint;
  v_out_position bigint;
  v_position bigint;
  v_membership uuid;
  v_pair uuid;
  v_event uuid;
  v_out_entry uuid;
  v_in_entry uuid;
begin
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  if jsonb_typeof(p_payload) is distinct from 'object' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','payload',p_animal_id);
  end if;
  -- Metadata stays nested data. F2A independently binds the current verified actor and original request.
  v_envelope:=jsonb_build_object('reactivation_operation_id',p_reactivation_operation_id,
    'transfer_operation_id',p_transfer_operation_id,'out_operation_id',p_out_operation_id,'metadata',p_payload);
  v_prepared:=economics_v2.prepare_group_operation(p_granja_id,p_operation_id,jsonb_build_object(
    'action','purpose_change','animal_id',p_animal_id,'source_period_id',null,
    'destination_group_id',p_group_id,'destination_purpose_id',p_purpose_id,
    'sale_id',null,'effective_on',p_effective_on,'payload',v_envelope));
  if p_reactivation_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','reactivation_operation_id',null);
  end if;
  if p_transfer_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','transfer_operation_id',null);
  end if;
  if p_out_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','out_operation_id',null);
  end if;

  if (v_prepared->>'replayed')::boolean then
    -- FALSE validates immutable provenance under CURRENT authorization, not current holding eligibility.
    -- No replay of old actor-bound OUT, no guessed old metadata and no destination chronology locks.
    v_context:=economics_v2.validate_reactivated_holding_history(p_granja_id,p_animal_id,
      p_reactivation_operation_id,p_transfer_operation_id,p_out_operation_id,p_effective_on,false);
    v_version:=(v_context->'out_result'->>'state_version')::bigint;
    v_out_position:=(v_context->'out_event'->>'event_position')::bigint;
    if v_version=9223372036854775807 then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    select * into v_stored from economics_v2.group_occupancy_operations
      where granja_id=p_granja_id and operation_id=p_operation_id;
    -- Rebuild exact19 from original event/member/period/zero legs, never mutable basis pointers.
    select jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
      'action','purpose_change','animal_id',p_animal_id,'source_period_id',null,'destination_period_id',p.id,
      'membership_event_ids',jsonb_build_array(e.id),'effective_on',p_effective_on,'event_position',e.event_position,
      'source_end_position',null,'destination_start_position',p.start_position,'basis_entry_ids',jsonb_build_array(b_out.id,b_in.id),
      'basis_before',0,'basis_after',0,'source_status',null,'destination_status','open','snapshot_id',null,
      'state_version',v_version+1,'replayed',false) into v_result
    from economics_v2.group_occupancy_events e
    join economics_v2.group_occupancy_memberships m on m.granja_id=e.granja_id and m.id=e.membership_id
    join economics_v2.group_occupancy_periods p on p.granja_id=m.granja_id and p.id=m.period_id
    join economics_v2.group_acquisition_basis_entries b_out on b_out.granja_id=e.granja_id and b_out.event_id=e.id
    join economics_v2.group_acquisition_basis_entries b_in on b_in.granja_id=e.granja_id and b_in.event_id=e.id
    where e.granja_id=p_granja_id and e.operation_id=p_operation_id and e.animal_id=p_animal_id
      and e.action='purpose_change' and e.sale_id is null and e.reason is null and e.effective_on=p_effective_on
      and e.event_position=v_stored.event_position and e.event_position>v_out_position
      and e.period_id=p.id and m.animal_id=p_animal_id and m.start_position=e.event_position and m.position_span<@p.position_span
      and p.group_id=p_group_id and p.purpose_id=p_purpose_id and p.start_position<=e.event_position
      and b_out.entry_kind='purpose_out' and b_out.account_kind='holding' and b_out.period_id is null
      and b_in.entry_kind='purpose_in' and b_in.account_kind='period' and b_in.period_id=p.id
      and b_out.operation_id=p_operation_id and b_in.operation_id=p_operation_id
      and b_out.animal_id=p_animal_id and b_in.animal_id=p_animal_id and b_out.signed_amount=0 and b_in.signed_amount=0
      and b_out.entry_pair_id=e.basis_transfer_id and b_in.entry_pair_id=e.basis_transfer_id;
    if v_result is null or v_stored.result is distinct from v_result
      or (select count(*) from economics_v2.group_occupancy_events where granja_id=p_granja_id and operation_id=p_operation_id)<>1
      or (select count(*) from economics_v2.group_acquisition_basis_entries where granja_id=p_granja_id and operation_id=p_operation_id)<>2 then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    return v_prepared->'result';
  end if;

  if p_group_id is null or p_purpose_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','destination',null);
  end if;
  -- Preparation already holds farm serialization. Discover complete mutable scope before ordered locks.
  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','animal_id',p_animal_id);
  end if;
  select id into v_destination_id from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and group_id=p_group_id and purpose_id=p_purpose_id and end_position is null;
  perform economics_v2.lock_group_writer_scope(p_granja_id,
    array(select g from unnest(array[p_group_id,v_animal.grupo_id]) g where g is not null),array[p_animal_id],
    case when v_destination_id is null then '{}'::uuid[] else array[v_destination_id] end,p_effective_on);
  -- Compute TRUE here after the core's own locks; pre-caller TRUE is neither a receipt nor authority.
  v_context:=economics_v2.validate_reactivated_holding_history(p_granja_id,p_animal_id,
    p_reactivation_operation_id,p_transfer_operation_id,p_out_operation_id,p_effective_on,true);
  v_version:=(v_context->'out_result'->>'state_version')::bigint;
  v_out_position:=(v_context->'out_event'->>'event_position')::bigint;
  if v_version=9223372036854775807 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  select * into v_basis from economics_v2.group_animal_acquisition_basis where granja_id=p_granja_id and animal_id=p_animal_id;
  select * into v_destination from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and group_id=p_group_id and purpose_id=p_purpose_id and end_position is null;
  if v_destination.id is distinct from v_destination_id then
    perform economics_v2.raise_group_writer_error('40001','stale_write','group_id',p_group_id);
  end if;
  if v_basis.version is distinct from v_version or v_basis.current_account_kind is distinct from 'holding'
    or v_basis.current_period_id is not null or v_basis.remaining_basis is distinct from 0 then
    perform economics_v2.raise_group_writer_error('40001','stale_write','animal_id',p_animal_id);
  end if;
  if v_animal.grupo_id is distinct from p_group_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',p_group_id);
  end if;
  if v_animal.proposito_id is distinct from p_purpose_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',p_purpose_id);
  end if;
  if not exists(select 1 from public.grupos where granja_id=p_granja_id and id=p_group_id and tipo_animal_id=v_animal.tipo_animal_id) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','group_id',p_group_id);
  end if;
  select * into v_purpose from public.cat_proposito_animal where granja_id=p_granja_id and id=p_purpose_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',p_purpose_id);
  end if;
  if v_purpose.codigo_calculo is distinct from 'carne' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','purpose_id',p_purpose_id);
  end if;
  if exists(select 1 from economics_v2.group_occupancy_periods p where p.granja_id=p_granja_id
    and p.group_id=p_group_id and p.purpose_id=p_purpose_id and (not isfinite(p.starts_on) or p.starts_on>p_effective_on
      or p.closed_on is not null and (not isfinite(p.closed_on) or p.closed_on>p_effective_on)
      or exists(select 1 from economics_v2.group_occupancy_events e where e.granja_id=p_granja_id
        and e.period_id=p.id and (not isfinite(e.effective_on) or e.effective_on>p_effective_on)))) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;
  if exists(select 1 from economics_v2.group_occupancy_periods p where p.granja_id=p_granja_id
    and p.group_id=p_group_id and p.purpose_id=p_purpose_id and ((p.end_position is null)<>(p.closed_on is null)
      or p.end_position is not null and not exists(select 1 from economics_v2.group_meat_snapshots s
        where s.granja_id=p_granja_id and s.period_id=p.id and s.snapshot_version='group-meat-snapshot.forward.v3'))) then
    perform economics_v2.raise_group_writer_error('23514','missing_closed_snapshot','group_id',p_group_id);
  end if;

  -- All request/state/destination refusals precede sequence issuance and operation reservation.
  v_position:=nextval('economics_v2.group_economics_event_position_seq');
  if v_position<=v_out_position or v_destination.id is not null and v_position<=v_destination.start_position then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
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
  -- Durable zero legs preserve accounting identity. No historical cost transfer or initial recapture.
  insert into economics_v2.group_acquisition_basis_entries(granja_id,animal_id,operation_id,event_id,
    entry_pair_id,entry_kind,account_kind,period_id,signed_amount)
    values(p_granja_id,p_animal_id,p_operation_id,v_event,v_pair,'purpose_out','holding',null,0) returning id into v_out_entry;
  insert into economics_v2.group_acquisition_basis_entries(granja_id,animal_id,operation_id,event_id,
    entry_pair_id,entry_kind,account_kind,period_id,signed_amount)
    values(p_granja_id,p_animal_id,p_operation_id,v_event,v_pair,'purpose_in','period',v_destination.id,0) returning id into v_in_entry;
  update economics_v2.group_animal_acquisition_basis set current_account_kind='period',current_period_id=v_destination.id,version=version+1
    where granja_id=p_granja_id and animal_id=p_animal_id returning * into v_basis;
  if not found then
    perform economics_v2.raise_group_writer_error('40001','stale_write','animal_id',p_animal_id);
  end if;
  v_result:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'action','purpose_change','animal_id',p_animal_id,'source_period_id',null,'destination_period_id',v_destination.id,
    'membership_event_ids',jsonb_build_array(v_event),'effective_on',p_effective_on,'event_position',v_position,
    'source_end_position',null,'destination_start_position',v_destination.start_position,'basis_entry_ids',jsonb_build_array(v_out_entry,v_in_entry),
    'basis_before',0,'basis_after',0,'source_status',null,'destination_status','open','snapshot_id',null,
    'state_version',v_basis.version,'replayed',false);
  -- Completion LAST: either late fault rolls back caller DML and all business rows, not nextval.
  update economics_v2.group_occupancy_operations set result=v_result where granja_id=p_granja_id and operation_id=p_operation_id;
  return v_result;
end;
$$;

revoke all on function economics_v2.return_reactivated_holding_to_group_meat(uuid,uuid,uuid,date,uuid,uuid,uuid,uuid,uuid,jsonb)
  from public,anon,authenticated;
