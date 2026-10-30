-- Private combined forward producer/refresh. Never calls the legacy mixture updater.
-- Fresh meat eligibility permits coexistence/reopening; only the owned source/fact changes.
create or replace function economics_v2.update_group_feed_allocation(
  p_granja_id uuid, p_operation_id uuid, p_period_id uuid, p_mixture_id uuid,
  p_expected_allocation_updated_at timestamptz, p_expected_source_updated_at timestamptz,
  p_expected_source_digest text, p_fecha_inicio date, p_fecha_termino date, p_ingredientes jsonb
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
  v_food uuid;
  v_item jsonb;
  v_category uuid;
  v_quantity numeric;
  v_cost numeric;
  v_sum_quantity numeric := 0;
  v_sum_cost numeric := 0;
  v_categories uuid[] := '{}'::uuid[];
  v_old_categories uuid[];
  v_old_foods uuid[];
  v_recipe jsonb := '[]'::jsonb;
  v_context jsonb;
  v_result jsonb;
  v_version timestamptz;
begin
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
  if p_fecha_inicio is null or not isfinite(p_fecha_inicio) or p_fecha_inicio>current_date
    or (p_fecha_termino is not null and (not isfinite(p_fecha_termino)
      or p_fecha_termino<p_fecha_inicio or p_fecha_termino>current_date)) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','occurred_on',p_mixture_id);
  end if;
  if jsonb_typeof(p_ingredientes) is distinct from 'array' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','ingredientes',p_mixture_id);
  end if;
  if jsonb_array_length(p_ingredientes)=0 then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','ingredientes',p_mixture_id);
  end if;
  -- Normalize scalar input BEFORE hashing, without any mutable category/source reads.
  for v_item in select a.value from jsonb_array_elements(p_ingredientes) a loop
    if jsonb_typeof(v_item) is distinct from 'object' then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','ingredientes',p_mixture_id);
    end if;
    if not v_item ?& array['categoria_id','cantidad_kg','costo_total']
      or (select count(*) from jsonb_object_keys(v_item))<>3 then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','ingredientes',p_mixture_id);
    end if;
    begin
      v_category := nullif(v_item->>'categoria_id','')::uuid;
      v_quantity := nullif(v_item->>'cantidad_kg','')::numeric;
      v_cost := nullif(v_item->>'costo_total','')::numeric;
    exception when invalid_text_representation or numeric_value_out_of_range then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','ingredientes',p_mixture_id);
    end;
    if v_category is null or v_category=any(v_categories) or v_quantity is null or v_quantity<=0
      or v_quantity in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric)
      or v_cost is null or v_cost<0 or v_cost in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric) then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','ingredientes',p_mixture_id);
    end if;
    begin
      v_sum_quantity := v_sum_quantity+v_quantity;
      v_sum_cost := v_sum_cost+v_cost;
    exception when numeric_value_out_of_range then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','ingredientes',p_mixture_id);
    end;
    v_categories := array_append(v_categories,v_category);
    v_recipe := v_recipe||jsonb_build_array(jsonb_build_object(
      'categoria_id',v_category,'cantidad_kg',v_quantity,'costo_total',v_cost));
  end loop;
  v_hash := encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-feed-update.v1',
    'granja_id',p_granja_id,'actor_id',v_actor,'operation_id',p_operation_id,
    'request',jsonb_build_object('action','feed_update','period_id',p_period_id,'mixture_id',p_mixture_id,
      'expected_allocation_updated_at_utc',to_char(p_expected_allocation_updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'expected_source_updated_at_utc',to_char(p_expected_source_updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'expected_source_digest',p_expected_source_digest,'fecha_inicio',p_fecha_inicio,
      'fecha_termino',p_fecha_termino,'ingredientes',v_recipe)))::text,'UTF8')),'hex');
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
      'contract_version','operation_id','mixture_id','period_id','allocation_id','updated_at',
      'component_count','quantity_kg','total_cost','source_digest','replayed']
      or (select count(*) from jsonb_object_keys(v_stored.result))<>11
      or v_stored.result->>'contract_version' is distinct from 'group-economics.forward.v3'
      or v_stored.result->>'operation_id' is distinct from p_operation_id::text
      or v_stored.result->>'mixture_id' is distinct from p_mixture_id::text
      or v_stored.result->>'period_id' is distinct from p_period_id::text
      or v_stored.result->'replayed' is distinct from 'false'::jsonb
      or jsonb_typeof(v_stored.result->'allocation_id') is distinct from 'string'
      or jsonb_typeof(v_stored.result->'updated_at') is distinct from 'string'
      or jsonb_typeof(v_stored.result->'source_digest') is distinct from 'string'
      or jsonb_typeof(v_stored.result->'component_count') is distinct from 'number'
      or jsonb_typeof(v_stored.result->'quantity_kg') is distinct from 'number'
      or jsonb_typeof(v_stored.result->'total_cost') is distinct from 'number' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    -- Replay does not consult mutable periods, sources, categories or facts.
    return v_stored.result||jsonb_build_object('replayed',true);
  end if;

  -- Fresh admission needs current event history, matching the retained header boundary.
  if pg_catalog.current_setting('transaction_isolation')<>'read committed' then
    perform economics_v2.raise_group_writer_error('40001','stale_write','period_id',p_period_id);
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
    if not found then perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_id); end if;
  end loop;
  select p.* into v_period from economics_v2.group_occupancy_periods p
  where p.id=p_period_id and p.granja_id=p_granja_id for update;
  if not found then perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id); end if;
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
  if not found then perform economics_v2.raise_group_writer_error('42501','forbidden','mixture_id',p_mixture_id); end if;
  if v_mixture.grupo_id is distinct from v_source_group then
    perform economics_v2.raise_group_writer_error('40001','stale_write','mixture_id',p_mixture_id);
  end if;
  -- Parent/food FOR UPDATE conflicts with immediate FK key-share checks, including
  -- new component references. Existing components/foods and old/new categories are ordered.
  perform mc.id from public.mezcla_comida mc where mc.mezcla_id=p_mixture_id order by mc.id for update;
  select array_agg(mc.comida_id order by mc.comida_id) into v_old_foods
  from public.mezcla_comida mc where mc.mezcla_id=p_mixture_id;
  perform c.id from public.comida c where c.id=any(v_old_foods) order by c.id for update;
  select array_agg(distinct c.cat_comida_id) into v_old_categories from public.comida c where c.id=any(v_old_foods);
  perform cc.id from public.cat_comida cc where cc.id=any(v_categories||coalesce(v_old_categories,'{}'::uuid[]))
    order by cc.id for share;
  perform t.id from public.tipo_animal t where t.id in (
    select g.tipo_animal_id from public.grupos g where g.id=any(array[v_period_group,v_source_group])) order by t.id for share;
  perform c.id from public.cat_proposito_animal c where c.id=v_period.purpose_id for share;
  -- Purpose metadata precedes its fence, then Group fences in UUID order, as in creation.
  -- Locks only: refusals/replay must not issue fence DML. The real header trigger touches it.
  perform f.entity_id from group_feed_integrity.fences f
  where f.scope='purpose' and f.entity_id=v_period.purpose_id for update;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',p_period_id);
  end if;
  for v_id in select distinct g.id from unnest(array[v_period_group,v_source_group]) g(id) order by g.id loop
    perform f.entity_id from group_feed_integrity.fences f
    where f.scope='group' and f.entity_id=v_id for update;
    if not found then
      -- Pre-boundary metadata cannot be stabilized by silently creating an admission fence.
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',p_period_id);
    end if;
  end loop;
  -- Count ALL open purposes under the fence, not only meat or a stored exemption marker.
  if (select count(*) from economics_v2.group_occupancy_periods p
    where p.granja_id=p_granja_id and p.group_id=v_period.group_id
      and p.closed_on is null and p.end_position is null)<>1 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',p_period_id);
  end if;
  -- The qualified validator rechecks actual same-farm Group/type, owned meat purpose,
  -- finite period/source dates, source version, dedicated components and old digest.
  v_context := economics_v2.validate_group_feed_source(p_granja_id,p_period_id,p_mixture_id,p_expected_source_updated_at);
  if v_context->>'source_digest' is distinct from p_expected_source_digest then
    perform economics_v2.raise_group_writer_error('40001','stale_write','source_digest',p_mixture_id);
  end if;
  -- New-date admission must happen BEFORE any header/component/food DML.
  if p_fecha_inicio<v_period.starts_on
    or exists(select 1 from economics_v2.group_occupancy_events e where e.granja_id=p_granja_id
      and e.period_id=p_period_id and e.effective_on>p_fecha_inicio)
    or exists(select 1 from economics_v2.group_occupancy_periods p where p.granja_id=p_granja_id
      and p.group_id=v_period.group_id and p.purpose_id=v_period.purpose_id and p.starts_on>p_fecha_inicio) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','occurred_on',p_mixture_id);
  end if;
  foreach v_id in array v_categories loop
    if not exists(select 1 from public.cat_comida cc where cc.id=v_id and cc.granja_id=p_granja_id) then
      perform economics_v2.raise_group_writer_error('42501','forbidden','category_id',v_id);
    end if;
    if not exists(select 1 from public.cat_comida cc where cc.id=v_id and cc.granja_id=p_granja_id
      and (cc.activo or cc.id=any(coalesce(v_old_categories,'{}'::uuid[])))) then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','category_id',v_id);
    end if;
  end loop;
  -- The retained date-end trigger can write legacy Cycles. This single-source core
  -- rejects such bindings instead of invoking legacy admission or mutating that history.
  if exists(select 1 from economics_v2.cycle_feeds cf where cf.mezcla_id=p_mixture_id) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;
  v_version := clock_timestamp();
  if v_version<=v_mixture.updated_at then
    perform economics_v2.raise_group_writer_error('40001','stale_write','mixture_id',p_mixture_id);
  end if;
  if v_version<=v_allocation.updated_at then
    perform economics_v2.raise_group_writer_error('40001','stale_write','allocation_id',v_allocation.id);
  end if;

  -- All admissions precede the NEW producer. Immutable farm/Group/creator metadata stays untouched.
  -- One observed real clock advances both versions; never fabricate a +1 timestamp.
  update public.mezcla set fecha_inicio=p_fecha_inicio,fecha_termino=p_fecha_termino,updated_at=v_version
  where id=p_mixture_id and granja_id=p_granja_id returning * into v_mixture;
  if not found or v_mixture.group_feed_meat_exempt is distinct from true
    or v_mixture.fecha_inicio is distinct from p_fecha_inicio
    or v_mixture.fecha_termino is distinct from p_fecha_termino
    or v_mixture.updated_at is distinct from v_version then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;
  delete from public.mezcla_comida where mezcla_id=p_mixture_id and granja_id=p_granja_id;
  -- The locked old source validator already proved these purchases owned and unshared.
  delete from public.comida where id=any(v_old_foods) and granja_id=p_granja_id;
  for v_item in select a.value from jsonb_array_elements(v_recipe) a loop
    v_food := gen_random_uuid();
    -- precio is TOTAL purchase cost; mc.cantidad is actual ingredient kg.
    insert into public.comida(id,granja_id,cat_comida_id,precio,cantidad)
    values(v_food,p_granja_id,(v_item->>'categoria_id')::uuid,(v_item->>'costo_total')::numeric,(v_item->>'cantidad_kg')::numeric);
    insert into public.mezcla_comida(id,granja_id,mezcla_id,comida_id,cantidad)
    values(gen_random_uuid(),p_granja_id,p_mixture_id,v_food,(v_item->>'cantidad_kg')::numeric);
  end loop;
  -- Actual NEW source, not requested totals or a supplied future digest/context.
  v_context := economics_v2.validate_group_feed_source(p_granja_id,p_period_id,p_mixture_id,v_version);
  if (v_context->>'component_count')::integer is distinct from cardinality(v_categories)
    or (v_context->>'quantity_kg')::numeric is distinct from v_sum_quantity
    or (v_context->>'total_cost')::numeric is distinct from v_sum_cost then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;
  update economics_v2.group_period_feed_allocations set occurred_on=(v_context->>'occurred_on')::date,
    source_updated_at=(v_context->>'source_updated_at')::timestamptz,
    component_count=(v_context->>'component_count')::integer,quantity_kg=(v_context->>'quantity_kg')::numeric,
    total_cost=(v_context->>'total_cost')::numeric,source_digest=v_context->>'source_digest',updated_at=v_version
  where id=v_allocation.id and granja_id=p_granja_id and period_id=p_period_id and mixture_id=p_mixture_id
    and updated_at=p_expected_allocation_updated_at and finalized_at is null returning * into v_allocation;
  if not found then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','allocation_id',null);
  end if;
  v_result := jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'mixture_id',v_allocation.mixture_id,'period_id',v_allocation.period_id,'allocation_id',v_allocation.id,
    'updated_at',v_allocation.updated_at,'component_count',v_allocation.component_count,
    'quantity_kg',v_allocation.quantity_kg,'total_cost',v_allocation.total_cost,
    'source_digest',v_allocation.source_digest,'replayed',false);
  -- Completion LAST. Every late error propagates and rolls back source, fact and receipt.
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result,event_position)
  values(p_granja_id,p_operation_id,v_hash,v_result,null);
  return v_result;
end;
$$;

revoke all on function economics_v2.update_group_feed_allocation(uuid,uuid,uuid,uuid,timestamptz,timestamptz,text,date,date,jsonb)
from public,anon,authenticated;
