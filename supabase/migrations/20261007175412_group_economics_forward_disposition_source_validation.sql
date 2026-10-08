-- Private pre-DML validation only: no operation preparation, replay, position issuance or writes.
-- The returned context is same-transaction working data, never a receipt or permission token.
create function economics_v2.validate_group_meat_nonclosing_source(
  p_granja_id uuid,p_animal_id uuid,p_effective_on date
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_actor uuid;
  v_animal public.animales%rowtype;
  v_group public.grupos%rowtype;
  v_source economics_v2.group_occupancy_periods%rowtype;
  v_member economics_v2.group_occupancy_memberships%rowtype;
  v_basis economics_v2.group_animal_acquisition_basis%rowtype;
  v_source_id uuid;
  v_member_id uuid;
  v_group_ids uuid[];
  v_scope jsonb;
  v_count bigint;
  v_active_count bigint;
  v_member_on date;
  v_net numeric;
begin
  v_actor := economics_v2.assert_group_writer_actor(p_granja_id);
  if p_animal_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','animal_id',null);
  end if;
  if p_effective_on is null or not isfinite(p_effective_on) or p_effective_on>current_date then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;

  -- Serialize scope discovery before delegating the complete ordered F2A row-lock prefix.
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
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
  select * into v_source from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and id=v_member.period_id;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if v_animal.grupo_id is null then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',null);
  end if;
  v_source_id := v_source.id;
  v_member_id := v_member.id;
  v_group_ids := array[v_source.group_id,v_animal.grupo_id];
  v_scope := economics_v2.lock_group_writer_scope(p_granja_id,v_group_ids,array[p_animal_id],
    array[v_source_id],p_effective_on);

  -- Reread the locked scope. The membership lock follows Group/animal/period/basis locks.
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
  select * into v_source from economics_v2.group_occupancy_periods
    where granja_id=p_granja_id and id=v_source_id;
  if not found or v_member.id is distinct from v_member_id
    or v_member.period_id is distinct from v_source_id
    or v_member.granja_id is distinct from v_source.granja_id
    or not (v_member.position_span<@v_source.position_span) then
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
  if not exists(select 1 from public.tipo_animal
    where granja_id=p_granja_id and id=v_animal.tipo_animal_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','tipo_animal_id',v_animal.tipo_animal_id);
  end if;

  -- Check both real catalog identities before equality: a foreign purpose is not a meat pin.
  if not exists(select 1 from public.cat_proposito_animal
    where granja_id=p_granja_id and id=v_source.purpose_id)
    or not exists(select 1 from public.cat_proposito_animal
      where granja_id=p_granja_id and id=v_animal.proposito_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',v_animal.proposito_id);
  end if;
  if exists(select 1 from public.cat_proposito_animal
    where granja_id=p_granja_id and id in (v_source.purpose_id,v_animal.proposito_id)
      and codigo_calculo is distinct from 'carne') then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','purpose_id',v_source.purpose_id);
  end if;
  if v_animal.proposito_id is distinct from v_source.purpose_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',v_animal.proposito_id);
  end if;
  if v_animal.activo is distinct from true or v_animal.baja_id is not null then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;

  -- Stored acquisition provenance is authoritative; mutable public cost is deliberately unused.
  select * into v_basis from economics_v2.group_animal_acquisition_basis
    where granja_id=p_granja_id and animal_id=p_animal_id;
  if not found or v_basis.status is distinct from 'active'
    or v_basis.current_account_kind is distinct from 'period'
    or v_basis.current_period_id is distinct from v_source_id or v_basis.disposed_event_id is not null
    or v_basis.initial_basis is null or v_basis.source_cost is null or v_basis.remaining_basis is null
    or v_basis.initial_basis<0 or v_basis.source_cost<0 or v_basis.remaining_basis<0
    or v_basis.initial_basis in ('NaN','Infinity','-Infinity')
    or v_basis.source_cost in ('NaN','Infinity','-Infinity')
    or v_basis.remaining_basis in ('NaN','Infinity','-Infinity')
    or v_basis.initial_basis is distinct from v_basis.source_cost
    or v_basis.remaining_basis is distinct from v_basis.initial_basis
    or exists(select 1 from economics_v2.group_occupancy_events
      where granja_id=p_granja_id and animal_id=p_animal_id and action in ('exit','delete','reactivate')) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select sum(signed_amount) into v_net from economics_v2.group_acquisition_basis_entries
    where granja_id=p_granja_id and animal_id=p_animal_id and account_kind='period' and period_id=v_source_id;
  if v_net is distinct from v_basis.remaining_basis then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;

  -- The membership must have a real matching start event, not an inferred acquisition date.
  select count(*),min(effective_on) into v_count,v_member_on from economics_v2.group_occupancy_events
    where granja_id=p_granja_id and animal_id=p_animal_id and period_id=v_source_id
      and membership_id=v_member.id and event_position=v_member.start_position
      and action in ('enter','transfer','purpose_change');
  if v_count<>1 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if not isfinite(v_animal.fecha_adquisicion) or not isfinite(v_source.starts_on)
    or not isfinite(v_member_on) or v_animal.fecha_adquisicion>p_effective_on
    or v_source.starts_on>p_effective_on or v_member_on>p_effective_on
    or exists(select 1 from economics_v2.group_occupancy_events
      where granja_id=p_granja_id and (animal_id=p_animal_id or period_id=v_source_id)
        and (not isfinite(effective_on) or effective_on>p_effective_on)) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;
  select count(*) into v_active_count from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and period_id=v_source_id and end_position is null;
  if v_active_count<=1 then
    perform economics_v2.raise_group_writer_error('23514','period_close_unfinalized_facts','source_period_id',v_source_id);
  end if;

  -- Future mutators obtain this internally before caller DML, never accept it from a client.
  return jsonb_build_object('context_version','group-disposition-source-context.v1',
    'actor_id',v_actor,'granja_id',p_granja_id,'animal_id',p_animal_id,'effective_on',p_effective_on,
    'source_period_id',v_source_id,'membership_id',v_member.id,'group_id',v_source.group_id,
    'purpose_id',v_source.purpose_id,'tipo_animal_id',v_animal.tipo_animal_id,
    'basis',to_jsonb(v_basis),'active_member_count',v_active_count,'scope',v_scope);
end;
$$;

revoke all on function economics_v2.validate_group_meat_nonclosing_source(uuid,uuid,date) from public,anon,authenticated;
