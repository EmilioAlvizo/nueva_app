begin;

-- HUMAN Sandbox Dashboard only; authored fixture, NOT runtime GREEN evidence.
-- First genuine UPDATE is uncaught: expect 42883 until implementation exists.
-- Exact9 required named inputs, including explicit nullable opaque note; exact6 receipt.
-- Fresh lock contract: farm advisory -> Group -> period -> expense. Sequential only:
-- this fixture cannot prove concurrent lock ordering or real membership-bearing closure.
-- No implementation/hash algorithm prescribed here; payload identity is tested behaviorally.
-- Budget target: fixture <=480; reserve >=300 for complete guarded UPDATE migration, total <=800.
-- Setup issues sequence positions; ROLLBACK does not rewind issued sequence values.

create temp table ids as select gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor,gen_random_uuid() viewer,gen_random_uuid() outsider,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,
  gen_random_uuid() type_b,gen_random_uuid() meat_a,gen_random_uuid() meat_b,
  gen_random_uuid() animal_a,gen_random_uuid() group_a,gen_random_uuid() entry_op,
  gen_random_uuid() owner_op,gen_random_uuid() editor_op,gen_random_uuid() null_op,
  gen_random_uuid() sibling_op,gen_random_uuid() fault_op,gen_random_uuid() expense_a;
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
create function pg_temp.check_true(ok boolean,label text) returns void
language plpgsql security invoker set search_path='' as $$
begin
  if ok is distinct from true then raise exception 'Expense UPDATE: %',label; end if;
  insert into pg_temp.assertions values(label);
end;
$$;
-- Trusted read-only evidence helper, never a business-call proxy. Positive snapshots
-- normalize ONLY named editable fields of selected existing rows, not row identity/count.
create function pg_temp.business_state(allowed_ops uuid[] default '{}',editable uuid[] default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; rows jsonb; state jsonb:='{}'; projection text; filter text;
begin
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    projection:='to_jsonb(r)'; filter:='';
    if t.schema_name='economics_v2' and t.table_name='group_period_expenses' then
      projection:='case when r.id=any($2) then to_jsonb(r)-array[''occurred_on'',''amount'',''category'',''note'',''updated_at''] else to_jsonb(r) end';
    elsif t.schema_name='economics_v2' and t.table_name='group_occupancy_operations' then
      filter:=' where not (r.granja_id=$3 and r.operation_id=any($1))';
    end if;
    execute format('select coalesce(jsonb_agg(v order by v::text),''[]''::jsonb)
      from (select %s v from %I.%I r%s) s',projection,t.schema_name,t.table_name,filter)
      into rows using allowed_ops,editable,(select farm_a from pg_temp.ids);
    state:=state||jsonb_build_object(t.schema_name||'.'||t.table_name,rows);
  end loop;
  for t in select * from pg_temp.sequences loop
    execute format('select jsonb_build_object(''last_value'',last_value,''log_cnt'',log_cnt,''is_called'',is_called)
      from %I.%I',t.schema_name,t.sequence_name) into rows;
    state:=state||jsonb_build_object(t.schema_name||'.'||t.sequence_name,rows);
  end loop;
  -- Privilege inspection starts only after the first genuine UPDATE invocation.
  if to_regclass('pg_temp.acl_baseline') is not null then
    select coalesce(jsonb_agg(a order by a::text),'[]'::jsonb) into rows from (
      select jsonb_build_array('relation',c.oid,c.relacl) a from pg_class c
      join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','economics_v2','group_feed_integrity','auth')
      union all select jsonb_build_array('function',p.oid,p.proacl) from pg_proc p
      join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','economics_v2','group_feed_integrity','auth')) acl;
    state:=state||jsonb_build_object('acl',rows);
  end if;
  return state;
end;
$$;
create function pg_temp.api_sql(farm uuid,op uuid,expense uuid,period uuid,version timestamptz,
  day date,amount numeric,category text,note text,impl boolean default false) returns text
language sql security invoker set search_path='' as $$
  select format('select %s(p_granja_id=>%L::uuid,p_operation_id=>%L::uuid,p_expense_id=>%L::uuid,
    p_period_id=>%L::uuid,p_expected_updated_at=>%L::timestamptz,p_occurred_on=>%L::date,
    p_amount=>%L::numeric,p_category=>%L::text,p_note=>%L::text)',case when impl then
    'economics_v2.update_group_finance_expense_impl' else 'public.update_group_finance_expense_v1' end,
    farm,op,expense,period,version,day,amount,category,note);
$$;
create function pg_temp.observe_dml() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('expense_update.observe',true)='on'
    or (tg_table_schema='economics_v2' and tg_table_name='group_feed_api_completions') then
    perform nextval('pg_temp.dml_attempts');
    raise exception 'Expense UPDATE replay/refusal or food sidecar attempted DML: %.% %',tg_table_schema,tg_table_name,tg_op;
  end if;
  return null;
end;
$$;
create function pg_temp.checked(statement text,expected_state text default null,
  code text default null,field text default null,entity uuid default null) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare before_state jsonb; counter jsonb; result jsonb; actual_state text; detail text;
begin
  before_state:=pg_temp.business_state();
  select jsonb_build_object('last_value',s.last_value,'log_cnt',s.log_cnt,'is_called',s.is_called) into counter from pg_temp.dml_attempts s;
  perform set_config('expense_update.observe','on',true);
  begin execute statement into result;
  exception when others then
    if expected_state is null then raise; end if;
    get stacked diagnostics actual_state=returned_sqlstate,detail=pg_exception_detail;
  end;
  perform set_config('expense_update.observe','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=before_state,'full business/sequence/ACL state unchanged');
  perform pg_temp.check_true((select jsonb_build_object('last_value',s.last_value,'log_cnt',s.log_cnt,'is_called',s.is_called)=counter
    from pg_temp.dml_attempts s),'no attempted DML, including caught or zero-row statements');
  if expected_state is null then
    perform pg_temp.check_true(result is not null,'nonempty replay/read result');
  else
    perform pg_temp.check_true(actual_state=expected_state,'SQLSTATE '||expected_state);
    if code is not null then
      perform pg_temp.check_true(detail::jsonb=jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',code,'field',field,'entity_id',entity),'exact4 typed refusal DETAIL');
    end if;
  end if;
  return result;
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select actor,'authenticated','authenticated','{"fixture":"group-expenses-update"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor,viewer,outsider]) actor;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Expense UPDATE A',owner_a from ids
union all select farm_b,owner_b,'Expense UPDATE B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor,'editor'::public.rol_miembro from ids
union all select farm_a,viewer,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Update type A',owner_a from ids union all select type_b,farm_b,'Update type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Update meat A','carne',owner_a from ids
union all select meat_b,farm_b,'Update meat B','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_a,farm_a,type_a,'Update occupied Group',owner_a from ids
union all select group_id,case when n=3 then farm_b else farm_a end,
  case when n=3 then type_b else type_a end,'Update foundation '||n,
  case when n=3 then owner_b else owner_a end from foundations cross join ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,owner_a from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true),
  set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
-- Actual private admission supplies acquisition metrics; it is setup, not UPDATE evidence.
create temp table targets as select i.*,(economics_v2.enter_group_meat_initial(
  farm_a,entry_op,animal_a,current_date-4,group_a,meat_a,'{}')->>'destination_period_id')::uuid period_a from ids i;
do $foundations$
declare f record; i record; pos bigint;
begin
  select * into i from ids;
  for f in select * from foundations order by n loop
    pos:=nextval('economics_v2.group_economics_event_position_seq');
    insert into economics_v2.group_occupancy_periods(id,granja_id,group_id,purpose_id,starts_on,closed_on,start_position,end_position)
    values(f.period_id,case when f.n=3 then i.farm_b else i.farm_a end,f.group_id,
      case when f.n=3 then i.meat_b else i.meat_a end,current_date-4,
      case when f.n=2 then current_date-1 end,pos,
      case when f.n=2 then nextval('economics_v2.group_economics_event_position_seq') end);
  end loop;
end;
$foundations$;
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
-- Only TEMP evidence privileges are granted before first invocation; no endpoint preflight.
do $observers$
declare t record;
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
  for t in select * from watched loop
    execute format('create trigger expense_update_statement_observer before insert or update or delete or truncate
      on %I.%I for each statement execute function pg_temp.observe_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;
grant select on ids,targets,foundations,originals,results to authenticated,anon;
grant insert on assertions,results to authenticated,anon;
grant select,usage on sequence dml_attempts to authenticated,anon;

do $first_public_call$
declare f record; version timestamptz; r jsonb;
begin
  select * into f from targets;
  select updated_at into strict version from originals where id=f.expense_a;
  set local role authenticated;
  r:=public.update_group_finance_expense_v1(p_granja_id=>f.farm_a::uuid,p_operation_id=>f.owner_op::uuid,
    p_expense_id=>f.expense_a::uuid,p_period_id=>f.period_a::uuid,p_expected_updated_at=>version::timestamptz,
    p_occurred_on=>(current_date-1)::date,p_amount=>75::numeric,p_category=>' Veterinary '::text,p_note=>''::text);
  perform pg_temp.check_true(current_user='authenticated','FIRST real UPDATE under client SQL role, owner and current OPEN version');
  insert into pg_temp.results values(f.owner_op,r);
  reset role;
end;
$first_public_call$;

create temp table acl_baseline(marker boolean);
insert into acl_baseline values(true);
create temp table acl_expected as select pg_temp.business_state()->'acl' state;
do $metadata_and_first_facts$
declare f record; v_function record; e record; r jsonb; m jsonb;
begin
  select * into f from targets;
  perform pg_temp.check_true((select count(*)=2 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='public' and p.proname='update_group_finance_expense_v1') or
      (n.nspname='economics_v2' and p.proname='update_group_finance_expense_impl')),'two functions without overloads');
  for v_function in select q.*,n.nspname from pg_proc q join pg_namespace n on n.oid=q.pronamespace where q.oid in
    ('public.update_group_finance_expense_v1(uuid,uuid,uuid,uuid,timestamptz,date,numeric,text,text)'::regprocedure,
     'economics_v2.update_group_finance_expense_impl(uuid,uuid,uuid,uuid,timestamptz,date,numeric,text,text)'::regprocedure) loop
    perform pg_temp.check_true(v_function.pronargs=9 and v_function.pronargdefaults=0 and v_function.proargmodes is null
      and v_function.proargnames=array['p_granja_id','p_operation_id','p_expense_id','p_period_id','p_expected_updated_at','p_occurred_on','p_amount','p_category','p_note']
      and v_function.prorettype='jsonb'::regtype and not v_function.proretset and v_function.prokind='f' and v_function.provolatile='v'
      and v_function.prosecdef=(v_function.nspname='economics_v2') and v_function.proowner='postgres'::regrole
      and v_function.proconfig @> array['search_path=""'] and has_function_privilege('authenticated',v_function.oid,'execute')
      and not has_function_privilege('anon',v_function.oid,'execute') and not exists(
        select 1 from aclexplode(coalesce(v_function.proacl,acldefault('f',v_function.proowner))) a
        where a.privilege_type='EXECUTE' and a.grantee not in (v_function.proowner,'authenticated'::regrole)),
      'exact9 required inputs, jsonb VOLATILE, postgres, empty path, auth-only INVOKER/guarded DEFINER');
  end loop;
  perform pg_temp.check_true(not exists(select 1 from (values('authenticated'),('anon')) a(role_name)
    cross join (values('economics_v2.group_period_expenses'),('economics_v2.group_occupancy_periods')) t(table_name)
    where has_table_privilege(a.role_name,t.table_name,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE')),
    'no direct expense/period privileges for either client role');
  select * into strict e from economics_v2.group_period_expenses where id=f.expense_a;
  select result into strict r from results where operation_id=f.owner_op;
  perform pg_temp.check_true(e.amount=75 and e.category=' Veterinary ' and e.note='' and e.occurred_on=current_date-1
    and e.updated_at>(select updated_at from originals where id=e.id) and isfinite(e.updated_at),'first UPDATE exact fields, opaque text, advancing finite version');
  perform pg_temp.check_true(r=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',f.owner_op,
    'expense_id',e.id,'period_id',e.period_id,'updated_at',e.updated_at,'replayed',false),'first exact6 stored-version receipt');
  m:=economics_v2.calculate_group_period_live_metrics(f.farm_a,f.period_a);
  perform pg_temp.check_true((m->>'direct_expense_total')::numeric=75 and (m->>'total_cost')::numeric=375
    and (m->>'acquisition_cost')::numeric=300,'live metric 50 -> 75 over unchanged acquisition 300');
end;
$metadata_and_first_facts$;

do $later_edits_and_read$
declare f record; q record; old_row record; e record; r jsonb; payload jsonb; item jsonb;
begin
  select * into f from targets;
  for q in select * from (values
    (f.editor_op,f.editor,f.expense_a,f.period_a,80::numeric,' Editor ',' ',true),
    (f.null_op,f.owner_a,f.expense_a,f.period_a,85,' Final ',null::text,false),
    (f.sibling_op,f.owner_a,(select expense_id from foundations where n=1),
      (select period_id from foundations where n=1),15,' Sibling ',null,false)) v(op,actor,expense,period,amount,category,note,impl) loop
    select * into strict old_row from economics_v2.group_period_expenses where id=q.expense;
    perform set_config('request.jwt.claim.sub',q.actor::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',q.actor,'role','authenticated')::text,true);
    set local role authenticated;
    execute pg_temp.api_sql(f.farm_a,q.op,q.expense,q.period,old_row.updated_at,current_date-1,q.amount,q.category,q.note,q.impl) into r;
    insert into pg_temp.results values(q.op,r);
    perform pg_temp.check_true(pg_temp.checked(pg_temp.api_sql(f.farm_a,q.op,q.expense,q.period,old_row.updated_at,
      current_date-1,q.amount,q.category,q.note,true))=r||'{"replayed":true}'::jsonb,'direct implementation success/replay with original expected token');
    reset role;
    select * into strict e from economics_v2.group_period_expenses where id=q.expense;
    perform pg_temp.check_true(to_jsonb(e)-array['occurred_on','amount','category','note','updated_at']
      =to_jsonb(old_row)-array['occurred_on','amount','category','note','updated_at'] and e.updated_at>old_row.updated_at
      and isfinite(e.updated_at) and e.occurred_on=current_date-1 and e.amount=q.amount and e.category=q.category
      and e.note is not distinct from q.note,'only editable fields/version changed, creator/creation/target preserved');
    perform pg_temp.check_true(r=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',q.op,
      'expense_id',e.id,'period_id',e.period_id,'updated_at',e.updated_at,'replayed',false),'later exact6 receipt');
  end loop;
  perform set_config('request.jwt.claim.sub',f.viewer::text,true);
  set local role authenticated;
  payload:=pg_temp.checked(format('select public.list_group_finance_expenses_v1(p_granja_id=>%L::uuid)',f.farm_a));
  select value into strict item from jsonb_array_elements(payload->'expenses') where value->>'expense_id'=f.expense_a::text;
  perform pg_temp.check_true(payload->>'role'='viewer' and item->'amount'='85'::jsonb and item->'note'='null'::jsonb
    and item->>'category'=' Final ' and item->'can_mutate'='false'::jsonb,'viewer reads actual updated fact, cannot mutate');
  reset role;
end;
$later_edits_and_read$;

do $replay_conflicts_and_validation$
declare f record; q record; v timestamptz; current_v timestamptz; sql text; r jsonb; impl boolean;
begin
  select * into f from targets;
  select updated_at into v from originals where id=f.expense_a;
  select updated_at into current_v from economics_v2.group_period_expenses where id=f.expense_a;
  select result into r from results where operation_id=f.owner_op;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  set local role authenticated;
  foreach impl in array array[false,true] loop
    sql:=pg_temp.api_sql(f.farm_a,f.owner_op,f.expense_a,f.period_a,v,current_date-1,75.00,' Veterinary ','',impl);
    perform pg_temp.check_true(pg_temp.checked(sql)=r||'{"replayed":true}'::jsonb,'historical original-token replay after later edits, normalized numeric scale');
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),f.expense_a,f.period_a,v,current_date-1,75,' Veterinary ','',impl),
      '40001','stale_write','expected_updated_at',f.expense_a);
  end loop;
  for q in select * from (values
    (f.expense_a,f.period_a,current_v,current_date-1,75::numeric,' Veterinary ',''::text),
    (gen_random_uuid(),f.period_a,v,current_date-1,75,' Veterinary ',''),
    (f.expense_a,(select period_id from pg_temp.foundations where n=1),v,current_date-1,75,' Veterinary ',''),
    (f.expense_a,f.period_a,v,current_date-2,75,' Veterinary ',''),(f.expense_a,f.period_a,v,current_date-1,76,' Veterinary ',''),
    (f.expense_a,f.period_a,v,current_date-1,75,'Veterinary',''),(f.expense_a,f.period_a,v,current_date-1,75,' Veterinary ',null),
    (f.expense_a,f.period_a,v,current_date-1,75,' Veterinary ',' ')) v(expense,period,version,day,amount,category,note) loop
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,f.owner_op,q.expense,q.period,q.version,q.day,q.amount,q.category,q.note),
      '22023','operation_payload_conflict','operation_id',f.owner_op);
  end loop;
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,f.entry_op,f.expense_a,f.period_a,current_v,current_date-1,75,'Veterinary',null),
    '22023','operation_payload_conflict','operation_id',f.entry_op); -- Shared occupancy/expense operation namespace.
  for q in select * from (values
    (null::date,75::numeric,'Veterinary'::text,'occurred_on'),(current_date+1,75,'Veterinary','occurred_on'),
    ('infinity'::date,75,'Veterinary','occurred_on'),(current_date-5,75,'Veterinary','occurred_on'),
    (current_date-1,null,'Veterinary','amount'),(current_date-1,0,'Veterinary','amount'),(current_date-1,-1,'Veterinary','amount'),
    (current_date-1,'NaN'::numeric,'Veterinary','amount'),(current_date-1,'Infinity'::numeric,'Veterinary','amount'),
    (current_date-1,'-Infinity'::numeric,'Veterinary','amount'),(current_date-1,75,null,'category'),
    (current_date-1,75,'','category'),(current_date-1,75,'  ','category')) v(day,amount,category,field) loop
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),f.expense_a,f.period_a,current_v,q.day,q.amount,q.category,null),
      '22023','invalid_request',q.field,case when q.field='occurred_on' then f.period_a else f.expense_a end);
  end loop;
  for q in select unnest(array[null::timestamptz,'infinity'::timestamptz,'-infinity'::timestamptz]) version loop
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),f.expense_a,f.period_a,q.version,current_date-1,75,'Veterinary',null),
      '22023','invalid_request','expected_updated_at',f.expense_a);
  end loop;
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,null,f.expense_a,f.period_a,current_v,current_date-1,75,'Veterinary',null),'22023','invalid_request','operation_id',null);
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),null,f.period_a,current_v,current_date-1,75,'Veterinary',null),'22023','invalid_request','expense_id',null);
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),f.expense_a,null,current_v,current_date-1,75,'Veterinary',null),'22023','invalid_request','period_id',null);
  perform pg_temp.checked(pg_temp.api_sql(null,gen_random_uuid(),f.expense_a,f.period_a,current_v,current_date-1,75,'Veterinary',null),'22023','invalid_request','granja_id',null);
  for q in select * from pg_temp.foundations where n in (1,3) loop
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),f.expense_a,q.period_id,current_v,current_date-1,75,'Veterinary',null),
      '42501','forbidden',case when q.n=3 then 'period_id' else 'expense_id' end,case when q.n=3 then q.period_id else f.expense_a end);
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),q.expense_id,f.period_a,current_v,current_date-1,75,'Veterinary',null),
      '42501','forbidden','expense_id',q.expense_id);
  end loop;
  reset role;
end;
$replay_conflicts_and_validation$;

do $authorization_and_history$
declare f record; a record; impl boolean; op uuid; sql text; v timestamptz; before_state jsonb; observed boolean; q record;
begin
  select * into f from targets;
  select updated_at into v from originals where id=f.expense_a;
  for a in select * from (values(f.viewer,'authenticated'),(f.owner_b,'authenticated'),(f.outsider,'authenticated'),
    (null::uuid,'authenticated'),(f.owner_a,'anon')) v(actor,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(a.actor::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',a.actor,'role',a.role_name)::text,true);
    execute format('set local role %I',a.role_name);
    foreach impl in array array[false,true] loop
      foreach op in array array[f.owner_op,gen_random_uuid()] loop
        perform pg_temp.checked(pg_temp.api_sql(f.farm_a,op,f.expense_a,f.period_a,v,current_date-1,75,' Veterinary ','',impl),
          '42501',case when a.role_name='authenticated' then 'forbidden' end,'granja_id',f.farm_a);
      end loop;
    end loop;
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  perform set_config('request.jwt.claim.sub',f.editor::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor,'role','authenticated')::text,true);
  set local role authenticated;
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,f.owner_op,f.expense_a,f.period_a,v,current_date-1,75,' Veterinary ',''),
    '22023','operation_payload_conflict','operation_id',f.owner_op);
  reset role;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  before_state:=pg_temp.business_state();
  begin
    update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
    set local role authenticated;
    foreach impl in array array[false,true] loop
      foreach op in array array[f.owner_op,gen_random_uuid()] loop
        perform pg_temp.checked(pg_temp.api_sql(f.farm_a,op,f.expense_a,f.period_a,v,current_date-1,75,' Veterinary ','',impl),
          '42501','forbidden','granja_id',f.farm_a);
      end loop;
    end loop;
    reset role;
    raise exception using errcode='ZR001',message='Restore entire feature flag probe';
  exception when sqlstate 'ZR001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=before_state,'flag refusal restores all metadata through subtransaction rollback');
  select o.* into q from originals o join foundations x on x.expense_id=o.id where x.n=2;
  set local role authenticated;
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),q.id,q.period_id,q.updated_at,current_date-1,15,'Sibling',null),
    '23514','closed_period_immutable','period_id',q.period_id);
  perform pg_temp.checked('select * from economics_v2.group_period_expenses','42501');
  perform pg_temp.checked('update economics_v2.group_period_expenses set note=null where false','42501');
  perform pg_temp.checked('select economics_v2.assert_group_writer_actor(null::uuid)','42501');
  perform pg_temp.checked('select economics_v2.enter_group_meat_initial(null::uuid,null::uuid,null::uuid,current_date,null::uuid,null::uuid,''{}''::jsonb)','42501');
  reset role;
  -- No memberships: synthetic closure and deletion are ADMIN probes, not CRUD/closure proof.
  select * into q from foundations where n=1;
  select updated_at into v from originals where id=q.expense_id;
  before_state:=pg_temp.business_state();
  observed:=false;
  begin
    update economics_v2.group_occupancy_periods set closed_on=current_date-1,end_position=start_position+1 where id=q.period_id;
    set local role authenticated;
    sql:=pg_temp.api_sql(f.farm_a,f.sibling_op,q.expense_id,q.period_id,v,current_date-1,15,' Sibling ',null);
    observed:=pg_temp.checked(sql)=(select result||'{"replayed":true}'::jsonb from pg_temp.results where operation_id=f.sibling_op);
    reset role;
    delete from economics_v2.group_period_expenses where id=q.expense_id;
    perform pg_temp.check_true(not exists(select 1 from economics_v2.group_period_expenses where id=q.expense_id),'historical fact actually deleted');
    set local role authenticated;
    observed:=observed and pg_temp.checked(sql)=(select result||'{"replayed":true}'::jsonb from pg_temp.results where operation_id=f.sibling_op);
    reset role;
    raise exception using errcode='ZH001',message='Restore synthetic closure/deletion';
  exception when sqlstate 'ZH001' then null;
  end;
  perform pg_temp.check_true(observed and pg_temp.business_state()=before_state,'historical replay precedes CLOSED/deleted mutable facts; whole probe restored');
end;
$authorization_and_history$;

-- AFTER receipt insertion: observe the exact changed real row AND persisted receipt,
-- then abort the statement. No counter/proof flag can substitute for these observations.
create temp table fault_original as select e.* from economics_v2.group_period_expenses e join ids i on e.id=i.expense_a;
grant select on fault_original to authenticated;
create function pg_temp.fail_late_ledger() returns trigger
language plpgsql security invoker set search_path='' as $$
declare f record; e record; old_row record;
begin
  select * into f from pg_temp.targets;
  if new.operation_id<>f.fault_op then return new; end if;
  select * into strict old_row from pg_temp.fault_original;
  select * into strict e from economics_v2.group_period_expenses where id=f.expense_a;
  if (to_jsonb(e)-array['occurred_on','amount','category','note','updated_at']) is distinct from
      (to_jsonb(old_row)-array['occurred_on','amount','category','note','updated_at'])
    or e.occurred_on is distinct from current_date-1 or e.amount is distinct from 37.5::numeric
    or e.category is distinct from ' Fault ' or e.note is distinct from 'Atomic rollback'
    or not isfinite(e.updated_at) or e.updated_at<=old_row.updated_at or new.granja_id<>f.farm_a
    or new.event_position is not null or btrim(new.payload_hash)='' or new.result is distinct from jsonb_build_object(
      'contract_version','group-economics.forward.v3','operation_id',f.fault_op,'expense_id',e.id,
      'period_id',e.period_id,'updated_at',e.updated_at,'replayed',false)
    or not exists(select 1 from economics_v2.group_occupancy_operations o where o.granja_id=f.farm_a
      and o.operation_id=f.fault_op and to_jsonb(o)=to_jsonb(new)) then
    raise exception 'Late ledger observer did not find exact changed expense and receipt';
  end if;
  raise exception using errcode='ZL001',message='Injected late ledger failure',detail='observed_after_real_expense_update_and_receipt';
end;
$$;
create trigger expense_update_late_ledger_fault after insert on economics_v2.group_occupancy_operations
  for each row execute function pg_temp.fail_late_ledger();
do $atomic_rollback_and_final_scope$
declare f record; before_state jsonb; v_sqlstate text; detail text; r record;
begin
  select * into f from targets;
  before_state:=pg_temp.business_state();
  set local role authenticated;
  begin
    execute pg_temp.api_sql(f.farm_a,f.fault_op,f.expense_a,f.period_a,(select updated_at from pg_temp.fault_original),
      current_date-1,37.5,' Fault ','Atomic rollback');
  exception when others then get stacked diagnostics v_sqlstate=returned_sqlstate,detail=pg_exception_detail;
  end;
  reset role;
  perform pg_temp.check_true(v_sqlstate='ZL001' and detail='observed_after_real_expense_update_and_receipt'
    and pg_temp.business_state()=before_state,'real UPDATE plus persisted receipt fault restores complete original row/version and all business state');
  update proof set late_ledger_rollback=true;
  for r in select * from results loop
    perform pg_temp.check_true((select result=r.result and event_position is null and btrim(payload_hash)<>''
      from economics_v2.group_occupancy_operations where granja_id=f.farm_a and operation_id=r.operation_id),'one actual positionless receipt per successful UPDATE');
  end loop;
  perform pg_temp.check_true((pg_temp.business_state(array[f.owner_op,f.editor_op,f.null_op,f.sibling_op],
    array[f.expense_a,(select expense_id from foundations where n=1)])-'acl')=(select state from baseline)
    and pg_temp.business_state()->'acl'=(select state from acl_expected),'only intended existing fields and four receipts; no extra expense/position, unrelated eggs/fences/basis/allocation/ACL/sequence changes');
end;
$atomic_rollback_and_final_scope$;

select jsonb_build_object('result','group_economics_forward_group_expenses_update_pass',
  'assertion_count',(select count(*) from assertions),'fixture_ids',jsonb_build_object(
    'scope',(select to_jsonb(t) from targets t),'foundations',(select jsonb_agg(to_jsonb(f)) from foundations f)),
  'locking_evidence','sequential_only','independent_review','pending',
  'closed_fixture_kind','synthetic_foundation_without_memberships','real_closure_proven',false,
  'group_expense_update_sql_rpc_proven',true,'expense_update_ledger_atomic_rollback_proven',(select late_ledger_rollback from proof),
  'http_transport_proven',false,'group_expense_crud_integrated',false,'later_event_backdating_proven',false,
  'production_gateway_integrated',false,'legacy_expense_guards_integrated',false,
  'all_legacy_mutation_paths_guarded',false,'canonical_group_expense_api_integrated',false) evidence;
rollback;
