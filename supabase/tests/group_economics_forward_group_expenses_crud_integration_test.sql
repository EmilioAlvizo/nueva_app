begin;

-- HUMAN execution only: Sandbox xagnnkqqtdtvadaseubc. Authored, not runtime evidence.
-- Installed public SQL RPCs must genuinely succeed; no manufactured missing-function RED.
-- Admission below is SETUP, not public occupancy or real closure proof. No expense fact DML.
-- All expense creation, including controls, uses authenticated public CREATE.
-- Rollback removes transactional setup/observers; setup sequence increments are NOT rewound.
create temp table ids as select gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor,gen_random_uuid() viewer,gen_random_uuid() outsider,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,
  gen_random_uuid() type_b,gen_random_uuid() meat_a,gen_random_uuid() meat_b,
  gen_random_uuid() create_op,gen_random_uuid() update_op,gen_random_uuid() delete_op;
create temp table foundations as select v_n n,gen_random_uuid() group_id,
  gen_random_uuid() animal_id,gen_random_uuid() entry_op,gen_random_uuid() control_op,
  null::uuid period_id from generate_series(1,3) v_n;
-- 1 primary, 2 same-farm sibling, 3 foreign; all genuinely admitted OPEN meat periods.
create temp table assertions(label text not null);
create temp table results(stage text primary key,operation_id uuid unique,result jsonb not null);
create temp table reads(stage text primary key,result jsonb not null);
create temp table requests(stage text primary key,statement text not null);
create temp table baseline(state jsonb not null);
create temp sequence dml_attempts;
grant insert on assertions to authenticated;
create temp table watched as select v_ns.nspname schema_name,v_c.relname table_name
  from pg_class v_c join pg_namespace v_ns on v_ns.oid=v_c.relnamespace
  where v_c.relkind in ('r','p') and (v_ns.nspname in ('public','economics_v2','group_feed_integrity')
    or (v_ns.nspname='auth' and v_c.relname='users'));
create temp table sequences as select v_ns.nspname schema_name,v_c.relname sequence_name
  from pg_class v_c join pg_namespace v_ns on v_ns.oid=v_c.relnamespace
  where v_c.relkind='S' and v_ns.nspname in ('public','economics_v2','group_feed_integrity');
create function pg_temp.check_true(v_ok boolean,v_label text) returns void
language plpgsql security invoker set search_path='' as $$
begin
  if v_ok is distinct from true then raise exception 'Expense CRUD integration: %',v_label; end if;
  insert into pg_temp.assertions values(v_label);
end;
$$;
-- Privileged read-only evidence, NEVER a proxy for a business invocation.
-- Final normalization excludes only the three exact main operation IDs in farm A.
-- No expense exclusions: CREATE -> UPDATE -> DELETE must leave zero net expense facts.
create function pg_temp.business_state(v_ops uuid[] default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_table record; v_rows jsonb; v_state jsonb:='{}'; v_filter text;
begin
  for v_table in select * from pg_temp.watched order by schema_name,table_name loop
    v_filter:='';
    if v_table.schema_name='economics_v2' and v_table.table_name='group_occupancy_operations' then
      v_filter:=' where not (r.granja_id=$2 and r.operation_id=any($1))';
    end if;
    execute format('select coalesce(jsonb_agg(v_row order by v_row::text),''[]''::jsonb)
      from (select to_jsonb(r) v_row from %I.%I r%s) v_s',
      v_table.schema_name,v_table.table_name,v_filter)
      into v_rows using v_ops,(select farm_a from pg_temp.ids);
    v_state:=v_state||jsonb_build_object(v_table.schema_name||'.'||v_table.table_name,v_rows);
  end loop;
  for v_table in select * from pg_temp.sequences loop
    execute format('select jsonb_build_object(''last_value'',v_s.last_value,''log_cnt'',v_s.log_cnt,''is_called'',v_s.is_called)
      from %I.%I v_s',v_table.schema_name,v_table.sequence_name) into v_rows;
    v_state:=v_state||jsonb_build_object(v_table.schema_name||'.'||v_table.sequence_name,v_rows);
  end loop;
  select coalesce(jsonb_agg(v_a order by v_a::text),'[]'::jsonb) into v_rows from (
    select jsonb_build_array('relation',v_c.oid,v_c.relacl) v_a from pg_class v_c
      join pg_namespace v_ns on v_ns.oid=v_c.relnamespace
      where v_ns.nspname in ('public','economics_v2','group_feed_integrity','auth')
    union all select jsonb_build_array('function',v_proc.oid,v_proc.proacl) from pg_proc v_proc
      join pg_namespace v_ns on v_ns.oid=v_proc.pronamespace
      where v_ns.nspname in ('public','economics_v2','group_feed_integrity','auth')) v_acl;
  return v_state||jsonb_build_object('acl',v_rows);
end;
$$;
create function pg_temp.observe_dml() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('expense_crud.observe',true)='on'
    or (tg_table_schema='economics_v2' and tg_table_name='group_feed_api_completions') then
    perform nextval('pg_temp.dml_attempts');
    raise exception 'Expense CRUD read/replay/refusal or feed sidecar DML: %.% %',tg_table_schema,tg_table_name,tg_op;
  end if;
  return null;
end;
$$;
-- Invoker executes the PUBLIC statement under the caller's actual SQL role and JWT.
-- A nontransactional counter detects even attempted DML whose exception was caught.
create function pg_temp.checked(v_statement text,v_expected_state text default null) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_counter jsonb; v_result jsonb; v_sqlstate text;
begin
  perform pg_temp.check_true(current_user='authenticated','checked call uses authenticated SQL role');
  v_before:=pg_temp.business_state();
  select jsonb_build_object('last_value',v_s.last_value,'log_cnt',v_s.log_cnt,'is_called',v_s.is_called)
    into v_counter from pg_temp.dml_attempts v_s;
  perform set_config('expense_crud.observe','on',true);
  begin execute v_statement into v_result;
  exception when others then
    if v_expected_state is null then raise; end if;
    get stacked diagnostics v_sqlstate=returned_sqlstate;
  end;
  perform set_config('expense_crud.observe','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'read/replay/refusal preserves full business, ACL and sequences');
  perform pg_temp.check_true((select jsonb_build_object('last_value',v_s.last_value,'log_cnt',v_s.log_cnt,'is_called',v_s.is_called)=v_counter
    from pg_temp.dml_attempts v_s),'no attempted DML, including zero-row or caught attempts');
  if v_expected_state is null then
    perform pg_temp.check_true(v_result is not null,'nonempty successful read/replay');
  else
    perform pg_temp.check_true(v_sqlstate=v_expected_state,'expected refusal SQLSTATE '||v_expected_state);
  end if;
  return v_result;
end;
$$;
create function pg_temp.actor(v_actor uuid) returns void
language plpgsql security invoker set search_path='' as $$
begin
  perform set_config('request.jwt.claim.sub',v_actor::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_actor,'role','authenticated')::text,true);
end;
$$;
-- Contract uses target_kind (not kind), matching the installed READ projection.
create function pg_temp.validate_read(v_payload jsonb,v_role text,v_main uuid default null) returns void
language plpgsql security invoker set search_path='' as $$
declare v_ids record; v_item jsonb; v_target jsonb; v_expected uuid[]; v_actual uuid[];
begin
  select * into v_ids from pg_temp.ids;
  perform pg_temp.check_true((select count(*)=6 from jsonb_object_keys(v_payload))
    and v_payload ?& array['contract_version','granja_id','role','can_edit','targets','expenses']
    and v_payload->>'contract_version'='group-economics.forward.v3'
    and v_payload->>'granja_id'=v_ids.farm_a::text and v_payload->>'role'=v_role
    and v_payload->'can_edit'=to_jsonb(v_role in ('owner','editor')),'exact6 READ envelope and current role');
  perform pg_temp.check_true(jsonb_array_length(v_payload->'targets')=2,'exactly primary and sibling OPEN selectable targets');
  for v_target in select value from jsonb_array_elements(v_payload->'targets') loop
    perform pg_temp.check_true((select count(*)=8 from jsonb_object_keys(v_target))
      and v_target ?& array['target_kind','target_id','stable_key','target_label','starts_on','closed_on','status','can_mutate']
      and v_target->>'target_kind'='group_period' and v_target->>'status'='open'
      and v_target->'closed_on'='null'::jsonb and v_target->>'stable_key'='group-period:'||(v_target->>'target_id')
      and v_target->'can_mutate'=to_jsonb(v_role in ('owner','editor'))
      and exists(select 1 from pg_temp.foundations v_f where v_f.n in (1,2) and v_f.period_id::text=v_target->>'target_id'),
      'exact8 target, stable key, OPEN and current mutability');
  end loop;
  select array_agg(v_e order by v_e) into v_expected from (
    select (v_r.result->>'expense_id')::uuid v_e from pg_temp.results v_r where v_r.stage='sibling'
    union all select v_main where v_main is not null) v_expected_rows;
  select array_agg((value->>'expense_id')::uuid order by (value->>'expense_id')::uuid)
    into v_actual from jsonb_array_elements(v_payload->'expenses');
  perform pg_temp.check_true(v_actual=v_expected,'complete same-farm list; foreign excluded; main presence matches stage');
  for v_item in select value from jsonb_array_elements(v_payload->'expenses') loop
    select value into strict v_target from jsonb_array_elements(v_payload->'targets')
      where value->>'target_id'=v_item->>'target_id';
    perform pg_temp.check_true((select count(*)=13 from jsonb_object_keys(v_item))
      and v_item ?& array['expense_id','target_kind','target_id','stable_target_key','target_label','occurred_on',
        'amount','category','note','created_by','created_at','updated_at','can_mutate']
      and v_item->>'target_kind'='group_period' and v_item->'stable_target_key'=v_target->'stable_key'
      and v_item->'target_label'=v_target->'target_label'
      and v_item->'can_mutate'=to_jsonb(v_role in ('owner','editor')),'exact13 expense linked to stable target and current mutability');
  end loop;
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select v_actor,'authenticated','authenticated','{"fixture":"group-expenses-crud-integration"}'::jsonb
  from ids cross join lateral unnest(array[owner_a,owner_b,editor,viewer,outsider]) v_actor;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Expense CRUD A',owner_a from ids
union all select farm_b,owner_b,'Expense CRUD B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor,'editor'::public.rol_miembro from ids
union all select farm_a,viewer,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'CRUD type A',owner_a from ids union all select type_b,farm_b,'CRUD type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'CRUD meat A','carne',owner_a from ids
union all select meat_b,farm_b,'CRUD meat B','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_id,case when n=3 then farm_b else farm_a end,case when n=3 then type_b else type_a end,
  'CRUD Group '||n,case when n=3 then owner_b else owner_a end from foundations cross join ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,created_by)
select animal_id,case when n=3 then farm_b else farm_a end,case when n=3 then type_b else type_a end,group_id,
  case when n=3 then meat_b else meat_a end,current_date-7,300,case when n=3 then owner_b else owner_a end
  from foundations cross join ids;
do $setup$
declare v_ids record; v_f record; v_period uuid; v_result jsonb;
begin
  select * into v_ids from ids;
  execute format('grant usage on schema %I to authenticated',pg_my_temp_schema()::regnamespace::text);
  for v_f in select * from foundations order by n loop
    perform pg_temp.actor(case when v_f.n=3 then v_ids.owner_b else v_ids.owner_a end);
    -- Private foundation SETUP only: acquisition 300, not public occupancy integration.
    v_period:=(economics_v2.enter_group_meat_initial(
      case when v_f.n=3 then v_ids.farm_b else v_ids.farm_a end,v_f.entry_op,v_f.animal_id,current_date-4,
      v_f.group_id,case when v_f.n=3 then v_ids.meat_b else v_ids.meat_a end,'{}')->>'destination_period_id')::uuid;
    update foundations set period_id=v_period where n=v_f.n;
    if v_f.n<>1 then
      set local role authenticated;
      v_result:=public.create_group_finance_expense_v1(
        p_granja_id=>case when v_f.n=3 then v_ids.farm_b else v_ids.farm_a end,
        p_operation_id=>v_f.control_op,p_period_id=>v_period,p_occurred_on=>current_date-2,
        p_amount=>10,p_category=>'Control',p_note=>null);
      perform pg_temp.check_true(current_user='authenticated','control expense created through real authenticated public API');
      reset role;
      insert into results values(case when v_f.n=3 then 'foreign' else 'sibling' end,v_f.control_op,v_result);
    end if;
  end loop;
end;
$setup$;
set constraints all immediate;
grant select on ids,foundations,results,requests,reads to authenticated;
grant insert on assertions,results,requests,reads to authenticated;
grant select,usage on sequence dml_attempts to authenticated;
do $observers$
declare v_table record;
begin
  for v_table in select * from watched loop
    execute format('create trigger expense_crud_statement_observer before insert or update or delete or truncate
      on %I.%I for each statement execute function pg_temp.observe_dml()',v_table.schema_name,v_table.table_name);
  end loop;
end;
$observers$;
insert into baseline select pg_temp.business_state();

do $integrated_chain$
declare v_ids record; v_period uuid; v_sibling_period uuid; v_read_sql text;
  v_create_sql text; v_update_sql text; v_delete_sql text; v_create jsonb; v_update jsonb; v_delete jsonb;
  v_payload jsonb; v_first jsonb; v_current jsonb; v_expense uuid; v_metrics jsonb; v_probe record; v_receipt record;
begin
  select * into v_ids from ids;
  select period_id into strict v_period from foundations where n=1;
  select period_id into strict v_sibling_period from foundations where n=2;
  v_metrics:=economics_v2.calculate_group_period_live_metrics(v_ids.farm_a,v_period);
  perform pg_temp.check_true((v_metrics->>'acquisition_cost')::numeric=300
    and (v_metrics->>'direct_expense_total')::numeric=0 and (v_metrics->>'total_cost')::numeric=300,'initial primary metrics 300; API-created controls are independent');
  v_read_sql:=format('select public.list_group_finance_expenses_v1(p_granja_id=>%L::uuid)',v_ids.farm_a);
  perform pg_temp.actor(v_ids.owner_a);
  set local role authenticated;
  v_payload:=pg_temp.checked(v_read_sql);
  perform pg_temp.validate_read(v_payload,'owner');
  insert into reads values('initial',v_payload);
  v_create_sql:=format('select public.create_group_finance_expense_v1(p_granja_id=>%L::uuid,p_operation_id=>%L::uuid,
    p_period_id=>%L::uuid,p_occurred_on=>%L::date,p_amount=>50::numeric,p_category=>%L::text,p_note=>%L::text)',
    v_ids.farm_a,v_ids.create_op,v_period,current_date-2,' Veterinary ',E'  Opaque\noriginal  ');
  execute v_create_sql into v_create;
  v_expense:=(v_create->>'expense_id')::uuid;
  perform pg_temp.check_true(current_user='authenticated' and v_expense is not null
    and isfinite((v_create->>'updated_at')::timestamptz)
    and v_create=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',v_ids.create_op,
      'expense_id',v_expense,'period_id',v_period,'updated_at',v_create->'updated_at','replayed',false),'CREATE exact6 server identity/version');
  insert into results values('create',v_ids.create_op,v_create);
  insert into requests values('create',v_create_sql);
  v_payload:=pg_temp.checked(v_read_sql);
  perform pg_temp.validate_read(v_payload,'owner',v_expense);
  insert into reads values('created',v_payload);
  select value into strict v_first from jsonb_array_elements(v_payload->'expenses') where value->>'expense_id'=v_expense::text;
  perform pg_temp.check_true(v_first->>'target_id'=v_period::text
    and v_first->'updated_at'=v_create->'updated_at' and v_first->'created_at'=v_create->'updated_at'
    and v_first->>'created_by'=v_ids.owner_a::text and (v_first->>'amount')::numeric=50
    and v_first->>'category'=' Veterinary ' and v_first->>'note'=E'  Opaque\noriginal  '
    and (v_first->>'occurred_on')::date=current_date-2,'READ carries CREATE identity, date, opaque text and server token');
  reset role;
  v_metrics:=economics_v2.calculate_group_period_live_metrics(v_ids.farm_a,v_period);
  perform pg_temp.check_true((v_metrics->>'acquisition_cost')::numeric=300
    and (v_metrics->>'direct_expense_total')::numeric=50 and (v_metrics->>'total_cost')::numeric=350,'CREATE metrics 300 + 50 = 350');

  -- UPDATE is a different authorized actor; its expected token is the CREATE response.
  perform pg_temp.actor(v_ids.editor);
  set local role authenticated;
  v_update_sql:=format('select public.update_group_finance_expense_v1(p_granja_id=>%L::uuid,p_operation_id=>%L::uuid,
    p_expense_id=>%L::uuid,p_period_id=>%L::uuid,p_expected_updated_at=>%L::timestamptz,p_occurred_on=>%L::date,
    p_amount=>75::numeric,p_category=>%L::text,p_note=>null::text)',
    v_ids.farm_a,v_ids.update_op,v_expense,v_period,v_create->>'updated_at',current_date-1,' Replacement ');
  execute v_update_sql into v_update;
  perform pg_temp.check_true(current_user='authenticated' and v_update=jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_id',v_ids.update_op,'expense_id',v_expense,
    'period_id',v_period,'updated_at',v_update->'updated_at','replayed',false)
    and isfinite((v_update->>'updated_at')::timestamptz)
    and (v_update->>'updated_at')::timestamptz>(v_create->>'updated_at')::timestamptz,'editor UPDATE exact6 advances returned CREATE version');
  insert into results values('update',v_ids.update_op,v_update);
  insert into requests values('update',v_update_sql);
  v_payload:=pg_temp.checked(v_read_sql);
  perform pg_temp.validate_read(v_payload,'editor',v_expense);
  insert into reads values('updated',v_payload);
  select value into strict v_current from jsonb_array_elements(v_payload->'expenses') where value->>'expense_id'=v_expense::text;
  perform pg_temp.check_true(v_current-'occurred_on'-'amount'-'category'-'note'-'updated_at'
    =v_first-'occurred_on'-'amount'-'category'-'note'-'updated_at'
    and (v_current->>'amount')::numeric=75 and v_current->>'category'=' Replacement '
    and v_current->'note'='null'::jsonb and (v_current->>'occurred_on')::date=current_date-1
    and v_current->'updated_at'=v_update->'updated_at','READ preserves identity/creator/created_at/target; replaces fields and nullable opaque note');
  reset role;
  v_metrics:=economics_v2.calculate_group_period_live_metrics(v_ids.farm_a,v_period);
  perform pg_temp.check_true((v_metrics->>'acquisition_cost')::numeric=300
    and (v_metrics->>'direct_expense_total')::numeric=75 and (v_metrics->>'total_cost')::numeric=375,'UPDATE metrics 300 + 75 = 375');

  perform pg_temp.actor(v_ids.owner_a);
  set local role authenticated;
  perform pg_temp.check_true(pg_temp.checked(v_create_sql)=v_create||'{"replayed":true}'::jsonb,'CREATE replay after UPDATE returns original receipt/version');
  -- Original actor owns each replay; another writer must conflict on the same operation.
  perform pg_temp.checked(v_update_sql,'22023');
  v_delete_sql:=format('select public.delete_group_finance_expense_v1(p_granja_id=>%L::uuid,p_operation_id=>%L::uuid,
    p_expense_id=>%L::uuid,p_period_id=>%L::uuid,p_expected_updated_at=>%L::timestamptz)',
    v_ids.farm_a,v_ids.delete_op,v_expense,v_period,v_update->>'updated_at');
  -- Cross-domain operation collisions, old tokens and wrong pairing cannot touch facts.
  perform pg_temp.checked(replace(v_update_sql,v_ids.update_op::text,v_ids.create_op::text),'22023');
  perform pg_temp.checked(replace(v_delete_sql,v_ids.delete_op::text,v_ids.create_op::text),'22023');
  perform pg_temp.checked(replace(v_create_sql,v_ids.create_op::text,v_ids.update_op::text),'22023');
  perform pg_temp.checked(replace(v_update_sql,v_ids.update_op::text,gen_random_uuid()::text),'40001');
  perform pg_temp.checked(replace(replace(v_delete_sql,v_ids.delete_op::text,gen_random_uuid()::text),
    v_update->>'updated_at',v_create->>'updated_at'),'40001');
  perform pg_temp.checked(replace(replace(v_delete_sql,v_ids.delete_op::text,gen_random_uuid()::text),
    v_period::text,v_sibling_period::text),'42501');
  perform pg_temp.validate_read(pg_temp.checked(v_read_sql),'owner',v_expense);
  reset role;
  perform pg_temp.actor(v_ids.viewer);
  set local role authenticated;
  v_payload:=pg_temp.checked(v_read_sql);
  perform pg_temp.validate_read(v_payload,'viewer',v_expense);
  insert into reads values('viewer_before_delete',v_payload);
  reset role;
  perform pg_temp.actor(v_ids.owner_a);
  set local role authenticated;
  execute v_delete_sql into v_delete;
  perform pg_temp.check_true(current_user='authenticated' and v_delete=jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_id',v_ids.delete_op,'expense_id',v_expense,
    'period_id',v_period,'deleted',true,'replayed',false),'DELETE exact6 consumes UPDATE response version');
  insert into results values('delete',v_ids.delete_op,v_delete);
  insert into requests values('delete',v_delete_sql);
  v_payload:=pg_temp.checked(v_read_sql);
  perform pg_temp.validate_read(v_payload,'owner');
  insert into reads values('deleted',v_payload);
  perform pg_temp.check_true(pg_temp.checked(v_create_sql)=v_create||'{"replayed":true}'::jsonb,'CREATE replay after DELETE never recreates expense');
  perform pg_temp.check_true(pg_temp.checked(v_delete_sql)=v_delete||'{"replayed":true}'::jsonb,'DELETE replay after DELETE returns exact original receipt');
  perform pg_temp.checked(replace(v_create_sql,v_ids.create_op::text,v_ids.delete_op::text),'22023');
  reset role;
  perform pg_temp.actor(v_ids.editor);
  set local role authenticated;
  perform pg_temp.check_true(pg_temp.checked(v_update_sql)=v_update||'{"replayed":true}'::jsonb,'original editor UPDATE replay after DELETE never resurrects expense');
  perform pg_temp.checked(replace(v_delete_sql,v_ids.delete_op::text,v_ids.update_op::text),'22023');
  reset role;
  v_metrics:=economics_v2.calculate_group_period_live_metrics(v_ids.farm_a,v_period);
  perform pg_temp.check_true((v_metrics->>'acquisition_cost')::numeric=300
    and (v_metrics->>'direct_expense_total')::numeric=0 and (v_metrics->>'total_cost')::numeric=300,'DELETE and historical replays leave metrics 300 + 0 = 300');

  perform pg_temp.actor(v_ids.viewer);
  set local role authenticated;
  v_payload:=pg_temp.checked(v_read_sql);
  perform pg_temp.validate_read(v_payload,'viewer');
  insert into reads values('viewer',v_payload);
  perform pg_temp.checked(v_create_sql,'42501');
  perform pg_temp.checked(v_update_sql,'42501');
  perform pg_temp.checked(v_delete_sql,'42501');
  reset role;
  for v_probe in select unnest(array[v_ids.outsider,v_ids.owner_b]) actor_id loop
    perform pg_temp.actor(v_probe.actor_id);
    set local role authenticated;
    perform pg_temp.checked(v_read_sql,'42501');
    perform pg_temp.checked(v_create_sql,'42501');
    reset role;
  end loop;
  perform pg_temp.actor(v_ids.owner_a);
  set local role authenticated;
  perform pg_temp.checked(format('select public.list_group_finance_expenses_v1(p_granja_id=>%L::uuid)',v_ids.farm_b),'42501');
  perform pg_temp.checked(replace(v_create_sql,v_ids.farm_a::text,v_ids.farm_b::text),'42501');
  reset role;

  for v_receipt in select * from results where stage in ('create','update','delete') loop
    perform pg_temp.check_true((select v_o.result=v_receipt.result and v_o.event_position is null
      and coalesce(btrim(v_o.payload_hash),'')<>'' from economics_v2.group_occupancy_operations v_o
      where v_o.granja_id=v_ids.farm_a and v_o.operation_id=v_receipt.operation_id),'positionless ledger completion equals original public response');
  end loop;
  perform pg_temp.check_true((select count(*)=3 from results where stage in ('create','update','delete'))
    and not exists(select 1 from economics_v2.group_period_expenses v_e where v_e.id=v_expense)
    and pg_temp.business_state(array[v_ids.create_op,v_ids.update_op,v_ids.delete_op])=(select state from baseline),
    'net main fact zero; exactly three receipts; controls, unrelated eggs/basis/feed/legacy, ACL and sequences unchanged');
end;
$integrated_chain$;

select jsonb_build_object('result','group_economics_forward_group_expenses_crud_integration_pass',
  'assertion_count',(select count(*) from assertions),'fixture_ids',jsonb_build_object(
    'scope',(select to_jsonb(v_i) from ids v_i),'foundations',(select jsonb_agg(to_jsonb(v_f) order by n) from foundations v_f),
    'returned_receipts',(select jsonb_object_agg(stage,result) from results)),
  'cleanup','ROLLBACK follows this evidence; setup sequence increments are not rewound',
  'group_expense_crud_integrated',true,'group_expense_crud_sql_rpc_integrated',true,
  'canonical_group_expense_api_integrated',false,'http_transport_proven',false,'production_gateway_integrated',false,
  'legacy_expense_guards_integrated',false,'all_legacy_mutation_paths_guarded',false,
  'independent_review','pending','locking_evidence','sequential_only','real_closure_proven',false,
  'atomicity_evidence','previous_separate_evidence; no integrated late-fault test',
  'authorization_scope','owner/editor writes, viewer read-only, outsider/two-farm denial; demotion/flag-OFF remain individual-suite evidence') evidence;
rollback;
