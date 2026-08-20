create index if not exists idx_cat_comida_granja_activa_nombre
  on public.cat_comida (granja_id, nombre)
  where activo;

create index if not exists idx_comida_cat_comida_id
  on public.comida (cat_comida_id);

create index if not exists idx_comida_granja_id
  on public.comida (granja_id);

create index if not exists idx_mezcla_granja_fecha_inicio
  on public.mezcla (granja_id, fecha_inicio desc);

create index if not exists idx_mezcla_grupo_id
  on public.mezcla (grupo_id);

create index if not exists idx_mezcla_comida_comida_id
  on public.mezcla_comida (comida_id);

alter table public.mezcla
  add column if not exists updated_at timestamptz;

update public.mezcla
set updated_at = coalesce(created_at, pg_catalog.now())
where updated_at is null;

alter table public.mezcla
  alter column updated_at set default pg_catalog.now(),
  alter column updated_at set not null;

do $constraints$
begin
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conname = 'comida_cantidad_finita_positiva'
      and conrelid = 'public.comida'::regclass
  ) then
    alter table public.comida add constraint comida_cantidad_finita_positiva
      check (cantidad > 0 and cantidad not in ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric));
  end if;
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conname = 'comida_precio_finito_no_negativo'
      and conrelid = 'public.comida'::regclass
  ) then
    alter table public.comida add constraint comida_precio_finito_no_negativo
      check (precio is null or (precio >= 0 and precio not in ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric)));
  end if;
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conname = 'mezcla_comida_cantidad_finita_positiva'
      and conrelid = 'public.mezcla_comida'::regclass
  ) then
    alter table public.mezcla_comida add constraint mezcla_comida_cantidad_finita_positiva
      check (cantidad is null or (cantidad > 0 and cantidad not in ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric)));
  end if;
end
$constraints$;

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

comment on function public.crear_mezcla_completa(uuid, uuid, date, uuid, jsonb) is
  'Crea atómica e idempotentemente una mezcla activa y sus compras dedicadas. costo_total representa el precio total de la cantidad ingresada.';

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

comment on function public.actualizar_mezcla_completa(
  uuid,
  uuid,
  timestamptz,
  date,
  date,
  uuid,
  jsonb
) is
  'Actualiza atómicamente una mezcla y reemplaza sólo sus compras dedicadas. Permite conservar categorías inactivas que ya pertenecían a la mezcla.';

create or replace function public.eliminar_mezcla_completa(
  p_granja_id uuid,
  p_mezcla_id uuid
)
returns void
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_locked_id uuid;
  v_food_ids uuid[] := array[]::uuid[];
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

  select m.id
  into v_locked_id
  from public.mezcla as m
  where m.id = p_mezcla_id
    and m.granja_id = p_granja_id
  for update;

  if v_locked_id is null then
    return;
  end if;

  perform mc.id
  from public.mezcla_comida as mc
  where mc.mezcla_id = p_mezcla_id
  order by mc.id
  for update;

  select coalesce(
    pg_catalog.array_agg(mc.comida_id order by mc.comida_id),
    array[]::uuid[]
  )
  into v_food_ids
  from public.mezcla_comida as mc
  where mc.mezcla_id = p_mezcla_id;

  perform c.id
  from public.comida as c
  where c.id = any(v_food_ids)
  order by c.id
  for update;

  if exists (
    select 1
    from public.mezcla_comida as mc
    where mc.comida_id = any(v_food_ids)
      and mc.mezcla_id <> p_mezcla_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'La mezcla contiene compras compartidas y no puede eliminarse de forma segura.';
  end if;

  delete from public.mezcla
  where id = p_mezcla_id
    and granja_id = p_granja_id;

  delete from public.comida
  where id = any(v_food_ids)
    and granja_id = p_granja_id;
end;
$function$;

comment on function public.eliminar_mezcla_completa(uuid, uuid) is
  'Elimina atómicamente una mezcla y únicamente las filas comida dedicadas a esa mezcla.';

create or replace function public.eliminar_categoria_comida_segura(
  p_granja_id uuid,
  p_categoria_id uuid
)
returns void
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_locked_id uuid;
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

  select cc.id
  into v_locked_id
  from public.cat_comida as cc
  where cc.id = p_categoria_id
    and cc.granja_id = p_granja_id
  for update;

  if v_locked_id is null then
    raise exception using
      errcode = 'P0002',
      message = 'La categoría no existe o no pertenece a la granja.';
  end if;

  if exists (
    select 1
    from public.comida as c
    where c.cat_comida_id = p_categoria_id
  ) then
    update public.cat_comida
    set activo = false
    where id = p_categoria_id
      and granja_id = p_granja_id;
  else
    delete from public.cat_comida
    where id = p_categoria_id
      and granja_id = p_granja_id;
  end if;
end;
$function$;

comment on function public.eliminar_categoria_comida_segura(uuid, uuid) is
  'Desactiva categorías con referencias históricas y elimina físicamente sólo las categorías sin referencias.';

revoke all on function public.crear_mezcla_completa(
  uuid,
  uuid,
  date,
  uuid,
  jsonb
) from public, anon, authenticated, service_role;

revoke all on function public.actualizar_mezcla_completa(
  uuid,
  uuid,
  timestamptz,
  date,
  date,
  uuid,
  jsonb
) from public, anon, authenticated, service_role;

revoke all on function public.eliminar_mezcla_completa(
  uuid,
  uuid
) from public, anon, authenticated, service_role;

revoke all on function public.eliminar_categoria_comida_segura(
  uuid,
  uuid
) from public, anon, authenticated, service_role;

grant execute on function public.crear_mezcla_completa(
  uuid,
  uuid,
  date,
  uuid,
  jsonb
) to authenticated;

grant execute on function public.actualizar_mezcla_completa(
  uuid,
  uuid,
  timestamptz,
  date,
  date,
  uuid,
  jsonb
) to authenticated;

grant execute on function public.eliminar_mezcla_completa(
  uuid,
  uuid
) to authenticated;

grant execute on function public.eliminar_categoria_comida_segura(
  uuid,
  uuid
) to authenticated;