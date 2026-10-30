begin;

-- HUMAN sandbox Dashboard: save and run this FULL BEGIN/ROLLBACK file, never fragments.
-- Expected first RED: 42883 at the exact nine-argument NEW private OUT call below.
-- Complete-unit forecast: fixture <=425 + future migration <=365 = <=790 lines.
-- Scope: real initial300 -> ordinary exit -> reactivation -> ONE qualified transfer -> OUT.
-- No direct-after-reactivation OUT, repeated transfer/reactivation, RETURN or full round trip.
-- Qualified prerequisite runtime evidence is not independent review approval; review remains pending.
-- Caller functions and transactional triggers are fixture-only, never public RPCs or RLS changes.
-- Historical cost stays realized; zero period/holding legs retain identities for a future RETURN.
-- Sequential evidence only; rollback retains issued sequence gaps, which must never be rewound.
create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,gen_random_uuid() type_b,
  gen_random_uuid() meat,gen_random_uuid() eggs,gen_random_uuid() ornamental,gen_random_uuid() foreign_purpose,
  gen_random_uuid() historical_group,gen_random_uuid() reactivated_group,gen_random_uuid() transferred_group,
  gen_random_uuid() foreign_group,gen_random_uuid() animal_a,gen_random_uuid() animal_b,
  gen_random_uuid() historical_anchor,gen_random_uuid() reactivated_anchor,gen_random_uuid() later_anchor,
  gen_random_uuid() exit_a,gen_random_uuid() exit_b,gen_random_uuid() reactivate_a,gen_random_uuid() reactivate_b,
  gen_random_uuid() transfer_a,gen_random_uuid() transfer_b,gen_random_uuid() out_a,gen_random_uuid() out_b,
  gen_random_uuid() out_fault;
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
  if current_setting('f2ro.no_write',true)='on' then
    raise exception using errcode='P0001',message='F2RO unexpected business DML';
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
    execute format('create trigger f2ro_no_write before insert or update or delete on %I.%I
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
  perform set_config('f2ro.no_write','on',true);
  begin
    execute p_sql into result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics state=returned_sqlstate,detail=pg_exception_detail;
  end;
  perform set_config('f2ro.no_write','off',true);
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

-- All history is written by actual qualified cores, not fabricated basis/event/operation rows.
create function pg_temp.prepare_history(p_animal uuid,p_exit uuid,p_reactivation uuid,p_transfer uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare f record; source uuid; context jsonb; prepared jsonb; exited jsonb; activated jsonb; actor uuid;
  payload jsonb:='{"provenance_version":"group-disposition-provenance.v1","disposition_kind":"ordinary_exit","metadata":{}}';
begin
  select * into f from pg_temp.ids;
  actor:=economics_v2.assert_group_writer_actor(f.farm_a);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||f.farm_a::text,0));
  if p_transfer is null then
    select period_id into source from economics_v2.group_occupancy_memberships
      where granja_id=f.farm_a and animal_id=p_animal and end_position is null;
    prepared:=economics_v2.prepare_group_operation(f.farm_a,p_exit,jsonb_build_object(
      'action','exit','animal_id',p_animal,'source_period_id',source,'destination_group_id',null,
      'destination_purpose_id',null,'sale_id',null,'effective_on',current_date-4,'payload',payload));
    context:=economics_v2.validate_group_meat_nonclosing_source(f.farm_a,p_animal,current_date-4);
    update public.animales set activo=false where granja_id=f.farm_a and id=p_animal and activo and baja_id is null;
    if not found then raise exception 'F2RO exit caller failed'; end if;
    exited:=economics_v2.exit_group_meat_nonclosing(f.farm_a,p_exit,p_animal,current_date-4,payload);
    prepared:=economics_v2.prepare_group_operation(f.farm_a,p_reactivation,jsonb_build_object(
      'action','reactivate','animal_id',p_animal,'source_period_id',null,'destination_group_id',f.reactivated_group,
      'destination_purpose_id',f.meat,'sale_id',null,'effective_on',current_date-3,
      'payload',jsonb_build_object('provenance_version','group-reactivation-provenance.v1',
        'disposition_kind','ordinary_reactivation','disposed_event_id',exited->'membership_event_ids'->0,'actor_id',actor,'metadata','{}'::jsonb)));
    context:=economics_v2.validate_disposed_group_meat_reactivation_source(f.farm_a,p_animal,
      (exited->'membership_event_ids'->>0)::uuid,current_date-3,f.reactivated_group,f.meat,false);
    update public.animales set activo=true,grupo_id=f.reactivated_group where granja_id=f.farm_a and id=p_animal and not activo;
    if not found then raise exception 'F2RO restore caller failed'; end if;
    activated:=economics_v2.reactivate_disposed_group_meat(f.farm_a,p_reactivation,p_animal,
      current_date-3,f.reactivated_group,f.meat,(exited->'membership_event_ids'->>0)::uuid,'{}');
    return activated;
  end if;
  select result into activated from economics_v2.group_occupancy_operations
    where granja_id=f.farm_a and operation_id=p_reactivation;
  select id into source from economics_v2.group_occupancy_periods where granja_id=f.farm_a
    and group_id=f.transferred_group and purpose_id=f.meat and end_position is null;
  context:=economics_v2.lock_group_writer_scope(f.farm_a,array[f.reactivated_group,f.transferred_group],array[p_animal],
    array[(activated->>'destination_period_id')::uuid]||case when source is null then '{}'::uuid[] else array[source] end,current_date-2);
  update public.animales set grupo_id=f.transferred_group where granja_id=f.farm_a and id=p_animal and activo;
  if not found then raise exception 'F2RO transfer caller failed'; end if;
  return economics_v2.transfer_reactivated_group_meat_nonclosing(
    f.farm_a,p_transfer,p_animal,current_date-2,f.transferred_group,f.meat,p_reactivation,'{}');
end;
$$;
create function pg_temp.holding_out(p_farm uuid,p_op uuid,p_animal uuid,p_date date,
  p_group uuid,p_purpose uuid,p_reactivation uuid,p_transfer uuid,p_metadata jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare source uuid; source_group uuid; context jsonb;
begin
  perform economics_v2.assert_group_writer_actor(p_farm);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_farm::text,0));
  if not exists(select 1 from economics_v2.group_occupancy_operations where granja_id=p_farm and operation_id=p_op) then
    select m.period_id,p.group_id into source,source_group from economics_v2.group_occupancy_memberships m
    join economics_v2.group_occupancy_periods p on p.granja_id=m.granja_id and p.id=m.period_id
    where m.granja_id=p_farm and m.animal_id=p_animal and m.end_position is null;
    context:=economics_v2.lock_group_writer_scope(p_farm,array[source_group,p_group],array[p_animal],array[source],p_date);
    update public.animales set grupo_id=p_group,proposito_id=p_purpose
      where granja_id=p_farm and id=p_animal and activo and baja_id is null;
    if not found then raise exception 'F2RO OUT caller failed'; end if;
  end if;
  -- FIRST intended absent-core call: exact typed signature; error must escape unhandled.
  return economics_v2.move_transferred_reactivated_meat_to_holding_nonclosing(
    p_farm,p_op,p_animal,p_date,p_group,p_purpose,p_reactivation,p_transfer,p_metadata);
end;
$$;

select pg_temp.check_true(not exists(select 1 from auth.users
  where raw_user_meta_data->>'fixture'='reactivated-holding-out'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"reactivated-holding-out"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F2RO farm A',owner_a from ids union all select farm_b,owner_b,'F2RO farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F2RO type A',owner_a from ids union all select type_b,farm_b,'F2RO type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat,farm_a,'F2RO meat','carne',owner_a from ids union all select eggs,farm_a,'F2RO eggs','postura',owner_a from ids
union all select ornamental,farm_a,'F2RO ornamental','ornamental',owner_a from ids
union all select foreign_purpose,farm_b,'F2RO foreign purpose','postura',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'F2RO group '||g::text,owner_a from ids
cross join lateral unnest(array[historical_group,reactivated_group,transferred_group]) g
union all select foreign_group,farm_b,type_b,'F2RO foreign group',owner_b from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,notas,created_by)
select a,farm_a,type_a,case when a=reactivated_anchor then reactivated_group
  when a=later_anchor then transferred_group else historical_group end,meat,current_date-7,
  case when a in(animal_a,animal_b) then 300 else 0 end,'F2RO animal',owner_a
from ids cross join lateral unnest(array[animal_a,animal_b,historical_anchor,reactivated_anchor,later_anchor]) a;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
create temp table initial as select a animal_id,economics_v2.enter_group_meat_initial(farm_a,gen_random_uuid(),a,
  current_date-6,case when a=reactivated_anchor then reactivated_group else historical_group end,meat,'{}') result
from ids cross join lateral unnest(array[animal_a,animal_b,historical_anchor,reactivated_anchor]) a;
create temp table captures as select animal_id,to_jsonb(b) full_row
from economics_v2.group_animal_acquisition_basis b where granja_id=(select farm_a from ids);
update public.animales set costo_adquisicion=999 where id in(select animal_a from ids union all select animal_b from ids);
-- Finish both earlier reactivations before either later transfer advances shared-period chronology.
create temp table reactivations as select animal_a animal_id,pg_temp.prepare_history(animal_a,exit_a,reactivate_a,null::uuid) result from ids
union all select animal_b,pg_temp.prepare_history(animal_b,exit_b,reactivate_b,null::uuid) from ids;
create temp table transfers as select animal_a animal_id,pg_temp.prepare_history(animal_a,exit_a,reactivate_a,transfer_a) result from ids
union all select animal_b,pg_temp.prepare_history(animal_b,exit_b,reactivate_b,transfer_b) from ids;
create temp table historical_rows as select 'events' kind,to_jsonb(e) full_row from economics_v2.group_occupancy_events e
where granja_id=(select farm_a from ids)
union all select 'entries',to_jsonb(b) from economics_v2.group_acquisition_basis_entries b where granja_id=(select farm_a from ids)
union all select 'periods',to_jsonb(p) from economics_v2.group_occupancy_periods p where granja_id=(select farm_a from ids);
create temp table source_members as select animal_id,to_jsonb(m) full_row from economics_v2.group_occupancy_memberships m
where animal_id in(select animal_a from ids union all select animal_b from ids) and end_position is null;
create temp table public_before as select id,to_jsonb(a) full_row from public.animales a where granja_id=(select farm_a from ids);
set constraints all immediate;
set constraints all deferred;
select pg_temp.check_true((select count(*)=2 and bool_and(initial_basis=300 and source_cost=300 and remaining_basis=0 and version=3)
  from economics_v2.group_animal_acquisition_basis where animal_id in(select animal_id from transfers)),
  'REAL original300 exit/reactivation/ONE qualified transfer precedes NEW OUT');
do $grants$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$grants$;
grant execute on function pg_temp.holding_out(uuid,uuid,uuid,date,uuid,uuid,uuid,uuid,jsonb),
  pg_temp.checked(text,text,text,text),pg_temp.check_true(boolean,text),pg_temp.business_state(),pg_temp.position_state() to authenticated,anon;
create temp table receipts(animal_id uuid,result jsonb);
do $first$
declare f record; r jsonb;
begin
  select * into f from pg_temp.ids;
  set local role authenticated;
  r:=pg_temp.holding_out(f.farm_a,f.out_a,f.animal_a,current_date-1,
    f.transferred_group,f.eggs,f.reactivate_a,f.transfer_a,'{"probe":1.00}'::jsonb);
  reset role;
  insert into pg_temp.receipts values(f.animal_a,r);
end;
$first$;

create function pg_temp.late_fault()
returns trigger language plpgsql set search_path='' as $$
begin
  if tg_table_name='group_acquisition_basis_entries' then
    if current_setting('f2ro.fault',true)='holding_leg' and new.account_kind='holding' then
      raise exception using errcode='P0001',message='F2RO injected holding_leg';
    end if;
  elsif current_setting('f2ro.fault',true)='completion' and new.result->>'action'='purpose_change' then
    perform pg_temp.check_true((select count(*)=2 and bool_and(signed_amount=0)
      from economics_v2.group_acquisition_basis_entries where granja_id=new.granja_id and operation_id=new.operation_id)
      and exists(select 1 from economics_v2.group_animal_acquisition_basis where granja_id=new.granja_id
        and animal_id=(new.result->>'animal_id')::uuid and current_account_kind='holding' and current_period_id is null and version=4),
      'completion LAST after real zero holding leg and basis pointer update');
    raise exception using errcode='P0001',message='F2RO injected completion';
  end if;
  return new;
end;
$$;
create trigger f2ro_late_leg before insert on economics_v2.group_acquisition_basis_entries for each row execute function pg_temp.late_fault();
create trigger f2ro_late_completion before update on economics_v2.group_occupancy_operations for each row execute function pg_temp.late_fault();
do $proof$
declare f record; r jsonb; repeated jsonb; sql text; baseline jsonb; before_seq jsonb;
  probe record; actor record; control record; proc record; state text; message text; prepared jsonb;
begin
  select * into f from pg_temp.ids;
  select result into r from pg_temp.receipts where animal_id=f.animal_a;
  sql:=format('select pg_temp.holding_out(%L,%L,%L,current_date-1,%L,%L,%L,%L,''{"probe":1}''::jsonb)',
    f.farm_a,f.out_a,f.animal_a,f.transferred_group,f.eggs,f.reactivate_a,f.transfer_a);
  repeated:=pg_temp.checked(sql);
  perform pg_temp.check_true(repeated=r||'{"replayed":true}'::jsonb,'canonical original-source replay while holding with no current member');
  for probe in select * from (values
    (f.eggs,f.reactivate_a,f.transfer_a,current_date-1,'{"probe":2}'::jsonb),
    (f.ornamental,f.reactivate_a,f.transfer_a,current_date-1,'{"probe":1}'::jsonb),
    (f.eggs,f.reactivate_b,f.transfer_a,current_date-1,'{"probe":1}'::jsonb),
    (f.eggs,f.reactivate_a,f.transfer_b,current_date-1,'{"probe":1}'::jsonb),
    (f.eggs,f.reactivate_a,f.transfer_a,current_date,'{"probe":1}'::jsonb)) v(purpose,reactivation,transfer,effective_on,metadata) loop
    perform pg_temp.checked(format('select pg_temp.holding_out(%L,%L,%L,%L::date,%L,%L,%L,%L,%L::jsonb)',
      f.farm_a,f.out_a,f.animal_a,probe.effective_on,f.transferred_group,probe.purpose,probe.reactivation,probe.transfer,probe.metadata),
      '22023','operation_payload_conflict','operation_id');
  end loop;
  -- Last-member refusal is genuine, before any new entry or synthetic closure.
  baseline:=pg_temp.business_state();
  begin
    update public.animales set proposito_id=f.ornamental where id=f.animal_b;
    perform pg_temp.checked(format('select economics_v2.move_transferred_reactivated_meat_to_holding_nonclosing(
      %L,%L,%L,current_date,%L,%L,%L,%L,''{}''::jsonb)',f.farm_a,gen_random_uuid(),f.animal_b,
      f.transferred_group,f.ornamental,f.reactivate_b,f.transfer_b),'23514','period_close_unfinalized_facts','source_period_id');
    raise exception using errcode='Z0001',message='F2RO restore last-member public probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'last-member public probe restored');
  perform economics_v2.enter_group_meat_initial(f.farm_a,gen_random_uuid(),f.later_anchor,current_date,f.transferred_group,f.meat,'{}');
  repeated:=pg_temp.checked(sql);
  perform pg_temp.check_true(repeated=r||'{"replayed":true}'::jsonb,'replay ignores later REAL source chronology');
  for actor in select * from (values(f.editor_a,'authenticated'),(f.viewer_a,'authenticated'),(null::uuid,'anon')) v(id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    if actor.id=f.editor_a then
      perform pg_temp.checked(sql,'22023','operation_payload_conflict','operation_id');
    else
      perform pg_temp.checked(sql,'42501','forbidden','granja_id');
    end if;
    perform pg_temp.checked('select economics_v2.move_transferred_reactivated_meat_to_holding_nonclosing(
      null::uuid,null::uuid,null::uuid,null::date,null::uuid,null::uuid,null::uuid,null::uuid,null::jsonb)','42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  for probe in select * from (values
    (f.farm_b,f.animal_b,f.reactivate_b,f.transfer_b,'42501','forbidden','granja_id'),
    (f.farm_a,f.animal_b,null::uuid,f.transfer_b,'22023','invalid_request','reactivation_operation_id'),
    (f.farm_a,f.animal_b,f.reactivate_b,null::uuid,'22023','invalid_request','transfer_operation_id'),
    (f.farm_a,f.animal_b,f.reactivate_a,f.transfer_b,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_b,f.reactivate_b,f.transfer_a,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.reactivated_anchor,f.reactivate_b,f.transfer_b,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_b,f.reactivate_b,f.transfer_b,'42501','forbidden','purpose_id')) v(farm,animal,reactivation,transfer,state,code,field) loop
    perform pg_temp.checked(format('select economics_v2.move_transferred_reactivated_meat_to_holding_nonclosing(
      %L,%L,%L,current_date,%L,%L,%L,%L,''{}''::jsonb)',probe.farm,gen_random_uuid(),probe.animal,
      f.transferred_group,f.ornamental,probe.reactivation,probe.transfer),probe.state,probe.code,probe.field);
  end loop;
  for probe in select * from (values('holding_leg'),('completion')) v(kind) loop
    baseline:=pg_temp.business_state();
    before_seq:=pg_temp.position_state();
    state:=null;
    message:=null;
    perform set_config('f2ro.fault',probe.kind,true);
    begin
      perform pg_temp.holding_out(f.farm_a,f.out_fault,f.animal_b,current_date,f.transferred_group,
        f.ornamental,f.reactivate_b,f.transfer_b,'{}');
    exception when others then
      get stacked diagnostics state=returned_sqlstate,message=message_text;
    end;
    perform set_config('f2ro.fault','off',true);
    perform pg_temp.check_true(state='P0001' and message='F2RO injected '||probe.kind,'reached independent late fault: '||probe.kind);
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'all rows including caller purpose DML rollback: '||probe.kind);
    perform pg_temp.check_true((pg_temp.position_state()->>'last_value')::bigint>(before_seq->>'last_value')::bigint,'sequence gap retained');
    set constraints all immediate;
    set constraints all deferred;
  end loop;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated')::text,true);
  set local role authenticated;
  r:=pg_temp.holding_out(f.farm_a,f.out_b,f.animal_b,current_date,f.transferred_group,
    f.ornamental,f.reactivate_b,f.transfer_b,'{}');
  reset role;
  insert into pg_temp.receipts values(f.animal_b,r);
  -- An authorized editor can use owner-created history without replaying its old actor hash as editor.
  for control in select * from (values(f.animal_a,f.out_a,f.reactivate_a,f.transfer_a,f.eggs,f.owner_a,current_date-1),
    (f.animal_b,f.out_b,f.reactivate_b,f.transfer_b,f.ornamental,f.editor_a,current_date)) v(animal,operation,reactivation,transfer,purpose,actor,effective_on) loop
    select result into r from pg_temp.receipts where animal_id=control.animal;
    perform pg_temp.check_true(r=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',control.operation,
      'action','purpose_change','animal_id',control.animal,'source_period_id',
      (select result->'destination_period_id' from pg_temp.transfers where animal_id=control.animal),
      'destination_period_id',null,'membership_event_ids',r->'membership_event_ids','effective_on',control.effective_on,
      'event_position',r->'event_position','source_end_position',r->'event_position','destination_start_position',null,
      'basis_entry_ids',r->'basis_entry_ids','basis_before',0,'basis_after',0,'source_status','open',
      'destination_status',null,'snapshot_id',null,'state_version',4,'replayed',false)
      and jsonb_array_length(r->'membership_event_ids')=1 and jsonb_array_length(r->'basis_entry_ids')=2,'exact19 zero OUT receipt');
    perform pg_temp.check_true((select count(*)=2 and count(distinct b.entry_pair_id)=1
      and bool_and(b.signed_amount=0 and b.animal_id=control.animal and b.event_id=e.id and b.entry_pair_id=e.basis_transfer_id
        and e.action='purpose_change' and e.operation_id=control.operation and e.animal_id=m.animal_id and e.period_id=m.period_id and e.sale_id is null
        and e.event_position=m.end_position and e.event_position=(r->>'event_position')::bigint
        and ((b.entry_kind='purpose_out' and b.account_kind='period' and b.period_id=e.period_id)
          or (b.entry_kind='purpose_in' and b.account_kind='holding' and b.period_id is null)))
      from economics_v2.group_acquisition_basis_entries b join economics_v2.group_occupancy_events e on e.id=b.event_id
      join economics_v2.group_occupancy_memberships m on m.id=e.membership_id where b.operation_id=control.operation)
      and (select array_agg(id::text order by id::text) from economics_v2.group_acquisition_basis_entries where operation_id=control.operation)
        =(select array_agg(v order by v) from jsonb_array_elements_text(r->'basis_entry_ids') v)
      and exists(select 1 from economics_v2.group_occupancy_events where id=(r->'membership_event_ids'->>0)::uuid
        and operation_id=control.operation),'one event/exact zero source-to-holding pair and receipt identities');
    perform pg_temp.check_true(exists(select 1 from economics_v2.group_animal_acquisition_basis b join pg_temp.captures c using(animal_id)
      where b.animal_id=control.animal and to_jsonb(b)=c.full_row||jsonb_build_object('remaining_basis',0,
        'current_account_kind','holding','current_period_id',null,'version',4))
      and not exists(select 1 from economics_v2.group_occupancy_memberships where animal_id=control.animal and end_position is null)
      and exists(select 1 from economics_v2.group_occupancy_memberships m join pg_temp.source_members s using(animal_id)
        where m.id=(s.full_row->>'id')::uuid and to_jsonb(m)-'position_span'=(s.full_row-'position_span')||jsonb_build_object('end_position',(r->>'event_position')::bigint))
      and exists(select 1 from public.animales a join pg_temp.public_before p on p.id=a.id
        where a.id=control.animal and to_jsonb(a)=p.full_row||jsonb_build_object('proposito_id',control.purpose)),
      'capture300/source999 immutable; exact caller purpose delta; no invented holding membership');
    perform set_config('request.jwt.claim.sub',control.actor::text,true);
    prepared:=economics_v2.prepare_group_operation(f.farm_a,control.operation,jsonb_build_object(
      'action','purpose_change','animal_id',control.animal,'source_period_id',r->'source_period_id','destination_group_id',f.transferred_group,
      'destination_purpose_id',control.purpose,'sale_id',null,'effective_on',control.effective_on,
      'payload',jsonb_build_object('reactivation_operation_id',control.reactivation,'transfer_operation_id',control.transfer,
        'metadata',case when control.animal=f.animal_a then '{"probe":1}'::jsonb else '{}'::jsonb end)));
    perform pg_temp.check_true(prepared->'result'=r||'{"replayed":true}'::jsonb,'actual actor and both history identities bound to canonical hash');
  end loop;
  perform pg_temp.check_true(not exists(select 1 from pg_temp.historical_rows h where not exists(
    select 1 from economics_v2.group_occupancy_events e where h.kind='events' and to_jsonb(e)=h.full_row
    union all select 1 from economics_v2.group_acquisition_basis_entries b where h.kind='entries' and to_jsonb(b)=h.full_row
    union all select 1 from economics_v2.group_occupancy_periods p where h.kind='periods' and to_jsonb(p)=h.full_row)),
    'all prior enter/exit/reactivation/transfer events, signed entries and period rows unchanged');
  perform pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(f.farm_a,
    (select (result->>'destination_period_id')::uuid from pg_temp.initial where animal_id=f.animal_a)) @> '{"acquisition_cost":600,"active_animal_count":1}'::jsonb
    and economics_v2.calculate_group_period_live_metrics(f.farm_a,(r->>'source_period_id')::uuid) @> '{"acquisition_cost":0,"active_animal_count":1}'::jsonb
    and (select coalesce(sum(signed_amount),0)=0 from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a and account_kind='holding'),
    'historical realized600 retained, transferred source0 and holding0; no recapture');
  select * into proc from pg_proc where oid=
    'economics_v2.move_transferred_reactivated_meat_to_holding_nonclosing(uuid,uuid,uuid,date,uuid,uuid,uuid,uuid,jsonb)'::regprocedure;
  perform pg_temp.check_true(proc.prorettype='jsonb'::regtype and not proc.prosecdef and proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(proc.proacl,acldefault('f',proc.proowner))) acl where acl.grantee=0 and acl.privilege_type='EXECUTE')
    and not has_function_privilege('anon',proc.oid,'EXECUTE') and not has_function_privilege('authenticated',proc.oid,'EXECUTE'),'private invoker/empty path/no PUBLIC or client execute');
  set constraints all immediate;
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_memberships m join economics_v2.group_occupancy_periods p on p.id=m.period_id
    where m.granja_id=f.farm_a and not(m.position_span<@p.position_span)),'forced deferred containment');
  perform pg_temp.check_true((select count(*)=13 from economics_v2.group_occupancy_operations where granja_id=f.farm_a)
    and (select count(*)=13 and sum(signed_amount)=600 from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a)
    and not exists(select 1 from economics_v2.group_meat_snapshots where granja_id=f.farm_a)
    and not exists(select 1 from economics_v2.group_occupancy_periods where granja_id=f.farm_a and end_position is not null)
    and not exists(select 1 from public.bajas_animales where granja_id=f.farm_a)
    and not exists(select 1 from public.venta_animal where granja_id=f.farm_a),'exact counts; failed OUT absent; no closure/snapshot/baja/sale/RETURN');
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_reactivated_holding_out_pass',
  'assertion_count',(select count(*) from assertions),'locking_evidence','sequential_only',
  'production_gateway_integrated',false,'return_compatibility_proven',false,'independent_review','pending',
  'fixture_ids',(select to_jsonb(ids) from ids)) as evidence;
rollback;
