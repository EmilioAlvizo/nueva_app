begin;

-- HUMAN Sandbox Dashboard only: review, then run this FULL BEGIN/ROLLBACK file.
-- FIRST delivery unit: STORAGE ONLY. No new primitive dependency or invocation.
-- Preparation ONLY. No execution, PASS, migration, gateway or production helper here.
-- First genuine new-object reference is the INSERT in $first$: expected initial
-- RED 42P01 must escape unchanged. No absent-relation casts/preflight/ROWTYPE,
-- missing-helper error simulation, synthetic receipt or replacement normalizer.
-- Requires the qualified CREATE API, private cores and all retained guards.
-- Setup runs real CREATE under authenticated and real private UPDATE/DELETE under
-- admin privileges with owner JWT. Isolate Sandbox traffic; setup consumes event
-- positions that ROLLBACK does not rewind. Never run against production.
--
-- Approved foundation: economics_v2.group_feed_api_completions, EXACT14 columns:
-- granja_id uuid, operation_id uuid, bridge_version text, operation_kind text,
-- actor_id uuid, period_id uuid, mixture_id uuid, group_id uuid,
-- expected_allocation_updated_at timestamptz, predecessor_source_updated_at
-- timestamptz, predecessor_source_digest text, public_payload_hash text,
-- core_payload_hash text, core_result_hash text. All NOT NULL except group_id:
-- required for feed_update, NULL for feed_delete. Version is exactly
-- group-feed-api-completion.v1. PK(granja_id,operation_id); ONLY FK is that pair
-- to durable group_occupancy_operations. No mutable target/actor FKs. Finite
-- timestamps; all four digest/hash fields are lowercase SHA256 hex64.
-- ENABLE/FORCE RLS, deny-direct policies and no PUBLIC/anon/authenticated table
-- privileges (including columns), no service_role grants. Application append-only
-- metadata, NOT a receipt/business truth copy or superuser immutability promise.
-- Authorized admin cleanup must remain possible; no unnecessary blocking trigger.
--
-- Primitive contracts/checks are delivered separately in the standalone
-- group_economics_forward_feed_api_completion_primitives_test.sql, only AFTER
-- this storage unit is installed and qualified. No coverage is discarded.
-- Here manual expected envelopes use ONLY existing canonical_group_request:
-- Public envelope EXACT6 keys, contract group-economics.forward.v3, domains
-- group-feed-update-api.v1 / group-feed-delete-api.v1; UPDATE request EXACT8,
-- DELETE EXACT4. UTC timestamps YYYY-MM-DD"T"HH24:MI:SS.US"Z". Array order is
-- identity, numeric scale is not. Existing private UPDATE9/DELETE6 fingerprints
-- and core ACLs remain unchanged; no entity/API contract-version increment.
--
-- Deferred gateway protocol (NOT implemented or proven by this foundation):
-- auth+grammar+public hash -> same-farm advisory -> immutable completion+ledger
-- BEFORE mutable targets. Verify actor/kind/targets/public/core/result bindings,
-- then CALL the actual core with original stored predecessors and client payload.
-- Fresh Groups ascending -> period -> allocation -> header; compare client
-- ALLOCATION token, derive predecessors from captured allocation fields and check
-- actual source, never absorb drift. Core receipt -> verify -> companion INSERT
-- -> public RETURN in one transaction; companion failure rolls back all effects.
-- Ledger without companion:22023 operation_payload_conflict; orphan/inconsistent
-- binding:23514 invariant_violation; stale allocation/source:40001 stale_write.
-- Public UPDATE/DELETE signatures stay design section7, no new public parameters.
-- This fixture proves storage only, NOT primitives or gateway binding integrity,
-- atomic business rollback, API replay, concurrency, HTTP, Flutter or closure.
-- Snapshot equality proves persisted state only, not absence of transient DML
-- or table reads. Row CHECKs/FK do not validate semantic actor/core/hash bindings;
-- that guarded gateway responsibility remains deferred, not a storage PASS claim.

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
insert into auth.users(id,aud,role,raw_user_meta_data)
select owner_a,'authenticated','authenticated','{"fixture":"feed-api-completion-foundation"}'::jsonb from ids;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Completion foundation farm',owner_a from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Completion foundation type',owner_a from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Completion foundation meat','carne',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_a,farm_a,type_a,'Completion foundation Group',owner_a from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select c,farm_a,'Completion foundation category '||c::text,true,owner_a from ids
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

-- FIRST genuine new-object reference. Do NOT catch 42P01; no new helper called yet.
do $first$
begin
  insert into economics_v2.group_feed_api_completions(
    granja_id,operation_id,bridge_version,operation_kind,actor_id,period_id,mixture_id,group_id,
    expected_allocation_updated_at,predecessor_source_updated_at,predecessor_source_digest,
    public_payload_hash,core_payload_hash,core_result_hash)
  select granja_id,operation_id,bridge_version,operation_kind,actor_id,period_id,mixture_id,group_id,
    expected_allocation_updated_at,predecessor_source_updated_at,predecessor_source_digest,
    public_payload_hash,core_payload_hash,core_result_hash from pg_temp.contexts;
end;
$first$;

-- All explicit new-table catalog resolution intentionally follows INSERT.
do $storage_catalog$
declare v_table oid; v_ledger oid; v_keys smallint[]; v_role text; v_priv text;
begin
  v_table:='economics_v2.group_feed_api_completions'::regclass;
  v_ledger:='economics_v2.group_occupancy_operations'::regclass;
  perform pg_temp.check_true((select count(*)=14 from pg_attribute
    where attrelid=v_table and attnum>0 and not attisdropped),'exact14 storage columns');
  perform pg_temp.check_true(not exists(
    select 1 from (values('granja_id','uuid',true),('operation_id','uuid',true),
      ('bridge_version','text',true),('operation_kind','text',true),('actor_id','uuid',true),
      ('period_id','uuid',true),('mixture_id','uuid',true),('group_id','uuid',false),
      ('expected_allocation_updated_at','timestamp with time zone',true),
      ('predecessor_source_updated_at','timestamp with time zone',true),
      ('predecessor_source_digest','text',true),('public_payload_hash','text',true),
      ('core_payload_hash','text',true),('core_result_hash','text',true)) e(name,type_name,required)
    left join pg_attribute a on a.attrelid=v_table and a.attname=e.name and not a.attisdropped
    where a.attnum is null or format_type(a.atttypid,a.atttypmod)<>e.type_name
      or a.attnotnull<>e.required),'exact column names/types/nullability');
  select array_agg(attnum order by array_position(array['granja_id','operation_id'],attname::text))
    into v_keys from pg_attribute where attrelid=v_table and attname in ('granja_id','operation_id');
  perform pg_temp.check_true((select count(*)=1 and bool_and(conkey=v_keys)
    from pg_constraint where conrelid=v_table and contype='p'),'exact farm/operation PK');
  perform pg_temp.check_true((select count(*)=1 and bool_and(confrelid=v_ledger and conkey=v_keys
    and confkey=(select array_agg(attnum order by array_position(array['granja_id','operation_id'],attname::text))
      from pg_attribute where attrelid=v_ledger and attname in ('granja_id','operation_id')))
    from pg_constraint where conrelid=v_table and contype='f'),'ONLY durable ledger pair FK, no mutable/actor FK');
  perform pg_temp.check_true((select relrowsecurity and relforcerowsecurity from pg_class where oid=v_table),
    'storage enables and forces RLS');
  perform pg_temp.check_true((select core_payload_hash=o.payload_hash and core_result_hash=
    encode(sha256(convert_to(economics_v2.canonical_group_request(o.result)::text,'UTF8')),'hex')
    from economics_v2.group_feed_api_completions c join economics_v2.group_occupancy_operations o
    using(granja_id,operation_id) where c.operation_kind='feed_delete' and c.granja_id=(select farm_a from pg_temp.ids)),
    'DELETE companion binds real durable receipt after source/fact deletion');
  foreach v_role in array array['anon','authenticated'] loop
    perform pg_temp.check_true(exists(select 1 from pg_policy p where p.polrelid=v_table and p.polcmd='*'
      and (0::oid=any(p.polroles) or (select oid from pg_roles where rolname=v_role)=any(p.polroles))
      and pg_get_expr(p.polqual,p.polrelid)='false' and pg_get_expr(p.polwithcheck,p.polrelid)='false'),
      'explicit deny-direct policy '||v_role);
    foreach v_priv in array array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] loop
      perform pg_temp.check_true(not has_table_privilege(v_role,v_table,v_priv),'no client table '||v_priv);
    end loop;
    foreach v_priv in array array['SELECT','INSERT','UPDATE','REFERENCES'] loop
      perform pg_temp.check_true(not has_any_column_privilege(v_role,v_table,v_priv),'no client column '||v_priv);
    end loop;
  end loop;
  perform pg_temp.check_true(not exists(select 1 from pg_class c,
    lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a
    where c.oid=v_table and (a.grantee=0 or a.grantee=(select oid from pg_roles where rolname='service_role'))),
    'no PUBLIC or service_role table grants');
  perform pg_temp.check_true(not exists(select 1 from pg_attribute a,
    lateral aclexplode(a.attacl) x where a.attrelid=v_table
    and (x.grantee=0 or x.grantee=(select oid from pg_roles where rolname='service_role'))),
    'no PUBLIC or service_role column grants');
end;
$storage_catalog$;

-- Constraint probes operate as admin inside rolled-back subtransactions. Candidate
-- row uses a REAL receipt; never fabricate or modify a business ledger entry.
create function pg_temp.storage_probe(p_patch jsonb,p_state text,p_duplicate boolean default false)
returns void language plpgsql security invoker set search_path='' as $$
declare c record; v_candidate jsonb; v_before jsonb; v_state text;
begin
  select * into c from pg_temp.contexts where operation_kind='feed_update';
  v_candidate:=(to_jsonb(c)-array['public_envelope','core_envelope','core_result','hash_args'])||p_patch;
  v_before:=pg_temp.business_state();
  begin
    if not p_duplicate then
      delete from economics_v2.group_feed_api_completions where granja_id=c.granja_id and operation_id=c.operation_id;
    end if;
    insert into economics_v2.group_feed_api_completions
    select r.* from jsonb_populate_record(null::economics_v2.group_feed_api_completions,v_candidate) r;
    set constraints all immediate;
    raise exception using errcode='ZT001',message='Expected storage constraint did not reject candidate';
  exception when others then get stacked diagnostics v_state=returned_sqlstate;
  end;
  perform pg_temp.check_true(v_state=p_state,'storage probe SQLSTATE '||p_state||' '||p_patch::text);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'storage probe rolls back metadata and preserves all business rows');
end;
$$;
do $constraints$
declare v_key text; v_value text;
begin
  foreach v_key in array array['granja_id','operation_id','bridge_version','operation_kind',
    'actor_id','period_id','mixture_id','expected_allocation_updated_at','predecessor_source_updated_at',
    'predecessor_source_digest','public_payload_hash','core_payload_hash','core_result_hash'] loop
    perform pg_temp.storage_probe(jsonb_build_object(v_key,null),'23502');
  end loop;
  perform pg_temp.storage_probe('{"group_id":null}','23514');
  perform pg_temp.storage_probe('{"operation_kind":"feed_delete"}','23514');
  perform pg_temp.storage_probe('{"operation_kind":"feed_create"}','23514');
  perform pg_temp.storage_probe('{"bridge_version":"group-feed-api-completion.v2"}','23514');
  foreach v_key in array array['expected_allocation_updated_at','predecessor_source_updated_at'] loop
    foreach v_value in array array['infinity','-infinity'] loop
      perform pg_temp.storage_probe(jsonb_build_object(v_key,v_value),'23514');
    end loop;
  end loop;
  foreach v_key in array array['predecessor_source_digest','public_payload_hash','core_payload_hash','core_result_hash'] loop
    foreach v_value in array array[repeat('A',64),repeat('a',63),repeat('a',65),repeat('g',64)] loop
      perform pg_temp.storage_probe(jsonb_build_object(v_key,v_value),'23514');
    end loop;
  end loop;
  perform pg_temp.storage_probe(jsonb_build_object('operation_id',gen_random_uuid()),'23503');
  perform pg_temp.storage_probe(jsonb_build_object('granja_id',gen_random_uuid()),'23503');
  perform pg_temp.storage_probe('{}','23505',true);
end;
$constraints$;

-- Revoke ALL clients, not only write privileges; test actual direct SQL refusals.
do $client_boundaries$
declare v_role text; v_sql text; v_state text; v_before jsonb;
begin
  v_before:=pg_temp.business_state();
  foreach v_role in array array['anon','authenticated'] loop
    foreach v_sql in array array[
      'select * from economics_v2.group_feed_api_completions',
      'insert into economics_v2.group_feed_api_completions default values',
      'update economics_v2.group_feed_api_completions set bridge_version=bridge_version',
      'delete from economics_v2.group_feed_api_completions'] loop
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
declare v_before jsonb; v_state text;
begin
  perform pg_temp.check_true(not exists(select 1 from pg_temp.contexts e
    left join economics_v2.group_feed_api_completions c using(granja_id,operation_id)
    where c.operation_id is null or to_jsonb(c) is distinct from
      to_jsonb(e)-array['public_envelope','core_envelope','core_result','hash_args']),
    'both exact14 companions retain original contexts and actual canonical receipt digests');
  perform pg_temp.check_true(not exists(select 1 from pg_temp.protected_acl b
    left join pg_class c on b.kind='table' and c.oid=b.oid
    left join pg_proc p on b.kind='function' and p.oid=b.oid
    where b.acl is distinct from case b.kind when 'table' then to_jsonb(c.relacl) else to_jsonb(p.proacl) end),
    'all retained core/helper/table ACLs unchanged');
  -- Application append-only does not forbid authorized Sandbox admin cleanup.
  v_before:=pg_temp.business_state();
  begin
    delete from economics_v2.group_feed_api_completions where granja_id=(select farm_a from pg_temp.ids);
    if exists(select 1 from economics_v2.group_feed_api_completions where granja_id=(select farm_a from pg_temp.ids)) then
      raise exception 'Admin cleanup did not remove companions';
    end if;
    raise exception using errcode='ZT002',message='Rollback successful admin cleanup probe';
  exception when others then get stacked diagnostics v_state=returned_sqlstate;
  end;
  perform pg_temp.check_true(v_state='ZT002' and pg_temp.business_state()=v_before,
    'admin cleanup allowed and probe restored, durable business receipts untouched');
end;
$final_integrity$;

select jsonb_build_object(
  'result','group_economics_forward_feed_api_completion_foundation_pass',
  'assertion_count',(select count(*) from pg_temp.assertions),
  'fixture_ids',(select to_jsonb(i) from pg_temp.ids i),
  'locking_evidence','sequential_only',
  'independent_review','pending',
  'real_closure_proven',false,
  'production_gateway_integrated',false,
  'canonical_group_food_update_api_integrated',false,
  'canonical_group_food_delete_api_integrated',false,
  'canonical_group_food_api_integrated',false,
  'foundation_storage_proven',true,
  'foundation_primitives_proven',false,
  'foundation_storage_and_primitives_proven',false,
  'metadata_atomic_business_rollback_proven',false,
  'privileged_business_provenance_proven',false
) as evidence;
rollback;
