begin;
create or replace function pg_temp.assert_true(condition boolean, message text)
returns void language plpgsql as $$
begin
  if condition is distinct from true then raise exception '%', message; end if;
end;
$$;
create or replace function pg_temp.expect_sqlstate(expected_state text, statement text, message text)
returns text language plpgsql as $$
declare actual_state text;
begin
  begin
    execute statement;
  exception when others then
    get stacked diagnostics actual_state = returned_sqlstate;
    perform pg_temp.assert_true(actual_state = expected_state, format('%s: expected %s, got %s', message, expected_state, actual_state));
    return actual_state;
  end;
  raise exception '%: expected SQLSTATE % but statement succeeded', message, expected_state;
end;
$$;
select pg_temp.assert_true(
  (select count(*) from pg_class r join pg_namespace n on n.oid = r.relnamespace
   where n.nspname = 'economics_v2' and r.relname in (
     'group_period_feed_allocations', 'group_period_expenses', 'group_period_sale_bindings',
     'group_animal_acquisition_basis', 'group_acquisition_basis_entries'
   )) = 5,
  'forward storage tables must exist'
);
select pg_temp.assert_true(
  (select count(*) from information_schema.columns
   where table_schema = 'economics_v2' and table_name = 'group_occupancy_events'
     and column_name in ('operation_id', 'sale_id', 'basis_transfer_id', 'reason')) = 4,
  'forward event metadata fields must exist'
);
select pg_temp.assert_true(
  exists (select 1 from pg_constraint where conname = 'group_occupancy_periods_membership_containment'
    and contype = 't' and condeferrable and condeferred),
  'period-side containment must be deferred'
);
select pg_temp.assert_true(
  (select count(*) from pg_class r join pg_namespace n on n.oid = r.relnamespace
   where n.nspname = 'economics_v2' and r.relname in (
     'group_period_feed_allocations', 'group_period_expenses', 'group_period_sale_bindings',
     'group_animal_acquisition_basis', 'group_acquisition_basis_entries'
   ) and r.relrowsecurity and r.relforcerowsecurity
     and not has_table_privilege('anon', r.oid, 'select,insert,update,delete')
     and not has_table_privilege('authenticated', r.oid, 'select,insert,update,delete')) = 5,
  'all forward storage tables must force RLS and deny direct client grants'
);
select pg_temp.assert_true(
  not has_function_privilege('authenticated', 'public.group_economics_parity(uuid,uuid)'::regprocedure, 'execute')
  and not has_function_privilege('authenticated', 'public.resolve_group_economics_quarantine(uuid,uuid,uuid,text,uuid,text)'::regprocedure, 'execute')
  and not has_function_privilege('authenticated', 'economics_v2.group_economics_parity_impl(uuid,uuid)'::regprocedure, 'execute')
  and not has_function_privilege('authenticated', 'economics_v2.resolve_group_economics_quarantine_impl(uuid,uuid,uuid,text,uuid,text)'::regprocedure, 'execute')
  and not has_function_privilege('authenticated', 'economics_v2.classify_legacy_cycle(uuid)'::regprocedure, 'execute'),
  'superseded parity and quarantine paths must remain client-inaccessible'
);
create temp table pg_temp.fixture_ids as
select gen_random_uuid() owner_a, gen_random_uuid() owner_b, gen_random_uuid() farm_a, gen_random_uuid() farm_b,
  gen_random_uuid() type_a, gen_random_uuid() type_b, gen_random_uuid() group_a, gen_random_uuid() group_b,
  gen_random_uuid() purpose_a, gen_random_uuid() animal_a, gen_random_uuid() animal_b,
  gen_random_uuid() mixture_a, gen_random_uuid() mixture_b, gen_random_uuid() sale_a, gen_random_uuid() sale_b,
  gen_random_uuid() period_a, gen_random_uuid() operation_a;

-- Auth triggers own profile and owner-membership rows; this fixture does not create either directly.
insert into auth.users (id, aud, role, created_at, updated_at)
select id, 'authenticated', 'authenticated', now(), now() from pg_temp.fixture_ids f
cross join lateral unnest(array[f.owner_a, f.owner_b]) as users(id);
insert into public.granjas (id, owner_id, nombre, created_by)
select farm_a, owner_a, 'F1A owned farm A', owner_a from pg_temp.fixture_ids
union all select farm_b, owner_b, 'F1A owned farm B', owner_b from pg_temp.fixture_ids;
insert into public.tipo_animal (id, granja_id, nombre, created_by)
select type_a, farm_a, 'F1A type A', owner_a from pg_temp.fixture_ids
union all select type_b, farm_b, 'F1A type B', owner_b from pg_temp.fixture_ids;
insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
select group_a, farm_a, type_a, 'F1A group A', owner_a from pg_temp.fixture_ids
union all select group_b, farm_b, type_b, 'F1A group B', owner_b from pg_temp.fixture_ids;
insert into public.cat_proposito_animal (id, granja_id, nombre, created_by, codigo_calculo)
select purpose_a, farm_a, 'F1A meat purpose', owner_a, 'carne' from pg_temp.fixture_ids;
insert into public.animales (id, granja_id, tipo_animal_id, grupo_id, proposito_id, costo_adquisicion, created_by)
select animal_a, farm_a, type_a, group_a, purpose_a, 0, owner_a from pg_temp.fixture_ids
union all select animal_b, farm_b, type_b, group_b, null, 12, owner_b from pg_temp.fixture_ids;
insert into public.mezcla (id, granja_id, grupo_id, fecha_inicio, created_by)
select mixture_a, farm_a, group_a, current_date, owner_a from pg_temp.fixture_ids
union all select mixture_b, farm_b, group_b, current_date, owner_b from pg_temp.fixture_ids;
insert into public.venta_animal (id, granja_id, grupo_id, tipo_animal_id, animal_id, fecha_venta, record_kind, quantity, total_amount)
select sale_a, farm_a, group_a, type_a, animal_a, current_date, 'individual', 1, 10 from pg_temp.fixture_ids
union all select sale_b, farm_b, group_b, type_b, animal_b, current_date, 'individual', 1, 20 from pg_temp.fixture_ids;
insert into economics_v2.group_occupancy_periods (id, granja_id, group_id, purpose_id, starts_on, closed_on, start_position, end_position)
select period_a, farm_a, group_a, purpose_a, current_date, current_date, 100, 130 from pg_temp.fixture_ids;
insert into economics_v2.group_occupancy_memberships (period_id, granja_id, animal_id, start_position, end_position)
select period_a, farm_a, animal_a, 110, 120 from pg_temp.fixture_ids;
insert into economics_v2.group_period_feed_allocations (granja_id, period_id, mixture_id, occurred_on, source_updated_at, component_count, quantity_kg, total_cost, source_digest)
select farm_a, period_a, mixture_a, current_date, now(), 1, 1, 0, 'f1a-feed' from pg_temp.fixture_ids;
insert into economics_v2.group_period_expenses (granja_id, period_id, occurred_on, amount, category, created_by)
select farm_a, period_a, current_date, 1, 'transport', owner_a from pg_temp.fixture_ids;
insert into economics_v2.group_period_sale_bindings (sale_id, granja_id, period_id, record_kind, quantity, saleable_kg, total_amount, source_digest)
select sale_a, farm_a, period_a, 'individual', 1, 1, 10, 'f1a-sale' from pg_temp.fixture_ids;
insert into economics_v2.group_animal_acquisition_basis (granja_id, animal_id, initial_basis, remaining_basis, status, current_account_kind, current_period_id, source_cost)
select farm_a, animal_a, 0, 0, 'active', 'period', period_a, 0 from pg_temp.fixture_ids;
insert into economics_v2.group_occupancy_operations (granja_id, operation_id, payload_hash, result)
select farm_a, operation_a, 'f1a-storage', '{}'::jsonb from pg_temp.fixture_ids;
insert into economics_v2.group_acquisition_basis_entries (granja_id, animal_id, operation_id, entry_kind, account_kind, period_id, signed_amount)
select farm_a, animal_a, operation_a, 'initial', 'period', period_a, 0 from pg_temp.fixture_ids;
select pg_temp.expect_sqlstate(
  '23503', format(
    'insert into economics_v2.group_period_feed_allocations (granja_id, period_id, mixture_id, occurred_on, source_updated_at, component_count, quantity_kg, total_cost, source_digest) values (%L::uuid, %L::uuid, %L::uuid, current_date, now(), 1, 1, 1, ''cross-farm-feed'')',
    farm_a, period_a, mixture_b
  ), 'cross-farm feed source must be denied by a foreign key'
) from pg_temp.fixture_ids;
select pg_temp.expect_sqlstate(
  '23503', format(
    'insert into economics_v2.group_period_sale_bindings (sale_id, granja_id, period_id, record_kind, quantity, saleable_kg, total_amount, source_digest) values (%L::uuid, %L::uuid, %L::uuid, ''individual'', 1, 1, 20, ''cross-farm-sale'')',
    sale_b, farm_a, period_a
  ), 'cross-farm sale source must be denied by a foreign key'
) from pg_temp.fixture_ids;
select pg_temp.expect_sqlstate(
  '23503', format(
    'insert into economics_v2.group_animal_acquisition_basis (granja_id, animal_id, initial_basis, remaining_basis, status, current_account_kind, source_cost) values (%L::uuid, %L::uuid, 1, 1, ''active'', ''holding'', 1)',
    farm_a, animal_b
  ), 'cross-farm animal basis must be denied by a foreign key'
) from pg_temp.fixture_ids;
set constraints all immediate;
set constraints all deferred;
do $containment$
begin
  begin
    update economics_v2.group_occupancy_periods set end_position = 115 where id = (select period_a from pg_temp.fixture_ids);
    set constraints all immediate;
    raise exception 'period shrink unexpectedly accepted an uncontained membership';
  exception when check_violation then null;
  end;
  update economics_v2.group_occupancy_memberships set end_position = 115 where period_id = (select period_a from pg_temp.fixture_ids);
  update economics_v2.group_occupancy_periods set end_position = 115 where id = (select period_a from pg_temp.fixture_ids);
  set constraints all immediate;
end;
$containment$;
set constraints all deferred;
update economics_v2.group_occupancy_periods set end_position = 112 where id = (select period_a from pg_temp.fixture_ids);
update economics_v2.group_occupancy_periods set end_position = 115 where id = (select period_a from pg_temp.fixture_ids);
set constraints all immediate;
set constraints all deferred;
update economics_v2.group_occupancy_memberships set end_position = 116 where period_id = (select period_a from pg_temp.fixture_ids);
update economics_v2.group_occupancy_memberships set end_position = 115 where period_id = (select period_a from pg_temp.fixture_ids);
set constraints all immediate;
do $surviving_membership$
begin
  begin
    update economics_v2.group_occupancy_memberships set end_position = 116 where period_id = (select period_a from pg_temp.fixture_ids);
    set constraints all immediate;
    raise exception 'surviving uncontained membership unexpectedly accepted';
  exception when check_violation then null;
  end;
end;
$surviving_membership$;
do $direct_denial$
begin
  set local role authenticated;
  begin
    perform 1 from economics_v2.group_period_feed_allocations;
    raise exception 'authenticated direct storage access unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  reset role;
end;
$direct_denial$;
select jsonb_build_object(
  'result', 'group_economics_forward_storage_pass',
  'owned_rows', jsonb_build_object(
    'feed', (select count(*) from economics_v2.group_period_feed_allocations),
    'expenses', (select count(*) from economics_v2.group_period_expenses),
    'sales', (select count(*) from economics_v2.group_period_sale_bindings),
    'basis', (select count(*) from economics_v2.group_animal_acquisition_basis),
    'entries', (select count(*) from economics_v2.group_acquisition_basis_entries)
  )
) as evidence;
rollback;
