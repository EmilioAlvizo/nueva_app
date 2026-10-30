begin;

-- HUMAN sandbox Dashboard: save/run the FULL BEGIN/ROLLBACK file; report the first error.
-- Expected first RED: 42883 at the seven-argument NEW validator, before implementation.
-- Complete-unit forecast: fixture <=450 + future private validator <=320 = <=770 lines.
-- Real original300 per animal -> ordinary exit -> reactivation -> ONE transfer -> OUT.
-- Every earlier shared-period phase finishes before the next later-dated phase starts.
-- The validator takes identities only: never caller receipts, old actor claims or guessed metadata.
-- TRUE additionally proves current holding; FALSE proves immutable history, NOT current eligibility.
-- Both modes authorize the actual CURRENT owner/editor. Neither impersonates a historical actor.
-- Context is exact14 server-read data, never an authorization token or persisted operation.
-- Public group/purpose can already be staged for RETURN; active/baja/farm/type checks still apply in TRUE.
-- Future RETURN must prepare replay first, lock mutable destination/public/basis scope, independently
-- call TRUE after caller DML in the SAME TX and recheck destination pins. No supplied context is accepted.
-- This fixture implements no RETURN, repeated movement, public RPC, closure or concurrency proof.
-- All mutations/triggers below are isolated fixture setup/probes, not validator permissions.
create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,gen_random_uuid() type_b,
  gen_random_uuid() meat,gen_random_uuid() eggs,gen_random_uuid() foreign_purpose,
  gen_random_uuid() historical_group,gen_random_uuid() reactivated_group,gen_random_uuid() transferred_group,
  gen_random_uuid() staged_group,gen_random_uuid() foreign_group,gen_random_uuid() animal_a,gen_random_uuid() animal_b,
  gen_random_uuid() historical_anchor,gen_random_uuid() reactivated_anchor,gen_random_uuid() transferred_anchor,
  gen_random_uuid() exit_a,gen_random_uuid() exit_b,gen_random_uuid() reactivate_a,gen_random_uuid() reactivate_b,
  gen_random_uuid() transfer_a,gen_random_uuid() transfer_b,gen_random_uuid() out_a,gen_random_uuid() out_b;
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
  if current_setting('f2hv.no_write',true)='on' then
    raise exception using errcode='P0001',message='F2HV unexpected validator DML';
  end if;
  return null;
end;
$$;
-- Statement blockers catch attempted DML even if it would affect zero rows or later roll back.
do $blockers$
declare t record;
begin
  for t in select * from pg_temp.watched_tables loop
    execute format('create trigger f2hv_no_write before insert or update or delete on %I.%I
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
  perform set_config('f2hv.no_write','on',true);
  begin
    execute p_sql into result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics state=returned_sqlstate,detail=pg_exception_detail;
  end;
  perform set_config('f2hv.no_write','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'all rows unchanged: '||p_sql);
  perform pg_temp.check_true(pg_temp.position_state()=before_seq,'sequence unchanged: '||p_sql);
  if p_state is null then
    perform pg_temp.check_true(result is not null,'nonempty validation context');
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

-- Fixture-only trusted orchestration. Every history row is written by a qualified real core.
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
      'destination_purpose_id',null,'sale_id',null,'effective_on',current_date-4,'payload',payload));
    context:=economics_v2.validate_group_meat_nonclosing_source(f.farm_a,p_animal,current_date-4);
    update public.animales set activo=false where granja_id=f.farm_a and id=p_animal and activo and baja_id is null;
    if not found then raise exception 'F2HV exit caller failed'; end if;
    exited:=economics_v2.exit_group_meat_nonclosing(f.farm_a,p_exit,p_animal,current_date-4,payload);
    prepared:=economics_v2.prepare_group_operation(f.farm_a,p_reactivation,jsonb_build_object(
      'action','reactivate','animal_id',p_animal,'source_period_id',null,'destination_group_id',f.reactivated_group,
      'destination_purpose_id',f.meat,'sale_id',null,'effective_on',current_date-3,
      'payload',jsonb_build_object('provenance_version','group-reactivation-provenance.v1',
        'disposition_kind','ordinary_reactivation','disposed_event_id',exited->'membership_event_ids'->0,'actor_id',actor,'metadata','{}'::jsonb)));
    context:=economics_v2.validate_disposed_group_meat_reactivation_source(f.farm_a,p_animal,
      (exited->'membership_event_ids'->>0)::uuid,current_date-3,f.reactivated_group,f.meat,false);
    update public.animales set activo=true,grupo_id=f.reactivated_group where granja_id=f.farm_a and id=p_animal and not activo;
    if not found then raise exception 'F2HV restore caller failed'; end if;
    return economics_v2.reactivate_disposed_group_meat(f.farm_a,p_reactivation,p_animal,
      current_date-3,f.reactivated_group,f.meat,(exited->'membership_event_ids'->>0)::uuid,'{}');
  elsif p_phase=1 then
    select result into activated from economics_v2.group_occupancy_operations
      where granja_id=f.farm_a and operation_id=p_reactivation;
    select id into source from economics_v2.group_occupancy_periods where granja_id=f.farm_a
      and group_id=f.transferred_group and purpose_id=f.meat and end_position is null;
    context:=economics_v2.lock_group_writer_scope(f.farm_a,array[f.reactivated_group,f.transferred_group],array[p_animal],
      array[(activated->>'destination_period_id')::uuid]||case when source is null then '{}'::uuid[] else array[source] end,current_date-2);
    update public.animales set grupo_id=f.transferred_group where granja_id=f.farm_a and id=p_animal and activo;
    if not found then raise exception 'F2HV transfer caller failed'; end if;
    return economics_v2.transfer_reactivated_group_meat_nonclosing(
      f.farm_a,p_transfer,p_animal,current_date-2,f.transferred_group,f.meat,p_reactivation,'{}');
  elsif p_phase=2 then
    select period_id into source from economics_v2.group_occupancy_memberships
      where granja_id=f.farm_a and animal_id=p_animal and end_position is null;
    context:=economics_v2.lock_group_writer_scope(f.farm_a,array[f.transferred_group],array[p_animal],array[source],current_date-1);
    update public.animales set proposito_id=f.eggs where granja_id=f.farm_a and id=p_animal and activo;
    if not found then raise exception 'F2HV OUT caller failed'; end if;
    return economics_v2.move_transferred_reactivated_meat_to_holding_nonclosing(
      f.farm_a,p_out,p_animal,current_date-1,f.transferred_group,f.eggs,p_reactivation,p_transfer,'{}');
  end if;
  raise exception 'F2HV invalid setup phase';
end;
$$;
create function pg_temp.validate_history(p_farm uuid,p_animal uuid,p_reactivation uuid,p_transfer uuid,p_out uuid,
  p_date date,p_require_current_holding boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  -- No actor substitution, public DML, supplied context or operation preparation in this wrapper.
  -- FIRST intended NEW call: exact typed signature; missing-function error must escape.
  return economics_v2.validate_reactivated_holding_history(
    p_farm,p_animal,p_reactivation,p_transfer,p_out,p_date,p_require_current_holding);
end;
$$;

select pg_temp.check_true(not exists(select 1 from auth.users
  where raw_user_meta_data->>'fixture'='holding-history-validation'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"holding-history-validation"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F2HV farm A',owner_a from ids union all select farm_b,owner_b,'F2HV farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F2HV type A',owner_a from ids union all select type_b,farm_b,'F2HV type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat,farm_a,'F2HV meat','carne',owner_a from ids union all select eggs,farm_a,'F2HV eggs','postura',owner_a from ids
union all select foreign_purpose,farm_b,'F2HV foreign purpose','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'F2HV group '||g::text,owner_a from ids
cross join lateral unnest(array[historical_group,reactivated_group,transferred_group,staged_group]) g
union all select foreign_group,farm_b,type_b,'F2HV foreign group',owner_b from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,notas,created_by)
select a,farm_a,type_a,case when a=reactivated_anchor then reactivated_group
  when a=transferred_anchor then transferred_group else historical_group end,meat,current_date-7,
  case when a in(animal_a,animal_b) then 300 else 0 end,'F2HV animal',owner_a
from ids cross join lateral unnest(array[animal_a,animal_b,historical_anchor,reactivated_anchor,transferred_anchor]) a;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
create temp table initial as select a animal_id,economics_v2.enter_group_meat_initial(farm_a,gen_random_uuid(),a,current_date-6,
  case when a=reactivated_anchor then reactivated_group when a=transferred_anchor then transferred_group else historical_group end,meat,'{}') result
from ids cross join lateral unnest(array[animal_a,animal_b,historical_anchor,reactivated_anchor,transferred_anchor]) a;
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
set constraints all immediate;
set constraints all deferred;
select pg_temp.check_true((select count(*)=2 and bool_and(initial_basis=300 and source_cost=300 and remaining_basis=0
  and status='active' and current_account_kind='holding' and current_period_id is null and disposed_event_id is null and version=4)
  from economics_v2.group_animal_acquisition_basis where animal_id in(select animal_a from ids union all select animal_b from ids)),
  'REAL initial300/exit/reactivation/ONE transfer/OUT produced holding0, never fabricated');
do $grants$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$grants$;
grant execute on function pg_temp.validate_history(uuid,uuid,uuid,uuid,uuid,date,boolean),
  pg_temp.checked(text,text,text,text),pg_temp.check_true(boolean,text),pg_temp.business_state(),pg_temp.position_state() to authenticated,anon;
create temp table contexts(animal_id uuid,result jsonb);
do $first$
declare f record; result jsonb; baseline jsonb; before_seq jsonb;
begin
  select * into f from pg_temp.ids;
  baseline:=pg_temp.business_state();
  before_seq:=pg_temp.position_state();
  perform set_config('f2hv.no_write','on',true);
  set local role authenticated;
  result:=pg_temp.validate_history(f.farm_a,f.animal_a,f.reactivate_a,f.transfer_a,f.out_a,current_date,true);
  reset role;
  perform set_config('f2hv.no_write','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=baseline and pg_temp.position_state()=before_seq,'first validator read is write/sequence free');
  insert into pg_temp.contexts values(f.animal_a,result);
end;
$first$;

do $proof$
declare f record; r jsonb; repeated jsonb; sql text; history_sql text; baseline jsonb;
  probe record; actor record; control record; proc record; mode text;
begin
  select * into f from pg_temp.ids;
  select result into r from pg_temp.contexts where animal_id=f.animal_a;
  sql:=format('select pg_temp.validate_history(%L,%L,%L,%L,%L,current_date,true)',
    f.farm_a,f.animal_a,f.reactivate_a,f.transfer_a,f.out_a);
  history_sql:=replace(sql,'current_date,true','current_date,false');
  repeated:=pg_temp.checked(sql);
  perform pg_temp.check_true(repeated=r,'repeated validation has no replay ledger or sequence side effect');
  repeated:=pg_temp.checked(history_sql);
  perform pg_temp.check_true(repeated=r||'{"require_current_holding":false}'::jsonb,'history-only context does not claim current eligibility');
  for actor in select * from (values(f.editor_a,'authenticated'),(f.owner_b,'authenticated'),
    (f.viewer_a,'authenticated'),(null::uuid,'anon')) v(id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    if actor.id=f.editor_a then
      repeated:=pg_temp.checked(sql);
      perform pg_temp.check_true(repeated=r||jsonb_build_object('actor_id',f.editor_a),'editor validates owner-written history without impersonation');
      repeated:=pg_temp.checked(history_sql);
      perform pg_temp.check_true(repeated=r||jsonb_build_object('actor_id',f.editor_a,'require_current_holding',false),'history-only independently authorizes actual editor');
    elsif actor.id=f.owner_b then
      perform pg_temp.checked(sql,'42501','forbidden','granja_id');
      perform pg_temp.checked(format('select pg_temp.validate_history(%L,%L,%L,%L,%L,current_date,true)',
        f.farm_b,f.animal_a,f.reactivate_a,f.transfer_a,f.out_a),'42501','forbidden','animal_id');
      perform pg_temp.checked(format('select pg_temp.validate_history(%L,%L,%L,%L,%L,current_date,false)',
        f.farm_b,f.animal_a,f.reactivate_a,f.transfer_a,f.out_a),'42501','forbidden','animal_id');
    else
      perform pg_temp.checked(sql,'42501','forbidden','granja_id');
      perform pg_temp.checked(history_sql,'42501','forbidden','granja_id');
    end if;
    perform pg_temp.checked('select economics_v2.validate_reactivated_holding_history(
      null::uuid,null::uuid,null::uuid,null::uuid,null::uuid,null::date,null::boolean)','42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  for probe in select * from (values
    (f.farm_b,f.animal_a,f.reactivate_a,f.transfer_a,f.out_a,current_date,true,'42501','forbidden','granja_id'),
    (f.farm_a,f.animal_b,f.reactivate_a,f.transfer_a,f.out_a,current_date,true,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_a,f.reactivate_b,f.transfer_a,f.out_a,current_date,true,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_a,f.reactivate_a,f.transfer_b,f.out_a,current_date,true,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_a,f.reactivate_a,f.transfer_a,f.out_b,current_date,true,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.reactivated_anchor,f.reactivate_a,f.transfer_a,f.out_a,current_date,true,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_a,null::uuid,f.transfer_a,f.out_a,current_date,true,'22023','invalid_request','reactivation_operation_id'),
    (f.farm_a,f.animal_a,f.reactivate_a,null::uuid,f.out_a,current_date,true,'22023','invalid_request','transfer_operation_id'),
    (f.farm_a,f.animal_a,f.reactivate_a,f.transfer_a,null::uuid,current_date,true,'22023','invalid_request','out_operation_id'),
    (f.farm_a,f.animal_a,f.reactivate_a,f.transfer_a,f.out_a,current_date,null::boolean,'22023','invalid_request','require_current_holding'),
    (f.farm_a,null::uuid,f.reactivate_a,f.transfer_a,f.out_a,current_date,true,'22023','invalid_request','animal_id'),
    (f.farm_a,f.animal_a,f.reactivate_a,f.transfer_a,f.out_a,null::date,true,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_a,f.reactivate_a,f.transfer_a,f.out_a,'infinity'::date,true,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_a,f.reactivate_a,f.transfer_a,f.out_a,current_date+1,true,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_a,f.reactivate_a,f.transfer_a,f.out_a,current_date-2,true,'22023','invalid_request','effective_on'))
    v(farm,animal,reactivation,transfer,out_op,effective_on,require_holding,state,code,field) loop
    perform pg_temp.checked(format('select pg_temp.validate_history(%L,%L,%L,%L,%L,%L::date,%L::boolean)',
      probe.farm,probe.animal,probe.reactivation,probe.transfer,probe.out_op,probe.effective_on,probe.require_holding),probe.state,probe.code,probe.field);
  end loop;
  -- Every corruption is a bounded fixture subtransaction; original rows are restored exactly.
  for mode in select unnest(array['capture','exit_receipt','reactivation_hash','transfer_receipt','out_receipt','out_pair']) loop
    baseline:=pg_temp.business_state();
    begin
      case mode
        when 'capture' then update economics_v2.group_animal_acquisition_basis set source_cost=301 where animal_id=f.animal_a;
        when 'exit_receipt' then update economics_v2.group_occupancy_operations set result='{}' where operation_id=f.exit_a;
        when 'reactivation_hash' then update economics_v2.group_occupancy_operations set payload_hash='f2hv-corrupt' where operation_id=f.reactivate_a;
        when 'transfer_receipt' then update economics_v2.group_occupancy_operations set result='{}' where operation_id=f.transfer_a;
        when 'out_receipt' then update economics_v2.group_occupancy_operations set result='{}' where operation_id=f.out_a;
        when 'out_pair' then update economics_v2.group_acquisition_basis_entries set entry_pair_id=gen_random_uuid()
          where operation_id=f.out_a and account_kind='holding';
      end case;
      perform pg_temp.checked(sql,'23514','invariant_violation',case when mode='reactivation_hash' then 'operation_id' else 'animal_id' end);
      perform pg_temp.checked(history_sql,'23514','invariant_violation',case when mode='reactivation_hash' then 'operation_id' else 'animal_id' end);
      raise exception using errcode='Z0001',message='F2HV restore history corruption';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'full history corruption restored: '||mode);
  end loop;
  for mode in select unnest(array['version','remaining','status','account','open_member','inactive','public_farm']) loop
    baseline:=pg_temp.business_state();
    begin
      case mode
        when 'version' then update economics_v2.group_animal_acquisition_basis set version=version+1 where animal_id=f.animal_a;
        when 'remaining' then update economics_v2.group_animal_acquisition_basis set remaining_basis=1 where animal_id=f.animal_a;
        when 'status' then update economics_v2.group_animal_acquisition_basis set status='disposed' where animal_id=f.animal_a;
        when 'account' then update economics_v2.group_animal_acquisition_basis set current_account_kind='period',
          current_period_id=(select (result->>'source_period_id')::uuid from pg_temp.setup_receipts where phase=2 and animal_id=f.animal_a)
          where animal_id=f.animal_a;
        when 'open_member' then
          -- Deliberately contradictory current-state probe, never evidence of an actual RETURN.
          insert into economics_v2.group_occupancy_memberships(granja_id,period_id,animal_id,start_position)
            select f.farm_a,(result->>'source_period_id')::uuid,f.animal_a,(result->>'event_position')::bigint+1
            from pg_temp.setup_receipts where phase=2 and animal_id=f.animal_a;
        when 'inactive' then update public.animales set activo=false where id=f.animal_a;
        when 'public_farm' then update public.animales set proposito_id=f.foreign_purpose where id=f.animal_a;
      end case;
      if mode='public_farm' then
        perform pg_temp.checked(sql,'42501','forbidden','purpose_id');
      else
        perform pg_temp.checked(sql,'23514','invariant_violation','animal_id');
      end if;
      -- FALSE deliberately skips mutable eligibility; this is a corruption probe, NOT a RETURN.
      repeated:=pg_temp.checked(history_sql);
      perform pg_temp.check_true(repeated->'require_current_holding'='false'::jsonb,'history mode never claims holding eligibility');
      raise exception using errcode='Z0001',message='F2HV restore current-state probe';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'current-state probe fully restored: '||mode);
  end loop;
  baseline:=pg_temp.business_state();
  begin
    update public.animales set grupo_id=f.staged_group,proposito_id=f.meat where id=f.animal_a;
    repeated:=pg_temp.checked(sql);
    perform pg_temp.check_true(repeated->'public_animal'=(select to_jsonb(a) from public.animales a where id=f.animal_a)
      and repeated->'basis'=(select to_jsonb(b) from economics_v2.group_animal_acquisition_basis b where animal_id=f.animal_a),
      'TRUE supports post-caller public meat pins while actual basis is still holding0');
    raise exception using errcode='Z0001',message='F2HV restore staging probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'staging proof fully restored; no RETURN performed');
  begin
    update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
    perform pg_temp.checked(sql,'42501','forbidden','granja_id');
    perform pg_temp.checked(history_sql,'42501','forbidden','granja_id');
    raise exception using errcode='Z0001',message='F2HV restore feature flag';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'disabled farm probe restored');
  for control in select * from (values(f.animal_a,f.reactivate_a,f.transfer_a,f.out_a),
    (f.animal_b,f.reactivate_b,f.transfer_b,f.out_b)) v(animal,reactivation,transfer,out_op) loop
    repeated:=pg_temp.checked(format('select pg_temp.validate_history(%L,%L,%L,%L,%L,current_date,true)',
      f.farm_a,control.animal,control.reactivation,control.transfer,control.out_op));
    perform pg_temp.check_true(repeated=jsonb_build_object('context_version','group-holding-history-context.v1',
      'actor_id',f.owner_a,'granja_id',f.farm_a,'animal_id',control.animal,'effective_on',current_date,
      'reactivation_operation_id',control.reactivation,'transfer_operation_id',control.transfer,'out_operation_id',control.out_op,
      'require_current_holding',true,'basis',(select to_jsonb(b) from economics_v2.group_animal_acquisition_basis b where animal_id=control.animal),
      'out_event',(select to_jsonb(e) from economics_v2.group_occupancy_events e where operation_id=control.out_op),
      'out_result',(select result from pg_temp.setup_receipts where phase=2 and animal_id=control.animal),
      'historical_period_id',(select (result->>'source_period_id')::uuid from pg_temp.setup_receipts where phase=2 and animal_id=control.animal),
      'public_animal',(select to_jsonb(a) from public.animales a where id=control.animal))
      and (select count(*)=14 from jsonb_object_keys(repeated)),'exact14 reusable server-read context, not auth token');
  end loop;
  perform pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(f.farm_a,
    (select (result->>'destination_period_id')::uuid from pg_temp.initial where animal_id=f.animal_a)) @> '{"acquisition_cost":600,"active_animal_count":1}'::jsonb
    and (select count(*)=2 and bool_and(initial_basis=300 and source_cost=300 and remaining_basis=0 and version=4)
      from economics_v2.group_animal_acquisition_basis where animal_id in(f.animal_a,f.animal_b))
    and (select count(*)=13 and sum(signed_amount)=600 from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a)
    and (select count(*)=13 from economics_v2.group_occupancy_operations where granja_id=f.farm_a),
    'history/capture/realized600 preserved; validator persists no operation or new entries');
  select * into proc from pg_proc where oid=
    'economics_v2.validate_reactivated_holding_history(uuid,uuid,uuid,uuid,uuid,date,boolean)'::regprocedure;
  perform pg_temp.check_true(proc.prorettype='jsonb'::regtype and not proc.prosecdef and proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(proc.proacl,acldefault('f',proc.proowner))) acl where acl.grantee=0 and acl.privilege_type='EXECUTE')
    and not has_function_privilege('anon',proc.oid,'EXECUTE') and not has_function_privilege('authenticated',proc.oid,'EXECUTE'),'private invoker/empty path/client EXECUTE false');
  set constraints all immediate;
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_memberships m join economics_v2.group_occupancy_periods p on p.id=m.period_id
    where m.granja_id=f.farm_a and not(m.position_span<@p.position_span)),'forced containment of full ended history');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_meat_snapshots where granja_id=f.farm_a)
    and not exists(select 1 from public.bajas_animales where granja_id=f.farm_a)
    and not exists(select 1 from public.venta_animal where granja_id=f.farm_a),'no synthetic closure/sale/baja/RETURN');
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_holding_history_validation_pass',
  'assertion_count',(select count(*) from assertions),'locking_evidence','sequential_only','validator_write_free',true,
  'return_performed',false,'production_gateway_integrated',false,'independent_review','pending',
  'fixture_ids',(select to_jsonb(ids) from ids)) as evidence;
rollback;
