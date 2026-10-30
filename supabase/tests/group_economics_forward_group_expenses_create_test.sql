begin;

-- HUMAN Sandbox Dashboard only: execute this FULL transaction after authorization.
-- Authored fixture, NOT execution/compilation/independent qualification evidence.
-- FIRST actual named PUBLIC CREATE must escape with genuine 42883 while absent.
-- No producer proxy, absent-function preflight, implementation or new replay table.
-- Pinned PUBLIC create_group_finance_expense_v1 / private create_group_finance_expense_impl:
-- (p_granja_id uuid,p_operation_id uuid,p_period_id uuid,p_occurred_on date,
--  p_amount numeric,p_category text,p_note text) RETURNS jsonb; seven required names.
-- Private guarded DEFINER may insert the actual expense and receipt directly;
-- PUBLIC INVOKER delegates with the same names. Both VOLATILE, postgres-owned,
-- empty search_path, authenticated-only. Reuse assert_group_writer_actor under
-- DEFINER with real auth.uid(), recheck after the group-economics farm advisory lock.
-- Fresh lock order: farm advisory -> owned Group UUID -> period -> expense insert.
-- Authorization/scalar grammar precedes receipt lookup; receipt precedes mutable
-- period/expense admission. Shared farm operation namespace; NULL event_position.
-- Hash: canonical_group_request(envelope)::text -> UTF8 -> sha256 -> lowercase hex.
-- Exact6 envelope: contract_version,operation_domain,granja_id,actor_id,operation_id,request.
-- Domain group-expense-create.v1; exact6 request: action=expense_create,period_id,
-- occurred_on,amount,category,note. Numeric scale normalizes; text is OPAQUE.
-- Validate btrim(category) nonblank, but persist/hash original category and note;
-- SQL NULL, empty and whitespace note are distinct. No category catalog or UI enum.
-- Exact6 result: contract_version,operation_id,expense_id,period_id,updated_at,replayed.
-- Dates: finite <=today, >=period start and latest applicable period/event date.
-- This fixture covers start-bound admission; later-event backdating remains unproved.
-- No source/basis/event/position/fence or food completion sidecar mutation permitted.
-- Full future unit forecast: fixture 462 + actual guarded logic/wrapper/ACL <=260
-- = <=722, hard cap800. Do not substitute a nonexistent expense core or code-golf.
-- Sequential isolated Sandbox evidence only. Setup sequence issuance is not rewound.

create temp table ids as select gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor,gen_random_uuid() viewer,gen_random_uuid() outsider,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,
  gen_random_uuid() type_b,gen_random_uuid() meat_a,gen_random_uuid() meat_b,
  gen_random_uuid() eggs_a,gen_random_uuid() animal_a,gen_random_uuid() group_a,
  gen_random_uuid() entry_op,gen_random_uuid() owner_op,gen_random_uuid() editor_op,
  gen_random_uuid() fault_op,gen_random_uuid() missing_period;
create temp table foundations as select n,gen_random_uuid() group_id,gen_random_uuid() period_id
  from generate_series(1,4) n; -- 1 sibling OPEN, 2 posture, 3 synthetic CLOSED, 4 foreign.
create temp table assertions(label text not null);
create temp table results(actor uuid,result jsonb not null);
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
  if ok is distinct from true then raise exception 'Expense CREATE: %',label; end if;
  insert into pg_temp.assertions values(label);
end;
$$;
-- Sole trusted evidence helper: read-only snapshot, never a business-call proxy.
-- Positive snapshots exclude ONLY facts identified by completed selected receipts.
create function pg_temp.business_state(allowed_ops uuid[] default '{}'::uuid[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare t record; rows jsonb; state jsonb:='{}'; filter text; expense_ids uuid[];
begin
  select coalesce(array_agg((o.result->>'expense_id')::uuid),'{}'::uuid[]) into expense_ids
  from economics_v2.group_occupancy_operations o join pg_temp.ids i on i.farm_a=o.granja_id
  where o.operation_id=any(allowed_ops);
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    filter:='';
    if t.schema_name='economics_v2' and t.table_name='group_period_expenses' then
      filter:=' where not r.id=any($1)';
    elsif t.schema_name='economics_v2' and t.table_name='group_occupancy_operations' then
      filter:=' where not (r.granja_id=$3 and r.operation_id=any($2))';
    end if;
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r%s',t.schema_name,t.table_name,filter) into rows
      using expense_ids,allowed_ops,(select farm_a from pg_temp.ids);
    state:=state||jsonb_build_object(t.schema_name||'.'||t.table_name,rows);
  end loop;
  for t in select * from pg_temp.sequences loop
    execute format('select jsonb_build_object(''last_value'',last_value,''is_called'',is_called)
      from %I.%I',t.schema_name,t.sequence_name) into rows;
    state:=state||jsonb_build_object(t.schema_name||'.'||t.sequence_name,rows);
  end loop;
  select coalesce(jsonb_agg(a order by a::text),'[]'::jsonb) into rows from (
    select jsonb_build_array('table',c.oid,c.relacl) a from pg_class c
    join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','economics_v2','group_feed_integrity','auth')
    union all select jsonb_build_array('function',p.oid,p.proacl) from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','economics_v2','group_feed_integrity','auth')) acl;
  return state||jsonb_build_object('acl',rows);
end;
$$;
create function pg_temp.api_sql(farm uuid,op uuid,period uuid,day date,amount numeric,
  category text,note text,impl boolean default false) returns text
language sql security invoker set search_path='' as $$
  select format('select %s(p_granja_id=>%L::uuid,p_operation_id=>%L::uuid,p_period_id=>%L::uuid,
    p_occurred_on=>%L::date,p_amount=>%L::numeric,p_category=>%L::text,p_note=>%L::text)',
    case when impl then 'economics_v2.create_group_finance_expense_impl'
      else 'public.create_group_finance_expense_v1' end,farm,op,period,day,amount,category,note);
$$;
create function pg_temp.observe_dml() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('expense_create.observe',true)='on'
    or (tg_table_schema='economics_v2' and tg_table_name='group_feed_api_completions') then
    perform nextval('pg_temp.dml_attempts');
    raise exception 'Expense replay/refusal or food sidecar attempted DML: %.% %',tg_table_schema,tg_table_name,tg_op;
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
  perform set_config('expense_create.observe','on',true);
  begin execute statement into result;
  exception when others then
    if expected_state is null then raise; end if;
    get stacked diagnostics actual_state=returned_sqlstate,detail=pg_exception_detail;
  end;
  perform set_config('expense_create.observe','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=before_state,'full facts/receipts/fences/sequences/ACL unchanged');
  perform pg_temp.check_true((select jsonb_build_object('last_value',s.last_value,'log_cnt',s.log_cnt,'is_called',s.is_called)=counter from pg_temp.dml_attempts s),'no attempted DML, including zero-row statements');
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
select actor,'authenticated','authenticated','{"fixture":"group-expenses-create"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor,viewer,outsider]) actor;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Expense CREATE A',owner_a from ids
union all select farm_b,owner_b,'Expense CREATE B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor,'editor'::public.rol_miembro from ids
union all select farm_a,viewer,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Expense type A',owner_a from ids union all select type_b,farm_b,'Expense type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select purpose,farm,code,code,actor from ids cross join lateral
  (values(meat_a,farm_a,'carne',owner_a),(eggs_a,farm_a,'postura',owner_a),(meat_b,farm_b,'carne',owner_b)) v(purpose,farm,code,actor);
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_a,farm_a,type_a,'Expense occupied Group',owner_a from ids
union all select group_id,case when n=4 then farm_b else farm_a end,
  case when n=4 then type_b else type_a end,'Expense foundation '||n,
  case when n=4 then owner_b else owner_a end from foundations cross join ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,owner_a from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true),
  set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
-- Actual qualified private admission as ADMIN with owner JWT, not a new PUBLIC producer proof.
create temp table targets as select i.*,(economics_v2.enter_group_meat_initial(
  farm_a,entry_op,animal_a,current_date-4,group_a,meat_a,'{}')->>'destination_period_id')::uuid period_a from ids i;
do $foundations$
declare f record; i record; start_pos bigint;
begin
  select * into i from ids;
  for f in select * from foundations order by n loop
    start_pos:=nextval('economics_v2.group_economics_event_position_seq');
    insert into economics_v2.group_occupancy_periods(id,granja_id,group_id,purpose_id,starts_on,closed_on,start_position,end_position)
    values(f.period_id,case when f.n=4 then i.farm_b else i.farm_a end,f.group_id,
      case when f.n=4 then i.meat_b when f.n=2 then i.eggs_a else i.meat_a end,
      current_date-4,case when f.n=3 then current_date-2 end,start_pos,
      case when f.n=3 then nextval('economics_v2.group_economics_event_position_seq') end);
  end loop;
end;
$foundations$;
set constraints all immediate;
create temp table baseline as select pg_temp.business_state() state;
do $observers$
declare t record;
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
  for t in select * from watched loop
    execute format('create trigger expense_create_statement_observer before insert or update or delete or truncate
      on %I.%I for each statement execute function pg_temp.observe_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;
grant select on ids,targets,foundations,results to authenticated,anon;
grant insert on assertions,results to authenticated,anon;
grant select,usage on sequence dml_attempts to authenticated,anon;
revoke all on function pg_temp.business_state(uuid[]) from public,anon;
grant execute on function pg_temp.business_state(uuid[]) to authenticated,anon;

do $first_public_call$
declare f record; r jsonb;
begin
  select * into f from targets;
  set local role authenticated;
  r:=public.create_group_finance_expense_v1(p_granja_id=>f.farm_a::uuid,p_operation_id=>f.owner_op::uuid,
    p_period_id=>f.period_a::uuid,p_occurred_on=>(current_date-1)::date,
    p_amount=>50::numeric,p_category=>'Veterinary'::text,p_note=>null::text);
  perform pg_temp.check_true(current_user='authenticated','FIRST genuine PUBLIC call under actual client SQL role');
  insert into pg_temp.results values(f.owner_a,r);
  reset role;
end;
$first_public_call$;

-- Catalog resolution intentionally occurs ONLY AFTER the genuine first business call.
do $metadata_and_editor$
declare f record; v_proc record; r jsonb; m jsonb;
begin
  select * into f from targets;
  perform pg_temp.check_true((select count(*)=2 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='public' and p.proname='create_group_finance_expense_v1') or
      (n.nspname='economics_v2' and p.proname='create_group_finance_expense_impl')),'exactly two functions, no overloads');
  for v_proc in select q.*,n.nspname from pg_proc q join pg_namespace n on n.oid=q.pronamespace where q.oid in
    ('public.create_group_finance_expense_v1(uuid,uuid,uuid,date,numeric,text,text)'::regprocedure,
     'economics_v2.create_group_finance_expense_impl(uuid,uuid,uuid,date,numeric,text,text)'::regprocedure) loop
    perform pg_temp.check_true(v_proc.pronargs=7 and v_proc.pronargdefaults=0 and v_proc.proargmodes is null
      and v_proc.proargnames=array['p_granja_id','p_operation_id','p_period_id','p_occurred_on','p_amount','p_category','p_note']
      and v_proc.prorettype='jsonb'::regtype and not v_proc.proretset and v_proc.prokind='f' and v_proc.provolatile='v'
      and v_proc.prosecdef=(v_proc.nspname='economics_v2') and v_proc.proowner='postgres'::regrole
      and v_proc.proconfig @> array['search_path=""'] and has_function_privilege('authenticated',v_proc.oid,'execute')
      and not has_function_privilege('anon',v_proc.oid,'execute') and not exists(
        select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) a
        where a.privilege_type='EXECUTE' and a.grantee not in (v_proc.proowner,'authenticated'::regrole)),
      'seven required named inputs, jsonb VOLATILE, postgres, empty path, auth-only INVOKER/guarded DEFINER');
  end loop;
  perform pg_temp.check_true(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='economics_v2' and p.proname in ('enter_group_meat_initial','assert_group_writer_actor',
      'raise_group_writer_error','canonical_group_request','prepare_group_operation','lock_group_writer_scope',
      'create_group_feed_allocation','update_group_feed_allocation','delete_group_feed_allocation')
    and (has_function_privilege('authenticated',p.oid,'execute') or has_function_privilege('anon',p.oid,'execute'))),
    'no private core/helper exposure');
  perform pg_temp.check_true(not exists(select 1 from (values('authenticated'),('anon')) a(role_name)
    cross join (values('economics_v2.group_period_expenses'),('economics_v2.group_occupancy_periods')) t(table_name)
    where has_table_privilege(a.role_name,t.table_name,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE')),
    'no raw expense/period SELECT or DML capability added');
  perform pg_temp.check_true(pg_temp.business_state(array[f.owner_op])=(select state from baseline),'owner changes ONLY actual expense and receipt');
  m:=economics_v2.calculate_group_period_live_metrics(f.farm_a,f.period_a);
  perform pg_temp.check_true((m->>'direct_expense_total')::numeric=50 and (m->>'total_cost')::numeric=350,'first expense counted once above acquisition 300');
  perform set_config('request.jwt.claim.sub',f.editor::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor,'role','authenticated')::text,true);
  set local role authenticated;
  execute pg_temp.api_sql(f.farm_a,f.editor_op,f.period_a,current_date-1,25,' Maintenance ',' Editor note ') into r;
  insert into pg_temp.results values(f.editor,r);
  perform pg_temp.check_true(pg_temp.checked(pg_temp.api_sql(f.farm_a,f.editor_op,f.period_a,current_date-1,
    25,' Maintenance ',' Editor note ',true))=r||'{"replayed":true}'::jsonb,'authorized direct implementation editor replay');
  reset role;
end;
$metadata_and_editor$;

create temp table expected_expenses as select e.* from economics_v2.group_period_expenses e join targets f on e.period_id=f.period_a;
grant select on expected_expenses to authenticated;
do $actual_facts_and_readback$
declare f record; e record; r jsonb; hash text; a record; payload jsonb; item jsonb; m jsonb;
begin
  select * into f from targets;
  perform pg_temp.check_true((select count(*)=2 from expected_expenses),'exactly two server-created expense facts');
  for e in select * from expected_expenses loop
    select result into strict r from results where actor=e.created_by;
    perform pg_temp.check_true(e.granja_id=f.farm_a and e.period_id=f.period_a and e.occurred_on=current_date-1
      and e.created_at is not null and e.updated_at is not null
      and ((e.created_by=f.owner_a and e.amount=50 and e.category='Veterinary' and e.note is null)
        or (e.created_by=f.editor and e.amount=25 and e.category=' Maintenance ' and e.note=' Editor note ')),
      'actual JWT creator, finite positive amount, original opaque text and real server timestamps');
    perform pg_temp.check_true(r=jsonb_build_object('contract_version','group-economics.forward.v3',
      'operation_id',case when e.created_by=f.owner_a then f.owner_op else f.editor_op end,
      'expense_id',e.id,'period_id',e.period_id,'updated_at',e.updated_at,'replayed',false),'exact6 result uses actual UUID and stored version');
    hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
      'contract_version','group-economics.forward.v3','operation_domain','group-expense-create.v1',
      'granja_id',f.farm_a,'actor_id',e.created_by,'operation_id',(r->>'operation_id')::uuid,
      'request',jsonb_build_object('action','expense_create','period_id',e.period_id,'occurred_on',e.occurred_on,
        'amount',e.amount,'category',e.category,'note',e.note)))::text,'UTF8')),'hex');
    perform pg_temp.check_true((select payload_hash=hash and result=r and event_position is null
      from economics_v2.group_occupancy_operations where granja_id=f.farm_a and operation_id=(r->>'operation_id')::uuid),'exact canonical receipt with NULL position');
  end loop;
  m:=economics_v2.calculate_group_period_live_metrics(f.farm_a,f.period_a);
  perform pg_temp.check_true((m->>'direct_expense_total')::numeric=75 and (m->>'total_cost')::numeric=375
    and (m->>'acquisition_cost')::numeric=300 and (m->>'feed_source_count')::integer=0,'two direct facts counted once, unchanged acquisition 300');
  for a in select * from (values(f.owner_a,'owner',true),(f.editor,'editor',true),(f.viewer,'viewer',false)) v(actor,role_name,editable) loop
    perform set_config('request.jwt.claim.sub',a.actor::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',a.actor,'role','authenticated')::text,true);
    set local role authenticated;
    payload:=pg_temp.checked(format('select public.list_group_finance_expenses_v1(p_granja_id=>%L::uuid)',f.farm_a));
    perform pg_temp.check_true((select count(*)=6 from jsonb_object_keys(payload)) and payload->>'role'=a.role_name
      and payload->'can_edit'=to_jsonb(a.editable) and jsonb_array_length(payload->'expenses')=2,'selected actual READ6 owner/editor/viewer projection');
    for e in select * from pg_temp.expected_expenses loop
      select value into strict item from jsonb_array_elements(payload->'expenses') where value->>'expense_id'=e.id::text;
      perform pg_temp.check_true((select count(*)=13 from jsonb_object_keys(item)) and item->'target_id'=to_jsonb(e.period_id)
        and item->'amount'=to_jsonb(e.amount) and item->'category'=to_jsonb(e.category)
        and item->'note'=coalesce(to_jsonb(e.note),'null'::jsonb) and item->'created_by'=to_jsonb(e.created_by)
        and (item->>'updated_at')::timestamptz=e.updated_at and item->'can_mutate'=to_jsonb(a.editable),'READ13 actual source identity, text and role capability');
    end loop;
    reset role;
  end loop;
end;
$actual_facts_and_readback$;

do $replay_and_refusals$
declare f record; q record; a record; impl boolean; r jsonb; sql text;
begin
  select * into f from targets;
  select result into r from results where actor=f.owner_a;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  set local role authenticated;
  sql:=pg_temp.api_sql(f.farm_a,f.owner_op,f.period_a,current_date-1,50.00,'Veterinary',null);
  perform pg_temp.check_true(pg_temp.checked(sql)=r||'{"replayed":true}'::jsonb,'numeric-scale normalized historical replay, no DML');
  for q in select * from (values
    ((select period_id from pg_temp.foundations where n=1),current_date-1,50::numeric,'Veterinary',null::text),
    (f.period_a,current_date-2,50,'Veterinary',null),(f.period_a,current_date-1,51,'Veterinary',null),
    (f.period_a,current_date-1,50,' Veterinary ',null),(f.period_a,current_date-1,50,'Veterinary',''),
    (f.period_a,current_date-1,50,'Veterinary',' ')) v(period_id,day,amount,category,note) loop
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,f.owner_op,q.period_id,q.day,q.amount,q.category,q.note),
      '22023','operation_payload_conflict','operation_id',f.owner_op);
  end loop;
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,f.entry_op,f.missing_period,current_date-1,50,'Veterinary',null),
    '22023','operation_payload_conflict','operation_id',f.entry_op); -- Occupancy domain conflict BEFORE missing-period lookup.
  for q in select * from (values
    (null::date,50::numeric,'Veterinary'::text,'occurred_on'),(current_date+1,50,'Veterinary','occurred_on'),
    ('infinity'::date,50,'Veterinary','occurred_on'),('-infinity'::date,50,'Veterinary','occurred_on'),
    (current_date-5,50,'Veterinary','occurred_on'),(current_date-1,null,'Veterinary','amount'),
    (current_date-1,0,'Veterinary','amount'),(current_date-1,-1,'Veterinary','amount'),
    (current_date-1,'NaN'::numeric,'Veterinary','amount'),(current_date-1,'Infinity'::numeric,'Veterinary','amount'),
    (current_date-1,'-Infinity'::numeric,'Veterinary','amount'),(current_date-1,50,null,'category'),
    (current_date-1,50,'','category'),(current_date-1,50,'  ','category')) v(day,amount,category,field) loop
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),f.period_a,q.day,q.amount,q.category,null),
      '22023','invalid_request',q.field,f.period_a);
  end loop;
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,f.owner_op,f.period_a,current_date-1,0,'Veterinary',null),
    '22023','invalid_request','amount',f.period_a); -- Scalar grammar BEFORE historical conflict.
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,null,f.period_a,current_date-1,50,'Veterinary',null),'22023','invalid_request','operation_id',null);
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),null,current_date-1,50,'Veterinary',null),'22023','invalid_request','period_id',null);
  for q in select n,period_id from pg_temp.foundations where n in (2,3,4)
    union all select 5,f.missing_period loop
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),q.period_id,current_date-1,50,'Veterinary',null),
      case q.n when 2 then '22023' when 3 then '23514' else '42501' end,
      case q.n when 2 then 'invalid_request' when 3 then 'closed_period_immutable' else 'forbidden' end,
      case when q.n=2 then 'purpose_id' else 'period_id' end,case when q.n=2 then f.eggs_a else q.period_id end);
  end loop;
  perform set_config('request.jwt.claim.sub',f.editor::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor,'role','authenticated')::text,true);
  perform pg_temp.checked(sql,'22023','operation_payload_conflict','operation_id',f.owner_op);
  reset role;
  for a in select * from (values(f.viewer,'authenticated'),(f.owner_b,'authenticated'),(f.outsider,'authenticated'),
    (null::uuid,'authenticated'),(f.owner_a,'anon')) v(actor,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(a.actor::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',a.actor,'role',a.role_name)::text,true);
    execute format('set local role %I',a.role_name);
    foreach impl in array array[false,true] loop
      perform pg_temp.checked(pg_temp.api_sql(f.farm_a,f.owner_op,f.period_a,current_date-1,50,'Veterinary',null,impl),
        '42501',case when a.role_name='authenticated' then 'forbidden' end,'granja_id',f.farm_a);
    end loop;
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  set local role authenticated;
  perform pg_temp.checked(pg_temp.api_sql(f.farm_b,gen_random_uuid(),f.period_a,current_date-1,0,'',null),'42501','forbidden','granja_id',f.farm_b);
  perform pg_temp.checked('select * from economics_v2.group_period_expenses','42501');
  perform pg_temp.checked('insert into economics_v2.group_period_expenses default values','42501');
  perform pg_temp.checked('update economics_v2.group_period_expenses set note=null where false','42501');
  perform pg_temp.checked('delete from economics_v2.group_period_expenses where false','42501');
  reset role;
  -- Roll back all flag columns and transactional trigger effects, not just the boolean.
  begin
    update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
    set local role authenticated;
    perform pg_temp.checked(sql,'42501','forbidden','granja_id',f.farm_a);
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,f.owner_op,f.period_a,current_date-1,50,'Veterinary',null,true),'42501','forbidden','granja_id',f.farm_a);
    reset role;
    raise exception using errcode='ZR001',message='Restore feature-flag denial probe';
  exception when sqlstate 'ZR001' then null;
  end;
end;
$replay_and_refusals$;

do $historical_absent_fact$
declare f record; r jsonb; before_state jsonb; observed boolean:=false;
begin
  select * into f from targets;
  select result into r from results where actor=f.owner_a;
  before_state:=pg_temp.business_state();
  begin
    -- ADMIN verification only, NOT canonical Expense DELETE or real period closure.
    delete from economics_v2.group_period_expenses where id=(r->>'expense_id')::uuid;
    perform pg_temp.check_true(not exists(select 1 from economics_v2.group_period_expenses
      where id=(r->>'expense_id')::uuid),'actual expense is absent before historical receipt replay');
    set local role authenticated;
    observed:=pg_temp.checked(pg_temp.api_sql(f.farm_a,f.owner_op,f.period_a,current_date-1,50,'Veterinary',null))=r||'{"replayed":true}'::jsonb;
    reset role;
    raise exception using errcode='Z0001',message='Restore absent-expense replay probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(observed and pg_temp.business_state()=before_state,'historical receipt survives missing fact; entire ADMIN deletion restored');
end;
$historical_absent_fact$;

-- Dedicated late fault checks the REAL inserted fact before receipt persistence.
create function pg_temp.fail_late_ledger() returns trigger
language plpgsql security invoker set search_path='' as $$
declare f record; e record; hash text;
begin
  select * into f from pg_temp.targets;
  if new.operation_id<>f.fault_op then return new; end if;
  select * into strict e from economics_v2.group_period_expenses where id=(new.result->>'expense_id')::uuid;
  hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-expense-create.v1',
    'granja_id',f.farm_a,'actor_id',f.owner_a,'operation_id',f.fault_op,'request',jsonb_build_object(
      'action','expense_create','period_id',f.period_a,'occurred_on',current_date-1,'amount',37.5,
      'category','Fault probe','note','Atomic rollback')))::text,'UTF8')),'hex');
  if e.granja_id<>f.farm_a or e.period_id<>f.period_a or e.created_by<>f.owner_a or e.occurred_on<>current_date-1
    or e.amount<>37.5 or e.category<>'Fault probe' or e.note is distinct from 'Atomic rollback'
    or e.created_at is null or e.updated_at is null or new.granja_id<>f.farm_a or new.event_position is not null
    or new.payload_hash is distinct from hash or new.result is distinct from jsonb_build_object(
      'contract_version','group-economics.forward.v3','operation_id',f.fault_op,'expense_id',e.id,
      'period_id',f.period_a,'updated_at',e.updated_at,'replayed',false) then
    raise exception 'Late ledger observer did not find the exact real expense lineage';
  end if;
  raise exception using errcode='ZL001',message='Injected late ledger failure',detail='observed_after_real_expense_insert';
end;
$$;
create trigger expense_create_late_ledger_fault before insert on economics_v2.group_occupancy_operations
  for each row execute function pg_temp.fail_late_ledger();
do $atomic_rollback$
declare f record; before_state jsonb; state text; detail text;
begin
  select * into f from targets;
  before_state:=pg_temp.business_state();
  set local role authenticated;
  begin
    execute pg_temp.api_sql(f.farm_a,f.fault_op,f.period_a,current_date-1,37.5,'Fault probe','Atomic rollback');
  exception when others then get stacked diagnostics state=returned_sqlstate,detail=pg_exception_detail;
  end;
  reset role;
  perform pg_temp.check_true(state='ZL001' and detail='observed_after_real_expense_insert'
    and pg_temp.business_state()=before_state,'real expense INSERT followed by ledger fault rolls back all facts/receipts/fences/sequences');
  update proof set late_ledger_rollback=true;
end;
$atomic_rollback$;

select pg_temp.check_true(pg_temp.business_state(array[owner_op,editor_op])=(select state from baseline),
  'only two actual expenses and receipts added; all sibling/foreign/food/fence/basis/ACL/sequence state unchanged') from targets;
select jsonb_build_object('result','group_economics_forward_group_expenses_create_pass',
  'assertion_count',(select count(*) from assertions),'fixture_ids',jsonb_build_object(
    'scope',(select to_jsonb(t) from targets t),'foundations',(select jsonb_agg(to_jsonb(f)) from foundations f),
    'expenses',(select jsonb_agg(result->'expense_id') from results)),
  'locking_evidence','sequential_only','independent_review','pending','real_closure_proven',false,
  'closed_fixture_kind','synthetic_foundation_without_memberships','group_expense_create_sql_rpc_proven',true,
  'group_expense_read_sql_rpc_proven',true,'expense_insert_ledger_atomic_rollback_proven',(select late_ledger_rollback from proof),
  'group_expense_crud_integrated',false,'canonical_group_expense_api_integrated',false,
  'legacy_expense_guards_integrated',false,'http_transport_proven',false,'production_gateway_integrated',false,
  'all_legacy_mutation_paths_guarded',false,'later_event_backdating_proven',false) evidence;
rollback;
