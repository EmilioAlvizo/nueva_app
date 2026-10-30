begin;

-- HUMAN Sandbox execution only; this file is authored evidence, not an observed RED/GREEN.
-- First meaningful probe is a valid owner's actual authenticated five-argument RPC.
-- Current implementation reaches INSERT: the statement observer must expose HUMAN RED.
-- Future contract: ONLY revoke client EXECUTE on the four exact retained signatures.
-- Includes meat, eggs and ornamental purposes; NOT a purpose-selective business guard.
-- No DROP, replacement body, owner change, table redesign or service-role grant intended.
-- Owner/DEFINER internal execution remains distinct from client EXECUTE retirement.
-- General Cycle lifecycle/mutations/deletion cascades are outside this contract.
-- Existing historical Cycle-write fixtures intentionally conflict with retirement.
-- Flutter still calls these wrappers: replacement integration is separate future work.
-- Run sequentially in an isolated sandbox; concurrent traffic invalidates snapshots.
-- ROLLBACK removes setup/observers, but cannot rewind consumed sequence positions.
-- Future backend work requires human-observed RED AND explicit installation consent.
-- Review budget: fixture <=650 plus approximately 15-30 migration lines, total <=800.

create temp table ids as select
  gen_random_uuid() owner_a, gen_random_uuid() owner_b,
  gen_random_uuid() editor_a, gen_random_uuid() viewer_a, gen_random_uuid() outsider,
  gen_random_uuid() farm_a, gen_random_uuid() farm_b, gen_random_uuid() type_a,
  gen_random_uuid() meat_a, gen_random_uuid() eggs_a, gen_random_uuid() ornamental_a,
  gen_random_uuid() group_a, gen_random_uuid() egg_group, gen_random_uuid() animal_a,
  gen_random_uuid() egg_animal, gen_random_uuid() mixture_a,
  gen_random_uuid() entry_op, gen_random_uuid() create_op, gen_random_uuid() delete_op,
  gen_random_uuid() cycle_expense, null::uuid period_id;
create temp table cycle_controls(purpose_code text primary key, purpose_id uuid, cycle_id uuid);
insert into cycle_controls
select 'carne',meat_a,gen_random_uuid() from ids
union all select 'postura',eggs_a,gen_random_uuid() from ids
union all select 'ornamental',ornamental_a,gen_random_uuid() from ids;
create temp table assertions(label text not null);
create temp table results(stage text primary key, result jsonb not null);
create temp table baseline(state jsonb not null);
create temp sequence attempted_dml;
create temp table writers(n integer primary key, signature text, function_name text,
  argument_names text[], definer boolean, language_name text);
insert into writers values
  (1,'public.registrar_gasto_ciclo_v2(uuid,uuid,date,numeric,text)',
    'registrar_gasto_ciclo_v2',array['p_granja_id','p_cycle_id','p_occurred_on','p_amount','p_note'],false,'sql'),
  (2,'public.registrar_gasto_ciclo_v2_con_categoria(uuid,uuid,date,numeric,text,text)',
    'registrar_gasto_ciclo_v2_con_categoria',
    array['p_granja_id','p_cycle_id','p_occurred_on','p_amount','p_category','p_note'],false,'sql'),
  (3,'economics_v2.record_cycle_expense_impl(uuid,uuid,date,numeric,text)',
    'record_cycle_expense_impl',array['p_granja_id','p_cycle_id','p_occurred_on','p_amount','p_note'],true,'sql'),
  (4,'economics_v2.record_cycle_expense_with_category_impl(uuid,uuid,date,numeric,text,text)',
    'record_cycle_expense_with_category_impl',
    array['p_granja_id','p_cycle_id','p_occurred_on','p_amount','p_category','p_note'],true,'plpgsql');

create function pg_temp.check_true(v_ok boolean,v_label text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if v_ok is distinct from true then raise exception '%',v_label; end if;
  insert into pg_temp.assertions values(v_label);
end;
$$;
create function pg_temp.actor(v_actor uuid,v_role text default 'authenticated') returns void
language plpgsql security invoker set search_path='' as $$
begin
  perform set_config('request.jwt.claim.sub',coalesce(v_actor::text,''),true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_actor,'role',v_role)::text,true);
end;
$$;
create temp table watched as
select v_ns.nspname schema_name,v_c.relname table_name from pg_class v_c
join pg_namespace v_ns on v_ns.oid=v_c.relnamespace
where v_c.relkind in ('r','p') and (v_ns.nspname in ('public','economics_v2','group_feed_integrity')
  or (v_ns.nspname='auth' and v_c.relname='users'));
create temp table watched_sequences as
select v_ns.nspname schema_name,v_c.relname sequence_name from pg_class v_c
join pg_namespace v_ns on v_ns.oid=v_c.relnamespace
where v_c.relkind='S' and v_ns.nspname in ('public','economics_v2','group_feed_integrity');
-- Privileged observation only, never a proxy for an authenticated business call.
-- Optional normalization is restricted to two known successful canonical receipts.
create function pg_temp.business_state(v_ops uuid[] default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_table record; v_rows jsonb; v_result jsonb:='{}'; v_filter text;
begin
  for v_table in select * from pg_temp.watched order by schema_name,table_name loop
    v_filter:='';
    if v_table.schema_name='economics_v2' and v_table.table_name='group_occupancy_operations' then
      v_filter:=' where not (r.granja_id=$2 and r.operation_id=any($1))';
    end if;
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),
      ''[]''::jsonb) from %I.%I r%s',v_table.schema_name,v_table.table_name,v_filter)
      into v_rows using v_ops,(select farm_a from pg_temp.ids);
    v_result:=v_result||jsonb_build_object(v_table.schema_name||'.'||v_table.table_name,v_rows);
  end loop;
  for v_table in select * from pg_temp.watched_sequences order by schema_name,sequence_name loop
    execute format('select jsonb_build_object(''last_value'',s.last_value,
      ''log_cnt'',s.log_cnt,''is_called'',s.is_called) from %I.%I s',
      v_table.schema_name,v_table.sequence_name) into v_rows;
    v_result:=v_result||jsonb_build_object(v_table.schema_name||'.'||v_table.sequence_name,v_rows);
  end loop;
  select coalesce(jsonb_agg(to_jsonb(v_p) order by v_p.oid),'[]'::jsonb) into v_rows
  from (select v_proc.oid,v_proc.proowner,v_proc.proacl,v_proc.proconfig,
      pg_get_functiondef(v_proc.oid) definition
    from pg_proc v_proc join pg_namespace v_ns on v_ns.oid=v_proc.pronamespace
    where v_ns.nspname in ('public','economics_v2','group_feed_integrity','auth')
      and v_proc.prokind in ('f','p')) v_p;
  v_result:=v_result||jsonb_build_object('functions',v_rows);
  select coalesce(jsonb_agg(to_jsonb(v_r) order by v_r.oid),'[]'::jsonb) into v_rows
  from (select v_c.oid,v_c.relowner,v_c.relacl,v_c.relrowsecurity,v_c.relforcerowsecurity
    from pg_class v_c join pg_namespace v_ns on v_ns.oid=v_c.relnamespace
    where v_ns.nspname in ('public','economics_v2','group_feed_integrity','auth')) v_r;
  v_result:=v_result||jsonb_build_object('relation_acls',v_rows);
  select coalesce(jsonb_agg(jsonb_build_array(v_ns.oid,v_ns.nspowner,v_ns.nspacl)
    order by v_ns.oid),'[]'::jsonb) into v_rows from pg_namespace v_ns
    where v_ns.nspname in ('public','economics_v2','group_feed_integrity','auth');
  v_result:=v_result||jsonb_build_object('schema_acls',v_rows);
  select coalesce(jsonb_agg(to_jsonb(v_t) order by v_t.oid),'[]'::jsonb) into v_rows
  from (select v_tr.oid,pg_get_triggerdef(v_tr.oid) definition,v_tr.tgenabled
    from pg_trigger v_tr join pg_class v_c on v_c.oid=v_tr.tgrelid
    join pg_namespace v_ns on v_ns.oid=v_c.relnamespace
    where v_ns.nspname in ('public','economics_v2','group_feed_integrity','auth')) v_t;
  v_result:=v_result||jsonb_build_object('triggers',v_rows);
  select coalesce(jsonb_agg(to_jsonb(v_p) order by v_p.oid),'[]'::jsonb) into v_rows
  from (select v_pol.* from pg_policy v_pol join pg_class v_c on v_c.oid=v_pol.polrelid
    join pg_namespace v_ns on v_ns.oid=v_c.relnamespace
    where v_ns.nspname in ('public','economics_v2','group_feed_integrity','auth')) v_p;
  return v_result||jsonb_build_object('policies',v_rows);
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select v_actor,'authenticated','authenticated','{"fixture":"cycle-expense-writer-retirement"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a,outsider]) v_actor;
insert into public.perfiles(id,nombre)
select v_actor,'Cycle writer retirement actor' from ids
cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a,outsider]) v_actor
on conflict(id) do nothing;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Cycle writer retirement A',owner_a from ids
union all select farm_b,owner_b,'Cycle writer retirement B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,owner_a,'owner'::public.rol_miembro from ids
union all select farm_b,owner_b,'owner'::public.rol_miembro from ids
union all select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids
on conflict(granja_id,user_id) do update set rol=excluded.rol;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Retirement bird',owner_a from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select v_c.purpose_id,v_i.farm_a,'Retirement '||v_c.purpose_code,v_c.purpose_code,v_i.owner_a
from cycle_controls v_c cross join ids v_i;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select v_group,farm_a,type_a,'Retirement Group '||v_group::text,owner_a
from ids cross join lateral unnest(array[group_a,egg_group]) v_group;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,owner_a from ids
union all select egg_animal,farm_a,type_a,egg_group,eggs_a,current_date-20,10,owner_a from ids;
insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
select mixture_a,farm_a,egg_group,current_date-10,owner_a from ids;
insert into economics_v2.cycles(id,granja_id,proposito_id,name,starts_on,ends_on,
  production_closed_on,settled_on,status,created_by)
select v_c.cycle_id,v_i.farm_a,v_c.purpose_id,'Retirement '||v_c.purpose_code,
  current_date-10,null,null,null,'open',v_i.owner_a from cycle_controls v_c cross join ids v_i;
-- ADMIN SETUP ONLY: historical Cycle row for preserved reader evidence, not writer proof.
insert into economics_v2.cycle_expenses(id,cycle_id,granja_id,occurred_on,amount,category,note,created_by)
select v_i.cycle_expense,v_c.cycle_id,v_i.farm_a,current_date-1,7,'Historical','Retained',v_i.owner_a
from ids v_i join cycle_controls v_c on v_c.purpose_code='carne';
do $setup$
declare v_ids record; v_cycle record; v_access economics_v2.cycles; v_period uuid;
begin
  select * into v_ids from pg_temp.ids;
  perform pg_temp.actor(v_ids.owner_a);
  -- Private occupancy admission is SETUP only; no direct Group expense DML.
  v_period:=(economics_v2.enter_group_meat_initial(v_ids.farm_a,v_ids.entry_op,
    v_ids.animal_a,current_date-4,v_ids.group_a,v_ids.meat_a,'{}')->>'destination_period_id')::uuid;
  update pg_temp.ids set period_id=v_period;
  perform pg_temp.check_true(v_period is not null,'Foundation admitted a meat Group period');
  for v_cycle in select * from pg_temp.cycle_controls loop
    v_access:=economics_v2.assert_cycle_access_impl(v_ids.farm_a,v_cycle.cycle_id,true);
    perform pg_temp.check_true(v_access.id=v_cycle.cycle_id and v_access.status='open'
      and v_access.starts_on<=current_date-1 and v_access.ends_on is null
      and v_access.production_closed_on is null and v_access.settled_on is null,
      'Owner/flag/window/state preflight: '||v_cycle.purpose_code);
    perform pg_temp.actor(v_ids.editor_a);
    perform economics_v2.assert_cycle_access_impl(v_ids.farm_a,v_cycle.cycle_id,true);
    perform pg_temp.actor(v_ids.owner_a);
  end loop;
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$setup$;
set constraints all immediate;
grant select on ids,cycle_controls,writers to authenticated,anon;

create function pg_temp.observe_dml() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if current_setting('cycle_writer_retirement.armed',true)='on' then
    perform nextval('pg_temp.attempted_dml'::regclass);
    raise exception using errcode='P0001',
      message='HUMAN RED: retired Cycle expense writer still reaches persistent DML',
      detail=tg_table_schema||'.'||tg_table_name||' '||tg_op;
  end if;
  return null;
end;
$$;
create function pg_temp.attempt_count() returns bigint
language sql security definer set search_path='' as $$
  select case when is_called then last_value else 0 end from pg_temp.attempted_dml;
$$;
do $observers$
declare v_table record;
begin
  for v_table in select * from pg_temp.watched loop
    execute format('create trigger cycle_writer_retirement_observer
      before insert or update or delete or truncate on %I.%I
      for each statement execute function pg_temp.observe_dml()',v_table.schema_name,v_table.table_name);
  end loop;
end;
$observers$;
insert into baseline select pg_temp.business_state();
-- INVOKER dispatch keeps private entrypoints subject to the actual SQL client ACL.
create function pg_temp.call_writer(v_n integer,v_farm uuid,v_cycle uuid) returns uuid
language plpgsql security invoker set search_path='' as $$
begin
  case v_n
    when 1 then return public.registrar_gasto_ciclo_v2(p_granja_id=>v_farm,p_cycle_id=>v_cycle,
      p_occurred_on=>current_date-1,p_amount=>11::numeric,p_note=>'Retirement probe');
    when 2 then return public.registrar_gasto_ciclo_v2_con_categoria(p_granja_id=>v_farm,p_cycle_id=>v_cycle,
      p_occurred_on=>current_date-1,p_amount=>11::numeric,p_category=>'Probe',p_note=>'Retirement probe');
    when 3 then return economics_v2.record_cycle_expense_impl(p_granja_id=>v_farm,p_cycle_id=>v_cycle,
      p_occurred_on=>current_date-1,p_amount=>11::numeric,p_note=>'Retirement probe');
    when 4 then return economics_v2.record_cycle_expense_with_category_impl(p_granja_id=>v_farm,p_cycle_id=>v_cycle,
      p_occurred_on=>current_date-1,p_amount=>11::numeric,p_category=>'Probe',p_note=>'Retirement probe');
    else raise exception 'Unknown writer %',v_n;
  end case;
end;
$$;
create function pg_temp.expect_denied(v_n integer,v_farm uuid,v_cycle uuid,v_label text) returns void
language plpgsql security invoker set search_path='' as $$
declare v_before jsonb:=pg_temp.business_state(); v_attempts bigint:=pg_temp.attempt_count();
  v_refused boolean:=false; v_state text; v_message text; v_name text; v_expected text;
begin
  select function_name into strict v_name from pg_temp.writers where n=v_n;
  v_expected:='permission denied for function '||v_name;
  -- Source grants economics_v2 USAGE only to authenticated, not anon. Do not widen it
  -- to manufacture a function-level anon error: a fresh lookup hits the schema boundary.
  -- A previously resolved statement may instead reach the exact function ACL check.
  -- Explicit function ACL checks below independently cover anon on all four writers.
  if current_user='anon' and v_n in (3,4) then
    v_expected:='permission denied for schema economics_v2';
  end if;
  perform pg_temp.check_true(current_user in ('authenticated','anon'),'Actual client role: '||v_label);
  perform set_config('cycle_writer_retirement.armed','on',true);
  begin
    perform pg_temp.call_writer(v_n,v_farm,v_cycle);
  exception when others then
    get stacked diagnostics v_state=returned_sqlstate,v_message=message_text;
    -- Bare RAISE retains unexpected original SQLSTATE/message/DETAIL/context, including HUMAN RED.
    if v_state is distinct from '42501' or (v_message is distinct from v_expected
      and not (current_user='anon' and v_n in (3,4)
        and v_message='permission denied for function '||v_name)) then raise; end if;
    v_refused:=true;
  end;
  perform set_config('cycle_writer_retirement.armed','off',true);
  if pg_temp.attempt_count()<>v_attempts then
    raise exception using errcode='P0001',message='HUMAN RED: writer swallowed a persistent DML attempt';
  end if;
  perform pg_temp.check_true(v_refused,'Client ACL denial: '||v_label||' '||v_name);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,
    'Denial preserves full business/sequence/function/ACL/trigger/policy state: '||v_label||' '||v_name);
end;
$$;

do $retirement_matrix$
declare v_ids record; v_cycle record; v_actor uuid; v_n integer; v_meat uuid;
begin
  select * into v_ids from pg_temp.ids;
  select cycle_id into strict v_meat from pg_temp.cycle_controls where purpose_code='carne';
  perform pg_temp.actor(v_ids.owner_a);
  set local role authenticated;
  -- FIRST mutation probe: not a catalog assertion, missing stub or business-error RED.
  perform pg_temp.expect_denied(1,v_ids.farm_a,v_meat,'owner carne FIRST');
  reset role;
  foreach v_actor in array array[v_ids.owner_a,v_ids.editor_a] loop
    perform pg_temp.actor(v_actor);
    for v_cycle in select * from pg_temp.cycle_controls order by purpose_code loop
      for v_n in 1..4 loop
        if v_actor=v_ids.owner_a and v_cycle.purpose_code='carne' and v_n=1 then continue; end if;
        set local role authenticated;
        perform pg_temp.expect_denied(v_n,v_ids.farm_a,v_cycle.cycle_id,
          v_actor::text||' '||v_cycle.purpose_code);
        reset role;
      end loop;
    end loop;
  end loop;
  foreach v_actor in array array[v_ids.viewer_a,v_ids.outsider,v_ids.owner_b,null::uuid] loop
    perform pg_temp.actor(v_actor);
    for v_n in 1..4 loop
      set local role authenticated;
      perform pg_temp.expect_denied(v_n,v_ids.farm_a,v_meat,coalesce(v_actor::text,'no JWT subject'));
      reset role;
    end loop;
  end loop;
  perform pg_temp.actor(null,'anon');
  for v_n in 1..4 loop
    set local role anon;
    perform pg_temp.expect_denied(v_n,v_ids.farm_a,v_meat,'anon');
    reset role;
  end loop;
  perform pg_temp.actor(v_ids.owner_a);
  for v_n in 1..4 loop
    set local role authenticated;
    perform pg_temp.expect_denied(v_n,v_ids.farm_b,v_meat,'foreign farm pairing');
    reset role;
  end loop;
  perform pg_temp.check_true(pg_temp.attempt_count()=0,'All 48 actual writer calls denied before persistent DML');
end;
$retirement_matrix$;

do $catalog_contract$
declare v_writer record; v_proc record;
begin
  for v_writer in select * from pg_temp.writers order by n loop
    select v_p.*,v_l.lanname into strict v_proc from pg_proc v_p
    join pg_language v_l on v_l.oid=v_p.prolang where v_p.oid=v_writer.signature::regprocedure;
    perform pg_temp.check_true(v_proc.prorettype='uuid'::regtype and v_proc.pronargdefaults=0
      and v_proc.proargnames=v_writer.argument_names and v_proc.prosecdef=v_writer.definer
      and v_proc.lanname=v_writer.language_name and v_proc.proconfig @> array['search_path=""'],
      'Retained exact signature/names/security/language/defaults/search path: '||v_writer.signature);
    perform pg_temp.check_true(not has_function_privilege('authenticated',v_proc.oid,'EXECUTE')
      and not has_function_privilege('anon',v_proc.oid,'EXECUTE')
      and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) v_acl
        where v_acl.grantee=0 and v_acl.privilege_type='EXECUTE'),
      'No authenticated/anon/effective PUBLIC execution: '||v_writer.signature);
    -- Inventory actual remaining grants, including service_role if present; invent none.
    insert into pg_temp.results values('acl_'||v_writer.n,jsonb_build_object(
      'signature',v_writer.signature,'owner',pg_get_userbyid(v_proc.proowner),'acl',v_proc.proacl));
  end loop;
  perform pg_temp.check_true(pg_temp.business_state()=(select state from pg_temp.baseline),
    'Negative matrix changes no rows, sequences, retained bodies/owners/config/ACLs or out-of-scope definitions');
end;
$catalog_contract$;
-- This post-install fixture compares catalogs across probes, NOT across migration install.
-- Human implementation review must separately compare pre/post-install bodies/owners/ACLs
-- and ensure the only changes are the four authorized client EXECUTE withdrawals.

do $preserved_readers$
declare v_ids record; v_meat uuid; v_expected jsonb; v_public jsonb; v_private jsonb;
begin
  select * into v_ids from pg_temp.ids;
  select cycle_id into strict v_meat from pg_temp.cycle_controls where purpose_code='carne';
  v_expected:=jsonb_build_array(jsonb_build_object('expense_id',v_ids.cycle_expense,
    'occurred_on',current_date-1,'amount',7,'category','Historical','note','Retained'));
  perform pg_temp.actor(v_ids.owner_a);
  perform set_config('cycle_writer_retirement.armed','on',true);
  set local role authenticated;
  v_public:=public.listar_gastos_ciclo_v2(p_granja_id=>v_ids.farm_a,p_cycle_id=>v_meat);
  v_private:=economics_v2.read_cycle_expenses_impl(p_granja_id=>v_ids.farm_a,p_cycle_id=>v_meat);
  reset role;
  perform set_config('cycle_writer_retirement.armed','off',true);
  perform pg_temp.check_true(v_public=v_expected and v_private=v_expected,
    'Public/private Cycle readers retain historical expense projection and client execution');
  perform pg_temp.check_true(pg_temp.attempt_count()=0
    and pg_temp.business_state()=(select state from pg_temp.baseline),
    'Preserved readers cause no attempted DML or full-state change');
end;
$preserved_readers$;

do $compatibility_smoke$
declare v_ids record; v_created jsonb; v_deleted jsonb; v_payload jsonb; v_expense uuid;
  v_legacy jsonb; v_legacy_id uuid; v_legacy_deleted uuid; v_receipt record;
begin
  select * into v_ids from pg_temp.ids;
  perform pg_temp.actor(v_ids.owner_a);
  set local role authenticated;
  v_created:=public.create_group_finance_expense_v1(p_granja_id=>v_ids.farm_a,
    p_operation_id=>v_ids.create_op,p_period_id=>v_ids.period_id,p_occurred_on=>current_date-1,
    p_amount=>13,p_category=>'Smoke',p_note=>'Canonical retained');
  v_expense:=(v_created->>'expense_id')::uuid;
  perform pg_temp.check_true(v_expense is not null and v_created=jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_id',v_ids.create_op,
    'expense_id',v_expense,'period_id',v_ids.period_id,'updated_at',v_created->'updated_at','replayed',false)
    and isfinite((v_created->>'updated_at')::timestamptz),'Canonical CREATE returns actual server identity/version');
  v_payload:=public.list_group_finance_expenses_v1(p_granja_id=>v_ids.farm_a);
  perform pg_temp.check_true(exists(select 1 from jsonb_array_elements(v_payload->'expenses') v_item
    where v_item->>'expense_id'=v_expense::text and v_item->>'target_id'=v_ids.period_id::text
      and (v_item->>'amount')::numeric=13 and v_item->'updated_at'=v_created->'updated_at'),
    'Canonical READ contains newly created Group expense and server token');
  v_deleted:=public.delete_group_finance_expense_v1(p_granja_id=>v_ids.farm_a,
    p_operation_id=>v_ids.delete_op,p_expense_id=>v_expense,p_period_id=>v_ids.period_id,
    p_expected_updated_at=>(v_created->>'updated_at')::timestamptz);
  perform pg_temp.check_true(v_deleted=jsonb_build_object('contract_version','group-economics.forward.v3',
    'operation_id',v_ids.delete_op,'expense_id',v_expense,'period_id',v_ids.period_id,
    'deleted',true,'replayed',false),'Canonical DELETE consumes returned CREATE token');
  v_payload:=public.list_group_finance_expenses_v1(p_granja_id=>v_ids.farm_a);
  perform pg_temp.check_true(not exists(select 1 from jsonb_array_elements(v_payload->'expenses') v_item
    where v_item->>'expense_id'=v_expense::text),'Canonical READ confirms deletion');
  reset role;
  insert into pg_temp.results values('canonical_create',v_created),('canonical_delete',v_deleted);
  -- Real editor public legacy_mixture CREATE/SELECT/DELETE on an egg Group's current mixture.
  perform pg_temp.actor(v_ids.editor_a);
  set local role authenticated;
  v_legacy:=public.create_finance_expense(p_granja_id=>v_ids.farm_a,p_target_kind=>'legacy_mixture',
    p_target_id=>v_ids.mixture_a,p_occurred_on=>current_date-1,p_amount=>17,
    p_category=>' Legacy smoke ',p_note=>null);
  v_legacy_id:=(v_legacy->>'expense_id')::uuid;
  perform pg_temp.check_true(v_legacy_id is not null and isfinite((v_legacy->>'updated_at')::timestamptz)
    and exists(select 1 from public.legacy_mixture_expenses v_e where v_e.id=v_legacy_id
      and v_e.mixture_id=v_ids.mixture_a and v_e.amount=17 and v_e.category='Legacy smoke'
      and v_e.created_by=v_ids.editor_a and v_e.updated_at=(v_legacy->>'updated_at')::timestamptz),
    'Legacy egg mixture CREATE and authenticated SELECT remain available');
  v_legacy_deleted:=public.delete_finance_expense(p_granja_id=>v_ids.farm_a,p_expense_id=>v_legacy_id,
    p_target_kind=>'legacy_mixture',p_target_id=>v_ids.mixture_a,
    p_expected_updated_at=>(v_legacy->>'updated_at')::timestamptz);
  perform pg_temp.check_true(v_legacy_deleted=v_legacy_id
    and not exists(select 1 from public.legacy_mixture_expenses where id=v_legacy_id),
    'Legacy mixture DELETE consumes its server token and removes the created expense');
  reset role;
  insert into pg_temp.results values('legacy_create',v_legacy),('legacy_delete',to_jsonb(v_legacy_deleted));
  for v_receipt in select * from pg_temp.results where stage in ('canonical_create','canonical_delete') loop
    perform pg_temp.check_true((select v_op.result=v_receipt.result and v_op.event_position is null
      and coalesce(btrim(v_op.payload_hash),'')<>'' from economics_v2.group_occupancy_operations v_op
      where v_op.granja_id=v_ids.farm_a
        and v_op.operation_id=(v_receipt.result->>'operation_id')::uuid),
      'Exact known canonical completion retained: '||v_receipt.stage);
  end loop;
  perform pg_temp.check_true((select count(*)=2 from economics_v2.group_occupancy_operations v_op
    where v_op.granja_id=v_ids.farm_a and v_op.operation_id=any(array[v_ids.create_op,v_ids.delete_op]))
    and pg_temp.business_state(array[v_ids.create_op,v_ids.delete_op])=(select state from pg_temp.baseline),
    'Smoke chains net zero expense facts; only two exact farm-A canonical completions excluded');
  perform pg_temp.check_true(pg_temp.attempt_count()=0,'No forbidden writer/reader DML attempts');
end;
$compatibility_smoke$;

select 'group_economics_forward_cycle_expense_writer_retirement_pass' evidence,
  (select count(*) from assertions) assertion_count,
  jsonb_build_object('scope',to_jsonb(ids),
    'cycles',(select jsonb_agg(to_jsonb(v_c) order by purpose_code) from cycle_controls v_c),
    'returned_ids_receipts_and_acl_inventory',(select jsonb_object_agg(stage,result) from results)) fixture_ids,
  true cycle_expense_writer_client_execution_retired,
  true cycle_expense_writer_nonmeat_execution_retired,
  true cycle_expense_readers_smoke_proven,
  true legacy_mixture_compatibility_smoke_proven,
  true canonical_group_expense_smoke_proven,
  false all_legacy_mutation_paths_guarded, false legacy_expense_guards_integrated,
  false canonical_api_integrated, false http, false production, false realclosure,
  'pending' independent_review, 'sequential_only' locking,
  'Owner/internal execution and general Cycle lifecycle are not retired' scope_limit
from ids;

rollback;
