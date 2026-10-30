-- Private atomic source/fact creation; no legacy producer or public gateway.
-- Historical completion is read before mutable admission; receipt insertion is LAST.
create function economics_v2.create_group_feed_allocation(
  p_granja_id uuid, p_operation_id uuid, p_period_id uuid, p_mixture_id uuid,
  p_fecha_inicio date, p_grupo_id uuid, p_ingredientes jsonb
) returns jsonb language plpgsql volatile security invoker set search_path='' as $$
declare
  v_actor uuid;
  v_hash text;
  v_stored economics_v2.group_occupancy_operations%rowtype;
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_mixture public.mezcla%rowtype;
  v_allocation economics_v2.group_period_feed_allocations%rowtype;
  v_group uuid;
  v_id uuid;
  v_food uuid;
  v_item jsonb;
  v_category uuid;
  v_quantity numeric;
  v_cost numeric;
  v_sum_quantity numeric := 0;
  v_sum_cost numeric := 0;
  v_categories uuid[] := '{}'::uuid[];
  v_recipe jsonb := '[]'::jsonb;
  v_context jsonb;
  v_result jsonb;
  v_affected bigint;
begin
  -- Current JWT authorization and complete grammar precede namespace conflict/replay.
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
  if p_grupo_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','group_id',null);
  end if;
  if p_fecha_inicio is null or not pg_catalog.isfinite(p_fecha_inicio) or p_fecha_inicio>current_date then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','occurred_on',p_mixture_id);
  end if;
  if pg_catalog.jsonb_typeof(p_ingredientes) is distinct from 'array' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','ingredientes',p_mixture_id);
  end if;
  if pg_catalog.jsonb_array_length(p_ingredientes)=0 then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','ingredientes',p_mixture_id);
  end if;
  for v_item in select a.value from pg_catalog.jsonb_array_elements(p_ingredientes) a loop
    if pg_catalog.jsonb_typeof(v_item) is distinct from 'object' then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','ingredientes',p_mixture_id);
    end if;
    if not v_item ?& array['categoria_id','cantidad_kg','costo_total']
      or (select count(*) from pg_catalog.jsonb_object_keys(v_item))<>3 then
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
    v_categories := pg_catalog.array_append(v_categories,v_category);
    v_recipe := v_recipe||pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'categoria_id',v_category,'cantidad_kg',v_quantity,'costo_total',v_cost));
  end loop;
  v_hash := pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
    economics_v2.canonical_group_request(pg_catalog.jsonb_build_object(
      'contract_version','group-economics.forward.v3','operation_domain','group-feed-create.v1',
      'granja_id',p_granja_id,'actor_id',v_actor,'operation_id',p_operation_id,
      'request',pg_catalog.jsonb_build_object('action','feed_create','period_id',p_period_id,
        'mixture_id',p_mixture_id,'fecha_inicio',p_fecha_inicio,'grupo_id',p_grupo_id,
        'ingredientes',v_recipe)))::text,'UTF8')),'hex');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('group-economics:'||p_granja_id::text,0));
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  select o.* into v_stored from economics_v2.group_occupancy_operations o
  where o.granja_id=p_granja_id and o.operation_id=p_operation_id for update;
  if found then
    if v_stored.payload_hash is distinct from v_hash then
      perform economics_v2.raise_group_writer_error('22023','operation_payload_conflict','operation_id',p_operation_id);
    end if;
    if pg_catalog.jsonb_typeof(v_stored.result) is distinct from 'object' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    if v_stored.event_position is not null or not v_stored.result ?& array[
      'contract_version','operation_id','mixture_id','period_id','allocation_id','updated_at',
      'component_count','quantity_kg','total_cost','source_digest','replayed']
      or (select count(*) from pg_catalog.jsonb_object_keys(v_stored.result))<>11
      or v_stored.result->>'contract_version' is distinct from 'group-economics.forward.v3'
      or v_stored.result->>'operation_id' is distinct from p_operation_id::text
      or v_stored.result->>'mixture_id' is distinct from p_mixture_id::text
      or v_stored.result->>'period_id' is distinct from p_period_id::text
      or v_stored.result->'replayed' is distinct from 'false'::jsonb
      or pg_catalog.jsonb_typeof(v_stored.result->'allocation_id') is distinct from 'string'
      or pg_catalog.jsonb_typeof(v_stored.result->'updated_at') is distinct from 'string'
      or pg_catalog.jsonb_typeof(v_stored.result->'source_digest') is distinct from 'string'
      or pg_catalog.jsonb_typeof(v_stored.result->'component_count') is distinct from 'number'
      or pg_catalog.jsonb_typeof(v_stored.result->'quantity_kg') is distinct from 'number'
      or pg_catalog.jsonb_typeof(v_stored.result->'total_cost') is distinct from 'number' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    -- No fence writes or mutable period/source/category reads on historical replay.
    return v_stored.result||pg_catalog.jsonb_build_object('replayed',true);
  end if;

  select p.* into v_period from economics_v2.group_occupancy_periods p
  where p.id=p_period_id and p.granja_id=p_granja_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id);
  end if;
  if v_period.group_id is distinct from p_grupo_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',p_grupo_id);
  end if;
  v_group := v_period.group_id;
  for v_id in select g.id from pg_catalog.unnest(array[v_group]) g(id) order by g.id loop
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
  if v_period.group_id is distinct from v_group then
    perform economics_v2.raise_group_writer_error('40001','stale_write','period_id',p_period_id);
  end if;
  if v_period.closed_on is not null or v_period.end_position is not null then
    perform economics_v2.raise_group_writer_error('23514','closed_period_immutable','period_id',p_period_id);
  end if;
  -- Purpose row precedes its fence and the Group fence, matching metadata's direction.
  perform c.id from public.cat_proposito_animal c where c.id=v_period.purpose_id order by c.id for share;
  perform t.id from public.tipo_animal t where t.id in (
    select g.tipo_animal_id from public.grupos g where g.id=v_group) order by t.id for share;
  perform cc.id from public.cat_comida cc where cc.id=any(v_categories) order by cc.id for share;
  perform f.entity_id from group_feed_integrity.fences f
  where f.scope='purpose' and f.entity_id=v_period.purpose_id for update;
  -- Lock, never touch, before refusal checks: the header trigger alone increments this fence.
  perform f.entity_id from group_feed_integrity.fences f
  where f.scope='group' and f.entity_id=v_group for update;
  if not found then
    -- Pre-boundary periods without a fence cannot safely establish one during admission.
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',p_period_id);
  end if;
  if not exists(select 1 from public.grupos g join public.tipo_animal t
    on t.id=g.tipo_animal_id and t.granja_id=g.granja_id
    where g.id=v_group and g.granja_id=p_granja_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_group);
  end if;
  if not exists(select 1 from public.cat_proposito_animal c
    where c.id=v_period.purpose_id and c.granja_id=p_granja_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',v_period.purpose_id);
  end if;
  if not exists(select 1 from public.cat_proposito_animal c
    where c.id=v_period.purpose_id and c.granja_id=p_granja_id and c.codigo_calculo='carne') then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','purpose_id',v_period.purpose_id);
  end if;
  -- Fresh VOLATILE query under the metadata Group fence counts ALL open purposes.
  if (select count(*) from economics_v2.group_occupancy_periods p
    where p.granja_id=p_granja_id and p.group_id=v_group
      and p.closed_on is null and p.end_position is null)<>1
    or v_period.starts_on is null or not pg_catalog.isfinite(v_period.starts_on)
    or v_period.starts_on>current_date then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',p_period_id);
  end if;
  if p_fecha_inicio<v_period.starts_on
    or exists(select 1 from economics_v2.group_occupancy_events e where e.granja_id=p_granja_id
      and e.period_id=p_period_id and e.effective_on>p_fecha_inicio)
    or exists(select 1 from economics_v2.group_occupancy_periods p where p.granja_id=p_granja_id
      and p.group_id=v_group and p.purpose_id=v_period.purpose_id and p.starts_on>p_fecha_inicio) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','occurred_on',p_mixture_id);
  end if;
  foreach v_id in array v_categories loop
    if not exists(select 1 from public.cat_comida cc where cc.id=v_id and cc.granja_id=p_granja_id) then
      perform economics_v2.raise_group_writer_error('42501','forbidden','category_id',v_id);
    end if;
    if not exists(select 1 from public.cat_comida cc where cc.id=v_id and cc.granja_id=p_granja_id and cc.activo) then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','category_id',v_id);
    end if;
  end loop;
  if exists(select 1 from public.mezcla m where m.id=p_mixture_id)
    or exists(select 1 from economics_v2.group_period_feed_allocations a where a.mixture_id=p_mixture_id) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;
  if pg_catalog.current_setting('transaction_isolation')<>'read committed' then
    perform economics_v2.raise_group_writer_error('40001','stale_write','period_id',p_period_id);
  end if;

  -- NEW real source only. Server trigger owns the exemption; no sibling header UPDATE.
  insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,fecha_termino,created_by,updated_at)
  values(p_mixture_id,p_granja_id,p_grupo_id,p_fecha_inicio,null,v_actor,pg_catalog.clock_timestamp())
  returning * into v_mixture;
  if not found or v_mixture.group_feed_meat_exempt is distinct from true
    or v_mixture.fecha_termino is not null or v_mixture.grupo_id is distinct from p_grupo_id
    or v_mixture.granja_id is distinct from p_granja_id or v_mixture.created_by is distinct from v_actor
    or v_mixture.fecha_inicio is distinct from p_fecha_inicio then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;
  for v_item in select a.value from pg_catalog.jsonb_array_elements(v_recipe) a loop
    v_food := pg_catalog.gen_random_uuid();
    -- precio is TOTAL purchase cost, not a unit price; mc.cantidad is ingredient kg.
    insert into public.comida(id,granja_id,cat_comida_id,precio,cantidad)
    values(v_food,p_granja_id,(v_item->>'categoria_id')::uuid,
      (v_item->>'costo_total')::numeric,(v_item->>'cantidad_kg')::numeric);
    get diagnostics v_affected = row_count;
    if v_affected<>1 then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','food_id',v_food);
    end if;
    insert into public.mezcla_comida(id,granja_id,mezcla_id,comida_id,cantidad)
    values(pg_catalog.gen_random_uuid(),p_granja_id,p_mixture_id,v_food,(v_item->>'cantidad_kg')::numeric);
    get diagnostics v_affected = row_count;
    if v_affected<>1 then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
    end if;
  end loop;
  -- Recompute actual rows/version/digest; requested totals are never allocation context.
  v_context := economics_v2.validate_group_feed_source(p_granja_id,p_period_id,p_mixture_id,v_mixture.updated_at);
  if (v_context->>'component_count')::integer is distinct from pg_catalog.cardinality(v_categories)
    or (v_context->>'quantity_kg')::numeric is distinct from v_sum_quantity
    or (v_context->>'total_cost')::numeric is distinct from v_sum_cost then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;
  insert into economics_v2.group_period_feed_allocations(
    id,granja_id,period_id,mixture_id,occurred_on,source_updated_at,
    component_count,quantity_kg,total_cost,source_digest,finalized_at,updated_at)
  values(pg_catalog.gen_random_uuid(),p_granja_id,p_period_id,p_mixture_id,(v_context->>'occurred_on')::date,
    (v_context->>'source_updated_at')::timestamptz,(v_context->>'component_count')::integer,
    (v_context->>'quantity_kg')::numeric,(v_context->>'total_cost')::numeric,
    v_context->>'source_digest',null,pg_catalog.clock_timestamp()) returning * into v_allocation;
  if not found or v_allocation.granja_id is distinct from p_granja_id
    or v_allocation.period_id is distinct from p_period_id or v_allocation.mixture_id is distinct from p_mixture_id
    or v_allocation.occurred_on is distinct from (v_context->>'occurred_on')::date
    or v_allocation.source_updated_at is distinct from v_mixture.updated_at
    or v_allocation.component_count is distinct from (v_context->>'component_count')::integer
    or v_allocation.quantity_kg is distinct from (v_context->>'quantity_kg')::numeric
    or v_allocation.total_cost is distinct from (v_context->>'total_cost')::numeric
    or v_allocation.source_digest is distinct from v_context->>'source_digest' or v_allocation.finalized_at is not null then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','allocation_id',p_mixture_id);
  end if;
  v_result := pg_catalog.jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'mixture_id',v_allocation.mixture_id,'period_id',v_allocation.period_id,'allocation_id',v_allocation.id,
    'updated_at',v_allocation.updated_at,'component_count',v_allocation.component_count,
    'quantity_kg',v_allocation.quantity_kg,'total_cost',v_allocation.total_cost,
    'source_digest',v_allocation.source_digest,'replayed',false);
  -- Receipt LAST, NULL position. All late exceptions propagate through atomic rollback.
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result,event_position)
  values(p_granja_id,p_operation_id,v_hash,v_result,null);
  get diagnostics v_affected = row_count;
  if v_affected<>1 then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
  end if;
  return v_result;
end;
$$;

revoke all on function economics_v2.create_group_feed_allocation(uuid,uuid,uuid,uuid,date,uuid,jsonb)
from public,anon,authenticated;
