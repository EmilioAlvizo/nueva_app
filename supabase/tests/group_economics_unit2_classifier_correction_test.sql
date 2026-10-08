begin;

create or replace function pg_temp.assert_true(condition boolean, message text)
returns void language plpgsql as $$
begin
  if condition is distinct from true then raise exception '%', message; end if;
end;
$$;

create or replace function pg_temp.expect_state(expected text, statement text)
returns void language plpgsql as $$
declare actual text;
begin
  begin execute statement;
  exception when others then
    get stacked diagnostics actual = returned_sqlstate;
    perform pg_temp.assert_true(actual = expected, format('expected %s, got %s', expected, actual));
    return;
  end;
  raise exception 'expected SQLSTATE % but statement succeeded', expected;
end;
$$;

create temp table pg_temp.fixture as select
  gen_random_uuid() owner_id, gen_random_uuid() farm_id, gen_random_uuid() type_id,
  gen_random_uuid() purpose_id, gen_random_uuid() group_id, gen_random_uuid() group_b_id, gen_random_uuid() period_id, gen_random_uuid() period_b_id,
  gen_random_uuid() exact_cycle_id, gen_random_uuid() feed_cycle_id,
  gen_random_uuid() conflict_cycle_id, gen_random_uuid() boundary_cycle_id, gen_random_uuid() out_cycle_id, gen_random_uuid() ambiguous_cycle_id, gen_random_uuid() missing_cycle_id, gen_random_uuid() cross_cycle_id,
  gen_random_uuid() exact_animal_id, gen_random_uuid() feed_animal_id,
  gen_random_uuid() conflict_animal_id, gen_random_uuid() boundary_animal_id, gen_random_uuid() out_animal_id, gen_random_uuid() ambiguous_animal_id, gen_random_uuid() cross_animal_id,
  gen_random_uuid() exact_sale_id, gen_random_uuid() conflict_sale_id, gen_random_uuid() out_sale_id,
  gen_random_uuid() second_conflict_sale_id, gen_random_uuid() other_farm_id, gen_random_uuid() other_type_id, gen_random_uuid() other_group_id, gen_random_uuid() operation_id;

insert into auth.users (id, aud, role, created_at, updated_at)
select owner_id, 'authenticated', 'authenticated', now(), now() from pg_temp.fixture;
insert into public.granjas (id, owner_id, nombre, created_by)
select farm_id, owner_id, 'CU2-A classifier fixture', owner_id from pg_temp.fixture;
insert into public.tipo_animal (id, granja_id, nombre, created_by)
select type_id, farm_id, 'CU2-A type', owner_id from pg_temp.fixture;
insert into public.cat_proposito_animal (id, granja_id, nombre, codigo_calculo, created_by)
select purpose_id, farm_id, 'CU2-A meat', 'carne', owner_id from pg_temp.fixture;
insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
select group_id, farm_id, type_id, 'mutable-name-is-not-evidence', owner_id from pg_temp.fixture;
insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
select group_b_id, farm_id, type_id, 'second-group', owner_id from pg_temp.fixture;
insert into public.animales (id, granja_id, tipo_animal_id, grupo_id, proposito_id, created_by)
select animal_id, farm_id, type_id, group_id, purpose_id, owner_id
from pg_temp.fixture cross join lateral unnest(array[exact_animal_id, feed_animal_id, conflict_animal_id, boundary_animal_id, out_animal_id, ambiguous_animal_id]) animal_id;
insert into public.granjas (id, owner_id, nombre, created_by)
select other_farm_id, owner_id, 'CU2-A other farm', owner_id from pg_temp.fixture;
insert into public.tipo_animal (id, granja_id, nombre, created_by)
select other_type_id, other_farm_id, 'CU2-A other type', owner_id from pg_temp.fixture;
insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
select other_group_id, other_farm_id, other_type_id, 'other-group', owner_id from pg_temp.fixture;
insert into public.animales (id, granja_id, tipo_animal_id, grupo_id, proposito_id, created_by)
select cross_animal_id, other_farm_id, other_type_id, other_group_id, purpose_id, owner_id from pg_temp.fixture;
insert into economics_v2.group_occupancy_periods (id, granja_id, group_id, purpose_id, starts_on, closed_on, start_position, end_position)
select period_id, farm_id, group_id, purpose_id, date '2025-01-01', date '2025-04-01', 10, 40 from pg_temp.fixture;
insert into economics_v2.group_occupancy_periods (id, granja_id, group_id, purpose_id, starts_on, closed_on, start_position, end_position)
select period_b_id, farm_id, group_b_id, purpose_id, date '2025-01-01', date '2025-04-01', 40, 70 from pg_temp.fixture;
insert into economics_v2.group_occupancy_memberships (id, period_id, granja_id, animal_id, start_position, end_position)
select gen_random_uuid(), period_id, farm_id, animal_id, 11 + row_number() over (), 31 + row_number() over ()
from pg_temp.fixture cross join lateral unnest(array[exact_animal_id, feed_animal_id, conflict_animal_id, boundary_animal_id, out_animal_id, ambiguous_animal_id]) animal_id;
insert into economics_v2.group_occupancy_memberships (period_id, granja_id, animal_id, start_position, end_position)
select period_b_id, farm_id, ambiguous_animal_id, 41, 69 from pg_temp.fixture;
insert into economics_v2.group_occupancy_events (granja_id, period_id, membership_id, animal_id, event_position, effective_on, action)
select membership.granja_id, membership.period_id, membership.id, membership.animal_id, membership.start_position, date '2025-01-01', 'enter'
from economics_v2.group_occupancy_memberships membership join pg_temp.fixture f on f.period_id = membership.period_id
union all
select membership.granja_id, membership.period_id, membership.id, membership.animal_id, membership.end_position, date '2025-04-01', 'exit'
from economics_v2.group_occupancy_memberships membership join pg_temp.fixture f on f.period_id = membership.period_id;
insert into economics_v2.group_occupancy_events (granja_id, period_id, membership_id, animal_id, event_position, effective_on, action)
select membership.granja_id, membership.period_id, membership.id, membership.animal_id, membership.start_position, date '2025-01-01', 'enter' from economics_v2.group_occupancy_memberships membership join pg_temp.fixture f on f.period_b_id = membership.period_id
union all select membership.granja_id, membership.period_id, membership.id, membership.animal_id, membership.end_position, date '2025-04-01', 'exit' from economics_v2.group_occupancy_memberships membership join pg_temp.fixture f on f.period_b_id = membership.period_id;
insert into economics_v2.cycles (id, granja_id, proposito_id, starts_on, ends_on, production_closed_on, status, created_by)
select cycle_id, farm_id, purpose_id, date '2025-02-01', date '2025-02-28', date '2025-02-27', 'production_closed', owner_id
from pg_temp.fixture cross join lateral unnest(array[exact_cycle_id, feed_cycle_id, conflict_cycle_id, boundary_cycle_id, out_cycle_id, ambiguous_cycle_id, missing_cycle_id, cross_cycle_id]) cycle_id;
insert into economics_v2.cycle_animals (cycle_id, animal_id, joined_on, left_on, sold_by_sale_id, group_name_snapshot)
select exact_cycle_id, exact_animal_id, date '2025-02-02', date '2025-02-27', exact_sale_id, 'mutable-name-is-not-evidence' from pg_temp.fixture union all
select feed_cycle_id, feed_animal_id, date '2025-02-02', date '2025-02-27', null, 'mutable-name-is-not-evidence' from pg_temp.fixture union all
select conflict_cycle_id, conflict_animal_id, date '2025-02-02', date '2025-02-27', conflict_sale_id, 'mutable-name-is-not-evidence' from pg_temp.fixture union all
select boundary_cycle_id, boundary_animal_id, date '2025-01-01', date '2025-02-27', null, 'mutable-name-is-not-evidence' from pg_temp.fixture;
insert into economics_v2.cycle_animals (cycle_id, animal_id, joined_on, left_on, sold_by_sale_id, group_name_snapshot)
select out_cycle_id, out_animal_id, date '2025-02-02', date '2025-02-27', out_sale_id, 'mutable-name-is-not-evidence' from pg_temp.fixture union all
select ambiguous_cycle_id, ambiguous_animal_id, date '2025-02-02', date '2025-02-27', null, 'mutable-name-is-not-evidence' from pg_temp.fixture union all
select cross_cycle_id, cross_animal_id, date '2025-02-02', date '2025-02-27', null, 'other-group' from pg_temp.fixture;
insert into public.venta_animal (id, granja_id, grupo_id, tipo_animal_id, animal_id, fecha_venta, total_amount, created_by)
select exact_sale_id, farm_id, group_id, type_id, exact_animal_id, date '2025-02-12', 125, owner_id from pg_temp.fixture union all
select conflict_sale_id, farm_id, group_id, type_id, conflict_animal_id, date '2025-02-12', 125, owner_id from pg_temp.fixture union all
select second_conflict_sale_id, farm_id, group_id, type_id, conflict_animal_id, date '2025-02-13', 126, owner_id from pg_temp.fixture union all
select out_sale_id, farm_id, group_id, type_id, out_animal_id, date '2025-02-01', 125, owner_id from pg_temp.fixture;
insert into economics_v2.cycle_expenses (cycle_id, granja_id, occurred_on, amount, created_by)
select exact_cycle_id, farm_id, date '2025-02-14', 20, owner_id from pg_temp.fixture;
insert into economics_v2.cycle_feeds (cycle_id, granja_id, starts_on, ends_on, group_name_snapshot, created_by)
select feed_cycle_id, farm_id, date '2025-02-10', date '2025-02-11', 'mutable-name-is-not-evidence', owner_id from pg_temp.fixture;

select economics_v2.classify_legacy_cycle(cycle_id)
from pg_temp.fixture cross join lateral unnest(array[exact_cycle_id, feed_cycle_id, conflict_cycle_id, boundary_cycle_id, out_cycle_id, ambiguous_cycle_id, missing_cycle_id, cross_cycle_id]) cycle_id;

select pg_temp.assert_true(
  (select classification = 'exact' and candidate_period_id = period_id
   and source_provenance ? 'member_sources' and source_provenance ? 'feed_sources'
   and source_provenance ? 'expense_sources' and source_provenance ? 'sale_sources'
   and jsonb_array_length(source_provenance->'member_sources') = 1
   and jsonb_array_length(source_provenance->'expense_sources') = 1
   and jsonb_array_length(source_provenance->'sale_sources') = 1
   from economics_v2.cycle_group_classifications join pg_temp.fixture on cycle_id = exact_cycle_id)
  and (select classification = 'compatible_but_unresolved' and reason_code = 'missing_feed_attribution' from economics_v2.cycle_group_classifications join pg_temp.fixture on cycle_id = feed_cycle_id)
  and (select classification = 'compatible_but_unresolved' and reason_code = 'contradictory_sale_evidence' from economics_v2.cycle_group_classifications join pg_temp.fixture on cycle_id = conflict_cycle_id)
  and (select classification = 'compatible_but_unresolved' and reason_code = 'legacy_same_day_order_unknown' from economics_v2.cycle_group_classifications join pg_temp.fixture on cycle_id = boundary_cycle_id)
  and (select classification = 'compatible_but_unresolved' and reason_code = 'contradictory_sale_evidence' from economics_v2.cycle_group_classifications join pg_temp.fixture on cycle_id = out_cycle_id)
  and (select classification = 'compatible_but_unresolved' and reason_code = 'multi_group' from economics_v2.cycle_group_classifications join pg_temp.fixture on cycle_id = ambiguous_cycle_id)
  and (select classification = 'compatible_but_unresolved' and reason_code = 'missing_evidence' from economics_v2.cycle_group_classifications join pg_temp.fixture on cycle_id = missing_cycle_id)
  and (select classification = 'compatible_but_unresolved' and reason_code = 'ownership_mismatch' from economics_v2.cycle_group_classifications join pg_temp.fixture on cycle_id = cross_cycle_id),
  'exact admission requires immutable member, expense, and canonical-sale evidence; missing, cross-farm, duplicate, same-day, out-of-window, and multi-group facts quarantine'
);

select pg_temp.assert_true(
  (select count(*) = 4 from pg_class relation join pg_namespace namespace on namespace.oid = relation.relnamespace
   join pg_policy policy on policy.polrelid = relation.oid
   where namespace.nspname = 'economics_v2' and policy.polname in (
     'cycle_group_classifications_deny_direct', 'group_economics_quarantines_deny_direct',
     'cycle_period_mappings_deny_direct', 'group_economics_quarantine_operations_deny_direct'
   ) and relation.relrowsecurity and relation.relforcerowsecurity
   and not has_table_privilege('authenticated', relation.oid, 'select,insert,update,delete')
   and not has_table_privilege('anon', relation.oid, 'select,insert,update,delete')),
  'all Unit 2 private tables require explicit deny-direct policies and no client table privileges'
);

do $interlock$
declare f pg_temp.fixture%rowtype; quarantine_id uuid;
begin
  select * into f from pg_temp.fixture;
  select id into quarantine_id from economics_v2.group_economics_quarantines where cycle_id = f.feed_cycle_id;
  perform set_config('request.jwt.claim.sub', f.owner_id::text, true); set local role authenticated;
  perform pg_temp.expect_state('0A000', format(
    'select public.resolve_group_economics_quarantine(%L::uuid, %L::uuid, %L::uuid, ''attach_evidence'', null, ''blocked until CU2-B'')',
    f.farm_id, quarantine_id, f.operation_id));
  reset role;
  perform pg_temp.assert_true(not exists (select 1 from economics_v2.cycle_period_mappings where cycle_id = f.feed_cycle_id), 'CU2-A must not map while resolver security remains deferred');
end;
$interlock$;

select jsonb_build_object('result', 'group_economics_unit2_classifier_correction_pass', 'quarantines', (select count(*) from economics_v2.group_economics_quarantines)) as evidence;
rollback;
