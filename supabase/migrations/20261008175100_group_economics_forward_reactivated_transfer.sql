-- Private first nonclosing transfer after ordinary reactivation; no animal CRUD or public activation.
-- The caller locks the complete mutable scope before public DML in this same transaction.
-- History identity is not authority. Current actor authorization and request hash remain independent.
create function economics_v2.transfer_reactivated_group_meat_nonclosing(
  p_granja_id uuid,p_operation_id uuid,p_animal_id uuid,p_effective_on date,
  p_group_id uuid,p_purpose_id uuid,p_reactivation_operation_id uuid,p_payload jsonb
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_stored economics_v2.group_occupancy_operations%rowtype;
  v_origin economics_v2.group_occupancy_operations%rowtype;
  v_exit_operation economics_v2.group_occupancy_operations%rowtype;
  v_activation economics_v2.group_occupancy_events%rowtype;
  v_exit economics_v2.group_occupancy_events%rowtype;
  v_member economics_v2.group_occupancy_memberships%rowtype;
  v_source economics_v2.group_occupancy_periods%rowtype;
  v_destination economics_v2.group_occupancy_periods%rowtype;
  v_basis economics_v2.group_animal_acquisition_basis%rowtype;
  v_animal public.animales%rowtype;
  v_prepared jsonb;
  v_envelope jsonb;
  v_reason jsonb;
  v_exit_reason jsonb;
  v_result jsonb;
  v_source_id uuid;
  v_destination_id uuid;
  v_history_actor uuid;
  v_version bigint;
  v_position bigint;
  v_pair uuid;
  v_new_member uuid;
  v_out_event uuid;
  v_in_event uuid;
  v_out_entry uuid;
  v_in_entry uuid;
begin
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  if p_reactivation_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','reactivation_operation_id',null);
  end if;
  if jsonb_typeof(p_payload) is distinct from 'object' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','payload',p_animal_id);
  end if;
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  select * into v_stored from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=p_operation_id;
  if found then
    begin
      v_source_id:=(v_stored.result->>'source_period_id')::uuid;
    exception when invalid_text_representation then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end;
  else
    select period_id into v_source_id from economics_v2.group_occupancy_memberships
      where granja_id=p_granja_id and animal_id=p_animal_id and end_position is null;
  end if;
  v_envelope:=jsonb_build_object('reactivation_operation_id',p_reactivation_operation_id,'metadata',p_payload);
  v_prepared:=economics_v2.prepare_group_operation(p_granja_id,p_operation_id,jsonb_build_object(
    'action','transfer','animal_id',p_animal_id,'source_period_id',v_source_id,
    'destination_group_id',p_group_id,'destination_purpose_id',p_purpose_id,
    'sale_id',null,'effective_on',p_effective_on,'payload',v_envelope));

  -- Replay never locks mutable periods or consults the animal's current destination/chronology.
  select * into v_source from economics_v2.group_occupancy_periods where granja_id=p_granja_id and id=v_source_id;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if not (v_prepared->>'replayed')::boolean then
    if p_group_id is null or p_purpose_id is null or p_group_id=v_source.group_id then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','destination',p_group_id);
    end if;
    select id into v_destination_id from economics_v2.group_occupancy_periods
      where granja_id=p_granja_id and group_id=p_group_id and purpose_id=p_purpose_id and end_position is null;
    perform economics_v2.lock_group_writer_scope(p_granja_id,array[v_source.group_id,p_group_id],array[p_animal_id],
      array[v_source_id]||case when v_destination_id is null then '{}'::uuid[] else array[v_destination_id] end,p_effective_on);
    select * into v_source from economics_v2.group_occupancy_periods where granja_id=p_granja_id and id=v_source_id;
  end if;

  -- Reread durable history after the fresh lock prefix; no caller context or receipt is trusted.
  select * into v_origin from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=p_reactivation_operation_id;
  select * into v_activation from economics_v2.group_occupancy_events
    where granja_id=p_granja_id and operation_id=p_reactivation_operation_id and animal_id=p_animal_id
      and action='reactivate' and v_origin.result->'membership_event_ids'=jsonb_build_array(id);
  if not found or v_activation.period_id is distinct from v_source_id then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  begin
    v_reason:=v_activation.reason::jsonb;
    v_history_actor:=(v_reason->>'actor_id')::uuid;
    v_version:=(v_origin.result->>'state_version')::bigint;
    select * into v_exit from economics_v2.group_occupancy_events
      where granja_id=p_granja_id and id=(v_reason->>'disposed_event_id')::uuid and animal_id=p_animal_id;
    v_exit_reason:=v_exit.reason::jsonb;
  exception when invalid_text_representation or numeric_value_out_of_range then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end;
  select * into v_basis from economics_v2.group_animal_acquisition_basis
    where granja_id=p_granja_id and animal_id=p_animal_id;
  if not found or v_basis.initial_basis is distinct from v_basis.source_cost
    or not isfinite(v_basis.captured_at) or v_version is null or v_version<2
    or v_history_actor is null or jsonb_typeof(v_reason->'metadata') is distinct from 'object'
    or v_reason is distinct from jsonb_build_object('provenance_version','group-reactivation-provenance.v1',
      'disposition_kind','ordinary_reactivation','disposed_event_id',v_exit.id,
      'actor_id',v_history_actor,'metadata',v_reason->'metadata')
    or v_activation.reason is distinct from economics_v2.canonical_group_request(v_reason)::text
    or v_activation.sale_id is not null or v_activation.basis_transfer_id is not null
    or not isfinite(v_activation.effective_on) or v_origin.event_position is distinct from v_activation.event_position
    or (select count(*) from economics_v2.group_occupancy_events where granja_id=p_granja_id and operation_id=p_reactivation_operation_id)<>1
    or v_origin.result is distinct from jsonb_build_object('contract_version','group-economics.forward.v3',
      'operation_id',p_reactivation_operation_id,'action','reactivate','animal_id',p_animal_id,'source_period_id',null,
      'destination_period_id',v_source_id,'membership_event_ids',jsonb_build_array(v_activation.id),
      'effective_on',v_activation.effective_on,'event_position',v_activation.event_position,'source_end_position',null,
      'destination_start_position',v_source.start_position,'basis_entry_ids','[]'::jsonb,'basis_before',0,'basis_after',0,
      'source_status',null,'destination_status','open','snapshot_id',null,'state_version',v_version,'replayed',false) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  -- Verify the original server-derived actor hash without impersonating or authorizing that actor.
  if v_origin.payload_hash is distinct from encode(sha256(convert_to(economics_v2.canonical_group_request(
    jsonb_build_object('contract_version','group-economics.forward.v3','granja_id',p_granja_id,
      'actor_id',v_history_actor,'operation_id',p_reactivation_operation_id,'request',jsonb_build_object(
        'action','reactivate','animal_id',p_animal_id,'source_period_id',null,'destination_group_id',v_source.group_id,
        'destination_purpose_id',v_source.purpose_id,'sale_id',null,'effective_on',v_activation.effective_on,
        'payload',v_reason)))::text,'UTF8')),'hex') then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_reactivation_operation_id);
  end if;
  select * into v_exit_operation from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=v_exit.operation_id;
  if v_exit.id is null or v_exit.action is distinct from 'exit' or v_exit.sale_id is not null
    or v_exit.basis_transfer_id is not null or not isfinite(v_exit.effective_on)
    or v_exit.event_position>=v_activation.event_position or v_exit.effective_on>v_activation.effective_on
    or jsonb_typeof(v_exit_reason->'metadata') is distinct from 'object'
    or v_exit_reason is distinct from jsonb_build_object('provenance_version','group-disposition-provenance.v1',
      'disposition_kind','ordinary_exit','metadata',v_exit_reason->'metadata')
    or v_exit.reason is distinct from economics_v2.canonical_group_request(v_exit_reason)::text
    or v_exit_operation.event_position is distinct from v_exit.event_position
    or (select count(*) from economics_v2.group_occupancy_events where granja_id=p_granja_id and operation_id=v_exit.operation_id)<>1
    or v_exit_operation.result is distinct from jsonb_build_object('contract_version','group-economics.forward.v3',
      'operation_id',v_exit.operation_id,'action','exit','animal_id',p_animal_id,'source_period_id',v_exit.period_id,
      'destination_period_id',null,'membership_event_ids',jsonb_build_array(v_exit.id),'effective_on',v_exit.effective_on,
      'event_position',v_exit.event_position,'source_end_position',v_exit.event_position,'destination_start_position',null,
      'basis_entry_ids','[]'::jsonb,'basis_before',v_basis.initial_basis,'basis_after',0,'source_status','open',
      'destination_status',null,'snapshot_id',null,'state_version',v_version-1,'replayed',false) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if not exists(select 1 from economics_v2.group_occupancy_memberships m
    join economics_v2.group_occupancy_memberships old_m on old_m.granja_id=m.granja_id and old_m.id=v_exit.membership_id
    join economics_v2.group_occupancy_periods old_p on old_p.granja_id=old_m.granja_id and old_p.id=old_m.period_id
    where m.granja_id=p_granja_id and m.id=v_activation.membership_id and m.animal_id=p_animal_id
      and m.period_id=v_source_id and m.start_position=v_activation.event_position and m.position_span<@v_source.position_span
      and old_m.animal_id=p_animal_id and old_m.id<>m.id and old_m.period_id=v_exit.period_id
      and old_m.end_position=v_exit.event_position and old_m.position_span<@old_p.position_span
      and isfinite(old_p.starts_on) and old_p.starts_on<=v_exit.effective_on)
    or (select sum(signed_amount) from economics_v2.group_acquisition_basis_entries
      where granja_id=p_granja_id and animal_id=p_animal_id and period_id=v_exit.period_id) is distinct from v_basis.initial_basis
    or (select count(*) from economics_v2.group_acquisition_basis_entries
      where granja_id=p_granja_id and animal_id=p_animal_id and entry_kind='initial')<>1
    or not exists(select 1 from economics_v2.group_acquisition_basis_entries b
      join economics_v2.group_occupancy_events e on e.granja_id=b.granja_id and e.id=b.event_id
      join economics_v2.group_occupancy_operations o on o.granja_id=b.granja_id and o.operation_id=b.operation_id
      where b.granja_id=p_granja_id and b.animal_id=p_animal_id and b.entry_kind='initial' and b.entry_pair_id is null
        and b.account_kind='period' and b.signed_amount=v_basis.initial_basis and b.created_at=v_basis.captured_at
        and e.action='enter' and e.animal_id=p_animal_id and e.period_id=b.period_id and e.operation_id=b.operation_id
        and e.event_position<v_exit.event_position and o.event_position=e.event_position
        and isfinite(e.effective_on) and e.effective_on<=v_exit.effective_on
        and o.result @> jsonb_build_object('contract_version','group-economics.forward.v3','action','enter',
          'animal_id',p_animal_id,'basis_after',v_basis.initial_basis,'basis_entry_ids',jsonb_build_array(b.id))) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;

  -- Historical closed source is read-only and still requires its qualified durable snapshot.
  if exists(select 1 from economics_v2.group_occupancy_periods p where p.granja_id=p_granja_id and p.id=v_exit.period_id
    and ((p.end_position is null)<>(p.closed_on is null) or p.closed_on<v_exit.effective_on
      or p.closed_on is not null and not isfinite(p.closed_on) or p.end_position<v_exit.event_position
      or p.end_position is not null and not exists(select 1 from economics_v2.group_meat_snapshots s
        where s.granja_id=p_granja_id and s.period_id=p.id and s.snapshot_version='group-meat-snapshot.forward.v3'))) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;

  if (v_prepared->>'replayed')::boolean then
    -- Rebuild the exact receipt from original legs, not present-day basis or destination chronology.
    select jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
      'action','transfer','animal_id',p_animal_id,'source_period_id',v_source_id,'destination_period_id',p.id,
      'membership_event_ids',jsonb_build_array(e_out.id,e_in.id),'effective_on',p_effective_on,
      'event_position',e_out.event_position,'source_end_position',e_out.event_position,'destination_start_position',p.start_position,
      'basis_entry_ids',jsonb_build_array(b_out.id,b_in.id),'basis_before',0,'basis_after',0,'source_status','open',
      'destination_status','open','snapshot_id',null,'state_version',v_version+1,'replayed',false) into v_result
    from economics_v2.group_occupancy_events e_out
    join economics_v2.group_occupancy_events e_in on e_in.granja_id=e_out.granja_id and e_in.operation_id=e_out.operation_id
    join economics_v2.group_acquisition_basis_entries b_out on b_out.granja_id=e_out.granja_id and b_out.event_id=e_out.id
    join economics_v2.group_acquisition_basis_entries b_in on b_in.granja_id=e_in.granja_id and b_in.event_id=e_in.id
    join economics_v2.group_occupancy_memberships m on m.granja_id=e_in.granja_id and m.id=e_in.membership_id
    join economics_v2.group_occupancy_periods p on p.granja_id=m.granja_id and p.id=m.period_id
    join economics_v2.group_occupancy_memberships old_m on old_m.granja_id=e_out.granja_id and old_m.id=e_out.membership_id
    where e_out.granja_id=p_granja_id and e_out.operation_id=p_operation_id and e_out.period_id=v_source_id
      and e_out.membership_id=v_activation.membership_id and e_out.animal_id=p_animal_id and e_in.animal_id=p_animal_id
      and e_out.action='transfer' and e_in.action='transfer' and e_out.sale_id is null and e_in.sale_id is null
      and e_out.event_position=e_in.event_position and e_out.event_position=v_stored.event_position
      and e_out.event_position>v_activation.event_position and e_out.effective_on=p_effective_on and e_in.effective_on=p_effective_on
      and e_out.basis_transfer_id=b_out.entry_pair_id and b_out.entry_pair_id=b_in.entry_pair_id
      and e_in.basis_transfer_id=b_in.entry_pair_id and b_out.entry_kind='transfer_out' and b_in.entry_kind='transfer_in'
      and b_out.operation_id=p_operation_id and b_in.operation_id=p_operation_id and b_out.animal_id=p_animal_id
      and b_in.animal_id=p_animal_id and b_out.signed_amount=0 and b_in.signed_amount=0
      and b_out.account_kind='period' and b_in.account_kind='period' and b_out.period_id=v_source_id and b_in.period_id=p.id
      and old_m.animal_id=p_animal_id and old_m.period_id=v_source_id and old_m.end_position=e_out.event_position
      and m.animal_id=p_animal_id and m.start_position=e_in.event_position and m.position_span<@p.position_span
      and p.group_id=p_group_id and p.purpose_id=p_purpose_id;
    if v_result is null or v_stored.result is distinct from v_result
      or (select count(*) from economics_v2.group_occupancy_events where granja_id=p_granja_id and operation_id=p_operation_id)<>2
      or (select count(*) from economics_v2.group_acquisition_basis_entries where granja_id=p_granja_id and operation_id=p_operation_id)<>2 then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    return v_prepared->'result';
  end if;

  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  select * into v_member from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and id=v_activation.membership_id for update;
  if v_member.end_position is not null or v_basis.current_period_id is distinct from v_source_id
    or v_basis.status is distinct from 'active' or v_basis.current_account_kind is distinct from 'period'
    or v_basis.remaining_basis is distinct from 0 or v_basis.disposed_event_id is not null
    or v_basis.version is distinct from v_version or v_animal.activo is distinct from true or v_animal.baja_id is not null
    or not isfinite(v_animal.fecha_adquisicion) or not isfinite(v_source.starts_on)
    or v_animal.fecha_adquisicion>v_activation.effective_on or v_source.starts_on>v_activation.effective_on
    or exists(select 1 from economics_v2.group_occupancy_events where granja_id=p_granja_id
      and animal_id=p_animal_id and event_position>v_activation.event_position)
    or (select count(*) from economics_v2.group_occupancy_events where granja_id=p_granja_id
      and animal_id=p_animal_id and action in('exit','delete','reactivate'))<>2
    or (select coalesce(sum(signed_amount),0) from economics_v2.group_acquisition_basis_entries
      where granja_id=p_granja_id and animal_id=p_animal_id and period_id=v_source_id)
      is distinct from (case when v_source_id=v_exit.period_id then v_basis.initial_basis else 0 end) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if v_animal.grupo_id is distinct from p_group_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',p_group_id);
  end if;
  if v_animal.proposito_id is distinct from p_purpose_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',p_purpose_id);
  end if;
  if not exists(select 1 from public.grupos where granja_id=p_granja_id and id=p_group_id
    and tipo_animal_id=v_animal.tipo_animal_id) or not exists(select 1 from public.grupos
    where granja_id=p_granja_id and id=v_source.group_id and tipo_animal_id=v_animal.tipo_animal_id) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','group_id',p_group_id);
  end if;
  if not exists(select 1 from public.tipo_animal where granja_id=p_granja_id and id=v_animal.tipo_animal_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','tipo_animal_id',v_animal.tipo_animal_id);
  end if;
  if (select count(*) from public.cat_proposito_animal where granja_id=p_granja_id
    and id=any(array[v_source.purpose_id,p_purpose_id]) and codigo_calculo='carne')
    <>(case when v_source.purpose_id=p_purpose_id then 1 else 2 end) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','purpose_id',p_purpose_id);
  end if;
  select * into v_destination from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and group_id=p_group_id and purpose_id=p_purpose_id and end_position is null;
  if v_destination.id is distinct from v_destination_id then
    perform economics_v2.raise_group_writer_error('40001','stale_write','group_id',p_group_id);
  end if;
  if exists(select 1 from economics_v2.group_occupancy_periods p where p.granja_id=p_granja_id
    and p.group_id=p_group_id and p.purpose_id=p_purpose_id and (not isfinite(p.starts_on) or p.starts_on>p_effective_on
      or p.closed_on is not null and (not isfinite(p.closed_on) or p.closed_on>p_effective_on)
      or exists(select 1 from economics_v2.group_occupancy_events e where e.granja_id=p_granja_id
        and e.period_id=p.id and (not isfinite(e.effective_on) or e.effective_on>p_effective_on)))) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;
  if exists(select 1 from economics_v2.group_occupancy_periods p where p.granja_id=p_granja_id
    and p.group_id=p_group_id and p.purpose_id=p_purpose_id and p.end_position is not null
    and not exists(select 1 from economics_v2.group_meat_snapshots s where s.granja_id=p_granja_id
      and s.period_id=p.id and s.snapshot_version='group-meat-snapshot.forward.v3')) then
    perform economics_v2.raise_group_writer_error('23514','missing_closed_snapshot','group_id',p_group_id);
  end if;
  if (select count(*) from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and period_id=v_source_id and end_position is null)<=1 then
    perform economics_v2.raise_group_writer_error('23514','period_close_unfinalized_facts','source_period_id',v_source_id);
  end if;

  -- Validation precedes issuance; close membership first for immediate half-open exclusion.
  v_position:=nextval('economics_v2.group_economics_event_position_seq');
  if v_position<=v_activation.event_position then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  v_pair:=gen_random_uuid();
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result,event_position)
    values(p_granja_id,p_operation_id,v_prepared->>'payload_hash','{}',v_position);
  if v_destination.id is null then
    insert into economics_v2.group_occupancy_periods(granja_id,group_id,purpose_id,starts_on,start_position)
      values(p_granja_id,p_group_id,p_purpose_id,p_effective_on,v_position) returning * into v_destination;
  end if;
  update economics_v2.group_occupancy_memberships set end_position=v_position where granja_id=p_granja_id and id=v_member.id;
  insert into economics_v2.group_occupancy_memberships(granja_id,period_id,animal_id,start_position)
    values(p_granja_id,v_destination.id,p_animal_id,v_position) returning id into v_new_member;
  insert into economics_v2.group_occupancy_events(granja_id,period_id,membership_id,animal_id,
    event_position,effective_on,action,operation_id,basis_transfer_id)
    values(p_granja_id,v_source_id,v_member.id,p_animal_id,v_position,p_effective_on,'transfer',p_operation_id,v_pair)
    returning id into v_out_event;
  insert into economics_v2.group_occupancy_events(granja_id,period_id,membership_id,animal_id,
    event_position,effective_on,action,operation_id,basis_transfer_id)
    values(p_granja_id,v_destination.id,v_new_member,p_animal_id,v_position,p_effective_on,'transfer',p_operation_id,v_pair)
    returning id into v_in_event;
  -- Retain zero legs and their pair identity. Never move realized historical cost or recapture.
  insert into economics_v2.group_acquisition_basis_entries(granja_id,animal_id,operation_id,event_id,
    entry_pair_id,entry_kind,account_kind,period_id,signed_amount)
    values(p_granja_id,p_animal_id,p_operation_id,v_out_event,v_pair,'transfer_out','period',v_source_id,0)
    returning id into v_out_entry;
  insert into economics_v2.group_acquisition_basis_entries(granja_id,animal_id,operation_id,event_id,
    entry_pair_id,entry_kind,account_kind,period_id,signed_amount)
    values(p_granja_id,p_animal_id,p_operation_id,v_in_event,v_pair,'transfer_in','period',v_destination.id,0)
    returning id into v_in_entry;
  update economics_v2.group_animal_acquisition_basis set current_period_id=v_destination.id,version=version+1
    where granja_id=p_granja_id and animal_id=p_animal_id returning * into v_basis;
  v_result:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'action','transfer','animal_id',p_animal_id,'source_period_id',v_source_id,'destination_period_id',v_destination.id,
    'membership_event_ids',jsonb_build_array(v_out_event,v_in_event),'effective_on',p_effective_on,'event_position',v_position,
    'source_end_position',v_position,'destination_start_position',v_destination.start_position,
    'basis_entry_ids',jsonb_build_array(v_out_entry,v_in_entry),'basis_before',0,'basis_after',0,
    'source_status','open','destination_status','open','snapshot_id',null,'state_version',v_basis.version,'replayed',false);
  -- Completion LAST; late failure also rolls back the trusted caller's public DML, not nextval.
  update economics_v2.group_occupancy_operations set result=v_result where granja_id=p_granja_id and operation_id=p_operation_id;
  return v_result;
end;
$$;

revoke all on function economics_v2.transfer_reactivated_group_meat_nonclosing(uuid,uuid,uuid,date,uuid,uuid,uuid,jsonb)
  from public,anon,authenticated;
