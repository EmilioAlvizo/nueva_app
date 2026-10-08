begin;

-- HUMAN sandbox Dashboard only: save and run this FULL BEGIN/ROLLBACK file.
-- First expected RED is genuine 42883 at the first intended eight-argument transfer.
-- Do not implement the new helper until that exact error has been recorded.
-- Complete-unit forecast: fixture <=480 + future private migration <=320 = <=800.
-- Scope: first nonclosing transfer after real ordinary exit/reactivation, not OUT/RETURN.
-- Original positive300 is retained in the historical source; transfer moves zero only.
-- Temporary trusted callers below are fixture orchestration, never production gateways.
-- Business triggers are transactional fault probes; no RLS or deployed helper is changed.
-- Sequential evidence only. Sequence gaps survive rollback; never rewind the sequence.
create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,
  gen_random_uuid() type_a,gen_random_uuid() type_b,
  gen_random_uuid() meat,gen_random_uuid() eggs,gen_random_uuid() meat_b,
  gen_random_uuid() historical_group,gen_random_uuid() reactivated_group,
  gen_random_uuid() destination_new,gen_random_uuid() destination_reuse,
  gen_random_uuid() destination_fault,gen_random_uuid() foreign_group,
  gen_random_uuid() animal_a,gen_random_uuid() animal_b,
  gen_random_uuid() historical_anchor,gen_random_uuid() reactivated_anchor,
  gen_random_uuid() destination_seed,gen_random_uuid() later_seed,
  gen_random_uuid() exit_a,gen_random_uuid() exit_b,
  gen_random_uuid() reactivate_a,gen_random_uuid() reactivate_b,
  gen_random_uuid() transfer_a,gen_random_uuid() transfer_b,gen_random_uuid() transfer_fault;
create temp table assertions(label text not null);
create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;

-- Full rows, not aggregate-only rollback checks: all ten economics tables and public inputs.
create temp table watched_tables(schema_name text,table_name text,primary key(schema_name,table_name));
insert into watched_tables values
  ('economics_v2','group_occupancy_operations'),('economics_v2','group_occupancy_periods'),
  ('economics_v2','group_occupancy_memberships'),('economics_v2','group_occupancy_events'),
  ('economics_v2','group_animal_acquisition_basis'),('economics_v2','group_acquisition_basis_entries'),
  ('economics_v2','group_period_feed_allocations'),('economics_v2','group_period_expenses'),
  ('economics_v2','group_period_sale_bindings'),('economics_v2','group_meat_snapshots'),
  ('economics_v2','feature_flags'),('public','animales'),('public','bajas_animales'),
  ('public','venta_animal'),('public','grupos'),('public','tipo_animal'),
  ('public','cat_proposito_animal'),('public','miembros_granja');
create function pg_temp.business_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; rows jsonb; result jsonb:='{}'; farms uuid[];
begin
  select array[farm_a,farm_b] into farms from pg_temp.ids;
  for t in select * from pg_temp.watched_tables order by schema_name,table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r where granja_id=any($1) or granja_id is null',t.schema_name,t.table_name)
      into rows using farms;
    result:=result||jsonb_build_object(t.schema_name||'.'||t.table_name,rows);
  end loop;
  return result;
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
  if current_setting('f2rt.no_write',true)='on' then
    raise exception using errcode='P0001',message='F2RT unexpected business DML';
  end if;
  return null;
end;
$$;
do $blockers$
declare t record;
begin
  for t in select * from pg_temp.watched_tables where schema_name='economics_v2'
    and table_name<>'feature_flags' or schema_name='public'
    and table_name in('animales','bajas_animales','venta_animal') loop
    execute format('create trigger f2rt_no_write before insert or update or delete on %I.%I
      for each statement execute function pg_temp.no_write()',t.schema_name,t.table_name);
  end loop;
end;
$blockers$;
create function pg_temp.checked(p_sql text,p_state text default null,
  p_code text default null,p_field text default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare baseline jsonb; position jsonb; result jsonb; state text; detail text;
begin
  baseline:=pg_temp.business_state();
  position:=pg_temp.position_state();
  perform set_config('f2rt.no_write','on',true);
  begin
    execute p_sql into result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics state=returned_sqlstate,detail=pg_exception_detail;
  end;
  perform set_config('f2rt.no_write','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'full rows unchanged: '||p_sql);
  perform pg_temp.check_true(pg_temp.position_state()=position,'sequence unchanged: '||p_sql);
  if p_state is null then
    perform pg_temp.check_true(result is not null,'nonempty replay');
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

-- Real qualified pre-DML validation followed by actual public exit and private exit core.
create function pg_temp.ordinary_exit(p_farm uuid,p_op uuid,p_animal uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare context jsonb; prepared jsonb; source uuid;
  payload jsonb:='{"provenance_version":"group-disposition-provenance.v1","disposition_kind":"ordinary_exit","metadata":{}}';
begin
  perform economics_v2.assert_group_writer_actor(p_farm);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_farm::text,0));
  select period_id into source from economics_v2.group_occupancy_memberships
    where granja_id=p_farm and animal_id=p_animal and end_position is null;
  prepared:=economics_v2.prepare_group_operation(p_farm,p_op,jsonb_build_object(
    'action','exit','animal_id',p_animal,'source_period_id',source,'destination_group_id',null,
    'destination_purpose_id',null,'sale_id',null,'effective_on',current_date-3,'payload',payload));
  context:=economics_v2.validate_group_meat_nonclosing_source(p_farm,p_animal,current_date-3);
  update public.animales set activo=false where granja_id=p_farm and id=p_animal and activo and baja_id is null;
  if not found then raise exception 'F2RT exit caller update failed'; end if;
  return economics_v2.exit_group_meat_nonclosing(p_farm,p_op,p_animal,current_date-3,payload);
end;
$$;
create function pg_temp.ordinary_reactivate(p_farm uuid,p_op uuid,p_animal uuid,p_group uuid,p_purpose uuid,p_event uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; context jsonb; prepared jsonb; envelope jsonb;
begin
  actor:=economics_v2.assert_group_writer_actor(p_farm);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_farm::text,0));
  envelope:=jsonb_build_object('provenance_version','group-reactivation-provenance.v1',
    'disposition_kind','ordinary_reactivation','disposed_event_id',p_event,'actor_id',actor,'metadata','{}'::jsonb);
  prepared:=economics_v2.prepare_group_operation(p_farm,p_op,jsonb_build_object(
    'action','reactivate','animal_id',p_animal,'source_period_id',null,'destination_group_id',p_group,
    'destination_purpose_id',p_purpose,'sale_id',null,'effective_on',current_date-2,'payload',envelope));
  context:=economics_v2.validate_disposed_group_meat_reactivation_source(
    p_farm,p_animal,p_event,current_date-2,p_group,p_purpose,false);
  update public.animales set activo=true,grupo_id=p_group,proposito_id=p_purpose
    where granja_id=p_farm and id=p_animal and not activo and baja_id is null;
  if not found then raise exception 'F2RT restore caller update failed'; end if;
  return economics_v2.reactivate_disposed_group_meat(
    p_farm,p_op,p_animal,current_date-2,p_group,p_purpose,p_event,'{}'::jsonb);
end;
$$;

-- Lock complete mutable scope before fixture caller DML; new core must independently reread.
-- Explicit reactivation operation is history identity, NOT an authorization token.
-- New core must bind it inside a server-derived payload envelope:
-- {reactivation_operation_id: UUID, metadata: caller object}; F2A still binds actual actor.
create function pg_temp.transfer(p_farm uuid,p_op uuid,p_animal uuid,p_date date,
  p_group uuid,p_purpose uuid,p_reactivation uuid,p_metadata jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare source uuid; source_group uuid; destination uuid; context jsonb;
begin
  perform economics_v2.assert_group_writer_actor(p_farm);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_farm::text,0));
  if not exists(select 1 from economics_v2.group_occupancy_operations
    where granja_id=p_farm and operation_id=p_op) then
    select m.period_id,p.group_id into source,source_group
    from economics_v2.group_occupancy_memberships m join economics_v2.group_occupancy_periods p
      on p.granja_id=m.granja_id and p.id=m.period_id
    where m.granja_id=p_farm and m.animal_id=p_animal and m.end_position is null;
    select id into destination from economics_v2.group_occupancy_periods
      where granja_id=p_farm and group_id=p_group and purpose_id=p_purpose and end_position is null;
    context:=economics_v2.lock_group_writer_scope(p_farm,array[source_group,p_group],array[p_animal],
      array[source]||case when destination is null then '{}'::uuid[] else array[destination] end,p_date);
    update public.animales set grupo_id=p_group,proposito_id=p_purpose
      where granja_id=p_farm and id=p_animal and activo and baja_id is null;
    if not found then raise exception 'F2RT transfer caller update failed'; end if;
  end if;
  -- FIRST intended new-core invocation: all eight arguments have their exact SQL types.
  return economics_v2.transfer_reactivated_group_meat_nonclosing(
    p_farm,p_op,p_animal,p_date,p_group,p_purpose,p_reactivation,p_metadata);
end;
$$;

select pg_temp.check_true(not exists(select 1 from auth.users
  where raw_user_meta_data->>'fixture'='reactivated-transfer'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"reactivated-transfer"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F2RT farm A',owner_a from ids
union all select farm_b,owner_b,'F2RT farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F2RT type A',owner_a from ids
union all select type_b,farm_b,'F2RT type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat,farm_a,'F2RT meat','carne',owner_a from ids
union all select eggs,farm_a,'F2RT eggs','postura',owner_a from ids
union all select meat_b,farm_b,'F2RT foreign meat','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'F2RT group '||g::text,owner_a from ids
cross join lateral unnest(array[historical_group,reactivated_group,destination_new,destination_reuse,destination_fault]) g
union all select foreign_group,farm_b,type_b,'F2RT foreign group',owner_b from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,notas,created_by)
select a,farm_a,type_a,case when a=reactivated_anchor then reactivated_group
  when a=destination_seed then destination_reuse when a=later_seed then destination_new else historical_group end,
  meat,current_date-6,case when a in(animal_a,animal_b) then 300 else 0 end,'F2RT animal',owner_a
from ids cross join lateral unnest(array[animal_a,animal_b,historical_anchor,reactivated_anchor,destination_seed,later_seed]) a;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
create temp table initial as select a animal_id,economics_v2.enter_group_meat_initial(
  farm_a,gen_random_uuid(),a,current_date-5,
  case when a=reactivated_anchor then reactivated_group when a=destination_seed then destination_reuse else historical_group end,
  meat,'{}'::jsonb) result from ids
cross join lateral unnest(array[animal_a,animal_b,historical_anchor,reactivated_anchor,destination_seed]) a;
create temp table captures as select animal_id,to_jsonb(b) full_row
from economics_v2.group_animal_acquisition_basis b where granja_id=(select farm_a from ids);
create temp table original_entries as select to_jsonb(b) full_row
from economics_v2.group_acquisition_basis_entries b where granja_id=(select farm_a from ids);
update public.animales set costo_adquisicion=999 where id in(select animal_a from ids union all select animal_b from ids);
create temp table exits as select animal_a animal_id,pg_temp.ordinary_exit(farm_a,exit_a,animal_a) result from ids
union all select animal_b,pg_temp.ordinary_exit(farm_a,exit_b,animal_b) from ids;
create temp table historical as select to_jsonb(e) event,to_jsonb(m) membership,to_jsonb(p) period
from economics_v2.group_occupancy_events e join economics_v2.group_occupancy_memberships m on m.id=e.membership_id
join economics_v2.group_occupancy_periods p on p.id=e.period_id
where e.granja_id=(select farm_a from ids) and e.action='exit';
create temp table reactivations as select x.animal_id,economics.result from exits x cross join ids f
cross join lateral (select pg_temp.ordinary_reactivate(f.farm_a,
  case when x.animal_id=f.animal_a then f.reactivate_a else f.reactivate_b end,x.animal_id,
  f.reactivated_group,f.meat,(x.result->'membership_event_ids'->>0)::uuid) result) economics;
set constraints all immediate;
set constraints all deferred;
select pg_temp.check_true((select count(*)=2 and bool_and(initial_basis=300 and source_cost=300
  and remaining_basis=0 and version=2 and status='active' and disposed_event_id is null)
  from economics_v2.group_animal_acquisition_basis where animal_id in(select animal_id from exits)),
  'REAL initial300 -> ordinary exit -> qualified reactivation before new transfer');
create temp table restored_public as select id,to_jsonb(a) full_row from public.animales a
where granja_id=(select farm_a from ids);
do $grants$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$grants$;
grant execute on function pg_temp.transfer(uuid,uuid,uuid,date,uuid,uuid,uuid,jsonb),
  pg_temp.checked(text,text,text,text),pg_temp.business_state(),pg_temp.position_state(),
  pg_temp.check_true(boolean,text) to authenticated,anon;
create temp table receipts(animal_id uuid,result jsonb);
do $first$
declare f record; r jsonb;
begin
  select * into f from pg_temp.ids;
  set local role authenticated;
  r:=pg_temp.transfer(f.farm_a,f.transfer_a,f.animal_a,current_date-1,
    f.destination_new,f.meat,f.reactivate_a,'{"probe":1.00}'::jsonb);
  reset role;
  insert into pg_temp.receipts values(f.animal_a,r);
end;
$first$;

-- Separate second-leg and completion faults: caller DML/new period/all rows must roll back.
create function pg_temp.late_fault()
returns trigger language plpgsql set search_path='' as $$
begin
  if tg_table_name='group_acquisition_basis_entries' then
    if current_setting('f2rt.fault',true)='second_leg' and new.entry_kind='transfer_in' then
      raise exception using errcode='P0001',message='F2RT injected second_leg';
    end if;
  elsif current_setting('f2rt.fault',true)='completion' and new.result->>'action'='transfer' then
    perform pg_temp.check_true((select count(*)=2 and bool_and(signed_amount=0)
      from economics_v2.group_acquisition_basis_entries where granja_id=new.granja_id and operation_id=new.operation_id)
      and exists(select 1 from economics_v2.group_animal_acquisition_basis
        where granja_id=new.granja_id and animal_id=(new.result->>'animal_id')::uuid
          and current_period_id=(new.result->>'destination_period_id')::uuid and remaining_basis=0 and version=3),
      'completion LAST after zero pair and basis pointer update');
    raise exception using errcode='P0001',message='F2RT injected completion';
  end if;
  return new;
end;
$$;
create trigger f2rt_late_leg before insert on economics_v2.group_acquisition_basis_entries
for each row execute function pg_temp.late_fault();
create trigger f2rt_late_completion before update on economics_v2.group_occupancy_operations
for each row execute function pg_temp.late_fault();

do $proof$
declare f record; r jsonb; repeated jsonb; sql text; baseline jsonb; position jsonb;
  probe record; actor record; control record; proc record; state text; message text; prepared jsonb;
begin
  select * into f from pg_temp.ids;
  select result into r from pg_temp.receipts where animal_id=f.animal_a;
  sql:=format('select pg_temp.transfer(%L,%L,%L,current_date-1,%L,%L,%L,''{"probe":1}''::jsonb)',
    f.farm_a,f.transfer_a,f.animal_a,f.destination_new,f.meat,f.reactivate_a);
  repeated:=pg_temp.checked(sql);
  perform pg_temp.check_true(repeated=r||'{"replayed":true}'::jsonb,'canonical replay with original source and numeric metadata');
  for probe in select * from (values
    (f.destination_new,f.meat,f.reactivate_a,current_date-1,'{"probe":2}'::jsonb),
    (f.destination_reuse,f.meat,f.reactivate_a,current_date-1,'{"probe":1}'::jsonb),
    (f.destination_new,f.eggs,f.reactivate_a,current_date-1,'{"probe":1}'::jsonb),
    (f.destination_new,f.meat,f.reactivate_b,current_date-1,'{"probe":1}'::jsonb),
    (f.destination_new,f.meat,f.reactivate_a,current_date,'{"probe":1}'::jsonb))
    v(group_id,purpose,reactivation,effective_on,metadata) loop
    perform pg_temp.checked(format('select pg_temp.transfer(%L,%L,%L,%L::date,%L,%L,%L,%L::jsonb)',
      f.farm_a,f.transfer_a,f.animal_a,probe.effective_on,probe.group_id,probe.purpose,probe.reactivation,probe.metadata),
      '22023','operation_payload_conflict','operation_id');
  end loop;
  -- Later real destination chronology must not obstruct original replay.
  perform economics_v2.enter_group_meat_initial(f.farm_a,gen_random_uuid(),f.later_seed,current_date,f.destination_new,f.meat,'{}');
  repeated:=pg_temp.checked(sql);
  perform pg_temp.check_true(repeated=r||'{"replayed":true}'::jsonb,'replay before later real destination chronology');
  for actor in select * from (values(f.editor_a,'authenticated'),(f.viewer_a,'authenticated'),(null::uuid,'anon')) v(id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    if actor.id=f.editor_a then
      perform pg_temp.checked(sql,'22023','operation_payload_conflict','operation_id');
    else
      perform pg_temp.checked(sql,'42501','forbidden','granja_id');
    end if;
    perform pg_temp.checked('select economics_v2.transfer_reactivated_group_meat_nonclosing(
      null::uuid,null::uuid,null::uuid,null::date,null::uuid,null::uuid,null::uuid,null::jsonb)','42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  -- Direct core refusals isolate history and authoritative public-state checks from caller DML.
  for probe in select * from (values
    (f.farm_b,f.animal_b,f.destination_reuse,f.meat,f.reactivate_b,'42501','forbidden','granja_id'),
    (f.farm_a,f.animal_b,f.destination_reuse,f.meat,null::uuid,'22023','invalid_request','reactivation_operation_id'),
    (f.farm_a,f.animal_b,f.destination_reuse,f.meat,f.reactivate_a,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_b,f.destination_reuse,f.meat,f.reactivate_b,'42501','forbidden','group_id'))
    v(farm,animal,group_id,purpose,reactivation,state,code,field) loop
    perform pg_temp.checked(format('select economics_v2.transfer_reactivated_group_meat_nonclosing(
      %L,%L,%L,current_date,%L,%L,%L,''{}''::jsonb)',probe.farm,gen_random_uuid(),probe.animal,
      probe.group_id,probe.purpose,probe.reactivation),probe.state,probe.code,probe.field);
  end loop;
  -- Fake remaining0 without real exit/reactivation is not eligible, even for an initial0 control.
  perform pg_temp.checked(format('select economics_v2.transfer_reactivated_group_meat_nonclosing(
    %L,%L,%L,current_date,%L,%L,%L,''{}''::jsonb)',f.farm_a,gen_random_uuid(),f.reactivated_anchor,
    f.destination_reuse,f.meat,f.reactivate_b),'23514','invariant_violation','animal_id');
  for probe in select * from (values('second_leg'),('completion')) v(kind) loop
    baseline:=pg_temp.business_state();
    position:=pg_temp.position_state();
    state:=null;
    message:=null;
    perform set_config('f2rt.fault',probe.kind,true);
    begin
      perform pg_temp.transfer(f.farm_a,f.transfer_fault,f.animal_b,current_date,
        f.destination_fault,f.meat,f.reactivate_b,'{}');
    exception when others then
      get stacked diagnostics state=returned_sqlstate,message=message_text;
    end;
    perform set_config('f2rt.fault','off',true);
    perform pg_temp.check_true(state='P0001' and message='F2RT injected '||probe.kind,'reached independent late fault: '||probe.kind);
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'caller DML/new period/all business rows rollback: '||probe.kind);
    perform pg_temp.check_true((pg_temp.position_state()->>'last_value')::bigint>(position->>'last_value')::bigint,
      'issued sequence gap retained: '||probe.kind);
    set constraints all immediate;
    set constraints all deferred;
  end loop;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated')::text,true);
  set local role authenticated;
  r:=pg_temp.transfer(f.farm_a,f.transfer_b,f.animal_b,current_date-1,f.destination_reuse,f.meat,f.reactivate_b,'{}');
  reset role;
  insert into pg_temp.receipts values(f.animal_b,r);
  -- Owner-created history is usable by an authorized editor; old actor hashes are not replayed as editor.
  for control in select * from (values(f.animal_a,f.transfer_a,f.reactivate_a,f.destination_new,f.owner_a),
    (f.animal_b,f.transfer_b,f.reactivate_b,f.destination_reuse,f.editor_a)) v(animal,operation,reactivation,group_id,actor) loop
    select result into r from pg_temp.receipts where animal_id=control.animal;
    perform pg_temp.check_true(r=jsonb_build_object('contract_version','group-economics.forward.v3',
      'operation_id',control.operation,'action','transfer','animal_id',control.animal,
      'source_period_id',(select result->'destination_period_id' from pg_temp.reactivations where animal_id=control.animal),
      'destination_period_id',r->'destination_period_id','membership_event_ids',r->'membership_event_ids',
      'effective_on',current_date-1,'event_position',r->'event_position','source_end_position',r->'event_position',
      'destination_start_position',r->'destination_start_position','basis_entry_ids',r->'basis_entry_ids',
      'basis_before',0,'basis_after',0,'source_status','open','destination_status','open',
      'snapshot_id',null,'state_version',3,'replayed',false)
      and jsonb_array_length(r->'membership_event_ids')=2 and jsonb_array_length(r->'basis_entry_ids')=2,
      'exact19 zero transfer receipt with real reactivation source');
    perform pg_temp.check_true((select count(*)=2 and count(distinct b.entry_pair_id)=1
      and bool_and(b.signed_amount=0 and b.account_kind='period' and b.animal_id=control.animal
        and b.entry_pair_id=e.basis_transfer_id and e.action='transfer' and e.animal_id=m.animal_id
        and e.event_position=(r->>'event_position')::bigint and e.period_id=m.period_id
        and b.period_id=e.period_id and e.sale_id is null
        and ((b.entry_kind='transfer_out' and b.period_id=(r->>'source_period_id')::uuid and m.end_position=e.event_position)
          or (b.entry_kind='transfer_in' and b.period_id=(r->>'destination_period_id')::uuid
            and m.start_position=e.event_position and m.end_position is null)))
      from economics_v2.group_acquisition_basis_entries b join economics_v2.group_occupancy_events e on e.id=b.event_id
      join economics_v2.group_occupancy_memberships m on m.id=e.membership_id where b.operation_id=control.operation)
      and (select array_agg(id::text order by id::text) from economics_v2.group_occupancy_events where operation_id=control.operation)
        =(select array_agg(v order by v) from jsonb_array_elements_text(r->'membership_event_ids') v)
      and (select array_agg(id::text order by id::text) from economics_v2.group_acquisition_basis_entries where operation_id=control.operation)
        =(select array_agg(v order by v) from jsonb_array_elements_text(r->'basis_entry_ids') v),'exact zero pair/legs/receipt IDs/boundaries');
    perform pg_temp.check_true(exists(select 1 from economics_v2.group_animal_acquisition_basis b join pg_temp.captures c using(animal_id)
      where b.animal_id=control.animal and to_jsonb(b)=c.full_row||jsonb_build_object('remaining_basis',0,
        'current_period_id',(r->>'destination_period_id')::uuid,'version',3))
      and exists(select 1 from public.animales a join pg_temp.restored_public p on p.id=a.id
        where a.id=control.animal and to_jsonb(a)=p.full_row||jsonb_build_object('grupo_id',control.group_id)),
      'capture300/cost999/timestamp preserved; public only fixture caller destination delta');
    perform set_config('request.jwt.claim.sub',control.actor::text,true);
    prepared:=economics_v2.prepare_group_operation(f.farm_a,control.operation,jsonb_build_object(
      'action','transfer','animal_id',control.animal,'source_period_id',r->'source_period_id',
      'destination_group_id',control.group_id,'destination_purpose_id',f.meat,'sale_id',null,
      'effective_on',current_date-1,'payload',jsonb_build_object('reactivation_operation_id',control.reactivation,
        'metadata',case when control.animal=f.animal_a then '{"probe":1}'::jsonb else '{}'::jsonb end)));
    perform pg_temp.check_true(prepared->'result'=r||'{"replayed":true}'::jsonb
      and exists(select 1 from economics_v2.group_occupancy_operations where operation_id=control.operation
        and result=r and event_position=(r->>'event_position')::bigint and payload_hash=prepared->>'payload_hash'),
      'completed original source/actor/history-bound canonical hash');
  end loop;
  perform pg_temp.check_true((select result->'destination_start_position'=result->'event_position'
    from pg_temp.receipts where animal_id=f.animal_a)
    and (r->>'destination_start_position')::bigint<(r->>'event_position')::bigint
    and r->'destination_period_id'=(select result->'destination_period_id'
      from pg_temp.initial where animal_id=f.destination_seed)
    and exists(select 1 from economics_v2.group_occupancy_periods
      where id=(select (result->>'destination_period_id')::uuid from pg_temp.receipts where animal_id=f.animal_a)
        and group_id=f.destination_new and purpose_id=f.meat and starts_on=current_date-1),
    'new destination boundary and actual reused original destination start');
  perform pg_temp.check_true(not exists(select 1 from pg_temp.historical h where not exists(
    select 1 from economics_v2.group_occupancy_events e join economics_v2.group_occupancy_memberships m on m.id=e.membership_id
    join economics_v2.group_occupancy_periods p on p.id=e.period_id
    where to_jsonb(e)=h.event and to_jsonb(m)=h.membership and to_jsonb(p)=h.period))
    and not exists(select 1 from pg_temp.original_entries o where not exists(
      select 1 from economics_v2.group_acquisition_basis_entries b where to_jsonb(b)=o.full_row)),
    'original exit/member/period/initial signed rows immutable');
  perform pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(f.farm_a,
    (select (result->>'source_period_id')::uuid from pg_temp.exits where animal_id=f.animal_a))
      @> '{"acquisition_cost":600,"active_animal_count":1}'::jsonb
    and economics_v2.calculate_group_period_live_metrics(f.farm_a,(r->>'source_period_id')::uuid)
      @> '{"acquisition_cost":0,"active_animal_count":1}'::jsonb
    and economics_v2.calculate_group_period_live_metrics(f.farm_a,(r->>'destination_period_id')::uuid)
      @> '{"acquisition_cost":0,"active_animal_count":2}'::jsonb
    and economics_v2.calculate_group_period_live_metrics(f.farm_a,
      (select (result->>'destination_period_id')::uuid from pg_temp.receipts where animal_id=f.animal_a))
      @> '{"acquisition_cost":0,"active_animal_count":2}'::jsonb,'realized600 stays historical; both new/reused destinations acquire0');
  select * into proc from pg_proc where oid=
    'economics_v2.transfer_reactivated_group_meat_nonclosing(uuid,uuid,uuid,date,uuid,uuid,uuid,jsonb)'::regprocedure;
  perform pg_temp.check_true(proc.prorettype='jsonb'::regtype and not proc.prosecdef
    and proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(proc.proacl,acldefault('f',proc.proowner))) acl
      where acl.grantee=0 and acl.privilege_type='EXECUTE')
    and not has_function_privilege('anon',proc.oid,'EXECUTE')
    and not has_function_privilege('authenticated',proc.oid,'EXECUTE'),'private invoker/empty path/no PUBLIC or client execute');
  set constraints all immediate;
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_memberships m
    join economics_v2.group_occupancy_periods p on p.id=m.period_id
    where m.granja_id=f.farm_a and not(m.position_span<@p.position_span)),'forced deferred containment');
  perform pg_temp.check_true((select count(*)=12 from economics_v2.group_occupancy_operations where granja_id=f.farm_a)
    and (select count(*)=10 and sum(signed_amount)=600 from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a)
    and not exists(select 1 from economics_v2.group_meat_snapshots where granja_id=f.farm_a)
    and not exists(select 1 from public.bajas_animales where granja_id=f.farm_a)
    and not exists(select 1 from public.venta_animal where granja_id=f.farm_a)
    and not exists(select 1 from economics_v2.group_occupancy_periods where granja_id=f.farm_a and end_position is not null),
    'exact operations/entries; failed operation absent; no closure/snapshot/sale/baja');
end;
$proof$;

select jsonb_build_object('result','group_economics_forward_reactivated_transfer_pass',
  'assertion_count',(select count(*) from assertions),'locking_evidence','sequential_only',
  'production_gateway_integrated',false,'out_return_compatibility_proven',false,
  'fixture_ids',(select to_jsonb(ids) from ids)) as evidence;
rollback;
