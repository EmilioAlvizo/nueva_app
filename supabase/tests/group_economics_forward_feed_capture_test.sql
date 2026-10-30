begin;

-- HUMAN sandbox Dashboard: run this FULL BEGIN/ROLLBACK file and report the first error.
-- Expected initial RED is the unhandled typed NEW capture call in pg_temp.capture below.
-- Full-unit forecast: fixture <=460 + complete future inline-protocol/capture migration <=260 = <=720.
-- FIRST capture only. No public API, update/delete, finalization, fake positive closure or full F3 proof.
-- Authorized inline feed protocol leaves qualified prepare_group_operation completely unchanged.
-- Hash: SHA256 UTF8 canonical_group_request(envelope)::text. Envelope exact6:
-- contract_version=group-economics.forward.v3, operation_domain=group-feed-capture.v1,
-- granja_id, actor_id=actual auth.uid(), operation_id, request. Request exact5:
-- action=feed_capture, period_id, mixture_id, expected_updated_at_utc, expected_source_digest.
-- UTC version renders YYYY-MM-DD"T"HH24:MI:SS.US"Z"; digest is mandatory lowercase SHA256 hex.
-- Shared farm/op namespace: authorize current actor, validate scalar request, farm advisory lock,
-- hash conflict/replay BEFORE mutable source/target reads. No animal surrogate or sequence position.
-- Same actor/request replays the exact stored result except replayed=true; changed actor/request conflicts.
-- New capture lock order: farm -> ascending affected Groups -> period -> mixture -> UUID-ordered
-- components -> UUID-ordered dedicated food -> referenced categories, then server source validation.
-- No animal/basis scope. Recalculate actual version AND digest under locks; input is not a context token.
-- Existing mixture allocation under any new op refuses 23514/invariant_violation/mixture_id; never retarget.
-- Expected digest mismatch is 40001/stale_write/source_digest; invalid digest is 22023/invalid_request.
-- Insert allocation, then INSERT completed ledger result LAST, event_position=NULL, no reservation/update.
-- Exact11 result matches accepted future create/update keys. Finalized_at remains NULL.
-- Sequential fixture cannot establish independently concurrent serialization or public producer atomicity.
create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,gen_random_uuid() type_b,
  gen_random_uuid() meat_a,gen_random_uuid() meat_b,gen_random_uuid() posture_a,
  gen_random_uuid() group_a,gen_random_uuid() group_other,gen_random_uuid() group_b,
  gen_random_uuid() category_a,gen_random_uuid() category_second,gen_random_uuid() category_b,
  gen_random_uuid() mixture_old,gen_random_uuid() mixture_a,gen_random_uuid() mixture_zero,
  gen_random_uuid() mixture_fault,gen_random_uuid() mixture_other,gen_random_uuid() mixture_b,
  gen_random_uuid() animal_a,gen_random_uuid() animal_other,gen_random_uuid() animal_b,gen_random_uuid() operation_a;
create temp table assertions(label text not null);
create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
create temp table watched(schema_name text,table_name text,primary key(schema_name,table_name));
insert into watched values
  ('economics_v2','group_occupancy_operations'),('economics_v2','group_period_feed_allocations'),
  ('economics_v2','group_occupancy_periods'),('economics_v2','group_occupancy_memberships'),
  ('economics_v2','group_occupancy_events'),('economics_v2','group_animal_acquisition_basis'),
  ('economics_v2','group_acquisition_basis_entries'),('economics_v2','group_period_expenses'),
  ('economics_v2','group_period_sale_bindings'),('economics_v2','group_meat_snapshots'),('economics_v2','feature_flags'),
  ('public','mezcla'),('public','mezcla_comida'),('public','comida'),('public','cat_comida'),
  ('public','animales'),('public','bajas_animales'),('public','venta_animal'),('public','grupos'),
  ('public','tipo_animal'),('public','cat_proposito_animal'),('public','miembros_granja');
create function pg_temp.business_state(p_include_facts boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_table record; v_rows jsonb; v_result jsonb:='{}'; v_farms uuid[]; v_actors uuid[];
begin
  select array[f.farm_a,f.farm_b],array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]
    into v_farms,v_actors from pg_temp.ids f;
  for v_table in select w.* from pg_temp.watched w where p_include_facts
    or w.table_name not in ('group_occupancy_operations','group_period_feed_allocations') order by w.schema_name,w.table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r where granja_id=any($1) or granja_id is null',v_table.schema_name,v_table.table_name)
      into v_rows using v_farms;
    v_result:=v_result||jsonb_build_object(v_table.schema_name||'.'||v_table.table_name,v_rows);
  end loop;
  return v_result||jsonb_build_object(
    'sequence',(select jsonb_build_object('last_value',s.last_value,'is_called',s.is_called)
      from economics_v2.group_economics_event_position_seq s),
    'farms',(select jsonb_agg(to_jsonb(g) order by g.id) from public.granjas g where g.id=any(v_farms)),
    'users',(select jsonb_agg(to_jsonb(u) order by u.id) from auth.users u where u.id=any(v_actors)),
    'profiles',(select jsonb_agg(to_jsonb(p) order by p.id) from public.perfiles p where p.id=any(v_actors)));
end;
$$;
create function pg_temp.capture(p_farm uuid,p_op uuid,p_period uuid,p_mixture uuid,p_version timestamptz,p_digest text)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  -- Trusted fixture gateway only; preserves JWT identity and supplies no source snapshot.
  return economics_v2.capture_group_feed_allocation(p_farm,p_op,p_period,p_mixture,p_version,p_digest);
end;
$$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,p_field text default null,
  p_unchanged boolean default true)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_nonfacts jsonb; v_result jsonb; v_state text; v_detail text;
begin
  v_before:=pg_temp.business_state();
  v_nonfacts:=pg_temp.business_state(false);
  perform set_config('f3fc.guard','on',true);
  begin
    execute p_sql into v_result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics v_state=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform set_config('f3fc.guard','off',true);
  perform pg_temp.check_true(pg_temp.business_state(false)=v_nonfacts,'source/occupancy/basis/sequence unchanged: '||p_sql);
  if p_state is not null or p_unchanged then
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'all business state unchanged: '||p_sql);
  end if;
  if p_state is not null then
    perform pg_temp.check_true(v_state=p_state,'expected SQLSTATE '||p_state||': '||p_sql);
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb @> jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field) and v_detail::jsonb ? 'entity_id','typed error: '||p_sql);
    end if;
  else
    perform pg_temp.check_true(v_result is not null,'nonempty capture result');
  end if;
  return v_result;
end;
$$;

select pg_temp.check_true(not exists(select 1 from auth.users u
  where u.raw_user_meta_data->>'fixture'='group-feed-capture'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"group-feed-capture"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F3FC farm A',owner_a from ids union all select farm_b,owner_b,'F3FC farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F3FC type A',owner_a from ids union all select type_b,farm_b,'F3FC type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'F3FC meat A','carne',owner_a from ids
union all select posture_a,farm_a,'F3FC posture A','postura',owner_a from ids
union all select meat_b,farm_b,'F3FC meat B','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'F3FC group '||g::text,owner_a from ids cross join lateral unnest(array[group_a,group_other]) g
union all select group_b,farm_b,type_b,'F3FC foreign group',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select category_a,farm_a,'F3FC ingredient A',true,owner_a from ids
union all select category_second,farm_a,'F3FC ingredient second',true,owner_a from ids
union all select category_b,farm_b,'F3FC ingredient B',true,owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
-- All real source producers run before forward admission; retain active-mixture chronology.
select public.crear_mezcla_completa(farm_a,mixture_old,current_date-6,group_a,jsonb_build_array(
  jsonb_build_object('categoria_id',category_a,'cantidad_kg',1,'costo_total',5))) from ids;
select public.crear_mezcla_completa(farm_a,mixture_a,current_date-3,group_a,jsonb_build_array(
  jsonb_build_object('categoria_id',category_a,'cantidad_kg',2,'costo_total',50),
  jsonb_build_object('categoria_id',category_second,'cantidad_kg',3,'costo_total',30))) from ids;
select public.crear_mezcla_completa(farm_a,mixture_other,current_date-2,group_other,jsonb_build_array(
  jsonb_build_object('categoria_id',category_a,'cantidad_kg',1,'costo_total',10))) from ids;
create temp table old_versions as select m.id,m.updated_at from public.mezcla m where m.id=(select mixture_a from ids);
select public.eliminar_categoria_comida_segura(farm_a,category_a) from ids;
select public.actualizar_mezcla_completa(mixture_a,farm_a,(select v.updated_at from old_versions v),current_date-2,null::date,
  group_a,jsonb_build_array(jsonb_build_object('categoria_id',category_a,'cantidad_kg',2,'costo_total',100),
    jsonb_build_object('categoria_id',category_second,'cantidad_kg',3,'costo_total',30))) from ids;
-- Preserve actual clock_timestamp() update version before automatic closure resets it to now().
update pg_temp.old_versions v set updated_at=m.updated_at from public.mezcla m where m.id=v.id;
select public.crear_mezcla_completa(farm_a,mixture_zero,current_date-1,group_a,jsonb_build_array(
  jsonb_build_object('categoria_id',category_second,'cantidad_kg',1,'costo_total',0))) from ids;
select public.crear_mezcla_completa(farm_a,mixture_fault,current_date,group_a,jsonb_build_array(
  jsonb_build_object('categoria_id',category_second,'cantidad_kg',2,'costo_total',20))) from ids;
select set_config('request.jwt.claim.sub',owner_b::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_b,'role','authenticated')::text,true) from ids;
select public.crear_mezcla_completa(farm_b,mixture_b,current_date-2,group_b,jsonb_build_array(
  jsonb_build_object('categoria_id',category_b,'cantidad_kg',7,'costo_total',70))) from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,notas,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,'F3FC animal A',owner_a from ids
union all select animal_other,farm_a,type_a,group_other,meat_a,current_date-7,0,'F3FC other animal',owner_a from ids
union all select animal_b,farm_b,type_b,group_b,meat_b,current_date-7,0,'F3FC animal B',owner_b from ids;
create temp table initial(animal_id uuid,result jsonb);
insert into initial select animal_b,economics_v2.enter_group_meat_initial(farm_b,gen_random_uuid(),animal_b,
  current_date-4,group_b,meat_b,'{}') from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
insert into initial select animal_a,economics_v2.enter_group_meat_initial(farm_a,gen_random_uuid(),animal_a,
  current_date-4,group_a,meat_a,'{}') from ids;
insert into initial select animal_other,economics_v2.enter_group_meat_initial(farm_a,gen_random_uuid(),animal_other,
  current_date-4,group_other,meat_a,'{}') from ids;
create temp table targets as select f.*,
  (select (i.result->>'destination_period_id')::uuid from initial i where i.animal_id=f.animal_a) period_a,
  (select (i.result->>'destination_period_id')::uuid from initial i where i.animal_id=f.animal_b) period_b,
  (select (i.result->>'destination_period_id')::uuid from initial i where i.animal_id=f.animal_other) period_other,
  (select (i.result->>'operation_id')::uuid from initial i where i.animal_id=f.animal_a) occupancy_op from ids f;
create temp table sources as select m.id,m.updated_at,m.fecha_inicio from public.mezcla m
where m.granja_id in(select farm_a from ids union all select farm_b from ids);
create temp table contexts as select s.id,economics_v2.validate_group_feed_source(t.farm_a,t.period_a,s.id,s.updated_at) value
from sources s cross join targets t where s.id in(t.mixture_a,t.mixture_zero,t.mixture_fault);
select pg_temp.check_true((select s.updated_at is distinct from v.updated_at from sources s join old_versions v on v.id=s.id),
  'actual update and later closure versions differ');
set constraints all immediate;
set constraints all deferred;

-- During capture, all business DML except new allocation/completed receipt is forbidden.
create function pg_temp.no_write()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_setting('f3fc.guard',true)='on' then
    raise exception using errcode='P0001',message='F3FC unexpected noncapture DML';
  end if;
  return null;
end;
$$;
do $guards$
declare v_table record;
begin
  for v_table in select w.* from pg_temp.watched w
    where w.table_name not in ('group_occupancy_operations','group_period_feed_allocations') loop
    execute format('create trigger f3fc_no_write before insert or update or delete on %I.%I
      for each statement execute function pg_temp.no_write()',v_table.schema_name,v_table.table_name);
  end loop;
end;
$guards$;
create function pg_temp.capture_fault()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if current_setting('f3fc.guard',true)='on' then
    if tg_table_name='group_occupancy_operations' then
      if new.event_position is not null or not exists(select 1 from economics_v2.group_period_feed_allocations a
        where a.id=(new.result->>'allocation_id')::uuid and a.granja_id=new.granja_id
          and a.period_id=(new.result->>'period_id')::uuid and a.mixture_id=(new.result->>'mixture_id')::uuid)
        or (select count(*) from jsonb_object_keys(new.result))<>11 or new.result->'replayed'<>'false'::jsonb then
        raise exception using errcode='P0001',message='F3FC completed ledger must follow actual allocation';
      end if;
      if current_setting('f3fc.fault',true)='completion' then
        raise exception using errcode='ZC001',message='F3FC late receipt insertion fault';
      end if;
    elsif current_setting('f3fc.fault',true)='allocation' then
      raise exception using errcode='ZA001',message='F3FC late allocation insertion fault';
    end if;
  end if;
  return new;
end;
$$;
create trigger f3fc_allocation_fault after insert on economics_v2.group_period_feed_allocations
for each row execute function pg_temp.capture_fault();
create trigger f3fc_completion_fault before insert on economics_v2.group_occupancy_operations
for each row execute function pg_temp.capture_fault();
create trigger f3fc_allocation_no_retarget before update or delete on economics_v2.group_period_feed_allocations
for each statement execute function pg_temp.no_write();
create trigger f3fc_receipt_no_update before update or delete on economics_v2.group_occupancy_operations
for each statement execute function pg_temp.no_write();
do $grants$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$grants$;
grant execute on function pg_temp.capture(uuid,uuid,uuid,uuid,timestamptz,text),pg_temp.business_state(boolean),
  pg_temp.check_true(boolean,text),pg_temp.checked(text,text,text,text,boolean) to authenticated,anon;
create temp table results(value jsonb);
do $first$
declare v_target record; v_context jsonb; v_result jsonb; v_before jsonb;
begin
  select t.* into v_target from pg_temp.targets t;
  select c.value into v_context from pg_temp.contexts c where c.id=v_target.mixture_a;
  v_before:=pg_temp.business_state(false);
  perform set_config('f3fc.guard','on',true);
  set local role authenticated;
  -- First NEW helper invocation; no exception handler can disguise the genuine missing-function RED.
  v_result:=pg_temp.capture(v_target.farm_a,v_target.operation_a,v_target.period_a,v_target.mixture_a,
    (v_context->>'source_updated_at')::timestamptz,v_context->>'source_digest');
  reset role;
  perform set_config('f3fc.guard','off',true);
  perform pg_temp.check_true(pg_temp.business_state(false)=v_before,'first capture preserves source/occupancy/basis/sequence');
  insert into pg_temp.results values(v_result);
end;
$first$;

do $proof$
declare v_target record; v_context jsonb; v_result jsonb; v_repeat jsonb; v_allocation record;
  v_sql text; v_before jsonb; v_hash text; v_actor record; v_probe record; v_mode text; v_food uuid;
  v_fault_context jsonb; v_zone text; v_proc record;
begin
  select t.* into v_target from pg_temp.targets t;
  select c.value into v_context from pg_temp.contexts c where c.id=v_target.mixture_a;
  select r.value into v_result from pg_temp.results r;
  select a.* into v_allocation from economics_v2.group_period_feed_allocations a where a.mixture_id=v_target.mixture_a;
  perform pg_temp.check_true(v_result=jsonb_build_object('contract_version','group-economics.forward.v3',
    'operation_id',v_target.operation_a,'mixture_id',v_target.mixture_a,'period_id',v_target.period_a,
    'allocation_id',v_allocation.id,'updated_at',v_allocation.updated_at,'component_count',2,
    'quantity_kg',5,'total_cost',130,'source_digest',v_context->>'source_digest','replayed',false)
    and (select count(*)=11 from jsonb_object_keys(v_result)),'exact11 server-derived capture result');
  perform pg_temp.check_true(v_allocation.granja_id=v_target.farm_a and v_allocation.period_id=v_target.period_a
    and v_allocation.source_updated_at=(v_context->>'source_updated_at')::timestamptz
    and v_allocation.occurred_on=current_date-2 and v_allocation.component_count=2
    and v_allocation.quantity_kg=5 and v_allocation.total_cost=130 and v_allocation.finalized_at is null
    and v_allocation.source_digest=v_context->>'source_digest','actual immutable target/source version/digest; no finalization');
  v_hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-feed-capture.v1',
    'granja_id',v_target.farm_a,'actor_id',v_target.owner_a,'operation_id',v_target.operation_a,
    'request',jsonb_build_object('action','feed_capture','period_id',v_target.period_a,'mixture_id',v_target.mixture_a,
      'expected_updated_at_utc',to_char((v_context->>'source_updated_at')::timestamptz at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'expected_source_digest',v_context->>'source_digest')))::text,'UTF8')),'hex');
  perform pg_temp.check_true((select o.payload_hash=v_hash and o.result=v_result and o.event_position is null
    from economics_v2.group_occupancy_operations o where o.granja_id=v_target.farm_a and o.operation_id=v_target.operation_a),
    'shared ledger exact domain/actor/request hash, original completed result, NULL position');
  perform pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(v_target.farm_a,v_target.period_a)
    @> '{"feed_cost":130,"feed_kg_total":5,"acquisition_cost":300}'::jsonb,'captured TOTAL ingredient cost130 and kg5; acquisition unchanged');
  v_sql:=format('select pg_temp.capture(%L,%L,%L,%L,%L::timestamptz,%L)',v_target.farm_a,v_target.operation_a,
    v_target.period_a,v_target.mixture_a,v_context->>'source_updated_at',v_context->>'source_digest');
  v_repeat:=pg_temp.checked(v_sql);
  perform pg_temp.check_true(v_repeat=v_result||'{"replayed":true}'::jsonb,'exact replay changes only replayed');
  v_zone:=current_setting('TimeZone');
  perform set_config('TimeZone','Etc/GMT+5',true);
  v_repeat:=pg_temp.checked(v_sql);
  perform pg_temp.check_true(v_repeat=v_result||'{"replayed":true}'::jsonb,'request version hash is timezone independent');
  perform set_config('TimeZone',v_zone,true);
  for v_probe in select * from (values
    (v_target.operation_a,v_target.period_b,v_target.mixture_a,v_context->>'source_updated_at',v_context->>'source_digest','22023','operation_payload_conflict','operation_id'),
    (v_target.operation_a,v_target.period_a,v_target.mixture_a,v_context->>'source_updated_at',repeat('0',64),'22023','operation_payload_conflict','operation_id'),
    (v_target.operation_a,v_target.period_a,v_target.mixture_a,(select v.updated_at::text from pg_temp.old_versions v),v_context->>'source_digest','22023','operation_payload_conflict','operation_id'),
    (v_target.occupancy_op,v_target.period_a,v_target.mixture_a,v_context->>'source_updated_at',v_context->>'source_digest','22023','operation_payload_conflict','operation_id'),
    (gen_random_uuid(),v_target.period_a,v_target.mixture_a,v_context->>'source_updated_at',v_context->>'source_digest','23514','invariant_violation','mixture_id'),
    (gen_random_uuid(),v_target.period_other,v_target.mixture_a,v_context->>'source_updated_at',v_context->>'source_digest','23514','invariant_violation','mixture_id'),
    (gen_random_uuid(),v_target.period_b,v_target.mixture_fault,(select s.updated_at::text from pg_temp.sources s where s.id=v_target.mixture_fault),repeat('0',64),'42501','forbidden','period_id'),
    (gen_random_uuid(),v_target.period_a,v_target.mixture_b,(select s.updated_at::text from pg_temp.sources s where s.id=v_target.mixture_b),repeat('0',64),'42501','forbidden','mixture_id'),
    (gen_random_uuid(),v_target.period_a,v_target.mixture_other,(select s.updated_at::text from pg_temp.sources s where s.id=v_target.mixture_other),repeat('0',64),'42501','forbidden','group_id'),
    (gen_random_uuid(),v_target.period_a,v_target.mixture_old,(select s.updated_at::text from pg_temp.sources s where s.id=v_target.mixture_old),repeat('0',64),'22023','invalid_request','occurred_on'),
    (gen_random_uuid(),v_target.period_a,v_target.mixture_zero,(select s.updated_at::text from pg_temp.sources s where s.id=v_target.mixture_zero),repeat('0',64),'40001','stale_write','source_digest'),
    (gen_random_uuid(),v_target.period_a,v_target.mixture_zero,(select v.updated_at::text from pg_temp.old_versions v),repeat('0',64),'40001','stale_write','mixture_id'),
    (gen_random_uuid(),v_target.period_a,v_target.mixture_zero,null::text,repeat('0',64),'22023','invalid_request','expected_updated_at'),
    (gen_random_uuid(),v_target.period_a,v_target.mixture_zero,v_context->>'source_updated_at',null::text,'22023','invalid_request','source_digest'),
    (gen_random_uuid(),v_target.period_a,v_target.mixture_zero,v_context->>'source_updated_at','BAD','22023','invalid_request','source_digest'),
    (gen_random_uuid(),null::uuid,v_target.mixture_zero,v_context->>'source_updated_at',repeat('0',64),'22023','invalid_request','period_id'),
    (gen_random_uuid(),v_target.period_a,null::uuid,v_context->>'source_updated_at',repeat('0',64),'22023','invalid_request','mixture_id'),
    (null::uuid,v_target.period_a,v_target.mixture_zero,v_context->>'source_updated_at',repeat('0',64),'22023','invalid_request','operation_id'))
    p(op,period,mixture,version,digest,state,code,field) loop
    perform pg_temp.checked(format('select pg_temp.capture(%L,%L,%L,%L,%L::timestamptz,%L)',v_target.farm_a,
      v_probe.op,v_probe.period,v_probe.mixture,v_probe.version,v_probe.digest),v_probe.state,v_probe.code,v_probe.field);
  end loop;
  perform pg_temp.checked(format('select economics_v2.enter_group_meat_initial(%L,%L,%L,%L::date,%L,%L,''{}''::jsonb)',
    v_target.farm_a,v_target.operation_a,v_target.animal_a,current_date-4,v_target.group_a,v_target.meat_a),
    '22023','operation_payload_conflict','operation_id');
  for v_actor in select * from (values(v_target.editor_a,'authenticated'),(v_target.viewer_a,'authenticated'),
    (v_target.owner_b,'authenticated'),(null::uuid,'anon')) a(id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(v_actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_actor.id,'role',v_actor.role_name)::text,true);
    execute format('set local role %I',v_actor.role_name);
    perform pg_temp.checked(v_sql,(case when v_actor.id=v_target.editor_a then '22023' else '42501' end),
      (case when v_actor.id=v_target.editor_a then 'operation_payload_conflict' else 'forbidden' end),
      (case when v_actor.id=v_target.editor_a then 'operation_id' else 'granja_id' end));
    perform pg_temp.checked('select economics_v2.capture_group_feed_allocation(null::uuid,null::uuid,null::uuid,null::uuid,null::timestamptz,null::text)','42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',v_target.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_target.owner_a,'role','authenticated')::text,true);
  select c.value into v_fault_context from pg_temp.contexts c where c.id=v_target.mixture_fault;
  select mc.comida_id into v_food from public.mezcla_comida mc where mc.mezcla_id=v_target.mixture_fault;
  -- Original replay remains valid after source mutation; new operation must compare actual digest.
  v_before:=pg_temp.business_state();
  begin
    update public.comida set precio=precio+1 where id in(select mc.comida_id from public.mezcla_comida mc where mc.mezcla_id=v_target.mixture_a);
    update public.mezcla set updated_at=updated_at+interval '1 second' where id=v_target.mixture_a;
    update public.comida set precio=precio+1 where id=v_food;
    v_repeat:=pg_temp.checked(v_sql);
    perform pg_temp.check_true(v_repeat=v_result||'{"replayed":true}'::jsonb,'historical replay does not reread economic source');
    perform pg_temp.check_true((select m.updated_at=(v_fault_context->>'source_updated_at')::timestamptz
      from public.mezcla m where m.id=v_target.mixture_fault),'uncaptured cost probe retains actual mixture version');
    perform pg_temp.checked(format('select pg_temp.capture(%L,%L,%L,%L,%L::timestamptz,%L)',v_target.farm_a,
      gen_random_uuid(),v_target.period_a,v_target.mixture_fault,v_fault_context->>'source_updated_at',v_fault_context->>'source_digest'),
      '40001','stale_write','source_digest');
    raise exception using errcode='Z0001',message='F3FC restore changed-source probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'economic probes restored; allocation not recaptured');
  for v_mode in select unnest(array['missing_cost','missing_kg','future_date','nonmeat','closed','disabled','allocation','completion']) loop
    v_before:=pg_temp.business_state();
    begin
      if v_mode='missing_cost' then update public.comida set precio=null where id=v_food;
      elsif v_mode='missing_kg' then update public.mezcla_comida set cantidad=null where mezcla_id=v_target.mixture_fault;
      elsif v_mode='future_date' then update public.mezcla set fecha_inicio=current_date+1 where id=v_target.mixture_fault;
      elsif v_mode='nonmeat' then update economics_v2.group_occupancy_periods set purpose_id=v_target.posture_a where id=v_target.period_a;
      elsif v_mode='closed' then update economics_v2.group_occupancy_periods set closed_on=current_date,end_position=start_position+1000 where id=v_target.period_a;
      elsif v_mode='disabled' then update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=v_target.farm_a;
      else perform set_config('f3fc.fault',v_mode,true);
      end if;
      perform pg_temp.checked(format('select pg_temp.capture(%L,%L,%L,%L,%L::timestamptz,%L)',v_target.farm_a,
        gen_random_uuid(),v_target.period_a,v_target.mixture_fault,v_fault_context->>'source_updated_at',v_fault_context->>'source_digest'),
        (case v_mode when 'missing_cost' then '23514' when 'missing_kg' then '23514' when 'future_date' then '22023' when 'nonmeat' then '22023' when 'closed' then '23514'
          when 'disabled' then '42501' when 'allocation' then 'ZA001' else 'ZC001' end),
        (case v_mode when 'missing_cost' then 'invariant_violation' when 'missing_kg' then 'invariant_violation' when 'future_date' then 'invalid_request' when 'nonmeat' then 'invalid_request'
          when 'closed' then 'closed_period_immutable' when 'disabled' then 'forbidden' else null end),
        (case v_mode when 'missing_cost' then 'mixture_id' when 'missing_kg' then 'mixture_id' when 'future_date' then 'occurred_on' when 'disabled' then 'granja_id'
          when 'nonmeat' then 'purpose_id' else 'period_id' end));
      if v_mode='closed' then
        v_repeat:=pg_temp.checked(v_sql);
        perform pg_temp.check_true(v_repeat=v_result||'{"replayed":true}'::jsonb,'original replay precedes closed metadata refusal');
      elsif v_mode='disabled' then
        perform pg_temp.checked(v_sql,'42501','forbidden','granja_id');
      end if;
      raise exception using errcode='Z0001',message='F3FC restore metadata/fault probe';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'all probes/late partial writes restored: '||v_mode);
  end loop;
  -- A real editor captures owner-produced zero-cost source with its own operation identity.
  perform set_config('request.jwt.claim.sub',v_target.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_target.editor_a,'role','authenticated')::text,true);
  select c.value into v_fault_context from pg_temp.contexts c where c.id=v_target.mixture_zero;
  set local role authenticated;
  v_repeat:=pg_temp.checked(format('select pg_temp.capture(%L,%L,%L,%L,%L::timestamptz,%L)',v_target.farm_a,
    gen_random_uuid(),v_target.period_a,v_target.mixture_zero,v_fault_context->>'source_updated_at',v_fault_context->>'source_digest'),
    null,null,null,false);
  reset role;
  perform pg_temp.check_true(v_repeat @> '{"component_count":1,"quantity_kg":1,"total_cost":0,"replayed":false}'::jsonb,'actual editor capture accepts recorded zero');
  select a.* into v_allocation from economics_v2.group_period_feed_allocations a where a.mixture_id=v_target.mixture_zero;
  perform pg_temp.check_true(v_repeat=jsonb_build_object('contract_version','group-economics.forward.v3',
    'operation_id',(v_repeat->>'operation_id')::uuid,'mixture_id',v_target.mixture_zero,'period_id',v_target.period_a,
    'allocation_id',v_allocation.id,'updated_at',v_allocation.updated_at,'component_count',1,
    'quantity_kg',1,'total_cost',0,'source_digest',v_fault_context->>'source_digest','replayed',false)
    and v_allocation.granja_id=v_target.farm_a and v_allocation.period_id=v_target.period_a
    and v_allocation.source_updated_at=(v_fault_context->>'source_updated_at')::timestamptz
    and v_allocation.source_digest=v_fault_context->>'source_digest' and v_allocation.finalized_at is null,
    'editor exact11 result binds actual zero-cost source/version/digest to immutable target');
  v_hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-feed-capture.v1',
    'granja_id',v_target.farm_a,'actor_id',v_target.editor_a,'operation_id',(v_repeat->>'operation_id')::uuid,
    'request',jsonb_build_object('action','feed_capture','period_id',v_target.period_a,'mixture_id',v_target.mixture_zero,
      'expected_updated_at_utc',to_char((v_fault_context->>'source_updated_at')::timestamptz at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'expected_source_digest',v_fault_context->>'source_digest')))::text,'UTF8')),'hex');
  perform pg_temp.check_true((select o.payload_hash=v_hash and o.result=v_repeat and o.event_position is null
    from economics_v2.group_occupancy_operations o where o.granja_id=v_target.farm_a
      and o.operation_id=(v_repeat->>'operation_id')::uuid),'editor receipt hashes actual editor, not source creator');
  perform pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(v_target.farm_a,v_target.period_a)
    @> '{"feed_cost":130,"feed_kg_total":6,"acquisition_cost":300}'::jsonb,'zero capture adds1kg but no cost/basis charge');
  select p.* into v_proc from pg_proc p where p.oid='economics_v2.capture_group_feed_allocation(uuid,uuid,uuid,uuid,timestamp with time zone,text)'::regprocedure;
  perform pg_temp.check_true(v_proc.prorettype='jsonb'::regtype and not v_proc.prosecdef and v_proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE')
    and not has_function_privilege('anon',v_proc.oid,'EXECUTE') and not has_function_privilege('authenticated',v_proc.oid,'EXECUTE'),
    'private invoker/empty path/client ACL false');
  set constraints all immediate;
  perform pg_temp.check_true((select count(*)=2 from economics_v2.group_period_feed_allocations a where a.granja_id=v_target.farm_a)
    and (select count(*)=5 from economics_v2.group_occupancy_operations o where o.granja_id in(v_target.farm_a,v_target.farm_b))
    and not exists(select 1 from economics_v2.group_meat_snapshots s where s.granja_id in(v_target.farm_a,v_target.farm_b)),
    'two real captures plus three actual occupancy operations; no partial receipt or closure snapshot');
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_feed_capture_pass','assertion_count',(select count(*) from assertions),
  'locking_evidence','sequential_only','allocation_capture_performed',true,'canonical_group_food_api_integrated',false,
  'real_closure_proven',false,'production_gateway_integrated',false,'independent_review','pending',
  'fixture_ids',(select to_jsonb(t) from targets t)) as evidence;
rollback;
