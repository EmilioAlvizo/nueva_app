begin;

create or replace function pg_temp.assert_true(condition boolean, message text)
returns void language plpgsql as $$
begin
  if condition is distinct from true then
    raise exception '%', message;
  end if;
end;
$$;

-- Task 3.2 must expose authenticated security-invoker wrappers for the engine.
select pg_temp.assert_true(
  to_regprocedure('public.calcular_ciclo_v2(uuid,uuid)') is not null
  and to_regprocedure('public.proyectar_ciclo_v2(uuid,uuid,jsonb)') is not null
  and to_regprocedure('public.finalizar_ciclo_v2(uuid,uuid)') is not null,
  'Task 3.2 must expose the calculation, projection, and finalization public APIs'
);

select pg_temp.assert_true(
  exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('calcular_ciclo_v2', 'proyectar_ciclo_v2', 'finalizar_ciclo_v2')
      and not p.prosecdef
  ),
  'calculation and finalization public APIs must remain security invoker'
);

do $calculations$
declare
  editor_id uuid := '00000000-0000-0000-0000-000000003101';
  outsider_id uuid := '00000000-0000-0000-0000-000000003102';
  farm_a uuid := '00000000-0000-0000-0000-000000003201';
  farm_b uuid := '00000000-0000-0000-0000-000000003202';
  type_a uuid := '00000000-0000-0000-0000-000000003301';
  group_posture uuid := '00000000-0000-0000-0000-000000003401';
  group_meat uuid := '00000000-0000-0000-0000-000000003402';
  group_ornamental uuid := '00000000-0000-0000-0000-000000003403';
  posture_animal_1 uuid := '00000000-0000-0000-0000-000000003501';
  posture_animal_2 uuid := '00000000-0000-0000-0000-000000003502';
  meat_animal uuid := '00000000-0000-0000-0000-000000003503';
  ornamental_animal uuid := '00000000-0000-0000-0000-000000003504';
  foreign_animal uuid := '00000000-0000-0000-0000-000000003505';
  posture_cycle uuid := '00000000-0000-0000-0000-000000003601';
  meat_cycle uuid := '00000000-0000-0000-0000-000000003602';
  ornamental_cycle uuid := '00000000-0000-0000-0000-000000003603';
  foreign_cycle uuid := '00000000-0000-0000-0000-000000003604';
  posture_mix uuid := '00000000-0000-0000-0000-000000003701';
  meat_mix uuid := '00000000-0000-0000-0000-000000003702';
  ornamental_mix uuid := '00000000-0000-0000-0000-000000003703';
  posture_food uuid := '00000000-0000-0000-0000-000000003801';
  meat_food uuid := '00000000-0000-0000-0000-000000003802';
  ornamental_food uuid := '00000000-0000-0000-0000-000000003803';
  posture_output jsonb;
  meat_output jsonb;
  ornamental_output jsonb;
  projection_one jsonb;
  projection_two jsonb;
  final_output jsonb;
  final_snapshot jsonb;
  final_result jsonb;
begin
  insert into auth.users (id, aud, role, email, created_at, updated_at)
  values
    (editor_id, 'authenticated', 'authenticated', 'economics-v2-calculations-editor@example.test', now(), now()),
    (outsider_id, 'authenticated', 'authenticated', 'economics-v2-calculations-outsider@example.test', now(), now());
  insert into public.perfiles (id, nombre)
  values (editor_id, 'Calculations editor'), (outsider_id, 'Calculations outsider')
  on conflict (id) do update set nombre = excluded.nombre;
  insert into public.granjas (id, owner_id, nombre, created_by)
  values
    (farm_a, editor_id, 'Calculations farm A', editor_id),
    (farm_b, outsider_id, 'Calculations farm B', outsider_id);
  insert into public.tipo_animal (id, granja_id, nombre, created_by)
  values (type_a, farm_a, 'Calculation bird', editor_id);
  insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
  values
    (group_posture, farm_a, type_a, 'Posture group', editor_id),
    (group_meat, farm_a, type_a, 'Meat group', editor_id),
    (group_ornamental, farm_a, type_a, 'Ornamental group', editor_id);
  insert into public.animales (id, granja_id, tipo_animal_id, grupo_id, fecha_adquisicion, created_by)
  values
    (posture_animal_1, farm_a, type_a, group_posture, current_date - 10, editor_id),
    (posture_animal_2, farm_a, type_a, group_posture, current_date - 10, editor_id),
    (meat_animal, farm_a, type_a, group_meat, current_date - 10, editor_id),
    (ornamental_animal, farm_a, type_a, group_ornamental, current_date - 10, editor_id),
    (foreign_animal, farm_b, type_a, null, current_date - 10, outsider_id);
  insert into economics_v2.feature_flags (granja_id, economics_v2_enabled)
  values (farm_a, true), (farm_b, true);
  insert into economics_v2.cycles (id, granja_id, proposito_id, starts_on, created_by)
  select posture_cycle, farm_a, id, current_date - 5, editor_id
  from public.cat_proposito_animal where codigo_calculo = 'postura' limit 1;
  insert into economics_v2.cycles (id, granja_id, proposito_id, starts_on, created_by)
  select meat_cycle, farm_a, id, current_date - 5, editor_id
  from public.cat_proposito_animal where codigo_calculo = 'carne' limit 1;
  insert into economics_v2.cycles (id, granja_id, proposito_id, starts_on, created_by)
  select ornamental_cycle, farm_a, id, current_date - 5, editor_id
  from public.cat_proposito_animal where codigo_calculo = 'ornamental' limit 1;
  insert into economics_v2.cycles (id, granja_id, proposito_id, starts_on, created_by)
  select foreign_cycle, farm_b, id, current_date - 5, outsider_id
  from public.cat_proposito_animal where codigo_calculo = 'carne' limit 1;
  insert into economics_v2.cycle_animals (cycle_id, animal_id, joined_on)
  values
    (posture_cycle, posture_animal_1, current_date - 5),
    (posture_cycle, posture_animal_2, current_date - 5),
    (meat_cycle, meat_animal, current_date - 5),
    (ornamental_cycle, ornamental_animal, current_date - 5),
    (foreign_cycle, foreign_animal, current_date - 5);

  insert into public.cat_comida (id, granja_id, nombre, created_by)
  values
    (posture_food, farm_a, 'Posture feed', editor_id),
    (meat_food, farm_a, 'Meat feed', editor_id),
    (ornamental_food, farm_a, 'Ornamental feed', editor_id);
  insert into public.comida (id, granja_id, cat_comida_id, precio, cantidad)
  values
    (posture_food, farm_a, posture_food, 10, 1),
    (meat_food, farm_a, meat_food, 20, 1),
    (ornamental_food, farm_a, ornamental_food, 30, 1);
  insert into public.mezcla (id, granja_id, grupo_id, fecha_inicio, fecha_termino, created_by)
  values
    (posture_mix, farm_a, group_posture, current_date - 5, current_date - 3, editor_id),
    (meat_mix, farm_a, group_meat, current_date - 5, current_date - 3, editor_id),
    (ornamental_mix, farm_a, group_ornamental, current_date - 5, current_date - 3, editor_id);
  insert into public.mezcla_comida (granja_id, mezcla_id, comida_id, cantidad)
  values
    (farm_a, posture_mix, posture_food, 1),
    (farm_a, meat_mix, meat_food, 1),
    (farm_a, ornamental_mix, ornamental_food, 1);
  insert into economics_v2.cycle_feeds (cycle_id, granja_id, mezcla_id, starts_on, ends_on, created_by)
  values
    (posture_cycle, farm_a, posture_mix, current_date - 5, current_date - 3, editor_id),
    (posture_cycle, farm_a, posture_mix, current_date - 4, current_date - 2, editor_id),
    (meat_cycle, farm_a, meat_mix, current_date - 5, current_date - 3, editor_id),
    (ornamental_cycle, farm_a, ornamental_mix, current_date - 5, current_date - 3, editor_id);
  insert into economics_v2.cycle_expenses (cycle_id, granja_id, occurred_on, amount, note, created_by)
  values
    (posture_cycle, farm_a, current_date - 4, 5, 'Posture direct cost', editor_id),
    (meat_cycle, farm_a, current_date - 4, 7, 'Meat direct cost', editor_id),
    (ornamental_cycle, farm_a, current_date - 4, 11, 'Ornamental direct cost', editor_id);
  insert into public.recoleccion_huevo (granja_id, grupo_id, fecha_recoleccion, buenos, rotos, created_by)
  values
    (farm_a, group_posture, current_date - 4, 12, 1, editor_id),
    (farm_a, group_posture, current_date - 2, 99, 0, editor_id);
  insert into public.venta_huevo (granja_id, grupo_id, fecha_venta, cantidad, precio, created_by)
  values
    (farm_a, group_posture, current_date - 4, 12, 3, editor_id),
    (farm_a, group_posture, current_date - 2, 99, 9, editor_id);
  insert into public.venta_animal (granja_id, tipo_animal_id, animal_id, fecha_venta, created_by, record_kind, quantity, total_amount)
  values
    (farm_a, type_a, meat_animal, current_date - 4, editor_id, 'individual', 1, 80),
    (farm_a, type_a, ornamental_animal, current_date - 4, editor_id, 'individual', 1, 120);
  update economics_v2.cycle_animals
  set left_on = current_date - 4,
      sold_by_sale_id = (select id from public.venta_animal where animal_id = meat_animal)
  where cycle_id = meat_cycle and animal_id = meat_animal;
  update economics_v2.cycle_animals
  set left_on = current_date - 4,
      sold_by_sale_id = (select id from public.venta_animal where animal_id = ornamental_animal)
  where cycle_id = ornamental_cycle and animal_id = ornamental_animal;

  perform set_config('request.jwt.claim.sub', editor_id::text, true);
  set local role authenticated;
  select public.calcular_ciclo_v2(farm_a, posture_cycle) into posture_output;
  select public.calcular_ciclo_v2(farm_a, meat_cycle) into meat_output;
  select public.calcular_ciclo_v2(farm_a, ornamental_cycle) into ornamental_output;
  reset role;

  perform pg_temp.assert_true(
    posture_output @> jsonb_build_object(
      'purpose_code', 'postura', 'production_basis', 'eggs', 'production_units', 12,
      'revenue', 36, 'feed_cost', 10, 'direct_cost', 5, 'total_cost', 15,
      'margin', 21, 'break_even', 1.25
    )
    and posture_output ? 'animal_sale_revenue'
    and posture_output -> 'animal_sale_revenue' = 'null'::jsonb
    and posture_output ? 'sold_members'
    and posture_output -> 'sold_members' = 'null'::jsonb,
    'posture must use a half-open egg basis, deduplicate overlapping feed links, and emit animal-only metrics as explicit JSON nulls'
  );
  perform pg_temp.assert_true(
    meat_output @> jsonb_build_object(
      'purpose_code', 'carne', 'production_basis', 'sold_animals', 'production_units', 1,
      'revenue', 80, 'feed_cost', 20, 'direct_cost', 7, 'total_cost', 27,
      'margin', 53, 'break_even', 27
    )
    and meat_output ? 'egg_production'
    and meat_output -> 'egg_production' = 'null'::jsonb
    and meat_output ? 'egg_revenue'
    and meat_output -> 'egg_revenue' = 'null'::jsonb,
    'meat must use only its explicitly linked feed, direct cost, closed-member canonical sale, and explicit egg-metric JSON nulls'
  );
  perform pg_temp.assert_true(
    ornamental_output @> jsonb_build_object(
      'purpose_code', 'ornamental', 'production_basis', 'specimens', 'production_units', 1,
      'revenue', 120, 'feed_cost', 30, 'direct_cost', 11, 'total_cost', 41,
      'margin', 79, 'break_even', 41
    )
    and ornamental_output ? 'egg_production'
    and ornamental_output -> 'egg_production' = 'null'::jsonb
    and ornamental_output ? 'egg_revenue'
    and ornamental_output -> 'egg_revenue' = 'null'::jsonb,
    'ornamental must use specimen sales, its own linked feed, and explicit egg-metric JSON nulls'
  );

  set local role authenticated;
  begin
    perform public.calcular_ciclo_v2(farm_b, foreign_cycle);
    raise exception 'cross-farm calculation must be rejected';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.finalizar_ciclo_v2(farm_b, foreign_cycle);
    raise exception 'cross-farm finalization must be rejected';
  exception when insufficient_privilege then null;
  end;
  reset role;

  set local role authenticated;
  select public.proyectar_ciclo_v2(farm_a, posture_cycle, '{"expected_units": 20, "unit_price": 3}'::jsonb) into projection_one;
  select public.proyectar_ciclo_v2(farm_a, posture_cycle, '{"expected_units": 40, "unit_price": 3}'::jsonb) into projection_two;
  reset role;
  perform pg_temp.assert_true(
    projection_one ->> 'kind' = 'projection'
    and (projection_one ->> 'projected_revenue')::numeric = 60
    and (projection_two ->> 'projected_revenue')::numeric = 120
    and projection_one <> projection_two
    and (select count(*) = 0 from economics_v2.final_results where cycle_id = posture_cycle),
    'projection assumptions must change only hypothetical output and must not finalize actuals'
  );

  set local role authenticated;
  select public.finalizar_ciclo_v2(farm_a, posture_cycle) into final_output;
  reset role;
  select input_snapshot, result_snapshot into final_snapshot, final_result
  from economics_v2.final_results where cycle_id = posture_cycle;
  perform pg_temp.assert_true(
    final_output @> jsonb_build_object('cycle_id', posture_cycle, 'calculation_version', 'v1')
    and final_snapshot is not null
    and final_result = posture_output
    and (select count(*) = 1 from economics_v2.final_results where cycle_id = posture_cycle),
    'finalization must insert exactly one versioned input and result snapshot'
  );

  begin
    update economics_v2.final_results
    set result_snapshot = '{}'::jsonb
    where cycle_id = posture_cycle;
    raise exception 'final snapshots must be immutable';
  exception when insufficient_privilege or check_violation or raise_exception then
    if sqlerrm = 'final snapshots must be immutable' then raise; end if;
  end;
  perform pg_temp.assert_true(
    (select result_snapshot = final_result from economics_v2.final_results where cycle_id = posture_cycle),
    'attempted final snapshot mutation must leave the persisted result unchanged'
  );

  set local role authenticated;
  begin
    perform public.finalizar_ciclo_v2(farm_a, posture_cycle);
    raise exception 'repeat finalization must be rejected';
  exception when unique_violation or check_violation or raise_exception then
    if sqlerrm = 'repeat finalization must be rejected' then raise; end if;
  end;
  reset role;
end;
$calculations$;

rollback;
