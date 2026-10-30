begin;

-- HUMAN Sandbox Dashboard, fixture FIRST: preparation is NOT runtime qualification.
-- First actual RPC must fail uncaught with 42883 until the new PUBLIC reader exists.
-- Admin-created facts prove projection only: no expense CRUD, occupancy producer or F5 closure.
-- closed_fixture_kind='synthetic_foundation_without_memberships'; real_closure_proven=false.
-- OPEN-only selectable targets is the technical enumeration choice; CLOSED expenses retain
-- their own target metadata. No new label punctuation, array ordering or history policy.
-- Contract cardinalities: top 6, target 8, expense 13. No metrics/snapshot dependency.
-- Isolate Sandbox: full table/sequence snapshots are sequential evidence, not concurrency proof.
-- ROLLBACK removes transactional setup/observers; issued sequence positions are not rewound.

create temp table ids as select gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor,gen_random_uuid() viewer,gen_random_uuid() outsider,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() farm_empty,
  gen_random_uuid() farm_off,gen_random_uuid() type_a,gen_random_uuid() type_b,
  gen_random_uuid() meat_a,gen_random_uuid() meat_b,gen_random_uuid() eggs_a,
  gen_random_uuid() egg_mixture,gen_random_uuid() egg_expense;
create temp table periods as
select n,gen_random_uuid() period_id,gen_random_uuid() group_id from generate_series(1,6) n;
update periods set group_id=(select group_id from periods where n=1) where n=4;
create temp table assertions(label text not null);
create temp sequence read_dml_attempts;
create temp table watched as
select n.nspname schema_name,c.relname table_name from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where c.relkind in ('r','p') and (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users'));
create temp table sequences as
select n.nspname schema_name,c.relname sequence_name from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity');

create function pg_temp.check_true(ok boolean,label text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if ok is distinct from true then raise exception 'F3 expense READ: %',label; end if;
  insert into pg_temp.assertions values(label);
end;
$$;
-- Trusted TEMP evidence reader only; it never calls the business RPC or writes facts.
create function pg_temp.business_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; v_rows jsonb; state jsonb:='{}';
begin
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r',t.schema_name,t.table_name) into v_rows;
    state:=state||jsonb_build_object(t.schema_name||'.'||t.table_name,v_rows);
  end loop;
  for t in select * from pg_temp.sequences order by schema_name,sequence_name loop
    execute format('select jsonb_build_object(''last_value'',last_value,''is_called'',is_called)
      from %I.%I',t.schema_name,t.sequence_name) into v_rows;
    state:=state||jsonb_build_object(t.schema_name||'.'||t.sequence_name,v_rows);
  end loop;
  select coalesce(jsonb_agg(a order by a::text),'[]'::jsonb) into v_rows from (
    select jsonb_build_array('relation',c.oid,c.relacl) a from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','economics_v2','group_feed_integrity','auth')
    union all select jsonb_build_array('function',p.oid,p.proacl) from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','economics_v2','group_feed_integrity','auth')) acl;
  return state||jsonb_build_object('acl',v_rows);
end;
$$;
create function pg_temp.observe_dml()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  -- Nontransactional TEMP counter also detects an attempted DML caught by the reader.
  perform nextval('pg_temp.read_dml_attempts');
  raise exception 'Expense READ attempted DML: %.% %',tg_table_schema,tg_table_name,tg_op;
end;
$$;
create function pg_temp.checked(statement text,expected_state text default null,
  expected_code text default null) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare before_state jsonb; result jsonb; actual_state text; detail text;
begin
  before_state:=pg_temp.business_state();
  begin execute statement into result;
  exception when others then
    if expected_state is null then raise; end if;
    get stacked diagnostics actual_state=returned_sqlstate,detail=pg_exception_detail;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=before_state,'read/refusal preserves full business state and ACL');
  perform pg_temp.check_true((select not is_called from pg_temp.read_dml_attempts),'no attempted persistent DML');
  if expected_state is null then
    perform pg_temp.check_true(result is not null,'successful reader returns payload');
  else
    perform pg_temp.check_true(actual_state=expected_state,'expected SQLSTATE '||expected_state);
    if expected_code is not null then
      perform pg_temp.check_true(detail::jsonb=jsonb_build_object(
        'contract_version','group-economics.forward.v3','code',expected_code,
        'field','granja_id','entity_id',null),'same exact typed farm error grammar as Group reader');
    end if;
  end if;
  return result;
end;
$$;

select pg_temp.check_true(not exists(select 1 from auth.users
  where raw_user_meta_data->>'fixture'='f3-group-expenses-read')
  and not exists(select 1 from public.granjas where nombre like 'F3 expense READ %'),'empty marker baseline');
-- Existing auth/farm triggers create profiles and owner memberships normally.
insert into auth.users(id,aud,role,raw_user_meta_data,created_at,updated_at)
select actor,'authenticated','authenticated','{"fixture":"f3-group-expenses-read"}',now(),now()
from ids cross join lateral unnest(array[owner_a,owner_b,editor,viewer,outsider]) actor;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm,owner,'F3 expense READ '||label,owner from ids cross join lateral
  (values(farm_a,owner_a,'A'),(farm_b,owner_b,'B'),
    (farm_empty,owner_a,'empty'),(farm_off,owner_a,'off')) v(farm,owner,label);
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor,'editor'::public.rol_miembro from ids
union all select farm_a,viewer,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm,enabled from ids cross join lateral
  (values(farm_a,true),(farm_b,true),(farm_empty,true),(farm_off,false)) v(farm,enabled);
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F3 expense type A',owner_a from ids
union all select type_b,farm_b,'F3 expense type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select purpose,farm,'F3 expense '||code,code,owner from ids cross join lateral
  (values(meat_a,farm_a,'carne',owner_a),(meat_b,farm_b,'carne',owner_b),
    (eggs_a,farm_a,'postura',owner_a)) v(purpose,farm,code,owner);
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_id,case when n=5 then farm_b else farm_a end,
  case when n=5 then type_b else type_a end,'F3 expense Group '||n,
  case when n=5 then owner_b else owner_a end from periods cross join ids where n<>4;
-- Closed period first, then the same Group's new OPEN period: disjoint [start,end) spans.
do $closed_foundation$
declare start_pos bigint; end_pos bigint;
begin
  start_pos:=nextval('economics_v2.group_economics_event_position_seq');
  end_pos:=nextval('economics_v2.group_economics_event_position_seq');
  insert into economics_v2.group_occupancy_periods
    (id,granja_id,group_id,purpose_id,starts_on,closed_on,start_position,end_position)
  select period_id,farm_a,group_id,meat_a,current_date-10,current_date-5,start_pos,end_pos
  from periods cross join ids where n=4;
end;
$closed_foundation$;
insert into economics_v2.group_occupancy_periods(id,granja_id,group_id,purpose_id,starts_on,start_position)
select period_id,case when n=5 then farm_b else farm_a end,group_id,
  case when n=5 then meat_b when n=6 then eggs_a else meat_a end,current_date-2,
  nextval('economics_v2.group_economics_event_position_seq')
from periods cross join ids where n<>4;
insert into economics_v2.group_period_expenses
  (granja_id,period_id,occurred_on,amount,category,note,created_by,created_at,updated_at)
select p.granja_id,p.id,case when f.n=4 then current_date-8 else current_date-1 end,
  v.amount,v.category,v.note,case when v.n=5 then s.owner_b when v.k=2 then s.editor else s.owner_a end,
  now()-interval '2 hours',now()-interval '1 hour'
from ids s cross join (values
  (1,1,50::numeric,'Veterinary',null::text),(2,1,25,'Maintenance','Owned open expense'),
  (3,2,12.5,'Supplies','Another Group'),(4,4,10,'Veterinary','Closed history'),
  (5,5,999,'Supplies','Foreign farm'),(6,6,700,'Supplies','Posture exclusion')) v(k,n,amount,category,note)
join periods f on f.n=v.n join economics_v2.group_occupancy_periods p on p.id=f.period_id;
-- Storage permits posture expenses (period FK, no purpose CHECK); this is an exclusion probe.
-- A real legacy egg row is also seeded, not read through or reclassified by the new API.
insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
select egg_mixture,farm_a,group_id,current_date-1,owner_a from ids cross join periods where n=6;
insert into public.legacy_mixture_expenses(id,mixture_id,granja_id,occurred_on,amount,category,created_by)
select egg_expense,egg_mixture,farm_a,current_date-1,333,'Egg supplies',owner_a from ids;
set constraints all immediate;

-- Expected rows are copied as ADMIN before auth calls; no private table SELECT is granted.
create temp table expected_periods as
select f.n,p.*,g.nombre group_name from periods f
join economics_v2.group_occupancy_periods p on p.id=f.period_id
join public.grupos g on g.id=p.group_id and g.granja_id=p.granja_id;
create temp table expected_expenses as
select e.* from economics_v2.group_period_expenses e join periods f on f.period_id=e.period_id;
create temp table baseline as select pg_temp.business_state() state;
grant select on ids,periods,expected_periods,expected_expenses,baseline to authenticated;
grant select on sequence read_dml_attempts to authenticated;
grant insert,select on assertions to authenticated;
revoke all on function pg_temp.business_state() from public,anon;
grant execute on function pg_temp.business_state() to authenticated;
do $observers$
declare t record;
begin
  for t in select * from watched loop
    execute format('create trigger f3_expense_read_observer before insert or update or delete or truncate
      on %I.%I for each statement execute function pg_temp.observe_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;

create function pg_temp.check_payload(payload jsonb,farm uuid,reader_role text)
returns void language plpgsql security invoker set search_path='' as $$
declare item jsonb; v_period record; v_expense record; editable boolean:=reader_role in ('owner','editor');
begin
  perform pg_temp.check_true((select array_agg(k order by k) from jsonb_object_keys(payload) k)
    =array['can_edit','contract_version','expenses','granja_id','role','targets'],'exact6 top keys');
  perform pg_temp.check_true(payload->>'contract_version'='group-economics.forward.v3'
    and payload->'granja_id'=to_jsonb(farm) and payload->>'role'=reader_role
    and payload->'can_edit'=to_jsonb(editable),'contract, farm and actual reader capability');
  perform pg_temp.check_true(jsonb_typeof(payload->'targets')='array'
    and jsonb_typeof(payload->'expenses')='array','arrays, not null or omitted');
  perform pg_temp.check_true((select array_agg(i->>'target_id' order by i->>'target_id')
    from jsonb_array_elements(payload->'targets') i) is not distinct from
    (select array_agg(id::text order by id::text) from pg_temp.expected_periods
      where granja_id=farm and n in (1,2,3,5)),'complete unique OPEN meat targets, including empty Group');
  perform pg_temp.check_true((select array_agg(i->>'expense_id' order by i->>'expense_id')
    from jsonb_array_elements(payload->'expenses') i) is not distinct from
    (select array_agg(e.id::text order by e.id::text) from pg_temp.expected_expenses e
      join pg_temp.expected_periods p on p.id=e.period_id
      where e.granja_id=farm and p.n<>6),'exact expense multiset: closed included, posture/legacy/foreign excluded');
  for item in select value from jsonb_array_elements(payload->'targets') loop
    select * into strict v_period from pg_temp.expected_periods where id=(item->>'target_id')::uuid;
    perform pg_temp.check_true((select array_agg(k order by k) from jsonb_object_keys(item) k)
      =array['can_mutate','closed_on','stable_key','starts_on','status','target_id','target_kind','target_label'],
      'exact8 target keys, no compatibility aliases');
    perform pg_temp.check_true(item->>'target_kind'='group_period'
      and item->>'stable_key'='group-period:'||v_period.id and item->'starts_on'=to_jsonb(v_period.starts_on)
      and item->'closed_on'='null'::jsonb and item->>'status'='open'
      and v_period.closed_on is null and v_period.end_position is null
      and item->'can_mutate'=to_jsonb(editable),'OPEN target binding, dates, stable key and role');
    perform pg_temp.check_true(btrim(item->>'target_label')<>''
      and strpos(item->>'target_label',v_period.group_name)>0,'meaningful Group target label, format unspecified');
  end loop;
  for item in select value from jsonb_array_elements(payload->'expenses') loop
    select * into strict v_expense from pg_temp.expected_expenses where id=(item->>'expense_id')::uuid;
    select * into strict v_period from pg_temp.expected_periods where id=v_expense.period_id;
    perform pg_temp.check_true((select array_agg(k order by k) from jsonb_object_keys(item) k)
      =array['amount','can_mutate','category','created_at','created_by','expense_id','note','occurred_on',
        'stable_target_key','target_id','target_kind','target_label','updated_at'],'exact13 expense keys');
    perform pg_temp.check_true(item->>'target_kind'='group_period' and item->'target_id'=to_jsonb(v_expense.period_id)
      and item->>'stable_target_key'='group-period:'||v_expense.period_id
      and jsonb_typeof(item->'amount')='number' and (item->>'amount')::numeric=v_expense.amount
      and item->'occurred_on'=to_jsonb(v_expense.occurred_on) and item->'category'=to_jsonb(v_expense.category)
      and item->'note'=coalesce(to_jsonb(v_expense.note),'null'::jsonb)
      and item->'created_by'=to_jsonb(v_expense.created_by)
      and (item->>'created_at')::timestamptz=v_expense.created_at
      and (item->>'updated_at')::timestamptz=v_expense.updated_at
      and item->'can_mutate'=to_jsonb(editable and v_period.end_position is null),'source fields preserved, closed/viewer immutable');
    perform pg_temp.check_true(btrim(item->>'target_label')<>''
      and strpos(item->>'target_label',v_period.group_name)>0,'embedded expense Group label, including closed history');
    perform pg_temp.check_true(not exists(select 1 from jsonb_array_elements(payload->'targets') t
      where t->'target_id'=item->'target_id' and t->'target_label' is distinct from item->'target_label'),
      'expense and selectable target labels agree for same period');
  end loop;
end;
$$;

do $first_public_call$
declare s record; result jsonb;
begin
  select * into s from ids;
  perform set_config('request.jwt.claim.sub',s.owner_a::text,true);
  set local role authenticated;
  -- Deliberately uncaught, named UUID argument; no absent regprocedure preflight or proxy.
  result:=public.list_group_finance_expenses_v1(p_granja_id=>s.farm_a::uuid);
  perform pg_temp.check_true(pg_temp.business_state()=(select state from pg_temp.baseline)
    and (select not is_called from pg_temp.read_dml_attempts),'first owner PUBLIC call is pure READ');
  perform pg_temp.check_payload(result,s.farm_a,'owner');
  reset role;
end;
$first_public_call$;

-- Metadata is checked ONLY AFTER the real first call, never instead of first RED.
do $metadata$
declare f record;
begin
  perform pg_temp.check_true((select count(*)=2 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='public' and p.proname='list_group_finance_expenses_v1')
      or (n.nspname='economics_v2' and p.proname='read_group_finance_expenses_impl')),'no overload/default alias escape');
  for f in select p.*,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.oid in ('public.list_group_finance_expenses_v1(uuid)'::regprocedure,
      'economics_v2.read_group_finance_expenses_impl(uuid)'::regprocedure) loop
    perform pg_temp.check_true(f.pronargs=1 and f.pronargdefaults=0 and f.proargnames=array['p_granja_id']
      and f.proargtypes[0]='uuid'::regtype and f.proargmodes is null
      and f.prorettype='jsonb'::regtype and not f.proretset and f.prokind='f'
      and f.provolatile='s' and f.prosecdef=(f.nspname='economics_v2')
      and f.proowner='postgres'::regrole and f.proconfig @> array['search_path=""']
      and has_function_privilege('authenticated',f.oid,'execute')
      and not has_function_privilege('anon',f.oid,'execute')
      and not exists(select 1 from aclexplode(coalesce(f.proacl,acldefault('f',f.proowner))) a
        where a.privilege_type='EXECUTE' and a.grantee not in (f.proowner,'authenticated'::regrole)),
      'one required named UUID, jsonb STABLE, postgres owner, empty path, auth-only invoker/definer');
  end loop;
  perform pg_temp.check_true(not has_table_privilege('authenticated','economics_v2.group_period_expenses','select')
    and not has_table_privilege('authenticated','economics_v2.group_occupancy_periods','select'),
    'no raw private SELECT capability added');
end;
$metadata$;

do $roles_and_errors$
declare s record; a record; endpoint text; result jsonb; public_result jsonb; before_state jsonb; state text;
begin
  select * into s from ids;
  set local role authenticated;
  for a in select * from (values(s.owner_a,'owner'),(s.editor,'editor'),(s.viewer,'viewer')) v(actor,reader_role) loop
    perform set_config('request.jwt.claim.sub',a.actor::text,true);
    public_result:=pg_temp.checked(format('select public.list_group_finance_expenses_v1(p_granja_id=>%L::uuid)',s.farm_a));
    perform pg_temp.check_payload(public_result,s.farm_a,a.reader_role);
    result:=pg_temp.checked(format('select economics_v2.read_group_finance_expenses_impl(p_granja_id=>%L::uuid)',s.farm_a));
    perform pg_temp.check_payload(result,s.farm_a,a.reader_role);
    -- Compare payloads as sets, not array positions: ordering is not a public contract.
    perform pg_temp.check_true((result-'targets'-'expenses')=(public_result-'targets'-'expenses')
      and not exists((select value from jsonb_array_elements(result->'targets')
        except select value from jsonb_array_elements(public_result->'targets'))
        union all (select value from jsonb_array_elements(result->'expenses')
        except select value from jsonb_array_elements(public_result->'expenses'))),'guarded direct implementation has same payload');
  end loop;
  foreach endpoint in array array['public.list_group_finance_expenses_v1','economics_v2.read_group_finance_expenses_impl'] loop
    for a in select unnest(array[s.owner_b,s.outsider]) actor loop
      perform set_config('request.jwt.claim.sub',a.actor::text,true);
      perform pg_temp.checked(format('select %s(p_granja_id=>%L::uuid)',endpoint,s.farm_a),'42501','forbidden');
    end loop;
    perform set_config('request.jwt.claim.sub','',true);
    perform pg_temp.checked(format('select %s(p_granja_id=>%L::uuid)',endpoint,s.farm_a),'42501','forbidden');
    perform set_config('request.jwt.claim.sub',s.owner_a::text,true);
    perform pg_temp.checked(format('select %s(p_granja_id=>%L::uuid)',endpoint,s.farm_b),'42501','forbidden');
    perform pg_temp.checked(format('select %s(p_granja_id=>%L::uuid)',endpoint,s.farm_off),'42501','forbidden');
    perform pg_temp.checked(format('select %s(p_granja_id=>null::uuid)',endpoint),'22023','invalid_request');
    result:=pg_temp.checked(format('select %s(p_granja_id=>%L::uuid)',endpoint,s.farm_empty));
    perform pg_temp.check_payload(result,s.farm_empty,'owner');
    perform pg_temp.check_true(result->'targets'='[]'::jsonb and result->'expenses'='[]'::jsonb,'authorized empty farm succeeds');
    perform set_config('request.jwt.claim.sub',s.owner_b::text,true);
    result:=pg_temp.checked(format('select %s(p_granja_id=>%L::uuid)',endpoint,s.farm_b));
    perform pg_temp.check_payload(result,s.farm_b,'owner');
  end loop;
  perform pg_temp.checked('select * from economics_v2.group_period_expenses','42501');
  perform pg_temp.checked('select * from economics_v2.group_occupancy_periods','42501');
  reset role;
  perform set_config('request.jwt.claim.sub',s.owner_a::text,true);
  before_state:=pg_temp.business_state();
  foreach endpoint in array array['public.list_group_finance_expenses_v1','economics_v2.read_group_finance_expenses_impl'] loop
    state:=null;
    set local role anon;
    begin execute format('select %s(p_granja_id=>%L::uuid)',endpoint,s.farm_a);
    exception when others then get stacked diagnostics state=returned_sqlstate;
    end;
    reset role;
    perform pg_temp.check_true(state='42501','anon denied by function ACL even with authenticated subject claim');
  end loop;
  perform pg_temp.check_true(pg_temp.business_state()=before_state,'anon refusals do not mutate business state');
end;
$roles_and_errors$;

select pg_temp.check_true(pg_temp.business_state()=(select state from baseline)
  and (select not is_called from read_dml_attempts),'all calls preserve baseline, fences, facts, eggs, ledgers, sequences and ACL');
select jsonb_build_object('result','group_economics_forward_group_expenses_read_pass',
  'assertion_count',(select count(*) from assertions),'fixture_ids',jsonb_build_object(
    'scope',(select to_jsonb(i) from ids i),'periods',(select jsonb_agg(to_jsonb(p)) from periods p),
    'expense_ids',(select jsonb_agg(id order by id) from expected_expenses)),
  'locking_evidence','sequential_only','independent_review','pending','real_closure_proven',false,
  'closed_fixture_kind','synthetic_foundation_without_memberships','group_expense_read_sql_rpc_proven',true,
  'group_expense_crud_integrated',false,'legacy_expense_guards_integrated',false,'http_transport_proven',false,
  'production_gateway_integrated',false,'canonical_group_expense_api_integrated',false,
  'all_legacy_mutation_paths_guarded',false) as evidence;
rollback;
