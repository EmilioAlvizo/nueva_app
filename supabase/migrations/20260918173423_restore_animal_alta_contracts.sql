-- Restore the animal alta RPC and read-view contracts used by the Flutter app.

create or replace function public.registrar_alta_animales(
  granja_id uuid,
  tipo_animal_id uuid,
  grupo_id uuid,
  proposito_id uuid,
  tipo_adquisicion_id uuid,
  fecha_alta date,
  cantidad integer,
  bracelets integer[] default null,
  proveedor text default null,
  costo_total numeric default null,
  notas text default null
)
returns public.altas_animales
language plpgsql
security invoker
set search_path = ''
as $$
declare
  created_alta public.altas_animales;
  bracelet_count integer := coalesce(pg_catalog.array_length(bracelets, 1), 0);
  distinct_bracelet_count integer := 0;
begin
  if auth.uid() is null then
    raise exception using
      errcode = '28000',
      message = 'Authentication required to register animal altas';
  end if;

  if not public.fn_puede_editar_granja(granja_id) then
    raise exception using
      errcode = '42501',
      message = 'Farm access denied for animal alta registration';
  end if;

  if cantidad is null or cantidad <= 0 then
    raise exception using
      errcode = '22023',
      message = 'cantidad must be greater than 0';
  end if;

  if bracelet_count > cantidad then
    raise exception using
      errcode = '22023',
      message = 'bracelets count must be less than or equal to cantidad';
  end if;

  if exists (
    select 1
    from pg_catalog.unnest(coalesce(bracelets, '{}'::integer[])) as b(bracelet)
    where b.bracelet is null
       or b.bracelet <= 0
       or b.bracelet > 32767
  ) then
    raise exception using
      errcode = '22023',
      message = 'bracelets must contain only positive small integers';
  end if;

  select pg_catalog.count(distinct b.bracelet)
  into distinct_bracelet_count
  from pg_catalog.unnest(coalesce(bracelets, '{}'::integer[])) as b(bracelet);

  if distinct_bracelet_count <> bracelet_count then
    raise exception using
      errcode = '22023',
      message = 'bracelets must not contain duplicates';
  end if;

  insert into public.altas_animales (
    granja_id,
    tipo_animal_id,
    grupo_id,
    proposito_id,
    tipo_adquisicion_id,
    fecha_alta,
    cantidad_animales,
    proveedor,
    costo_total,
    notas,
    created_by
  )
  values (
    granja_id,
    tipo_animal_id,
    grupo_id,
    proposito_id,
    tipo_adquisicion_id,
    fecha_alta,
    cantidad,
    nullif(pg_catalog.btrim(proveedor), ''),
    costo_total,
    nullif(pg_catalog.btrim(notas), ''),
    auth.uid()
  )
  returning * into created_alta;

  insert into public.animales (
    granja_id,
    tipo_animal_id,
    grupo_id,
    alta_id,
    brazalete,
    proposito_id,
    tipo_adquisicion_id,
    fecha_adquisicion,
    costo_adquisicion,
    activo,
    notas,
    created_by
  )
  select
    granja_id,
    tipo_animal_id,
    grupo_id,
    created_alta.id,
    case
      when generated.position <= bracelet_count then bracelets[generated.position]
      else null
    end,
    proposito_id,
    tipo_adquisicion_id,
    fecha_alta,
    null,
    true,
    nullif(pg_catalog.btrim(notas), ''),
    auth.uid()
  from pg_catalog.generate_series(1, cantidad) as generated(position);

  return created_alta;
end;
$$;

revoke all on function public.registrar_alta_animales(
  uuid, uuid, uuid, uuid, uuid, date, integer, integer[], text, numeric, text
) from public, anon, authenticated;
grant execute on function public.registrar_alta_animales(
  uuid, uuid, uuid, uuid, uuid, date, integer, integer[], text, numeric, text
) to authenticated, service_role;

create or replace function public.actualizar_alta_animales(
  p_alta_id uuid,
  p_fecha_alta date,
  p_proposito_id uuid default null,
  p_tipo_adquisicion_id uuid default null,
  p_proveedor text default null,
  p_costo_total numeric default null,
  p_notas text default null
)
returns public.altas_animales
language plpgsql
security invoker
set search_path = ''
as $$
declare
  locked_alta public.altas_animales;
  normalized_proveedor text := nullif(
    pg_catalog.btrim(coalesce(p_proveedor, '')),
    ''
  );
  normalized_notas text := nullif(
    pg_catalog.btrim(coalesce(p_notas, '')),
    ''
  );
begin
  if auth.uid() is null then
    raise exception using
      errcode = '28000',
      message = 'Authentication required to update animal altas';
  end if;

  select *
  into locked_alta
  from public.altas_animales as alta
  where alta.id = p_alta_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'alta_id was not found';
  end if;

  if not public.fn_puede_editar_granja(locked_alta.granja_id) then
    raise exception using
      errcode = '42501',
      message = 'Farm access denied for alta update';
  end if;

  update public.altas_animales
  set
    fecha_alta = p_fecha_alta,
    proposito_id = p_proposito_id,
    tipo_adquisicion_id = p_tipo_adquisicion_id,
    proveedor = normalized_proveedor,
    costo_total = p_costo_total,
    notas = normalized_notas
  where id = locked_alta.id
  returning * into locked_alta;

  update public.animales
  set
    fecha_adquisicion = p_fecha_alta,
    proposito_id = p_proposito_id,
    tipo_adquisicion_id = p_tipo_adquisicion_id,
    notas = normalized_notas
  where alta_id = locked_alta.id;

  return locked_alta;
end;
$$;

revoke all on function public.actualizar_alta_animales(
  uuid, date, uuid, uuid, text, numeric, text
) from public, anon, authenticated;
grant execute on function public.actualizar_alta_animales(
  uuid, date, uuid, uuid, text, numeric, text
) to authenticated, service_role;

create or replace function public.eliminar_alta_animales(
  p_alta_id uuid,
  p_delete_bajas boolean default false
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  locked_alta public.altas_animales;
  selected_animal_ids uuid[] := '{}'::uuid[];
  selected_animal_count integer := 0;
  linked_baja_ids uuid[] := '{}'::uuid[];
  linked_baja_count integer := 0;
  unsafe_baja_count integer := 0;
  has_inactive_or_baja boolean := false;
begin
  if auth.uid() is null then
    raise exception using
      errcode = '28000',
      message = 'Authentication required to delete animal altas';
  end if;

  select *
  into locked_alta
  from public.altas_animales as alta
  where alta.id = p_alta_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'alta_id was not found';
  end if;

  if not public.fn_puede_editar_granja(locked_alta.granja_id) then
    raise exception using
      errcode = '42501',
      message = 'Farm access denied for alta deletion';
  end if;

  with selected_animales as (
    select animal.id, animal.activo, animal.baja_id
    from public.animales as animal
    where animal.alta_id = locked_alta.id
    for update
  )
  select
    coalesce(pg_catalog.array_agg(id), '{}'::uuid[]),
    pg_catalog.count(*),
    pg_catalog.bool_or(coalesce(activo, false) = false or baja_id is not null),
    coalesce(
      pg_catalog.array_agg(distinct baja_id) filter (where baja_id is not null),
      '{}'::uuid[]
    ),
    pg_catalog.count(distinct baja_id) filter (where baja_id is not null)
  into
    selected_animal_ids,
    selected_animal_count,
    has_inactive_or_baja,
    linked_baja_ids,
    linked_baja_count
  from selected_animales;

  if selected_animal_count = 0 then
    raise exception using
      errcode = 'P0002',
      message = 'No animals were found for the selected alta';
  end if;

  if has_inactive_or_baja and not p_delete_bajas then
    raise exception using
      errcode = '23514',
      message = 'This alta includes inactive animals or bajas; explicit delete_bajas confirmation is required';
  end if;

  if p_delete_bajas and linked_baja_count > 0 then
    select pg_catalog.count(*)
    into unsafe_baja_count
    from (
      select baja_id
      from public.animales
      where baja_id = any(linked_baja_ids)
      group by baja_id
      having pg_catalog.bool_or(alta_id is distinct from locked_alta.id)
    ) as unsafe_bajas;

    if unsafe_baja_count > 0 then
      raise exception using
        errcode = '23514',
        message = 'One or more bajas also reference animals outside this alta; deletion is not safe';
    end if;
  end if;

  delete from public.animales
  where id = any(selected_animal_ids);

  if p_delete_bajas and linked_baja_count > 0 then
    delete from public.bajas_animales
    where id = any(linked_baja_ids);
  end if;

  delete from public.altas_animales
  where id = locked_alta.id;

  return locked_alta.id;
end;
$$;

revoke all on function public.eliminar_alta_animales(uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.eliminar_alta_animales(uuid, boolean)
  to authenticated, service_role;

create or replace view public.vista_altas_animales
with (security_invoker = true)
as
select
  alta.id,
  alta.granja_id,
  alta.grupo_id,
  alta.tipo_animal_id,
  alta.proposito_id,
  alta.tipo_adquisicion_id,
  alta.fecha_alta,
  alta.proveedor,
  alta.costo_total,
  alta.cantidad_animales,
  alta.created_by,
  alta.created_at,
  alta.notas,
  coalesce(
    pg_catalog.array_agg(animal.brazalete order by animal.brazalete)
      filter (where animal.brazalete is not null),
    '{}'::smallint[]
  ) as brazaletes
from public.altas_animales as alta
left join public.animales as animal on animal.alta_id = alta.id
group by
  alta.id,
  alta.granja_id,
  alta.grupo_id,
  alta.tipo_animal_id,
  alta.proposito_id,
  alta.tipo_adquisicion_id,
  alta.fecha_alta,
  alta.proveedor,
  alta.costo_total,
  alta.cantidad_animales,
  alta.created_by,
  alta.created_at,
  alta.notas;

revoke all on public.vista_altas_animales from public, anon;
grant select on public.vista_altas_animales to authenticated, service_role;

create or replace view public.vista_bajas_animales
with (security_invoker = true)
as
select
  baja.id,
  baja.granja_id,
  baja.tipo_animal_id,
  baja.razon_baja_id,
  baja.fecha_baja,
  baja.importe_total,
  baja.notas,
  baja.created_at,
  baja.created_by,
  baja.cantidad_animales as total_bajas,
  tipo.nombre as tipo_nombre,
  razon.nombre as razon_nombre,
  case
    when pg_catalog.count(distinct grupo.id) = 1 then pg_catalog.min(grupo.nombre)
    else null::text
  end as grupo_nombre,
  pg_catalog.array_agg(animal.brazalete order by animal.brazalete)
    filter (where animal.brazalete is not null) as brazaletes
from public.bajas_animales as baja
join public.tipo_animal as tipo on tipo.id = baja.tipo_animal_id
join public.cat_razon_baja as razon on razon.id = baja.razon_baja_id
left join public.animales as animal on animal.baja_id = baja.id
left join public.grupos as grupo on grupo.id = animal.grupo_id
group by baja.id, tipo.nombre, razon.nombre;

revoke all on public.vista_bajas_animales from public, anon;
grant select on public.vista_bajas_animales to authenticated, service_role;

notify pgrst, 'reload schema';
