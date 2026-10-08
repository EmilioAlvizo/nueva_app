begin;

-- Run the FULL file in the sandbox SQL Editor; stop and report the first error.
-- Expected first RED: 42883 at the first seven-argument private validator call.
-- Forecast: fixture <=540 + future read-only validator <=250 = <=790/800 lines.
-- All created tables are TEMP; do not enable or change business-table RLS.
-- This unit validates real ordinary-exit history, NOT actual accounting reactivation.
-- FALSE checks pre-restore inactive/source public state; TRUE checks caller-restored
-- active/destination public state while basis remains disposed with its real pointer.
-- Both phases are private predicates, never user-restoration permission or receipts.
-- Future caller locks the complete prefix BEFORE public restore DML in the SAME TX.
-- Historical source is read-only and never a mutable F2A period-lock argument.
-- Closed-history runtime coverage/F5, other dispositions and concurrent sessions are deferred.
-- The later mutator owns replay, exact19 transitions, final completion and late faults.
create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,
  gen_random_uuid() type_a,gen_random_uuid() type_wrong,gen_random_uuid() type_b,
  gen_random_uuid() meat,gen_random_uuid() other_meat,
  gen_random_uuid() eggs,gen_random_uuid() purpose_b,
  gen_random_uuid() source_a,gen_random_uuid() source_zero,
  gen_random_uuid() destination_new,gen_random_uuid() destination_reuse,
  gen_random_uuid() destination_wrong,gen_random_uuid() group_b,
  gen_random_uuid() animal_a,gen_random_uuid() anchor_a,
  gen_random_uuid() animal_zero,gen_random_uuid() anchor_zero,
  gen_random_uuid() destination_seed,gen_random_uuid() animal_b,
  gen_random_uuid() exit_a,gen_random_uuid() exit_zero;
create temp table assertions(label text not null);
create temp table payload as select
  '{"provenance_version":"group-disposition-provenance.v1","disposition_kind":"ordinary_exit","metadata":{"reference":1}}'::jsonb value;

create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;

-- Full rows, not counts: all10 forward tables plus authoritative public/auth sources.
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

-- Block even attempted zero-row DML during validation calls, never during setup.
create function pg_temp.no_write()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_setting('f2rv.no_write',true)='on' then
    raise exception using errcode='P0001',message='F2RV unexpected business DML';
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
    execute format('create trigger f2rv_no_write before insert or update or delete on %I.%I
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
  perform set_config('f2rv.no_write','on',true);
  begin
    execute p_sql into result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics state=returned_sqlstate,detail=pg_exception_detail;
  end;
  perform set_config('f2rv.no_write','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=before_rows,'full rows unchanged: '||p_sql);
  perform pg_temp.check_true(pg_temp.position_state()=before_seq,'sequence unchanged: '||p_sql);
  if p_state is null then
    perform pg_temp.check_true(result is not null,'nonempty internal context');
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

-- REAL qualified ordinary exit setup; no fabricated disposed row or completed receipt.
create function pg_temp.exit_gateway(p_farm uuid,p_operation uuid,p_animal uuid,p_date date)
returns jsonb language plpgsql security definer set search_path='' as $$
declare source_id uuid; prepared jsonb; context jsonb; value jsonb; affected bigint;
begin
  perform economics_v2.assert_group_writer_actor(p_farm);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_farm::text,0));
  select p.value into value from pg_temp.payload p;
  if exists(select 1 from economics_v2.group_occupancy_operations
    where granja_id=p_farm and operation_id=p_operation) then
    return economics_v2.exit_group_meat_nonclosing(p_farm,p_operation,p_animal,p_date,value);
  end if;
  select period_id into source_id from economics_v2.group_occupancy_memberships
    where granja_id=p_farm and animal_id=p_animal and end_position is null;
  prepared:=economics_v2.prepare_group_operation(p_farm,p_operation,jsonb_build_object(
    'action','exit','animal_id',p_animal,'source_period_id',source_id,
    'destination_group_id',null,'destination_purpose_id',null,'sale_id',null,
    'effective_on',p_date,'payload',value));
  context:=economics_v2.validate_group_meat_nonclosing_source(p_farm,p_animal,p_date);
  perform pg_temp.check_true(context->>'actor_id'=auth.uid()::text
    and context->>'source_period_id'=source_id::text,'real exit pre-DML prefix');
  update public.animales set activo=false where granja_id=p_farm and id=p_animal
    and activo is true and baja_id is null;
  get diagnostics affected=row_count;
  perform pg_temp.check_true(affected=1,'real exit public inactive update');
  return economics_v2.exit_group_meat_nonclosing(p_farm,p_operation,p_animal,p_date,value);
end;
$$;

-- Fixture-only trusted bridge preserves JWT actor and calls the real private validator.
-- It implements no validation predicate, restoration policy or helper stub.
create function pg_temp.validate_gateway(p_farm uuid,p_animal uuid,p_event uuid,p_date date,
  p_group uuid,p_purpose uuid,p_active boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  return economics_v2.validate_disposed_group_meat_reactivation_source(
    p_farm,p_animal,p_event,p_date,p_group,p_purpose,p_active);
end;
$$;

select pg_temp.check_true(
  not exists(select 1 from auth.users where raw_user_meta_data->>'fixture'='group-reactivation-source-validation')
  and not exists(select 1 from public.granjas where nombre like 'F2RV %'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"group-reactivation-source-validation"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F2RV farm A',owner_a from ids
union all select farm_b,owner_b,'F2RV farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F2RV type A',owner_a from ids
union all select type_wrong,farm_a,'F2RV wrong type',owner_a from ids
union all select type_b,farm_b,'F2RV foreign type',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat,farm_a,'F2RV meat','carne',owner_a from ids
union all select other_meat,farm_a,'F2RV other meat','carne',owner_a from ids
union all select eggs,farm_a,'F2RV eggs','postura',owner_a from ids
union all select purpose_b,farm_b,'F2RV foreign meat','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'F2RV group '||g::text,owner_a
from ids cross join lateral unnest(array[source_a,source_zero,destination_new,destination_reuse]) g
union all select destination_wrong,farm_a,type_wrong,'F2RV wrong group',owner_a from ids
union all select group_b,farm_b,type_b,'F2RV foreign group',owner_b from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,notas,created_by)
select a,farm_a,type_a,case when a in(animal_zero,anchor_zero) then source_zero
  when a=destination_seed then destination_reuse else source_a end,meat,current_date-5,
  case when a=animal_a then 300 else 0 end,'F2RV animal',owner_a
from ids cross join lateral unnest(array[animal_a,anchor_a,animal_zero,anchor_zero,destination_seed]) a
union all select animal_b,farm_b,type_b,group_b,purpose_b,current_date-5,0,'F2RV foreign',owner_b from ids;
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
create temp table exits as select animal_a animal_id,pg_temp.exit_gateway(
  farm_a,exit_a,animal_a,current_date-2) result from ids
union all select animal_zero,pg_temp.exit_gateway(farm_a,exit_zero,animal_zero,current_date-2) from ids;
create temp table disposed_rows as select animal_id,to_jsonb(b) basis
from economics_v2.group_animal_acquisition_basis b where animal_id in(
  select animal_a from ids union all select animal_zero from ids);
set constraints all immediate;
set constraints all deferred;

-- FIRST missing-helper boundary: actual initial300 -> actual anchored ordinary exit.
-- The missing function error escapes; no regprocedure test or expected-error catch precedes it.
create temp table first_context as select pg_temp.checked(format(
  'select pg_temp.validate_gateway(%L,%L,%L,current_date-1,%L,%L,false)',
  f.farm_a,f.animal_a,e.result->'membership_event_ids'->>0,f.destination_new,f.other_meat)) result
from ids f join exits e on e.animal_id=f.animal_a;

do $grants$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$grants$;
grant execute on function pg_temp.validate_gateway(uuid,uuid,uuid,date,uuid,uuid,boolean),
  pg_temp.checked(text,text,text,text),pg_temp.check_true(boolean,text),
  pg_temp.business_state(),pg_temp.position_state() to authenticated,anon;

-- Exact INTERNAL16 working context. Full rows are compared to authoritative storage.
create function pg_temp.assert_context(p_context jsonb,p_animal uuid,p_event uuid,
  p_group uuid,p_purpose uuid,p_active boolean)
returns void language plpgsql security definer set search_path='' as $$
declare f record; e record; m record; b jsonb; receipt jsonb; destination uuid; groups uuid[];
begin
  select * into f from pg_temp.ids;
  select * into e from economics_v2.group_occupancy_events where id=p_event;
  select * into m from economics_v2.group_occupancy_memberships where id=e.membership_id;
  select to_jsonb(r) into b from economics_v2.group_animal_acquisition_basis r
    where granja_id=f.farm_a and animal_id=p_animal;
  select result into receipt from economics_v2.group_occupancy_operations
    where granja_id=f.farm_a and operation_id=e.operation_id;
  select id into destination from economics_v2.group_occupancy_periods
    where granja_id=f.farm_a and group_id=p_group and purpose_id=p_purpose and end_position is null;
  select array_agg(distinct g order by g) into groups from unnest(array[p_group,
    (select group_id from economics_v2.group_occupancy_periods where id=e.period_id),
    (select grupo_id from public.animales where id=p_animal)]) g;
  perform pg_temp.check_true(p_context=jsonb_build_object(
    'context_version','group-reactivation-source-context.v1','actor_id',auth.uid(),
    'granja_id',f.farm_a,'animal_id',p_animal,'disposed_event_id',p_event,
    'effective_on',current_date-1,'destination_group_id',p_group,'destination_purpose_id',p_purpose,
    'expected_active',p_active,'basis',b,'disposition_event',to_jsonb(e),
    'disposition_result',receipt,'historical_membership',to_jsonb(m),'historical_period_id',e.period_id,
    'destination_period_id',destination,'scope',jsonb_build_object('actor_id',auth.uid(),
      'group_ids',groups,'animal_ids',jsonb_build_array(p_animal),
      'period_ids',case when destination is null then '[]'::jsonb else jsonb_build_array(destination) end))
    and (select count(*)=16 from jsonb_object_keys(p_context)),
    'exact16 actual rows and ordered scope; historical period excluded');
end;
$$;

do $proof$
declare f record; control record; probe record; actor record; r jsonb; repeated jsonb;
  event_a uuid; event_zero uuid; baseline jsonb; sql text; proc record; message text; state text;
begin
  select * into f from pg_temp.ids;
  select (result->'membership_event_ids'->>0)::uuid into event_a from pg_temp.exits where animal_id=f.animal_a;
  select (result->'membership_event_ids'->>0)::uuid into event_zero from pg_temp.exits where animal_id=f.animal_zero;
  baseline:=pg_temp.business_state();

  for control in select * from (values
    (f.animal_a,event_a,f.destination_new,f.other_meat,300::numeric),
    (f.animal_zero,event_zero,f.destination_reuse,f.meat,0::numeric)) v(animal,event,destination,purpose,cost) loop
    select result into r from pg_temp.exits where animal_id=control.animal;
    perform pg_temp.check_true(r=jsonb_build_object('contract_version','group-economics.forward.v3',
      'operation_id',case when control.animal=f.animal_a then f.exit_a else f.exit_zero end,
      'action','exit','animal_id',control.animal,'source_period_id',r->'source_period_id',
      'destination_period_id',null,'membership_event_ids',jsonb_build_array(control.event),
      'effective_on',current_date-2,'event_position',r->'event_position','source_end_position',r->'event_position',
      'destination_start_position',null,'basis_entry_ids','[]'::jsonb,'basis_before',control.cost,
      'basis_after',0,'source_status','open','destination_status',null,'snapshot_id',null,
      'state_version',1,'replayed',false),'real source exact19 receipt300/0');
    perform pg_temp.check_true(exists(select 1 from economics_v2.group_animal_acquisition_basis b
      join pg_temp.captures c using(animal_id) where b.animal_id=control.animal
        and to_jsonb(b)=c.basis||jsonb_build_object('remaining_basis',0,'status','disposed',
          'current_account_kind','disposed','current_period_id',null,'disposed_event_id',control.event,'version',1)),
      'real exit retained complete capture; remaining0 version1');
    sql:=format('select pg_temp.validate_gateway(%L,%L,%L,current_date-1,%L,%L,false)',
      f.farm_a,control.animal,control.event,control.destination,control.purpose);
    r:=pg_temp.checked(sql);
    perform pg_temp.assert_context(r,control.animal,control.event,control.destination,control.purpose,false);
    repeated:=pg_temp.checked(sql);
    perform pg_temp.check_true(repeated=r,'deterministic read-only repeated validation');
    if control.animal=f.animal_a then
      perform pg_temp.check_true(r=(select result from pg_temp.first_context),'first valid context unchanged');
    end if;

    -- FALSE obtains the complete prefix before fixture-only public restore DML.
    -- TRUE rechecks actual destination state, not a supplied context token.
    begin
      update public.animales set activo=true,grupo_id=control.destination,proposito_id=control.purpose
        where id=control.animal;
      r:=pg_temp.checked(format('select pg_temp.validate_gateway(%L,%L,%L,current_date-1,%L,%L,true)',
        f.farm_a,control.animal,control.event,control.destination,control.purpose));
      perform pg_temp.assert_context(r,control.animal,control.event,control.destination,control.purpose,true);
      perform pg_temp.checked(sql,'23514','invariant_violation','animal_id');
      -- The postphase must independently reread both actual destination identities.
      update public.animales set grupo_id=f.source_a where id=control.animal;
      perform pg_temp.checked(format('select pg_temp.validate_gateway(%L,%L,%L,current_date-1,%L,%L,true)',
        f.farm_a,control.animal,control.event,control.destination,control.purpose),
        '42501','forbidden','group_id');
      update public.animales set grupo_id=control.destination,
        proposito_id=case when control.purpose=f.meat then f.other_meat else f.meat end
        where id=control.animal;
      perform pg_temp.checked(format('select pg_temp.validate_gateway(%L,%L,%L,current_date-1,%L,%L,true)',
        f.farm_a,control.animal,control.event,control.destination,control.purpose),
        '42501','forbidden','purpose_id');
      update public.animales set proposito_id=control.purpose,activo=false where id=control.animal;
      perform pg_temp.checked(format('select pg_temp.validate_gateway(%L,%L,%L,current_date-1,%L,%L,true)',
        f.farm_a,control.animal,control.event,control.destination,control.purpose),
        '23514','invariant_violation','animal_id');
      raise exception using errcode='Z0001',message='F2RV restore public poststate probe';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'full public poststate probe rollback');
  end loop;

  -- Every refusal must precede sequence issuance and every attempted business write.
  for probe in select * from (values
    (null::uuid,f.animal_a,event_a,current_date-1,f.destination_new,f.other_meat,false,'22023','invalid_request','granja_id'),
    (f.farm_b,f.animal_a,event_a,current_date-1,f.destination_new,f.other_meat,false,'42501','forbidden','granja_id'),
    (f.farm_a,f.animal_b,event_a,current_date-1,f.destination_new,f.other_meat,false,'42501','forbidden','animal_id'),
    (f.farm_a,gen_random_uuid(),event_a,current_date-1,f.destination_new,f.other_meat,false,'42501','forbidden','animal_id'),
    (f.farm_a,null::uuid,event_a,current_date-1,f.destination_new,f.other_meat,false,'22023','invalid_request','animal_id'),
    (f.farm_a,f.animal_a,null::uuid,current_date-1,f.destination_new,f.other_meat,false,'22023','invalid_request','disposed_event_id'),
    (f.farm_a,f.animal_a,event_zero,current_date-1,f.destination_new,f.other_meat,false,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_a,event_a,null::date,f.destination_new,f.other_meat,false,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_a,event_a,'infinity'::date,f.destination_new,f.other_meat,false,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_a,event_a,'-infinity'::date,f.destination_new,f.other_meat,false,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_a,event_a,current_date+1,f.destination_new,f.other_meat,false,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_a,event_a,current_date-3,f.destination_new,f.other_meat,false,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_a,event_a,current_date-1,null::uuid,f.other_meat,false,'22023','invalid_request','destination'),
    (f.farm_a,f.animal_a,event_a,current_date-1,f.destination_new,null::uuid,false,'22023','invalid_request','destination'),
    (f.farm_a,f.animal_a,event_a,current_date-1,f.group_b,f.other_meat,false,'42501','forbidden','group_id'),
    (f.farm_a,f.animal_a,event_a,current_date-1,gen_random_uuid(),f.other_meat,false,'42501','forbidden','group_id'),
    (f.farm_a,f.animal_a,event_a,current_date-1,f.destination_wrong,f.other_meat,false,'23514','invariant_violation','group_id'),
    (f.farm_a,f.animal_a,event_a,current_date-1,f.destination_new,f.purpose_b,false,'42501','forbidden','purpose_id'),
    (f.farm_a,f.animal_a,event_a,current_date-1,f.destination_new,f.eggs,false,'22023','invalid_request','purpose_id'),
    (f.farm_a,f.animal_a,event_a,current_date-1,f.destination_new,gen_random_uuid(),false,'42501','forbidden','purpose_id'),
    (f.farm_a,f.animal_a,event_a,current_date-1,f.destination_new,f.other_meat,null::boolean,'22023','invalid_request','expected_active'),
    (f.farm_a,f.animal_a,event_a,current_date-1,f.destination_new,f.other_meat,true,'23514','invariant_violation','animal_id'))
    v(farm,animal,event,effective_on,destination,purpose,active,state,code,field) loop
    perform pg_temp.checked(format('select pg_temp.validate_gateway(%L::uuid,%L::uuid,%L::uuid,%L::date,%L::uuid,%L::uuid,%L::boolean)',
      probe.farm,probe.animal,probe.event,probe.effective_on,probe.destination,probe.purpose,probe.active),
      probe.state,probe.code,probe.field);
  end loop;

  sql:=format('select pg_temp.validate_gateway(%L,%L,%L,current_date-1,%L,%L,false)',
    f.farm_a,f.animal_a,event_a,f.destination_new,f.other_meat);
  -- Valid isolated corruption probes, rolled back without bypassing qualified constraints.
  for probe in select * from (values
    ('disabled',format('update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=%L',f.farm_a),'42501','forbidden','granja_id'),
    ('phase',format('update public.animales set activo=true where id=%L',f.animal_a),'23514','invariant_violation','animal_id'),
    ('old_group',format('update public.animales set grupo_id=%L where id=%L',f.destination_new,f.animal_a),'42501','forbidden','group_id'),
    ('old_purpose',format('update public.animales set proposito_id=%L where id=%L',f.other_meat,f.animal_a),'42501','forbidden','purpose_id'),
    ('source_type',format('update public.grupos set tipo_animal_id=%L where id=%L',f.type_wrong,f.source_a),'23514','invariant_violation','group_id'),
    ('source_nonmeat',format('update public.cat_proposito_animal set codigo_calculo=''postura'' where id=%L',f.meat),'22023','invalid_request','purpose_id'),
    ('remaining',format('update economics_v2.group_animal_acquisition_basis set remaining_basis=1 where animal_id=%L',f.animal_a),'23514','invariant_violation','animal_id'),
    ('capture',format('update economics_v2.group_animal_acquisition_basis set source_cost=301 where animal_id=%L',f.animal_a),'23514','invariant_violation','animal_id'),
    ('pointer',format('update economics_v2.group_animal_acquisition_basis set disposed_event_id=%L where animal_id=%L',event_zero,f.animal_a),'23514','invariant_violation','animal_id'),
    ('version',format('update economics_v2.group_animal_acquisition_basis set version=2 where animal_id=%L',f.animal_a),'23514','invariant_violation','animal_id'),
    ('status',format('update economics_v2.group_animal_acquisition_basis set status=''active'' where animal_id=%L',f.animal_a),'23514','invariant_violation','animal_id'),
    ('account',format('update economics_v2.group_animal_acquisition_basis set current_account_kind=''holding'' where animal_id=%L',f.animal_a),'23514','invariant_violation','animal_id'),
    ('open_membership',format('update economics_v2.group_occupancy_memberships set end_position=null where id=(select membership_id from economics_v2.group_occupancy_events where id=%L)',event_a),'23514','invariant_violation','animal_id'),
    ('signed_source',format('update economics_v2.group_acquisition_basis_entries set signed_amount=301 where animal_id=%L',f.animal_a),'23514','invariant_violation','animal_id'),
    ('incomplete',format('update economics_v2.group_occupancy_operations set result=''{}'' where operation_id=%L',f.exit_a),'23514','invariant_violation','operation_id'),
    ('receipt_link',format('update economics_v2.group_occupancy_operations set result=jsonb_set(result,''{animal_id}'',to_jsonb(%L::uuid)) where operation_id=%L',f.animal_zero,f.exit_a),'23514','invariant_violation','operation_id'),
    ('receipt_version',format('update economics_v2.group_occupancy_operations set result=jsonb_set(result,''{contract_version}'',''"wrong"'') where operation_id=%L',f.exit_a),'23514','invariant_violation','operation_id'),
    ('receipt_basis',format('update economics_v2.group_occupancy_operations set result=jsonb_set(result,''{basis_before}'',''301'') where operation_id=%L',f.exit_a),'23514','invariant_violation','operation_id'),
    ('receipt_action',format('update economics_v2.group_occupancy_operations set result=jsonb_set(result,''{action}'',''"delete"'') where operation_id=%L',f.exit_a),'23514','invariant_violation','operation_id'),
    ('receipt_position',format('update economics_v2.group_occupancy_operations set event_position=event_position+1 where operation_id=%L',f.exit_a),'23514','invariant_violation','operation_id'),
    ('ended_boundary',format('update economics_v2.group_occupancy_memberships set end_position=end_position+1 where id=(select membership_id from economics_v2.group_occupancy_events where id=%L)',event_a),'23514','invariant_violation','animal_id'))
    v(label,setup_sql,state,code,field) loop
    begin
      execute probe.setup_sql;
      perform pg_temp.checked(sql,probe.state,probe.code,probe.field);
      raise exception using errcode='Z0001',message='F2RV restore isolated source refusal';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'full isolated source probe restored: '||probe.label);
  end loop;

  -- Immutable event provenance cannot be forged even by fixture owner DML.
  -- Assert the real trigger's rejection; do NOT disable it to create false history.
  for probe in select * from (values
    (format('update economics_v2.group_occupancy_events set reason=''{}'' where id=%L',event_a)),
    (format('delete from economics_v2.group_occupancy_events where id=%L',event_a))) v(sql) loop
    state:=null;
    message:=null;
    begin
      execute probe.sql;
    exception when others then
      get stacked diagnostics state=returned_sqlstate,message=message_text;
    end;
    perform pg_temp.check_true(state='23514' and message='Group economics history is immutable',
      'durable provenance tampering refused by existing immutable trigger');
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'immutable event full rows preserved');
  end loop;

  for actor in select * from (values
    (f.owner_a,'authenticated'),(f.editor_a,'authenticated'),
    (f.viewer_a,'authenticated'),(null::uuid,'anon')) v(id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    if actor.id in(f.owner_a,f.editor_a) then
      r:=pg_temp.checked(sql);
      perform pg_temp.check_true(r->>'actor_id'=actor.id::text,'actual trusted owner/editor validation preserves actor');
    else
      perform pg_temp.checked(sql,'42501','forbidden','granja_id');
    end if;
    perform pg_temp.checked(format('select economics_v2.validate_disposed_group_meat_reactivation_source(%L,%L,%L,current_date-1,%L,%L,false)',
      f.farm_a,f.animal_a,event_a,f.destination_new,f.other_meat),'42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);

  select * into proc from pg_proc where oid=
    'economics_v2.validate_disposed_group_meat_reactivation_source(uuid,uuid,uuid,date,uuid,uuid,boolean)'::regprocedure;
  perform pg_temp.check_true(proc.prorettype='jsonb'::regtype and not proc.prosecdef
    and proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(proc.proacl,acldefault('f',proc.proowner))) acl
      where acl.grantee=0 and acl.privilege_type='EXECUTE')
    and not has_function_privilege('anon',proc.oid,'EXECUTE')
    and not has_function_privilege('authenticated',proc.oid,'EXECUTE'),'private invoker empty path and all client execute denied');
  perform pg_temp.checked('with attempt as (update public.animales set activo=activo where false returning id)
    select to_jsonb(attempt) from attempt','P0001');
  perform pg_temp.check_true((select count(*)=13 from pg_trigger where tgname='f2rv_no_write'),
    'all10 plus animal/baja/sale statement blockers');
  set constraints all immediate;
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'all business rows exactly unchanged after validation proof');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_memberships m
    join economics_v2.group_occupancy_periods p on p.id=m.period_id
    where m.granja_id=f.farm_a and not(m.position_span<@p.position_span)),
    'forced membership containment; no reopened historical span');
  perform pg_temp.check_true(not exists(select 1 from pg_temp.original_entries o where not exists(
    select 1 from economics_v2.group_acquisition_basis_entries b where to_jsonb(b)=o.full_row))
    and (select sum(signed_amount)=300 from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a)
    and (select count(*)=5 from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a),
    'all original signed rows preserved; old realized300 retained and no new acquisition charge');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_animal_acquisition_basis b
    join pg_temp.disposed_rows d using(animal_id) where to_jsonb(b)<>d.basis)
    and exists(select 1 from public.animales where id=f.animal_a and costo_adquisicion=999 and activo=false),
    'disposed pointer/version/capture unchanged; mutable public999 irrelevant');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_events
    where granja_id=f.farm_a and action in('reactivate','delete','transfer','purpose_change'))
    and not exists(select 1 from economics_v2.group_meat_snapshots where granja_id=f.farm_a)
    and not exists(select 1 from public.bajas_animales where granja_id=f.farm_a)
    and not exists(select 1 from public.venta_animal where granja_id=f.farm_a),
    'validation only: no accounting reactivation, other disposition, sale, baja or F5');
end;
$proof$;

-- PASS requires the real validator and the FULL runtime proof, never a caught missing call.
select jsonb_build_object('result','group_economics_forward_reactivation_source_validation_pass',
  'assertion_count',(select count(*) from assertions),'validator_write_free',true,
  'reactivation_performed',false,'locking_evidence','sequential_only',
  'production_gateway_integrated',false,'zero_basis_movement_compatibility_proven',false,
  'fixture_ids',(select to_jsonb(ids) from ids)) as evidence;
rollback;
