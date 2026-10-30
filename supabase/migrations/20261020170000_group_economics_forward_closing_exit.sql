-- Private ordinary last-animal exit; no public activation, sale, baja or reactivation.
-- One transaction owns animal DML, captured-source validation, closure and receipt.
-- Historical feed H is retained, not rewritten or recaptured for a successor period.
create function economics_v2.exit_group_meat_closing(
  p_granja_id uuid,p_operation_id uuid,p_animal_id uuid,p_effective_on date,p_payload jsonb
) returns jsonb language plpgsql volatile security invoker set search_path='' as $$
declare
  v_actor uuid;
  v_animal public.animales%rowtype;
  v_group public.grupos%rowtype;
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_member economics_v2.group_occupancy_memberships%rowtype;
  v_basis economics_v2.group_animal_acquisition_basis%rowtype;
  v_operation economics_v2.group_occupancy_operations%rowtype;
  v_snapshot economics_v2.group_meat_snapshots%rowtype;
  v_feed economics_v2.group_period_feed_allocations%rowtype;
  v_event economics_v2.group_occupancy_events%rowtype;
  v_row record;
  v_animals uuid[];
  v_periods uuid[];
  v_headers uuid[];
  v_id uuid;
  v_source uuid;
  v_group_id uuid;
  v_member_id uuid;
  v_event_id uuid;
  v_snapshot_id uuid;
  v_position bigint;
  v_version bigint;
  v_before numeric;
  v_hash text;
  v_result jsonb;
  v_expected jsonb;
  v_original jsonb;
  v_entries jsonb;
  v_metrics jsonb;
  v_clock timestamptz;
  v_start_on date;
  v_metric_keys text[]:=array['acquisition_cost','active_animal_count','animal_count','animal_sale_revenue',
    'balance_per_animal','break_even_kg','direct_expense_total','exited_animal_count','feed_cost',
    'feed_kg_total','feed_source_count','profit','realized_price_per_kg','sale_count','saleable_kg',
    'sold_animal_count','total_cost'];
begin
  v_actor:=economics_v2.assert_group_writer_actor(p_granja_id);
  if p_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','operation_id',null);
  end if;
  if p_animal_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','animal_id',null);
  end if;
  if p_effective_on is null or not isfinite(p_effective_on) or p_effective_on>current_date then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;
  if jsonb_typeof(p_payload) is distinct from 'object' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','payload',p_animal_id);
  end if;
  if (select count(*) from jsonb_object_keys(p_payload))<>3
    or p_payload->'provenance_version' is distinct from '"group-disposition-provenance.v1"'::jsonb
    or p_payload->'disposition_kind' is distinct from '"ordinary_exit"'::jsonb
    or jsonb_typeof(p_payload->'metadata') is distinct from 'object' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','payload',p_animal_id);
  end if;
  -- Separate domain, without mutable source discovery in the canonical request.
  v_hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-meat-closing-exit.v1',
    'granja_id',p_granja_id,'actor_id',v_actor,'operation_id',p_operation_id,'request',jsonb_build_object(
      'action','ordinary_exit','animal_id',p_animal_id,'effective_on',p_effective_on,'payload',p_payload)))::text,'UTF8')),'hex');
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  select * into v_operation from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=p_operation_id for update;
  if found then
    if v_operation.payload_hash is distinct from v_hash then
      perform economics_v2.raise_group_writer_error('22023','operation_payload_conflict','operation_id',p_operation_id);
    end if;
    v_result:=v_operation.result;
    -- Only stored scalar conversion is caught; business/trigger exceptions propagate.
    begin
      v_source:=(v_result->>'source_period_id')::uuid;
      v_event_id:=(v_result->'membership_event_ids'->>0)::uuid;
      v_snapshot_id:=(v_result->>'snapshot_id')::uuid;
      v_position:=(v_result->>'event_position')::bigint;
      v_version:=(v_result->>'state_version')::bigint;
      v_before:=(v_result->>'basis_before')::numeric;
    exception when data_exception then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end;
    v_expected:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
      'action','exit','animal_id',p_animal_id,'source_period_id',v_source,'destination_period_id',null,
      'membership_event_ids',jsonb_build_array(v_event_id),'effective_on',p_effective_on,'event_position',v_position,
      'source_end_position',v_position,'destination_start_position',null,'basis_entry_ids','[]'::jsonb,
      'basis_before',v_before,'basis_after',0,'source_status','closed','destination_status',null,
      'snapshot_id',v_snapshot_id,'state_version',v_version,'replayed',false);
    if v_source is null or v_event_id is null or v_snapshot_id is null or v_position is null or v_position<=0
      or v_version is null or v_version<=0 or v_before is null or v_before<0 or v_before in ('NaN','Infinity','-Infinity')
      or v_operation.event_position is distinct from v_position or v_result is distinct from v_expected
      or not exists(select 1 from economics_v2.group_occupancy_events e where e.id=v_event_id
        and e.granja_id=p_granja_id and e.operation_id=p_operation_id and e.animal_id=p_animal_id
        and e.period_id=v_source and e.event_position=v_position and e.effective_on=p_effective_on
        and e.action='exit' and e.sale_id is null and e.basis_transfer_id is null
        and e.reason=economics_v2.canonical_group_request(p_payload)::text) then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    select * into v_snapshot from economics_v2.group_meat_snapshots where id=v_snapshot_id
      and granja_id=p_granja_id and period_id=v_source;
    if not found or v_snapshot.snapshot_version<>'group-meat-snapshot.forward.v3'
      or jsonb_typeof(v_snapshot.payload->'group_name') is distinct from 'string'
      or v_snapshot.payload->>'purpose_code' is distinct from 'carne'
      or jsonb_typeof(v_snapshot.payload->'metrics') is distinct from 'object' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    if (select array_agg(k order by k) from jsonb_object_keys(v_snapshot.payload->'metrics') k) is distinct from v_metric_keys then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    return v_result||jsonb_build_object('replayed',true);
  end if;

  if current_setting('transaction_isolation')<>'read committed' then
    perform economics_v2.raise_group_writer_error('40001','stale_write','animal_id',p_animal_id);
  end if;
  select * into v_animal from public.animales where granja_id=p_granja_id and id=p_animal_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','animal_id',p_animal_id);
  end if;
  if (select count(*) from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and animal_id=p_animal_id and end_position is null)<>1 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  select * into v_member from economics_v2.group_occupancy_memberships
    where granja_id=p_granja_id and animal_id=p_animal_id and end_position is null;
  select * into v_period from economics_v2.group_occupancy_periods where id=v_member.period_id and granja_id=p_granja_id;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if v_animal.grupo_id is null then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',null);
  end if;
  v_source:=v_period.id;
  v_group_id:=v_period.group_id; v_member_id:=v_member.id;
  -- Discover ALL historical animals before the ordered Group/animal/period/basis prefix.
  -- Closed periods are locked too; the nonclosing lock helper deliberately rejects them.
  select array_agg(id order by id) into v_periods from economics_v2.group_occupancy_periods where group_id=v_group_id;
  select array_agg(distinct id order by id) into v_animals from (
    select id from public.animales where grupo_id=v_period.group_id
    union select animal_id from economics_v2.group_occupancy_memberships where period_id=any(v_periods)
    union select p_animal_id) scope;
  for v_id in select distinct id from unnest(array[v_period.group_id,v_animal.grupo_id]) id order by id loop
    perform 1 from public.grupos where id=v_id and granja_id=p_granja_id for update;
    if not found then perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_id); end if;
  end loop;
  perform 1 from public.animales where id=any(v_animals) order by id for update;
  perform 1 from economics_v2.group_occupancy_periods where id=any(v_periods) order by id for update;
  perform 1 from economics_v2.group_animal_acquisition_basis where animal_id=any(v_animals) order by animal_id for update;
  perform 1 from economics_v2.group_occupancy_memberships where period_id=any(v_periods) or animal_id=any(v_animals) order by id for update;
  perform 1 from economics_v2.group_occupancy_events where period_id=v_source or animal_id=any(v_animals) order by id for share;
  perform 1 from economics_v2.group_acquisition_basis_entries where period_id=v_source or animal_id=any(v_animals) order by id for share;
  perform 1 from economics_v2.group_occupancy_operations o where exists(
    select 1 from economics_v2.group_occupancy_events e where e.operation_id=o.operation_id
      and e.granja_id=o.granja_id and (e.period_id=v_source or e.animal_id=any(v_animals))) order by o.operation_id for share;
  -- Discovery cannot silently grow while waiting for the prefix (including admin DML).
  if (select array_agg(id order by id) from economics_v2.group_occupancy_periods where group_id=v_group_id) is distinct from v_periods
    or (select array_agg(distinct id order by id) from (
      select id from public.animales where grupo_id=v_group_id
      union select animal_id from economics_v2.group_occupancy_memberships where period_id=any(v_periods)
      union select p_animal_id) scope) is distinct from v_animals then
    perform economics_v2.raise_group_writer_error('40001','stale_write','period_id',v_source);
  end if;
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  select * into v_animal from public.animales where id=p_animal_id and granja_id=p_granja_id;
  select * into v_member from economics_v2.group_occupancy_memberships where id=v_member_id;
  select * into v_period from economics_v2.group_occupancy_periods where id=v_source;
  if not found or v_period.group_id is distinct from v_group_id or v_period.granja_id is distinct from p_granja_id then
    perform economics_v2.raise_group_writer_error('40001','stale_write','period_id',v_source);
  end if;
  select * into v_group from public.grupos where id=v_period.group_id and granja_id=p_granja_id;
  if not found or v_animal.grupo_id is distinct from v_period.group_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_animal.grupo_id);
  end if;
  if v_animal.activo is distinct from true or v_animal.baja_id is not null
    or v_member.animal_id is distinct from p_animal_id or v_member.period_id is distinct from v_source
    or v_member.granja_id is distinct from p_granja_id or v_member.end_position is not null
    or not(v_member.position_span<@v_period.position_span) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if v_period.closed_on is not null or v_period.end_position is not null then
    perform economics_v2.raise_group_writer_error('23514','closed_period_immutable','period_id',v_source);
  end if;
  if v_group.nombre is null or v_group.tipo_animal_id is distinct from v_animal.tipo_animal_id then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','group_id',v_group.id);
  end if;
  perform 1 from public.tipo_animal where id=v_animal.tipo_animal_id and granja_id=p_granja_id for share;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','tipo_animal_id',v_animal.tipo_animal_id);
  end if;
  perform 1 from public.cat_proposito_animal where id in(v_period.purpose_id,v_animal.proposito_id) order by id for share;
  if not exists(select 1 from public.cat_proposito_animal where id=v_period.purpose_id and granja_id=p_granja_id)
    or not exists(select 1 from public.cat_proposito_animal where id=v_animal.proposito_id and granja_id=p_granja_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',v_animal.proposito_id);
  end if;
  if exists(select 1 from public.cat_proposito_animal where id in(v_period.purpose_id,v_animal.proposito_id) and codigo_calculo is distinct from 'carne') then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','purpose_id',v_period.purpose_id);
  end if;
  if v_animal.proposito_id is distinct from v_period.purpose_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',v_animal.proposito_id);
  end if;
  if v_animal.fecha_adquisicion is null or not isfinite(v_animal.fecha_adquisicion)
    or v_period.starts_on is null or not isfinite(v_period.starts_on)
    or v_animal.fecha_adquisicion>p_effective_on or v_period.starts_on>p_effective_on
    or exists(select 1 from economics_v2.group_occupancy_events where (animal_id=any(v_animals) or period_id=any(v_periods))
      and (not isfinite(effective_on) or effective_on>p_effective_on)) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;
  select count(*),min(effective_on) into v_version,v_start_on from economics_v2.group_occupancy_events
    where granja_id=p_granja_id and animal_id=p_animal_id and period_id=v_source
      and membership_id=v_member.id and event_position=v_member.start_position and action in('enter','transfer','purpose_change');
  select * into v_basis from economics_v2.group_animal_acquisition_basis where granja_id=p_granja_id and animal_id=p_animal_id;
  if not found or v_version<>1 or v_start_on is null or v_start_on>p_effective_on
    or v_basis.status is distinct from 'active' or v_basis.current_account_kind is distinct from 'period'
    or v_basis.current_period_id is distinct from v_source or v_basis.disposed_event_id is not null
    or v_basis.initial_basis is distinct from v_basis.source_cost or v_basis.remaining_basis is distinct from v_basis.initial_basis
    or v_basis.initial_basis is null or v_basis.initial_basis<0 or v_basis.initial_basis in ('NaN','Infinity','-Infinity')
    or not isfinite(v_basis.captured_at) or v_basis.version=9223372036854775807
    or exists(select 1 from economics_v2.group_occupancy_events where animal_id=p_animal_id and action in('exit','delete','reactivate'))
    or (select sum(signed_amount) from economics_v2.group_acquisition_basis_entries
      where granja_id=p_granja_id and animal_id=p_animal_id and account_kind='period' and period_id=v_source) is distinct from v_basis.remaining_basis then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  -- Entry/event/completed-operation lineage is checked across the historical scope.
  if exists(select 1 from economics_v2.group_acquisition_basis_entries a
    left join economics_v2.group_occupancy_events e on e.id=a.event_id
    left join economics_v2.group_occupancy_operations o on o.granja_id=a.granja_id and o.operation_id=a.operation_id
    where a.animal_id=any(v_animals) and (a.granja_id<>p_granja_id or e.granja_id is distinct from a.granja_id
      or e.animal_id is distinct from a.animal_id or e.operation_id is distinct from a.operation_id
      or not coalesce(o.result->'basis_entry_ids' @> jsonb_build_array(a.id),false)
      or not coalesce(o.result->'membership_event_ids' @> jsonb_build_array(e.id),false)
      or o.result->>'contract_version' is distinct from 'group-economics.forward.v3'
      or o.result->'animal_id' is distinct from to_jsonb(a.animal_id)
      or o.result->'event_position' is distinct from to_jsonb(e.event_position)
      or o.result->'effective_on' is distinct from to_jsonb(e.effective_on)
      or o.result->>'action' is distinct from e.action or o.result->'replayed' is distinct from 'false'::jsonb
      or o.event_position is distinct from e.event_position or e.basis_transfer_id is distinct from a.entry_pair_id
      or (a.account_kind='period' and a.period_id is distinct from e.period_id)
      or (a.entry_kind<>'initial' and e.action is distinct from case when a.entry_kind like 'purpose_%' then 'purpose_change' else 'transfer' end)
      or (a.entry_kind='initial' and (e.action<>'enter' or a.entry_pair_id is not null or a.signed_amount<0))))
    or exists(select 1 from economics_v2.group_animal_acquisition_basis b where b.animal_id=any(v_animals)
      and (b.granja_id<>p_granja_id or not isfinite(b.captured_at) or b.initial_basis is distinct from b.source_cost
        or (select count(*) from economics_v2.group_acquisition_basis_entries a where a.animal_id=b.animal_id and a.entry_kind='initial')<>1
        or (select sum(signed_amount) from economics_v2.group_acquisition_basis_entries a
          where a.animal_id=b.animal_id and a.entry_kind='initial') is distinct from b.initial_basis
        or (select sum(signed_amount) from economics_v2.group_acquisition_basis_entries a
          where a.animal_id=b.animal_id) is distinct from b.initial_basis))
    or exists(select 1 from economics_v2.group_acquisition_basis_entries a where a.animal_id=any(v_animals)
      and a.entry_kind<>'initial' and (a.entry_pair_id is null
        or (select count(*) from economics_v2.group_acquisition_basis_entries pair where pair.entry_pair_id=a.entry_pair_id)<>2
        or exists(select 1 from economics_v2.group_acquisition_basis_entries pair where pair.entry_pair_id=a.entry_pair_id
          and row(pair.granja_id,pair.animal_id,pair.operation_id) is distinct from row(a.granja_id,a.animal_id,a.operation_id))
        or (select count(*) from economics_v2.group_acquisition_basis_entries pair where pair.entry_pair_id=a.entry_pair_id
          and pair.entry_kind in('transfer_in','purpose_in') and pair.signed_amount>=0)<>1
        or (select count(*) from economics_v2.group_acquisition_basis_entries pair where pair.entry_pair_id=a.entry_pair_id
          and pair.entry_kind in('transfer_out','purpose_out') and pair.signed_amount<=0)<>1
        or (select sum(signed_amount) from economics_v2.group_acquisition_basis_entries pair where pair.entry_pair_id=a.entry_pair_id)<>0))
    or exists(select 1 from economics_v2.group_occupancy_events e left join economics_v2.group_occupancy_operations o
      on o.granja_id=e.granja_id and o.operation_id=e.operation_id where e.period_id=v_source
      and (e.granja_id<>p_granja_id or o.event_position is distinct from e.event_position
        or o.result->>'contract_version' is distinct from 'group-economics.forward.v3'
        or o.result->'animal_id' is distinct from to_jsonb(e.animal_id)
        or o.result->'effective_on' is distinct from to_jsonb(e.effective_on)
        or o.result->'event_position' is distinct from to_jsonb(e.event_position)
        or o.result->>'action' is distinct from e.action or o.result->'replayed' is distinct from 'false'::jsonb
        or not coalesce(o.result->'membership_event_ids' @> jsonb_build_array(e.id),false))) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if exists(select 1 from economics_v2.group_occupancy_memberships m left join public.animales a on a.id=m.animal_id
    left join economics_v2.group_animal_acquisition_basis b on b.animal_id=m.animal_id and b.granja_id=m.granja_id
    where m.period_id=v_source and (m.granja_id<>p_granja_id or a.granja_id is distinct from p_granja_id or b.animal_id is null
      or not(m.position_span<@v_period.position_span)
      or (select count(*) from economics_v2.group_occupancy_events e where e.membership_id=m.id
        and e.animal_id=m.animal_id and e.granja_id=m.granja_id and e.period_id=m.period_id
        and e.event_position=m.start_position and e.action in('enter','transfer','purpose_change'))<>1
      or (m.end_position is not null and not exists(select 1 from economics_v2.group_occupancy_events e
        where e.membership_id=m.id and e.animal_id=m.animal_id and e.period_id=m.period_id
          and e.granja_id=m.granja_id and e.event_position=m.end_position and e.action in('exit','delete','transfer','purpose_change'))))) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  if (select count(*) from economics_v2.group_occupancy_memberships where period_id=v_source and end_position is null)<>1
    or exists(select 1 from public.animales a where a.grupo_id=v_group.id and a.proposito_id=v_period.purpose_id and a.activo
      and not exists(select 1 from economics_v2.group_occupancy_memberships m where m.period_id=v_source and m.animal_id=a.id and m.end_position is null)) then
    perform economics_v2.raise_group_writer_error('23514','period_close_unfinalized_facts','source_period_id',v_source);
  end if;

  -- Lock allocations even if misbound, and all Group headers including historical H.
  perform 1 from economics_v2.group_period_feed_allocations a where a.period_id=v_source
    or exists(select 1 from public.mezcla m where m.id=a.mixture_id and m.grupo_id=v_group.id) order by a.id for update;
  select coalesce(array_agg(id order by id),'{}'::uuid[]) into v_headers from public.mezcla m
    where m.grupo_id=v_group.id or exists(select 1 from economics_v2.group_period_feed_allocations a where a.period_id=v_source and a.mixture_id=m.id);
  perform 1 from public.mezcla where id=any(v_headers) order by id for update;
  perform 1 from public.mezcla_comida where mezcla_id=any(v_headers) order by id for update;
  perform 1 from public.comida where id in(select comida_id from public.mezcla_comida where mezcla_id=any(v_headers)) order by id for update;
  perform 1 from public.cat_comida where id in(select c.cat_comida_id from public.comida c
    join public.mezcla_comida mc on mc.comida_id=c.id where mc.mezcla_id=any(v_headers)) order by id for share;
  perform 1 from economics_v2.group_period_expenses where period_id=v_source order by id for update;
  perform 1 from economics_v2.group_period_sale_bindings where period_id=v_source order by sale_id for update;
  perform 1 from public.venta_animal where grupo_id=v_group.id or animal_id=any(v_animals)
    or id in(select sale_id from economics_v2.group_period_sale_bindings where period_id=v_source) order by id for update;
  -- Lock existing fences only: refusals/replays must not touch revisions or reserve rows.
  perform 1 from group_feed_integrity.fences where scope='purpose' and entity_id=v_period.purpose_id for update;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',v_source);
  end if;
  perform 1 from group_feed_integrity.fences where scope='group' and entity_id=v_group.id for update;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',v_source);
  end if;
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  if exists(select 1 from public.mezcla m where m.id=any(v_headers) and not group_feed_integrity.is_closed_feed_history(m)
    and not exists(select 1 from economics_v2.group_period_feed_allocations a
      where a.mixture_id=m.id and a.period_id=v_source and a.granja_id=p_granja_id))
    or exists(select 1 from economics_v2.group_period_expenses where period_id=v_source
      and (granja_id<>p_granja_id or not isfinite(occurred_on) or occurred_on<v_period.starts_on
        or amount<=0 or amount in ('NaN','Infinity','-Infinity') or btrim(category)=''
        or not isfinite(created_at) or not isfinite(updated_at)))
    or exists(select 1 from economics_v2.group_period_sale_bindings where period_id=v_source)
    or exists(select 1 from public.venta_animal where grupo_id=v_group.id or animal_id=any(v_animals)) then
    -- Explicit ordinary-slice refusal, not a general ban on future canonical sale closure.
    perform economics_v2.raise_group_writer_error('23514','period_close_unfinalized_facts','source_period_id',v_source);
  end if;
  if exists(select 1 from economics_v2.group_period_expenses where period_id=v_source and occurred_on>p_effective_on)
    or exists(select 1 from public.mezcla m where m.id=any(v_headers) and not group_feed_integrity.is_closed_feed_history(m)
      and (m.fecha_inicio>p_effective_on or m.fecha_termino>p_effective_on)) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_animal_id);
  end if;
  for v_feed in select * from economics_v2.group_period_feed_allocations where period_id=v_source order by id loop
    perform economics_v2.validate_group_feed_allocation_for_close(p_granja_id,v_source,v_feed.id);
  end loop;
  select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb) into v_entries
    from economics_v2.group_acquisition_basis_entries a where a.animal_id=any(v_animals);

  -- Every admission/refusal above precedes the single nontransactional position issue.
  v_before:=v_basis.remaining_basis; v_version:=v_basis.version+1;
  v_position:=nextval('economics_v2.group_economics_event_position_seq');
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result,event_position)
    values(p_granja_id,p_operation_id,v_hash,'{}',v_position) returning * into v_operation;
  if not found or v_operation.payload_hash is distinct from v_hash or v_operation.result<>'{}'::jsonb
    or v_operation.granja_id is distinct from p_granja_id or v_operation.operation_id is distinct from p_operation_id
    or v_operation.event_position is distinct from v_position then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
  end if;
  v_original:=to_jsonb(v_animal);
  update public.animales set activo=false where id=p_animal_id and granja_id=p_granja_id returning * into v_animal;
  if not found or to_jsonb(v_animal)-'updated_at' is distinct from (v_original||'{"activo":false}'::jsonb)-'updated_at' then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  v_original:=to_jsonb(v_member);
  update economics_v2.group_occupancy_memberships set end_position=v_position where id=v_member.id returning * into v_member;
  if not found or to_jsonb(v_member) is distinct from v_original||jsonb_build_object('end_position',v_position,
    'position_span',int8range(v_member.start_position,v_position,'[)')) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  v_event_id:=gen_random_uuid();
  insert into economics_v2.group_occupancy_events(id,granja_id,period_id,membership_id,animal_id,event_position,
    effective_on,action,operation_id,reason) values(v_event_id,p_granja_id,v_source,v_member.id,p_animal_id,v_position,
      p_effective_on,'exit',p_operation_id,economics_v2.canonical_group_request(p_payload)::text) returning * into v_event;
  if not found or row(v_event.id,v_event.granja_id,v_event.period_id,v_event.membership_id,v_event.animal_id,
    v_event.event_position,v_event.effective_on,v_event.action,v_event.operation_id,v_event.reason,v_event.sale_id,v_event.basis_transfer_id)
    is distinct from row(v_event_id,p_granja_id,v_source,v_member.id,p_animal_id,v_position,p_effective_on,'exit',
      p_operation_id,economics_v2.canonical_group_request(p_payload)::text,null::uuid,null::uuid)
    or not isfinite(v_event.created_at) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  v_expected:=to_jsonb(v_basis)||jsonb_build_object('remaining_basis',0,'status','disposed','current_account_kind','disposed',
    'current_period_id',null,'disposed_event_id',v_event_id,'version',v_version);
  update economics_v2.group_animal_acquisition_basis set remaining_basis=0,status='disposed',current_account_kind='disposed',
    current_period_id=null,disposed_event_id=v_event_id,version=v_version
    where granja_id=p_granja_id and animal_id=p_animal_id returning * into v_basis;
  if not found or to_jsonb(v_basis) is distinct from v_expected then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','animal_id',p_animal_id);
  end if;
  -- Reinspect under retained locks while still OPEN, then verify each finalized row.
  v_clock:=clock_timestamp();
  for v_feed in select * from economics_v2.group_period_feed_allocations where period_id=v_source order by id loop
    perform economics_v2.validate_group_feed_allocation_for_close(p_granja_id,v_source,v_feed.id);
    v_expected:=to_jsonb(v_feed)||jsonb_build_object('finalized_at',v_clock,'updated_at',v_clock);
    update economics_v2.group_period_feed_allocations set finalized_at=v_clock,updated_at=v_clock
      where id=v_feed.id returning * into v_feed;
    if not found or to_jsonb(v_feed) is distinct from v_expected then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','allocation_id',v_feed.id);
    end if;
  end loop;
  v_expected:=to_jsonb(v_period)||jsonb_build_object('closed_on',p_effective_on,'end_position',v_position,
    'position_span',int8range(v_period.start_position,v_position,'[)'));
  update economics_v2.group_occupancy_periods set closed_on=p_effective_on,end_position=v_position
    where id=v_source returning * into v_period;
  if not found or to_jsonb(v_period) is distinct from v_expected then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',v_source);
  end if;
  v_metrics:=economics_v2.calculate_group_period_live_metrics(p_granja_id,v_source);
  if jsonb_typeof(v_metrics) is distinct from 'object' then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',v_source);
  end if;
  if (select array_agg(k order by k) from jsonb_object_keys(v_metrics) k) is distinct from v_metric_keys
    or v_metrics->'active_animal_count' is distinct from '0'::jsonb then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',v_source);
  end if;
  for v_row in select key,value from jsonb_each(v_metrics) loop
    if v_row.key in('realized_price_per_kg','break_even_kg','balance_per_animal') and v_row.value='null'::jsonb then continue; end if;
    if jsonb_typeof(v_row.value) is distinct from 'number' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',v_source);
    end if;
  end loop;
  v_snapshot_id:=gen_random_uuid();
  v_expected:=jsonb_build_object('group_name',v_group.nombre,'purpose_code','carne','metrics',v_metrics);
  insert into economics_v2.group_meat_snapshots(id,period_id,granja_id,snapshot_version,payload)
    values(v_snapshot_id,v_source,p_granja_id,'group-meat-snapshot.forward.v3',v_expected) returning * into v_snapshot;
  if not found or row(v_snapshot.id,v_snapshot.period_id,v_snapshot.granja_id,v_snapshot.snapshot_version,v_snapshot.payload)
    is distinct from row(v_snapshot_id,v_source,p_granja_id,'group-meat-snapshot.forward.v3',v_expected)
    or not isfinite(v_snapshot.created_at) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','snapshot_id',v_snapshot_id);
  end if;
  -- Direct final-state verification, without changing the caller's constraint mode.
  if not exists(select 1 from public.animales a where a.id=p_animal_id and to_jsonb(a)=to_jsonb(v_animal))
    or not exists(select 1 from economics_v2.group_animal_acquisition_basis b where b.animal_id=p_animal_id
      and b.granja_id=p_granja_id and to_jsonb(b)=to_jsonb(v_basis))
    or not exists(select 1 from economics_v2.group_occupancy_memberships m where m.id=v_member.id and to_jsonb(m)=to_jsonb(v_member))
    or not exists(select 1 from economics_v2.group_occupancy_periods p where p.id=v_source and to_jsonb(p)=to_jsonb(v_period))
    or not exists(select 1 from economics_v2.group_meat_snapshots s where s.id=v_snapshot_id and to_jsonb(s)=to_jsonb(v_snapshot))
    or economics_v2.calculate_group_period_live_metrics(p_granja_id,v_source) is distinct from v_metrics
    or exists(select 1 from public.mezcla m where m.grupo_id=v_group.id and not group_feed_integrity.is_closed_feed_history(m))
    or exists(select 1 from public.venta_animal where grupo_id=v_group.id or animal_id=any(v_animals))
    or exists(select 1 from economics_v2.group_occupancy_memberships where period_id=v_source
      and (end_position is null or not(position_span<@v_period.position_span)))
    or exists(select 1 from economics_v2.group_period_feed_allocations a left join public.mezcla m on m.id=a.mixture_id
      where a.period_id=v_source and (a.finalized_at is null or m.id is null or not group_feed_integrity.is_closed_feed_history(m)))
    or (select coalesce(jsonb_agg(to_jsonb(a) order by a.id),'[]'::jsonb) from economics_v2.group_acquisition_basis_entries a
      where a.animal_id=any(v_animals)) is distinct from v_entries then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',v_source);
  end if;
  v_result:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'action','exit','animal_id',p_animal_id,'source_period_id',v_source,'destination_period_id',null,
    'membership_event_ids',jsonb_build_array(v_event_id),'effective_on',p_effective_on,'event_position',v_position,
    'source_end_position',v_position,'destination_start_position',null,'basis_entry_ids','[]'::jsonb,
    'basis_before',v_before,'basis_after',0,'source_status','closed','destination_status',null,
    'snapshot_id',v_snapshot_id,'state_version',v_version,'replayed',false);
  -- Receipt completion is LAST; AFTER-storage faults retain their original SQLSTATE.
  update economics_v2.group_occupancy_operations set result=v_result
    where granja_id=p_granja_id and operation_id=p_operation_id returning * into v_operation;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
  end if;
  select * into v_operation from economics_v2.group_occupancy_operations where granja_id=p_granja_id and operation_id=p_operation_id;
  if not found or v_operation.result is distinct from v_result or v_operation.payload_hash is distinct from v_hash
    or v_operation.event_position is distinct from v_position or v_operation.granja_id is distinct from p_granja_id
    or v_operation.operation_id is distinct from p_operation_id then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
  end if;
  return v_result;
end;
$$;

alter function economics_v2.exit_group_meat_closing(uuid,uuid,uuid,date,jsonb) owner to postgres;
revoke execute on function economics_v2.exit_group_meat_closing(uuid,uuid,uuid,date,jsonb)
  from public,anon,authenticated,service_role;
