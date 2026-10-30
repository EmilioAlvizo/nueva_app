begin;

-- HUMAN sandbox Dashboard: save/run this FULL BEGIN/ROLLBACK file, never selected fragments.
-- Expected first RED: genuine 42883 at the exact ten-argument NEW RETURN call below.
-- Full-unit reforecast after qualified validator: fixture <=500 + future migration <=260 = <=760.
-- Real original300 each -> ordinary exit -> reactivation -> ONE transfer -> OUT -> FIRST RETURN.
-- New/reused meat destinations; realized historical600 stays put, holding and returned basis stay0.
-- All earlier shared-period phases complete before later dates; no invented history/basis/operation rows.
-- Core request is purpose_change/sourceNULL with server-derived payload {reactivation_operation_id,
-- transfer_operation_id,out_operation_id,metadata}; actual CURRENT actor binds the F2A hash.
-- Core prepares original replay BEFORE holding checks, validates immutable history with FALSE for
-- replay, then reconstructs original receipt/rows without consulting current pointers or chronology.
-- Fresh core owns complete mutable locks, TRUE reread after caller DML, destination pin/type/date
-- checks and zero holding-out/period-in writes. Context is not supplied to or accepted by the core.
-- No direct OUT, repeated valid movement/reactivation/RETURN, closure, concurrency or public gateway.
-- Prior runtime qualification is not independent approval; review remains pending.
create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,gen_random_uuid() type_wrong,gen_random_uuid() type_b,
  gen_random_uuid() meat,gen_random_uuid() other_meat,gen_random_uuid() eggs,gen_random_uuid() foreign_purpose,
  gen_random_uuid() historical_group,gen_random_uuid() reactivated_group,gen_random_uuid() transferred_group,
  gen_random_uuid() destination_new,gen_random_uuid() destination_reuse,gen_random_uuid() destination_fault,
  gen_random_uuid() wrong_group,gen_random_uuid() foreign_group,gen_random_uuid() animal_a,gen_random_uuid() animal_b,
  gen_random_uuid() historical_anchor,gen_random_uuid() reactivated_anchor,gen_random_uuid() transferred_anchor,
  gen_random_uuid() destination_seed,gen_random_uuid() later_seed,
  gen_random_uuid() exit_a,gen_random_uuid() exit_b,gen_random_uuid() reactivate_a,gen_random_uuid() reactivate_b,
  gen_random_uuid() transfer_a,gen_random_uuid() transfer_b,gen_random_uuid() out_a,gen_random_uuid() out_b,
  gen_random_uuid() return_a,gen_random_uuid() return_b,gen_random_uuid() return_fault;
create temp table assertions(label text not null);
create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
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
declare t record; rows jsonb; result jsonb:='{}'; farms uuid[]; actors uuid[];
begin
  select array[farm_a,farm_b],array[owner_a,owner_b,editor_a,viewer_a] into farms,actors from pg_temp.ids;
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
  if current_setting('f2rr.no_write',true)='on' then
    raise exception using errcode='P0001',message='F2RR unexpected business DML';
  end if;
  return null;
end;
$$;
do $blockers$
declare t record;
begin
  for t in select * from pg_temp.watched_tables loop
    execute format('create trigger f2rr_no_write before insert or update or delete on %I.%I
      for each statement execute function pg_temp.no_write()',t.schema_name,t.table_name);
  end loop;
end;
$blockers$;
create function pg_temp.checked(p_sql text,p_state text default null,
  p_code text default null,p_field text default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare baseline jsonb; before_seq jsonb; result jsonb; state text; detail text;
begin
  baseline:=pg_temp.business_state();
  before_seq:=pg_temp.position_state();
  perform set_config('f2rr.no_write','on',true);
  begin
    execute p_sql into result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics state=returned_sqlstate,detail=pg_exception_detail;
  end;
  perform set_config('f2rr.no_write','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'all rows unchanged: '||p_sql);
  perform pg_temp.check_true(pg_temp.position_state()=before_seq,'sequence unchanged: '||p_sql);
  if p_state is null then
    perform pg_temp.check_true(result is not null,'nonempty replay');
  else
    perform pg_temp.check_true(state=p_state,'expected SQLSTATE '||p_state||': '||p_sql);
    if p_code is not null then
      perform pg_temp.check_true(detail::jsonb @> jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field) and detail::jsonb ? 'entity_id','typed refusal: '||p_sql);
    end if;
  end if;
  return result;
end;
$$;

-- Fixture-only orchestration of already qualified cores. The NEW RETURN remains absent.
create function pg_temp.prepare_history(p_animal uuid,p_exit uuid,p_reactivation uuid,p_transfer uuid,p_out uuid,p_phase integer)
returns jsonb language plpgsql security definer set search_path='' as $$
declare f record; source uuid; context jsonb; prepared jsonb; exited jsonb; activated jsonb; actor uuid;
  payload jsonb:='{"provenance_version":"group-disposition-provenance.v1","disposition_kind":"ordinary_exit","metadata":{}}';
begin
  select * into f from pg_temp.ids;
  actor:=economics_v2.assert_group_writer_actor(f.farm_a);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||f.farm_a::text,0));
  if p_phase=0 then
    select period_id into source from economics_v2.group_occupancy_memberships
      where granja_id=f.farm_a and animal_id=p_animal and end_position is null;
    prepared:=economics_v2.prepare_group_operation(f.farm_a,p_exit,jsonb_build_object(
      'action','exit','animal_id',p_animal,'source_period_id',source,'destination_group_id',null,
      'destination_purpose_id',null,'sale_id',null,'effective_on',current_date-5,'payload',payload));
    context:=economics_v2.validate_group_meat_nonclosing_source(f.farm_a,p_animal,current_date-5);
    update public.animales set activo=false where granja_id=f.farm_a and id=p_animal and activo and baja_id is null;
    if not found then raise exception 'F2RR exit caller failed'; end if;
    exited:=economics_v2.exit_group_meat_nonclosing(f.farm_a,p_exit,p_animal,current_date-5,payload);
    prepared:=economics_v2.prepare_group_operation(f.farm_a,p_reactivation,jsonb_build_object(
      'action','reactivate','animal_id',p_animal,'source_period_id',null,'destination_group_id',f.reactivated_group,
      'destination_purpose_id',f.meat,'sale_id',null,'effective_on',current_date-4,
      'payload',jsonb_build_object('provenance_version','group-reactivation-provenance.v1',
        'disposition_kind','ordinary_reactivation','disposed_event_id',exited->'membership_event_ids'->0,'actor_id',actor,'metadata','{}'::jsonb)));
    context:=economics_v2.validate_disposed_group_meat_reactivation_source(f.farm_a,p_animal,
      (exited->'membership_event_ids'->>0)::uuid,current_date-4,f.reactivated_group,f.meat,false);
    update public.animales set activo=true,grupo_id=f.reactivated_group where granja_id=f.farm_a and id=p_animal and not activo;
    if not found then raise exception 'F2RR restore caller failed'; end if;
    return economics_v2.reactivate_disposed_group_meat(f.farm_a,p_reactivation,p_animal,
      current_date-4,f.reactivated_group,f.meat,(exited->'membership_event_ids'->>0)::uuid,'{}');
  elsif p_phase=1 then
    select result into activated from economics_v2.group_occupancy_operations
      where granja_id=f.farm_a and operation_id=p_reactivation;
    select id into source from economics_v2.group_occupancy_periods where granja_id=f.farm_a
      and group_id=f.transferred_group and purpose_id=f.meat and end_position is null;
    context:=economics_v2.lock_group_writer_scope(f.farm_a,array[f.reactivated_group,f.transferred_group],array[p_animal],
      array[(activated->>'destination_period_id')::uuid]||case when source is null then '{}'::uuid[] else array[source] end,current_date-3);
    update public.animales set grupo_id=f.transferred_group where granja_id=f.farm_a and id=p_animal and activo;
    if not found then raise exception 'F2RR transfer caller failed'; end if;
    return economics_v2.transfer_reactivated_group_meat_nonclosing(
      f.farm_a,p_transfer,p_animal,current_date-3,f.transferred_group,f.meat,p_reactivation,'{}');
  elsif p_phase=2 then
    select period_id into source from economics_v2.group_occupancy_memberships
      where granja_id=f.farm_a and animal_id=p_animal and end_position is null;
    context:=economics_v2.lock_group_writer_scope(f.farm_a,array[f.transferred_group],array[p_animal],array[source],current_date-2);
    update public.animales set proposito_id=f.eggs where granja_id=f.farm_a and id=p_animal and activo;
    if not found then raise exception 'F2RR OUT caller failed'; end if;
    return economics_v2.move_transferred_reactivated_meat_to_holding_nonclosing(
      f.farm_a,p_out,p_animal,current_date-2,f.transferred_group,f.eggs,p_reactivation,p_transfer,'{}');
  end if;
  raise exception 'F2RR invalid setup phase';
end;
$$;
create function pg_temp.holding_return(p_farm uuid,p_op uuid,p_animal uuid,p_date date,p_group uuid,p_purpose uuid,
  p_reactivation uuid,p_transfer uuid,p_out uuid,p_metadata jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare context jsonb; prepared jsonb; destination uuid;
begin
  perform economics_v2.assert_group_writer_actor(p_farm);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_farm::text,0));
  if not exists(select 1 from economics_v2.group_occupancy_operations where granja_id=p_farm and operation_id=p_op) then
    prepared:=economics_v2.prepare_group_operation(p_farm,p_op,jsonb_build_object(
      'action','purpose_change','animal_id',p_animal,'source_period_id',null,'destination_group_id',p_group,
      'destination_purpose_id',p_purpose,'sale_id',null,'effective_on',p_date,
      'payload',jsonb_build_object('reactivation_operation_id',p_reactivation,'transfer_operation_id',p_transfer,
        'out_operation_id',p_out,'metadata',p_metadata)));
    context:=economics_v2.validate_reactivated_holding_history(p_farm,p_animal,p_reactivation,p_transfer,p_out,p_date,true);
    select id into destination from economics_v2.group_occupancy_periods
      where granja_id=p_farm and group_id=p_group and purpose_id=p_purpose and end_position is null;
    perform economics_v2.lock_group_writer_scope(p_farm,
      array[(context->'public_animal'->>'grupo_id')::uuid,p_group],array[p_animal],
      case when destination is null then '{}'::uuid[] else array[destination] end,p_date);
    update public.animales set grupo_id=p_group,proposito_id=p_purpose
      where granja_id=p_farm and id=p_animal and activo and baja_id is null;
    if not found then raise exception 'F2RR RETURN caller failed'; end if;
  end if;
  -- FIRST intended NEW core call: ten exact SQL types, unhandled missing-function RED.
  return economics_v2.return_reactivated_holding_to_group_meat(
    p_farm,p_op,p_animal,p_date,p_group,p_purpose,p_reactivation,p_transfer,p_out,p_metadata);
end;
$$;

select pg_temp.check_true(not exists(select 1 from auth.users
  where raw_user_meta_data->>'fixture'='reactivated-holding-return'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"reactivated-holding-return"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F2RR farm A',owner_a from ids union all select farm_b,owner_b,'F2RR farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F2RR type A',owner_a from ids union all select type_wrong,farm_a,'F2RR wrong type',owner_a from ids
union all select type_b,farm_b,'F2RR type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat,farm_a,'F2RR meat','carne',owner_a from ids union all select other_meat,farm_a,'F2RR other meat','carne',owner_a from ids
union all select eggs,farm_a,'F2RR eggs','postura',owner_a from ids union all select foreign_purpose,farm_b,'F2RR foreign meat','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'F2RR group '||g::text,owner_a from ids
cross join lateral unnest(array[historical_group,reactivated_group,transferred_group,destination_new,destination_reuse,destination_fault]) g
union all select wrong_group,farm_a,type_wrong,'F2RR wrong group',owner_a from ids
union all select foreign_group,farm_b,type_b,'F2RR foreign group',owner_b from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,notas,created_by)
select a,farm_a,type_a,case when a=reactivated_anchor then reactivated_group when a=transferred_anchor then transferred_group
  when a=destination_seed then destination_reuse when a=later_seed then destination_new else historical_group end,
  case when a=later_seed then other_meat else meat end,current_date-8,
  case when a in(animal_a,animal_b) then 300 else 0 end,'F2RR animal',owner_a
from ids cross join lateral unnest(array[animal_a,animal_b,historical_anchor,reactivated_anchor,transferred_anchor,destination_seed,later_seed]) a;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
create temp table initial as select a animal_id,economics_v2.enter_group_meat_initial(farm_a,gen_random_uuid(),a,current_date-7,
  case when a=reactivated_anchor then reactivated_group when a=transferred_anchor then transferred_group
    when a=destination_seed then destination_reuse else historical_group end,meat,'{}') result
from ids cross join lateral unnest(array[animal_a,animal_b,historical_anchor,reactivated_anchor,transferred_anchor,destination_seed]) a;
create temp table captures as select animal_id,to_jsonb(b) full_row
from economics_v2.group_animal_acquisition_basis b where granja_id=(select farm_a from ids);
update public.animales set costo_adquisicion=999 where id in(select animal_a from ids union all select animal_b from ids);
create temp table setup_receipts(phase integer,animal_id uuid,result jsonb);
do $setup$
declare f record; phase integer; a record;
begin
  select * into f from pg_temp.ids;
  for phase in 0..2 loop
    for a in select * from (values(f.animal_a,f.exit_a,f.reactivate_a,f.transfer_a,f.out_a),
      (f.animal_b,f.exit_b,f.reactivate_b,f.transfer_b,f.out_b)) v(animal,exit_op,reactivation,transfer,out_op) loop
      insert into pg_temp.setup_receipts values(phase,a.animal,
        pg_temp.prepare_history(a.animal,a.exit_op,a.reactivation,a.transfer,a.out_op,phase));
    end loop;
  end loop;
end;
$setup$;
create temp table historical_rows as select 'events' kind,to_jsonb(e) full_row from economics_v2.group_occupancy_events e where granja_id=(select farm_a from ids)
union all select 'entries',to_jsonb(b) from economics_v2.group_acquisition_basis_entries b where granja_id=(select farm_a from ids)
union all select 'members',to_jsonb(m) from economics_v2.group_occupancy_memberships m where granja_id=(select farm_a from ids)
union all select 'periods',to_jsonb(p) from economics_v2.group_occupancy_periods p where granja_id=(select farm_a from ids);
create temp table public_before as select id,to_jsonb(a) full_row from public.animales a where granja_id=(select farm_a from ids);
set constraints all immediate;
set constraints all deferred;
select pg_temp.check_true((select count(*)=2 and bool_and(initial_basis=300 and source_cost=300 and remaining_basis=0
  and current_account_kind='holding' and current_period_id is null and status='active' and disposed_event_id is null and version=4)
  from economics_v2.group_animal_acquisition_basis where animal_id in(select animal_a from ids union all select animal_b from ids)),
  'REAL original300 full qualified chain produced holding0 before first RETURN');
do $grants$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$grants$;
grant execute on function pg_temp.holding_return(uuid,uuid,uuid,date,uuid,uuid,uuid,uuid,uuid,jsonb),
  pg_temp.checked(text,text,text,text),pg_temp.check_true(boolean,text),pg_temp.business_state(),pg_temp.position_state() to authenticated,anon;
create temp table receipts(animal_id uuid,result jsonb);
do $first$
declare f record; r jsonb;
begin
  select * into f from pg_temp.ids;
  set local role authenticated;
  r:=pg_temp.holding_return(f.farm_a,f.return_a,f.animal_a,current_date-1,
    f.destination_new,f.other_meat,f.reactivate_a,f.transfer_a,f.out_a,'{"probe":1.00}'::jsonb);
  reset role;
  insert into pg_temp.receipts values(f.animal_a,r);
end;
$first$;

create function pg_temp.late_fault()
returns trigger language plpgsql set search_path='' as $$
begin
  if tg_table_name='group_acquisition_basis_entries' then
    if current_setting('f2rr.fault',true)='second_leg' and new.entry_kind='purpose_in' and new.account_kind='period' then
      raise exception using errcode='P0001',message='F2RR injected second_leg';
    end if;
  elsif current_setting('f2rr.fault',true)='completion' and new.result->>'action'='purpose_change' then
    perform pg_temp.check_true((select count(*)=2 and bool_and(signed_amount=0)
      from economics_v2.group_acquisition_basis_entries where granja_id=new.granja_id and operation_id=new.operation_id)
      and exists(select 1 from economics_v2.group_animal_acquisition_basis where granja_id=new.granja_id
        and animal_id=(new.result->>'animal_id')::uuid and current_account_kind='period'
        and current_period_id=(new.result->>'destination_period_id')::uuid and remaining_basis=0 and version=5)
      and exists(select 1 from economics_v2.group_occupancy_memberships where granja_id=new.granja_id
        and animal_id=(new.result->>'animal_id')::uuid and start_position=new.event_position and end_position is null),
      'completion LAST after new destination/member/event/zero pair/basis pointer update');
    raise exception using errcode='P0001',message='F2RR injected completion';
  end if;
  return new;
end;
$$;
create trigger f2rr_late_leg before insert on economics_v2.group_acquisition_basis_entries for each row execute function pg_temp.late_fault();
create trigger f2rr_late_completion before update on economics_v2.group_occupancy_operations for each row execute function pg_temp.late_fault();
do $proof$
declare f record; r jsonb; repeated jsonb; sql text; baseline jsonb; before_seq jsonb; context jsonb;
  probe record; actor record; control record; proc record; state text; message text; prepared jsonb;
begin
  select * into f from pg_temp.ids;
  select result into r from pg_temp.receipts where animal_id=f.animal_a;
  sql:=format('select pg_temp.holding_return(%L,%L,%L,current_date-1,%L,%L,%L,%L,%L,''{"probe":1}''::jsonb)',
    f.farm_a,f.return_a,f.animal_a,f.destination_new,f.other_meat,f.reactivate_a,f.transfer_a,f.out_a);
  repeated:=pg_temp.checked(sql);
  perform pg_temp.check_true(repeated=r||'{"replayed":true}'::jsonb,'canonical replay after holding ended, original sourceNULL');
  for probe in select * from (values
    (f.destination_new,f.other_meat,f.reactivate_a,f.transfer_a,f.out_a,current_date-1,'{"probe":2}'::jsonb),
    (f.destination_reuse,f.other_meat,f.reactivate_a,f.transfer_a,f.out_a,current_date-1,'{"probe":1}'::jsonb),
    (f.destination_new,f.meat,f.reactivate_a,f.transfer_a,f.out_a,current_date-1,'{"probe":1}'::jsonb),
    (f.destination_new,f.other_meat,f.reactivate_b,f.transfer_a,f.out_a,current_date-1,'{"probe":1}'::jsonb),
    (f.destination_new,f.other_meat,f.reactivate_a,f.transfer_b,f.out_a,current_date-1,'{"probe":1}'::jsonb),
    (f.destination_new,f.other_meat,f.reactivate_a,f.transfer_a,f.out_b,current_date-1,'{"probe":1}'::jsonb),
    (f.destination_new,f.other_meat,f.reactivate_a,f.transfer_a,f.out_a,current_date,'{"probe":1}'::jsonb))
    v(group_id,purpose,reactivation,transfer,out_op,effective_on,metadata) loop
    perform pg_temp.checked(format('select pg_temp.holding_return(%L,%L,%L,%L::date,%L,%L,%L,%L,%L,%L::jsonb)',
      f.farm_a,f.return_a,f.animal_a,probe.effective_on,probe.group_id,probe.purpose,probe.reactivation,probe.transfer,probe.out_op,probe.metadata),
      '22023','operation_payload_conflict','operation_id');
  end loop;
  -- Qualified FALSE remains reusable after RETURN; TRUE correctly refuses current non-holding state.
  context:=economics_v2.validate_reactivated_holding_history(f.farm_a,f.animal_a,f.reactivate_a,f.transfer_a,f.out_a,current_date-1,false);
  perform pg_temp.check_true(context->'out_result'=(select result from pg_temp.setup_receipts where phase=2 and animal_id=f.animal_a),
    'FALSE validates original OUT without old-actor replay or mutable holding assumption');
  perform pg_temp.checked(format('select economics_v2.validate_reactivated_holding_history(%L,%L,%L,%L,%L,current_date,true)',
    f.farm_a,f.animal_a,f.reactivate_a,f.transfer_a,f.out_a),'23514','invariant_violation','animal_id');
  perform economics_v2.enter_group_meat_initial(f.farm_a,gen_random_uuid(),f.later_seed,current_date,f.destination_new,f.other_meat,'{}');
  repeated:=pg_temp.checked(sql);
  perform pg_temp.check_true(repeated=r||'{"replayed":true}'::jsonb,'replay precedes later REAL destination chronology');
  for actor in select * from (values(f.editor_a,'authenticated'),(f.viewer_a,'authenticated'),(null::uuid,'anon')) v(id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    if actor.id=f.editor_a then
      perform pg_temp.checked(sql,'22023','operation_payload_conflict','operation_id');
    else
      perform pg_temp.checked(sql,'42501','forbidden','granja_id');
    end if;
    perform pg_temp.checked('select economics_v2.return_reactivated_holding_to_group_meat(
      null::uuid,null::uuid,null::uuid,null::date,null::uuid,null::uuid,null::uuid,null::uuid,null::uuid,null::jsonb)','42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  perform pg_temp.checked(format('select economics_v2.return_reactivated_holding_to_group_meat(
    %L,%L,%L,current_date,%L,%L,%L,%L,%L,''{}''::jsonb)',f.farm_a,gen_random_uuid(),f.animal_a,
    f.destination_new,f.other_meat,f.reactivate_a,f.transfer_a,f.out_a),'23514','invariant_violation','animal_id');
  for probe in select * from (values(null::jsonb),('[]'::jsonb)) v(metadata) loop
    perform pg_temp.checked(format('select economics_v2.return_reactivated_holding_to_group_meat(
      %L,%L,%L,current_date,%L,%L,%L,%L,%L,%L::jsonb)',f.farm_a,gen_random_uuid(),f.animal_b,
      f.destination_reuse,f.meat,f.reactivate_b,f.transfer_b,f.out_b,probe.metadata),'22023','invalid_request','payload');
  end loop;
  -- Direct calls prove core-owned history/public guards independently of fixture caller preparation.
  for probe in select * from (values
    (f.farm_b,f.animal_b,f.transferred_group,f.meat,f.reactivate_b,f.transfer_b,f.out_b,'42501','forbidden','granja_id'),
    (f.farm_a,f.animal_b,f.transferred_group,f.meat,f.reactivate_a,f.transfer_b,f.out_b,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_b,f.transferred_group,f.meat,f.reactivate_b,f.transfer_a,f.out_b,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_b,f.transferred_group,f.meat,f.reactivate_b,f.transfer_b,f.out_a,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_b,f.transferred_group,f.meat,null::uuid,f.transfer_b,f.out_b,'22023','invalid_request','reactivation_operation_id'),
    (f.farm_a,f.animal_b,f.transferred_group,f.meat,f.reactivate_b,null::uuid,f.out_b,'22023','invalid_request','transfer_operation_id'),
    (f.farm_a,f.animal_b,f.transferred_group,f.meat,f.reactivate_b,f.transfer_b,null::uuid,'22023','invalid_request','out_operation_id'),
    (f.farm_a,f.animal_b,f.transferred_group,f.meat,f.reactivate_b,f.transfer_b,f.out_b,'42501','forbidden','purpose_id'),
    (f.farm_a,f.animal_b,f.destination_reuse,f.meat,f.reactivate_b,f.transfer_b,f.out_b,'42501','forbidden','group_id'))
    v(farm,animal,group_id,purpose,reactivation,transfer,out_op,state,code,field) loop
    perform pg_temp.checked(format('select economics_v2.return_reactivated_holding_to_group_meat(
      %L,%L,%L,current_date,%L,%L,%L,%L,%L,''{}''::jsonb)',probe.farm,gen_random_uuid(),probe.animal,
      probe.group_id,probe.purpose,probe.reactivation,probe.transfer,probe.out_op),probe.state,probe.code,probe.field);
  end loop;
  for probe in select * from (values(f.foreign_group,f.meat,current_date,'42501','forbidden','group_id'),
    (f.wrong_group,f.meat,current_date,'23514','invariant_violation','group_id'),
    (f.destination_reuse,f.eggs,current_date,'22023','invalid_request','purpose_id'),
    (f.destination_reuse,f.meat,current_date-3,'22023','invalid_request','effective_on'),
    (f.destination_reuse,f.meat,current_date+1,'22023','invalid_request','effective_on')) v(group_id,purpose,effective_on,state,code,field) loop
    baseline:=pg_temp.business_state();
    before_seq:=pg_temp.position_state();
    begin
      perform pg_temp.holding_return(f.farm_a,gen_random_uuid(),f.animal_b,probe.effective_on,
        probe.group_id,probe.purpose,f.reactivate_b,f.transfer_b,f.out_b,'{}');
      raise exception 'F2RR expected caller refusal';
    exception when others then
      get stacked diagnostics state=returned_sqlstate,message=pg_exception_detail;
      perform pg_temp.check_true(state=probe.state and message::jsonb @> jsonb_build_object(
        'code',probe.code,'field',probe.field),'typed destination/date refusal');
    end;
    perform pg_temp.check_true(pg_temp.business_state()=baseline and pg_temp.position_state()=before_seq,
      'caller stage/scope/date refusal fully rolls back with no sequence issuance');
  end loop;
  for probe in select * from (values('second_leg'),('completion')) v(kind) loop
    baseline:=pg_temp.business_state();
    before_seq:=pg_temp.position_state();
    state:=null;
    message:=null;
    perform set_config('f2rr.fault',probe.kind,true);
    begin
      perform pg_temp.holding_return(f.farm_a,f.return_fault,f.animal_b,current_date,
        f.destination_fault,f.other_meat,f.reactivate_b,f.transfer_b,f.out_b,'{}');
    exception when others then
      get stacked diagnostics state=returned_sqlstate,message=message_text;
    end;
    perform set_config('f2rr.fault','off',true);
    perform pg_temp.check_true(state='P0001' and message='F2RR injected '||probe.kind,'reached independent late fault: '||probe.kind);
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'caller pins/new period/member/event/pair/basis/ledger rollback: '||probe.kind);
    perform pg_temp.check_true((pg_temp.position_state()->>'last_value')::bigint>(before_seq->>'last_value')::bigint,'issued sequence gap retained');
    set constraints all immediate;
    set constraints all deferred;
  end loop;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated')::text,true);
  set local role authenticated;
  r:=pg_temp.holding_return(f.farm_a,f.return_b,f.animal_b,current_date-1,
    f.destination_reuse,f.meat,f.reactivate_b,f.transfer_b,f.out_b,'{}');
  reset role;
  insert into pg_temp.receipts values(f.animal_b,r);
  -- Both controls are REAL original300, not original0-only compatibility surrogates.
  for control in select * from (values(f.animal_a,f.return_a,f.reactivate_a,f.transfer_a,f.out_a,f.destination_new,f.other_meat,f.owner_a),
    (f.animal_b,f.return_b,f.reactivate_b,f.transfer_b,f.out_b,f.destination_reuse,f.meat,f.editor_a))
    v(animal,operation,reactivation,transfer,out_op,group_id,purpose,actor) loop
    select result into r from pg_temp.receipts where animal_id=control.animal;
    perform pg_temp.check_true(r=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',control.operation,
      'action','purpose_change','animal_id',control.animal,'source_period_id',null,'destination_period_id',r->'destination_period_id',
      'membership_event_ids',r->'membership_event_ids','effective_on',current_date-1,'event_position',r->'event_position',
      'source_end_position',null,'destination_start_position',r->'destination_start_position','basis_entry_ids',r->'basis_entry_ids',
      'basis_before',0,'basis_after',0,'source_status',null,'destination_status','open','snapshot_id',null,'state_version',5,'replayed',false)
      and jsonb_array_length(r->'membership_event_ids')=1 and jsonb_array_length(r->'basis_entry_ids')=2,'exact19 zero RETURN/sourceNULL receipt');
    perform pg_temp.check_true((select count(*)=2 and count(distinct b.entry_pair_id)=1
      and bool_and(b.signed_amount=0 and b.animal_id=control.animal and e.operation_id=control.operation
        and b.entry_pair_id=e.basis_transfer_id and e.action='purpose_change' and e.animal_id=m.animal_id
        and e.period_id=m.period_id and m.start_position=e.event_position and m.end_position is null and e.sale_id is null
        and e.event_position=(r->>'event_position')::bigint and e.period_id=(r->>'destination_period_id')::uuid
        and ((b.entry_kind='purpose_out' and b.account_kind='holding' and b.period_id is null)
          or (b.entry_kind='purpose_in' and b.account_kind='period' and b.period_id=e.period_id)))
      from economics_v2.group_acquisition_basis_entries b join economics_v2.group_occupancy_events e on e.id=b.event_id
      join economics_v2.group_occupancy_memberships m on m.id=e.membership_id where b.operation_id=control.operation)
      and (select array_agg(id::text order by id::text) from economics_v2.group_acquisition_basis_entries where operation_id=control.operation)
        =(select array_agg(v order by v) from jsonb_array_elements_text(r->'basis_entry_ids') v)
      and exists(select 1 from economics_v2.group_occupancy_events e where e.id=(r->'membership_event_ids'->>0)::uuid
        and e.operation_id=control.operation and e.event_position>(select (result->>'event_position')::bigint
          from pg_temp.setup_receipts where phase=2 and animal_id=control.animal)),
      'real new membership after holding gap/exact one event/zero holding-out and period-in pair/IDs');
    perform pg_temp.check_true(exists(select 1 from economics_v2.group_occupancy_periods where id=(r->>'destination_period_id')::uuid
      and granja_id=f.farm_a and group_id=control.group_id and purpose_id=control.purpose and end_position is null)
      and exists(select 1 from economics_v2.group_animal_acquisition_basis b join pg_temp.captures c using(animal_id)
        where b.animal_id=control.animal and to_jsonb(b)=c.full_row||jsonb_build_object('remaining_basis',0,
          'current_period_id',(r->>'destination_period_id')::uuid,'version',5))
      and exists(select 1 from public.animales a join pg_temp.public_before p on p.id=a.id where a.id=control.animal
        and to_jsonb(a)=p.full_row||jsonb_build_object('grupo_id',control.group_id,'proposito_id',control.purpose)),
      'purpose-pinned open destination; exact capture preservation and caller-only public pins with cost999');
    perform set_config('request.jwt.claim.sub',control.actor::text,true);
    prepared:=economics_v2.prepare_group_operation(f.farm_a,control.operation,jsonb_build_object(
      'action','purpose_change','animal_id',control.animal,'source_period_id',null,'destination_group_id',control.group_id,
      'destination_purpose_id',control.purpose,'sale_id',null,'effective_on',current_date-1,
      'payload',jsonb_build_object('reactivation_operation_id',control.reactivation,'transfer_operation_id',control.transfer,
        'out_operation_id',control.out_op,'metadata',case when control.animal=f.animal_a then '{"probe":1}'::jsonb else '{}'::jsonb end)));
    perform pg_temp.check_true(prepared->'result'=r||'{"replayed":true}'::jsonb
      and exists(select 1 from economics_v2.group_occupancy_operations where operation_id=control.operation and result=r
        and event_position=(r->>'event_position')::bigint and payload_hash=prepared->>'payload_hash'),'completed current actor/sourceNULL/three history IDs hash');
  end loop;
  perform pg_temp.check_true((select result->'destination_start_position'=result->'event_position' from pg_temp.receipts where animal_id=f.animal_a)
    and (r->>'destination_start_position')::bigint<(r->>'event_position')::bigint
    and r->'destination_period_id'=(select result->'destination_period_id' from pg_temp.initial where animal_id=f.destination_seed),
    'new start at RETURN boundary; reused destination preserves original start');
  perform pg_temp.check_true(not exists(select 1 from pg_temp.historical_rows h where not exists(
    select 1 from economics_v2.group_occupancy_events e where h.kind='events' and to_jsonb(e)=h.full_row
    union all select 1 from economics_v2.group_acquisition_basis_entries b where h.kind='entries' and to_jsonb(b)=h.full_row
    union all select 1 from economics_v2.group_occupancy_memberships m where h.kind='members' and to_jsonb(m)=h.full_row
    union all select 1 from economics_v2.group_occupancy_periods p where h.kind='periods' and to_jsonb(p)=h.full_row)),
    'all prior initial/exit/reactivation/transfer/OUT events/members/entries/periods immutable');
  perform pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(f.farm_a,
    (select (result->>'destination_period_id')::uuid from pg_temp.initial where animal_id=f.animal_a)) @> '{"acquisition_cost":600,"active_animal_count":1}'::jsonb
    and economics_v2.calculate_group_period_live_metrics(f.farm_a,(r->>'destination_period_id')::uuid) @> '{"acquisition_cost":0,"active_animal_count":2}'::jsonb
    and economics_v2.calculate_group_period_live_metrics(f.farm_a,
      (select (result->>'destination_period_id')::uuid from pg_temp.receipts where animal_id=f.animal_a)) @> '{"acquisition_cost":0,"active_animal_count":2}'::jsonb
    and (select coalesce(sum(signed_amount),0)=0 from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a and account_kind='holding'),
    'historical realized600 retained; new/reused destination0 and holding0, no acquisition recapture');
  select * into proc from pg_proc where oid=
    'economics_v2.return_reactivated_holding_to_group_meat(uuid,uuid,uuid,date,uuid,uuid,uuid,uuid,uuid,jsonb)'::regprocedure;
  perform pg_temp.check_true(proc.prorettype='jsonb'::regtype and not proc.prosecdef and proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(proc.proacl,acldefault('f',proc.proowner))) acl where acl.grantee=0 and acl.privilege_type='EXECUTE')
    and not has_function_privilege('anon',proc.oid,'EXECUTE') and not has_function_privilege('authenticated',proc.oid,'EXECUTE'),'private invoker/empty path/no client EXECUTE');
  set constraints all immediate;
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_memberships m join economics_v2.group_occupancy_periods p on p.id=m.period_id
    where m.granja_id=f.farm_a and not(m.position_span<@p.position_span)),'forced deferred containment of old and new memberships');
  perform pg_temp.check_true((select count(*)=17 from economics_v2.group_occupancy_operations where granja_id=f.farm_a)
    and (select count(*)=19 and sum(signed_amount)=600 from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a)
    and not exists(select 1 from economics_v2.group_meat_snapshots where granja_id=f.farm_a)
    and not exists(select 1 from public.bajas_animales where granja_id=f.farm_a)
    and not exists(select 1 from public.venta_animal where granja_id=f.farm_a),'exact operations/entries; failed RETURN absent; no closure/sale/baja');
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_reactivated_holding_return_pass',
  'assertion_count',(select count(*) from assertions),'locking_evidence','sequential_only','production_gateway_integrated',false,
  'repeated_movement_compatibility_proven',false,'independent_review','pending','fixture_ids',(select to_jsonb(ids) from ids)) as evidence;
rollback;
