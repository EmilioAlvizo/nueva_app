begin;

create temp table pg_temp.fixture_ids as
select gen_random_uuid() owner_a, gen_random_uuid() owner_b, gen_random_uuid() farm_a, gen_random_uuid() farm_b,
  gen_random_uuid() type_a, gen_random_uuid() type_b, gen_random_uuid() purpose_a, gen_random_uuid() purpose_b,
  gen_random_uuid() group_main, gen_random_uuid() group_transfer, gen_random_uuid() group_zero, gen_random_uuid() group_b,
  gen_random_uuid() group_rejoin, gen_random_uuid() group_zero_revenue, gen_random_uuid() group_quantity,
  gen_random_uuid() animal_a, gen_random_uuid() animal_b, gen_random_uuid() animal_transfer,
  gen_random_uuid() animal_rejoin, gen_random_uuid() animal_zero_revenue, gen_random_uuid() animal_quantity,
  gen_random_uuid() period_main, gen_random_uuid() period_source, gen_random_uuid() period_destination,
  gen_random_uuid() period_zero, gen_random_uuid() period_b, gen_random_uuid() period_rejoin,
  gen_random_uuid() period_zero_revenue, gen_random_uuid() period_quantity,
  gen_random_uuid() mixture_a, gen_random_uuid() mixture_b, gen_random_uuid() sale_a, gen_random_uuid() sale_b,
  gen_random_uuid() sale_zero_revenue, gen_random_uuid() sale_quantity,
  gen_random_uuid() operation_a, gen_random_uuid() operation_b;

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void language plpgsql as $$
begin
  if p_condition is distinct from true then
    raise exception '%', p_message;
  end if;
end;
$$;

create or replace function pg_temp.expect_error(
  p_statement text, p_state text, p_code text, p_field text
) returns void language plpgsql as $$
declare v_state text; v_detail text;
begin
  begin
    execute p_statement;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_detail = pg_exception_detail;
    perform pg_temp.assert_true(v_state = p_state, format('expected %s, got %s', p_state, v_state));
    perform pg_temp.assert_true((v_detail::jsonb)->>'contract_version' = 'group-economics.forward.v3', 'contract version detail');
    perform pg_temp.assert_true((v_detail::jsonb)->>'code' = p_code, 'typed error code');
    perform pg_temp.assert_true((v_detail::jsonb)->>'field' = p_field, 'typed error field');
    return;
  end;
  raise exception 'expected SQLSTATE % but statement succeeded', p_state;
end;
$$;

select pg_temp.assert_true(
  (select count(*) from auth.users where raw_user_meta_data->>'fixture' = 'f1bm-forward-live-metrics') = 0
  and (select count(*) from public.granjas where nombre in ('F1BM metrics farm A', 'F1BM metrics farm B')) = 0,
  'synthetic marker baseline must be empty'
);

-- Auth triggers create profiles and owner memberships; the fixture only creates owned farms.
insert into auth.users (id, aud, role, raw_user_meta_data, created_at, updated_at)
select id, 'authenticated', 'authenticated', jsonb_build_object('fixture', 'f1bm-forward-live-metrics'), now(), now()
from pg_temp.fixture_ids f cross join lateral unnest(array[f.owner_a, f.owner_b]) as u(id);
insert into public.granjas (id, owner_id, nombre, created_by)
select farm_a, owner_a, 'F1BM metrics farm A', owner_a from pg_temp.fixture_ids
union all select farm_b, owner_b, 'F1BM metrics farm B', owner_b from pg_temp.fixture_ids;
insert into public.tipo_animal (id, granja_id, nombre, created_by)
select type_a, farm_a, 'F1BM type A', owner_a from pg_temp.fixture_ids
union all select type_b, farm_b, 'F1BM type B', owner_b from pg_temp.fixture_ids;
insert into public.cat_proposito_animal (id, granja_id, nombre, codigo_calculo, created_by)
select purpose_a, farm_a, 'F1BM meat A', 'carne', owner_a from pg_temp.fixture_ids
union all select purpose_b, farm_b, 'F1BM meat B', 'carne', owner_b from pg_temp.fixture_ids;
insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
select group_main, farm_a, type_a, 'F1BM main', owner_a from pg_temp.fixture_ids union all
select group_transfer, farm_a, type_a, 'F1BM transfer', owner_a from pg_temp.fixture_ids union all
select group_zero, farm_a, type_a, 'F1BM empty', owner_a from pg_temp.fixture_ids union all
select group_b, farm_b, type_b, 'F1BM foreign', owner_b from pg_temp.fixture_ids union all
select group_rejoin, farm_a, type_a, 'F1BM rejoin', owner_a from pg_temp.fixture_ids union all
select group_zero_revenue, farm_a, type_a, 'F1BM zero revenue', owner_a from pg_temp.fixture_ids union all
select group_quantity, farm_a, type_a, 'F1BM quantity probe', owner_a from pg_temp.fixture_ids;
insert into public.animales (id, granja_id, tipo_animal_id, grupo_id, proposito_id, costo_adquisicion, notas, created_by)
select animal_a, farm_a, type_a, group_main, purpose_a, 999, 'F1BM owned animal A', owner_a from pg_temp.fixture_ids union all
select animal_b, farm_a, type_a, group_main, purpose_a, 999, 'F1BM owned animal B', owner_a from pg_temp.fixture_ids union all
select animal_transfer, farm_a, type_a, group_transfer, purpose_a, 999, 'F1BM transfer animal', owner_a from pg_temp.fixture_ids union all
select animal_rejoin, farm_a, type_a, group_rejoin, purpose_a, 0, 'F1BM rejoin animal', owner_a from pg_temp.fixture_ids union all
select animal_zero_revenue, farm_a, type_a, group_zero_revenue, purpose_a, 0, 'F1BM zero revenue animal', owner_a from pg_temp.fixture_ids union all
select animal_quantity, farm_a, type_a, group_quantity, purpose_a, 0, 'F1BM quantity probe animal', owner_a from pg_temp.fixture_ids;
insert into economics_v2.group_occupancy_periods (id, granja_id, group_id, purpose_id, starts_on, start_position, end_position)
select period_main, farm_a, group_main, purpose_a, current_date, 10, 30 from pg_temp.fixture_ids union all
select period_source, farm_a, group_transfer, purpose_a, current_date, 40, 50 from pg_temp.fixture_ids union all
select period_destination, farm_a, group_transfer, purpose_a, current_date, 50, null from pg_temp.fixture_ids union all
select period_zero, farm_a, group_zero, purpose_a, current_date, 80, 90 from pg_temp.fixture_ids union all
select period_b, farm_b, group_b, purpose_b, current_date, 10, 20 from pg_temp.fixture_ids union all
select period_rejoin, farm_a, group_rejoin, purpose_a, current_date, 100, null from pg_temp.fixture_ids union all
select period_zero_revenue, farm_a, group_zero_revenue, purpose_a, current_date, 200, 210 from pg_temp.fixture_ids union all
select period_quantity, farm_a, group_quantity, purpose_a, current_date, 300, 310 from pg_temp.fixture_ids;
insert into economics_v2.group_occupancy_memberships (granja_id, period_id, animal_id, start_position, end_position)
select farm_a, period_main, animal_a, 11, 20 from pg_temp.fixture_ids union all
select farm_a, period_main, animal_b, 12, 20 from pg_temp.fixture_ids union all
select farm_a, period_source, animal_transfer, 41, 45 from pg_temp.fixture_ids union all
select farm_a, period_destination, animal_transfer, 51, null from pg_temp.fixture_ids union all
select farm_a, period_rejoin, animal_rejoin, 101, 105 from pg_temp.fixture_ids union all
select farm_a, period_rejoin, animal_rejoin, 105, null from pg_temp.fixture_ids union all
select farm_a, period_zero_revenue, animal_zero_revenue, 201, 205 from pg_temp.fixture_ids union all
select farm_a, period_quantity, animal_quantity, 301, 305 from pg_temp.fixture_ids;
insert into public.mezcla (id, granja_id, grupo_id, fecha_inicio, created_by)
select mixture_a, farm_a, group_main, current_date, owner_a from pg_temp.fixture_ids union all
select mixture_b, farm_a, group_main, current_date, owner_a from pg_temp.fixture_ids;
insert into economics_v2.group_period_feed_allocations (granja_id, period_id, mixture_id, occurred_on, source_updated_at, component_count, quantity_kg, total_cost, source_digest)
select farm_a, period_main, mixture_a, current_date, now(), 1, 40, 40, 'f1bm-feed-a' from pg_temp.fixture_ids union all
select farm_a, period_main, mixture_b, current_date, now(), 1, 60, 60, 'f1bm-feed-b' from pg_temp.fixture_ids;
insert into economics_v2.group_period_expenses (granja_id, period_id, occurred_on, amount, category, created_by)
select farm_a, period_main, current_date, 20, 'transport', owner_a from pg_temp.fixture_ids union all
select farm_a, period_main, current_date, 30, 'care', owner_a from pg_temp.fixture_ids;
insert into public.venta_animal (id, granja_id, grupo_id, tipo_animal_id, animal_id, fecha_venta, record_kind, quantity, peso, total_amount)
select sale_a, farm_a, group_main, type_a, animal_a, current_date, 'individual', 1, 75, 450 from pg_temp.fixture_ids union all
select sale_b, farm_a, group_main, type_a, animal_b, current_date, 'individual', 1, 75, 450 from pg_temp.fixture_ids union all
select sale_zero_revenue, farm_a, group_zero_revenue, type_a, animal_zero_revenue, current_date, 'individual', 1, 75, 0 from pg_temp.fixture_ids union all
select sale_quantity, farm_a, group_quantity, type_a, animal_quantity, current_date, 'individual', 2, 100, 200 from pg_temp.fixture_ids;
insert into economics_v2.group_period_sale_bindings (sale_id, granja_id, period_id, record_kind, quantity, saleable_kg, total_amount, source_digest)
select sale_a, farm_a, period_main, 'individual', 1, 75, 450, 'f1bm-sale-a' from pg_temp.fixture_ids union all
select sale_b, farm_a, period_main, 'individual', 1, 75, 450, 'f1bm-sale-b' from pg_temp.fixture_ids union all
select sale_zero_revenue, farm_a, period_zero_revenue, 'individual', 1, 75, 0, 'f1bm-sale-zero-revenue' from pg_temp.fixture_ids union all
-- Mathematical private-binding probe only: it is not a canonical Group sale-writer proof.
select sale_quantity, farm_a, period_quantity, 'individual', 2, 100, 200, 'f1bm-sale-quantity' from pg_temp.fixture_ids;
insert into economics_v2.group_animal_acquisition_basis (granja_id, animal_id, initial_basis, remaining_basis, status, current_account_kind, current_period_id, source_cost)
select farm_a, animal_a, 150, 0, 'disposed', 'disposed', null::uuid, 150 from pg_temp.fixture_ids union all
select farm_a, animal_b, 150, 0, 'disposed', 'disposed', null::uuid, 150 from pg_temp.fixture_ids union all
select farm_a, animal_transfer, 300, 300, 'active', 'period', period_destination, 300 from pg_temp.fixture_ids;
insert into economics_v2.group_occupancy_operations (granja_id, operation_id, payload_hash, result)
select farm_a, operation_a, 'f1bm-a', '{}'::jsonb from pg_temp.fixture_ids union all
select farm_a, operation_b, 'f1bm-b', '{}'::jsonb from pg_temp.fixture_ids;
insert into economics_v2.group_acquisition_basis_entries (granja_id, animal_id, operation_id, entry_kind, account_kind, period_id, signed_amount)
select farm_a, animal_a, operation_a, 'initial', 'period', period_main, 150 from pg_temp.fixture_ids union all
select farm_a, animal_b, operation_a, 'initial', 'period', period_main, 150 from pg_temp.fixture_ids union all
select farm_a, animal_transfer, operation_b, 'initial', 'period', period_source, 300 from pg_temp.fixture_ids union all
select farm_a, animal_transfer, operation_b, 'transfer_out', 'period', period_source, -300 from pg_temp.fixture_ids union all
select farm_a, animal_transfer, operation_b, 'transfer_in', 'period', period_destination, 300 from pg_temp.fixture_ids union all
select farm_a, animal_transfer, operation_b, 'purpose_out', 'holding', null::uuid, -300 from pg_temp.fixture_ids;
set constraints all immediate;

create temp table pg_temp.results as
select economics_v2.calculate_group_period_live_metrics(farm_a, period_main) as main_metrics,
  economics_v2.calculate_group_period_live_metrics(farm_a, period_source) as source_metrics,
  economics_v2.calculate_group_period_live_metrics(farm_a, period_destination) as destination_metrics,
  economics_v2.calculate_group_period_live_metrics(farm_a, period_zero) as zero_metrics,
  economics_v2.calculate_group_period_live_metrics(farm_a, period_zero_revenue) as zero_revenue_metrics,
  economics_v2.calculate_group_period_live_metrics(farm_a, period_rejoin) as rejoin_metrics,
  economics_v2.calculate_group_period_live_metrics(farm_a, period_quantity) as quantity_metrics
from pg_temp.fixture_ids;

select pg_temp.assert_true(
  (select array_agg(metric_key order by metric_key) from jsonb_object_keys(main_metrics) as keys(metric_key)) = array[
    'acquisition_cost','active_animal_count','animal_count','animal_sale_revenue','balance_per_animal','break_even_kg',
    'direct_expense_total','exited_animal_count','feed_cost','feed_kg_total','feed_source_count','profit',
    'realized_price_per_kg','sale_count','saleable_kg','sold_animal_count','total_cost'
  ], 'metric key set must exactly match the forward contract'
) from pg_temp.results;
select pg_temp.assert_true(
  main_metrics @> '{"animal_count":2,"active_animal_count":0,"exited_animal_count":2,"sold_animal_count":2,"feed_source_count":2,"feed_kg_total":100,"feed_cost":100,"acquisition_cost":300,"direct_expense_total":50,"sale_count":2,"saleable_kg":150,"animal_sale_revenue":900,"total_cost":450,"profit":450,"realized_price_per_kg":6,"break_even_kg":75,"balance_per_animal":225}'::jsonb,
  'independent facts must yield exact 450/450/6/75 economics'
) from pg_temp.results;
select pg_temp.assert_true(
  source_metrics @> '{"animal_count":1,"active_animal_count":0,"exited_animal_count":1,"acquisition_cost":0,"total_cost":0,"profit":0,"balance_per_animal":0}'::jsonb
  and destination_metrics @> '{"animal_count":1,"active_animal_count":1,"exited_animal_count":0,"acquisition_cost":300,"total_cost":300,"profit":-300,"balance_per_animal":-300}'::jsonb
  and source_metrics->'realized_price_per_kg' = 'null'::jsonb and destination_metrics->'break_even_kg' = 'null'::jsonb,
  'signed source and destination period basis must remain exact without holding double count'
) from pg_temp.results;
select pg_temp.assert_true(
  zero_metrics @> '{"animal_count":0,"feed_source_count":0,"sale_count":0,"total_cost":0,"profit":0}'::jsonb
  and zero_metrics->'realized_price_per_kg' = 'null'::jsonb and zero_metrics->'break_even_kg' = 'null'::jsonb
  and zero_metrics->'balance_per_animal' = 'null'::jsonb,
  'a known empty period must return legitimate zero metrics with null ratios'
) from pg_temp.results;
select pg_temp.assert_true(
  zero_revenue_metrics @> '{"animal_count":1,"sale_count":1,"sold_animal_count":1,"saleable_kg":75,"animal_sale_revenue":0,"realized_price_per_kg":0,"total_cost":0,"profit":0}'::jsonb
  and zero_revenue_metrics->'break_even_kg' = 'null'::jsonb,
  'positive kilograms with recorded zero revenue must have price zero and null break-even'
) from pg_temp.results;
select pg_temp.assert_true(
  rejoin_metrics @> '{"animal_count":1,"active_animal_count":1,"exited_animal_count":0}'::jsonb,
  'finite then open rejoin memberships must deduplicate and prefer active'
) from pg_temp.results;
select pg_temp.assert_true(
  quantity_metrics @> '{"sale_count":1,"sold_animal_count":2,"saleable_kg":100,"animal_sale_revenue":200}'::jsonb,
  'one permitted sale record must remain distinct from its recorded quantity and kilograms'
) from pg_temp.results;
select pg_temp.expect_error(
  'select economics_v2.calculate_group_period_live_metrics(null, null)', '22023', 'invalid_request', 'granja_id'
);
select pg_temp.expect_error(
  format('select economics_v2.calculate_group_period_live_metrics(%L::uuid, null)', farm_a), '22023', 'invalid_request', 'period_id'
) from pg_temp.fixture_ids;
select pg_temp.expect_error(
  format('select economics_v2.calculate_group_period_live_metrics(%L::uuid, gen_random_uuid())', farm_a), '22023', 'invalid_request', 'period_id'
) from pg_temp.fixture_ids;
select pg_temp.expect_error(
  format('select economics_v2.calculate_group_period_live_metrics(%L::uuid, %L::uuid)', farm_a, period_b), '42501', 'forbidden', 'period_id'
) from pg_temp.fixture_ids;
select pg_temp.assert_true(
  (select not p.prosecdef and p.provolatile = 's' and p.proconfig @> array['search_path=""']
     and not has_function_privilege('public', p.oid, 'execute')
     and not has_function_privilege('anon', p.oid, 'execute')
     and not has_function_privilege('authenticated', p.oid, 'execute')
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'economics_v2' and p.proname = 'calculate_group_period_live_metrics'
      and pg_get_function_identity_arguments(p.oid) = 'p_granja_id uuid, p_period_id uuid'),
  'private helper must be stable invoker, empty-path, and client-inaccessible'
);
do $authenticated_denial$
declare v_farm uuid; v_period uuid;
begin
  select farm_a, period_main into v_farm, v_period from pg_temp.fixture_ids;
  set local role authenticated;
  begin
    perform economics_v2.calculate_group_period_live_metrics(v_farm, v_period);
    raise exception 'authenticated direct helper access unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  reset role;
end;
$authenticated_denial$;
select jsonb_build_object(
  'result', 'group_economics_forward_metrics_read_pass',
  'case_count', 13,
  'metrics', jsonb_build_object('main', main_metrics, 'source', source_metrics, 'destination', destination_metrics,
    'empty', zero_metrics, 'zero_revenue', zero_revenue_metrics, 'rejoin', rejoin_metrics, 'quantity_probe', quantity_metrics)
) as evidence from pg_temp.results;
rollback;
