begin;

-- HUMAN sandbox Dashboard: run this FULL BEGIN/ROLLBACK file; report the first error.
-- Expected initial RED: exact typed NEW combined producer/update call in pg_temp.update_feed.
-- Complete forecast: fixture <=460 + combined producer/protocol/refresh migration <=320 = <=780.
-- No temporary producer implementation and no legacy update after forward admission/capture.
-- Future private core owns ingredient replacement AND refresh AND completed receipt LAST.
-- Signature: farm/op/period/mixture, expected ALLOCATION timestamp, expected OLD SOURCE timestamp,
-- expected OLD SOURCE digest, new start/end dates, ingredient array. Group comes from immutable period.
-- No caller can provide a future server timestamp, future digest, totals or trusted context.
-- Hash envelope exact6: contract_version=group-economics.forward.v3, operation_domain=group-feed-update.v1,
-- granja_id, actual actor_id, operation_id, request. Request exact9: action=feed_update, period_id,
-- mixture_id, expected_allocation_updated_at_utc, expected_source_updated_at_utc, expected_source_digest,
-- fecha_inicio, fecha_termino, ingredientes. UTC stamps use YYYY-MM-DD"T"HH24:MI:SS.US"Z".
-- Normalize ingredient UUID/numeric values into exact3 categoria_id/cantidad_kg/costo_total objects;
-- canonical_group_request normalizes numeric scale; input array order remains request identity.
-- Scalar/ingredient grammar and current actor precede farm advisory/hash conflict/replay.
-- Historical replay precedes mutable source/allocation/period reads. Shared farm/op namespace,
-- NULL event_position; no occupancy preparer rewrite, event, animal/basis charge or sequence use.
-- Fresh update locks Groups ascending -> period -> allocation -> mixture -> component/food UUIDs
-- -> old/new category UUIDs, stabilizes references via parent FOR UPDATE/FKs, then validates old source.
-- Allocation farm/period/mixture/id stay pinned: wrong target42501/period_id; finalized fact23514/
-- invariant_violation/allocation_id; stale allocation40001/allocation_id; stale source40001/mixture_id;
-- actual old digest mismatch40001/source_digest. Retain archived categories ONLY if previously referenced.
-- Reject implicit active-sibling closure23514/invariant_violation/mixture_id before source DML.
-- Validate new dates against open period/latest events; no silent mutation of sibling allocations.
-- New source header and fact timestamps use real clock_timestamp(); preserve allocation ID/finalized NULL.
-- Revalidate new actual source via qualified validator, derive digest/totals, then exact11 result/receipt.
-- Source ingredient kg=mc.cantidad; comida.precio=TOTAL cost, never unit-price multiplication/proration.
-- Negative closed/finalized metadata probes are corruption only, NOT real F5 proof.
-- Sequential only; public API, legacy guards, deletion, finalization and concurrency remain deferred.
create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,gen_random_uuid() type_b,
  gen_random_uuid() meat_a,gen_random_uuid() meat_b,gen_random_uuid() posture_a,
  gen_random_uuid() group_a,gen_random_uuid() group_other,gen_random_uuid() group_b,
  gen_random_uuid() category_a,gen_random_uuid() category_second,gen_random_uuid() category_archived,gen_random_uuid() category_b,
  gen_random_uuid() mixture_a,gen_random_uuid() mixture_zero,gen_random_uuid() mixture_other,gen_random_uuid() mixture_b,
  gen_random_uuid() animal_a,gen_random_uuid() animal_other,gen_random_uuid() animal_b,
  gen_random_uuid() capture_op,gen_random_uuid() update_op,gen_random_uuid() editor_op;
create temp table assertions(label text not null);
create temp table original_food_ids(id uuid primary key);
create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
create temp table watched(schema_name text,table_name text,primary key(schema_name,table_name));
insert into watched values
  ('economics_v2','group_occupancy_operations'),('economics_v2','group_period_feed_allocations'),
  ('economics_v2','group_occupancy_periods'),('economics_v2','group_occupancy_memberships'),
  ('economics_v2','group_occupancy_events'),('economics_v2','group_animal_acquisition_basis'),
  ('economics_v2','group_acquisition_basis_entries'),('economics_v2','group_period_expenses'),
  ('economics_v2','group_period_sale_bindings'),('economics_v2','group_meat_snapshots'),('economics_v2','feature_flags'),
  ('public','mezcla'),('public','mezcla_comida'),('public','comida'),('public','cat_comida'),
  ('public','animales'),('public','bajas_animales'),('public','venta_animal'),('public','grupos'),
  ('public','tipo_animal'),('public','cat_proposito_animal'),('public','miembros_granja');
create function pg_temp.business_state(p_all boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_t record; v_rows jsonb; v_result jsonb:='{}'; v_f record; v_foods uuid[]; v_extra text;
begin
  select f.* into v_f from pg_temp.ids f;
  select array_agg(q.id) into v_foods from (select o.id from pg_temp.original_food_ids o
    union select mc.comida_id from public.mezcla_comida mc where mc.mezcla_id=v_f.mixture_a) q;
  for v_t in select w.* from pg_temp.watched w order by w.schema_name,w.table_name loop
    v_extra:='';
    if not p_all then
      case v_t.table_name
        when 'mezcla' then v_extra:=format(' and r.id<>%L::uuid',v_f.mixture_a);
        when 'mezcla_comida' then v_extra:=format(' and r.mezcla_id<>%L::uuid',v_f.mixture_a);
        when 'comida' then v_extra:=' and not r.id=any($2)';
        when 'group_period_feed_allocations' then v_extra:=format(' and r.mixture_id<>%L::uuid',v_f.mixture_a);
        when 'group_occupancy_operations' then v_extra:=format(' and r.operation_id not in (%L::uuid,%L::uuid)',v_f.update_op,v_f.editor_op);
        else null;
      end case;
    end if;
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r where (granja_id=any($1) or granja_id is null)%s',v_t.schema_name,v_t.table_name,v_extra)
      into v_rows using array[v_f.farm_a,v_f.farm_b],v_foods;
    v_result:=v_result||jsonb_build_object(v_t.schema_name||'.'||v_t.table_name,v_rows);
  end loop;
  return v_result||jsonb_build_object('sequence',(select jsonb_build_object('last_value',s.last_value,'is_called',s.is_called)
    from economics_v2.group_economics_event_position_seq s),
    'farms',(select jsonb_agg(to_jsonb(g) order by g.id) from public.granjas g where g.id in(v_f.farm_a,v_f.farm_b)),
    'users',(select jsonb_agg(to_jsonb(u) order by u.id) from auth.users u where u.id in(v_f.owner_a,v_f.owner_b,v_f.editor_a,v_f.viewer_a)),
    'profiles',(select jsonb_agg(to_jsonb(p) order by p.id) from public.perfiles p where p.id in(v_f.owner_a,v_f.owner_b,v_f.editor_a,v_f.viewer_a)));
end;
$$;
create function pg_temp.update_feed(p_farm uuid,p_op uuid,p_period uuid,p_mixture uuid,
  p_allocation_version timestamptz,p_source_version timestamptz,p_digest text,p_start date,p_end date,p_ingredients jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  -- Trusted fixture gateway, NOT a producer. The first NEW call performs all business work itself.
  return economics_v2.update_group_feed_allocation(p_farm,p_op,p_period,p_mixture,
    p_allocation_version,p_source_version,p_digest,p_start,p_end,p_ingredients);
end;
$$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,p_field text default null,
  p_unchanged boolean default true)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_other jsonb; v_result jsonb; v_state text; v_detail text;
begin
  v_before:=pg_temp.business_state(); v_other:=pg_temp.business_state(false);
  perform set_config('f3fu.guard','on',true);
  perform set_config('f3fu.deny_dml',(case when (p_state is not null and p_state not in ('ZS001','ZA001','ZL001'))
    or (p_state is null and p_unchanged) then 'on' else 'off' end),true);
  begin
    execute p_sql into v_result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics v_state=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform set_config('f3fu.guard','off',true);
  perform set_config('f3fu.deny_dml','off',true);
  perform pg_temp.check_true(pg_temp.business_state(false)=v_other,'unrelated sources/occupancy/basis/sequence unchanged');
  if p_state is not null or p_unchanged then
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'all source/fact/receipt rows unchanged: '||p_sql);
  end if;
  if p_state is not null then
    perform pg_temp.check_true(v_state=p_state,'expected SQLSTATE '||p_state||': '||p_sql);
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb @> jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field) and v_detail::jsonb ? 'entity_id','typed refusal: '||p_sql);
    end if;
  else perform pg_temp.check_true(v_result is not null,'nonempty update result');
  end if;
  return v_result;
end;
$$;

select pg_temp.check_true(not exists(select 1 from auth.users u where u.raw_user_meta_data->>'fixture'='group-feed-update'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"group-feed-update"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F3FU farm A',owner_a from ids union all select farm_b,owner_b,'F3FU farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F3FU type A',owner_a from ids union all select type_b,farm_b,'F3FU type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'F3FU meat A','carne',owner_a from ids union all select posture_a,farm_a,'F3FU posture A','postura',owner_a from ids
union all select meat_b,farm_b,'F3FU meat B','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'F3FU group '||g::text,owner_a from ids cross join lateral unnest(array[group_a,group_other]) g
union all select group_b,farm_b,type_b,'F3FU foreign group',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select c,farm_a,'F3FU ingredient '||c::text,true,owner_a from ids cross join lateral unnest(array[category_a,category_second,category_archived]) c
union all select category_b,farm_b,'F3FU foreign ingredient',true,owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
-- Actual legacy creation ONLY before forward admission. A ends through later real zero creation.
select public.crear_mezcla_completa(farm_a,mixture_a,current_date-3,group_a,jsonb_build_array(
  jsonb_build_object('categoria_id',category_a,'cantidad_kg',2,'costo_total',100),
  jsonb_build_object('categoria_id',category_second,'cantidad_kg',3,'costo_total',30))) from ids;
select public.crear_mezcla_completa(farm_a,mixture_other,current_date-2,group_other,jsonb_build_array(
  jsonb_build_object('categoria_id',category_archived,'cantidad_kg',1,'costo_total',1))) from ids;
select public.eliminar_categoria_comida_segura(farm_a,category_a) from ids;
select public.eliminar_categoria_comida_segura(farm_a,category_archived) from ids;
select public.crear_mezcla_completa(farm_a,mixture_zero,current_date-1,group_a,jsonb_build_array(
  jsonb_build_object('categoria_id',category_second,'cantidad_kg',1,'costo_total',0))) from ids;
select set_config('request.jwt.claim.sub',owner_b::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_b,'role','authenticated')::text,true) from ids;
select public.crear_mezcla_completa(farm_b,mixture_b,current_date-2,group_b,jsonb_build_array(
  jsonb_build_object('categoria_id',category_b,'cantidad_kg',7,'costo_total',70))) from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,notas,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,'F3FU animal A',owner_a from ids
union all select animal_other,farm_a,type_a,group_other,meat_a,current_date-7,0,'F3FU other animal',owner_a from ids
union all select animal_b,farm_b,type_b,group_b,meat_b,current_date-7,0,'F3FU animal B',owner_b from ids;
create temp table initial(animal_id uuid,result jsonb);
insert into initial select animal_b,economics_v2.enter_group_meat_initial(farm_b,gen_random_uuid(),animal_b,current_date-4,group_b,meat_b,'{}') from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
insert into initial select a,economics_v2.enter_group_meat_initial(farm_a,gen_random_uuid(),a,current_date-4,
  (case when a=animal_a then group_a else group_other end),meat_a,'{}') from ids cross join lateral unnest(array[animal_a,animal_other]) a;
create temp table targets as select f.*,
  (select (i.result->>'destination_period_id')::uuid from initial i where i.animal_id=f.animal_a) period_a,
  (select (i.result->>'destination_period_id')::uuid from initial i where i.animal_id=f.animal_other) period_other,
  (select (i.result->>'destination_period_id')::uuid from initial i where i.animal_id=f.animal_b) period_b,
  (select (i.result->>'operation_id')::uuid from initial i where i.animal_id=f.animal_a) occupancy_op from ids f;
create temp table captured as select t.*,economics_v2.validate_group_feed_source(t.farm_a,t.period_a,t.mixture_a,m.updated_at) context
from targets t join public.mezcla m on m.id=t.mixture_a;
create temp table capture_result as select economics_v2.capture_group_feed_allocation(c.farm_a,c.capture_op,c.period_a,c.mixture_a,
  (c.context->>'source_updated_at')::timestamptz,c.context->>'source_digest') value from captured c;
create temp table baseline as select c.*,a.id allocation_id,a.updated_at allocation_version,
  (c.context->>'source_updated_at')::timestamptz source_version,c.context->>'source_digest' source_digest,
  jsonb_build_array(jsonb_build_object('categoria_id',c.category_a,'cantidad_kg',4,'costo_total',80),
    jsonb_build_object('categoria_id',c.category_second,'cantidad_kg',2,'costo_total',20)) ingredients
from captured c join economics_v2.group_period_feed_allocations a on a.mixture_id=c.mixture_a;
insert into original_food_ids select mc.comida_id from public.mezcla_comida mc where mc.mezcla_id=(select mixture_a from ids);
set constraints all immediate;
set constraints all deferred;

create function pg_temp.no_write()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_setting('f3fu.guard',true)='on' then raise exception using errcode='P0001',message='F3FU unexpected nonupdate DML'; end if;
  return null;
end;
$$;
do $guards$
declare v_t record;
begin
  for v_t in select w.* from pg_temp.watched w where w.table_name not in
    ('mezcla','mezcla_comida','comida','group_period_feed_allocations','group_occupancy_operations') loop
    execute format('create trigger f3fu_no_write before insert or update or delete on %I.%I
      for each statement execute function pg_temp.no_write()',v_t.schema_name,v_t.table_name);
  end loop;
end;
$guards$;
-- Refusals/replays must precede source/fact DML; late-fault cases deliberately allow it.
create function pg_temp.deny_validation_dml()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_setting('f3fu.guard',true)='on' and current_setting('f3fu.deny_dml',true)='on' then
    raise exception using errcode='P0001',message='F3FU refusal/replay attempted business DML';
  end if;
  return null;
end;
$$;
do $validation_guards$
declare v_t record;
begin
  for v_t in select w.* from pg_temp.watched w where w.table_name in
    ('mezcla','mezcla_comida','comida','group_period_feed_allocations','group_occupancy_operations') loop
    execute format('create trigger f3fu_validation_no_write before insert or update or delete on %I.%I
      for each statement execute function pg_temp.deny_validation_dml()',v_t.schema_name,v_t.table_name);
  end loop;
end;
$validation_guards$;
create function pg_temp.update_fault()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if current_setting('f3fu.guard',true)='on' then
    if tg_table_name='group_period_feed_allocations' then
      if new.id<>old.id or new.period_id<>old.period_id or new.mixture_id<>old.mixture_id or new.granja_id<>old.granja_id
        or new.finalized_at is not null then raise exception using errcode='P0001',message='F3FU immutable allocation identity'; end if;
      if current_setting('f3fu.fault',true)='allocation' then raise exception using errcode='ZA001',message='F3FU late allocation update fault'; end if;
    elsif tg_table_name='group_occupancy_operations' then
      if new.event_position is not null or not exists(select 1 from economics_v2.group_period_feed_allocations a
        where a.id=(new.result->>'allocation_id')::uuid and a.source_digest=new.result->>'source_digest'
          and a.updated_at=(new.result->>'updated_at')::timestamptz) then
        raise exception using errcode='P0001',message='F3FU receipt must follow refreshed fact';
      end if;
      if current_setting('f3fu.fault',true)='receipt' then raise exception using errcode='ZL001',message='F3FU late receipt insertion fault'; end if;
    elsif current_setting('f3fu.fault',true)='source' then
      raise exception using errcode='ZS001',message='F3FU late source ingredient insertion fault';
    end if;
  end if;
  return new;
end;
$$;
create trigger f3fu_source_fault after insert on public.comida for each row execute function pg_temp.update_fault();
create trigger f3fu_allocation_fault after update on economics_v2.group_period_feed_allocations for each row execute function pg_temp.update_fault();
create trigger f3fu_receipt_fault before insert on economics_v2.group_occupancy_operations for each row execute function pg_temp.update_fault();
create trigger f3fu_receipt_no_update before update or delete on economics_v2.group_occupancy_operations for each statement execute function pg_temp.no_write();
create trigger f3fu_allocation_no_replace before insert or delete on economics_v2.group_period_feed_allocations for each statement execute function pg_temp.no_write();
do $grants$
begin execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text); end;
$grants$;
grant execute on function pg_temp.update_feed(uuid,uuid,uuid,uuid,timestamptz,timestamptz,text,date,date,jsonb),
  pg_temp.checked(text,text,text,text,boolean),pg_temp.business_state(boolean),pg_temp.check_true(boolean,text) to authenticated,anon;
create temp table results(value jsonb);
do $first$
declare v_b record; v_result jsonb; v_before jsonb;
begin
  select b.* into v_b from pg_temp.baseline b;
  v_before:=pg_temp.business_state(false);
  perform set_config('f3fu.guard','on',true);
  set local role authenticated;
  -- FIRST NEW typed producer/update call: missing-function error escapes before source DML.
  v_result:=pg_temp.update_feed(v_b.farm_a,v_b.update_op,v_b.period_a,v_b.mixture_a,
    v_b.allocation_version,v_b.source_version,v_b.source_digest,current_date-2,current_date-1,v_b.ingredients);
  reset role;
  perform set_config('f3fu.guard','off',true);
  perform pg_temp.check_true(pg_temp.business_state(false)=v_before,'first update preserves other sources/receipts/occupancy/basis/sequence');
  insert into pg_temp.results values(v_result);
end;
$first$;

do $proof$
declare v_b record; v_result jsonb; v_repeat jsonb; v_context jsonb; v_a record; v_m record; v_hash text;
  v_sql text; v_before jsonb; v_actor record; v_probe record; v_mode text; v_food uuid; v_bad jsonb; v_proc record; v_zone text;
begin
  select b.* into v_b from pg_temp.baseline b;
  select r.value into v_result from pg_temp.results r;
  select a.* into v_a from economics_v2.group_period_feed_allocations a where a.id=v_b.allocation_id;
  select m.* into v_m from public.mezcla m where m.id=v_b.mixture_a;
  v_context:=economics_v2.validate_group_feed_source(v_b.farm_a,v_b.period_a,v_b.mixture_a,v_m.updated_at);
  perform pg_temp.check_true(v_result=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',v_b.update_op,
    'mixture_id',v_b.mixture_a,'period_id',v_b.period_a,'allocation_id',v_b.allocation_id,'updated_at',v_a.updated_at,
    'component_count',2,'quantity_kg',6,'total_cost',100,'source_digest',v_context->>'source_digest','replayed',false),
    'exact11 result preserves allocation identity and captures TOTAL80+20 not weighted360');
  perform pg_temp.check_true(v_a.period_id=v_b.period_a and v_a.granja_id=v_b.farm_a and v_a.mixture_id=v_b.mixture_a
    and v_a.source_updated_at=v_m.updated_at and v_a.updated_at>v_b.allocation_version and v_m.updated_at>v_b.source_version
    and v_a.occurred_on=current_date-2 and v_a.component_count=2 and v_a.quantity_kg=6 and v_a.total_cost=100
    and v_a.finalized_at is null and v_a.source_digest=v_context->>'source_digest' and v_a.source_digest<>v_b.source_digest,
    'actual clocks/version/digest and refreshed fact agree without finalization');
  perform pg_temp.check_true((select count(*)=2 from public.mezcla_comida mc where mc.mezcla_id=v_b.mixture_a)
    and not exists(select 1 from public.comida c join pg_temp.original_food_ids o on o.id=c.id)
    and not (select c.activo from public.cat_comida c where c.id=v_b.category_a),
    'real NEW producer replaced dedicated old purchases and retained referenced inactive category');
  perform pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(v_b.farm_a,v_b.period_a)
    @> '{"feed_cost":100,"feed_kg_total":6,"acquisition_cost":300}'::jsonb,'updated economics replace130/5 with100/6; basis300 retained');
  v_hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-feed-update.v1','granja_id',v_b.farm_a,
    'actor_id',v_b.owner_a,'operation_id',v_b.update_op,'request',jsonb_build_object('action','feed_update',
      'period_id',v_b.period_a,'mixture_id',v_b.mixture_a,'expected_allocation_updated_at_utc',to_char(v_b.allocation_version at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'expected_source_updated_at_utc',to_char(v_b.source_version at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'expected_source_digest',v_b.source_digest,'fecha_inicio',current_date-2,'fecha_termino',current_date-1,'ingredientes',v_b.ingredients)))::text,'UTF8')),'hex');
  perform pg_temp.check_true((select o.payload_hash=v_hash and o.result=v_result and o.event_position is null
    from economics_v2.group_occupancy_operations o where o.granja_id=v_b.farm_a and o.operation_id=v_b.update_op),'exact domain/current actor/request receipt');
  v_sql:=format('select pg_temp.update_feed(%L,%L,%L,%L,%L::timestamptz,%L::timestamptz,%L,%L::date,%L::date,%L::jsonb)',
    v_b.farm_a,v_b.update_op,v_b.period_a,v_b.mixture_a,v_b.allocation_version,v_b.source_version,v_b.source_digest,current_date-2,current_date-1,v_b.ingredients);
  v_repeat:=pg_temp.checked(v_sql);
  perform pg_temp.check_true(v_repeat=v_result||'{"replayed":true}'::jsonb,'original replay precedes now-stale versions');
  v_zone:=current_setting('TimeZone');
  perform set_config('TimeZone','Etc/GMT+5',true);
  v_repeat:=pg_temp.checked(format('select pg_temp.update_feed(%L,%L,%L,%L,%L::timestamptz,%L::timestamptz,%L,%L::date,%L::date,%L::jsonb)',
    v_b.farm_a,v_b.update_op,v_b.period_a,v_b.mixture_a,v_b.allocation_version,v_b.source_version,v_b.source_digest,
    current_date-2,current_date-1,jsonb_set(v_b.ingredients,'{0,cantidad_kg}','4.00'::jsonb)));
  perform pg_temp.check_true(v_repeat=v_result||'{"replayed":true}'::jsonb,'canonical numeric scale and UTC request version replay');
  perform set_config('TimeZone',v_zone,true);
  perform pg_temp.checked(format('select economics_v2.capture_group_feed_allocation(%L,%L,%L,%L,%L::timestamptz,%L)',
    v_b.farm_a,v_b.update_op,v_b.period_a,v_b.mixture_a,v_b.source_version,v_b.source_digest),'22023','operation_payload_conflict','operation_id');
  v_repeat:=pg_temp.checked(format('select economics_v2.capture_group_feed_allocation(%L,%L,%L,%L,%L::timestamptz,%L)',
    v_b.farm_a,v_b.capture_op,v_b.period_a,v_b.mixture_a,v_b.source_version,v_b.source_digest));
  perform pg_temp.check_true(v_repeat=(select c.value||'{"replayed":true}'::jsonb from pg_temp.capture_result c),'capture historical receipt unchanged after update');
  for v_probe in select * from (values
    (v_b.capture_op,v_b.period_a,v_b.mixture_a,v_a.updated_at,v_m.updated_at,v_context->>'source_digest','22023','operation_payload_conflict','operation_id'),
    (v_b.occupancy_op,v_b.period_a,v_b.mixture_a,v_a.updated_at,v_m.updated_at,v_context->>'source_digest','22023','operation_payload_conflict','operation_id'),
    (v_b.update_op,v_b.period_other,v_b.mixture_a,v_b.allocation_version,v_b.source_version,v_b.source_digest,'22023','operation_payload_conflict','operation_id'),
    (v_b.update_op,v_b.period_a,v_b.mixture_a,v_a.updated_at,v_m.updated_at,v_context->>'source_digest','22023','operation_payload_conflict','operation_id'),
    (gen_random_uuid(),v_b.period_other,v_b.mixture_a,v_a.updated_at,v_m.updated_at,v_context->>'source_digest','42501','forbidden','period_id'),
    (gen_random_uuid(),v_b.period_b,v_b.mixture_a,v_a.updated_at,v_m.updated_at,v_context->>'source_digest','42501','forbidden','period_id'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_b,v_a.updated_at,v_m.updated_at,v_context->>'source_digest','42501','forbidden','mixture_id'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_b.allocation_version,v_m.updated_at,v_context->>'source_digest','40001','stale_write','allocation_id'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_a.updated_at,v_b.source_version,v_context->>'source_digest','40001','stale_write','mixture_id'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_a.updated_at,v_m.updated_at,repeat('0',64),'40001','stale_write','source_digest'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,null::timestamptz,v_m.updated_at,v_context->>'source_digest','22023','invalid_request','expected_allocation_updated_at'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_a.updated_at,null::timestamptz,v_context->>'source_digest','22023','invalid_request','expected_source_updated_at'))
    p(op,period,mixture,av,sv,digest,state,code,field) loop
    perform pg_temp.checked(format('select pg_temp.update_feed(%L,%L,%L,%L,%L::timestamptz,%L::timestamptz,%L,%L::date,%L::date,%L::jsonb)',
      v_b.farm_a,v_probe.op,v_probe.period,v_probe.mixture,v_probe.av,v_probe.sv,v_probe.digest,current_date-2,current_date-1,v_b.ingredients),v_probe.state,v_probe.code,v_probe.field);
  end loop;
  for v_actor in select * from (values(v_b.editor_a,'authenticated'),(v_b.viewer_a,'authenticated'),(v_b.owner_b,'authenticated'),(null::uuid,'anon')) a(id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(v_actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_actor.id,'role',v_actor.role_name)::text,true);
    execute format('set local role %I',v_actor.role_name);
    perform pg_temp.checked(v_sql,(case when v_actor.id=v_b.editor_a then '22023' else '42501' end),
      (case when v_actor.id=v_b.editor_a then 'operation_payload_conflict' else 'forbidden' end),
      (case when v_actor.id=v_b.editor_a then 'operation_id' else 'granja_id' end));
    perform pg_temp.checked('select economics_v2.update_group_feed_allocation(null::uuid,null::uuid,null::uuid,null::uuid,null::timestamptz,null::timestamptz,null::text,null::date,null::date,null::jsonb)','42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',v_b.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_b.owner_a,'role','authenticated')::text,true);
  -- Grammar/domain and category probes use current versions but must leave every source/fact intact.
  for v_probe in select * from (values
    ('null',null::jsonb),('empty','[]'::jsonb),('object','{}'::jsonb),('missing','[{"cantidad_kg":1,"costo_total":1}]'::jsonb),
    ('zero_kg',jsonb_build_array(jsonb_build_object('categoria_id',v_b.category_second,'cantidad_kg',0,'costo_total',1))),
    ('nan',jsonb_build_array(jsonb_build_object('categoria_id',v_b.category_second,'cantidad_kg','NaN','costo_total',1))),
    ('infinite',jsonb_build_array(jsonb_build_object('categoria_id',v_b.category_second,'cantidad_kg',1,'costo_total','Infinity'))),
    ('negative',jsonb_build_array(jsonb_build_object('categoria_id',v_b.category_second,'cantidad_kg',1,'costo_total',-1))),
    ('duplicate',jsonb_build_array(v_b.ingredients->0,v_b.ingredients->0)),
    ('foreign',jsonb_build_array(jsonb_build_object('categoria_id',v_b.category_b,'cantidad_kg',1,'costo_total',1))),
    ('new_archived',jsonb_build_array(jsonb_build_object('categoria_id',v_b.category_archived,'cantidad_kg',1,'costo_total',1)))) p(mode,ingredients) loop
    perform pg_temp.checked(format('select pg_temp.update_feed(%L,%L,%L,%L,%L::timestamptz,%L::timestamptz,%L,%L::date,%L::date,%L::jsonb)',
      v_b.farm_a,gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_a.updated_at,v_m.updated_at,v_context->>'source_digest',current_date-2,current_date-1,v_probe.ingredients),
      (case when v_probe.mode='foreign' then '42501' else '22023' end),
      (case when v_probe.mode='foreign' then 'forbidden' else 'invalid_request' end),
      (case when v_probe.mode in ('foreign','new_archived') then 'category_id' else 'ingredientes' end));
  end loop;
  for v_probe in select * from (values (null::date,current_date-1),(current_date+1,null::date),
    ('infinity'::date,null::date),(current_date-6,current_date-1),(current_date-2,current_date-3)) p(starts_on,ends_on) loop
    perform pg_temp.checked(format('select pg_temp.update_feed(%L,%L,%L,%L,%L::timestamptz,%L::timestamptz,%L,%L::date,%L::date,%L::jsonb)',
      v_b.farm_a,gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_a.updated_at,v_m.updated_at,v_context->>'source_digest',
      v_probe.starts_on,v_probe.ends_on,v_b.ingredients),'22023','invalid_request','occurred_on');
  end loop;
  select mc.comida_id into v_food from public.mezcla_comida mc where mc.mezcla_id=v_b.mixture_a order by mc.id limit 1;
  for v_mode in select unnest(array['digest','closed','finalized','nonmeat','disabled','source','allocation','receipt']) loop
    v_before:=pg_temp.business_state();
    begin
      if v_mode='digest' then update public.comida set precio=precio+1 where id=v_food;
      elsif v_mode='closed' then update economics_v2.group_occupancy_periods set closed_on=current_date,end_position=start_position+1000 where id=v_b.period_a;
      elsif v_mode='finalized' then update economics_v2.group_period_feed_allocations set finalized_at=clock_timestamp() where id=v_b.allocation_id;
      elsif v_mode='nonmeat' then update economics_v2.group_occupancy_periods set purpose_id=v_b.posture_a where id=v_b.period_a;
      elsif v_mode='disabled' then update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=v_b.farm_a;
      else perform set_config('f3fu.fault',v_mode,true);
      end if;
      perform pg_temp.checked(format('select pg_temp.update_feed(%L,%L,%L,%L,%L::timestamptz,%L::timestamptz,%L,%L::date,%L::date,%L::jsonb)',
        v_b.farm_a,gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_a.updated_at,v_m.updated_at,v_context->>'source_digest',current_date-2,current_date-1,v_b.ingredients),
        (case v_mode when 'digest' then '40001' when 'closed' then '23514' when 'finalized' then '23514' when 'nonmeat' then '22023'
          when 'disabled' then '42501' when 'source' then 'ZS001' when 'allocation' then 'ZA001' else 'ZL001' end),
        (case v_mode when 'digest' then 'stale_write' when 'closed' then 'closed_period_immutable' when 'finalized' then 'invariant_violation'
          when 'nonmeat' then 'invalid_request' when 'disabled' then 'forbidden' else null end),
        (case v_mode when 'digest' then 'source_digest' when 'finalized' then 'allocation_id' when 'nonmeat' then 'purpose_id'
          when 'disabled' then 'granja_id' else 'period_id' end));
      if v_mode in ('digest','closed','finalized') then
        v_repeat:=pg_temp.checked(v_sql);
        perform pg_temp.check_true(v_repeat=v_result||'{"replayed":true}'::jsonb,'historical replay before changed source/closed/finalized checks');
      end if;
      raise exception using errcode='Z0001',message='F3FU restore source/fact/metadata/late-fault probe';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'full old source/components/fact/receipt restored: '||v_mode);
  end loop;
  -- Explicitly reject reopening A while another real active mixture would be auto-closed.
  perform pg_temp.checked(format('select pg_temp.update_feed(%L,%L,%L,%L,%L::timestamptz,%L::timestamptz,%L,%L::date,null::date,%L::jsonb)',
    v_b.farm_a,gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_a.updated_at,v_m.updated_at,v_context->>'source_digest',current_date,v_b.ingredients),
    '23514','invariant_violation','mixture_id');
  -- An actual editor performs a NEW combined producer/update, not creator impersonation.
  insert into pg_temp.original_food_ids select mc.comida_id from public.mezcla_comida mc where mc.mezcla_id=v_b.mixture_a on conflict do nothing;
  perform set_config('request.jwt.claim.sub',v_b.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_b.editor_a,'role','authenticated')::text,true);
  v_bad:=jsonb_build_array(jsonb_build_object('categoria_id',v_b.category_second,'cantidad_kg',1,'costo_total',0));
  set local role authenticated;
  v_repeat:=pg_temp.checked(format('select pg_temp.update_feed(%L,%L,%L,%L,%L::timestamptz,%L::timestamptz,%L,%L::date,%L::date,%L::jsonb)',
    v_b.farm_a,v_b.editor_op,v_b.period_a,v_b.mixture_a,v_a.updated_at,v_m.updated_at,v_context->>'source_digest',current_date-2,current_date-1,v_bad),null,null,null,false);
  reset role;
  perform pg_temp.check_true(v_repeat @> jsonb_build_object('allocation_id',v_b.allocation_id,'component_count',1,'quantity_kg',1,'total_cost',0,'replayed',false)
    and economics_v2.calculate_group_period_live_metrics(v_b.farm_a,v_b.period_a) @> '{"feed_cost":0,"feed_kg_total":1,"acquisition_cost":300}'::jsonb,
    'editor real source replacement/refresh accepts zero total cost; immutable allocation/basis retained');
  v_hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-feed-update.v1','granja_id',v_b.farm_a,
    'actor_id',v_b.editor_a,'operation_id',v_b.editor_op,'request',jsonb_build_object('action','feed_update',
      'period_id',v_b.period_a,'mixture_id',v_b.mixture_a,'expected_allocation_updated_at_utc',to_char(v_a.updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'expected_source_updated_at_utc',to_char(v_m.updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'expected_source_digest',v_context->>'source_digest','fecha_inicio',current_date-2,'fecha_termino',current_date-1,'ingredientes',v_bad)))::text,'UTF8')),'hex');
  perform pg_temp.check_true((select o.payload_hash=v_hash and o.result=v_repeat and o.event_position is null
    from economics_v2.group_occupancy_operations o where o.granja_id=v_b.farm_a and o.operation_id=v_b.editor_op),
    'editor receipt records actual current editor, not source creator');
  select p.* into v_proc from pg_proc p where p.oid='economics_v2.update_group_feed_allocation(uuid,uuid,uuid,uuid,timestamp with time zone,timestamp with time zone,text,date,date,jsonb)'::regprocedure;
  perform pg_temp.check_true(v_proc.prorettype='jsonb'::regtype and not v_proc.prosecdef and v_proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE')
    and not has_function_privilege('anon',v_proc.oid,'EXECUTE') and not has_function_privilege('authenticated',v_proc.oid,'EXECUTE'),'private invoker/empty path/client ACL false');
  set constraints all immediate;
  perform pg_temp.check_true((select count(*)=1 from economics_v2.group_period_feed_allocations a where a.granja_id=v_b.farm_a)
    and (select count(*)=6 from economics_v2.group_occupancy_operations o where o.granja_id in(v_b.farm_a,v_b.farm_b))
    and not exists(select 1 from economics_v2.group_meat_snapshots s where s.granja_id in(v_b.farm_a,v_b.farm_b)),
    'same allocation, three real occupancy operations/capture/two updates, no partial receipt or F5 snapshot');
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_feed_update_pass','assertion_count',(select count(*) from assertions),
  'locking_evidence','sequential_only','private_source_and_fact_update_performed',true,'canonical_group_food_api_integrated',false,
  'real_closure_proven',false,'production_gateway_integrated',false,'independent_review','pending','fixture_ids',(select to_jsonb(t) from targets t)) as evidence;
rollback;
