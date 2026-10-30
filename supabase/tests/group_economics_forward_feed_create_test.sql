begin;

-- HUMAN Sandbox Dashboard: review, then run this FULL BEGIN/ROLLBACK file.
-- Preparation only: no execution, implementation or independent review is claimed.
-- NEW PRIVATE fixture contract, NOT an existing public API:
-- economics_v2.create_group_feed_allocation(p_granja_id uuid,p_operation_id uuid,
--   p_period_id uuid,p_mixture_id uuid,p_fecha_inicio date,p_grupo_id uuid,
--   p_ingredientes jsonb) returns jsonb. The temporary gateway only calls this core.
-- Expected first RED: genuine 42883 undefined_function escapes the first typed call.
-- Exact11 result: contract_version,operation_id,mixture_id,period_id,allocation_id,
-- updated_at,component_count,quantity_kg,total_cost,source_digest,replayed.
-- SHA256 UTF8 canonical_group_request envelope exact6: contract_version=
-- group-economics.forward.v3,operation_domain=group-feed-create.v1,granja_id,
-- actual actor_id,operation_id,request. Request exact6: action=feed_create,
-- period_id,mixture_id,fecha_inicio,grupo_id,ingredientes. Normalize UUID/numeric
-- exact3 categoria_id/cantidad_kg/costo_total objects; numeric scale is canonical,
-- array order remains identity. No input timestamps, totals, digest or trusted context.
-- Current actor/scalar/ingredient grammar precede shared farm/op conflict/replay;
-- historical replay precedes mutable period/source/category checks. Receipt LAST,
-- NULL event_position; inline create protocol must not reuse the capture operation.
-- Group must match the owned open meat period. Exactly one eligible open period
-- across ALL purposes is required BEFORE source DML: ambiguous classification must
-- refuse23514/invariant_violation/period_id, never invoke legacy singleton fallback.
-- Existing same-farm source UUID refuses23514/invariant_violation/mixture_id;
-- missing/foreign period42501/forbidden/period_id; Group mismatch42501/group_id.
-- Closed23514/closed_period_immutable/period_id; nonmeat22023/purpose_id;
-- dates22023/invalid_request/occurred_on; categories42501/forbidden/category_id
-- if foreign/missing,22023/invalid_request/category_id if archived. Typed DETAIL
-- includes contract_version,code,field,entity_id, following retained writer helpers.
-- Real INSERT header/dedicated food/components -> qualified actual source validator
-- -> allocation -> completed receipt. comida.precio is TOTAL cost, mc.cantidad kg.
-- Multiple active meat sources coexist; no previous header/fact/receipt replacement.
-- SECURITY INVOKER VOLATILE empty search_path; no PUBLIC/anon/authenticated EXECUTE.
-- Forecast: fixture <=480 + future complete private core <=300 = <=780; hard cap800.
-- Setup legitimately issues sequence values; ROLLBACK cannot rewind sequence setup.
-- Observed create/replay/refusal/fault paths must not consume any sequence values.
-- Synthetic metadata probes are not production transitions or real closure proof.

create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,gen_random_uuid() type_b,
  gen_random_uuid() meat_a,gen_random_uuid() posture_a,gen_random_uuid() meat_b,
  gen_random_uuid() group_a,gen_random_uuid() group_other,gen_random_uuid() group_b,
  gen_random_uuid() category_a,gen_random_uuid() category_second,gen_random_uuid() category_archived,gen_random_uuid() category_b,
  gen_random_uuid() prior_source,gen_random_uuid() deleted_source,gen_random_uuid() new_source,gen_random_uuid() editor_source,
  gen_random_uuid() animal_a,gen_random_uuid() animal_other,gen_random_uuid() animal_b,
  gen_random_uuid() capture_op,gen_random_uuid() update_op,gen_random_uuid() delete_op,
  gen_random_uuid() create_op,gen_random_uuid() editor_op;
create temp table assertions(label text not null);
create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
-- Discover every persistent table, including legacy bindings/expenses and private fences.
create temp table watched as select n.nspname schema_name,c.relname table_name
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users')) and c.relkind in ('r','p');
create function pg_temp.business_state(p_source uuid default null,p_op uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; f record; v_rows jsonb; v_result jsonb:='{}'; v_filter text; v_foods uuid[];
begin
  select * into f from pg_temp.ids;
  select coalesce(array_agg(mc.comida_id),'{}'::uuid[]) into v_foods
  from public.mezcla_comida mc where mc.mezcla_id=p_source;
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    -- Farm-bearing rows are bounded to the two fixture farms; shared metadata stays watched.
    v_filter:=' where (to_jsonb(r)->>''granja_id'' is null or to_jsonb(r)->>''granja_id''=any($1))';
    if t.schema_name='auth' then
      v_filter:=' where coalesce(to_jsonb(r)->>''user_id'',to_jsonb(r)->>''id'')=any($2)';
    elsif t.table_name in ('granjas','perfiles') then
      v_filter:=' where to_jsonb(r)->>''id''=any($1||$2)';
    elsif t.schema_name='group_feed_integrity' then
      v_filter:=' where true'; -- Fences have no farm column: retain every other Group/purpose.
      if p_source is not null then v_filter:=v_filter||format(' and not (r.scope=''group'' and r.entity_id=%L::uuid)',f.group_a); end if;
    end if;
    if p_source is not null then
      case t.table_name
        when 'mezcla' then v_filter:=v_filter||format(' and r.id<>%L::uuid',p_source);
        when 'mezcla_comida' then v_filter:=v_filter||format(' and r.mezcla_id<>%L::uuid',p_source);
        when 'comida' then v_filter:=v_filter||' and not r.id=any($4)';
        when 'group_period_feed_allocations' then v_filter:=v_filter||format(' and r.mixture_id<>%L::uuid',p_source);
        when 'group_occupancy_operations' then v_filter:=v_filter||format(' and r.operation_id<>%L::uuid',p_op);
        else null;
      end case;
    end if;
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb) from %I.%I r%s',
      t.schema_name,t.table_name,v_filter) into v_rows using array[f.farm_a::text,f.farm_b::text],
      array[f.owner_a::text,f.owner_b::text,f.editor_a::text,f.viewer_a::text],
      array[f.group_a,f.group_other,f.group_b,f.meat_a,f.meat_b,f.posture_a],v_foods;
    v_result:=v_result||jsonb_build_object(t.schema_name||'.'||t.table_name,v_rows);
  end loop;
  return v_result||jsonb_build_object('sequence',(select jsonb_build_object('last_value',s.last_value,'is_called',s.is_called)
    from economics_v2.group_economics_event_position_seq s));
end;
$$;
create function pg_temp.create_feed(p_farm uuid,p_op uuid,p_period uuid,p_source uuid,p_start date,p_group uuid,p_recipe jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  return economics_v2.create_group_feed_allocation(p_granja_id=>p_farm::uuid,p_operation_id=>p_op::uuid,
    p_period_id=>p_period::uuid,p_mixture_id=>p_source::uuid,p_fecha_inicio=>p_start::date,
    p_grupo_id=>p_group::uuid,p_ingredientes=>p_recipe::jsonb);
end;
$$;
create function pg_temp.create_sql(p_farm uuid,p_op uuid,p_period uuid,p_source uuid,p_start date,p_group uuid,p_recipe jsonb)
returns text language sql set search_path='' as $$
  select format('select pg_temp.create_feed(%L::uuid,%L::uuid,%L::uuid,%L::uuid,%L::date,%L::uuid,%L::jsonb)',
    p_farm,p_op,p_period,p_source,p_start,p_group,p_recipe);
$$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,p_field text default null,
  p_source uuid default null,p_op uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_other jsonb; v_result jsonb; v_state text; v_detail text;
begin
  v_before:=pg_temp.business_state(); v_other:=pg_temp.business_state(p_source,p_op);
  perform set_config('f3fc.guard','on',true);
  perform set_config('f3fc.deny_dml',case when p_state is null and p_source is not null
    or p_state in ('ZH001','ZF001','ZC001','ZA001','ZR001') then 'off' else 'on' end,true);
  begin
    execute p_sql into v_result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics v_state=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform set_config('f3fc.guard','off',true);
  perform set_config('f3fc.deny_dml','off',true);
  perform pg_temp.check_true(pg_temp.business_state(p_source,p_op)=v_other,'all unrelated rows/purpose fences/sequence unchanged');
  if p_state is not null or p_source is null then
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'full state including Group fence unchanged/restored');
  end if;
  if p_state is not null then
    perform pg_temp.check_true(v_state=p_state,'expected SQLSTATE '||p_state||': '||p_sql);
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb @> jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field) and v_detail::jsonb ? 'entity_id','typed refusal DETAIL');
    end if;
  else perform pg_temp.check_true(v_result is not null,'nonempty actual core result');
  end if;
  return v_result;
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"group-feed-create"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Create farm A',owner_a from ids union all select farm_b,owner_b,'Create farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Create type A',owner_a from ids union all select type_b,farm_b,'Create type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Create meat','carne',owner_a from ids union all select posture_a,farm_a,'Create eggs','postura',owner_a from ids
union all select meat_b,farm_b,'Create foreign meat','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'Create group '||g::text,owner_a from ids cross join lateral unnest(array[group_a,group_other]) g
union all select group_b,farm_b,type_b,'Create foreign group',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select c,farm_a,'Create category '||c::text,c<>category_archived,owner_a from ids
cross join lateral unnest(array[category_a,category_second,category_archived]) c
union all select category_b,farm_b,'Create foreign category',true,owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
-- All legacy producers precede every forward admission, never delegated to by NEW create.
select public.crear_mezcla_completa(farm_a,prior_source,current_date-3,group_a,jsonb_build_array(
  jsonb_build_object('categoria_id',category_a,'cantidad_kg',2,'costo_total',100))) from ids;
select public.crear_mezcla_completa(farm_a,deleted_source,current_date-3,group_other,jsonb_build_array(
  jsonb_build_object('categoria_id',category_a,'cantidad_kg',1,'costo_total',9))) from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,owner_a from ids
union all select animal_other,farm_a,type_a,group_other,meat_a,current_date-7,0,owner_a from ids
union all select animal_b,farm_b,type_b,group_b,meat_b,current_date-7,0,owner_b from ids;
create temp table admitted(animal_id uuid,result jsonb);
insert into admitted select a,economics_v2.enter_group_meat_initial(farm_a,gen_random_uuid(),a,current_date-4,
  case when a=animal_a then group_a else group_other end,meat_a,'{}') from ids cross join lateral unnest(array[animal_a,animal_other]) a;
select set_config('request.jwt.claim.sub',owner_b::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_b,'role','authenticated')::text,true) from ids;
insert into admitted select animal_b,economics_v2.enter_group_meat_initial(farm_b,gen_random_uuid(),animal_b,current_date-4,group_b,meat_b,'{}') from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
create temp table targets as select f.*,
  (select (result->>'destination_period_id')::uuid from admitted where animal_id=f.animal_a) period_a,
  (select (result->>'destination_period_id')::uuid from admitted where animal_id=f.animal_other) period_other,
  (select (result->>'destination_period_id')::uuid from admitted where animal_id=f.animal_b) period_b,
  (select (result->>'operation_id')::uuid from admitted where animal_id=f.animal_a) occupancy_op,
  jsonb_build_array(jsonb_build_object('categoria_id',category_a,'cantidad_kg',4,'costo_total',80),
    jsonb_build_object('categoria_id',category_second,'cantidad_kg',2,'costo_total',20)) recipe from ids f;
-- Seed REAL capture/update/delete namespace receipts; NEW create must preserve them all.
do $seed$
declare t record; c jsonb; a record; m record;
begin
  select * into t from pg_temp.targets;
  select * into m from public.mezcla where id=t.prior_source;
  c:=economics_v2.validate_group_feed_source(t.farm_a,t.period_a,m.id,m.updated_at);
  perform economics_v2.capture_group_feed_allocation(t.farm_a,t.capture_op,t.period_a,m.id,m.updated_at,c->>'source_digest');
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=m.id;
  perform economics_v2.update_group_feed_allocation(t.farm_a,t.update_op,t.period_a,m.id,a.updated_at,m.updated_at,
    c->>'source_digest',current_date-3,null,jsonb_build_array(jsonb_build_object('categoria_id',t.category_a,'cantidad_kg',2,'costo_total',100)));
  select * into m from public.mezcla where id=t.deleted_source;
  c:=economics_v2.validate_group_feed_source(t.farm_a,t.period_other,m.id,m.updated_at);
  perform economics_v2.capture_group_feed_allocation(t.farm_a,gen_random_uuid(),t.period_other,m.id,m.updated_at,c->>'source_digest');
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=m.id;
  perform economics_v2.delete_group_feed_allocation(t.farm_a,t.delete_op,t.period_other,m.id,a.updated_at,m.updated_at,c->>'source_digest');
end;
$seed$;
set constraints all immediate;
set constraints all deferred;

create function pg_temp.guard_dml()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_setting('f3fc.guard',true)='on' and (current_setting('f3fc.deny_dml',true)='on'
    or tg_argv[0]='never') then raise exception using errcode='P0001',message='Create attempted forbidden DML'; end if;
  return null;
end;
$$;
do $guards$
declare t record;
begin
  for t in select * from pg_temp.watched where schema_name<>'auth' loop
    execute format('create trigger f3fc_guard before insert or update or delete on %I.%I
      for each statement execute function pg_temp.guard_dml(%L)',t.schema_name,t.table_name,
      case when t.table_name in ('mezcla','mezcla_comida','comida','group_period_feed_allocations','group_occupancy_operations','fences') then 'allowed' else 'never' end);
    if t.table_name in ('mezcla','mezcla_comida','comida','group_period_feed_allocations','group_occupancy_operations') then
      execute format('create trigger f3fc_insert_only before update or delete on %I.%I
        for each statement execute function pg_temp.guard_dml(''never'')',t.schema_name,t.table_name);
    end if;
  end loop;
end;
$guards$;
create function pg_temp.stage_fault()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_stage text; v_a record; v_m record; v_context jsonb;
begin
  if current_setting('f3fc.guard',true)='on' then
    v_stage:=case tg_table_name when 'mezcla' then 'header' when 'comida' then 'food'
      when 'mezcla_comida' then 'component' when 'group_period_feed_allocations' then 'allocation' else 'receipt' end;
    if v_stage='receipt' then
      select * into v_a from economics_v2.group_period_feed_allocations where id=(new.result->>'allocation_id')::uuid;
      select * into v_m from public.mezcla where id=v_a.mixture_id;
      v_context:=economics_v2.validate_group_feed_source(v_a.granja_id,v_a.period_id,v_m.id,v_m.updated_at);
      if new.event_position is not null or v_a.id is null or v_a.source_digest is distinct from v_context->>'source_digest'
        or new.result is distinct from jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',new.operation_id,
          'mixture_id',v_a.mixture_id,'period_id',v_a.period_id,'allocation_id',v_a.id,'updated_at',v_a.updated_at,
          'component_count',v_a.component_count,'quantity_kg',v_a.quantity_kg,'total_cost',v_a.total_cost,
          'source_digest',v_a.source_digest,'replayed',false) then
        raise exception using errcode='P0001',message='Exact11 completed receipt must follow actual source and allocation';
      end if;
    end if;
    if current_setting('f3fc.fault',true)=v_stage then
      raise exception using errcode=case v_stage when 'header' then 'ZH001' when 'food' then 'ZF001'
        when 'component' then 'ZC001' when 'allocation' then 'ZA001' else 'ZR001' end,message='Injected real create stage fault';
    end if;
  end if;
  return new;
end;
$$;
create trigger f3fc_header_fault after insert on public.mezcla for each row execute function pg_temp.stage_fault();
create trigger f3fc_food_fault after insert on public.comida for each row execute function pg_temp.stage_fault();
create trigger f3fc_component_fault after insert on public.mezcla_comida for each row execute function pg_temp.stage_fault();
create trigger f3fc_allocation_fault after insert on economics_v2.group_period_feed_allocations for each row execute function pg_temp.stage_fault();
create trigger f3fc_receipt_last before insert on economics_v2.group_occupancy_operations for each row execute function pg_temp.stage_fault();
do $grants$
begin execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text); end;
$grants$;
grant execute on function pg_temp.create_feed(uuid,uuid,uuid,uuid,date,uuid,jsonb),pg_temp.create_sql(uuid,uuid,uuid,uuid,date,uuid,jsonb),
  pg_temp.checked(text,text,text,text,uuid,uuid),pg_temp.business_state(uuid,uuid),pg_temp.check_true(boolean,text) to authenticated,anon;
-- FIRST genuine call is restored only AFTER success, so one-active baseline can admit
-- closed/ambiguous metadata probes without violating the installed loss-of-exemption guard.
do $first$
declare t record; v_before jsonb; v_result jsonb; a record; m record;
begin
  select * into t from pg_temp.targets;
  v_before:=pg_temp.business_state();
  begin
    set local role authenticated;
    v_result:=pg_temp.checked(pg_temp.create_sql(t.farm_a,t.create_op,t.period_a,t.new_source,current_date-2,t.group_a,t.recipe),
      null,null,null,t.new_source,t.create_op);
    reset role;
    perform pg_temp.check_true(v_result->'replayed'='false'::jsonb,'first call genuinely creates source and fact');
    -- Real deletion removes the NEW source/fact but preserves its historical create receipt.
    select * into a from economics_v2.group_period_feed_allocations where mixture_id=t.new_source;
    select * into m from public.mezcla where id=t.new_source;
    perform economics_v2.delete_group_feed_allocation(t.farm_a,gen_random_uuid(),t.period_a,m.id,
      a.updated_at,m.updated_at,a.source_digest);
    update economics_v2.group_occupancy_periods set closed_on=current_date,end_position=start_position+1000 where id=t.period_a;
    perform pg_temp.check_true(pg_temp.checked(pg_temp.create_sql(t.farm_a,t.create_op,t.period_a,t.new_source,
      current_date-2,t.group_a,t.recipe))=v_result||'{"replayed":true}'::jsonb,
      'historical create replay precedes absent source/fact and synthetic closed period');
    raise exception using errcode='Z0001',message='Restore successful first create for metadata probes';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'first success restored including private fences');
end;
$first$;

do $proof$
declare t record; p record; actor record; v_mode text; v_before jsonb; v_sql text; v_result jsonb; v_repeat jsonb;
  v_context jsonb; a record; m record; v_hash text; v_proc record; v_fence bigint; v_zone text; v_date date;
begin
  select * into t from pg_temp.targets;
  v_date:=current_date-2;
  v_sql:=pg_temp.create_sql(t.farm_a,t.create_op,t.period_a,t.new_source,v_date,t.group_a,t.recipe);
  for p in select * from (values
    (t.capture_op,t.period_a,t.new_source,t.group_a,'22023','operation_payload_conflict','operation_id'),
    (t.update_op,t.period_a,t.new_source,t.group_a,'22023','operation_payload_conflict','operation_id'),
    (t.delete_op,t.period_a,t.new_source,t.group_a,'22023','operation_payload_conflict','operation_id'),
    (t.occupancy_op,t.period_a,t.new_source,t.group_a,'22023','operation_payload_conflict','operation_id'),
    (null::uuid,t.period_a,t.new_source,t.group_a,'22023','invalid_request','operation_id'),
    (gen_random_uuid(),null::uuid,t.new_source,t.group_a,'22023','invalid_request','period_id'),
    (gen_random_uuid(),t.period_a,null::uuid,t.group_a,'22023','invalid_request','mixture_id'),
    (gen_random_uuid(),t.period_a,t.new_source,null::uuid,'22023','invalid_request','group_id'),
    (gen_random_uuid(),gen_random_uuid(),t.new_source,t.group_a,'42501','forbidden','period_id'),
    (gen_random_uuid(),t.period_b,t.new_source,t.group_b,'42501','forbidden','period_id'),
    (gen_random_uuid(),t.period_a,t.new_source,t.group_other,'42501','forbidden','group_id'),
    (gen_random_uuid(),t.period_a,t.new_source,t.group_b,'42501','forbidden','group_id'),
    (gen_random_uuid(),t.period_a,t.prior_source,t.group_a,'23514','invariant_violation','mixture_id'))
    q(op,period,source,group_id,state,code,field) loop
    perform pg_temp.checked(pg_temp.create_sql(t.farm_a,p.op,p.period,p.source,v_date,p.group_id,t.recipe),p.state,p.code,p.field);
  end loop;
  for p in select * from (values
    (null::jsonb,'ingredientes','22023'),('[]'::jsonb,'ingredientes','22023'),('{}'::jsonb,'ingredientes','22023'),
    ('[null]'::jsonb,'ingredientes','22023'),('[{"cantidad_kg":1,"costo_total":1}]'::jsonb,'ingredientes','22023'),
    (jsonb_build_array((t.recipe->0)||'{"extra":1}'::jsonb),'ingredientes','22023'),
    (jsonb_build_array(jsonb_set(t.recipe->0,'{categoria_id}','"bad"')),'ingredientes','22023'),
    (jsonb_build_array(jsonb_set(t.recipe->0,'{cantidad_kg}','0')),'ingredientes','22023'),
    (jsonb_build_array(jsonb_set(t.recipe->0,'{cantidad_kg}','"NaN"')),'ingredientes','22023'),
    (jsonb_build_array(jsonb_set(t.recipe->0,'{costo_total}','"Infinity"')),'ingredientes','22023'),
    (jsonb_build_array(jsonb_set(t.recipe->0,'{costo_total}','-1')),'ingredientes','22023'),
    (jsonb_build_array(t.recipe->0,t.recipe->0),'ingredientes','22023'),
    (jsonb_build_array(jsonb_set(t.recipe->0,'{categoria_id}',to_jsonb(t.category_b))),'category_id','42501'),
    (jsonb_build_array(jsonb_set(t.recipe->0,'{categoria_id}',to_jsonb(gen_random_uuid()))),'category_id','42501'),
    (jsonb_build_array(jsonb_set(t.recipe->0,'{categoria_id}',to_jsonb(t.category_archived))),'category_id','22023')) q(recipe,field,state) loop
    perform pg_temp.checked(pg_temp.create_sql(t.farm_a,t.capture_op,t.period_a,t.new_source,v_date,t.group_a,p.recipe),
      case when p.field='ingredientes' then p.state else '22023' end,
      case when p.field='ingredientes' then 'invalid_request' else 'operation_payload_conflict' end,
      case when p.field='ingredientes' then p.field else 'operation_id' end);
    perform pg_temp.checked(pg_temp.create_sql(t.farm_a,gen_random_uuid(),t.period_a,t.new_source,v_date,t.group_a,p.recipe),
      p.state,case when p.state='42501' then 'forbidden' else 'invalid_request' end,p.field);
  end loop;
  for p in select d from unnest(array[null::date,current_date+1,'infinity'::date,current_date-6,current_date-5]) d loop
    perform pg_temp.checked(pg_temp.create_sql(t.farm_a,gen_random_uuid(),t.period_a,t.new_source,p.d,t.group_a,t.recipe),
      '22023','invalid_request','occurred_on');
  end loop;
  for v_mode in select unnest(array['closed','nonmeat','disabled','ambiguous','latest_event','header','food','component','allocation','receipt']) loop
    v_before:=pg_temp.business_state();
    begin
      if v_mode='closed' then update economics_v2.group_occupancy_periods set closed_on=current_date,end_position=start_position+1000 where id=t.period_a;
      elsif v_mode='nonmeat' then update economics_v2.group_occupancy_periods set purpose_id=t.posture_a where id=t.period_a;
      elsif v_mode='disabled' then update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=t.farm_a;
      elsif v_mode='ambiguous' then
        -- Explicit position avoids sequence consumption in this synthetic corruption probe.
        insert into economics_v2.group_occupancy_periods(granja_id,group_id,purpose_id,starts_on,start_position)
        values(t.farm_a,t.group_a,t.posture_a,current_date-4,(select start_position from economics_v2.group_occupancy_periods where id=t.period_a)+1000);
      elsif v_mode='latest_event' then
        insert into economics_v2.group_occupancy_events(granja_id,period_id,event_position,effective_on,action)
        values(t.farm_a,t.period_a,(select start_position from economics_v2.group_occupancy_periods where id=t.period_a)+1000,current_date-1,'enter');
      else perform set_config('f3fc.fault',v_mode,true);
      end if;
      perform pg_temp.checked(v_sql,case v_mode when 'closed' then '23514' when 'nonmeat' then '22023' when 'disabled' then '42501'
        when 'ambiguous' then '23514' when 'latest_event' then '22023' when 'header' then 'ZH001' when 'food' then 'ZF001'
        when 'component' then 'ZC001' when 'allocation' then 'ZA001' else 'ZR001' end,
        case v_mode when 'closed' then 'closed_period_immutable' when 'nonmeat' then 'invalid_request' when 'disabled' then 'forbidden'
          when 'ambiguous' then 'invariant_violation' when 'latest_event' then 'invalid_request' else null end,
        case v_mode when 'nonmeat' then 'purpose_id' when 'disabled' then 'granja_id' when 'latest_event' then 'occurred_on' else 'period_id' end);
      raise exception using errcode='Z0001',message='Restore metadata/fault probe';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'full rollback including fences: '||v_mode);
  end loop;
  select revision into v_fence from group_feed_integrity.fences where scope='group' and entity_id=t.group_a;
  set local role authenticated;
  v_result:=pg_temp.checked(v_sql,null,null,null,t.new_source,t.create_op);
  v_repeat:=pg_temp.checked(v_sql);
  reset role;
  select * into a from economics_v2.group_period_feed_allocations where mixture_id=t.new_source;
  select * into m from public.mezcla where id=t.new_source;
  v_context:=economics_v2.validate_group_feed_source(t.farm_a,t.period_a,m.id,m.updated_at);
  perform pg_temp.check_true(v_result=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',t.create_op,
    'mixture_id',m.id,'period_id',t.period_a,'allocation_id',a.id,'updated_at',a.updated_at,'component_count',2,
    'quantity_kg',6,'total_cost',100,'source_digest',v_context->>'source_digest','replayed',false)
    and v_repeat=v_result||'{"replayed":true}'::jsonb,'exact11 actual owner creation and no-DML replay');
  perform pg_temp.check_true(m.granja_id=t.farm_a and m.grupo_id=t.group_a and m.created_by=t.owner_a and m.fecha_inicio=v_date
    and m.fecha_termino is null and m.group_feed_meat_exempt and a.period_id=t.period_a and a.granja_id=t.farm_a
    and a.source_updated_at=m.updated_at and a.finalized_at is null and a.source_digest=v_context->>'source_digest'
    and a.component_count=2 and a.quantity_kg=6 and a.total_cost=100,'owned active actual source/fact agree');
  perform pg_temp.check_true((select count(*)=2 and sum(mc.cantidad)=6 and sum(c.precio)=100
    from public.mezcla_comida mc join public.comida c on c.id=mc.comida_id where mc.mezcla_id=t.new_source)
    and not exists(select 1 from public.mezcla_comida x join public.mezcla_comida y on y.comida_id=x.comida_id
      and y.mezcla_id<>x.mezcla_id where x.mezcla_id=t.new_source)
    and (select count(*)=2 from public.mezcla where grupo_id=t.group_a and fecha_termino is null)
    and (select revision>v_fence from group_feed_integrity.fences where scope='group' and entity_id=t.group_a),
    'two dedicated purchases, two active headers, intentional Group fence change only');
  perform pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(t.farm_a,t.period_a)
    @> '{"feed_cost":200,"feed_kg_total":8,"acquisition_cost":300}'::jsonb,'SUM prior100/2 plus new100/6 without overwrite/double charge');
  v_hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-feed-create.v1','granja_id',t.farm_a,
    'actor_id',t.owner_a,'operation_id',t.create_op,'request',jsonb_build_object('action','feed_create','period_id',t.period_a,
      'mixture_id',t.new_source,'fecha_inicio',v_date,'grupo_id',t.group_a,'ingredientes',t.recipe)))::text,'UTF8')),'hex');
  perform pg_temp.check_true((select payload_hash=v_hash and result=v_result and event_position is null
    from economics_v2.group_occupancy_operations where granja_id=t.farm_a and operation_id=t.create_op),'exact6 envelope/request/current owner receipt');
  v_zone:=current_setting('TimeZone');
  perform set_config('TimeZone','Etc/GMT+5',true);
  perform pg_temp.check_true(pg_temp.checked(pg_temp.create_sql(t.farm_a,t.create_op,t.period_a,t.new_source,v_date,t.group_a,
    jsonb_set(jsonb_set(t.recipe,'{0,cantidad_kg}','"4.00"'),'{0,categoria_id}',to_jsonb(upper(t.category_a::text)))))
    =v_repeat,'numeric scale/UUID normalization replay independent of timezone; date pinned');
  perform set_config('TimeZone',v_zone,true);
  perform pg_temp.checked(pg_temp.create_sql(t.farm_a,t.create_op,t.period_a,t.new_source,v_date,t.group_a,
    jsonb_build_array(t.recipe->1,t.recipe->0)),'22023','operation_payload_conflict','operation_id');
  perform pg_temp.checked(pg_temp.create_sql(t.farm_a,gen_random_uuid(),t.period_a,t.new_source,v_date,t.group_a,t.recipe),
    '23514','invariant_violation','mixture_id');
  for actor in select * from (values(t.editor_a,'authenticated'),(t.viewer_a,'authenticated'),(t.owner_b,'authenticated'),(null::uuid,'anon')) q(id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    perform pg_temp.checked(v_sql,case when actor.id=t.editor_a then '22023' else '42501' end,
      case when actor.id=t.editor_a then 'operation_payload_conflict' else 'forbidden' end,
      case when actor.id=t.editor_a then 'operation_id' else 'granja_id' end);
    perform pg_temp.checked('select economics_v2.create_group_feed_allocation(null::uuid,null::uuid,null::uuid,null::uuid,null::date,null::uuid,null::jsonb)','42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',t.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',t.editor_a,'role','authenticated')::text,true);
  v_sql:=pg_temp.create_sql(t.farm_a,t.editor_op,t.period_a,t.editor_source,v_date,t.group_a,
    jsonb_build_array(jsonb_build_object('categoria_id',t.category_second,'cantidad_kg',1,'costo_total',0)));
  set local role authenticated;
  v_result:=pg_temp.checked(v_sql,null,null,null,t.editor_source,t.editor_op);
  perform pg_temp.check_true(pg_temp.checked(v_sql)=v_result||'{"replayed":true}'::jsonb,'editor no-DML replay');
  reset role;
  perform pg_temp.check_true(v_result @> '{"component_count":1,"quantity_kg":1,"total_cost":0,"replayed":false}'::jsonb
    and (select created_by=t.editor_a from public.mezcla where id=t.editor_source)
    and economics_v2.calculate_group_period_live_metrics(t.farm_a,t.period_a)
      @> '{"feed_cost":200,"feed_kg_total":9,"acquisition_cost":300}'::jsonb,'editor creates legitimate additional zero-TOTAL-cost source');
  v_hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-feed-create.v1','granja_id',t.farm_a,
    'actor_id',t.editor_a,'operation_id',t.editor_op,'request',jsonb_build_object('action','feed_create','period_id',t.period_a,
      'mixture_id',t.editor_source,'fecha_inicio',v_date,'grupo_id',t.group_a,'ingredientes',jsonb_build_array(
        jsonb_build_object('categoria_id',t.category_second,'cantidad_kg',1,'costo_total',0)))))::text,'UTF8')),'hex');
  perform pg_temp.check_true((select payload_hash=v_hash and result=v_result and event_position is null
    from economics_v2.group_occupancy_operations where granja_id=t.farm_a and operation_id=t.editor_op),'actual editor receipt actor binding');
  -- Historical replay after mutable category archival; no metadata loss with multiple headers.
  v_before:=pg_temp.business_state();
  begin
    update public.cat_comida set activo=false where id=t.category_second;
    perform pg_temp.check_true(pg_temp.checked(v_sql)=v_result||'{"replayed":true}'::jsonb,'historical replay before archived-category admission');
    raise exception using errcode='Z0001',message='Restore archival probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'archival probe fully restored');
  select * into v_proc from pg_proc where oid='economics_v2.create_group_feed_allocation(uuid,uuid,uuid,uuid,date,uuid,jsonb)'::regprocedure;
  perform pg_temp.check_true(v_proc.prorettype='jsonb'::regtype and not v_proc.prosecdef and v_proc.provolatile='v'
    and v_proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) x where x.grantee=0 and x.privilege_type='EXECUTE')
    and not has_function_privilege('anon',v_proc.oid,'EXECUTE') and not has_function_privilege('authenticated',v_proc.oid,'EXECUTE'),
    'private invoker VOLATILE empty path/no PUBLIC or client grants');
  set constraints all immediate;
  perform pg_temp.check_true((select count(*)=3 from economics_v2.group_period_feed_allocations where period_id=t.period_a)
    and not exists(select 1 from economics_v2.group_meat_snapshots where granja_id in(t.farm_a,t.farm_b)),
    'one retained plus two new allocations; no closure snapshot');
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_feed_create_pass','assertion_count',(select count(*) from assertions),
  'fixture_ids',(select to_jsonb(t) from targets t),'locking_evidence','sequential_only','independent_review','pending',
  'real_closure_proven',false,'production_gateway_integrated',false,'canonical_group_food_api_integrated',false,
  'private_source_and_fact_create_performed',true) evidence;
rollback;
