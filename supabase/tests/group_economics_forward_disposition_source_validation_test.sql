begin;

-- Run the FULL file in the sandbox SQL Editor, never a selected fragment.
-- Expected first RED: the real source validator is missing, SQLSTATE 42883.
-- This fixture creates no deployed helper, migration, disposition or lifecycle history.
-- If Studio offers automatic RLS changes, do not authorize business-table changes.
create temp table ids as select
  gen_random_uuid() owner_a, gen_random_uuid() owner_b,
  gen_random_uuid() editor_a, gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a, gen_random_uuid() farm_b,
  gen_random_uuid() type_a, gen_random_uuid() type_wrong, gen_random_uuid() type_b,
  gen_random_uuid() meat, gen_random_uuid() other_meat,
  gen_random_uuid() eggs, gen_random_uuid() purpose_b,
  gen_random_uuid() group_a, gen_random_uuid() group_alone,
  gen_random_uuid() group_wrong, gen_random_uuid() group_b,
  gen_random_uuid() animal_a, gen_random_uuid() animal_zero,
  gen_random_uuid() animal_alone, gen_random_uuid() animal_unentered,
  gen_random_uuid() animal_b, gen_random_uuid() reason_a, gen_random_uuid() baja_a;
create temp table assertions(label text not null);

create function pg_temp.check_true(p_ok boolean, p_label text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%', p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;

-- Every comparison retains complete rows, not just totals or row counts.
-- Sorting serialized full rows also covers tables with composite primary keys.
create temp table watched_tables(schema_name text, table_name text, primary key(schema_name, table_name));
insert into watched_tables values
  ('economics_v2','group_occupancy_operations'), ('economics_v2','group_occupancy_periods'),
  ('economics_v2','group_occupancy_memberships'), ('economics_v2','group_occupancy_events'),
  ('economics_v2','group_animal_acquisition_basis'), ('economics_v2','group_acquisition_basis_entries'),
  ('economics_v2','group_period_feed_allocations'), ('economics_v2','group_period_expenses'),
  ('economics_v2','group_period_sale_bindings'), ('economics_v2','group_meat_snapshots'),
  ('public','animales'), ('public','bajas_animales'), ('public','venta_animal'),
  ('public','tipo_animal'), ('public','grupos'), ('public','cat_proposito_animal'),
  ('public','cat_razon_baja'), ('public','cat_tipo_adquisicion'),
  ('public','altas_animales'), ('public','miembros_granja'), ('economics_v2','feature_flags');
create function pg_temp.business_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; rows jsonb; result jsonb := '{}'::jsonb; farms uuid[]; actors uuid[];
begin
  select array[farm_a,farm_b], array[owner_a,owner_b,editor_a,viewer_a]
    into farms, actors from pg_temp.ids;
  for t in select * from pg_temp.watched_tables order by schema_name,table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r where granja_id=any($1) or granja_id is null', t.schema_name,t.table_name)
      into rows using farms;
    result := result || jsonb_build_object(t.schema_name||'.'||t.table_name,rows);
  end loop;
  return result || jsonb_build_object(
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

-- Statement triggers reject even zero-row INSERT/UPDATE/DELETE attempts.
-- The transaction-local switch is enabled only around a checked call, not probe setup.
create function pg_temp.reject_validator_dml()
returns trigger language plpgsql as $$
begin
  if current_setting('f2dv.validator_call',true)='on' then
    raise exception using errcode='P0001', message='F2DV validator attempted business DML';
  end if;
  return null;
end;
$$;
do $blockers$
declare t record;
begin
  for t in select * from pg_temp.watched_tables
    where schema_name='economics_v2' and table_name<>'feature_flags'
      or schema_name='public' and table_name in ('animales','bajas_animales','venta_animal') loop
    execute format('create trigger f2dv_no_dml before insert or update or delete on %I.%I
      for each statement execute function pg_temp.reject_validator_dml()',t.schema_name,t.table_name);
  end loop;
end;
$blockers$;

-- Invoker execution preserves SET ROLE. Only snapshot/assertion utilities are privileged.
-- An unexpected failure is rethrown: the initial missing-function error is never swallowed.
create function pg_temp.checked(p_sql text, p_state text default null,
  p_code text default null, p_field text default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare before_rows jsonb; before_seq jsonb; result jsonb; state text; detail text;
begin
  before_rows := pg_temp.business_state();
  before_seq := pg_temp.position_state();
  perform set_config('f2dv.validator_call','on',true);
  begin
    execute p_sql into result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics state=returned_sqlstate, detail=pg_exception_detail;
  end;
  perform set_config('f2dv.validator_call','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=before_rows,'full state unchanged: '||p_sql);
  perform pg_temp.check_true(pg_temp.position_state()=before_seq,'last_value/is_called unchanged: '||p_sql);
  if p_state is null then
    perform pg_temp.check_true(result is not null,'validator returns context');
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

select pg_temp.check_true(
  not exists(select 1 from auth.users where raw_user_meta_data->>'fixture'='group-source-validation')
  and not exists(select 1 from public.granjas where nombre like 'F2DV %'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"group-source-validation"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F2DV farm A',owner_a from ids
union all select farm_b,owner_b,'F2DV farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F2DV type A',owner_a from ids
union all select type_wrong,farm_a,'F2DV wrong type',owner_a from ids
union all select type_b,farm_b,'F2DV foreign type',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat,farm_a,'F2DV meat','carne',owner_a from ids
union all select other_meat,farm_a,'F2DV other meat','carne',owner_a from ids
union all select eggs,farm_a,'F2DV eggs','postura',owner_a from ids
union all select purpose_b,farm_b,'F2DV foreign meat','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'F2DV group '||g::text,owner_a
from ids cross join lateral unnest(array[group_a,group_alone]) g
union all select group_wrong,farm_a,type_wrong,'F2DV wrong group',owner_a from ids
union all select group_b,farm_b,type_b,'F2DV foreign group',owner_b from ids;
insert into public.cat_razon_baja(id,granja_id,nombre,genera_ingreso,created_by)
select reason_a,farm_a,'F2DV non-income linkage probe',false,owner_a from ids;
-- Referential row for an isolated linkage probe only; no sale or disposition producer is called.
insert into public.bajas_animales(id,granja_id,tipo_animal_id,razon_baja_id,fecha_baja,notas,created_by)
select baja_a,farm_a,type_a,reason_a,current_date,'F2DV linkage probe',owner_a from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,notas,created_by)
select a,farm_a,type_a,case when a=animal_alone then group_alone else group_a end,
  meat,current_date-4,case when a=animal_a then 300 else 0 end,'F2DV animal',owner_a
from ids cross join lateral unnest(array[animal_a,animal_zero,animal_alone,animal_unentered]) a
union all select animal_b,farm_b,type_b,group_b,purpose_b,current_date-4,0,'F2DV foreign',owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
set constraints all immediate;
set constraints all deferred;

-- Real qualified initial entries: 300+0 share a period; a third 0 is alone.
-- The later real zero entry supplies affected-period and membership chronology evidence.
create temp table initial as
select animal_a animal_id,economics_v2.enter_group_meat_initial(
  farm_a,gen_random_uuid(),animal_a,current_date-3,group_a,meat,'{}') result from ids;
insert into initial select animal_zero,economics_v2.enter_group_meat_initial(
  farm_a,gen_random_uuid(),animal_zero,current_date-2,group_a,meat,'{}') from ids;
insert into initial select animal_alone,economics_v2.enter_group_meat_initial(
  farm_a,gen_random_uuid(),animal_alone,current_date-3,group_alone,meat,'{}') from ids;
set constraints all immediate;
set constraints all deferred;
select pg_temp.check_true((select count(*)=3 from initial)
  and (select count(*)=2 from economics_v2.group_occupancy_periods where granja_id=(select farm_a from ids)),
  'real referentially valid three-entry/two-period baseline');
create temp table captures as select animal_id,to_jsonb(b) basis
from economics_v2.group_animal_acquisition_basis b where granja_id=(select farm_a from ids);

-- FIRST new-validator call, after valid REAL initial setup: expected missing helper 42883.
-- No gateway body or regprocedure assertion references the validator before this call.
create temp table contexts as select pg_temp.checked(format(
  'select economics_v2.validate_group_meat_nonclosing_source(%L::uuid,%L::uuid,current_date)',
  farm_a,animal_a)) first_context from ids;

create function pg_temp.source(p_farm uuid,p_animal uuid,p_date date)
returns jsonb language sql security definer set search_path='' as $$
  select economics_v2.validate_group_meat_nonclosing_source(p_farm,p_animal,p_date);
$$;
do $grants$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$grants$;
grant execute on function pg_temp.source(uuid,uuid,date), pg_temp.checked(text,text,text,text),
  pg_temp.check_true(boolean,text), pg_temp.business_state(), pg_temp.position_state() to authenticated,anon;

do $proof$
declare f record; a jsonb; z jsonb; repeated jsonb; baseline jsonb; probe record;
  source_period uuid; solo_period uuid; membership uuid; call_sql text; proc record; actor record;
begin
  select * into f from pg_temp.ids;
  select first_context into a from pg_temp.contexts;
  select period_id,id into source_period,membership from economics_v2.group_occupancy_memberships
    where animal_id=f.animal_a and end_position is null;
  select period_id into solo_period from economics_v2.group_occupancy_memberships
    where animal_id=f.animal_alone and end_position is null;
  perform pg_temp.check_true((select array_agg(k order by k) from jsonb_object_keys(a) k)=array[
    'active_member_count','actor_id','animal_id','basis','context_version','effective_on','granja_id',
    'group_id','membership_id','purpose_id','scope','source_period_id','tipo_animal_id'],'exact INTERNAL13 keys');
  perform pg_temp.check_true(a @> jsonb_build_object('context_version','group-disposition-source-context.v1',
    'actor_id',f.owner_a,'granja_id',f.farm_a,'animal_id',f.animal_a,'effective_on',current_date,
    'source_period_id',source_period,'membership_id',membership,'group_id',f.group_a,
    'purpose_id',f.meat,'tipo_animal_id',f.type_a,'active_member_count',2),'server-derived source context');
  perform pg_temp.check_true(a->'basis'=(select basis from pg_temp.captures where animal_id=f.animal_a)
    and a->'basis' @> '{"initial_basis":300,"source_cost":300,"remaining_basis":300,"status":"active"}'::jsonb,
    'exact stored basis, including capture timestamp/version/pointers');
  perform pg_temp.check_true(a->'scope'=jsonb_build_object('actor_id',f.owner_a,
    'group_ids',jsonb_build_array(f.group_a),'animal_ids',jsonb_build_array(f.animal_a),
    'period_ids',jsonb_build_array(source_period)),'exact qualified F2A four-key scope');
  perform pg_temp.check_true((select count(*)=2 from economics_v2.group_occupancy_memberships
    where period_id=source_period and end_position is null),'active source count agrees with stored rows');
  call_sql := format('select pg_temp.source(%L,%L,current_date)',f.farm_a,f.animal_a);
  repeated := pg_temp.checked(call_sql);
  perform pg_temp.check_true(repeated=a,'repeat validation is not an operation or replay receipt');
  update public.animales set costo_adquisicion=999 where id=f.animal_a;
  repeated := pg_temp.checked(call_sql);
  perform pg_temp.check_true(repeated=a and repeated->'basis'->'source_cost'='300'::jsonb,
    'mutable public cost999 does not recapture stored300');
  z := pg_temp.checked(format('select pg_temp.source(%L,%L,current_date)',f.farm_a,f.animal_zero));
  perform pg_temp.check_true(z->'basis'=(select basis from pg_temp.captures where animal_id=f.animal_zero)
    and z->'basis'->'remaining_basis'='0'::jsonb and z->'source_period_id'=a->'source_period_id'
    and z->'active_member_count'='2'::jsonb,'original zero has a real shared source and intact capture');
  perform pg_temp.check_true((select count(*)=13 from jsonb_object_keys(z))
    and z=jsonb_build_object('context_version','group-disposition-source-context.v1',
      'actor_id',f.owner_a,'granja_id',f.farm_a,'animal_id',f.animal_zero,'effective_on',current_date,
      'source_period_id',source_period,'membership_id',(select id from economics_v2.group_occupancy_memberships
        where animal_id=f.animal_zero and end_position is null),
      'group_id',f.group_a,'purpose_id',f.meat,'tipo_animal_id',f.type_a,
      'basis',(select basis from pg_temp.captures where animal_id=f.animal_zero),'active_member_count',2,
      'scope',jsonb_build_object('actor_id',f.owner_a,'group_ids',jsonb_build_array(f.group_a),
        'animal_ids',jsonb_build_array(f.animal_zero),'period_ids',jsonb_build_array(source_period))),
    'original zero exact13 context and actual F2A scope');

  -- Direct arguments and chronology refusals are checked individually, never as a batch snapshot.
  for probe in select * from (values
    (null::uuid,f.animal_a,current_date,'22023','invalid_request','granja_id'),
    (gen_random_uuid(),f.animal_a,current_date,'42501','forbidden','granja_id'),
    (f.farm_b,f.animal_a,current_date,'42501','forbidden','granja_id'),
    (f.farm_a,null::uuid,current_date,'22023','invalid_request','animal_id'),
    (f.farm_a,gen_random_uuid(),current_date,'42501','forbidden','animal_id'),
    (f.farm_a,f.animal_b,current_date,'42501','forbidden','animal_id'),
    (f.farm_a,f.animal_unentered,current_date,'23514','invariant_violation','animal_id'),
    (f.farm_a,f.animal_a,null::date,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_a,'infinity'::date,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_a,'-infinity'::date,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_a,current_date+1,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_a,current_date-5,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_a,current_date-3,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_zero,current_date-3,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_alone,current_date,'23514','period_close_unfinalized_facts','source_period_id'))
    v(farm,animal,effective_on,state,code,field) loop
    perform pg_temp.checked(format('select pg_temp.source(%L::uuid,%L::uuid,%L::date)',
      probe.farm,probe.animal,probe.effective_on),probe.state,probe.code,probe.field);
  end loop;

  -- Each intentional edit is isolated by a subtransaction and restored BEFORE the next probe.
  -- No existing data is deleted, and no disposed/reactivated basis or closed period is fabricated.
  -- Unknown FK targets cannot be assigned without failing setup; foreign existing IDs exercise ownership.
  baseline := pg_temp.business_state();
  for probe in select * from (values
    ('inactive',format('update public.animales set activo=false where id=%L',f.animal_a),'23514','invariant_violation','animal_id'),
    ('baja_link',format('update public.animales set baja_id=%L where id=%L',f.baja_a,f.animal_a),'23514','invariant_violation','animal_id'),
    ('foreign_group',format('update public.animales set grupo_id=%L where id=%L',f.group_b,f.animal_a),'42501','forbidden','group_id'),
    ('group_mismatch',format('update public.animales set grupo_id=%L where id=%L',f.group_alone,f.animal_a),'42501','forbidden','group_id'),
    ('absent_group',format('update public.animales set grupo_id=null where id=%L',f.animal_a),'42501','forbidden','group_id'),
    ('type_mismatch',format('update public.grupos set tipo_animal_id=%L where id=%L',f.type_wrong,f.group_a),'23514','invariant_violation','group_id'),
    ('foreign_type',format('update public.animales set tipo_animal_id=%L where id=%L; update public.grupos set tipo_animal_id=%L where id=%L',
      f.type_b,f.animal_a,f.type_b,f.group_a),'42501','forbidden','tipo_animal_id'),
    ('foreign_purpose',format('update public.animales set proposito_id=%L where id=%L',f.purpose_b,f.animal_a),'42501','forbidden','purpose_id'),
    ('purpose_mismatch',format('update public.animales set proposito_id=%L where id=%L',f.other_meat,f.animal_a),'42501','forbidden','purpose_id'),
    ('nonmeat',format('update public.cat_proposito_animal set codigo_calculo=''postura'' where id=%L',f.meat),'22023','invalid_request','purpose_id'),
    ('source_purpose_mismatch',format('update economics_v2.group_occupancy_periods set purpose_id=%L where id=%L',f.other_meat,source_period),'42501','forbidden','purpose_id'),
    ('source_nonmeat',format('update economics_v2.group_occupancy_periods set purpose_id=%L where id=%L',f.eggs,source_period),'22023','invalid_request','purpose_id'),
    ('wrong_account',format('update economics_v2.group_animal_acquisition_basis set current_account_kind=''holding'',current_period_id=null where animal_id=%L',f.animal_a),'23514','invariant_violation','animal_id'),
    ('wrong_period',format('update economics_v2.group_animal_acquisition_basis set current_period_id=%L where animal_id=%L',solo_period,f.animal_a),'23514','invariant_violation','animal_id'),
    ('remaining_gate',format('update economics_v2.group_animal_acquisition_basis set remaining_basis=299 where animal_id=%L',f.animal_a),'23514','invariant_violation','animal_id'),
    ('initial_gate',format('update economics_v2.group_animal_acquisition_basis set initial_basis=301 where animal_id=%L',f.animal_a),'23514','invariant_violation','animal_id'),
    ('source_cost_gate',format('update economics_v2.group_animal_acquisition_basis set source_cost=301 where animal_id=%L',f.animal_a),'23514','invariant_violation','animal_id'),
    ('net_gate',format('update economics_v2.group_acquisition_basis_entries set signed_amount=299 where animal_id=%L',f.animal_a),'23514','invariant_violation','animal_id'),
    ('missing_basis',format('delete from economics_v2.group_acquisition_basis_entries where animal_id=%L; delete from economics_v2.group_animal_acquisition_basis where animal_id=%L',
      f.animal_a,f.animal_a),'23514','invariant_violation','animal_id'),
    ('membership_source',format('update economics_v2.group_occupancy_memberships set period_id=%L where animal_id=%L',solo_period,f.animal_a),'23514','invariant_violation','animal_id'),
    ('containment',format('update economics_v2.group_occupancy_periods set start_position=start_position+1 where id=%L',source_period),'23514','invariant_violation','animal_id'),
    ('acquisition_future',format('update public.animales set fecha_adquisicion=current_date+1 where id=%L',f.animal_a),'22023','invalid_request','effective_on'),
    ('acquisition_infinity',format('update public.animales set fecha_adquisicion=''infinity'' where id=%L',f.animal_a),'22023','invalid_request','effective_on'),
    ('acquisition_negative_infinity',format('update public.animales set fecha_adquisicion=''-infinity'' where id=%L',f.animal_a),'22023','invalid_request','effective_on'),
    ('period_future',format('update economics_v2.group_occupancy_periods set starts_on=current_date+1 where id=%L',source_period),'22023','invalid_request','effective_on'),
    ('period_infinity',format('update economics_v2.group_occupancy_periods set starts_on=''infinity'' where id=%L',source_period),'22023','invalid_request','effective_on'),
    ('period_negative_infinity',format('update economics_v2.group_occupancy_periods set starts_on=''-infinity'' where id=%L',source_period),'22023','invalid_request','effective_on'),
    ('disabled_phase',format('update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=%L',f.farm_a),'42501','forbidden','granja_id'))
    v(label,setup_sql,state,code,field) loop
    begin
      execute probe.setup_sql;
      perform pg_temp.checked(call_sql,probe.state,probe.code,probe.field);
      raise exception using errcode='Z0001',message='F2DV restore isolated probe';
    exception when sqlstate 'Z0001' then
      null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'probe fully restored: '||probe.label);
    -- Assertions inside the rolled-back probe are intentionally counted here, after restoration.
    perform pg_temp.check_true(true,'typed/no-DML/full-state/sequence probe completed: '||probe.label);
  end loop;

  -- Trusted owner/editor gateway retains JWT identity; direct private calls retain denial semantics.
  for actor in select * from (values
    (f.owner_a,'authenticated',true),(f.editor_a,'authenticated',true),
    (f.viewer_a,'authenticated',false),(null::uuid,'anon',false)) v(id,role_name,allowed) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    if actor.allowed then
      repeated := pg_temp.checked(call_sql);
      perform pg_temp.check_true(repeated->>'actor_id'=actor.id::text
        and repeated->'scope'->>'actor_id'=actor.id::text
        and repeated->'basis'=a->'basis','trusted gateway preserves actual owner/editor JWT');
    else
      perform pg_temp.checked(call_sql,'42501','forbidden','granja_id');
    end if;
    perform pg_temp.checked(format('select economics_v2.validate_group_meat_nonclosing_source(%L,%L,current_date)',
      f.farm_a,f.animal_a),'42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  select * into proc from pg_proc
    where oid='economics_v2.validate_group_meat_nonclosing_source(uuid,uuid,date)'::regprocedure;
  perform pg_temp.check_true(proc.prorettype='jsonb'::regtype and not proc.prosecdef
    and proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(proc.proacl,acldefault('f',proc.proowner))) acl
      where acl.grantee=0 and acl.privilege_type='EXECUTE')
    and not has_function_privilege('anon',proc.oid,'EXECUTE')
    and not has_function_privilege('authenticated',proc.oid,'EXECUTE'),'jsonb/private invoker/empty path/actual PUBLIC ACL');

  -- Independently prove statement instrumentation detects a zero-row business write.
  perform pg_temp.check_true((select count(*)=13 and bool_and(
      (t.tgtype::integer & 1)=0 and (t.tgtype::integer & 2)=2 and (t.tgtype::integer & 28)=28)
    from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
    join pg_temp.watched_tables w on w.schema_name=n.nspname and w.table_name=c.relname
    where t.tgname='f2dv_no_dml'),'all10 forward plus animal/baja/sale BEFORE statement DML blockers');
  perform pg_temp.checked('with attempt as (update public.animales set activo=activo where false returning id)
    select to_jsonb(attempt) from attempt','P0001');
  set constraints all immediate;
  perform pg_temp.check_true((select bool_and(m.position_span<@p.position_span)
    from economics_v2.group_occupancy_memberships m join economics_v2.group_occupancy_periods p on p.id=m.period_id
    where m.granja_id=f.farm_a),'forced deferred containment of all real memberships');
  perform pg_temp.check_true((select count(*)=3 from economics_v2.group_occupancy_operations where granja_id=f.farm_a)
    and (select count(*)=3 and bool_and(action='enter') from economics_v2.group_occupancy_events where granja_id=f.farm_a)
    and not exists(select 1 from economics_v2.group_meat_snapshots where granja_id in(f.farm_a,f.farm_b))
    and not exists(select 1 from economics_v2.group_occupancy_periods where granja_id=f.farm_a
      and (closed_on is not null or end_position is not null)),'only real initial operations/events; no disposition or closure');
  perform pg_temp.check_true((select count(*)=3 and bool_and(to_jsonb(b)=c.basis)
    from economics_v2.group_animal_acquisition_basis b join pg_temp.captures c using(animal_id))
    and (select sum(signed_amount)=300 from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a),
    'all captures and signed300 preserved; no operation reservation, completion or position issue');
end;
$proof$;

-- This named PASS can only be produced by actual full execution after implementation.
-- Context is internal same-transaction working data, NOT a public result, receipt or permission token.
select jsonb_build_object('result','group_economics_forward_disposition_source_validation_pass',
  'assertion_count',(select count(*) from assertions),'locking_evidence','sequential_only',
  'validator_write_free',true,'validation_is_operation',false,'fixture_ids',(select to_jsonb(ids) from ids)) as evidence;
rollback;
