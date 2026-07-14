-- Migration: add transactional Animales alta update RPC.
--
-- Rollback guidance:
-- 1. Drop function `public.actualizar_alta_animales(uuid, date, uuid, uuid, text, numeric, text)`.

begin;

set local lock_timeout = '5s';

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
set search_path = public, auth
as $$
declare
  locked_alta public.altas_animales;
  normalized_proveedor text := nullif(trim(coalesce(p_proveedor, '')), '');
  normalized_notas text := nullif(trim(coalesce(p_notas, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Authentication required to update animal altas';
  end if;

  select *
  into locked_alta
  from public.altas_animales as alta
  where alta.id = p_alta_id
  for update;

  if not found then
    raise exception 'alta_id was not found';
  end if;

  if not exists (
    select 1
    from public.granjas as granja
    where granja.id = locked_alta.granja_id
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
    raise exception 'Farm access denied for alta update';
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

commit;
