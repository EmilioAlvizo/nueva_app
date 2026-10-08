begin;

-- Run the FULL file in the sandbox SQL Editor; report the first error and stop.
-- Expected first RED: 42883 at the eight-argument reactivate_disposed_group_meat call.
-- Fresh complete-unit forecast: fixture <=560 + future core <=240 = <=800 lines.
-- All created tables are TEMP; never enable or change RLS on business tables.
-- Real initial -> real qualified ordinary exit -> caller restore -> NEW private core.
-- Qualified source validator FALSE locks before public DML; core independently calls TRUE.
-- INTERNAL16 is working data, not an authorization token or a caller-submitted receipt.
-- Historical source is read-only, excluded from mutable F2A period locks.
-- The metadata object is nested inside an exact5 SERVER-derived provenance envelope.
-- Replay binds the ORIGINAL explicit disposed UUID with source_period_id NULL.
-- No public restoration policy, sale cancellation, F5 or zero-basis movement compatibility.
create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,
  gen_random_uuid() type_a,gen_random_uuid() type_wrong,gen_random_uuid() type_b,
  gen_random_uuid() meat,gen_random_uuid() other_meat,gen_random_uuid() eggs,gen_random_uuid() purpose_b,
  gen_random_uuid() source_a,gen_random_uuid() source_zero,
  gen_random_uuid() destination_new,gen_random_uuid() destination_reuse,
  gen_random_uuid() destination_fault,gen_random_uuid() destination_wrong,gen_random_uuid() group_b,
  gen_random_uuid() animal_a,gen_random_uuid() anchor_a,
  gen_random_uuid() animal_zero,gen_random_uuid() anchor_zero,
  gen_random_uuid() destination_seed,gen_random_uuid() later_animal,gen_random_uuid() animal_b,
  gen_random_uuid() exit_a,gen_random_uuid() exit_zero,
  gen_random_uuid() operation_a,gen_random_uuid() operation_zero,gen_random_uuid() operation_fault;
create temp table assertions(label text not null);
create temp table metadata as select '{"reference":1,"actor_id":"untrusted-metadata"}'::jsonb value;
create temp table exit_payload as select
  '{"provenance_version":"group-disposition-provenance.v1","disposition_kind":"ordinary_exit","metadata":{"reference":1}}'::jsonb value;

create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;

-- Full snapshots of all10 forward tables plus actual public/catalog/auth rows.
create temp table watched_tables(schema_name text,table_name text,primary key(schema_name,table_name));
insert into watched_tables values
  ('economics_v2','group_occupancy_operations'),('economics_v2','group_occupancy_periods'),
  ('economics_v2','group_occupancy_memberships'),('economics_v2','group_occupancy_events'),
  ('economics_v2','group_animal_acquisition_basis'),('economics_v2','group_acquisition_basis_entries'),
  ('economics_v2','group_period_feed_allocations'),('economics_v2','group_period_expenses'),
  ('economics_v2','group_period_sale_bindings'),('economics_v2','group_meat_snapshots'),
  ('public','animales'),('public','bajas_animales'),('public','venta_animal'),
  ('public','tipo_animal'),('public','grupos'),('public','cat_proposito_animal'),
  ('public','cat_razon_baja'),('public','cat_tipo_adquisicion'),('public','altas_animales'),
  ('public','miembros_granja'),('economics_v2','feature_flags');
create function pg_temp.business_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; rows jsonb; result jsonb:='{}'; farms uuid[]; actors uuid[];
begin
  select array[farm_a,farm_b],array[owner_a,owner_b,editor_a,viewer_a]
    into farms,actors from pg_temp.ids;
  for t in select * from pg_temp.watched_tables order by schema_name,table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r where granja_id=any($1) or granja_id is null',t.schema_name,t.table_name)
      into rows using farms;
    result:=result||jsonb_build_object(t.schema_name||'.'||t.table_name,rows);
  end loop;
  return result||jsonb_build_object(
    'farms',(select jsonb_agg(to_jsonb(r) order by id) from public.granjas r where id=any(farms)),
    'users',(select jsonb_agg(to_jsonb(r) order by id) from auth.users r where id=any(actors)),
    'profiles',(select jsonb_agg(to_jsonb(r) order by id) from public.perfiles r where id=any(actors)));
end;
$$;
create function pg_temp.position_state()
returns jsonb language sql security definer set search_path='' as $$
  select jsonb_build_object('last_value',last_value,'is_called',is_called)
  from economics_v2.group_economics_event_position_seq;
$$;
create function pg_temp.no_write()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_setting('f2rx.no_write',true)='on' then
    raise exception using errcode='P0001',message='F2RX unexpected business DML';
  end if;
  return null;
end;
$$;
do $blockers$
declare t record;
begin
  for t in select * from pg_temp.watched_tables
    where schema_name='economics_v2' and table_name<>'feature_flags'
      or schema_name='public' and table_name in('animales','bajas_animales','venta_animal') loop
    execute format('create trigger f2rx_no_write before insert or update or delete on %I.%I
      for each statement execute function pg_temp.no_write()',t.schema_name,t.table_name);
  end loop;
end;
$blockers$;
create function pg_temp.checked(p_sql text,p_state text default null,
  p_code text default null,p_field text default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare before_rows jsonb; before_seq jsonb; result jsonb; state text; detail text;
begin
  before_rows:=pg_temp.business_state();
  before_seq:=pg_temp.position_state();
  perform set_config('f2rx.no_write','on',true);
  begin
    execute p_sql into result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics state=returned_sqlstate,detail=pg_exception_detail;
  end;
  perform set_config('f2rx.no_write','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=before_rows,'full rows unchanged: '||p_sql);
  perform pg_temp.check_true(pg_temp.position_state()=before_seq,'sequence unchanged: '||p_sql);
  if p_state is null then
    perform pg_temp.check_true(result is not null,'nonempty replay result');
  else
    perform pg_temp.check_true(state=p_state,'expected SQLSTATE '||p_state||': '||p_sql);
    if p_code is not null then
      perform pg_temp.check_true(detail::jsonb @> jsonb_build_object(
        'contract_version','group-economics.forward.v3','code',p_code,'field',p_field)
        and detail::jsonb ? 'entity_id','typed refusal: '||p_sql);
    end if;
  end if;
  return result;
end;
$$;

-- Trusted temporary setup only: actual actor, replay first, qualified active prefix,
-- then actual inactive public state and the qualified ordinary-exit post-DML core.
create function pg_temp.exit_gateway(p_farm uuid,p_operation uuid,p_animal uuid,p_date date)
returns jsonb language plpgsql security definer set search_path='' as $$
declare source_id uuid; prepared jsonb; context jsonb; payload jsonb;
begin
  perform economics_v2.assert_group_writer_actor(p_farm);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_farm::text,0));
  select p.value into payload from pg_temp.exit_payload p;
  if exists(select 1 from economics_v2.group_occupancy_operations
    where granja_id=p_farm and operation_id=p_operation) then
    return economics_v2.exit_group_meat_nonclosing(p_farm,p_operation,p_animal,p_date,payload);
  end if;
  select period_id into source_id from economics_v2.group_occupancy_memberships
    where granja_id=p_farm and animal_id=p_animal and end_position is null;
  prepared:=economics_v2.prepare_group_operation(p_farm,p_operation,jsonb_build_object(
    'action','exit','animal_id',p_animal,'source_period_id',source_id,
    'destination_group_id',null,'destination_purpose_id',null,'sale_id',null,
    'effective_on',p_date,'payload',payload));
  context:=economics_v2.validate_group_meat_nonclosing_source(p_farm,p_animal,p_date);
  update public.animales set activo=false where granja_id=p_farm and id=p_animal
    and activo=true and baja_id is null;
  if not found then raise exception 'F2RX exit caller update failed'; end if;
  return economics_v2.exit_group_meat_nonclosing(p_farm,p_operation,p_animal,p_date,payload);
end;
$$;

-- This is fixture-only caller orchestration, NOT a deployed mutator body or RPC.
-- Core must reconstruct replay before consulting current disposed pointers/membership.
create function pg_temp.reactivate_gateway(p_farm uuid,p_operation uuid,p_animal uuid,p_date date,
  p_group uuid,p_purpose uuid,p_event uuid,p_metadata jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; prepared jsonb; context jsonb; envelope jsonb;
begin
  actor:=economics_v2.assert_group_writer_actor(p_farm);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_farm::text,0));
  if exists(select 1 from economics_v2.group_occupancy_operations
    where granja_id=p_farm and operation_id=p_operation) then
    return economics_v2.reactivate_disposed_group_meat(
      p_farm,p_operation,p_animal,p_date,p_group,p_purpose,p_event,p_metadata);
  end if;
  envelope:=jsonb_build_object('provenance_version','group-reactivation-provenance.v1',
    'disposition_kind','ordinary_reactivation','disposed_event_id',p_event,'actor_id',actor,'metadata',p_metadata);
  prepared:=economics_v2.prepare_group_operation(p_farm,p_operation,jsonb_build_object(
    'action','reactivate','animal_id',p_animal,'source_period_id',null,
    'destination_group_id',p_group,'destination_purpose_id',p_purpose,'sale_id',null,
    'effective_on',p_date,'payload',envelope));
  context:=economics_v2.validate_disposed_group_meat_reactivation_source(
    p_farm,p_animal,p_event,p_date,p_group,p_purpose,false);
  perform pg_temp.check_true(context->>'actor_id'=actor::text,'qualified FALSE prefix preserves actual actor');
  update public.animales set activo=true,grupo_id=p_group,proposito_id=p_purpose
    where granja_id=p_farm and id=p_animal and activo=false and baja_id is null;
  if not found then raise exception 'F2RX restore caller update failed'; end if;
  -- FIRST missing-mutator call: valid REAL history and prefix, AFTER actual caller restore.
  return economics_v2.reactivate_disposed_group_meat(
    p_farm,p_operation,p_animal,p_date,p_group,p_purpose,p_event,p_metadata);
end;
$$;

select pg_temp.check_true(
  not exists(select 1 from auth.users where raw_user_meta_data->>'fixture'='group-reactivation')
  and not exists(select 1 from public.granjas where nombre like 'F2RX %'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"group-reactivation"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F2RX farm A',owner_a from ids
union all select farm_b,owner_b,'F2RX farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F2RX type A',owner_a from ids
union all select type_wrong,farm_a,'F2RX wrong type',owner_a from ids
union all select type_b,farm_b,'F2RX foreign type',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat,farm_a,'F2RX meat','carne',owner_a from ids
union all select other_meat,farm_a,'F2RX other meat','carne',owner_a from ids
union all select eggs,farm_a,'F2RX eggs','postura',owner_a from ids
union all select purpose_b,farm_b,'F2RX foreign meat','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'F2RX group '||g::text,owner_a from ids
cross join lateral unnest(array[source_a,source_zero,destination_new,destination_reuse,destination_fault]) g
union all select destination_wrong,farm_a,type_wrong,'F2RX wrong group',owner_a from ids
union all select group_b,farm_b,type_b,'F2RX foreign group',owner_b from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,notas,created_by)
select a,farm_a,type_a,case when a in(animal_zero,anchor_zero) then source_zero
  when a=destination_seed then destination_reuse when a=later_animal then destination_new else source_a end,
  case when a=later_animal then other_meat else meat end,current_date-5,
  case when a=animal_a then 300 else 0 end,'F2RX animal',owner_a
from ids cross join lateral unnest(array[animal_a,anchor_a,animal_zero,anchor_zero,destination_seed,later_animal]) a
union all select animal_b,farm_b,type_b,group_b,purpose_b,current_date-5,0,'F2RX foreign',owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
set constraints all immediate;
set constraints all deferred;
create temp table initial as select a animal_id,economics_v2.enter_group_meat_initial(
  farm_a,gen_random_uuid(),a,current_date-4,
  case when a in(animal_zero,anchor_zero) then source_zero
    when a=destination_seed then destination_reuse else source_a end,meat,'{}') result
from ids cross join lateral unnest(array[animal_a,anchor_a,animal_zero,anchor_zero,destination_seed]) a;
create temp table captures as select animal_id,to_jsonb(b) basis
from economics_v2.group_animal_acquisition_basis b where granja_id=(select farm_a from ids);
create temp table original_entries as select to_jsonb(b) full_row
from economics_v2.group_acquisition_basis_entries b where granja_id=(select farm_a from ids);
update public.animales set costo_adquisicion=999 where id=(select animal_a from ids);
create temp table exits as select animal_a animal_id,pg_temp.exit_gateway(farm_a,exit_a,animal_a,current_date-3) result from ids
union all select animal_zero,pg_temp.exit_gateway(farm_a,exit_zero,animal_zero,current_date-3) from ids;
create temp table historical_rows as select e.animal_id,to_jsonb(e) event,to_jsonb(m) membership,to_jsonb(p) period
from economics_v2.group_occupancy_events e join economics_v2.group_occupancy_memberships m on m.id=e.membership_id
join economics_v2.group_occupancy_periods p on p.id=e.period_id
where e.granja_id=(select farm_a from ids) and e.action='exit';
create temp table disposed_public as select id,to_jsonb(a) full_row from public.animales a
where id in(select animal_a from ids union all select animal_zero from ids);
set constraints all immediate;
set constraints all deferred;

do $grants$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$grants$;
grant execute on function pg_temp.reactivate_gateway(uuid,uuid,uuid,date,uuid,uuid,uuid,jsonb),
  pg_temp.checked(text,text,text,text),pg_temp.check_true(boolean,text),
  pg_temp.business_state(),pg_temp.position_state() to authenticated,anon;

-- Actual OWNER mutation under authenticated role; the first new-core error MUST escape.
create temp table receipts(animal_id uuid,result jsonb);
do $first$
declare f record; event uuid; data jsonb; r jsonb;
begin
  select * into f from pg_temp.ids;
  select (result->'membership_event_ids'->>0)::uuid into event from pg_temp.exits where animal_id=f.animal_a;
  select value into data from pg_temp.metadata;
  set local role authenticated;
  r:=pg_temp.reactivate_gateway(f.farm_a,f.operation_a,f.animal_a,current_date-2,
    f.destination_new,f.other_meat,event,data);
  reset role;
  insert into pg_temp.receipts values(f.animal_a,r);
end;
$first$;

-- Independent late UPDATE faults; sequence gaps survive, every business row must roll back.
create function pg_temp.late_fault()
returns trigger language plpgsql set search_path='' as $$
begin
  if tg_table_name='group_animal_acquisition_basis' then
    if current_setting('f2rx.fault',true)='basis' and new.status='active' then
      raise exception using errcode='P0001',message='F2RX injected basis activation failure';
    end if;
  elsif tg_table_name='group_occupancy_operations' then
    if current_setting('f2rx.fault',true)='completion' and new.result->>'action'='reactivate' then
      perform pg_temp.check_true(exists(select 1 from economics_v2.group_occupancy_events e
        join economics_v2.group_occupancy_memberships m on m.id=e.membership_id
        join economics_v2.group_occupancy_periods p on p.id=e.period_id
        join economics_v2.group_animal_acquisition_basis b on b.granja_id=e.granja_id and b.animal_id=e.animal_id
        join public.animales a on a.id=e.animal_id and a.granja_id=e.granja_id
        where e.granja_id=new.granja_id and e.operation_id=new.operation_id and e.action='reactivate'
          and e.event_position=new.event_position and m.start_position=e.event_position and m.end_position is null
          and p.start_position=e.event_position and p.end_position is null
          and b.status='active' and b.current_account_kind='period' and b.current_period_id=p.id
          and b.remaining_basis=0 and b.disposed_event_id is null and b.version=2
          and a.activo=true and a.baja_id is null and a.grupo_id=p.group_id and a.proposito_id=p.purpose_id),
        'final completion LAST: caller restore/new period/new member/event/active basis already exist');
      raise exception using errcode='P0001',message='F2RX injected final completion failure';
    end if;
  end if;
  return new;
end;
$$;
create trigger f2rx_late_basis before update on economics_v2.group_animal_acquisition_basis
for each row execute function pg_temp.late_fault();
create trigger f2rx_late_completion before update on economics_v2.group_occupancy_operations
for each row execute function pg_temp.late_fault();

do $proof$
declare f record; r jsonb; z jsonb; repeated jsonb; data jsonb; envelope jsonb; prepared jsonb;
  event_a uuid; event_zero uuid; destination uuid; baseline jsonb; before_seq jsonb;
  sql text; probe record; actor record; state text; message text; proc record; control record;
begin
  select * into f from pg_temp.ids;
  select value into data from pg_temp.metadata;
  select (result->'membership_event_ids'->>0)::uuid into event_a from pg_temp.exits where animal_id=f.animal_a;
  select (result->'membership_event_ids'->>0)::uuid into event_zero from pg_temp.exits where animal_id=f.animal_zero;
  select result into r from pg_temp.receipts where animal_id=f.animal_a;
  destination:=(r->>'destination_period_id')::uuid;
  perform pg_temp.check_true(exists(select 1 from economics_v2.group_occupancy_periods
    where id=destination and granja_id=f.farm_a and group_id=f.destination_new and purpose_id=f.other_meat
      and starts_on=current_date-2 and start_position=(r->>'event_position')::bigint and end_position is null),
    'new destination is actual requested meat pin at activation boundary');

  sql:=format('select pg_temp.reactivate_gateway(%L,%L,%L,current_date-2,%L,%L,%L,%L::jsonb)',
    f.farm_a,f.operation_a,f.animal_a,f.destination_new,f.other_meat,event_a,data);
  repeated:=pg_temp.checked(sql);
  perform pg_temp.check_true(repeated=r||'{"replayed":true}'::jsonb,'original replay after pointer cleared');
  repeated:=pg_temp.checked(format('select pg_temp.reactivate_gateway(%L,%L,%L,current_date-2,%L,%L,%L,%L::jsonb)',
    f.farm_a,f.operation_a,f.animal_a,f.destination_new,f.other_meat,event_a,jsonb_set(data,'{reference}','1.00')));
  perform pg_temp.check_true(repeated=r||'{"replayed":true}'::jsonb,'numeric metadata canonicalization');
  for probe in select * from (values
    (event_a,f.destination_new,f.other_meat,current_date-2,jsonb_set(data,'{reference}','2')),
    (event_zero,f.destination_new,f.other_meat,current_date-2,data),
    (event_a,f.destination_reuse,f.other_meat,current_date-2,data),
    (event_a,f.destination_new,f.meat,current_date-2,data),
    (event_a,f.destination_new,f.other_meat,current_date-1,data)) v(event,group_id,purpose,effective_on,metadata) loop
    perform pg_temp.checked(format('select pg_temp.reactivate_gateway(%L,%L,%L,%L::date,%L,%L,%L,%L::jsonb)',
      f.farm_a,f.operation_a,f.animal_a,probe.effective_on,probe.group_id,probe.purpose,probe.event,probe.metadata),
      '22023','operation_payload_conflict','operation_id');
  end loop;
  baseline:=pg_temp.business_state();
  for probe in select * from (values('{}'::jsonb),
    (jsonb_set(r,'{membership_event_ids}',jsonb_build_array(event_zero)))) v(receipt) loop
    begin
      update economics_v2.group_occupancy_operations set result=probe.receipt
        where operation_id=f.operation_a and granja_id=f.farm_a;
      perform pg_temp.checked(sql,'23514','invariant_violation','operation_id');
      raise exception using errcode='Z0001',message='F2RX restore invalid replay ledger';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'invalid replay ledger probe fully restored');
  end loop;
  -- Old EXIT replay remains original-history-only after real accounting reactivation.
  repeated:=pg_temp.checked(format('select pg_temp.exit_gateway(%L,%L,%L,current_date-3)',f.farm_a,f.exit_a,f.animal_a));
  perform pg_temp.check_true(repeated=(select result from pg_temp.exits where animal_id=f.animal_a)||'{"replayed":true}'::jsonb,
    'original owner EXIT replay after real reactivation');
  perform economics_v2.enter_group_meat_initial(f.farm_a,gen_random_uuid(),f.later_animal,
    current_date,f.destination_new,f.other_meat,'{}');
  repeated:=pg_temp.checked(sql);
  perform pg_temp.check_true(repeated=r||'{"replayed":true}'::jsonb,'replay precedes later REAL destination chronology');

  -- Core-owned metadata guards are direct calls: no caller DML masks the refusal.
  for probe in select * from (values(null::jsonb),('[]'::jsonb),('1'::jsonb),('"text"'::jsonb)) v(metadata) loop
    perform pg_temp.checked(format('select economics_v2.reactivate_disposed_group_meat(%L,%L,%L,current_date-1,%L,%L,%L,%L::jsonb)',
      f.farm_a,gen_random_uuid(),f.animal_zero,f.destination_reuse,f.meat,event_zero,probe.metadata),
      '22023','invalid_request','payload');
  end loop;
  perform pg_temp.checked(format('select economics_v2.reactivate_disposed_group_meat(%L,null::uuid,%L,current_date,%L,%L,%L,%L::jsonb)',
    f.farm_a,f.animal_zero,f.destination_reuse,f.meat,event_zero,data),
    '22023','invalid_request','request');
  -- Representative integration refusals; the qualified full history matrix is not duplicated.
  for probe in select * from (values
    (f.farm_a,f.animal_a,event_a,current_date,f.destination_reuse,f.meat,'23514','invariant_violation','animal_id'),
    (f.farm_b,f.animal_zero,event_zero,current_date,f.destination_reuse,f.meat,'42501','forbidden','granja_id'),
    (f.farm_a,f.animal_b,event_zero,current_date,f.destination_reuse,f.meat,'42501','forbidden','animal_id'),
    (f.farm_a,f.animal_zero,event_a,current_date,f.destination_reuse,f.meat,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_zero,null::uuid,current_date,f.destination_reuse,f.meat,'22023','invalid_request','disposed_event_id'),
    (f.farm_a,f.destination_seed,event_zero,current_date,f.destination_reuse,f.meat,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_zero,event_zero,current_date-4,f.destination_reuse,f.meat,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_zero,event_zero,current_date,f.group_b,f.meat,'42501','forbidden','group_id'),
    (f.farm_a,f.animal_zero,event_zero,current_date,f.destination_wrong,f.meat,'23514','invariant_violation','group_id'),
    (f.farm_a,f.animal_zero,event_zero,current_date,f.destination_reuse,f.eggs,'22023','invalid_request','purpose_id'))
    v(farm,animal,event,effective_on,group_id,purpose,state,code,field) loop
    perform pg_temp.checked(format('select pg_temp.reactivate_gateway(%L,%L,%L,%L::date,%L,%L,%L,%L::jsonb)',
      probe.farm,gen_random_uuid(),probe.animal,probe.effective_on,probe.group_id,probe.purpose,probe.event,data),
      probe.state,probe.code,probe.field);
  end loop;
  perform pg_temp.checked(format('select economics_v2.reactivate_disposed_group_meat(%L,%L,%L,current_date,%L,%L,%L,%L::jsonb)',
    f.farm_a,gen_random_uuid(),f.animal_zero,f.destination_reuse,f.meat,event_zero,data),
    '23514','invariant_violation','animal_id');
  baseline:=pg_temp.business_state();
  begin
    update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
    perform pg_temp.checked(sql,'42501','forbidden','granja_id');
    raise exception using errcode='Z0001',message='F2RX restore disabled farm';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'disabled farm probe fully restored');
  -- A qualified FALSE prefix is not permission to skip the core's independent TRUE reread.
  begin
    perform economics_v2.validate_disposed_group_meat_reactivation_source(
      f.farm_a,f.animal_zero,event_zero,current_date,f.destination_reuse,f.meat,false);
    update public.animales set activo=true,grupo_id=f.destination_fault where id=f.animal_zero;
    perform pg_temp.checked(format('select economics_v2.reactivate_disposed_group_meat(%L,%L,%L,current_date,%L,%L,%L,%L::jsonb)',
      f.farm_a,gen_random_uuid(),f.animal_zero,f.destination_reuse,f.meat,event_zero,data),
      '42501','forbidden','group_id');
    raise exception using errcode='Z0001',message='F2RX restore post-prefix mismatch';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'post-prefix public mismatch fully restored');

  for actor in select * from (values(f.editor_a,'authenticated'),(f.viewer_a,'authenticated'),(null::uuid,'anon')) v(id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    if actor.id=f.editor_a then
      perform pg_temp.checked(sql,'22023','operation_payload_conflict','operation_id');
    else
      perform pg_temp.checked(sql,'42501','forbidden','granja_id');
    end if;
    perform pg_temp.checked(format('select economics_v2.reactivate_disposed_group_meat(%L,%L,%L,current_date,%L,%L,%L,%L::jsonb)',
      f.farm_a,f.operation_a,f.animal_a,f.destination_new,f.other_meat,event_a,data),'42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated')::text,true);

  -- Both late faults use a brand NEW destination, proving period creation also rolls back.
  for probe in select * from (values('basis'),('completion')) v(kind) loop
    baseline:=pg_temp.business_state();
    before_seq:=pg_temp.position_state();
    state:=null;
    message:=null;
    perform set_config('f2rx.fault',probe.kind,true);
    begin
      perform pg_temp.reactivate_gateway(f.farm_a,f.operation_fault,f.animal_zero,current_date,
        f.destination_fault,f.other_meat,event_zero,data);
    exception when others then
      get stacked diagnostics state=returned_sqlstate,message=message_text;
    end;
    perform set_config('f2rx.fault','off',true);
    perform pg_temp.check_true(state='P0001' and message=case when probe.kind='basis'
      then 'F2RX injected basis activation failure' else 'F2RX injected final completion failure' end,
      'independent reached late UPDATE fault: '||probe.kind);
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'all rows/caller restore/new period rollback: '||probe.kind);
    perform pg_temp.check_true((pg_temp.position_state()->>'last_value')::bigint>(before_seq->>'last_value')::bigint,
      'real position issued; rollback retains sequence gap: '||probe.kind);
    set constraints all immediate;
    set constraints all deferred;
  end loop;
  set local role authenticated;
  z:=pg_temp.reactivate_gateway(f.farm_a,f.operation_zero,f.animal_zero,current_date-1,
    f.destination_reuse,f.meat,event_zero,data);
  reset role;
  insert into pg_temp.receipts values(f.animal_zero,z);

  -- Complete integrated state proof for original300/OWNER/new and original0/EDITOR/reuse.
  for control in select * from (values
    (f.animal_a,f.operation_a,event_a,f.destination_new,f.other_meat,f.owner_a,current_date-2),
    (f.animal_zero,f.operation_zero,event_zero,f.destination_reuse,f.meat,f.editor_a,current_date-1))
    v(animal,operation,event,group_id,purpose,actor,effective_on) loop
    select result into r from pg_temp.receipts where animal_id=control.animal;
    envelope:=jsonb_build_object('provenance_version','group-reactivation-provenance.v1',
      'disposition_kind','ordinary_reactivation','disposed_event_id',control.event,'actor_id',control.actor,'metadata',data);
    perform pg_temp.check_true(r=jsonb_build_object('contract_version','group-economics.forward.v3',
      'operation_id',control.operation,'action','reactivate','animal_id',control.animal,'source_period_id',null,
      'destination_period_id',r->'destination_period_id','membership_event_ids',r->'membership_event_ids',
      'effective_on',control.effective_on,'event_position',r->'event_position','source_end_position',null,
      'destination_start_position',r->'destination_start_position','basis_entry_ids','[]'::jsonb,
      'basis_before',0,'basis_after',0,'source_status',null,'destination_status','open','snapshot_id',null,
      'state_version',2,'replayed',false) and jsonb_array_length(r->'membership_event_ids')=1
      and (select count(*)=19 from jsonb_object_keys(r)),'exact19 complete zero-basis activation receipt');
    perform pg_temp.check_true(exists(select 1 from economics_v2.group_occupancy_events e
      join economics_v2.group_occupancy_memberships m on m.id=e.membership_id
      join economics_v2.group_occupancy_periods p on p.id=m.period_id
      join pg_temp.historical_rows h on h.animal_id=e.animal_id
      where e.id=(r->'membership_event_ids'->>0)::uuid and e.granja_id=f.farm_a and e.animal_id=control.animal
        and e.operation_id=control.operation and e.action='reactivate' and e.effective_on=control.effective_on
        and e.event_position=(r->>'event_position')::bigint and m.start_position=e.event_position
        and m.end_position is null and m.id<>(h.membership->>'id')::uuid
        and e.event_position>(h.event->>'event_position')::bigint and e.period_id=p.id
        and p.id=(r->>'destination_period_id')::uuid and p.group_id=control.group_id and p.purpose_id=control.purpose
        and p.start_position=(r->>'destination_start_position')::bigint and p.end_position is null
        and e.sale_id is null and e.basis_transfer_id is null
        and e.reason=economics_v2.canonical_group_request(envelope)::text),
      'real new membership/gap/event/pin/boundary and exact5 server provenance');
    perform pg_temp.check_true(exists(select 1 from economics_v2.group_animal_acquisition_basis b
      join pg_temp.captures c using(animal_id) join public.animales a on a.id=b.animal_id
      where b.animal_id=control.animal and to_jsonb(b)=c.basis||jsonb_build_object(
        'remaining_basis',0,'status','active','current_account_kind','period',
        'current_period_id',(r->>'destination_period_id')::uuid,'disposed_event_id',null,'version',2)
        and a.activo=true and a.baja_id is null and a.grupo_id=control.group_id and a.proposito_id=control.purpose),
      'full captured row preserved except exact activation delta; no recapture');
    perform pg_temp.check_true(exists(select 1 from public.animales a join pg_temp.disposed_public d on d.id=a.id
      where a.id=control.animal and to_jsonb(a)=d.full_row||jsonb_build_object(
        'activo',true,'grupo_id',control.group_id,'proposito_id',control.purpose)),
      'public full row changed only by fixture caller restore; original300 public cost remains999');
    perform set_config('request.jwt.claim.sub',control.actor::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',control.actor,'role','authenticated')::text,true);
    prepared:=economics_v2.prepare_group_operation(f.farm_a,control.operation,jsonb_build_object(
      'action','reactivate','animal_id',control.animal,'source_period_id',null,'destination_group_id',control.group_id,
      'destination_purpose_id',control.purpose,'sale_id',null,'effective_on',control.effective_on,'payload',envelope));
    perform pg_temp.check_true(prepared->'result'=r||'{"replayed":true}'::jsonb
      and exists(select 1 from economics_v2.group_occupancy_operations where granja_id=f.farm_a
        and operation_id=control.operation and result=r and event_position=(r->>'event_position')::bigint
        and payload_hash=prepared->>'payload_hash'),'exact canonical8/sourceNULL/reserved5 hash and completed ledger');
  end loop;
  perform pg_temp.check_true((z->>'destination_start_position')::bigint<(z->>'event_position')::bigint
    and z->'destination_period_id'=(select result->'destination_period_id' from pg_temp.initial where animal_id=f.destination_seed),
    'reused destination preserves original start, not new membership boundary');
  perform pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(f.farm_a,destination) @>
    '{"active_animal_count":2,"acquisition_cost":0}'::jsonb
    and economics_v2.calculate_group_period_live_metrics(f.farm_a,(z->>'destination_period_id')::uuid) @>
    '{"active_animal_count":2,"acquisition_cost":0}'::jsonb
    and economics_v2.calculate_group_period_live_metrics(f.farm_a,(select (result->>'source_period_id')::uuid
      from pg_temp.exits where animal_id=f.animal_a)) @> '{"acquisition_cost":300,"active_animal_count":1}'::jsonb,
    'source realized300 retained; separate new/reused destinations acquire0');
  perform pg_temp.check_true(not exists(select 1 from pg_temp.historical_rows h where not exists(
    select 1 from economics_v2.group_occupancy_events e join economics_v2.group_occupancy_memberships m on m.id=e.membership_id
    join economics_v2.group_occupancy_periods p on p.id=e.period_id
    where to_jsonb(e)=h.event and to_jsonb(m)=h.membership and to_jsonb(p)=h.period)),
    'all original exit event/member/period rows fully unchanged');
  perform pg_temp.check_true(not exists(select 1 from pg_temp.original_entries o where not exists(
    select 1 from economics_v2.group_acquisition_basis_entries b where to_jsonb(b)=o.full_row))
    and (select count(*)=6 and sum(signed_amount)=300 from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a)
    and not exists(select 1 from economics_v2.group_acquisition_basis_entries
      where granja_id=f.farm_a and operation_id in(f.operation_a,f.operation_zero,f.operation_fault)),
    'signed original entries unchanged; later initial only, no activation entries/pairs/holding');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_animal_acquisition_basis b
    join pg_temp.captures c using(animal_id) where b.animal_id not in(f.animal_a,f.animal_zero) and to_jsonb(b)<>c.basis),
    'all original non-reactivating captures fully unchanged');
  select * into proc from pg_proc where oid=
    'economics_v2.reactivate_disposed_group_meat(uuid,uuid,uuid,date,uuid,uuid,uuid,jsonb)'::regprocedure;
  perform pg_temp.check_true(proc.prorettype='jsonb'::regtype and not proc.prosecdef
    and proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(proc.proacl,acldefault('f',proc.proowner))) acl
      where acl.grantee=0 and acl.privilege_type='EXECUTE')
    and not has_function_privilege('anon',proc.oid,'EXECUTE')
    and not has_function_privilege('authenticated',proc.oid,'EXECUTE'),'private invoker/empty path/no PUBLIC or client execute');
  perform pg_temp.check_true((select count(*)=13 from pg_trigger where tgname='f2rx_no_write'),'all13 no-write statement blockers');
  perform pg_temp.check_true((select count(*)=10 from economics_v2.group_occupancy_operations where granja_id=f.farm_a)
    and (select count(*)=2 from economics_v2.group_occupancy_events where granja_id=f.farm_a and action='reactivate'),
    'exact completed operations and two activation events; failed operations absent');
  set constraints all immediate;
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_memberships m
    join economics_v2.group_occupancy_periods p on p.id=m.period_id
    where m.granja_id=f.farm_a and not(m.position_span<@p.position_span)), 'forced membership containment');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_meat_snapshots where granja_id=f.farm_a)
    and not exists(select 1 from public.bajas_animales where granja_id=f.farm_a)
    and not exists(select 1 from public.venta_animal where granja_id=f.farm_a)
    and not exists(select 1 from economics_v2.group_occupancy_events where granja_id=f.farm_a
      and action in('delete','transfer','purpose_change')),'ordinary exits/reactivations only; no other branch or F5');
end;
$proof$;

select jsonb_build_object('result','group_economics_forward_reactivation_pass',
  'assertion_count',(select count(*) from assertions),'locking_evidence','sequential_only',
  'reactivation_performed',true,'production_gateway_integrated',false,
  'zero_basis_movement_compatibility_proven',false,'fixture_ids',(select to_jsonb(ids) from ids)) as evidence;
rollback;
