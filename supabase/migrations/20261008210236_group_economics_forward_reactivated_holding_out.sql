-- Private OUT after ordinary reactivation and exactly one qualified zero-basis transfer.
-- Trusted callers lock the full mutable scope before public DML in this same transaction.
-- No public activation, animal CRUD, direct reactivation OUT, repeated movement or RETURN.
create function economics_v2.move_transferred_reactivated_meat_to_holding_nonclosing(
  p_granja_id uuid,p_operation_id uuid,p_animal_id uuid,p_effective_on date,p_group_id uuid,p_purpose_id uuid,
  p_reactivation_operation_id uuid,p_transfer_operation_id uuid,p_payload jsonb
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_stored economics_v2.group_occupancy_operations%rowtype;
  v_origin economics_v2.group_occupancy_operations%rowtype;
  v_exit_operation economics_v2.group_occupancy_operations%rowtype;
  v_transfer economics_v2.group_occupancy_operations%rowtype;
  v_activation economics_v2.group_occupancy_events%rowtype;
  v_exit economics_v2.group_occupancy_events%rowtype;
  v_transfer_in economics_v2.group_occupancy_events%rowtype;
  v_source economics_v2.group_occupancy_periods%rowtype;
  v_reactivated economics_v2.group_occupancy_periods%rowtype;
  v_member economics_v2.group_occupancy_memberships%rowtype;
  v_basis economics_v2.group_animal_acquisition_basis%rowtype;
  v_animal public.animales%rowtype;
  v_purpose public.cat_proposito_animal%rowtype;
  v_prepared jsonb;
  v_envelope jsonb;
  v_reason jsonb;
  v_exit_reason jsonb;
  v_result jsonb;
  v_source_id uuid;
  v_history_actor uuid;
  v_version bigint;
  v_position bigint;
  v_pair uuid;
  v_event uuid;
  v_out_entry uuid;
  v_in_entry uuid;
begin
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  if p_reactivation_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','reactivation_operation_id',null);
  end if;
  if p_transfer_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','transfer_operation_id',null);
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
  -- Both IDs are nested history identity, never authorization. F2A hashes the current verified actor.
  v_envelope:=jsonb_build_object('reactivation_operation_id',p_reactivation_operation_id,
    'transfer_operation_id',p_transfer_operation_id,'metadata',p_payload);
  v_prepared:=economics_v2.prepare_group_operation(p_granja_id,p_operation_id,jsonb_build_object(
    'action','purpose_change','animal_id',p_animal_id,'source_period_id',v_source_id,
    'destination_group_id',p_group_id,'destination_purpose_id',p_purpose_id,
    'sale_id',null,'effective_on',p_effective_on,'payload',v_envelope));
  select * into v_source from economics_v2.group_occupancy_periods where granja_id=p_granja_id and id=v_source_id;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if not (v_prepared->>'replayed')::boolean then
    if p_group_id is null or p_purpose_id is null then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','destination',null);
    end if;
    select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
    perform economics_v2.lock_group_writer_scope(p_granja_id,
      array(select g from unnest(array[v_source.group_id,p_group_id,v_animal.grupo_id]) g where g is not null),
      array[p_animal_id],array[v_source_id],p_effective_on);
    select * into v_source from economics_v2.group_occupancy_periods where granja_id=p_granja_id and id=v_source_id;
  end if;

  -- Independently reread durable capture/exit/reactivation, including the original server actor hash.
  -- Historical periods are read-only, never part of mutable period locks or impersonated replay.
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
  if not found or v_basis.initial_basis is distinct from v_basis.source_cost or not isfinite(v_basis.captured_at)
    or v_reactivated.id is null or v_version is null or v_version<2 or v_history_actor is null
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
      where b.granja_id=p_granja_id and b.animal_id=p_animal_id and b.entry_kind='initial' and b.entry_pair_id is null
        and b.account_kind='period' and b.signed_amount=v_basis.initial_basis and b.created_at=v_basis.captured_at
        and e.action='enter' and e.animal_id=p_animal_id and e.period_id=b.period_id and e.operation_id=b.operation_id
        and e.event_position<v_exit.event_position and o.event_position=e.event_position
        and isfinite(e.effective_on) and e.effective_on<=v_exit.effective_on
        and o.result @> jsonb_build_object('contract_version','group-economics.forward.v3','action','enter',
          'animal_id',p_animal_id,'basis_after',v_basis.initial_basis,'basis_entry_ids',jsonb_build_array(b.id))) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if exists(select 1 from economics_v2.group_occupancy_periods p where p.granja_id=p_granja_id
    and p.id in(v_exit.period_id,v_reactivated.id) and ((p.end_position is null)<>(p.closed_on is null)
      or p.closed_on is not null and not isfinite(p.closed_on)
      or p.id=v_exit.period_id and (p.closed_on<v_exit.effective_on or p.end_position<v_exit.event_position)
      or p.end_position is not null and not exists(select 1 from economics_v2.group_meat_snapshots s
        where s.granja_id=p_granja_id and s.period_id=p.id and s.snapshot_version='group-meat-snapshot.forward.v3'))) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;

  -- Transfer has no stored request/actor envelope. Verify its exact server ledger and linked legs,
  -- never guess its actor/metadata, impersonate its replay, or use its hash as an authorization token.
  select * into v_transfer from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=p_transfer_operation_id;
  select * into v_transfer_in from economics_v2.group_occupancy_events
    where granja_id=p_granja_id and operation_id=p_transfer_operation_id and animal_id=p_animal_id and period_id=v_source_id;
  select jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_transfer_operation_id,
    'action','transfer','animal_id',p_animal_id,'source_period_id',v_reactivated.id,'destination_period_id',v_source_id,
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
    and e_out.event_position=e_in.event_position
    and e_in.event_position=v_transfer.event_position and e_in.event_position>v_activation.event_position
    and isfinite(e_in.effective_on) and e_out.effective_on=e_in.effective_on and e_in.effective_on>=v_activation.effective_on
    and e_out.basis_transfer_id=b_out.entry_pair_id and b_out.entry_pair_id=b_in.entry_pair_id and e_in.basis_transfer_id=b_in.entry_pair_id
    and b_out.entry_kind='transfer_out' and b_in.entry_kind='transfer_in' and b_out.operation_id=p_transfer_operation_id
    and b_in.operation_id=p_transfer_operation_id and b_out.animal_id=p_animal_id and b_in.animal_id=p_animal_id
    and b_out.signed_amount=0 and b_in.signed_amount=0 and b_out.account_kind='period' and b_in.account_kind='period'
    and b_out.period_id=v_reactivated.id and b_in.period_id=v_source_id and m.period_id=v_source_id
    and old_m.animal_id=p_animal_id and old_m.period_id=v_reactivated.id and old_m.end_position=e_out.event_position
    and m.animal_id=p_animal_id and m.start_position=e_in.event_position and m.position_span<@v_source.position_span;
  if v_result is null or v_transfer.result is distinct from v_result or v_source_id=v_reactivated.id
    or v_source.group_id=v_reactivated.group_id or v_reactivated.closed_on<v_transfer_in.effective_on
    or v_reactivated.end_position<v_transfer_in.event_position
    or (select count(*) from economics_v2.group_occupancy_events where granja_id=p_granja_id and operation_id=p_transfer_operation_id)<>2
    or (select count(*) from economics_v2.group_acquisition_basis_entries where granja_id=p_granja_id and operation_id=p_transfer_operation_id)<>2 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;

  if (v_prepared->>'replayed')::boolean then
    -- Reconstruct original OUT while holding, before consulting current pointers or later chronology.
    select jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
      'action','purpose_change','animal_id',p_animal_id,'source_period_id',v_source_id,'destination_period_id',null,
      'membership_event_ids',jsonb_build_array(e.id),'effective_on',p_effective_on,'event_position',e.event_position,
      'source_end_position',e.event_position,'destination_start_position',null,'basis_entry_ids',jsonb_build_array(b_out.id,b_in.id),
      'basis_before',0,'basis_after',0,'source_status','open','destination_status',null,'snapshot_id',null,
      'state_version',v_version+2,'replayed',false) into v_result
    from economics_v2.group_occupancy_events e
    join economics_v2.group_occupancy_memberships m on m.granja_id=e.granja_id and m.id=e.membership_id
    join economics_v2.group_acquisition_basis_entries b_out on b_out.granja_id=e.granja_id and b_out.event_id=e.id
    join economics_v2.group_acquisition_basis_entries b_in on b_in.granja_id=e.granja_id and b_in.event_id=e.id
    where e.granja_id=p_granja_id and e.operation_id=p_operation_id and e.animal_id=p_animal_id
      and e.period_id=v_source_id and e.membership_id=v_transfer_in.membership_id and e.action='purpose_change'
      and e.sale_id is null and e.effective_on=p_effective_on and e.event_position=v_stored.event_position
      and e.event_position>v_transfer_in.event_position and e.effective_on>=v_transfer_in.effective_on
      and m.animal_id=p_animal_id and m.period_id=v_source_id and m.end_position=e.event_position and m.position_span<@v_source.position_span
      and b_out.entry_kind='purpose_out' and b_out.account_kind='period' and b_out.period_id=v_source_id
      and b_in.entry_kind='purpose_in' and b_in.account_kind='holding' and b_in.period_id is null
      and b_out.animal_id=p_animal_id and b_in.animal_id=p_animal_id and b_out.operation_id=p_operation_id and b_in.operation_id=p_operation_id
      and b_out.entry_pair_id=e.basis_transfer_id and b_in.entry_pair_id=e.basis_transfer_id and b_out.signed_amount=0 and b_in.signed_amount=0;
    if v_result is null or v_stored.result is distinct from v_result
      or (select count(*) from economics_v2.group_occupancy_events where granja_id=p_granja_id and operation_id=p_operation_id)<>1
      or (select count(*) from economics_v2.group_acquisition_basis_entries where granja_id=p_granja_id and operation_id=p_operation_id)<>2 then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    return v_prepared->'result';
  end if;

  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  select * into v_member from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and id=v_transfer_in.membership_id for update;
  if v_member.end_position is not null or v_basis.current_period_id is distinct from v_source_id
    or v_basis.status is distinct from 'active' or v_basis.current_account_kind is distinct from 'period'
    or v_basis.remaining_basis is distinct from 0 or v_basis.disposed_event_id is not null or v_basis.version is distinct from v_version+1
    or v_animal.activo is distinct from true or v_animal.baja_id is not null or not isfinite(v_animal.fecha_adquisicion)
    or v_animal.fecha_adquisicion>v_activation.effective_on or not isfinite(v_source.starts_on)
    or v_source.starts_on>v_transfer_in.effective_on
    or exists(select 1 from economics_v2.group_occupancy_events where granja_id=p_granja_id
      and animal_id=p_animal_id and event_position>v_transfer_in.event_position)
    or (select count(*) from economics_v2.group_occupancy_events where granja_id=p_granja_id
      and animal_id=p_animal_id and action in('exit','delete','reactivate'))<>2
    or (select coalesce(sum(signed_amount),0) from economics_v2.group_acquisition_basis_entries
      where granja_id=p_granja_id and animal_id=p_animal_id and period_id=v_source_id)<>0
    or (select coalesce(sum(signed_amount),0) from economics_v2.group_acquisition_basis_entries
      where granja_id=p_granja_id and animal_id=p_animal_id and account_kind='holding')<>0 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if v_animal.grupo_id is distinct from p_group_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',p_group_id);
  end if;
  if v_animal.proposito_id is distinct from p_purpose_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',p_purpose_id);
  end if;
  if not exists(select 1 from public.grupos where granja_id=p_granja_id and id=p_group_id and tipo_animal_id=v_animal.tipo_animal_id)
    or not exists(select 1 from public.grupos where granja_id=p_granja_id and id=v_source.group_id and tipo_animal_id=v_animal.tipo_animal_id) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','group_id',p_group_id);
  end if;
  if not exists(select 1 from public.tipo_animal where granja_id=p_granja_id and id=v_animal.tipo_animal_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','tipo_animal_id',v_animal.tipo_animal_id);
  end if;
  select * into v_purpose from public.cat_proposito_animal where granja_id=p_granja_id and id=p_purpose_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',p_purpose_id);
  end if;
  if v_purpose.codigo_calculo is null or v_purpose.codigo_calculo not in('postura','ornamental')
    or not exists(select 1 from public.cat_proposito_animal where granja_id=p_granja_id and id=v_source.purpose_id and codigo_calculo='carne') then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','purpose_id',p_purpose_id);
  end if;
  if (select count(*) from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and period_id=v_source_id and end_position is null)<=1 then
    perform economics_v2.raise_group_writer_error('23514','period_close_unfinalized_facts','source_period_id',v_source_id);
  end if;

  -- Refusals precede issuance. End the real meat member without inventing a holding membership.
  v_position:=nextval('economics_v2.group_economics_event_position_seq');
  if v_position<=v_transfer_in.event_position then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  v_pair:=gen_random_uuid();
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result,event_position)
    values(p_granja_id,p_operation_id,v_prepared->>'payload_hash','{}',v_position);
  update economics_v2.group_occupancy_memberships set end_position=v_position where granja_id=p_granja_id and id=v_member.id;
  insert into economics_v2.group_occupancy_events(granja_id,period_id,membership_id,animal_id,
    event_position,effective_on,action,operation_id,basis_transfer_id)
    values(p_granja_id,v_source_id,v_member.id,p_animal_id,v_position,p_effective_on,'purpose_change',p_operation_id,v_pair)
    returning id into v_event;
  -- Zero legs remain durable; original realized cost and capture are never moved or recaptured.
  insert into economics_v2.group_acquisition_basis_entries(granja_id,animal_id,operation_id,event_id,
    entry_pair_id,entry_kind,account_kind,period_id,signed_amount)
    values(p_granja_id,p_animal_id,p_operation_id,v_event,v_pair,'purpose_out','period',v_source_id,0) returning id into v_out_entry;
  insert into economics_v2.group_acquisition_basis_entries(granja_id,animal_id,operation_id,event_id,
    entry_pair_id,entry_kind,account_kind,period_id,signed_amount)
    values(p_granja_id,p_animal_id,p_operation_id,v_event,v_pair,'purpose_in','holding',null,0) returning id into v_in_entry;
  update economics_v2.group_animal_acquisition_basis set current_account_kind='holding',current_period_id=null,version=version+1
    where granja_id=p_granja_id and animal_id=p_animal_id returning * into v_basis;
  v_result:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'action','purpose_change','animal_id',p_animal_id,'source_period_id',v_source_id,'destination_period_id',null,
    'membership_event_ids',jsonb_build_array(v_event),'effective_on',p_effective_on,'event_position',v_position,
    'source_end_position',v_position,'destination_start_position',null,'basis_entry_ids',jsonb_build_array(v_out_entry,v_in_entry),
    'basis_before',0,'basis_after',0,'source_status','open','destination_status',null,'snapshot_id',null,
    'state_version',v_basis.version,'replayed',false);
  -- Completion LAST: any late fault rolls back all economics rows and caller DML, never nextval.
  update economics_v2.group_occupancy_operations set result=v_result where granja_id=p_granja_id and operation_id=p_operation_id;
  return v_result;
end;
$$;

revoke all on function economics_v2.move_transferred_reactivated_meat_to_holding_nonclosing(uuid,uuid,uuid,date,uuid,uuid,uuid,uuid,jsonb)
  from public,anon,authenticated;
