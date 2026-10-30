begin;

-- HUMAN Sandbox Dashboard only: review, then run this FULL BEGIN/ROLLBACK file.
-- Preparation is not execution, independent review, concurrency or closure proof.
-- Scope: FRESH UUID calls to the EXISTING authenticated legacy create RPC only.
-- No existing-UUID replay, direct-table, update/delete or canonical API coverage.
-- Accepted design section 7 requires refusal for the same Group's open meat period
-- before ANY persistent DML, including internal fences. Other Groups remain usable.
-- Technical DETAIL pin: exact4 contract_version/code/field/entity_id, field=group_id,
-- entity_id=p_grupo_id: this legacy request has a Group, not a supplied period_id.
-- Future equivalent inline RAISE is sufficient; do not grant private error helpers.
-- Meaningful first RED on the retained creator: uncaught P0001 from its real first
-- public.mezcla INSERT, BEFORE the header row trigger can touch the Group fence.
-- An earlier setup/authorization/schema failure is NOT that meaningful RED.
-- Statement observers deny writes while armed; they never manufacture typed refusal.
-- No implementation, deployed gateway, grants to private cores or RLS bypass added.
-- Forecast: fixture <=450 + FULL future legacy replacement <=300 = <=750, cap800.
-- Retained creator is 196 lines; budget includes its complete body, not a guard diff.
-- Genuine initial-entry setup consumes positions; ROLLBACK cannot rewind sequences.
-- Refusal and egg control observations must leave sequence values unchanged.
-- Use an isolated, sequential Sandbox session; no shared concurrent sequence traffic.

create temp table ids as select
  gen_random_uuid() owner_a, gen_random_uuid() owner_b,
  gen_random_uuid() editor_a, gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a, gen_random_uuid() farm_b,
  gen_random_uuid() type_a, gen_random_uuid() meat_a, gen_random_uuid() eggs_a,
  gen_random_uuid() group_meat, gen_random_uuid() group_eggs, gen_random_uuid() group_eggs_other,
  gen_random_uuid() animal_meat, gen_random_uuid() animal_eggs, gen_random_uuid() animal_eggs_other,
  gen_random_uuid() category_a, gen_random_uuid() prior_source,
  gen_random_uuid() owner_source, gen_random_uuid() editor_source,
  gen_random_uuid() egg_first, gen_random_uuid() egg_second, gen_random_uuid() egg_other;
create temp table assertions(label text not null);
create function pg_temp.check_true(p_ok boolean, p_label text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%', p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;

-- Read evidence is bounded to fixture farms, users and Group/purpose identities.
-- Statement observers cover all persistent tables in these business schemas, but
-- their connection-local arm is off for setup, controls and every other session.
create temp table watched as
select n.nspname schema_name, c.relname table_name
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where c.relkind in ('r','p') and (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users'));
create temp table watched_sequences as
select n.nspname schema_name, c.relname sequence_name
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity');
create function pg_temp.business_state(p_exclude_egg_sources boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  f record; t record; v_rows jsonb; v_result jsonb:='{}'; v_filter text;
  v_ids text[]; v_foods uuid[];
begin
  select * into f from pg_temp.ids;
  select array_agg(value) into v_ids from jsonb_each_text(to_jsonb(f));
  select coalesce(array_agg(mc.comida_id),'{}'::uuid[]) into v_foods
  from public.mezcla_comida mc join public.mezcla m on m.id=mc.mezcla_id
  where m.grupo_id in (f.group_eggs,f.group_eggs_other);
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    v_filter:=' where (to_jsonb(r)->>''granja_id''=any($1)
      or to_jsonb(r)->>''id''=any($2) or to_jsonb(r)->>''user_id''=any($2)
      or to_jsonb(r)->>''entity_id''=any($2) or to_jsonb(r)->>''group_id''=any($2)
      or to_jsonb(r)->>''grupo_id''=any($2))';
    if p_exclude_egg_sources then
      if t.schema_name='public' and t.table_name='mezcla' then
        v_filter:=v_filter||' and (r.grupo_id is null or r.grupo_id not in ($4,$5))';
      elsif t.schema_name='public' and t.table_name='mezcla_comida' then
        v_filter:=v_filter||' and r.mezcla_id not in ($6,$7,$8)';
      elsif t.schema_name='public' and t.table_name='comida' then
        v_filter:=v_filter||' and not r.id=any($3)';
      elsif t.schema_name='group_feed_integrity' and t.table_name='fences' then
        v_filter:=v_filter||' and not (r.scope=''group'' and r.entity_id in ($4,$5))';
      end if;
    end if;
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r%s',t.schema_name,t.table_name,v_filter)
      into v_rows using array[f.farm_a::text,f.farm_b::text],v_ids,v_foods,
        f.group_eggs,f.group_eggs_other,f.egg_first,f.egg_second,f.egg_other;
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

select set_config('legacy_feed_guard.armed','off',true);
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"legacy-feed-create-guard"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Legacy guard farm A',owner_a from ids
union all select farm_b,owner_b,'Legacy guard farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Legacy guard type',owner_a from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Legacy guard meat','carne',owner_a from ids
union all select eggs_a,farm_a,'Legacy guard eggs','postura',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'Legacy guard group '||g::text,owner_a
from ids cross join lateral unnest(array[group_meat,group_eggs,group_eggs_other]) g;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select category_a,farm_a,'Legacy guard ingredient',true,owner_a from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;

-- A genuine retained source is seeded BEFORE forward admission. No replay probe.
-- Fixture IDs need only temporary SELECT; no persistent permission is changed.
do $temp_access$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$temp_access$;
grant select on pg_temp.ids to authenticated;
set local role authenticated;
select public.crear_mezcla_completa(farm_a,prior_source,current_date-3,group_meat,
  jsonb_build_array(jsonb_build_object('categoria_id',category_a,'cantidad_kg',2,'costo_total',10))) from pg_temp.ids;
reset role;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,created_by)
select animal_meat,farm_a,type_a,group_meat,meat_a,current_date-7,300,owner_a from ids
union all select animal_eggs,farm_a,type_a,group_eggs,eggs_a,current_date-7,0,owner_a from ids
union all select animal_eggs_other,farm_a,type_a,group_eggs_other,eggs_a,current_date-7,0,owner_a from ids;
-- Privileged setup calls the retained PRIVATE initial-entry core directly; no
-- definer business gateway is created or used for the legacy RPC observations.
create temp table admission as select economics_v2.enter_group_meat_initial(
  farm_a,gen_random_uuid(),animal_meat,current_date-4,group_meat,meat_a,'{}') result from ids;
create temp table targets as select f.*,
  (a.result->>'destination_period_id')::uuid period_a,
  jsonb_build_array(jsonb_build_object('categoria_id',category_a,'cantidad_kg',3,'costo_total',12)) recipe
from ids f cross join admission a;
set constraints all immediate;

do $preflight$
declare t record; v_proc record;
begin
  select * into t from pg_temp.targets;
  perform pg_temp.check_true((select count(*)=1 from economics_v2.group_occupancy_periods
    where id=t.period_a and granja_id=t.farm_a and group_id=t.group_meat and purpose_id=t.meat_a
      and closed_on is null and end_position is null),'genuine owned open meat period');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_periods
    where group_id in (t.group_eggs,t.group_eggs_other)), 'egg Groups have no forward meat period');
  perform pg_temp.check_true(not exists(select 1 from public.mezcla
    where id in (t.owner_source,t.editor_source,t.egg_first,t.egg_second,t.egg_other)),
    'every planned legacy UUID is fresh, excluding the early-return branch');
  select * into v_proc from pg_proc
  where oid='public.crear_mezcla_completa(uuid,uuid,date,uuid,jsonb)'::regprocedure;
  perform pg_temp.check_true(not v_proc.prosecdef and v_proc.prorettype='uuid'::regtype
    and v_proc.proconfig @> array['search_path=""']
    and has_function_privilege('authenticated',v_proc.oid,'EXECUTE')
    and not has_function_privilege('anon',v_proc.oid,'EXECUTE')
    and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) x
      where x.grantee=0 and x.privilege_type='EXECUTE'), 'retained invoker RPC and client ACL');
  perform pg_temp.check_true(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='economics_v2' and p.proname in ('enter_group_meat_initial','validate_group_feed_source',
      'capture_group_feed_allocation','create_group_feed_allocation','update_group_feed_allocation',
      'delete_group_feed_allocation','raise_group_writer_error')
      and (has_function_privilege('authenticated',p.oid,'EXECUTE')
        or has_function_privilege('anon',p.oid,'EXECUTE'))), 'private feed cores remain unavailable to clients');
end;
$preflight$;

create function pg_temp.guard_dml()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('legacy_feed_guard.armed',true)='on' then
    raise exception using errcode='P0001',
      message='Legacy create attempted persistent DML before forward-period refusal',
      detail=tg_table_schema||'.'||tg_table_name||' '||tg_op;
  end if;
  return null;
end;
$$;
do $observers$
declare t record;
begin
  for t in select * from pg_temp.watched loop
    execute format('create trigger legacy_feed_create_dml_observer
      before insert or update or delete or truncate on %I.%I
      for each statement execute function pg_temp.guard_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;

-- ONLY invoker observation helpers invoke public.crear_mezcla_completa.
-- Unexpected states (including P0001, 42883 and 42501 here) escape unmodified.
create function pg_temp.expect_forward_refusal(p_farm uuid,p_source uuid,p_group uuid,p_recipe jsonb)
returns void language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_detail text; v_refused boolean:=false;
begin
  perform pg_temp.check_true(current_user='authenticated','actual authenticated legacy invocation');
  v_before:=pg_temp.business_state();
  perform set_config('legacy_feed_guard.armed','on',true);
  begin
    perform public.crear_mezcla_completa(p_farm,p_source,current_date-2,p_group,p_recipe);
  exception when check_violation then
    get stacked diagnostics v_detail=pg_exception_detail;
    perform pg_temp.check_true(v_detail::jsonb=jsonb_build_object(
      'contract_version','group-economics.forward.v3','code','forward_group_period_required',
      'field','group_id','entity_id',p_group), 'exact typed forward refusal DETAIL');
    v_refused:=true;
  end;
  perform set_config('legacy_feed_guard.armed','off',true);
  perform pg_temp.check_true(v_refused,'fresh legacy create must refuse, never silently return a UUID');
  perform pg_temp.check_true(pg_temp.business_state()=v_before,
    'refusal preserves headers, food, components, facts, receipts, fences and sequences');
end;
$$;
create function pg_temp.expect_authorization_refusal(p_farm uuid,p_source uuid,p_group uuid,p_recipe jsonb)
returns void language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_refused boolean:=false;
begin
  v_before:=pg_temp.business_state();
  perform set_config('legacy_feed_guard.armed','on',true);
  begin
    perform public.crear_mezcla_completa(p_farm,p_source,current_date-2,p_group,p_recipe);
  exception when insufficient_privilege then v_refused:=true;
  end;
  perform set_config('legacy_feed_guard.armed','off',true);
  -- Retain the existing 42501 contract; do not impose new typed authorization DETAIL.
  perform pg_temp.check_true(v_refused,'existing authorization refuses with 42501');
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'authorization refusal has no writes or sequence use');
end;
$$;
revoke all on function pg_temp.check_true(boolean,text),pg_temp.business_state(boolean),
  pg_temp.expect_forward_refusal(uuid,uuid,uuid,jsonb),
  pg_temp.expect_authorization_refusal(uuid,uuid,uuid,jsonb) from public;
grant execute on function pg_temp.check_true(boolean,text),pg_temp.business_state(boolean),
  pg_temp.expect_forward_refusal(uuid,uuid,uuid,jsonb),
  pg_temp.expect_authorization_refusal(uuid,uuid,uuid,jsonb) to authenticated,anon;

do $proof$
declare t record; actor record; v_before jsonb; v_return uuid;
begin
  select * into t from pg_temp.targets;
  -- FIRST meaningful probe: real owner RPC, valid inputs, fresh source, actual role.
  set local role authenticated;
  perform pg_temp.expect_forward_refusal(t.farm_a,t.owner_source,t.group_meat,t.recipe);
  reset role;
  perform set_config('request.jwt.claim.sub',t.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',t.editor_a,'role','authenticated')::text,true);
  set local role authenticated;
  perform pg_temp.expect_forward_refusal(t.farm_a,t.editor_source,t.group_meat,t.recipe);
  reset role;
  for actor in select * from (values (t.viewer_a,'authenticated'),
    (t.owner_b,'authenticated'),(null::uuid,'anon')) a(user_id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.user_id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.user_id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    perform pg_temp.expect_authorization_refusal(t.farm_a,gen_random_uuid(),t.group_meat,t.recipe);
    reset role;
  end loop;

  -- Real known-egg controls AFTER meat admission prove Group scope, not farm scope.
  -- No egg cycle is seeded: no qualified egg-cycle creation/sync proof is claimed.
  v_before:=pg_temp.business_state(true);
  perform set_config('request.jwt.claim.sub',t.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',t.owner_a,'role','authenticated')::text,true);
  set local role authenticated;
  v_return:=public.crear_mezcla_completa(t.farm_a,t.egg_first,current_date-3,t.group_eggs,t.recipe);
  perform pg_temp.check_true(v_return=t.egg_first,'owner creates ordinary egg Group source');
  v_return:=public.crear_mezcla_completa(t.farm_a,t.egg_other,current_date-3,t.group_eggs_other,t.recipe);
  perform pg_temp.check_true(v_return=t.egg_other,'another egg Group remains independently usable');
  reset role;
  perform set_config('request.jwt.claim.sub',t.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',t.editor_a,'role','authenticated')::text,true);
  set local role authenticated;
  v_return:=public.crear_mezcla_completa(t.farm_a,t.egg_second,current_date-2,t.group_eggs,t.recipe);
  perform pg_temp.check_true(v_return=t.egg_second,'editor creates ordinary replacement egg source');
  reset role;
  perform pg_temp.check_true(pg_temp.business_state(true)=v_before,
    'egg controls change only their sources, dedicated food/components and Group fences');
  perform pg_temp.check_true((select count(*)=3 from public.mezcla
    where grupo_id in (t.group_eggs,t.group_eggs_other))
    and (select fecha_termino=current_date-2 and fecha_inicio=current_date-3
      and grupo_id=t.group_eggs and created_by=t.owner_a
      and not group_feed_meat_exempt from public.mezcla where id=t.egg_first)
    and (select fecha_termino is null and fecha_inicio=current_date-2
      and grupo_id=t.group_eggs and created_by=t.editor_a
      and not group_feed_meat_exempt from public.mezcla where id=t.egg_second)
    and (select fecha_termino is null and fecha_inicio=current_date-3
      and grupo_id=t.group_eggs_other and created_by=t.owner_a
      and not group_feed_meat_exempt from public.mezcla where id=t.egg_other),
    'retained one-active-per-egg-Group closure and other Group independence');
  perform pg_temp.check_true((select count(*)=3 and sum(mc.cantidad)=9 and sum(c.precio)=36
    from public.mezcla_comida mc join public.comida c on c.id=mc.comida_id
    where mc.mezcla_id in (t.egg_first,t.egg_second,t.egg_other))
    and not exists(select 1 from public.mezcla_comida mc join public.comida c on c.id=mc.comida_id
      where mc.mezcla_id in (t.egg_first,t.egg_second,t.egg_other)
        and (mc.cantidad is distinct from 3 or c.cantidad is distinct from 3
          or c.precio is distinct from 12 or c.cat_comida_id is distinct from t.category_a))
    and not exists(select 1 from public.mezcla_comida x join public.mezcla_comida y
      on y.comida_id=x.comida_id and y.mezcla_id<>x.mezcla_id
      where x.mezcla_id in (t.egg_first,t.egg_second,t.egg_other)),
    'three dedicated egg purchases preserve kg and TOTAL cost semantics');
  set constraints all immediate;
end;
$proof$;

select jsonb_build_object(
  'result','group_economics_forward_legacy_feed_create_guard_pass',
  'assertion_count',(select count(*) from assertions),
  'fixture_ids',(select to_jsonb(t)-'recipe' from targets t),
  'locking_evidence','sequential_only','independent_review','pending',
  'real_closure_proven',false,'production_gateway_integrated',false,
  'canonical_group_food_api_integrated',false,
  'legacy_fresh_create_forward_bypass_blocked',true,
  'all_legacy_mutation_paths_guarded',false) evidence;
rollback;
