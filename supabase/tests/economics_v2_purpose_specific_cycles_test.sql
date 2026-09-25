begin;

create or replace function pg_temp.assert_true(condition boolean, message text)
returns void language plpgsql as $$
begin
  if condition is distinct from true then
    raise exception '%', message;
  end if;
end;
$$;

select pg_temp.assert_true(
  to_regprocedure(
    'public.registrar_venta_animales_ciclo_v2(uuid,uuid,uuid[],date,numeric,numeric,text)'
  ) is not null
  and to_regprocedure('public.obtener_resultado_final_ciclo_v2(uuid,uuid)') is not null,
  'Purpose-specific cycles must expose cycle-scoped sale and immutable final-result reads'
);

select pg_temp.assert_true(
  (select not procedure.prosecdef
     and procedure.proconfig @> array['search_path=""']
     and has_function_privilege('authenticated', procedure.oid, 'execute')
     and not has_function_privilege('anon', procedure.oid, 'execute')
     and not exists (
       select 1
       from aclexplode(coalesce(
         procedure.proacl,
         acldefault('f', procedure.proowner)
       )) privilege
       where privilege.grantee = 0
         and privilege.privilege_type = 'EXECUTE'
     )
   from pg_proc procedure
   where procedure.oid = to_regprocedure(
     'public.registrar_venta_animales_ciclo_v2(uuid,uuid,uuid[],date,numeric,numeric,text)'
   )),
  'Cycle sale API must remain a fixed-path SECURITY INVOKER wrapper'
);

do $purpose_specific$
<<purpose_specific>>
declare
  editor_id uuid := '00000000-0000-0000-0000-000000009101';
  farm_id uuid := '00000000-0000-0000-0000-000000009201';
  type_id uuid := '00000000-0000-0000-0000-000000009301';
  group_id uuid := '00000000-0000-0000-0000-000000009401';
  meat_group_id uuid := '00000000-0000-0000-0000-000000009402';
  posture_one uuid := '00000000-0000-0000-0000-000000009501';
  posture_two uuid := '00000000-0000-0000-0000-000000009502';
  meat_one uuid := '00000000-0000-0000-0000-000000009503';
  meat_two uuid := '00000000-0000-0000-0000-000000009504';
  meat_three uuid := '00000000-0000-0000-0000-000000009505';
  meat_four uuid := '00000000-0000-0000-0000-000000009506';
  category_id uuid := '00000000-0000-0000-0000-000000009601';
  food_one uuid := '00000000-0000-0000-0000-000000009611';
  food_two uuid := '00000000-0000-0000-0000-000000009612';
  mixture_one uuid := '00000000-0000-0000-0000-000000009701';
  mixture_two uuid := '00000000-0000-0000-0000-000000009702';
  meat_mixture_one uuid := '00000000-0000-0000-0000-000000009703';
  meat_mixture_two uuid := '00000000-0000-0000-0000-000000009704';
  posture_purpose_id uuid;
  meat_purpose_id uuid;
  sale_reason_id uuid;
  posture_cycle_id uuid;
  meat_cycle_id uuid;
  empty_meat_cycle_id uuid;
  projection_one jsonb;
  projection_two jsonb;
  sale jsonb;
  actual jsonb;
  summaries jsonb;
  meat_summary jsonb;
  empty_meat_summary jsonb;
  final_result jsonb;
begin
  insert into auth.users (id, aud, role, email, created_at, updated_at)
  values (
    editor_id,
    'authenticated',
    'authenticated',
    'purpose-specific-editor@example.test',
    now(),
    now()
  );
  insert into public.perfiles (id, nombre)
  values (editor_id, 'Purpose-specific editor')
  on conflict (id) do update set nombre = excluded.nombre;
  insert into public.granjas (id, owner_id, nombre, created_by)
  values (farm_id, editor_id, 'Purpose-specific farm', editor_id);
  insert into economics_v2.feature_flags (granja_id, economics_v2_enabled)
  values (farm_id, true);

  select id into posture_purpose_id
  from public.cat_proposito_animal
  where codigo_calculo = 'postura'
  order by id limit 1;
  select id into meat_purpose_id
  from public.cat_proposito_animal
  where codigo_calculo = 'carne'
  order by id limit 1;
  select id into sale_reason_id
  from public.cat_razon_baja
  where genera_ingreso and activo
  order by id limit 1;
  if sale_reason_id is null then
    insert into public.cat_razon_baja (nombre, genera_ingreso, activo)
    values ('Purpose-specific sale', true, true)
    returning id into sale_reason_id;
  end if;

  insert into public.tipo_animal (id, granja_id, nombre, created_by)
  values (type_id, farm_id, 'Bird', editor_id);
  insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
  values
    (group_id, farm_id, type_id, 'Shared group', editor_id),
    (meat_group_id, farm_id, type_id, 'Meat group', editor_id);
  insert into public.animales (
    id, granja_id, tipo_animal_id, grupo_id, proposito_id,
    brazalete, fecha_adquisicion, created_by
  ) values
    (posture_one, farm_id, type_id, group_id, posture_purpose_id, 901, current_date - 20, editor_id),
    (posture_two, farm_id, type_id, group_id, posture_purpose_id, 902, current_date - 20, editor_id),
    (meat_one, farm_id, type_id, meat_group_id, meat_purpose_id, 903, current_date - 20, editor_id),
    (meat_two, farm_id, type_id, meat_group_id, meat_purpose_id, 904, current_date - 20, editor_id),
    (meat_three, farm_id, type_id, meat_group_id, meat_purpose_id, 905, current_date - 20, editor_id),
    (meat_four, farm_id, type_id, meat_group_id, meat_purpose_id, 906, current_date - 20, editor_id);

  update public.animales
  set costo_adquisicion = case id
    when meat_one then 10
    when meat_two then 20
    when meat_three then 30
    when meat_four then 40
  end
  where id in (meat_one, meat_two, meat_three, meat_four);

  insert into public.cat_comida (id, granja_id, nombre, created_by)
  values (category_id, farm_id, 'Balanced feed', editor_id);
  insert into public.comida (id, granja_id, cat_comida_id, precio, cantidad)
  values
    (food_one, farm_id, category_id, 60, 7),
    (food_two, farm_id, category_id, 40, 5);

  insert into public.mezcla (id, granja_id, grupo_id, fecha_inicio, created_by)
  values (mixture_one, farm_id, group_id, current_date - 10, editor_id);
  insert into public.mezcla_comida (granja_id, mezcla_id, comida_id, cantidad)
  values
    (farm_id, mixture_one, food_one, 7),
    (farm_id, mixture_one, food_two, 5);

  insert into public.mezcla (
    id, granja_id, grupo_id, fecha_inicio, created_by
  ) values
    (meat_mixture_one, farm_id, meat_group_id, current_date - 3, editor_id),
    (meat_mixture_two, farm_id, meat_group_id, current_date - 1, editor_id);
  insert into public.mezcla_comida (
    granja_id, mezcla_id, comida_id, cantidad
  ) values
    (farm_id, meat_mixture_one, food_one, 3),
    (farm_id, meat_mixture_one, food_two, 2),
    (farm_id, meat_mixture_two, food_one, 4),
    (farm_id, meat_mixture_two, food_two, 1);
  perform set_config('request.jwt.claim.sub', editor_id::text, true);
  set local role authenticated;
  select public.crear_ciclo_v2_con_fechas(
    farm_id, posture_purpose_id, current_date - 10, null
  ) into posture_cycle_id;
  perform public.asignar_animal_ciclo_v2(
    farm_id, posture_cycle_id, posture_one, current_date - 10
  );
  perform public.asignar_animal_ciclo_v2(
    farm_id, posture_cycle_id, posture_two, current_date - 10
  );
  reset role;
  update economics_v2.cycle_animals
  set left_on = current_date - 5
  where cycle_id = posture_cycle_id and animal_id = posture_two;
  set local role authenticated;
  perform public.reemplazar_alimento_ciclo_v2(
    farm_id, posture_cycle_id, mixture_one, current_date - 10, null
  );
  reset role;

  insert into economics_v2.projections (
    cycle_id,
    granja_id,
    assumptions,
    result_snapshot,
    note,
    calculation_version,
    created_by
  ) values (
    posture_cycle_id,
    farm_id,
    jsonb_build_object('legacy_horizon_days', 30),
    jsonb_build_object('legacy_result', true),
    'Preserved legacy projection',
    'v2',
    editor_id
  );

  set local role authenticated;

  select public.guardar_proyeccion_ciclo_v2(
    farm_id,
    posture_cycle_id,
    jsonb_build_object(
      'expected_unit_price', 3,
      'production_per_day', 4,
      'feed_rate_kg_per_bird_day', 0.1,
      'other_costs', 10
    ),
    'Current projection'
  ) into projection_one;
  select public.guardar_proyeccion_ciclo_v2(
    farm_id,
    posture_cycle_id,
    jsonb_build_object(
      'expected_unit_price', 4,
      'production_per_day', 5,
      'feed_rate_kg_per_bird_day', 0.1,
      'other_costs', 12
    ),
    'Replacement projection'
  ) into projection_two;

  reset role;

  perform pg_temp.assert_true(
    (projection_one -> 'result' ->> 'available_feed_kg')::numeric = 12
    and (projection_one -> 'result' ->> 'historical_bird_days')::numeric = 15
    and (projection_one -> 'result' ->> 'consumed_kg')::numeric = 1.5
    and (projection_one -> 'result' ->> 'remaining_kg')::numeric = 10.5
    and (projection_one -> 'result' ->> 'current_active_birds')::integer = 1
    and (projection_one -> 'result' ->> 'remaining_days')::integer = 105
    and (projection_one -> 'result' ->> 'projected_horizon_days')::integer = 115
    and (projection_one -> 'result' ->> 'weighted_average_birds')::numeric = 1.5
    and (projection_two -> 'result' ->> 'remaining_days')::integer = 105
    and (select count(*) = 1
         from economics_v2.projections
         where cycle_id = posture_cycle_id
           and calculation_version = 'v3')
    and (select count(*) = 1
         from economics_v2.projections
         where cycle_id = posture_cycle_id
           and calculation_version = 'v2'),
    'Posture projection must use ingredient kg, half-open bird-days, replace the current forecast, and preserve legacy data'
  );

  insert into public.mezcla (id, granja_id, grupo_id, fecha_inicio, created_by)
  values (mixture_two, farm_id, group_id, current_date, editor_id);
  perform pg_temp.assert_true(
    (select fecha_termino = current_date
     from public.mezcla where id = mixture_one)
    and (select fecha_termino is null
         from public.mezcla where id = mixture_two)
    and (select count(*) = 1
         from public.mezcla
         where grupo_id = purpose_specific.group_id
           and fecha_termino is null)
    and (select status = 'production_closed'
         and production_closed_on = current_date - 1
         from economics_v2.cycles where id = posture_cycle_id),
    'Replacing a group mixture must close its posture cycle at the new half-open boundary'
  );

  set local role authenticated;
  begin
    perform public.reemplazar_alimento_ciclo_v2(
      farm_id, posture_cycle_id, mixture_two, current_date, null
    );
    raise exception 'posture cycles must reject a second feed mixture';
  exception when check_violation then null;
  end;

  select public.crear_ciclo_v2_con_fechas(
    farm_id, meat_purpose_id, current_date - 3, null
  ) into meat_cycle_id;
  perform public.asignar_animal_ciclo_v2(
    farm_id, meat_cycle_id, meat_one, current_date - 3
  );
  perform public.asignar_animal_ciclo_v2(
    farm_id, meat_cycle_id, meat_two, current_date - 3
  );
  perform public.asignar_animal_ciclo_v2(
    farm_id, meat_cycle_id, meat_three, current_date - 3
  );
  perform public.asignar_animal_ciclo_v2(
    farm_id, meat_cycle_id, meat_four, current_date - 3
  );
  perform public.reemplazar_alimento_ciclo_v2(
    farm_id,
    meat_cycle_id,
    meat_mixture_one,
    current_date - 3,
    current_date - 1
  );
  perform public.reemplazar_alimento_ciclo_v2(
    farm_id,
    meat_cycle_id,
    meat_mixture_two,
    current_date - 1,
    null
  );
  reset role;

  insert into economics_v2.cycle_expenses (
    cycle_id, granja_id, occurred_on, amount, created_by
  ) values (meat_cycle_id, farm_id, current_date - 2, 25, editor_id);

  set local role authenticated;

  begin
    perform public.guardar_proyeccion_ciclo_v2(
      farm_id,
      meat_cycle_id,
      jsonb_build_object(
        'expected_unit_price', 4,
        'production_per_day', 5,
        'feed_rate_kg_per_bird_day', 0.1,
        'other_costs', 12
      ),
      null
    );
    raise exception 'meat cycles must reject generic projections';
  exception when invalid_parameter_value then null;
  end;

  select public.registrar_venta_animales_ciclo_v2(
    farm_id,
    meat_cycle_id,
    array[meat_one, meat_two],
    current_date - 1,
    100,
    10,
    'First sale'
  ) into sale;
  select public.listar_resumen_ciclos_v2(farm_id) into summaries;
  select value
  into meat_summary
  from jsonb_array_elements(summaries) value
  where value ->> 'cycle_id' = meat_cycle_id::text;

  perform pg_temp.assert_true(
    (meat_summary ->> 'animal_sale_revenue')::numeric = 100
    and (meat_summary ->> 'sale_count')::integer = 1
    and (meat_summary ->> 'sold_animal_count')::integer = 2,
    'One multi-animal sale must contribute its distinct sale amount and count exactly once'
  );

  select public.registrar_venta_animales_ciclo_v2(
    farm_id,
    meat_cycle_id,
    array[meat_three, meat_four],
    current_date,
    150,
    12,
    'Second sale'
  ) into sale;
  select public.calcular_ciclo_v2(farm_id, meat_cycle_id) into actual;

  select public.crear_ciclo_v2_con_fechas(
    farm_id, meat_purpose_id, current_date, null
  ) into empty_meat_cycle_id;
  select public.listar_resumen_ciclos_v2(farm_id) into summaries;
  reset role;

  select value
  into meat_summary
  from jsonb_array_elements(summaries) value
  where value ->> 'cycle_id' = meat_cycle_id::text;
  select value
  into empty_meat_summary
  from jsonb_array_elements(summaries) value
  where value ->> 'cycle_id' = empty_meat_cycle_id::text;

  perform pg_temp.assert_true(
    sale ->> 'status' = 'production_closed'
    and (sale ->> 'sold_count')::integer = 2
    and (actual ->> 'revenue')::numeric = 250
    and (actual ->> 'production_units')::numeric = 22
    and (select count(*) = 0
         from economics_v2.cycle_animals
         where cycle_id = meat_cycle_id and left_on is null)
    and (select status = 'production_closed'
         and production_closed_on = current_date
         from economics_v2.cycles where id = meat_cycle_id),
    'A second distinct sale must add revenue once and sell-all must auto-close production'
  );

  perform pg_temp.assert_true(
    meat_summary ->> 'purpose_code' = 'carne'
    and (meat_summary ->> 'animal_count')::integer = 4
    and (meat_summary ->> 'feed_cost')::numeric = 200
    and (meat_summary ->> 'feed_kg_total')::numeric = 10
    and (meat_summary ->> 'direct_expense_total')::numeric = 25
    and (meat_summary ->> 'acquisition_cost')::numeric = 100
    and (meat_summary ->> 'total_cost')::numeric = 325
    and (meat_summary ->> 'animal_sale_revenue')::numeric = 250
    and (meat_summary ->> 'sale_count')::integer = 2
    and (meat_summary ->> 'sold_animal_count')::integer = 4
    and (meat_summary ->> 'profit')::numeric = -75
    and (meat_summary ->> 'balance_per_animal')::numeric = -18.75
    and (meat_summary ->> 'linked_mixture_count')::integer = 2
    and meat_summary ->> 'latest_linked_group_name' = 'Meat group'
    and (meat_summary ->> 'production_closed_on')::date = current_date
    and (meat_summary ->> 'ends_on')::date = current_date + 1,
    'Meat summary must aggregate distinct mixtures, ingredients, acquisition, sales, and closed display date without multiplying rows'
  );

  perform pg_temp.assert_true(
    empty_meat_summary -> 'balance_per_animal' = 'null'::jsonb,
    'A zero-animal meat cycle must return a null balance per animal'
  );

  insert into economics_v2.final_results (
    cycle_id, granja_id, calculation_version,
    input_snapshot, result_snapshot, created_by
  ) values (
    meat_cycle_id,
    farm_id,
    'v2',
    '{}'::jsonb,
    jsonb_build_object(
      'cycle_id', meat_cycle_id,
      'purpose_code', 'carne',
      'production_basis', 'saleable_kg',
      'total_cost', 25,
      'revenue', 100,
      'profit', 75,
      'margin', 75,
      'break_even', 5
    ),
    editor_id
  );
  update economics_v2.cycles
  set status = 'settled', settled_on = current_date
  where id = meat_cycle_id;

  set local role authenticated;
  select public.obtener_resultado_final_ciclo_v2(farm_id, meat_cycle_id)
  into final_result;
  reset role;
  perform pg_temp.assert_true(
    (final_result -> 'result' ->> 'profit')::numeric = 75
    and final_result ->> 'calculation_version' = 'v2',
    'Settled reads must return the immutable final_results.result_snapshot'
  );
end;
$purpose_specific$;

rollback;
