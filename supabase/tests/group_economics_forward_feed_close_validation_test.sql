begin;

-- HUMAN Sandbox only: review/run the FULL transaction; report the first error.
-- Authoring only. Expected first RED: uncaught 42883 at $first$'s named NEW call.
-- Budget: fixture <=500 + complete future private migration <=300 = <=800 lines.
-- Target implementation 220-270 lines, including auth, structural checks, digest and ACL.
-- Proposed private contract: validate_group_feed_allocation_for_close(uuid,uuid,uuid)
-- with required names p_granja_id/p_period_id/p_allocation_id, returns jsonb,
-- STABLE SECURITY INVOKER, postgres owner, empty search_path; no client EXECUTE.
-- Result exact9: contract_version=group-economics.forward.v3, allocation_id,
-- mixture_id, period_id, source_updated_at, source_digest, component_count,
-- quantity_kg, total_cost. Values describe independently verified stored source.
-- No actor argument, token, reservation, receipt, snapshot, finalization or public facade.
-- Authorize current JWT through assert_group_writer_actor, even under postgres.
-- Missing/foreign period or allocation/pairing: 42501/forbidden with matching field.
-- Null arguments: 22023/invalid_request. Closed: 23514/closed_period_immutable.
-- Allocation/source disagreement: 23514/invariant_violation/allocation_id.
-- Retain source structural errors from validate_group_feed_source, NOT its admission
-- chronology: later occupancy is valid. Do not call that validator after later entry.
-- Require owned OPEN meat target, owned Group/type/purpose/header/components/food/catalog,
-- header Group=period Group, finite ordered dates/timestamp, complete dedicated unshared
-- purchases, distinct categories, nonempty finite positive kg/nonnegative TOTAL costs.
-- Compare occurred_on, source_updated_at, digest, count, kg and cost to captured fact.
-- Hash stays group-feed-source.v1: canonical exact8 header plus UUID-ordered exact5
-- components, UTC microseconds Z. Allocation.updated_at, stock and category.activo
-- do not enter it. No new calendar admission or unique-open-purpose requirement.
-- Pure inspector, NOT closure authority. Future closer locks complete scope/facts and
-- revalidates transactionally. No lock/concurrency or real F5 completion proof here.
-- All corruption uses admin privileges already allowed by installed direct guards;
-- no disabled triggers/constraints, clock repairs, producer proxies or fabricated events.

create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,gen_random_uuid() editor_a,
  gen_random_uuid() viewer_a,gen_random_uuid() outsider,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,
  gen_random_uuid() type_a,gen_random_uuid() type_b,
  gen_random_uuid() meat_a,gen_random_uuid() meat_b,gen_random_uuid() posture_a,
  gen_random_uuid() group_a,gen_random_uuid() group_other,gen_random_uuid() group_b,
  gen_random_uuid() category_a,gen_random_uuid() category_second,gen_random_uuid() category_b,
  gen_random_uuid() animal_a,gen_random_uuid() animal_later,gen_random_uuid() animal_other,
  gen_random_uuid() animal_b,gen_random_uuid() mixture_a,gen_random_uuid() mixture_b,
  gen_random_uuid() enter_a,gen_random_uuid() enter_later,gen_random_uuid() enter_other,
  gen_random_uuid() enter_b,gen_random_uuid() create_a,gen_random_uuid() create_b;
create temp table assertions(label text not null);
create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated',jsonb_build_object('fixture','feed-close-validation','tag',farm_a)
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a,outsider]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Feed close A '||farm_a,owner_a from ids
union all select farm_b,owner_b,'Feed close B '||farm_b,owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Feed close type A',owner_a from ids
union all select type_b,farm_b,'Feed close type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Feed close meat A','carne',owner_a from ids
union all select posture_a,farm_a,'Feed close posture','postura',owner_a from ids
union all select meat_b,farm_b,'Feed close meat B','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'Feed close Group '||g,owner_a from ids
cross join lateral unnest(array[group_a,group_other]) g
union all select group_b,farm_b,type_b,'Feed close foreign Group',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select c,farm_a,'Feed close category '||c,true,owner_a from ids
cross join lateral unnest(array[category_a,category_second]) c
union all select category_b,farm_b,'Feed close foreign category',true,owner_b from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,created_by)
select a,farm_a,type_a,group_a,meat_a,current_date-7,0,owner_a from ids
cross join lateral unnest(array[animal_a,animal_later]) a
union all select animal_other,farm_a,type_a,group_other,meat_a,current_date-7,0,owner_a from ids
union all select animal_b,farm_b,type_b,group_b,meat_b,current_date-7,0,owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true),
  set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
create temp table admissions(animal_id uuid,result jsonb);
insert into admissions select animal_a,economics_v2.enter_group_meat_initial(
  farm_a,enter_a,animal_a,current_date-4,group_a,meat_a,'{}') from ids;
insert into admissions select animal_other,economics_v2.enter_group_meat_initial(
  farm_a,enter_other,animal_other,current_date-4,group_other,meat_a,'{}') from ids;
select set_config('request.jwt.claim.sub',owner_b::text,true),
  set_config('request.jwt.claims',jsonb_build_object('sub',owner_b,'role','authenticated')::text,true) from ids;
insert into admissions select animal_b,economics_v2.enter_group_meat_initial(
  farm_b,enter_b,animal_b,current_date-4,group_b,meat_b,'{}') from ids;
create temp table targets as select f.*,
  (select (a.result->>'destination_period_id')::uuid from admissions a where a.animal_id=f.animal_a) period_a,
  (select (a.result->>'destination_period_id')::uuid from admissions a where a.animal_id=f.animal_other) period_other,
  (select (a.result->>'destination_period_id')::uuid from admissions a where a.animal_id=f.animal_b) period_b
from ids f;
do $temp_access$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$temp_access$;
grant select on pg_temp.targets to authenticated;
create temp table captures(farm_id uuid,result jsonb);
grant insert on pg_temp.captures to authenticated;
-- Actual authenticated public producer; allocation and source are created together.
set local role authenticated;
insert into pg_temp.captures select farm_b,public.crear_mezcla_grupo_v1(
  p_granja_id=>farm_b,p_operation_id=>create_b,p_period_id=>period_b,p_mezcla_id=>mixture_b,
  p_fecha_inicio=>current_date-3,p_grupo_id=>group_b,p_ingredientes=>jsonb_build_array(
    jsonb_build_object('categoria_id',category_b,'cantidad_kg',1,'costo_total',0))) from pg_temp.targets;
reset role;
select set_config('request.jwt.claim.sub',owner_a::text,true),
  set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
set local role authenticated;
insert into pg_temp.captures select farm_a,public.crear_mezcla_grupo_v1(
  p_granja_id=>farm_a,p_operation_id=>create_a,p_period_id=>period_a,p_mezcla_id=>mixture_a,
  p_fecha_inicio=>current_date-3,p_grupo_id=>group_a,p_ingredientes=>jsonb_build_array(
    jsonb_build_object('categoria_id',category_a,'cantidad_kg',1,'costo_total',4),
    jsonb_build_object('categoria_id',category_second,'cantidad_kg',2,'costo_total',8))) from pg_temp.targets;
reset role;
create temp table captured as select a.* from economics_v2.group_period_feed_allocations a
where a.granja_id in(select farm_a from ids union all select farm_b from ids);
-- This real core entry happens AFTER actual capture, with a later effective date.
insert into admissions select animal_later,economics_v2.enter_group_meat_initial(
  farm_a,enter_later,animal_later,current_date-1,group_a,meat_a,'{}') from ids;
select pg_temp.check_true((select (a.result->>'destination_period_id')::uuid=t.period_a
  and exists(select 1 from economics_v2.group_occupancy_events e
    where e.granja_id=t.farm_a and e.period_id=t.period_a and e.animal_id=t.animal_later
      and e.operation_id=t.enter_later and e.action='enter' and e.effective_on=current_date-1
      and e.effective_on>c.occurred_on)
  and exists(select 1 from economics_v2.group_occupancy_periods p
    where p.id=t.period_a and p.closed_on is null and p.end_position is null)
  and c.finalized_at is null
  from targets t join admissions a on a.animal_id=t.animal_later
  join captured c on c.mixture_id=t.mixture_a),'actual later entry retained captured OPEN period');
set constraints all immediate;
set constraints all deferred;

-- Independent oracle: no new inspector or mutating capture helper computes expected values.
create temp table expected as
select a.id allocation_id,jsonb_build_object('contract_version','group-economics.forward.v3',
  'allocation_id',a.id,'mixture_id',m.id,'period_id',a.period_id,'source_updated_at',m.updated_at,
  'source_digest',encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'source_version','group-feed-source.v1','granja_id',m.granja_id,'mixture_id',m.id,'group_id',m.grupo_id,
    'fecha_inicio',m.fecha_inicio,'fecha_termino',m.fecha_termino,
    'updated_at_utc',to_char(m.updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'components',x.components))::text,'UTF8')),'hex'),
  'component_count',x.component_count,'quantity_kg',x.quantity_kg,'total_cost',x.total_cost) value
from captured a join public.mezcla m on m.id=a.mixture_id
cross join lateral (select count(*) component_count,sum(mc.cantidad) quantity_kg,sum(c.precio) total_cost,
  jsonb_agg(jsonb_build_object('component_id',mc.id,'food_id',c.id,'category_id',c.cat_comida_id,
    'quantity_kg',mc.cantidad,'total_cost',c.precio) order by mc.id) components
  from public.mezcla_comida mc join public.comida c on c.id=mc.comida_id where mc.mezcla_id=m.id) x;
select pg_temp.check_true((select e.value @> '{"component_count":2,"quantity_kg":3,"total_cost":12}'::jsonb
  and e.value->>'source_digest'=a.source_digest and (e.value->>'source_updated_at')::timestamptz=a.source_updated_at
  from expected e join captured a on a.id=e.allocation_id join targets t on t.mixture_a=a.mixture_id),
  'known kg1+2 and TOTAL cost4+8, independent canonical digest and real source timestamp');
select pg_temp.check_true(not exists(select 1 from captured c
  join economics_v2.group_period_feed_allocations a on a.id=c.id where to_jsonb(a)<>to_jsonb(c))
  and (select count(*)=2 from captured)
  and (select count(*)=6 from economics_v2.group_occupancy_operations o
    where o.granja_id in(select farm_a from ids union all select farm_b from ids))
  and (select count(*)=4 from economics_v2.group_occupancy_events e
    where e.granja_id in(select farm_a from ids union all select farm_b from ids)),
  'four real entries/two atomic feed creates; later entry did not modify captured facts');

-- Whole-schema observations, including fences, receipts, ACLs and explicit sequence columns.
-- Isolate Sandbox traffic: these full-state comparisons are sequential evidence only.
create temp table watched as select n.nspname schema_name,c.relname table_name
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where c.relkind in ('r','p') and (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users'));
create temp table watched_sequences as select n.nspname schema_name,c.relname sequence_name
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity');
-- nextval survives exception/subtransaction rollback, exposing swallowed DML attempts.
create temp sequence attempted_dml;
grant usage,select on sequence pg_temp.attempted_dml to authenticated,anon;
create function pg_temp.business_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_table record; v_rows jsonb; v_result jsonb:='{}';
begin
  for v_table in select w.* from pg_temp.watched w order by w.schema_name,w.table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r',v_table.schema_name,v_table.table_name) into v_rows;
    v_result:=v_result||jsonb_build_object(v_table.schema_name||'.'||v_table.table_name,v_rows);
  end loop;
  for v_table in select s.* from pg_temp.watched_sequences s order by s.schema_name,s.sequence_name loop
    execute format('select jsonb_build_object(''last_value'',s.last_value,''log_cnt'',s.log_cnt,''is_called'',s.is_called)
      from %I.%I s',v_table.schema_name,v_table.sequence_name) into v_rows;
    v_result:=v_result||jsonb_build_object(v_table.schema_name||'.'||v_table.sequence_name,v_rows);
  end loop;
  select jsonb_agg(to_jsonb(a) order by a.kind,a.oid) into v_rows from (
    select 'relation' kind,c.oid,c.relacl::text acl from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','economics_v2','group_feed_integrity','auth')
    union all select 'function',p.oid,p.proacl::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','economics_v2','group_feed_integrity','auth')
    union all select 'schema',n.oid,n.nspacl::text from pg_namespace n
    where n.nspname in ('public','economics_v2','group_feed_integrity','auth')) a;
  return v_result||jsonb_build_object('acl',v_rows);
end;
$$;
create function pg_temp.observe_dml()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('feed_close.observe',true)='on' then
    perform nextval('pg_temp.attempted_dml'::regclass);
    raise exception using errcode='P0001',message='Feed close inspection attempted DML',
      detail=tg_table_schema||'.'||tg_table_name||' '||tg_op;
  end if;
  return null;
end;
$$;
do $observers$
declare v_table record;
begin
  for v_table in select w.* from pg_temp.watched w loop
    execute format('create trigger feed_close_observer before insert or update or delete or truncate
      on %I.%I for each statement execute function pg_temp.observe_dml()',v_table.schema_name,v_table.table_name);
  end loop;
end;
$observers$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,
  p_field text default null,p_entity uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_result jsonb; v_state text; v_detail text; v_attempts jsonb;
begin
  v_before:=pg_temp.business_state();
  select jsonb_build_object('last_value',s.last_value,'log_cnt',s.log_cnt,'is_called',s.is_called)
    into v_attempts from pg_temp.attempted_dml s;
  perform set_config('feed_close.observe','on',true);
  begin execute p_sql into v_result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics v_state=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform set_config('feed_close.observe','off',true);
  perform pg_temp.check_true((select jsonb_build_object('last_value',s.last_value,
    'log_cnt',s.log_cnt,'is_called',s.is_called) from pg_temp.attempted_dml s)=v_attempts,
    'no DML attempts, including swallowed observer exceptions');
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'inspection/refusal preserves full business/ACL/sequences');
  if p_state is null then
    perform pg_temp.check_true(v_result is not null,'nonempty inspection result');
  else
    perform pg_temp.check_true(v_state=p_state,'expected SQLSTATE '||p_state);
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb=jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field,'entity_id',p_entity),'exact4 typed error DETAIL');
    end if;
  end if;
  return v_result;
end;
$$;
-- Temporary definers only observe state; NEVER invoke business validators/producers.
revoke all on function pg_temp.business_state(),pg_temp.check_true(boolean,text),
  pg_temp.checked(text,text,text,text,uuid) from public;
grant execute on function pg_temp.business_state(),pg_temp.check_true(boolean,text),
  pg_temp.checked(text,text,text,text,uuid) to authenticated,anon;
grant insert on pg_temp.assertions to authenticated,anon;
create temp table baseline as select pg_temp.business_state() state,
  jsonb_build_object('last_value',s.last_value,'log_cnt',s.log_cnt,'is_called',s.is_called) attempted_state
from pg_temp.attempted_dml s;
create temp table results(value jsonb);
do $first$
declare v_target record; v_allocation uuid; v_result jsonb; v_attempts jsonb;
begin
  select t.* into v_target from pg_temp.targets t;
  select c.id into v_allocation from pg_temp.captured c where c.mixture_id=v_target.mixture_a;
  select jsonb_build_object('last_value',s.last_value,'log_cnt',s.log_cnt,'is_called',s.is_called)
    into v_attempts from pg_temp.attempted_dml s;
  perform set_config('feed_close.observe','on',true);
  -- Direct postgres-owned invocation with actual owner JWT, no exception handler.
  v_result:=economics_v2.validate_group_feed_allocation_for_close(
    p_granja_id=>v_target.farm_a,p_period_id=>v_target.period_a,p_allocation_id=>v_allocation);
  perform set_config('feed_close.observe','off',true);
  perform pg_temp.check_true((select jsonb_build_object('last_value',s.last_value,
    'log_cnt',s.log_cnt,'is_called',s.is_called) from pg_temp.attempted_dml s)=v_attempts,
    'first direct call made no DML attempts, even if exceptions were swallowed');
  perform pg_temp.check_true(pg_temp.business_state()=(select b.state from pg_temp.baseline b),'first call is pure');
  insert into pg_temp.results values(v_result);
end;
$first$;

do $proof$
declare v_target record; v_a record; v_b record; v_proc record; v_probe record;
  v_sql text; v_result jsonb; v_expected jsonb; v_mode text; v_food uuid; v_before jsonb; v_zone text;
begin
  select t.* into v_target from pg_temp.targets t;
  select a.* into v_a from pg_temp.captured a where a.mixture_id=v_target.mixture_a;
  select a.* into v_b from pg_temp.captured a where a.mixture_id=v_target.mixture_b;
  select e.value into v_expected from pg_temp.expected e where e.allocation_id=v_a.id;
  perform pg_temp.check_true((select r.value=v_expected and (select count(*)=9 from jsonb_object_keys(r.value))
    from pg_temp.results r),'exact9 verified-source result accepts actual later occupancy');
  v_sql:=format('select economics_v2.validate_group_feed_allocation_for_close(
    p_granja_id=>%L::uuid,p_period_id=>%L::uuid,p_allocation_id=>%L::uuid)',v_target.farm_a,v_target.period_a,v_a.id);
  perform pg_temp.check_true(pg_temp.checked(v_sql)=v_expected,'repeat inspection has no receipt/token');
  v_zone:=current_setting('TimeZone');
  perform set_config('TimeZone','Etc/GMT+5',true);
  v_result:=pg_temp.checked(v_sql);
  perform pg_temp.check_true(v_result->>'source_digest'=v_expected->>'source_digest'
    and (v_result->>'source_updated_at')::timestamptz=v_a.source_updated_at,'UTC digest independent of rendering');
  perform set_config('TimeZone',v_zone,true);
  perform set_config('request.jwt.claim.sub',v_target.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_target.editor_a,'role','authenticated')::text,true);
  perform pg_temp.check_true(pg_temp.checked(v_sql)=v_expected,'admin inspection honors real editor JWT');
  perform set_config('request.jwt.claim.sub',v_target.owner_b::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_target.owner_b,'role','authenticated')::text,true);
  perform pg_temp.check_true(pg_temp.checked(format(
    'select economics_v2.validate_group_feed_allocation_for_close(%L::uuid,%L::uuid,%L::uuid)',
    v_target.farm_b,v_target.period_b,v_b.id))=(select e.value from pg_temp.expected e where e.allocation_id=v_b.id),
    'own foreign-farm source with recorded zero cost is valid');
  for v_probe in select unnest(array[v_target.viewer_a,v_target.outsider,v_target.owner_b]) actor loop
    perform set_config('request.jwt.claim.sub',v_probe.actor::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_probe.actor,'role','authenticated')::text,true);
    perform pg_temp.checked(v_sql,'42501','forbidden','granja_id',v_target.farm_a);
  end loop;
  -- Actual SQL roles cannot execute private helper, even with a correct owner/editor JWT.
  for v_probe in select * from (values(v_target.owner_a,'authenticated'),
    (v_target.editor_a,'authenticated'),(null::uuid,'anon')) a(actor,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(v_probe.actor::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_probe.actor,'role',v_probe.role_name)::text,true);
    execute format('set local role %I',v_probe.role_name);
    perform pg_temp.checked(v_sql,'42501');
    perform pg_temp.checked(format('select public.validate_group_feed_allocation_for_close(%L::uuid,%L::uuid,%L::uuid)',
      v_target.farm_a,v_target.period_a,v_a.id),'42883');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims','{"role":"anon"}',true);
  perform pg_temp.checked(v_sql,'42501','forbidden','granja_id',v_target.farm_a);
  perform set_config('request.jwt.claim.sub',v_target.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_target.owner_a,'role','authenticated')::text,true);
  for v_probe in select * from (values
    (null::uuid,v_target.period_a,v_a.id,'22023','invalid_request','granja_id',null::uuid),
    (v_target.farm_a,null::uuid,v_a.id,'22023','invalid_request','period_id',null::uuid),
    (v_target.farm_a,v_target.period_a,null::uuid,'22023','invalid_request','allocation_id',null::uuid),
    (v_target.farm_a,gen_random_uuid(),v_a.id,'42501','forbidden','period_id',null::uuid),
    (v_target.farm_a,v_target.period_b,v_a.id,'42501','forbidden','period_id',v_target.period_b),
    (v_target.farm_a,v_target.period_a,gen_random_uuid(),'42501','forbidden','allocation_id',null::uuid),
    (v_target.farm_a,v_target.period_a,v_b.id,'42501','forbidden','allocation_id',v_b.id),
    (v_target.farm_a,v_target.period_other,v_a.id,'42501','forbidden','allocation_id',v_a.id),
    (v_target.farm_a,v_target.period_a,v_target.mixture_a,'42501','forbidden','allocation_id',v_target.mixture_a))
    p(farm,period,allocation,state,code,field,entity) loop
    perform pg_temp.checked(format('select economics_v2.validate_group_feed_allocation_for_close(%L::uuid,%L::uuid,%L::uuid)',
      v_probe.farm,v_probe.period,v_probe.allocation),v_probe.state,v_probe.code,v_probe.field,
      case when v_probe.entity is not null then v_probe.entity
        when v_probe.code='forbidden' and v_probe.field='period_id' then v_probe.period
        when v_probe.code='forbidden' then v_probe.allocation else null end);
  end loop;
  select mc.comida_id into v_food from public.mezcla_comida mc
    join public.comida c on c.id=mc.comida_id where mc.mezcla_id=v_target.mixture_a and c.cat_comida_id=v_target.category_a;
  for v_mode in select unnest(array['count','kg','cost','digest','version','occurred_on',
    'source_price','source_kg','source_version','empty','nonmeat','closed','disabled','group']) loop
    v_before:=pg_temp.business_state();
    begin
      case v_mode
        when 'count' then update economics_v2.group_period_feed_allocations set component_count=3 where id=v_a.id;
        when 'kg' then update economics_v2.group_period_feed_allocations set quantity_kg=4 where id=v_a.id;
        when 'cost' then update economics_v2.group_period_feed_allocations set total_cost=13 where id=v_a.id;
        when 'digest' then update economics_v2.group_period_feed_allocations set source_digest=repeat('0',64) where id=v_a.id;
        when 'version' then update economics_v2.group_period_feed_allocations set source_updated_at=source_updated_at+interval '1 second' where id=v_a.id;
        when 'occurred_on' then update economics_v2.group_period_feed_allocations set occurred_on=current_date-2 where id=v_a.id;
        when 'source_price' then update public.comida set precio=precio+1 where id=v_food;
        when 'source_kg' then update public.mezcla_comida set cantidad=cantidad+1 where mezcla_id=v_target.mixture_a and comida_id=v_food;
        when 'source_version' then update public.mezcla set updated_at=updated_at+interval '1 second' where id=v_target.mixture_a;
        when 'empty' then delete from public.mezcla_comida where mezcla_id=v_target.mixture_a;
        when 'nonmeat' then update economics_v2.group_occupancy_periods set purpose_id=v_target.posture_a where id=v_target.period_a;
        when 'closed' then update economics_v2.group_occupancy_periods set closed_on=current_date,end_position=start_position+1000 where id=v_target.period_a;
        when 'disabled' then update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=v_target.farm_a;
        when 'group' then update public.mezcla set grupo_id=v_target.group_other where id=v_target.mixture_a;
      end case;
      if v_mode in ('source_price','source_kg') then
        perform pg_temp.check_true((select m.updated_at=v_a.source_updated_at from public.mezcla m where m.id=v_target.mixture_a),
          'price/weight-only drift retains actual header version');
      end if;
      perform pg_temp.checked(v_sql,
        case when v_mode in ('disabled','group') then '42501' when v_mode='nonmeat' then '22023' else '23514' end,
        case v_mode when 'disabled' then 'forbidden' when 'group' then 'forbidden' when 'nonmeat' then 'invalid_request'
          when 'closed' then 'closed_period_immutable' else 'invariant_violation' end,
        case v_mode when 'disabled' then 'granja_id' when 'group' then 'group_id' when 'nonmeat' then 'purpose_id'
          when 'closed' then 'period_id' when 'empty' then 'mixture_id' else 'allocation_id' end,
        case v_mode when 'disabled' then v_target.farm_a when 'group' then v_target.group_other when 'nonmeat' then v_target.posture_a
          when 'closed' then v_target.period_a when 'empty' then v_target.mixture_a else v_a.id end);
      -- Synthetic closed metadata is only a negative probe, never a closure proof.
      raise exception using errcode='Z0001',message='Restore complete corruption subtransaction';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'exact restoration after '||v_mode);
  end loop;
  -- Table CHECKs already exclude nonfinite/negative kg and costs. Nullable source
  -- fields and cross-farm links remain constructible and must be inspected explicitly.
  for v_probe in select * from (values
    ('missing_price','23514','invariant_violation','mixture_id',v_target.mixture_a),
    ('missing_kg','23514','invariant_violation','mixture_id',v_target.mixture_a),
    ('foreign_food','42501','forbidden','food_id',v_food),
    ('foreign_catalog','42501','forbidden','category_id',v_target.category_b),
    ('duplicate_category','23514','invariant_violation','mixture_id',v_target.mixture_a),
    ('shared_food','23514','invariant_violation','mixture_id',v_target.mixture_a),
    ('source_infinite_version','23514','invariant_violation','mixture_id',v_target.mixture_a))
    p(mode,state,code,field,entity) loop
    v_before:=pg_temp.business_state();
    begin
      case v_probe.mode
        when 'missing_price' then update public.comida set precio=null where id=v_food;
        when 'missing_kg' then update public.mezcla_comida set cantidad=null where mezcla_id=v_target.mixture_a and comida_id=v_food;
        when 'foreign_food' then update public.comida set granja_id=v_target.farm_b where id=v_food;
        when 'foreign_catalog' then update public.comida set cat_comida_id=v_target.category_b where id=v_food;
        when 'duplicate_category' then update public.comida set cat_comida_id=v_target.category_a
          where id in(select mc.comida_id from public.mezcla_comida mc where mc.mezcla_id=v_target.mixture_a) and id<>v_food;
        when 'shared_food' then insert into public.mezcla_comida(granja_id,mezcla_id,comida_id,cantidad)
          values(v_target.farm_b,v_target.mixture_b,v_food,1);
        when 'source_infinite_version' then update public.mezcla set updated_at='infinity'::timestamptz where id=v_target.mixture_a;
      end case;
      perform pg_temp.checked(v_sql,v_probe.state,v_probe.code,v_probe.field,v_probe.entity);
      raise exception using errcode='Z0001',message='Restore structural source corruption';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'structural probe restored: '||v_probe.mode);
  end loop;
  v_before:=pg_temp.business_state();
  begin
    update economics_v2.group_period_feed_allocations set updated_at=updated_at+interval '1 second' where id=v_a.id;
    update public.comida set cantidad=100 where id=v_food;
    update public.cat_comida set activo=false where id=v_target.category_a;
    perform pg_temp.check_true(pg_temp.checked(v_sql)=v_expected,'allocation clock/stock/archival are not source digest inputs');
    raise exception using errcode='Z0001',message='Restore irrelevant mutable metadata';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'irrelevant metadata restored');
  -- Missing header cannot be fabricated with installed immediate allocation FK.
  -- Prove that boundary instead; no trigger/constraint bypass to manufacture a dangling fact.
  begin
    delete from public.mezcla where id=v_target.mixture_a;
    raise exception 'Expected immediate allocation/header FK refusal';
  exception when foreign_key_violation then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'header deletion cannot leave missing captured source');
  select p.* into v_proc from pg_proc p
  where p.oid='economics_v2.validate_group_feed_allocation_for_close(uuid,uuid,uuid)'::regprocedure;
  perform pg_temp.check_true(v_proc.prorettype='jsonb'::regtype and v_proc.provolatile='s' and not v_proc.prosecdef
    and v_proc.proowner='postgres'::regrole and v_proc.proconfig @> array['search_path=""']
    and v_proc.pronargdefaults=0 and v_proc.proargnames=array['p_granja_id','p_period_id','p_allocation_id']::text[]
    and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) a
      where a.grantee=0 and a.privilege_type='EXECUTE')
    and not has_function_privilege('anon',v_proc.oid,'EXECUTE')
    and not has_function_privilege('authenticated',v_proc.oid,'EXECUTE'),'private STABLE invoker exact signature/owner/ACL');
  perform pg_temp.check_true(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='validate_group_feed_allocation_for_close'),'no public wrapper');
  set constraints all immediate;
  perform pg_temp.check_true((select jsonb_build_object('last_value',s.last_value,
    'log_cnt',s.log_cnt,'is_called',s.is_called) from pg_temp.attempted_dml s)
    =(select b.attempted_state from pg_temp.baseline b),'no DML attempts across entire inspection suite');
  perform pg_temp.check_true(pg_temp.business_state()=(select b.state from pg_temp.baseline b),'whole end state equals post-setup baseline');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_period_feed_allocations a
    where a.granja_id in(v_target.farm_a,v_target.farm_b) and a.finalized_at is not null)
    and not exists(select 1 from economics_v2.group_meat_snapshots s where s.granja_id in(v_target.farm_a,v_target.farm_b)),
    'no finalized_at writes or snapshot production');
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_feed_close_validation_pass',
  'assertion_count',(select count(*) from assertions),'private_feed_close_integrity_validation_proven',true,
  'later_occupancy_event_accepted',true,'feed_finalization_proven',false,'real_closure_proven',false,
  'snapshot_production_proven',false,'public_api_activated',false,'http_proven',false,'production_proven',false,
  'independent_review','pending','locking_evidence','sequential_only','fixture_ids',jsonb_build_object(
    'targets',(select to_jsonb(t) from targets t),'admissions',(select jsonb_agg(to_jsonb(a)) from admissions a),
    'captures',(select jsonb_agg(to_jsonb(c)) from captures c),'allocations',(select jsonb_agg(to_jsonb(a)) from captured a),
    'ingredients',(select jsonb_agg(to_jsonb(mc)) from public.mezcla_comida mc
      where mc.mezcla_id in(select mixture_a from ids union all select mixture_b from ids)))) as evidence;
rollback;
