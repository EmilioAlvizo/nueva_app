begin;

create or replace function pg_temp.assert_true(condition boolean, message text)
returns void language plpgsql as $$
begin
  if condition is distinct from true then
    raise exception '%', message;
  end if;
end;
$$;

create or replace function pg_temp.expect_sqlstate(
  expected_state text,
  statement text,
  message text
) returns text language plpgsql as $$
declare
  actual_state text;
begin
  begin
    execute statement;
  exception when others then
    get stacked diagnostics actual_state = returned_sqlstate;
    perform pg_temp.assert_true(
      actual_state = expected_state,
      format('%s: expected SQLSTATE %s, received %s', message, expected_state, actual_state)
    );
    return actual_state;
  end;

  raise exception '%: expected SQLSTATE % but the statement succeeded', message, expected_state;
end;
$$;

create temp table pg_temp.fixture_ids as
select
  gen_random_uuid() as owner_id,
  gen_random_uuid() as editor_id,
  gen_random_uuid() as viewer_id,
  gen_random_uuid() as nonmember_id,
  gen_random_uuid() as cross_farm_id,
  gen_random_uuid() as farm_a_id,
  gen_random_uuid() as farm_b_id,
  gen_random_uuid() as type_a_id,
  gen_random_uuid() as type_b_id,
  gen_random_uuid() as group_a_id,
  gen_random_uuid() as purpose_a_id,
  gen_random_uuid() as animal_a_id,
  gen_random_uuid() as animal_b_id,
  gen_random_uuid() as period_id,
  gen_random_uuid() as membership_id,
  gen_random_uuid() as event_id,
  gen_random_uuid() as snapshot_id,
  gen_random_uuid() as cleanup_operation_id;

-- The active auth/farm triggers create profiles and owner memberships.
insert into auth.users (id, aud, role, created_at, updated_at)
select user_id, 'authenticated', 'authenticated', now(), now()
from pg_temp.fixture_ids fixture
cross join lateral unnest(array[
  fixture.owner_id,
  fixture.editor_id,
  fixture.viewer_id,
  fixture.nonmember_id,
  fixture.cross_farm_id
]) as users(user_id);

insert into public.granjas (id, owner_id, nombre, created_by)
select farm_a_id, owner_id, 'GE evidence farm A', owner_id from pg_temp.fixture_ids
union all
select farm_b_id, cross_farm_id, 'GE evidence farm B', cross_farm_id from pg_temp.fixture_ids;

insert into public.miembros_granja (granja_id, user_id, rol, invited_by)
select farm_a_id, editor_id, 'editor'::public.rol_miembro, owner_id from pg_temp.fixture_ids
union all
select farm_a_id, viewer_id, 'viewer'::public.rol_miembro, owner_id from pg_temp.fixture_ids;

insert into public.tipo_animal (id, granja_id, nombre, created_by)
select type_a_id, farm_a_id, 'GE evidence type A', owner_id from pg_temp.fixture_ids
union all
select type_b_id, farm_b_id, 'GE evidence type B', cross_farm_id from pg_temp.fixture_ids;

insert into public.grupos (id, granja_id, tipo_animal_id, nombre, created_by)
select group_a_id, farm_a_id, type_a_id, 'GE evidence group A', owner_id
from pg_temp.fixture_ids;

insert into public.cat_proposito_animal (
  id, granja_id, nombre, created_by, codigo_calculo
)
select purpose_a_id, farm_a_id, 'GE evidence meat purpose', owner_id, 'carne'
from pg_temp.fixture_ids;

insert into public.animales (
  id, granja_id, tipo_animal_id, grupo_id, proposito_id, created_by
)
select animal_a_id, farm_a_id, type_a_id, group_a_id, purpose_a_id, owner_id
from pg_temp.fixture_ids
union all
select animal_b_id, farm_b_id, type_b_id, null, null, cross_farm_id
from pg_temp.fixture_ids;

create temp table pg_temp.phase_matrix (
  actor text primary key,
  expected_sqlstate text not null,
  actual_sqlstate text not null
);

do $phase_matrix$
declare
  fixture record;
  actor_name text;
  actual_state text;
begin
  select * into fixture from pg_temp.fixture_ids;

  set local role anon;
  begin
    perform public.list_group_economics(fixture.farm_a_id, 25, null, null);
    raise exception 'anon wrapper unexpectedly succeeded';
  exception when insufficient_privilege then
    get stacked diagnostics actual_state = returned_sqlstate;
  end;
  reset role;
  insert into pg_temp.phase_matrix values ('anon', '42501', actual_state);

  foreach actor_name in array array['owner', 'editor', 'viewer', 'nonmember', 'cross_farm']
  loop
    perform set_config(
      'request.jwt.claim.sub',
      case actor_name
        when 'owner' then fixture.owner_id::text
        when 'editor' then fixture.editor_id::text
        when 'viewer' then fixture.viewer_id::text
        when 'nonmember' then fixture.nonmember_id::text
        else fixture.cross_farm_id::text
      end,
      true
    );
    set local role authenticated;
    begin
      perform public.list_group_economics(fixture.farm_a_id, 25, null, null);
      raise exception '% wrapper unexpectedly succeeded', actor_name;
    exception when feature_not_supported then
      get stacked diagnostics actual_state = returned_sqlstate;
    end;
    reset role;
    insert into pg_temp.phase_matrix values (actor_name, '0A000', actual_state);
  end loop;
end;
$phase_matrix$;

do $role_controls$
declare
  fixture record;
begin
  select * into fixture from pg_temp.fixture_ids;
  perform set_config('request.jwt.claim.sub', fixture.viewer_id::text, true);
  set local role authenticated;
  begin
    perform 1 from economics_v2.group_occupancy_periods;
    raise exception 'authenticated direct foundation-table read unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    perform economics_v2.group_economics_not_activated();
    raise exception 'authenticated private helper unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  reset role;
end;
$role_controls$;

insert into economics_v2.group_occupancy_periods (
  granja_id, group_id, purpose_id, starts_on, closed_on, start_position, end_position
)
select farm_a_id, group_a_id, purpose_a_id, current_date, current_date, 10, 20
from pg_temp.fixture_ids
union all
select farm_a_id, group_a_id, purpose_a_id, current_date, current_date, 20, 30
from pg_temp.fixture_ids
union all
select farm_a_id, group_a_id, purpose_a_id, current_date, current_date, 100, 200
from pg_temp.fixture_ids;

insert into economics_v2.group_occupancy_periods (
  id, granja_id, group_id, purpose_id, starts_on, start_position
)
select period_id, farm_a_id, group_a_id, purpose_a_id, current_date, 300
from pg_temp.fixture_ids;

create temp table pg_temp.constraint_results (
  check_name text primary key,
  actual_sqlstate text not null
);

insert into pg_temp.constraint_results
select 'period_overlap', pg_temp.expect_sqlstate(
  '23P01',
  format(
    'insert into economics_v2.group_occupancy_periods (granja_id, group_id, purpose_id, starts_on, closed_on, start_position, end_position) values (%L::uuid, %L::uuid, %L::uuid, current_date, current_date, 19, 29)',
    farm_a_id, group_a_id, purpose_a_id
  ),
  'overlapping period positions must be rejected'
)
from pg_temp.fixture_ids;

insert into pg_temp.constraint_results
select 'one_open', pg_temp.expect_sqlstate(
  '23P01',
  format(
    'insert into economics_v2.group_occupancy_periods (granja_id, group_id, purpose_id, starts_on, start_position) values (%L::uuid, %L::uuid, %L::uuid, current_date, 301)',
    farm_a_id, group_a_id, purpose_a_id
  ),
  'second open period must be rejected'
)
from pg_temp.fixture_ids;

insert into economics_v2.group_occupancy_memberships (
  id, period_id, granja_id, animal_id, start_position, end_position
)
select membership_id, period_id, farm_a_id, animal_a_id, 110, 120
from pg_temp.fixture_ids;

insert into pg_temp.constraint_results
select 'membership_containment', pg_temp.expect_sqlstate(
  '23514',
  format($statement$
    insert into economics_v2.group_occupancy_memberships (period_id, granja_id, animal_id, start_position, end_position)
    values (%L::uuid, %L::uuid, %L::uuid, 120, 201);
    set constraints all immediate
  $statement$, period_id, farm_a_id, animal_a_id),
  'membership outside the period span must be rejected'
)
from pg_temp.fixture_ids;

insert into pg_temp.constraint_results
select 'membership_cross_farm', pg_temp.expect_sqlstate(
  '23514',
  format($statement$
    insert into economics_v2.group_occupancy_memberships (period_id, granja_id, animal_id, start_position, end_position)
    values (%L::uuid, %L::uuid, %L::uuid, 130, 140);
    set constraints all immediate
  $statement$, period_id, farm_a_id, animal_b_id),
  'cross-farm membership must be rejected'
)
from pg_temp.fixture_ids;

insert into economics_v2.group_occupancy_events (
  id, granja_id, period_id, membership_id, animal_id, event_position, effective_on, action
)
select event_id, farm_a_id, period_id, membership_id, animal_a_id, 110, current_date, 'enter'
from pg_temp.fixture_ids;

insert into economics_v2.group_meat_snapshots (
  id, period_id, granja_id, snapshot_version, payload
)
select snapshot_id, period_id, farm_a_id, 'group-meat-snapshot.v2', '{}'::jsonb
from pg_temp.fixture_ids;

insert into pg_temp.constraint_results
select 'event_update_immutable', pg_temp.expect_sqlstate(
  '23514',
  format('update economics_v2.group_occupancy_events set effective_on = current_date + 1 where id = %L::uuid', event_id),
  'event update must be rejected'
)
from pg_temp.fixture_ids;

insert into pg_temp.constraint_results
select 'snapshot_delete_immutable', pg_temp.expect_sqlstate(
  '23514',
  format('delete from economics_v2.group_meat_snapshots where id = %L::uuid', snapshot_id),
  'snapshot deletion must be rejected'
)
from pg_temp.fixture_ids;

do $cleanup$
declare
  caught_intentional_failure boolean := false;
begin
  begin
    insert into economics_v2.group_occupancy_operations (
      granja_id, operation_id, payload_hash, result, event_position
    )
    select farm_a_id, cleanup_operation_id, 'evidence-cleanup-probe', '{}'::jsonb, 999
    from pg_temp.fixture_ids;
    raise exception using errcode = 'P0001', message = 'intentional evidence cleanup failure';
  exception when raise_exception then
    caught_intentional_failure := true;
  end;

  perform pg_temp.assert_true(caught_intentional_failure, 'intentional cleanup failure must be caught');
  perform pg_temp.assert_true(
    not exists (
      select 1
      from economics_v2.group_occupancy_operations operation
      join pg_temp.fixture_ids fixture on fixture.cleanup_operation_id = operation.operation_id
    ),
    'caught cleanup failure must roll back its synthetic operation'
  );
end;
$cleanup$;

select pg_temp.assert_true(
  (select count(*) from pg_temp.phase_matrix) = 6
  and not exists (
    select 1 from pg_temp.phase_matrix
    where (actor = 'anon' and actual_sqlstate <> '42501')
       or (actor <> 'anon' and actual_sqlstate <> '0A000')
  )
  and (select count(*) from pg_temp.constraint_results) = 6
  and (select count(*) from economics_v2.group_occupancy_periods period join pg_temp.fixture_ids fixture on period.granja_id = fixture.farm_a_id) = 4
  and (select count(*) from economics_v2.group_occupancy_memberships membership join pg_temp.fixture_ids fixture on membership.id = fixture.membership_id) = 1
  and (select count(*) from economics_v2.group_occupancy_events event join pg_temp.fixture_ids fixture on event.id = fixture.event_id) = 1
  and (select count(*) from economics_v2.group_meat_snapshots snapshot join pg_temp.fixture_ids fixture on snapshot.id = fixture.snapshot_id) = 1,
  'phase probes and negative controls must preserve owned fixture state'
);

select jsonb_build_object(
  'result', 'group_economics_foundation_evidence_pass',
  'phase_matrix', (select jsonb_agg(to_jsonb(phase) order by actor) from pg_temp.phase_matrix phase),
  'constraint_sqlstates', (select jsonb_agg(to_jsonb(result) order by check_name) from pg_temp.constraint_results result),
  'extension_schema', (select namespace.nspname from pg_extension extension join pg_namespace namespace on namespace.oid = extension.extnamespace where extension.extname = 'btree_gist')
) as evidence;

rollback;
