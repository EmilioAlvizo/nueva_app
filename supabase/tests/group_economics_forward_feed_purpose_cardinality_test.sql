begin;

-- HUMAN Sandbox Dashboard: run this FULL BEGIN/ROLLBACK file and report the first error.
-- MCP may deliver the full file to the Sandbox after separate HUMAN authorization; no CLI is needed.
-- Preparation only: this file has not been executed or independently reviewed.
-- Use an isolated Sandbox: legitimate setup issues sequence values, which ROLLBACK cannot rewind.
-- Sequence preservation assertions apply to observed header INSERTs, not to admission setup.
-- Forecast: fixture <=400 + future shared-boundary migration <=250 = <=650; hard cap800.
-- Approved discriminator: exactly ONE trustworthy OPEN period across ALL purposes for the
-- same Group/farm, owned purpose codigo_calculo='carne', and an admissible source date.
-- Date admission retains the qualified source contract: finite start <=current_date,
-- start >=period.starts_on and no later applicable occupancy event/period history.
-- Valid non-null ends remain finite, >=start and <=current_date; no date protection is relaxed.
-- OPEN requires closed_on IS NULL AND end_position IS NULL. Count all open purposes:
-- one meat period plus another purpose is ambiguous, NOT an eligible meat exemption.
-- Ambiguous/unclassified Groups retain legacy singleton cardinality, without exemption.
-- Mutable animal membership, caller JWT purpose/period claims and session flags are not identity.
-- The source INSERT precedes allocation: a new header cannot need its own existing allocation.
-- Eggs remain one active mixture per Group, never one per farm; legacy posture sync remains.
-- Real legacy producers run ONLY before forward admission. Real initial-entry/validator/capture
-- cores establish the retained sources/facts. Later direct header INSERTs are trusted ADMIN
-- boundary fixtures, not complete sources, production source-create integration or a public API.
-- The extra posture period is legitimate synthetic foundation data, NOT a production transition.
-- No substitute producer, business helper, disabled constraint/trigger or fabricated end bypass.
-- Expected first cardinality RED: actual second meat header auto-closes the retained first source,
-- then P0001: 'meat sibling source header unchanged'. A unique_violation may instead expose
-- a partially changed boundary. Missing prerequisites/setup errors must be reported as themselves.
-- Protected update core still refuses sibling reopening; this fixture does not rewrite that proof.
-- Three active headers are representative checks, not an approved maximum on meat mixtures.

create temp table ids as select
  gen_random_uuid() owner_a, gen_random_uuid() owner_b,
  gen_random_uuid() farm_a, gen_random_uuid() farm_b,
  gen_random_uuid() type_a, gen_random_uuid() type_b,
  gen_random_uuid() meat, gen_random_uuid() posture, gen_random_uuid() meat_b,
  gen_random_uuid() group_meat, gen_random_uuid() group_egg_a, gen_random_uuid() group_egg_b,
  gen_random_uuid() group_unknown, gen_random_uuid() group_mixed, gen_random_uuid() group_foreign,
  gen_random_uuid() category, gen_random_uuid() animal_meat, gen_random_uuid() animal_egg,
  gen_random_uuid() animal_mixed, gen_random_uuid() animal_foreign, gen_random_uuid() animal_egg_b,
  gen_random_uuid() source_ended, gen_random_uuid() source_first,
  gen_random_uuid() source_second, gen_random_uuid() source_third, gen_random_uuid() header_ended,
  gen_random_uuid() egg_first, gen_random_uuid() egg_next,
  gen_random_uuid() egg_other_first, gen_random_uuid() egg_other_next,
  gen_random_uuid() unknown_first, gen_random_uuid() unknown_next,
  gen_random_uuid() mixed_first, gen_random_uuid() mixed_next, gen_random_uuid() foreign_bad;
create temp table assertions(label text not null);
create function pg_temp.check_true(p_ok boolean, p_label text)
returns void language plpgsql set search_path='' as $$
begin
  if p_ok is distinct from true then
    raise exception using errcode='P0001', message=p_label;
  end if;
  insert into pg_temp.assertions values (p_label);
end;
$$;

-- Observe all persistent public/economics tables, including legacy Cycle bindings,
-- source ingredients, allocation totals, occupancy, acquisition basis and receipts.
-- Only explicitly expected source headers may be excluded, never their ingredients/facts.
create function pg_temp.boundary_state(p_expected_headers uuid[] default '{}'::uuid[])
returns jsonb language plpgsql set search_path='' as $$
declare
  v_table record;
  v_rows jsonb;
  v_result jsonb := '{}';
  v_filter text;
begin
  for v_table in
    select n.nspname schema_name, c.relname table_name
    from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','economics_v2') and c.relkind in ('r','p')
    order by n.nspname,c.relname
  loop
    v_filter := case when v_table.schema_name='public' and v_table.table_name='mezcla'
      then ' where not (r.id=any($1))' else '' end;
    execute format(
      'select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb) from %I.%I r%s',
      v_table.schema_name,v_table.table_name,v_filter
    ) into v_rows using p_expected_headers;
    v_result := v_result || jsonb_build_object(v_table.schema_name||'.'||v_table.table_name,v_rows);
  end loop;
  return v_result || jsonb_build_object('position_sequence',
    (select jsonb_build_object('last_value',s.last_value,'is_called',s.is_called)
     from economics_v2.group_economics_event_position_seq s));
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"group-feed-purpose-cardinality"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Cardinality farm A',owner_a from ids
union all select farm_b,owner_b,'Cardinality farm B',owner_b from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Cardinality type A',owner_a from ids
union all select type_b,farm_b,'Cardinality type B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat,farm_a,'Cardinality meat','carne',owner_a from ids
union all select posture,farm_a,'Cardinality eggs','postura',owner_a from ids
union all select meat_b,farm_b,'Cardinality foreign meat','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'Cardinality group '||g::text,owner_a
from ids cross join lateral unnest(array[group_meat,group_egg_a,group_egg_b,group_unknown,group_mixed]) g
union all select group_foreign,farm_b,type_b,'Cardinality foreign group',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select category,farm_a,'Cardinality ingredient',true,owner_a from ids;
insert into public.animales(
  id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,created_by
)
select animal_meat,farm_a,type_a,group_meat,meat,current_date-7,30,owner_a from ids
union all select animal_egg,farm_a,type_a,group_egg_a,posture,current_date-7,0,owner_a from ids
union all select animal_egg_b,farm_a,type_a,group_egg_b,posture,current_date-7,0,owner_a from ids
union all select animal_mixed,farm_a,type_a,group_mixed,meat,current_date-7,0,owner_a from ids
union all select animal_foreign,farm_b,type_b,group_foreign,meat_b,current_date-7,0,owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;

-- Real legacy creation deliberately precedes EVERY forward admission.
select public.crear_mezcla_completa(farm_a,source_ended,current_date-3,group_meat,
  jsonb_build_array(jsonb_build_object('categoria_id',category,'cantidad_kg',1,'costo_total',5))) from ids;
select public.crear_mezcla_completa(farm_a,source_first,current_date-2,group_meat,
  jsonb_build_array(jsonb_build_object('categoria_id',category,'cantidad_kg',2,'costo_total',20))) from ids;
select public.crear_mezcla_completa(farm_a,egg_first,current_date-3,group_egg_a,
  jsonb_build_array(jsonb_build_object('categoria_id',category,'cantidad_kg',1,'costo_total',3))) from ids;
select public.crear_mezcla_completa(farm_a,egg_other_first,current_date-3,group_egg_b,
  jsonb_build_array(jsonb_build_object('categoria_id',category,'cantidad_kg',1,'costo_total',4))) from ids;
select public.crear_mezcla_completa(farm_a,unknown_first,current_date-2,group_unknown,
  jsonb_build_array(jsonb_build_object('categoria_id',category,'cantidad_kg',1,'costo_total',6))) from ids;
select public.crear_mezcla_completa(farm_a,mixed_first,current_date-2,group_mixed,
  jsonb_build_array(jsonb_build_object('categoria_id',category,'cantidad_kg',1,'costo_total',7))) from ids;

create temp table egg_cycle as
select public.crear_ciclo_v2_con_fechas(farm_a,posture,current_date-3,null::date) cycle_id from ids;
select public.asignar_animal_ciclo_v2(f.farm_a,c.cycle_id,f.animal_egg,current_date-3)
from ids f cross join egg_cycle c;
select public.reemplazar_alimento_ciclo_v2(f.farm_a,c.cycle_id,f.egg_first,current_date-3,null::date)
from ids f cross join egg_cycle c;
create temp table egg_other_before as
select to_jsonb(m) value from public.mezcla m where m.id=(select egg_other_first from ids);
select public.crear_mezcla_completa(farm_a,egg_next,current_date-1,group_egg_a,
  jsonb_build_array(jsonb_build_object('categoria_id',category,'cantidad_kg',1,'costo_total',8))) from ids;
select pg_temp.check_true(
  (select m.fecha_termino=current_date-1 from public.mezcla m where m.id=f.egg_first)
  and (select count(*)=1 from public.mezcla m where m.grupo_id=f.group_egg_a and m.fecha_termino is null),
  'eggs close previous source and retain exactly one active per Group') from ids f;
select pg_temp.check_true(
  (select to_jsonb(m)=b.value from public.mezcla m cross join egg_other_before b where m.id=f.egg_other_first),
  'egg replacement leaves the other Group on the same farm unchanged') from ids f;
select pg_temp.check_true(
  (select c.status='production_closed' and c.production_closed_on=current_date-2 and c.ends_on=current_date-1
   from economics_v2.cycles c where c.id=(select cycle_id from egg_cycle))
  and (select cf.ends_on=current_date-1 from economics_v2.cycle_feeds cf
       where cf.cycle_id=(select cycle_id from egg_cycle) and cf.mezcla_id=f.egg_first),
  'actual legacy posture binding synchronizes mixture closure') from ids f;
select public.crear_mezcla_completa(farm_a,egg_other_next,current_date,group_egg_b,
  jsonb_build_array(jsonb_build_object('categoria_id',category,'cantidad_kg',1,'costo_total',9))) from ids;
select pg_temp.check_true(
  (select count(*)=2 from public.mezcla m
   where m.grupo_id in (f.group_egg_a,f.group_egg_b) and m.fecha_termino is null)
  and (select m.fecha_termino is null from public.mezcla m where m.id=f.egg_next)
  and (select m.fecha_termino=current_date from public.mezcla m where m.id=f.egg_other_first),
  'distinct egg Groups retain independent active sources on one farm') from ids f;

create temp table admitted(animal_id uuid,result jsonb);
insert into admitted select animal_meat,economics_v2.enter_group_meat_initial(
  farm_a,gen_random_uuid(),animal_meat,current_date-4,group_meat,meat,'{}') from ids;
insert into admitted select animal_mixed,economics_v2.enter_group_meat_initial(
  farm_a,gen_random_uuid(),animal_mixed,current_date-4,group_mixed,meat,'{}') from ids;
select set_config('request.jwt.claim.sub',owner_b::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_b,'role','authenticated')::text,true) from ids;
insert into admitted select animal_foreign,economics_v2.enter_group_meat_initial(
  farm_b,gen_random_uuid(),animal_foreign,current_date-4,group_foreign,meat_b,'{}') from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
create temp table targets as select f.*,
  (select (a.result->>'destination_period_id')::uuid from admitted a where a.animal_id=f.animal_meat) period_meat,
  (select (a.result->>'destination_period_id')::uuid from admitted a where a.animal_id=f.animal_mixed) period_mixed,
  (select (a.result->>'destination_period_id')::uuid from admitted a where a.animal_id=f.animal_foreign) period_foreign
from ids f;
-- Synthetic ADMIN foundation baseline: real constraints permit different open purposes.
-- Its sequence issuance belongs to setup, never to the observed source-header INSERTs.
insert into economics_v2.group_occupancy_periods(granja_id,group_id,purpose_id,starts_on)
select farm_a,group_mixed,posture,current_date-4 from ids;
create temp table source_contexts as
select m.id,economics_v2.validate_group_feed_source(t.farm_a,t.period_meat,m.id,m.updated_at) value
from public.mezcla m cross join targets t where m.id in (t.source_ended,t.source_first);
select economics_v2.capture_group_feed_allocation(t.farm_a,gen_random_uuid(),t.period_meat,c.id,
  (c.value->>'source_updated_at')::timestamptz,c.value->>'source_digest')
from source_contexts c cross join targets t;
set constraints all immediate;
set constraints all deferred;
select pg_temp.check_true(
  (select count(*)=1 from economics_v2.group_occupancy_periods p
   where p.granja_id=t.farm_a and p.group_id=t.group_meat and p.end_position is null and p.closed_on is null)
  and exists(select 1 from economics_v2.group_occupancy_periods p
    join public.cat_proposito_animal c on c.id=p.purpose_id and c.granja_id=p.granja_id
    where p.id=t.period_meat and c.codigo_calculo='carne' and p.starts_on<=current_date-1)
  and (select count(*)=2 and sum(a.quantity_kg)=3 and sum(a.total_cost)=25
       from economics_v2.group_period_feed_allocations a where a.period_id=t.period_meat),
  'trusted unique meat period and real open/ended source allocations established') from targets t;

-- FIRST post-admission source creation: actual table INSERT; no handler/helper can hide RED.
do $first_meat_header$
declare t record; v_first jsonb; v_before jsonb;
begin
  select * into t from pg_temp.targets;
  select to_jsonb(m) into v_first from public.mezcla m where m.id=t.source_first;
  v_before := pg_temp.boundary_state(array[t.source_second]);
  insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
  values(t.source_second,t.farm_a,t.group_meat,current_date-1,t.owner_a);
  perform pg_temp.check_true(
    (select to_jsonb(m)=v_first from public.mezcla m where m.id=t.source_first),
    'meat sibling source header unchanged');
  perform pg_temp.check_true(
    (select count(*)=2 from public.mezcla m where m.grupo_id=t.group_meat and m.fecha_termino is null),
    'two active meat headers coexist without needing a new allocation');
  perform pg_temp.check_true(
    (select m.granja_id=t.farm_a and m.grupo_id=t.group_meat and m.fecha_inicio=current_date-1
     and m.fecha_termino is null and m.created_by=t.owner_a from public.mezcla m where m.id=t.source_second),
    'new intended header retains its authorized farm, Group, start and open state');
  perform pg_temp.check_true(pg_temp.boundary_state(array[t.source_second])=v_before,
    'second header preserves all other sources, Cycle, occupancy, basis, facts and sequence');
end;
$first_meat_header$;

do $remaining_boundary$
declare t record; v_before jsonb; v_state text; v_version timestamptz;
begin
  select * into t from pg_temp.targets;
  v_before := pg_temp.boundary_state(array[t.header_ended,t.source_third]);
  -- A valid ended header is not an index bypass: the two prior active headers already coexist.
  insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,fecha_termino,created_by)
  values(t.header_ended,t.farm_a,t.group_meat,current_date-1,current_date,t.owner_a);
  insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
  values(t.source_third,t.farm_a,t.group_meat,current_date,t.owner_a);
  perform pg_temp.check_true(pg_temp.boundary_state(array[t.header_ended,t.source_third])=v_before,
    'ended and third header preserve existing source dates, versions, components, allocations and all other state');
  perform pg_temp.check_true(
    (select count(*)=3 from public.mezcla m where m.grupo_id=t.group_meat and m.fecha_termino is null)
    and (select m.fecha_termino=current_date from public.mezcla m where m.id=t.header_ended),
    'third active meat header coexists; ended state does not gate subsequent creation');

  -- Actual existing farm/Group refusal, not an invented cardinality-specific typed contract.
  v_before := pg_temp.boundary_state();
  begin
    insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
    values(t.foreign_bad,t.farm_a,t.group_foreign,current_date,t.owner_a);
  exception when foreign_key_violation then
    get stacked diagnostics v_state=returned_sqlstate;
  end;
  perform pg_temp.check_true(v_state='23503','foreign Group cannot manufacture meat exemption');
  perform pg_temp.check_true(pg_temp.boundary_state()=v_before,'foreign header refusal changes no state');

  select m.updated_at into v_version from public.mezcla m where m.id=t.source_first;
  v_state := null;
  begin
    perform economics_v2.validate_group_feed_source(t.farm_a,t.period_foreign,t.source_first,v_version);
  exception when insufficient_privilege then
    get stacked diagnostics v_state=returned_sqlstate;
  end;
  perform pg_temp.check_true(v_state='42501','foreign period cannot authorize the retained source');
  v_state := null;
  begin
    perform economics_v2.validate_group_feed_source(t.farm_a,t.period_mixed,t.source_first,v_version);
  exception when insufficient_privilege then
    get stacked diagnostics v_state=returned_sqlstate;
  end;
  perform pg_temp.check_true(v_state='42501','another same-farm Group period cannot authorize the source');
  perform pg_temp.check_true(pg_temp.boundary_state()=v_before,'source ownership refusals are read-only');

  -- Malicious caller hints carry a real period UUID but are not trusted Group classification.
  perform set_config('request.jwt.claims',jsonb_build_object('sub',t.owner_a,'role','authenticated',
    'purpose','carne','period_id',t.period_meat,'allow_multiple_mixtures',true)::text,true);
  perform set_config('group_feed.purpose','carne',true);
  perform set_config('group_feed.period_id',t.period_foreign::text,true);
  v_before := pg_temp.boundary_state(array[t.unknown_first,t.unknown_next]);
  insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
  values(t.unknown_next,t.farm_a,t.group_unknown,current_date,t.owner_a);
  perform pg_temp.check_true(
    not exists(select 1 from economics_v2.group_occupancy_periods p where p.group_id=t.group_unknown)
    and (select m.fecha_termino=current_date from public.mezcla m where m.id=t.unknown_first)
    and (select count(*)=1 from public.mezcla m where m.grupo_id=t.group_unknown and m.fecha_termino is null),
    'unclassified Group retains legacy singleton despite spoofed JWT/session hints');
  perform pg_temp.check_true(pg_temp.boundary_state(array[t.unknown_first,t.unknown_next])=v_before,
    'unclassified fallback changes only its intended legacy headers');

  v_before := pg_temp.boundary_state(array[t.mixed_first,t.mixed_next]);
  insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
  values(t.mixed_next,t.farm_a,t.group_mixed,current_date,t.owner_a);
  perform pg_temp.check_true(
    (select count(*)=2 from economics_v2.group_occupancy_periods p
     where p.granja_id=t.farm_a and p.group_id=t.group_mixed and p.closed_on is null and p.end_position is null)
    and (select m.fecha_termino=current_date from public.mezcla m where m.id=t.mixed_first)
    and (select count(*)=1 from public.mezcla m where m.grupo_id=t.group_mixed and m.fecha_termino is null),
    'meat plus posture open periods are ambiguous: count ALL purposes and retain singleton');
  perform pg_temp.check_true(pg_temp.boundary_state(array[t.mixed_first,t.mixed_next])=v_before,
    'ambiguous fallback changes only its intended legacy headers');
end;
$remaining_boundary$;

set constraints all immediate;
select jsonb_build_object(
  'result','group_economics_forward_feed_purpose_cardinality_pass',
  'assertion_count',(select count(*) from assertions),
  'fixture_ids',(select to_jsonb(t) from targets t),
  'locking_evidence','sequential_only',
  'independent_review','pending',
  'real_closure_proven',false,
  'production_gateway_integrated',false,
  'canonical_group_food_api_integrated',false,
  'private_source_create_integrated',false,
  'purpose_cardinality_boundary_test',true
) evidence;

rollback;
