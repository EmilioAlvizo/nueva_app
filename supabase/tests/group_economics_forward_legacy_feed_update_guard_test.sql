begin;

-- HUMAN Sandbox Dashboard only: review, then run this FULL BEGIN/ROLLBACK file.
-- Fixture FIRST: no UPDATE guard implementation, producer gateway or client grants.
-- Accepted design section 7: allocated source OR current/destination open meat Group
-- requires the forward path BEFORE ANY persistent DML, including private fences.
-- Exact4 technical DETAIL: contract_version/code/field/entity_id; mixture_id/source UUID.
-- Meaningful initial RED: uncaught P0001, public.mezcla UPDATE, from the actual owner
-- RPC with valid dates/recipe and the CURRENT SOURCE timestamp, not allocation version.
-- BEFORE STATEMENT observation precedes the header's BEFORE ROW fence maintenance.
-- Observers never manufacture typed refusal; every unexpected failure escapes intact.
-- All legacy sources, including unallocated meat sources, precede actual admission.
-- Closed-period branch SKIPPED: genuine open memberships cannot fit a finite period
-- span without actual membership exits. No invented closure/status/snapshot is used.
-- A reversible, singleton-safe purpose metadata probe isolates allocation protection;
-- it is synthetic classification evidence, NOT real closure or an occupancy producer.
-- Egg controls have no bound Cycle: no posture Cycle creation/synchronization proof.
-- No existing-UUID CREATE, direct-table bypass, DELETE or canonical API coverage.
-- Forecast: fixture358 + FULL retained body245 + all new guard/call/DDL <=130 = <=733.
-- Hard cap800; count the entire replacement, never a two-line guard insertion diff.
-- Sequential only. Setup consumes positions; ROLLBACK does not rewind sequences.
-- Refusals and egg controls must leave all watched sequence values unchanged.

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
  gen_random_uuid() foreign_source;
create temp table assertions(label text not null);
create function pg_temp.check_true(p_ok boolean, p_label text)
returns void language plpgsql security definer set search_path='' as $$
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
-- Retain old egg food identities after ingredient replacement deletes their rows.
create temp table egg_food_ids(id uuid primary key);
create function pg_temp.business_state(p_exclude_eggs boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare f record; t record; v_rows jsonb; v_result jsonb:='{}'; v_filter text;
  v_ids text[]; v_foods uuid[];
begin
  select * into f from pg_temp.ids;
  select array_agg(value) into v_ids from jsonb_each_text(to_jsonb(f));
  select coalesce(array_agg(id),'{}'::uuid[]) into v_foods from (
    select id from pg_temp.egg_food_ids
    union select comida_id from public.mezcla_comida
      where mezcla_id in (f.egg_owner_source,f.egg_editor_source)) food;
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

select set_config('legacy_feed_update_guard.armed','off',true);
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"legacy-feed-update-guard"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Legacy update farm A',owner_a from ids
union all select farm_b,owner_b,'Legacy update farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Legacy update type A',owner_a from ids
union all select type_b,farm_b,'Legacy update type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Legacy update meat','carne',owner_a from ids
union all select eggs_a,farm_a,'Legacy update eggs','postura',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'Legacy update Group '||g::text,owner_a
from ids cross join lateral unnest(array[group_meat_a,group_meat_b,group_egg_a,group_egg_b]) g
union all select group_foreign,farm_b,type_b,'Legacy update foreign Group',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select category_a,farm_a,'Legacy update ingredient A',true,owner_a from ids
union all select category_b,farm_b,'Legacy update ingredient B',true,owner_b from ids;
do $temp_access$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$temp_access$;
grant select on pg_temp.ids to authenticated;
-- Actual authenticated legacy creators, all BEFORE forward entry; no definer gateway.
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
-- Privileged setup invokes the qualified PRIVATE validator/capture directly.
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
  select * into v_proc from pg_proc
    where oid='public.actualizar_mezcla_completa(uuid,uuid,timestamptz,date,date,uuid,jsonb)'::regprocedure;
  perform pg_temp.check_true(not v_proc.prosecdef and v_proc.prorettype='void'::regtype
    and v_proc.proconfig @> array['search_path=""']
    and has_function_privilege('authenticated',v_proc.oid,'EXECUTE')
    and not has_function_privilege('anon',v_proc.oid,'EXECUTE')
    and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) x
      where x.grantee=0 and x.privilege_type='EXECUTE'), 'legacy UPDATE remains authenticated invoker/void/empty path');
  perform pg_temp.check_true(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='economics_v2' and p.proname in ('enter_group_meat_initial','validate_group_feed_source',
      'capture_group_feed_allocation','create_group_feed_allocation','update_group_feed_allocation',
      'delete_group_feed_allocation','raise_group_writer_error')
      and (has_function_privilege('authenticated',p.oid,'EXECUTE')
        or has_function_privilege('anon',p.oid,'EXECUTE'))), 'private producer and error helpers have no client EXECUTE');
end;
$preflight$;
create function pg_temp.guard_dml()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('legacy_feed_update_guard.armed',true)='on' then
    raise exception using errcode='P0001',
      message='Legacy update attempted persistent DML before forward-period refusal',
      detail=tg_table_schema||'.'||tg_table_name||' '||tg_op;
  end if;
  return null;
end;
$$;
do $observers$
declare t record;
begin
  for t in select * from pg_temp.watched loop
    execute format('create trigger legacy_feed_update_dml_observer
      before insert or update or delete or truncate on %I.%I
      for each statement execute function pg_temp.guard_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;
-- INVOKER ONLY: the real client role executes the unchanged public legacy RPC.
create function pg_temp.expect_refusal(
  p_source uuid, p_farm uuid, p_source_version timestamptz, p_group uuid,
  p_recipe jsonb, p_expected_state text default '23514'
) returns void language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_detail text; v_state text; v_refused boolean:=false;
begin
  v_before:=pg_temp.business_state();
  perform set_config('legacy_feed_update_guard.armed','on',true);
  begin
    perform public.actualizar_mezcla_completa(p_source,p_farm,p_source_version,
      current_date-2,null,p_group,p_recipe);
  exception when check_violation then
    if p_expected_state<>'23514' then raise; end if;
    get stacked diagnostics v_detail=pg_exception_detail;
    perform pg_temp.check_true(current_user='authenticated' and v_detail::jsonb=jsonb_build_object(
      'contract_version','group-economics.forward.v3','code','forward_group_period_required',
      'field','mixture_id','entity_id',p_source), 'authenticated exact4 forward UPDATE refusal');
    v_refused:=true;
  when insufficient_privilege or serialization_failure or foreign_key_violation then
    get stacked diagnostics v_state=returned_sqlstate;
    if v_state<>p_expected_state then raise; end if;
    v_refused:=true; -- Preserve existing SQLSTATE only, not invented authorization DETAIL.
  end;
  perform set_config('legacy_feed_update_guard.armed','off',true);
  perform pg_temp.check_true(v_refused,'legacy UPDATE refuses with '||p_expected_state);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,
    'refusal preserves every farm row, fact, receipt, fence and sequence');
end;
$$;
revoke all on function pg_temp.check_true(boolean,text),pg_temp.business_state(boolean),
  pg_temp.expect_refusal(uuid,uuid,timestamptz,uuid,jsonb,text) from public;
grant execute on function pg_temp.check_true(boolean,text),pg_temp.business_state(boolean),
  pg_temp.expect_refusal(uuid,uuid,timestamptz,uuid,jsonb,text) to authenticated,anon;

do $proof$
declare f record; s record; actor record; v_recipe jsonb; v_before jsonb; v_sv timestamptz;
  v_old_foods uuid[]; v_header jsonb;
begin
  select * into f from pg_temp.ids;
  v_recipe:=jsonb_build_array(jsonb_build_object('categoria_id',f.category_a,'cantidad_kg',3,'costo_total',12));
  select updated_at into v_sv from public.mezcla where id=f.allocated_source;
  -- FIRST meaningful probe. P0001 is deliberately NOT caught by expect_refusal.
  set local role authenticated;
  perform pg_temp.expect_refusal(f.allocated_source,f.farm_a,v_sv,f.group_meat_a,v_recipe);
  reset role;
  -- Each branch uses a genuine source with its own correct current source version.
  for s in select * from (values
    (f.editor_a,f.unallocated_source,f.group_meat_b), -- Current open meat, no allocation.
    (f.owner_a,f.egg_owner_source,f.group_meat_a), -- Destination-only open meat.
    (f.editor_a,f.unallocated_source,f.group_egg_a)) q(actor,source_id,destination) loop
    select updated_at into v_sv from public.mezcla where id=s.source_id;
    perform set_config('request.jwt.claim.sub',s.actor::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',s.actor,'role','authenticated')::text,true);
    set local role authenticated;
    perform pg_temp.expect_refusal(s.source_id,f.farm_a,v_sv,s.destination,v_recipe);
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  v_before:=pg_temp.business_state();
  begin
    -- One active source per affected Group; current metadata guards allow revocation.
    update public.cat_proposito_animal set codigo_calculo='postura' where id=f.meat_a;
    perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_periods p
      join public.cat_proposito_animal c on c.id=p.purpose_id and c.granja_id=p.granja_id
      where p.group_id=f.group_meat_a and p.closed_on is null and p.end_position is null
        and c.codigo_calculo='carne'), 'allocation-only probe has no current/destination open meat');
    select updated_at into v_sv from public.mezcla where id=f.allocated_source;
    set local role authenticated;
    perform pg_temp.expect_refusal(f.allocated_source,f.farm_a,v_sv,f.group_meat_a,v_recipe);
    reset role;
    raise exception using errcode='Z0001',message='Restore singleton-safe metadata probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'synthetic classification and all fences restored');
  select updated_at into v_sv from public.mezcla where id=f.allocated_source;
  for actor in select * from (values (f.viewer_a,'authenticated'),
    (f.owner_b,'authenticated'),(null::uuid,'anon')) q(user_id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.user_id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.user_id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    perform pg_temp.expect_refusal(f.allocated_source,f.farm_a,v_sv,f.group_meat_a,v_recipe,'42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  select updated_at into v_sv from public.mezcla where id=f.egg_owner_source;
  set local role authenticated;
  perform pg_temp.expect_refusal(f.egg_owner_source,f.farm_b,v_sv,f.group_foreign,v_recipe,'42501');
  perform pg_temp.expect_refusal(f.egg_owner_source,f.farm_a,v_sv,f.group_foreign,v_recipe,'23503');
  perform pg_temp.expect_refusal(f.egg_owner_source,f.farm_a,v_sv-interval '1 second',f.group_egg_a,v_recipe,'40001');
  reset role;
  -- Real ingredient/date/end updates on independent egg Groups, no sibling closure.
  v_before:=pg_temp.business_state(true);
  for s in select * from (values (f.owner_a,f.egg_owner_source,f.group_egg_a,current_date-1),
    (f.editor_a,f.egg_editor_source,f.group_egg_b,null::date)) q(actor,source_id,group_id,ends_on) loop
    select updated_at,to_jsonb(m)-array['fecha_inicio','fecha_termino','updated_at'] into v_sv,v_header
      from public.mezcla m where id=s.source_id;
    select array_agg(comida_id) into v_old_foods from public.mezcla_comida where mezcla_id=s.source_id;
    perform set_config('request.jwt.claim.sub',s.actor::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',s.actor,'role','authenticated')::text,true);
    set local role authenticated;
    perform public.actualizar_mezcla_completa(s.source_id,f.farm_a,v_sv,current_date-2,s.ends_on,s.group_id,v_recipe);
    reset role;
    perform pg_temp.check_true((select updated_at>v_sv and fecha_inicio=current_date-2
      and fecha_termino is not distinct from s.ends_on and created_by=s.actor and not group_feed_meat_exempt
      and to_jsonb(m)-array['fecha_inicio','fecha_termino','updated_at']=v_header
      from public.mezcla m where id=s.source_id), 'owner/editor egg update retains identity and advances source version');
    perform pg_temp.check_true((select count(*)=1 and sum(mc.cantidad)=3 and sum(c.precio)=12
      and bool_and(c.cantidad=mc.cantidad and c.cat_comida_id=f.category_a)
      from public.mezcla_comida mc join public.comida c on c.id=mc.comida_id where mc.mezcla_id=s.source_id)
      and not exists(select 1 from public.comida where id=any(v_old_foods)), 'real dedicated replacement preserves kg and TOTAL price');
  end loop;
  perform pg_temp.check_true(pg_temp.business_state(true)=v_before,
    'egg controls change only their headers, dedicated foods/components and egg Group fences');
  perform pg_temp.check_true(not exists(select 1 from public.mezcla
    where grupo_id in (f.group_egg_a,f.group_egg_b) and fecha_termino is null
    group by grupo_id having count(*)>1), 'egg Groups retain at most one active source');
  set constraints all immediate;
end;
$proof$;
select jsonb_build_object(
  'result','group_economics_forward_legacy_feed_update_guard_pass',
  'assertion_count',(select count(*) from assertions),'fixture_ids',(select to_jsonb(f) from ids f),
  'locking_evidence','sequential_only','independent_review','pending','real_closure_proven',false,
  'production_gateway_integrated',false,'canonical_group_food_api_integrated',false,
  'closed_period_branch','skipped_open_membership_requires_real_exit',
  'legacy_update_forward_bypass_blocked',true,'all_legacy_mutation_paths_guarded',false) evidence;
rollback;
