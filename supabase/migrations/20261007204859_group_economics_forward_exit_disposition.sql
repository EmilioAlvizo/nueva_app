-- Private ordinary nonclosing exit only. No public animal CRUD, sale, baja or closure.
-- Trusted callers acquire the active source prefix BEFORE animal DML in the SAME transaction.
-- This post-DML core independently rereads inactive state; locks are not a validation token.
create function economics_v2.exit_group_meat_nonclosing(
  p_granja_id uuid,p_operation_id uuid,p_animal_id uuid,p_effective_on date,p_payload jsonb
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_stored economics_v2.group_occupancy_operations%rowtype;
  v_animal public.animales%rowtype;
  v_group public.grupos%rowtype;
  v_source economics_v2.group_occupancy_periods%rowtype;
  v_member economics_v2.group_occupancy_memberships%rowtype;
  v_basis economics_v2.group_animal_acquisition_basis%rowtype;
  v_prepared jsonb;
  v_result jsonb;
  v_source_id uuid;
  v_member_id uuid;
  v_event uuid;
  v_replay_animal uuid;
  v_date date;
  v_position bigint;
  v_version bigint;
  v_count bigint;
  v_member_on date;
  v_before numeric;
  v_net numeric;
begin
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  -- Provenance is durable data, never authority to select another disposition branch.
  if jsonb_typeof(p_payload) is distinct from 'object' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','payload',p_animal_id);
  end if;
  if (select count(*) from jsonb_object_keys(p_payload))<>3
    or p_payload->'provenance_version' is distinct from '"group-disposition-provenance.v1"'::jsonb
    or p_payload->'disposition_kind' is distinct from '"ordinary_exit"'::jsonb
    or jsonb_typeof(p_payload->'metadata') is distinct from 'object' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','payload',p_animal_id);
  end if;
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  select * into v_stored from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=p_operation_id;
  if found then
    -- Reconstruct ORIGINAL source and typed receipt, not current membership/basis state.
    v_result:=v_stored.result;
    begin
      v_source_id:=(v_result->>'source_period_id')::uuid;
      v_replay_animal:=(v_result->>'animal_id')::uuid;
      v_event:=(v_result->'membership_event_ids'->>0)::uuid;
      v_date:=(v_result->>'effective_on')::date;
      v_position:=(v_result->>'event_position')::bigint;
      v_version:=(v_result->>'state_version')::bigint;
      v_before:=(v_result->>'basis_before')::numeric;
    exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow or numeric_value_out_of_range then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end;
    if v_source_id is null or v_replay_animal is null or v_event is null or v_date is null
      or not isfinite(v_date) or v_position is null or v_position<=0 or v_version is null or v_version<=0
      or v_before is null or v_before<0 or v_before in ('NaN','Infinity','-Infinity')
      or v_stored.event_position is distinct from v_position
      or v_result is distinct from jsonb_build_object('contract_version','group-economics.forward.v3',
        'operation_id',p_operation_id,'action','exit','animal_id',v_replay_animal,'source_period_id',v_source_id,
        'destination_period_id',null,'membership_event_ids',jsonb_build_array(v_event),'effective_on',v_date,
        'event_position',v_position,'source_end_position',v_position,'destination_start_position',null,
        'basis_entry_ids','[]'::jsonb,'basis_before',v_before,'basis_after',0,'source_status','open',
        'destination_status',null,'snapshot_id',null,'state_version',v_version,'replayed',false) then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
  else
    select period_id into v_source_id from economics_v2.group_occupancy_memberships
      where granja_id=p_granja_id and animal_id=p_animal_id and end_position is null;
  end if;
  v_prepared:=economics_v2.prepare_group_operation(p_granja_id,p_operation_id,jsonb_build_object(
    'action','exit','animal_id',p_animal_id,'source_period_id',v_source_id,
    'destination_group_id',null,'destination_purpose_id',null,'sale_id',null,
    'effective_on',p_effective_on,'payload',p_payload));
  if (v_prepared->>'replayed')::boolean then
    if not exists(select 1 from economics_v2.group_occupancy_events e
      join economics_v2.group_occupancy_memberships m on m.id=e.membership_id and m.granja_id=e.granja_id
      join economics_v2.group_occupancy_periods s on s.id=e.period_id and s.granja_id=e.granja_id
      where e.granja_id=p_granja_id and e.id=v_event and e.operation_id=p_operation_id
        and e.animal_id=v_replay_animal and m.animal_id=v_replay_animal and m.period_id=v_source_id
        and e.period_id=v_source_id and e.event_position=v_position and m.end_position=v_position
        and e.effective_on=v_date and e.action='exit' and e.sale_id is null and e.basis_transfer_id is null
        and e.reason=economics_v2.canonical_group_request(p_payload)::text) then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    return v_prepared->'result';
  end if;

  -- Discovery under farm serialization precedes the complete ordered F2A row prefix.
  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','animal_id',p_animal_id);
  end if;
  select count(*) into v_count from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and animal_id=p_animal_id and end_position is null;
  if v_count<>1 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select * into v_member from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and animal_id=p_animal_id and end_position is null;
  v_member_id:=v_member.id;
  select * into v_source from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and id=v_source_id;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if v_animal.grupo_id is null then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',null);
  end if;
  perform economics_v2.lock_group_writer_scope(p_granja_id,array[v_source.group_id,v_animal.grupo_id],
    array[p_animal_id],array[v_source_id],p_effective_on);

  -- Reread POST-DML authoritative state. Never invoke the active-only source validator here.
  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','animal_id',p_animal_id);
  end if;
  select count(*) into v_count from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and animal_id=p_animal_id and end_position is null;
  if v_count<>1 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select * into v_member from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and animal_id=p_animal_id and end_position is null for update;
  select * into v_source from economics_v2.group_occupancy_periods where granja_id=p_granja_id and id=v_source_id;
  if not found or v_member.id is distinct from v_member_id or v_member.period_id is distinct from v_source_id
    or v_member.granja_id is distinct from v_source.granja_id or not(v_member.position_span<@v_source.position_span) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if v_source.end_position is not null or v_source.closed_on is not null then
    perform economics_v2.raise_group_writer_error('23514','closed_period_immutable','period_id',v_source_id);
  end if;
  if v_animal.grupo_id is distinct from v_source.group_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_animal.grupo_id);
  end if;
  select * into v_group from public.grupos where granja_id=p_granja_id and id=v_source.group_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_source.group_id);
  end if;
  if v_group.tipo_animal_id is distinct from v_animal.tipo_animal_id then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','group_id',v_source.group_id);
  end if;
  if not exists(select 1 from public.tipo_animal where granja_id=p_granja_id and id=v_animal.tipo_animal_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','tipo_animal_id',v_animal.tipo_animal_id);
  end if;
  if not exists(select 1 from public.cat_proposito_animal where granja_id=p_granja_id and id=v_source.purpose_id)
    or not exists(select 1 from public.cat_proposito_animal where granja_id=p_granja_id and id=v_animal.proposito_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',v_animal.proposito_id);
  end if;
  if exists(select 1 from public.cat_proposito_animal where granja_id=p_granja_id
    and id in(v_source.purpose_id,v_animal.proposito_id) and codigo_calculo is distinct from 'carne') then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','purpose_id',v_source.purpose_id);
  end if;
  if v_animal.proposito_id is distinct from v_source.purpose_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',v_animal.proposito_id);
  end if;
  if v_animal.activo is distinct from false or v_animal.baja_id is not null then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;

  -- Captured source cost, not mutable public cost, supplies the disposition basis.
  select * into v_basis from economics_v2.group_animal_acquisition_basis
    where granja_id=p_granja_id and animal_id=p_animal_id;
  if not found or v_basis.status is distinct from 'active' or v_basis.current_account_kind is distinct from 'period'
    or v_basis.current_period_id is distinct from v_source_id or v_basis.disposed_event_id is not null
    or v_basis.initial_basis is null or v_basis.source_cost is null or v_basis.remaining_basis is null
    or v_basis.initial_basis<0 or v_basis.source_cost<0 or v_basis.remaining_basis<0
    or v_basis.initial_basis in ('NaN','Infinity','-Infinity') or v_basis.source_cost in ('NaN','Infinity','-Infinity')
    or v_basis.remaining_basis in ('NaN','Infinity','-Infinity') or v_basis.initial_basis is distinct from v_basis.source_cost
    or v_basis.remaining_basis is distinct from v_basis.initial_basis
    or exists(select 1 from economics_v2.group_occupancy_events where granja_id=p_granja_id
      and animal_id=p_animal_id and action in('exit','delete','reactivate')) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select sum(signed_amount) into v_net from economics_v2.group_acquisition_basis_entries
    where granja_id=p_granja_id and animal_id=p_animal_id and account_kind='period' and period_id=v_source_id;
  if v_net is distinct from v_basis.remaining_basis then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select count(*),min(effective_on) into v_count,v_member_on from economics_v2.group_occupancy_events
    where granja_id=p_granja_id and animal_id=p_animal_id and period_id=v_source_id
      and membership_id=v_member.id and event_position=v_member.start_position and action in('enter','transfer','purpose_change');
  if v_count<>1 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if v_animal.fecha_adquisicion is null or v_source.starts_on is null or v_member_on is null
    or not isfinite(v_animal.fecha_adquisicion) or not isfinite(v_source.starts_on) or not isfinite(v_member_on)
    or v_animal.fecha_adquisicion>p_effective_on or v_source.starts_on>p_effective_on or v_member_on>p_effective_on
    or exists(select 1 from economics_v2.group_occupancy_events where granja_id=p_granja_id
      and (animal_id=p_animal_id or period_id=v_source_id) and (not isfinite(effective_on) or effective_on>p_effective_on)) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;
  select count(*) into v_count from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and period_id=v_source_id and end_position is null;
  if v_count<=1 then
    perform economics_v2.raise_group_writer_error('23514','period_close_unfinalized_facts','source_period_id',v_source_id);
  end if;

  -- Every refusal precedes nextval/reservation. Source realized cost stays in its signed entries.
  v_before:=v_basis.remaining_basis;
  v_position:=nextval('economics_v2.group_economics_event_position_seq');
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result,event_position)
    values(p_granja_id,p_operation_id,v_prepared->>'payload_hash','{}',v_position);
  update economics_v2.group_occupancy_memberships set end_position=v_position where id=v_member.id;
  insert into economics_v2.group_occupancy_events(granja_id,period_id,membership_id,animal_id,
    event_position,effective_on,action,operation_id,sale_id,basis_transfer_id,reason)
    values(p_granja_id,v_source_id,v_member.id,p_animal_id,v_position,p_effective_on,'exit',p_operation_id,
      null,null,economics_v2.canonical_group_request(p_payload)::text) returning id into v_event;
  update economics_v2.group_animal_acquisition_basis set remaining_basis=0,status='disposed',
    current_account_kind='disposed',current_period_id=null,disposed_event_id=v_event,version=version+1
    where granja_id=p_granja_id and animal_id=p_animal_id returning * into v_basis;
  v_result:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'action','exit','animal_id',p_animal_id,'source_period_id',v_source_id,'destination_period_id',null,
    'membership_event_ids',jsonb_build_array(v_event),'effective_on',p_effective_on,'event_position',v_position,
    'source_end_position',v_position,'destination_start_position',null,'basis_entry_ids','[]'::jsonb,
    'basis_before',v_before,'basis_after',0,'source_status','open','destination_status',null,
    'snapshot_id',null,'state_version',v_basis.version,'replayed',false);
  -- Completion is LAST; caller animal DML and every economics write share failure rollback.
  update economics_v2.group_occupancy_operations set result=v_result
    where granja_id=p_granja_id and operation_id=p_operation_id;
  return v_result;
end;
$$;

revoke all on function economics_v2.exit_group_meat_nonclosing(uuid,uuid,uuid,date,jsonb) from public,anon,authenticated;
