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
  to_regprocedure('public.obtener_detalle_ciclo_v2(uuid,uuid)') is not null
  and to_regprocedure('public.listar_animales_ciclo_v2(uuid,uuid)') is not null
  and to_regprocedure('public.listar_alimentos_ciclo_v2(uuid,uuid)') is not null
  and to_regprocedure('public.listar_gastos_ciclo_v2(uuid,uuid)') is not null
  and to_regprocedure('public.listar_proyecciones_ciclo_v2(uuid,uuid)') is not null
  and to_regprocedure('public.obtener_preparacion_cierre_ciclo_v2(uuid,uuid)') is not null
  and to_regprocedure('public.reemplazar_alimento_ciclo_v2(uuid,uuid,uuid,date,date)') is not null
  and to_regprocedure('public.registrar_gasto_ciclo_v2_con_categoria(uuid,uuid,date,numeric,text,text)') is not null
  and to_regprocedure('public.guardar_proyeccion_ciclo_v2(uuid,uuid,jsonb,text)') is not null
  and to_regprocedure('public.cerrar_produccion_ciclo_v2(uuid,uuid,date)') is not null
  and to_regprocedure('public.finalizar_ciclo_v2(uuid,uuid)') is not null,
  'Finance cycle full scope must expose every focused read and mutation contract'
);

select pg_temp.assert_true(
  (select count(*)
   from pg_proc procedure
   join pg_namespace namespace on namespace.oid = procedure.pronamespace
   where namespace.nspname = 'public'
     and procedure.proname in (
       'obtener_detalle_ciclo_v2',
       'listar_animales_ciclo_v2',
       'listar_alimentos_ciclo_v2',
       'listar_gastos_ciclo_v2',
       'listar_proyecciones_ciclo_v2',
       'obtener_preparacion_cierre_ciclo_v2',
       'reemplazar_alimento_ciclo_v2',
       'registrar_gasto_ciclo_v2_con_categoria',
       'guardar_proyeccion_ciclo_v2',
       'cerrar_produccion_ciclo_v2',
       'finalizar_ciclo_v2'
      )
     and not procedure.prosecdef
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
      )) = 11,
  'Finance cycle public APIs must be fixed-path invokers executable only by authenticated'
);

select pg_temp.assert_true(
  (select count(*)
   from pg_proc procedure
   join pg_namespace namespace on namespace.oid = procedure.pronamespace
   where namespace.nspname = 'economics_v2'
     and procedure.proname in (
       'read_cycle_detail_impl',
       'read_cycle_members_impl',
       'read_cycle_feeds_impl',
       'read_cycle_expenses_impl',
       'read_cycle_projections_impl',
       'read_cycle_readiness_impl',
       'replace_cycle_feed_impl',
       'record_cycle_expense_with_category_impl',
       'save_cycle_projection_impl',
       'close_cycle_production_impl',
       'finalize_cycle_impl'
     )
     and procedure.prosecdef
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
     )) = 11,
  'Finance cycle private implementations must be fixed-path definers executable only by authenticated'
);

select pg_temp.assert_true(
  (select procedure.prosecdef
     and procedure.proconfig @> array['search_path=""']
     and not has_function_privilege('authenticated', procedure.oid, 'execute')
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
     'economics_v2.create_cycle_complete_impl(uuid,uuid,text,date,date)'
   )),
  'Cycle creation implementation must remain a private fixed-path definer'
);

do $full_scope$
<<full_scope>>
declare
  editor_id uuid := '00000000-0000-0000-0000-000000008101';
  viewer_id uuid := '00000000-0000-0000-0000-000000008102';
  outsider_id uuid := '00000000-0000-0000-0000-000000008103';
  farm_id uuid := '00000000-0000-0000-0000-000000008201';
  foreign_farm_id uuid := '00000000-0000-0000-0000-000000008202';
  type_id uuid := '00000000-0000-0000-0000-000000008301';
  group_id uuid := '00000000-0000-0000-0000-000000008401';
  animal_one uuid := '00000000-0000-0000-0000-000000008501';
  animal_two uuid := '00000000-0000-0000-0000-000000008502';
  food_one uuid := '00000000-0000-0000-0000-000000008601';
  food_two uuid := '00000000-0000-0000-0000-000000008602';
  mixture_one uuid := '00000000-0000-0000-0000-000000008701';
  mixture_two uuid := '00000000-0000-0000-0000-000000008702';
  purpose_id uuid;
  cycle_id uuid;
  first_feed_id uuid;
  second_feed_id uuid;
  expense_id uuid;
  detail jsonb;
  members jsonb;
  feeds jsonb;
  readiness jsonb;
  projection jsonb;
  finalization jsonb;
begin
  insert into auth.users (id, aud, role, email, created_at, updated_at)
  values
    (editor_id, 'authenticated', 'authenticated', 'full-scope-editor@example.test', now(), now()),
    (viewer_id, 'authenticated', 'authenticated', 'full-scope-viewer@example.test', now(), now()),
    (outsider_id, 'authenticated', 'authenticated', 'full-scope-outsider@example.test', now(), now());
  insert into public.perfiles (id, nombre)
  values
    (editor_id, 'Full scope editor'),
    (viewer_id, 'Full scope viewer'),
    (outsider_id, 'Full scope outsider')
  on conflict (id) do update set nombre = excluded.nombre;
  insert into public.granjas (id, owner_id, nombre, created_by)
  values
    (farm_id, editor_id, 'Full scope farm', editor_id),
    (foreign_farm_id, outsider_id, 'Foreign farm', outsider_id);
  insert into public.miembros_granja (granja_id, user_id, rol, invited_by)
  values (farm_id, viewer_id, 'viewer', editor_id);
  insert into economics_v2.feature_flags (granja_id, economics_v2_enabled)
  values (farm_id, true), (foreign_farm_id, true);
  select id into purpose_id
  from public.cat_proposito_animal
  where codigo_calculo = 'postura'
  order by id
  limit 1;
  insert into public.tipo_animal (id, granja_id, nombre, created_by)
  values (type_id, farm_id, 'Full scope bird', editor_id);
  insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
  values (group_id, farm_id, type_id, 'Original group', editor_id);
  insert into public.animales (
    id, granja_id, tipo_animal_id, grupo_id, proposito_id,
    brazalete, fecha_adquisicion, created_by
  ) values
    (animal_one, farm_id, type_id, group_id, purpose_id, 101, current_date - 10, editor_id),
    (animal_two, farm_id, type_id, group_id, purpose_id, 102, current_date - 10, editor_id);
  insert into public.cat_comida (id, granja_id, nombre, created_by)
  values
    (food_one, farm_id, 'Feed one', editor_id),
    (food_two, farm_id, 'Feed two', editor_id);
  insert into public.comida (id, granja_id, cat_comida_id, precio, cantidad)
  values
    (food_one, farm_id, food_one, 20, 1),
    (food_two, farm_id, food_two, 30, 1);
  insert into public.mezcla (id, granja_id, grupo_id, fecha_inicio, created_by)
  values
    (mixture_one, farm_id, group_id, current_date - 6, editor_id),
    (mixture_two, farm_id, group_id, current_date - 3, editor_id);
  insert into public.mezcla_comida (granja_id, mezcla_id, comida_id, cantidad)
  values
    (farm_id, mixture_one, food_one, 1),
    (farm_id, mixture_two, food_two, 1);

  perform set_config('request.jwt.claim.sub', editor_id::text, true);
  set local role authenticated;
  select public.crear_ciclo_v2_con_fechas(
    farm_id, purpose_id, current_date - 7, current_date + 7
  ) into cycle_id;
  perform public.asignar_animal_ciclo_v2(
    farm_id, cycle_id, animal_one, current_date - 7
  );
  select public.reemplazar_alimento_ciclo_v2(
    farm_id, cycle_id, mixture_one, current_date - 6, null
  ) into first_feed_id;
  select public.reemplazar_alimento_ciclo_v2(
    farm_id, cycle_id, mixture_two, current_date - 3, null
  ) into second_feed_id;
  reset role;

  perform pg_temp.assert_true(
    (select starts_on = current_date - 6 and ends_on = current_date - 3
     from economics_v2.cycle_feeds where id = first_feed_id)
    and (select starts_on = current_date - 3 and ends_on is null
         from economics_v2.cycle_feeds where id = second_feed_id),
    'feed replacement must close the prior half-open interval exactly at the new start'
  );

  update public.grupos set nombre = 'Renamed group' where id = group_id;
  set local role authenticated;
  select public.listar_alimentos_ciclo_v2(farm_id, cycle_id) into feeds;
  select public.obtener_detalle_ciclo_v2(farm_id, cycle_id) into detail;
  select public.listar_animales_ciclo_v2(farm_id, cycle_id) into members;
  select public.obtener_preparacion_cierre_ciclo_v2(farm_id, cycle_id) into readiness;
  reset role;

  perform pg_temp.assert_true(
    feeds -> 'intervals' -> 0 ->> 'group_name_snapshot' = 'Original group'
    and detail ->> 'status' = 'open'
    and jsonb_array_length(members -> 'members') = 1
    and jsonb_array_length(members -> 'candidates') = 1
    and (detail ->> 'direct_expense_total')::numeric = 0
    and readiness ->> 'can_close_production' = 'true',
    'reads must use real scoped data, preserve historical group snapshots, and allow zero direct expense'
  );

  set local role authenticated;
  begin
    perform public.registrar_gasto_ciclo_v2_con_categoria(
      farm_id, cycle_id, current_date - 2, 0, 'Veterinary', 'Invalid zero'
    );
    raise exception 'zero expenses must be rejected';
  exception when invalid_parameter_value then null;
  end;
  select public.registrar_gasto_ciclo_v2_con_categoria(
    farm_id, cycle_id, current_date - 2, 15, 'Veterinary', 'Routine treatment'
  ) into expense_id;
  select public.guardar_proyeccion_ciclo_v2(
    farm_id,
    cycle_id,
    jsonb_build_object(
      'expected_unit_price', 3,
      'production_per_day', 10,
      'feed_per_day', 2,
      'other_costs', 5,
      'horizon_days', 30
    ),
    'Conservative scenario'
  ) into projection;
  reset role;

  perform pg_temp.assert_true(
    expense_id is not null
    and projection ->> 'projection_id' is not null
    and (projection -> 'result' ->> 'projected_revenue')::numeric = 900
    and (select count(*) = 1 from economics_v2.projections projection where projection.cycle_id = full_scope.cycle_id)
    and (select count(*) = 0 from economics_v2.final_results result where result.cycle_id = full_scope.cycle_id),
    'projection persistence must remain hypothetical and separate from actual and final data'
  );

  insert into public.recoleccion_huevo (
    granja_id, grupo_id, fecha_recoleccion, buenos, rotos, created_by
  ) values (farm_id, group_id, current_date - 2, 20, 1, editor_id);

  set local role authenticated;
  perform public.cerrar_produccion_ciclo_v2(
    farm_id, cycle_id, current_date - 1
  );
  select public.obtener_preparacion_cierre_ciclo_v2(farm_id, cycle_id)
  into readiness;
  perform pg_temp.assert_true(
    readiness ->> 'can_settle' = 'true',
    'production closure must make a complete cycle eligible for settlement'
  );
  select public.finalizar_ciclo_v2(farm_id, cycle_id) into finalization;
  reset role;

  perform pg_temp.assert_true(
    finalization ->> 'status' = 'settled'
    and finalization ->> 'calculation_version' = 'v2'
    and (select status = 'settled' and settled_on is not null
         from economics_v2.cycles where id = cycle_id)
    and (select count(*) = 1 from economics_v2.final_results result where result.cycle_id = full_scope.cycle_id),
    'finalization must atomically settle once and freeze one versioned snapshot'
  );

  set local role authenticated;
  begin
    perform public.finalizar_ciclo_v2(farm_id, cycle_id);
    raise exception 'repeat finalization must be rejected';
  exception when unique_violation or check_violation then null;
  end;
  begin
    perform public.asignar_animal_ciclo_v2(
      farm_id, cycle_id, animal_two, current_date
    );
    raise exception 'post-settlement membership edits must be rejected';
  exception when insufficient_privilege or check_violation then null;
  end;
  begin
    perform public.registrar_gasto_ciclo_v2_con_categoria(
      farm_id, cycle_id, current_date, 1, 'Other', 'Late expense'
    );
    raise exception 'post-settlement expenses must be rejected';
  exception when insufficient_privilege or check_violation then null;
  end;
  begin
    perform public.reemplazar_alimento_ciclo_v2(
      farm_id, cycle_id, mixture_one, current_date, null
    );
    raise exception 'post-settlement feed edits must be rejected';
  exception when insufficient_privilege or check_violation then null;
  end;
  begin
    perform public.guardar_proyeccion_ciclo_v2(
      farm_id,
      cycle_id,
      jsonb_build_object(
        'expected_unit_price', 3,
        'production_per_day', 10,
        'feed_per_day', 2,
        'other_costs', 5,
        'horizon_days', 30
      ),
      'Late projection'
    );
    raise exception 'post-settlement projections must be rejected';
  exception when insufficient_privilege or check_violation then null;
  end;
  reset role;

  perform set_config('request.jwt.claim.sub', outsider_id::text, true);
  set local role authenticated;
  begin
    perform public.obtener_detalle_ciclo_v2(farm_id, cycle_id);
    raise exception 'cross-farm detail access must be rejected';
  exception when insufficient_privilege then null;
  end;
  reset role;

  perform set_config('request.jwt.claim.sub', viewer_id::text, true);
  set local role authenticated;
  select public.obtener_detalle_ciclo_v2(farm_id, cycle_id) into detail;
  perform pg_temp.assert_true(
    detail ->> 'cycle_id' = cycle_id::text,
    'viewer must retain farm-scoped read access'
  );
  begin
    perform public.registrar_gasto_ciclo_v2_con_categoria(
      farm_id, cycle_id, current_date, 1, 'Other', 'Viewer expense'
    );
    raise exception 'viewer mutation must be rejected';
  exception when insufficient_privilege then null;
  end;
  reset role;
end;
$full_scope$;

rollback;
