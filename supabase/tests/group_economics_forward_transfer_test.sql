begin;

create temp table ids as select gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor_a,gen_random_uuid() viewer_a,gen_random_uuid() farm_a,gen_random_uuid() farm_b,
  gen_random_uuid() type_a,gen_random_uuid() type_wrong,gen_random_uuid() type_b,
  gen_random_uuid() purpose_a,gen_random_uuid() purpose_other,gen_random_uuid() purpose_egg,gen_random_uuid() purpose_b,
  gen_random_uuid() group_a,gen_random_uuid() group_b,gen_random_uuid() group_c,gen_random_uuid() group_d,
  gen_random_uuid() group_wrong,gen_random_uuid() group_foreign,gen_random_uuid() animal_a,
  gen_random_uuid() animal_zero,gen_random_uuid() animal_anchor,gen_random_uuid() animal_seed,
  gen_random_uuid() animal_foreign,gen_random_uuid() op_a,gen_random_uuid() op_later,
  gen_random_uuid() op_zero,gen_random_uuid() op_incomplete;
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
-- Exact complete business-state comparisons include row identities, versions, timestamps and incomplete operations.
create function pg_temp.business_state(p_farm uuid) returns jsonb language sql as $$
  select jsonb_build_object(
    'operations',(select coalesce(jsonb_agg(to_jsonb(t) order by operation_id),'[]') from economics_v2.group_occupancy_operations t where granja_id=p_farm),
    'periods',(select coalesce(jsonb_agg(to_jsonb(t) order by id),'[]') from economics_v2.group_occupancy_periods t where granja_id=p_farm),
    'memberships',(select coalesce(jsonb_agg(to_jsonb(t) order by id),'[]') from economics_v2.group_occupancy_memberships t where granja_id=p_farm),
    'events',(select coalesce(jsonb_agg(to_jsonb(t) order by id),'[]') from economics_v2.group_occupancy_events t where granja_id=p_farm),
    'basis',(select coalesce(jsonb_agg(to_jsonb(t) order by animal_id),'[]') from economics_v2.group_animal_acquisition_basis t where granja_id=p_farm),
    'entries',(select coalesce(jsonb_agg(to_jsonb(t) order by id),'[]') from economics_v2.group_acquisition_basis_entries t where granja_id=p_farm),
    'snapshots',(select coalesce(jsonb_agg(to_jsonb(t) order by id),'[]') from economics_v2.group_meat_snapshots t where granja_id=p_farm));
$$;
select pg_temp.check_true(not exists(select 1 from auth.users where raw_user_meta_data->>'fixture'='f2b-transfer')
  and not exists(select 1 from public.granjas where nombre like 'F2BT %'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"f2b-transfer"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F2BT farm A',owner_a from ids union all select farm_b,owner_b,'F2BT farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F2BT type A',owner_a from ids union all select type_wrong,farm_a,'F2BT wrong type',owner_a from ids
union all select type_b,farm_b,'F2BT type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select purpose_a,farm_a,'F2BT meat','carne',owner_a from ids union all
select purpose_other,farm_a,'F2BT other meat','carne',owner_a from ids union all
select purpose_egg,farm_a,'F2BT eggs','postura',owner_a from ids union all
select purpose_b,farm_b,'F2BT foreign meat','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'F2BT group '||g::text,owner_a from ids cross join lateral unnest(array[group_a,group_b,group_c,group_d]) g
union all select group_wrong,farm_a,type_wrong,'F2BT wrong group',owner_a from ids
union all select group_foreign,farm_b,type_b,'F2BT foreign group',owner_b from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,notas,created_by)
select a,farm_a,type_a,case when a=animal_seed then group_b else group_a end,purpose_a,current_date-3,
  case when a=animal_a then 300 else 0 end,'F2BT animal',owner_a
from ids cross join lateral unnest(array[animal_a,animal_zero,animal_anchor,animal_seed]) a
union all select animal_foreign,farm_b,type_b,group_foreign,purpose_b,current_date-3,0,'F2BT foreign',owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
create temp table initial as select a animal_id,economics_v2.enter_group_meat_initial(farm_a,gen_random_uuid(),a,
  current_date-1,case when a=animal_seed then group_b else group_a end,purpose_a,'{}') result
from ids cross join lateral unnest(array[animal_a,animal_zero,animal_anchor,animal_seed]) a;
set constraints all immediate;
set constraints all deferred;
-- Fixture-only authoritative-state setup; the private helper never performs animal CRUD.
update public.animales set grupo_id=(select group_b from ids) where id=(select animal_a from ids);
-- First transfer call must produce actual missing-helper RED before its migration exists.
create temp table results as select economics_v2.transfer_group_meat_nonclosing(
  farm_a,op_a,animal_a,current_date,group_b,purpose_a,'{"probe":1.00}'::jsonb) first_result from ids;

create function pg_temp.transfer(p_farm uuid,p_op uuid,p_animal uuid,p_date date,p_group uuid,p_purpose uuid,p_payload jsonb)
returns jsonb language sql security definer set search_path='' as $$
  select economics_v2.transfer_group_meat_nonclosing(p_farm,p_op,p_animal,p_date,p_group,p_purpose,p_payload);
$$;
do $grants$ begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
  execute format('grant usage on all sequences in schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end; $grants$;
grant select,insert on pg_temp.assertions to authenticated,anon;
create function pg_temp.reject_write() returns trigger language plpgsql as $$
begin
  if tg_table_name='group_acquisition_basis_entries' then
    if new.entry_kind<>'transfer_in' then return new; end if;
  end if;
  raise exception 'F2BT injected late write failure';
end;
$$;
do $proof$
declare f record; a jsonb; later jsonb; z jsonb; replay jsonb; capture jsonb; before_state jsonb;
  before_position bigint; bad record; table_name text; mode text; proc record;
begin
  select * into f from pg_temp.ids;
  select first_result into a from pg_temp.results;
  select result->>'destination_period_id' source_id into bad from pg_temp.initial where animal_id=f.animal_a;
  perform pg_temp.check_true(a @> jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',f.op_a,
    'action','transfer','animal_id',f.animal_a,'source_period_id',bad.source_id,'basis_before',300,'basis_after',300,
    'state_version',1,'source_status','open','destination_status','open','snapshot_id',null,'replayed',false),'exact transfer result');
  perform pg_temp.check_true((select array_agg(k order by k) from jsonb_object_keys(a) k)=array[
    'action','animal_id','basis_after','basis_before','basis_entry_ids','contract_version','destination_period_id',
    'destination_start_position','destination_status','effective_on','event_position','membership_event_ids',
    'operation_id','replayed','snapshot_id','source_end_position','source_period_id','source_status','state_version'],'exact result keys');
  perform pg_temp.check_true(a->'source_end_position'=a->'event_position'
    and (a->>'event_position')::bigint>(a->>'destination_start_position')::bigint,'shared boundary and reused destination');
  perform pg_temp.check_true((select count(*)=2 and sum(b.signed_amount)=0 and min(b.signed_amount)=-300
    and max(b.signed_amount)=300 and count(distinct b.entry_pair_id)=1 and bool_and(b.entry_pair_id=e.basis_transfer_id)
    and bool_and(e.event_position=(a->>'event_position')::bigint and e.action='transfer' and e.operation_id=f.op_a)
    from economics_v2.group_acquisition_basis_entries b join economics_v2.group_occupancy_events e on e.id=b.event_id
    where b.operation_id=f.op_a),'exact signed pair, shared operation/event position and pair identity');
  perform pg_temp.check_true((select count(*)=2 and bool_and(b.animal_id=e.animal_id and e.animal_id=m.animal_id
    and b.period_id=e.period_id and e.period_id=m.period_id and b.account_kind='period'
    and ((b.entry_kind='transfer_out' and b.period_id=(a->>'source_period_id')::uuid and b.signed_amount=-300)
      or (b.entry_kind='transfer_in' and b.period_id=(a->>'destination_period_id')::uuid and b.signed_amount=300)))
    from economics_v2.group_acquisition_basis_entries b join economics_v2.group_occupancy_events e on e.id=b.event_id
    join economics_v2.group_occupancy_memberships m on m.id=e.membership_id where b.operation_id=f.op_a),'exact leg kinds, periods and animal/membership identities');
  perform pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(f.farm_a,(a->>'source_period_id')::uuid)->'acquisition_cost'='0'::jsonb
    and economics_v2.calculate_group_period_live_metrics(f.farm_a,(a->>'destination_period_id')::uuid)->'acquisition_cost'='300'::jsonb,
    'Policy B moves period acquisition cost A minus300 and B plus300');
  perform pg_temp.check_true((select array_agg(id::text order by id::text) from economics_v2.group_acquisition_basis_entries where operation_id=f.op_a)
    =(select array_agg(v order by v) from jsonb_array_elements_text(a->'basis_entry_ids') v)
    and (select array_agg(id::text order by id::text) from economics_v2.group_occupancy_events where operation_id=f.op_a)
    =(select array_agg(v order by v) from jsonb_array_elements_text(a->'membership_event_ids') v),'result IDs match exact stored rows');
  perform pg_temp.check_true((select count(*)=2 and min(end_position)=(a->>'event_position')::bigint
    and max(start_position)=(a->>'event_position')::bigint from economics_v2.group_occupancy_memberships where animal_id=f.animal_a),
    'old membership ends before new half-open membership begins');
  select to_jsonb(b)-'current_period_id'-'version' into capture from economics_v2.group_animal_acquisition_basis b where animal_id=f.animal_a;
  update public.animales set costo_adquisicion=999,grupo_id=f.group_c where id=f.animal_a;
  set local role authenticated;
  later:=pg_temp.transfer(f.farm_a,f.op_later,f.animal_a,current_date,f.group_c,f.purpose_a,'{}');
  reset role;
  perform pg_temp.check_true(later->'source_period_id'=a->'destination_period_id' and later->'state_version'='2'::jsonb
    and later->'destination_start_position'=later->'event_position'
    and (later->>'event_position')::bigint>(a->>'event_position')::bigint,'later owner transfer creates destination and advances version');
  before_state:=pg_temp.business_state(f.farm_a);
  replay:=economics_v2.transfer_group_meat_nonclosing(f.farm_a,f.op_a,f.animal_a,current_date,f.group_b,f.purpose_a,'{"probe":1}');
  perform pg_temp.check_true(replay=jsonb_set(a,'{replayed}','true') and pg_temp.business_state(f.farm_a)=before_state,
    'original-source canonical replay after later transfer performs no write');
  perform pg_temp.check_true((select to_jsonb(b)-'current_period_id'-'version' from economics_v2.group_animal_acquisition_basis b
    where animal_id=f.animal_a)=capture and capture @> '{"initial_basis":300,"remaining_basis":300,"source_cost":300}',
    'capture, source cost, timestamp and provenance survive source edit and both transfers');
  perform pg_temp.expect_error(format('select pg_temp.transfer(%L,%L,%L,current_date,%L,%L,''{"probe":2}'')',
    f.farm_a,f.op_a,f.animal_a,f.group_b,f.purpose_a),'22023','operation_payload_conflict','operation_id');
  update public.animales set grupo_id=f.group_b where id=f.animal_zero;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  set local role authenticated;
  z:=pg_temp.transfer(f.farm_a,f.op_zero,f.animal_zero,current_date,f.group_b,f.purpose_a,'{}');
  reset role;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform pg_temp.check_true(z->'basis_before'='0'::jsonb and z->'basis_after'='0'::jsonb
    and z->'destination_period_id'=a->'destination_period_id'
    and (select count(*)=2 and sum(signed_amount)=0 and bool_and(signed_amount=0) from economics_v2.group_acquisition_basis_entries
      where operation_id=f.op_zero),'editor trusted invocation transfers legitimate zero without acquisition charge');

  -- Last-member refusal must precede ALL business writes and nontransactional sequence issuance.
  update public.animales set grupo_id=f.group_d where id=f.animal_anchor;
  before_state:=pg_temp.business_state(f.farm_a);
  select last_value into before_position from economics_v2.group_economics_event_position_seq;
  foreach table_name in array array['group_occupancy_operations','group_occupancy_periods','group_occupancy_memberships',
    'group_occupancy_events','group_animal_acquisition_basis','group_acquisition_basis_entries','group_meat_snapshots'] loop
    execute format('create trigger f2bt_no_write before insert or update or delete on economics_v2.%I for each row execute function pg_temp.reject_write()',table_name);
  end loop;
  perform pg_temp.expect_error(format('select pg_temp.transfer(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,gen_random_uuid(),f.animal_anchor,f.group_d,f.purpose_a),'23514','period_close_unfinalized_facts','source_period_id');
  foreach table_name in array array['group_occupancy_operations','group_occupancy_periods','group_occupancy_memberships',
    'group_occupancy_events','group_animal_acquisition_basis','group_acquisition_basis_entries','group_meat_snapshots'] loop
    execute format('drop trigger f2bt_no_write on economics_v2.%I',table_name);
  end loop;
  perform pg_temp.check_true(pg_temp.business_state(f.farm_a)=before_state
    and (select last_value from economics_v2.group_economics_event_position_seq)=before_position,'last-member refusal unchanged state and sequence');
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result)
    values(f.farm_a,f.op_incomplete,'f2bt-incomplete','{}');
  before_state:=pg_temp.business_state(f.farm_a);
  perform pg_temp.expect_error(format('select pg_temp.transfer(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,f.op_incomplete,f.animal_zero,f.group_d,f.purpose_a),'23514','invariant_violation','operation_id');
  perform pg_temp.check_true(pg_temp.business_state(f.farm_a)=before_state,'incomplete ledger is not a successful replay');
  for bad in select * from (values
    (f.animal_zero,f.group_b,f.purpose_a,current_date,'22023','invalid_request','destination'),
    (f.animal_zero,f.group_foreign,f.purpose_a,current_date,'42501','forbidden','group_id'),
    (f.animal_zero,f.group_wrong,f.purpose_a,current_date,'23514','invariant_violation','group_id'),
    (f.animal_zero,gen_random_uuid(),f.purpose_a,current_date,'42501','forbidden','group_id'),
    (f.animal_foreign,f.group_d,f.purpose_a,current_date,'42501','forbidden','animal_id'),
    (f.animal_zero,f.group_d,f.purpose_b,current_date,'42501','forbidden','purpose_id'),
    (f.animal_zero,f.group_d,f.purpose_egg,current_date,'22023','invalid_request','purpose_id'),
    (f.animal_zero,f.group_d,f.purpose_other,current_date,'42501','forbidden','purpose_id'),
    (f.animal_zero,f.group_d,f.purpose_a,current_date+1,'22023','invalid_request','effective_on'),
    (f.animal_zero,f.group_d,f.purpose_a,current_date-2,'22023','invalid_request','effective_on'))
    v(animal,group_id,purpose_id,effective_on,state,code,field) loop
    perform pg_temp.expect_error(format('select pg_temp.transfer(%L,%L,%L,%L::date,%L,%L,''{}'')',
      f.farm_a,gen_random_uuid(),bad.animal,bad.effective_on,bad.group_id,bad.purpose_id),bad.state,bad.code,bad.field);
  end loop;
  update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
  perform pg_temp.expect_error(format('select pg_temp.transfer(%L,%L,%L,current_date,%L,%L,''{}'')',
    f.farm_a,gen_random_uuid(),f.animal_zero,f.group_d,f.purpose_a),'42501','forbidden','granja_id');
  update economics_v2.feature_flags set economics_v2_enabled=true where granja_id=f.farm_a;
  for bad in select actor,role_name from (values (f.viewer_a,'authenticated'),(null::uuid,'anon')) v(actor,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(bad.actor::text,''),true);
    execute format('set local role %I',bad.role_name);
    perform pg_temp.expect_error(format('select pg_temp.transfer(%L,%L,%L,current_date,%L,%L,''{}'')',
      f.farm_a,gen_random_uuid(),f.animal_zero,f.group_d,f.purpose_a),'42501','forbidden','granja_id');
    perform pg_temp.expect_error('select economics_v2.transfer_group_meat_nonclosing(null,null,null,null,null,null,null)','42501',null,null);
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  set local role authenticated;
  perform pg_temp.expect_error('select economics_v2.transfer_group_meat_nonclosing(null,null,null,null,null,null,null)','42501',null,null);
  reset role;

  -- Separate late faults: destination basis leg, then final operation result UPDATE.
  update public.animales set grupo_id=f.group_d where id=f.animal_zero;
  foreach mode in array array['second_leg','final_result'] loop
    before_state:=pg_temp.business_state(f.farm_a);
    if mode='second_leg' then
      create trigger f2bt_failure before insert on economics_v2.group_acquisition_basis_entries for each row execute function pg_temp.reject_write();
    else
      create trigger f2bt_failure before update on economics_v2.group_occupancy_operations for each row execute function pg_temp.reject_write();
    end if;
    perform pg_temp.expect_error(format('select pg_temp.transfer(%L,%L,%L,current_date,%L,%L,''{}'')',
      f.farm_a,gen_random_uuid(),f.animal_zero,f.group_d,f.purpose_a),'P0001',null,null);
    execute format('drop trigger f2bt_failure on economics_v2.%I',case when mode='second_leg' then 'group_acquisition_basis_entries' else 'group_occupancy_operations' end);
    set constraints all immediate;
    set constraints all deferred;
    perform pg_temp.check_true(pg_temp.business_state(f.farm_a)=before_state,'exact operation/events/memberships/periods/basis rollback: '||mode);
  end loop;
  select * into proc from pg_proc where oid='economics_v2.transfer_group_meat_nonclosing(uuid,uuid,uuid,date,uuid,uuid,jsonb)'::regprocedure;
  perform pg_temp.check_true(not proc.prosecdef and proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(proc.proacl,acldefault('f',proc.proowner))) acl where acl.grantee=0 and acl.privilege_type='EXECUTE')
    and not has_function_privilege('anon',proc.oid,'EXECUTE') and not has_function_privilege('authenticated',proc.oid,'EXECUTE'),'private invoker empty path and actual PUBLIC/client ACL');
  set constraints all immediate;
  perform pg_temp.check_true((select bool_and(m.position_span<@p.position_span) from economics_v2.group_occupancy_memberships m
    join economics_v2.group_occupancy_periods p on p.id=m.period_id where m.granja_id=f.farm_a),'forced deferred containment');
  perform pg_temp.check_true((select sum(signed_amount)=300 and count(*) filter(where entry_kind='initial')=4
    from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a)
    and (select sum(remaining_basis)=300 from economics_v2.group_animal_acquisition_basis where granja_id=f.farm_a),'no recapture or acquisition charge');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_meat_snapshots where granja_id=f.farm_a)
    and not exists(select 1 from economics_v2.group_occupancy_periods where granja_id=f.farm_a and (end_position is not null or closed_on is not null))
    and not exists(select 1 from economics_v2.group_occupancy_periods p where p.granja_id=f.farm_a
      and not exists(select 1 from economics_v2.group_occupancy_memberships m where m.period_id=p.id and m.end_position is null)),
    'no snapshot, closed period, empty open source or fake finalizer');
  perform pg_temp.check_true(position('group_economics_not_activated' in pg_get_functiondef(
    'economics_v2.transition_group_occupancy_impl(uuid,uuid,text,uuid,date,uuid,uuid,uuid)'::regprocedure))>0,'public activation remains disabled');
  insert into pg_temp.results values(jsonb_build_object('first',a,'later',later,'zero',z));
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_transfer_pass','assertion_count',(select count(*) from assertions),
  'locking_evidence','sequential_only','late_rollback_cases',2,
  'transfers',(select first_result from results where first_result ? 'first')) as evidence;
rollback;
