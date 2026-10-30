-- Legacy UPDATE only: refuse before header, component, food or private fence DML.
-- Keep business writes invoker-only; the independently authorized guard only reads/locks.
create function economics_v2.assert_legacy_feed_update_allowed(
  p_granja_id uuid,
  p_mixture_id uuid,
  p_destination_group_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $guard$
declare
  v_source_group_id uuid;
  v_groups uuid[];
begin
  -- Direct callers must pass authorization before any private history inspection.
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'An authenticated session is required.';
  end if;
  if not coalesce(public.fn_es_miembro_granja(p_granja_id), false)
     or not coalesce(public.fn_puede_editar_granja(p_granja_id), false) then
    raise exception using errcode = '42501', message = 'Farm editing permission is required.';
  end if;

  -- Re-read the actual source Group under the same header lock held by the RPC.
  -- The immediate allocation/source FK also needs KEY SHARE on this header.
  select m.grupo_id into v_source_group_id
  from public.mezcla as m
  where m.id = p_mixture_id and m.granja_id = p_granja_id
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'Mixture access is not authorized.';
  end if;
  v_groups := array[v_source_group_id, p_destination_group_id];

  -- Immediate period/Group FKs stabilize new or reassigned references.
  perform g.id
  from public.grupos as g
  where g.id = any(v_groups) and g.granja_id = p_granja_id
  order by g.id
  for update;
  if not exists (
    select 1 from public.grupos as g
    where g.id = p_destination_group_id and g.granja_id = p_granja_id
  ) or (v_source_group_id is not null and not exists (
    select 1 from public.grupos as g
    where g.id = v_source_group_id and g.granja_id = p_granja_id
  )) then
    raise exception using errcode = '42501', message = 'Group access is not authorized.';
  end if;

  -- VOLATILE queries need fresh statement snapshots, as in header admission.
  if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
    raise exception using errcode = '40001',
      message = 'Feed header writes require a Read Committed transaction';
  end if;

  -- Include closed periods: do not allow an existing row to reopen after checking.
  perform p.id
  from economics_v2.group_occupancy_periods as p
  where p.granja_id = p_granja_id and p.group_id = any(v_groups)
  order by p.id
  for share;

  -- Stabilize every referenced purpose, including currently non-meat classification.
  perform c.id
  from public.cat_proposito_animal as c
  where exists (
    select 1 from economics_v2.group_occupancy_periods as p
    where p.granja_id = p_granja_id and p.group_id = any(v_groups)
      and p.purpose_id = c.id
  )
  order by c.id
  for share;

  -- Join existing Group fences without INSERT/UPDATE, including first-use absence.
  -- Header/Group/period/purpose locks above do not depend on a fence being present.
  perform f.entity_id
  from group_feed_integrity.fences as f
  where f.scope = 'group' and f.entity_id = any(v_groups)
  order by f.entity_id
  for update;

  -- Allocation protection is independent of period closure or current purpose code.
  -- Any owned open meat period blocks either Group; no flag or singleton gate.
  if exists (
    select 1 from economics_v2.group_period_feed_allocations as a
    where a.granja_id = p_granja_id and a.mixture_id = p_mixture_id
  ) or exists (
    select 1
    from economics_v2.group_occupancy_periods as p
    join public.cat_proposito_animal as c
      on c.id = p.purpose_id and c.granja_id = p.granja_id
    where p.granja_id = p_granja_id and p.group_id = any(v_groups)
      and p.closed_on is null and p.end_position is null
      and c.codigo_calculo = 'carne'
  ) then
    raise exception using
      errcode = '23514',
      message = 'Legacy feed update requires the forward Group period path.',
      detail = pg_catalog.jsonb_build_object(
        'contract_version', 'group-economics.forward.v3',
        'code', 'forward_group_period_required',
        'field', 'mixture_id',
        'entity_id', p_mixture_id
      )::text;
  end if;
  -- Locks last until transaction end. Metadata/header lock-order conflicts may abort;
  -- this is not concurrency proof, and no producer or fence writer is invoked here.
end;
$guard$;

-- Existing schema USAGE is sufficient; never expose private tables or core helpers.
revoke all on function economics_v2.assert_legacy_feed_update_allowed(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function economics_v2.assert_legacy_feed_update_allowed(uuid, uuid, uuid)
  to authenticated;

-- Preserve the full retained updater, its original ownership, messages and grammar.
create or replace function public.actualizar_mezcla_completa(
  p_mezcla_id uuid,
  p_granja_id uuid,
  p_expected_updated_at timestamptz,
  p_fecha_inicio date,
  p_fecha_termino date,
  p_grupo_id uuid,
  p_ingredientes jsonb
)
returns void
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_locked_id uuid;
  v_locked_updated_at timestamptz;
  v_old_food_ids uuid[] := array[]::uuid[];
  v_old_category_ids uuid[] := array[]::uuid[];
  v_new_category_ids uuid[] := array[]::uuid[];
  v_comida_id uuid;
  v_item jsonb;
  v_categoria_id uuid;
  v_cantidad numeric;
  v_costo numeric;
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

  select m.id, m.updated_at
  into v_locked_id, v_locked_updated_at
  from public.mezcla as m
  where m.id = p_mezcla_id
    and m.granja_id = p_granja_id
  for update;

  if v_locked_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'La mezcla no existe o no pertenece a la granja.';
  end if;

  if p_expected_updated_at is null
     or v_locked_updated_at is distinct from p_expected_updated_at then
    raise exception using
      errcode = '40001',
      message = 'La mezcla cambió desde que fue abierta. Recarga e intenta nuevamente.';
  end if;

  if p_fecha_inicio is null then
    raise exception using
      errcode = '22023',
      message = 'La fecha de inicio es obligatoria.';
  end if;

  if p_fecha_termino is not null
     and p_fecha_termino < p_fecha_inicio then
    raise exception using
      errcode = '22023',
      message = 'La fecha de término no puede ser anterior al inicio.';
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

  -- After retained validation, before any header/component/food/fence persistent DML.
  perform economics_v2.assert_legacy_feed_update_allowed(p_granja_id, p_mezcla_id, p_grupo_id);

  perform mc.id
  from public.mezcla_comida as mc
  where mc.mezcla_id = p_mezcla_id
  order by mc.id
  for update;

  select
    coalesce(
      pg_catalog.array_agg(mc.comida_id order by mc.comida_id),
      array[]::uuid[]
    ),
    coalesce(
      pg_catalog.array_agg(c.cat_comida_id order by c.cat_comida_id),
      array[]::uuid[]
    )
  into v_old_food_ids, v_old_category_ids
  from public.mezcla_comida as mc
  join public.comida as c
    on c.id = mc.comida_id
  where mc.mezcla_id = p_mezcla_id;

  perform c.id
  from public.comida as c
  where c.id = any(v_old_food_ids)
  order by c.id
  for update;

  if exists (
    select 1
    from public.mezcla_comida as mc
    where mc.comida_id = any(v_old_food_ids)
      and mc.mezcla_id <> p_mezcla_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'La mezcla contiene compras compartidas y no puede actualizarse de forma segura.';
  end if;

  update public.mezcla
  set fecha_inicio = p_fecha_inicio,
      fecha_termino = p_fecha_termino,
      grupo_id = p_grupo_id,
      updated_at = pg_catalog.clock_timestamp()
  where id = p_mezcla_id
    and granja_id = p_granja_id;

  delete from public.mezcla_comida
  where mezcla_id = p_mezcla_id
    and granja_id = p_granja_id;

  delete from public.comida
  where id = any(v_old_food_ids)
    and granja_id = p_granja_id;

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

    if v_categoria_id = any(v_new_category_ids) then
      raise exception using
        errcode = '22023',
        message = 'No se permiten categorías repetidas en una mezcla.';
    end if;

    perform cc.id
    from public.cat_comida as cc
    where cc.id = v_categoria_id
      and cc.granja_id = p_granja_id
      and (
        cc.activo
        or cc.id = any(v_old_category_ids)
      )
    for key share;

    if not found then
      raise exception using
        errcode = '23503',
        message = 'La categoría no está disponible para esta mezcla.';
    end if;

    v_new_category_ids :=
      pg_catalog.array_append(v_new_category_ids, v_categoria_id);
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
end;
$function$;

-- Retain the original authenticated-only updater ACL; no other grants change.
revoke all on function public.actualizar_mezcla_completa(uuid, uuid, timestamptz, date, date, uuid, jsonb)
  from public, anon, authenticated, service_role;
grant execute on function public.actualizar_mezcla_completa(uuid, uuid, timestamptz, date, date, uuid, jsonb)
  to authenticated;
