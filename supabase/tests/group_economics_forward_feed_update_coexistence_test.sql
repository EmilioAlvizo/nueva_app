begin;

-- HUMAN Sandbox Dashboard: run this FULL BEGIN/ROLLBACK file and report the first error.
-- Fixture FIRST, no replacement core here. Expected first RED is the EXISTING update
-- guard: SQLSTATE23514, DETAIL invariant_violation/mixture_id, not undefined_function.
-- Same private ten-argument core and exact11 result; no public API or session bypass.
-- Target ends legitimately BEFORE forward entry through a later legacy creation.
-- Capture both legacy sources, then create a real private sibling AFTER admission.
-- Reopen with two other active sources; update open/closed/reopened target independently.
-- Hash remains group-feed-update.v1, current actor, canonical UTC old versions/recipe.
-- Fresh eligibility must count ALL open purposes before any source DML; never trust
-- an old exemption marker or invoke ambiguous legacy fallback to auto-close siblings.
-- Future migration must retain the separate Cycle-binding guard and all old contracts.
-- Forecast: fixture <=400 + FULL replacement migration <=330 (old core265 included)
-- = <=730 authored lines; hard cap800, no shortened-diff accounting or code golf.
-- Setup legitimately consumes event positions; ROLLBACK cannot rewind that sequence.
-- Observed update/refusal/replay/fault paths must not change sequence/event/basis rows.
-- No synthetic period closure/purpose loss with multiple active headers: the shared
-- metadata guard legitimately forbids that setup. This is sequential evidence only.

create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,gen_random_uuid() editor_a,gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,gen_random_uuid() type_b,
  gen_random_uuid() meat_a,gen_random_uuid() meat_b,
  gen_random_uuid() group_a,gen_random_uuid() group_other,gen_random_uuid() group_b,
  gen_random_uuid() category_a,gen_random_uuid() category_second,gen_random_uuid() category_archived,gen_random_uuid() category_b,
  gen_random_uuid() target_source,gen_random_uuid() prior_source,gen_random_uuid() sibling_source,
  gen_random_uuid() animal_a,gen_random_uuid() animal_other,gen_random_uuid() animal_b,
  gen_random_uuid() capture_op,gen_random_uuid() create_op,gen_random_uuid() reopen_op;
create temp table assertions(label text not null);
create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
-- Full JSON watches include every persistent legacy/private table and every fence.
create temp table watched as select n.nspname schema_name,c.relname table_name
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users')) and c.relkind in ('r','p');
create function pg_temp.business_state(p_op uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; f record; v_rows jsonb; v_result jsonb:='{}'; v_filter text; v_foods uuid[];
begin
  select * into f from pg_temp.ids;
  select coalesce(array_agg(mc.comida_id),'{}'::uuid[]) into v_foods
  from public.mezcla_comida mc where mc.mezcla_id=f.target_source;
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    v_filter:=' where (to_jsonb(r)->>''granja_id'' is null or to_jsonb(r)->>''granja_id''=any($1))';
    if t.schema_name='auth' then
      v_filter:=' where to_jsonb(r)->>''id''=any($2)';
    elsif t.table_name in ('granjas','perfiles') then
      v_filter:=' where to_jsonb(r)->>''id''=any($1||$2)';
    elsif t.schema_name='group_feed_integrity' then
      v_filter:=' where true';
      if p_op is not null then v_filter:=v_filter||format(' and not (r.scope=''group'' and r.entity_id=%L::uuid)',f.group_a); end if;
    end if;
    if p_op is not null then
      case t.table_name
        when 'mezcla' then v_filter:=v_filter||format(' and r.id<>%L::uuid',f.target_source);
        when 'mezcla_comida' then v_filter:=v_filter||format(' and r.mezcla_id<>%L::uuid',f.target_source);
        when 'comida' then v_filter:=v_filter||' and not r.id=any($3)';
        when 'group_period_feed_allocations' then v_filter:=v_filter||format(' and r.mixture_id<>%L::uuid',f.target_source);
        when 'group_occupancy_operations' then v_filter:=v_filter||format(' and r.operation_id<>%L::uuid',p_op);
        else null;
      end case;
    end if;
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb) from %I.%I r%s',
      t.schema_name,t.table_name,v_filter) into v_rows using array[f.farm_a::text,f.farm_b::text],
      array[f.owner_a::text,f.owner_b::text,f.editor_a::text,f.viewer_a::text],v_foods;
    v_result:=v_result||jsonb_build_object(t.schema_name||'.'||t.table_name,v_rows);
  end loop;
  return v_result||jsonb_build_object('sequence',(select jsonb_build_object('last_value',s.last_value,'is_called',s.is_called)
    from economics_v2.group_economics_event_position_seq s));
end;
$$;
create function pg_temp.update_feed(p_farm uuid,p_op uuid,p_period uuid,p_source uuid,
  p_av timestamptz,p_sv timestamptz,p_digest text,p_start date,p_end date,p_recipe jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  -- Trusted temporary gateway only; every business step belongs to the actual core.
  return economics_v2.update_group_feed_allocation(p_farm,p_op,p_period,p_source,p_av,p_sv,p_digest,p_start,p_end,p_recipe);
end;
$$;
create function pg_temp.update_sql(p_farm uuid,p_op uuid,p_period uuid,p_source uuid,
  p_av timestamptz,p_sv timestamptz,p_digest text,p_start date,p_end date,p_recipe jsonb)
returns text language sql set search_path='' as $$
  select format('select pg_temp.update_feed(%L::uuid,%L::uuid,%L::uuid,%L::uuid,%L::timestamptz,%L::timestamptz,%L,%L::date,%L::date,%L::jsonb)',
    p_farm,p_op,p_period,p_source,p_av,p_sv,p_digest,p_start,p_end,p_recipe);
$$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,p_field text default null,p_op uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_other jsonb; v_result jsonb; v_state text; v_detail text;
begin
  v_before:=pg_temp.business_state(); v_other:=pg_temp.business_state(p_op);
  perform set_config('f3uc.guard','on',true);
  perform set_config('f3uc.deny_dml',case when p_state in ('ZS001','ZA001','ZR001')
    or (p_state is null and p_op is not null) then 'off' else 'on' end,true);
  begin
    execute p_sql into v_result;
  exception when others then
    if p_state is null then raise; end if; -- First genuine RED escapes unchanged.
    get stacked diagnostics v_state=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform set_config('f3uc.guard','off',true);
  perform set_config('f3uc.deny_dml','off',true);
  perform pg_temp.check_true(pg_temp.business_state(p_op)=v_other,'full sibling headers/markers/facts/components/receipts and other fences unchanged');
  if p_state is not null or p_op is null then
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'all rows and ALL private fences unchanged/restored');
  end if;
  if p_state is not null then
    perform pg_temp.check_true(v_state=p_state,'expected SQLSTATE '||p_state);
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb @> jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field) and v_detail::jsonb ? 'entity_id','typed refusal DETAIL');
    end if;
  else perform pg_temp.check_true(v_result is not null,'actual core returned a result');
  end if;
  return v_result;
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"group-feed-update-coexistence"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Update coexistence A',owner_a from ids union all select farm_b,owner_b,'Update coexistence B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Update type A',owner_a from ids union all select type_b,farm_b,'Update type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Update meat A','carne',owner_a from ids union all select meat_b,farm_b,'Update meat B','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'Update group '||g::text,owner_a from ids cross join lateral unnest(array[group_a,group_other]) g
union all select group_b,farm_b,type_b,'Update foreign group',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select c,farm_a,'Update category '||c::text,c<>category_archived,owner_a from ids
cross join lateral unnest(array[category_a,category_second,category_archived]) c
union all select category_b,farm_b,'Update foreign category',true,owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
-- Real legacy singleton behavior ends the target; no hand-written ending/index bypass.
select public.crear_mezcla_completa(farm_a,target_source,current_date-3,group_a,jsonb_build_array(
  jsonb_build_object('categoria_id',category_a,'cantidad_kg',2,'costo_total',100),
  jsonb_build_object('categoria_id',category_second,'cantidad_kg',3,'costo_total',30))) from ids;
select public.crear_mezcla_completa(farm_a,prior_source,current_date-2,group_a,jsonb_build_array(
  jsonb_build_object('categoria_id',category_second,'cantidad_kg',1,'costo_total',10))) from ids;
select public.eliminar_categoria_comida_segura(farm_a,category_a) from ids;
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
  jsonb_build_array(jsonb_build_object('categoria_id',category_a,'cantidad_kg',4,'costo_total',80),
    jsonb_build_object('categoria_id',category_second,'cantidad_kg',2,'costo_total',20)) recipe from ids f;
do $seed$
declare t record; m record; c jsonb;
begin
  select * into t from pg_temp.targets;
  for m in select * from public.mezcla where id in(t.target_source,t.prior_source) order by id loop
    c:=economics_v2.validate_group_feed_source(t.farm_a,t.period_a,m.id,m.updated_at);
    perform economics_v2.capture_group_feed_allocation(t.farm_a,
      case when m.id=t.target_source then t.capture_op else gen_random_uuid() end,t.period_a,m.id,m.updated_at,c->>'source_digest');
  end loop;
  perform economics_v2.create_group_feed_allocation(t.farm_a,t.create_op,t.period_a,t.sibling_source,current_date-1,t.group_a,
    jsonb_build_array(jsonb_build_object('categoria_id',t.category_second,'cantidad_kg',2,'costo_total',20)));
end;
$seed$;
create temp table baseline as select t.*,a.id allocation_id,a.updated_at av,m.updated_at sv,a.source_digest digest,
  (select revision from group_feed_integrity.fences where scope='group' and entity_id=t.group_a) group_revision,
  to_jsonb(m)-array['fecha_inicio','fecha_termino','updated_at','group_feed_meat_exempt'] immutable_header
from targets t join economics_v2.group_period_feed_allocations a on a.mixture_id=t.target_source
join public.mezcla m on m.id=t.target_source;
set constraints all immediate;
set constraints all deferred;

create function pg_temp.guard_dml()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_setting('f3uc.guard',true)='on' and (current_setting('f3uc.deny_dml',true)='on' or tg_argv[0]='never') then
    raise exception using errcode='P0001',message='Update coexistence attempted forbidden DML';
  end if;
  if tg_level='ROW' then if tg_op='DELETE' then return old; else return new; end if; end if;
  return null;
end;
$$;
do $guards$
declare t record;
begin
  for t in select * from pg_temp.watched where schema_name<>'auth' loop
    -- Retained date-end sync issues zero-row Cycle UPDATEs even without a binding.
    -- Row guards allow those statements but forbid any actual legacy history mutation.
    execute format('create trigger f3uc_guard before insert or update or delete on %I.%I for each %s execute function pg_temp.guard_dml(%L)',
      t.schema_name,t.table_name,case when t.table_name in ('cycles','cycle_feeds') then 'row' else 'statement' end,
      case when t.table_name in ('mezcla','mezcla_comida','comida','group_period_feed_allocations','group_occupancy_operations','fences') then 'allowed' else 'never' end);
  end loop;
end;
$guards$;
create trigger f3uc_receipt_immutable before update or delete on economics_v2.group_occupancy_operations
for each statement execute function pg_temp.guard_dml('never');
create trigger f3uc_fact_identity before insert or delete on economics_v2.group_period_feed_allocations
for each statement execute function pg_temp.guard_dml('never');
create function pg_temp.stage_fault()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_stage text; a record; m record; c jsonb;
begin
  if current_setting('f3uc.guard',true)='on' then
    v_stage:=case tg_table_name when 'comida' then 'source' when 'group_period_feed_allocations' then 'allocation' else 'receipt' end;
    if v_stage='allocation' then
      if new.id<>old.id or new.period_id<>old.period_id or new.mixture_id<>old.mixture_id
        or new.granja_id<>old.granja_id or new.finalized_at is not null then raise exception 'Immutable allocation changed'; end if;
    end if;
    if v_stage='receipt' then
      select * into a from economics_v2.group_period_feed_allocations where id=(new.result->>'allocation_id')::uuid;
      select * into m from public.mezcla where id=a.mixture_id;
      c:=economics_v2.validate_group_feed_source(a.granja_id,a.period_id,m.id,m.updated_at);
      if new.event_position is not null or a.id is null or a.source_digest is distinct from c->>'source_digest'
        or a.source_updated_at is distinct from m.updated_at or new.result is distinct from jsonb_build_object(
          'contract_version','group-economics.forward.v3','operation_id',new.operation_id,'mixture_id',m.id,'period_id',a.period_id,
          'allocation_id',a.id,'updated_at',a.updated_at,'component_count',a.component_count,'quantity_kg',a.quantity_kg,
          'total_cost',a.total_cost,'source_digest',a.source_digest,'replayed',false) then raise exception 'Receipt must follow actual source and refreshed fact'; end if;
    end if;
    if current_setting('f3uc.fault',true)=v_stage then
      raise exception using errcode=case v_stage when 'source' then 'ZS001' when 'allocation' then 'ZA001' else 'ZR001' end,message='Injected late update fault';
    end if;
  end if;
  return new;
end;
$$;
create trigger f3uc_source_fault after insert on public.comida for each row execute function pg_temp.stage_fault();
create trigger f3uc_allocation_fault after update on economics_v2.group_period_feed_allocations for each row execute function pg_temp.stage_fault();
create trigger f3uc_receipt_last before insert on economics_v2.group_occupancy_operations for each row execute function pg_temp.stage_fault();
do $grants$
begin execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text); end;
$grants$;
grant execute on function pg_temp.update_feed(uuid,uuid,uuid,uuid,timestamptz,timestamptz,text,date,date,jsonb),
  pg_temp.update_sql(uuid,uuid,uuid,uuid,timestamptz,timestamptz,text,date,date,jsonb),
  pg_temp.checked(text,text,text,text,uuid),pg_temp.business_state(uuid),pg_temp.check_true(boolean,text) to authenticated,anon;
create temp table results(value jsonb);
do $first$
declare b record; v_result jsonb;
begin
  select * into b from pg_temp.baseline;
  perform pg_temp.check_true((select fecha_termino=current_date-2 from public.mezcla where id=b.target_source)
    and (select count(*)=2 from public.mezcla where grupo_id=b.group_a and fecha_termino is null),'legitimate ended target and two actual active siblings');
  set local role authenticated;
  -- Do NOT catch23514: the installed obsolete guard must be the first genuine RED.
  v_result:=pg_temp.checked(pg_temp.update_sql(b.farm_a,b.reopen_op,b.period_a,b.target_source,b.av,b.sv,b.digest,
    current_date-2,null,b.recipe),null,null,null,b.reopen_op);
  reset role;
  perform pg_temp.check_true((select revision>b.group_revision from group_feed_integrity.fences where scope='group' and entity_id=b.group_a),
    'first genuine reopening advances the intentional Group fence');
  insert into pg_temp.results values(v_result);
end;
$first$;

do $proof$
declare b record; a record; m record; p record; actor record; v_result jsonb; c jsonb; v_hash text; v_sql text;
  v_op uuid; v_av timestamptz; v_sv timestamptz; v_digest text; v_recipe jsonb; v_cost numeric; v_kg numeric;
  v_end date; v_zone text; v_before jsonb; v_mode text; v_cycle uuid; v_fence bigint; v_proc record; v_writer uuid;
begin
  select * into b from pg_temp.baseline;
  -- First result plus fully open update, valid ending, and genuine reopening with siblings.
  for p in select * from (values(0,100::numeric,6::numeric,null::date),(1,60,3,null::date),
    (2,40,4,current_date-1),(3,100,6,null::date)) q(step,cost,kg,ends_on) loop
    v_end:=p.ends_on; v_cost:=p.cost; v_kg:=p.kg;
    v_writer:=case when p.step=1 then b.editor_a else b.owner_a end;
    perform set_config('request.jwt.claim.sub',v_writer::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_writer,'role','authenticated')::text,true);
    if p.step=0 then
      v_op:=b.reopen_op; v_av:=b.av; v_sv:=b.sv; v_digest:=b.digest; v_recipe:=b.recipe;
      select value into v_result from pg_temp.results;
    else
      select * into a from economics_v2.group_period_feed_allocations where id=b.allocation_id;
      select * into m from public.mezcla where id=b.target_source;
      v_op:=gen_random_uuid(); v_av:=a.updated_at; v_sv:=m.updated_at; v_digest:=a.source_digest;
      -- Keep the archived category referenced at EVERY step; no new archival exemption.
      v_recipe:=case when p.step=3 then b.recipe else jsonb_build_array(
        jsonb_build_object('categoria_id',b.category_a,'cantidad_kg',v_kg-1,'costo_total',v_cost-20),
        jsonb_build_object('categoria_id',b.category_second,'cantidad_kg',1,'costo_total',20)) end;
      select revision into v_fence from group_feed_integrity.fences where scope='group' and entity_id=b.group_a;
      set local role authenticated;
      v_result:=pg_temp.checked(pg_temp.update_sql(b.farm_a,v_op,b.period_a,b.target_source,v_av,v_sv,v_digest,
        current_date-2,v_end,v_recipe),null,null,null,v_op);
      reset role;
      perform pg_temp.check_true((select revision>v_fence from group_feed_integrity.fences where scope='group' and entity_id=b.group_a),'successful update advances intentional Group fence');
    end if;
    select * into a from economics_v2.group_period_feed_allocations where id=b.allocation_id;
    select * into m from public.mezcla where id=b.target_source;
    c:=economics_v2.validate_group_feed_source(b.farm_a,b.period_a,m.id,m.updated_at);
    perform pg_temp.check_true(v_result=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',v_op,
      'mixture_id',m.id,'period_id',b.period_a,'allocation_id',b.allocation_id,'updated_at',a.updated_at,
      'component_count',jsonb_array_length(v_recipe),'quantity_kg',v_kg,'total_cost',v_cost,'source_digest',c->>'source_digest','replayed',false)
      and a.source_updated_at=m.updated_at and a.updated_at>v_av and m.updated_at>v_sv and a.source_digest<>v_digest
      and a.source_digest=c->>'source_digest' and a.finalized_at is null and a.occurred_on=current_date-2,'exact11 same identity/new real versions/recomputed digest');
    perform pg_temp.check_true(m.fecha_termino is not distinct from v_end and m.group_feed_meat_exempt
      and to_jsonb(m)-array['fecha_inicio','fecha_termino','updated_at','group_feed_meat_exempt']=b.immutable_header
      and (select count(*)=case when v_end is null then 3 else 2 end from public.mezcla where grupo_id=b.group_a and fecha_termino is null),
      'only owned target state changes; other open sources remain active');
    perform pg_temp.check_true((select count(*)=jsonb_array_length(v_recipe) and sum(mc.cantidad)=v_kg and sum(food.precio)=v_cost
      from public.mezcla_comida mc join public.comida food on food.id=mc.comida_id where mc.mezcla_id=b.target_source)
      and not exists(select 1 from jsonb_array_elements(v_recipe) r where not exists(select 1 from public.mezcla_comida mc
        join public.comida food on food.id=mc.comida_id where mc.mezcla_id=b.target_source and food.cat_comida_id=(r.value->>'categoria_id')::uuid
        and mc.cantidad=(r.value->>'cantidad_kg')::numeric and food.cantidad=mc.cantidad and food.precio=(r.value->>'costo_total')::numeric))
      and economics_v2.calculate_group_period_live_metrics(b.farm_a,b.period_a) @> jsonb_build_object(
        'feed_cost',v_cost+30,'feed_kg_total',v_kg+3,'acquisition_cost',300),'actual replacement once plus stable siblings30/3 and basis300');
    v_hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
      'contract_version','group-economics.forward.v3','operation_domain','group-feed-update.v1','granja_id',b.farm_a,
      'actor_id',v_writer,'operation_id',v_op,'request',jsonb_build_object('action','feed_update','period_id',b.period_a,'mixture_id',b.target_source,
        'expected_allocation_updated_at_utc',to_char(v_av at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        'expected_source_updated_at_utc',to_char(v_sv at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        'expected_source_digest',v_digest,'fecha_inicio',current_date-2,'fecha_termino',v_end,'ingredientes',v_recipe)))::text,'UTF8')),'hex');
    perform pg_temp.check_true((select payload_hash=v_hash and result=v_result and event_position is null
      from economics_v2.group_occupancy_operations where granja_id=b.farm_a and operation_id=v_op),'unchanged domain/current actor/canonical UTC receipt');
    v_sql:=pg_temp.update_sql(b.farm_a,v_op,b.period_a,b.target_source,v_av,v_sv,v_digest,current_date-2,v_end,v_recipe);
    perform pg_temp.check_true(pg_temp.checked(v_sql)=v_result||'{"replayed":true}'::jsonb,'no-DML replay precedes now-stale mutable versions');
  end loop;
  perform pg_temp.check_true((select revision>b.group_revision from group_feed_integrity.fences where scope='group' and entity_id=b.group_a),
    'successful coexistence advances only the permitted Group fence');
  perform pg_temp.check_true(pg_temp.checked(pg_temp.update_sql(b.farm_a,b.reopen_op,b.period_a,b.target_source,b.av,b.sv,b.digest,
    current_date-2,null,b.recipe))=(select value||'{"replayed":true}'::jsonb from pg_temp.results),'original reopening receipt survives all later target replacements');
  v_zone:=current_setting('TimeZone'); perform set_config('TimeZone','Etc/GMT+5',true);
  perform pg_temp.check_true(pg_temp.checked(pg_temp.update_sql(b.farm_a,v_op,b.period_a,b.target_source,v_av,v_sv,v_digest,
    m.fecha_inicio,v_end,jsonb_set(v_recipe,'{0,cantidad_kg}','"4.00"')))=v_result||'{"replayed":true}'::jsonb,'numeric normalization/UTC versions replay with pinned date');
  perform set_config('TimeZone',v_zone,true);
  for p in select * from (values
    (gen_random_uuid(),b.period_other,a.updated_at,m.updated_at,a.source_digest,'42501','forbidden','period_id'),
    (gen_random_uuid(),b.period_b,a.updated_at,m.updated_at,a.source_digest,'42501','forbidden','period_id'),
    (gen_random_uuid(),b.period_a,b.av,m.updated_at,a.source_digest,'40001','stale_write','allocation_id'),
    (gen_random_uuid(),b.period_a,a.updated_at,b.sv,a.source_digest,'40001','stale_write','mixture_id'),
    (gen_random_uuid(),b.period_a,null::timestamptz,m.updated_at,a.source_digest,'22023','invalid_request','expected_allocation_updated_at'),
    (gen_random_uuid(),b.period_a,a.updated_at,m.updated_at,repeat('0',64),'40001','stale_write','source_digest'),
    (b.create_op,b.period_a,a.updated_at,m.updated_at,a.source_digest,'22023','operation_payload_conflict','operation_id')) q(op,period,av,sv,digest,state,code,field) loop
    perform pg_temp.checked(pg_temp.update_sql(b.farm_a,p.op,p.period,b.target_source,p.av,p.sv,p.digest,current_date-2,null,b.recipe),p.state,p.code,p.field);
  end loop;
  for actor in select * from (values(b.editor_a,'authenticated'),(b.viewer_a,'authenticated'),(b.owner_b,'authenticated'),(null::uuid,'anon')) q(id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    perform pg_temp.checked(v_sql,case when actor.id=b.editor_a then '22023' else '42501' end,
      case when actor.id=b.editor_a then 'operation_payload_conflict' else 'forbidden' end,
      case when actor.id=b.editor_a then 'operation_id' else 'granja_id' end);
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',b.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b.owner_a,'role','authenticated')::text,true);
  for v_mode in select unnest(array['disabled','date','archived','foreign_category','cycle','source','allocation','receipt']) loop
    v_before:=pg_temp.business_state();
    begin
      if v_mode='disabled' then update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=b.farm_a;
      elsif v_mode='cycle' then
        -- Fresh real Cycle with no prior feeds: binding never closes an existing interval.
        v_cycle:=economics_v2.create_cycle_complete_impl(b.farm_a,b.meat_a,'Update binding guard',current_date-4,null);
        perform economics_v2.replace_cycle_feed_by_purpose_impl(b.farm_a,v_cycle,b.target_source,current_date-2,null);
      elsif v_mode in ('source','allocation','receipt') then perform set_config('f3uc.fault',v_mode,true);
      end if;
      perform pg_temp.checked(pg_temp.update_sql(b.farm_a,gen_random_uuid(),b.period_a,b.target_source,a.updated_at,m.updated_at,a.source_digest,
        case when v_mode='date' then current_date-5 else current_date-2 end,null,
        case when v_mode in ('archived','foreign_category') then jsonb_build_array(jsonb_build_object('categoria_id',
          case when v_mode='archived' then b.category_archived else b.category_b end,'cantidad_kg',1,'costo_total',1)) else b.recipe end),
        case v_mode when 'disabled' then '42501' when 'date' then '22023' when 'archived' then '22023' when 'foreign_category' then '42501'
          when 'cycle' then '23514' when 'source' then 'ZS001' when 'allocation' then 'ZA001' else 'ZR001' end,
        case when v_mode in ('disabled','foreign_category') then 'forbidden' when v_mode in ('date','archived') then 'invalid_request'
          when v_mode='cycle' then 'invariant_violation' else null end,
        case when v_mode='disabled' then 'granja_id' when v_mode='date' then 'occurred_on' when v_mode in ('archived','foreign_category') then 'category_id' else 'mixture_id' end);
      raise exception using errcode='Z0001',message='Restore legitimate binding/metadata/fault probe';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'complete rollback of source/fact/receipt/ALL fences and Cycle probe: '||v_mode);
  end loop;
  select * into v_proc from pg_proc where oid='economics_v2.update_group_feed_allocation(uuid,uuid,uuid,uuid,timestamp with time zone,timestamp with time zone,text,date,date,jsonb)'::regprocedure;
  perform pg_temp.check_true(v_proc.prorettype='jsonb'::regtype and not v_proc.prosecdef and v_proc.provolatile='v' and v_proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) x where x.grantee=0 and x.privilege_type='EXECUTE')
    and not has_function_privilege('anon',v_proc.oid,'EXECUTE') and not has_function_privilege('authenticated',v_proc.oid,'EXECUTE'),'private invoker/empty path/no client grants');
  set constraints all immediate;
  perform pg_temp.check_true((select count(*)=3 from economics_v2.group_period_feed_allocations where period_id=b.period_a)
    and not exists(select 1 from economics_v2.group_meat_snapshots where granja_id in(b.farm_a,b.farm_b)),'three retained identities, no closure snapshot');
end;
$proof$;
select jsonb_build_object('result','group_economics_forward_feed_update_coexistence_pass','assertion_count',(select count(*) from assertions),
  'fixture_ids',(select to_jsonb(t) from targets t),'locking_evidence','sequential_only','independent_review','pending',
  'real_closure_proven',false,'production_gateway_integrated',false,'canonical_group_food_api_integrated',false,
  'private_source_and_fact_update_performed',true,'meat_source_coexistence_proven',true) evidence;
rollback;
