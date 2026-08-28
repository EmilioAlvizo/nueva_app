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
  to_regprocedure('public.crear_ciclo_v2(uuid,uuid,date)') is not null
  and to_regprocedure('public.asignar_animal_ciclo_v2(uuid,uuid,uuid,date)') is not null
  and to_regprocedure('public.registrar_gasto_ciclo_v2(uuid,uuid,date,numeric,text)') is not null
  and to_regprocedure('public.vincular_alimento_ciclo_v2(uuid,uuid,uuid,date,date)') is not null,
  'lifecycle public APIs must expose the exact create, assign, expense, and feed-link signatures'
);

select pg_temp.assert_true(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'crear_ciclo_v2',
        'asignar_animal_ciclo_v2',
        'registrar_gasto_ciclo_v2',
        'vincular_alimento_ciclo_v2'
      )
      and p.prosecdef
  ),
  'lifecycle public APIs must remain security invoker'
);

select pg_temp.assert_true(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'economics_v2'
     and (p.oid = 'economics_v2.create_cycle_impl(uuid,uuid,date)'::regprocedure
       or p.oid = 'economics_v2.assign_cycle_animal_impl(uuid,uuid,uuid,date)'::regprocedure
       or p.oid = 'economics_v2.record_cycle_expense_impl(uuid,uuid,date,numeric,text)'::regprocedure
       or p.oid = 'economics_v2.link_cycle_feed_impl(uuid,uuid,uuid,date,date)'::regprocedure)
     and p.prosecdef
     and p.proconfig @> array['search_path=""']
     and has_function_privilege('authenticated', p.oid, 'execute')
     and not has_function_privilege('anon', p.oid, 'execute')
     and not has_function_privilege('public', p.oid, 'execute')) = 4,
  'only authenticated may execute all four fixed-search-path private lifecycle implementations'
);

select pg_temp.assert_true(
  to_regprocedure('economics_v2.create_cycle_impl()') is null
  and to_regprocedure('economics_v2.assign_cycle_animal_impl()') is null
  and to_regprocedure('economics_v2.record_cycle_expense_impl()') is null
  and to_regprocedure('economics_v2.link_cycle_feed_impl()') is null,
  'obsolete no-argument lifecycle implementation stubs must not remain callable'
);

do $lifecycle$
<<lifecycle>>
declare
  editor_id uuid := '00000000-0000-0000-0000-000000007101';
  viewer_id uuid := '00000000-0000-0000-0000-000000007102';
  farm_a uuid := '00000000-0000-0000-0000-000000007201';
  farm_b uuid := '00000000-0000-0000-0000-000000007202';
  type_a uuid := '00000000-0000-0000-0000-000000007301';
  group_a uuid := '00000000-0000-0000-0000-000000007401';
  group_b uuid := '00000000-0000-0000-0000-000000007402';
  animal_a uuid := '00000000-0000-0000-0000-000000007501';
  animal_wrong_purpose uuid := '00000000-0000-0000-0000-000000007502';
  animal_foreign uuid := '00000000-0000-0000-0000-000000007503';
  mix_a uuid := '00000000-0000-0000-0000-000000007601';
  mix_foreign uuid := '00000000-0000-0000-0000-000000007602';
  postura_purpose uuid;
  carne_purpose uuid;
  cycle_id uuid;
  expense_id uuid;
  feed_id uuid;
begin
  insert into auth.users (id, aud, role, email, created_at, updated_at)
  values
    (editor_id, 'authenticated', 'authenticated', 'economics-v2-lifecycle-editor@example.test', now(), now()),
    (viewer_id, 'authenticated', 'authenticated', 'economics-v2-lifecycle-viewer@example.test', now(), now());
  insert into public.perfiles (id, nombre)
  values (editor_id, 'Lifecycle editor'), (viewer_id, 'Lifecycle viewer')
  on conflict (id) do update set nombre = excluded.nombre;
  insert into public.granjas (id, owner_id, nombre, created_by)
  values
    (farm_a, editor_id, 'Lifecycle farm A', editor_id),
    (farm_b, editor_id, 'Lifecycle farm B', editor_id);
  insert into public.miembros_granja (granja_id, user_id, rol)
  values (farm_a, viewer_id, 'viewer');
  insert into public.tipo_animal (id, granja_id, nombre, created_by)
  values (type_a, farm_a, 'Lifecycle bird', editor_id);
  insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
  values
    (group_a, farm_a, type_a, 'Lifecycle group A', editor_id),
    (group_b, farm_b, type_a, 'Lifecycle group B', editor_id);
  select id into postura_purpose from public.cat_proposito_animal where codigo_calculo = 'postura' limit 1;
  select id into carne_purpose from public.cat_proposito_animal where codigo_calculo = 'carne' limit 1;
  insert into public.animales (id, granja_id, tipo_animal_id, grupo_id, proposito_id, fecha_adquisicion, created_by)
  values
    (animal_a, farm_a, type_a, group_a, postura_purpose, current_date - 5, editor_id),
    (animal_wrong_purpose, farm_a, type_a, group_a, carne_purpose, current_date - 5, editor_id),
    (animal_foreign, farm_b, type_a, group_b, postura_purpose, current_date - 5, editor_id);
  insert into public.mezcla (id, granja_id, grupo_id, fecha_inicio, created_by)
  values
    (mix_a, farm_a, group_a, current_date - 2, editor_id),
    (mix_foreign, farm_b, group_b, current_date - 2, editor_id);
  insert into economics_v2.feature_flags (granja_id, economics_v2_enabled)
  values (farm_a, true), (farm_b, true);

  perform set_config('request.jwt.claim.sub', viewer_id::text, true);
  set local role authenticated;
  begin
    perform public.crear_ciclo_v2(farm_a, postura_purpose, current_date - 1);
    raise exception 'viewer lifecycle creation must be rejected';
  exception when insufficient_privilege then null;
  end;
  reset role;

  perform set_config('request.jwt.claim.sub', editor_id::text, true);
  set local role authenticated;
  select public.crear_ciclo_v2(farm_a, postura_purpose, current_date - 1) into cycle_id;
  begin
    perform public.asignar_animal_ciclo_v2(farm_a, cycle_id, animal_foreign, current_date);
    raise exception 'cross-farm animal assignment must be rejected';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.asignar_animal_ciclo_v2(farm_a, cycle_id, animal_wrong_purpose, current_date);
    raise exception 'wrong-purpose animal assignment must be rejected';
  exception when invalid_parameter_value then null;
  end;
  perform public.asignar_animal_ciclo_v2(farm_a, cycle_id, animal_a, current_date);
  select public.registrar_gasto_ciclo_v2(farm_a, cycle_id, current_date, 12.5, 'Lifecycle expense') into expense_id;
  select public.vincular_alimento_ciclo_v2(farm_a, cycle_id, mix_a, current_date, null) into feed_id;
  begin
    perform public.vincular_alimento_ciclo_v2(farm_a, cycle_id, mix_foreign, current_date, null);
    raise exception 'cross-farm feed links must be rejected';
  exception when insufficient_privilege then null;
  end;
  reset role;

  perform pg_temp.assert_true(
    cycle_id is not null
    and (select c.granja_id = farm_a and c.proposito_id = postura_purpose and c.status = 'open' from economics_v2.cycles c where c.id = lifecycle.cycle_id)
    and (select membership.joined_on = current_date and membership.left_on is null from economics_v2.cycle_animals membership where membership.cycle_id = lifecycle.cycle_id and membership.animal_id = animal_a)
    and (select expense.amount = 12.5 and expense.created_by = editor_id from economics_v2.cycle_expenses expense where expense.id = expense_id and expense.cycle_id = lifecycle.cycle_id)
    and (select feed.mezcla_id = mix_a and feed.starts_on = current_date and feed.ends_on is null from economics_v2.cycle_feeds feed where feed.id = feed_id and feed.cycle_id = lifecycle.cycle_id),
    'authorized lifecycle wrappers must create farm-scoped cycle, active membership, direct expense, and explicit feed link'
  );
end;
$lifecycle$;

rollback;
