begin;

-- HUMAN Sandbox Dashboard only: review, then run this FULL BEGIN/ROLLBACK file.
-- Fixture-first preparation, not execution, implementation or independent PASS.
-- First genuine RED must escape as 42883 at the named public call in $first$.
-- No missing-function regprocedure preflight or temporary definer producer proxy.
-- Accepted public.crear_mezcla_grupo_v1 and economics_v2.create_group_feed_impl:
-- (p_granja_id uuid,p_operation_id uuid,p_period_id uuid,p_mezcla_id uuid,
--  p_fecha_inicio date,p_grupo_id uuid,p_ingredientes jsonb) returns jsonb.
-- All seven named parameters are required, without defaults. Public INVOKER calls
-- private-schema DEFINER implementation with named arguments; only that guarded
-- implementation delegates to the actual INVOKER create_group_feed_allocation.
-- Translate p_mezcla_id to core p_mixture_id; preserve every other argument.
-- Implementation owned by postgres, empty search_path, actual JWT owner/editor
-- authorization via assert_group_writer_actor; no mutable lookup before core replay.
-- Both new functions intentionally allow authenticated EXECUTE, never PUBLIC/anon.
-- No client EXECUTE grants on any existing core, validator or error/actor helper.
-- Exact11 result and group-feed-create.v1 canonical hash remain the core's contract.
-- No client digest, context, timestamps, totals, creator, flags or new replay domain.
-- Canonical UPDATE/DELETE require a separate durable predecessor/replay protocol.
-- Selected installed legacy/direct guards are composed, not global route proof.
-- SQL role RPC path only: no REST, Flutter, real closure or production writer proof.
-- Sequential only; isolate Sandbox traffic. Setup sequence issuance is NOT rewound.
-- Forecast: this fixture <=500 + FULL future wrapper/implementation/ACL <=150
-- = <=650, within hard cap800. Do not copy the qualified private core.

create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,
  gen_random_uuid() type_a,gen_random_uuid() type_b,
  gen_random_uuid() meat_a,gen_random_uuid() meat_b,
  gen_random_uuid() group_a,gen_random_uuid() group_other,gen_random_uuid() group_b,
  gen_random_uuid() animal_a,gen_random_uuid() animal_b,
  gen_random_uuid() category_a,gen_random_uuid() category_second,
  gen_random_uuid() category_archived,gen_random_uuid() category_b,
  gen_random_uuid() prior_source,gen_random_uuid() new_source,gen_random_uuid() editor_source,
  gen_random_uuid() capture_op,gen_random_uuid() create_op,gen_random_uuid() editor_op;
create temp table assertions(label text not null);
create temp table results(actor uuid,result jsonb not null);
create temp table watched as
select n.nspname schema_name,c.relname table_name from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where c.relkind in ('r','p') and (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users'));
create temp table watched_sequences as
select n.nspname schema_name,c.relname sequence_name from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity');
create temp table acl_baseline as
select 'table' kind,c.oid,to_jsonb(c.relacl) acl from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','economics_v2','group_feed_integrity')
union all select 'function',p.oid,to_jsonb(p.proacl) from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','economics_v2','group_feed_integrity');

create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
-- Read-only definer snapshot: clients never receive private producer capabilities.
create function pg_temp.business_state(p_source uuid default null,p_op uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; f record; v_rows jsonb; v_result jsonb:='{}'; v_filter text; v_foods uuid[];
begin
  select * into f from pg_temp.ids;
  select coalesce(array_agg(comida_id),'{}'::uuid[]) into v_foods
  from public.mezcla_comida where mezcla_id=p_source;
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    v_filter:='';
    if p_source is not null then
      if t.schema_name='public' and t.table_name='mezcla' then v_filter:=' where r.id<>$1';
      elsif t.schema_name='public' and t.table_name='mezcla_comida' then v_filter:=' where r.mezcla_id<>$1';
      elsif t.schema_name='public' and t.table_name='comida' then v_filter:=' where not r.id=any($2)';
      elsif t.schema_name='economics_v2' and t.table_name='group_period_feed_allocations' then
        v_filter:=' where r.mixture_id<>$1';
      elsif t.schema_name='economics_v2' and t.table_name='group_occupancy_operations' then
        v_filter:=' where r.operation_id<>$3';
      elsif t.schema_name='group_feed_integrity' and t.table_name='fences' then
        v_filter:=' where not (r.scope=''group'' and r.entity_id=$4)';
      end if;
    end if;
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r%s',t.schema_name,t.table_name,v_filter)
      into v_rows using p_source,v_foods,p_op,f.group_a;
    v_result:=v_result||jsonb_build_object(t.schema_name||'.'||t.table_name,v_rows);
  end loop;
  for t in select * from pg_temp.watched_sequences order by schema_name,sequence_name loop
    execute format('select jsonb_build_object(''last_value'',s.last_value,''is_called'',s.is_called)
      from %I.%I s',t.schema_name,t.sequence_name) into v_rows;
    v_result:=v_result||jsonb_build_object(t.schema_name||'.'||t.sequence_name,v_rows);
  end loop;
  return v_result;
end;
$$;
-- Text construction only: no early resolution of the intentionally absent API.
create function pg_temp.api_sql(p_farm uuid,p_op uuid,p_period uuid,p_source uuid,
  p_start date,p_group uuid,p_recipe jsonb,p_impl boolean default false)
returns text language plpgsql security invoker set search_path='' as $$
begin
  return format('select %s(p_granja_id=>%L::uuid,p_operation_id=>%L::uuid,
    p_period_id=>%L::uuid,p_mezcla_id=>%L::uuid,p_fecha_inicio=>%L::date,
    p_grupo_id=>%L::uuid,p_ingredientes=>%L::jsonb)',
    case when p_impl then 'economics_v2.create_group_feed_impl' else 'public.crear_mezcla_grupo_v1' end,
    p_farm,p_op,p_period,p_source,p_start,p_group,p_recipe);
end;
$$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,
  p_field text default null,p_entity uuid default null,p_row_guard boolean default false)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_result jsonb; v_state text; v_detail text;
begin
  v_before:=pg_temp.business_state();
  perform set_config('feed_api.observe',case when p_row_guard then 'row' else 'statement' end,true);
  begin execute p_sql into v_result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics v_state=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform set_config('feed_api.observe','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,
    'no change to full rows, private fences, events, basis, receipts or sequences');
  if p_state is not null then
    perform pg_temp.check_true(v_state=p_state,'expected SQLSTATE '||p_state);
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb=jsonb_build_object(
        'contract_version','group-economics.forward.v3','code',p_code,'field',p_field,'entity_id',p_entity),
        'exact4 refusal DETAIL');
    end if;
  else perform pg_temp.check_true(v_result is not null,'nonempty stored replay result');
  end if;
  return v_result;
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"feed-create-api"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'CREATE API farm A',owner_a from ids
union all select farm_b,owner_b,'CREATE API farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'CREATE API type A',owner_a from ids
union all select type_b,farm_b,'CREATE API type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'CREATE API meat A','carne',owner_a from ids
union all select meat_b,farm_b,'CREATE API meat B','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'CREATE API Group '||g::text,owner_a from ids
cross join lateral unnest(array[group_a,group_other]) g
union all select group_b,farm_b,type_b,'CREATE API foreign Group',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select c,farm_a,'CREATE API category '||c::text,c<>category_archived,owner_a from ids
cross join lateral unnest(array[category_a,category_second,category_archived]) c
union all select category_b,farm_b,'CREATE API foreign category',true,owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
do $setup_access$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$setup_access$;
grant select on pg_temp.ids to authenticated;
set local role authenticated;
-- Actual legacy creation BEFORE entry; never a proxy for the new producer.
select public.crear_mezcla_completa(farm_a,prior_source,current_date-3,group_a,
  jsonb_build_array(jsonb_build_object('categoria_id',category_a,'cantidad_kg',2,'costo_total',10))) from ids;
reset role;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,owner_a from ids
union all select animal_b,farm_b,type_b,group_b,meat_b,current_date-7,0,owner_b from ids;
create temp table admissions(animal_id uuid,result jsonb);
insert into admissions select animal_a,economics_v2.enter_group_meat_initial(
  farm_a,gen_random_uuid(),animal_a,current_date-4,group_a,meat_a,'{}') from ids;
select set_config('request.jwt.claim.sub',owner_b::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_b,'role','authenticated')::text,true) from ids;
insert into admissions select animal_b,economics_v2.enter_group_meat_initial(
  farm_b,gen_random_uuid(),animal_b,current_date-4,group_b,meat_b,'{}') from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
create temp table targets as select f.*,
  (select (result->>'destination_period_id')::uuid from admissions where animal_id=f.animal_a) period_a,
  (select (result->>'destination_period_id')::uuid from admissions where animal_id=f.animal_b) period_b,
  (select (result->>'operation_id')::uuid from admissions where animal_id=f.animal_a) occupancy_op,
  jsonb_build_array(jsonb_build_object('categoria_id',category_a,'cantidad_kg',4,'costo_total',80),
    jsonb_build_object('categoria_id',category_second,'cantidad_kg',2,'costo_total',20)) recipe
from ids f;
do $capture$
declare f record; m record; c jsonb;
begin
  select * into f from pg_temp.targets;
  select * into m from public.mezcla where id=f.prior_source;
  c:=economics_v2.validate_group_feed_source(f.farm_a,f.period_a,m.id,m.updated_at);
  perform economics_v2.capture_group_feed_allocation(f.farm_a,f.capture_op,f.period_a,
    m.id,m.updated_at,c->>'source_digest');
end;
$capture$;
set constraints all immediate;

-- Observe transient DML, not merely state after exception rollback. ROW mode lets
-- actual BEFORE ROW direct guards raise their own error before persistence.
create function pg_temp.observe_dml()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('feed_api.observe',true)='statement'
    or (tg_when='AFTER' and current_setting('feed_api.observe',true)='row') then
    raise exception using errcode='P0001',message='CREATE API replay/refusal attempted DML',
      detail=tg_table_schema||'.'||tg_table_name||' '||tg_op;
  end if;
  return null;
end;
$$;
do $observers$
declare t record;
begin
  for t in select * from pg_temp.watched loop
    execute format('create trigger feed_api_statement_observer before insert or update or delete or truncate
      on %I.%I for each statement execute function pg_temp.observe_dml()',t.schema_name,t.table_name);
    execute format('create trigger feed_api_row_observer after insert or update or delete
      on %I.%I for each row execute function pg_temp.observe_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;
grant select on pg_temp.ids,pg_temp.targets to authenticated,anon;
grant insert on pg_temp.assertions,pg_temp.results to authenticated,anon;
revoke all on function pg_temp.check_true(boolean,text),pg_temp.business_state(uuid,uuid),
  pg_temp.api_sql(uuid,uuid,uuid,uuid,date,uuid,jsonb,boolean),
  pg_temp.checked(text,text,text,text,uuid,boolean) from public;
grant execute on function pg_temp.check_true(boolean,text),pg_temp.business_state(uuid,uuid),
  pg_temp.api_sql(uuid,uuid,uuid,uuid,date,uuid,jsonb,boolean),
  pg_temp.checked(text,text,text,text,uuid,boolean) to authenticated,anon;

do $first$
declare f record; v_other jsonb; v_result jsonb;
begin
  select * into f from pg_temp.targets;
  v_other:=pg_temp.business_state(f.new_source,f.create_op);
  set local role authenticated;
  -- FIRST actual canonical call: unresolved 42883 propagates, never caught/masked.
  v_result:=public.crear_mezcla_grupo_v1(p_granja_id=>f.farm_a::uuid,
    p_operation_id=>f.create_op::uuid,p_period_id=>f.period_a::uuid,p_mezcla_id=>f.new_source::uuid,
    p_fecha_inicio=>(current_date-2)::date,p_grupo_id=>f.group_a::uuid,p_ingredientes=>f.recipe::jsonb);
  perform pg_temp.check_true(current_user='authenticated','first public RPC uses actual client SQL role');
  insert into pg_temp.results values(f.owner_a,v_result);
  reset role;
  perform pg_temp.check_true(pg_temp.business_state(f.new_source,f.create_op)=v_other,
    'first creation preserves every unrelated full row and sequence');
end;
$first$;

do $metadata_and_source$
declare f record; v_proc record; a record; m record; c jsonb; r jsonb; v_hash text;
begin
  select * into f from pg_temp.targets;
  for v_proc in select q.*,n.nspname from pg_proc q join pg_namespace n on n.oid=q.pronamespace
    where q.oid in ('public.crear_mezcla_grupo_v1(uuid,uuid,uuid,uuid,date,uuid,jsonb)'::regprocedure,
      'economics_v2.create_group_feed_impl(uuid,uuid,uuid,uuid,date,uuid,jsonb)'::regprocedure) loop
    perform pg_temp.check_true(v_proc.prosecdef=(v_proc.nspname='economics_v2')
      and v_proc.proowner='postgres'::regrole and v_proc.prorettype='jsonb'::regtype
      and v_proc.provolatile='v' and v_proc.pronargs=7 and v_proc.pronargdefaults=0
      and v_proc.proargnames=array['p_granja_id','p_operation_id','p_period_id','p_mezcla_id',
        'p_fecha_inicio','p_grupo_id','p_ingredientes'] and v_proc.proconfig @> array['search_path=""']
      and has_function_privilege('authenticated',v_proc.oid,'EXECUTE')
      and not has_function_privilege('anon',v_proc.oid,'EXECUTE')
      and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) x
        where x.grantee=0 and x.privilege_type='EXECUTE'), 'pinned required seven-argument gateway metadata and ACL');
  end loop;
  perform pg_temp.check_true(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='economics_v2' and p.proname in ('enter_group_meat_initial','validate_group_feed_source',
      'capture_group_feed_allocation','create_group_feed_allocation','update_group_feed_allocation',
      'delete_group_feed_allocation','raise_group_writer_error','assert_group_writer_actor','canonical_group_request')
      and (has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE'))),
    'no private core or helper privilege workaround');
  select * into m from public.mezcla where id=f.new_source;
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=m.id;
  select result_row.result into r from pg_temp.results as result_row where result_row.actor=f.owner_a;
  c:=economics_v2.validate_group_feed_source(f.farm_a,f.period_a,m.id,m.updated_at);
  perform pg_temp.check_true(m.created_by=f.owner_a and m.granja_id=f.farm_a and m.grupo_id=f.group_a
    and m.fecha_inicio=current_date-2 and m.fecha_termino is null and m.group_feed_meat_exempt
    and a.period_id=f.period_a and a.granja_id=f.farm_a and a.finalized_at is null
    and a.source_updated_at=m.updated_at and a.updated_at is not null
    and a.source_digest=c->>'source_digest' and a.component_count=2 and a.quantity_kg=6 and a.total_cost=100,
    'actual owner source and allocation agree with private validator readback');
  perform pg_temp.check_true(r=jsonb_build_object('contract_version','group-economics.forward.v3',
    'operation_id',f.create_op,'mixture_id',m.id,'period_id',f.period_a,'allocation_id',a.id,
    'updated_at',a.updated_at,'component_count',2,'quantity_kg',6,'total_cost',100,
    'source_digest',a.source_digest,'replayed',false), 'exact11 public result uses actual server fact');
  perform pg_temp.check_true((select count(*)=2 and sum(mc.cantidad)=6 and sum(food.precio)=100
    and bool_and(food.cantidad=mc.cantidad and food.granja_id=f.farm_a and mc.granja_id=f.farm_a)
    from public.mezcla_comida mc join public.comida food on food.id=mc.comida_id where mc.mezcla_id=m.id)
    and not exists(select 1 from public.mezcla_comida mc join public.mezcla_comida other
      on other.comida_id=mc.comida_id and other.id<>mc.id where mc.mezcla_id=m.id)
    and (select count(*)=1 from economics_v2.group_period_feed_allocations where mixture_id=m.id),
    'dedicated actual purchases use TOTAL price and ingredient kg, one allocation');
  perform pg_temp.check_true((select jsonb_agg(jsonb_build_object('categoria_id',food.cat_comida_id,
    'cantidad_kg',mc.cantidad,'costo_total',food.precio) order by food.cat_comida_id)
    from public.mezcla_comida mc join public.comida food on food.id=mc.comida_id where mc.mezcla_id=m.id)
    =(select jsonb_agg(value order by (value->>'categoria_id')::uuid) from jsonb_array_elements(f.recipe)),
    'actual categories, kg and TOTAL costs match each requested ingredient');
  v_hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-feed-create.v1',
    'granja_id',f.farm_a,'actor_id',f.owner_a,'operation_id',f.create_op,
    'request',jsonb_build_object('action','feed_create','period_id',f.period_a,'mixture_id',f.new_source,
      'fecha_inicio',current_date-2,'grupo_id',f.group_a,'ingredientes',f.recipe)))::text,'UTF8')),'hex');
  perform pg_temp.check_true((select payload_hash=v_hash and result=r and event_position is null
    from economics_v2.group_occupancy_operations where granja_id=f.farm_a and operation_id=f.create_op),
    'actual completed receipt preserves private canonical namespace and NULL position');
  perform pg_temp.check_true((select sum(total_cost)=110 and sum(quantity_kg)=8
    from economics_v2.group_period_feed_allocations where period_id=f.period_a)
    and (select remaining_basis=300 from economics_v2.group_animal_acquisition_basis
      where granja_id=f.farm_a and animal_id=f.animal_a), 'prior plus new live SUM is 110/8, basis remains 300');
end;
$metadata_and_source$;

do $replay_and_refusals$
declare f record; actor record; q record; r jsonb; v_recipe jsonb; v_sql text;
begin
  select * into f from pg_temp.targets;
  select result_row.result into r from pg_temp.results as result_row where result_row.actor=f.owner_a;
  v_sql:=pg_temp.api_sql(f.farm_a,f.create_op,f.period_a,f.new_source,current_date-2,f.group_a,f.recipe);
  set local role authenticated;
  perform pg_temp.check_true(pg_temp.checked(v_sql)=r||'{"replayed":true}'::jsonb,'owner exact historical replay');
  v_recipe:=jsonb_build_array(jsonb_build_object('categoria_id',upper(f.category_a::text),
    'cantidad_kg','4.000','costo_total','80.00'),jsonb_build_object('categoria_id',upper(f.category_second::text),
    'cantidad_kg','2.0','costo_total','20.000'));
  perform pg_temp.check_true(pg_temp.checked(pg_temp.api_sql(f.farm_a,f.create_op,f.period_a,
    f.new_source,current_date-2,f.group_a,v_recipe))=r||'{"replayed":true}'::jsonb,
    'normalized UUID and numeric text share the exact replay identity');
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,f.create_op,f.period_a,f.new_source,current_date-2,
    f.group_a,jsonb_build_array(f.recipe->1,f.recipe->0)), '22023','operation_payload_conflict','operation_id',f.create_op);
  for q in select * from (values (f.capture_op),(f.occupancy_op)) operations(op) loop
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,q.op,f.period_a,gen_random_uuid(),current_date-2,f.group_a,f.recipe),
      '22023','operation_payload_conflict','operation_id',q.op);
  end loop;
  -- Current actor authorization is required even for an existing historical receipt.
  reset role;
  for actor in select * from (values (f.viewer_a,'authenticated'),(f.owner_b,'authenticated'),
    (null::uuid,'anon')) actors(uid,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.uid::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.uid,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    perform pg_temp.checked(v_sql,'42501');
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,f.create_op,f.period_a,f.new_source,
      current_date-2,f.group_a,f.recipe,true),'42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  set local role authenticated;
  for q in select * from (values
    (f.farm_b,f.period_a,f.group_a,current_date-2,f.recipe,'42501','forbidden','granja_id',f.farm_b),
    (f.farm_a,f.period_b,f.group_a,current_date-2,f.recipe,'42501','forbidden','period_id',f.period_b),
    (f.farm_a,f.period_a,f.group_other,current_date-2,f.recipe,'42501','forbidden','group_id',f.group_other),
    (f.farm_a,f.period_a,f.group_a,current_date-5,f.recipe,'22023','invalid_request','occurred_on',f.editor_source),
    (f.farm_a,f.period_a,f.group_a,current_date-2,jsonb_build_array(jsonb_build_object(
      'categoria_id',f.category_b,'cantidad_kg',1,'costo_total',0)),'42501','forbidden','category_id',f.category_b),
    (f.farm_a,f.period_a,f.group_a,current_date-2,jsonb_build_array(jsonb_build_object(
      'categoria_id',f.category_archived,'cantidad_kg',1,'costo_total',0)),'22023','invalid_request','category_id',f.category_archived),
    (f.farm_a,f.period_a,f.group_a,current_date-2,jsonb_build_array(jsonb_build_object(
      'categoria_id',f.category_a,'cantidad_kg',0,'costo_total',0)),'22023','invalid_request','ingredientes',f.editor_source))
    cases(farm,period_id,group_id,start_on,recipe,state,code,field,entity) loop
    perform pg_temp.checked(pg_temp.api_sql(q.farm,gen_random_uuid(),q.period_id,f.editor_source,
      q.start_on,q.group_id,q.recipe),q.state,q.code,q.field,q.entity);
  end loop;
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),f.period_b,f.editor_source,
    current_date-2,f.group_a,f.recipe,true),'42501','forbidden','period_id',f.period_b);
  perform pg_temp.checked(format('select economics_v2.create_group_feed_allocation(%L::uuid,%L::uuid,
    %L::uuid,%L::uuid,%L::date,%L::uuid,%L::jsonb)',f.farm_a,gen_random_uuid(),f.period_a,
    f.editor_source,current_date-2,f.group_a,f.recipe),'42501');
  reset role;
end;
$replay_and_refusals$;

do $historical_replay$
declare f record; r jsonb; v_before jsonb; a record; m record; v_sql text;
begin
  select * into f from pg_temp.targets;
  select result_row.result into r from pg_temp.results as result_row where result_row.actor=f.owner_a;
  v_sql:=pg_temp.api_sql(f.farm_a,f.create_op,f.period_a,f.new_source,current_date-2,f.group_a,f.recipe);
  v_before:=pg_temp.business_state();
  begin
    update public.cat_comida set activo=false where id=f.category_a;
    set local role authenticated;
    perform pg_temp.check_true(pg_temp.checked(v_sql)=r||'{"replayed":true}'::jsonb,
      'historical public replay precedes category archival admission');
    reset role;
    raise exception using errcode='Z0001',message='Restore category archival probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'category probe fully restored');
  begin
    -- Actual privileged verification action, NOT canonical public DELETE integration.
    select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.new_source;
    select * into m from public.mezcla where id=f.new_source;
    perform economics_v2.delete_group_feed_allocation(f.farm_a,gen_random_uuid(),f.period_a,m.id,
      a.updated_at,m.updated_at,a.source_digest);
    perform pg_temp.check_true(not exists(select 1 from public.mezcla where id=f.new_source)
      and not exists(select 1 from economics_v2.group_period_feed_allocations where mixture_id=f.new_source),
      'actual private admin deletion removes source and fact, not a forged closed period');
    set local role authenticated;
    perform pg_temp.check_true(pg_temp.checked(v_sql)=r||'{"replayed":true}'::jsonb,
      'historical public receipt replay precedes absent actual source and fact');
    reset role;
    raise exception using errcode='Z0001',message='Restore actual private deletion verification';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'actual deletion, receipt and fences fully restored');
end;
$historical_replay$;

do $composed_guards_and_editor$
declare f record; v_header record; v_component record; r jsonb; v_other jsonb; v_recipe jsonb;
begin
  select * into f from pg_temp.targets;
  select * into v_header from public.mezcla where id=f.new_source;
  select * into v_component from public.mezcla_comida where mezcla_id=v_header.id order by id limit 1;
  set local role authenticated;
  perform pg_temp.checked(format('update public.mezcla set updated_at=clock_timestamp() where id=%L',v_header.id),
    '23514','forward_group_period_required','mixture_id',v_header.id,true);
  perform pg_temp.checked(format('update public.mezcla_comida set cantidad=cantidad+1 where id=%L',v_component.id),
    '23514','forward_group_period_required','mixture_id',v_header.id,true);
  perform pg_temp.checked(format('update public.comida set precio=precio+1 where id=%L',v_component.comida_id),
    '23514','forward_group_period_required','mixture_id',v_header.id,true);
  perform pg_temp.checked(format('select public.crear_mezcla_completa(%L::uuid,%L::uuid,%L::date,%L::uuid,%L::jsonb)',
    f.farm_a,gen_random_uuid(),current_date-2,f.group_a,f.recipe),
    '23514','forward_group_period_required','group_id',f.group_a);
  perform pg_temp.checked(format('select public.actualizar_mezcla_completa(%L::uuid,%L::uuid,%L::timestamptz,
    %L::date,null::date,%L::uuid,%L::jsonb)',v_header.id,f.farm_a,v_header.updated_at,current_date-2,f.group_a,f.recipe),
    '23514','forward_group_period_required','mixture_id',v_header.id);
  perform pg_temp.checked(format('select public.eliminar_mezcla_completa(%L::uuid,%L::uuid)',f.farm_a,v_header.id),
    '23514','forward_group_period_required','mixture_id',v_header.id);
  reset role;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated')::text,true);
  v_recipe:=jsonb_build_array(jsonb_build_object('categoria_id',f.category_second,'cantidad_kg',1,'costo_total',0));
  v_other:=pg_temp.business_state(f.editor_source,f.editor_op);
  set local role authenticated;
  execute pg_temp.api_sql(f.farm_a,f.editor_op,f.period_a,f.editor_source,current_date-1,f.group_a,v_recipe) into r;
  perform pg_temp.check_true(current_user='authenticated' and r->'replayed'='false'::jsonb,
    'legitimate editor public creation with zero TOTAL cost');
  insert into pg_temp.results values(f.editor_a,r);
  perform pg_temp.check_true(pg_temp.checked(pg_temp.api_sql(f.farm_a,f.editor_op,f.period_a,
    f.editor_source,current_date-1,f.group_a,v_recipe,true))=r||'{"replayed":true}'::jsonb,
    'deliberate authenticated implementation capability uses same editor replay guards');
  reset role;
  perform pg_temp.check_true(pg_temp.business_state(f.editor_source,f.editor_op)=v_other,
    'editor creation preserves all other sources, full facts, receipts, events and basis');
  perform pg_temp.check_true((select created_by=f.editor_a from public.mezcla where id=f.editor_source)
    and (select a.quantity_kg=1 and a.total_cost=0 and a.source_updated_at=m.updated_at
      and a.source_digest=economics_v2.validate_group_feed_source(f.farm_a,f.period_a,m.id,m.updated_at)->>'source_digest'
      from economics_v2.group_period_feed_allocations a join public.mezcla m on m.id=a.mixture_id
      where m.id=f.editor_source) and (select sum(total_cost)=110 and sum(quantity_kg)=9
      from economics_v2.group_period_feed_allocations where period_id=f.period_a),
    'actual editor creator, validated fact and three-source live SUM 110/9');
  perform pg_temp.check_true((select r=jsonb_build_object('contract_version','group-economics.forward.v3',
    'operation_id',f.editor_op,'mixture_id',f.editor_source,'period_id',f.period_a,'allocation_id',a.id,
    'updated_at',a.updated_at,'component_count',1,'quantity_kg',1,'total_cost',0,
    'source_digest',a.source_digest,'replayed',false) from economics_v2.group_period_feed_allocations a
    where a.mixture_id=f.editor_source) and (select result=r and event_position is null
    from economics_v2.group_occupancy_operations where granja_id=f.farm_a and operation_id=f.editor_op)
    and (select count(*)=1 and sum(mc.cantidad)=1 and sum(food.precio)=0 and sum(food.cantidad)=1
      from public.mezcla_comida mc join public.comida food on food.id=mc.comida_id where mc.mezcla_id=f.editor_source),
    'editor exact11 receipt and actual zero-cost purchase agree');
  perform pg_temp.check_true(not exists(select 1 from pg_temp.acl_baseline b
    left join pg_class c on b.kind='table' and c.oid=b.oid
    left join pg_proc p on b.kind='function' and p.oid=b.oid
    where b.acl is distinct from case when b.kind='table' then to_jsonb(c.relacl) else to_jsonb(p.proacl) end),
    'all preexisting persistent table and function ACLs unchanged by fixture');
  set constraints all immediate;
end;
$composed_guards_and_editor$;

select jsonb_build_object(
  'result','group_economics_forward_feed_create_api_pass',
  'assertion_count',(select count(*) from assertions),'fixture_ids',(select to_jsonb(f) from targets f),
  'locking_evidence','sequential_only','independent_review','pending','real_closure_proven',false,
  'production_gateway_integrated',false,'canonical_group_food_create_api_integrated',true,
  'canonical_group_food_api_integrated',false,'sql_rpc_path_proven',true,'http_transport_proven',false,
  'all_legacy_mutation_paths_guarded',false,'privileged_business_provenance_proven',false) evidence;
rollback;
