begin;

-- HUMAN Sandbox Dashboard only: standalone additional REQUIRED qualification.
-- Run only AFTER the base fixture and installed canonical UPDATE gateway are GREEN.
-- This is a regression proof against UNCHANGED implementation, not a new-object RED.
-- Preparation only: no execution or independent PASS claimed by authoring this file.
-- Base proves critical owner/editor mutation, binding and late companion rollback;
-- this unit proves historical/namespace/corruption/drift/flag/fresh-header boundaries.
-- BOTH GREEN plus composed/native gates are required; neither is production readiness.
-- No implementation, normalizer or private core is copied/replaced. Public exact9
-- and private authorized exact9 signatures, exact11 result and exact14 completion stay.
-- Immutable ledger/companion before mutable reads; original predecessor replay must
-- CALL the real core. Future source review must verify that call and lock ordering;
-- result equality alone is NOT runtime delegation tracing or read-order proof.
-- Actual ADMIN private DELETE is verification, NOT canonical public DELETE integration.
-- Integrity probes are ADMIN-only, shape-valid and fully restored subtransactions.
-- No FK disabling, forged orphan/receipt, public producer proxy or core ACL rewrite.
-- Fresh auxiliary source belongs to its OWN real meat Group/period: no +1 clock trick.
-- If genuine CREATE clocks coincide, header-token distinction remains NOT proven.
-- Isolate Sandbox traffic: initial-entry sequence issuance is not rewound by ROLLBACK.
-- Sequential SQL RPC only, not HTTP/concurrency/closure/provenance/all-route coverage.
-- Separate test-only review slice; cumulative base+extended+FULL implementation is
-- larger than 800 and requires separate delivery/review slices, not a budget exception.

create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() editor_a,gen_random_uuid() farm_a,
  gen_random_uuid() type_a,gen_random_uuid() meat_a,gen_random_uuid() group_a,gen_random_uuid() group_aux,
  gen_random_uuid() animal_a,gen_random_uuid() animal_aux,gen_random_uuid() source_a,gen_random_uuid() source_aux,
  gen_random_uuid() category_a,gen_random_uuid() category_second,gen_random_uuid() entry_op,gen_random_uuid() aux_entry_op,
  gen_random_uuid() create_op,gen_random_uuid() aux_create_op,gen_random_uuid() private_op,
  gen_random_uuid() owner_op,gen_random_uuid() editor_op,gen_random_uuid() aux_update_op;
create temp table assertions(label text not null);
create temp table evidence(fresh_header_token_rejection_observed boolean);
insert into evidence values(false);
create temp table calls(operation_id uuid,actor_id uuid,mixture_id uuid,period_id uuid,group_id uuid,
  allocation_id uuid,allocation_stamp timestamptz,source_stamp timestamptz,source_digest text,
  start_on date,end_on date,recipe jsonb,result jsonb);
create temp table watched as
select n.nspname schema_name,c.relname table_name from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where c.relkind in ('r','p') and (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users'));
create temp table sequences as
select n.nspname schema_name,c.relname sequence_name from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity');
create temp table protected_acl as
select 'table' kind,c.oid,to_jsonb(c.relacl) acl from pg_class c
join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','economics_v2','group_feed_integrity')
union all select 'function',p.oid,to_jsonb(p.proacl) from pg_proc p
join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','economics_v2','group_feed_integrity');

create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
-- Read-only DEFINER evidence access is the only privileged client-callable helper.
-- No exclusions: refusal, historical replay and subtransaction restoration are full-state.
create function pg_temp.business_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; v_rows jsonb; v_state jsonb:='{}';
begin
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r',t.schema_name,t.table_name) into v_rows;
    v_state:=v_state||jsonb_build_object(t.schema_name||'.'||t.table_name,v_rows);
  end loop;
  for t in select * from pg_temp.sequences order by schema_name,sequence_name loop
    execute format('select jsonb_build_object(''last_value'',last_value,''is_called'',is_called)
      from %I.%I',t.schema_name,t.sequence_name) into v_rows;
    v_state:=v_state||jsonb_build_object(t.schema_name||'.'||t.sequence_name,v_rows);
  end loop;
  return v_state;
end;
$$;
-- INVOKER builds text only. Explicit source/period overrides support the fresh auxiliary RPC.
create function pg_temp.api_sql(p_op uuid,p_stamp timestamptz,p_recipe jsonb,p_start date,p_end date,
  p_group uuid,p_source uuid default null,p_period uuid default null,p_impl boolean default false)
returns text language plpgsql security invoker set search_path='' as $$
declare f record;
begin
  select * into f from pg_temp.targets;
  return format('select %s(p_mezcla_id=>%L::uuid,p_granja_id=>%L::uuid,p_operation_id=>%L::uuid,
    p_period_id=>%L::uuid,p_expected_updated_at=>%L::timestamptz,p_fecha_inicio=>%L::date,
    p_fecha_termino=>%L::date,p_grupo_id=>%L::uuid,p_ingredientes=>%L::jsonb)',
    case when p_impl then 'economics_v2.update_group_feed_impl' else 'public.actualizar_mezcla_grupo_v1' end,
    coalesce(p_source,f.source_a),f.farm_a,p_op,coalesce(p_period,f.period_a),p_stamp,p_start,p_end,p_group,p_recipe);
end;
$$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,
  p_field text default null,p_entity uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_result jsonb; v_state text; v_detail text;
begin
  v_before:=pg_temp.business_state();
  perform set_config('feed_update_integrity.observe','on',true);
  begin execute p_sql into v_result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics v_state=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform set_config('feed_update_integrity.observe','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'no change to full source/foods/facts/ledger/context/fences/sequences');
  if p_state is null then perform pg_temp.check_true(v_result is not null,'nonempty immutable historical replay');
  else
    perform pg_temp.check_true(v_state=p_state,'expected SQLSTATE '||p_state);
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb=jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field,'entity_id',p_entity),'exact4 typed refusal');
    end if;
  end if;
  return v_result;
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"feed-update-api-integrity"}'::jsonb from ids
cross join lateral unnest(array[owner_a,editor_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'UPDATE integrity farm',owner_a from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled) select farm_a,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'UPDATE integrity type',owner_a from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'UPDATE integrity meat','carne',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'UPDATE integrity Group '||g::text,owner_a from ids
cross join lateral unnest(array[group_a,group_aux]) g;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select c,farm_a,'UPDATE integrity category '||c::text,true,owner_a from ids
cross join lateral unnest(array[category_a,category_second]) c;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,owner_a from ids
union all select animal_aux,farm_a,type_a,group_aux,meat_a,current_date-7,0,owner_a from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
-- Real private ADMIN occupancy setup, not public occupancy integration proof.
create temp table targets as select f.*,
  (economics_v2.enter_group_meat_initial(farm_a,entry_op,animal_a,current_date-4,group_a,meat_a,'{}')->>'destination_period_id')::uuid period_a,
  (economics_v2.enter_group_meat_initial(farm_a,aux_entry_op,animal_aux,current_date-4,group_aux,meat_a,'{}')->>'destination_period_id')::uuid period_aux,
  jsonb_build_array(jsonb_build_object('categoria_id',category_a,'cantidad_kg',4,'costo_total',80),
    jsonb_build_object('categoria_id',category_second,'cantidad_kg',2,'costo_total',20)) recipe from ids f;
do $setup_access$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$setup_access$;
grant select on pg_temp.targets,pg_temp.calls to authenticated,anon;
grant insert on pg_temp.assertions to authenticated,anon;
revoke all on function pg_temp.check_true(boolean,text),pg_temp.business_state(),
  pg_temp.api_sql(uuid,timestamptz,jsonb,date,date,uuid,uuid,uuid,boolean),
  pg_temp.checked(text,text,text,text,uuid) from public;
grant execute on function pg_temp.check_true(boolean,text),pg_temp.business_state(),
  pg_temp.api_sql(uuid,timestamptz,jsonb,date,date,uuid,uuid,uuid,boolean),
  pg_temp.checked(text,text,text,text,uuid) to authenticated,anon;
do $setup_sources$
declare f record; q record; a record; v_recipe jsonb;
begin
  select * into f from pg_temp.targets;
  v_recipe:=jsonb_build_array(jsonb_build_object('categoria_id',f.category_a,'cantidad_kg',2,'costo_total',10));
  set local role authenticated;
  for q in select * from (values(f.source_a,f.create_op,f.period_a,f.group_a),
    (f.source_aux,f.aux_create_op,f.period_aux,f.group_aux)) sources(id,op,period_id,group_id) loop
    perform public.crear_mezcla_grupo_v1(p_granja_id=>f.farm_a,p_operation_id=>q.op,p_period_id=>q.period_id,
      p_mezcla_id=>q.id,p_fecha_inicio=>current_date-2,p_grupo_id=>q.group_id,p_ingredientes=>v_recipe);
  end loop;
  reset role;
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.source_a;
  perform economics_v2.update_group_feed_allocation(f.farm_a,f.private_op,f.period_a,f.source_a,
    a.updated_at,a.source_updated_at,a.source_digest,current_date-2,null,v_recipe);
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.source_a;
  insert into pg_temp.calls values(f.owner_op,f.owner_a,f.source_a,f.period_a,f.group_a,a.id,
    a.updated_at,a.source_updated_at,a.source_digest,current_date-2,null,f.recipe,null);
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.source_aux;
  insert into pg_temp.calls values(f.aux_update_op,f.owner_a,f.source_aux,f.period_aux,f.group_aux,a.id,
    a.updated_at,a.source_updated_at,a.source_digest,current_date-2,null,f.recipe,null);
end;
$setup_sources$;

-- Independent ADMIN INVOKER readback: captured PRE-call fields, not a sidecar copy.
create function pg_temp.assert_completion(p_op uuid)
returns void language plpgsql security invoker set search_path='' as $$
declare f record; c record; a record; m record; o record; s record; v_public jsonb; v_core jsonb; v_context jsonb;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls where operation_id=p_op;
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=c.mixture_id;
  select * into m from public.mezcla where id=c.mixture_id;
  select * into o from economics_v2.group_occupancy_operations where granja_id=f.farm_a and operation_id=p_op;
  select * into s from economics_v2.group_feed_api_completions where granja_id=f.farm_a and operation_id=p_op;
  v_context:=economics_v2.validate_group_feed_source(f.farm_a,c.period_id,c.mixture_id,m.updated_at);
  perform pg_temp.check_true(m.created_by=f.owner_a and m.grupo_id=c.group_id and a.id=c.allocation_id
    and a.period_id=c.period_id and a.updated_at=m.updated_at and a.source_updated_at=m.updated_at
    and a.updated_at>c.allocation_stamp and a.source_digest=v_context->>'source_digest'
    and a.quantity_kg=(v_context->>'quantity_kg')::numeric and a.total_cost=(v_context->>'total_cost')::numeric
    and a.component_count=(v_context->>'component_count')::integer
    and c.result=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_op,
      'mixture_id',c.mixture_id,'period_id',c.period_id,'allocation_id',a.id,'updated_at',a.updated_at,
      'component_count',a.component_count,'quantity_kg',a.quantity_kg,'total_cost',a.total_cost,
      'source_digest',a.source_digest,'replayed',false) and o.result=c.result and o.event_position is null,
    'actual owned source/fact and completed exact11 gateway receipt');
  v_public:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_domain','group-feed-update-api.v1',
    'granja_id',f.farm_a,'actor_id',c.actor_id,'operation_id',p_op,'request',jsonb_build_object('action','feed_update',
      'period_id',c.period_id,'mixture_id',c.mixture_id,'expected_allocation_updated_at_utc',
      to_char(c.allocation_stamp at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'fecha_inicio',c.start_on,'fecha_termino',c.end_on,'grupo_id',c.group_id,'ingredientes',c.recipe));
  v_core:=v_public||jsonb_build_object('operation_domain','group-feed-update.v1',
    'request',((v_public->'request')-'grupo_id')||jsonb_build_object('expected_source_updated_at_utc',
      to_char(c.source_stamp at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'expected_source_digest',c.source_digest));
  perform pg_temp.check_true(to_jsonb(s)=jsonb_build_object('granja_id',f.farm_a,'operation_id',p_op,
    'bridge_version','group-feed-api-completion.v1','operation_kind','feed_update','actor_id',c.actor_id,
    'period_id',c.period_id,'mixture_id',c.mixture_id,'group_id',c.group_id,
    'expected_allocation_updated_at',c.allocation_stamp,'predecessor_source_updated_at',c.source_stamp,
    'predecessor_source_digest',c.source_digest,'public_payload_hash',
    encode(sha256(convert_to(economics_v2.canonical_group_request(v_public)::text,'UTF8')),'hex'),
    'core_payload_hash',encode(sha256(convert_to(economics_v2.canonical_group_request(v_core)::text,'UTF8')),'hex'),
    'core_result_hash',encode(sha256(convert_to(economics_v2.canonical_group_request(o.result)::text,'UTF8')),'hex'))
    and s.core_payload_hash=o.payload_hash,'real gateway exact14 independent API8/core9/result binding gate');
end;
$$;
do $real_gateway_context$
declare f record; a record; c record; r jsonb;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls where operation_id=f.owner_op;
  set local role authenticated;
  r:=public.actualizar_mezcla_grupo_v1(p_mezcla_id=>f.source_a,p_granja_id=>f.farm_a,p_operation_id=>f.owner_op,
    p_period_id=>f.period_a,p_expected_updated_at=>c.allocation_stamp,p_fecha_inicio=>c.start_on,
    p_fecha_termino=>c.end_on,p_grupo_id=>f.group_a,p_ingredientes=>c.recipe);
  reset role;
  update pg_temp.calls set result=r where operation_id=f.owner_op;
  perform pg_temp.assert_completion(f.owner_op);
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.source_a;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated')::text,true);
  set local role authenticated;
  perform public.actualizar_mezcla_grupo_v1(p_mezcla_id=>f.source_a,p_granja_id=>f.farm_a,p_operation_id=>f.editor_op,
    p_period_id=>f.period_a,p_expected_updated_at=>a.updated_at,p_fecha_inicio=>current_date-1,
    p_fecha_termino=>null::date,p_grupo_id=>f.group_a,p_ingredientes=>jsonb_build_array(
      jsonb_build_object('categoria_id',f.category_second,'cantidad_kg',2,'costo_total',30)));
  reset role;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
end;
$real_gateway_context$;
set constraints all immediate;

create function pg_temp.observe_dml()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('feed_update_integrity.observe',true)='on' then
    raise exception 'Extended UPDATE replay/refusal attempted DML: %.% %',tg_table_schema,tg_table_name,tg_op;
  end if;
  return null;
end;
$$;
do $observers$
declare t record;
begin
  for t in select * from pg_temp.watched loop
    execute format('create trigger feed_update_integrity_observer before insert or update or delete or truncate
      on %I.%I for each statement execute function pg_temp.observe_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;

do $fresh_auxiliary_token$
declare f record; c record; m record; v_before jsonb; r jsonb; v_observed boolean:=false;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls where operation_id=f.aux_update_op;
  select * into m from public.mezcla where id=f.source_aux;
  perform pg_temp.check_true(m.updated_at=c.source_stamp,'auxiliary source still has genuine pre-UPDATE CREATE version');
  v_before:=pg_temp.business_state(); -- BOTH real entries/CREATE sources already precede this baseline.
  begin
    set local role authenticated;
    if m.updated_at is distinct from c.allocation_stamp then
      perform pg_temp.checked(pg_temp.api_sql(gen_random_uuid(),m.updated_at,c.recipe,c.start_on,null,
        c.group_id,c.mixture_id,c.period_id),'40001','stale_write','allocation_id',c.allocation_id);
      v_observed:=true; -- Only after exact refusal, no transient DML and full snapshot equality.
    end if;
    execute pg_temp.api_sql(c.operation_id,c.allocation_stamp,c.recipe,c.start_on,null,c.group_id,c.mixture_id,c.period_id) into r;
    reset role;
    update pg_temp.calls set result=r where operation_id=c.operation_id;
    perform pg_temp.assert_completion(c.operation_id);
    perform pg_temp.check_true((select quantity_kg=6 and total_cost=100 and component_count=2
      from economics_v2.group_period_feed_allocations where mixture_id=c.mixture_id),'fresh actual ALLOCATION token succeeds');
    raise exception using errcode='ZR001',message='Restore auxiliary positive/negative verification';
  exception when sqlstate 'ZR001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'auxiliary business/receipt/fences restored without sequence drift');
  -- PLpgSQL local survives subtransaction rollback; persist evidence only AFTER restoration.
  update pg_temp.evidence set fresh_header_token_rejection_observed=v_observed;
  perform pg_temp.check_true(true,case when v_observed then 'fresh header-token rejection observed'
    else 'CREATE clocks coincide: fresh header-token distinction NOT proven' end);
end;
$fresh_auxiliary_token$;

do $historical_identity_and_namespace$
declare f record; c record; q record; v_sql text;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls where operation_id=f.owner_op;
  v_sql:=pg_temp.api_sql(c.operation_id,c.allocation_stamp,c.recipe,c.start_on,null,f.group_a);
  set local role authenticated;
  perform pg_temp.check_true(pg_temp.checked(v_sql)=c.result||'{"replayed":true}'::jsonb,'original owner result after actual later editor UPDATE');
  for q in select * from (values
    (f.group_aux,c.start_on,c.end_on,c.allocation_stamp,c.recipe),
    (f.group_a,c.start_on+1,c.end_on,c.allocation_stamp,c.recipe),
    (f.group_a,c.start_on,current_date-1,c.allocation_stamp,c.recipe),
    (f.group_a,c.start_on,c.end_on,c.allocation_stamp+interval '1 second',c.recipe),
    (f.group_a,c.start_on,c.end_on,c.allocation_stamp,jsonb_build_array(c.recipe->1,c.recipe->0))) changes(group_id,start_on,end_on,stamp,recipe) loop
    perform pg_temp.checked(pg_temp.api_sql(c.operation_id,q.stamp,q.recipe,q.start_on,q.end_on,q.group_id),
      '22023','operation_payload_conflict','operation_id',c.operation_id);
  end loop;
  for q in select * from (values(f.create_op),(f.private_op),(f.entry_op)) operations(op) loop
    perform pg_temp.checked(pg_temp.api_sql(q.op,c.allocation_stamp,c.recipe,c.start_on,null,f.group_a),
      '22023','operation_payload_conflict','operation_id',q.op);
  end loop;
  perform pg_temp.checked(pg_temp.api_sql(c.operation_id,null,c.recipe,c.start_on,null,f.group_a),
    '22023','invalid_request','expected_allocation_updated_at',f.source_a);
  reset role;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated')::text,true);
  set local role authenticated;
  perform pg_temp.checked(v_sql,'22023','operation_payload_conflict','operation_id',c.operation_id);
  perform pg_temp.checked(pg_temp.api_sql(c.operation_id,c.allocation_stamp,c.recipe,c.start_on,null,f.group_a,
    null,null,true),'22023','operation_payload_conflict','operation_id',c.operation_id);
  reset role;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
end;
$historical_identity_and_namespace$;

do $admin_integrity_and_history$
declare f record; c record; a record; v_before jsonb; v_sql text; v_probe text; v_state text; v_code text; v_field text;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls where operation_id=f.owner_op;
  v_sql:=pg_temp.api_sql(c.operation_id,c.allocation_stamp,c.recipe,c.start_on,null,f.group_a);
  foreach v_probe in array array['missing_companion','core_payload_hash','core_result_hash','ledger_result','source_stamp','source_price','flag','delete'] loop
    v_before:=pg_temp.business_state();
    select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.source_a;
    begin
      v_state:='23514'; v_code:='invariant_violation'; v_field:='operation_id';
      if v_probe='missing_companion' then
        delete from economics_v2.group_feed_api_completions where granja_id=f.farm_a and operation_id=c.operation_id;
        v_state:='22023'; v_code:='operation_payload_conflict';
      elsif v_probe in ('core_payload_hash','core_result_hash') then
        execute format('update economics_v2.group_feed_api_completions set %I=%L where granja_id=$1 and operation_id=$2',
          v_probe,repeat('0',64)) using f.farm_a,c.operation_id;
      elsif v_probe='ledger_result' then
        update economics_v2.group_occupancy_operations set result=jsonb_set(result,'{total_cost}',
          to_jsonb((result->>'total_cost')::numeric+1)) where granja_id=f.farm_a and operation_id=c.operation_id;
      elsif v_probe='source_stamp' then
        update public.mezcla set updated_at=clock_timestamp() where id=f.source_a;
        v_state:='40001'; v_code:='stale_write'; v_field:='mixture_id';
      elsif v_probe='source_price' then
        update public.comida set precio=precio+1 where id=(select comida_id from public.mezcla_comida where mezcla_id=f.source_a limit 1);
        v_state:='40001'; v_code:='stale_write'; v_field:='source_digest';
      elsif v_probe='flag' then update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
      else
        perform economics_v2.delete_group_feed_allocation(f.farm_a,gen_random_uuid(),f.period_a,f.source_a,
          a.updated_at,a.source_updated_at,a.source_digest);
        perform pg_temp.check_true(not exists(select 1 from public.mezcla where id=f.source_a)
          and not exists(select 1 from economics_v2.group_period_feed_allocations where mixture_id=f.source_a),
          'actual ADMIN private DELETE removes source/fact; durable ledger and companion remain');
      end if;
      set local role authenticated;
      if v_probe='delete' then
        perform pg_temp.check_true(pg_temp.checked(v_sql)=c.result||'{"replayed":true}'::jsonb,'original UPDATE replay after real physical DELETE');
      elsif v_probe='flag' then
        perform pg_temp.checked(v_sql,'42501');
        perform pg_temp.checked(pg_temp.api_sql(c.operation_id,c.allocation_stamp,c.recipe,c.start_on,null,f.group_a,null,null,true),'42501');
      elsif v_probe in ('source_stamp','source_price') then
        perform pg_temp.checked(pg_temp.api_sql(gen_random_uuid(),a.updated_at,f.recipe,c.start_on,null,f.group_a),v_state,v_code,v_field,f.source_a);
      else perform pg_temp.checked(v_sql,v_state,v_code,v_field,c.operation_id);
      end if;
      reset role;
      raise exception using errcode='ZR001',message='Restore ADMIN integrity/history probe';
    exception when sqlstate 'ZR001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'actual probe completed and fully restored: '||v_probe);
  end loop;
end;
$admin_integrity_and_history$;

do $metadata_and_client_storage$
declare p record; v_role text; v_sql text;
begin
  for p in select q.*,n.nspname from pg_proc q join pg_namespace n on n.oid=q.pronamespace
    where q.oid in ('public.actualizar_mezcla_grupo_v1(uuid,uuid,uuid,uuid,timestamptz,date,date,uuid,jsonb)'::regprocedure,
      'economics_v2.update_group_feed_impl(uuid,uuid,uuid,uuid,timestamptz,date,date,uuid,jsonb)'::regprocedure) loop
    perform pg_temp.check_true(p.prosecdef=(p.nspname='economics_v2') and p.proowner='postgres'::regrole
      and p.prorettype='jsonb'::regtype and p.provolatile='v' and p.pronargs=9 and p.pronargdefaults=0
      and p.proargnames=array['p_mezcla_id','p_granja_id','p_operation_id','p_period_id','p_expected_updated_at',
        'p_fecha_inicio','p_fecha_termino','p_grupo_id','p_ingredientes'] and p.proconfig @> array['search_path=""']
      and has_function_privilege('authenticated',p.oid,'EXECUTE') and not has_function_privilege('anon',p.oid,'EXECUTE')
      and not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) x
        where x.grantee=0 and x.privilege_type='EXECUTE'),'exact9 required gateway metadata/owner/ACL');
  end loop;
  perform pg_temp.check_true(not exists(select 1 from pg_proc q join pg_namespace n on n.oid=q.pronamespace
    where n.nspname='economics_v2' and q.proname in ('update_group_feed_allocation','delete_group_feed_allocation',
      'create_group_feed_allocation','assert_group_writer_actor','validate_group_feed_source',
      'normalize_group_feed_api_ingredients','group_feed_api_payload_hash','canonical_group_request')
    and (has_function_privilege('authenticated',q.oid,'EXECUTE') or has_function_privilege('anon',q.oid,'EXECUTE'))),
    'existing cores and private helpers remain inaccessible to clients');
  foreach v_role in array array['authenticated','anon'] loop
    execute format('set local role %I',v_role);
    foreach v_sql in array array['select * from economics_v2.group_feed_api_completions',
      'insert into economics_v2.group_feed_api_completions default values',
      'update economics_v2.group_feed_api_completions set bridge_version=bridge_version',
      'delete from economics_v2.group_feed_api_completions'] loop
      perform pg_temp.checked(v_sql,'42501');
    end loop;
    reset role;
  end loop;
  perform pg_temp.check_true(not exists(select 1 from pg_temp.protected_acl b
    left join pg_class c on b.kind='table' and c.oid=b.oid left join pg_proc q on b.kind='function' and q.oid=b.oid
    where b.acl is distinct from case b.kind when 'table' then to_jsonb(c.relacl) else to_jsonb(q.proacl) end),
    'UNCHANGED installed gateway/core/helper/storage ACLs throughout extended verification');
  set constraints all immediate;
end;
$metadata_and_client_storage$;
select jsonb_build_object(
  'result','group_economics_forward_feed_update_api_integrity_pass','assertion_count',(select count(*) from assertions),
  'fixture_ids',(select to_jsonb(f) from targets f),'extended_update_integrity_proven',true,
  'fresh_header_token_rejection_observed',(select fresh_header_token_rejection_observed from evidence),
  'base_gateway_required_green',true,'full_update_qualification_proven',false,'production_release_ready',false,
  'locking_evidence','sequential_only','independent_review','pending','real_closure_proven',false,
  'production_gateway_integrated',false,'canonical_group_food_update_api_integrated',true,
  'canonical_group_food_delete_api_integrated',false,'canonical_group_food_api_integrated',false,
  'sql_rpc_path_proven',true,'http_transport_proven',false,'metadata_atomic_business_rollback_proven',false,
  'all_legacy_mutation_paths_guarded',false,'privileged_business_provenance_proven',false) evidence;
rollback;
