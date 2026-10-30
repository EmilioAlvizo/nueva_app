begin;

-- HUMAN sandbox Dashboard: review, then run this FULL BEGIN/ROLLBACK file.
-- NEW PRIVATE fixture expectation ONLY; no implemented/public delete contract is claimed.
-- economics_v2.delete_group_feed_allocation(farm uuid,operation uuid,period uuid,
--   mixture uuid,expected_allocation_updated_at timestamptz,
--   expected_source_updated_at timestamptz,expected_source_digest text) returns jsonb.
-- First real typed call must escape with missing-function RED; no substitute core.
-- Exact7 result: contract_version=group-economics.forward.v3, operation_id, mixture_id,
-- period_id, allocation_id, deleted=true, replayed=false (true on historical replay).
-- SHA256 UTF8 canonical_group_request envelope exact6: contract_version,
-- operation_domain=group-feed-delete.v1, granja_id, actual actor_id, operation_id, request.
-- Request exact6: action=feed_delete, period_id, mixture_id,
-- expected_allocation_updated_at_utc, expected_source_updated_at_utc, expected_source_digest.
-- UTC timestamps: YYYY-MM-DD"T"HH24:MI:SS.US"Z". Scalar grammar/current authorized actor
-- precede shared farm/op advisory/hash conflict/replay; replay precedes mutable reads.
-- Fresh locks mirror update: Groups ascending -> period -> allocation -> mixture ->
-- components/foods ascending -> category/type/purpose metadata; stabilize references via FKs.
-- Refuse Cycle bindings BEFORE DML. Explicit allocation/component/purchase/header DELETEs;
-- never depend on component cascades. Preserve completed capture/update receipts.
-- Completed delete receipt LAST with NULL event_position; no event/basis/sequence writes.
-- Closed/finalized probes are synthetic corruption, NOT actual closure/snapshot evidence.
-- Forecast: focused fixture <=460 + future private core <=250 = <=710, not a guarantee.
-- Sequential only; independent review, production gateway and canonical food API pending.
create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,gen_random_uuid() type_b,
  gen_random_uuid() meat_a,gen_random_uuid() meat_b,gen_random_uuid() posture_a,
  gen_random_uuid() group_a,gen_random_uuid() group_other,gen_random_uuid() group_b,
  gen_random_uuid() category_a,gen_random_uuid() category_second,gen_random_uuid() category_b,
  gen_random_uuid() mixture_a,gen_random_uuid() mixture_other,gen_random_uuid() mixture_b,
  gen_random_uuid() animal_a,gen_random_uuid() animal_other,gen_random_uuid() animal_b,
  gen_random_uuid() capture_op,gen_random_uuid() update_op,gen_random_uuid() delete_op,gen_random_uuid() editor_op;
create temp table assertions(label text not null);
create temp table owned_foods(id uuid primary key);
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
  ('economics_v2','cycles'),('economics_v2','cycle_feeds'),
  ('public','mezcla'),('public','mezcla_comida'),('public','comida'),('public','cat_comida'),
  ('public','animales'),('public','bajas_animales'),('public','venta_animal'),('public','grupos'),
  ('public','tipo_animal'),('public','cat_proposito_animal'),('public','miembros_granja');
create function pg_temp.business_state(p_all boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_t record; v_rows jsonb; v_result jsonb:='{}'; v_f record; v_foods uuid[]; v_extra text;
begin
  select f.* into v_f from pg_temp.ids f;
  select coalesce(array_agg(o.id),'{}'::uuid[]) into v_foods from pg_temp.owned_foods o;
  for v_t in select w.* from pg_temp.watched w order by w.schema_name,w.table_name loop
    v_extra:='';
    if not p_all then
      case v_t.table_name
        when 'mezcla' then v_extra:=format(' and r.id<>%L::uuid',v_f.mixture_a);
        when 'mezcla_comida' then v_extra:=format(' and r.mezcla_id<>%L::uuid',v_f.mixture_a);
        when 'comida' then v_extra:=' and not r.id=any($2)';
        when 'group_period_feed_allocations' then v_extra:=format(' and r.mixture_id<>%L::uuid',v_f.mixture_a);
        when 'group_occupancy_operations' then v_extra:=format(' and r.operation_id not in (%L::uuid,%L::uuid)',v_f.delete_op,v_f.editor_op);
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
create function pg_temp.delete_feed(p_farm uuid,p_op uuid,p_period uuid,p_mixture uuid,
  p_allocation_version timestamptz,p_source_version timestamptz,p_digest text)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  -- Trusted temporary gateway delegates ONLY to the real NEW private core.
  return economics_v2.delete_group_feed_allocation(p_farm,p_op,p_period,p_mixture,
    p_allocation_version,p_source_version,p_digest);
end;
$$;
create function pg_temp.delete_sql(p_farm uuid,p_op uuid,p_period uuid,p_mixture uuid,
  p_av timestamptz,p_sv timestamptz,p_digest text)
returns text language sql security invoker set search_path='' as $$
  select format('select pg_temp.delete_feed(%L::uuid,%L::uuid,%L::uuid,%L::uuid,%L::timestamptz,%L::timestamptz,%L::text)',
    p_farm,p_op,p_period,p_mixture,p_av,p_sv,p_digest);
$$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,p_field text default null,
  p_unchanged boolean default true)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_other jsonb; v_result jsonb; v_state text; v_detail text;
begin
  v_before:=pg_temp.business_state(); v_other:=pg_temp.business_state(false);
  perform set_config('f3fd.guard','on',true);
  perform set_config('f3fd.deny_dml',(case when (p_state is not null and p_state not in ('ZS001','ZA001','ZL001'))
    or (p_state is null and p_unchanged) then 'on' else 'off' end),true);
  begin
    execute p_sql into v_result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics v_state=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform set_config('f3fd.guard','off',true);
  perform set_config('f3fd.deny_dml','off',true);
  perform pg_temp.check_true(pg_temp.business_state(false)=v_other,'unrelated sources/receipts/Cycles/occupancy/basis/sequence unchanged');
  if p_state is not null or p_unchanged then
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'all source/fact/receipt rows unchanged: '||p_sql);
  end if;
  if p_state is not null then
    perform pg_temp.check_true(v_state=p_state,'expected SQLSTATE '||p_state||': '||p_sql);
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb @> jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field) and v_detail::jsonb ? 'entity_id','typed refusal: '||p_sql);
    end if;
  else perform pg_temp.check_true(v_result is not null,'nonempty real core result');
  end if;
  return v_result;
end;
$$;

select pg_temp.check_true(not exists(select 1 from auth.users u where u.raw_user_meta_data->>'fixture'='group-feed-delete'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"group-feed-delete"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F3FD farm A',owner_a from ids union all select farm_b,owner_b,'F3FD farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F3FD type A',owner_a from ids union all select type_b,farm_b,'F3FD type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'F3FD meat A','carne',owner_a from ids union all select posture_a,farm_a,'F3FD posture A','postura',owner_a from ids
union all select meat_b,farm_b,'F3FD meat B','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'F3FD group '||g::text,owner_a from ids cross join lateral unnest(array[group_a,group_other]) g
union all select group_b,farm_b,type_b,'F3FD foreign group',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select c,farm_a,'F3FD ingredient '||c::text,true,owner_a from ids cross join lateral unnest(array[category_a,category_second]) c
union all select category_b,farm_b,'F3FD foreign ingredient',true,owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
-- Actual legacy creation ONLY BEFORE forward admission; no legacy source mutation later.
select public.crear_mezcla_completa(farm_a,mixture_a,current_date-3,group_a,jsonb_build_array(
  jsonb_build_object('categoria_id',category_a,'cantidad_kg',2,'costo_total',100),
  jsonb_build_object('categoria_id',category_second,'cantidad_kg',3,'costo_total',30))) from ids;
select public.crear_mezcla_completa(farm_a,mixture_other,current_date-2,group_other,jsonb_build_array(
  jsonb_build_object('categoria_id',category_second,'cantidad_kg',1,'costo_total',9))) from ids;
create temp table legacy_cycle as select economics_v2.create_cycle_complete_impl(farm_a,meat_a,'F3FD unbound cycle',current_date-4,null) id from ids;
select set_config('request.jwt.claim.sub',owner_b::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_b,'role','authenticated')::text,true) from ids;
select public.crear_mezcla_completa(farm_b,mixture_b,current_date-2,group_b,jsonb_build_array(
  jsonb_build_object('categoria_id',category_b,'cantidad_kg',7,'costo_total',70))) from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,notas,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,'F3FD animal A',owner_a from ids
union all select animal_other,farm_a,type_a,group_other,meat_a,current_date-7,0,'F3FD other animal',owner_a from ids
union all select animal_b,farm_b,type_b,group_b,meat_b,current_date-7,0,'F3FD animal B',owner_b from ids;
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
-- Existing real combined update creates a historical receipt that deletion must preserve.
create temp table update_request as select c.*,a.updated_at allocation_version,
  jsonb_build_array(jsonb_build_object('categoria_id',c.category_a,'cantidad_kg',4,'costo_total',80),
    jsonb_build_object('categoria_id',c.category_second,'cantidad_kg',2,'costo_total',20)) ingredients
from captured c join economics_v2.group_period_feed_allocations a on a.mixture_id=c.mixture_a;
create temp table update_result as select economics_v2.update_group_feed_allocation(c.farm_a,c.update_op,c.period_a,c.mixture_a,
  c.allocation_version,(c.context->>'source_updated_at')::timestamptz,c.context->>'source_digest',current_date-2,null,c.ingredients) value from update_request c;
create temp table baseline as select t.*,a.id allocation_id,a.updated_at allocation_version,
  m.updated_at source_version,a.source_digest from targets t
join economics_v2.group_period_feed_allocations a on a.mixture_id=t.mixture_a join public.mezcla m on m.id=t.mixture_a;
insert into owned_foods select mc.comida_id from public.mezcla_comida mc where mc.mezcla_id=(select mixture_a from ids);
select pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(farm_a,period_a)
  @> '{"feed_cost":100,"feed_kg_total":6,"acquisition_cost":300}'::jsonb,'actual predelete feed100/6 and basis300') from baseline;
set constraints all immediate;
set constraints all deferred;

create function pg_temp.no_write()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_setting('f3fd.guard',true)='on' then raise exception using errcode='P0001',message='F3FD forbidden nondelete DML'; end if;
  return null;
end;
$$;
create function pg_temp.deny_validation_dml()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_setting('f3fd.guard',true)='on' and current_setting('f3fd.deny_dml',true)='on' then
    raise exception using errcode='P0001',message='F3FD refusal/replay attempted business DML';
  end if;
  return null;
end;
$$;
do $guards$
declare v_t record;
begin
  for v_t in select w.* from pg_temp.watched w loop
    if v_t.table_name in ('mezcla','mezcla_comida','comida','group_period_feed_allocations','group_occupancy_operations') then
      execute format('create trigger f3fd_validation_no_write before insert or update or delete on %I.%I
        for each statement execute function pg_temp.deny_validation_dml()',v_t.schema_name,v_t.table_name);
      execute format('create trigger f3fd_no_replace before %s on %I.%I for each statement execute function pg_temp.no_write()',
        case when v_t.table_name='group_occupancy_operations' then 'update or delete' else 'insert or update' end,v_t.schema_name,v_t.table_name);
    else
      execute format('create trigger f3fd_no_write before insert or update or delete on %I.%I
        for each statement execute function pg_temp.no_write()',v_t.schema_name,v_t.table_name);
    end if;
  end loop;
end;
$guards$;
create function pg_temp.delete_order_fault()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_b record;
begin
  if current_setting('f3fd.guard',true)='on' then
    select b.* into v_b from pg_temp.baseline b;
    if tg_table_name='mezcla' then
      if exists(select 1 from public.mezcla_comida mc where mc.mezcla_id=old.id)
        or exists(select 1 from economics_v2.group_period_feed_allocations a where a.mixture_id=old.id) then
        raise exception using errcode='P0001',message='F3FD explicit fact/components delete must precede header; no cascade';
      end if;
    elsif tg_table_name='comida' then
      if exists(select 1 from public.mezcla_comida mc where mc.comida_id=old.id) then
        raise exception using errcode='P0001',message='F3FD explicit components delete must precede purchase; no cascade';
      end if;
    elsif tg_table_name='group_occupancy_operations' then
      if new.event_position is not null or new.result is distinct from jsonb_build_object(
        'contract_version','group-economics.forward.v3','operation_id',new.operation_id,'mixture_id',v_b.mixture_a,
        'period_id',v_b.period_a,'allocation_id',v_b.allocation_id,'deleted',true,'replayed',false)
        or exists(select 1 from public.mezcla m where m.id=v_b.mixture_a)
        or exists(select 1 from public.mezcla_comida mc where mc.mezcla_id=v_b.mixture_a)
        or exists(select 1 from public.comida c join pg_temp.owned_foods o on o.id=c.id)
        or exists(select 1 from economics_v2.group_period_feed_allocations a where a.id=v_b.allocation_id) then
        raise exception using errcode='P0001',message='F3FD exact7 completed receipt LAST after all owned rows removed';
      end if;
      if current_setting('f3fd.fault',true)='receipt' then raise exception using errcode='ZL001',message='F3FD late receipt fault'; end if;
      return new;
    end if;
    if tg_when='AFTER' and tg_table_name='mezcla' and current_setting('f3fd.fault',true)='source' then
      raise exception using errcode='ZS001',message='F3FD late source header delete fault';
    elsif tg_table_name='group_period_feed_allocations' and current_setting('f3fd.fault',true)='allocation' then
      raise exception using errcode='ZA001',message='F3FD late allocation delete fault';
    end if;
  end if;
  return old;
end;
$$;
create trigger f3fd_header_order before delete on public.mezcla for each row execute function pg_temp.delete_order_fault();
create trigger f3fd_purchase_order before delete on public.comida for each row execute function pg_temp.delete_order_fault();
create trigger f3fd_source_fault after delete on public.mezcla for each row execute function pg_temp.delete_order_fault();
create trigger f3fd_allocation_fault after delete on economics_v2.group_period_feed_allocations for each row execute function pg_temp.delete_order_fault();
create trigger f3fd_receipt_fault before insert on economics_v2.group_occupancy_operations for each row execute function pg_temp.delete_order_fault();
do $grants$
begin execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text); end;
$grants$;
grant execute on function pg_temp.delete_feed(uuid,uuid,uuid,uuid,timestamptz,timestamptz,text),
  pg_temp.checked(text,text,text,text,boolean),pg_temp.business_state(boolean),pg_temp.check_true(boolean,text) to authenticated,anon;
do $first$
declare v_b record; v_result jsonb; v_before jsonb;
begin
  select b.* into v_b from pg_temp.baseline b;
  v_before:=pg_temp.business_state();
  begin
    perform set_config('f3fd.guard','on',true);
    set local role authenticated;
    -- FIRST NEW real typed call: undefined_function escapes immediately, never fabricated/caught.
    v_result:=pg_temp.delete_feed(v_b.farm_a,v_b.delete_op,v_b.period_a,v_b.mixture_a,
      v_b.allocation_version,v_b.source_version,v_b.source_digest);
    reset role;
    perform pg_temp.check_true(v_result @> '{"deleted":true,"replayed":false}'::jsonb,'first owner deletion is real');
    raise exception using errcode='Z0001',message='F3FD restore first successful owner deletion for refusal probes';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'first successful delete deliberately restored in subtransaction');
end;
$first$;

do $proof$
declare v_b record; v_probe record; v_actor record; v_mode text; v_before jsonb; v_result jsonb; v_repeat jsonb;
  v_sql text; v_hash text; v_food uuid; v_proc record; v_zone text;
begin
  select b.* into v_b from pg_temp.baseline b;
  v_sql:=pg_temp.delete_sql(v_b.farm_a,v_b.delete_op,v_b.period_a,v_b.mixture_a,v_b.allocation_version,v_b.source_version,v_b.source_digest);
  for v_probe in select * from (values
    (v_b.capture_op,v_b.period_a,v_b.mixture_a,v_b.allocation_version,v_b.source_version,v_b.source_digest,'22023','operation_payload_conflict','operation_id'),
    (v_b.update_op,v_b.period_a,v_b.mixture_a,v_b.allocation_version,v_b.source_version,v_b.source_digest,'22023','operation_payload_conflict','operation_id'),
    (v_b.occupancy_op,v_b.period_a,v_b.mixture_a,v_b.allocation_version,v_b.source_version,v_b.source_digest,'22023','operation_payload_conflict','operation_id'),
    (null::uuid,v_b.period_a,v_b.mixture_a,v_b.allocation_version,v_b.source_version,v_b.source_digest,'22023','invalid_request','operation_id'),
    (gen_random_uuid(),null::uuid,v_b.mixture_a,v_b.allocation_version,v_b.source_version,v_b.source_digest,'22023','invalid_request','period_id'),
    (gen_random_uuid(),v_b.period_a,null::uuid,v_b.allocation_version,v_b.source_version,v_b.source_digest,'22023','invalid_request','mixture_id'),
    (gen_random_uuid(),v_b.period_other,v_b.mixture_a,v_b.allocation_version,v_b.source_version,v_b.source_digest,'42501','forbidden','period_id'),
    (gen_random_uuid(),v_b.period_other,v_b.mixture_other,v_b.allocation_version,v_b.source_version,v_b.source_digest,'23514','invariant_violation','allocation_id'),
    (gen_random_uuid(),v_b.period_b,v_b.mixture_a,v_b.allocation_version,v_b.source_version,v_b.source_digest,'42501','forbidden','period_id'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_b,v_b.allocation_version,v_b.source_version,v_b.source_digest,'42501','forbidden','mixture_id'),
    (gen_random_uuid(),v_b.period_a,gen_random_uuid(),v_b.allocation_version,v_b.source_version,v_b.source_digest,'42501','forbidden','mixture_id'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_b.allocation_version-interval '1 second',v_b.source_version,v_b.source_digest,'40001','stale_write','allocation_id'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_b.allocation_version,v_b.source_version-interval '1 second',v_b.source_digest,'40001','stale_write','mixture_id'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_b.allocation_version,v_b.source_version,repeat('0',64),'40001','stale_write','source_digest'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,null::timestamptz,v_b.source_version,v_b.source_digest,'22023','invalid_request','expected_allocation_updated_at'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_b.allocation_version,null::timestamptz,v_b.source_digest,'22023','invalid_request','expected_source_updated_at'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,'infinity'::timestamptz,v_b.source_version,v_b.source_digest,'22023','invalid_request','expected_allocation_updated_at'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_b.allocation_version,'infinity'::timestamptz,v_b.source_digest,'22023','invalid_request','expected_source_updated_at'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_b.allocation_version,v_b.source_version,null::text,'22023','invalid_request','source_digest'),
    (gen_random_uuid(),v_b.period_a,v_b.mixture_a,v_b.allocation_version,v_b.source_version,'BAD','22023','invalid_request','source_digest'))
    p(op,period,mixture,av,sv,digest,state,code,field) loop
    perform pg_temp.checked(pg_temp.delete_sql(v_b.farm_a,v_probe.op,v_probe.period,v_probe.mixture,v_probe.av,v_probe.sv,v_probe.digest),v_probe.state,v_probe.code,v_probe.field);
  end loop;
  select o.id into v_food from pg_temp.owned_foods o order by o.id limit 1;
  for v_mode in select unnest(array['digest','closed','finalized','shared','cycle','source','allocation','receipt']) loop
    v_before:=pg_temp.business_state();
    begin
      if v_mode='digest' then update public.comida set precio=precio+1 where id=v_food;
      elsif v_mode='closed' then update economics_v2.group_occupancy_periods set closed_on=current_date,end_position=start_position+1000 where id=v_b.period_a;
      elsif v_mode='finalized' then update economics_v2.group_period_feed_allocations set finalized_at=clock_timestamp() where id=v_b.allocation_id;
      elsif v_mode='shared' then
        insert into public.mezcla_comida(id,granja_id,mezcla_id,comida_id,cantidad)
        values(gen_random_uuid(),v_b.farm_a,v_b.mixture_other,v_food,1);
      elsif v_mode='cycle' then
        -- Legitimate retained meat Cycle binding through real API; no constraint/trigger bypass.
        perform economics_v2.replace_cycle_feed_by_purpose_impl(v_b.farm_a,(select c.id from pg_temp.legacy_cycle c),v_b.mixture_a,current_date-2,null);
        perform pg_temp.check_true(exists(select 1 from economics_v2.cycle_feeds cf
          where cf.mezcla_id=v_b.mixture_a and cf.granja_id=v_b.farm_a),'actual Cycle-bound source negative branch');
      else perform set_config('f3fd.fault',v_mode,true);
      end if;
      perform pg_temp.checked(v_sql,
        (case v_mode when 'digest' then '40001' when 'source' then 'ZS001' when 'allocation' then 'ZA001' when 'receipt' then 'ZL001' else '23514' end),
        (case when v_mode='digest' then 'stale_write' when v_mode='closed' then 'closed_period_immutable'
          when v_mode in ('finalized','shared','cycle') then 'invariant_violation' else null end),
        (case when v_mode='digest' then 'source_digest' when v_mode='closed' then 'period_id'
          when v_mode='finalized' then 'allocation_id' else 'mixture_id' end));
      raise exception using errcode='Z0001',message='F3FD restore synthetic metadata/shared/Cycle/late-fault probe';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'all source/fact/receipt/Cycle rows restored: '||v_mode);
  end loop;
  -- A separate legitimate editor executes and replays a real deletion in a rollback probe.
  v_before:=pg_temp.business_state();
  begin
    perform set_config('request.jwt.claim.sub',v_b.editor_a::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_b.editor_a,'role','authenticated')::text,true);
    set local role authenticated;
    v_repeat:=pg_temp.checked(pg_temp.delete_sql(v_b.farm_a,v_b.editor_op,v_b.period_a,v_b.mixture_a,
      v_b.allocation_version,v_b.source_version,v_b.source_digest),null,null,null,false);
    perform pg_temp.check_true(v_repeat=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',v_b.editor_op,
      'mixture_id',v_b.mixture_a,'period_id',v_b.period_a,'allocation_id',v_b.allocation_id,'deleted',true,'replayed',false),'editor exact7 real deletion');
    perform pg_temp.check_true(pg_temp.checked(pg_temp.delete_sql(v_b.farm_a,v_b.editor_op,v_b.period_a,v_b.mixture_a,
      v_b.allocation_version,v_b.source_version,v_b.source_digest))=v_repeat||'{"replayed":true}'::jsonb,'editor replay with source absent');
    reset role;
    v_hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
      'contract_version','group-economics.forward.v3','operation_domain','group-feed-delete.v1','granja_id',v_b.farm_a,
      'actor_id',v_b.editor_a,'operation_id',v_b.editor_op,'request',jsonb_build_object('action','feed_delete',
        'period_id',v_b.period_a,'mixture_id',v_b.mixture_a,'expected_allocation_updated_at_utc',to_char(v_b.allocation_version at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        'expected_source_updated_at_utc',to_char(v_b.source_version at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        'expected_source_digest',v_b.source_digest)))::text,'UTF8')),'hex');
    perform pg_temp.check_true((select o.payload_hash=v_hash and o.result=v_repeat and o.event_position is null
      from economics_v2.group_occupancy_operations o where o.granja_id=v_b.farm_a and o.operation_id=v_b.editor_op),'editor receipt hashes actual editor, not source creator');
    raise exception using errcode='Z0001',message='F3FD restore editor deletion';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'editor real deletion restored for final owner success');
  set local role authenticated;
  v_result:=pg_temp.checked(v_sql,null,null,null,false);
  v_repeat:=pg_temp.checked(v_sql);
  reset role;
  perform pg_temp.check_true(v_result=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',v_b.delete_op,
    'mixture_id',v_b.mixture_a,'period_id',v_b.period_a,'allocation_id',v_b.allocation_id,'deleted',true,'replayed',false)
    and v_repeat=v_result||'{"replayed":true}'::jsonb,'owner exact7 and original allocation ID survive source/fact absence');
  perform pg_temp.check_true(not exists(select 1 from public.mezcla m where m.id=v_b.mixture_a)
    and not exists(select 1 from public.mezcla_comida mc where mc.mezcla_id=v_b.mixture_a)
    and not exists(select 1 from public.comida c join pg_temp.owned_foods o on o.id=c.id)
    and not exists(select 1 from economics_v2.group_period_feed_allocations a where a.id=v_b.allocation_id),'all owned source/components/purchases/fact physically removed');
  perform pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(v_b.farm_a,v_b.period_a)
    @> '{"feed_cost":0,"feed_kg_total":0,"acquisition_cost":300}'::jsonb,'actual feed deduction100/6 to0/0 keeps basis300');
  v_hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-feed-delete.v1','granja_id',v_b.farm_a,
    'actor_id',v_b.owner_a,'operation_id',v_b.delete_op,'request',jsonb_build_object('action','feed_delete',
      'period_id',v_b.period_a,'mixture_id',v_b.mixture_a,'expected_allocation_updated_at_utc',to_char(v_b.allocation_version at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'expected_source_updated_at_utc',to_char(v_b.source_version at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'expected_source_digest',v_b.source_digest)))::text,'UTF8')),'hex');
  perform pg_temp.check_true((select o.payload_hash=v_hash and o.result=v_result and o.event_position is null
    from economics_v2.group_occupancy_operations o where o.granja_id=v_b.farm_a and o.operation_id=v_b.delete_op),'exact delete domain/actual actor/request receipt');
  v_zone:=current_setting('TimeZone');
  perform set_config('TimeZone','Etc/GMT+5',true);
  perform pg_temp.check_true(pg_temp.checked(pg_temp.delete_sql(v_b.farm_a,v_b.delete_op,v_b.period_a,v_b.mixture_a,
    v_b.allocation_version,v_b.source_version,v_b.source_digest))=v_repeat,'canonical UTC replay after physical deletion');
  perform set_config('TimeZone',v_zone,true);
  perform pg_temp.checked(pg_temp.delete_sql(v_b.farm_a,v_b.delete_op,v_b.period_other,v_b.mixture_a,
    v_b.allocation_version,v_b.source_version,v_b.source_digest),'22023','operation_payload_conflict','operation_id');
  perform pg_temp.checked(pg_temp.delete_sql(v_b.farm_a,v_b.delete_op,v_b.period_a,v_b.mixture_a,
    v_b.allocation_version,v_b.source_version,repeat('0',64)),'22023','operation_payload_conflict','operation_id');
  perform pg_temp.checked(pg_temp.delete_sql(v_b.farm_a,v_b.delete_op,v_b.period_a,v_b.mixture_a,
    null,v_b.source_version,v_b.source_digest),'22023','invalid_request','expected_allocation_updated_at');
  perform pg_temp.checked(pg_temp.delete_sql(v_b.farm_a,gen_random_uuid(),v_b.period_a,v_b.mixture_a,
    v_b.allocation_version,v_b.source_version,v_b.source_digest),'42501','forbidden','mixture_id');
  for v_actor in select * from (values(v_b.editor_a,'authenticated'),(v_b.viewer_a,'authenticated'),(v_b.owner_b,'authenticated'),(null::uuid,'anon')) a(id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(v_actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_actor.id,'role',v_actor.role_name)::text,true);
    execute format('set local role %I',v_actor.role_name);
    perform pg_temp.checked(v_sql,(case when v_actor.id=v_b.editor_a then '22023' else '42501' end),
      (case when v_actor.id=v_b.editor_a then 'operation_payload_conflict' else 'forbidden' end),
      (case when v_actor.id=v_b.editor_a then 'operation_id' else 'granja_id' end));
    perform pg_temp.checked('select economics_v2.delete_group_feed_allocation(null::uuid,null::uuid,null::uuid,null::uuid,null::timestamptz,null::timestamptz,null::text)','42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',v_b.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_b.owner_a,'role','authenticated')::text,true);
  -- Both retained protocols replay BEFORE mutable reads; the real source is now gone.
  perform pg_temp.checked(format('select economics_v2.capture_group_feed_allocation(%L,%L,%L,%L,%L::timestamptz,%L)',
    c.farm_a,c.delete_op,c.period_a,c.mixture_a,c.context->>'source_updated_at',c.context->>'source_digest'),
    '22023','operation_payload_conflict','operation_id') from pg_temp.captured c;
  perform pg_temp.check_true(pg_temp.checked(format('select economics_v2.capture_group_feed_allocation(%L,%L,%L,%L,%L::timestamptz,%L)',
    c.farm_a,c.capture_op,c.period_a,c.mixture_a,c.context->>'source_updated_at',c.context->>'source_digest'))
    =(select r.value||'{"replayed":true}'::jsonb from pg_temp.capture_result r),'actual capture historical replay after source gone') from pg_temp.captured c;
  perform pg_temp.check_true(pg_temp.checked(format('select economics_v2.update_group_feed_allocation(%L,%L,%L,%L,%L::timestamptz,%L::timestamptz,%L,%L::date,null::date,%L::jsonb)',
    c.farm_a,c.update_op,c.period_a,c.mixture_a,c.allocation_version,c.context->>'source_updated_at',c.context->>'source_digest',current_date-2,c.ingredients))
    =(select r.value||'{"replayed":true}'::jsonb from pg_temp.update_result r),'actual update historical replay after source gone') from pg_temp.update_request c;
  select p.* into v_proc from pg_proc p where p.oid='economics_v2.delete_group_feed_allocation(uuid,uuid,uuid,uuid,timestamp with time zone,timestamp with time zone,text)'::regprocedure;
  perform pg_temp.check_true(v_proc.prorettype='jsonb'::regtype and not v_proc.prosecdef and v_proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE')
    and not has_function_privilege('anon',v_proc.oid,'EXECUTE') and not has_function_privilege('authenticated',v_proc.oid,'EXECUTE'),'private invoker/empty path/no PUBLIC or client EXECUTE');
  set constraints all immediate;
  perform pg_temp.check_true((select count(*)=6 from economics_v2.group_occupancy_operations o where o.granja_id in(v_b.farm_a,v_b.farm_b))
    and not exists(select 1 from economics_v2.group_meat_snapshots s where s.granja_id in(v_b.farm_a,v_b.farm_b)),'three occupancy/capture/update/delete receipts, no partial receipt or closure snapshot');
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_feed_delete_pass','assertion_count',(select count(*) from assertions),
  'fixture_ids',(select to_jsonb(t) from targets t),'locking_evidence','sequential_only','independent_review','pending',
  'real_closure_proven',false,'production_gateway_integrated',false,'canonical_group_food_api_integrated',false,
  'private_source_and_fact_delete_performed',true) as evidence;
rollback;
