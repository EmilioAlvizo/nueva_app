begin;

-- HUMAN Sandbox Dashboard only: review and run this FULL BEGIN/ROLLBACK file FIRST.
-- Preparation only. The first PUBLIC DELETE below must expose genuine uncaught 42883.
-- No missing-function catalog cast, producer proxy, implementation or PASS is supplied.
-- Required public.eliminar_mezcla_grupo_v1 and economics_v2.delete_group_feed_impl:
-- (p_granja_id uuid,p_operation_id uuid,p_period_id uuid,p_mezcla_id uuid,
--  p_expected_updated_at timestamptz) returns jsonb; all five required, no defaults.
-- Public INVOKER -> authorized private DEFINER/postgres/empty search_path; auth only.
-- Current assert_group_writer_actor, scalar grammar, API hash with SQL NULL date/date/
-- Group/recipe, farm advisory lock, reauthorization, ledger AND companion locks FIRST.
-- Preserve both FOUND values. Context kind feed_delete, Group SQL NULL, bridge v1.
-- Historical context validates actor/targets/client token/public hash, reconstructed
-- private request6 and actual stored non-replayed result digest, event_position NULL.
-- CALL actual private DELETE with original predecessors, never receipt-only return.
-- No mutable Group/period/source/allocation/category reads on historical replay.
-- Fresh Read Committed locks: Groups ascending -> period -> allocation -> header.
-- Client token is ALLOCATION clock. Derive source predecessors from allocation capture;
-- never absorb current header/price drift. Actual core owns remaining admission checks.
-- Core DELETE completes ledger LAST; verify receipt, INSERT exact14 context, check FOUND,
-- then RETURN in same transaction. No catch-to-success, upsert, backfill or new core ACL.
-- Both this base AND standalone integrity fixture must be GREEN on UNCHANGED gateway.
-- Remaining composed/transport/native gates still required: no global readiness claim.
-- Result equality is not tracing proof: future source review must check delegation,
-- mutable-free replay and lock order. Sequential SQL role RPC only, not HTTP/closure.
-- Isolate Sandbox traffic: setup entry sequence issuance is not rewound by ROLLBACK.
-- Review unit: this whole fixture + FULL future implementation/wrapper/ACL <=800.
-- Additional integrity fixture is a separate REQUIRED test-only review unit.

create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() owner_b,gen_random_uuid() farm_a,gen_random_uuid() farm_b,
  gen_random_uuid() type_a,gen_random_uuid() meat_a,gen_random_uuid() animal_a,
  gen_random_uuid() group_a,gen_random_uuid() category_a,gen_random_uuid() source_a,
  gen_random_uuid() source_editor,gen_random_uuid() sibling,gen_random_uuid() entry_op,
  gen_random_uuid() create_op,gen_random_uuid() editor_create_op,gen_random_uuid() sibling_create_op,
  gen_random_uuid() update_op,gen_random_uuid() owner_op,gen_random_uuid() editor_op,gen_random_uuid() fault_op;
create temp table assertions(label text not null);
create temp table evidence(atomic_rollback boolean not null);
insert into evidence values(false);
create temp table creations(mixture_id uuid primary key,result jsonb not null);
create temp table update_call(allocation_stamp timestamptz,recipe jsonb,result jsonb);
create temp table calls(operation_id uuid primary key,actor_id uuid,mixture_id uuid,
  allocation_id uuid,allocation_stamp timestamptz,source_stamp timestamptz,source_digest text,result jsonb);
create temp table owned_foods(mixture_id uuid,id uuid primary key);
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
-- Only client-callable DEFINER helper: read-only evidence, never a business producer.
-- Exclude ONLY one source, its remembered food IDs, exact new operation and Group fence.
create function pg_temp.business_state(p_source uuid default null,p_op uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare f record; t record; v_rows jsonb; v_state jsonb:='{}'; v_filter text; v_foods uuid[];
begin
  select * into f from pg_temp.ids;
  select coalesce(array_agg(o.id),'{}'::uuid[]) into v_foods
    from pg_temp.owned_foods o where o.mixture_id=p_source;
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    v_filter:='';
    if p_source is not null then
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
      into v_rows using p_source,v_foods,p_op,f.group_a,f.farm_a;
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
create function pg_temp.api_sql(p_farm uuid,p_op uuid,p_period uuid,p_source uuid,
  p_stamp timestamptz,p_impl boolean default false)
returns text language plpgsql security invoker set search_path='' as $$
begin
  return format('select %s(p_granja_id=>%L::uuid,p_operation_id=>%L::uuid,p_period_id=>%L::uuid,
    p_mezcla_id=>%L::uuid,p_expected_updated_at=>%L::timestamptz)',
    case when p_impl then 'economics_v2.delete_group_feed_impl' else 'public.eliminar_mezcla_grupo_v1' end,
    p_farm,p_op,p_period,p_source,p_stamp);
end;
$$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,
  p_field text default null,p_entity uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_result jsonb; v_state text; v_detail text;
begin
  v_before:=pg_temp.business_state();
  perform set_config('feed_delete_api.observe',case when p_state='ZC001' then 'off' else 'on' end,true);
  begin execute p_sql into v_result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics v_state=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform set_config('feed_delete_api.observe','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'full persistent rows, receipts, fences and sequences unchanged');
  if p_state is null then perform pg_temp.check_true(v_result is not null,'historical result returned');
  else
    perform pg_temp.check_true(v_state=p_state,'expected SQLSTATE '||p_state);
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb=jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field,'entity_id',p_entity),'exact4 typed refusal');
    end if;
    if p_state='ZC001' then
      perform pg_temp.check_true(v_detail='observed_after_real_core_delete_completion','late failure observed real physical DELETE completion');
      update pg_temp.evidence set atomic_rollback=true;
    end if;
  end if;
  return v_result;
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"feed-delete-api"}'::jsonb from ids
cross join lateral unnest(array[owner_a,editor_a,viewer_a,owner_b]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'DELETE API farm A',owner_a from ids
union all select farm_b,owner_b,'DELETE API farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'DELETE API type',owner_a from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'DELETE API meat','carne',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_a,farm_a,type_a,'DELETE API Group',owner_a from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select category_a,farm_a,'DELETE API category',true,owner_a from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,owner_a from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
-- Actual private ADMIN occupancy admission, not public occupancy integration.
create temp table targets as select f.*,
  (economics_v2.enter_group_meat_initial(farm_a,entry_op,animal_a,current_date-4,group_a,meat_a,'{}')->>'destination_period_id')::uuid period_a,
  jsonb_build_array(jsonb_build_object('categoria_id',category_a,'cantidad_kg',2,'costo_total',10)) recipe from ids f;
do $access$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$access$;
grant select on pg_temp.targets,pg_temp.calls,pg_temp.update_call to authenticated,anon;
grant insert on pg_temp.assertions to authenticated,anon;
grant update on pg_temp.evidence to authenticated,anon;
revoke all on function pg_temp.check_true(boolean,text),pg_temp.business_state(uuid,uuid),
  pg_temp.api_sql(uuid,uuid,uuid,uuid,timestamptz,boolean),pg_temp.checked(text,text,text,text,uuid) from public;
grant execute on function pg_temp.check_true(boolean,text),pg_temp.business_state(uuid,uuid),
  pg_temp.api_sql(uuid,uuid,uuid,uuid,timestamptz,boolean),pg_temp.checked(text,text,text,text,uuid) to authenticated,anon;
do $sources$
declare f record; q record; r jsonb; v_stamp timestamptz;
begin
  select * into f from pg_temp.targets;
  for q in select * from (values(f.source_a,f.create_op),(f.source_editor,f.editor_create_op),
    (f.sibling,f.sibling_create_op)) sources(id,op) loop
    set local role authenticated;
    r:=public.crear_mezcla_grupo_v1(p_granja_id=>f.farm_a,p_operation_id=>q.op,p_period_id=>f.period_a,
      p_mezcla_id=>q.id,p_fecha_inicio=>current_date-2,p_grupo_id=>f.group_a,p_ingredientes=>f.recipe);
    reset role;
    insert into pg_temp.creations values(q.id,r);
  end loop;
  select (c.result->>'updated_at')::timestamptz into v_stamp from pg_temp.creations c where c.mixture_id=f.source_a;
  set local role authenticated;
  r:=public.actualizar_mezcla_grupo_v1(p_mezcla_id=>f.source_a,p_granja_id=>f.farm_a,p_operation_id=>f.update_op,
    p_period_id=>f.period_a,p_expected_updated_at=>v_stamp,p_fecha_inicio=>current_date-2,
    p_fecha_termino=>null::date,p_grupo_id=>f.group_a,p_ingredientes=>f.recipe);
  reset role;
  insert into pg_temp.update_call values(v_stamp,f.recipe,r);
  -- Client tokens come from actual API responses; only source predecessors come from facts.
  insert into pg_temp.calls
  select seed.op,seed.actor,seed.source,a.id,(seed.response->>'updated_at')::timestamptz,a.source_updated_at,a.source_digest,null
  from (values(f.owner_op,f.owner_a,f.source_a,r),
    (f.editor_op,f.editor_a,f.source_editor,(select c.result from pg_temp.creations c where c.mixture_id=f.source_editor)),
    (f.fault_op,f.editor_a,f.source_editor,(select c.result from pg_temp.creations c where c.mixture_id=f.source_editor)))
    seed(op,actor,source,response) join economics_v2.group_period_feed_allocations a on a.mixture_id=seed.source;
  insert into pg_temp.owned_foods select mc.mezcla_id,mc.comida_id from public.mezcla_comida mc
    where mc.mezcla_id in (f.source_a,f.source_editor,f.sibling);
  perform pg_temp.check_true((select count(*)=3 and sum(total_cost)=30 and sum(quantity_kg)=6
    from economics_v2.group_period_feed_allocations where period_id=f.period_a),'three actual sources at 10 TOTAL cost / 2 kg each');
  perform pg_temp.check_true((select count(*)=3 from pg_temp.owned_foods),
    'remember actual dedicated food IDs for both targets AND sibling before any DELETE');
end;
$sources$;
set constraints all immediate;

create function pg_temp.observe_dml()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('feed_delete_api.observe',true)='on' then
    raise exception 'DELETE replay/refusal attempted persistent DML: %.% %',tg_table_schema,tg_table_name,tg_op;
  end if;
  return null;
end;
$$;
do $observers$
declare t record;
begin
  for t in select * from pg_temp.watched loop
    execute format('create trigger feed_delete_api_observer before insert or update or delete or truncate
      on %I.%I for each statement execute function pg_temp.observe_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;
do $first$
declare f record; c record; r jsonb; v_other jsonb;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls x where x.operation_id=f.owner_op;
  v_other:=pg_temp.business_state(c.mixture_id,c.operation_id);
  set local role authenticated;
  -- FIRST genuine PUBLIC DELETE exact5 named args. Missing 42883 MUST escape.
  r:=public.eliminar_mezcla_grupo_v1(p_granja_id=>f.farm_a::uuid,p_operation_id=>c.operation_id::uuid,
    p_period_id=>f.period_a::uuid,p_mezcla_id=>c.mixture_id::uuid,p_expected_updated_at=>c.allocation_stamp::timestamptz);
  perform pg_temp.check_true(current_user='authenticated','first owner DELETE uses actual SQL client role');
  reset role;
  update pg_temp.calls x set result=r where x.operation_id=c.operation_id;
  perform pg_temp.check_true(pg_temp.business_state(c.mixture_id,c.operation_id)=v_other,
    'owner DELETE preserves siblings, all earlier CREATE/UPDATE completions, basis, period and sequences');
end;
$first$;

-- ADMIN INVOKER evidence helpers only; no producer delegation or client EXECUTE.
-- Independent manual envelope6/API request4 and private request6, not the hash helper.
create function pg_temp.expected_context(p_op uuid)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare f record; c record; o record; v_public jsonb; v_core jsonb;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls x where x.operation_id=p_op;
  select * into o from economics_v2.group_occupancy_operations x where x.granja_id=f.farm_a and x.operation_id=p_op;
  v_public:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_domain','group-feed-delete-api.v1',
    'granja_id',f.farm_a,'actor_id',c.actor_id,'operation_id',p_op,'request',jsonb_build_object(
      'action','feed_delete','period_id',f.period_a,'mixture_id',c.mixture_id,'expected_allocation_updated_at_utc',
      to_char(c.allocation_stamp at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')));
  v_core:=v_public||jsonb_build_object('operation_domain','group-feed-delete.v1','request',
    (v_public->'request')||jsonb_build_object('expected_source_updated_at_utc',
      to_char(c.source_stamp at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'expected_source_digest',c.source_digest));
  return jsonb_build_object('granja_id',f.farm_a,'operation_id',p_op,'bridge_version','group-feed-api-completion.v1',
    'operation_kind','feed_delete','actor_id',c.actor_id,'period_id',f.period_a,'mixture_id',c.mixture_id,'group_id',null,
    'expected_allocation_updated_at',c.allocation_stamp,'predecessor_source_updated_at',c.source_stamp,
    'predecessor_source_digest',c.source_digest,'public_payload_hash',
    encode(sha256(convert_to(economics_v2.canonical_group_request(v_public)::text,'UTF8')),'hex'),
    'core_payload_hash',encode(sha256(convert_to(economics_v2.canonical_group_request(v_core)::text,'UTF8')),'hex'),
    'core_result_hash',encode(sha256(convert_to(economics_v2.canonical_group_request(o.result)::text,'UTF8')),'hex'));
end;
$$;
create function pg_temp.assert_deleted(p_op uuid,p_context boolean default true)
returns void language plpgsql security invoker set search_path='' as $$
declare f record; c record; o record; s record; v_context jsonb;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls x where x.operation_id=p_op;
  select * into o from economics_v2.group_occupancy_operations x where x.granja_id=f.farm_a and x.operation_id=p_op;
  v_context:=pg_temp.expected_context(p_op);
  perform pg_temp.check_true(o.result=jsonb_build_object('contract_version','group-economics.forward.v3',
    'operation_id',p_op,'mixture_id',c.mixture_id,'period_id',f.period_a,'allocation_id',c.allocation_id,'deleted',true,'replayed',false)
    and o.event_position is null and o.payload_hash=v_context->>'core_payload_hash','actual core exact7 receipt and independent private hash');
  perform pg_temp.check_true(not exists(select 1 from public.mezcla m where m.id=c.mixture_id)
    and not exists(select 1 from public.mezcla_comida mc where mc.mezcla_id=c.mixture_id)
    and not exists(select 1 from economics_v2.group_period_feed_allocations a where a.id=c.allocation_id or a.mixture_id=c.mixture_id)
    and not exists(select 1 from public.comida food join pg_temp.owned_foods old_food on old_food.id=food.id
      where old_food.mixture_id=c.mixture_id),'captured allocation, source, components and all remembered dedicated foods physically absent');
  if p_context then
    select * into s from economics_v2.group_feed_api_completions x where x.granja_id=f.farm_a and x.operation_id=p_op;
    perform pg_temp.check_true(to_jsonb(s)=v_context and c.result=o.result,
      'exact14 produced context: actual actor, NULL Group, original predecessors and independent API/core/result SHA bindings');
  end if;
end;
$$;
revoke all on function pg_temp.expected_context(uuid),pg_temp.assert_deleted(uuid,boolean) from public;
select pg_temp.assert_deleted(owner_op) from ids;

do $history_and_identity$
declare f record; c record; u record; q record; r jsonb; v_sql text; v_before jsonb;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls x where x.operation_id=f.owner_op;
  select * into u from pg_temp.update_call;
  v_sql:=pg_temp.api_sql(f.farm_a,c.operation_id,f.period_a,c.mixture_id,c.allocation_stamp);
  set local role authenticated;
  perform pg_temp.check_true(pg_temp.checked(v_sql)=c.result||'{"replayed":true}'::jsonb,'DELETE receipt replays after source/fact removal');
  perform pg_temp.check_true(pg_temp.checked(pg_temp.api_sql(f.farm_a,c.operation_id,f.period_a,c.mixture_id,c.allocation_stamp,true))
    =c.result||'{"replayed":true}'::jsonb,'authorized same-actor direct implementation replay');
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),f.period_a,c.mixture_id,c.allocation_stamp),
    '42501','forbidden','mixture_id',c.mixture_id);
  for q in select * from (values(c.allocation_stamp+interval '1 second',f.period_a,c.mixture_id),
    (c.allocation_stamp,gen_random_uuid(),c.mixture_id),(c.allocation_stamp,f.period_a,f.sibling)) changes(stamp,period_id,source) loop
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,c.operation_id,q.period_id,q.source,q.stamp),
      '22023','operation_payload_conflict','operation_id',c.operation_id);
  end loop;
  r:=pg_temp.checked(format('select public.actualizar_mezcla_grupo_v1(p_mezcla_id=>%L::uuid,p_granja_id=>%L::uuid,
    p_operation_id=>%L::uuid,p_period_id=>%L::uuid,p_expected_updated_at=>%L::timestamptz,p_fecha_inicio=>%L::date,
    p_fecha_termino=>null::date,p_grupo_id=>%L::uuid,p_ingredientes=>%L::jsonb)',
    f.source_a,f.farm_a,f.update_op,f.period_a,u.allocation_stamp,current_date-2,f.group_a,u.recipe));
  perform pg_temp.check_true(r=u.result||'{"replayed":true}'::jsonb,'original PUBLIC UPDATE receipt survives actual canonical DELETE');
  reset role;
  v_before:=pg_temp.business_state();
  begin
    -- Recreate through the REAL guarded API, never manual source INSERT or creator override.
    set local role authenticated;
    r:=public.crear_mezcla_grupo_v1(p_granja_id=>f.farm_a,p_operation_id=>gen_random_uuid(),p_period_id=>f.period_a,
      p_mezcla_id=>f.source_a,p_fecha_inicio=>current_date-1,p_grupo_id=>f.group_a,p_ingredientes=>f.recipe);
    reset role;
    perform pg_temp.check_true((r->>'allocation_id')::uuid<>c.allocation_id and exists(select 1 from public.mezcla m where m.id=f.source_a)
      and exists(select 1 from economics_v2.group_period_feed_allocations a where a.id=(r->>'allocation_id')::uuid),
      'same UUID recreated by canonical CREATE with a genuinely new allocation');
    set local role authenticated;
    perform pg_temp.check_true(pg_temp.checked(v_sql)=c.result||'{"replayed":true}'::jsonb,
      'old DELETE returns original receipt without DML against recreated source/fact/purchases');
    reset role;
    raise exception using errcode='ZR001',message='Restore canonical same-UUID recreation probe';
  exception when sqlstate 'ZR001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'UUID probe restores entire post-delete baseline including receipts and fences');
end;
$history_and_identity$;

do $authorization$
declare f record; c record; v_actor record; v_sql text; v_impl text;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls x where x.operation_id=f.owner_op;
  v_sql:=pg_temp.api_sql(f.farm_a,c.operation_id,f.period_a,c.mixture_id,c.allocation_stamp);
  v_impl:=pg_temp.api_sql(f.farm_a,c.operation_id,f.period_a,c.mixture_id,c.allocation_stamp,true);
  for v_actor in select * from (values(f.viewer_a,'authenticated'),(f.owner_b,'authenticated'),(null::uuid,'anon')) actors(uid,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(v_actor.uid::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_actor.uid,'role',v_actor.role_name)::text,true);
    execute format('set local role %I',v_actor.role_name);
    perform pg_temp.checked(v_sql,'42501');
    perform pg_temp.checked(v_impl,'42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated')::text,true);
  set local role authenticated;
  perform pg_temp.checked(v_sql,'22023','operation_payload_conflict','operation_id',c.operation_id);
  perform pg_temp.checked('select economics_v2.delete_group_feed_allocation(null::uuid,null::uuid,null::uuid,null::uuid,
    null::timestamptz,null::timestamptz,null::text)','42501');
  reset role;
end;
$authorization$;

-- Dedicated table/NEW type. Called inside actual authorized implementation, AFTER core.
create function pg_temp.late_completion_fault()
returns trigger language plpgsql security invoker set search_path='' as $$
declare f record; v_context jsonb;
begin
  select * into f from pg_temp.targets;
  if new.operation_id<>f.fault_op then return new; end if;
  perform pg_temp.assert_deleted(new.operation_id,false);
  v_context:=pg_temp.expected_context(new.operation_id);
  if to_jsonb(new) is distinct from v_context then
    raise exception 'Late companion probe did not receive exact original DELETE context';
  end if;
  raise exception using errcode='ZC001',message='Deliberate companion INSERT failure after physical deletion',
    detail='observed_after_real_core_delete_completion';
end;
$$;
create trigger feed_delete_api_late_fault before insert on economics_v2.group_feed_api_completions
for each row execute function pg_temp.late_completion_fault();
do $late_fault_and_editor$
declare f record; c record; r jsonb; v_other jsonb;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls x where x.operation_id=f.editor_op;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated')::text,true);
  perform pg_temp.check_true((select m.created_by=f.owner_a from public.mezcla m where m.id=c.mixture_id),
    'editor deletes farm-owned source originally created by owner, without creator impersonation');
  set local role authenticated;
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,f.fault_op,f.period_a,c.mixture_id,c.allocation_stamp),'ZC001');
  reset role;
  perform pg_temp.check_true((select atomic_rollback from pg_temp.evidence),'late metadata failure restored real deleted rows, ledger, context and fences');
  v_other:=pg_temp.business_state(c.mixture_id,c.operation_id);
  set local role authenticated;
  r:=public.eliminar_mezcla_grupo_v1(p_granja_id=>f.farm_a,p_operation_id=>c.operation_id,
    p_period_id=>f.period_a,p_mezcla_id=>c.mixture_id,p_expected_updated_at=>c.allocation_stamp);
  perform pg_temp.check_true(current_user='authenticated','second real DELETE uses actual editor client role');
  perform pg_temp.check_true(pg_temp.checked(pg_temp.api_sql(f.farm_a,c.operation_id,f.period_a,c.mixture_id,c.allocation_stamp))
    =r||'{"replayed":true}'::jsonb,'editor historical replay without transient DML');
  reset role;
  update pg_temp.calls x set result=r where x.operation_id=c.operation_id;
  perform pg_temp.assert_deleted(c.operation_id);
  perform pg_temp.check_true(pg_temp.business_state(c.mixture_id,c.operation_id)=v_other,'editor preserves owner receipt/context, sibling and full unrelated state');
  perform pg_temp.check_true((select sum(total_cost)=10 and sum(quantity_kg)=2 from economics_v2.group_period_feed_allocations where period_id=f.period_a)
    and (select remaining_basis=300 from economics_v2.group_animal_acquisition_basis where animal_id=f.animal_a and granja_id=f.farm_a)
    and (select closed_on is null and end_position is null from economics_v2.group_occupancy_periods where id=f.period_a),
    'only deleted contributions deducted; sibling 10/2, basis300 and open period remain');
end;
$late_fault_and_editor$;

set constraints all immediate;
select jsonb_build_object(
  'result','group_economics_forward_feed_delete_api_pass','assertion_count',(select count(*) from assertions),
  'fixture_ids',(select to_jsonb(f) from targets f),'locking_evidence','sequential_only','independent_review','pending',
  'real_closure_proven',false,'production_gateway_integrated',false,'canonical_group_food_delete_api_integrated',true,
  'canonical_group_food_sql_crud_paths_proven',true,'canonical_group_food_api_integrated',false,
  'sql_rpc_path_proven',true,'http_transport_proven',false,
  'metadata_atomic_business_rollback_proven',(select atomic_rollback from evidence),
  'extended_delete_integrity_proven',false,'fresh_header_token_rejection_observed',false,
  'full_delete_qualification_proven',false,'production_release_ready',false,
  'all_legacy_mutation_paths_guarded',false,'privileged_business_provenance_proven',false) evidence;
rollback;
