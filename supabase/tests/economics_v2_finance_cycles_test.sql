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
  to_regprocedure('public.obtener_acceso_ciclos_v2(uuid)') is not null
  and to_regprocedure('public.listar_resumen_ciclos_v2(uuid)') is not null
  and to_regprocedure('public.crear_ciclo_v2_con_fechas(uuid,uuid,date,date)') is not null
  and to_regprocedure('public.crear_ciclo_v2(uuid,uuid,date)') is not null,
  'Finance cycles must expose distinct access, summary, and date-aware create RPCs without removing legacy create'
);

select pg_temp.assert_true(
  (select count(*)
   from pg_proc procedure
   join pg_namespace namespace on namespace.oid = procedure.pronamespace
   where namespace.nspname = 'public'
     and procedure.proname in (
       'obtener_acceso_ciclos_v2',
       'listar_resumen_ciclos_v2',
       'crear_ciclo_v2_con_fechas'
     )
     and not procedure.prosecdef
     and procedure.proconfig @> array['search_path=""']
     and has_function_privilege('authenticated', procedure.oid, 'execute')
     and not has_function_privilege('anon', procedure.oid, 'execute')
     and not has_function_privilege('public', procedure.oid, 'execute')) = 3,
  'Finance cycles public wrappers must be fixed-search-path invokers executable only by authenticated'
);

select pg_temp.assert_true(
  (select count(*)
   from pg_proc procedure
   join pg_namespace namespace on namespace.oid = procedure.pronamespace
   where namespace.nspname = 'economics_v2'
     and procedure.proname in (
       'read_farm_access_impl',
       'read_cycle_summaries_impl',
       'create_cycle_with_dates_impl'
     )
     and procedure.prosecdef
     and procedure.proconfig @> array['search_path=""']
     and has_function_privilege('authenticated', procedure.oid, 'execute')
     and not has_function_privilege('anon', procedure.oid, 'execute')
     and not has_function_privilege('public', procedure.oid, 'execute')) = 3,
  'Finance cycles private implementations must be hardened definers executable only by authenticated'
);

do $finance_cycles$
<<finance_cycles>>
declare
  editor_id uuid := '00000000-0000-0000-0000-000000009101';
  outsider_id uuid := '00000000-0000-0000-0000-000000009102';
  viewer_id uuid := '00000000-0000-0000-0000-000000009103';
  farm_a uuid := '00000000-0000-0000-0000-000000009201';
  farm_b uuid := '00000000-0000-0000-0000-000000009202';
  type_a uuid := '00000000-0000-0000-0000-000000009301';
  group_old uuid := '00000000-0000-0000-0000-000000009401';
  group_latest uuid := '00000000-0000-0000-0000-000000009402';
  animal_active uuid := '00000000-0000-0000-0000-000000009501';
  animal_exited uuid := '00000000-0000-0000-0000-000000009502';
  mix_old uuid := '00000000-0000-0000-0000-000000009601';
  mix_latest uuid := '00000000-0000-0000-0000-000000009602';
  purpose_id uuid;
  cycle_id uuid;
  planned_cycle_id uuid;
  access_result jsonb;
  summary_result jsonb;
begin
  insert into auth.users (id, aud, role, email, created_at, updated_at)
  values
    (editor_id, 'authenticated', 'authenticated', 'finance-cycles-editor@example.test', now(), now()),
    (outsider_id, 'authenticated', 'authenticated', 'finance-cycles-outsider@example.test', now(), now()),
    (viewer_id, 'authenticated', 'authenticated', 'finance-cycles-viewer@example.test', now(), now());
  insert into public.perfiles (id, nombre)
  values
    (editor_id, 'Finance cycles editor'),
    (outsider_id, 'Finance cycles outsider'),
    (viewer_id, 'Finance cycles viewer')
  on conflict (id) do update set nombre = excluded.nombre;
  insert into public.granjas (id, owner_id, nombre, created_by)
  values
    (farm_a, editor_id, 'Finance cycles A', editor_id),
    (farm_b, editor_id, 'Finance cycles B', editor_id);
  insert into public.miembros_granja (granja_id, user_id, rol, invited_by)
  values (farm_a, viewer_id, 'viewer', editor_id);
  insert into public.tipo_animal (id, granja_id, nombre, created_by)
  values (type_a, farm_a, 'Finance cycles bird', editor_id);
  insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
  values
    (group_old, farm_a, type_a, 'Gallinero sur', editor_id),
    (group_latest, farm_a, type_a, 'Gallinero norte', editor_id);
  select id into purpose_id
  from public.cat_proposito_animal
  where codigo_calculo = 'postura'
  order by id
  limit 1;
  insert into public.animales (
    id, granja_id, tipo_animal_id, grupo_id, proposito_id, fecha_adquisicion, created_by
  ) values
    (animal_active, farm_a, type_a, group_latest, purpose_id, date '2026-08-01', editor_id),
    (animal_exited, farm_a, type_a, group_old, purpose_id, date '2026-08-01', editor_id);
  insert into public.mezcla (id, granja_id, grupo_id, fecha_inicio, created_by)
  values
    (mix_old, farm_a, group_old, date '2026-08-02', editor_id),
    (mix_latest, farm_a, group_latest, date '2026-08-10', editor_id);
  insert into economics_v2.feature_flags (granja_id, economics_v2_enabled)
  values (farm_a, true), (farm_b, false);

  perform set_config('request.jwt.claim.sub', outsider_id::text, true);
  set local role authenticated;
  begin
    perform public.obtener_acceso_ciclos_v2(farm_a);
    raise exception 'cross-farm access reads must be rejected';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.listar_resumen_ciclos_v2(farm_a);
    raise exception 'cross-farm summary reads must be rejected';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.crear_ciclo_v2_con_fechas(
      farm_a, purpose_id, date '2026-08-01', null
    );
    raise exception 'cross-farm cycle creation must be rejected';
  exception when insufficient_privilege then null;
  end;
  reset role;

  perform set_config('request.jwt.claim.sub', viewer_id::text, true);
  set local role authenticated;
  select public.obtener_acceso_ciclos_v2(farm_a) into access_result;
  perform pg_temp.assert_true(
    access_result ->> 'enabled' = 'true'
    and access_result ->> 'role' = 'viewer'
    and access_result ->> 'can_edit' = 'false',
    'viewer access reads must report the role without granting Economics V2 data access'
  );
  begin
    perform public.listar_resumen_ciclos_v2(farm_a);
    raise exception 'viewer summary reads must be rejected';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.crear_ciclo_v2_con_fechas(
      farm_a, purpose_id, date '2026-08-01', null
    );
    raise exception 'viewer cycle creation must be rejected';
  exception when insufficient_privilege then null;
  end;
  reset role;

  perform set_config('request.jwt.claim.sub', editor_id::text, true);
  set local role authenticated;
  select public.obtener_acceso_ciclos_v2(farm_b) into access_result;
  perform pg_temp.assert_true(
    access_result ->> 'enabled' = 'false',
    'authorized access reads must distinguish a disabled farm without exposing cycle data'
  );
  begin
    perform public.listar_resumen_ciclos_v2(farm_b);
    raise exception 'disabled-farm summary reads must be rejected';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.crear_ciclo_v2_con_fechas(
      farm_b, purpose_id, date '2026-08-01', null
    );
    raise exception 'disabled-farm cycle creation must be rejected';
  exception when insufficient_privilege then null;
  end;

  select public.crear_ciclo_v2_con_fechas(
    farm_a, purpose_id, date '2026-08-01', null
  ) into cycle_id;
  select public.crear_ciclo_v2_con_fechas(
    farm_a, purpose_id, date '2026-09-01', date '2026-09-30'
  ) into planned_cycle_id;
  begin
    perform public.crear_ciclo_v2_con_fechas(
      farm_a, purpose_id, date '2026-10-02', date '2026-10-01'
    );
    raise exception 'an end date before the start date must be rejected';
  exception when invalid_parameter_value then null;
  end;
  reset role;

  insert into economics_v2.cycle_animals (cycle_id, animal_id, joined_on, left_on)
  values
    (cycle_id, animal_active, date '2026-08-01', null),
    (cycle_id, animal_exited, date '2026-08-01', date '2026-08-15');
  insert into economics_v2.cycle_expenses (
    cycle_id, granja_id, occurred_on, amount, created_by
  ) values
    (cycle_id, farm_a, date '2026-08-05', 12.5, editor_id),
    (cycle_id, farm_a, date '2026-08-06', 7.5, editor_id);
  insert into economics_v2.cycle_feeds (
    cycle_id, granja_id, mezcla_id, starts_on, created_by
  ) values
    (cycle_id, farm_a, mix_old, date '2026-08-02', editor_id),
    (cycle_id, farm_a, mix_latest, date '2026-08-10', editor_id);

  perform set_config('request.jwt.claim.sub', editor_id::text, true);
  set local role authenticated;
  select public.listar_resumen_ciclos_v2(farm_a) into summary_result;
  reset role;

  perform pg_temp.assert_true(
    (select cycle.status = 'open'
       and cycle.ends_on is null
     from economics_v2.cycles cycle
     where cycle.id = finance_cycles.cycle_id)
    and (select cycle.status = 'open'
       and cycle.ends_on = date '2026-09-30'
     from economics_v2.cycles cycle
     where cycle.id = planned_cycle_id),
    'date-aware create must preserve explicit open status and optional end date'
  );
  perform pg_temp.assert_true(
    jsonb_array_length(summary_result) = 2
    and summary_result -> 0 ->> 'cycle_id' = planned_cycle_id::text
    and summary_result -> 1 ->> 'cycle_id' = cycle_id::text
    and (summary_result -> 1 ->> 'active_animal_count')::integer = 1
    and (summary_result -> 1 ->> 'exited_animal_count')::integer = 1
    and (summary_result -> 1 ->> 'direct_expense_total')::numeric = 20
    and (summary_result -> 1 ->> 'linked_mixture_count')::integer = 2
    and summary_result -> 1 ->> 'latest_linked_group_name' = 'Gallinero norte',
    'summary must be deterministic and report honest animal, expense, purpose, date, status, mixture, and linked-group data'
  );
end;
$finance_cycles$;

rollback;
