-- Migration: add transactional Animales alta delete RPC.
--
-- Rollback guidance:
-- 1. Drop function `public.eliminar_alta_animales(uuid, boolean)`.

begin;

set local lock_timeout = '5s';

create or replace function public.eliminar_alta_animales(
  p_alta_id uuid,
  p_delete_bajas boolean default false
)
returns uuid
language plpgsql
set search_path = public, auth
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
    raise exception 'Authentication required to delete animal altas';
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
    raise exception 'Farm access denied for alta deletion';
  end if;

  with selected_animales as (
    select animal.id, animal.activo, animal.baja_id
    from public.animales as animal
    where animal.alta_id = locked_alta.id
    for update
  )
  select
    coalesce(array_agg(id), '{}'::uuid[]),
    count(*),
    bool_or(coalesce(activo, false) = false or baja_id is not null),
    coalesce(
      array_agg(distinct baja_id) filter (where baja_id is not null),
      '{}'::uuid[]
    ),
    count(distinct baja_id) filter (where baja_id is not null)
  into
    selected_animal_ids,
    selected_animal_count,
    has_inactive_or_baja,
    linked_baja_ids,
    linked_baja_count
  from selected_animales;

  if selected_animal_count = 0 then
    raise exception 'No animals were found for the selected alta';
  end if;

  if has_inactive_or_baja and not p_delete_bajas then
    raise exception 'This alta includes inactive animals or bajas; explicit delete_bajas confirmation is required';
  end if;

  if p_delete_bajas and linked_baja_count > 0 then
    select count(*)
    into unsafe_baja_count
    from (
      select baja_id
      from public.animales
      where baja_id = any(linked_baja_ids)
      group by baja_id
      having bool_or(alta_id is distinct from locked_alta.id)
    ) as unsafe_bajas;

    if unsafe_baja_count > 0 then
      raise exception 'One or more bajas also reference animals outside this alta; deletion is not safe';
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

commit;
