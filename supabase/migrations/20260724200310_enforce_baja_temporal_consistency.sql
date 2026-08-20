begin;

set local lock_timeout = '5s';

lock table public.animales in share row exclusive mode;
lock table public.bajas_animales in share row exclusive mode;

do $preflight$
declare
  v_violation record;
begin
  select
    animal.id as animal_id,
    animal.baja_id,
    animal.fecha_adquisicion,
    animal.granja_id as animal_granja_id,
    animal.tipo_animal_id as animal_tipo_animal_id,
    baja.fecha_baja,
    baja.granja_id as baja_granja_id,
    baja.tipo_animal_id as baja_tipo_animal_id
  into v_violation
  from public.animales as animal
  left join public.bajas_animales as baja
    on baja.id = animal.baja_id
  where animal.baja_id is not null
    and (
      baja.id is null
      or baja.fecha_baja is null
      or animal.fecha_adquisicion > baja.fecha_baja
      or animal.granja_id is distinct from baja.granja_id
      or animal.tipo_animal_id is distinct from baja.tipo_animal_id
    )
  order by animal.id
  limit 1;

  if found then
    raise exception
      'Cannot install baja invariants: animal % has an inconsistent baja link %',
      v_violation.animal_id,
      v_violation.baja_id
      using errcode = '23514';
  end if;
end;
$preflight$;

create or replace function public.validar_consistencia_baja_animal()
returns trigger
language plpgsql
volatile
security invoker
set search_path = pg_catalog, public
as $function$
declare
  v_fecha_baja date;
  v_granja_id uuid;
  v_tipo_animal_id uuid;
begin
  if new.baja_id is null then
    return new;
  end if;

  select
    baja.fecha_baja,
    baja.granja_id,
    baja.tipo_animal_id
  into
    v_fecha_baja,
    v_granja_id,
    v_tipo_animal_id
  from public.bajas_animales as baja
  where baja.id = new.baja_id
  for share;

  if not found then
    raise exception
      'baja_id % does not exist or is not visible to the current role',
      new.baja_id
      using errcode = '23514';
  end if;

  if v_fecha_baja is null then
    raise exception 'The linked baja must have a non-null fecha_baja'
      using errcode = '23514';
  end if;

  if new.fecha_adquisicion > v_fecha_baja then
    raise exception
      'Animal acquisition date % cannot be after baja date %',
      new.fecha_adquisicion,
      v_fecha_baja
      using errcode = '23514';
  end if;

  if new.granja_id is distinct from v_granja_id then
    raise exception 'Animal and baja must belong to the same farm'
      using errcode = '23514';
  end if;

  if new.tipo_animal_id is distinct from v_tipo_animal_id then
    raise exception 'Animal and baja must belong to the same animal type'
      using errcode = '23514';
  end if;

  return new;
end;
$function$;

create or replace function public.validar_consistencia_animales_de_baja()
returns trigger
language plpgsql
volatile
security invoker
set search_path = pg_catalog, public
as $function$
begin
  if new.fecha_baja is null then
    raise exception 'fecha_baja must not be null'
      using errcode = '23514';
  end if;

  if new.fecha_baja is not distinct from old.fecha_baja
    and new.granja_id is not distinct from old.granja_id
    and new.tipo_animal_id is not distinct from old.tipo_animal_id
  then
    return new;
  end if;

  if exists (
    select 1
    from public.animales as animal
    where animal.baja_id = old.id
      and (
        animal.fecha_adquisicion > new.fecha_baja
        or animal.granja_id is distinct from new.granja_id
        or animal.tipo_animal_id is distinct from new.tipo_animal_id
      )
  ) then
    raise exception
      'The baja change would invalidate one or more linked animals'
      using errcode = '23514';
  end if;

  return new;
end;
$function$;

drop trigger if exists animales_validar_consistencia_baja
  on public.animales;

create trigger animales_validar_consistencia_baja
before insert
  or update of baja_id, fecha_adquisicion, granja_id, tipo_animal_id
on public.animales
for each row
execute function public.validar_consistencia_baja_animal();

drop trigger if exists bajas_animales_validar_animales_vinculados
  on public.bajas_animales;

create trigger bajas_animales_validar_animales_vinculados
before update of fecha_baja, granja_id, tipo_animal_id
on public.bajas_animales
for each row
execute function public.validar_consistencia_animales_de_baja();

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
volatile
security invoker
set search_path = public, auth
as $function$
declare
  created_baja public.bajas_animales;
  requested_count integer := coalesce(array_length(p_animal_ids, 1), 0);
  selected_count integer := 0;
  selected_type_count integer := 0;
  selected_other_type_count integer := 0;
  future_animal_count integer := 0;
  duplicate_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required to register animal bajas';
  end if;

  if p_fecha_baja is null then
    raise exception 'fecha_baja must not be null';
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

  select count(*) - count(distinct requested.animal_id)
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

  perform animal.id
  from public.animales as animal
  where animal.granja_id = p_granja_id
    and animal.id = any(p_animal_ids)
    and animal.activo = true
    and animal.baja_id is null
  order by animal.id
  for update;

  select
    count(*),
    count(distinct animal.tipo_animal_id),
    count(*) filter (
      where animal.tipo_animal_id <> p_tipo_animal_id
    ),
    count(*) filter (
      where animal.fecha_adquisicion > p_fecha_baja
    )
  into
    selected_count,
    selected_type_count,
    selected_other_type_count,
    future_animal_count
  from public.animales as animal
  where animal.granja_id = p_granja_id
    and animal.id = any(p_animal_ids)
    and animal.activo = true
    and animal.baja_id is null;

  if selected_count <> requested_count then
    raise exception
      'One or more animals are unavailable, inactive, or outside the selected farm';
  end if;

  if selected_type_count <> 1 or selected_other_type_count <> 0 then
    raise exception
      'All selected animals must belong to the requested tipo_animal_id';
  end if;

  if future_animal_count > 0 then
    raise exception
      'One or more animals were acquired after the requested baja date';
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
  set
    activo = false,
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
$function$;

revoke all on function public.registrar_baja_animales(
  uuid, uuid, uuid, date, integer, uuid[], numeric, text
) from public, anon, authenticated, service_role;

grant execute on function public.registrar_baja_animales(
  uuid, uuid, uuid, date, integer, uuid[], numeric, text
) to authenticated, service_role;

revoke all on function public.validar_consistencia_baja_animal()
  from public, anon, authenticated;

revoke all on function public.validar_consistencia_animales_de_baja()
  from public, anon, authenticated;

commit;