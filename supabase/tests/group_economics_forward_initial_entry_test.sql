begin;

create temp table ids as select gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor_a,gen_random_uuid() viewer_a,gen_random_uuid() farm_a,gen_random_uuid() farm_b,
  gen_random_uuid() type_a,gen_random_uuid() type_a2,gen_random_uuid() type_b,
  gen_random_uuid() purpose_a,gen_random_uuid() purpose_a2,gen_random_uuid() purpose_b,gen_random_uuid() purpose_egg,
  gen_random_uuid() group_a,gen_random_uuid() group_unknown,gen_random_uuid() group_wrong,gen_random_uuid() group_b,
  gen_random_uuid() animal_a,gen_random_uuid() animal_zero,gen_random_uuid() animal_unknown,
  gen_random_uuid() animal_pin,gen_random_uuid() animal_b,gen_random_uuid() op_a,gen_random_uuid() op_zero,gen_random_uuid() op_pin;
create temp table assertions(id integer generated always as identity);
create function pg_temp.check_true(p_ok boolean,p_label text) returns void language plpgsql as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions default values;
end;
$$;
create function pg_temp.expect_error(p_sql text,p_state text,p_code text,p_field text) returns void language plpgsql as $$
declare v_state text; v_detail text;
begin
  begin execute p_sql;
  exception when others then
    get stacked diagnostics v_state=returned_sqlstate,v_detail=pg_exception_detail;
    perform pg_temp.check_true(v_state=p_state,format('expected %s got %s: %s',p_state,v_state,p_sql));
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb @> jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field) and v_detail::jsonb ? 'entity_id','typed error');
    end if;
    return;
  end;
  raise exception 'Expected error: %',p_sql;
end;
$$;
select pg_temp.check_true(not exists(select 1 from auth.users where raw_user_meta_data->>'fixture'='f2b1-initial-entry')
  and not exists(select 1 from public.granjas where nombre like 'F2B1 %'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"f2b1-initial-entry"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F2B1 farm A',owner_a from ids union all select farm_b,owner_b,'F2B1 farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F2B1 type A',owner_a from ids union all select type_a2,farm_a,'F2B1 type A2',owner_a from ids union all
select type_b,farm_b,'F2B1 type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select purpose_a,farm_a,'F2B1 meat A','carne',owner_a from ids union all
select purpose_a2,farm_a,'F2B1 meat A2','carne',owner_a from ids union all
select purpose_b,farm_b,'F2B1 meat B','carne',owner_b from ids union all
select purpose_egg,farm_a,'F2B1 eggs','postura',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_a,farm_a,type_a,'F2B1 group A',owner_a from ids union all
select group_unknown,farm_a,type_a,'F2B1 unknown-cost group',owner_a from ids union all
select group_wrong,farm_a,type_a2,'F2B1 wrong-type group',owner_a from ids union all
select group_b,farm_b,type_b,'F2B1 group B',owner_b from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,notas,created_by)
select animal_a,farm_a,type_a,group_a,purpose_a,current_date-2,300,'F2B1 known',owner_a from ids union all
select animal_zero,farm_a,type_a,group_a,purpose_a,current_date-2,0,'F2B1 zero',owner_a from ids union all
select animal_unknown,farm_a,type_a,group_unknown,purpose_a,current_date-2,null::numeric,'F2B1 unknown',owner_a from ids union all
select animal_pin,farm_a,type_a,group_a,purpose_a2,current_date-2,0,'F2B1 other pin',owner_a from ids union all
select animal_b,farm_b,type_b,group_b,purpose_b,current_date-2,0,'F2B1 foreign',owner_b from ids;
set constraints all immediate;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
-- First real initial-entry call: expected missing-helper RED before implementation.
create temp table results as select economics_v2.enter_group_meat_initial(
  farm_a,op_a,animal_a,current_date,group_a,purpose_a,'{"probe":1.00}'::jsonb) first_result from ids;

-- The temporary gateway exercises trusted invocation without adding a deployed API.
create function pg_temp.entry(p_farm uuid,p_op uuid,p_animal uuid,p_date date,p_group uuid,p_purpose uuid,p_payload jsonb)
returns jsonb language sql security definer set search_path='' as $$
  select economics_v2.enter_group_meat_initial(p_farm,p_op,p_animal,p_date,p_group,p_purpose,p_payload);
$$;
do $grants$ begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
  execute format('grant usage on all sequences in schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end; $grants$;
grant select,insert on pg_temp.assertions to authenticated,anon;
create function pg_temp.reject_write() returns trigger language plpgsql as $$
begin raise exception 'unknown-cost check attempted a write'; end;
$$;
do $proof$
declare f record; a jsonb; z jsonb; p jsonb; replay jsonb; before_basis jsonb; bad record; table_name text; before_position bigint;
begin
  select * into f from pg_temp.ids;
  select first_result into a from pg_temp.results;
  perform pg_temp.check_true(a @> jsonb_build_object('contract_version','group-economics.forward.v3',
    'action','enter','animal_id',f.animal_a,'basis_before',0,'basis_after',300,'replayed',false),'exact initial result');
  perform pg_temp.check_true((select array_agg(k order by k) from jsonb_object_keys(a) k)=array[
    'action','animal_id','basis_after','basis_before','basis_entry_ids','contract_version','destination_period_id',
    'destination_start_position','destination_status','effective_on','event_position','membership_event_ids',
    'operation_id','replayed','snapshot_id','source_end_position','source_period_id','source_status','state_version'],'result key contract');
  select to_jsonb(b) into before_basis from economics_v2.group_animal_acquisition_basis b where animal_id=f.animal_a;
  perform pg_temp.check_true(before_basis @> jsonb_build_object('initial_basis',300,'remaining_basis',300,
    'source_cost',300,'status','active','current_account_kind','period','version',0)
    and before_basis->>'captured_at' is not null,'exact captured provenance');
  select last_value into before_position from economics_v2.group_economics_event_position_seq;
  foreach table_name in array array['group_occupancy_operations','group_occupancy_periods','group_occupancy_memberships',
    'group_occupancy_events','group_animal_acquisition_basis','group_acquisition_basis_entries',
    'group_period_feed_allocations','group_period_expenses','group_period_sale_bindings','group_meat_snapshots'] loop
    execute format('create trigger f2b1_cost_probe before insert or update or delete on economics_v2.%I for each row execute function pg_temp.reject_write()',table_name);
  end loop;
  perform pg_temp.expect_error(format('select pg_temp.entry(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,gen_random_uuid(),f.animal_unknown,f.group_unknown,f.purpose_a),'23514','incomplete_acquisition_basis','costo_adquisicion');
  foreach table_name in array array['group_occupancy_operations','group_occupancy_periods','group_occupancy_memberships',
    'group_occupancy_events','group_animal_acquisition_basis','group_acquisition_basis_entries',
    'group_period_feed_allocations','group_period_expenses','group_period_sale_bindings','group_meat_snapshots'] loop
    execute format('drop trigger f2b1_cost_probe on economics_v2.%I',table_name);
  end loop;
  perform pg_temp.check_true((select last_value from economics_v2.group_economics_event_position_seq)=before_position
    and not exists(select 1 from economics_v2.group_occupancy_periods where group_id=f.group_unknown),'unknown cost precedes every write and position issue');
  z:=economics_v2.enter_group_meat_initial(f.farm_a,f.op_zero,f.animal_zero,current_date,f.group_a,f.purpose_a,'{}');
  perform pg_temp.check_true(z->'basis_after'='0'::jsonb and z->'destination_period_id'=a->'destination_period_id'
    and z->'destination_start_position'=a->'destination_start_position'
    and (z->>'event_position')::bigint>(a->>'event_position')::bigint,'zero accepted and open pin reused');
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  set local role authenticated;
  p:=pg_temp.entry(f.farm_a,f.op_pin,f.animal_pin,current_date,f.group_a,f.purpose_a2,'{}');
  reset role;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform pg_temp.check_true(p->'destination_period_id'<>a->'destination_period_id'
    and (p->>'event_position')::bigint>(z->>'event_position')::bigint,'other purpose pin opens a distinct period under editor JWT');
  update public.animales set costo_adquisicion=999 where id=f.animal_a;
  replay:=economics_v2.enter_group_meat_initial(f.farm_a,f.op_a,f.animal_a,current_date,f.group_a,f.purpose_a,'{"probe":1}');
  perform pg_temp.check_true(replay=jsonb_set(a,'{replayed}','true')
    and (select to_jsonb(b) from economics_v2.group_animal_acquisition_basis b where animal_id=f.animal_a)=before_basis,
    'semantic replay preserves result, captured value, timestamp and version');
  perform pg_temp.expect_error(format('select pg_temp.entry(%L,%L,%L,current_date,%L,%L,''{"probe":2}'')',
    f.farm_a,f.op_a,f.animal_a,f.group_a,f.purpose_a),'22023','operation_payload_conflict','operation_id');
  perform pg_temp.expect_error(format('select pg_temp.entry(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,gen_random_uuid(),f.animal_a,f.group_a,f.purpose_a),'23514','invariant_violation','animal_id');
  for bad in select * from (values
    (f.farm_a,null::uuid,f.animal_zero,current_date,f.group_a,f.purpose_a,'22023','invalid_request','request'),
    (f.farm_a,gen_random_uuid(),null::uuid,current_date,f.group_a,f.purpose_a,'22023','invalid_request','animal_id'),
    (f.farm_a,gen_random_uuid(),gen_random_uuid(),current_date,f.group_a,f.purpose_a,'42501','forbidden','animal_id'),
    (f.farm_a,gen_random_uuid(),f.animal_b,current_date,f.group_a,f.purpose_a,'42501','forbidden','animal_id'),
    (f.farm_b,gen_random_uuid(),f.animal_b,current_date,f.group_b,f.purpose_b,'42501','forbidden','granja_id'),
    (f.farm_a,gen_random_uuid(),f.animal_unknown,current_date,gen_random_uuid(),f.purpose_a,'42501','forbidden','group_id'),
    (f.farm_a,gen_random_uuid(),f.animal_unknown,current_date,null::uuid,f.purpose_a,'22023','invalid_request','destination'),
    (f.farm_a,gen_random_uuid(),f.animal_unknown,current_date,f.group_b,f.purpose_a,'42501','forbidden','group_id'),
    (f.farm_a,gen_random_uuid(),f.animal_unknown,current_date,f.group_unknown,f.purpose_b,'42501','forbidden','purpose_id'),
    (f.farm_a,gen_random_uuid(),f.animal_unknown,current_date,f.group_unknown,gen_random_uuid(),'42501','forbidden','purpose_id'),
    (f.farm_a,gen_random_uuid(),f.animal_unknown,current_date,f.group_unknown,f.purpose_a2,'42501','forbidden','purpose_id'),
    (f.farm_a,gen_random_uuid(),f.animal_unknown,current_date,f.group_unknown,f.purpose_egg,'22023','invalid_request','purpose_id'),
    (f.farm_a,gen_random_uuid(),f.animal_unknown,current_date+1,f.group_unknown,f.purpose_a,'22023','invalid_request','effective_on'),
    (f.farm_a,gen_random_uuid(),f.animal_unknown,current_date-3,f.group_unknown,f.purpose_a,'22023','invalid_request','effective_on'))
    v(farm,op,animal,effective_on,group_id,purpose_id,state,code,field) loop
    perform pg_temp.expect_error(format('select pg_temp.entry(%L,%L,%L,%L::date,%L,%L,''{}'')',
      bad.farm,bad.op,bad.animal,bad.effective_on,bad.group_id,bad.purpose_id),bad.state,bad.code,bad.field);
  end loop;
  update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
  perform pg_temp.expect_error(format('select pg_temp.entry(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,gen_random_uuid(),f.animal_unknown,f.group_unknown,f.purpose_a),'42501','forbidden','granja_id');
  update economics_v2.feature_flags set economics_v2_enabled=true where granja_id=f.farm_a;
  for bad in select amount from (values (-1::numeric),('NaN'::numeric),('Infinity'::numeric)) v(amount) loop
    update public.animales set costo_adquisicion=bad.amount where id=f.animal_unknown;
    perform pg_temp.expect_error(format('select pg_temp.entry(%L,%L,%L,current_date,%L,%L,''{}'')',
      f.farm_a,gen_random_uuid(),f.animal_unknown,f.group_unknown,f.purpose_a),'23514','invariant_violation','costo_adquisicion');
  end loop;
  update public.animales set costo_adquisicion=0 where id=f.animal_unknown;
  create trigger f2b1_failure_probe before insert on economics_v2.group_acquisition_basis_entries
    for each row execute function pg_temp.reject_write();
  perform pg_temp.expect_error(format('select pg_temp.entry(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,gen_random_uuid(),f.animal_unknown,f.group_unknown,f.purpose_a),'P0001',null,null);
  drop trigger f2b1_failure_probe on economics_v2.group_acquisition_basis_entries;
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_periods where group_id=f.group_unknown)
    and not exists(select 1 from economics_v2.group_animal_acquisition_basis where animal_id=f.animal_unknown)
    and not exists(select 1 from economics_v2.group_occupancy_memberships where animal_id=f.animal_unknown),
    'late write failure rolls back operation, new period, membership, event and basis');
  update public.animales set costo_adquisicion=null where id=f.animal_unknown;
  update public.animales set grupo_id=f.group_wrong where id=f.animal_unknown;
  perform pg_temp.expect_error(format('select pg_temp.entry(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,gen_random_uuid(),f.animal_unknown,f.group_wrong,f.purpose_a),'23514','invariant_violation','group_id');
  update public.animales set grupo_id=f.group_unknown where id=f.animal_unknown;
  perform set_config('request.jwt.claim.sub',f.viewer_a::text,true);
  set local role authenticated;
  perform pg_temp.expect_error(format('select pg_temp.entry(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,gen_random_uuid(),f.animal_unknown,f.group_unknown,f.purpose_a),'42501','forbidden','granja_id');
  reset role;
  perform set_config('request.jwt.claim.sub','',true);
  set local role anon;
  perform pg_temp.expect_error(format('select pg_temp.entry(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,gen_random_uuid(),f.animal_unknown,f.group_unknown,f.purpose_a),'42501','forbidden','granja_id');
  perform pg_temp.expect_error('select economics_v2.enter_group_meat_initial(null,null,null,null,null,null,null)','42501',null,null);
  reset role;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  set local role authenticated;
  perform pg_temp.expect_error('select economics_v2.enter_group_meat_initial(null,null,null,null,null,null,null)','42501',null,null);
  reset role;
  perform pg_temp.check_true((select not proc.prosecdef and proc.proconfig @> array['search_path=""']
    and not has_function_privilege('public',proc.oid,'execute') and not has_function_privilege('anon',proc.oid,'execute')
    and not has_function_privilege('authenticated',proc.oid,'execute') from pg_proc proc
    where proc.oid='economics_v2.enter_group_meat_initial(uuid,uuid,uuid,date,uuid,uuid,jsonb)'::regprocedure),'private invoker ACL/path');
  set constraints all immediate;
  perform pg_temp.check_true((select count(*) from economics_v2.group_occupancy_memberships m
    join economics_v2.group_occupancy_periods t on t.id=m.period_id where m.granja_id=f.farm_a and m.position_span<@t.position_span)=3,
    'all three memberships contained');
  perform pg_temp.check_true((select count(*) from economics_v2.group_acquisition_basis_entries b
    join economics_v2.group_occupancy_events e on e.id=b.event_id and e.operation_id=b.operation_id
    join economics_v2.group_occupancy_memberships m on m.id=e.membership_id and m.start_position=e.event_position
    where b.granja_id=f.farm_a and b.entry_kind='initial' and b.account_kind='period'
      and b.period_id=m.period_id and b.animal_id=m.animal_id)=3,'event/basis/membership identities and issued positions');
  perform pg_temp.check_true((select sum(signed_amount) from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a)=300
    and (select sum(remaining_basis) from economics_v2.group_animal_acquisition_basis where granja_id=f.farm_a)=300,'initial basis conservation');
  perform pg_temp.check_true((select count(*) from economics_v2.group_occupancy_operations where granja_id=f.farm_a)=3
    and (select count(*) from economics_v2.group_occupancy_events where granja_id=f.farm_a)=3
    and not exists(select 1 from economics_v2.group_meat_snapshots where granja_id=f.farm_a)
    and not exists(select 1 from economics_v2.group_occupancy_periods where granja_id=f.farm_a and end_position is not null),'no duplicate writes or closure');
  insert into pg_temp.results values(jsonb_build_object('first',a,'zero',z,'other_pin',p));
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_initial_entry_pass',
  'assertion_count',(select count(*) from assertions),'locking_evidence','sequential_only',
  'entries',(select first_result from results where first_result ? 'first'),
  'basis',(select jsonb_agg(jsonb_build_object('initial_basis',initial_basis,'remaining_basis',remaining_basis,'source_cost',source_cost)
    order by animal_id) from economics_v2.group_animal_acquisition_basis)) as evidence;
rollback;
