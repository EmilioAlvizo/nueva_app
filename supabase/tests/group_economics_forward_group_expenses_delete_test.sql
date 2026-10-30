begin;

-- HUMAN Sandbox Dashboard only. Authored fixture, NOT runtime RED/GREEN evidence.
-- First genuine public DELETE is uncaught: expect 42883 until implementation exists.
-- Required five named inputs, no date argument; exact six-key completion receipt.
-- Fresh lock contract: farm advisory -> Group -> period -> expense. Sequential only;
-- neither concurrent lock ordering nor real membership-bearing closure is proven here.
-- Budget: fixture <=480, reserve >=300 for the complete guarded migration, total <=800.
-- Setup issues positions; transaction rollback does not rewind sequence values.
create temp table ids as select gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor,gen_random_uuid() viewer,gen_random_uuid() outsider,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,
  gen_random_uuid() type_b,gen_random_uuid() meat_a,gen_random_uuid() meat_b,
  gen_random_uuid() animal_a,gen_random_uuid() group_a,gen_random_uuid() entry_op,
  gen_random_uuid() owner_op,gen_random_uuid() editor_op,gen_random_uuid() fault_op,
  gen_random_uuid() expense_a;
create temp table foundations as select n,gen_random_uuid() group_id,
  gen_random_uuid() period_id,gen_random_uuid() expense_id from generate_series(1,3) n;
-- 1 sibling OPEN without memberships, 2 synthetic CLOSED, 3 foreign OPEN.
create temp table assertions(label text not null);
create temp table results(operation_id uuid primary key,result jsonb not null);
create temp table proof(late_ledger_rollback boolean not null default false);
insert into proof default values;
create temp sequence dml_attempts;
create temp table watched as select n.nspname schema_name,c.relname table_name
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where c.relkind in ('r','p') and (n.nspname in ('public','economics_v2','group_feed_integrity')
    or (n.nspname='auth' and c.relname='users'));
create temp table sequences as select n.nspname schema_name,c.relname sequence_name
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity');
create function pg_temp.check_true(p_ok boolean,p_label text) returns void
language plpgsql security invoker set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception 'Expense DELETE: %',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
-- Trusted read-only snapshot, never a business-call proxy. Only selected deletions and
-- allowed farm/operation receipts are excluded; final assertions also require absence.
create function pg_temp.business_state(p_ops uuid[] default '{}',p_deleted uuid[] default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_table record; v_rows jsonb; v_state jsonb:='{}'; v_filter text;
begin
  for v_table in select * from pg_temp.watched order by schema_name,table_name loop
    v_filter:='';
    if v_table.schema_name='economics_v2' and v_table.table_name='group_period_expenses' then
      v_filter:=' where not (r.id=any($2))';
    elsif v_table.schema_name='economics_v2' and v_table.table_name='group_occupancy_operations' then
      v_filter:=' where not (r.granja_id=$3 and r.operation_id=any($1))';
    end if;
    execute format('select coalesce(jsonb_agg(v order by v::text),''[]''::jsonb)
      from (select to_jsonb(r) v from %I.%I r%s) s',v_table.schema_name,v_table.table_name,v_filter)
      into v_rows using p_ops,p_deleted,(select farm_a from pg_temp.ids);
    v_state:=v_state||jsonb_build_object(v_table.schema_name||'.'||v_table.table_name,v_rows);
  end loop;
  for v_table in select * from pg_temp.sequences loop
    execute format('select jsonb_build_object(''last_value'',s.last_value,''log_cnt'',s.log_cnt,''is_called'',s.is_called)
      from %I.%I s',v_table.schema_name,v_table.sequence_name) into v_rows;
    v_state:=v_state||jsonb_build_object(v_table.schema_name||'.'||v_table.sequence_name,v_rows);
  end loop;
  -- Opaque ACL snapshot only: no DELETE resolution or endpoint privilege preflight.
  -- Missing endpoints therefore still fail at the first genuine invocation below.
  select coalesce(jsonb_agg(a order by a::text),'[]'::jsonb) into v_rows from (
      select jsonb_build_array('relation',c.oid,c.relacl) a from pg_class c
      join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','economics_v2','group_feed_integrity','auth')
      union all select jsonb_build_array('function',p.oid,p.proacl) from pg_proc p
      join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','economics_v2','group_feed_integrity','auth')) acl;
  v_state:=v_state||jsonb_build_object('acl',v_rows);
  return v_state;
end;
$$;
create function pg_temp.api_sql(p_farm uuid,p_op uuid,p_expense uuid,p_period uuid,
  p_version timestamptz,p_impl boolean default false) returns text
language sql security invoker set search_path='' as $$
  select format('select %s(p_granja_id=>%L::uuid,p_operation_id=>%L::uuid,p_expense_id=>%L::uuid,
    p_period_id=>%L::uuid,p_expected_updated_at=>%L::timestamptz)',case when p_impl then
    'economics_v2.delete_group_finance_expense_impl' else 'public.delete_group_finance_expense_v1' end,
    p_farm,p_op,p_expense,p_period,p_version);
$$;
create function pg_temp.observe_dml() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('expense_delete.observe',true)='on'
    or (tg_table_schema='economics_v2' and tg_table_name='group_feed_api_completions') then
    perform nextval('pg_temp.dml_attempts');
    raise exception 'Expense DELETE replay/refusal or food sidecar attempted DML: %.% %',tg_table_schema,tg_table_name,tg_op;
  end if;
  return null;
end;
$$;
create function pg_temp.checked(p_statement text,p_expected_state text default null,
  p_code text default null,p_field text default null,p_entity uuid default null) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_counter jsonb; v_result jsonb; v_sqlstate text; v_detail text;
begin
  v_before:=pg_temp.business_state();
  select jsonb_build_object('last_value',s.last_value,'log_cnt',s.log_cnt,'is_called',s.is_called)
    into v_counter from pg_temp.dml_attempts s;
  perform set_config('expense_delete.observe','on',true);
  begin execute p_statement into v_result;
  exception when others then
    if p_expected_state is null then raise; end if;
    get stacked diagnostics v_sqlstate=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform set_config('expense_delete.observe','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'full business/sequence/ACL state unchanged');
  perform pg_temp.check_true((select jsonb_build_object('last_value',s.last_value,'log_cnt',s.log_cnt,'is_called',s.is_called)=v_counter
    from pg_temp.dml_attempts s),'no attempted DML, including caught or zero-row statements');
  if p_expected_state is null then
    perform pg_temp.check_true(v_result is not null,'nonempty replay/read result');
  else
    perform pg_temp.check_true(v_sqlstate=p_expected_state,'SQLSTATE '||p_expected_state);
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb=jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field,'entity_id',p_entity),'exact4 typed refusal DETAIL');
    end if;
  end if;
  return v_result;
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select actor,'authenticated','authenticated','{"fixture":"group-expenses-delete"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor,viewer,outsider]) actor;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Expense DELETE A',owner_a from ids
union all select farm_b,owner_b,'Expense DELETE B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor,'editor'::public.rol_miembro from ids
union all select farm_a,viewer,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Delete type A',owner_a from ids union all select type_b,farm_b,'Delete type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Delete meat A','carne',owner_a from ids
union all select meat_b,farm_b,'Delete meat B','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_a,farm_a,type_a,'Delete occupied Group',owner_a from ids
union all select group_id,case when n=3 then farm_b else farm_a end,
  case when n=3 then type_b else type_a end,'Delete foundation '||n,
  case when n=3 then owner_b else owner_a end from foundations cross join ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,owner_a from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true),
  set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
-- Actual private admission supplies acquisition metrics; setup is NOT DELETE evidence.
create temp table targets as select i.*,(economics_v2.enter_group_meat_initial(
  farm_a,entry_op,animal_a,current_date-4,group_a,meat_a,'{}')->>'destination_period_id')::uuid period_a from ids i;
do $foundations$
declare v_foundation record; v_ids record; v_position bigint;
begin
  select * into v_ids from ids;
  for v_foundation in select * from foundations order by n loop
    v_position:=nextval('economics_v2.group_economics_event_position_seq');
    insert into economics_v2.group_occupancy_periods(id,granja_id,group_id,purpose_id,starts_on,closed_on,start_position,end_position)
    values(v_foundation.period_id,case when v_foundation.n=3 then v_ids.farm_b else v_ids.farm_a end,v_foundation.group_id,
      case when v_foundation.n=3 then v_ids.meat_b else v_ids.meat_a end,current_date-4,
      case when v_foundation.n=2 then current_date-1 end,v_position,
      case when v_foundation.n=2 then nextval('economics_v2.group_economics_event_position_seq') end);
  end loop;
end;
$foundations$;
-- Direct seeding is setup, not CREATE integration evidence.
insert into economics_v2.group_period_expenses(id,granja_id,period_id,occurred_on,amount,category,note,created_by,created_at,updated_at)
select expense_a,farm_a,period_a,current_date-2,50,'Veterinary',null,owner_a,now()-interval '2 hours',now()-interval '1 hour' from targets
union all select expense_id,case when n=3 then farm_b else farm_a end,period_id,current_date-2,
  10,'Sibling',null,case when n=3 then owner_b else owner_a end,now()-interval '2 hours',now()-interval '1 hour'
  from foundations cross join ids;
set constraints all immediate;
create temp table originals as select e.* from economics_v2.group_period_expenses e
  where e.id in (select expense_a from ids union all select expense_id from foundations);
create temp table baseline as select pg_temp.business_state('{}',array[expense_a,
  (select expense_id from foundations where n=1)]) state from ids;
do $setup_metrics_and_observers$
declare v_table record; v_metrics jsonb;
begin
  select economics_v2.calculate_group_period_live_metrics(farm_a,period_a) into v_metrics from targets;
  perform pg_temp.check_true((v_metrics->>'direct_expense_total')::numeric=50
    and (v_metrics->>'acquisition_cost')::numeric=300 and (v_metrics->>'total_cost')::numeric=350,'initial live expense 50 plus acquisition 300');
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
  for v_table in select * from watched loop
    execute format('create trigger expense_delete_statement_observer before insert or update or delete or truncate
      on %I.%I for each statement execute function pg_temp.observe_dml()',v_table.schema_name,v_table.table_name);
  end loop;
end;
$setup_metrics_and_observers$;
grant select on ids,targets,foundations,originals,results to authenticated,anon;
grant insert on assertions,results to authenticated,anon;
grant select,usage on sequence dml_attempts to authenticated,anon;

do $first_public_call$
declare v_ids record; v_version timestamptz; v_result jsonb;
begin
  select * into v_ids from targets;
  select o.updated_at into strict v_version from originals o where o.id=v_ids.expense_a;
  set local role authenticated;
  v_result:=public.delete_group_finance_expense_v1(p_granja_id=>v_ids.farm_a::uuid,p_operation_id=>v_ids.owner_op::uuid,
    p_expense_id=>v_ids.expense_a::uuid,p_period_id=>v_ids.period_a::uuid,p_expected_updated_at=>v_version::timestamptz);
  perform pg_temp.check_true(current_user='authenticated','FIRST real DELETE under client SQL role, owner and current OPEN version');
  insert into pg_temp.results values(v_ids.owner_op,v_result);
  reset role;
end;
$first_public_call$;

do $metadata_and_first_facts$
declare v_ids record; v_function record; v_result jsonb; v_metrics jsonb;
begin
  select * into v_ids from targets;
  perform pg_temp.check_true((select count(*)=2 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='public' and p.proname='delete_group_finance_expense_v1') or
      (n.nspname='economics_v2' and p.proname='delete_group_finance_expense_impl')),'two functions without overloads');
  for v_function in select q.*,n.nspname from pg_proc q join pg_namespace n on n.oid=q.pronamespace where q.oid in
    ('public.delete_group_finance_expense_v1(uuid,uuid,uuid,uuid,timestamptz)'::regprocedure,
     'economics_v2.delete_group_finance_expense_impl(uuid,uuid,uuid,uuid,timestamptz)'::regprocedure) loop
    perform pg_temp.check_true(v_function.pronargs=5 and v_function.pronargdefaults=0 and v_function.proargmodes is null
      and v_function.proargnames=array['p_granja_id','p_operation_id','p_expense_id','p_period_id','p_expected_updated_at']
      and v_function.prorettype='jsonb'::regtype and not v_function.proretset and v_function.prokind='f' and v_function.provolatile='v'
      and v_function.prosecdef=(v_function.nspname='economics_v2') and v_function.proowner='postgres'::regrole
      and v_function.proconfig @> array['search_path=""'] and has_function_privilege('authenticated',v_function.oid,'execute')
      and not has_function_privilege('anon',v_function.oid,'execute') and not has_function_privilege('service_role',v_function.oid,'execute')
      and not exists(select 1 from aclexplode(coalesce(v_function.proacl,acldefault('f',v_function.proowner))) a
        where a.privilege_type='EXECUTE' and a.grantee not in (v_function.proowner,'authenticated'::regrole)),
      'exact5 required, jsonb VOLATILE, postgres, empty path, authenticated-only INVOKER/guarded DEFINER');
  end loop;
  perform pg_temp.check_true(not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='economics_v2' and c.relname in ('group_period_expenses','group_occupancy_periods','group_occupancy_operations')
      and (not c.relrowsecurity or not c.relforcerowsecurity)),
    'private business tables enable and FORCE RLS');
  perform pg_temp.check_true(not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    cross join (values('authenticated'),('anon')) a(role_name) where n.nspname='economics_v2'
      and c.relname in ('group_period_expenses','group_occupancy_periods','group_occupancy_operations')
      and has_table_privilege(a.role_name,c.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE')),'no direct private table client privileges');
  select r.result into strict v_result from results r where r.operation_id=v_ids.owner_op;
  perform pg_temp.check_true(v_result=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',v_ids.owner_op,
    'expense_id',v_ids.expense_a,'period_id',v_ids.period_a,'deleted',true,'replayed',false)
    and not exists(select 1 from economics_v2.group_period_expenses e where e.id=v_ids.expense_a),'first exact6 receipt and actual deletion');
  v_metrics:=economics_v2.calculate_group_period_live_metrics(v_ids.farm_a,v_ids.period_a);
  perform pg_temp.check_true((v_metrics->>'direct_expense_total')::numeric=0 and (v_metrics->>'total_cost')::numeric=300
    and (v_metrics->>'acquisition_cost')::numeric=300,'live expense 50 -> 0, acquisition stays 300');
end;
$metadata_and_first_facts$;

do $replay_validation_and_refusals$
declare v_ids record; v_probe record; v_original record; v_impl boolean; v_version timestamptz; v_result jsonb;
begin
  select * into v_ids from targets;
  select o.updated_at into v_version from originals o where o.id=v_ids.expense_a;
  select r.result into v_result from results r where r.operation_id=v_ids.owner_op;
  select o.* into strict v_original from originals o join foundations f on f.expense_id=o.id where f.n=1;
  set local role authenticated;
  foreach v_impl in array array[false,true] loop
    perform pg_temp.check_true(pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,v_ids.owner_op,v_ids.expense_a,v_ids.period_a,v_version,v_impl))
      =v_result||'{"replayed":true}'::jsonb,'historical original-token replay after deletion, public/private');
    perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,gen_random_uuid(),v_original.id,v_original.period_id,v_original.updated_at-interval '1 second',v_impl),
      '40001','stale_write','expected_updated_at',v_original.id);
    perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,gen_random_uuid(),v_ids.expense_a,v_ids.period_a,v_version,v_impl),
      '42501','forbidden','expense_id',v_ids.expense_a);
  end loop;
  for v_probe in select * from (values
    (gen_random_uuid(),v_ids.period_a,v_version),(v_ids.expense_a,v_original.period_id,v_version),
    (v_ids.expense_a,v_ids.period_a,v_version+interval '1 microsecond')) x(expense,period,version) loop
    perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,v_ids.owner_op,v_probe.expense,v_probe.period,v_probe.version),
      '22023','operation_payload_conflict','operation_id',v_ids.owner_op);
  end loop;
  perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,v_ids.entry_op,v_original.id,v_original.period_id,v_original.updated_at),
    '22023','operation_payload_conflict','operation_id',v_ids.entry_op); -- Shared occupancy/expense namespace.
  for v_probe in select unnest(array[null::timestamptz,'infinity'::timestamptz,'-infinity'::timestamptz]) version loop
    perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,gen_random_uuid(),v_original.id,v_original.period_id,v_probe.version),
      '22023','invalid_request','expected_updated_at',v_original.id);
  end loop;
  perform pg_temp.checked(pg_temp.api_sql(null,gen_random_uuid(),v_original.id,v_original.period_id,v_original.updated_at),'22023','invalid_request','granja_id',null);
  perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,null,v_original.id,v_original.period_id,v_original.updated_at),'22023','invalid_request','operation_id',null);
  perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,gen_random_uuid(),null,v_original.period_id,v_original.updated_at),'22023','invalid_request','expense_id',null);
  perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,gen_random_uuid(),v_original.id,null,v_original.updated_at),'22023','invalid_request','period_id',null);
  perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,gen_random_uuid(),v_original.id,v_ids.period_a,v_original.updated_at),'42501','forbidden','expense_id',v_original.id);
  for v_probe in select * from pg_temp.foundations where n in (2,3) loop
    if v_probe.n=2 then
      perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,gen_random_uuid(),v_probe.expense_id,v_probe.period_id,v_version),
        '23514','closed_period_immutable','period_id',v_probe.period_id);
    else
      perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,gen_random_uuid(),v_probe.expense_id,v_original.period_id,v_version),'42501','forbidden','expense_id',v_probe.expense_id);
      perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,gen_random_uuid(),v_original.id,v_probe.period_id,v_version),'42501','forbidden','period_id',v_probe.period_id);
    end if;
  end loop;
  perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,gen_random_uuid(),v_original.id,v_ids.fault_op,v_version),'42501','forbidden','period_id',v_ids.fault_op);
  perform pg_temp.checked('select * from economics_v2.group_period_expenses','42501');
  perform pg_temp.checked('delete from economics_v2.group_period_expenses where false','42501');
  perform pg_temp.checked('select economics_v2.assert_group_writer_actor(null::uuid)','42501');
  perform pg_temp.checked('select economics_v2.enter_group_meat_initial(null::uuid,null::uuid,null::uuid,current_date,null::uuid,null::uuid,''{}''::jsonb)','42501');
  reset role;
end;
$replay_validation_and_refusals$;

do $current_authorization$
declare v_ids record; v_actor record; v_original record; v_impl boolean; v_op uuid; v_version timestamptz; v_before jsonb;
begin
  select * into v_ids from targets;
  select o.updated_at into v_version from originals o where o.id=v_ids.expense_a;
  select o.* into strict v_original from originals o join foundations f on f.expense_id=o.id where f.n=1;
  for v_actor in select * from (values(v_ids.viewer,'authenticated'),(v_ids.owner_b,'authenticated'),(v_ids.outsider,'authenticated'),
    (null::uuid,'authenticated'),(v_ids.owner_a,'anon')) x(actor,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(v_actor.actor::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_actor.actor,'role',v_actor.role_name)::text,true);
    execute format('set local role %I',v_actor.role_name);
    foreach v_impl in array array[false,true] loop
      foreach v_op in array array[v_ids.owner_op,gen_random_uuid()] loop
        perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,v_op,
          case when v_op=v_ids.owner_op then v_ids.expense_a else v_original.id end,
          case when v_op=v_ids.owner_op then v_ids.period_a else v_original.period_id end,v_version,v_impl),
          '42501',case when v_actor.role_name='authenticated' then 'forbidden' end,'granja_id',v_ids.farm_a);
      end loop;
    end loop;
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',v_ids.editor::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_ids.editor,'role','authenticated')::text,true);
  set local role authenticated;
  perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,v_ids.owner_op,v_ids.expense_a,v_ids.period_a,v_version),
    '22023','operation_payload_conflict','operation_id',v_ids.owner_op);
  reset role;
  perform set_config('request.jwt.claim.sub',v_ids.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_ids.owner_a,'role','authenticated')::text,true);
  v_before:=pg_temp.business_state();
  begin
    update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=v_ids.farm_a;
    set local role authenticated;
    foreach v_impl in array array[false,true] loop
      foreach v_op in array array[v_ids.owner_op,gen_random_uuid()] loop
        perform pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,v_op,
          case when v_op=v_ids.owner_op then v_ids.expense_a else v_original.id end,
          case when v_op=v_ids.owner_op then v_ids.period_a else v_original.period_id end,v_version,v_impl),'42501','forbidden','granja_id',v_ids.farm_a);
      end loop;
    end loop;
    reset role;
    raise exception using errcode='ZR001',message='Restore entire flag probe';
  exception when sqlstate 'ZR001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'flag OFF probe restores all metadata, not only the boolean');
end;
$current_authorization$;

-- AFTER ledger insertion observes a real DELETE plus the persisted exact receipt.
create temp table fault_original as select o.* from originals o join foundations f on f.expense_id=o.id where f.n=1;
grant select on fault_original to authenticated;
create function pg_temp.fail_late_ledger() returns trigger
language plpgsql security invoker set search_path='' as $$
declare v_ids record; v_original record;
begin
  select * into v_ids from pg_temp.targets;
  if new.operation_id<>v_ids.fault_op then return new; end if;
  select * into strict v_original from pg_temp.fault_original;
  if v_original.granja_id is distinct from v_ids.farm_a or v_original.amount is distinct from 10::numeric
    or v_original.created_by is distinct from v_ids.owner_a or not isfinite(v_original.updated_at)
    or exists(select 1 from economics_v2.group_period_expenses e where e.id=v_original.id)
    or new.granja_id is distinct from v_ids.farm_a or new.event_position is not null
    or coalesce(btrim(new.payload_hash),'')='' or new.result is distinct from jsonb_build_object(
      'contract_version','group-economics.forward.v3','operation_id',v_ids.fault_op,'expense_id',v_original.id,
      'period_id',v_original.period_id,'deleted',true,'replayed',false)
    or not exists(select 1 from economics_v2.group_occupancy_operations o where o.granja_id=v_ids.farm_a
      and o.operation_id=v_ids.fault_op and to_jsonb(o)=to_jsonb(new)) then
    raise exception 'Late ledger observer did not find real deletion and exact persisted receipt';
  end if;
  raise exception using errcode='ZL001',message='Injected late ledger failure',detail='observed_after_real_expense_delete_and_receipt';
end;
$$;
create trigger expense_delete_late_ledger_fault after insert on economics_v2.group_occupancy_operations
  for each row execute function pg_temp.fail_late_ledger();
do $atomic_rollback$
declare v_ids record; v_original record; v_before jsonb; v_sqlstate text; v_detail text;
begin
  select * into v_ids from targets;
  select * into strict v_original from fault_original;
  perform pg_temp.check_true((select to_jsonb(e)=to_jsonb(v_original) from economics_v2.group_period_expenses e
    where e.id=v_original.id),'fault target exists with exact captured original amount/creator/version before DELETE');
  v_before:=pg_temp.business_state();
  set local role authenticated;
  begin
    execute pg_temp.api_sql(v_ids.farm_a,v_ids.fault_op,v_original.id,v_original.period_id,v_original.updated_at);
  exception when others then get stacked diagnostics v_sqlstate=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  reset role;
  perform pg_temp.check_true(v_sqlstate='ZL001' and v_detail='observed_after_real_expense_delete_and_receipt'
    and pg_temp.business_state()=v_before and (select to_jsonb(e)=to_jsonb(v_original)
      from economics_v2.group_period_expenses e where e.id=v_original.id)
    and not exists(select 1 from economics_v2.group_occupancy_operations o where o.granja_id=v_ids.farm_a and o.operation_id=v_ids.fault_op),
    'late fault restores exact original expense/amount/creator/version and entire state, no receipt');
  update proof set late_ledger_rollback=true;
end;
$atomic_rollback$;

do $editor_history_viewer_and_final_scope$
declare v_ids record; v_original record; v_result jsonb; v_receipt record; v_before jsonb; v_observed boolean:=false; v_payload jsonb; v_impl boolean;
begin
  select * into v_ids from targets;
  select * into strict v_original from fault_original;
  perform set_config('request.jwt.claim.sub',v_ids.editor::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_ids.editor,'role','authenticated')::text,true);
  set local role authenticated;
  execute pg_temp.api_sql(v_ids.farm_a,v_ids.editor_op,v_original.id,v_original.period_id,v_original.updated_at,true) into v_result;
  insert into pg_temp.results values(v_ids.editor_op,v_result);
  foreach v_impl in array array[false,true] loop
    perform pg_temp.check_true(pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,v_ids.editor_op,v_original.id,v_original.period_id,v_original.updated_at,v_impl))
      =v_result||'{"replayed":true}'::jsonb,'editor direct success and public/private historical replay');
  end loop;
  reset role;
  perform pg_temp.check_true(v_result=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',v_ids.editor_op,
    'expense_id',v_original.id,'period_id',v_original.period_id,'deleted',true,'replayed',false),'editor exact6 fresh result');
  v_before:=pg_temp.business_state();
  begin
    -- ADMIN probes only: no real closure or CREATE integration claimed. Re-created UUID
    -- has a different mutable version; historical DELETE must not delete the new row.
    update economics_v2.group_occupancy_periods set closed_on=current_date-1,end_position=start_position+1 where id=v_original.period_id;
    set local role authenticated;
    v_observed:=pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,v_ids.editor_op,v_original.id,v_original.period_id,v_original.updated_at))=v_result||'{"replayed":true}'::jsonb;
    reset role;
    insert into economics_v2.group_period_expenses select (jsonb_populate_record(null::economics_v2.group_period_expenses,
      to_jsonb(v_original)||jsonb_build_object('updated_at',v_original.updated_at+interval '1 second'))).*;
    set local role authenticated;
    v_observed:=v_observed and pg_temp.checked(pg_temp.api_sql(v_ids.farm_a,v_ids.editor_op,v_original.id,v_original.period_id,v_original.updated_at,true))=v_result||'{"replayed":true}'::jsonb;
    reset role;
    raise exception using errcode='ZH001',message='Restore ADMIN closure and UUID recreation probe';
  exception when sqlstate 'ZH001' then null;
  end;
  perform pg_temp.check_true(v_observed and pg_temp.business_state()=v_before,'historical replay precedes CLOSED/re-created mutable row lookup, probe fully restored');
  perform set_config('request.jwt.claim.sub',v_ids.viewer::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_ids.viewer,'role','authenticated')::text,true);
  set local role authenticated;
  v_payload:=pg_temp.checked(format('select public.list_group_finance_expenses_v1(p_granja_id=>%L::uuid)',v_ids.farm_a));
  perform pg_temp.check_true(v_payload->>'role'='viewer' and v_payload->'can_edit'='false'::jsonb
    and jsonb_array_length(v_payload->'expenses')=1 and v_payload->'expenses'->0->>'expense_id'=(select expense_id::text from pg_temp.foundations where n=2),
    'viewer sees remaining CLOSED sibling, both deleted expenses absent and foreign sibling excluded');
  reset role;
  for v_receipt in select * from results loop
    perform pg_temp.check_true((select o.result=v_receipt.result and o.event_position is null and coalesce(btrim(o.payload_hash),'')<>''
      from economics_v2.group_occupancy_operations o where o.granja_id=v_ids.farm_a and o.operation_id=v_receipt.operation_id),'actual positionless persisted receipt matches original response');
  end loop;
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_period_expenses e where e.id in (v_ids.expense_a,v_original.id))
    and pg_temp.business_state(array[v_ids.owner_op,v_ids.editor_op],array[v_ids.expense_a,v_original.id])=(select b.state from baseline b),
    'only two selected deletions/two receipts; no new expenses, unrelated facts, eggs, basis, fences, positions, feed, ACL or sequence changes');
end;
$editor_history_viewer_and_final_scope$;

select jsonb_build_object('result','group_economics_forward_group_expenses_delete_pass',
  'assertion_count',(select count(*) from assertions),'fixture_ids',jsonb_build_object(
    'scope',(select to_jsonb(t) from targets t),'foundations',(select jsonb_agg(to_jsonb(f)) from foundations f)),
  'locking_evidence','sequential_only','independent_review','pending',
  'closed_fixture_kind','synthetic_foundation_without_memberships','real_closure_proven',false,
  'group_expense_delete_sql_rpc_proven',true,'expense_delete_ledger_atomic_rollback_proven',(select late_ledger_rollback from proof),
  'http_transport_proven',false,'group_expense_crud_integrated',false,'production_gateway_integrated',false,
  'legacy_expense_guards_integrated',false,'all_legacy_mutation_paths_guarded',false,'canonical_group_expense_api_integrated',false) evidence;
rollback;
