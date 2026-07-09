-- Migration: add transactional Animales baja RPC.
--
-- Rollback guidance:
-- 1. Drop function `public.registrar_baja_animales(uuid, uuid, uuid, date, integer, uuid[], numeric, text)`.

begin;

set local lock_timeout = '5s';

create or replace function public.registrar_baja_animales(
  p_granja_id uuid,
  p_tipo_animal_id uuid,
  p_razon_baja_id uuid,
  p_fecha_baja date,
  p_cantidad_animales integer,
  p_animal_ids uuid[],
  p_importe_total numeric default null,
  p_notas text default null
)
returns public.bajas_animales
language plpgsql
set search_path = public, auth
as $$
declare
  created_baja public.bajas_animales;
  requested_count integer := coalesce(array_length(p_animal_ids, 1), 0);
  selected_count integer := 0;
  selected_type_count integer := 0;
  selected_other_type_count integer := 0;
  duplicate_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required to register animal bajas';
  end if;

  if p_cantidad_animales is null or p_cantidad_animales <= 0 then
    raise exception 'cantidad_animales must be greater than 0';
  end if;

  if requested_count = 0 then
    raise exception 'animal_ids must contain at least one animal';
  end if;

  if requested_count <> p_cantidad_animales then
    raise exception 'cantidad_animales must match animal_ids length';
  end if;

  select count(*) - count(distinct animal_id)
  into duplicate_count
  from unnest(p_animal_ids) as requested(animal_id);

  if duplicate_count > 0 then
    raise exception 'animal_ids must not contain duplicates';
  end if;

  if not exists (
    select 1
    from public.granjas as granja
    where granja.id = p_granja_id
      and (
        granja.owner_id = auth.uid()
        or exists (
          select 1
          from public.miembros_granja as miembro
          where miembro.granja_id = granja.id
            and miembro.user_id = auth.uid()
            and miembro.rol in ('owner', 'editor')
        )
      )
  ) then
    raise exception 'Farm access denied for baja registration';
  end if;

  if not exists (
    select 1
    from public.tipo_animal as tipo
    where tipo.id = p_tipo_animal_id
      and tipo.granja_id = p_granja_id
  ) then
    raise exception 'tipo_animal_id does not belong to the selected farm';
  end if;

  if not exists (
    select 1
    from public.cat_razon_baja as razon
    where razon.id = p_razon_baja_id
      and razon.activo = true
      and (razon.granja_id is null or razon.granja_id = p_granja_id)
  ) then
    raise exception 'razon_baja_id is not available for the selected farm';
  end if;

  with selected_animales as (
    select animal.id, animal.tipo_animal_id
    from public.animales as animal
    where animal.granja_id = p_granja_id
      and animal.id = any(p_animal_ids)
      and animal.activo = true
      and animal.baja_id is null
    for update
  )
  select
    count(*),
    count(distinct tipo_animal_id),
    count(*) filter (where tipo_animal_id <> p_tipo_animal_id)
  into selected_count, selected_type_count, selected_other_type_count
  from selected_animales;

  if selected_count <> requested_count then
    raise exception 'One or more animals are unavailable, inactive, or outside the selected farm';
  end if;

  if selected_type_count <> 1 or selected_other_type_count <> 0 then
    raise exception 'All selected animals must belong to the requested tipo_animal_id';
  end if;

  insert into public.bajas_animales (
    granja_id,
    tipo_animal_id,
    razon_baja_id,
    fecha_baja,
    cantidad_animales,
    importe_total,
    notas,
    created_by
  )
  values (
    p_granja_id,
    p_tipo_animal_id,
    p_razon_baja_id,
    p_fecha_baja,
    p_cantidad_animales,
    p_importe_total,
    nullif(trim(p_notas), ''),
    auth.uid()
  )
  returning * into created_baja;

  update public.animales as animal
  set activo = false,
      baja_id = created_baja.id
  where animal.granja_id = p_granja_id
    and animal.id = any(p_animal_ids)
    and animal.activo = true
    and animal.baja_id is null;

  get diagnostics selected_count = row_count;

  if selected_count <> requested_count then
    raise exception 'Failed to link every selected animal to the new baja';
  end if;

  return created_baja;
end;
$$;

commit;
