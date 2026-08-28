create or replace function economics_v2.read_farm_access_impl(
  p_granja_id uuid
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_role text;
  v_enabled boolean;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  select membership.rol, coalesce(flag.economics_v2_enabled, false)
  into v_role, v_enabled
  from public.miembros_granja membership
  left join economics_v2.feature_flags flag
    on flag.granja_id = membership.granja_id
  where membership.granja_id = p_granja_id
    and membership.user_id = v_user_id;

  if v_role is null then
    raise exception using errcode = '42501', message = 'Farm access denied';
  end if;

  return jsonb_build_object(
    'granja_id', p_granja_id,
    'enabled', v_enabled,
    'role', v_role,
    'can_edit', v_role in ('owner', 'editor')
  );
end;
$$;

create or replace function economics_v2.read_cycle_summaries_impl(
  p_granja_id uuid
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if not exists (
    select 1
    from public.miembros_granja membership
    join economics_v2.feature_flags flag
      on flag.granja_id = membership.granja_id
      and flag.economics_v2_enabled
    where membership.granja_id = p_granja_id
      and membership.user_id = v_user_id
      and membership.rol in ('owner', 'editor')
  ) then
    raise exception using errcode = '42501', message = 'Cycle summary access denied';
  end if;

  select coalesce(
    jsonb_agg(summary.row_value order by summary.starts_on desc, summary.cycle_id),
    '[]'::jsonb
  )
  into v_result
  from (
    select
      cycle.id as cycle_id,
      cycle.starts_on,
      jsonb_build_object(
        'cycle_id', cycle.id,
        'granja_id', cycle.granja_id,
        'status', cycle.status,
        'starts_on', cycle.starts_on,
        'ends_on', cycle.ends_on,
        'purpose_id', purpose.id,
        'purpose_name', purpose.nombre,
        'active_animal_count', animal_counts.active_count,
        'exited_animal_count', animal_counts.exited_count,
        'direct_expense_total', expense_totals.total,
        'linked_mixture_count', feed_totals.total,
        'latest_linked_group_name', latest_feed.group_name
      ) as row_value
    from economics_v2.cycles cycle
    join public.cat_proposito_animal purpose on purpose.id = cycle.proposito_id
    cross join lateral (
      select
        count(*) filter (where member.left_on is null)::integer as active_count,
        count(*) filter (where member.left_on is not null)::integer as exited_count
      from economics_v2.cycle_animals member
      where member.cycle_id = cycle.id
    ) animal_counts
    cross join lateral (
      select coalesce(sum(expense.amount), 0) as total
      from economics_v2.cycle_expenses expense
      where expense.cycle_id = cycle.id
        and expense.granja_id = cycle.granja_id
    ) expense_totals
    cross join lateral (
      select count(*)::integer as total
      from economics_v2.cycle_feeds feed
      where feed.cycle_id = cycle.id
        and feed.granja_id = cycle.granja_id
    ) feed_totals
    left join lateral (
      select animal_group.nombre as group_name
      from economics_v2.cycle_feeds feed
      join public.mezcla mixture
        on mixture.id = feed.mezcla_id
        and mixture.granja_id = cycle.granja_id
      join public.grupos animal_group
        on animal_group.id = mixture.grupo_id
        and animal_group.granja_id = cycle.granja_id
      where feed.cycle_id = cycle.id
        and feed.granja_id = cycle.granja_id
      order by feed.starts_on desc, feed.id desc
      limit 1
    ) latest_feed on true
    where cycle.granja_id = p_granja_id
  ) summary;

  return v_result;
end;
$$;

create or replace function economics_v2.create_cycle_with_dates_impl(
  p_granja_id uuid,
  p_proposito_id uuid,
  p_starts_on date,
  p_ends_on date
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_cycle_id uuid;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if p_starts_on is null
    or (p_ends_on is not null and p_ends_on < p_starts_on) then
    raise exception using errcode = '22023', message = 'A valid cycle date range is required';
  end if;
  if not exists (
    select 1
    from public.miembros_granja membership
    join economics_v2.feature_flags flag
      on flag.granja_id = membership.granja_id
      and flag.economics_v2_enabled
    where membership.granja_id = p_granja_id
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
      and (purpose.granja_id is null or purpose.granja_id = p_granja_id)
  ) then
    raise exception using errcode = '22023', message = 'A supported farm purpose is required';
  end if;

  insert into economics_v2.cycles (
    granja_id,
    proposito_id,
    starts_on,
    ends_on,
    status,
    created_by
  ) values (
    p_granja_id,
    p_proposito_id,
    p_starts_on,
    p_ends_on,
    'open',
    v_user_id
  ) returning id into v_cycle_id;

  return v_cycle_id;
end;
$$;

create or replace function public.obtener_acceso_ciclos_v2(
  p_granja_id uuid
) returns jsonb
language sql security invoker set search_path = '' as $$
  select economics_v2.read_farm_access_impl(p_granja_id);
$$;

create or replace function public.listar_resumen_ciclos_v2(
  p_granja_id uuid
) returns jsonb
language sql security invoker set search_path = '' as $$
  select economics_v2.read_cycle_summaries_impl(p_granja_id);
$$;

create or replace function public.crear_ciclo_v2_con_fechas(
  p_granja_id uuid,
  p_proposito_id uuid,
  p_starts_on date,
  p_ends_on date
) returns uuid
language sql security invoker set search_path = '' as $$
  select economics_v2.create_cycle_with_dates_impl(
    p_granja_id,
    p_proposito_id,
    p_starts_on,
    p_ends_on
  );
$$;

revoke all on function economics_v2.read_farm_access_impl(uuid) from public, anon, authenticated;
revoke all on function economics_v2.read_cycle_summaries_impl(uuid) from public, anon, authenticated;
revoke all on function economics_v2.create_cycle_with_dates_impl(uuid, uuid, date, date) from public, anon, authenticated;
revoke all on function public.obtener_acceso_ciclos_v2(uuid) from public, anon, authenticated;
revoke all on function public.listar_resumen_ciclos_v2(uuid) from public, anon, authenticated;
revoke all on function public.crear_ciclo_v2_con_fechas(uuid, uuid, date, date) from public, anon, authenticated;

grant execute on function economics_v2.read_farm_access_impl(uuid) to authenticated;
grant execute on function economics_v2.read_cycle_summaries_impl(uuid) to authenticated;
grant execute on function economics_v2.create_cycle_with_dates_impl(uuid, uuid, date, date) to authenticated;
grant execute on function public.obtener_acceso_ciclos_v2(uuid) to authenticated;
grant execute on function public.listar_resumen_ciclos_v2(uuid) to authenticated;
grant execute on function public.crear_ciclo_v2_con_fechas(uuid, uuid, date, date) to authenticated;
