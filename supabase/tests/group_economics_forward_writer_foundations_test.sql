begin;

create temp table fixture_ids as
select gen_random_uuid() owner_a, gen_random_uuid() owner_b, gen_random_uuid() editor_a,
  gen_random_uuid() viewer_a, gen_random_uuid() farm_a, gen_random_uuid() farm_b,
  gen_random_uuid() type_a, gen_random_uuid() type_b, gen_random_uuid() purpose_a,
  gen_random_uuid() purpose_b, gen_random_uuid() group_a, gen_random_uuid() group_a2,
  gen_random_uuid() group_b, gen_random_uuid() animal_a, gen_random_uuid() animal_a2,
  gen_random_uuid() animal_b, gen_random_uuid() period_a, gen_random_uuid() period_b,
  gen_random_uuid() period_closed, gen_random_uuid() operation_a;
create temp table assertions (id integer generated always as identity);
create function pg_temp.check_true(p_ok boolean, p_label text) returns void language plpgsql as $$
begin
  if p_ok is distinct from true then raise exception '%', p_label; end if;
  insert into pg_temp.assertions default values;
end;
$$;
create function pg_temp.expect_error(p_sql text, p_state text, p_code text) returns void language plpgsql as $$
declare v_state text; v_detail text;
begin
  begin execute p_sql;
  exception when others then
    get stacked diagnostics v_state=returned_sqlstate, v_detail=pg_exception_detail;
    perform pg_temp.check_true(v_state=p_state, format('expected %s got %s: %s',p_state,v_state,p_sql));
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb @> jsonb_build_object(
        'contract_version','group-economics.forward.v3','code',p_code)
        and v_detail::jsonb ?& array['field','entity_id'], 'typed error detail');
    end if;
    return;
  end;
  raise exception 'Expected error: %',p_sql;
end;
$$;
select pg_temp.check_true(not exists(select 1 from auth.users where raw_user_meta_data->>'fixture'='f2a-private-foundations')
  and not exists(select 1 from public.granjas where nombre like 'F2A %'),'fixture baseline empty');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"f2a-private-foundations"}'::jsonb
from fixture_ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F2A farm A',owner_a from fixture_ids union all
select farm_b,owner_b,'F2A farm B',owner_b from fixture_ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from fixture_ids union all
select farm_a,viewer_a,'viewer'::public.rol_miembro from fixture_ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from fixture_ids union all select farm_b,true from fixture_ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F2A type A',owner_a from fixture_ids union all
select type_b,farm_b,'F2A type B',owner_b from fixture_ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select purpose_a,farm_a,'F2A meat A','carne',owner_a from fixture_ids union all
select purpose_b,farm_b,'F2A meat B','carne',owner_b from fixture_ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_a,farm_a,type_a,'F2A group A',owner_a from fixture_ids union all
select group_a2,farm_a,type_a,'F2A group A2',owner_a from fixture_ids union all
select group_b,farm_b,type_b,'F2A group B',owner_b from fixture_ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,fecha_adquisicion,costo_adquisicion,created_by)
select animal_a,farm_a,type_a,group_a,current_date-5,0,owner_a from fixture_ids union all
select animal_a2,farm_a,type_a,group_a2,current_date-5,300,owner_a from fixture_ids union all
select animal_b,farm_b,type_b,group_b,current_date-5,0,owner_b from fixture_ids;
insert into economics_v2.group_occupancy_periods(id,granja_id,group_id,purpose_id,starts_on,start_position,end_position,closed_on)
select period_a,farm_a,group_a,purpose_a,current_date-3,10,null::bigint,null::date from fixture_ids union all
select period_b,farm_b,group_b,purpose_b,current_date-3,10,null::bigint,null::date from fixture_ids union all
select period_closed,farm_a,group_a,purpose_a,current_date-5,1,5,current_date-4 from fixture_ids;
insert into economics_v2.group_occupancy_events(granja_id,period_id,animal_id,effective_on,action,event_position,reason)
select farm_a,period_a,animal_a,current_date-1,'enter',10,'f2a-private-foundations' from fixture_ids;
set constraints all immediate;

-- The first missing-helper call is behavioral RED, not a caught harness failure.
select set_config('request.jwt.claim.sub',owner_a::text,true) from fixture_ids;
select economics_v2.assert_group_writer_actor(farm_a) from fixture_ids;

-- This test-only definer is rolled back; no deployed client gateway is added.
create function pg_temp.invoke(p_kind text,p_farm uuid,p_groups uuid[],p_animals uuid[],
  p_periods uuid[],p_date date,p_operation uuid,p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if p_kind='scope' then
    return economics_v2.lock_group_writer_scope(p_farm,p_groups,p_animals,p_periods,p_date);
  elsif p_kind='prepare' then
    return economics_v2.prepare_group_operation(p_farm,p_operation,p_request);
  end if;
  return to_jsonb(economics_v2.assert_group_writer_actor(p_farm));
end;
$$;
do $grants$ begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
  execute format('grant usage on all sequences in schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end; $grants$;
grant select,insert on pg_temp.assertions to authenticated,anon;
create temp table requests as select f.*,jsonb_build_object('action','transfer','animal_id',animal_a,
  'source_period_id',period_a,'destination_group_id',group_a2,'destination_purpose_id',purpose_a,
  'sale_id',null,'effective_on',current_date,'payload','{"amount":1.00,"nested":[0.0]}'::jsonb) request from fixture_ids f;
do $proof$
declare f record; r jsonb; r2 jsonb; q jsonb; bad record; user_id uuid; helper record;
begin
  select * into f from pg_temp.requests;
  r:=economics_v2.lock_group_writer_scope(f.farm_a,array[f.group_a2,f.group_a],
    array[f.animal_a2,f.animal_a],array[f.period_a],current_date);
  r2:=economics_v2.lock_group_writer_scope(f.farm_a,array[f.group_a,f.group_a2,f.group_a],
    array[f.animal_a,f.animal_a2],array[f.period_a],current_date);
  perform pg_temp.check_true(r=r2 and r->>'actor_id'=f.owner_a::text,'deterministic sequential scope locks');
  perform pg_temp.check_true(r->'group_ids'=(select jsonb_agg(id order by id) from unnest(array[f.group_a,f.group_a2]) id)
    and r->'animal_ids'=(select jsonb_agg(id order by id) from unnest(array[f.animal_a,f.animal_a2]) id),'ascending lock recipe');
  perform pg_temp.check_true(exists(select 1 from pg_locks where pid=pg_backend_pid()
    and locktype='advisory' and granted),'transaction advisory lock held');
  perform pg_temp.check_true(economics_v2.lock_group_writer_scope(f.farm_a,array[]::uuid[],
    array[f.animal_a],array[f.period_a],current_date-1)->>'actor_id'=f.owner_a::text,'latest event date accepted');
  r:=economics_v2.prepare_group_operation(f.farm_a,f.operation_a,f.request);
  perform pg_temp.check_true(r->>'replayed'='false' and r->'result'='null'::jsonb,'absent operation is preparation only');
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result)
  values(f.farm_a,f.operation_a,r->>'payload_hash','{"immutable":[1,2],"replayed":false}'::jsonb);
  q:=jsonb_set(f.request,'{payload}','{"nested":[0],"amount":1}'::jsonb);
  r2:=economics_v2.prepare_group_operation(f.farm_a,f.operation_a,q);
  perform pg_temp.check_true(r2->'result'='{"immutable":[1,2],"replayed":true}'::jsonb
    and r2->>'payload_hash'=r->>'payload_hash','semantic numeric/key equality and stored result replay');
  for bad in select key,value from jsonb_each(jsonb_build_object('action','exit','source_period_id',f.period_closed,
    'destination_group_id',f.group_a,'destination_purpose_id',f.purpose_b,'sale_id',gen_random_uuid(),
    'effective_on',current_date-1,'payload','{"amount":2}'::jsonb,'animal_id',f.animal_a2)) loop
    perform pg_temp.expect_error(format('select economics_v2.prepare_group_operation(%L,%L,%L::jsonb)',
      f.farm_a,f.operation_a,jsonb_set(f.request,array[bad.key],bad.value)),'22023','operation_payload_conflict');
  end loop;
  for bad in select * from (values
    (null::uuid,'{}'::jsonb),(gen_random_uuid(),null::jsonb),(gen_random_uuid(),f.request-'sale_id'),
    (gen_random_uuid(),jsonb_set(f.request,'{animal_id}','null')),
    (gen_random_uuid(),'[]'::jsonb),
    (gen_random_uuid(),jsonb_set(f.request,'{effective_on}',to_jsonb(current_date+1))),
    (gen_random_uuid(),jsonb_set(f.request,'{source_period_id}','"invalid-uuid"')))
    v(operation_id,request) loop
    perform pg_temp.expect_error(format('select economics_v2.prepare_group_operation(%L,%L,%L::jsonb)',
      f.farm_a,bad.operation_id,bad.request),'22023','invalid_request');
  end loop;
  for bad in select * from (values
    (null::uuid,array[]::uuid[],array[]::uuid[],array[]::uuid[],current_date,'22023','invalid_request'),
    (f.farm_a,null::uuid[],array[]::uuid[],array[]::uuid[],current_date,'22023','invalid_request'),
    (f.farm_a,array[null::uuid],array[]::uuid[],array[]::uuid[],current_date,'22023','invalid_request'),
    (f.farm_a,array[f.group_b],array[]::uuid[],array[]::uuid[],current_date,'42501','forbidden'),
    (f.farm_a,array[gen_random_uuid()],array[]::uuid[],array[]::uuid[],current_date,'42501','forbidden'),
    (f.farm_a,array[]::uuid[],array[f.animal_b],array[]::uuid[],current_date,'42501','forbidden'),
    (f.farm_a,array[]::uuid[],array[gen_random_uuid()],array[]::uuid[],current_date,'42501','forbidden'),
    (f.farm_a,array[]::uuid[],array[]::uuid[],array[f.period_b],current_date,'42501','forbidden'),
    (f.farm_a,array[]::uuid[],array[]::uuid[],array[gen_random_uuid()],current_date,'42501','forbidden'),
    (f.farm_a,array[]::uuid[],array[]::uuid[],array[f.period_closed],current_date,'23514','closed_period_immutable'),
    (f.farm_a,array[]::uuid[],array[]::uuid[],array[f.period_a],current_date-4,'22023','invalid_request'),
    (f.farm_a,array[]::uuid[],array[f.animal_a],array[f.period_a],current_date-2,'22023','invalid_request'),
    (f.farm_a,array[]::uuid[],array[]::uuid[],array[]::uuid[],null::date,'22023','invalid_request'),
    (f.farm_a,array[]::uuid[],array[]::uuid[],array[]::uuid[],current_date+1,'22023','invalid_request'))
    v(farm,groups,animals,periods,effective_on,state,code) loop
    perform pg_temp.expect_error(format('select economics_v2.lock_group_writer_scope(%L,%L::uuid[],%L::uuid[],%L::uuid[],%L::date)',
      bad.farm,bad.groups,bad.animals,bad.periods,bad.effective_on),bad.state,bad.code);
  end loop;
  perform pg_temp.expect_error('select economics_v2.assert_group_writer_actor(null)','22023','invalid_request');
  perform pg_temp.expect_error('select economics_v2.assert_group_writer_actor(gen_random_uuid())','42501','forbidden');
  foreach user_id in array array[f.owner_a,f.editor_a] loop
    perform set_config('request.jwt.claim.sub',user_id::text,true);
    set local role authenticated;
    perform pg_temp.check_true(pg_temp.invoke('actor',f.farm_a,null,null,null,null,null,null)=to_jsonb(user_id),'trusted invoker preserves JWT actor');
    reset role;
  end loop;
  perform pg_temp.expect_error(format('select economics_v2.prepare_group_operation(%L,%L,%L::jsonb)',
    f.farm_a,f.operation_a,f.request),'22023','operation_payload_conflict');
  perform set_config('request.jwt.claim.sub',f.viewer_a::text,true);
  set local role authenticated;
  perform pg_temp.expect_error(format('select pg_temp.invoke(''actor'',%L,null,null,null,null,null,null)',f.farm_a),'42501','forbidden');
  reset role;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform pg_temp.expect_error(format('select economics_v2.assert_group_writer_actor(%L)',f.farm_b),'42501','forbidden');
  update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
  perform pg_temp.expect_error(format('select economics_v2.assert_group_writer_actor(%L)',f.farm_a),'42501','forbidden');
  update economics_v2.feature_flags set economics_v2_enabled=true where granja_id=f.farm_a;
  perform set_config('request.jwt.claim.sub','',true);
  set local role anon;
  perform pg_temp.expect_error(format('select pg_temp.invoke(''actor'',%L,null,null,null,null,null,null)',f.farm_a),'42501','forbidden');
  reset role;
  for helper in select p.oid,p.proname,p.prosecdef,p.proconfig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='economics_v2' and p.proname in ('raise_group_writer_error','assert_group_writer_actor',
      'canonical_group_request','lock_group_writer_scope','prepare_group_operation') loop
    perform pg_temp.check_true(not helper.prosecdef and helper.proconfig @> array['search_path=""']
      and not has_function_privilege('public',helper.oid,'execute')
      and not has_function_privilege('authenticated',helper.oid,'execute')
      and not has_function_privilege('anon',helper.oid,'execute'),'private invoker ACL/path');
  end loop;
  foreach user_id in array array[f.owner_a,null::uuid] loop
    perform set_config('request.jwt.claim.sub',coalesce(user_id::text,''),true);
    if user_id is null then set local role anon; else set local role authenticated; end if;
    perform pg_temp.expect_error(format('select economics_v2.assert_group_writer_actor(%L)',f.farm_a),'42501',null);
    perform pg_temp.expect_error(format('select economics_v2.prepare_group_operation(%L,%L,%L::jsonb)',f.farm_a,f.operation_a,f.request),'42501',null);
    perform pg_temp.expect_error(format('select economics_v2.lock_group_writer_scope(%L,''{}'',''{}'',''{}'',current_date)',f.farm_a),'42501',null);
    perform pg_temp.expect_error('select economics_v2.canonical_group_request(''{}'')','42501',null);
    perform pg_temp.expect_error('select economics_v2.raise_group_writer_error(''22023'',''invalid_request'',null,null)','42501',null);
    reset role;
  end loop;
  perform pg_temp.check_true((select count(*) from economics_v2.group_occupancy_operations where granja_id=f.farm_a)=1
    and (select result from economics_v2.group_occupancy_operations where granja_id=f.farm_a)='{"immutable":[1,2],"replayed":false}'::jsonb,
    'preparation never changes the stored operation');
  perform pg_temp.check_true((select count(*) from economics_v2.group_occupancy_events where granja_id=f.farm_a)=1
    and not exists(select 1 from economics_v2.group_animal_acquisition_basis where granja_id=f.farm_a)
    and not exists(select 1 from economics_v2.group_meat_snapshots where granja_id=f.farm_a),'no business writes');
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_writer_foundations_pass',
  'assertion_count',(select count(*) from assertions),'locking_evidence','sequential_only') as evidence;
rollback;
