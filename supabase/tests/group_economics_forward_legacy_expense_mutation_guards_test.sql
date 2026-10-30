begin;

-- HUMAN Sandbox only: run the complete file, sequentially, after reviewing it.
-- Fixture first: no backend change is authorized until a human observes real RED.
-- First mutation probe: authenticated owner, public CREATE, fully valid meat Cycle.
-- Current source attempts INSERT economics_v2.cycle_expenses: observer raises P0001
-- with the attempted table/operation. Unexpected SQLSTATE/message/detail escape intact.
-- Proposed contract: actor authorization FIRST, then NULL-safe legacy_mixture only
-- in the three private finance mutators; public wrappers and existing ACLs stay intact.
-- Out of scope: legacy READ Cycle projection, record_cycle_expense helper paths,
-- canonical APIs, Flutter, HTTP, genuine closure and concurrency/locking guarantees.
-- Historical finance_expenses_vertical_slice_test.sql expects Cycle CRUD and will
-- conflict with this planned contract; it is intentionally not changed here.
-- Budget: fixture <=500 + full retained definitions 206 + guard/DDL reserve 54 <=760.
-- Snapshots cover entire business tables, ACLs and explicit sequence state, not just
-- fixture rows. Use an isolated sandbox: unrelated traffic invalidates this evidence.
-- ROLLBACK removes setup/observers, but cannot rewind consumed sequence positions.

create temp table ids as select
  gen_random_uuid() owner_a, gen_random_uuid() owner_b,
  gen_random_uuid() editor_a, gen_random_uuid() viewer_a, gen_random_uuid() outsider,
  gen_random_uuid() farm_a, gen_random_uuid() farm_b, gen_random_uuid() type_a,
  gen_random_uuid() meat_a, gen_random_uuid() eggs_a, gen_random_uuid() egg_animal,
  gen_random_uuid() group_a, gen_random_uuid() group_sibling,
  gen_random_uuid() mixture_a, gen_random_uuid() mixture_sibling,
  gen_random_uuid() cycle_a, gen_random_uuid() cycle_expense,
  gen_random_uuid() legacy_expense;
create temp table assertions(label text not null);
create temp sequence attempted_dml;
create function pg_temp.check_true(p_ok boolean, p_label text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%', p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
create temp table watched as
select n.nspname schema_name, c.relname table_name
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where c.relkind in ('r','p') and (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users'));
create temp table watched_sequences as
select n.nspname schema_name, c.relname sequence_name
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity');
create function pg_temp.business_state() returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_table record; v_rows jsonb; v_result jsonb := '{}';
begin
  for v_table in select * from pg_temp.watched order by schema_name,table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),
      ''[]''::jsonb) from %I.%I r',v_table.schema_name,v_table.table_name) into v_rows;
    v_result := v_result || jsonb_build_object(v_table.schema_name||'.'||v_table.table_name,v_rows);
  end loop;
  for v_table in select * from pg_temp.watched_sequences order by schema_name,sequence_name loop
    execute format('select jsonb_build_object(''last_value'',s.last_value,
      ''log_cnt'',s.log_cnt,''is_called'',s.is_called) from %I.%I s',
      v_table.schema_name,v_table.sequence_name) into v_rows;
    v_result := v_result || jsonb_build_object(v_table.schema_name||'.'||v_table.sequence_name,v_rows);
  end loop;
  select coalesce(jsonb_agg(jsonb_build_array(p.oid,p.proacl,p.proowner,p.prosecdef,p.proconfig)
    order by p.oid),'[]') into v_rows from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','economics_v2');
  v_result := v_result || jsonb_build_object('function_acls',v_rows);
  select coalesce(jsonb_agg(jsonb_build_array(c.oid,c.relacl,c.relowner,c.relrowsecurity)
    order by c.oid),'[]') into v_rows from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','economics_v2','group_feed_integrity');
  return v_result || jsonb_build_object('relation_acls',v_rows);
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select v_actor,'authenticated','authenticated',
  '{"fixture":"forward-legacy-expense-mutation-guards"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a,outsider]) v_actor;
insert into public.perfiles(id,nombre)
select v_actor,'Expense guard actor' from ids
cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a,outsider]) v_actor
on conflict(id) do nothing;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Expense guard farm A',owner_a from ids
union all select farm_b,owner_b,'Expense guard farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,owner_a,'owner'::public.rol_miembro from ids
union all select farm_b,owner_b,'owner'::public.rol_miembro from ids
union all select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids
on conflict(granja_id,user_id) do update set rol=excluded.rol;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Expense guard bird',owner_a from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Expense guard meat','carne',owner_a from ids
union all select eggs_a,farm_a,'Expense guard eggs','postura',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select v_group,farm_a,type_a,'Expense guard Group '||v_group::text,owner_a
from ids cross join lateral unnest(array[group_a,group_sibling]) v_group;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,created_by)
select egg_animal,farm_a,type_a,group_a,eggs_a,current_date-20,10,owner_a from ids;
insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
select mixture_a,farm_a,group_a,current_date-10,owner_a from ids
union all select mixture_sibling,farm_a,group_sibling,current_date-10,owner_a from ids;
insert into economics_v2.cycles(id,granja_id,proposito_id,name,starts_on,ends_on,status,created_by)
select cycle_a,farm_a,meat_a,'Expense guard valid meat Cycle',
  current_date-10,null,'open',owner_a from ids;
-- ADMIN SETUP ONLY: valid row IDs/tokens for forbidden UPDATE/DELETE, not RPC evidence.
insert into economics_v2.cycle_expenses(id,cycle_id,granja_id,occurred_on,amount,category,created_by)
select cycle_expense,cycle_a,farm_a,current_date-1,7,'Seed Cycle',owner_a from ids;
insert into public.legacy_mixture_expenses(id,mixture_id,granja_id,occurred_on,amount,category,created_by)
select legacy_expense,mixture_a,farm_a,current_date-1,8,'Seed legacy',owner_a from ids;
set constraints all immediate;
create temp table baseline as select pg_temp.business_state() state;
do $temp_access$
begin
  execute format('grant usage on schema %I to authenticated',pg_my_temp_schema()::regnamespace::text);
end;
$temp_access$;
grant select on pg_temp.ids to authenticated;

-- The nontransactional counter detects attempts even if application code swallows
-- an observer exception inside a subtransaction. Never observe the temp counter itself.
create function pg_temp.guard_dml() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if current_setting('expense_guard.armed',true)='on' then
    perform nextval('pg_temp.attempted_dml'::regclass);
    raise exception using errcode='P0001',
      message='HUMAN RED: legacy finance attempted forbidden DML before discriminator refusal',
      detail=tg_table_schema||'.'||tg_table_name||' '||tg_op;
  end if;
  return null;
end;
$$;
do $observers$
declare v_table record;
begin
  for v_table in select * from pg_temp.watched loop
    execute format('create trigger expense_mutation_guard_observer
      before insert or update or delete or truncate on %I.%I
      for each statement execute function pg_temp.guard_dml()',v_table.schema_name,v_table.table_name);
  end loop;
end;
$observers$;
create function pg_temp.attempt_count() returns bigint
language sql security definer set search_path='' as $$
  select case when is_called then last_value else 0 end from pg_temp.attempted_dml;
$$;
-- INVOKER dispatch: the actual authenticated role calls public and private endpoints.
-- DELETE really returns UUID; only the test dispatch wraps that UUID as JSON.
create function pg_temp.mutate(p_private boolean,p_operation text,p_farm uuid,p_kind text,
  p_target uuid,p_expense uuid,p_version timestamptz,p_note text default ' note ')
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_schema text := case when p_private then 'economics_v2' else 'public' end;
  v_suffix text := case when p_private then '_impl' else '' end; v_result jsonb;
begin
  if p_operation='create' then
    execute format('select %I.create_finance_expense%s(p_granja_id=>$1,p_target_kind=>$2,
      p_target_id=>$3,p_occurred_on=>$4,p_amount=>$5,p_category=>$6,p_note=>$7)',v_schema,v_suffix)
      into v_result using p_farm,p_kind,p_target,current_date-1,11::numeric,' Category ',p_note;
  elsif p_operation='update' then
    execute format('select %I.update_finance_expense%s(p_granja_id=>$1,p_expense_id=>$2,
      p_target_kind=>$3,p_target_id=>$4,p_expected_updated_at=>$5,p_occurred_on=>$6,
      p_amount=>$7,p_category=>$8,p_note=>$9)',v_schema,v_suffix)
      into v_result using p_farm,p_expense,p_kind,p_target,p_version,current_date-2,
        12::numeric,' Updated ',p_note;
  elsif p_operation='delete' then
    execute format('select to_jsonb(%I.delete_finance_expense%s(p_granja_id=>$1,p_expense_id=>$2,
      p_target_kind=>$3,p_target_id=>$4,p_expected_updated_at=>$5))',v_schema,v_suffix)
      into v_result using p_farm,p_expense,p_kind,p_target,p_version;
  else
    raise exception 'Unknown fixture operation: %',p_operation;
  end if;
  return v_result;
end;
$$;
create function pg_temp.expect_refusal(p_private boolean,p_operation text,p_farm uuid,p_kind text,
  p_target uuid,p_expense uuid,p_version timestamptz,p_state text,p_message text)
returns void language plpgsql security invoker set search_path='' as $$
declare v_before jsonb := pg_temp.business_state(); v_attempts bigint := pg_temp.attempt_count();
  v_refused boolean := false; v_state text; v_message text; v_detail text;
begin
  perform set_config('expense_guard.armed','on',true);
  begin
    perform pg_temp.mutate(p_private,p_operation,p_farm,p_kind,p_target,p_expense,p_version);
  exception when others then
    get stacked diagnostics v_state=returned_sqlstate,v_message=message_text,v_detail=pg_exception_detail;
    -- RAISE preserves original SQLSTATE, DETAIL, message and context for genuine RED.
    if v_state is distinct from p_state or v_message is distinct from p_message then raise; end if;
    v_refused := true;
  end;
  perform set_config('expense_guard.armed','off',true);
  if pg_temp.attempt_count()<>v_attempts then
    raise exception using errcode='P0001',message='HUMAN RED: swallowed forbidden DML attempt',
      detail=format('Observed state=%s message=%s detail=%s',v_state,v_message,v_detail);
  end if;
  perform pg_temp.check_true(v_refused,format('Expected refusal %s %s private=%s kind=%s',
    p_state,p_operation,p_private,coalesce(p_kind,'NULL')));
  perform pg_temp.check_true(pg_temp.business_state()=v_before,
    'Refusal preserves all business rows, Cycle timestamps, Group facts/ledger, ACLs and sequences');
end;
$$;

do $negative_matrix$
declare v_ids record; v_private boolean; v_kind text; v_operation text; v_actor uuid;
  v_target uuid; v_expense uuid; v_version timestamptz; v_cycle_version timestamptz; v_legacy_version timestamptz;
begin
  select * into v_ids from pg_temp.ids;
  select updated_at into v_cycle_version from economics_v2.cycle_expenses where id=v_ids.cycle_expense;
  select updated_at into v_legacy_version from public.legacy_mixture_expenses where id=v_ids.legacy_expense;
  perform set_config('request.jwt.claim.sub',v_ids.owner_a::text,true);
  -- Preflight checks are read/lock only: valid meat purpose, flag, dates, actor and IDs.
  perform economics_v2.assert_finance_expense_actor_impl(v_ids.farm_a,true);
  perform economics_v2.validate_finance_expense_target_impl(v_ids.farm_a,'cycle',v_ids.cycle_a,current_date-1);
  perform economics_v2.validate_finance_expense_target_impl(v_ids.farm_a,'legacy_mixture',v_ids.mixture_a,current_date-1);
  set local role authenticated;
  -- FIRST meaningful probe: no missing-function assertion or synthetic validation fault.
  perform pg_temp.expect_refusal(false,'create',v_ids.farm_a,'cycle',v_ids.cycle_a,
    v_ids.cycle_expense,v_cycle_version,'22023','Unsupported finance expense target');
  reset role;
  foreach v_private in array array[false,true] loop
    foreach v_kind in array array['cycle','group_period',null::text] loop
      v_target := case when v_kind='cycle' then v_ids.cycle_a else v_ids.mixture_a end;
      v_expense := case when v_kind='cycle' then v_ids.cycle_expense else v_ids.legacy_expense end;
      v_version := case when v_kind='cycle' then v_cycle_version else v_legacy_version end;
      foreach v_operation in array array['create','update','delete'] loop
        set local role authenticated;
        perform pg_temp.expect_refusal(v_private,v_operation,v_ids.farm_a,v_kind,v_target,
          v_expense,v_version,'22023','Unsupported finance expense target');
        reset role;
      end loop;
    end loop;
    foreach v_actor in array array[v_ids.viewer_a,v_ids.owner_b,v_ids.outsider,null::uuid] loop
      perform set_config('request.jwt.claim.sub',coalesce(v_actor::text,''),true);
      foreach v_kind in array array['cycle','group_period',null::text,'legacy_mixture'] loop
        foreach v_operation in array array['create','update','delete'] loop
          set local role authenticated;
          perform pg_temp.expect_refusal(v_private,v_operation,v_ids.farm_a,v_kind,v_ids.mixture_a,
            v_ids.legacy_expense,v_legacy_version,'42501',case when v_actor is null
              then 'Authentication required' else 'Finance expense access denied' end);
          reset role;
        end loop;
      end loop;
    end loop;
    perform set_config('request.jwt.claim.sub',v_ids.owner_a::text,true);
    foreach v_operation in array array['create','update','delete'] loop
      set local role authenticated;
      perform pg_temp.expect_refusal(v_private,v_operation,v_ids.farm_b,'legacy_mixture',v_ids.mixture_a,
        v_ids.legacy_expense,v_legacy_version,'42501','Finance expense access denied');
      reset role;
    end loop;
  end loop;
end;
$negative_matrix$;

do $compatibility$
declare v_ids record; v_private boolean; v_actor uuid; v_created jsonb; v_updated jsonb;
  v_deleted jsonb; v_id uuid; v_first timestamptz; v_next timestamptz; v_row record;
begin
  select * into v_ids from pg_temp.ids;
  foreach v_private in array array[false,true] loop
    foreach v_actor in array array[v_ids.owner_a,v_ids.editor_a] loop
      perform set_config('request.jwt.claim.sub',v_actor::text,true);
      set local role authenticated;
      v_created := pg_temp.mutate(v_private,'create',v_ids.farm_a,'legacy_mixture',
        v_ids.mixture_a,null,null);
      v_id := (v_created->>'expense_id')::uuid;
      v_first := (v_created->>'updated_at')::timestamptz;
      perform pg_temp.check_true(v_created=jsonb_build_object('expense_id',v_id,'updated_at',v_first)
        and v_id is not null and v_first is not null,'Legacy CREATE keeps its two-field response, not canonical six');
      -- Authenticated SELECT exercises the existing membership RLS contract.
      select * into v_row from public.legacy_mixture_expenses where id=v_id;
      perform pg_temp.check_true(v_row.id=v_id and v_row.mixture_id=v_ids.mixture_a
        and v_row.granja_id=v_ids.farm_a and v_row.occurred_on=current_date-1
        and v_row.amount=11 and v_row.category='Category' and v_row.note='note'
        and v_row.created_by=v_actor and v_row.updated_at=v_first,
        'Legacy CREATE persists exact trimmed values and authenticated creator');
      v_updated := pg_temp.mutate(v_private,'update',v_ids.farm_a,'legacy_mixture',
        v_ids.mixture_a,v_id,v_first,'   ');
      v_next := (v_updated->>'updated_at')::timestamptz;
      perform pg_temp.check_true(v_updated=jsonb_build_object('expense_id',v_id,'updated_at',v_next)
        and v_next>v_first,'Legacy UPDATE advances using clock_timestamp/one microsecond source contract');
      select * into v_row from public.legacy_mixture_expenses where id=v_id;
      perform pg_temp.check_true(v_row.mixture_id=v_ids.mixture_a and v_row.granja_id=v_ids.farm_a
        and v_row.amount=12 and v_row.occurred_on=current_date-2 and v_row.category='Updated'
        and v_row.note is null and v_row.created_by=v_actor and v_row.updated_at=v_next,
        'Legacy UPDATE preserves target/creator and normalizes blank note to NULL');
      perform pg_temp.expect_refusal(v_private,'update',v_ids.farm_a,'legacy_mixture',
        v_ids.mixture_sibling,v_id,v_next,'42501','Finance expense target is immutable');
      perform pg_temp.expect_refusal(v_private,'delete',v_ids.farm_a,'legacy_mixture',
        v_ids.mixture_sibling,v_id,v_next,'42501','Finance expense target is immutable');
      perform pg_temp.expect_refusal(v_private,'update',v_ids.farm_a,'legacy_mixture',
        v_ids.mixture_a,v_id,v_first,'40001','Finance expense changed since it was opened');
      perform pg_temp.expect_refusal(v_private,'delete',v_ids.farm_a,'legacy_mixture',
        v_ids.mixture_a,v_id,v_first,'40001','Finance expense changed since it was opened');
      v_deleted := pg_temp.mutate(v_private,'delete',v_ids.farm_a,'legacy_mixture',
        v_ids.mixture_a,v_id,v_next);
      perform pg_temp.check_true(v_deleted=to_jsonb(v_id)
        and not exists(select 1 from public.legacy_mixture_expenses where id=v_id),
        'Legacy DELETE returns UUID and removes only its expense');
      -- Explicit NULL note compatibility on a second actual CREATE/DELETE lifecycle.
      v_created := pg_temp.mutate(v_private,'create',v_ids.farm_a,'legacy_mixture',
        v_ids.mixture_a,null,null,null);
      v_id := (v_created->>'expense_id')::uuid;
      perform pg_temp.check_true((select note is null from public.legacy_mixture_expenses where id=v_id),
        'Legacy CREATE preserves NULL note');
      v_deleted := pg_temp.mutate(v_private,'delete',v_ids.farm_a,'legacy_mixture',v_ids.mixture_a,
        v_id,(v_created->>'updated_at')::timestamptz);
      perform pg_temp.check_true(v_deleted=to_jsonb(v_id),'Second DELETE preserves UUID response');
      reset role;
      perform pg_temp.check_true(pg_temp.business_state()=(select state from pg_temp.baseline),
        'Each owner/editor lifecycle nets zero expenses and leaves every sibling/metadata field unchanged');
    end loop;
  end loop;
end;
$compatibility$;

-- Exercise actual table permissions as the real client, not merely catalog flags.
do $direct_dml$
declare v_ids record; v_table text; v_operation text; v_before jsonb; v_attempts bigint;
  v_refused boolean; v_state text; v_message text; v_detail text;
begin
  select * into v_ids from pg_temp.ids;
  perform set_config('request.jwt.claim.sub',v_ids.owner_a::text,true);
  foreach v_table in array array['public.legacy_mixture_expenses','economics_v2.cycle_expenses'] loop
    foreach v_operation in array array['insert','update','delete'] loop
      v_before := pg_temp.business_state();
      v_attempts := pg_temp.attempt_count();
      v_refused := false;
      perform set_config('expense_guard.armed','on',true);
      set local role authenticated;
      begin
        if v_operation='insert' then
          execute format('insert into %s select * from %s where false',v_table,v_table);
        elsif v_operation='update' then
          execute format('update %s set amount=amount where false',v_table);
        else
          execute format('delete from %s where false',v_table);
        end if;
      exception when others then
        get stacked diagnostics v_state=returned_sqlstate,v_message=message_text,v_detail=pg_exception_detail;
        if v_state<>'42501' or v_message not like 'permission denied for table %' then raise; end if;
        v_refused := true;
      end;
      reset role;
      perform set_config('expense_guard.armed','off',true);
      perform pg_temp.check_true(v_refused and pg_temp.attempt_count()=v_attempts,
        'Actual direct DML denied before statement observers: '||v_table||' '||v_operation);
      perform pg_temp.check_true(pg_temp.business_state()=v_before,
        'Actual direct DML denial preserves full business/ACL/sequence state');
    end loop;
  end loop;
end;
$direct_dml$;

do $acl_contract$
declare v_proc record; v_table text; v_operation text;
begin
  for v_proc in select p.*,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='public' and p.proname in
      ('create_finance_expense','update_finance_expense','delete_finance_expense'))
      or (n.nspname='economics_v2' and p.proname in ('create_finance_expense_impl',
        'update_finance_expense_impl','delete_finance_expense_impl',
        'assert_finance_expense_actor_impl','validate_finance_expense_target_impl')) loop
    perform pg_temp.check_true(v_proc.prosecdef=(v_proc.nspname='economics_v2')
      and v_proc.proconfig @> array['search_path=""']
      and has_function_privilege('authenticated',v_proc.oid,'EXECUTE')
      and not has_function_privilege('anon',v_proc.oid,'EXECUTE')
      and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) x
        where x.grantee=0 and x.privilege_type='EXECUTE'),
      'Existing wrappers/private mutators/helpers retain authenticated EXECUTE and empty path');
    if v_proc.proname in ('delete_finance_expense','delete_finance_expense_impl') then
      perform pg_temp.check_true(v_proc.prorettype='uuid'::regtype,'DELETE signature returns UUID');
    end if;
  end loop;
  foreach v_table in array array['public.legacy_mixture_expenses','economics_v2.cycle_expenses'] loop
    foreach v_operation in array array['INSERT','UPDATE','DELETE'] loop
      perform pg_temp.check_true(not has_table_privilege('authenticated',v_table,v_operation),
        'Direct authenticated expense DML remains denied: '||v_table||' '||v_operation);
    end loop;
  end loop;
  perform pg_temp.check_true(has_table_privilege('authenticated','public.legacy_mixture_expenses','SELECT'),
    'Legacy member SELECT remains granted; no helper or service-role ACL redesign');
  perform pg_temp.check_true(pg_temp.business_state()=(select state from pg_temp.baseline),
    'Final full business/ACL/sequence snapshot equals seeded baseline without normalization');
end;
$acl_contract$;

select 'group_economics_forward_legacy_expense_mutation_guards_pass' evidence,
  (select count(*) from assertions) assertion_count, to_jsonb(ids) fixture_ids,
  true legacy_finance_mutation_discriminators_guarded,
  true legacy_mixture_crud_compatibility_proven,
  false legacy_expense_guards_integrated, false all_legacy_mutation_paths_guarded,
  false legacy_finance_read_cycle_projection_removed, false canonical_api_integrated,
  false http, false production, 'pending' independent_review,
  'sequential_only' locking, false realclosure
from ids;

rollback;
