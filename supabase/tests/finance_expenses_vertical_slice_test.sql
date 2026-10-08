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
  to_regclass('public.legacy_mixture_expenses') is not null
  and to_regprocedure('public.list_finance_expenses(uuid)') is not null
  and to_regprocedure(
    'public.create_finance_expense(uuid,text,uuid,date,numeric,text,text)'
  ) is not null
  and to_regprocedure(
    'public.update_finance_expense(uuid,uuid,text,uuid,timestamp with time zone,date,numeric,text,text)'
  ) is not null
  and to_regprocedure(
    'public.delete_finance_expense(uuid,uuid,text,uuid,timestamp with time zone)'
  ) is not null,
  'Finance expenses must expose the additive table and unified CRUD API'
);

select pg_temp.assert_true(
  (
    select count(*)
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'list_finance_expenses',
        'create_finance_expense',
        'update_finance_expense',
        'delete_finance_expense'
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
      )
  ) = 4,
  'Public expense APIs must be fixed-path invokers granted only to authenticated'
);

select pg_temp.assert_true(
  (
    select count(*)
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'economics_v2'
      and procedure.proname in (
        'assert_finance_expense_actor_impl',
        'validate_finance_expense_target_impl',
        'read_finance_expenses_impl',
        'create_finance_expense_impl',
        'update_finance_expense_impl',
        'delete_finance_expense_impl'
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
      )
  ) = 6,
  'Private expense implementations must be fixed-path definers granted only to authenticated'
);

select pg_temp.assert_true(
  has_table_privilege('authenticated', 'public.legacy_mixture_expenses', 'SELECT')
  and not has_table_privilege('authenticated', 'public.legacy_mixture_expenses', 'INSERT')
  and not has_table_privilege('authenticated', 'public.legacy_mixture_expenses', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.legacy_mixture_expenses', 'DELETE')
  and not has_table_privilege('anon', 'public.legacy_mixture_expenses', 'SELECT'),
  'Authenticated clients may read legacy rows through RLS but must mutate only through RPCs'
);

do $finance_expenses$
<<finance_expenses>>
declare
  owner_id uuid := '00000000-0000-0000-0000-000000009101';
  viewer_id uuid := '00000000-0000-0000-0000-000000009102';
  outsider_id uuid := '00000000-0000-0000-0000-000000009103';
  farm_id uuid := '00000000-0000-0000-0000-000000009201';
  foreign_farm_id uuid := '00000000-0000-0000-0000-000000009202';
  type_id uuid := '00000000-0000-0000-0000-000000009301';
  foreign_type_id uuid := '00000000-0000-0000-0000-000000009302';
  group_id uuid := '00000000-0000-0000-0000-000000009401';
  foreign_group_id uuid := '00000000-0000-0000-0000-000000009402';
  food_category_id uuid := '00000000-0000-0000-0000-000000009501';
  food_id uuid := '00000000-0000-0000-0000-000000009502';
  mixture_id uuid := '00000000-0000-0000-0000-000000009601';
  next_mixture_id uuid := '00000000-0000-0000-0000-000000009602';
  meat_cycle_id uuid := '00000000-0000-0000-0000-000000009701';
  settled_cycle_id uuid := '00000000-0000-0000-0000-000000009702';
  foreign_cycle_id uuid := '00000000-0000-0000-0000-000000009703';
  meat_purpose_id uuid;
  cycle_expense jsonb;
  legacy_expense jsonb;
  snapshot jsonb;
  summaries jsonb;
  summary jsonb;
  first_updated_at timestamptz;
  legacy_cycle_expense_id uuid;
begin
  insert into auth.users (id, aud, role, email, created_at, updated_at)
  values
    (owner_id, 'authenticated', 'authenticated', 'expense-owner@example.test', now(), now()),
    (viewer_id, 'authenticated', 'authenticated', 'expense-viewer@example.test', now(), now()),
    (outsider_id, 'authenticated', 'authenticated', 'expense-outsider@example.test', now(), now());

  insert into public.perfiles (id, nombre)
  values
    (owner_id, 'Expense owner'),
    (viewer_id, 'Expense viewer'),
    (outsider_id, 'Expense outsider')
  on conflict (id) do update set nombre = excluded.nombre;

  insert into public.granjas (id, owner_id, nombre, created_by)
  values
    (farm_id, owner_id, 'Expense farm', owner_id),
    (foreign_farm_id, outsider_id, 'Foreign expense farm', outsider_id);

  insert into public.miembros_granja (granja_id, user_id, rol, invited_by)
  values
    (farm_id, owner_id, 'owner', owner_id),
    (farm_id, viewer_id, 'viewer', owner_id),
    (foreign_farm_id, outsider_id, 'owner', outsider_id)
  on conflict (granja_id, user_id) do update set rol = excluded.rol;

  insert into economics_v2.feature_flags (granja_id, economics_v2_enabled)
  values (farm_id, true), (foreign_farm_id, true);

  select id into meat_purpose_id
  from public.cat_proposito_animal
  where codigo_calculo = 'carne'
  order by id
  limit 1;

  insert into public.tipo_animal (id, granja_id, nombre, created_by)
  values
    (type_id, farm_id, 'Expense bird', owner_id),
    (foreign_type_id, foreign_farm_id, 'Foreign bird', outsider_id);
  insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
  values
    (group_id, farm_id, type_id, 'Gallinero expense', owner_id),
    (foreign_group_id, foreign_farm_id, foreign_type_id, 'Foreign group', outsider_id);

  insert into public.cat_comida (id, granja_id, nombre, created_by)
  values (food_category_id, farm_id, 'Expense feed', owner_id);
  insert into public.comida (id, granja_id, cat_comida_id, precio, cantidad)
  values (food_id, farm_id, food_category_id, 100, 10);
  insert into public.mezcla (id, granja_id, grupo_id, fecha_inicio, created_by)
  values (mixture_id, farm_id, group_id, current_date - 10, owner_id);
  insert into public.mezcla_comida (granja_id, mezcla_id, comida_id, cantidad)
  values (farm_id, mixture_id, food_id, 10);
  insert into public.recoleccion_huevo (
    granja_id, grupo_id, fecha_recoleccion, buenos, rotos, created_by
  ) values (farm_id, group_id, current_date - 1, 10, 0, owner_id);

  insert into economics_v2.cycles (
    id, granja_id, proposito_id, name, starts_on, ends_on, status, created_by
  ) values
    (
      meat_cycle_id, farm_id, meat_purpose_id, 'Meat expense cycle',
      current_date - 10, current_date, 'open', owner_id
    ),
    (
      settled_cycle_id, farm_id, meat_purpose_id, 'Settled expense cycle',
      current_date - 20, current_date - 10, 'settled', owner_id
    ),
    (
      foreign_cycle_id, foreign_farm_id, meat_purpose_id, 'Foreign cycle',
      current_date - 10, current_date, 'open', outsider_id
    );

  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  set local role authenticated;

  select public.create_finance_expense(
    farm_id,
    'cycle',
    meat_cycle_id,
    current_date - 1,
    30,
    'Veterinary',
    'Cycle cost'
  ) into cycle_expense;
  select public.create_finance_expense(
    farm_id,
    'legacy_mixture',
    mixture_id,
    current_date - 1,
    20,
    'Maintenance',
    null
  ) into legacy_expense;
  select public.list_finance_expenses(farm_id) into snapshot;

  perform pg_temp.assert_true(
    snapshot ->> 'role' = 'owner'
    and (snapshot ->> 'can_edit')::boolean
    and jsonb_array_length(snapshot -> 'targets') = 2
    and jsonb_array_length(snapshot -> 'expenses') = 2
    and (
      select count(distinct value ->> 'expense_id') = 2
      from jsonb_array_elements(snapshot -> 'expenses') value
    ),
    'Farm list must return access, current targets, and each tagged expense exactly once'
  );

  select public.listar_resumen_ciclos_v2(farm_id) into summaries;
  select value into summary
  from jsonb_array_elements(summaries) value
  where value ->> 'cycle_id' = meat_cycle_id::text;
  perform pg_temp.assert_true(
    (summary ->> 'direct_expense_total')::numeric = 30,
    'V2 summary must count a unified cycle expense exactly once'
  );

  select public.registrar_gasto_ciclo_v2(
    farm_id,
    meat_cycle_id,
    current_date - 1,
    2,
    'Legacy cycle workspace contract'
  ) into legacy_cycle_expense_id;
  perform pg_temp.assert_true(
    (select category is null from economics_v2.cycle_expenses
     where id = legacy_cycle_expense_id),
    'Existing cycle expense API must preserve its optional category contract'
  );
  perform public.delete_finance_expense(
    farm_id,
    legacy_cycle_expense_id,
    'cycle',
    meat_cycle_id,
    (select updated_at from economics_v2.cycle_expenses
     where id = legacy_cycle_expense_id)
  );

  perform pg_temp.assert_true(
    (
      select total_costo_comidas = 100
        and total_gastos_directos = 20
        and costo_total = 120
        and punto_de_equilibrio = 12
      from public.puntos_equilibrio_huevos
      where mezcla_id = mixture_id
    ),
    'Legacy break-even must retain food cost and add mixture-scoped direct expenses once'
  );

  first_updated_at := (cycle_expense ->> 'updated_at')::timestamptz;
  perform public.update_finance_expense(
    farm_id,
    (cycle_expense ->> 'expense_id')::uuid,
    'cycle',
    meat_cycle_id,
    first_updated_at,
    current_date - 2,
    35,
    'Veterinary',
    'Updated'
  );

  begin
    perform public.update_finance_expense(
      farm_id,
      (cycle_expense ->> 'expense_id')::uuid,
      'cycle',
      meat_cycle_id,
      first_updated_at,
      current_date - 2,
      36,
      'Veterinary',
      null
    );
    raise exception 'Expected a stale write rejection';
  exception when serialization_failure then
    null;
  end;

  begin
    perform public.update_finance_expense(
      farm_id,
      (cycle_expense ->> 'expense_id')::uuid,
      'cycle',
      settled_cycle_id,
      (select updated_at from economics_v2.cycle_expenses
       where id = (cycle_expense ->> 'expense_id')::uuid),
      current_date - 2,
      36,
      'Veterinary',
      null
    );
    raise exception 'Expected immutable target rejection';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform public.create_finance_expense(
      farm_id, 'cycle', meat_cycle_id, current_date + 1, 1, 'Future', null
    );
    raise exception 'Expected future date rejection';
  exception when invalid_parameter_value then
    null;
  end;

  begin
    perform public.create_finance_expense(
      farm_id, 'cycle', meat_cycle_id, current_date - 1,
      'NaN'::numeric, 'Non-finite', null
    );
    raise exception 'Expected non-finite amount rejection';
  exception when invalid_parameter_value then
    null;
  end;

  begin
    perform public.create_finance_expense(
      farm_id,
      'cycle',
      meat_cycle_id,
      current_date,
      1,
      'Exclusive end',
      null
    );
    raise exception 'Expected exclusive cycle end rejection';
  exception when invalid_parameter_value then
    null;
  end;

  begin
    perform public.create_finance_expense(
      farm_id, 'cycle', foreign_cycle_id, current_date, 1, 'Foreign', null
    );
    raise exception 'Expected cross-farm target rejection';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform public.create_finance_expense(
      farm_id,
      'legacy_mixture',
      mixture_id,
      current_date - 11,
      1,
      'Before mixture',
      null
    );
    raise exception 'Expected legacy start boundary rejection';
  exception when invalid_parameter_value then
    null;
  end;

  reset role;
  insert into economics_v2.cycle_expenses (
    id, cycle_id, granja_id, occurred_on, amount, category, note, created_by
  ) values (
    '00000000-0000-0000-0000-000000009801',
    settled_cycle_id,
    farm_id,
    current_date - 11,
    5,
    'Settled',
    null,
    owner_id
  );
  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  set local role authenticated;
  begin
    perform public.delete_finance_expense(
      farm_id,
      '00000000-0000-0000-0000-000000009801',
      'cycle',
      settled_cycle_id,
      (select updated_at from economics_v2.cycle_expenses
       where id = '00000000-0000-0000-0000-000000009801')
    );
    raise exception 'Expected settled cycle immutability';
  exception when check_violation then
    null;
  end;

  perform public.delete_finance_expense(
    farm_id,
    (legacy_expense ->> 'expense_id')::uuid,
    'legacy_mixture',
    mixture_id,
    (legacy_expense ->> 'updated_at')::timestamptz
  );
  perform pg_temp.assert_true(
    (
      select total_costo_comidas = 100
        and total_gastos_directos = 0
        and costo_total = 100
        and punto_de_equilibrio = 10
      from public.puntos_equilibrio_huevos
      where mezcla_id = mixture_id
    ),
    'Deleting a legacy expense must refresh break-even source data immediately'
  );

  select public.create_finance_expense(
    farm_id,
    'legacy_mixture',
    mixture_id,
    current_date - 1,
    10,
    'Old mixture',
    null
  ) into legacy_expense;

  reset role;
  insert into public.mezcla (id, granja_id, grupo_id, fecha_inicio, created_by)
  values (next_mixture_id, farm_id, group_id, current_date, owner_id);
  perform set_config('request.jwt.claim.sub', owner_id::text, true);
  set local role authenticated;
  begin
    perform public.update_finance_expense(
      farm_id,
      (legacy_expense ->> 'expense_id')::uuid,
      'legacy_mixture',
      mixture_id,
      (legacy_expense ->> 'updated_at')::timestamptz,
      current_date - 1,
      11,
      'Old mixture',
      null
    );
    raise exception 'Expected closed legacy target immutability';
  exception when check_violation then
    null;
  end;
  select public.list_finance_expenses(farm_id) into snapshot;
  perform pg_temp.assert_true(
    not exists (
      select 1
      from jsonb_array_elements(snapshot -> 'expenses') value
      where value ->> 'target_id' = mixture_id::text
    )
    and exists (
      select 1
      from jsonb_array_elements(snapshot -> 'targets') value
      where value ->> 'target_id' = next_mixture_id::text
    ),
    'Dashboard totals and rows must include current break-even targets only'
  );

  reset role;
  perform set_config('request.jwt.claim.sub', viewer_id::text, true);
  set local role authenticated;
  select public.list_finance_expenses(farm_id) into snapshot;
  perform pg_temp.assert_true(
    not (snapshot ->> 'can_edit')::boolean
    and not exists (
      select 1
      from jsonb_array_elements(snapshot -> 'expenses') value
      where (value ->> 'can_mutate')::boolean
    ),
    'Viewer must read the farm snapshot without mutation affordances'
  );
  begin
    perform public.create_finance_expense(
      farm_id,
      'legacy_mixture',
      next_mixture_id,
      current_date,
      1,
      'Viewer',
      null
    );
    raise exception 'Expected viewer mutation rejection';
  exception when insufficient_privilege then
    null;
  end;

  reset role;
  perform set_config('request.jwt.claim.sub', outsider_id::text, true);
  set local role authenticated;
  begin
    perform public.list_finance_expenses(farm_id);
    raise exception 'Expected outsider read rejection';
  exception when insufficient_privilege then
    null;
  end;

  reset role;
end;
$finance_expenses$;

rollback;
