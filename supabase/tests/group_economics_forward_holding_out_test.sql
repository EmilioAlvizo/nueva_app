begin;

create temp table ids as select gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor_a,gen_random_uuid() viewer_a,gen_random_uuid() farm_a,gen_random_uuid() farm_b,
  gen_random_uuid() type_a,gen_random_uuid() type_wrong,gen_random_uuid() type_b,
  gen_random_uuid() meat,gen_random_uuid() eggs,gen_random_uuid() ornamental,gen_random_uuid() purpose_b,
  gen_random_uuid() group_a,gen_random_uuid() group_wrong,gen_random_uuid() group_b,
  gen_random_uuid() animal_a,gen_random_uuid() animal_zero,gen_random_uuid() anchor,
  gen_random_uuid() animal_foreign,gen_random_uuid() op_a,gen_random_uuid() op_zero,gen_random_uuid() op_incomplete;
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
        'code',p_code,'field',p_field) and v_detail::jsonb ? 'entity_id','typed refusal');
    end if;
    return;
  end;
  raise exception 'Expected error: %',p_sql;
end;
$$;
-- Compare complete row state, not counts: identities, captures, versions and ledger completion matter.
create function pg_temp.business_state(p_farm uuid) returns jsonb language sql as $$
  select jsonb_build_object(
    'animals',(select coalesce(jsonb_agg(to_jsonb(t) order by id),'[]') from public.animales t where granja_id=p_farm),
    'operations',(select coalesce(jsonb_agg(to_jsonb(t) order by operation_id),'[]') from economics_v2.group_occupancy_operations t where granja_id=p_farm),
    'periods',(select coalesce(jsonb_agg(to_jsonb(t) order by id),'[]') from economics_v2.group_occupancy_periods t where granja_id=p_farm),
    'memberships',(select coalesce(jsonb_agg(to_jsonb(t) order by id),'[]') from economics_v2.group_occupancy_memberships t where granja_id=p_farm),
    'events',(select coalesce(jsonb_agg(to_jsonb(t) order by id),'[]') from economics_v2.group_occupancy_events t where granja_id=p_farm),
    'basis',(select coalesce(jsonb_agg(to_jsonb(t) order by animal_id),'[]') from economics_v2.group_animal_acquisition_basis t where granja_id=p_farm),
    'entries',(select coalesce(jsonb_agg(to_jsonb(t) order by id),'[]') from economics_v2.group_acquisition_basis_entries t where granja_id=p_farm),
    'snapshots',(select coalesce(jsonb_agg(to_jsonb(t) order by id),'[]') from economics_v2.group_meat_snapshots t where granja_id=p_farm));
$$;
select pg_temp.check_true(not exists(select 1 from auth.users where raw_user_meta_data->>'fixture'='f2b-holding-out')
  and not exists(select 1 from public.granjas where nombre like 'F2HO %'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"f2b-holding-out"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F2HO farm A',owner_a from ids union all select farm_b,owner_b,'F2HO farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F2HO type A',owner_a from ids union all select type_wrong,farm_a,'F2HO wrong type',owner_a from ids
union all select type_b,farm_b,'F2HO type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat,farm_a,'F2HO meat','carne',owner_a from ids union all select eggs,farm_a,'F2HO eggs','postura',owner_a from ids
union all select ornamental,farm_a,'F2HO ornamental','ornamental',owner_a from ids
union all select purpose_b,farm_b,'F2HO foreign','postura',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_a,farm_a,type_a,'F2HO group A',owner_a from ids union all select group_wrong,farm_a,type_wrong,'F2HO wrong group',owner_a from ids
union all select group_b,farm_b,type_b,'F2HO foreign group',owner_b from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,notas,created_by)
select a,farm_a,type_a,group_a,meat,current_date-3,case when a=animal_a then 300 else 0 end,'F2HO animal',owner_a
from ids cross join lateral unnest(array[animal_a,animal_zero,anchor]) a
union all select animal_foreign,farm_b,type_b,group_b,purpose_b,current_date-3,0,'F2HO foreign',owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
create temp table initial as select a animal_id,economics_v2.enter_group_meat_initial(farm_a,gen_random_uuid(),a,
  current_date-1,group_a,meat,'{}') result from ids cross join lateral unnest(array[animal_a,animal_zero,anchor]) a;
set constraints all immediate;
set constraints all deferred;
create temp table captures as select animal_id,to_jsonb(b)-'current_account_kind'-'current_period_id'-'version' capture
from economics_v2.group_animal_acquisition_basis b where granja_id=(select farm_a from ids);
-- Fixture-only authoritative purpose edit, including a source-cost edit that must never be recaptured.
update public.animales set proposito_id=(select eggs from ids),costo_adquisicion=999 where id=(select animal_a from ids);
-- Complete fixture reaches actual missing-helper RED only after valid setup and real initial entries.
create temp table results as select economics_v2.move_group_meat_to_holding_nonclosing(
  farm_a,op_a,animal_a,current_date,group_a,eggs,'{"probe":1.00}'::jsonb) first_result from ids;

create function pg_temp.holding_out(p_farm uuid,p_op uuid,p_animal uuid,p_date date,p_group uuid,p_purpose uuid,p_payload jsonb)
returns jsonb language sql security definer set search_path='' as $$
  select economics_v2.move_group_meat_to_holding_nonclosing(p_farm,p_op,p_animal,p_date,p_group,p_purpose,p_payload);
$$;
do $grants$ begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
  execute format('grant usage on all sequences in schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end; $grants$;
grant select,insert on pg_temp.assertions to authenticated,anon;
create function pg_temp.reject_write() returns trigger language plpgsql as $$
begin raise exception 'F2HO write probe'; end;
$$;
create function pg_temp.reject_holding_leg() returns trigger language plpgsql as $$
begin
  if new.account_kind='holding' then raise exception 'F2HO late holding leg'; end if;
  return new;
end;
$$;
do $proof$
declare f record; a jsonb; z jsonb; replay jsonb; before_state jsonb; before_position bigint;
  bad record; table_name text; mode text; proc record; source_id uuid;
begin
  select * into f from pg_temp.ids;
  select first_result into a from pg_temp.results;
  select (result->>'destination_period_id')::uuid into source_id from pg_temp.initial where animal_id=f.animal_a;
  perform pg_temp.check_true(a @> jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',f.op_a,
    'action','purpose_change','animal_id',f.animal_a,'source_period_id',source_id,'source_status','open',
    'destination_period_id',null,'destination_status',null,'destination_start_position',null,'snapshot_id',null,
    'basis_before',300,'basis_after',300,'state_version',1,'replayed',false),'exact holding-out result');
  perform pg_temp.check_true((select array_agg(k order by k) from jsonb_object_keys(a) k)=array[
    'action','animal_id','basis_after','basis_before','basis_entry_ids','contract_version','destination_period_id',
    'destination_start_position','destination_status','effective_on','event_position','membership_event_ids',
    'operation_id','replayed','snapshot_id','source_end_position','source_period_id','source_status','state_version'],'exact19 result keys');
  perform pg_temp.check_true(a->'source_end_position'=a->'event_position' and a->>'effective_on'=current_date::text
    and (select count(*)=1 and bool_and(end_position=(a->>'event_position')::bigint) from economics_v2.group_occupancy_memberships
      where animal_id=f.animal_a),'source membership ends at issued boundary with no invented holding membership');
  perform pg_temp.check_true((select count(*)=1 and bool_and(e.action='purpose_change' and e.period_id=source_id
    and e.animal_id=f.animal_a and e.membership_id=m.id and e.event_position=m.end_position)
    from economics_v2.group_occupancy_events e join economics_v2.group_occupancy_memberships m on m.id=e.membership_id
    where e.operation_id=f.op_a),'one real source membership event');
  perform pg_temp.check_true((select count(*)=2 and sum(b.signed_amount)=0 and count(distinct b.entry_pair_id)=1
    and bool_and(b.entry_pair_id=e.basis_transfer_id and b.animal_id=e.animal_id and b.operation_id=e.operation_id
      and ((b.entry_kind='purpose_out' and b.account_kind='period' and b.period_id=source_id and b.signed_amount=-300)
        or (b.entry_kind='purpose_in' and b.account_kind='holding' and b.period_id is null and b.signed_amount=300)))
    from economics_v2.group_acquisition_basis_entries b join economics_v2.group_occupancy_events e on e.id=b.event_id
    where b.operation_id=f.op_a),'exact signed pair and shared real event/animal/operation identities');
  perform pg_temp.check_true((select array_agg(id::text order by id::text) from economics_v2.group_acquisition_basis_entries where operation_id=f.op_a)
    =(select array_agg(v order by v) from jsonb_array_elements_text(a->'basis_entry_ids') v)
    and (select array_agg(id::text order by id::text) from economics_v2.group_occupancy_events where operation_id=f.op_a)
    =(select array_agg(v order by v) from jsonb_array_elements_text(a->'membership_event_ids') v),'result IDs match exact rows');
  before_state:=pg_temp.business_state(f.farm_a);
  set local role authenticated;
  replay:=pg_temp.holding_out(f.farm_a,f.op_a,f.animal_a,current_date,f.group_a,f.eggs,'{"probe":1}');
  reset role;
  perform pg_temp.check_true(replay=jsonb_set(a,'{replayed}','true') and pg_temp.business_state(f.farm_a)=before_state,
    'owner trusted canonical replay reconstructs original source and writes nothing while holding');
  perform pg_temp.expect_error(format('select pg_temp.holding_out(%L,%L,%L,current_date,%L,%L,''{"probe":2}'')',
    f.farm_a,f.op_a,f.animal_a,f.group_a,f.eggs),'22023','operation_payload_conflict','operation_id');
  update public.animales set proposito_id=f.ornamental where id=f.animal_zero;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  set local role authenticated;
  z:=pg_temp.holding_out(f.farm_a,f.op_zero,f.animal_zero,current_date,f.group_a,f.ornamental,'{}');
  reset role;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform pg_temp.check_true(z->'basis_before'='0'::jsonb and z->'basis_after'='0'::jsonb and z->'state_version'='1'::jsonb
    and (select count(*)=2 and bool_and(signed_amount=0) from economics_v2.group_acquisition_basis_entries where operation_id=f.op_zero),
    'editor trusted ornamental exit carries recorded zero through both legs');
  perform pg_temp.check_true((select count(*)=2 and bool_and(b.status='active' and b.current_account_kind='holding'
    and b.current_period_id is null and b.version=1 and to_jsonb(b)-'current_account_kind'-'current_period_id'-'version'=c.capture)
    from economics_v2.group_animal_acquisition_basis b join pg_temp.captures c using(animal_id)
    where b.animal_id in(f.animal_a,f.animal_zero)),'full immutable capture/provenance preserved despite public cost edit');
  perform pg_temp.check_true((select count(*)=1 and bool_and(animal_id=f.anchor) from economics_v2.group_occupancy_memberships
    where period_id=source_id and end_position is null)
    and economics_v2.calculate_group_period_live_metrics(f.farm_a,source_id)->'acquisition_cost'='0'::jsonb,
    'intentional holding gap leaves other member and removes only moved acquisition basis from source metrics');

  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result)
    values(f.farm_a,f.op_incomplete,'f2ho-incomplete','{}');
  before_state:=pg_temp.business_state(f.farm_a);
  perform pg_temp.expect_error(format('select pg_temp.holding_out(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,f.op_incomplete,f.anchor,f.group_a,f.eggs),'23514','invariant_violation','operation_id');
  perform pg_temp.check_true(pg_temp.business_state(f.farm_a)=before_state,'unfinished ledger cannot replay or write');
  for bad in select * from (values
    (f.farm_b,f.anchor,f.group_a,f.eggs,current_date,'42501','forbidden','granja_id'),
    (f.farm_a,f.animal_foreign,f.group_a,f.eggs,current_date,'42501','forbidden','animal_id'),
    (f.farm_a,gen_random_uuid(),f.group_a,f.eggs,current_date,'42501','forbidden','animal_id'),
    (f.farm_a,f.anchor,f.group_b,f.eggs,current_date,'42501','forbidden','group_id'),
    (f.farm_a,f.anchor,gen_random_uuid(),f.eggs,current_date,'42501','forbidden','group_id'),
    (f.farm_a,f.anchor,f.group_wrong,f.eggs,current_date,'23514','invariant_violation','group_id'),
    (f.farm_a,f.anchor,f.group_a,f.purpose_b,current_date,'42501','forbidden','purpose_id'),
    (f.farm_a,f.anchor,f.group_a,gen_random_uuid(),current_date,'42501','forbidden','purpose_id'),
    (f.farm_a,f.anchor,f.group_a,f.meat,current_date,'22023','invalid_request','purpose_id'),
    (f.farm_a,f.anchor,f.group_a,f.eggs,current_date,'42501','forbidden','purpose_id'),
    (f.farm_a,f.anchor,f.group_a,f.eggs,current_date+1,'22023','invalid_request','effective_on'),
    (f.farm_a,f.anchor,f.group_a,f.eggs,current_date-2,'22023','invalid_request','effective_on'))
    v(farm,animal,group_id,purpose_id,effective_on,state,code,field) loop
    perform pg_temp.expect_error(format('select pg_temp.holding_out(%L,%L,%L,%L::date,%L,%L,''{}'')',
      bad.farm,gen_random_uuid(),bad.animal,bad.effective_on,bad.group_id,bad.purpose_id),bad.state,bad.code,bad.field);
  end loop;
  update public.animales set proposito_id=f.eggs,activo=false where id=f.anchor;
  perform pg_temp.expect_error(format('select pg_temp.holding_out(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,gen_random_uuid(),f.anchor,f.group_a,f.eggs),'23514','invariant_violation','animal_id');
  update public.animales set activo=true where id=f.anchor;
  update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
  perform pg_temp.expect_error(format('select pg_temp.holding_out(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,gen_random_uuid(),f.anchor,f.group_a,f.eggs),'42501','forbidden','granja_id');
  update economics_v2.feature_flags set economics_v2_enabled=true where granja_id=f.farm_a;
  for bad in select actor,role_name from (values (f.viewer_a,'authenticated'),(null::uuid,'anon')) v(actor,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(bad.actor::text,''),true);
    execute format('set local role %I',bad.role_name);
    perform pg_temp.expect_error(format('select pg_temp.holding_out(%L,%L,%L,current_date,%L,%L,''{}'')',
      f.farm_a,gen_random_uuid(),f.anchor,f.group_a,f.eggs),'42501','forbidden','granja_id');
    perform pg_temp.expect_error('select economics_v2.move_group_meat_to_holding_nonclosing(null,null,null,null,null,null,null)','42501',null,null);
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  set local role authenticated;
  perform pg_temp.expect_error('select economics_v2.move_group_meat_to_holding_nonclosing(null,null,null,null,null,null,null)','42501',null,null);
  reset role;

  -- Last-member refusal must precede every business write AND nontransactional position issuance.
  before_state:=pg_temp.business_state(f.farm_a);
  select last_value into before_position from economics_v2.group_economics_event_position_seq;
  foreach table_name in array array['group_occupancy_operations','group_occupancy_periods','group_occupancy_memberships',
    'group_occupancy_events','group_animal_acquisition_basis','group_acquisition_basis_entries',
    'group_period_feed_allocations','group_period_expenses','group_period_sale_bindings','group_meat_snapshots'] loop
    execute format('create trigger f2ho_no_write before insert or update or delete on economics_v2.%I for each row execute function pg_temp.reject_write()',table_name);
  end loop;
  perform pg_temp.expect_error(format('select pg_temp.holding_out(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,gen_random_uuid(),f.anchor,f.group_a,f.eggs),'23514','period_close_unfinalized_facts','source_period_id');
  foreach table_name in array array['group_occupancy_operations','group_occupancy_periods','group_occupancy_memberships',
    'group_occupancy_events','group_animal_acquisition_basis','group_acquisition_basis_entries',
    'group_period_feed_allocations','group_period_expenses','group_period_sale_bindings','group_meat_snapshots'] loop
    execute format('drop trigger f2ho_no_write on economics_v2.%I',table_name);
  end loop;
  perform pg_temp.check_true(pg_temp.business_state(f.farm_a)=before_state
    and (select last_value from economics_v2.group_economics_event_position_seq)=before_position,'last-member unchanged business state and sequence');
  -- Real initial entry adds another member for independent late-fault cases; no fabricated holding or closure.
  update public.animales set proposito_id=f.meat where id=f.anchor;
  insert into public.animales(granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,notas,created_by)
    values(f.farm_a,f.type_a,f.group_a,f.meat,current_date-3,0,'F2HO late anchor',f.owner_a) returning id into bad;
  perform economics_v2.enter_group_meat_initial(f.farm_a,gen_random_uuid(),bad.id,current_date,f.group_a,f.meat,'{}');
  update public.animales set proposito_id=f.eggs where id=f.anchor;
  foreach mode in array array['holding_leg','final_result'] loop
    before_state:=pg_temp.business_state(f.farm_a);
    if mode='holding_leg' then
      create trigger f2ho_fault before insert on economics_v2.group_acquisition_basis_entries for each row execute function pg_temp.reject_holding_leg();
    else
      create trigger f2ho_fault before update on economics_v2.group_occupancy_operations for each row execute function pg_temp.reject_write();
    end if;
    perform pg_temp.expect_error(format('select pg_temp.holding_out(%L,%L,%L,current_date,%L,%L,''{}'')',
      f.farm_a,gen_random_uuid(),f.anchor,f.group_a,f.eggs),'P0001',null,null);
    execute format('drop trigger f2ho_fault on economics_v2.%I',case when mode='holding_leg' then 'group_acquisition_basis_entries' else 'group_occupancy_operations' end);
    set constraints all immediate;
    set constraints all deferred;
    perform pg_temp.check_true(pg_temp.business_state(f.farm_a)=before_state,'complete independent late rollback: '||mode);
  end loop;
  set local role authenticated;
  replay:=pg_temp.holding_out(f.farm_a,gen_random_uuid(),f.anchor,current_date,f.group_a,f.eggs,'{}');
  reset role;
  perform pg_temp.check_true(replay->'state_version'='1'::jsonb and replay->'replayed'='false'::jsonb
    and (select current_account_kind='holding' and current_period_id is null from economics_v2.group_animal_acquisition_basis
      where animal_id=f.anchor),'owner trusted mutation succeeds after independent rollback probes');
  select * into proc from pg_proc where oid='economics_v2.move_group_meat_to_holding_nonclosing(uuid,uuid,uuid,date,uuid,uuid,jsonb)'::regprocedure;
  perform pg_temp.check_true(not proc.prosecdef and proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(proc.proacl,acldefault('f',proc.proowner))) acl where acl.grantee=0 and acl.privilege_type='EXECUTE')
    and not has_function_privilege('anon',proc.oid,'EXECUTE') and not has_function_privilege('authenticated',proc.oid,'EXECUTE'),'private invoker empty path and actual PUBLIC/client ACL');
  set constraints all immediate;
  perform pg_temp.check_true((select bool_and(m.position_span<@p.position_span) from economics_v2.group_occupancy_memberships m
    join economics_v2.group_occupancy_periods p on p.id=m.period_id where m.granja_id=f.farm_a),'forced deferred containment includes ended memberships');
  perform pg_temp.check_true((select sum(signed_amount)=300 and count(*) filter(where entry_kind='initial')=4
    from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a)
    and (select sum(remaining_basis)=300 from economics_v2.group_animal_acquisition_basis where granja_id=f.farm_a),'no recapture or acquisition charge');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_meat_snapshots where granja_id=f.farm_a)
    and not exists(select 1 from economics_v2.group_occupancy_periods where granja_id=f.farm_a and (end_position is not null or closed_on is not null))
    and position('group_economics_not_activated' in pg_get_functiondef(
      'economics_v2.transition_group_occupancy_impl(uuid,uuid,text,uuid,date,uuid,uuid,uuid)'::regprocedure))>0,'no closure, snapshot or public activation');
  insert into pg_temp.results values(jsonb_build_object('known',a,'zero',z));
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_holding_out_pass','assertion_count',(select count(*) from assertions),
  'locking_evidence','sequential_only','late_rollback_cases',2,
  'holding_out',(select first_result from results where first_result ? 'known')) as evidence;
rollback;
