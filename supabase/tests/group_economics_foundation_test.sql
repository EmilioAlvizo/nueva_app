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
  to_regprocedure('public.transition_group_occupancy(uuid,uuid,text,uuid,date,uuid,uuid,uuid)') is not null
  and to_regprocedure('public.list_group_economics(uuid,integer,date,uuid)') is not null
  and to_regprocedure('public.group_economics_parity(uuid,uuid)') is not null
  and to_regprocedure('public.resolve_group_economics_quarantine(uuid,uuid,uuid,text,uuid,text)') is not null,
  'all four Group Economics public RPC signatures must exist'
);

select pg_temp.assert_true(
  not exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'transition_group_occupancy',
        'list_group_economics',
        'group_economics_parity',
        'resolve_group_economics_quarantine'
      )
      and procedure.prosecdef
  ),
  'Group Economics public RPCs must be security invoker'
);

select pg_temp.assert_true(
  (select count(*)
   from pg_proc procedure
   join pg_namespace namespace on namespace.oid = procedure.pronamespace
   where namespace.nspname = 'economics_v2'
     and procedure.proname in (
       'transition_group_occupancy_impl',
       'list_group_economics_impl',
       'group_economics_parity_impl',
       'resolve_group_economics_quarantine_impl'
     )
     and procedure.prosecdef
     and procedure.proconfig @> array['search_path=""']
     and has_function_privilege('authenticated', procedure.oid, 'execute')
     and not has_function_privilege('anon', procedure.oid, 'execute')
     and not has_function_privilege('public', procedure.oid, 'execute')) = 4,
  'only authenticated may execute fixed-search-path guarded implementations'
);

select pg_temp.assert_true(
  (select count(*)
   from pg_class relation
   join pg_namespace namespace on namespace.oid = relation.relnamespace
   where namespace.nspname = 'economics_v2'
     and relation.relname in (
       'group_occupancy_periods',
       'group_occupancy_memberships',
       'group_occupancy_events',
       'group_occupancy_operations',
       'group_meat_snapshots'
     )
     and relation.relrowsecurity
     and relation.relforcerowsecurity
     and not has_table_privilege('authenticated', relation.oid, 'select,insert,update,delete')
     and not has_table_privilege('anon', relation.oid, 'select,insert,update,delete')) = 5,
  'foundation tables must be forced-RLS and inaccessible directly'
);

select pg_temp.assert_true(
  exists (
    select 1 from pg_extension extension join pg_namespace namespace on namespace.oid = extension.extnamespace
    where extension.extname = 'btree_gist' and namespace.nspname = 'extensions'
  )
  and to_regclass('economics_v2.group_occupancy_periods') is not null
  and to_regclass('economics_v2.group_occupancy_memberships') is not null
  and exists (select 1 from pg_constraint where conname = 'group_occupancy_periods_no_overlap')
  and exists (select 1 from pg_constraint where conname = 'group_occupancy_memberships_no_overlap')
  and to_regclass('economics_v2.group_occupancy_periods_one_open') is not null
  and to_regclass('economics_v2.group_occupancy_memberships_one_open') is not null,
  'ordered ranges must enforce non-overlap and one active interval'
);

do $foundation$
begin
  begin
    perform public.list_group_economics(
      '00000000-0000-0000-0000-000000009201', 0, null, null
    );
    raise exception 'list page size below one must be rejected';
  exception when invalid_parameter_value then null;
  end;

  begin
    perform public.list_group_economics(
      '00000000-0000-0000-0000-000000009201', 51, null, null
    );
    raise exception 'list page size above fifty must be rejected';
  exception when invalid_parameter_value then null;
  end;

  begin
    perform public.list_group_economics(
      '00000000-0000-0000-0000-000000009201', 25, current_date, null
    );
    raise exception 'one-sided cursor must be rejected';
  exception when invalid_parameter_value then null;
  end;

  begin
    perform public.transition_group_occupancy(
      '00000000-0000-0000-0000-000000009201',
      '00000000-0000-0000-0000-000000009202',
      'enter',
      '00000000-0000-0000-0000-000000009203',
      current_date,
      null,
      null,
      null
    );
    raise exception 'the inactive transition scaffold must fail closed';
  exception when feature_not_supported then null;
  end;
end;
$foundation$;

select pg_temp.assert_true(
  (select count(*) from economics_v2.group_occupancy_periods) = 0
  and (select count(*) from economics_v2.group_occupancy_memberships) = 0
  and (select count(*) from economics_v2.group_occupancy_events) = 0
  and (select count(*) from economics_v2.group_occupancy_operations) = 0
  and (select count(*) from economics_v2.group_meat_snapshots) = 0,
  'foundation scaffolds must not activate occupancy, facts, or compatibility writes'
);

rollback;
