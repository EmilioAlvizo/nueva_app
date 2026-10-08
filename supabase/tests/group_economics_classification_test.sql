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

create temp table pg_temp.ids as
select gen_random_uuid() owner_id, gen_random_uuid() viewer_id, gen_random_uuid() farm_id,
  gen_random_uuid() type_id, gen_random_uuid() meat_id, gen_random_uuid() egg_id,
  gen_random_uuid() group_a_id, gen_random_uuid() group_b_id, gen_random_uuid() exact_period_id,
  gen_random_uuid() exact_cycle_id, gen_random_uuid() multi_cycle_id, gen_random_uuid() missing_cycle_id,
  gen_random_uuid() same_day_cycle_id, gen_random_uuid() egg_cycle_id,
  gen_random_uuid() animal_a_id, gen_random_uuid() animal_b_id, gen_random_uuid() operation_id;
create temp table pg_temp.baseline as select
  (select count(*) from economics_v2.cycle_group_classifications) classifications,
  (select count(*) from economics_v2.group_economics_quarantines) quarantines,
  (select count(*) from economics_v2.cycle_period_mappings) mappings,
  (select count(*) from economics_v2.cycles) cycles,
  (select count(*) from economics_v2.cycle_animals) members;

insert into auth.users (id, aud, role, created_at, updated_at)
select user_id, 'authenticated', 'authenticated', now(), now()
from pg_temp.ids cross join lateral unnest(array[owner_id, viewer_id]) users(user_id);
insert into public.granjas (id, owner_id, nombre, created_by)
select farm_id, owner_id, 'classification fixture farm', owner_id from pg_temp.ids;
insert into public.miembros_granja (granja_id, user_id, rol, invited_by)
select farm_id, viewer_id, 'viewer', owner_id from pg_temp.ids;
insert into public.tipo_animal (id, granja_id, nombre, created_by)
select type_id, farm_id, 'classification fixture type', owner_id from pg_temp.ids;
insert into public.cat_proposito_animal (id, granja_id, nombre, codigo_calculo, created_by)
select meat_id, farm_id, 'fixture meat', 'carne', owner_id from pg_temp.ids union all
select egg_id, farm_id, 'fixture egg', 'postura', owner_id from pg_temp.ids;
insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
select group_a_id, farm_id, type_id, 'fixture group A', owner_id from pg_temp.ids union all
select group_b_id, farm_id, type_id, 'fixture group B', owner_id from pg_temp.ids;
insert into public.animales (id, granja_id, tipo_animal_id, grupo_id, proposito_id, created_by)
select animal_a_id, farm_id, type_id, group_a_id, meat_id, owner_id from pg_temp.ids union all
select animal_b_id, farm_id, type_id, group_b_id, meat_id, owner_id from pg_temp.ids;
insert into economics_v2.group_occupancy_periods (id, granja_id, group_id, purpose_id, starts_on, closed_on, start_position, end_position)
select exact_period_id, farm_id, group_a_id, meat_id, date '2025-01-01', date '2025-04-01', 10, 20 from pg_temp.ids;
insert into economics_v2.cycles (id, granja_id, proposito_id, starts_on, ends_on, production_closed_on, status, created_by)
select exact_cycle_id, farm_id, meat_id, date '2025-02-01', date '2025-02-28', date '2025-02-27', 'production_closed', owner_id from pg_temp.ids union all
select multi_cycle_id, farm_id, meat_id, date '2025-02-01', date '2025-02-28', date '2025-02-27', 'production_closed', owner_id from pg_temp.ids union all
select missing_cycle_id, farm_id, meat_id, date '2025-02-01', date '2025-02-28', date '2025-02-27', 'production_closed', owner_id from pg_temp.ids union all
select same_day_cycle_id, farm_id, meat_id, date '2025-01-01', date '2025-01-20', date '2025-01-19', 'production_closed', owner_id from pg_temp.ids union all
select egg_cycle_id, farm_id, egg_id, date '2025-02-01', date '2025-02-28', date '2025-02-27', 'production_closed', owner_id from pg_temp.ids;
insert into economics_v2.cycle_animals (cycle_id, animal_id, joined_on, left_on, group_name_snapshot)
select exact_cycle_id, animal_a_id, date '2025-02-01', date '2025-02-27', 'fixture group A' from pg_temp.ids union all
select multi_cycle_id, animal_a_id, date '2025-02-01', date '2025-02-27', 'fixture group A' from pg_temp.ids union all
select multi_cycle_id, animal_b_id, date '2025-02-01', date '2025-02-27', 'fixture group B' from pg_temp.ids union all
select same_day_cycle_id, animal_a_id, date '2025-01-01', date '2025-01-19', 'fixture group A' from pg_temp.ids;

select economics_v2.classify_legacy_cycle(cycle_id)
from pg_temp.ids cross join lateral unnest(array[exact_cycle_id, multi_cycle_id, missing_cycle_id, same_day_cycle_id, egg_cycle_id]) cycles(cycle_id);
select pg_temp.assert_true(
  (select classification = 'exact' and candidate_period_id = exact_period_id from economics_v2.cycle_group_classifications join pg_temp.ids on cycle_id = exact_cycle_id)
  and (select classification = 'compatible_but_unresolved' and reason_code = 'multi_group' from economics_v2.cycle_group_classifications join pg_temp.ids on cycle_id = multi_cycle_id)
  and (select classification = 'compatible_but_unresolved' and reason_code = 'missing_evidence' from economics_v2.cycle_group_classifications join pg_temp.ids on cycle_id = missing_cycle_id)
  and (select classification = 'compatible_but_unresolved' and reason_code = 'legacy_same_day_order_unknown' from economics_v2.cycle_group_classifications join pg_temp.ids on cycle_id = same_day_cycle_id)
  and (select classification = 'non_mappable' and reason_code = 'non_meat_purpose' from economics_v2.cycle_group_classifications join pg_temp.ids on cycle_id = egg_cycle_id)
  and (select count(*) from economics_v2.group_economics_quarantines) = (select quarantines + 4 from pg_temp.baseline)
  and (select count(*) from economics_v2.cycle_period_mappings) = (select mappings from pg_temp.baseline),
  'classifier must preserve exact evidence and quarantine every ambiguous or non-mappable cycle without inferred mapping'
);

select economics_v2.classify_legacy_cycle(exact_cycle_id) from pg_temp.ids;
select pg_temp.assert_true(
  (select count(*) = (select classifications + 5 from pg_temp.baseline) from economics_v2.cycle_group_classifications)
  and (select source_provenance ? 'cycle_id' and source_provenance ? 'temporal_precision' and source_provenance->>'temporal_precision' = 'date' from economics_v2.cycle_group_classifications join pg_temp.ids on cycle_id = exact_cycle_id)
  and (select count(*) = (select cycles + 5 from pg_temp.baseline) from economics_v2.cycles)
  and (select count(*) = (select members + 4 from pg_temp.baseline) from economics_v2.cycle_animals),
  'classification replay must be idempotent and retain legacy source rows and date-only provenance'
);

do $resolution$
declare fixture record; quarantine_id uuid; result jsonb;
begin
  select * into fixture from pg_temp.ids;
  select id into quarantine_id from economics_v2.group_economics_quarantines where cycle_id = fixture.same_day_cycle_id;
  perform set_config('request.jwt.claim.sub', fixture.viewer_id::text, true); set local role authenticated;
  perform pg_temp.expect_state('42501', format('select public.resolve_group_economics_quarantine(%L::uuid, %L::uuid, %L::uuid, ''attach_evidence'', null, ''viewer evidence'')', fixture.farm_id, quarantine_id, fixture.operation_id));
  reset role; perform set_config('request.jwt.claim.sub', fixture.owner_id::text, true); set local role authenticated;
  result := public.resolve_group_economics_quarantine(fixture.farm_id, quarantine_id, fixture.operation_id, 'attach_evidence', null, 'source ledger reviewed');
  perform pg_temp.assert_true(result->>'resolution_action' = 'attach_evidence' and coalesce((result->>'replayed')::boolean, false) is false, 'owner evidence must append once');
  result := public.resolve_group_economics_quarantine(fixture.farm_id, quarantine_id, fixture.operation_id, 'attach_evidence', null, 'source ledger reviewed');
  perform pg_temp.assert_true((result->>'replayed')::boolean, 'identical quarantine operation must replay');
  perform pg_temp.expect_state('22023', format('select public.resolve_group_economics_quarantine(%L::uuid, %L::uuid, %L::uuid, ''attach_evidence'', null, ''different evidence'')', fixture.farm_id, quarantine_id, fixture.operation_id));
  reset role;
  update economics_v2.cycles set starts_on = date '2025-01-02', production_closed_on = date '2025-01-21', ends_on = date '2025-01-22' where id = fixture.same_day_cycle_id;
  perform economics_v2.classify_legacy_cycle(fixture.same_day_cycle_id);
  perform set_config('request.jwt.claim.sub', fixture.owner_id::text, true); set local role authenticated;
  result := public.resolve_group_economics_quarantine(fixture.farm_id, quarantine_id, gen_random_uuid(), 'map_exact', fixture.exact_period_id, 'corrected source evidence');
  reset role;
  perform pg_temp.assert_true(result->>'resolution_action' = 'map_exact' and result->>'period_id' = fixture.exact_period_id::text and (select count(*) = 1 from economics_v2.cycle_period_mappings where cycle_id = fixture.same_day_cycle_id), 'fresh exact classification must create one evidence-backed mapping');
  select id into quarantine_id from economics_v2.group_economics_quarantines where cycle_id = fixture.egg_cycle_id;
  perform set_config('request.jwt.claim.sub', fixture.owner_id::text, true); set local role authenticated;
  result := public.resolve_group_economics_quarantine(fixture.farm_id, quarantine_id, gen_random_uuid(), 'confirm_non_mappable', null, 'purpose is not meat');
  perform pg_temp.assert_true(result->>'resolution_action' = 'confirm_non_mappable' and result->>'classification' = 'non_mappable', 'owner must confirm only a non-mappable quarantine');
  reset role;
end;
$resolution$;

select jsonb_build_object('result', 'group_economics_classification_pass', 'classifications', (select count(*) from economics_v2.cycle_group_classifications), 'quarantines', (select count(*) from economics_v2.group_economics_quarantines)) as evidence;
rollback;
