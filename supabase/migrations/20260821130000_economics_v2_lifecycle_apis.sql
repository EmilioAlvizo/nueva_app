create or replace function economics_v2.create_cycle_impl(
  p_granja_id uuid,
  p_proposito_id uuid,
  p_starts_on date
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_farm_id uuid;
  v_cycle_id uuid;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if p_starts_on is null then
    raise exception using errcode = '22023', message = 'A cycle start date is required';
  end if;

  select farm.id
  into v_farm_id
  from public.granjas farm
  where farm.id = p_granja_id
  for key share;

  if v_farm_id is null
    or not exists (
      select 1
      from public.miembros_granja membership
      join economics_v2.feature_flags flag
        on flag.granja_id = membership.granja_id and flag.economics_v2_enabled
      where membership.granja_id = v_farm_id
        and membership.user_id = v_user_id
        and membership.rol in ('owner', 'editor')
    ) then
    raise exception using errcode = '42501', message = 'Cycle creation access denied';
  end if;

  if not exists (
    select 1
    from public.cat_proposito_animal purpose
    where purpose.id = p_proposito_id
      and purpose.activo
      and purpose.codigo_calculo in ('postura', 'carne', 'ornamental')
      and (purpose.granja_id is null or purpose.granja_id = v_farm_id)
  ) then
    raise exception using errcode = '22023', message = 'A supported farm purpose is required';
  end if;

  insert into economics_v2.cycles (granja_id, proposito_id, starts_on, created_by)
  values (v_farm_id, p_proposito_id, p_starts_on, v_user_id)
  returning id into v_cycle_id;

  return v_cycle_id;
end;
$$;

create or replace function economics_v2.assign_cycle_animal_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_animal_id uuid,
  p_joined_on date
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_farm_id uuid;
  v_purpose_id uuid;
  v_starts_on date;
  v_ends_on date;
  v_animal_farm_id uuid;
  v_animal_purpose_id uuid;
  v_animal_active boolean;
  v_animal_baja_id uuid;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if p_joined_on is null then
    raise exception using errcode = '22023', message = 'An animal membership start date is required';
  end if;

  select cycle.granja_id, cycle.proposito_id, cycle.starts_on, cycle.ends_on
  into v_farm_id, v_purpose_id, v_starts_on, v_ends_on
  from economics_v2.cycles cycle
  where cycle.id = p_cycle_id and cycle.granja_id = p_granja_id and cycle.status = 'open'
  for update;

  if v_farm_id is null
    or not exists (
      select 1
      from public.miembros_granja membership
      join economics_v2.feature_flags flag
        on flag.granja_id = membership.granja_id and flag.economics_v2_enabled
      where membership.granja_id = v_farm_id
        and membership.user_id = v_user_id
        and membership.rol in ('owner', 'editor')
    ) then
    raise exception using errcode = '42501', message = 'Cycle membership access denied';
  end if;

  select animal.granja_id, animal.proposito_id, animal.activo, animal.baja_id
  into v_animal_farm_id, v_animal_purpose_id, v_animal_active, v_animal_baja_id
  from public.animales animal
  where animal.id = p_animal_id
  for update;

  if v_animal_farm_id is distinct from v_farm_id then
    raise exception using errcode = '42501', message = 'Animal must belong to the cycle farm';
  end if;
  if not v_animal_active or v_animal_baja_id is not null then
    raise exception using errcode = '22023', message = 'Animal must be active and without a baja';
  end if;
  if v_animal_purpose_id is distinct from v_purpose_id then
    raise exception using errcode = '22023', message = 'Animal purpose must match the cycle purpose';
  end if;
  if p_joined_on < v_starts_on or (v_ends_on is not null and p_joined_on >= v_ends_on) then
    raise exception using errcode = '22023', message = 'Animal membership must be within the cycle window';
  end if;
  if exists (
    select 1
    from economics_v2.cycle_animals membership
    where membership.animal_id = p_animal_id
      and membership.left_on is null
      and membership.cycle_id <> p_cycle_id
  ) then
    raise exception using errcode = '23505', message = 'Animal already has an active cycle membership';
  end if;

  insert into economics_v2.cycle_animals (cycle_id, animal_id, joined_on)
  values (p_cycle_id, p_animal_id, p_joined_on);
end;
$$;

create or replace function economics_v2.record_cycle_expense_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_occurred_on date,
  p_amount numeric,
  p_note text
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_farm_id uuid;
  v_starts_on date;
  v_ends_on date;
  v_expense_id uuid;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if p_occurred_on is null or p_amount is null or p_amount < 0 then
    raise exception using errcode = '22023', message = 'A non-negative dated cycle expense is required';
  end if;

  select cycle.granja_id, cycle.starts_on, cycle.ends_on
  into v_farm_id, v_starts_on, v_ends_on
  from economics_v2.cycles cycle
  where cycle.id = p_cycle_id and cycle.granja_id = p_granja_id and cycle.status = 'open'
  for update;

  if v_farm_id is null
    or not exists (
      select 1
      from public.miembros_granja membership
      join economics_v2.feature_flags flag
        on flag.granja_id = membership.granja_id and flag.economics_v2_enabled
      where membership.granja_id = v_farm_id
        and membership.user_id = v_user_id
        and membership.rol in ('owner', 'editor')
    ) then
    raise exception using errcode = '42501', message = 'Cycle expense access denied';
  end if;
  if p_occurred_on < v_starts_on or (v_ends_on is not null and p_occurred_on >= v_ends_on) then
    raise exception using errcode = '22023', message = 'Cycle expense must be within the cycle window';
  end if;

  insert into economics_v2.cycle_expenses (
    cycle_id, granja_id, occurred_on, amount, note, created_by
  ) values (
    p_cycle_id, v_farm_id, p_occurred_on, p_amount, nullif(trim(p_note), ''), v_user_id
  ) returning id into v_expense_id;

  return v_expense_id;
end;
$$;

create or replace function economics_v2.link_cycle_feed_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_mezcla_id uuid,
  p_starts_on date,
  p_ends_on date
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_farm_id uuid;
  v_cycle_starts_on date;
  v_cycle_ends_on date;
  v_mix_farm_id uuid;
  v_feed_id uuid;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if p_mezcla_id is null or p_starts_on is null or (p_ends_on is not null and p_ends_on < p_starts_on) then
    raise exception using errcode = '22023', message = 'A valid explicit feed interval is required';
  end if;

  select cycle.granja_id, cycle.starts_on, cycle.ends_on
  into v_farm_id, v_cycle_starts_on, v_cycle_ends_on
  from economics_v2.cycles cycle
  where cycle.id = p_cycle_id and cycle.granja_id = p_granja_id and cycle.status = 'open'
  for update;

  if v_farm_id is null
    or not exists (
      select 1
      from public.miembros_granja membership
      join economics_v2.feature_flags flag
        on flag.granja_id = membership.granja_id and flag.economics_v2_enabled
      where membership.granja_id = v_farm_id
        and membership.user_id = v_user_id
        and membership.rol in ('owner', 'editor')
    ) then
    raise exception using errcode = '42501', message = 'Cycle feed access denied';
  end if;
  if p_starts_on < v_cycle_starts_on
    or (v_cycle_ends_on is not null and (p_starts_on >= v_cycle_ends_on or p_ends_on is null or p_ends_on > v_cycle_ends_on)) then
    raise exception using errcode = '22023', message = 'Feed link must be within the cycle window';
  end if;

  select mix.granja_id
  into v_mix_farm_id
  from public.mezcla mix
  where mix.id = p_mezcla_id
  for key share;

  if v_mix_farm_id is distinct from v_farm_id then
    raise exception using errcode = '42501', message = 'Feed mix must belong to the cycle farm';
  end if;

  insert into economics_v2.cycle_feeds (
    cycle_id, granja_id, mezcla_id, starts_on, ends_on, created_by
  ) values (
    p_cycle_id, v_farm_id, p_mezcla_id, p_starts_on, p_ends_on, v_user_id
  ) returning id into v_feed_id;

  return v_feed_id;
end;
$$;

drop function if exists economics_v2.create_cycle_impl();
drop function if exists economics_v2.assign_cycle_animal_impl();
drop function if exists economics_v2.record_cycle_expense_impl();
drop function if exists economics_v2.link_cycle_feed_impl();

create or replace function public.crear_ciclo_v2(
  p_granja_id uuid,
  p_proposito_id uuid,
  p_starts_on date
) returns uuid
language sql security invoker set search_path = '' as $$
  select economics_v2.create_cycle_impl(p_granja_id, p_proposito_id, p_starts_on);
$$;

create or replace function public.asignar_animal_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_animal_id uuid,
  p_joined_on date
) returns void
language sql security invoker set search_path = '' as $$
  select economics_v2.assign_cycle_animal_impl(p_granja_id, p_cycle_id, p_animal_id, p_joined_on);
$$;

create or replace function public.registrar_gasto_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_occurred_on date,
  p_amount numeric,
  p_note text
) returns uuid
language sql security invoker set search_path = '' as $$
  select economics_v2.record_cycle_expense_impl(p_granja_id, p_cycle_id, p_occurred_on, p_amount, p_note);
$$;

create or replace function public.vincular_alimento_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_mezcla_id uuid,
  p_starts_on date,
  p_ends_on date
) returns uuid
language sql security invoker set search_path = '' as $$
  select economics_v2.link_cycle_feed_impl(p_granja_id, p_cycle_id, p_mezcla_id, p_starts_on, p_ends_on);
$$;

revoke execute on function economics_v2.create_cycle_impl(uuid, uuid, date) from public, anon;
revoke execute on function economics_v2.assign_cycle_animal_impl(uuid, uuid, uuid, date) from public, anon;
revoke execute on function economics_v2.record_cycle_expense_impl(uuid, uuid, date, numeric, text) from public, anon;
revoke execute on function economics_v2.link_cycle_feed_impl(uuid, uuid, uuid, date, date) from public, anon;
revoke execute on function public.crear_ciclo_v2(uuid, uuid, date) from public, anon;
revoke execute on function public.asignar_animal_ciclo_v2(uuid, uuid, uuid, date) from public, anon;
revoke execute on function public.registrar_gasto_ciclo_v2(uuid, uuid, date, numeric, text) from public, anon;
revoke execute on function public.vincular_alimento_ciclo_v2(uuid, uuid, uuid, date, date) from public, anon;

grant execute on function economics_v2.create_cycle_impl(uuid, uuid, date) to authenticated;
grant execute on function economics_v2.assign_cycle_animal_impl(uuid, uuid, uuid, date) to authenticated;
grant execute on function economics_v2.record_cycle_expense_impl(uuid, uuid, date, numeric, text) to authenticated;
grant execute on function economics_v2.link_cycle_feed_impl(uuid, uuid, uuid, date, date) to authenticated;
grant execute on function public.crear_ciclo_v2(uuid, uuid, date) to authenticated;
grant execute on function public.asignar_animal_ciclo_v2(uuid, uuid, uuid, date) to authenticated;
grant execute on function public.registrar_gasto_ciclo_v2(uuid, uuid, date, numeric, text) to authenticated;
grant execute on function public.vincular_alimento_ciclo_v2(uuid, uuid, uuid, date, date) to authenticated;
