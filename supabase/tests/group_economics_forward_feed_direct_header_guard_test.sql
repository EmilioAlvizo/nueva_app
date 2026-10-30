begin;

-- HUMAN Sandbox Dashboard only: review, then run this FULL BEGIN/ROLLBACK file.
-- Fixture FIRST; no production helper, trigger, gateway or producer ACL changes.
-- Expected FIRST RED: actual authenticated INSERT reaches the retained cardinality
-- trigger's upsert: P0001, group_feed_integrity.fences INSERT, with MESSAGE
-- 'Direct header write attempted internal DML before forward refusal'.
-- Do NOT observe public.mezcla BEFORE STATEMENT: that precedes the future row guard.
-- Future BEFORE ROW SECURITY INVOKER guard must sort before mezcla_one_active_per_group
-- (for example mezcla_forward_header_guard), seeing actual effective current_user.
-- Privileged authority means real rolsuper/rolbypassrls AND operation table permission;
-- never a role name, JWT, session_user, SET ROLE string, marker, flag or trigger depth.
-- A private read-only definer must authorize actual OLD/NEW farms and Groups BEFORE
-- history reads; ANY OLD/NEW UUID allocation has no farm filter after source ownership.
-- ANY owned open meat period on either Group blocks, including ambiguous cardinality.
-- Fallback open creation/reopening/movement must protect ANY allocated active sibling
-- before cardinality's privileged auto-close. Caller marker repair is not an exemption.
-- Exact4 HEADER refusal: 23514 / forward.v3 / forward_group_period_required /
-- mixture_id / INSERT NEW.id, UPDATE OLD.id (including UUID changes), DELETE OLD.id.
-- Grants/RLS are retained: authenticated CRUD on all three source tables, farm editor
-- checks, and foreign invisible UPDATE/DELETE zero rows, not invented authorization errors.
-- Component/food UUID-only cascading FKs are NOT fixed by this header-only fixture.
-- Synthetic singleton-safe purpose loss is NOT closure. Higher isolation is unproven:
-- do not switch transaction isolation after setup reads. Concurrency/review remain pending.
-- Full unit forecast: fixture 461 + complete future helper/invoker/ACL/trigger <=300
-- = <=761 authored lines, cap800. No shortened-diff accounting or minified SQL.
-- Setup consumes event positions; ROLLBACK does not rewind sequences. Use isolation
-- from other Sandbox traffic; all observed controls/refusals preserve sequence values.

create temp table ids as select
  gen_random_uuid() owner_a, gen_random_uuid() owner_b,
  gen_random_uuid() editor_a, gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a, gen_random_uuid() farm_b,
  gen_random_uuid() type_a, gen_random_uuid() type_b,
  gen_random_uuid() meat_a, gen_random_uuid() eggs_a,
  gen_random_uuid() group_meat_a, gen_random_uuid() group_meat_b,
  gen_random_uuid() group_egg_a, gen_random_uuid() group_egg_b, gen_random_uuid() group_foreign,
  gen_random_uuid() animal_meat_a, gen_random_uuid() animal_meat_b,
  gen_random_uuid() animal_egg_a, gen_random_uuid() animal_egg_b,
  gen_random_uuid() category_a, gen_random_uuid() category_b,
  gen_random_uuid() dormant_source, gen_random_uuid() allocated_source,
  gen_random_uuid() unallocated_source, gen_random_uuid() egg_source, gen_random_uuid() foreign_source,
  gen_random_uuid() fresh_source, gen_random_uuid() changed_source,
  gen_random_uuid() direct_first, gen_random_uuid() direct_second,
  gen_random_uuid() legacy_control, gen_random_uuid() private_control,
  gen_random_uuid() create_op, gen_random_uuid() update_op, gen_random_uuid() delete_op;
create temp table assertions(label text not null);
create function pg_temp.check_true(p_ok boolean, p_label text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%', p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
create temp table watched as
select n.nspname schema_name, c.relname table_name
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where c.relkind in ('r','p') and (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users'));
create temp table watched_sequences as
select n.nspname schema_name, c.relname sequence_name
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity');
create function pg_temp.business_state(p_controls boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare f record; t record; v_rows jsonb; v_result jsonb:='{}'; v_filter text;
  v_ids text[]; v_sources uuid[]; v_foods uuid[];
begin
  select * into f from pg_temp.ids;
  select array_agg(value) into v_ids from jsonb_each_text(to_jsonb(f));
  v_sources:=array[f.direct_first,f.direct_second,f.legacy_control,f.private_control];
  select coalesce(array_agg(comida_id),'{}'::uuid[]) into v_foods
    from public.mezcla_comida where mezcla_id=any(v_sources);
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    v_filter:=' where (to_jsonb(r)->>''granja_id''=any($1)
      or to_jsonb(r)->>''id''=any($2) or to_jsonb(r)->>''user_id''=any($2)
      or to_jsonb(r)->>''entity_id''=any($2) or to_jsonb(r)->>''group_id''=any($2)
      or to_jsonb(r)->>''grupo_id''=any($2))';
    if p_controls then
      if t.schema_name='public' and t.table_name='mezcla' then
        v_filter:=v_filter||' and not r.id=any($3)';
      elsif t.schema_name='public' and t.table_name='mezcla_comida' then
        v_filter:=v_filter||' and not r.mezcla_id=any($3)';
      elsif t.schema_name='public' and t.table_name='comida' then
        v_filter:=v_filter||' and not r.id=any($4)';
      elsif t.schema_name='economics_v2' and t.table_name='group_period_feed_allocations' then
        v_filter:=v_filter||' and not r.mixture_id=any($3)';
      elsif t.schema_name='economics_v2' and t.table_name='group_occupancy_operations' then
        v_filter:=v_filter||' and not r.operation_id=any($5)';
      elsif t.schema_name='group_feed_integrity' and t.table_name='fences' then
        v_filter:=v_filter||' and not (r.scope=''group'' and r.entity_id=any($6))';
      end if;
    end if;
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r%s',t.schema_name,t.table_name,v_filter)
      into v_rows using array[f.farm_a::text,f.farm_b::text],v_ids,v_sources,v_foods,
        array[f.create_op,f.update_op,f.delete_op],array[f.group_egg_b,f.group_meat_b];
    v_result:=v_result||jsonb_build_object(t.schema_name||'.'||t.table_name,v_rows);
  end loop;
  for t in select * from pg_temp.watched_sequences order by schema_name,sequence_name loop
    execute format('select jsonb_build_object(''last_value'',s.last_value,''is_called'',s.is_called)
      from %I.%I s',t.schema_name,t.sequence_name) into v_rows;
    v_result:=v_result||jsonb_build_object(t.schema_name||'.'||t.sequence_name,v_rows);
  end loop;
  return v_result;
end;
$$;
create temp table acl_baseline as
select 'table' kind,c.oid,to_jsonb(c.relacl) acl from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','economics_v2','group_feed_integrity')
union all select 'function',p.oid,to_jsonb(p.proacl) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','economics_v2','group_feed_integrity');

select set_config('direct_header_guard.armed','off',true);
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"direct-header-guard"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Direct header farm A',owner_a from ids
union all select farm_b,owner_b,'Direct header farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Direct header type A',owner_a from ids
union all select type_b,farm_b,'Direct header type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Direct header meat','carne',owner_a from ids
union all select eggs_a,farm_a,'Direct header eggs','postura',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'Direct header Group '||g::text,owner_a from ids
cross join lateral unnest(array[group_meat_a,group_meat_b,group_egg_a,group_egg_b]) g
union all select group_foreign,farm_b,type_b,'Direct header foreign Group',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select category_a,farm_a,'Direct header ingredient A',true,owner_a from ids
union all select category_b,farm_b,'Direct header ingredient B',true,owner_b from ids;
do $temp_access$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$temp_access$;
grant select on pg_temp.ids to authenticated;
grant insert on pg_temp.assertions to authenticated,anon;
-- Real legacy creators under actual authenticated owner/editor roles, BEFORE entry.
do $legacy_setup$
declare f record; s record;
begin
  select * into f from pg_temp.ids;
  for s in select * from (values
    (1,f.owner_a,f.farm_a,f.dormant_source,f.group_meat_a,f.category_a,current_date-4),
    (2,f.owner_a,f.farm_a,f.allocated_source,f.group_meat_a,f.category_a,current_date-3),
    (3,f.editor_a,f.farm_a,f.unallocated_source,f.group_meat_b,f.category_a,current_date-3),
    (4,f.owner_a,f.farm_a,f.egg_source,f.group_egg_a,f.category_a,current_date-3),
    (5,f.owner_b,f.farm_b,f.foreign_source,f.group_foreign,f.category_b,current_date-3))
    q(ordinal,actor,farm,source_id,group_id,category_id,starts_on) order by ordinal loop
    perform set_config('request.jwt.claim.sub',s.actor::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',s.actor,'role','authenticated')::text,true);
    set local role authenticated;
    perform public.crear_mezcla_completa(s.farm,s.source_id,s.starts_on,s.group_id,
      jsonb_build_array(jsonb_build_object('categoria_id',s.category_id,'cantidad_kg',2,'costo_total',10)));
    reset role;
  end loop;
end;
$legacy_setup$;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,created_by)
select a,farm_a,type_a,g,p,current_date-7,300,owner_a from ids
cross join lateral (values (animal_meat_a,group_meat_a,meat_a),(animal_meat_b,group_meat_b,meat_a),
  (animal_egg_a,group_egg_a,eggs_a),(animal_egg_b,group_egg_b,eggs_a)) animals(a,g,p);
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
create temp table admissions as select a animal_id,economics_v2.enter_group_meat_initial(
  farm_a,gen_random_uuid(),a,current_date-4,g,meat_a,'{}') result from ids
cross join lateral (values (animal_meat_a,group_meat_a),(animal_meat_b,group_meat_b)) animals(a,g);
do $capture$
declare f record; m record; v_period uuid; v_context jsonb;
begin
  select * into f from pg_temp.ids;
  select * into m from public.mezcla where id=f.allocated_source;
  select (result->>'destination_period_id')::uuid into v_period from pg_temp.admissions
    where animal_id=f.animal_meat_a;
  v_context:=economics_v2.validate_group_feed_source(f.farm_a,v_period,m.id,m.updated_at);
  perform economics_v2.capture_group_feed_allocation(f.farm_a,gen_random_uuid(),v_period,
    m.id,m.updated_at,v_context->>'source_digest');
end;
$capture$;
set constraints all immediate;

do $preflight$
declare f record;
begin
  select * into f from pg_temp.ids;
  perform pg_temp.check_true((select count(*)=2 from economics_v2.group_occupancy_periods
    where granja_id=f.farm_a and purpose_id=f.meat_a and closed_on is null and end_position is null),
    'two genuine open meat Groups; egg Groups have no forward period');
  perform pg_temp.check_true((select count(*)=1 from economics_v2.group_period_feed_allocations
    where mixture_id=f.allocated_source) and not exists(select 1 from economics_v2.group_period_feed_allocations
    where mixture_id in (f.unallocated_source,f.dormant_source,f.egg_source)), 'only intended source allocated');
  perform pg_temp.check_true((select count(*)=1 from public.mezcla where grupo_id=f.group_meat_a
    and fecha_termino is null) and (select fecha_termino=current_date-3 from public.mezcla
    where id=f.dormant_source), 'real legacy auto-close left exactly one active allocated sibling');
  perform pg_temp.check_true(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='economics_v2' and p.proname in ('enter_group_meat_initial','validate_group_feed_source',
      'capture_group_feed_allocation','create_group_feed_allocation','update_group_feed_allocation',
      'delete_group_feed_allocation','raise_group_writer_error')
    and (has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE'))),
    'private cores and error helper remain unavailable to clients');
  perform pg_temp.check_true(not exists(select 1 from unnest(array['mezcla','mezcla_comida','comida']) t
    where not has_table_privilege('authenticated','public.'||t,'SELECT,INSERT,UPDATE,DELETE')),
    'existing authenticated direct CRUD retained on all three source tables');
end;
$preflight$;
create function pg_temp.guard_dml()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('direct_header_guard.armed',true)='on' then
    raise exception using errcode='P0001',
      message='Direct header write attempted internal DML before forward refusal',
      detail=tg_table_schema||'.'||tg_table_name||' '||tg_op;
  end if;
  return null;
end;
$$;
do $observers$
declare t record;
begin
  for t in select * from pg_temp.watched
    where not (schema_name='public' and table_name='mezcla') loop
    execute format('create trigger direct_header_internal_dml_observer
      before insert or update or delete or truncate on %I.%I
      for each statement execute function pg_temp.guard_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;
create trigger direct_header_persist_observer after insert or update or delete on public.mezcla
for each row execute function pg_temp.guard_dml();
create function pg_temp.expect_refusal(p_sql text,p_source uuid,p_state text default '23514',
  p_field text default null,p_entity uuid default null)
returns void language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_detail text; v_refused boolean:=false;
begin
  v_before:=pg_temp.business_state();
  perform set_config('direct_header_guard.armed','on',true);
  begin
    execute p_sql;
  exception when check_violation then
    if p_state<>'23514' then raise; end if;
    get stacked diagnostics v_detail=pg_exception_detail;
    perform pg_temp.check_true(current_user='authenticated' and v_detail::jsonb=jsonb_build_object(
      'contract_version','group-economics.forward.v3','code','forward_group_period_required',
      'field','mixture_id','entity_id',p_source), 'exact4 direct header refusal protects actual source UUID');
    v_refused:=true;
  when insufficient_privilege then
    if p_state<>'42501' then raise; end if;
    if p_field is not null then
      get stacked diagnostics v_detail=pg_exception_detail;
      perform pg_temp.check_true(v_detail::jsonb=jsonb_build_object('contract_version','group-economics.forward.v3',
        'code','forbidden','field',p_field,'entity_id',p_entity), 'actual NEW farm/Group authorization precedes history');
    end if;
    v_refused:=true;
  end;
  perform set_config('direct_header_guard.armed','off',true);
  perform pg_temp.check_true(v_refused,'direct statement refuses with '||p_state);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'all farm rows, facts, receipts, fences and sequences preserved');
end;
$$;
-- Trusted TEMP delegation only: actual private business cores, no substitute producer.
create function pg_temp.private_control(p_action text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare f record; v_period uuid; a record; m record;
begin
  select * into f from pg_temp.ids;
  perform pg_temp.check_true((select rolsuper or rolbypassrls from pg_roles where rolname=current_user)
    and has_table_privilege(current_user,'public.mezcla',p_action), 'actual effective privileged role has operation permission');
  select (result->>'destination_period_id')::uuid into v_period from pg_temp.admissions where animal_id=f.animal_meat_b;
  if p_action='INSERT' then
    return economics_v2.create_group_feed_allocation(f.farm_a,f.create_op,v_period,f.private_control,
      current_date-2,f.group_meat_b,jsonb_build_array(jsonb_build_object(
        'categoria_id',f.category_a,'cantidad_kg',3,'costo_total',12)));
  end if;
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.private_control;
  select * into m from public.mezcla where id=f.private_control;
  if p_action='UPDATE' then
    return economics_v2.update_group_feed_allocation(f.farm_a,f.update_op,v_period,m.id,a.updated_at,
      m.updated_at,a.source_digest,current_date-1,null,jsonb_build_array(jsonb_build_object(
        'categoria_id',f.category_a,'cantidad_kg',4,'costo_total',16)));
  end if;
  return economics_v2.delete_group_feed_allocation(f.farm_a,f.delete_op,v_period,m.id,
    a.updated_at,m.updated_at,a.source_digest);
end;
$$;
revoke all on function pg_temp.check_true(boolean,text),pg_temp.business_state(boolean),
  pg_temp.expect_refusal(text,uuid,text,text,uuid),pg_temp.private_control(text) from public;
grant execute on function pg_temp.check_true(boolean,text),pg_temp.business_state(boolean),
  pg_temp.expect_refusal(text,uuid,text,text,uuid) to authenticated,anon;
grant execute on function pg_temp.private_control(text) to authenticated;

do $negative_proof$
declare f record; s record; actor record; v_before jsonb; v_count bigint;
begin
  select * into f from pg_temp.ids;
  -- FIRST observed direct command: valid owned open meat Group, fresh UUID/date/actor.
  set local role authenticated;
  perform pg_temp.expect_refusal(format('insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
    values(%L,%L,%L,current_date-2,%L)',f.fresh_source,f.farm_a,f.group_meat_a,f.owner_a),f.fresh_source);
  reset role;
  for s in select * from (values
    (f.allocated_source,'fecha_inicio=current_date-2'),(f.allocated_source,'updated_at=clock_timestamp()'),
    (f.allocated_source,'group_feed_meat_exempt=true'),(f.allocated_source,format('id=%L',f.changed_source)),
    (f.allocated_source,format('grupo_id=%L',f.group_egg_b)),(f.allocated_source,'fecha_termino=current_date-1'),
    (f.unallocated_source,'updated_at=clock_timestamp()'),(f.unallocated_source,'group_feed_meat_exempt=false'),
    (f.egg_source,format('grupo_id=%L',f.group_meat_b)),(f.egg_source,format('id=%L',f.allocated_source)))
    q(source_id,assignments) loop
    set local role authenticated;
    perform pg_temp.expect_refusal(format('update public.mezcla set %s where id=%L',s.assignments,s.source_id),s.source_id);
    reset role;
  end loop;
  foreach v_count in array array[1::bigint,2::bigint] loop
    set local role authenticated;
    perform pg_temp.expect_refusal(format('delete from public.mezcla where id=%L',
      case when v_count=1 then f.allocated_source else f.unallocated_source end),
      case when v_count=1 then f.allocated_source else f.unallocated_source end);
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated',
    'purpose','postura','trusted_writer',true)::text,true);
  perform set_config('group_feed_integrity.trusted_writer','true',true);
  set local role authenticated;
  perform pg_temp.expect_refusal(format('update public.mezcla set updated_at=clock_timestamp() where id=%L',f.allocated_source),f.allocated_source);
  reset role;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  v_before:=pg_temp.business_state();
  begin
    update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
    set local role authenticated;
    perform pg_temp.expect_refusal(format('delete from public.mezcla where id=%L',f.unallocated_source),f.unallocated_source);
    reset role;
    update public.cat_proposito_animal set codigo_calculo='postura' where id=f.meat_a;
    perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_periods p
      join public.cat_proposito_animal c on c.id=p.purpose_id and c.granja_id=p.granja_id
      where p.granja_id=f.farm_a and p.closed_on is null and p.end_position is null and c.codigo_calculo='carne'),
      'reversible allocation-only classification; one active source per affected Group');
    set local role authenticated;
    perform pg_temp.expect_refusal(format('update public.mezcla set updated_at=clock_timestamp() where id=%L',f.allocated_source),f.allocated_source);
    perform pg_temp.expect_refusal(format('delete from public.mezcla where id=%L',f.allocated_source),f.allocated_source);
    perform pg_temp.expect_refusal(format('insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by,group_feed_meat_exempt)
      values(%L,%L,%L,current_date-2,%L,true)',f.fresh_source,f.farm_a,f.group_meat_a,f.owner_a),f.fresh_source);
    perform pg_temp.expect_refusal(format('update public.mezcla set fecha_termino=null where id=%L',f.dormant_source),f.dormant_source);
    perform pg_temp.expect_refusal(format('update public.mezcla set grupo_id=%L where id=%L',f.group_meat_a,f.egg_source),f.egg_source);
    perform pg_temp.expect_refusal(format('update public.mezcla set id=%L where id=%L',f.allocated_source,f.egg_source),f.egg_source);
    reset role;
    raise exception using errcode='Z0001',message='Restore synthetic purpose and flag probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'purpose, flag and all source/fence state restored');
  set local role authenticated;
  perform pg_temp.expect_refusal(format('update public.mezcla set grupo_id=%L where id=%L',f.group_foreign,f.egg_source),
    f.egg_source,'42501','group_id',f.group_foreign);
  perform pg_temp.expect_refusal(format('update public.mezcla set granja_id=%L where id=%L',f.farm_b,f.egg_source),
    f.egg_source,'42501','granja_id',f.farm_b);
  reset role;
  for actor in select * from (values (f.viewer_a,'authenticated'),(f.owner_b,'authenticated'),(null::uuid,'anon')) q(uid,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.uid::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.uid,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    perform pg_temp.expect_refusal(format('insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
      values(%L,%L,%L,current_date-2,%L)',f.fresh_source,f.farm_a,f.group_meat_a,f.owner_a),f.fresh_source,'42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  v_before:=pg_temp.business_state();
  set local role authenticated;
  update public.mezcla set updated_at=clock_timestamp() where id=f.foreign_source;
  get diagnostics v_count=row_count;
  perform pg_temp.check_true(v_count=0,'foreign invisible UPDATE is zero rows');
  delete from public.mezcla where id=f.foreign_source;
  get diagnostics v_count=row_count;
  perform pg_temp.check_true(v_count=0,'foreign invisible DELETE is zero rows');
  perform pg_temp.expect_refusal('select economics_v2.create_group_feed_allocation(null,null,null,null,null,null,null)',null,'42501');
  perform pg_temp.expect_refusal('select economics_v2.update_group_feed_allocation(null,null,null,null,null,null,null,null,null,null)',null,'42501');
  perform pg_temp.expect_refusal('select economics_v2.delete_group_feed_allocation(null,null,null,null,null,null,null)',null,'42501');
  reset role;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'RLS no-ops and direct core EXECUTE denials preserve state');
end;
$negative_proof$;

do $positive_controls$
declare f record; v_other jsonb; v_version timestamptz; v_result jsonb; v_foods uuid[]; v_action text;
begin
  select * into f from pg_temp.ids;
  v_other:=pg_temp.business_state(true);
  set local role authenticated;
  insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
    values(f.direct_first,f.farm_a,f.group_egg_b,current_date-2,f.owner_a);
  update public.mezcla set updated_at=clock_timestamp() where id=f.direct_first;
  insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
    values(f.direct_second,f.farm_a,f.group_egg_b,current_date-1,f.owner_a);
  reset role;
  perform pg_temp.check_true((select fecha_termino=current_date-1 from public.mezcla where id=f.direct_first)
    and (select fecha_termino is null and not group_feed_meat_exempt from public.mezcla where id=f.direct_second),
    'ordinary direct egg headers retain singleton auto-close without food production');
  perform pg_temp.check_true(pg_temp.business_state(true)=v_other,'direct egg writes change only control headers and egg fence');
  set local role authenticated;
  delete from public.mezcla where id in (f.direct_first,f.direct_second);
  perform public.crear_mezcla_completa(f.farm_a,f.legacy_control,current_date-2,f.group_egg_b,
    jsonb_build_array(jsonb_build_object('categoria_id',f.category_a,'cantidad_kg',2,'costo_total',10)));
  select updated_at into v_version from public.mezcla where id=f.legacy_control;
  perform public.actualizar_mezcla_completa(f.legacy_control,f.farm_a,v_version,current_date-1,null,f.group_egg_b,
    jsonb_build_array(jsonb_build_object('categoria_id',f.category_a,'cantidad_kg',3,'costo_total',12)));
  reset role;
  perform pg_temp.check_true((select sum(mc.cantidad)=3 and sum(c.precio)=12 from public.mezcla_comida mc
    join public.comida c on c.id=mc.comida_id where mc.mezcla_id=f.legacy_control), 'real legacy egg CREATE/UPDATE recipe');
  perform pg_temp.check_true(pg_temp.business_state(true)=v_other,'legacy egg controls preserve all unrelated metadata and economics');
  select array_agg(comida_id) into v_foods from public.mezcla_comida where mezcla_id=f.legacy_control;
  set local role authenticated;
  perform public.eliminar_mezcla_completa(f.farm_a,f.legacy_control);
  reset role;
  perform pg_temp.check_true(not exists(select 1 from public.mezcla where id=f.legacy_control)
    and not exists(select 1 from public.comida where id=any(v_foods)), 'real legacy egg DELETE removes source and dedicated foods');
  foreach v_action in array array['INSERT','UPDATE','DELETE'] loop
    set local role authenticated;
    v_result:=pg_temp.private_control(v_action);
    reset role;
    perform pg_temp.check_true(v_result->>'mixture_id'=f.private_control::text
      and v_result->'replayed'='false'::jsonb, 'real private core result under trusted temporary privileged delegation');
    if v_action<>'DELETE' then
      perform pg_temp.check_true((select a.quantity_kg=case when v_action='INSERT' then 3 else 4 end
        and a.total_cost=case when v_action='INSERT' then 12 else 16 end and a.source_updated_at=m.updated_at
        from economics_v2.group_period_feed_allocations a join public.mezcla m on m.id=a.mixture_id
        where m.id=f.private_control), 'actual private source/fact totals and versions agree');
      select array_agg(comida_id) into v_foods from public.mezcla_comida where mezcla_id=f.private_control;
    else
      perform pg_temp.check_true(v_result->'deleted'='true'::jsonb
        and not exists(select 1 from public.mezcla where id=f.private_control)
        and not exists(select 1 from economics_v2.group_period_feed_allocations where mixture_id=f.private_control)
        and not exists(select 1 from public.comida where id=any(v_foods)), 'actual private DELETE removes dedicated source/fact/foods');
    end if;
    perform pg_temp.check_true(pg_temp.business_state(true)=v_other,'control writes preserve siblings, events, basis, Cycles and every sequence');
  end loop;
  perform pg_temp.check_true(not exists(select 1 from pg_temp.acl_baseline b
    left join pg_class c on b.kind='table' and c.oid=b.oid
    left join pg_proc p on b.kind='function' and p.oid=b.oid
    where b.acl is distinct from case when b.kind='table' then to_jsonb(c.relacl) else to_jsonb(p.proacl) end),
    'all persistent table/function ACLs unchanged');
  set constraints all immediate;
end;
$positive_controls$;
select jsonb_build_object(
  'result','group_economics_forward_feed_direct_header_guard_pass',
  'assertion_count',(select count(*) from assertions),'fixture_ids',(select to_jsonb(f) from ids f),
  'locking_evidence','sequential_only','independent_review','pending','real_closure_proven',false,
  'production_gateway_integrated',false,'canonical_group_food_api_integrated',false,
  'direct_header_forward_bypass_blocked',true,'components_and_food_direct_paths_guarded',false,
  'all_legacy_mutation_paths_guarded',false,'higher_isolation_proven',false,
  'privileged_business_provenance_proven',false) evidence;
rollback;
