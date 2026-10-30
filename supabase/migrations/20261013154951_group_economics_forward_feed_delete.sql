-- Private forward deletion only: no public gateway, legacy delegation or Cycle mutation.
-- Historical receipts survive physical source/fact removal; completion is written last.
create function economics_v2.delete_group_feed_allocation(
  p_granja_id uuid, p_operation_id uuid, p_period_id uuid, p_mixture_id uuid,
  p_expected_allocation_updated_at timestamptz, p_expected_source_updated_at timestamptz,
  p_expected_source_digest text
) returns jsonb language plpgsql volatile security invoker set search_path='' as $$
declare
  v_actor uuid;
  v_hash text;
  v_stored economics_v2.group_occupancy_operations%rowtype;
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_allocation economics_v2.group_period_feed_allocations%rowtype;
  v_mixture public.mezcla%rowtype;
  v_period_group uuid;
  v_source_group uuid;
  v_id uuid;
  v_foods uuid[];
  v_context jsonb;
  v_result jsonb;
  v_affected bigint;
begin
  -- Actual current authorization and scalar grammar precede hashing and replay.
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
  if p_expected_allocation_updated_at is null or not isfinite(p_expected_allocation_updated_at) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','expected_allocation_updated_at',p_mixture_id);
  end if;
  if p_expected_source_updated_at is null or not isfinite(p_expected_source_updated_at) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','expected_source_updated_at',p_mixture_id);
  end if;
  if p_expected_source_digest is null or p_expected_source_digest !~ '^[0-9a-f]{64}$' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','source_digest',p_mixture_id);
  end if;
  v_hash := encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-feed-delete.v1',
    'granja_id',p_granja_id,'actor_id',v_actor,'operation_id',p_operation_id,
    'request',jsonb_build_object('action','feed_delete','period_id',p_period_id,'mixture_id',p_mixture_id,
      'expected_allocation_updated_at_utc',to_char(p_expected_allocation_updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'expected_source_updated_at_utc',to_char(p_expected_source_updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'expected_source_digest',p_expected_source_digest)))::text,'UTF8')),'hex');
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  select o.* into v_stored from economics_v2.group_occupancy_operations o
  where o.granja_id=p_granja_id and o.operation_id=p_operation_id for update;
  if found then
    if v_stored.payload_hash is distinct from v_hash then
      perform economics_v2.raise_group_writer_error('22023','operation_payload_conflict','operation_id',p_operation_id);
    end if;
    if jsonb_typeof(v_stored.result) is distinct from 'object' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    if v_stored.event_position is not null or not v_stored.result ?& array[
      'contract_version','operation_id','mixture_id','period_id','allocation_id','deleted','replayed']
      or (select count(*) from jsonb_object_keys(v_stored.result))<>7
      or v_stored.result->>'contract_version' is distinct from 'group-economics.forward.v3'
      or v_stored.result->>'operation_id' is distinct from p_operation_id::text
      or v_stored.result->>'mixture_id' is distinct from p_mixture_id::text
      or v_stored.result->>'period_id' is distinct from p_period_id::text
      or jsonb_typeof(v_stored.result->'allocation_id') is distinct from 'string'
      or coalesce(v_stored.result->>'allocation_id','') !~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
      or v_stored.result->'deleted' is distinct from 'true'::jsonb
      or v_stored.result->'replayed' is distinct from 'false'::jsonb then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    -- No mutable period/source/fact reads on historical replay; do not rewrite its receipt.
    return v_stored.result||jsonb_build_object('replayed',true);
  end if;

  select p.* into v_period from economics_v2.group_occupancy_periods p
  where p.id=p_period_id and p.granja_id=p_granja_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id);
  end if;
  select m.* into v_mixture from public.mezcla m where m.id=p_mixture_id and m.granja_id=p_granja_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','mixture_id',p_mixture_id);
  end if;
  v_period_group := v_period.group_id;
  v_source_group := v_mixture.grupo_id;
  for v_id in select distinct g.id from unnest(array[v_period_group,v_source_group]) g(id) order by g.id loop
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
  where a.mixture_id=p_mixture_id and a.granja_id=p_granja_id for update;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','allocation_id',p_mixture_id);
  end if;
  if v_allocation.period_id is distinct from p_period_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id);
  end if;
  if v_allocation.finalized_at is not null then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','allocation_id',v_allocation.id);
  end if;
  if v_allocation.updated_at is distinct from p_expected_allocation_updated_at then
    perform economics_v2.raise_group_writer_error('40001','stale_write','allocation_id',v_allocation.id);
  end if;
  select m.* into v_mixture from public.mezcla m where m.id=p_mixture_id and m.granja_id=p_granja_id for update;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','mixture_id',p_mixture_id);
  end if;
  if v_mixture.grupo_id is distinct from v_source_group then
    perform economics_v2.raise_group_writer_error('40001','stale_write','mixture_id',p_mixture_id);
  end if;
  -- Parent/food FOR UPDATE conflicts with immediate FK key-share checks, stabilizing
  -- new references as well as the owned, dedicated purchase set validated below.
  perform mc.id from public.mezcla_comida mc where mc.mezcla_id=p_mixture_id order by mc.id for update;
  select array_agg(mc.comida_id order by mc.comida_id) into v_foods
  from public.mezcla_comida mc where mc.mezcla_id=p_mixture_id;
  perform c.id from public.comida c where c.id=any(v_foods) order by c.id for update;
  perform cc.id from public.cat_comida cc where cc.id in (
    select c.cat_comida_id from public.comida c where c.id=any(v_foods)) order by cc.id for share;
  perform t.id from public.tipo_animal t where t.id in (
    select g.tipo_animal_id from public.grupos g where g.id=any(array[v_period_group,v_source_group])) order by t.id for share;
  perform c.id from public.cat_proposito_animal c where c.id=v_period.purpose_id for share;
  v_context := economics_v2.validate_group_feed_source(p_granja_id,p_period_id,p_mixture_id,p_expected_source_updated_at);
  if v_allocation.source_updated_at is distinct from p_expected_source_updated_at then
    perform economics_v2.raise_group_writer_error('40001','stale_write','mixture_id',p_mixture_id);
  end if;
  if v_context->>'source_digest' is distinct from p_expected_source_digest
    or v_allocation.source_digest is distinct from p_expected_source_digest then
    perform economics_v2.raise_group_writer_error('40001','stale_write','source_digest',p_mixture_id);
  end if;
  -- Reject retained Cycle references BEFORE any DML; never detach or mutate Cycle history.
  if exists(select 1 from economics_v2.cycle_feeds cf where cf.mezcla_id=p_mixture_id) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;
  -- Do not let the header's legacy expense cascade delete unrelated economic records.
  if exists(select 1 from public.legacy_mixture_expenses e where e.mixture_id=p_mixture_id) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;

  -- Explicit child-first deletion; every expected row count is enforced, not silent success.
  delete from economics_v2.group_period_feed_allocations
  where id=v_allocation.id and granja_id=p_granja_id and period_id=p_period_id and mixture_id=p_mixture_id
    and updated_at=p_expected_allocation_updated_at and finalized_at is null;
  get diagnostics v_affected = row_count;
  if v_affected<>1 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','allocation_id',v_allocation.id);
  end if;
  delete from public.mezcla_comida where mezcla_id=p_mixture_id and granja_id=p_granja_id;
  get diagnostics v_affected = row_count;
  if v_affected is distinct from (v_context->>'component_count')::bigint then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;
  delete from public.comida where id=any(v_foods) and granja_id=p_granja_id;
  get diagnostics v_affected = row_count;
  if v_affected is distinct from cardinality(v_foods)::bigint then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;
  delete from public.mezcla where id=p_mixture_id and granja_id=p_granja_id
    and updated_at=p_expected_source_updated_at;
  get diagnostics v_affected = row_count;
  if v_affected<>1 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;
  v_result := jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'mixture_id',p_mixture_id,'period_id',p_period_id,'allocation_id',v_allocation.id,'deleted',true,'replayed',false);
  -- Receipt LAST. No event/basis/sequence writes; all late exceptions propagate atomically.
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result,event_position)
  values(p_granja_id,p_operation_id,v_hash,v_result,null);
  get diagnostics v_affected = row_count;
  if v_affected<>1 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
  end if;
  return v_result;
end;
$$;

revoke all on function economics_v2.delete_group_feed_allocation(uuid,uuid,uuid,uuid,timestamptz,timestamptz,text)
from public,anon,authenticated;
