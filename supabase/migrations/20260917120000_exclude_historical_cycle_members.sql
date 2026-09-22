-- Prevent same-cycle re-entry while retaining active membership exclusion.
create or replace function economics_v2.read_cycle_members_impl(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_cycle economics_v2.cycles;
  v_members jsonb;
  v_candidates jsonb;
begin
  v_cycle := economics_v2.assert_cycle_access_impl(p_granja_id, p_cycle_id, false);

  select coalesce(jsonb_agg(jsonb_build_object(
    'animal_id', animal.id,
    'label', concat(animal_type.nombre, case when animal.brazalete is null then '' else concat(' #', animal.brazalete) end),
    'group_name_snapshot', member.group_name_snapshot,
    'joined_on', member.joined_on,
    'left_on', member.left_on,
    'is_active', member.left_on is null
  ) order by member.joined_on desc, animal.id), '[]'::jsonb)
  into v_members
  from economics_v2.cycle_animals member
  join public.animales animal on animal.id = member.animal_id and animal.granja_id = p_granja_id
  join public.tipo_animal animal_type on animal_type.id = animal.tipo_animal_id
  where member.cycle_id = p_cycle_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'animal_id', animal.id,
    'label', concat(animal_type.nombre, case when animal.brazalete is null then '' else concat(' #', animal.brazalete) end),
    'group_name', animal_group.nombre
  ) order by animal_type.nombre, animal.brazalete nulls last, animal.id), '[]'::jsonb)
  into v_candidates
  from public.animales animal
  join public.tipo_animal animal_type on animal_type.id = animal.tipo_animal_id
  left join public.grupos animal_group on animal_group.id = animal.grupo_id
  where animal.granja_id = p_granja_id
    and animal.proposito_id = v_cycle.proposito_id
    and animal.activo
    and animal.baja_id is null
    and not exists (
      select 1
      from economics_v2.cycle_animals existing
      where existing.animal_id = animal.id
        and (existing.cycle_id = p_cycle_id or existing.left_on is null)
    );

  return jsonb_build_object('members', v_members, 'candidates', v_candidates);
end;
$$;

revoke all on function economics_v2.read_cycle_members_impl(uuid, uuid)
  from public, anon, authenticated;
grant execute on function economics_v2.read_cycle_members_impl(uuid, uuid) to authenticated;
