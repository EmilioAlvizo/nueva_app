-- Private ordinary-exit reactivation only; never public restoration authority or animal CRUD.
-- Trusted caller obtains qualified FALSE prefix BEFORE public restore DML in the SAME TX.
-- This core independently obtains TRUE after replay; no supplied context is accepted.
create function economics_v2.reactivate_disposed_group_meat(
  p_granja_id uuid,p_operation_id uuid,p_animal_id uuid,p_effective_on date,
  p_destination_group_id uuid,p_destination_purpose_id uuid,p_disposed_event_id uuid,p_payload jsonb
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_actor uuid;
  v_envelope jsonb;
  v_prepared jsonb;
  v_context jsonb;
  v_result jsonb;
  v_reason jsonb;
  v_stored economics_v2.group_occupancy_operations%rowtype;
  v_old_operation economics_v2.group_occupancy_operations%rowtype;
  v_old_event economics_v2.group_occupancy_events%rowtype;
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_basis economics_v2.group_animal_acquisition_basis%rowtype;
  v_animal uuid;
  v_destination uuid;
  v_event uuid;
  v_member uuid;
  v_date date;
  v_position bigint;
  v_start bigint;
  v_version bigint;
  v_old_cost numeric;
begin
  v_actor:=economics_v2.assert_group_writer_actor(p_granja_id);
  if jsonb_typeof(p_payload) is distinct from 'object' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','payload',p_animal_id);
  end if;
  if p_disposed_event_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','disposed_event_id',null);
  end if;
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  -- Metadata remains nested data. Both this envelope and F2A bind the verified actor.
  v_envelope:=jsonb_build_object('provenance_version','group-reactivation-provenance.v1',
    'disposition_kind','ordinary_reactivation','disposed_event_id',p_disposed_event_id,
    'actor_id',v_actor,'metadata',p_payload);
  v_prepared:=economics_v2.prepare_group_operation(p_granja_id,p_operation_id,jsonb_build_object(
    'action','reactivate','animal_id',p_animal_id,'source_period_id',null,
    'destination_group_id',p_destination_group_id,'destination_purpose_id',p_destination_purpose_id,
    'sale_id',null,'effective_on',p_effective_on,'payload',v_envelope));

  if (v_prepared->>'replayed')::boolean then
    -- Hash conflict precedes history reads. Reconstruct ONLY original receipt/history,
    -- never the now-cleared basis pointer, current membership or latest destination dates.
    select * into v_stored from economics_v2.group_occupancy_operations
      where granja_id=p_granja_id and operation_id=p_operation_id;
    v_result:=v_stored.result;
    begin
      v_animal:=(v_result->>'animal_id')::uuid;
      v_destination:=(v_result->>'destination_period_id')::uuid;
      v_event:=(v_result->'membership_event_ids'->>0)::uuid;
      v_date:=(v_result->>'effective_on')::date;
      v_position:=(v_result->>'event_position')::bigint;
      v_start:=(v_result->>'destination_start_position')::bigint;
      v_version:=(v_result->>'state_version')::bigint;
    exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow or numeric_value_out_of_range then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end;
    if v_animal is null or v_animal is distinct from p_animal_id or v_destination is null or v_event is null
      or v_date is null or not isfinite(v_date) or v_position is null or v_position<=0
      or v_start is null or v_start<=0 or v_start>v_position or v_version is null or v_version<2
      or v_stored.event_position is distinct from v_position
      or v_result is distinct from jsonb_build_object('contract_version','group-economics.forward.v3',
        'operation_id',p_operation_id,'action','reactivate','animal_id',v_animal,'source_period_id',null,
        'destination_period_id',v_destination,'membership_event_ids',jsonb_build_array(v_event),'effective_on',v_date,
        'event_position',v_position,'source_end_position',null,'destination_start_position',v_start,
        'basis_entry_ids','[]'::jsonb,'basis_before',0,'basis_after',0,'source_status',null,
        'destination_status','open','snapshot_id',null,'state_version',v_version,'replayed',false) then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    select * into v_old_event from economics_v2.group_occupancy_events
      where granja_id=p_granja_id and id=p_disposed_event_id and animal_id=v_animal;
    if not found or v_old_event.action is distinct from 'exit' or v_old_event.sale_id is not null
      or v_old_event.basis_transfer_id is not null or v_old_event.operation_id is null
      or v_old_event.event_position>=v_position or not isfinite(v_old_event.effective_on)
      or v_old_event.effective_on>v_date then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    select * into v_old_operation from economics_v2.group_occupancy_operations
      where granja_id=p_granja_id and operation_id=v_old_event.operation_id;
    if not found then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    begin
      v_old_cost:=(v_old_operation.result->>'basis_before')::numeric;
      v_reason:=v_old_event.reason::jsonb;
    exception when invalid_text_representation or numeric_value_out_of_range then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end;
    if jsonb_typeof(v_reason) is distinct from 'object' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    if v_old_cost is null or v_old_cost<0 or v_old_cost in ('NaN','Infinity','-Infinity')
      or (select count(*) from jsonb_object_keys(v_reason))<>3
      or v_reason->'provenance_version' is distinct from '"group-disposition-provenance.v1"'::jsonb
      or v_reason->'disposition_kind' is distinct from '"ordinary_exit"'::jsonb
      or jsonb_typeof(v_reason->'metadata') is distinct from 'object'
      or v_old_event.reason is distinct from economics_v2.canonical_group_request(v_reason)::text
      or v_old_operation.event_position is distinct from v_old_event.event_position
      or v_old_operation.result is distinct from jsonb_build_object('contract_version','group-economics.forward.v3',
        'operation_id',v_old_event.operation_id,'action','exit','animal_id',v_animal,'source_period_id',v_old_event.period_id,
        'destination_period_id',null,'membership_event_ids',jsonb_build_array(v_old_event.id),
        'effective_on',v_old_event.effective_on,'event_position',v_old_event.event_position,
        'source_end_position',v_old_event.event_position,'destination_start_position',null,
        'basis_entry_ids','[]'::jsonb,'basis_before',v_old_cost,'basis_after',0,'source_status','open',
        'destination_status',null,'snapshot_id',null,'state_version',v_version-1,'replayed',false) then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    -- Historical spans may later end/close. Their original starts and linkage remain immutable.
    if not exists(select 1 from economics_v2.group_occupancy_events e
      join economics_v2.group_occupancy_memberships m on m.granja_id=e.granja_id and m.id=e.membership_id
      join economics_v2.group_occupancy_periods p on p.granja_id=e.granja_id and p.id=e.period_id
      join economics_v2.group_occupancy_memberships old_m
        on old_m.granja_id=v_old_event.granja_id and old_m.id=v_old_event.membership_id
      join economics_v2.group_occupancy_periods old_p
        on old_p.granja_id=v_old_event.granja_id and old_p.id=v_old_event.period_id
      where e.granja_id=p_granja_id and e.id=v_event and e.operation_id=p_operation_id
        and e.animal_id=v_animal and e.action='reactivate' and e.effective_on=v_date and e.event_position=v_position
        and e.sale_id is null and e.basis_transfer_id is null
        and e.reason=economics_v2.canonical_group_request(v_envelope)::text
        and m.animal_id=v_animal and m.period_id=v_destination and m.start_position=v_position
        and m.position_span<@p.position_span and p.id=v_destination and p.start_position=v_start
        and p.group_id=p_destination_group_id and p.purpose_id=p_destination_purpose_id
        and old_m.animal_id=v_animal and old_m.period_id=old_p.id and old_m.id<>m.id
        and old_m.end_position=v_old_event.event_position and old_m.start_position<old_m.end_position
        and old_m.position_span<@old_p.position_span) then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    return v_prepared->'result';
  end if;

  -- Fresh post-DML validation is computed HERE, never accepted from the caller.
  -- Qualified TRUE rereads history/public state and obtains the complete ordered prefix.
  v_context:=economics_v2.validate_disposed_group_meat_reactivation_source(p_granja_id,p_animal_id,
    p_disposed_event_id,p_effective_on,p_destination_group_id,p_destination_purpose_id,true);
  v_destination:=(v_context->>'destination_period_id')::uuid;
  if v_destination is not null then
    select * into v_period from economics_v2.group_occupancy_periods
      where granja_id=p_granja_id and id=v_destination;
    if not found then
      perform economics_v2.raise_group_writer_error('40001','stale_write','group_id',p_destination_group_id);
    end if;
  end if;

  -- Request/source validation precedes issuance; enforce the issued boundary before writes.
  -- Realized source C stays put; failed late writes never rewind this sequence.
  v_position:=nextval('economics_v2.group_economics_event_position_seq');
  if v_position<=(v_context->'disposition_event'->>'event_position')::bigint then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result,event_position)
    values(p_granja_id,p_operation_id,v_prepared->>'payload_hash','{}',v_position);
  if v_destination is null then
    insert into economics_v2.group_occupancy_periods(granja_id,group_id,purpose_id,starts_on,start_position)
      values(p_granja_id,p_destination_group_id,p_destination_purpose_id,p_effective_on,v_position)
      returning * into v_period;
  end if;
  insert into economics_v2.group_occupancy_memberships(granja_id,period_id,animal_id,start_position)
    values(p_granja_id,v_period.id,p_animal_id,v_position) returning id into v_member;
  insert into economics_v2.group_occupancy_events(granja_id,period_id,membership_id,animal_id,
    event_position,effective_on,action,operation_id,sale_id,basis_transfer_id,reason)
    values(p_granja_id,v_period.id,v_member,p_animal_id,v_position,p_effective_on,'reactivate',p_operation_id,
      null,null,economics_v2.canonical_group_request(v_envelope)::text) returning id into v_event;
  -- No acquisition entries/pair/holding and no recapture of original cost or timestamp.
  update economics_v2.group_animal_acquisition_basis set status='active',current_account_kind='period',
    current_period_id=v_period.id,remaining_basis=0,disposed_event_id=null,version=version+1
    where granja_id=p_granja_id and animal_id=p_animal_id returning * into v_basis;
  if not found then
    perform economics_v2.raise_group_writer_error('40001','stale_write','animal_id',p_animal_id);
  end if;
  v_result:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'action','reactivate','animal_id',p_animal_id,'source_period_id',null,'destination_period_id',v_period.id,
    'membership_event_ids',jsonb_build_array(v_event),'effective_on',p_effective_on,'event_position',v_position,
    'source_end_position',null,'destination_start_position',v_period.start_position,'basis_entry_ids','[]'::jsonb,
    'basis_before',0,'basis_after',0,'source_status',null,'destination_status','open','snapshot_id',null,
    'state_version',v_basis.version,'replayed',false);
  -- Completion LAST: every write and caller restore shares rollback on either late fault.
  update economics_v2.group_occupancy_operations set result=v_result
    where granja_id=p_granja_id and operation_id=p_operation_id;
  return v_result;
end;
$$;

revoke all on function economics_v2.reactivate_disposed_group_meat(uuid,uuid,uuid,date,uuid,uuid,uuid,jsonb)
  from public,anon,authenticated;
