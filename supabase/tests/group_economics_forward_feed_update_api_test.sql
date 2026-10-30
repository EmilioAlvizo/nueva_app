begin;

-- HUMAN Sandbox Dashboard only: review, then run this FULL BEGIN/ROLLBACK file.
-- Fixture-first preparation ONLY; no execution, implementation or independent PASS.
-- Requires qualified CREATE, completion storage/primitives and retained private cores/guards.
-- The first named PUBLIC UPDATE in $first$ must expose genuine 42883, uncaught.
-- No absent-function regprocedure preflight, producer proxy or synthesized companion.
-- Public INVOKER -> authorized private DEFINER -> existing inaccessible INVOKER core.
-- Both NEW functions: exact9 required parameters below, jsonb result, postgres owner,
-- empty search_path, authenticated EXECUTE only. Existing ACLs/schema stay unchanged.
-- Map p_mezcla_id to p_mixture_id; p_expected_updated_at is the CLIENT ALLOCATION
-- token, never the current header stamp. assert_group_writer_actor precedes lookup.
-- Normalize scalars/ordered recipe -> API hash -> same-farm group-economics: advisory
-- lock -> immutable ledger/companion BEFORE mutable targets. Historical retry verifies
-- actor/kind/targets/client token/Group/public hash, reconstructed private hash and
-- stored result digest, then CALLS actual private UPDATE with original predecessors.
-- Source review must verify that delegation and absence of mutable reads: matching
-- returned JSON alone is NOT runtime tracing proof. No tracing flag is manufactured.
-- Fresh lock order: Groups ascending -> period -> allocation -> header. Group must
-- match request, period and header. Read source predecessors from allocation capture;
-- actual source timestamp/digest drift must fail rather than become new context.
-- Core receipt first -> verify actual core/result bindings -> companion INSERT ->
-- public RETURN, one transaction. No backfill for a ledger without its companion.
-- Missing companion/caller conflict:22023; inconsistent core/result:23514; stale:40001.
-- Completion exact14, bridge group-feed-api-completion.v1, feed_update, Group required.
-- Public envelope6/request8/domain group-feed-update-api.v1; private request9/domain
-- group-feed-update.v1 omits Group and includes captured source version/digest.
-- No recipe/result duplication in completion, no new public parameters/result keys.
-- Sequential SQL role RPC only; no HTTP, concurrency, closure, UI or all-route proof.
-- Full qualification requires this base AND the standalone integrity fixture GREEN,
-- plus remaining composed/native gates. Base GREEN alone is NOT release readiness.
-- Extended drift/corruption/history/flag/metadata/fresh-header proofs move there;
-- they remain required, against the UNCHANGED installed gateway, not earlier receipts.
-- Isolate Sandbox traffic; setup event sequence issuance is NOT rewound by ROLLBACK.
-- Full future gateway budget includes both complete bodies and own ACLs (260-330 lines).
-- Do not compress this fixture or copy qualified core/normalizers to fit the 800 cap.

create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() owner_b,gen_random_uuid() farm_a,gen_random_uuid() farm_b,
  gen_random_uuid() type_a,gen_random_uuid() meat_a,gen_random_uuid() animal_a,
  gen_random_uuid() group_a,gen_random_uuid() group_other,
  gen_random_uuid() category_a,gen_random_uuid() category_second,
  gen_random_uuid() source_a,gen_random_uuid() sibling,gen_random_uuid() create_op,
  gen_random_uuid() sibling_create_op,gen_random_uuid() entry_op,
  gen_random_uuid() owner_op,gen_random_uuid() editor_op,gen_random_uuid() fault_op;
create temp table assertions(label text not null);
create temp table evidence(atomic_rollback boolean);
insert into evidence values(false);
create temp table calls(operation_id uuid,actor_id uuid,allocation_id uuid,
  allocation_stamp timestamptz,source_stamp timestamptz,source_digest text,
  start_on date,end_on date,recipe jsonb,result jsonb);
create temp table owned_food_ids(id uuid primary key);
create temp table watched as
select n.nspname schema_name,c.relname table_name from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where c.relkind in ('r','p') and (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users'));
create temp table sequences as
select n.nspname schema_name,c.relname sequence_name from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity');

create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
-- The only client-callable DEFINER helper is read-only private evidence access.
-- Remember OLD food IDs before replacement; after-state also excludes new IDs.
create function pg_temp.business_state(p_op uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; f record; v_rows jsonb; v_state jsonb:='{}'; v_filter text; v_foods uuid[];
begin
  select * into f from pg_temp.ids;
  select array_agg(id) into v_foods from (select id from pg_temp.owned_food_ids
    union select comida_id from public.mezcla_comida where mezcla_id=f.source_a) foods;
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    v_filter:='';
    if p_op is not null then
      if t.schema_name='public' and t.table_name='mezcla' then v_filter:=' where r.id<>$1';
      elsif t.schema_name='public' and t.table_name='mezcla_comida' then v_filter:=' where r.mezcla_id<>$1';
      elsif t.schema_name='public' and t.table_name='comida' then v_filter:=' where not r.id=any($2)';
      elsif t.schema_name='economics_v2' and t.table_name='group_period_feed_allocations' then
        v_filter:=' where r.mixture_id<>$1';
      elsif t.schema_name='economics_v2' and t.table_name in ('group_occupancy_operations','group_feed_api_completions') then
        v_filter:=' where not (r.granja_id=$5 and r.operation_id=$3)';
      elsif t.schema_name='group_feed_integrity' and t.table_name='fences' then
        v_filter:=' where not (r.scope=''group'' and r.entity_id=$4)';
      end if;
    end if;
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r%s',t.schema_name,t.table_name,v_filter)
      into v_rows using f.source_a,v_foods,p_op,f.group_a,f.farm_a;
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
-- INVOKER text builder: dispatches only the actual public or authorized private API.
create function pg_temp.api_sql(p_op uuid,p_stamp timestamptz,p_recipe jsonb,
  p_start date,p_end date,p_group uuid,p_farm uuid,p_impl boolean default false)
returns text language plpgsql security invoker set search_path='' as $$
declare f record;
begin
  select * into f from pg_temp.targets;
  return format('select %s(p_mezcla_id=>%L::uuid,p_granja_id=>%L::uuid,p_operation_id=>%L::uuid,
    p_period_id=>%L::uuid,p_expected_updated_at=>%L::timestamptz,p_fecha_inicio=>%L::date,
    p_fecha_termino=>%L::date,p_grupo_id=>%L::uuid,p_ingredientes=>%L::jsonb)',
    case when p_impl then 'economics_v2.update_group_feed_impl' else 'public.actualizar_mezcla_grupo_v1' end,
    f.source_a,p_farm,p_op,f.period_a,p_stamp,p_start,p_end,p_group,p_recipe);
end;
$$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,
  p_field text default null,p_entity uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_result jsonb; v_state text; v_detail text;
begin
  v_before:=pg_temp.business_state();
  perform set_config('feed_update_api.observe',case when p_state='ZC001' then 'off' else 'on' end,true);
  begin execute p_sql into v_result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics v_state=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform set_config('feed_update_api.observe','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'full rows, fences, receipts and sequences unchanged');
  if p_state is null then
    perform pg_temp.check_true(v_result is not null,'historical result returned');
  else
    perform pg_temp.check_true(v_state=p_state,'expected SQLSTATE '||p_state);
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb=jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field,'entity_id',p_entity),'exact4 typed refusal');
    end if;
    if p_state='ZC001' then
      perform pg_temp.check_true(v_detail='observed_after_real_core_completion','late fault actually followed business mutation');
      update pg_temp.evidence set atomic_rollback=true;
    end if;
  end if;
  return v_result;
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"feed-update-api"}'::jsonb from ids
cross join lateral unnest(array[owner_a,editor_a,viewer_a,owner_b]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'UPDATE API farm A',owner_a from ids
union all select farm_b,owner_b,'UPDATE API farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'UPDATE API type',owner_a from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'UPDATE API meat','carne',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'UPDATE API Group '||g::text,owner_a from ids
cross join lateral unnest(array[group_a,group_other]) g;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select c,farm_a,'UPDATE API category '||c::text,true,owner_a from ids
cross join lateral unnest(array[category_a,category_second]) c;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,owner_a from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
create temp table targets as select f.*,
  (economics_v2.enter_group_meat_initial(farm_a,entry_op,animal_a,
    current_date-4,group_a,meat_a,'{}')->>'destination_period_id')::uuid period_a,
  jsonb_build_array(jsonb_build_object('categoria_id',category_a,'cantidad_kg',4,'costo_total',80),
    jsonb_build_object('categoria_id',category_second,'cantidad_kg',2,'costo_total',20)) recipe from ids f;
do $setup_access$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$setup_access$;
grant select on pg_temp.ids,pg_temp.targets,pg_temp.calls to authenticated,anon;
grant insert on pg_temp.assertions to authenticated,anon;
grant update on pg_temp.evidence to authenticated,anon;
revoke all on function pg_temp.check_true(boolean,text),pg_temp.business_state(uuid),
  pg_temp.api_sql(uuid,timestamptz,jsonb,date,date,uuid,uuid,boolean),
  pg_temp.checked(text,text,text,text,uuid) from public;
grant execute on function pg_temp.check_true(boolean,text),pg_temp.business_state(uuid),
  pg_temp.api_sql(uuid,timestamptz,jsonb,date,date,uuid,uuid,boolean),
  pg_temp.checked(text,text,text,text,uuid) to authenticated,anon;
do $setup_sources$
declare f record; q record; a record; v_recipe jsonb;
begin
  select * into f from pg_temp.targets;
  v_recipe:=jsonb_build_array(jsonb_build_object('categoria_id',f.category_a,'cantidad_kg',2,'costo_total',10));
  set local role authenticated;
  for q in select * from (values(f.source_a,f.create_op),(f.sibling,f.sibling_create_op)) sources(id,op) loop
    perform public.crear_mezcla_grupo_v1(p_granja_id=>f.farm_a,p_operation_id=>q.op,p_period_id=>f.period_a,
      p_mezcla_id=>q.id,p_fecha_inicio=>current_date-2,p_grupo_id=>f.group_a,p_ingredientes=>v_recipe);
  end loop;
  reset role;
  -- Namespace collisions with real private/occupancy receipts belong to extended proof.
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.source_a;
  insert into pg_temp.calls values(f.owner_op,f.owner_a,a.id,a.updated_at,a.source_updated_at,
    a.source_digest,current_date-2,null,f.recipe,null);
  insert into pg_temp.owned_food_ids select comida_id from public.mezcla_comida where mezcla_id=f.source_a;
  perform pg_temp.check_true((select a.source_updated_at=m.updated_at and m.created_by=f.owner_a
    from public.mezcla m where m.id=f.source_a),'real CREATE source capture and immutable creator baseline');
end;
$setup_sources$;
set constraints all immediate;

create function pg_temp.observe_dml()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('feed_update_api.observe',true)='on' then
    raise exception 'UPDATE API replay/refusal attempted DML: %.% %',tg_table_schema,tg_table_name,tg_op;
  end if;
  return null;
end;
$$;
do $observers$
declare t record;
begin
  for t in select * from pg_temp.watched loop
    execute format('create trigger feed_update_api_observer before insert or update or delete or truncate
      on %I.%I for each statement execute function pg_temp.observe_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;
do $first$
declare f record; c record; v_other jsonb; r jsonb;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls where operation_id=f.owner_op;
  v_other:=pg_temp.business_state(f.owner_op);
  set local role authenticated;
  -- FIRST actual PUBLIC UPDATE: exact9 named arguments; missing 42883 escapes.
  r:=public.actualizar_mezcla_grupo_v1(p_mezcla_id=>f.source_a::uuid,p_granja_id=>f.farm_a::uuid,
    p_operation_id=>f.owner_op::uuid,p_period_id=>f.period_a::uuid,
    p_expected_updated_at=>c.allocation_stamp::timestamptz,p_fecha_inicio=>c.start_on::date,
    p_fecha_termino=>c.end_on::date,p_grupo_id=>f.group_a::uuid,p_ingredientes=>c.recipe::jsonb);
  perform pg_temp.check_true(current_user='authenticated','first public UPDATE uses actual client SQL role');
  reset role;
  update pg_temp.calls set result=r where operation_id=f.owner_op;
  perform pg_temp.check_true(pg_temp.business_state(f.owner_op)=v_other,
    'owner UPDATE preserves sibling source/components/fact, earlier receipts, basis and sequences');
end;
$first$;

-- ADMIN INVOKER readback only; this function never calls or replaces a producer.
create function pg_temp.assert_completion(p_op uuid)
returns void language plpgsql security invoker set search_path='' as $$
declare f record; c record; a record; m record; o record; s record; v_public jsonb; v_core jsonb; v_context jsonb;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls where operation_id=p_op;
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.source_a;
  select * into m from public.mezcla where id=f.source_a;
  select * into o from economics_v2.group_occupancy_operations where granja_id=f.farm_a and operation_id=p_op;
  select * into s from economics_v2.group_feed_api_completions where granja_id=f.farm_a and operation_id=p_op;
  v_context:=economics_v2.validate_group_feed_source(f.farm_a,f.period_a,f.source_a,m.updated_at);
  perform pg_temp.check_true(m.created_by=f.owner_a and m.grupo_id=f.group_a and m.granja_id=f.farm_a
    and m.fecha_inicio=c.start_on and m.fecha_termino is not distinct from c.end_on and m.group_feed_meat_exempt
    and a.id=c.allocation_id and a.period_id=f.period_a and a.granja_id=f.farm_a and a.finalized_at is null
    and a.updated_at=m.updated_at and a.updated_at>c.allocation_stamp and a.source_updated_at=m.updated_at
    and a.source_digest=v_context->>'source_digest','same owned source/fact, actual clock, immutable creator');
  perform pg_temp.check_true((select jsonb_agg(jsonb_build_object('categoria_id',food.cat_comida_id,
    'cantidad_kg',mc.cantidad,'costo_total',food.precio) order by food.cat_comida_id)
    from public.mezcla_comida mc join public.comida food on food.id=mc.comida_id where mc.mezcla_id=f.source_a)
    =(select jsonb_agg(value order by (value->>'categoria_id')::uuid) from jsonb_array_elements(c.recipe))
    and a.component_count=(v_context->>'component_count')::integer
    and a.quantity_kg=(v_context->>'quantity_kg')::numeric and a.total_cost=(v_context->>'total_cost')::numeric,
    'actual dedicated purchases and validated fact equal requested kg/TOTAL costs');
  perform pg_temp.check_true(c.result=jsonb_build_object('contract_version','group-economics.forward.v3',
    'operation_id',p_op,'mixture_id',f.source_a,'period_id',f.period_a,'allocation_id',a.id,
    'updated_at',a.updated_at,'component_count',a.component_count,'quantity_kg',a.quantity_kg,
    'total_cost',a.total_cost,'source_digest',a.source_digest,'replayed',false)
    and o.result=c.result and o.event_position is null,'exact11 result is actual non-replayed completed core receipt');
  v_public:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_domain','group-feed-update-api.v1',
    'granja_id',f.farm_a,'actor_id',c.actor_id,'operation_id',p_op,'request',jsonb_build_object(
      'action','feed_update','period_id',f.period_a,'mixture_id',f.source_a,
      'expected_allocation_updated_at_utc',to_char(c.allocation_stamp at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'fecha_inicio',c.start_on,'fecha_termino',c.end_on,'grupo_id',f.group_a,'ingredientes',c.recipe));
  v_core:=v_public||jsonb_build_object('operation_domain','group-feed-update.v1',
    'request',((v_public->'request')-'grupo_id')||jsonb_build_object('expected_source_updated_at_utc',
      to_char(c.source_stamp at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'expected_source_digest',c.source_digest));
  perform pg_temp.check_true(to_jsonb(s)=jsonb_build_object('granja_id',f.farm_a,'operation_id',p_op,
    'bridge_version','group-feed-api-completion.v1','operation_kind','feed_update','actor_id',c.actor_id,
    'period_id',f.period_a,'mixture_id',f.source_a,'group_id',f.group_a,
    'expected_allocation_updated_at',c.allocation_stamp,'predecessor_source_updated_at',c.source_stamp,
    'predecessor_source_digest',c.source_digest,'public_payload_hash',
    encode(sha256(convert_to(economics_v2.canonical_group_request(v_public)::text,'UTF8')),'hex'),
    'core_payload_hash',encode(sha256(convert_to(economics_v2.canonical_group_request(v_core)::text,'UTF8')),'hex'),
    'core_result_hash',encode(sha256(convert_to(economics_v2.canonical_group_request(o.result)::text,'UTF8')),'hex'))
    and s.core_payload_hash=o.payload_hash,'gateway produced exact14 original context with independent API8/core9/result bindings');
  perform pg_temp.check_true((select sum(total_cost)=a.total_cost+10 and sum(quantity_kg)=a.quantity_kg+2
    from economics_v2.group_period_feed_allocations where period_id=f.period_a)
    and (select remaining_basis=300 from economics_v2.group_animal_acquisition_basis
      where animal_id=f.animal_a and granja_id=f.farm_a),'sibling 10/2 coexists and acquisition basis stays 300');
end;
$$;
select pg_temp.assert_completion(owner_op) from ids;
-- Complete catalog/retained-ACL regression moves to extended proof; actual core
-- EXECUTE refusal remains below alongside PUBLIC/direct implementation authorization.

do $editor_and_replay$
declare f record; a record; c record; r jsonb; v_other jsonb; v_recipe jsonb; v_sql text; q record;
begin
  select * into f from pg_temp.targets;
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.source_a;
  v_recipe:=jsonb_build_array(jsonb_build_object('categoria_id',f.category_second,'cantidad_kg',2,'costo_total',30));
  insert into pg_temp.owned_food_ids select comida_id from public.mezcla_comida where mezcla_id=f.source_a on conflict do nothing;
  insert into pg_temp.calls values(f.editor_op,f.editor_a,a.id,a.updated_at,a.source_updated_at,a.source_digest,
    current_date-1,null,v_recipe,null);
  v_other:=pg_temp.business_state(f.editor_op);
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated')::text,true);
  set local role authenticated;
  execute pg_temp.api_sql(f.editor_op,a.updated_at,v_recipe,current_date-1,null,f.group_a,f.farm_a) into r;
  perform pg_temp.check_true(current_user='authenticated','legitimate second editor UPDATE uses actual client role');
  perform pg_temp.check_true(pg_temp.checked(pg_temp.api_sql(f.editor_op,a.updated_at,v_recipe,
    current_date-1,null,f.group_a,f.farm_a,true))=r||'{"replayed":true}'::jsonb,'direct authorized implementation same-actor replay');
  reset role;
  update pg_temp.calls set result=r where operation_id=f.editor_op;
  perform pg_temp.check_true(pg_temp.business_state(f.editor_op)=v_other,'editor preserves ALL earlier completions and sibling history');
  perform pg_temp.assert_completion(f.editor_op);
  select * into c from pg_temp.calls where operation_id=f.owner_op;
  v_sql:=pg_temp.api_sql(c.operation_id,c.allocation_stamp,c.recipe,c.start_on,c.end_on,f.group_a,f.farm_a);
  set local role authenticated;
  perform pg_temp.checked(v_sql,'22023','operation_payload_conflict','operation_id',c.operation_id);
  reset role;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  set local role authenticated;
  perform pg_temp.check_true(pg_temp.checked(v_sql)=c.result||'{"replayed":true}'::jsonb,'original owner result after later editor update');
  v_recipe:=jsonb_build_array(jsonb_build_object('categoria_id',upper(f.category_a::text),'cantidad_kg','4.000','costo_total','80.00'),
    jsonb_build_object('categoria_id',upper(f.category_second::text),'cantidad_kg','2.0','costo_total','20.000'));
  perform pg_temp.check_true(pg_temp.checked(pg_temp.api_sql(c.operation_id,c.allocation_stamp,v_recipe,c.start_on,null,
    f.group_a,f.farm_a))=c.result||'{"replayed":true}'::jsonb,'normalized UUID/numeric recipe historical identity');
  for q in select * from (values
    (f.group_other,c.start_on,c.end_on,c.allocation_stamp,c.recipe),
    (f.group_a,c.start_on,c.end_on,c.allocation_stamp+interval '1 second',c.recipe))
    changes(group_id,start_on,end_on,stamp,recipe) loop
    perform pg_temp.checked(pg_temp.api_sql(c.operation_id,q.stamp,q.recipe,q.start_on,q.end_on,q.group_id,f.farm_a),
      '22023','operation_payload_conflict','operation_id',c.operation_id);
  end loop;
  reset role;
end;
$editor_and_replay$;

do $authorization_and_stale$
declare f record; c record; a record; v_actor record; v_sql text;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls where operation_id=f.owner_op;
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.source_a;
  v_sql:=pg_temp.api_sql(c.operation_id,c.allocation_stamp,c.recipe,c.start_on,null,f.group_a,f.farm_a);
  for v_actor in select * from (values(f.viewer_a,'authenticated'),(f.owner_b,'authenticated'),(null::uuid,'anon')) actors(uid,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(v_actor.uid::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_actor.uid,'role',v_actor.role_name)::text,true);
    execute format('set local role %I',v_actor.role_name);
    perform pg_temp.checked(v_sql,'42501');
    perform pg_temp.checked(pg_temp.api_sql(c.operation_id,c.allocation_stamp,c.recipe,c.start_on,null,f.group_a,f.farm_a,true),'42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  set local role authenticated;
  perform pg_temp.checked(pg_temp.api_sql(gen_random_uuid(),a.updated_at,f.recipe,c.start_on,null,f.group_other,f.farm_a),
    '42501','forbidden','group_id',f.group_other);
  perform pg_temp.checked(pg_temp.api_sql(gen_random_uuid(),a.updated_at,f.recipe,c.start_on,null,f.group_a,f.farm_b),
    '42501','forbidden','granja_id',f.farm_b);
  perform pg_temp.checked(pg_temp.api_sql(gen_random_uuid(),c.allocation_stamp,f.recipe,c.start_on,null,f.group_a,f.farm_a),
    '40001','stale_write','allocation_id',a.id);
  perform pg_temp.checked(format('select economics_v2.update_group_feed_allocation(%L::uuid,%L::uuid,%L::uuid,%L::uuid,
    %L::timestamptz,%L::timestamptz,%L::text,%L::date,null::date,%L::jsonb)',f.farm_a,gen_random_uuid(),f.period_a,
    f.source_a,a.updated_at,a.source_updated_at,a.source_digest,c.start_on,f.recipe),'42501');
  reset role;
end;
$authorization_and_stale$;

-- Dedicated companion trigger: NEW always has the exact completion row type.
-- No business producer, forged receipt or generic NEW-field short-circuit hazard.
create function pg_temp.late_completion_fault()
returns trigger language plpgsql security invoker set search_path='' as $$
declare f record; a record; m record; o record; v_context jsonb;
begin
  select * into f from pg_temp.targets;
  if new.operation_id<>f.fault_op then return new; end if;
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=new.mixture_id;
  select * into m from public.mezcla where id=new.mixture_id;
  select * into o from economics_v2.group_occupancy_operations
    where granja_id=new.granja_id and operation_id=new.operation_id;
  v_context:=economics_v2.validate_group_feed_source(new.granja_id,new.period_id,new.mixture_id,m.updated_at);
  if o.operation_id is null or o.event_position is not null or new.core_payload_hash is distinct from o.payload_hash
    or new.core_result_hash is distinct from encode(sha256(convert_to(economics_v2.canonical_group_request(o.result)::text,'UTF8')),'hex')
    or m.updated_at is distinct from a.updated_at or a.source_updated_at is distinct from m.updated_at
    or a.updated_at<=new.expected_allocation_updated_at or a.total_cost<>100 or a.quantity_kg<>6 or a.component_count<>2
    or a.source_digest is distinct from v_context->>'source_digest'
    or (v_context->>'total_cost')::numeric<>100 or (v_context->>'quantity_kg')::numeric<>6
    or o.result is distinct from jsonb_build_object('contract_version','group-economics.forward.v3',
      'operation_id',new.operation_id,'mixture_id',new.mixture_id,'period_id',new.period_id,'allocation_id',a.id,
      'updated_at',a.updated_at,'component_count',2,'quantity_kg',6,'total_cost',100,'source_digest',a.source_digest,'replayed',false) then
    raise exception 'Companion fault reached before real completed business mutation';
  end if;
  raise exception using errcode='ZC001',message='Deliberate late companion INSERT failure',
    detail='observed_after_real_core_completion';
end;
$$;
create trigger feed_update_api_late_fault before insert on economics_v2.group_feed_api_completions
for each row execute function pg_temp.late_completion_fault();
do $atomic_fault$
declare f record; a record;
begin
  select * into f from pg_temp.targets;
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.source_a;
  perform pg_temp.check_true(a.total_cost=30 and a.quantity_kg=2,'late probe has genuinely different old business totals');
  set local role authenticated;
  perform pg_temp.checked(pg_temp.api_sql(f.fault_op,a.updated_at,f.recipe,current_date-2,null,f.group_a,f.farm_a),'ZC001');
  reset role;
  perform pg_temp.check_true((select atomic_rollback from pg_temp.evidence),'metadata fault rolls back source, foods, fact, ledger, companion and fences');
end;
$atomic_fault$;

set constraints all immediate;
select jsonb_build_object(
  'result','group_economics_forward_feed_update_api_pass','assertion_count',(select count(*) from assertions),
  'fixture_ids',(select to_jsonb(f) from targets f),'locking_evidence','sequential_only','independent_review','pending',
  'real_closure_proven',false,'production_gateway_integrated',false,'canonical_group_food_update_api_integrated',true,
  'canonical_group_food_delete_api_integrated',false,'canonical_group_food_api_integrated',false,
  'sql_rpc_path_proven',true,'http_transport_proven',false,
  'metadata_atomic_business_rollback_proven',(select atomic_rollback from evidence),
  'extended_update_integrity_proven',false,'fresh_header_token_rejection_observed',false,
  'full_update_qualification_proven',false,'production_release_ready',false,
  'all_legacy_mutation_paths_guarded',false,'privileged_business_provenance_proven',false) evidence;
rollback;
