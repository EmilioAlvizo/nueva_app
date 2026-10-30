begin;

-- HUMAN Sandbox Dashboard only: review, then run this FULL BEGIN/ROLLBACK file.
-- SECOND delivery unit: PURE PRIVATE PRIMITIVES, dependent on installed and
-- qualified completion STORAGE. Do not run before the storage foundation GREEN.
-- Standalone real setup; no include, persistent fixture helper or fake receipt.
-- Preparation ONLY: no execution, migration, business gateway or PASS claim here.
-- First NEW primitive invocation is normalize_group_feed_api_ingredients in
-- $first_primitive$: expected initial 42883 escapes unchanged, NOT captured.
-- No regprocedure preflight, missing-helper simulation or replacement normalizer.
-- Setup runs qualified CREATE as authenticated, actual private UPDATE/DELETE as
-- admin with owner JWT, and inserts metadata AFTER physical source/fact deletion.
-- Only that setup mutates business data. Isolate Sandbox traffic; setup event
-- sequence issuance is NOT rewound by ROLLBACK. Never run against production.
--
-- Exact NEW PRIVATE contracts, all arguments required, no defaults/overloads:
-- economics_v2.normalize_group_feed_api_ingredients(
--   p_ingredientes jsonb,p_mixture_id uuid) returns jsonb.
-- Ordered nonempty array, exact3 keys categoria_id/cantidad_kg/costo_total;
-- UUID and numeric text normalize to UUID strings and JSON numbers. Same private
-- UPDATE grammar: unique UUIDs, finite kg>0, finite TOTAL cost>=0, checked sums.
-- Refusals: 22023, exact4 DETAIL invalid_request/ingredientes/p_mixture_id.
-- No table, JWT/actor, category-policy reads or writes. VOLATILE is allowed;
-- logical purity does NOT require IMMUTABLE or fake authorization.
-- economics_v2.group_feed_api_payload_hash(
--   p_operation_kind text,p_granja_id uuid,p_operation_id uuid,p_actor_id uuid,
--   p_period_id uuid,p_mixture_id uuid,p_expected_allocation_updated_at timestamptz,
--   p_fecha_inicio date,p_fecha_termino date,p_grupo_id uuid,p_ingredientes jsonb)
-- returns text. UPDATE requires start/group/recipe, nullable end. DELETE requires
-- ALL four unused UPDATE args SQL NULL (JSON null recipe is NOT SQL NULL).
-- Required farm/op/actor/period/mixture; finite allocation token. UPDATE date
-- grammar matches core finite start<=today, start<=end<=today when end is present;
-- no table-history checks. No IMMUTABLE requirement with current_date grammar.
-- Scalar errors: 22023 invalid_request, field=operation_kind/granja_id/
-- operation_id/actor_id/period_id/mixture_id/expected_allocation_updated_at/
-- occurred_on/group_id/request; entity is mixture_id except required UUID/kind
-- omissions use NULL. DELETE non-NULL unused args use request/mixture_id.
-- Both helpers are private INVOKER, empty search_path, no client EXECUTE; only
-- normalize then canonical_group_request and SHA256, never receipt capabilities.
-- Public envelope EXACT6 keys, contract group-economics.forward.v3, domains
-- group-feed-update-api.v1 / group-feed-delete-api.v1; UPDATE request EXACT8,
-- DELETE EXACT4. UTC timestamps YYYY-MM-DD"T"HH24:MI:SS.US"Z". Array order is
-- identity, numeric scale is not. Existing private UPDATE9/DELETE6 fingerprints
-- and core ACLs remain unchanged; no entity/API contract-version increment.
--
-- Companion exact14/PK/only durable ledger FK, FORCED RLS and integration rows
-- are prerequisite checks here; the full storage constraint matrix belongs to
-- group_economics_forward_feed_api_completion_foundation_test.sql, not rerun here.
-- This fixture does NOT prove gateways, API replay, atomic business rollback,
-- privileged business provenance, HTTP, concurrency, Flutter or real closure.
-- Sum-overflow parity is required; huge-numeric probing is deliberately omitted,
-- not claimed covered. Snapshot equality proves persisted state only, not absence
-- of transient DML or table reads. Future implementation still needs code review.

create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() farm_a,gen_random_uuid() type_a,
  gen_random_uuid() meat_a,gen_random_uuid() group_a,gen_random_uuid() animal_a,
  gen_random_uuid() category_a,gen_random_uuid() category_second,
  gen_random_uuid() source_a,gen_random_uuid() create_op,
  gen_random_uuid() update_op,gen_random_uuid() delete_op;
create temp table assertions(label text not null);
create temp table contexts(
  granja_id uuid,operation_id uuid,bridge_version text,operation_kind text,
  actor_id uuid,period_id uuid,mixture_id uuid,group_id uuid,
  expected_allocation_updated_at timestamptz,predecessor_source_updated_at timestamptz,
  predecessor_source_digest text,public_payload_hash text,core_payload_hash text,
  core_result_hash text,public_envelope jsonb,core_envelope jsonb,core_result jsonb,
  hash_args jsonb);
create temp table watched as
select n.nspname schema_name,c.relname table_name from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where c.relkind in ('r','p') and (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users'));
create temp table watched_sequences as
select n.nspname schema_name,c.relname sequence_name from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity');
create temp table protected_acl as
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
-- Read-only admin snapshot; no client grant or business producer proxy.
create function pg_temp.business_state()
returns jsonb language plpgsql security invoker set search_path='' as $$
declare t record; v_rows jsonb; v_state jsonb:='{}';
begin
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r',t.schema_name,t.table_name) into v_rows;
    v_state:=v_state||jsonb_build_object(t.schema_name||'.'||t.table_name,v_rows);
  end loop;
  for t in select * from pg_temp.watched_sequences order by schema_name,sequence_name loop
    execute format('select jsonb_build_object(''last_value'',last_value,''is_called'',is_called)
      from %I.%I',t.schema_name,t.sequence_name) into v_rows;
    v_state:=v_state||jsonb_build_object(t.schema_name||'.'||t.sequence_name,v_rows);
  end loop;
  return v_state;
end;
$$;
create function pg_temp.expect_error(p_sql text,p_state text,p_field text default null,
  p_entity uuid default null)
returns void language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_state text; v_detail text;
begin
  v_before:=pg_temp.business_state();
  begin
    execute p_sql;
    set constraints all immediate;
    raise exception using errcode='ZT001',message='Expected refusal did not occur';
  exception when others then
    get stacked diagnostics v_state=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform pg_temp.check_true(v_state=p_state,'refusal SQLSTATE '||p_state);
  if p_field is not null then
    perform pg_temp.check_true(v_detail::jsonb=jsonb_build_object(
      'contract_version','group-economics.forward.v3','code','invalid_request',
      'field',p_field,'entity_id',p_entity),'exact4 typed primitive refusal '||p_field);
  end if;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'refusal restores all rows/fences/receipts/sequences');
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select owner_a,'authenticated','authenticated','{"fixture":"feed-api-completion-primitives"}'::jsonb from ids;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Completion primitives farm',owner_a from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Completion primitives type',owner_a from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Completion primitives meat','carne',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_a,farm_a,type_a,'Completion primitives Group',owner_a from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select c,farm_a,'Completion primitives category '||c::text,true,owner_a from ids
cross join lateral unnest(array[category_a,category_second]) c;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,owner_a from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;

do $setup$
declare f record; a record; m record; o record; v_entry jsonb; v_create jsonb;
  v_period uuid; v_recipe jsonb; v_op uuid; v_kind text; v_request jsonb;
  v_public jsonb; v_core jsonb; v_result jsonb; v_args jsonb;
begin
  select * into f from pg_temp.ids;
  v_entry:=economics_v2.enter_group_meat_initial(f.farm_a,gen_random_uuid(),f.animal_a,
    current_date-4,f.group_a,f.meat_a,'{}');
  v_period:=(v_entry->>'destination_period_id')::uuid;
  v_recipe:=jsonb_build_array(
    jsonb_build_object('categoria_id',f.category_a,'cantidad_kg',4,'costo_total',80),
    jsonb_build_object('categoria_id',f.category_second,'cantidad_kg',2,'costo_total',20));
  set local role authenticated;
  v_create:=public.crear_mezcla_grupo_v1(p_granja_id=>f.farm_a,p_operation_id=>f.create_op,
    p_period_id=>v_period,p_mezcla_id=>f.source_a,p_fecha_inicio=>current_date-2,
    p_grupo_id=>f.group_a,p_ingredientes=>v_recipe);
  reset role;
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.source_a;
  select * into m from public.mezcla where id=f.source_a;
  perform pg_temp.check_true((v_create->>'updated_at')::timestamptz=a.updated_at
    and a.source_updated_at=m.updated_at,'CREATE token is allocation clock; source clock captured separately');
  -- Do not require different clocks or manufacture +1: preserve actual observations.
  for v_kind,v_op in select * from (values('feed_update',f.update_op),('feed_delete',f.delete_op)) q(kind,op) loop
    select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.source_a;
    select * into m from public.mezcla where id=f.source_a;
    perform pg_temp.check_true(a.source_updated_at=m.updated_at,'captured predecessor equals actual source');
    v_request:=jsonb_build_object('action',v_kind,'period_id',v_period,'mixture_id',f.source_a,
      'expected_allocation_updated_at_utc',to_char(a.updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'));
    if v_kind='feed_update' then
      v_request:=v_request||jsonb_build_object('fecha_inicio',current_date-2,'fecha_termino',null,
        'grupo_id',f.group_a,'ingredientes',v_recipe);
    end if;
    v_public:=jsonb_build_object('contract_version','group-economics.forward.v3',
      'operation_domain',case v_kind when 'feed_update' then 'group-feed-update-api.v1' else 'group-feed-delete-api.v1' end,
      'granja_id',f.farm_a,'actor_id',f.owner_a,'operation_id',v_op,'request',v_request);
    v_core:=v_public||jsonb_build_object('operation_domain',
      case v_kind when 'feed_update' then 'group-feed-update.v1' else 'group-feed-delete.v1' end,
      'request',(v_request-'grupo_id')||jsonb_build_object(
        'expected_source_updated_at_utc',to_char(a.source_updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        'expected_source_digest',a.source_digest));
    v_args:=jsonb_build_object('kind',v_kind,'farm',f.farm_a,'op',v_op,'actor',f.owner_a,
      'period',v_period,'source',f.source_a,'version',a.updated_at,
      'start',case when v_kind='feed_update' then current_date-2 end,'end',null,
      'group',case when v_kind='feed_update' then f.group_a end,
      'recipe',case when v_kind='feed_update' then v_recipe end);
    if v_kind='feed_update' then
      v_result:=economics_v2.update_group_feed_allocation(f.farm_a,v_op,v_period,f.source_a,
        a.updated_at,a.source_updated_at,a.source_digest,current_date-2,null,v_recipe);
    else
      v_result:=economics_v2.delete_group_feed_allocation(f.farm_a,v_op,v_period,f.source_a,
        a.updated_at,a.source_updated_at,a.source_digest);
    end if;
    select * into o from economics_v2.group_occupancy_operations where granja_id=f.farm_a and operation_id=v_op;
    perform pg_temp.check_true(o.result=v_result and o.event_position is null
      and o.payload_hash=encode(sha256(convert_to(economics_v2.canonical_group_request(v_core)::text,'UTF8')),'hex'),
      'actual durable receipt matches original private envelope '||v_kind);
    insert into pg_temp.contexts values(f.farm_a,v_op,'group-feed-api-completion.v1',v_kind,
      f.owner_a,v_period,f.source_a,case when v_kind='feed_update' then f.group_a end,
      a.updated_at,a.source_updated_at,a.source_digest,
      encode(sha256(convert_to(economics_v2.canonical_group_request(v_public)::text,'UTF8')),'hex'),
      o.payload_hash,encode(sha256(convert_to(economics_v2.canonical_group_request(o.result)::text,'UTF8')),'hex'),
      v_public,v_core,o.result,v_args);
  end loop;
  perform pg_temp.check_true(not exists(select 1 from public.mezcla where id=f.source_a)
    and not exists(select 1 from economics_v2.group_period_feed_allocations where mixture_id=f.source_a),
    'real DELETE physically removed source and allocation before companion storage');
end;
$setup$;
set constraints all immediate;

-- Already-installed storage dependency, never a fake completion producer.
insert into economics_v2.group_feed_api_completions(
  granja_id,operation_id,bridge_version,operation_kind,actor_id,period_id,mixture_id,group_id,
  expected_allocation_updated_at,predecessor_source_updated_at,predecessor_source_digest,
  public_payload_hash,core_payload_hash,core_result_hash)
select granja_id,operation_id,bridge_version,operation_kind,actor_id,period_id,mixture_id,group_id,
  expected_allocation_updated_at,predecessor_source_updated_at,predecessor_source_digest,
  public_payload_hash,core_payload_hash,core_result_hash from pg_temp.contexts;

do $storage_dependency$
declare v_table oid; v_keys smallint[];
begin
  v_table:='economics_v2.group_feed_api_completions'::regclass;
  perform pg_temp.check_true((select count(*)=14 from pg_attribute
    where attrelid=v_table and attnum>0 and not attisdropped),'installed storage exact14 columns');
  select array_agg(attnum order by array_position(array['granja_id','operation_id'],attname::text))
    into v_keys from pg_attribute where attrelid=v_table and attname in ('granja_id','operation_id');
  perform pg_temp.check_true((select count(*)=1 and bool_and(conkey=v_keys)
    from pg_constraint where conrelid=v_table and contype='p'),'installed storage farm/operation PK');
  perform pg_temp.check_true((select count(*)=1 and bool_and(conkey=v_keys
    and confrelid='economics_v2.group_occupancy_operations'::regclass
    and confkey=(select array_agg(attnum order by array_position(array['granja_id','operation_id'],attname::text))
      from pg_attribute where attrelid='economics_v2.group_occupancy_operations'::regclass
        and attname in ('granja_id','operation_id')))
    from pg_constraint where conrelid=v_table and contype='f'),'installed storage ONLY durable ledger FK');
  perform pg_temp.check_true((select relrowsecurity and relforcerowsecurity from pg_class where oid=v_table),
    'installed storage enables and forces RLS');
  perform pg_temp.check_true(not exists(select 1 from pg_temp.contexts e
    left join economics_v2.group_feed_api_completions c using(granja_id,operation_id)
    where c.operation_id is null or to_jsonb(c) is distinct from
      to_jsonb(e)-array['public_envelope','core_envelope','core_result','hash_args']),
    'both real companions retain exact14 original metadata after physical source/fact deletion');
end;
$storage_dependency$;

do $first_primitive$
declare c record; v_before jsonb; v_normal jsonb;
begin
  select * into c from pg_temp.contexts where operation_kind='feed_update';
  v_before:=pg_temp.business_state();
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims','{}',true);
  -- FIRST actual NEW primitive call. Missing 42883 propagates unchanged.
  v_normal:=economics_v2.normalize_group_feed_api_ingredients(
    p_ingredientes=>c.hash_args->'recipe',p_mixture_id=>c.mixture_id);
  perform pg_temp.check_true(v_normal=c.hash_args->'recipe','first actual normalizer preserves valid ordered recipe');
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'first primitive preserves all persistent rows and sequences');
end;
$first_primitive$;

-- Text construction only: every invocation below resolves the ACTUAL new primitive.
create function pg_temp.hash_sql(p_args jsonb)
returns text language sql security invoker set search_path='' as $$
  select format('select economics_v2.group_feed_api_payload_hash(%L::text,%L::uuid,%L::uuid,
    %L::uuid,%L::uuid,%L::uuid,%L::timestamptz,%L::date,%L::date,%L::uuid,%L::jsonb)',
    p_args->>'kind',p_args->>'farm',p_args->>'op',p_args->>'actor',p_args->>'period',
    p_args->>'source',p_args->>'version',p_args->>'start',p_args->>'end',p_args->>'group',
    case when p_args->'recipe'='null'::jsonb then null else (p_args->'recipe')::text end);
$$;

do $primitives$
declare c record; v_before jsonb; v_hash text; v_args jsonb; v_recipe jsonb; v_normal jsonb;
  v_bad jsonb; v_zone text; v_key text; v_proc record;
begin
  v_before:=pg_temp.business_state();
  -- Clear JWT: pure functions must not need an authorized actor or mutable targets.
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims','{}',true);
  for c in select * from pg_temp.contexts order by operation_kind loop
    perform pg_temp.check_true((select count(*)=6 from jsonb_object_keys(c.public_envelope))
      and (select count(*)=case c.operation_kind when 'feed_update' then 8 else 4 end
        from jsonb_object_keys(c.public_envelope->'request')),'manual exact6 envelope and UPDATE8/DELETE4 request');
    execute pg_temp.hash_sql(c.hash_args) into v_hash;
    perform pg_temp.check_true(v_hash=c.public_payload_hash and v_hash<>c.core_payload_hash,
      'actual API primitive matches independent manual envelope, not private domain '||c.operation_kind);
    perform pg_temp.check_true((select s.public_payload_hash=v_hash and s.core_payload_hash=o.payload_hash
      and s.core_result_hash=encode(sha256(convert_to(economics_v2.canonical_group_request(o.result)::text,'UTF8')),'hex')
      from economics_v2.group_feed_api_completions s join economics_v2.group_occupancy_operations o
      using(granja_id,operation_id) where s.granja_id=c.granja_id and s.operation_id=c.operation_id),
      'actual primitive agrees with companion metadata and real durable receipt '||c.operation_kind);
    foreach v_zone in array array['UTC','America/New_York','Asia/Kolkata'] loop
      perform set_config('TimeZone',v_zone,true);
      v_args:=c.hash_args||jsonb_build_object('version',c.expected_allocation_updated_at::text);
      execute pg_temp.hash_sql(v_args) into v_hash;
      perform pg_temp.check_true(v_hash=c.public_payload_hash,'same instant/offset/timezone identity '||v_zone);
    end loop;
    perform set_config('TimeZone','UTC',true);
    foreach v_key in array array['farm','op','actor','period','source'] loop
      execute pg_temp.hash_sql(c.hash_args||jsonb_build_object(v_key,gen_random_uuid())) into v_hash;
      perform pg_temp.check_true(v_hash<>c.public_payload_hash,'UUID binding changes identity '||v_key);
      perform pg_temp.expect_error(pg_temp.hash_sql(c.hash_args||jsonb_build_object(v_key,null)),
        '22023',case v_key when 'farm' then 'granja_id' when 'op' then 'operation_id'
          when 'actor' then 'actor_id' when 'period' then 'period_id' else 'mixture_id' end,null);
    end loop;
    execute pg_temp.hash_sql(c.hash_args||jsonb_build_object('version',c.expected_allocation_updated_at+interval '1 second')) into v_hash;
    perform pg_temp.check_true(v_hash<>c.public_payload_hash,'changed client allocation token changes identity');
    perform pg_temp.expect_error(pg_temp.hash_sql(c.hash_args||'{"version":null}'),
      '22023','expected_allocation_updated_at',c.mixture_id);
    perform pg_temp.expect_error(pg_temp.hash_sql(c.hash_args||'{"version":"infinity"}'),
      '22023','expected_allocation_updated_at',c.mixture_id);
    perform pg_temp.expect_error(pg_temp.hash_sql(c.hash_args||'{"kind":"feed_create"}'),
      '22023','operation_kind',null);
    if c.operation_kind='feed_update' then
      v_recipe:=c.hash_args->'recipe';
      v_normal:=economics_v2.normalize_group_feed_api_ingredients(v_recipe,c.mixture_id);
      perform pg_temp.check_true(v_normal=v_recipe,'normalizer preserves ordered exact3 numeric recipe');
      v_recipe:=jsonb_build_array(
        jsonb_build_object('categoria_id',upper(v_recipe->0->>'categoria_id'),'cantidad_kg','4.000','costo_total','80.00'),
        jsonb_build_object('categoria_id',upper(v_recipe->1->>'categoria_id'),'cantidad_kg','2.0','costo_total','20.000'));
      v_normal:=economics_v2.normalize_group_feed_api_ingredients(v_recipe,c.mixture_id);
      perform pg_temp.check_true(v_normal=c.hash_args->'recipe'
        and jsonb_typeof(v_normal->0->'cantidad_kg')='number'
        and jsonb_typeof(v_normal->0->'costo_total')='number','UUID/text numbers normalize, not retained as strings');
      execute pg_temp.hash_sql(c.hash_args||jsonb_build_object('recipe',v_recipe)) into v_hash;
      perform pg_temp.check_true(v_hash=c.public_payload_hash,'uppercase UUID/text numeric scale identity');
      v_recipe:=jsonb_build_array(
        jsonb_build_object('categoria_id',c.hash_args->'recipe'->0->>'categoria_id',
          'cantidad_kg',4.000::numeric,'costo_total',80.00::numeric),
        jsonb_build_object('categoria_id',c.hash_args->'recipe'->1->>'categoria_id',
          'cantidad_kg',2.0::numeric,'costo_total',20.000::numeric));
      execute pg_temp.hash_sql(c.hash_args||jsonb_build_object('recipe',v_recipe)) into v_hash;
      perform pg_temp.check_true(v_hash=c.public_payload_hash,'JSON numeric scale identity after recursive canonicalization');
      v_normal:=economics_v2.normalize_group_feed_api_ingredients(
        jsonb_build_array(jsonb_set(c.hash_args->'recipe'->0,'{costo_total}','0')),c.mixture_id);
      perform pg_temp.check_true(v_normal->0->'costo_total'='0'::jsonb,'finite zero TOTAL cost is accepted');
      execute pg_temp.hash_sql(c.hash_args||jsonb_build_object('recipe',
        jsonb_build_array(c.hash_args->'recipe'->1,c.hash_args->'recipe'->0))) into v_hash;
      perform pg_temp.check_true(v_hash<>c.public_payload_hash,'recipe order remains identity');
      foreach v_key in array array['group','start','end','recipe'] loop
        v_args:=c.hash_args||case v_key when 'group' then jsonb_build_object('group',gen_random_uuid())
          when 'start' then jsonb_build_object('start',current_date-1)
          when 'end' then jsonb_build_object('end',current_date-1)
          else jsonb_build_object('recipe',jsonb_set(c.hash_args->'recipe','{0,costo_total}','81')) end;
        execute pg_temp.hash_sql(v_args) into v_hash;
        perform pg_temp.check_true(v_hash<>c.public_payload_hash,'UPDATE field changes identity '||v_key);
      end loop;
      perform pg_temp.expect_error(pg_temp.hash_sql(c.hash_args||'{"group":null}'),'22023','group_id',c.mixture_id);
      foreach v_args in array array['{"start":null}'::jsonb,'{"start":"infinity"}'::jsonb,
        jsonb_build_object('start',current_date+1),jsonb_build_object('end',current_date-3)] loop
        perform pg_temp.expect_error(pg_temp.hash_sql(c.hash_args||v_args),'22023','occurred_on',c.mixture_id);
      end loop;
      -- Focused private-core grammar parity: no huge numeric resource probe.
      for v_bad in select value from jsonb_array_elements(jsonb_build_array(
        null,'[]'::jsonb,'{}'::jsonb,jsonb_build_array(jsonb_build_object('categoria_id',c.actor_id)),
        jsonb_build_array((c.hash_args->'recipe'->0)||'{"extra":1}'),
        jsonb_build_array(c.hash_args->'recipe'->0,c.hash_args->'recipe'->0),
        jsonb_build_array(jsonb_set(c.hash_args->'recipe'->0,'{cantidad_kg}','"NaN"')),
        jsonb_build_array(jsonb_set(c.hash_args->'recipe'->0,'{costo_total}','"Infinity"')),
        jsonb_build_array(jsonb_set(c.hash_args->'recipe'->0,'{cantidad_kg}','0')),
        jsonb_build_array(jsonb_set(c.hash_args->'recipe'->0,'{costo_total}','-1')),
        jsonb_build_array(jsonb_set(c.hash_args->'recipe'->0,'{cantidad_kg}','true')))) loop
        perform pg_temp.expect_error(format('select economics_v2.normalize_group_feed_api_ingredients(%L::jsonb,%L::uuid)',
          v_bad,c.mixture_id),'22023','ingredientes',c.mixture_id);
        perform pg_temp.expect_error(pg_temp.hash_sql(c.hash_args||jsonb_build_object('recipe',v_bad)),
          '22023','ingredientes',c.mixture_id);
      end loop;
      perform pg_temp.expect_error(format('select economics_v2.normalize_group_feed_api_ingredients(NULL::jsonb,%L::uuid)',
        c.mixture_id),'22023','ingredientes',c.mixture_id);
    else
      foreach v_args in array array[jsonb_build_object('start',current_date-2),
        jsonb_build_object('end',current_date-1),jsonb_build_object('group',gen_random_uuid()),
        '{"recipe":[]}'::jsonb] loop
        perform pg_temp.expect_error(pg_temp.hash_sql(c.hash_args||v_args),'22023','request',c.mixture_id);
      end loop;
      perform pg_temp.expect_error(replace(pg_temp.hash_sql(c.hash_args),'NULL::jsonb','''null''::jsonb'),
        '22023','request',c.mixture_id);
    end if;
  end loop;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'all primitive successes/refusals preserve persistent state');
  for v_proc in select p.* from pg_proc p where p.oid in (
    'economics_v2.normalize_group_feed_api_ingredients(jsonb,uuid)'::regprocedure,
    'economics_v2.group_feed_api_payload_hash(text,uuid,uuid,uuid,uuid,uuid,timestamptz,date,date,uuid,jsonb)'::regprocedure) loop
    perform pg_temp.check_true(not v_proc.prosecdef and v_proc.pronargdefaults=0
      and v_proc.proconfig @> array['search_path=""'],'private INVOKER, no defaults, empty search_path');
    perform pg_temp.check_true(v_proc.prorettype=case v_proc.proname
      when 'normalize_group_feed_api_ingredients' then 'jsonb'::regtype else 'text'::regtype end,'exact primitive result type');
    perform pg_temp.check_true(v_proc.proargnames=case v_proc.proname
      when 'normalize_group_feed_api_ingredients' then array['p_ingredientes','p_mixture_id']
      else array['p_operation_kind','p_granja_id','p_operation_id','p_actor_id','p_period_id',
        'p_mixture_id','p_expected_allocation_updated_at','p_fecha_inicio','p_fecha_termino',
        'p_grupo_id','p_ingredientes'] end,'exact private named arguments');
    perform pg_temp.check_true(not has_function_privilege('anon',v_proc.oid,'EXECUTE')
      and not has_function_privilege('authenticated',v_proc.oid,'EXECUTE'),'no client primitive EXECUTE');
  end loop;
  perform pg_temp.check_true((select count(*)=2 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='economics_v2' and p.proname in ('normalize_group_feed_api_ingredients','group_feed_api_payload_hash')),
    'one exact signature per primitive, no overloads');
end;
$primitives$;

-- Actual private EXECUTE refusals and retained direct-table denial, not ACL claims only.
do $client_boundaries$
declare v_role text; v_sql text; v_state text; v_before jsonb;
begin
  v_before:=pg_temp.business_state();
  foreach v_role in array array['anon','authenticated'] loop
    foreach v_sql in array array[
      'select * from economics_v2.group_feed_api_completions',
      'insert into economics_v2.group_feed_api_completions default values',
      'update economics_v2.group_feed_api_completions set bridge_version=bridge_version',
      'delete from economics_v2.group_feed_api_completions',
      'select economics_v2.normalize_group_feed_api_ingredients(''[]''::jsonb,NULL::uuid)',
      'select economics_v2.group_feed_api_payload_hash(NULL::text,NULL::uuid,NULL::uuid,NULL::uuid,NULL::uuid,NULL::uuid,NULL::timestamptz,NULL::date,NULL::date,NULL::uuid,NULL::jsonb)'] loop
      v_state:=null;
      begin
        execute format('set local role %I',v_role);
        execute v_sql;
      exception when others then get stacked diagnostics v_state=returned_sqlstate;
      end;
      reset role;
      perform pg_temp.check_true(v_state='42501','actual client direct refusal '||v_role||' '||v_sql);
      perform pg_temp.check_true(pg_temp.business_state()=v_before,'client refusal preserves all rows and sequences');
    end loop;
  end loop;
end;
$client_boundaries$;

do $final_integrity$
begin
  perform pg_temp.check_true(not exists(select 1 from pg_temp.contexts e
    left join economics_v2.group_feed_api_completions c using(granja_id,operation_id)
    where c.operation_id is null or to_jsonb(c) is distinct from
      to_jsonb(e)-array['public_envelope','core_envelope','core_result','hash_args']),
    'primitive tests preserve both original companion metadata rows');
  perform pg_temp.check_true(not exists(select 1 from pg_temp.protected_acl b
    left join pg_class c on b.kind='table' and c.oid=b.oid
    left join pg_proc p on b.kind='function' and p.oid=b.oid
    where b.acl is distinct from case b.kind when 'table' then to_jsonb(c.relacl) else to_jsonb(p.proacl) end),
    'all retained core/helper/table ACLs unchanged, including storage dependency');
end;
$final_integrity$;

select jsonb_build_object(
  'result','group_economics_forward_feed_api_completion_primitives_pass',
  'assertion_count',(select count(*) from pg_temp.assertions),
  'fixture_ids',(select to_jsonb(i) from pg_temp.ids i),
  'locking_evidence','sequential_only',
  'independent_review','pending',
  'storage_dependency_present',true,
  'foundation_primitives_proven',true,
  'real_closure_proven',false,
  'production_gateway_integrated',false,
  'canonical_group_food_update_api_integrated',false,
  'canonical_group_food_delete_api_integrated',false,
  'canonical_group_food_api_integrated',false,
  'metadata_atomic_business_rollback_proven',false,
  'privileged_business_provenance_proven',false
) as evidence;
rollback;
