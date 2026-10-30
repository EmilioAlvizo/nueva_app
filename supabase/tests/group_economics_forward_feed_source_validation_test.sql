begin;

-- HUMAN sandbox Dashboard: save/run this FULL BEGIN/ROLLBACK file; report the first error.
-- Expected first RED: 42883 at the exact four-argument NEW private source validator below.
-- Full-unit forecast: fixture <=430 + future private migration <=220 = <=650 lines.
-- Accepted order: private F3 source/facts prerequisite, then canonical F4 producers and real F5 closure.
-- Prior nonclosing F2 proofs do NOT establish full F2, public activation or independent approval.
-- Real legacy mixture create/update and category archival run BEFORE forward meat admission.
-- No manual positive mezcla/comida/component/allocation rows, legacy open-meat bypass or fake finalizer.
-- Read-only source context is not a token, persisted allocation, operation receipt or full F3 API.
-- Future writers own immutable allocation-target checks/ordered fact locks/atomic capture; F5 compares
-- persisted source version/digest under its own locks before real finalization/snapshot creation.
-- Arithmetic: mezcla_comida.cantidad is ingredient kg; comida.precio is TOTAL ingredient cost.
-- Snapshot canonicalization: SHA256 of canonical JSON exact8 source_version/granja_id/mixture_id/
-- group_id/fecha_inicio/fecha_termino/updated_at_utc/components; components ordered by component UUID.
-- Each component is exact5 component_id/food_id/category_id/quantity_kg/total_cost. UTC is ISO microseconds Z.
-- Stock cantidad and mutable category activo are not ingredient kg/cost and do not enter the digest.
-- Context is exact12 as asserted below. Current owner/editor authorization is independent of creator.
-- Scoped source validation: open farm/Group/meat period, source date bounds/version, owned unshared
-- dedicated producer rows, nonempty complete finite components. No allocation/finalization/replay writes.
-- Closed metadata below is a rolled-back negative corruption probe, NOT real F5 proof.
create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,gen_random_uuid() type_b,
  gen_random_uuid() meat,gen_random_uuid() meat_b,gen_random_uuid() posture,gen_random_uuid() group_a,gen_random_uuid() group_other,gen_random_uuid() group_b,
  gen_random_uuid() category_a,gen_random_uuid() category_second,gen_random_uuid() category_b,
  gen_random_uuid() mixture_a,gen_random_uuid() mixture_zero,gen_random_uuid() mixture_old,
  gen_random_uuid() mixture_other,gen_random_uuid() mixture_b,
  gen_random_uuid() animal_a,gen_random_uuid() anchor_a,gen_random_uuid() animal_b,gen_random_uuid() exit_a;
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
  ('economics_v2','group_period_sale_bindings'),('economics_v2','group_meat_snapshots'),('economics_v2','feature_flags'),
  ('public','mezcla'),('public','mezcla_comida'),('public','comida'),('public','cat_comida'),('public','animales'),
  ('public','bajas_animales'),('public','venta_animal'),('public','grupos'),('public','tipo_animal'),
  ('public','cat_proposito_animal'),('public','miembros_granja');
create function pg_temp.business_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; rows jsonb; result jsonb:='{}'; farms uuid[]; actors uuid[];
begin
  select array[farm_a,farm_b],array[owner_a,owner_b,editor_a,viewer_a] into farms,actors from pg_temp.ids;
  for t in select * from pg_temp.watched_tables order by schema_name,table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r where granja_id=any($1) or granja_id is null',t.schema_name,t.table_name) into rows using farms;
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
  if current_setting('f3fs.no_write',true)='on' then
    raise exception using errcode='P0001',message='F3FS unexpected validator DML';
  end if;
  return null;
end;
$$;
do $blockers$
declare t record;
begin
  for t in select * from pg_temp.watched_tables loop
    execute format('create trigger f3fs_no_write before insert or update or delete on %I.%I
      for each statement execute function pg_temp.no_write()',t.schema_name,t.table_name);
  end loop;
end;
$blockers$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,p_field text default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare baseline jsonb; before_seq jsonb; result jsonb; state text; detail text;
begin
  baseline:=pg_temp.business_state();
  before_seq:=pg_temp.position_state();
  perform set_config('f3fs.no_write','on',true);
  begin
    execute p_sql into result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics state=returned_sqlstate,detail=pg_exception_detail;
  end;
  perform set_config('f3fs.no_write','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'all source/business rows unchanged: '||p_sql);
  perform pg_temp.check_true(pg_temp.position_state()=before_seq,'sequence unchanged: '||p_sql);
  if p_state is null then
    perform pg_temp.check_true(result is not null,'nonempty source context');
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
create function pg_temp.validate_feed(p_farm uuid,p_period uuid,p_mixture uuid,p_expected_updated_at timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  -- Trusted fixture caller only. No source DML, prepared operation or substituted actor.
  -- FIRST intended NEW typed call: missing-function error escapes before any implementation.
  return economics_v2.validate_group_feed_source(p_farm,p_period,p_mixture,p_expected_updated_at);
end;
$$;

select pg_temp.check_true(not exists(select 1 from auth.users
  where raw_user_meta_data->>'fixture'='group-feed-source-validation'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"group-feed-source-validation"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F3FS farm A',owner_a from ids union all select farm_b,owner_b,'F3FS farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F3FS type A',owner_a from ids union all select type_b,farm_b,'F3FS type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat,farm_a,'F3FS meat A','carne',owner_a from ids
union all select posture,farm_a,'F3FS posture A','postura',owner_a from ids
union all select meat_b,farm_b,'F3FS meat B','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'F3FS group '||g::text,owner_a from ids cross join lateral unnest(array[group_a,group_other]) g
union all select group_b,farm_b,type_b,'F3FS foreign group',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select category_a,farm_a,'F3FS ingredient A',true,owner_a from ids
union all select category_second,farm_a,'F3FS ingredient second',true,owner_a from ids
union all select category_b,farm_b,'F3FS ingredient B',true,owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
-- Actual source producer, not manually inserted positive ingredient rows. No forward periods yet.
-- Preserve the active-mixture trigger: old -> A -> actual A update -> zero, in date order.
select public.crear_mezcla_completa(farm_a,mixture_old,current_date-6,group_a,jsonb_build_array(
  jsonb_build_object('categoria_id',category_a,'cantidad_kg',1,'costo_total',5))) from ids;
select public.crear_mezcla_completa(farm_a,mixture_a,current_date-3,group_a,jsonb_build_array(
  jsonb_build_object('categoria_id',category_a,'cantidad_kg',2,'costo_total',50),
  jsonb_build_object('categoria_id',category_second,'cantidad_kg',3,'costo_total',30))) from ids;
select public.crear_mezcla_completa(farm_a,mixture_other,current_date-2,group_other,jsonb_build_array(
  jsonb_build_object('categoria_id',category_a,'cantidad_kg',1,'costo_total',10))) from ids;
create temp table old_versions as select id,updated_at from public.mezcla where id=(select mixture_a from ids);
select public.eliminar_categoria_comida_segura(farm_a,category_a) from ids;
-- Real update retains a referenced inactive category, as the verified legacy contract permits.
select public.actualizar_mezcla_completa(mixture_a,farm_a,(select updated_at from old_versions),
  current_date-2,null::date,group_a,jsonb_build_array(
    jsonb_build_object('categoria_id',category_a,'cantidad_kg',2,'costo_total',100),
    jsonb_build_object('categoria_id',category_second,'cantidad_kg',3,'costo_total',30))) from ids;
-- Retain the real update version as the stale witness. Later automatic closure uses now(),
-- which can equal the original create version within this same transaction.
update pg_temp.old_versions v set updated_at=m.updated_at from public.mezcla m where m.id=v.id;
-- A is still active during its update; only this later real create closes A at day -1.
select public.crear_mezcla_completa(farm_a,mixture_zero,current_date-1,group_a,jsonb_build_array(
  jsonb_build_object('categoria_id',category_second,'cantidad_kg',1,'costo_total',0))) from ids;
select set_config('request.jwt.claim.sub',owner_b::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_b,'role','authenticated')::text,true) from ids;
select public.crear_mezcla_completa(farm_b,mixture_b,current_date-2,group_b,jsonb_build_array(
  jsonb_build_object('categoria_id',category_b,'cantidad_kg',7,'costo_total',70))) from ids;
-- Only now admit actual forward meat periods, preserving the later legacy guard boundary.
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,notas,created_by)
select a,farm_a,type_a,group_a,meat,current_date-7,case when a=animal_a then 300 else 0 end,'F3FS animal A',owner_a
from ids cross join lateral unnest(array[animal_a,anchor_a]) a
union all select animal_b,farm_b,type_b,group_b,meat_b,current_date-7,0,'F3FS animal B',owner_b from ids;
create temp table initial(animal_id uuid,result jsonb);
insert into initial select animal_b,economics_v2.enter_group_meat_initial(farm_b,gen_random_uuid(),animal_b,
  current_date-4,group_b,meat_b,'{}') from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
insert into initial select a,economics_v2.enter_group_meat_initial(farm_a,gen_random_uuid(),a,current_date-4,group_a,meat,'{}')
from ids cross join lateral unnest(array[animal_a,anchor_a]) a;
create temp table sources as select id,grupo_id,updated_at,fecha_inicio from public.mezcla
where granja_id in(select farm_a from ids union all select farm_b from ids);
select pg_temp.check_true((select s.updated_at is distinct from v.updated_at
  from sources s join old_versions v on v.id=s.id),'actual update version differs from later closure version');
set constraints all immediate;
set constraints all deferred;
do $grants$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$grants$;
grant execute on function pg_temp.validate_feed(uuid,uuid,uuid,timestamptz),pg_temp.checked(text,text,text,text),
  pg_temp.business_state(),pg_temp.position_state(),pg_temp.check_true(boolean,text) to authenticated,anon;
create temp table contexts(value jsonb);
do $first$
declare f record; period uuid; version timestamptz; result jsonb; baseline jsonb; before_seq jsonb;
begin
  select * into f from pg_temp.ids;
  select (i.result->>'destination_period_id')::uuid into period from pg_temp.initial i where i.animal_id=f.animal_a;
  select updated_at into version from pg_temp.sources where id=f.mixture_a;
  baseline:=pg_temp.business_state();
  before_seq:=pg_temp.position_state();
  perform set_config('f3fs.no_write','on',true);
  set local role authenticated;
  result:=pg_temp.validate_feed(f.farm_a,period,f.mixture_a,version);
  reset role;
  perform set_config('f3fs.no_write','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=baseline and pg_temp.position_state()=before_seq,'first source read writes/sequence none');
  insert into pg_temp.contexts values(result);
end;
$first$;

do $proof$
declare f record; period_a uuid; period_b uuid; r jsonb; repeated jsonb; snapshot jsonb; components jsonb;
  sql text; baseline jsonb; version timestamptz; old_zone text; mode text; actor record; probe record; food uuid; proc record;
  invalid_start date; changed_snapshot jsonb;
begin
  select * into f from pg_temp.ids;
  select (result->>'destination_period_id')::uuid into period_a from pg_temp.initial where animal_id=f.animal_a;
  select (result->>'destination_period_id')::uuid into period_b from pg_temp.initial where animal_id=f.animal_b;
  select value into r from pg_temp.contexts;
  select updated_at into version from pg_temp.sources where id=f.mixture_a;
  sql:=format('select pg_temp.validate_feed(%L,%L,%L,%L::timestamptz)',f.farm_a,period_a,f.mixture_a,version);
  repeated:=pg_temp.checked(sql);
  perform pg_temp.check_true(repeated=r,'repeated source validation persists no replay ledger');
  select jsonb_agg(jsonb_build_object('component_id',mc.id,'food_id',c.id,'category_id',c.cat_comida_id,
    'quantity_kg',mc.cantidad,'total_cost',c.precio) order by mc.id) into components
  from public.mezcla_comida mc join public.comida c on c.id=mc.comida_id where mc.mezcla_id=f.mixture_a;
  select economics_v2.canonical_group_request(jsonb_build_object('source_version','group-feed-source.v1',
    'granja_id',m.granja_id,'mixture_id',m.id,'group_id',m.grupo_id,'fecha_inicio',m.fecha_inicio,
    'fecha_termino',m.fecha_termino,'updated_at_utc',to_char(m.updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'components',components)) into snapshot from public.mezcla m where m.id=f.mixture_a;
  perform pg_temp.check_true(r=jsonb_build_object('context_version','group-feed-source-context.v1','actor_id',f.owner_a,
    'granja_id',f.farm_a,'period_id',period_a,'mixture_id',f.mixture_a,'source_updated_at',version,'occurred_on',current_date-2,
    'component_count',2,'quantity_kg',5,'total_cost',130,'source_digest',encode(sha256(convert_to(snapshot::text,'UTF8')),'hex'),
    'source_snapshot',snapshot) and (select count(*)=12 from jsonb_object_keys(r)),
    'exact12 context/exact8 source snapshot/UUID-ordered exact5 components/UTC canonical SHA256');
  perform pg_temp.check_true(r->'total_cost'='130'::jsonb and r->'quantity_kg'='5'::jsonb
    and not (select activo from public.cat_comida where id=f.category_a),
    'TOTAL100+30 not unit-price290; source kg2+3; existing inactive category remains legitimate');
  repeated:=pg_temp.checked(format('select pg_temp.validate_feed(%L,%L,%L,%L::timestamptz)',
    f.farm_a,period_a,f.mixture_zero,(select updated_at from pg_temp.sources where id=f.mixture_zero)));
  perform pg_temp.check_true(repeated @> '{"component_count":1,"quantity_kg":1,"total_cost":0}'::jsonb,'recorded zero food cost is valid');
  old_zone:=current_setting('TimeZone');
  perform set_config('TimeZone','Etc/GMT+5',true);
  repeated:=pg_temp.checked(sql);
  perform pg_temp.check_true(repeated->'source_digest'=r->'source_digest' and repeated->'source_snapshot'=snapshot,
    'digest independent of session timestamp rendering');
  perform set_config('TimeZone',old_zone,true);
  for actor in select * from (values(f.editor_a,'authenticated'),(f.owner_b,'authenticated'),
    (f.viewer_a,'authenticated'),(null::uuid,'anon')) v(id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    if actor.id=f.editor_a then
      repeated:=pg_temp.checked(sql);
      perform pg_temp.check_true(repeated=r||jsonb_build_object('actor_id',f.editor_a),'actual editor reads owner-produced source without creator impersonation');
    elsif actor.id=f.owner_b then
      perform pg_temp.checked(sql,'42501','forbidden','granja_id');
      perform pg_temp.checked(format('select pg_temp.validate_feed(%L,%L,%L,%L::timestamptz)',
        f.farm_b,period_b,f.mixture_a,version),'42501','forbidden','mixture_id');
    else
      perform pg_temp.checked(sql,'42501','forbidden','granja_id');
    end if;
    perform pg_temp.checked('select economics_v2.validate_group_feed_source(null::uuid,null::uuid,null::uuid,null::timestamptz)','42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  for probe in select * from (values
    (period_b,f.mixture_a,version,'42501','forbidden','period_id'),
    (period_a,f.mixture_b,(select updated_at from pg_temp.sources where id=f.mixture_b),'42501','forbidden','mixture_id'),
    (period_a,f.mixture_other,(select updated_at from pg_temp.sources where id=f.mixture_other),'42501','forbidden','group_id'),
    (period_a,f.mixture_old,(select updated_at from pg_temp.sources where id=f.mixture_old),'22023','invalid_request','occurred_on'),
    (period_a,f.mixture_a,(select updated_at from pg_temp.old_versions),'40001','stale_write','mixture_id'),
    (period_a,f.mixture_a,null::timestamptz,'22023','invalid_request','expected_updated_at'),
    (null::uuid,f.mixture_a,version,'22023','invalid_request','period_id'),
    (period_a,null::uuid,version,'22023','invalid_request','mixture_id')) v(period,mixture,expected,state,code,field) loop
    perform pg_temp.checked(format('select pg_temp.validate_feed(%L,%L,%L,%L::timestamptz)',
      f.farm_a,probe.period,probe.mixture,probe.expected),probe.state,probe.code,probe.field);
  end loop;
  select c.id into food from public.comida c join public.mezcla_comida mc on mc.comida_id=c.id
    where mc.mezcla_id=f.mixture_a and c.cat_comida_id=f.category_a;
  for mode in select unnest(array['missing_price','missing_kg','empty_components','foreign_food','shared_food','duplicate_category']) loop
    baseline:=pg_temp.business_state();
    begin
      case mode
        when 'missing_price' then update public.comida set precio=null where id=food;
        when 'missing_kg' then update public.mezcla_comida set cantidad=null where mezcla_id=f.mixture_a and comida_id=food;
        when 'empty_components' then delete from public.mezcla_comida where mezcla_id=f.mixture_a;
        when 'foreign_food' then update public.mezcla_comida set comida_id=(select comida_id from public.mezcla_comida where mezcla_id=f.mixture_b)
          where mezcla_id=f.mixture_a and comida_id=food;
        when 'shared_food' then insert into public.mezcla_comida(granja_id,mezcla_id,comida_id,cantidad)
          values(f.farm_a,f.mixture_other,food,1);
        when 'duplicate_category' then update public.comida set cat_comida_id=f.category_a where id in(
          select comida_id from public.mezcla_comida where mezcla_id=f.mixture_a) and id<>food;
      end case;
      if mode='foreign_food' then
        perform pg_temp.checked(sql,'42501','forbidden','food_id');
      else
        perform pg_temp.checked(sql,'23514','invariant_violation','mixture_id');
      end if;
      raise exception using errcode='Z0001',message='F3FS restore source corruption';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'source corruption restored exactly: '||mode);
  end loop;
  baseline:=pg_temp.business_state();
  begin
    update public.comida set cantidad=100 where id=food;
    repeated:=pg_temp.checked(sql);
    perform pg_temp.check_true(repeated=r,'stock quantity is not ingredient kg or cost proration');
    raise exception using errcode='Z0001',message='F3FS restore stock probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'stock probe restored');
  -- The source schema permits these dates on an already ended mixture. The validator,
  -- not a table constraint or the active-mixture trigger, must reject each invalid start.
  for invalid_start in select unnest(array[current_date+1,'infinity'::date,'-infinity'::date]) loop
    baseline:=pg_temp.business_state();
    begin
      update public.mezcla set fecha_inicio=invalid_start where id=f.mixture_a;
      perform pg_temp.checked(sql,'22023','invalid_request','occurred_on');
      raise exception using errcode='Z0001',message='F3FS restore invalid source date';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'invalid source date restored: '||invalid_start::text);
  end loop;
  baseline:=pg_temp.business_state();
  begin
    -- Negative target corruption only: do not fabricate a successful nonmeat occupancy.
    update economics_v2.group_occupancy_periods set purpose_id=f.posture where id=period_a;
    perform pg_temp.checked(sql,'22023','invalid_request','purpose_id');
    raise exception using errcode='Z0001',message='F3FS restore nonmeat target';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'nonmeat target metadata restored');
  baseline:=pg_temp.business_state();
  begin
    -- Legal economic corruption probe: a preserved mixture timestamp cannot mask changed cost.
    update public.comida set precio=precio+1 where id=food;
    repeated:=pg_temp.checked(sql);
    select jsonb_agg(jsonb_build_object('component_id',mc.id,'food_id',c.id,'category_id',c.cat_comida_id,
      'quantity_kg',mc.cantidad,'total_cost',c.precio) order by mc.id) into components
    from public.mezcla_comida mc join public.comida c on c.id=mc.comida_id where mc.mezcla_id=f.mixture_a;
    changed_snapshot:=economics_v2.canonical_group_request(jsonb_set(snapshot,'{components}',components));
    perform pg_temp.check_true((select updated_at=version from public.mezcla where id=f.mixture_a)
      and repeated=r||jsonb_build_object('total_cost',131,'source_snapshot',changed_snapshot,
        'source_digest',encode(sha256(convert_to(changed_snapshot::text,'UTF8')),'hex'))
      and repeated->'source_digest'<>r->'source_digest',
      'economic component change changes canonical digest even when mixture version is unchanged');
    raise exception using errcode='Z0001',message='F3FS restore economic component';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'economic component probe restored');
  begin
    update economics_v2.group_occupancy_periods set closed_on=current_date,end_position=start_position+1000 where id=period_a;
    perform pg_temp.checked(sql,'23514','closed_period_immutable','period_id');
    raise exception using errcode='Z0001',message='F3FS restore closed metadata probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'closed metadata negative restored; no real F5 closure claimed');
  begin
    update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
    perform pg_temp.checked(sql,'42501','forbidden','granja_id');
    raise exception using errcode='Z0001',message='F3FS restore flag';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'disabled phase probe restored');
  select * into proc from pg_proc where oid='economics_v2.validate_group_feed_source(uuid,uuid,uuid,timestamp with time zone)'::regprocedure;
  perform pg_temp.check_true(proc.prorettype='jsonb'::regtype and not proc.prosecdef and proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(proc.proacl,acldefault('f',proc.proowner))) acl where acl.grantee=0 and acl.privilege_type='EXECUTE')
    and not has_function_privilege('anon',proc.oid,'EXECUTE') and not has_function_privilege('authenticated',proc.oid,'EXECUTE'),'private invoker/empty path/client EXECUTE false');
  set constraints all immediate;
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_period_feed_allocations where granja_id in(f.farm_a,f.farm_b))
    and (select count(*)=3 from economics_v2.group_occupancy_operations where granja_id in(f.farm_a,f.farm_b))
    and economics_v2.calculate_group_period_live_metrics(f.farm_a,period_a) @> '{"feed_cost":0,"acquisition_cost":300}'::jsonb
    and not exists(select 1 from economics_v2.group_meat_snapshots where granja_id in(f.farm_a,f.farm_b)),
    'source validation persists no allocation/operation; metrics still omit uncaptured feed; no F5 snapshot');
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_feed_source_validation_pass',
  'assertion_count',(select count(*) from assertions),'locking_evidence','sequential_only','source_validation_write_free',true,
  'allocation_capture_performed',false,'canonical_group_food_api_integrated',false,'real_closure_proven',false,
  'production_gateway_integrated',false,'independent_review','pending','fixture_ids',(select to_jsonb(ids) from ids)) as evidence;
rollback;
