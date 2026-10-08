-- Private read-only ordinary-exit history validation; no restoration authority or transition.
-- FALSE is pre-caller-DML; TRUE is post-caller-DML with the disposed basis still intact.
-- Context is same-TX working data, never a supplied token, operation receipt or replay.
create function economics_v2.validate_disposed_group_meat_reactivation_source(
  p_granja_id uuid,p_animal_id uuid,p_disposed_event_id uuid,p_effective_on date,
  p_destination_group_id uuid,p_destination_purpose_id uuid,p_expected_active boolean
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_actor uuid;
  v_animal public.animales%rowtype;
  v_basis economics_v2.group_animal_acquisition_basis%rowtype;
  v_event economics_v2.group_occupancy_events%rowtype;
  v_member economics_v2.group_occupancy_memberships%rowtype;
  v_source economics_v2.group_occupancy_periods%rowtype;
  v_destination economics_v2.group_occupancy_periods%rowtype;
  v_operation economics_v2.group_occupancy_operations%rowtype;
  v_group public.grupos%rowtype;
  v_scope jsonb;
  v_reason jsonb;
  v_version bigint;
  v_source_id uuid;
  v_destination_id uuid;
  v_group_id uuid;
  v_purpose_id uuid;
  v_member_on date;
  v_count bigint;
  v_net numeric;
begin
  v_actor:=economics_v2.assert_group_writer_actor(p_granja_id);
  if p_animal_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','animal_id',null);
  end if;
  if p_disposed_event_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','disposed_event_id',null);
  end if;
  if p_expected_active is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','expected_active',p_animal_id);
  end if;
  if p_effective_on is null or not isfinite(p_effective_on) or p_effective_on>current_date then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;
  if p_destination_group_id is null or p_destination_purpose_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','destination',null);
  end if;

  -- Farm serialization precedes discovery; the complete ordered F2A prefix precedes rereads.
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','animal_id',p_animal_id);
  end if;
  select * into v_basis from economics_v2.group_animal_acquisition_basis
    where granja_id=p_granja_id and animal_id=p_animal_id;
  if not found or v_basis.disposed_event_id is distinct from p_disposed_event_id then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select * into v_event from economics_v2.group_occupancy_events
    where granja_id=p_granja_id and id=p_disposed_event_id and animal_id=p_animal_id;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select * into v_source from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and id=v_event.period_id;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if v_animal.grupo_id is null then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',null);
  end if;
  v_source_id:=v_source.id;
  select * into v_destination from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and group_id=p_destination_group_id
      and purpose_id=p_destination_purpose_id and end_position is null;
  v_destination_id:=v_destination.id;
  -- Only the mutable destination belongs in period_ids, even if history later genuinely closes.
  v_scope:=economics_v2.lock_group_writer_scope(p_granja_id,
    array[v_source.group_id,v_animal.grupo_id,p_destination_group_id],array[p_animal_id],
    case when v_destination_id is null then '{}'::uuid[] else array[v_destination_id] end,p_effective_on);
  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','animal_id',p_animal_id);
  end if;
  select * into v_basis from economics_v2.group_animal_acquisition_basis
    where granja_id=p_granja_id and animal_id=p_animal_id;
  if not found or v_basis.status is distinct from 'disposed'
    or v_basis.current_account_kind is distinct from 'disposed' or v_basis.current_period_id is not null
    or v_basis.remaining_basis is distinct from 0 or v_basis.disposed_event_id is distinct from p_disposed_event_id
    or v_basis.initial_basis is null or v_basis.initial_basis<0 or v_basis.source_cost is null
    or v_basis.initial_basis in ('NaN','Infinity','-Infinity')
    or v_basis.source_cost is distinct from v_basis.initial_basis
    or v_basis.captured_at is null or not isfinite(v_basis.captured_at)
    or exists(select 1 from economics_v2.group_occupancy_memberships
      where granja_id=p_granja_id and animal_id=p_animal_id and end_position is null) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select * into v_event from economics_v2.group_occupancy_events
    where granja_id=p_granja_id and id=p_disposed_event_id and animal_id=p_animal_id;
  if not found or v_event.action is distinct from 'exit' or v_event.period_id is distinct from v_source_id
    or v_event.operation_id is null or v_event.sale_id is not null or v_event.basis_transfer_id is not null
    or v_event.event_position<=0 or not isfinite(v_event.effective_on)
    or exists(select 1 from economics_v2.group_occupancy_events e
      where e.granja_id=p_granja_id and e.animal_id=p_animal_id
        and (e.event_position>v_event.event_position or e.id<>v_event.id and e.action in('exit','delete','reactivate'))) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select * into v_source from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and id=v_source_id;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select * into v_member from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and id=v_event.membership_id for share;
  if not found or v_member.animal_id is distinct from p_animal_id
    or v_member.period_id is distinct from v_source_id or v_member.end_position is distinct from v_event.event_position
    or v_member.start_position>=v_event.event_position or not(v_member.position_span<@v_source.position_span) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;

  -- Durable reason is exact3 canonical provenance data, not client authorization metadata.
  begin
    v_reason:=v_event.reason::jsonb;
  exception when invalid_text_representation or numeric_value_out_of_range then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end;
  if jsonb_typeof(v_reason) is distinct from 'object' then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if (select count(*) from jsonb_object_keys(v_reason))<>3
    or v_reason->'provenance_version' is distinct from '"group-disposition-provenance.v1"'::jsonb
    or v_reason->'disposition_kind' is distinct from '"ordinary_exit"'::jsonb
    or jsonb_typeof(v_reason->'metadata') is distinct from 'object'
    or v_event.reason is distinct from economics_v2.canonical_group_request(v_reason)::text then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select * into v_operation from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=v_event.operation_id for share;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',v_event.operation_id);
  end if;
  begin
    v_version:=(v_operation.result->>'state_version')::bigint;
  exception when invalid_text_representation or numeric_value_out_of_range then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',v_event.operation_id);
  end;
  if v_version is null or v_version<=0 or v_operation.event_position is distinct from v_event.event_position
    or v_operation.result is distinct from jsonb_build_object('contract_version','group-economics.forward.v3',
      'operation_id',v_event.operation_id,'action','exit','animal_id',p_animal_id,'source_period_id',v_source_id,
      'destination_period_id',null,'membership_event_ids',jsonb_build_array(v_event.id),'effective_on',v_event.effective_on,
      'event_position',v_event.event_position,'source_end_position',v_event.event_position,'destination_start_position',null,
      'basis_entry_ids','[]'::jsonb,'basis_before',v_basis.initial_basis,'basis_after',0,'source_status','open',
      'destination_status',null,'snapshot_id',null,'state_version',v_version,'replayed',false) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',v_event.operation_id);
  end if;
  -- Parse the receipt independently, THEN compare current version: distinct error ownership.
  -- Never prepare the old operation under this actor: its original hash binds a different actor.
  if v_basis.version is distinct from v_version then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;

  foreach v_group_id in array array[v_source.group_id,v_animal.grupo_id,p_destination_group_id] loop
    select * into v_group from public.grupos where granja_id=p_granja_id and id=v_group_id;
    if not found then
      perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_group_id);
    end if;
    if v_group.tipo_animal_id is distinct from v_animal.tipo_animal_id then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','group_id',v_group_id);
    end if;
  end loop;
  if not exists(select 1 from public.tipo_animal where granja_id=p_granja_id and id=v_animal.tipo_animal_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','tipo_animal_id',v_animal.tipo_animal_id);
  end if;
  foreach v_purpose_id in array array[v_source.purpose_id,v_animal.proposito_id,p_destination_purpose_id] loop
    if not exists(select 1 from public.cat_proposito_animal where granja_id=p_granja_id and id=v_purpose_id) then
      perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',v_purpose_id);
    end if;
    if exists(select 1 from public.cat_proposito_animal where granja_id=p_granja_id
      and id=v_purpose_id and codigo_calculo is distinct from 'carne') then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','purpose_id',v_purpose_id);
    end if;
  end loop;
  if v_animal.activo is distinct from p_expected_active or v_animal.baja_id is not null then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if v_animal.grupo_id is distinct from (case when p_expected_active then p_destination_group_id else v_source.group_id end) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_animal.grupo_id);
  end if;
  if v_animal.proposito_id is distinct from (case when p_expected_active then p_destination_purpose_id else v_source.purpose_id end) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',v_animal.proposito_id);
  end if;

  -- Historical source signed cost is ORIGINAL C, not disposed remaining0 or public cost999.
  select sum(signed_amount) into v_net from economics_v2.group_acquisition_basis_entries
    where granja_id=p_granja_id and animal_id=p_animal_id and account_kind='period' and period_id=v_source_id;
  if v_net is distinct from v_basis.initial_basis
    or (select count(*) from economics_v2.group_acquisition_basis_entries
      where granja_id=p_granja_id and animal_id=p_animal_id and entry_kind='initial'
        and signed_amount=v_basis.initial_basis and entry_pair_id is null)<>1 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  -- Tie the retained capture to its real original entry/event/operation, never recapture it.
  if not exists(select 1 from economics_v2.group_acquisition_basis_entries b
    join economics_v2.group_occupancy_events e on e.granja_id=b.granja_id and e.id=b.event_id
    join economics_v2.group_occupancy_operations o on o.granja_id=b.granja_id and o.operation_id=b.operation_id
    where b.granja_id=p_granja_id and b.animal_id=p_animal_id and b.entry_kind='initial'
      and b.signed_amount=v_basis.initial_basis and b.account_kind='period' and b.entry_pair_id is null
      and b.created_at=v_basis.captured_at and e.action='enter' and e.animal_id=p_animal_id
      and e.period_id=b.period_id and e.operation_id=b.operation_id and e.event_position<v_event.event_position
      and o.event_position=e.event_position and o.result->>'contract_version'='group-economics.forward.v3'
      and o.result->>'action'='enter' and o.result->'animal_id'=to_jsonb(p_animal_id)
      and o.result->'basis_after'=to_jsonb(v_basis.initial_basis)
      and o.result->'basis_entry_ids'=jsonb_build_array(b.id)) then
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
    or v_animal.fecha_adquisicion>v_member_on or v_source.starts_on>v_member_on or v_member_on>v_event.effective_on
    or v_event.effective_on>p_effective_on
    or exists(select 1 from economics_v2.group_occupancy_events where granja_id=p_granja_id
      and animal_id=p_animal_id and (not isfinite(effective_on) or effective_on>p_effective_on)) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;
  -- Closed historical periods remain read-only; real closed-history runtime proof is deferred.
  if (v_source.end_position is null)<>(v_source.closed_on is null)
    or v_source.closed_on is not null and (not isfinite(v_source.closed_on) or v_source.closed_on<v_event.effective_on) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if v_source.end_position is not null and not exists(select 1 from economics_v2.group_meat_snapshots
    where granja_id=p_granja_id and period_id=v_source_id and snapshot_version='group-meat-snapshot.forward.v3') then
    perform economics_v2.raise_group_writer_error('23514','missing_closed_snapshot','group_id',v_source.group_id);
  end if;

  select * into v_destination from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and group_id=p_destination_group_id
      and purpose_id=p_destination_purpose_id and end_position is null;
  if v_destination.id is distinct from v_destination_id then
    perform economics_v2.raise_group_writer_error('40001','stale_write','group_id',p_destination_group_id);
  end if;
  if exists(select 1 from economics_v2.group_occupancy_periods t
    where t.granja_id=p_granja_id and t.group_id=p_destination_group_id and t.purpose_id=p_destination_purpose_id
      and (not isfinite(t.starts_on) or t.starts_on>p_effective_on
        or t.closed_on is not null and (not isfinite(t.closed_on) or t.closed_on>p_effective_on)
        or exists(select 1 from economics_v2.group_occupancy_events e where e.granja_id=p_granja_id
          and e.period_id=t.id and (not isfinite(e.effective_on) or e.effective_on>p_effective_on)))) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;
  if exists(select 1 from economics_v2.group_occupancy_periods t
    where t.granja_id=p_granja_id and t.group_id=p_destination_group_id and t.purpose_id=p_destination_purpose_id
      and t.end_position is not null and not exists(select 1 from economics_v2.group_meat_snapshots s
        where s.granja_id=t.granja_id and s.period_id=t.id and s.snapshot_version='group-meat-snapshot.forward.v3')) then
    perform economics_v2.raise_group_writer_error('23514','missing_closed_snapshot','group_id',p_destination_group_id);
  end if;
  return jsonb_build_object('context_version','group-reactivation-source-context.v1','actor_id',v_actor,
    'granja_id',p_granja_id,'animal_id',p_animal_id,'disposed_event_id',p_disposed_event_id,'effective_on',p_effective_on,
    'destination_group_id',p_destination_group_id,'destination_purpose_id',p_destination_purpose_id,
    'expected_active',p_expected_active,'basis',to_jsonb(v_basis),'disposition_event',to_jsonb(v_event),
    'disposition_result',v_operation.result,'historical_membership',to_jsonb(v_member),'historical_period_id',v_source_id,
    'destination_period_id',v_destination_id,'scope',v_scope);
end;
$$;

revoke all on function economics_v2.validate_disposed_group_meat_reactivation_source(uuid,uuid,uuid,date,uuid,uuid,boolean)
  from public,anon,authenticated;
