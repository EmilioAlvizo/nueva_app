-- Migration: add transactional Animales registration RPC and bracelet uniqueness guard.
--
-- Rollback guidance:
-- 1. Drop index `idx_bracelet_unique_per_tipo` from `public.animales`.
-- 2. Drop function `public.registrar_alta_animales(uuid, uuid, uuid, uuid, uuid, date, integer, integer[], text, numeric, text)`.

begin;

set local lock_timeout = '5s';

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
set search_path = ''
as $$
declare
  created_alta public.altas_animales;
  bracelet_count integer := coalesce(array_length(bracelets, 1), 0);
  distinct_bracelet_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required to register animal altas';
  end if;

  if cantidad is null or cantidad <= 0 then
    raise exception 'cantidad must be greater than 0';
  end if;

  if bracelet_count > cantidad then
    raise exception 'bracelets count must be less than or equal to cantidad';
  end if;

  if exists (
    select 1
    from unnest(coalesce(bracelets, '{}'::integer[])) as b(bracelet)
    where b.bracelet is null
       or b.bracelet <= 0
       or b.bracelet > 32767
  ) then
    raise exception 'bracelets must contain only positive small integers';
  end if;

  select count(distinct b.bracelet)
  into distinct_bracelet_count
  from unnest(coalesce(bracelets, '{}'::integer[])) as b(bracelet);

  if distinct_bracelet_count <> bracelet_count then
    raise exception 'bracelets must not contain duplicates';
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
    nullif(trim(proveedor), ''),
    costo_total,
    nullif(trim(notas), ''),
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
      when gs.position <= bracelet_count then bracelets[gs.position]
      else null
    end,
    proposito_id,
    tipo_adquisicion_id,
    fecha_alta,
    null,
    true,
    nullif(trim(notas), ''),
    auth.uid()
  from generate_series(1, cantidad) as gs(position);

  return created_alta;
end;
$$;

create unique index if not exists idx_bracelet_unique_per_tipo
  on public.animales (granja_id, tipo_animal_id, brazalete)
  where brazalete is not null;

commit;
