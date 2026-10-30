begin;

-- HUMAN Sandbox Dashboard only: review, then run this FULL BEGIN/ROLLBACK file.
-- Fixture FIRST: no legacy DELETE implementation, canonical API or client gateway.
-- Accepted section 7: ANY source allocation OR ANY owned OPEN meat source Group
-- requires exact4 typed 23514 BEFORE ANY persistent DML, including private fences.
-- Initial RED expected from the retained RPC: uncaught P0001, public.mezcla DELETE.
-- The actual legacy body deletes the HEADER first, not components or allocation.
-- BEFORE STATEMENT observation precedes its BEFORE ROW Group-fence write and FK.
-- The private child-first DELETE producer is a different path and is NOT invoked.
-- Unexpected P0001/generic FK/other errors escape unchanged, never accepted as RED.
-- All actual authenticated legacy CREATE calls precede qualified private admission.
-- Allocation-only classification is synthetic/reversible, NOT real period closure.
-- Closed-period branch SKIPPED: real open memberships require a real exit producer.
-- Independent egg Groups have no bound Cycle; no posture synchronization claim.
-- Forecast: fixture <=360 + FULL retained DELETE body77 + guard <=110 + ACL <=210
-- = <=757 authored lines; hard cap800, never count only a guard insertion diff.
-- Sequential only. Setup consumes positions; ROLLBACK does not rewind sequences.
-- No runtime PASS or independent review is implied by authoring this fixture.

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
  gen_random_uuid() allocated_source, gen_random_uuid() unallocated_source,
  gen_random_uuid() egg_owner_source, gen_random_uuid() egg_editor_source,
  gen_random_uuid() foreign_source, gen_random_uuid() missing_source;
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
-- Permanent within this transaction: deletion must not erase the exclusion identities.
create temp table egg_food_ids(id uuid primary key);
create function pg_temp.business_state(p_exclude_eggs boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare f record; t record; v_rows jsonb; v_result jsonb:='{}'; v_filter text;
  v_ids text[]; v_foods uuid[];
begin
  select * into f from pg_temp.ids;
  select array_agg(value) into v_ids from jsonb_each_text(to_jsonb(f));
  select coalesce(array_agg(id),'{}'::uuid[]) into v_foods from pg_temp.egg_food_ids;
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    v_filter:=' where (to_jsonb(r)->>''granja_id''=any($1)
      or to_jsonb(r)->>''id''=any($2) or to_jsonb(r)->>''user_id''=any($2)
      or to_jsonb(r)->>''entity_id''=any($2) or to_jsonb(r)->>''group_id''=any($2)
      or to_jsonb(r)->>''grupo_id''=any($2))';
    if p_exclude_eggs then
      if t.schema_name='public' and t.table_name='mezcla' then
        v_filter:=v_filter||' and r.id not in ($6,$7)';
      elsif t.schema_name='public' and t.table_name='mezcla_comida' then
        v_filter:=v_filter||' and r.mezcla_id not in ($6,$7)';
      elsif t.schema_name='public' and t.table_name='comida' then
        v_filter:=v_filter||' and not r.id=any($3)';
      elsif t.schema_name='group_feed_integrity' and t.table_name='fences' then
        v_filter:=v_filter||' and not (r.scope=''group'' and r.entity_id in ($4,$5))';
      end if;
    end if;
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r%s',t.schema_name,t.table_name,v_filter)
      into v_rows using array[f.farm_a::text,f.farm_b::text],v_ids,v_foods,
        f.group_egg_a,f.group_egg_b,f.egg_owner_source,f.egg_editor_source;
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

select set_config('legacy_feed_delete_guard.armed','off',true);
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"legacy-feed-delete-guard"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Legacy delete farm A',owner_a from ids
union all select farm_b,owner_b,'Legacy delete farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Legacy delete type A',owner_a from ids
union all select type_b,farm_b,'Legacy delete type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Legacy delete meat','carne',owner_a from ids
union all select eggs_a,farm_a,'Legacy delete eggs','postura',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'Legacy delete Group '||g::text,owner_a
from ids cross join lateral unnest(array[group_meat_a,group_meat_b,group_egg_a,group_egg_b]) g
union all select group_foreign,farm_b,type_b,'Legacy delete foreign Group',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select category_a,farm_a,'Legacy delete ingredient A',true,owner_a from ids
union all select category_b,farm_b,'Legacy delete ingredient B',true,owner_b from ids;
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
    (f.owner_a,f.farm_a,f.egg_owner_source,f.group_egg_a,f.category_a),
    (f.editor_a,f.farm_a,f.egg_editor_source,f.group_egg_b,f.category_a),
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
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,created_by)
select a,farm_a,type_a,g,p,current_date-7,300,owner_a from ids
cross join lateral (values (animal_meat_a,group_meat_a,meat_a),
  (animal_meat_b,group_meat_b,meat_a),(animal_egg_a,group_egg_a,eggs_a),
  (animal_egg_b,group_egg_b,eggs_a)) animals(a,g,p);
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
  select (result->>'destination_period_id')::uuid into v_period
    from pg_temp.admissions where animal_id=f.animal_meat_a;
  v_context:=economics_v2.validate_group_feed_source(f.farm_a,v_period,m.id,m.updated_at);
  perform economics_v2.capture_group_feed_allocation(f.farm_a,gen_random_uuid(),v_period,
    m.id,m.updated_at,v_context->>'source_digest');
end;
$capture$;
insert into egg_food_ids select mc.comida_id from public.mezcla_comida mc cross join ids f
where mc.mezcla_id in (f.egg_owner_source,f.egg_editor_source);
set constraints all immediate;

do $preflight$
declare f record; v_proc record;
begin
  select * into f from pg_temp.ids;
  perform pg_temp.check_true((select count(*)=2 from economics_v2.group_occupancy_periods
    where granja_id=f.farm_a and group_id in (f.group_meat_a,f.group_meat_b)
      and purpose_id=f.meat_a and closed_on is null and end_position is null), 'two genuine open meat Groups');
  perform pg_temp.check_true((select count(*)=1 from economics_v2.group_period_feed_allocations
    where granja_id=f.farm_a and mixture_id=f.allocated_source)
    and not exists(select 1 from economics_v2.group_period_feed_allocations
      where mixture_id in (f.unallocated_source,f.egg_owner_source,f.egg_editor_source)), 'only target is allocated');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_periods
    where group_id in (f.group_egg_a,f.group_egg_b)), 'egg Groups have no forward period');
  perform pg_temp.check_true((select count(*)=2 from pg_temp.egg_food_ids)
    and (select count(*)=2 from public.comida where id in (select id from pg_temp.egg_food_ids)),
    'two real dedicated egg purchases retained for physical deletion checks');
  select * into v_proc from pg_proc where oid='public.eliminar_mezcla_completa(uuid,uuid)'::regprocedure;
  perform pg_temp.check_true(not v_proc.prosecdef and v_proc.prorettype='void'::regtype
    and v_proc.proconfig @> array['search_path=""']
    and has_function_privilege('authenticated',v_proc.oid,'EXECUTE')
    and not has_function_privilege('anon',v_proc.oid,'EXECUTE')
    and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) x
      where x.grantee=0 and x.privilege_type='EXECUTE'), 'legacy DELETE remains authenticated invoker/void/empty path');
  perform pg_temp.check_true(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='economics_v2' and p.proname in ('enter_group_meat_initial','validate_group_feed_source',
      'capture_group_feed_allocation','create_group_feed_allocation','update_group_feed_allocation',
      'delete_group_feed_allocation','raise_group_writer_error')
      and (has_function_privilege('authenticated',p.oid,'EXECUTE')
        or has_function_privilege('anon',p.oid,'EXECUTE'))), 'private producers and error helpers have no client EXECUTE');
end;
$preflight$;
create function pg_temp.guard_dml()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('legacy_feed_delete_guard.armed',true)='on' then
    raise exception using errcode='P0001',
      message='Legacy delete attempted persistent DML before forward-period refusal',
      detail=tg_table_schema||'.'||tg_table_name||' '||tg_op;
  end if;
  return null;
end;
$$;
do $observers$
declare t record;
begin
  for t in select * from pg_temp.watched loop
    execute format('create trigger legacy_feed_delete_dml_observer
      before insert or update or delete or truncate on %I.%I
      for each statement execute function pg_temp.guard_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;
-- INVOKER ONLY: no privileged producer proxy; snapshots are read-only definers.
create function pg_temp.expect_refusal(p_source uuid, p_farm uuid, p_expected_state text default '23514')
returns void language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_detail text; v_refused boolean:=false;
begin
  v_before:=pg_temp.business_state();
  perform set_config('legacy_feed_delete_guard.armed','on',true);
  begin
    perform public.eliminar_mezcla_completa(p_farm,p_source);
  exception when check_violation then
    if p_expected_state<>'23514' then raise; end if;
    get stacked diagnostics v_detail=pg_exception_detail;
    perform pg_temp.check_true(current_user='authenticated' and v_detail::jsonb=jsonb_build_object(
      'contract_version','group-economics.forward.v3','code','forward_group_period_required',
      'field','mixture_id','entity_id',p_source), 'authenticated exact4 forward DELETE refusal');
    v_refused:=true;
  when insufficient_privilege then
    if p_expected_state<>'42501' then raise; end if;
    v_refused:=true; -- Existing authorization SQLSTATE, not invented typed DETAIL.
  end;
  perform set_config('legacy_feed_delete_guard.armed','off',true);
  perform pg_temp.check_true(v_refused,'legacy DELETE refuses with '||p_expected_state);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,
    'refusal preserves every farm row, fact, receipt, fence and sequence');
end;
$$;
revoke all on function pg_temp.check_true(boolean,text),pg_temp.business_state(boolean),
  pg_temp.expect_refusal(uuid,uuid,text) from public;
grant execute on function pg_temp.check_true(boolean,text),pg_temp.business_state(boolean),
  pg_temp.expect_refusal(uuid,uuid,text) to authenticated,anon;

do $proof$
declare f record; s record; actor record; v_before jsonb; v_old_foods uuid[];
begin
  select * into f from pg_temp.ids;
  -- FIRST meaningful owner probe: correct farm, real captured source, no fake refusal.
  set local role authenticated;
  perform pg_temp.expect_refusal(f.allocated_source,f.farm_a);
  reset role;
  for s in select * from (values (f.editor_a,f.allocated_source),
    (f.editor_a,f.unallocated_source)) q(actor,source_id) loop
    perform set_config('request.jwt.claim.sub',s.actor::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',s.actor,'role','authenticated')::text,true);
    set local role authenticated;
    perform pg_temp.expect_refusal(s.source_id,f.farm_a);
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  v_before:=pg_temp.business_state();
  begin
    update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
    set local role authenticated;
    perform pg_temp.expect_refusal(f.unallocated_source,f.farm_a);
    reset role;
    -- Singleton-safe metadata change removes meat classification, not membership/history.
    update public.cat_proposito_animal set codigo_calculo='postura' where id=f.meat_a;
    perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_periods p
      join public.cat_proposito_animal c on c.id=p.purpose_id and c.granja_id=p.granja_id
      where p.group_id=f.group_meat_a and p.closed_on is null and p.end_position is null
        and c.codigo_calculo='carne'), 'allocation-only probe has no current open meat classification');
    set local role authenticated;
    perform pg_temp.expect_refusal(f.allocated_source,f.farm_a);
    reset role;
    raise exception using errcode='Z0001',message='Restore synthetic classification and flag probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'classification, flag and all fences restored');
  for actor in select * from (values (f.viewer_a,'authenticated'),
    (f.owner_b,'authenticated'),(null::uuid,'anon')) q(user_id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.user_id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.user_id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    perform pg_temp.expect_refusal(f.allocated_source,f.farm_a,'42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  set local role authenticated;
  perform pg_temp.expect_refusal(f.egg_owner_source,f.farm_b,'42501');
  reset role;
  v_before:=pg_temp.business_state();
  perform set_config('legacy_feed_delete_guard.armed','on',true);
  set local role authenticated;
  -- Scoped authorized-farm no-ops from the retained body, NOT foreign authorization proof.
  perform public.eliminar_mezcla_completa(f.farm_a,f.foreign_source);
  perform public.eliminar_mezcla_completa(f.farm_a,f.missing_source);
  reset role;
  perform set_config('legacy_feed_delete_guard.armed','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'foreign-source mismatch and missing source remain no-ops');
  v_before:=pg_temp.business_state(true);
  for s in select * from (values (f.owner_a,f.egg_owner_source),
    (f.editor_a,f.egg_editor_source)) q(actor,source_id) loop
    select array_agg(comida_id) into v_old_foods from public.mezcla_comida where mezcla_id=s.source_id;
    perform pg_temp.check_true(cardinality(v_old_foods)=1,'egg control starts with one dedicated purchase');
    perform set_config('request.jwt.claim.sub',s.actor::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',s.actor,'role','authenticated')::text,true);
    set local role authenticated;
    perform public.eliminar_mezcla_completa(f.farm_a,s.source_id);
    reset role;
    perform pg_temp.check_true(not exists(select 1 from public.mezcla where id=s.source_id)
      and not exists(select 1 from public.mezcla_comida where mezcla_id=s.source_id)
      and not exists(select 1 from public.comida where id=any(v_old_foods)),
      'owner/editor egg DELETE physically removes header, cascaded components and dedicated food');
    perform pg_temp.check_true(pg_temp.business_state(true)=v_before,
      'egg DELETE changes only intended headers/components/foods and egg Group fences');
    if s.source_id=f.egg_owner_source then
      perform pg_temp.check_true(exists(select 1 from public.mezcla where id=f.egg_editor_source)
        and exists(select 1 from public.mezcla_comida where mezcla_id=f.egg_editor_source),
        'first egg DELETE preserves the independent editor source');
    end if;
    perform set_config('legacy_feed_delete_guard.armed','on',true);
    set local role authenticated;
    perform public.eliminar_mezcla_completa(f.farm_a,s.source_id);
    reset role;
    perform set_config('legacy_feed_delete_guard.armed','off',true);
    perform pg_temp.check_true(pg_temp.business_state(true)=v_before,'deleted-source repetition remains no-op');
  end loop;
  perform pg_temp.check_true((select count(*)=2 from pg_temp.egg_food_ids)
    and not exists(select 1 from public.comida where id in (select id from pg_temp.egg_food_ids)),
    'both remembered original egg food IDs are physically absent');
  set constraints all immediate;
end;
$proof$;
select jsonb_build_object(
  'result','group_economics_forward_legacy_feed_delete_guard_pass',
  'assertion_count',(select count(*) from assertions),'fixture_ids',(select to_jsonb(f) from ids f),
  'locking_evidence','sequential_only','independent_review','pending','real_closure_proven',false,
  'production_gateway_integrated',false,'canonical_group_food_api_integrated',false,
  'closed_period_branch','skipped_open_membership_requires_real_exit',
  'legacy_delete_forward_bypass_blocked',true,'all_legacy_mutation_paths_guarded',false) evidence;
rollback;
