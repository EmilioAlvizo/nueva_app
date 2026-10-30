-- Fresh legacy create only: refuse before source DML or internal fence DML.
-- Existing UUID replay, legacy update/delete and direct-table writes are out of scope.
-- Keep the business creator invoker-only; this private definer can only refuse/return.
create function economics_v2.assert_legacy_feed_create_allowed(
  p_granja_id uuid,
  p_grupo_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $guard$
begin
  -- Independently authorize direct SQL callers before reading private history.
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'An authenticated session is required.';
  end if;
  if not coalesce(public.fn_es_miembro_granja(p_granja_id), false)
     or not coalesce(public.fn_puede_editar_granja(p_granja_id), false) then
    raise exception using errcode = '42501', message = 'Farm editing permission is required.';
  end if;
  if p_grupo_id is null then
    return;
  end if;

  -- The immediate Group foreign keys block new or reassigned period references.
  -- Scope locks to this Group, not the entire farm or unrelated Groups.
  perform g.id
  from public.grupos as g
  where g.id = p_grupo_id and g.granja_id = p_granja_id
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'Group access is not authorized.';
  end if;

  -- Match the existing header admission requirement: fresh statement snapshots.
  if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
    raise exception using errcode = '40001',
      message = 'Feed header writes require a Read Committed transaction';
  end if;

  -- Lock closed periods too: an existing row must not reopen after the check.
  perform p.id
  from economics_v2.group_occupancy_periods as p
  where p.granja_id = p_granja_id and p.group_id = p_grupo_id
  order by p.id
  for share;

  -- Stabilize purpose classification, including currently non-meat purposes.
  perform c.id
  from public.cat_proposito_animal as c
  where exists (
    select 1 from economics_v2.group_occupancy_periods as p
    where p.granja_id = p_granja_id and p.group_id = p_grupo_id
      and p.purpose_id = c.id
  )
  order by c.id
  for share;

  -- Join the existing metadata/header fence without creating or updating it.
  -- Row locks above cover first use when the Group fence does not yet exist.
  perform f.entity_id
  from group_feed_integrity.fences as f
  where f.scope = 'group' and f.entity_id = p_grupo_id
  for update;

  -- Any owned open meat period blocks bypass, even with ambiguous cardinality.
  -- No feature flag gate: disabling rollout must not erase forward history.
  -- Locks last until transaction end. Metadata lock-order conflicts may abort;
  -- concurrency is not proven by the sequential fixture and requires follow-up.
  if exists (
    select 1
    from economics_v2.group_occupancy_periods as p
    join public.cat_proposito_animal as c
      on c.id = p.purpose_id and c.granja_id = p.granja_id
    where p.granja_id = p_granja_id and p.group_id = p_grupo_id
      and p.closed_on is null and p.end_position is null
      and c.codigo_calculo = 'carne'
  ) then
    raise exception using
      errcode = '23514',
      message = 'Legacy feed creation requires the forward Group period path.',
      detail = pg_catalog.jsonb_build_object(
        'contract_version', 'group-economics.forward.v3',
        'code', 'forward_group_period_required',
        'field', 'group_id',
        'entity_id', p_grupo_id
      )::text;
  end if;
end;
$guard$;

-- economics_v2 already grants authenticated schema USAGE, not private table access.
-- Only this independently authorized read guard becomes callable, never producers.
revoke all on function economics_v2.assert_legacy_feed_create_allowed(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function economics_v2.assert_legacy_feed_create_allowed(uuid, uuid)
  to authenticated;

-- Preserve the full retained creator, including its existing messages and grammar.
create or replace function public.crear_mezcla_completa(
  p_granja_id uuid,
  p_mezcla_id uuid,
  p_fecha_inicio date,
  p_grupo_id uuid,
  p_ingredientes jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_existing_farm_id uuid;
  v_existing_created_by uuid;
  v_comida_id uuid;
  v_item jsonb;
  v_categoria_id uuid;
  v_cantidad numeric;
  v_costo numeric;
  v_categorias uuid[] := array[]::uuid[];
begin
  if (select auth.uid()) is null then
    raise exception using
      errcode = '42501',
      message = 'Se requiere una sesión autenticada.';
  end if;

  if not coalesce(public.fn_es_miembro_granja(p_granja_id), false)
     or not coalesce(public.fn_puede_editar_granja(p_granja_id), false) then
    raise exception using
      errcode = '42501',
      message = 'No tienes permisos para editar esta granja.';
  end if;

  if p_mezcla_id is null then
    raise exception using errcode = '22023', message = 'El identificador de mezcla es obligatorio.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_mezcla_id::text, 0)
  );

  select m.granja_id, m.created_by
  into v_existing_farm_id, v_existing_created_by
  from public.mezcla as m
  where m.id = p_mezcla_id;

  if found then
    if v_existing_farm_id <> p_granja_id
       or v_existing_created_by is distinct from (select auth.uid()) then
      raise exception using errcode = '42501', message = 'El identificador de mezcla ya está en uso.';
    end if;
    return p_mezcla_id;
  end if;

  if p_fecha_inicio is null then
    raise exception using
      errcode = '22023',
      message = 'La fecha de inicio es obligatoria.';
  end if;

  perform g.id
  from public.grupos as g
  where g.id = p_grupo_id
    and g.granja_id = p_granja_id
  for key share;

  if not found then
    raise exception using
      errcode = '23503',
      message = 'El grupo no pertenece a la granja.';
  end if;

  if p_ingredientes is null
     or pg_catalog.jsonb_typeof(p_ingredientes) <> 'array'
     or pg_catalog.jsonb_array_length(p_ingredientes) = 0 then
    raise exception using
      errcode = '22023',
      message = 'La mezcla debe contener al menos un ingrediente.';
  end if;

  -- Fresh UUID only, after retained authorization/grammar, before ANY persistent DML.
  perform economics_v2.assert_legacy_feed_create_allowed(p_granja_id, p_grupo_id);

  insert into public.mezcla (
    id,
    granja_id,
    fecha_inicio,
    fecha_termino,
    created_by,
    grupo_id
  )
  values (
    p_mezcla_id,
    p_granja_id,
    p_fecha_inicio,
    null,
    (select auth.uid()),
    p_grupo_id
  );

  for v_item in
    select value
    from pg_catalog.jsonb_array_elements(p_ingredientes)
  loop
    if pg_catalog.jsonb_typeof(v_item) <> 'object' then
      raise exception using
        errcode = '22023',
        message = 'Cada ingrediente debe ser un objeto JSON.';
    end if;

    begin
      v_categoria_id := nullif(v_item ->> 'categoria_id', '')::uuid;
      v_cantidad := nullif(v_item ->> 'cantidad_kg', '')::numeric;
      v_costo := nullif(v_item ->> 'costo_total', '')::numeric;
    exception
      when invalid_text_representation or numeric_value_out_of_range then
        raise exception using
          errcode = '22023',
          message = 'El ingrediente contiene valores inválidos.';
    end;

    if v_categoria_id is null then
      raise exception using
        errcode = '22023',
        message = 'La categoría del ingrediente es obligatoria.';
    end if;

    if v_cantidad is null or v_cantidad <= 0
       or v_cantidad in ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric) then
      raise exception using
        errcode = '22023',
        message = 'La cantidad debe ser mayor que cero.';
    end if;

    if v_costo is null or v_costo < 0
       or v_costo in ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric) then
      raise exception using
        errcode = '22023',
        message = 'El costo total no puede ser negativo.';
    end if;

    if v_categoria_id = any(v_categorias) then
      raise exception using
        errcode = '22023',
        message = 'No se permiten categorías repetidas en una mezcla.';
    end if;

    perform cc.id
    from public.cat_comida as cc
    where cc.id = v_categoria_id
      and cc.granja_id = p_granja_id
      and cc.activo
    for key share;

    if not found then
      raise exception using
        errcode = '23503',
        message = 'La categoría no está activa o no pertenece a la granja.';
    end if;

    v_categorias := pg_catalog.array_append(v_categorias, v_categoria_id);
    v_comida_id := pg_catalog.gen_random_uuid();

    insert into public.comida (
      id,
      granja_id,
      cat_comida_id,
      precio,
      cantidad
    )
    values (
      v_comida_id,
      p_granja_id,
      v_categoria_id,
      v_costo,
      v_cantidad
    );

    insert into public.mezcla_comida (
      id,
      granja_id,
      mezcla_id,
      comida_id,
      cantidad
    )
    values (
      pg_catalog.gen_random_uuid(),
      p_granja_id,
      p_mezcla_id,
      v_comida_id,
      v_cantidad
    );
  end loop;

  return p_mezcla_id;
end;
$function$;

-- Retain the original authenticated-only creator ACL and invoker business boundary.
revoke all on function public.crear_mezcla_completa(uuid, uuid, date, uuid, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.crear_mezcla_completa(uuid, uuid, date, uuid, jsonb)
  to authenticated;
