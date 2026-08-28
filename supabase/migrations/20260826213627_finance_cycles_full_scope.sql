-- Finance/Cycles full-scope contracts.
-- Public functions remain fixed-search-path invokers. Privileged implementations
-- stay in the private economics_v2 schema and enforce actor/farm access directly.

alter table economics_v2.cycles
  add column if not exists name text,
  add column if not exists planned_ends_on date,
  add column if not exists production_closed_on date,
  add column if not exists settled_on date,
  add column if not exists updated_at timestamptz not null default now();

alter table economics_v2.cycles
  drop constraint if exists cycles_status_check;

update economics_v2.cycles cycle
set
  production_closed_on = coalesce(cycle.ends_on, cycle.starts_on),
  ends_on = coalesce(cycle.ends_on, cycle.starts_on) + 1,
  status = 'production_closed'
where cycle.status = 'closed';

update economics_v2.cycles cycle
set
  production_closed_on = coalesce(cycle.production_closed_on, cycle.ends_on - 1, cycle.starts_on),
  ends_on = coalesce(cycle.ends_on, cycle.starts_on + 1),
  settled_on = coalesce(
    (select result.created_at::date
     from economics_v2.final_results result
     where result.cycle_id = cycle.id),
    cycle.ends_on - 1,
    cycle.starts_on
  ),
  status = 'settled'
where exists (
  select 1
  from economics_v2.final_results result
  where result.cycle_id = cycle.id
);

update economics_v2.cycles
set planned_ends_on = ends_on,
    ends_on = null
where status = 'open'
  and ends_on is not null;

alter table economics_v2.cycles
  add constraint cycles_status_check
    check (status in ('open', 'production_closed', 'settled')),
  add constraint cycles_planned_dates_check
    check (planned_ends_on is null or planned_ends_on >= starts_on),
  add constraint cycles_production_closed_date_check
    check (
      (status = 'open' and production_closed_on is null and ends_on is null)
      or (
        status in ('production_closed', 'settled')
        and production_closed_on is not null
        and production_closed_on >= starts_on
        and ends_on = production_closed_on + 1
      )
    ),
  add constraint cycles_settled_date_check
    check (
      (status <> 'settled' and settled_on is null)
      or (status = 'settled' and settled_on is not null and settled_on >= production_closed_on)
    );

alter table economics_v2.cycle_animals
  add column if not exists group_name_snapshot text,
  add column if not exists acquisition_cost_snapshot numeric;

alter table economics_v2.cycle_animals
  add constraint cycle_animals_acquisition_cost_snapshot_check
    check (acquisition_cost_snapshot is null or acquisition_cost_snapshot >= 0);

alter table economics_v2.cycle_feeds
  add column if not exists group_name_snapshot text;

alter table economics_v2.cycle_expenses
  add column if not exists category text;

alter table economics_v2.projections
  add column if not exists result_snapshot jsonb,
  add column if not exists note text,
  add column if not exists calculation_version text not null default 'v2';

create unique index if not exists cycle_feeds_mixture_once_idx
  on economics_v2.cycle_feeds (mezcla_id)
  where mezcla_id is not null;

create or replace function economics_v2.assert_cycle_access_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_mutation boolean
) returns economics_v2.cycles
language plpgsql
security definer
set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_cycle economics_v2.cycles;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  select cycle.*
  into v_cycle
  from economics_v2.cycles cycle
  where cycle.id = p_cycle_id
    and cycle.granja_id = p_granja_id;

  if v_cycle.id is null
    or not exists (
      select 1
      from public.miembros_granja membership
      join economics_v2.feature_flags flag
        on flag.granja_id = membership.granja_id
       and flag.economics_v2_enabled
      where membership.granja_id = p_granja_id
        and membership.user_id = v_user_id
        and (
          not p_mutation
          or membership.rol in ('owner', 'editor')
        )
    ) then
    raise exception using errcode = '42501', message = 'Cycle access denied';
  end if;

  return v_cycle;
end;
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
    select
      coalesce(sum(sale.total_amount), 0),
      count(*),
      coalesce(sum(coalesce(sale.peso, 0)), 0)
    into v_animal_sale_revenue, v_sold_members, v_saleable_weight
    from economics_v2.cycle_animals member
    join public.venta_animal sale on sale.id = member.sold_by_sale_id
    where member.cycle_id = p_cycle_id
      and member.left_on is not null
      and member.left_on >= v_cycle.starts_on
      and sale.granja_id = p_granja_id
      and sale.record_kind = 'individual';

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

create or replace function economics_v2.calculate_cycle_impl(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language sql
security definer
set search_path = '' as $$
  select economics_v2.calculate_cycle_v2_impl(p_granja_id, p_cycle_id);
$$;

create or replace function economics_v2.read_cycle_detail_impl(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_cycle economics_v2.cycles;
  v_purpose_name text;
  v_purpose_code text;
  v_actual jsonb;
  v_active_count integer;
  v_exited_count integer;
  v_latest_group_name text;
begin
  v_cycle := economics_v2.assert_cycle_access_impl(
    p_granja_id,
    p_cycle_id,
    false
  );
  v_actual := economics_v2.calculate_cycle_v2_impl(p_granja_id, p_cycle_id);

  select purpose.nombre, purpose.codigo_calculo
  into v_purpose_name, v_purpose_code
  from public.cat_proposito_animal purpose
  where purpose.id = v_cycle.proposito_id;

  select
    count(*) filter (where member.left_on is null)::integer,
    count(*) filter (where member.left_on is not null)::integer
  into v_active_count, v_exited_count
  from economics_v2.cycle_animals member
  where member.cycle_id = p_cycle_id;

  select feed.group_name_snapshot
  into v_latest_group_name
  from economics_v2.cycle_feeds feed
  where feed.cycle_id = p_cycle_id
  order by feed.starts_on desc, feed.id desc
  limit 1;

  return jsonb_build_object(
    'cycle_id', v_cycle.id,
    'granja_id', v_cycle.granja_id,
    'name', v_cycle.name,
    'status', v_cycle.status,
    'starts_on', v_cycle.starts_on,
    'planned_ends_on', v_cycle.planned_ends_on,
    'production_closed_on', v_cycle.production_closed_on,
    'settled_on', v_cycle.settled_on,
    'purpose_id', v_cycle.proposito_id,
    'purpose_name', v_purpose_name,
    'purpose_code', v_purpose_code,
    'active_animal_count', v_active_count,
    'exited_animal_count', v_exited_count,
    'feed_cost', (v_actual ->> 'feed_cost')::numeric,
    'direct_expense_total', (v_actual ->> 'direct_cost')::numeric,
    'revenue', (v_actual ->> 'revenue')::numeric,
    'total_cost', (v_actual ->> 'total_cost')::numeric,
    'profit', (v_actual ->> 'profit')::numeric,
    'margin_percentage', (v_actual ->> 'margin_percentage')::numeric,
    'unit_cost', (v_actual ->> 'unit_cost')::numeric,
    'break_even', (v_actual ->> 'break_even')::numeric,
    'latest_group_name_snapshot', v_latest_group_name,
    'updated_at', v_cycle.updated_at
  );
end;
$$;

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
  v_cycle := economics_v2.assert_cycle_access_impl(
    p_granja_id,
    p_cycle_id,
    false
  );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'animal_id', animal.id,
        'label', concat(
          animal_type.nombre,
          case when animal.brazalete is null then '' else concat(' #', animal.brazalete) end
        ),
        'group_name_snapshot', member.group_name_snapshot,
        'joined_on', member.joined_on,
        'left_on', member.left_on,
        'is_active', member.left_on is null
      ) order by member.joined_on desc, animal.id
    ),
    '[]'::jsonb
  )
  into v_members
  from economics_v2.cycle_animals member
  join public.animales animal
    on animal.id = member.animal_id
   and animal.granja_id = p_granja_id
  join public.tipo_animal animal_type on animal_type.id = animal.tipo_animal_id
  where member.cycle_id = p_cycle_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'animal_id', animal.id,
        'label', concat(
          animal_type.nombre,
          case when animal.brazalete is null then '' else concat(' #', animal.brazalete) end
        ),
        'group_name', animal_group.nombre
      ) order by animal_type.nombre, animal.brazalete nulls last, animal.id
    ),
    '[]'::jsonb
  )
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
        and existing.left_on is null
    );

  return jsonb_build_object(
    'members', v_members,
    'candidates', v_candidates
  );
end;
$$;

create or replace function economics_v2.read_cycle_feeds_impl(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_cycle economics_v2.cycles;
  v_intervals jsonb;
  v_candidates jsonb;
begin
  v_cycle := economics_v2.assert_cycle_access_impl(
    p_granja_id,
    p_cycle_id,
    false
  );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'feed_id', feed.id,
        'mixture_id', feed.mezcla_id,
        'mixture_label', concat('Mixture ', mixture.fecha_inicio),
        'group_name_snapshot', feed.group_name_snapshot,
        'starts_on', feed.starts_on,
        'ends_on', feed.ends_on,
        'cost', feed_cost.total
      ) order by feed.starts_on desc, feed.id
    ),
    '[]'::jsonb
  )
  into v_intervals
  from economics_v2.cycle_feeds feed
  join public.mezcla mixture
    on mixture.id = feed.mezcla_id
   and mixture.granja_id = p_granja_id
  cross join lateral (
    select coalesce(sum(coalesce(food.precio, 0)), 0) as total
    from public.mezcla_comida component
    join public.comida food
      on food.id = component.comida_id
     and food.granja_id = p_granja_id
    where component.mezcla_id = mixture.id
      and component.granja_id = p_granja_id
  ) feed_cost
  where feed.cycle_id = p_cycle_id
    and feed.granja_id = p_granja_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'mixture_id', mixture.id,
        'mixture_label', concat('Mixture ', mixture.fecha_inicio),
        'group_name', animal_group.nombre
      ) order by mixture.fecha_inicio desc, mixture.id
    ),
    '[]'::jsonb
  )
  into v_candidates
  from public.mezcla mixture
  join public.grupos animal_group
    on animal_group.id = mixture.grupo_id
   and animal_group.granja_id = p_granja_id
  where mixture.granja_id = p_granja_id
    and not exists (
      select 1
      from economics_v2.cycle_feeds existing
      where existing.mezcla_id = mixture.id
    )
    and exists (
      select 1
      from public.animales animal
      where animal.granja_id = p_granja_id
        and animal.grupo_id = mixture.grupo_id
        and animal.proposito_id = v_cycle.proposito_id
    );

  return jsonb_build_object(
    'intervals', v_intervals,
    'candidates', v_candidates
  );
end;
$$;

create or replace function economics_v2.read_cycle_expenses_impl(
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

  return (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'expense_id', expense.id,
          'occurred_on', expense.occurred_on,
          'amount', expense.amount,
          'category', expense.category,
          'note', expense.note
        ) order by expense.occurred_on desc, expense.created_at desc, expense.id
      ),
      '[]'::jsonb
    )
    from economics_v2.cycle_expenses expense
    where expense.cycle_id = p_cycle_id
      and expense.granja_id = p_granja_id
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

  return (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'projection_id', projection.id,
          'created_at', projection.created_at,
          'note', projection.note,
          'calculation_version', projection.calculation_version,
          'assumptions', projection.assumptions,
          'result', projection.result_snapshot
        ) order by projection.created_at desc, projection.id
      ),
      '[]'::jsonb
    )
    from economics_v2.projections projection
    where projection.cycle_id = p_cycle_id
      and projection.granja_id = p_granja_id
  );
end;
$$;

create or replace function economics_v2.project_scenario_v2_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_assumptions jsonb
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_expected_unit_price numeric;
  v_production_per_day numeric;
  v_feed_per_day numeric;
  v_other_costs numeric;
  v_horizon_days integer;
begin
  perform economics_v2.assert_cycle_access_impl(
    p_granja_id,
    p_cycle_id,
    false
  );

  if p_assumptions is null or jsonb_typeof(p_assumptions) <> 'object' then
    raise exception using errcode = '22023', message = 'Projection assumptions must be an object';
  end if;

  begin
    v_expected_unit_price := (p_assumptions ->> 'expected_unit_price')::numeric;
    v_production_per_day := (p_assumptions ->> 'production_per_day')::numeric;
    v_feed_per_day := (p_assumptions ->> 'feed_per_day')::numeric;
    v_other_costs := (p_assumptions ->> 'other_costs')::numeric;
    v_horizon_days := (p_assumptions ->> 'horizon_days')::integer;
  exception when invalid_text_representation or numeric_value_out_of_range then
    raise exception using errcode = '22023', message = 'Projection assumptions must be numeric';
  end;

  if v_expected_unit_price is null
    or v_production_per_day is null
    or v_feed_per_day is null
    or v_other_costs is null
    or v_horizon_days is null
    or v_expected_unit_price < 0
    or v_production_per_day < 0
    or v_feed_per_day < 0
    or v_other_costs < 0
    or v_horizon_days <= 0 then
    raise exception using errcode = '22023', message = 'Projection assumptions are outside the supported range';
  end if;

  return jsonb_build_object(
    'expected_units', v_production_per_day * v_horizon_days,
    'projected_revenue', v_expected_unit_price * v_production_per_day * v_horizon_days,
    'projected_total_cost', v_feed_per_day * v_horizon_days + v_other_costs,
    'projected_balance',
      (v_expected_unit_price * v_production_per_day * v_horizon_days)
      - (v_feed_per_day * v_horizon_days + v_other_costs)
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
    raise exception using errcode = '23514', message = 'Settled cycle projections are immutable';
  end if;
  v_result := economics_v2.project_scenario_v2_impl(
    p_granja_id,
    p_cycle_id,
    p_assumptions
  );

  insert into economics_v2.projections (
    cycle_id,
    granja_id,
    assumptions,
    result_snapshot,
    note,
    calculation_version,
    created_by
  ) values (
    p_cycle_id,
    p_granja_id,
    p_assumptions,
    v_result,
    nullif(trim(p_note), ''),
    'v2',
    v_user_id
  ) returning id, created_at into v_projection_id, v_created_at;

  return jsonb_build_object(
    'projection_id', v_projection_id,
    'created_at', v_created_at,
    'note', nullif(trim(p_note), ''),
    'calculation_version', 'v2',
    'assumptions', p_assumptions,
    'result', v_result
  );
end;
$$;

create or replace function economics_v2.assign_cycle_animal_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_animal_id uuid,
  p_joined_on date
) returns void
language plpgsql
security definer
set search_path = '' as $$
declare
  v_cycle economics_v2.cycles;
  v_animal_farm_id uuid;
  v_animal_purpose_id uuid;
  v_animal_active boolean;
  v_animal_baja_id uuid;
  v_group_name text;
  v_acquisition_cost numeric;
  v_purpose_code text;
begin
  if p_joined_on is null
    or p_joined_on > current_date then
    raise exception using errcode = '22023', message = 'A non-future animal membership date is required';
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
  if v_cycle.status <> 'open' then
    raise exception using errcode = '23514', message = 'Production membership is closed';
  end if;

  select
    animal.granja_id,
    animal.proposito_id,
    animal.activo,
    animal.baja_id,
    animal_group.nombre,
    animal.costo_adquisicion
  into
    v_animal_farm_id,
    v_animal_purpose_id,
    v_animal_active,
    v_animal_baja_id,
    v_group_name,
    v_acquisition_cost
  from public.animales animal
  left join public.grupos animal_group on animal_group.id = animal.grupo_id
  where animal.id = p_animal_id
  for update of animal;

  if v_animal_farm_id is distinct from p_granja_id then
    raise exception using errcode = '42501', message = 'Animal must belong to the cycle farm';
  end if;
  if not v_animal_active or v_animal_baja_id is not null then
    raise exception using errcode = '22023', message = 'Animal must be active and without a baja';
  end if;
  if v_animal_purpose_id is distinct from v_cycle.proposito_id then
    raise exception using errcode = '22023', message = 'Animal purpose must match the cycle purpose';
  end if;
  if p_joined_on < v_cycle.starts_on then
    raise exception using errcode = '22023', message = 'Animal membership cannot predate the cycle';
  end if;
  if exists (
    select 1
    from economics_v2.cycle_animals membership
    where membership.animal_id = p_animal_id
      and membership.left_on is null
  ) then
    raise exception using errcode = '23505', message = 'Animal already has an active cycle membership';
  end if;

  select purpose.codigo_calculo
  into v_purpose_code
  from public.cat_proposito_animal purpose
  where purpose.id = v_cycle.proposito_id;

  insert into economics_v2.cycle_animals (
    cycle_id,
    animal_id,
    joined_on,
    group_name_snapshot,
    acquisition_cost_snapshot
  ) values (
    p_cycle_id,
    p_animal_id,
    p_joined_on,
    v_group_name,
    case when v_purpose_code = 'carne' then coalesce(v_acquisition_cost, 0) else null end
  );

  update economics_v2.cycles
  set updated_at = now()
  where id = p_cycle_id;
end;
$$;

create or replace function economics_v2.record_cycle_expense_with_category_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_occurred_on date,
  p_amount numeric,
  p_category text,
  p_note text
) returns uuid
language plpgsql
security definer
set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_cycle economics_v2.cycles;
  v_expense_id uuid;
begin
  if p_occurred_on is null
    or p_occurred_on > current_date
    or p_amount is null
    or p_amount <= 0 then
    raise exception using errcode = '22023', message = 'A positive non-future dated expense is required';
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
  if v_cycle.status not in ('open', 'production_closed') then
    raise exception using errcode = '23514', message = 'Settled cycle expenses are immutable';
  end if;
  if p_occurred_on < v_cycle.starts_on then
    raise exception using errcode = '22023', message = 'Cycle expense cannot predate the cycle';
  end if;

  insert into economics_v2.cycle_expenses (
    cycle_id,
    granja_id,
    occurred_on,
    amount,
    category,
    note,
    created_by
  ) values (
    p_cycle_id,
    p_granja_id,
    p_occurred_on,
    p_amount,
    nullif(trim(p_category), ''),
    nullif(trim(p_note), ''),
    v_user_id
  ) returning id into v_expense_id;

  update economics_v2.cycles
  set updated_at = now()
  where id = p_cycle_id;

  return v_expense_id;
end;
$$;

create or replace function economics_v2.record_cycle_expense_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_occurred_on date,
  p_amount numeric,
  p_note text
) returns uuid
language sql
security definer
set search_path = '' as $$
  select economics_v2.record_cycle_expense_with_category_impl(
    p_granja_id,
    p_cycle_id,
    p_occurred_on,
    p_amount,
    null,
    p_note
  );
$$;

create or replace function economics_v2.replace_cycle_feed_impl(
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
  v_user_id uuid := auth.uid();
  v_cycle economics_v2.cycles;
  v_mix_farm_id uuid;
  v_mix_group_id uuid;
  v_group_name text;
  v_feed_id uuid;
begin
  if p_mezcla_id is null
    or p_starts_on is null
    or p_starts_on > current_date
    or (p_ends_on is not null and (p_ends_on <= p_starts_on or p_ends_on > current_date)) then
    raise exception using errcode = '22023', message = 'A valid non-future half-open feed interval is required';
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
  if v_cycle.status <> 'open' then
    raise exception using errcode = '23514', message = 'Production feeding is closed';
  end if;
  if p_starts_on < v_cycle.starts_on then
    raise exception using errcode = '22023', message = 'Feed interval cannot predate the cycle';
  end if;

  select mixture.granja_id, mixture.grupo_id, animal_group.nombre
  into v_mix_farm_id, v_mix_group_id, v_group_name
  from public.mezcla mixture
  join public.grupos animal_group on animal_group.id = mixture.grupo_id
  where mixture.id = p_mezcla_id
  for key share of mixture, animal_group;

  if v_mix_farm_id is distinct from p_granja_id then
    raise exception using errcode = '42501', message = 'Feed mixture must belong to the cycle farm';
  end if;
  if not exists (
    select 1
    from public.animales animal
    where animal.granja_id = p_granja_id
      and animal.grupo_id = v_mix_group_id
      and animal.proposito_id = v_cycle.proposito_id
  ) then
    raise exception using errcode = '22023', message = 'Feed group is not compatible with the cycle purpose';
  end if;
  if exists (
    select 1
    from economics_v2.cycle_feeds feed
    where feed.mezcla_id = p_mezcla_id
  ) then
    raise exception using errcode = '23505', message = 'Feed mixture is already attributed to a cycle';
  end if;

  update economics_v2.cycle_feeds feed
  set ends_on = p_starts_on
  where feed.cycle_id = p_cycle_id
    and feed.granja_id = p_granja_id
    and feed.ends_on is null
    and feed.starts_on < p_starts_on;

  if exists (
    select 1
    from economics_v2.cycle_feeds feed
    where feed.cycle_id = p_cycle_id
      and feed.granja_id = p_granja_id
      and feed.starts_on < coalesce(p_ends_on, 'infinity'::date)
      and coalesce(feed.ends_on, 'infinity'::date) > p_starts_on
  ) then
    raise exception using errcode = '23514', message = 'Feed intervals cannot overlap';
  end if;

  insert into economics_v2.cycle_feeds (
    cycle_id,
    granja_id,
    mezcla_id,
    starts_on,
    ends_on,
    group_name_snapshot,
    created_by
  ) values (
    p_cycle_id,
    p_granja_id,
    p_mezcla_id,
    p_starts_on,
    p_ends_on,
    v_group_name,
    v_user_id
  ) returning id into v_feed_id;

  update economics_v2.cycles
  set updated_at = now()
  where id = p_cycle_id;

  return v_feed_id;
end;
$$;

create or replace function economics_v2.link_cycle_feed_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_mezcla_id uuid,
  p_starts_on date,
  p_ends_on date
) returns uuid
language sql
security definer
set search_path = '' as $$
  select economics_v2.replace_cycle_feed_impl(
    p_granja_id,
    p_cycle_id,
    p_mezcla_id,
    p_starts_on,
    p_ends_on
  );
$$;

create or replace function economics_v2.read_cycle_readiness_impl(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_cycle economics_v2.cycles;
  v_actual jsonb;
  v_has_members boolean;
  v_has_feed boolean;
  v_has_saleable_output boolean;
  v_sales_within_output boolean;
  v_open_feed_count integer;
  v_can_close boolean;
  v_can_settle boolean;
  v_reasons text[] := array[]::text[];
begin
  v_cycle := economics_v2.assert_cycle_access_impl(
    p_granja_id,
    p_cycle_id,
    false
  );
  v_actual := economics_v2.calculate_cycle_v2_impl(p_granja_id, p_cycle_id);

  select exists (
    select 1
    from economics_v2.cycle_animals member
    where member.cycle_id = p_cycle_id
  ) into v_has_members;
  select exists (
    select 1
    from economics_v2.cycle_feeds feed
    where feed.cycle_id = p_cycle_id
      and feed.granja_id = p_granja_id
  ) into v_has_feed;
  select count(*)::integer
  into v_open_feed_count
  from economics_v2.cycle_feeds feed
  where feed.cycle_id = p_cycle_id
    and feed.granja_id = p_granja_id
    and feed.ends_on is null;

  v_has_saleable_output := coalesce((v_actual ->> 'production_units')::numeric, 0) > 0;
  v_sales_within_output := coalesce((v_actual ->> 'sold_units')::numeric, 0)
    <= coalesce((v_actual ->> 'production_units')::numeric, 0);
  v_can_close := v_cycle.status = 'open' and v_has_members and v_has_feed;
  v_can_settle := v_cycle.status = 'production_closed'
    and v_has_members
    and v_has_feed
    and v_has_saleable_output
    and v_sales_within_output
    and v_open_feed_count = 0;

  if not v_has_members then v_reasons := array_append(v_reasons, 'missing_members'); end if;
  if not v_has_feed then v_reasons := array_append(v_reasons, 'missing_feed'); end if;
  if not v_has_saleable_output then v_reasons := array_append(v_reasons, 'missing_saleable_output'); end if;
  if not v_sales_within_output then v_reasons := array_append(v_reasons, 'sales_exceed_output'); end if;
  if v_open_feed_count > 0 and v_cycle.status <> 'open' then
    v_reasons := array_append(v_reasons, 'open_feed_intervals');
  end if;
  if v_cycle.status = 'open' then
    v_reasons := array_append(v_reasons, 'production_not_closed');
  end if;

  return jsonb_build_object(
    'cycle_id', p_cycle_id,
    'status', v_cycle.status,
    'can_close_production', v_can_close,
    'can_settle', v_can_settle,
    'has_members', v_has_members,
    'has_feed', v_has_feed,
    'has_saleable_output', v_has_saleable_output,
    'sales_within_output', v_sales_within_output,
    'open_feed_count', v_open_feed_count,
    'reasons', to_jsonb(v_reasons)
  );
end;
$$;

create or replace function economics_v2.close_cycle_production_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_closed_on date
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_cycle economics_v2.cycles;
  v_readiness jsonb;
begin
  if p_closed_on is null or p_closed_on > current_date then
    raise exception using errcode = '22023', message = 'A non-future production closure date is required';
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

  if v_cycle.status <> 'open' then
    raise exception using errcode = '23514', message = 'Production is already closed';
  end if;
  if p_closed_on < v_cycle.starts_on then
    raise exception using errcode = '22023', message = 'Production closure cannot predate the cycle';
  end if;
  if exists (
    select 1
    from economics_v2.cycle_animals member
    where member.cycle_id = p_cycle_id
      and member.joined_on > p_closed_on
  ) or exists (
    select 1
    from economics_v2.cycle_feeds feed
    where feed.cycle_id = p_cycle_id
      and feed.starts_on > p_closed_on
  ) then
    raise exception using errcode = '22023', message = 'Production closure predates recorded production activity';
  end if;

  v_readiness := economics_v2.read_cycle_readiness_impl(
    p_granja_id,
    p_cycle_id
  );
  if not (v_readiness ->> 'can_close_production')::boolean then
    raise exception using errcode = '23514', message = 'Cycle is not ready to close production';
  end if;

  update economics_v2.cycle_feeds feed
  set ends_on = p_closed_on + 1
  where feed.cycle_id = p_cycle_id
    and feed.granja_id = p_granja_id
    and feed.ends_on is null;

  update economics_v2.cycles
  set
    status = 'production_closed',
    production_closed_on = p_closed_on,
    ends_on = p_closed_on + 1,
    updated_at = now()
  where id = p_cycle_id;

  return economics_v2.read_cycle_detail_impl(p_granja_id, p_cycle_id);
end;
$$;

create or replace function economics_v2.finalize_cycle_impl(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_cycle economics_v2.cycles;
  v_readiness jsonb;
  v_result jsonb;
  v_input_snapshot jsonb;
  v_settled_on date := current_date;
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

  if v_cycle.status <> 'production_closed' then
    raise exception using errcode = '23514', message = 'Cycle must close production before settlement';
  end if;
  if exists (
    select 1
    from economics_v2.final_results result
    where result.cycle_id = p_cycle_id
  ) then
    raise exception using errcode = '23505', message = 'Cycle has already been finalized';
  end if;

  v_readiness := economics_v2.read_cycle_readiness_impl(
    p_granja_id,
    p_cycle_id
  );
  if not (v_readiness ->> 'can_settle')::boolean then
    raise exception using errcode = '23514', message = 'Cycle is not ready for settlement';
  end if;

  v_result := economics_v2.calculate_cycle_v2_impl(p_granja_id, p_cycle_id);
  v_input_snapshot := jsonb_build_object(
    'calculation_version', 'v2',
    'cycle', jsonb_build_object(
      'cycle_id', v_cycle.id,
      'granja_id', v_cycle.granja_id,
      'purpose_id', v_cycle.proposito_id,
      'starts_on', v_cycle.starts_on,
      'planned_ends_on', v_cycle.planned_ends_on,
      'production_closed_on', v_cycle.production_closed_on
    ),
    'members', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'animal_id', member.animal_id,
            'joined_on', member.joined_on,
            'left_on', member.left_on,
            'sold_by_sale_id', member.sold_by_sale_id,
            'group_name_snapshot', member.group_name_snapshot,
            'acquisition_cost_snapshot', member.acquisition_cost_snapshot
          ) order by member.animal_id
        ),
        '[]'::jsonb
      )
      from economics_v2.cycle_animals member
      where member.cycle_id = p_cycle_id
    ),
    'feeds', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'feed_id', feed.id,
            'mixture_id', feed.mezcla_id,
            'starts_on', feed.starts_on,
            'ends_on', feed.ends_on,
            'group_name_snapshot', feed.group_name_snapshot
          ) order by feed.starts_on, feed.id
        ),
        '[]'::jsonb
      )
      from economics_v2.cycle_feeds feed
      where feed.cycle_id = p_cycle_id
    ),
    'expenses', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'expense_id', expense.id,
            'occurred_on', expense.occurred_on,
            'amount', expense.amount,
            'category', expense.category,
            'note', expense.note
          ) order by expense.occurred_on, expense.id
        ),
        '[]'::jsonb
      )
      from economics_v2.cycle_expenses expense
      where expense.cycle_id = p_cycle_id
    ),
    'readiness', v_readiness
  );

  insert into economics_v2.final_results (
    cycle_id,
    granja_id,
    calculation_version,
    input_snapshot,
    result_snapshot,
    created_by
  ) values (
    p_cycle_id,
    p_granja_id,
    'v2',
    v_input_snapshot,
    v_result,
    v_user_id
  );

  update economics_v2.cycle_animals member
  set left_on = v_cycle.ends_on
  where member.cycle_id = p_cycle_id
    and member.left_on is null;

  update economics_v2.cycles
  set
    status = 'settled',
    settled_on = v_settled_on,
    updated_at = now()
  where id = p_cycle_id;

  return jsonb_build_object(
    'cycle_id', p_cycle_id,
    'status', 'settled',
    'calculation_version', 'v2',
    'settled_on', v_settled_on,
    'result', v_result
  );
end;
$$;

create or replace function economics_v2.create_cycle_complete_impl(
  p_granja_id uuid,
  p_proposito_id uuid,
  p_name text,
  p_starts_on date,
  p_planned_ends_on date
) returns uuid
language plpgsql
security definer
set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_cycle_id uuid;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;
  if p_starts_on is null
    or p_starts_on > current_date
    or (p_planned_ends_on is not null and p_planned_ends_on < p_starts_on) then
    raise exception using errcode = '22023', message = 'A valid non-future cycle start is required';
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
    name,
    starts_on,
    planned_ends_on,
    status,
    created_by
  ) values (
    p_granja_id,
    p_proposito_id,
    nullif(trim(p_name), ''),
    p_starts_on,
    p_planned_ends_on,
    'open',
    v_user_id
  ) returning id into v_cycle_id;

  return v_cycle_id;
end;
$$;

create or replace function economics_v2.create_cycle_with_dates_impl(
  p_granja_id uuid,
  p_proposito_id uuid,
  p_starts_on date,
  p_ends_on date
) returns uuid
language sql
security definer
set search_path = '' as $$
  select economics_v2.create_cycle_complete_impl(
    p_granja_id,
    p_proposito_id,
    null,
    p_starts_on,
    p_ends_on
  );
$$;

create or replace function economics_v2.create_cycle_impl(
  p_granja_id uuid,
  p_proposito_id uuid,
  p_starts_on date
) returns uuid
language sql
security definer
set search_path = '' as $$
  select economics_v2.create_cycle_complete_impl(
    p_granja_id,
    p_proposito_id,
    null,
    p_starts_on,
    null
  );
$$;

create or replace function public.obtener_detalle_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language sql
security invoker
set search_path = '' as $$
  select economics_v2.read_cycle_detail_impl(p_granja_id, p_cycle_id);
$$;

create or replace function public.listar_animales_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language sql
security invoker
set search_path = '' as $$
  select economics_v2.read_cycle_members_impl(p_granja_id, p_cycle_id);
$$;

create or replace function public.listar_alimentos_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language sql
security invoker
set search_path = '' as $$
  select economics_v2.read_cycle_feeds_impl(p_granja_id, p_cycle_id);
$$;

create or replace function public.listar_gastos_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language sql
security invoker
set search_path = '' as $$
  select economics_v2.read_cycle_expenses_impl(p_granja_id, p_cycle_id);
$$;

create or replace function public.listar_proyecciones_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language sql
security invoker
set search_path = '' as $$
  select economics_v2.read_cycle_projections_impl(p_granja_id, p_cycle_id);
$$;

create or replace function public.obtener_preparacion_cierre_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid
) returns jsonb
language sql
security invoker
set search_path = '' as $$
  select economics_v2.read_cycle_readiness_impl(p_granja_id, p_cycle_id);
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
  select economics_v2.replace_cycle_feed_impl(
    p_granja_id,
    p_cycle_id,
    p_mezcla_id,
    p_starts_on,
    p_ends_on
  );
$$;

create or replace function public.registrar_gasto_ciclo_v2_con_categoria(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_occurred_on date,
  p_amount numeric,
  p_category text,
  p_note text
) returns uuid
language sql
security invoker
set search_path = '' as $$
  select economics_v2.record_cycle_expense_with_category_impl(
    p_granja_id,
    p_cycle_id,
    p_occurred_on,
    p_amount,
    p_category,
    p_note
  );
$$;

create or replace function public.guardar_proyeccion_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_assumptions jsonb,
  p_note text
) returns jsonb
language sql
security invoker
set search_path = '' as $$
  select economics_v2.save_cycle_projection_impl(
    p_granja_id,
    p_cycle_id,
    p_assumptions,
    p_note
  );
$$;

create or replace function public.cerrar_produccion_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_closed_on date
) returns jsonb
language sql
security invoker
set search_path = '' as $$
  select economics_v2.close_cycle_production_impl(
    p_granja_id,
    p_cycle_id,
    p_closed_on
  );
$$;

revoke all on function economics_v2.assert_cycle_access_impl(uuid, uuid, boolean) from public, anon, authenticated;
revoke all on function economics_v2.calculate_cycle_v2_impl(uuid, uuid) from public, anon, authenticated;
revoke all on function economics_v2.read_cycle_detail_impl(uuid, uuid) from public, anon, authenticated;
revoke all on function economics_v2.read_cycle_members_impl(uuid, uuid) from public, anon, authenticated;
revoke all on function economics_v2.read_cycle_feeds_impl(uuid, uuid) from public, anon, authenticated;
revoke all on function economics_v2.read_cycle_expenses_impl(uuid, uuid) from public, anon, authenticated;
revoke all on function economics_v2.read_cycle_projections_impl(uuid, uuid) from public, anon, authenticated;
revoke all on function economics_v2.project_scenario_v2_impl(uuid, uuid, jsonb) from public, anon, authenticated;
revoke all on function economics_v2.save_cycle_projection_impl(uuid, uuid, jsonb, text) from public, anon, authenticated;
revoke all on function economics_v2.record_cycle_expense_with_category_impl(uuid, uuid, date, numeric, text, text) from public, anon, authenticated;
revoke all on function economics_v2.replace_cycle_feed_impl(uuid, uuid, uuid, date, date) from public, anon, authenticated;
revoke all on function economics_v2.read_cycle_readiness_impl(uuid, uuid) from public, anon, authenticated;
revoke all on function economics_v2.close_cycle_production_impl(uuid, uuid, date) from public, anon, authenticated;
revoke all on function economics_v2.finalize_cycle_impl(uuid, uuid) from public, anon, authenticated;
revoke all on function economics_v2.create_cycle_complete_impl(uuid, uuid, text, date, date) from public, anon, authenticated;
revoke all on function public.obtener_detalle_ciclo_v2(uuid, uuid) from public, anon, authenticated;
revoke all on function public.listar_animales_ciclo_v2(uuid, uuid) from public, anon, authenticated;
revoke all on function public.listar_alimentos_ciclo_v2(uuid, uuid) from public, anon, authenticated;
revoke all on function public.listar_gastos_ciclo_v2(uuid, uuid) from public, anon, authenticated;
revoke all on function public.listar_proyecciones_ciclo_v2(uuid, uuid) from public, anon, authenticated;
revoke all on function public.obtener_preparacion_cierre_ciclo_v2(uuid, uuid) from public, anon, authenticated;
revoke all on function public.reemplazar_alimento_ciclo_v2(uuid, uuid, uuid, date, date) from public, anon, authenticated;
revoke all on function public.registrar_gasto_ciclo_v2_con_categoria(uuid, uuid, date, numeric, text, text) from public, anon, authenticated;
revoke all on function public.guardar_proyeccion_ciclo_v2(uuid, uuid, jsonb, text) from public, anon, authenticated;
revoke all on function public.cerrar_produccion_ciclo_v2(uuid, uuid, date) from public, anon, authenticated;
revoke all on function public.finalizar_ciclo_v2(uuid, uuid) from public, anon, authenticated;

grant execute on function economics_v2.assert_cycle_access_impl(uuid, uuid, boolean) to authenticated;
grant execute on function economics_v2.calculate_cycle_v2_impl(uuid, uuid) to authenticated;
grant execute on function economics_v2.read_cycle_detail_impl(uuid, uuid) to authenticated;
grant execute on function economics_v2.read_cycle_members_impl(uuid, uuid) to authenticated;
grant execute on function economics_v2.read_cycle_feeds_impl(uuid, uuid) to authenticated;
grant execute on function economics_v2.read_cycle_expenses_impl(uuid, uuid) to authenticated;
grant execute on function economics_v2.read_cycle_projections_impl(uuid, uuid) to authenticated;
grant execute on function economics_v2.project_scenario_v2_impl(uuid, uuid, jsonb) to authenticated;
grant execute on function economics_v2.save_cycle_projection_impl(uuid, uuid, jsonb, text) to authenticated;
grant execute on function economics_v2.record_cycle_expense_with_category_impl(uuid, uuid, date, numeric, text, text) to authenticated;
grant execute on function economics_v2.replace_cycle_feed_impl(uuid, uuid, uuid, date, date) to authenticated;
grant execute on function economics_v2.read_cycle_readiness_impl(uuid, uuid) to authenticated;
grant execute on function economics_v2.close_cycle_production_impl(uuid, uuid, date) to authenticated;
grant execute on function economics_v2.finalize_cycle_impl(uuid, uuid) to authenticated;
grant execute on function public.obtener_detalle_ciclo_v2(uuid, uuid) to authenticated;
grant execute on function public.listar_animales_ciclo_v2(uuid, uuid) to authenticated;
grant execute on function public.listar_alimentos_ciclo_v2(uuid, uuid) to authenticated;
grant execute on function public.listar_gastos_ciclo_v2(uuid, uuid) to authenticated;
grant execute on function public.listar_proyecciones_ciclo_v2(uuid, uuid) to authenticated;
grant execute on function public.obtener_preparacion_cierre_ciclo_v2(uuid, uuid) to authenticated;
grant execute on function public.reemplazar_alimento_ciclo_v2(uuid, uuid, uuid, date, date) to authenticated;
grant execute on function public.registrar_gasto_ciclo_v2_con_categoria(uuid, uuid, date, numeric, text, text) to authenticated;
grant execute on function public.guardar_proyeccion_ciclo_v2(uuid, uuid, jsonb, text) to authenticated;
grant execute on function public.cerrar_produccion_ciclo_v2(uuid, uuid, date) to authenticated;
grant execute on function public.finalizar_ciclo_v2(uuid, uuid) to authenticated;
