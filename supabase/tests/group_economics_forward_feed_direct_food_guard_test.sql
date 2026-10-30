begin;

-- HUMAN Sandbox Dashboard only: review, then run this FULL BEGIN/ROLLBACK file.
-- Fixture FIRST; no production guard, helper, RPC, delegation or ACL implementation.
-- FIRST meaningful RED: authenticated owner changes dedicated allocated TOTAL cost 10 to 11.
-- Expected P0001: 'Direct food write reached persistence before forward refusal',
-- DETAIL 'public.comida UPDATE'. Row change before rollback is NOT durable commit.
-- Never observe incoming comida BEFORE STATEMENT: a future BEFORE ROW guard runs later.
-- Other tables, including mezcla_comida, are observed BEFORE STATEMENT to trap cascades.
-- Future SECURITY INVOKER guard checks actual current_user BEFORE a read-only definer:
-- rolsuper/BYPASSRLS AND operation privilege, not JWT, session_user, names or trigger depth.
-- Reject farm reassignment; authorize auth.uid owner/editor, actual OLD identity and NEW category,
-- ALL linked component/header/food/Group ownership BEFORE private allocation history.
-- Inspect ALL parents of EITHER OLD/NEW food UUID, including collisions; no farm filter.
-- ANY allocation independently protects; ANY open meat Group protects without uniqueness.
-- Exact4 23514 DETAIL names actual protected mixture_id, never incoming food UUID.
-- Unlinked fresh food cannot imply a Group; allow ordinary owned farm/category CRUD.
-- precio is TOTAL purchase cost; mc.cantidad is source kg; c.cantidad is stock.
-- Stock is not a digest metric, but linked protected purchases remain immutable.
-- Real exits required for closure; do not forge periods, memberships or snapshots.
-- Sequential only; isolate Sandbox traffic. Setup sequences are NOT rewound by rollback.
-- Forecast: fixture 480 + COMPLETE future helper/invoker/trigger/ACL <=300 = <=780.
-- Hard cap800; stop rather than compress code or drop coverage to meet the budget.

create temp table ids as select
  gen_random_uuid() owner_a, gen_random_uuid() owner_b,
  gen_random_uuid() editor_a, gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a, gen_random_uuid() farm_b,
  gen_random_uuid() type_a, gen_random_uuid() type_b,
  gen_random_uuid() meat_a, gen_random_uuid() eggs_a,
  gen_random_uuid() group_meat_a, gen_random_uuid() group_meat_b,
  gen_random_uuid() group_egg_a, gen_random_uuid() group_egg_b,
  gen_random_uuid() group_control, gen_random_uuid() group_foreign,
  gen_random_uuid() animal_meat_a, gen_random_uuid() animal_meat_b,
  gen_random_uuid() animal_egg_a, gen_random_uuid() animal_egg_b,
  gen_random_uuid() category_a, gen_random_uuid() category_other, gen_random_uuid() category_b,
  gen_random_uuid() allocated_source, gen_random_uuid() unallocated_source,
  gen_random_uuid() egg_source_a, gen_random_uuid() egg_source_b, gen_random_uuid() foreign_source,
  gen_random_uuid() free_food, gen_random_uuid() changed_food, gen_random_uuid() fresh_component,
  gen_random_uuid() shared_component, gen_random_uuid() direct_control,
  gen_random_uuid() cascade_control, gen_random_uuid() legacy_control, gen_random_uuid() private_control,
  gen_random_uuid() create_op, gen_random_uuid() update_op, gen_random_uuid() delete_op;
create temp table assertions(label text not null);
create temp table control_foods(id uuid primary key);
create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
create temp table watched as
select n.nspname schema_name,c.relname table_name
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where c.relkind in ('r','p') and (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users'));
create temp table watched_sequences as
select n.nspname schema_name,c.relname sequence_name
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity');
create function pg_temp.business_state(p_controls boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare f record; t record; v_rows jsonb; v_result jsonb:='{}'; v_filter text;
begin
  select * into f from pg_temp.ids;
  -- Full tables include auth fixtures, private facts, receipts and ALL fences.
  -- Only fresh positive controls are excluded; remember purchases after link deletion.
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    v_filter:='';
    if p_controls then
      if t.schema_name='public' and t.table_name='mezcla' then
        v_filter:=' where not r.id=any($1)';
      elsif t.schema_name='public' and t.table_name='mezcla_comida' then
        v_filter:=' where not r.mezcla_id=any($1)';
      elsif t.schema_name='public' and t.table_name='comida' then
        v_filter:=' where r.id<>$2 and not exists(select 1 from pg_temp.control_foods c where c.id=r.id)';
      elsif t.schema_name='economics_v2' and t.table_name='group_period_feed_allocations' then
        v_filter:=' where not r.mixture_id=any($1)';
      elsif t.schema_name='economics_v2' and t.table_name='group_occupancy_operations' then
        v_filter:=' where not r.operation_id=any($3)';
      elsif t.schema_name='group_feed_integrity' and t.table_name='fences' then
        v_filter:=' where not (r.scope=''group'' and r.entity_id=any($4))';
      end if;
    end if;
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r%s',t.schema_name,t.table_name,v_filter) into v_rows
      using array[f.cascade_control,f.legacy_control,f.private_control],f.direct_control,
        array[f.create_op,f.update_op,f.delete_op],array[f.group_control,f.group_meat_b];
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
select set_config('direct_food_guard.armed','off',true);
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"direct-food-guard"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Direct food farm A',owner_a from ids
union all select farm_b,owner_b,'Direct food farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Direct food type A',owner_a from ids
union all select type_b,farm_b,'Direct food type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Direct food meat','carne',owner_a from ids
union all select eggs_a,farm_a,'Direct food eggs','postura',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'Direct food Group '||g::text,owner_a from ids
cross join lateral unnest(array[group_meat_a,group_meat_b,group_egg_a,group_egg_b,group_control]) g
union all select group_foreign,farm_b,type_b,'Direct food foreign Group',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select c,farm_a,'Direct food ingredient '||c::text,true,owner_a from ids
cross join lateral unnest(array[category_a,category_other]) c
union all select category_b,farm_b,'Direct food foreign ingredient',true,owner_b from ids;
do $temp_access$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$temp_access$;
grant select on pg_temp.ids to authenticated;
grant insert on pg_temp.assertions to authenticated,anon;
do $legacy_setup$
declare f record; s record;
begin
  select * into f from pg_temp.ids;
  for s in select * from (values
    (f.owner_a,f.farm_a,f.allocated_source,f.group_meat_a,f.category_a),
    (f.editor_a,f.farm_a,f.unallocated_source,f.group_meat_b,f.category_a),
    (f.owner_a,f.farm_a,f.egg_source_a,f.group_egg_a,f.category_a),
    (f.owner_a,f.farm_a,f.egg_source_b,f.group_egg_b,f.category_a),
    (f.owner_b,f.farm_b,f.foreign_source,f.group_foreign,f.category_b))
    q(actor,farm,source_id,group_id,category_id) loop
    perform set_config('request.jwt.claim.sub',s.actor::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',s.actor,'role','authenticated')::text,true);
    set local role authenticated;
    perform public.crear_mezcla_completa(s.farm,s.source_id,current_date-3,s.group_id,
      jsonb_build_array(jsonb_build_object('categoria_id',s.category_id,'cantidad_kg',2,'costo_total',10)));
    reset role;
  end loop;
end;
$legacy_setup$;
create temp table targets as select f.*,a.comida_id allocated_food,u.comida_id unallocated_food,
  e.comida_id egg_food,x.comida_id foreign_food
from ids f join public.mezcla_comida a on a.mezcla_id=f.allocated_source
join public.mezcla_comida u on u.mezcla_id=f.unallocated_source
join public.mezcla_comida e on e.mezcla_id=f.egg_source_a
join public.mezcla_comida x on x.mezcla_id=f.foreign_source;
grant select on pg_temp.targets to authenticated;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
set local role authenticated;
-- Genuine ordinary sharing BEFORE admission; allocated purchase stays dedicated.
insert into public.mezcla_comida(id,granja_id,mezcla_id,comida_id,cantidad)
select shared_component,farm_a,egg_source_a,unallocated_food,1 from pg_temp.targets;
insert into public.comida(id,granja_id,cat_comida_id,precio,cantidad)
select free_food,farm_a,category_a,15,3 from pg_temp.ids;
reset role;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,created_by)
select a,farm_a,type_a,g,p,current_date-7,300,owner_a from ids
cross join lateral (values (animal_meat_a,group_meat_a,meat_a),(animal_meat_b,group_meat_b,meat_a),
  (animal_egg_a,group_egg_a,eggs_a),(animal_egg_b,group_egg_b,eggs_a)) animals(a,g,p);
create temp table admissions as select a animal_id,economics_v2.enter_group_meat_initial(
  farm_a,gen_random_uuid(),a,current_date-4,g,meat_a,'{}') result from ids
cross join lateral (values (animal_meat_a,group_meat_a),(animal_meat_b,group_meat_b)) animals(a,g);
do $capture$
declare f record; m record; v_period uuid; v_context jsonb;
begin
  select * into f from pg_temp.ids;
  select * into m from public.mezcla where id=f.allocated_source;
  select (result->>'destination_period_id')::uuid into v_period from pg_temp.admissions where animal_id=f.animal_meat_a;
  v_context:=economics_v2.validate_group_feed_source(f.farm_a,v_period,m.id,m.updated_at);
  perform economics_v2.capture_group_feed_allocation(f.farm_a,gen_random_uuid(),v_period,
    m.id,m.updated_at,v_context->>'source_digest');
end;
$capture$;
set constraints all immediate;
do $preflight$
declare f record;
begin
  select * into f from pg_temp.targets;
  perform pg_temp.check_true((select count(*)=1 from pg_temp.targets)
    and (select precio=10 and cantidad=2 from public.comida where id=f.allocated_food)
    and (select count(*)=2 from public.mezcla_comida where comida_id=f.unallocated_food)
    and (select count(*)=2 from economics_v2.group_occupancy_periods where granja_id=f.farm_a
      and closed_on is null and end_position is null), 'real dedicated allocation and shared open meat purchase');
  perform pg_temp.check_true((select count(*)=1 from economics_v2.group_period_feed_allocations
    where mixture_id=f.allocated_source) and not exists(select 1 from economics_v2.group_period_feed_allocations
    where mixture_id in (f.unallocated_source,f.egg_source_a,f.egg_source_b)), 'only dedicated source is captured');
  perform pg_temp.check_true(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='economics_v2' and p.proname in ('enter_group_meat_initial','validate_group_feed_source',
      'capture_group_feed_allocation','create_group_feed_allocation','update_group_feed_allocation','delete_group_feed_allocation')
    and (has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE'))),
    'actual private producers remain unavailable to clients');
  perform pg_temp.check_true(not exists(select 1 from unnest(array['mezcla','mezcla_comida','comida']) t
    cross join unnest(array['SELECT','INSERT','UPDATE','DELETE']) op
    where not has_table_privilege('authenticated','public.'||t,op)), 'each authenticated source CRUD privilege retained');
end;
$preflight$;
create function pg_temp.observe_dml()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('direct_food_guard.armed',true)='on' then
    raise exception using errcode='P0001',message='Direct food write reached persistence before forward refusal',
      detail=tg_table_schema||'.'||tg_table_name||' '||tg_op;
  end if;
  return null;
end;
$$;
do $observers$
declare t record;
begin
  for t in select * from pg_temp.watched where not (schema_name='public' and table_name='comida') loop
    execute format('create trigger direct_food_internal_dml_observer
      before insert or update or delete or truncate on %I.%I
      for each statement execute function pg_temp.observe_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;
create trigger direct_food_persist_observer after insert or update or delete on public.comida
for each row execute function pg_temp.observe_dml();
create function pg_temp.expect_refusal(p_sql text,p_parent uuid,p_state text default '23514')
returns void language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_detail text; v_refused boolean:=false;
begin
  v_before:=pg_temp.business_state();
  perform set_config('direct_food_guard.armed','on',true);
  begin
    execute p_sql;
  exception when check_violation then
    if p_state<>'23514' then raise; end if;
    get stacked diagnostics v_detail=pg_exception_detail;
    begin
      v_refused:=v_detail::jsonb=jsonb_build_object(
        'contract_version','group-economics.forward.v3','code','forward_group_period_required',
        'field','mixture_id','entity_id',p_parent);
    exception when invalid_text_representation then v_refused:=false;
    end;
    if v_refused is distinct from true or current_user<>'authenticated' then raise; end if;
    perform pg_temp.check_true(v_refused,'exact4 refusal names actual protected parent');
  when insufficient_privilege then
    if p_state<>'42501' then raise; end if;
    v_refused:=true; -- No new authorization DETAIL grammar is assumed.
  end;
  perform set_config('direct_food_guard.armed','off',true);
  perform pg_temp.check_true(v_refused,'direct command refuses with '||p_state);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'all rows, receipts, allocations, fences and sequences unchanged');
end;
$$;
create function pg_temp.private_control(p_action text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare f record; v_period uuid; a record; m record;
begin
  select * into f from pg_temp.ids;
  perform pg_temp.check_true((select rolsuper or rolbypassrls from pg_roles where rolname=current_user)
    and has_table_privilege(current_user,'public.comida',p_action), 'actual privileged SQL role has food operation permission');
  select (result->>'destination_period_id')::uuid into v_period from pg_temp.admissions where animal_id=f.animal_meat_b;
  if p_action='INSERT' then
    return economics_v2.create_group_feed_allocation(f.farm_a,f.create_op,v_period,f.private_control,
      current_date-2,f.group_meat_b,jsonb_build_array(jsonb_build_object('categoria_id',f.category_a,'cantidad_kg',3,'costo_total',12)));
  end if;
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=f.private_control;
  select * into m from public.mezcla where id=f.private_control;
  if p_action='UPDATE' then
    return economics_v2.update_group_feed_allocation(f.farm_a,f.update_op,v_period,m.id,a.updated_at,
      m.updated_at,a.source_digest,current_date-1,null,jsonb_build_array(jsonb_build_object('categoria_id',f.category_a,'cantidad_kg',4,'costo_total',16)));
  end if;
  return economics_v2.delete_group_feed_allocation(f.farm_a,f.delete_op,v_period,m.id,a.updated_at,m.updated_at,a.source_digest);
end;
$$;
revoke all on function pg_temp.check_true(boolean,text),pg_temp.business_state(boolean),
  pg_temp.expect_refusal(text,uuid,text),pg_temp.private_control(text) from public;
grant execute on function pg_temp.check_true(boolean,text),pg_temp.business_state(boolean),
  pg_temp.expect_refusal(text,uuid,text) to authenticated,anon;
grant execute on function pg_temp.private_control(text) to authenticated;

do $negative_proof$
declare f record; s record; actor record; v_before jsonb; v_count bigint;
begin
  select * into f from pg_temp.targets;
  set local role authenticated;
  perform pg_temp.expect_refusal(format('update public.comida set precio=11 where id=%L',f.allocated_food),f.allocated_source);
  for s in select * from (values
    (f.allocated_food,'cantidad=3',f.allocated_source),
    (f.allocated_food,format('cat_comida_id=%L',f.category_other),f.allocated_source),
    (f.allocated_food,format('id=%L',f.changed_food),f.allocated_source),
    (f.unallocated_food,'precio=11',f.unallocated_source),
    (f.unallocated_food,'cantidad=3',f.unallocated_source),
    (f.free_food,format('id=%L',f.allocated_food),f.allocated_source)) q(food,assignments,parent) loop
    perform pg_temp.expect_refusal(format('update public.comida set %s where id=%L',s.assignments,s.food),s.parent);
  end loop;
  perform pg_temp.expect_refusal(format('insert into public.comida(id,granja_id,cat_comida_id,precio,cantidad)
    values(%L,%L,%L,10,2)',f.allocated_food,f.farm_a,f.category_a),f.allocated_source);
  perform pg_temp.expect_refusal(format('insert into public.comida(id,granja_id,cat_comida_id,precio,cantidad)
    values(%L,%L,%L,10,2) on conflict(id) do nothing',f.allocated_food,f.farm_a,f.category_a),f.allocated_source);
  for s in select * from (values (f.allocated_food,f.allocated_source),
    (f.unallocated_food,f.unallocated_source)) q(food,parent) loop
    perform pg_temp.expect_refusal(format('delete from public.comida where id=%L',s.food),s.parent);
  end loop;
  perform pg_temp.expect_refusal(format('update public.comida set granja_id=%L where id=%L',f.farm_b,f.allocated_food),null,'42501');
  perform pg_temp.expect_refusal(format('update public.comida set cat_comida_id=%L where id=%L',f.category_b,f.allocated_food),null,'42501');
  perform pg_temp.expect_refusal(format('update public.comida set id=%L where id=%L',f.foreign_food,f.free_food),null,'42501');
  reset role;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated','trusted_writer',true)::text,true);
  perform set_config('group_feed_integrity.trusted_writer','true',true);
  set local role authenticated;
  perform pg_temp.expect_refusal(format('update public.comida set precio=11 where id=%L',f.allocated_food),f.allocated_source);
  reset role;
  perform set_config('group_feed_integrity.trusted_writer','false',true);
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  v_before:=pg_temp.business_state();
  begin
    update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
    update public.cat_proposito_animal set codigo_calculo='postura' where id=f.meat_a;
    perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_periods p
      join public.cat_proposito_animal c on c.id=p.purpose_id where p.granja_id=f.farm_a
      and p.closed_on is null and p.end_position is null and c.codigo_calculo='carne'), 'allocation-only classification probe, not closure');
    set local role authenticated;
    perform pg_temp.expect_refusal(format('update public.comida set precio=11 where id=%L',f.allocated_food),f.allocated_source);
    perform pg_temp.expect_refusal(format('delete from public.comida where id=%L',f.allocated_food),f.allocated_source);
    reset role;
    raise exception using errcode='Z0001',message='Restore classification and feature flag';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'classification, flags and fence state restored');
  begin
    -- Deliberately malformed ownership probe, never forged forward business history.
    update public.mezcla_comida set granja_id=f.farm_b where id=f.shared_component;
    set local role authenticated;
    perform pg_temp.expect_refusal(format('update public.comida set precio=11 where id=%L',f.unallocated_food),null,'42501');
    reset role;
    raise exception using errcode='Z0001',message='Restore linked ownership probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'foreign linked component cannot disappear under incoming food farm filter');
  for actor in select * from (values (f.viewer_a,'authenticated'),(f.owner_b,'authenticated'),(null::uuid,'anon')) q(uid,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.uid::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.uid,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    perform pg_temp.expect_refusal(format('insert into public.comida(id,granja_id,cat_comida_id,precio,cantidad)
      values(%L,%L,%L,10,2)',f.changed_food,f.farm_a,f.category_a),null,'42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  perform set_config('direct_food_guard.armed','on',true);
  set local role authenticated;
  update public.comida set precio=11 where id=f.foreign_food;
  get diagnostics v_count=row_count;
  perform pg_temp.check_true(v_count=0,'foreign invisible food UPDATE is zero rows, not authorization-error proof');
  delete from public.comida where id=f.foreign_food;
  get diagnostics v_count=row_count;
  perform pg_temp.check_true(v_count=0,'foreign invisible food DELETE is zero rows');
  reset role;
  perform set_config('direct_food_guard.armed','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'RLS no-ops preserve all state');
end;
$negative_proof$;

do $positive_controls$
declare f record; v_other jsonb; v_header jsonb; v_version timestamptz; v_result jsonb;
  v_foods uuid[]; v_previous uuid[]; v_action text; v_source uuid;
begin
  select * into f from pg_temp.targets;
  perform pg_temp.check_true(not exists(select 1 from public.mezcla
    where id in (f.cascade_control,f.legacy_control,f.private_control))
    and not exists(select 1 from public.comida where id=f.direct_control), 'positive controls fresh before baseline');
  v_other:=pg_temp.business_state(true);
  set local role authenticated;
  insert into public.comida(id,granja_id,cat_comida_id,precio,cantidad) values(f.direct_control,f.farm_a,f.category_a,10,2);
  update public.comida set precio=12,cantidad=3,cat_comida_id=f.category_other where id=f.direct_control;
  perform pg_temp.check_true((select precio=12 and cantidad=3 and cat_comida_id=f.category_other
    from public.comida where id=f.direct_control), 'ordinary unlinked owned stock CRUD needs no Group or period');
  delete from public.comida where id=f.direct_control;
  reset role;
  perform pg_temp.check_true(not exists(select 1 from public.comida where id=f.direct_control)
    and pg_temp.business_state(true)=v_other,'standalone control removed without unrelated changes');
  foreach v_source in array array[f.cascade_control,f.legacy_control] loop
    set local role authenticated;
    perform public.crear_mezcla_completa(f.farm_a,v_source,current_date-2,f.group_control,
      jsonb_build_array(jsonb_build_object('categoria_id',f.category_a,'cantidad_kg',2,'costo_total',10)));
    reset role;
    select array_agg(comida_id) into v_foods from public.mezcla_comida where mezcla_id=v_source;
    insert into pg_temp.control_foods select unnest(v_foods);
    if v_source=f.cascade_control then
      select to_jsonb(m) into v_header from public.mezcla m where id=v_source;
      set local role authenticated;
      update public.comida set precio=12,cantidad=3,cat_comida_id=f.category_other where id=any(v_foods);
      perform pg_temp.check_true((select count(*)=1 and sum(c.precio)=12 and sum(mc.cantidad)=2
        and sum(c.cantidad)=3 and bool_and(c.cat_comida_id=f.category_other)
        from public.comida c join public.mezcla_comida mc on mc.comida_id=c.id where mc.mezcla_id=v_source),
        'ordinary linked TOTAL cost/stock update does not rewrite ingredient kg');
      delete from public.comida where id=any(v_foods);
      reset role;
      perform pg_temp.check_true(not exists(select 1 from public.mezcla_comida where mezcla_id=v_source)
        and (select to_jsonb(m)=v_header from public.mezcla m where id=v_source), 'ordinary food cascade removes components, preserves header exactly');
    else
      v_previous:=v_foods;
      select updated_at into v_version from public.mezcla where id=v_source;
      set local role authenticated;
      perform public.actualizar_mezcla_completa(v_source,f.farm_a,v_version,current_date-1,null,f.group_control,
        jsonb_build_array(jsonb_build_object('categoria_id',f.category_a,'cantidad_kg',3,'costo_total',12)));
      reset role;
      select array_agg(comida_id) into v_foods from public.mezcla_comida where mezcla_id=v_source;
      insert into pg_temp.control_foods select unnest(v_foods);
      perform pg_temp.check_true(not exists(select 1 from public.comida where id=any(v_previous))
        and (select count(*)=1 and sum(mc.cantidad)=3 and sum(c.precio)=12 from public.mezcla_comida mc
          join public.comida c on c.id=mc.comida_id where mc.mezcla_id=v_source)
        and (select updated_at>v_version from public.mezcla where id=v_source), 'real legacy UPDATE replaces purchases, kg, TOTAL cost and source version');
    end if;
    set local role authenticated;
    perform public.eliminar_mezcla_completa(f.farm_a,v_source);
    reset role;
    perform pg_temp.check_true(not exists(select 1 from public.mezcla where id=v_source)
      and not exists(select 1 from public.mezcla_comida where mezcla_id=v_source)
      and not exists(select 1 from public.comida where id=any(v_foods))
      and pg_temp.business_state(true)=v_other, 'real ordinary legacy DELETE preserves all baseline rows and sequences');
  end loop;
  foreach v_action in array array['INSERT','UPDATE','DELETE'] loop
    v_previous:=coalesce(v_foods,'{}'::uuid[]);
    set local role authenticated;
    v_result:=pg_temp.private_control(v_action);
    reset role;
    perform pg_temp.check_true(v_result->>'mixture_id'=f.private_control::text and v_result->'replayed'='false'::jsonb,
      'actual private core through explicit temporary delegation, not a production gateway');
    if v_action<>'DELETE' then
      select array_agg(comida_id) into v_foods from public.mezcla_comida where mezcla_id=f.private_control;
      insert into pg_temp.control_foods select unnest(v_foods);
      perform pg_temp.check_true((select a.quantity_kg=case when v_action='INSERT' then 3 else 4 end
        and a.total_cost=case when v_action='INSERT' then 12 else 16 end and a.source_updated_at=m.updated_at
        from economics_v2.group_period_feed_allocations a join public.mezcla m on m.id=a.mixture_id
        where m.id=f.private_control) and (select count(*)=1
          and sum(mc.cantidad)=case when v_action='INSERT' then 3 else 4 end
          and sum(c.precio)=case when v_action='INSERT' then 12 else 16 end
          from public.mezcla_comida mc join public.comida c on c.id=mc.comida_id where mc.mezcla_id=f.private_control)
        and not exists(select 1 from public.comida where id=any(v_previous)),
        'private actual allocation totals/versions agree and old purchases are destroyed');
    else
      perform pg_temp.check_true(v_result->'deleted'='true'::jsonb
        and not exists(select 1 from public.mezcla where id=f.private_control)
        and not exists(select 1 from economics_v2.group_period_feed_allocations where mixture_id=f.private_control)
        and not exists(select 1 from public.mezcla_comida where mezcla_id=f.private_control)
        and not exists(select 1 from public.comida where id=any(v_previous)), 'private DELETE removes actual source, fact, components and stock');
    end if;
    perform pg_temp.check_true(pg_temp.business_state(true)=v_other,'private controls preserve all non-control rows and sequence positions');
  end loop;
  perform pg_temp.check_true(not exists(select 1 from pg_temp.acl_baseline b
    left join pg_class c on b.kind='table' and c.oid=b.oid left join pg_proc p on b.kind='function' and p.oid=b.oid
    where b.acl is distinct from case when b.kind='table' then to_jsonb(c.relacl) else to_jsonb(p.proacl) end),
    'all preexisting persistent table/function ACLs unchanged');
  set constraints all immediate;
end;
$positive_controls$;
select jsonb_build_object(
  'result','group_economics_forward_feed_direct_food_guard_pass',
  'assertion_count',(select count(*) from assertions),'fixture_ids',(select to_jsonb(f) from targets f),
  'locking_evidence','sequential_only','independent_review','pending','real_closure_proven',false,
  'production_gateway_integrated',false,'canonical_group_food_api_integrated',false,
  'direct_food_forward_bypass_blocked',true,'all_legacy_mutation_paths_guarded',false,
  'higher_isolation_proven',false,'privileged_business_provenance_proven',false,
  'closed_period_branch','skipped_open_membership_requires_real_exit','malformed_cascade_proven',false,
  'cascade_proven',false,'targeted_cascade_controls_proven',true) evidence;
rollback;
