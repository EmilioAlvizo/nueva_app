-- Private read-only proof of initial capture -> ordinary exit -> reactivation -> ONE transfer -> OUT.
-- TRUE additionally proves current holding; FALSE never claims current mutation eligibility.
-- Context is server-read same-TX working data, not an authorization token or accepted input receipt.
-- Future RETURN independently prepares replay, locks mutable scope and calls TRUE after caller DML.
-- VOLATILE reflects advisory locking and volatile authorization dependencies, not row mutation.
-- Custom dependencies: assert_group_writer_actor/auth.uid, raise_group_writer_error, canonical_group_request.
-- No mutator, prepare_group_operation, row-update locks, dynamic SQL, DML, DDL or sequence calls.
create function economics_v2.validate_reactivated_holding_history(
  p_granja_id uuid,p_animal_id uuid,p_reactivation_operation_id uuid,p_transfer_operation_id uuid,
  p_out_operation_id uuid,p_effective_on date,p_require_current_holding boolean
) returns jsonb language plpgsql volatile security invoker set search_path='' as $$
declare
  v_actor uuid;
  v_origin economics_v2.group_occupancy_operations%rowtype;
  v_exit_operation economics_v2.group_occupancy_operations%rowtype;
  v_transfer economics_v2.group_occupancy_operations%rowtype;
  v_out_operation economics_v2.group_occupancy_operations%rowtype;
  v_activation economics_v2.group_occupancy_events%rowtype;
  v_exit economics_v2.group_occupancy_events%rowtype;
  v_transfer_in economics_v2.group_occupancy_events%rowtype;
  v_out economics_v2.group_occupancy_events%rowtype;
  v_source economics_v2.group_occupancy_periods%rowtype;
  v_reactivated economics_v2.group_occupancy_periods%rowtype;
  v_basis economics_v2.group_animal_acquisition_basis%rowtype;
  v_animal public.animales%rowtype;
  v_reason jsonb;
  v_exit_reason jsonb;
  v_result jsonb;
  v_history_actor uuid;
  v_version bigint;
begin
  v_actor:=economics_v2.assert_group_writer_actor(p_granja_id);
  if p_animal_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','animal_id',null);
  end if;
  if p_reactivation_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','reactivation_operation_id',null);
  end if;
  if p_transfer_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','transfer_operation_id',null);
  end if;
  if p_out_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','out_operation_id',null);
  end if;
  if p_require_current_holding is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','require_current_holding',p_animal_id);
  end if;
  if p_effective_on is null or not isfinite(p_effective_on) or p_effective_on>current_date then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;
  -- Cooperating writers serialize by farm. Historical periods are never mutable scope locks.
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  v_actor:=economics_v2.assert_group_writer_actor(p_granja_id);
  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','animal_id',p_animal_id);
  end if;
  select * into v_out_operation from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=p_out_operation_id;
  select * into v_out from economics_v2.group_occupancy_events
    where granja_id=p_granja_id and operation_id=p_out_operation_id and animal_id=p_animal_id
      and action='purpose_change' and v_out_operation.result->'membership_event_ids'=jsonb_build_array(id);
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select * into v_source from economics_v2.group_occupancy_periods where granja_id=p_granja_id and id=v_out.period_id;
  select * into v_origin from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=p_reactivation_operation_id;
  select * into v_activation from economics_v2.group_occupancy_events
    where granja_id=p_granja_id and operation_id=p_reactivation_operation_id and animal_id=p_animal_id
      and action='reactivate' and v_origin.result->'membership_event_ids'=jsonb_build_array(id);
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select * into v_reactivated from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and id=v_activation.period_id;
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
  -- Immutable capture/provenance checks apply in BOTH modes. Mutable basis fields are not used here.
  if not found or v_basis.initial_basis is distinct from v_basis.source_cost or not isfinite(v_basis.captured_at)
    or v_basis.initial_basis<0 or v_basis.initial_basis in('NaN','Infinity','-Infinity')
    or v_reactivated.id is null or v_source.id is null or v_version is null or v_version<2 or v_history_actor is null
    or v_version>9223372036854775805 or v_activation.event_position<=0
    or not isfinite(v_reactivated.starts_on) or v_reactivated.starts_on>v_activation.effective_on
    or jsonb_typeof(v_reason->'metadata') is distinct from 'object'
    or v_reason is distinct from jsonb_build_object('provenance_version','group-reactivation-provenance.v1',
      'disposition_kind','ordinary_reactivation','disposed_event_id',v_exit.id,'actor_id',v_history_actor,'metadata',v_reason->'metadata')
    or v_activation.reason is distinct from economics_v2.canonical_group_request(v_reason)::text
    or v_activation.sale_id is not null or v_activation.basis_transfer_id is not null or not isfinite(v_activation.effective_on)
    or v_origin.event_position is distinct from v_activation.event_position
    or (select count(*) from economics_v2.group_occupancy_events where granja_id=p_granja_id and operation_id=p_reactivation_operation_id)<>1
    or v_origin.result is distinct from jsonb_build_object('contract_version','group-economics.forward.v3',
      'operation_id',p_reactivation_operation_id,'action','reactivate','animal_id',p_animal_id,'source_period_id',null,
      'destination_period_id',v_reactivated.id,'membership_event_ids',jsonb_build_array(v_activation.id),
      'effective_on',v_activation.effective_on,'event_position',v_activation.event_position,'source_end_position',null,
      'destination_start_position',v_reactivated.start_position,'basis_entry_ids','[]'::jsonb,'basis_before',0,'basis_after',0,
      'source_status',null,'destination_status','open','snapshot_id',null,'state_version',v_version,'replayed',false) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  -- Derive the historical actor only from stored provenance. Never set a JWT or replay as that actor.
  if v_origin.payload_hash is distinct from encode(sha256(convert_to(economics_v2.canonical_group_request(
    jsonb_build_object('contract_version','group-economics.forward.v3','granja_id',p_granja_id,
      'actor_id',v_history_actor,'operation_id',p_reactivation_operation_id,'request',jsonb_build_object(
        'action','reactivate','animal_id',p_animal_id,'source_period_id',null,'destination_group_id',v_reactivated.group_id,
        'destination_purpose_id',v_reactivated.purpose_id,'sale_id',null,'effective_on',v_activation.effective_on,
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
      and m.period_id=v_reactivated.id and m.start_position=v_activation.event_position and m.position_span<@v_reactivated.position_span
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
      join economics_v2.group_occupancy_memberships m on m.granja_id=e.granja_id and m.id=e.membership_id
      join economics_v2.group_occupancy_periods p on p.granja_id=m.granja_id and p.id=m.period_id
      where b.granja_id=p_granja_id and b.animal_id=p_animal_id and b.entry_kind='initial' and b.entry_pair_id is null
        and b.account_kind='period' and b.signed_amount=v_basis.initial_basis and b.created_at=v_basis.captured_at
        and e.action='enter' and e.animal_id=p_animal_id and e.period_id=b.period_id and e.operation_id=b.operation_id
        and e.sale_id is null and e.basis_transfer_id is null and e.reason is null
        and e.event_position>0 and e.event_position<v_exit.event_position and o.event_position=e.event_position
        and (select count(*) from economics_v2.group_occupancy_events where granja_id=p_granja_id and operation_id=b.operation_id)=1
        and (select count(*) from economics_v2.group_acquisition_basis_entries where granja_id=p_granja_id and operation_id=b.operation_id)=1
        and m.animal_id=p_animal_id and m.period_id=b.period_id and m.start_position=e.event_position and m.position_span<@p.position_span
        and isfinite(e.effective_on) and e.effective_on<=v_exit.effective_on
        and o.result=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',b.operation_id,
          'action','enter','animal_id',p_animal_id,'source_period_id',null,'destination_period_id',p.id,
          'membership_event_ids',jsonb_build_array(e.id),'effective_on',e.effective_on,'event_position',e.event_position,
          'source_end_position',null,'destination_start_position',p.start_position,'basis_entry_ids',jsonb_build_array(b.id),
          'basis_before',0,'basis_after',v_basis.initial_basis,'source_status',null,'destination_status','open',
          'snapshot_id',null,'state_version',0,'replayed',false)) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if exists(select 1 from economics_v2.group_occupancy_periods p where p.granja_id=p_granja_id
    and p.id in(v_exit.period_id,v_reactivated.id,v_source.id) and ((p.end_position is null)<>(p.closed_on is null)
      or p.closed_on is not null and not isfinite(p.closed_on)
      or p.id=v_exit.period_id and (p.closed_on<v_exit.effective_on or p.end_position<v_exit.event_position)
      or p.end_position is not null and not exists(select 1 from economics_v2.group_meat_snapshots s
        where s.granja_id=p_granja_id and s.period_id=p.id and s.snapshot_version='group-meat-snapshot.forward.v3'))) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;

  -- Historical pins must still identify farm-contained meat periods in either mode.
  if exists(select 1 from economics_v2.group_occupancy_periods p
    left join public.cat_proposito_animal q on q.granja_id=p.granja_id and q.id=p.purpose_id
    where p.granja_id=p_granja_id and p.id in(v_exit.period_id,v_reactivated.id,v_source.id)
      and q.codigo_calculo is distinct from 'carne') then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;

  -- Transfer/OUT do not store their full requests or actors. Verify receipts/linked rows, not guessed hashes.
  select * into v_transfer from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=p_transfer_operation_id;
  select * into v_transfer_in from economics_v2.group_occupancy_events
    where granja_id=p_granja_id and operation_id=p_transfer_operation_id and animal_id=p_animal_id and period_id=v_source.id;
  select jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_transfer_operation_id,
    'action','transfer','animal_id',p_animal_id,'source_period_id',v_reactivated.id,'destination_period_id',v_source.id,
    'membership_event_ids',jsonb_build_array(e_out.id,e_in.id),'effective_on',e_in.effective_on,
    'event_position',e_in.event_position,'source_end_position',e_in.event_position,'destination_start_position',v_source.start_position,
    'basis_entry_ids',jsonb_build_array(b_out.id,b_in.id),'basis_before',0,'basis_after',0,'source_status','open',
    'destination_status','open','snapshot_id',null,'state_version',v_version+1,'replayed',false) into v_result
  from economics_v2.group_occupancy_events e_out join economics_v2.group_occupancy_events e_in
    on e_in.granja_id=e_out.granja_id and e_in.operation_id=e_out.operation_id
  join economics_v2.group_acquisition_basis_entries b_out on b_out.granja_id=e_out.granja_id and b_out.event_id=e_out.id
  join economics_v2.group_acquisition_basis_entries b_in on b_in.granja_id=e_in.granja_id and b_in.event_id=e_in.id
  join economics_v2.group_occupancy_memberships old_m on old_m.granja_id=e_out.granja_id and old_m.id=e_out.membership_id
  join economics_v2.group_occupancy_memberships m on m.granja_id=e_in.granja_id and m.id=e_in.membership_id
  where e_out.granja_id=p_granja_id and e_out.operation_id=p_transfer_operation_id
    and e_out.period_id=v_reactivated.id and e_out.membership_id=v_activation.membership_id and e_in.id=v_transfer_in.id
    and e_out.animal_id=p_animal_id and e_in.animal_id=p_animal_id and e_out.action='transfer' and e_in.action='transfer'
    and e_out.sale_id is null and e_in.sale_id is null and e_out.reason is null and e_in.reason is null
    and e_out.event_position=e_in.event_position and e_in.event_position=v_transfer.event_position
    and e_in.event_position>v_activation.event_position and isfinite(e_in.effective_on)
    and e_out.effective_on=e_in.effective_on and e_in.effective_on>=v_activation.effective_on
    and e_out.basis_transfer_id=b_out.entry_pair_id and b_out.entry_pair_id=b_in.entry_pair_id and e_in.basis_transfer_id=b_in.entry_pair_id
    and b_out.entry_kind='transfer_out' and b_in.entry_kind='transfer_in' and b_out.operation_id=p_transfer_operation_id
    and b_in.operation_id=p_transfer_operation_id and b_out.animal_id=p_animal_id and b_in.animal_id=p_animal_id
    and b_out.signed_amount=0 and b_in.signed_amount=0 and b_out.account_kind='period' and b_in.account_kind='period'
    and b_out.period_id=v_reactivated.id and b_in.period_id=v_source.id and m.period_id=v_source.id
    and old_m.animal_id=p_animal_id and old_m.period_id=v_reactivated.id and old_m.end_position=e_out.event_position
    and m.animal_id=p_animal_id and m.start_position=e_in.event_position and m.position_span<@v_source.position_span;
  if v_result is null or v_transfer.result is distinct from v_result or v_source.id=v_reactivated.id
    or v_source.group_id=v_reactivated.group_id or v_reactivated.closed_on<v_transfer_in.effective_on
    or v_reactivated.end_position<v_transfer_in.event_position
    or (select count(*) from economics_v2.group_occupancy_events where granja_id=p_granja_id and operation_id=p_transfer_operation_id)<>2
    or (select count(*) from economics_v2.group_acquisition_basis_entries where granja_id=p_granja_id and operation_id=p_transfer_operation_id)<>2 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_out_operation_id,
    'action','purpose_change','animal_id',p_animal_id,'source_period_id',v_source.id,'destination_period_id',null,
    'membership_event_ids',jsonb_build_array(v_out.id),'effective_on',v_out.effective_on,'event_position',v_out.event_position,
    'source_end_position',v_out.event_position,'destination_start_position',null,'basis_entry_ids',jsonb_build_array(b_out.id,b_in.id),
    'basis_before',0,'basis_after',0,'source_status','open','destination_status',null,'snapshot_id',null,
    'state_version',v_version+2,'replayed',false) into v_result
  from economics_v2.group_occupancy_memberships m
  join economics_v2.group_acquisition_basis_entries b_out on b_out.granja_id=m.granja_id and b_out.event_id=v_out.id
  join economics_v2.group_acquisition_basis_entries b_in on b_in.granja_id=m.granja_id and b_in.event_id=v_out.id
  where m.granja_id=p_granja_id and m.id=v_out.membership_id and v_out.membership_id=v_transfer_in.membership_id
    and v_out.sale_id is null and v_out.reason is null and v_out.event_position=v_out_operation.event_position
    and isfinite(v_out.effective_on) and v_out.event_position>v_transfer_in.event_position and v_out.effective_on>=v_transfer_in.effective_on
    and m.animal_id=p_animal_id and m.period_id=v_source.id and m.end_position=v_out.event_position and m.position_span<@v_source.position_span
    and b_out.entry_kind='purpose_out' and b_out.account_kind='period' and b_out.period_id=v_source.id
    and b_in.entry_kind='purpose_in' and b_in.account_kind='holding' and b_in.period_id is null
    and b_out.animal_id=p_animal_id and b_in.animal_id=p_animal_id and b_out.operation_id=p_out_operation_id and b_in.operation_id=p_out_operation_id
    and b_out.entry_pair_id=v_out.basis_transfer_id and b_in.entry_pair_id=v_out.basis_transfer_id and b_out.signed_amount=0 and b_in.signed_amount=0;
  if v_result is null or v_out_operation.result is distinct from v_result
    or v_source.closed_on<v_out.effective_on or v_source.end_position<v_out.event_position
    or not isfinite(v_source.starts_on) or v_source.starts_on>v_transfer_in.effective_on
    or (select count(*) from economics_v2.group_occupancy_events where granja_id=p_granja_id and operation_id=p_out_operation_id)<>1
    or (select count(*) from economics_v2.group_acquisition_basis_entries where granja_id=p_granja_id and operation_id=p_out_operation_id)<>2
    or (select count(*) from economics_v2.group_occupancy_events where granja_id=p_granja_id and animal_id=p_animal_id
      and event_position<=v_out.event_position and action in('exit','delete','reactivate'))<>2 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if v_out.effective_on>p_effective_on then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;

  -- No current membership, status, pointer, remaining amount, public purpose or version assumptions in FALSE.
  if p_require_current_holding then
    if v_basis.status is distinct from 'active' or v_basis.current_account_kind is distinct from 'holding'
      or v_basis.current_period_id is not null or v_basis.disposed_event_id is not null or v_basis.remaining_basis is distinct from 0
      or v_basis.version is distinct from v_version+2 or v_animal.activo is distinct from true or v_animal.baja_id is not null
      or not isfinite(v_animal.fecha_adquisicion) or v_animal.fecha_adquisicion>v_activation.effective_on
      or exists(select 1 from economics_v2.group_occupancy_memberships where granja_id=p_granja_id and animal_id=p_animal_id and end_position is null)
      or exists(select 1 from economics_v2.group_occupancy_events where granja_id=p_granja_id and animal_id=p_animal_id and event_position>v_out.event_position)
      or (select coalesce(sum(signed_amount),0) from economics_v2.group_acquisition_basis_entries
        where granja_id=p_granja_id and animal_id=p_animal_id and account_kind='holding')<>0 then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
    end if;
    if not exists(select 1 from public.tipo_animal where granja_id=p_granja_id and id=v_animal.tipo_animal_id) then
      perform economics_v2.raise_group_writer_error('42501','forbidden','tipo_animal_id',v_animal.tipo_animal_id);
    end if;
    if not exists(select 1 from public.grupos where granja_id=p_granja_id and id=v_animal.grupo_id) then
      perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_animal.grupo_id);
    end if;
    if not exists(select 1 from public.grupos where granja_id=p_granja_id and id=v_animal.grupo_id and tipo_animal_id=v_animal.tipo_animal_id)
      or exists(select 1 from economics_v2.group_occupancy_periods p join public.grupos g on g.granja_id=p.granja_id and g.id=p.group_id
        where p.granja_id=p_granja_id and p.id in(v_exit.period_id,v_reactivated.id,v_source.id) and g.tipo_animal_id<>v_animal.tipo_animal_id) then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','group_id',v_animal.grupo_id);
    end if;
    -- Purpose may already be valid meat staging; do not require the old OUT's non-meat purpose.
    if not exists(select 1 from public.cat_proposito_animal where granja_id=p_granja_id and id=v_animal.proposito_id) then
      perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',v_animal.proposito_id);
    end if;
    if not exists(select 1 from public.cat_proposito_animal where granja_id=p_granja_id and id=v_animal.proposito_id
      and codigo_calculo in('carne','postura','ornamental')) then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','purpose_id',v_animal.proposito_id);
    end if;
  end if;
  return jsonb_build_object('context_version','group-holding-history-context.v1','actor_id',v_actor,
    'granja_id',p_granja_id,'animal_id',p_animal_id,'effective_on',p_effective_on,
    'reactivation_operation_id',p_reactivation_operation_id,'transfer_operation_id',p_transfer_operation_id,
    'out_operation_id',p_out_operation_id,'require_current_holding',p_require_current_holding,
    'basis',to_jsonb(v_basis),'out_event',to_jsonb(v_out),'out_result',v_out_operation.result,
    'historical_period_id',v_source.id,'public_animal',to_jsonb(v_animal));
end;
$$;

revoke all on function economics_v2.validate_reactivated_holding_history(uuid,uuid,uuid,uuid,uuid,date,boolean)
  from public,anon,authenticated;
