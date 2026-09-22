create or replace function economics_v2.assign_cycle_animals_impl(
  p_cycle_id uuid,
  p_animal_ids uuid[],
  p_joined_on date
) returns void
language plpgsql
security definer
set search_path = '' as $$
declare
  v_farm_id uuid;
  v_animal_id uuid;
begin
  if p_cycle_id is null then
    raise exception using
      errcode = '22004',
      message = 'A cycle is required';
  end if;
  if p_animal_ids is null or cardinality(p_animal_ids) = 0 then
    raise exception using
      errcode = '22023',
      message = 'At least one animal is required';
  end if;
  if array_position(p_animal_ids, null) is not null then
    raise exception using
      errcode = '22004',
      message = 'Animal identifiers cannot be null';
  end if;
  if cardinality(p_animal_ids) <> (
    select count(distinct animal_id)
    from unnest(p_animal_ids) as selected(animal_id)
  ) then
    raise exception using
      errcode = '22023',
      message = 'Animal identifiers must be unique';
  end if;
  if p_joined_on is null or p_joined_on > current_date then
    raise exception using
      errcode = '22023',
      message = 'A non-future animal membership date is required';
  end if;

  select cycle.granja_id
  into v_farm_id
  from economics_v2.cycles cycle
  where cycle.id = p_cycle_id;

  if v_farm_id is null then
    raise exception using
      errcode = '42501',
      message = 'Cycle membership access denied';
  end if;

  foreach v_animal_id in array p_animal_ids loop
    perform economics_v2.assign_cycle_animal_impl(
      v_farm_id,
      p_cycle_id,
      v_animal_id,
      p_joined_on
    );
  end loop;
end;
$$;

create or replace function public.asignar_animales_ciclo_v2(
  p_cycle_id uuid,
  p_animal_ids uuid[],
  p_joined_on date
) returns void
language sql
security invoker
set search_path = '' as $$
  select economics_v2.assign_cycle_animals_impl(
    p_cycle_id,
    p_animal_ids,
    p_joined_on
  );
$$;

revoke execute on function economics_v2.assign_cycle_animals_impl(uuid, uuid[], date)
from public, anon;
revoke execute on function public.asignar_animales_ciclo_v2(uuid, uuid[], date)
from public, anon;

grant execute on function economics_v2.assign_cycle_animals_impl(uuid, uuid[], date)
to authenticated;
grant execute on function public.asignar_animales_ciclo_v2(uuid, uuid[], date)
to authenticated;
