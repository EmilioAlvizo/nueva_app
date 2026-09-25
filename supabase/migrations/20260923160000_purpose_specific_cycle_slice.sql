-- Purpose-specific feed, projection, sale, and settlement contracts.
-- Public APIs remain fixed-search-path invokers. Privileged implementations
-- remain fixed-search-path definers and perform their own farm authorization.

with ordered_mixtures as (
  select
    mixture.id,
    lead(mixture.fecha_inicio) over (
      partition by mixture.grupo_id
      order by mixture.fecha_inicio, mixture.id
    ) as next_start
  from public.mezcla mixture
  where mixture.grupo_id is not null
), duplicate_active as (
  select ordered.id, ordered.next_start
  from ordered_mixtures ordered
  join public.mezcla mixture on mixture.id = ordered.id
  where mixture.fecha_termino is null
    and ordered.next_start is not null
)
update public.mezcla mixture
set fecha_termino = duplicate_active.next_start,
    updated_at = now()
from duplicate_active
where mixture.id = duplicate_active.id;

create unique index if not exists mezcla_one_active_per_group_idx
  on public.mezcla (grupo_id)
  where grupo_id is not null and fecha_termino is null;

create or replace function public.enforce_group_active_mixture()
returns trigger
language plpgsql
security definer
set search_path = '' as $$
declare
  v_later_start date;
begin
  if new.grupo_id is null or new.fecha_termino is not null then
    return new;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.grupo_id::text, 0)
  );

  if not exists (
    select 1
    from public.grupos animal_group
    where animal_group.id = new.grupo_id
      and animal_group.granja_id = new.granja_id
  ) then
    raise exception using
      errcode = '23503',
      message = 'Feed mixture group must belong to the same farm';
  end if;

  select mixture.fecha_inicio
  into v_later_start
  from public.mezcla mixture
  where mixture.grupo_id = new.grupo_id
    and mixture.granja_id = new.granja_id
    and mixture.fecha_termino is null
    and mixture.id <> new.id
    and mixture.fecha_inicio > new.fecha_inicio
  order by mixture.fecha_inicio, mixture.id
  limit 1;

  if v_later_start is not null then
    raise exception using
      errcode = '22023',
      message = 'An active mixture cannot start before the current group mixture';
  end if;

  update public.mezcla mixture
  set fecha_termino = new.fecha_inicio,
      updated_at = now()
  where mixture.grupo_id = new.grupo_id
    and mixture.granja_id = new.granja_id
    and mixture.fecha_termino is null
    and mixture.id <> new.id;

  return new;
end;
$$;

drop trigger if exists mezcla_one_active_per_group on public.mezcla;
create trigger mezcla_one_active_per_group
before insert or update of grupo_id, fecha_inicio, fecha_termino
on public.mezcla
for each row execute function public.enforce_group_active_mixture();

revoke all on function public.enforce_group_active_mixture()
from public, anon, authenticated;

-- Legacy forecasts and immutable final settlement snapshots remain untouched.
-- The v3 APIs expose and update only the current compatible posture forecast;
-- older rows stay preserved as historical data instead of being deleted.

create or replace function economics_v2.project_scenario_v2_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_assumptions jsonb
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_cycle economics_v2.cycles;
  v_purpose_code text;
  v_as_of date := current_date;
  v_expected_unit_price numeric;
  v_production_per_day numeric;
  v_feed_rate numeric;
  v_other_costs numeric;
  v_available_feed_kg numeric;
  v_feed_cost numeric;
  v_feed_count integer;
  v_historical_bird_days numeric;
  v_consumed_kg numeric;
  v_remaining_kg numeric;
  v_active_birds integer;
  v_elapsed_days integer;
  v_remaining_days integer;
  v_projected_horizon_days integer;
  v_expected_end_exclusive date;
  v_weighted_average_birds numeric;
begin
  v_cycle := economics_v2.assert_cycle_access_impl(
    p_granja_id,
    p_cycle_id,
    false
  );

  select purpose.codigo_calculo
  into v_purpose_code
  from public.cat_proposito_animal purpose
  where purpose.id = v_cycle.proposito_id;

  if v_purpose_code <> 'postura' then
    raise exception using
      errcode = '22023',
      message = 'Current projections are supported only for posture cycles';
  end if;
  if p_assumptions is null or jsonb_typeof(p_assumptions) <> 'object' then
    raise exception using
      errcode = '22023',
      message = 'Projection assumptions must be an object';
  end if;

  begin
    v_expected_unit_price := (p_assumptions ->> 'expected_unit_price')::numeric;
    v_production_per_day := (p_assumptions ->> 'production_per_day')::numeric;
    v_feed_rate := (p_assumptions ->> 'feed_rate_kg_per_bird_day')::numeric;
    v_other_costs := (p_assumptions ->> 'other_costs')::numeric;
  exception when invalid_text_representation or numeric_value_out_of_range then
    raise exception using
      errcode = '22023',
      message = 'Projection assumptions must be numeric';
  end;

  if v_expected_unit_price is null
    or v_production_per_day is null
    or v_feed_rate is null
    or v_other_costs is null
    or v_expected_unit_price < 0
    or v_production_per_day < 0
    or v_feed_rate <= 0
    or v_other_costs < 0 then
    raise exception using
      errcode = '22023',
      message = 'Projection assumptions are outside the supported range';
  end if;

  select count(*)::integer
  into v_feed_count
  from economics_v2.cycle_feeds feed
  where feed.cycle_id = p_cycle_id
    and feed.granja_id = p_granja_id;

  select
    coalesce(sum(component.cantidad), 0),
    coalesce(sum(coalesce(food.precio, 0)), 0)
  into v_available_feed_kg, v_feed_cost
  from economics_v2.cycle_feeds feed
  join public.mezcla mixture
    on mixture.id = feed.mezcla_id
   and mixture.granja_id = p_granja_id
  join public.mezcla_comida component
    on component.mezcla_id = mixture.id
   and component.granja_id = p_granja_id
  join public.comida food
    on food.id = component.comida_id
   and food.granja_id = p_granja_id
  where feed.cycle_id = p_cycle_id
    and feed.granja_id = p_granja_id;

  if v_feed_count <> 1 or v_available_feed_kg <= 0 then
    raise exception using
      errcode = '23514',
      message = 'A posture projection requires one feed mixture with ingredient kg';
  end if;

  select coalesce(sum(
    greatest(
      0,
      least(coalesce(member.left_on, v_as_of), v_as_of)
        - greatest(member.joined_on, v_cycle.starts_on)
    )
  ), 0)
  into v_historical_bird_days
  from economics_v2.cycle_animals member
  where member.cycle_id = p_cycle_id
    and member.joined_on < v_as_of
    and coalesce(member.left_on, v_as_of) > v_cycle.starts_on;

  select count(*)::integer
  into v_active_birds
  from economics_v2.cycle_animals member
  where member.cycle_id = p_cycle_id
    and member.joined_on <= v_as_of
    and (member.left_on is null or member.left_on > v_as_of);

  v_elapsed_days := greatest(0, v_as_of - v_cycle.starts_on);
  v_consumed_kg := v_feed_rate * v_historical_bird_days;
  v_remaining_kg := greatest(0, v_available_feed_kg - v_consumed_kg);
  v_remaining_days := case
    when v_remaining_kg = 0 then 0
    when v_active_birds > 0
      then ceil(v_remaining_kg / (v_feed_rate * v_active_birds))::integer
    else null
  end;
  v_expected_end_exclusive := case
    when v_remaining_days is null then null
    else v_as_of + v_remaining_days
  end;
  v_projected_horizon_days := case
    when v_expected_end_exclusive is null then null
    else greatest(0, v_expected_end_exclusive - v_cycle.starts_on)
  end;
  v_weighted_average_birds := case
    when v_elapsed_days > 0 then v_historical_bird_days / v_elapsed_days
    else v_active_birds
  end;

  return jsonb_build_object(
    'cycle_id', p_cycle_id,
    'purpose_code', v_purpose_code,
    'production_basis', 'good_eggs',
    'as_of', v_as_of,
    'available_feed_kg', v_available_feed_kg,
    'historical_bird_days', v_historical_bird_days,
    'consumed_kg', v_consumed_kg,
    'remaining_kg', v_remaining_kg,
    'current_active_birds', v_active_birds,
    'remaining_days', v_remaining_days,
    'projected_horizon_days', v_projected_horizon_days,
    'expected_end_exclusive', v_expected_end_exclusive,
    'weighted_average_birds', v_weighted_average_birds,
    'expected_units', case
      when v_projected_horizon_days is null then 0
      else v_production_per_day * v_projected_horizon_days
    end,
    'projected_revenue', case
      when v_projected_horizon_days is null then 0
      else v_expected_unit_price * v_production_per_day * v_projected_horizon_days
    end,
    'projected_total_cost', v_feed_cost + v_other_costs,
    'projected_balance', case
      when v_projected_horizon_days is null then -(v_feed_cost + v_other_costs)
      else (v_expected_unit_price * v_production_per_day * v_projected_horizon_days)
        - (v_feed_cost + v_other_costs)
    end,
    'projected_margin', case
      when v_projected_horizon_days is null then -(v_feed_cost + v_other_costs)
      else (v_expected_unit_price * v_production_per_day * v_projected_horizon_days)
        - (v_feed_cost + v_other_costs)
    end
  );
end;
$$;

create or replace function economics_v2.save_cycle_projection_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_assumptions jsonb,
  p_note text
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_cycle economics_v2.cycles;
  v_projection_id uuid;
  v_result jsonb;
  v_created_at timestamptz;
begin
  v_cycle := economics_v2.assert_cycle_access_impl(
    p_granja_id,
    p_cycle_id,
    true
  );
  select cycle.*
  into strict v_cycle
  from economics_v2.cycles cycle
  where cycle.id = p_cycle_id
    and cycle.granja_id = p_granja_id
  for update;
  if v_cycle.status = 'settled' then
    raise exception using
      errcode = '23514',
      message = 'Settled cycle projections are immutable';
  end if;

  v_result := economics_v2.project_scenario_v2_impl(
    p_granja_id,
    p_cycle_id,
    p_assumptions
  );

  select projection.id
  into v_projection_id
  from economics_v2.projections projection
  where projection.cycle_id = p_cycle_id
    and projection.granja_id = p_granja_id
    and projection.calculation_version = 'v3'
    and projection.assumptions ? 'feed_rate_kg_per_bird_day'
  order by projection.created_at desc, projection.id desc
  limit 1
  for update;

  if v_projection_id is null then
    insert into economics_v2.projections (
      cycle_id,
      granja_id,
      assumptions,
      result_snapshot,
      note,
      calculation_version,
      created_by,
      created_at
    ) values (
      p_cycle_id,
      p_granja_id,
      p_assumptions,
      v_result,
      nullif(trim(p_note), ''),
      'v3',
      v_user_id,
      now()
    )
    returning id, created_at into v_projection_id, v_created_at;
  else
    update economics_v2.projections projection
    set assumptions = p_assumptions,
        result_snapshot = v_result,
        note = nullif(trim(p_note), ''),
        calculation_version = 'v3',
        created_by = v_user_id,
        created_at = now()
    where projection.id = v_projection_id
    returning projection.created_at into v_created_at;
  end if;

  return jsonb_build_object(
    'projection_id', v_projection_id,
    'created_at', v_created_at,
    'note', nullif(trim(p_note), ''),
    'calculation_version', 'v3',
    'assumptions', p_assumptions,
    'result', v_result
  );
end;
$$;

create or replace function economics_v2.read_cycle_projections_impl(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
begin
  perform economics_v2.assert_cycle_access_impl(
    p_granja_id,
    p_cycle_id,
    false
  );

  return coalesce(
    (
      select jsonb_build_array(
        jsonb_build_object(
          'projection_id', projection.id,
          'created_at', projection.created_at,
          'note', projection.note,
          'calculation_version', 'v3',
          'assumptions', projection.assumptions,
          'result', economics_v2.project_scenario_v2_impl(
            p_granja_id,
            p_cycle_id,
            projection.assumptions
          )
        )
      )
      from economics_v2.projections projection
      where projection.cycle_id = p_cycle_id
        and projection.granja_id = p_granja_id
        and projection.calculation_version = 'v3'
        and projection.assumptions ? 'feed_rate_kg_per_bird_day'
      order by projection.created_at desc, projection.id desc
      limit 1
    ),
    '[]'::jsonb
  );
end;
$$;

create or replace function economics_v2.replace_cycle_feed_by_purpose_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_mezcla_id uuid,
  p_starts_on date,
  p_ends_on date
) returns uuid
language plpgsql
security definer
set search_path = '' as $$
declare
  v_cycle economics_v2.cycles;
  v_purpose_code text;
  v_mixture_start date;
  v_mixture_end date;
  v_feed_id uuid;
begin
  v_cycle := economics_v2.assert_cycle_access_impl(
    p_granja_id,
    p_cycle_id,
    true
  );
  select cycle.*
  into strict v_cycle
  from economics_v2.cycles cycle
  where cycle.id = p_cycle_id
    and cycle.granja_id = p_granja_id
  for update;

  select purpose.codigo_calculo
  into v_purpose_code
  from public.cat_proposito_animal purpose
  where purpose.id = v_cycle.proposito_id;

  if v_purpose_code = 'postura' then
    if exists (
      select 1
      from economics_v2.cycle_feeds feed
      where feed.cycle_id = p_cycle_id
    ) then
      raise exception using
        errcode = '23514',
        message = 'A posture cycle allows exactly one feed mixture';
    end if;

    select mixture.fecha_inicio, mixture.fecha_termino
    into v_mixture_start, v_mixture_end
    from public.mezcla mixture
    where mixture.id = p_mezcla_id
      and mixture.granja_id = p_granja_id;

    if p_starts_on <> v_cycle.starts_on
      or v_mixture_start <> v_cycle.starts_on then
      raise exception using
        errcode = '22023',
        message = 'A posture cycle and its feed mixture must start together';
    end if;
    if p_ends_on is distinct from v_mixture_end then
      raise exception using
        errcode = '22023',
        message = 'A posture feed ends only when its mixture is ended';
    end if;
  end if;

  v_feed_id := economics_v2.replace_cycle_feed_impl(
    p_granja_id,
    p_cycle_id,
    p_mezcla_id,
    p_starts_on,
    p_ends_on
  );

  if v_purpose_code = 'postura'
    and v_mixture_end is not null
    and v_mixture_end > v_cycle.starts_on then
    update economics_v2.cycles
    set status = 'production_closed',
        production_closed_on = v_mixture_end - 1,
        ends_on = v_mixture_end,
        updated_at = now()
    where id = p_cycle_id;
  end if;

  return v_feed_id;
end;
$$;

create or replace function public.reemplazar_alimento_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_mezcla_id uuid,
  p_starts_on date,
  p_ends_on date
) returns uuid
language sql
security invoker
set search_path = '' as $$
  select economics_v2.replace_cycle_feed_by_purpose_impl(
    p_granja_id,
    p_cycle_id,
    p_mezcla_id,
    p_starts_on,
    p_ends_on
  );
$$;

create or replace function public.sync_posture_cycle_mixture_end()
returns trigger
language plpgsql
security definer
set search_path = '' as $$
begin
  if new.fecha_termino is null
    or new.fecha_termino is not distinct from old.fecha_termino then
    return new;
  end if;

  update economics_v2.cycle_feeds feed
  set ends_on = new.fecha_termino
  from economics_v2.cycles cycle
  join public.cat_proposito_animal purpose
    on purpose.id = cycle.proposito_id
   and purpose.codigo_calculo = 'postura'
  where feed.cycle_id = cycle.id
    and feed.mezcla_id = new.id
    and feed.ends_on is null;

  update economics_v2.cycles cycle
  set status = 'production_closed',
      production_closed_on = new.fecha_termino - 1,
      ends_on = new.fecha_termino,
      updated_at = now()
  from economics_v2.cycle_feeds feed
  where feed.cycle_id = cycle.id
    and feed.mezcla_id = new.id
    and cycle.status = 'open'
    and new.fecha_termino > cycle.starts_on
    and exists (
      select 1
      from public.cat_proposito_animal purpose
      where purpose.id = cycle.proposito_id
        and purpose.codigo_calculo = 'postura'
    );

  return new;
end;
$$;

drop trigger if exists mezcla_sync_posture_cycle_end on public.mezcla;
create trigger mezcla_sync_posture_cycle_end
after update of fecha_termino on public.mezcla
for each row execute function public.sync_posture_cycle_mixture_end();

revoke all on function public.sync_posture_cycle_mixture_end()
from public, anon, authenticated;

create or replace function economics_v2.record_cycle_animal_sale_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_animal_ids uuid[],
  p_fecha_venta date,
  p_total_amount numeric,
  p_peso numeric,
  p_notas text
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_cycle economics_v2.cycles;
  v_purpose_code text;
  v_selected_count integer;
  v_remaining_count integer;
  v_sale_id uuid;
  v_status text;
begin
  if p_animal_ids is null
    or cardinality(p_animal_ids) = 0
    or array_position(p_animal_ids, null) is not null
    or cardinality(p_animal_ids) <> (
      select count(distinct selected.animal_id)
      from unnest(p_animal_ids) selected(animal_id)
    ) then
    raise exception using
      errcode = '22023',
      message = 'Selected animal IDs must be present and unique';
  end if;
  if p_fecha_venta is null
    or p_fecha_venta > current_date
    or p_total_amount is null
    or p_total_amount < 0
    or p_peso is null
    or p_peso <= 0 then
    raise exception using
      errcode = '22023',
      message = 'A non-future sale with valid amount and total weight is required';
  end if;

  v_cycle := economics_v2.assert_cycle_access_impl(
    p_granja_id,
    p_cycle_id,
    true
  );
  select cycle.*
  into strict v_cycle
  from economics_v2.cycles cycle
  where cycle.id = p_cycle_id
    and cycle.granja_id = p_granja_id
  for update;

  select purpose.codigo_calculo
  into v_purpose_code
  from public.cat_proposito_animal purpose
  where purpose.id = v_cycle.proposito_id;
  if v_purpose_code <> 'carne' then
    raise exception using
      errcode = '22023',
      message = 'Cycle-scoped animal sales are supported only for meat cycles';
  end if;
  if v_cycle.status <> 'open' then
    raise exception using
      errcode = '23514',
      message = 'Meat production is not open';
  end if;
  if p_fecha_venta < v_cycle.starts_on then
    raise exception using
      errcode = '22023',
      message = 'Sale date cannot predate the cycle';
  end if;

  perform member.animal_id
  from economics_v2.cycle_animals member
  where member.cycle_id = p_cycle_id
    and member.animal_id = any(p_animal_ids)
  order by member.animal_id
  for update;

  select count(*)::integer
  into v_selected_count
  from economics_v2.cycle_animals member
  where member.cycle_id = p_cycle_id
    and member.animal_id = any(p_animal_ids)
    and member.left_on is null
    and member.joined_on <= p_fecha_venta;
  if v_selected_count <> cardinality(p_animal_ids) then
    raise exception using
      errcode = '23514',
      message = 'Every sold animal must be an active member of the meat cycle';
  end if;

  v_sale_id := economics_v2.record_animal_sale_impl(
    p_granja_id,
    p_animal_ids,
    p_fecha_venta,
    p_total_amount,
    p_peso,
    p_notas
  );

  select count(*)::integer
  into v_remaining_count
  from economics_v2.cycle_animals member
  where member.cycle_id = p_cycle_id
    and member.left_on is null;

  if v_remaining_count = 0 then
    update economics_v2.cycle_feeds feed
    set ends_on = p_fecha_venta + 1
    where feed.cycle_id = p_cycle_id
      and feed.granja_id = p_granja_id
      and feed.ends_on is null;
    update economics_v2.cycles
    set status = 'production_closed',
        production_closed_on = p_fecha_venta,
        ends_on = p_fecha_venta + 1,
        updated_at = now()
    where id = p_cycle_id;
    v_status := 'production_closed';
  else
    update economics_v2.cycles
    set updated_at = now()
    where id = p_cycle_id;
    v_status := 'open';
  end if;

  return jsonb_build_object(
    'sale_id', v_sale_id,
    'cycle_id', p_cycle_id,
    'sold_count', v_selected_count,
    'status', v_status
  );
end;
$$;

create or replace function public.registrar_venta_animales_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_animal_ids uuid[],
  p_fecha_venta date,
  p_total_amount numeric,
  p_peso numeric,
  p_notas text
) returns jsonb
language sql
security invoker
set search_path = '' as $$
  select economics_v2.record_cycle_animal_sale_impl(
    p_granja_id,
    p_cycle_id,
    p_animal_ids,
    p_fecha_venta,
    p_total_amount,
    p_peso,
    p_notas
  );
$$;

create or replace function economics_v2.calculate_cycle_v2_impl(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_cycle economics_v2.cycles;
  v_purpose_code text;
  v_window_end date;
  v_feed_cost numeric := 0;
  v_direct_cost numeric := 0;
  v_acquisition_cost numeric := 0;
  v_good_eggs numeric := 0;
  v_broken_eggs numeric := 0;
  v_egg_sales_units numeric := 0;
  v_egg_revenue numeric := 0;
  v_animal_sale_revenue numeric := 0;
  v_sold_members numeric := 0;
  v_saleable_weight numeric := 0;
  v_production_units numeric := 0;
  v_revenue numeric := 0;
  v_total_cost numeric := 0;
  v_profit numeric := 0;
  v_realized_unit_price numeric;
begin
  v_cycle := economics_v2.assert_cycle_access_impl(
    p_granja_id,
    p_cycle_id,
    false
  );

  select purpose.codigo_calculo
  into v_purpose_code
  from public.cat_proposito_animal purpose
  where purpose.id = v_cycle.proposito_id;
  if v_purpose_code not in ('postura', 'carne', 'ornamental') then
    raise exception using errcode = '22023', message = 'Unsupported cycle purpose';
  end if;

  v_window_end := coalesce(v_cycle.ends_on, current_date + 1);

  select coalesce(sum(coalesce(food.precio, 0)), 0)
  into v_feed_cost
  from (
    select distinct feed.mezcla_id
    from economics_v2.cycle_feeds feed
    where feed.cycle_id = p_cycle_id
      and feed.granja_id = p_granja_id
      and feed.mezcla_id is not null
      and feed.starts_on < v_window_end
      and coalesce(feed.ends_on, v_window_end) > v_cycle.starts_on
  ) linked
  join public.mezcla mixture
    on mixture.id = linked.mezcla_id
   and mixture.granja_id = p_granja_id
  join public.mezcla_comida component
    on component.mezcla_id = mixture.id
   and component.granja_id = p_granja_id
  join public.comida food
    on food.id = component.comida_id
   and food.granja_id = p_granja_id;

  select coalesce(sum(expense.amount), 0)
  into v_direct_cost
  from economics_v2.cycle_expenses expense
  where expense.cycle_id = p_cycle_id
    and expense.granja_id = p_granja_id
    and expense.occurred_on >= v_cycle.starts_on;

  if v_purpose_code = 'carne' then
    select coalesce(sum(coalesce(member.acquisition_cost_snapshot, 0)), 0)
    into v_acquisition_cost
    from economics_v2.cycle_animals member
    where member.cycle_id = p_cycle_id;
  end if;

  if v_purpose_code = 'postura' then
    select
      coalesce(sum(collection.buenos), 0),
      coalesce(sum(collection.rotos), 0)
    into v_good_eggs, v_broken_eggs
    from public.recoleccion_huevo collection
    where collection.granja_id = p_granja_id
      and collection.fecha_recoleccion >= v_cycle.starts_on
      and collection.fecha_recoleccion < v_window_end
      and exists (
        select 1
        from economics_v2.cycle_animals member
        join public.animales animal
          on animal.id = member.animal_id
         and animal.granja_id = p_granja_id
        where member.cycle_id = p_cycle_id
          and animal.grupo_id = collection.grupo_id
          and collection.fecha_recoleccion >= member.joined_on
          and collection.fecha_recoleccion < coalesce(member.left_on, v_window_end)
      )
      and exists (
        select 1
        from economics_v2.cycle_feeds feed
        join public.mezcla mixture
          on mixture.id = feed.mezcla_id
         and mixture.granja_id = p_granja_id
        where feed.cycle_id = p_cycle_id
          and feed.granja_id = p_granja_id
          and mixture.grupo_id = collection.grupo_id
          and collection.fecha_recoleccion >= feed.starts_on
          and collection.fecha_recoleccion < coalesce(feed.ends_on, v_window_end)
      );

    select
      coalesce(sum(sale.cantidad), 0),
      coalesce(sum(sale.cantidad * sale.precio), 0)
    into v_egg_sales_units, v_egg_revenue
    from public.venta_huevo sale
    where sale.granja_id = p_granja_id
      and sale.fecha_venta >= v_cycle.starts_on
      and exists (
        select 1
        from economics_v2.cycle_animals member
        join public.animales animal
          on animal.id = member.animal_id
         and animal.granja_id = p_granja_id
        where member.cycle_id = p_cycle_id
          and animal.grupo_id = sale.grupo_id
      );

    v_production_units := v_good_eggs;
    v_revenue := v_egg_revenue;
  else
    with cycle_sales as (
      select distinct sale.id, sale.total_amount, sale.quantity, sale.peso
      from economics_v2.cycle_animals member
      join public.venta_animal sale on sale.id = member.sold_by_sale_id
      where member.cycle_id = p_cycle_id
        and member.left_on is not null
        and member.left_on >= v_cycle.starts_on
        and member.left_on < v_window_end
        and sale.granja_id = p_granja_id
        and sale.record_kind = 'individual'
    )
    select
      coalesce(sum(cycle_sales.total_amount), 0),
      coalesce(sum(cycle_sales.quantity), 0),
      coalesce(sum(coalesce(cycle_sales.peso, 0)), 0)
    into v_animal_sale_revenue, v_sold_members, v_saleable_weight
    from cycle_sales;

    v_production_units := case
      when v_purpose_code = 'carne' then v_saleable_weight
      else v_sold_members
    end;
    v_revenue := v_animal_sale_revenue;
  end if;

  v_total_cost := v_feed_cost + v_direct_cost + v_acquisition_cost;
  v_profit := v_revenue - v_total_cost;
  v_realized_unit_price := case
    when v_production_units > 0 and v_revenue > 0
      then v_revenue / v_production_units
    else null
  end;

  return jsonb_build_object(
    'kind', 'actual',
    'calculation_version', 'v2',
    'cycle_id', p_cycle_id,
    'purpose_code', v_purpose_code,
    'production_basis', case
      when v_purpose_code = 'postura' then 'good_eggs'
      when v_purpose_code = 'carne' then 'saleable_kg'
      else 'specimens'
    end,
    'production_units', v_production_units,
    'good_eggs', case when v_purpose_code = 'postura' then v_good_eggs else null end,
    'broken_eggs', case when v_purpose_code = 'postura' then v_broken_eggs else null end,
    'sold_units', case when v_purpose_code = 'postura' then v_egg_sales_units else v_sold_members end,
    'revenue', v_revenue,
    'feed_cost', v_feed_cost,
    'direct_cost', v_direct_cost,
    'acquisition_cost', v_acquisition_cost,
    'total_cost', v_total_cost,
    'profit', v_profit,
    'margin', v_profit,
    'margin_percentage', case when v_revenue > 0 then v_profit * 100 / v_revenue else null end,
    'unit_cost', case when v_production_units > 0 then v_total_cost / v_production_units else null end,
    'realized_unit_price', v_realized_unit_price,
    'break_even', case when v_realized_unit_price > 0 then v_total_cost / v_realized_unit_price else null end
  );
end;
$$;

create or replace function economics_v2.read_final_result_impl(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_cycle economics_v2.cycles;
  v_result economics_v2.final_results;
begin
  v_cycle := economics_v2.assert_cycle_access_impl(
    p_granja_id,
    p_cycle_id,
    false
  );
  if v_cycle.status <> 'settled' then
    raise exception using
      errcode = '23514',
      message = 'Final result is available only for a settled cycle';
  end if;

  select final.*
  into strict v_result
  from economics_v2.final_results final
  where final.cycle_id = p_cycle_id
    and final.granja_id = p_granja_id;

  return jsonb_build_object(
    'cycle_id', p_cycle_id,
    'calculation_version', v_result.calculation_version,
    'settled_on', v_cycle.settled_on,
    'result', v_result.result_snapshot
  );
end;
$$;

create or replace function public.obtener_resultado_final_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language sql
security invoker
set search_path = '' as $$
  select economics_v2.read_final_result_impl(p_granja_id, p_cycle_id);
$$;

revoke all on function economics_v2.replace_cycle_feed_by_purpose_impl(uuid, uuid, uuid, date, date)
from public, anon, authenticated;
revoke all on function economics_v2.record_cycle_animal_sale_impl(uuid, uuid, uuid[], date, numeric, numeric, text)
from public, anon, authenticated;
revoke all on function economics_v2.read_final_result_impl(uuid, uuid)
from public, anon, authenticated;
revoke all on function public.registrar_venta_animales_ciclo_v2(uuid, uuid, uuid[], date, numeric, numeric, text)
from public, anon, authenticated;
revoke all on function public.obtener_resultado_final_ciclo_v2(uuid, uuid)
from public, anon, authenticated;

grant execute on function economics_v2.replace_cycle_feed_by_purpose_impl(uuid, uuid, uuid, date, date)
to authenticated;
grant execute on function economics_v2.record_cycle_animal_sale_impl(uuid, uuid, uuid[], date, numeric, numeric, text)
to authenticated;
grant execute on function economics_v2.read_final_result_impl(uuid, uuid)
to authenticated;
grant execute on function public.registrar_venta_animales_ciclo_v2(uuid, uuid, uuid[], date, numeric, numeric, text)
to authenticated;
grant execute on function public.obtener_resultado_final_ciclo_v2(uuid, uuid)
to authenticated;
