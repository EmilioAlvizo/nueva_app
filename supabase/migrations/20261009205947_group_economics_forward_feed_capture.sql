-- Private FIRST capture only. No public producer, retarget, update/delete or finalization.
-- Inline feed protocol shares the farm/operation namespace without changing occupancy preparation.
create function economics_v2.capture_group_feed_allocation(
  p_granja_id uuid, p_operation_id uuid, p_period_id uuid, p_mixture_id uuid,
  p_expected_updated_at timestamptz, p_expected_source_digest text
) returns jsonb language plpgsql volatile security invoker set search_path='' as $$
declare
  v_actor uuid;
  v_hash text;
  v_stored economics_v2.group_occupancy_operations%rowtype;
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_mixture public.mezcla%rowtype;
  v_allocation economics_v2.group_period_feed_allocations%rowtype;
  v_period_group uuid;
  v_mixture_group uuid;
  v_group uuid;
  v_context jsonb;
  v_result jsonb;
begin
  -- Authorization uses the actual JWT actor, never source creator or supplied context.
  v_actor := economics_v2.assert_group_writer_actor(p_granja_id);
  if p_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','operation_id',null);
  end if;
  if p_period_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','period_id',null);
  end if;
  if p_mixture_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','mixture_id',null);
  end if;
  if p_expected_updated_at is null or not isfinite(p_expected_updated_at) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','expected_updated_at',p_mixture_id);
  end if;
  if p_expected_source_digest is null or p_expected_source_digest !~ '^[0-9a-f]{64}$' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','source_digest',p_mixture_id);
  end if;
  v_hash := encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-feed-capture.v1',
    'granja_id',p_granja_id,'actor_id',v_actor,'operation_id',p_operation_id,
    'request',jsonb_build_object('action','feed_capture','period_id',p_period_id,'mixture_id',p_mixture_id,
      'expected_updated_at_utc',to_char(p_expected_updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'expected_source_digest',p_expected_source_digest)))::text,'UTF8')),'hex');

  -- Same advisory key as occupancy writers. No reservation and no event-position issuance.
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  select o.* into v_stored from economics_v2.group_occupancy_operations o
  where o.granja_id=p_granja_id and o.operation_id=p_operation_id for update;
  if found then
    -- Domain discriminant makes an occupancy operation a conflict, not a feed replay.
    if v_stored.payload_hash is distinct from v_hash then
      perform economics_v2.raise_group_writer_error('22023','operation_payload_conflict','operation_id',p_operation_id);
    end if;
    if jsonb_typeof(v_stored.result) is distinct from 'object' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    if v_stored.event_position is not null or not v_stored.result ?& array[
      'contract_version','operation_id','mixture_id','period_id','allocation_id','updated_at',
      'component_count','quantity_kg','total_cost','source_digest','replayed']
      or (select count(*) from jsonb_object_keys(v_stored.result))<>11
      or v_stored.result->>'contract_version' is distinct from 'group-economics.forward.v3'
      or v_stored.result->>'operation_id' is distinct from p_operation_id::text
      or v_stored.result->>'mixture_id' is distinct from p_mixture_id::text
      or v_stored.result->>'period_id' is distinct from p_period_id::text
      or v_stored.result->>'source_digest' is distinct from p_expected_source_digest
      or v_stored.result->'replayed' is distinct from 'false'::jsonb
      or jsonb_typeof(v_stored.result->'allocation_id') is distinct from 'string'
      or jsonb_typeof(v_stored.result->'updated_at') is distinct from 'string'
      or jsonb_typeof(v_stored.result->'component_count') is distinct from 'number'
      or jsonb_typeof(v_stored.result->'quantity_kg') is distinct from 'number'
      or jsonb_typeof(v_stored.result->'total_cost') is distinct from 'number' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    -- Historical receipt is returned before any source/period reads, even if now stale/closed.
    return v_stored.result||jsonb_build_object('replayed',true);
  end if;

  -- Derive owned scope before locking; recheck discovered Group pins after waiting.
  select p.* into v_period from economics_v2.group_occupancy_periods p
  where p.id=p_period_id and p.granja_id=p_granja_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id);
  end if;
  select m.* into v_mixture from public.mezcla m
  where m.id=p_mixture_id and m.granja_id=p_granja_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','mixture_id',p_mixture_id);
  end if;
  v_period_group := v_period.group_id;
  v_mixture_group := v_mixture.grupo_id;
  for v_group in select distinct g.id from unnest(array[v_period_group,v_mixture_group]) g(id) order by g.id loop
    perform g.id from public.grupos g where g.id=v_group and g.granja_id=p_granja_id for update;
    if not found then
      perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_group);
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
  select m.* into v_mixture from public.mezcla m
  where m.id=p_mixture_id and m.granja_id=p_granja_id for update;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','mixture_id',p_mixture_id);
  end if;
  if v_mixture.grupo_id is distinct from v_mixture_group then
    perform economics_v2.raise_group_writer_error('40001','stale_write','mixture_id',p_mixture_id);
  end if;
  -- Parent mixture lock serializes this unique source's captures, even before a row exists.
  -- Duplicate refusal precedes source/target Group mismatch: a new operation never moves a fact.
  if exists(select 1 from economics_v2.group_period_feed_allocations a where a.mixture_id=p_mixture_id) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;

  -- FOR UPDATE on the mixture conflicts with immediate component FK key-share checks:
  -- new components/retargets cannot pass their parent check while this capture owns the lock.
  -- Existing components are locked in UUID order, then reread to derive the food lock set.
  perform mc.id from public.mezcla_comida mc where mc.mezcla_id=p_mixture_id order by mc.id for update;
  perform c.id from public.comida c where c.id in (
    select mc.comida_id from public.mezcla_comida mc where mc.mezcla_id=p_mixture_id)
    order by c.id for update;
  -- Food FOR UPDATE also blocks new cross-mixture references via its immediate FK,
  -- stabilizing the dedicated/unshared check, not just ingredient price updates.
  perform cc.id from public.cat_comida cc where cc.id in (
    select c.cat_comida_id from public.comida c where c.id in (
      select mc.comida_id from public.mezcla_comida mc where mc.mezcla_id=p_mixture_id))
    order by cc.id for share;
  -- These metadata locks stabilize ownership/type/purpose checks during source validation.
  perform t.id from public.tipo_animal t where t.id in (
    select g.tipo_animal_id from public.grupos g where g.id=any(array[v_period_group,v_mixture_group]))
    order by t.id for share;
  perform c.id from public.cat_proposito_animal c where c.id=v_period.purpose_id for share;
  -- Independent current-actor validation and actual-source recalculation under owned locks.
  -- No caller-supplied context, economic totals or allocation target is trusted.
  v_context := economics_v2.validate_group_feed_source(p_granja_id,p_period_id,p_mixture_id,p_expected_updated_at);
  if v_context->>'source_digest' is distinct from p_expected_source_digest then
    perform economics_v2.raise_group_writer_error('40001','stale_write','source_digest',p_mixture_id);
  end if;

  insert into economics_v2.group_period_feed_allocations(
    granja_id,period_id,mixture_id,occurred_on,source_updated_at,
    component_count,quantity_kg,total_cost,source_digest,finalized_at)
  values(p_granja_id,p_period_id,p_mixture_id,(v_context->>'occurred_on')::date,
    (v_context->>'source_updated_at')::timestamptz,(v_context->>'component_count')::integer,
    (v_context->>'quantity_kg')::numeric,(v_context->>'total_cost')::numeric,
    v_context->>'source_digest',null) returning * into v_allocation;
  v_result := jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'mixture_id',v_allocation.mixture_id,'period_id',v_allocation.period_id,
    'allocation_id',v_allocation.id,'updated_at',v_allocation.updated_at,
    'component_count',v_allocation.component_count,'quantity_kg',v_allocation.quantity_kg,
    'total_cost',v_allocation.total_cost,'source_digest',v_allocation.source_digest,'replayed',false);
  -- Completed receipt LAST. Any allocation/receipt failure propagates; both writes roll back.
  -- No ON CONFLICT success, reservation row, operation UPDATE or position default is used.
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result,event_position)
  values(p_granja_id,p_operation_id,v_hash,v_result,null);
  return v_result;
end;
$$;

revoke all on function economics_v2.capture_group_feed_allocation(uuid,uuid,uuid,uuid,timestamptz,text)
from public,anon,authenticated;
