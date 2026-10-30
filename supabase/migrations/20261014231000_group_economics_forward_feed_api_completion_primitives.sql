-- Pure private completion primitives: no business reads, writes or authorization.
-- Keep the existing core fingerprints, storage, gateways and ACLs unchanged.
create function economics_v2.normalize_group_feed_api_ingredients(
  p_ingredientes jsonb, p_mixture_id uuid
) returns jsonb language plpgsql volatile security invoker set search_path='' as $$
declare
  v_item jsonb;
  v_category uuid;
  v_quantity numeric;
  v_cost numeric;
  v_sum_quantity numeric := 0;
  v_sum_cost numeric := 0;
  v_categories uuid[] := '{}'::uuid[];
  v_recipe jsonb := '[]'::jsonb;
begin
  if pg_catalog.jsonb_typeof(p_ingredientes) is distinct from 'array' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','ingredientes',p_mixture_id);
  end if;
  if pg_catalog.jsonb_array_length(p_ingredientes)=0 then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','ingredientes',p_mixture_id);
  end if;

  -- Match the qualified private UPDATE grammar, including cast and sum refusals.
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
  return v_recipe;
end;
$$;

create function economics_v2.group_feed_api_payload_hash(
  p_operation_kind text,
  p_granja_id uuid,
  p_operation_id uuid,
  p_actor_id uuid,
  p_period_id uuid,
  p_mixture_id uuid,
  p_expected_allocation_updated_at timestamptz,
  p_fecha_inicio date,
  p_fecha_termino date,
  p_grupo_id uuid,
  p_ingredientes jsonb
) returns text language plpgsql volatile security invoker set search_path='' as $$
declare
  v_domain text;
  v_request jsonb;
  v_envelope jsonb;
  v_recipe jsonb;
  v_allocation_utc text;
begin
  if p_operation_kind is null or p_operation_kind not in ('feed_update','feed_delete') then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','operation_kind',null);
  end if;
  if p_granja_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','granja_id',null);
  end if;
  if p_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','operation_id',null);
  end if;
  -- Actor is an opaque identity input, not evidence of authorization.
  if p_actor_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','actor_id',null);
  end if;
  if p_period_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','period_id',null);
  end if;
  if p_mixture_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','mixture_id',null);
  end if;
  if p_expected_allocation_updated_at is null
    or not pg_catalog.isfinite(p_expected_allocation_updated_at) then
    perform economics_v2.raise_group_writer_error(
      '22023','invalid_request','expected_allocation_updated_at',p_mixture_id);
  end if;

  if p_operation_kind='feed_update' then
    -- Session current_date matches core grammar; do not claim immutability.
    if p_fecha_inicio is null or not pg_catalog.isfinite(p_fecha_inicio) or p_fecha_inicio>current_date
      or (p_fecha_termino is not null and (not pg_catalog.isfinite(p_fecha_termino)
        or p_fecha_termino<p_fecha_inicio or p_fecha_termino>current_date)) then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','occurred_on',p_mixture_id);
    end if;
    if p_grupo_id is null then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','group_id',p_mixture_id);
    end if;
    v_recipe := economics_v2.normalize_group_feed_api_ingredients(p_ingredientes,p_mixture_id);
    v_domain := 'group-feed-update-api.v1';
  else
    -- JSON null is a supplied recipe and must not be silently ignored.
    if p_fecha_inicio is not null or p_fecha_termino is not null
      or p_grupo_id is not null or p_ingredientes is not null then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','request',p_mixture_id);
    end if;
    v_domain := 'group-feed-delete-api.v1';
  end if;

  v_allocation_utc := pg_catalog.to_char(
    p_expected_allocation_updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"');
  -- DELETE has exactly four request keys; UPDATE adds exactly four more.
  v_request := pg_catalog.jsonb_build_object(
    'action',p_operation_kind,
    'period_id',p_period_id,
    'mixture_id',p_mixture_id,
    'expected_allocation_updated_at_utc',v_allocation_utc);
  if p_operation_kind='feed_update' then
    v_request := v_request||pg_catalog.jsonb_build_object(
      'fecha_inicio',p_fecha_inicio,
      'fecha_termino',p_fecha_termino,
      'grupo_id',p_grupo_id,
      'ingredientes',v_recipe);
  end if;
  v_envelope := pg_catalog.jsonb_build_object(
    'contract_version','group-economics.forward.v3',
    'operation_domain',v_domain,
    'granja_id',p_granja_id,
    'actor_id',p_actor_id,
    'operation_id',p_operation_id,
    'request',v_request);
  return pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
    economics_v2.canonical_group_request(v_envelope)::text,'UTF8')),'hex');
end;
$$;

alter function economics_v2.normalize_group_feed_api_ingredients(jsonb,uuid) owner to postgres;
alter function economics_v2.group_feed_api_payload_hash(
  text,uuid,uuid,uuid,uuid,uuid,timestamptz,date,date,uuid,jsonb) owner to postgres;

revoke all on function economics_v2.normalize_group_feed_api_ingredients(jsonb,uuid)
  from public,anon,authenticated,service_role;
revoke all on function economics_v2.group_feed_api_payload_hash(
  text,uuid,uuid,uuid,uuid,uuid,timestamptz,date,date,uuid,jsonb)
  from public,anon,authenticated,service_role;
