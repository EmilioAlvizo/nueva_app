-- DELETE gateway only. Retained cores, helpers, guards and ACLs stay unchanged.
-- Completion context binds original predecessors, never current recreated targets.
-- Source inspection is not execution proof; both frozen fixtures remain required.
create function economics_v2.delete_group_feed_impl(
  p_granja_id uuid,
  p_operation_id uuid,
  p_period_id uuid,
  p_mezcla_id uuid,
  p_expected_updated_at timestamptz
) returns jsonb language plpgsql volatile security definer set search_path='' as $implementation$
declare
  v_actor uuid;
  v_public_hash text;
  v_core_hash text;
  v_result_hash text;
  v_result jsonb;
  v_ledger economics_v2.group_occupancy_operations%rowtype;
  v_completion economics_v2.group_feed_api_completions%rowtype;
  v_has_ledger boolean;
  v_has_completion boolean;
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_allocation economics_v2.group_period_feed_allocations%rowtype;
  v_mixture public.mezcla%rowtype;
  v_period_group uuid;
  v_source_group uuid;
  v_id uuid;
  v_predecessor_stamp timestamptz;
  v_predecessor_digest text;
begin
  v_actor := economics_v2.assert_group_writer_actor(p_granja_id);
  v_public_hash := economics_v2.group_feed_api_payload_hash(
    'feed_delete',p_granja_id,p_operation_id,v_actor,p_period_id,p_mezcla_id,
    p_expected_updated_at,null::date,null::date,null::uuid,null::jsonb);
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('group-economics:'||p_granja_id::text,0));
  perform economics_v2.assert_group_writer_actor(p_granja_id);

  -- Immutable namespace first: preserve both FOUND values before mutable admission.
  select o.* into v_ledger from economics_v2.group_occupancy_operations o
    where o.granja_id=p_granja_id and o.operation_id=p_operation_id for update;
  v_has_ledger := found;
  select c.* into v_completion from economics_v2.group_feed_api_completions c
    where c.granja_id=p_granja_id and c.operation_id=p_operation_id for update;
  v_has_completion := found;
  if v_has_ledger and not v_has_completion then
    perform economics_v2.raise_group_writer_error(
      '22023','operation_payload_conflict','operation_id',p_operation_id);
  end if;
  if v_has_completion and not v_has_ledger then
    perform economics_v2.raise_group_writer_error(
      '23514','invariant_violation','operation_id',p_operation_id);
  end if;

  if v_has_ledger then
    if v_completion.operation_kind is distinct from 'feed_delete'
      or v_completion.actor_id is distinct from v_actor
      or v_completion.period_id is distinct from p_period_id
      or v_completion.mixture_id is distinct from p_mezcla_id
      or v_completion.group_id is not null
      or v_completion.expected_allocation_updated_at is distinct from p_expected_updated_at
      or v_completion.public_payload_hash is distinct from v_public_hash then
      perform economics_v2.raise_group_writer_error(
        '22023','operation_payload_conflict','operation_id',p_operation_id);
    end if;
    if v_completion.bridge_version is distinct from 'group-feed-api-completion.v1'
      or v_completion.predecessor_source_updated_at is null
      or not pg_catalog.isfinite(v_completion.predecessor_source_updated_at)
      or v_completion.predecessor_source_digest is null
      or v_completion.predecessor_source_digest !~ '^[0-9a-f]{64}$' then
      perform economics_v2.raise_group_writer_error(
        '23514','invariant_violation','operation_id',p_operation_id);
    end if;
    v_predecessor_stamp := v_completion.predecessor_source_updated_at;
    v_predecessor_digest := v_completion.predecessor_source_digest;
  else
    -- Only fresh admission requires Read Committed and current business targets.
    if pg_catalog.current_setting('transaction_isolation')<>'read committed' then
      perform economics_v2.raise_group_writer_error('40001','stale_write','period_id',p_period_id);
    end if;
    select p.* into v_period from economics_v2.group_occupancy_periods p
      where p.id=p_period_id and p.granja_id=p_granja_id;
    if not found then
      perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id);
    end if;
    select m.* into v_mixture from public.mezcla m
      where m.id=p_mezcla_id and m.granja_id=p_granja_id;
    if not found then
      perform economics_v2.raise_group_writer_error('42501','forbidden','mixture_id',p_mezcla_id);
    end if;
    v_period_group := v_period.group_id;
    v_source_group := v_mixture.grupo_id;

    -- Core lock prefix: Groups ascending, period, allocation, source header.
    for v_id in select distinct g.id
      from pg_catalog.unnest(array[v_period_group,v_source_group]) g(id) order by g.id loop
      perform g.id from public.grupos g where g.id=v_id and g.granja_id=p_granja_id for update;
      if not found then
        perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_id);
      end if;
    end loop;
    select p.* into v_period from economics_v2.group_occupancy_periods p
      where p.id=p_period_id and p.granja_id=p_granja_id for update;
    if not found then
      perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id);
    end if;
    if v_period.group_id is distinct from v_period_group then
      perform economics_v2.raise_group_writer_error('40001','stale_write','period_id',p_period_id);
    end if;
    if v_period.closed_on is not null or v_period.end_position is not null then
      perform economics_v2.raise_group_writer_error('23514','closed_period_immutable','period_id',p_period_id);
    end if;
    select a.* into v_allocation from economics_v2.group_period_feed_allocations a
      where a.mixture_id=p_mezcla_id and a.granja_id=p_granja_id for update;
    if not found then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','allocation_id',p_mezcla_id);
    end if;
    if v_allocation.period_id is distinct from p_period_id then
      perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id);
    end if;
    if v_allocation.finalized_at is not null then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','allocation_id',v_allocation.id);
    end if;
    -- The client supplies the allocation token, never a substitute header clock.
    if v_allocation.updated_at is distinct from p_expected_updated_at then
      perform economics_v2.raise_group_writer_error('40001','stale_write','allocation_id',v_allocation.id);
    end if;
    v_predecessor_stamp := v_allocation.source_updated_at;
    v_predecessor_digest := v_allocation.source_digest;
    select m.* into v_mixture from public.mezcla m
      where m.id=p_mezcla_id and m.granja_id=p_granja_id for update;
    if not found then
      perform economics_v2.raise_group_writer_error('42501','forbidden','mixture_id',p_mezcla_id);
    end if;
    if v_mixture.grupo_id is distinct from v_source_group
      or v_mixture.updated_at is distinct from v_predecessor_stamp then
      perform economics_v2.raise_group_writer_error('40001','stale_write','mixture_id',p_mezcla_id);
    end if;
    if v_mixture.grupo_id is distinct from v_period.group_id then
      perform economics_v2.raise_group_writer_error('42501','forbidden','mixture_id',p_mezcla_id);
    end if;
    -- The actual core locks remaining metadata and validates the CAPTURED digest.
    -- Do not refresh source context or absorb timestamp-preserving price drift.
  end if;

  -- Exact private envelope6/request6, reconstructed from original predecessors.
  v_core_hash := pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
    economics_v2.canonical_group_request(pg_catalog.jsonb_build_object(
      'contract_version','group-economics.forward.v3','operation_domain','group-feed-delete.v1',
      'granja_id',p_granja_id,'actor_id',v_actor,'operation_id',p_operation_id,
      'request',pg_catalog.jsonb_build_object(
        'action','feed_delete','period_id',p_period_id,'mixture_id',p_mezcla_id,
        'expected_allocation_updated_at_utc',pg_catalog.to_char(
          p_expected_updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        'expected_source_updated_at_utc',pg_catalog.to_char(
          v_predecessor_stamp at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        'expected_source_digest',v_predecessor_digest)))::text,'UTF8')),'hex');
  if v_has_ledger then
    -- Bind the stored NON-replayed receipt before historical core delegation.
    v_result_hash := pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
      economics_v2.canonical_group_request(v_ledger.result)::text,'UTF8')),'hex');
    if v_completion.core_payload_hash is distinct from v_core_hash
      or v_ledger.payload_hash is distinct from v_core_hash
      or v_completion.core_result_hash is distinct from v_result_hash
      or v_ledger.event_position is not null then
      perform economics_v2.raise_group_writer_error(
        '23514','invariant_violation','operation_id',p_operation_id);
    end if;
  end if;

  -- Both branches call the real core. Replay validates its exact7 stored receipt
  -- without looking up a deleted target or touching a same-UUID recreation.
  v_result := economics_v2.delete_group_feed_allocation(
    p_granja_id => p_granja_id,
    p_operation_id => p_operation_id,
    p_period_id => p_period_id,
    p_mixture_id => p_mezcla_id,
    p_expected_allocation_updated_at => p_expected_updated_at,
    p_expected_source_updated_at => v_predecessor_stamp,
    p_expected_source_digest => v_predecessor_digest
  );
  if not v_has_ledger then
    select o.* into v_ledger from economics_v2.group_occupancy_operations o
      where o.granja_id=p_granja_id and o.operation_id=p_operation_id for update;
    if not found then
      perform economics_v2.raise_group_writer_error(
        '23514','invariant_violation','operation_id',p_operation_id);
    end if;
    if v_ledger.payload_hash is distinct from v_core_hash
      or v_ledger.event_position is not null
      or v_ledger.result is distinct from v_result
      or pg_catalog.jsonb_typeof(v_result) is distinct from 'object'
      or v_result->'replayed' is distinct from 'false'::jsonb then
      perform economics_v2.raise_group_writer_error(
        '23514','invariant_violation','operation_id',p_operation_id);
    end if;
    v_result_hash := pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
      economics_v2.canonical_group_request(v_ledger.result)::text,'UTF8')),'hex');

    -- Sole gateway DML: append exact14 context AFTER actual core completion.
    -- No backfill/upsert/reservation. Late errors roll back deletion and receipt.
    insert into economics_v2.group_feed_api_completions(
      granja_id,operation_id,bridge_version,operation_kind,actor_id,period_id,mixture_id,group_id,
      expected_allocation_updated_at,predecessor_source_updated_at,predecessor_source_digest,
      public_payload_hash,core_payload_hash,core_result_hash)
    values(p_granja_id,p_operation_id,'group-feed-api-completion.v1','feed_delete',v_actor,
      p_period_id,p_mezcla_id,null::uuid,p_expected_updated_at,v_predecessor_stamp,
      v_predecessor_digest,v_public_hash,v_core_hash,v_result_hash);
    if not found then
      perform economics_v2.raise_group_writer_error(
        '23514','invariant_violation','operation_id',p_operation_id);
    end if;
  end if;
  return v_result;
end;
$implementation$;

create function public.eliminar_mezcla_grupo_v1(
  p_granja_id uuid,
  p_operation_id uuid,
  p_period_id uuid,
  p_mezcla_id uuid,
  p_expected_updated_at timestamptz
) returns jsonb language plpgsql volatile security invoker set search_path='' as $gateway$
begin
  return economics_v2.delete_group_feed_impl(
    p_granja_id => p_granja_id,
    p_operation_id => p_operation_id,
    p_period_id => p_period_id,
    p_mezcla_id => p_mezcla_id,
    p_expected_updated_at => p_expected_updated_at
  );
end;
$gateway$;

alter function economics_v2.delete_group_feed_impl(uuid,uuid,uuid,uuid,timestamptz)
  owner to postgres;
alter function public.eliminar_mezcla_grupo_v1(uuid,uuid,uuid,uuid,timestamptz)
  owner to postgres;

-- Only these two new capabilities change ACLs; cores/helpers/tables stay private.
revoke all on function economics_v2.delete_group_feed_impl(uuid,uuid,uuid,uuid,timestamptz)
  from public,anon,authenticated,service_role;
revoke all on function public.eliminar_mezcla_grupo_v1(uuid,uuid,uuid,uuid,timestamptz)
  from public,anon,authenticated,service_role;
grant execute on function economics_v2.delete_group_feed_impl(uuid,uuid,uuid,uuid,timestamptz)
  to authenticated;
grant execute on function public.eliminar_mezcla_grupo_v1(uuid,uuid,uuid,uuid,timestamptz)
  to authenticated;
