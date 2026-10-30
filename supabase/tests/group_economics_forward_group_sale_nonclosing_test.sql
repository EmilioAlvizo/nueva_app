begin;

-- HUMAN isolated Sandbox only: run the FULL file, stop at the first error, ROLLBACK.
-- Authoring only, not compiled/executed evidence. First RED: uncaught 42883 at $owner$.
-- This creates no producer, migration, public wrapper or business-call proxy.
-- HARD unit cap1100: fixture <=600, future COMPLETE private producer <=500.
-- Other caps remain unchanged. Stop rather than omit essential coverage/code-golf.
-- Required private9, NO defaults/overloads: record_group_meat_sale_nonclosing(
-- p_granja_id uuid,p_operation_id uuid,p_period_id uuid,p_animal_ids uuid[],
-- p_sold_on date,p_saleable_kg numeric,p_total_amount numeric,p_razon_baja_id uuid,
-- p_notes text) RETURNS jsonb. VOLATILE INVOKER, postgres, empty search_path.
-- Revoke PUBLIC/anon/authenticated/service_role EXECUTE; no public activation.
-- Real current owner/editor JWT + enabled flag, including replay, even SQL postgres.
-- Validate one-dimensional, nonnull, unique IDs (>=2), THEN sort the selected set.
-- Kind=group and quantity=count are server-derived; notes are opaque nullable text.
-- Finite date <=today, >=source/events; finite kg>0, finite amount>=0; active income
-- reason belongs to farm OR global. No client actor, price allocation or per-head sale.
-- Fresh: farm advisory -> COMPLETE ordered scope for ALL selected -> existing ACTIVE
-- validator for EACH -> same input period/Group/type/purpose -> selected<active count.
-- All refusal checks precede nextval/reservation/DML. Old single-source count>1 alone
-- is insufficient. No bypass, disabled trigger, fake survivor or ordinary-exit reuse.
-- One position/ledger, one baja BEFORE one sale, one binding; sorted per-animal loop:
-- deactivate+baja link, end actual membership, exit with common sale/position, dispose
-- basis/version+1. No negative acquisition entries. Receipt completed LAST after
-- readback/FOUND checks and reflected live metrics. Failure propagates atomically.
-- Exact19 receipt is built independently in assert_batch below; distinct batch version
-- group-meat-sale-batch.v1, not the singular transition contract. Each disposition is
-- exact6: animal_id,membership_id,exit_event_id,basis_before,basis_after,state_version.
-- Event.reason = canonical JSON text of exact5 server manifest: provenance_version=
-- group-sale-disposition.v1,sale_id,baja_id,period_id,animal_ids(sorted). Not authority.
-- Request hash = canonical exact6 envelope below -> UTF8 SHA256 lowercase hex.
-- Source digest = canonical exact5 object: digest_version=group-meat-sale-source.v1,
-- sale=ENTIRE stored sale, baja=ENTIRE stored baja, binding=ENTIRE stored binding minus
-- source_digest, dispositions=sorted [{animal_id,membership:ENTIRE row,event:ENTIRE row}].
-- All hashed timestamptz fields are typed created_at in sale/baja/binding/event;
-- membership has none; none of these five tables has updated_at. Replace ONLY those
-- four values with to_char(ts AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"').
-- This preserves instants/microseconds and every other field; source.v1 includes this
-- UTC rule. The TEMP oracle below is observation only, not a required production helper.
-- Those are stored identities/lineage, NOT request-only evidence or split revenue.
-- Replay authenticates and checks hash/version/typed receipt BEFORE mutable ACTIVE/
-- OPEN checks, verifies durable sale/baja/binding/member/event integrity and digest.
-- Later closure/movement must not rewrite the original receipt; NOT simulated here.
-- Typed errors exact4: contract_version=group-economics.forward.v3,code,field,entity_id.
-- New scalar/vector errors 22023/invalid_request (entity null for IDs, period for
-- sold_on/kg/amount; reason ID for inactive/non-income). Missing reason 42501/forbidden.
-- Batch would close: 23514/period_close_unfinalized_facts/period_id/input period.
-- Batch pairing: 23514/invariant_violation/period_id/input period. Source helper's
-- existing typed errors remain unchanged. Conflict22023/operation_payload_conflict;
-- incomplete/tampered replay23514/invariant_violation, both operation_id/op UUID.
-- Only this private nonclosing GROUP slice is exercised; qualified storage/source/
-- ordinary-closing suites are not duplicated. No concurrency/HTTP/production proof.

create temp table ids as select gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor,gen_random_uuid() viewer,gen_random_uuid() outsider,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,
  gen_random_uuid() type_b,gen_random_uuid() meat,gen_random_uuid() group_a,
  gen_random_uuid() other_group,gen_random_uuid() foreign_group,gen_random_uuid() foreign_animal,
  gen_random_uuid() reason,gen_random_uuid() other_reason,gen_random_uuid() category,
  gen_random_uuid() animal_a,gen_random_uuid() animal_b,gen_random_uuid() survivor,
  gen_random_uuid() owner_op,gen_random_uuid() editor_op,gen_random_uuid() mixture,
  gen_random_uuid() missing_id,null::uuid period_id;
create temp table assertions(label text not null);
create temp table receipts(label text,persisted boolean,result jsonb);
create temp table gaps(stage text,before_position bigint,after_position bigint);
create function pg_temp.check_true(p_ok boolean,p_label text) returns void
language plpgsql security invoker set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
create function pg_temp.jwt(p_actor uuid) returns void
language plpgsql security invoker set search_path='' as $$
begin
  perform set_config('request.jwt.claim.sub',coalesce(p_actor::text,''),true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',p_actor,'role','authenticated')::text,true);
end;
$$;
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"group-sale-nonclosing"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor,viewer,outsider]) u;
select pg_temp.check_true((select count(*)=5 from public.perfiles p join ids i
  on p.id=any(array[i.owner_a,i.owner_b,i.editor,i.viewer,i.outsider])),
  'installed auth trigger supplied all real creator profiles');
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Batch sale A '||farm_a,owner_a from ids
union all select farm_b,owner_b,'Batch sale B '||farm_b,owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor,'editor'::public.rol_miembro from ids
union all select farm_a,viewer,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Batch meat',owner_a from ids union all select type_b,farm_b,'Foreign',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat,farm_a,'Batch meat','carne',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'Batch control '||g,owner_a from ids cross join lateral unnest(array[group_a,other_group]) g
union all select foreign_group,farm_b,type_b,'Foreign control',owner_b from ids;
insert into public.cat_razon_baja(id,granja_id,nombre,genera_ingreso,activo,created_by)
select r,farm_a,'Batch reason '||r,true,true,owner_a from ids cross join lateral unnest(array[reason,other_reason]) r;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select category,farm_a,'Batch ingredient',true,owner_a from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,created_by)
select a,farm_a,type_a,group_a,meat,current_date-4,100,owner_a from ids
cross join lateral unnest(array[animal_a,animal_b,survivor]) a
union all select foreign_animal,farm_b,type_b,foreign_group,null::uuid,current_date-4,1,owner_b from ids;
select pg_temp.jwt(owner_a) from ids;
do $admit$
declare v_f record; v_a uuid; v_r jsonb;
begin
  select * into v_f from pg_temp.ids;
  foreach v_a in array array[v_f.animal_a,v_f.animal_b,v_f.survivor] loop
    v_r:=economics_v2.enter_group_meat_initial(v_f.farm_a,gen_random_uuid(),v_a,current_date-4,v_f.group_a,v_f.meat,'{}');
    update pg_temp.ids set period_id=(v_r->>'destination_period_id')::uuid;
  end loop;
end;
$admit$;
select public.crear_mezcla_grupo_v1(f.farm_a,gen_random_uuid(),f.period_id,f.mixture,current_date-1,f.group_a,
  jsonb_build_array(jsonb_build_object('categoria_id',f.category,'cantidad_kg',3,'costo_total',100))) from ids f;
select public.create_group_finance_expense_v1(f.farm_a,gen_random_uuid(),f.period_id,current_date-1,50,'care','Batch fixture') from ids f;
set constraints all immediate;
set constraints all deferred;

-- Full business snapshots include foreign/legacy rows and all internal fences.
-- Only read-only observation helpers are DEFINER; business calls remain INVOKER.
create temp table watched as select n.nspname schema_name,c.relname table_name,c.relkind
from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind in ('r','p','S')
and (n.nspname in ('public','economics_v2','group_feed_integrity') or (n.nspname='auth' and c.relname='users'));
create temp sequence attempted_dml;
create function pg_temp.state(p_sequences boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_t record; v_rows jsonb; v_result jsonb:='{}';
begin
  for v_t in select * from pg_temp.watched where (relkind='S')=p_sequences order by schema_name,table_name loop
    if p_sequences then
      execute format('select jsonb_build_object(''last_value'',s.last_value,''log_cnt'',s.log_cnt,''is_called'',s.is_called) from %I.%I s',
        v_t.schema_name,v_t.table_name) into v_rows;
    else
      execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb) from %I.%I r',
        v_t.schema_name,v_t.table_name) into v_rows;
    end if;
    v_result:=v_result||jsonb_build_object(v_t.schema_name||'.'||v_t.table_name,v_rows);
  end loop;
  return v_result;
end;
$$;
create function pg_temp.metadata() returns jsonb
language sql security definer set search_path='' as $$
  select jsonb_agg(x order by x::text) from (
    select jsonb_build_array('relation',c.oid,c.relowner,c.relacl,c.relrowsecurity,c.relforcerowsecurity) x
    from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','economics_v2','group_feed_integrity','auth')
    union all select jsonb_build_array('function',p.oid,p.proowner,p.proacl,pg_get_functiondef(p.oid))
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.prokind='f'
      and p.proname<>'record_group_meat_sale_nonclosing' and n.nspname in ('public','economics_v2','group_feed_integrity')
  ) q;
$$;
create function pg_temp.observe() returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('batch_sale.observe',true)='on' then
    perform nextval('pg_temp.attempted_dml');
    raise exception using errcode='ZX001',message='Batch replay/refusal attempted DML';
  end if;
  return null;
end;
$$;
do $observers$
declare v_t record;
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
  for v_t in select * from pg_temp.watched where relkind<>'S' loop
    execute format('create trigger batch_sale_observer before insert or update or delete or truncate on %I.%I
      for each statement execute function pg_temp.observe()',v_t.schema_name,v_t.table_name);
  end loop;
end;
$observers$;
create temp table baseline as select pg_temp.state() rows,pg_temp.metadata() metadata;
create function pg_temp.call_sql(p_op uuid,p_patch jsonb default '{}') returns text
language sql security invoker set search_path='' as $$
  select format('select economics_v2.record_group_meat_sale_nonclosing(%L::uuid,%L::uuid,%L::uuid,%L::uuid[],%L::date,%L::numeric,%L::numeric,%L::uuid,%L::text)',
    b->>'farm',p_op,b->>'period',b->>'animals',b->>'day',b->>'kg',b->>'amount',b->>'reason',b->>'notes')
  from (select jsonb_build_object('farm',i.farm_a,'period',i.period_id,'animals',array[i.animal_a,i.animal_b]::text,
    'day',current_date,'kg',150,'amount',900,'reason',i.reason,'notes',null)||p_patch b from pg_temp.ids i) q;
$$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,
  p_field text default null,p_entity uuid default null) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare v_b jsonb; v_q jsonb; v_c record; v_r jsonb; v_st text; v_detail text;
begin
  v_b:=pg_temp.state(); v_q:=pg_temp.state(true);
  select * into v_c from pg_temp.attempted_dml;
  perform set_config('batch_sale.observe','on',true);
  begin execute p_sql into v_r;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics v_st=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform set_config('batch_sale.observe','off',true);
  perform pg_temp.check_true(pg_temp.state()=v_b and pg_temp.state(true)=v_q,'replay/refusal preserves ALL business rows and sequences');
  perform pg_temp.check_true((select s.last_value=v_c.last_value and s.log_cnt=v_c.log_cnt and s.is_called=v_c.is_called
    from pg_temp.attempted_dml s),'no attempted, zero-row or swallowed DML');
  if p_state is null then
    perform pg_temp.check_true(v_r is not null,'nonempty replay result');
  else
    perform pg_temp.check_true(v_st=p_state,'expected SQLSTATE '||p_state||': '||p_sql);
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb=jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field,'entity_id',p_entity),'exact4 private typed error');
    end if;
  end if;
  return v_r;
end;
$$;
grant select on ids to authenticated,anon;
grant insert on assertions to authenticated,anon;
grant select,usage on sequence attempted_dml to authenticated,anon;
revoke all on function pg_temp.state(boolean),pg_temp.metadata() from public;
grant execute on function pg_temp.state(boolean) to authenticated,anon;

-- Restore ONLY the explicitly verified selected originals and generated identities.
-- Every other full row (including source feed/expense/period/survivor/fence) must match.
create function pg_temp.normalized(p_r jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare v_live jsonb:=pg_temp.state(); v_base jsonb; v_t text; v_rows jsonb; v_ids jsonb:=p_r->'animal_ids';
begin
  select b.rows into v_base from pg_temp.baseline b;
  foreach v_t in array array['public.animales','economics_v2.group_occupancy_memberships','economics_v2.group_animal_acquisition_basis'] loop
    select jsonb_agg(coalesce((select o from jsonb_array_elements(v_base->v_t) o
      where (case when v_t='public.animales' then o->>'id' else o->>'animal_id' end)
        =(case when v_t='public.animales' then x->>'id' else x->>'animal_id' end)
      and v_ids ? (case when v_t='public.animales' then x->>'id' else x->>'animal_id' end)),x))
      into v_rows from jsonb_array_elements(v_live->v_t) x;
    select jsonb_agg(x order by x::text) into v_rows from jsonb_array_elements(v_rows) x;
    v_live:=jsonb_set(v_live,array[v_t],v_rows);
  end loop;
  for v_t in select unnest(array['public.venta_animal','public.bajas_animales','economics_v2.group_period_sale_bindings',
    'economics_v2.group_occupancy_events','economics_v2.group_occupancy_operations']) loop
    select coalesce(jsonb_agg(x order by x::text),'[]'::jsonb) into v_rows from jsonb_array_elements(v_live->v_t) x
    where not case v_t when 'public.venta_animal' then x->>'id'=p_r->>'sale_id'
      when 'public.bajas_animales' then x->>'id'=p_r->>'baja_id'
      when 'economics_v2.group_period_sale_bindings' then x->>'sale_id'=p_r->>'sale_id'
      when 'economics_v2.group_occupancy_events' then exists(select 1 from jsonb_array_elements(p_r->'dispositions') d where d->>'exit_event_id'=x->>'id')
      else x->>'operation_id'=p_r->>'operation_id' and x->>'granja_id'=(select farm_a::text from pg_temp.ids) end;
    v_live:=jsonb_set(v_live,array[v_t],v_rows);
  end loop;
  return v_live;
end;
$$;
create function pg_temp.source_digest(p_sale uuid) returns text
language sql stable security invoker set search_path='' as $$
  select encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'digest_version','group-meat-sale-source.v1',
    'sale',to_jsonb(s)||jsonb_build_object('created_at',to_char(s.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')),
    'baja',to_jsonb(b)||jsonb_build_object('created_at',to_char(b.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')),
    'binding',(to_jsonb(x)-'source_digest')||jsonb_build_object('created_at',to_char(x.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')),
    'dispositions',(select jsonb_agg(jsonb_build_object('animal_id',e.animal_id,'membership',to_jsonb(m),
      'event',to_jsonb(e)||jsonb_build_object('created_at',to_char(e.created_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')))
      order by e.animal_id) from economics_v2.group_occupancy_events e
      join economics_v2.group_occupancy_memberships m on m.id=e.membership_id where e.sale_id=s.id)
    ))::text,'UTF8')),'hex')
  from public.venta_animal s join public.bajas_animales b on b.id=s.baja_id
  join economics_v2.group_period_sale_bindings x on x.sale_id=s.id where s.id=p_sale;
$$;
create function pg_temp.assert_batch(p_r jsonb,p_actor uuid,p_op uuid) returns void
language plpgsql security invoker set search_path='' as $$
declare v_f record; v_s public.venta_animal%rowtype; v_b public.bajas_animales%rowtype;
  v_binding economics_v2.group_period_sale_bindings%rowtype; v_ids uuid[]; v_pos bigint;
  v_dispositions jsonb; v_manifest jsonb; v_digest text; v_hash text; v_expected jsonb; v_original jsonb;
begin
  select * into v_f from pg_temp.ids;
  select b.rows into v_original from pg_temp.baseline b;
  select array_agg(a order by a) into v_ids from unnest(array[v_f.animal_a,v_f.animal_b]) a;
  select * into strict v_s from public.venta_animal where id=(p_r->>'sale_id')::uuid;
  select * into strict v_b from public.bajas_animales where id=v_s.baja_id;
  select * into strict v_binding from economics_v2.group_period_sale_bindings where sale_id=v_s.id;
  v_pos:=(p_r->>'event_position')::bigint;
  v_manifest:=jsonb_build_object('provenance_version','group-sale-disposition.v1','sale_id',v_s.id,
    'baja_id',v_b.id,'period_id',v_f.period_id,'animal_ids',v_ids);
  perform pg_temp.check_true(v_s.granja_id=v_f.farm_a and v_s.grupo_id=v_f.group_a and v_s.tipo_animal_id=v_f.type_a
    and v_s.animal_id is null and v_s.record_kind='group' and v_s.quantity=2 and v_s.peso=150
    and v_s.total_amount=900 and v_s.precio is null and v_s.created_by=p_actor and v_s.fecha_venta=current_date
    and isfinite(v_s.created_at),'one real Group sale, derived two, total kg150/amount900, no invented unit price');
  perform pg_temp.check_true(v_b.granja_id=v_f.farm_a and v_b.tipo_animal_id=v_f.type_a and v_b.razon_baja_id=v_f.reason
    and v_b.fecha_baja=current_date and v_b.cantidad_animales=2 and v_b.importe_total=900
    and v_b.notas is null and v_b.created_by=p_actor and isfinite(v_b.created_at),
    'one shared real baja: farm/type/reason/date/count/amount/opaque notes/actor (schema has no grupo_id)');
  perform pg_temp.check_true(v_binding.granja_id=v_f.farm_a and v_binding.period_id=v_f.period_id
    and v_binding.record_kind='group' and v_binding.quantity=2 and v_binding.saleable_kg=150
    and v_binding.total_amount=900 and isfinite(v_binding.created_at),'actual unique binding, no duplicated baja revenue');
  perform pg_temp.check_true((select count(*)=2 and bool_and(e.animal_id=any(v_ids) and e.granja_id=v_f.farm_a
    and e.period_id=v_f.period_id and e.sale_id=v_s.id and e.action='exit' and e.event_position=v_pos
    and e.effective_on=current_date and e.basis_transfer_id is null and isfinite(e.created_at)
    and e.reason=economics_v2.canonical_group_request(v_manifest)::text and m.end_position=v_pos
    and m.animal_id=e.animal_id and m.period_id=e.period_id and m.granja_id=e.granja_id and v_pos>m.start_position)
    from economics_v2.group_occupancy_events e join economics_v2.group_occupancy_memberships m on m.id=e.membership_id
    where e.operation_id=p_op),'exact two real selected exit events at ONE shared position with canonical server manifest');
  perform pg_temp.check_true((select count(*)=2 and bool_and(to_jsonb(a)-'updated_at'=
    (o||jsonb_build_object('activo',false,'baja_id',v_b.id))-'updated_at')
    from public.animales a cross join lateral (select x o from jsonb_array_elements(v_original->'public.animales') x where x->>'id'=a.id::text) q
    where a.id=any(v_ids)),'both selected animals receive only deactivation/shared baja');
  perform pg_temp.check_true((select count(*)=2 and bool_and(to_jsonb(m)=o||jsonb_build_object(
    'end_position',v_pos,'position_span',int8range(m.start_position,v_pos,'[)')))
    from economics_v2.group_occupancy_memberships m cross join lateral (select x o from jsonb_array_elements(
      v_original->'economics_v2.group_occupancy_memberships') x where x->>'id'=m.id::text) q
    where m.animal_id=any(v_ids)),'only the two actual selected membership ends change');
  perform pg_temp.check_true((select count(*)=2 and bool_and(to_jsonb(b)=o||jsonb_build_object('remaining_basis',0,
    'status','disposed','current_account_kind','disposed','current_period_id',null,'disposed_event_id',e.id,'version',1))
    from economics_v2.group_animal_acquisition_basis b join economics_v2.group_occupancy_events e
      on e.animal_id=b.animal_id and e.operation_id=p_op
    cross join lateral (select x o from jsonb_array_elements(v_original->'economics_v2.group_animal_acquisition_basis') x
      where x->>'animal_id'=b.animal_id::text) q),'two captured100 bases become0/version1; survivor and entries stay unchanged');
  select jsonb_agg(jsonb_build_object('animal_id',e.animal_id,'membership_id',m.id,'exit_event_id',e.id,
    'basis_before',100,'basis_after',0,'state_version',1) order by e.animal_id)
    into v_dispositions from economics_v2.group_occupancy_events e
    join economics_v2.group_occupancy_memberships m on m.id=e.membership_id where e.operation_id=p_op;
  v_digest:=pg_temp.source_digest(v_s.id);
  v_expected:=jsonb_build_object('contract_version','group-economics.forward.v3','receipt_version','group-meat-sale-batch.v1',
    'operation_id',p_op,'sale_id',v_s.id,'baja_id',v_b.id,'period_id',v_f.period_id,'group_id',v_f.group_a,
    'animal_ids',v_ids,'dispositions',v_dispositions,'sold_on',current_date,'event_position',v_pos,'record_kind','group',
    'quantity',2,'saleable_kg',150,'total_amount',900,'source_digest',v_digest,'source_status','open','snapshot_id',null,'replayed',false);
  perform pg_temp.check_true(p_r=v_expected and v_binding.source_digest=v_digest,'exact19 typed batch receipt and independent stored-row SHA256 digest');
  v_hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-meat-sale-nonclosing.v1',
    'granja_id',v_f.farm_a,'actor_id',p_actor,'operation_id',p_op,'request',jsonb_build_object('period_id',v_f.period_id,
      'animal_ids',v_ids,'sold_on',current_date,'saleable_kg',150,'total_amount',900,'razon_baja_id',v_f.reason,'notes',null)))::text,'UTF8')),'hex');
  perform pg_temp.check_true((select result=v_expected and payload_hash=v_hash and event_position=v_pos
    from economics_v2.group_occupancy_operations where granja_id=v_f.farm_a and operation_id=p_op),
    'actual completed ledger binds original actor/domain/input period/sorted IDs/all opaque request fields');
  perform pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(v_f.farm_a,v_f.period_id)=
    '{"animal_count":3,"active_animal_count":1,"exited_animal_count":2,"sold_animal_count":2,"feed_source_count":1,"feed_kg_total":3,"feed_cost":100,"acquisition_cost":300,"direct_expense_total":50,"sale_count":1,"saleable_kg":150,"animal_sale_revenue":900,"total_cost":450,"profit":450,"realized_price_per_kg":6,"break_even_kg":75,"balance_per_animal":150}'::jsonb,
    'independent literal17: cost450/revenue900/profit450, NEVER1800 from fiscal baja');
  perform pg_temp.check_true(pg_temp.normalized(p_r)=v_original,
    'ONLY verified sale/baja/binding/two animal/member/basis/events/one ledger deltas; OPEN period, survivor100, feed unfinalized, no snapshot');
end;
$$;
create function pg_temp.position_gap(p_before jsonb,p_stage text) returns void
language plpgsql security invoker set search_path='' as $$
declare v_after jsonb:=pg_temp.state(true); v_key text:='economics_v2.group_economics_event_position_seq'; v_n bigint;
begin
  v_n:=(p_before->v_key->>'last_value')::bigint;
  perform pg_temp.check_true(v_after-v_key=p_before-v_key and (v_after->v_key->>'last_value')::bigint=v_n+1,
    'exact one issued position retained, all other sequences unchanged: '||p_stage);
  insert into pg_temp.gaps values(p_stage,v_n,v_n+1);
end;
$$;

do $owner$
declare v_f record; v_r jsonb; v_q jsonb; v_verified boolean:=false; v_st text; v_msg text;
  v_timezone text:=current_setting('TimeZone'); v_alternate text; v_stamp text;
begin
  select * into v_f from pg_temp.ids; v_q:=pg_temp.state(true);
  perform pg_temp.check_true((select count(*)=3 and bool_and(activo and baja_id is null) from public.animales
    where id=any(array[v_f.animal_a,v_f.animal_b,v_f.survivor]))
    and (select count(*)=3 and bool_and(end_position is null) from economics_v2.group_occupancy_memberships where period_id=v_f.period_id)
    and (select count(*)=3 and bool_and(status='active' and remaining_basis=100 and version=0)
      from economics_v2.group_animal_acquisition_basis where current_period_id=v_f.period_id)
    and (select sum(signed_amount)=300 from economics_v2.group_acquisition_basis_entries where period_id=v_f.period_id)
    and exists(select 1 from economics_v2.group_occupancy_periods where id=v_f.period_id and closed_on is null and end_position is null)
    and (select count(*)=1 and bool_and(finalized_at is null and quantity_kg=3 and total_cost=100)
      from economics_v2.group_period_feed_allocations where period_id=v_f.period_id)
    and (select sum(amount)=50 from economics_v2.group_period_expenses where period_id=v_f.period_id)
    and not exists(select 1 from economics_v2.group_meat_snapshots where period_id=v_f.period_id),
    'real three-ACTIVE source: each captured100, acquisition300/feed100/expense50, OPEN/unfinalized/no snapshot');
  begin
    -- FIRST new-function reference is a genuine named call under SQL postgres/owner JWT.
    v_r:=economics_v2.record_group_meat_sale_nonclosing(p_granja_id=>v_f.farm_a,p_operation_id=>v_f.owner_op,
      p_period_id=>v_f.period_id,p_animal_ids=>array[v_f.animal_a,v_f.animal_b],p_sold_on=>current_date,
      p_saleable_kg=>150::numeric,p_total_amount=>900::numeric,p_razon_baja_id=>v_f.reason,p_notes=>null::text);
    perform pg_temp.assert_batch(v_r,v_f.owner_a,v_f.owner_op);
    perform pg_temp.check_true(pg_temp.checked(pg_temp.call_sql(v_f.owner_op))=v_r||'{"replayed":true}'::jsonb,
      'owner replay verified against STILL STORED real sale and inactive selected animals');
    select to_jsonb(s)->>'created_at' into v_stamp from public.venta_animal s where s.id=(v_r->>'sale_id')::uuid;
    select name into strict v_alternate from pg_timezone_names
      where utc_offset<>make_interval(secs=>extract(timezone from current_timestamp)::double precision)
        and (current_timestamp at time zone name)::date=current_date order by name limit 1;
    perform set_config('TimeZone',v_alternate,true); -- Presentation only; preserve business date, never authority.
    perform pg_temp.check_true((select to_jsonb(s)->>'created_at'<>v_stamp from public.venta_animal s
      where s.id=(v_r->>'sale_id')::uuid) and pg_temp.source_digest((v_r->>'sale_id')::uuid)=v_r->>'source_digest',
      'different raw timestamp rendering, identical independently recomputed UTC-instant digest');
    perform pg_temp.check_true(pg_temp.checked(pg_temp.call_sql(v_f.owner_op,
      jsonb_build_object('day',v_r->>'sold_on')))=v_r||'{"replayed":true}'::jsonb,
      'actual stored owner replay under different TimeZone retains exact receipt and digest without DML');
    perform set_config('TimeZone',v_timezone,true);
    set constraints all immediate;
    set constraints all deferred;
    v_verified:=true;
    raise exception using errcode='ZO731',message='Restore verified owner batch positive';
  exception when sqlstate 'ZO731' then
    get stacked diagnostics v_st=returned_sqlstate,v_msg=message_text;
    if not v_verified or v_msg<>'Restore verified owner batch positive' then raise; end if;
  end;
  perform pg_temp.check_true(v_verified and current_setting('TimeZone')=v_timezone and pg_temp.state()=(select b.rows from pg_temp.baseline b),
    'owner positive was fully verified BEFORE sentinel rollback; original three ACTIVE sources restored transactionally');
  perform pg_temp.position_gap(v_q,'verified_owner_positive_rollback');
  insert into pg_temp.receipts values('owner_rolled_back',false,v_r);
end;
$owner$;

-- Reduced new-boundary matrix; do NOT repeat the qualified 168-line source suite.
do $refusals$
declare v_f record; v_c record; v_sql text; v_b jsonb; v_q jsonb; v_pair uuid[]; v_second uuid;
begin
  select * into v_f from pg_temp.ids;
  select array_agg(a order by a) into v_pair from unnest(array[v_f.animal_a,v_f.animal_b]) a;
  v_second:=v_pair[2]; v_sql:=pg_temp.call_sql(v_f.editor_op);
  for v_c in select patch,field,entity from (values
    ('{"animals":null}'::jsonb,'animal_ids',null::uuid),('{"animals":"{}"}','animal_ids',null::uuid),
    (jsonb_build_object('animals',array[v_f.animal_a]::text),'animal_ids',null::uuid),
    (jsonb_build_object('animals',array[v_f.animal_a,v_f.animal_a]::text),'animal_ids',null::uuid),
    (jsonb_build_object('animals',array[v_f.animal_a,null::uuid]::text),'animal_ids',null::uuid),
    (jsonb_build_object('animals',array[array[v_f.animal_a,v_f.animal_b]]::text),'animal_ids',null::uuid),
    ('{"day":null}','sold_on',v_f.period_id),('{"day":"infinity"}','sold_on',v_f.period_id),
    (jsonb_build_object('day',current_date+1),'sold_on',v_f.period_id),
    ('{"kg":null}','saleable_kg',v_f.period_id),('{"kg":0}','saleable_kg',v_f.period_id),
    ('{"kg":"NaN"}','saleable_kg',v_f.period_id),('{"kg":"Infinity"}','saleable_kg',v_f.period_id),
    ('{"amount":null}','total_amount',v_f.period_id),('{"amount":-1}','total_amount',v_f.period_id),
    ('{"amount":"Infinity"}','total_amount',v_f.period_id),('{"reason":null}','razon_baja_id',null::uuid)
  ) q(patch,field,entity) loop
    perform pg_temp.checked(pg_temp.call_sql(v_f.editor_op,v_c.patch),'22023','invalid_request',v_c.field,v_c.entity);
  end loop;
  perform pg_temp.checked(pg_temp.call_sql(null),'22023','invalid_request','operation_id',null);
  perform pg_temp.checked(pg_temp.call_sql(v_f.editor_op,'{"period":null}'),'22023','invalid_request','period_id',null);
  perform pg_temp.checked(pg_temp.call_sql(v_f.editor_op,jsonb_build_object('day',current_date-5)),
    '22023','invalid_request','effective_on',v_pair[1]); -- Qualified ordered source-lock error, not a new public codec.
  perform pg_temp.checked(pg_temp.call_sql(v_f.editor_op,jsonb_build_object('animals',array[v_f.animal_a,v_f.foreign_animal]::text)),
    '42501','forbidden','animal_id',v_f.foreign_animal);
  perform pg_temp.checked(pg_temp.call_sql(v_f.editor_op,jsonb_build_object('animals',array[v_f.animal_a,v_f.missing_id]::text)),
    '42501','forbidden','animal_id',v_f.missing_id);
  perform pg_temp.checked(pg_temp.call_sql(v_f.editor_op,jsonb_build_object('animals',array[v_f.animal_a,v_f.animal_b,v_f.survivor]::text)),
    '23514','period_close_unfinalized_facts','period_id',v_f.period_id);
  perform pg_temp.checked(pg_temp.call_sql(v_f.editor_op,jsonb_build_object('period',v_f.missing_id)),
    '42501','forbidden','period_id',v_f.missing_id);
  perform pg_temp.checked(pg_temp.call_sql(v_f.editor_op,jsonb_build_object('reason',v_f.missing_id)),
    '42501','forbidden','razon_baja_id',v_f.missing_id);
  for v_c in select * from (values('disabled'),('wrong_group'),('missing_basis'),('inactive_reason'),('nonincome_reason')) q(mode) loop
    v_b:=pg_temp.state(); v_q:=pg_temp.state(true);
    begin
      case v_c.mode
        when 'disabled' then update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=v_f.farm_a;
        when 'wrong_group' then update public.animales set grupo_id=v_f.other_group where id=v_second;
        when 'missing_basis' then
          delete from economics_v2.group_acquisition_basis_entries where animal_id=v_second;
          delete from economics_v2.group_animal_acquisition_basis where animal_id=v_second;
        when 'inactive_reason' then update public.cat_razon_baja set activo=false where id=v_f.reason;
        when 'nonincome_reason' then update public.cat_razon_baja set genera_ingreso=false where id=v_f.reason;
      end case;
      perform pg_temp.checked(v_sql,case when v_c.mode in ('disabled','wrong_group') then '42501'
        when v_c.mode='missing_basis' then '23514' else '22023' end,
        case when v_c.mode in ('disabled','wrong_group') then 'forbidden' when v_c.mode='missing_basis' then 'invariant_violation' else 'invalid_request' end,
        case v_c.mode when 'disabled' then 'granja_id' when 'wrong_group' then 'group_id' when 'missing_basis' then 'animal_id' else 'razon_baja_id' end,
        case v_c.mode when 'disabled' then v_f.farm_a when 'wrong_group' then v_f.other_group when 'missing_basis' then v_second else v_f.reason end);
      raise exception using errcode='ZR731',message='Restore isolated refusal';
    exception when sqlstate 'ZR731' then null;
    end;
    perform pg_temp.check_true(pg_temp.state()=v_b and pg_temp.state(true)=v_q,'all isolated corruption/flag fields restored: '||v_c.mode);
  end loop;
  for v_c in select unnest(array[v_f.viewer,v_f.owner_b,v_f.outsider,null::uuid]) actor loop
    perform pg_temp.jwt(v_c.actor);
    perform pg_temp.checked(v_sql,'42501','forbidden','granja_id',v_f.farm_a);
  end loop;
  perform pg_temp.jwt(v_f.owner_a);
  set local role authenticated;
  perform pg_temp.checked(v_sql,'42501');
  reset role;
  set local role anon;
  perform pg_temp.checked(v_sql,'42501');
  reset role;
end;
$refusals$;

-- Three distinct AFTER-storage faults, never BEFORE promises or swallowed guards.
create function pg_temp.late_fault() returns trigger language plpgsql security invoker set search_path='' as $$
declare v_mode text:=current_setting('batch_sale.fault',true); v_f record; v_sale uuid;
begin
  if v_mode is null or v_mode='off' then return null; end if;
  if (tg_table_name='venta_animal' and v_mode<>'sale')
    or (tg_table_name='group_animal_acquisition_basis' and v_mode<>'basis_partial')
    or (tg_table_name='group_occupancy_operations' and v_mode<>'completion') then return null; end if;
  select * into v_f from pg_temp.ids;
  if tg_table_name='group_occupancy_operations' then
    if new.operation_id<>v_f.editor_op or not(new.result ? 'receipt_version') then return null; end if;
    perform pg_temp.assert_batch(new.result,v_f.editor,v_f.editor_op);
  else
    select id into strict v_sale from public.venta_animal where granja_id=v_f.farm_a and record_kind='group';
    perform pg_temp.check_true(exists(select 1 from public.venta_animal s join public.bajas_animales b on b.id=s.baja_id
      where s.id=v_sale and s.quantity=2 and s.peso=150 and s.total_amount=900 and b.cantidad_animales=2 and b.importe_total=900),
      'fault observes ACTUAL stored sale and its already-stored shared baja');
    if v_mode='basis_partial' then
      perform pg_temp.check_true((select count(*)=1 from economics_v2.group_animal_acquisition_basis
        where animal_id=any(array[v_f.animal_a,v_f.animal_b]) and status='disposed' and remaining_basis=0 and version=1)
        and (select count(*)=1 from public.animales where id=any(array[v_f.animal_a,v_f.animal_b]) and activo and baja_id is null)
        and exists(select 1 from economics_v2.group_occupancy_events e where e.id=new.disposed_event_id
          and e.animal_id=new.animal_id and e.sale_id=v_sale and e.operation_id=v_f.editor_op),
        'first actual selected basis disposed, matching exit stored, OTHER selected animal still ACTIVE');
    end if;
    perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_operations
      where operation_id=v_f.editor_op and result ? 'receipt_version'),'business receipt not completed prematurely');
  end if;
  raise exception using errcode='ZL731',message='Batch sale AFTER storage: '||v_mode;
end;
$$;
create trigger batch_sale_sale_fault after insert on public.venta_animal for each row execute function pg_temp.late_fault();
create trigger batch_sale_basis_fault after update on economics_v2.group_animal_acquisition_basis for each row execute function pg_temp.late_fault();
create trigger batch_sale_completion_fault after insert or update on economics_v2.group_occupancy_operations for each row execute function pg_temp.late_fault();
do $editor$
declare v_f record; v_mode text; v_b jsonb; v_q jsonb; v_r jsonb; v_st text; v_msg text;
begin
  select * into v_f from pg_temp.ids;
  perform pg_temp.jwt(v_f.editor);
  foreach v_mode in array array['sale','basis_partial','completion'] loop
    v_b:=pg_temp.state(); v_q:=pg_temp.state(true); v_st:=null; v_msg:=null;
    perform set_config('batch_sale.fault',v_mode,true);
    begin execute pg_temp.call_sql(v_f.editor_op) into v_r;
    exception when others then get stacked diagnostics v_st=returned_sqlstate,v_msg=message_text;
    end;
    perform set_config('batch_sale.fault','off',true);
    perform pg_temp.check_true(v_st='ZL731' and v_msg='Batch sale AFTER storage: '||v_mode,'reached exact actual AFTER stage: '||v_mode);
    perform pg_temp.check_true(pg_temp.state()=v_b,'WHOLE business rollback including partial selected batch/ledger: '||v_mode);
    perform pg_temp.position_gap(v_q,v_mode);
    set constraints all immediate;
    set constraints all deferred;
  end loop;
  v_q:=pg_temp.state(true);
  execute pg_temp.call_sql(v_f.editor_op) into v_r;
  perform pg_temp.assert_batch(v_r,v_f.editor,v_f.editor_op);
  perform pg_temp.position_gap(v_q,'editor_success');
  insert into pg_temp.receipts values('editor_stored',true,v_r);
end;
$editor$;

do $replay_and_private_contract$
declare v_f record; v_r jsonb; v_c record; v_b jsonb; v_q jsonb; v_proc record; v_entry uuid;
begin
  select * into v_f from pg_temp.ids;
  select result into strict v_r from pg_temp.receipts where persisted;
  perform pg_temp.check_true(pg_temp.checked(pg_temp.call_sql(v_f.editor_op,jsonb_build_object(
    'animals',array[v_f.animal_b,v_f.animal_a]::text,'kg',150.00,'amount',900.00)))=v_r||'{"replayed":true}'::jsonb,
    'sorted-set/numeric-scale historical replay uses original receipt, not now-inactive sources');
  for v_c in select patch from (values('{"notes":""}'::jsonb),('{"notes":" "}'),('{"kg":151}'),('{"amount":901}'),
    (jsonb_build_object('reason',v_f.other_reason)),(jsonb_build_object('period',v_f.missing_id)),
    (jsonb_build_object('animals',array[v_f.animal_a,v_f.survivor]::text))) q(patch) loop
    perform pg_temp.checked(pg_temp.call_sql(v_f.editor_op,v_c.patch),'22023','operation_payload_conflict','operation_id',v_f.editor_op);
  end loop;
  perform pg_temp.jwt(v_f.owner_a);
  perform pg_temp.checked(pg_temp.call_sql(v_f.editor_op),'22023','operation_payload_conflict','operation_id',v_f.editor_op);
  select operation_id into v_entry from economics_v2.group_occupancy_events where animal_id=v_f.survivor and action='enter';
  perform pg_temp.checked(pg_temp.call_sql(v_entry),'22023','operation_payload_conflict','operation_id',v_entry);
  for v_c in select unnest(array[v_f.viewer,v_f.owner_b,v_f.outsider,null::uuid]) actor loop
    perform pg_temp.jwt(v_c.actor);
    perform pg_temp.checked(pg_temp.call_sql(v_f.editor_op),'42501','forbidden','granja_id',v_f.farm_a);
  end loop;
  perform pg_temp.jwt(v_f.editor);
  for v_c in select * from (values('disabled'),('digest'),('stored_sale'),('incomplete')) q(mode) loop
    v_b:=pg_temp.state(); v_q:=pg_temp.state(true);
    begin
      case v_c.mode
        when 'disabled' then update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=v_f.farm_a;
        when 'digest' then update economics_v2.group_period_sale_bindings set source_digest=repeat('0',64) where sale_id=(v_r->>'sale_id')::uuid;
        when 'stored_sale' then update public.venta_animal set total_amount=901 where id=(v_r->>'sale_id')::uuid;
        when 'incomplete' then update economics_v2.group_occupancy_operations set result='{}' where operation_id=v_f.editor_op;
      end case;
      perform pg_temp.checked(pg_temp.call_sql(v_f.editor_op),case when v_c.mode='disabled' then '42501' else '23514' end,
        case when v_c.mode='disabled' then 'forbidden' else 'invariant_violation' end,
        case when v_c.mode='disabled' then 'granja_id' else 'operation_id' end,
        case when v_c.mode='disabled' then v_f.farm_a else v_f.editor_op end);
      raise exception using errcode='ZR731',message='Restore replay corruption';
    exception when sqlstate 'ZR731' then null;
    end;
    perform pg_temp.check_true(pg_temp.state()=v_b and pg_temp.state(true)=v_q,'replay probe restored without repairing clocks: '||v_c.mode);
  end loop;
  select * into v_proc from pg_proc where oid='economics_v2.record_group_meat_sale_nonclosing(uuid,uuid,uuid,uuid[],date,numeric,numeric,uuid,text)'::regprocedure;
  perform pg_temp.check_true(v_proc.pronargs=9 and v_proc.pronargdefaults=0 and v_proc.proargmodes is null
    and v_proc.proargnames=array['p_granja_id','p_operation_id','p_period_id','p_animal_ids','p_sold_on','p_saleable_kg','p_total_amount','p_razon_baja_id','p_notes']
    and v_proc.prorettype='jsonb'::regtype and not v_proc.proretset and v_proc.provolatile='v' and not v_proc.prosecdef
    and v_proc.proowner='postgres'::regrole and v_proc.proconfig=array['search_path=""']::text[]
    and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE')
    and not exists(select 1 from unnest(array['anon','authenticated','service_role']) r where has_function_privilege(r,v_proc.oid,'EXECUTE')),
    'exact private9 VOLATILE INVOKER postgres/empty path/no client or PUBLIC execute');
  perform pg_temp.check_true((select count(*)=1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where p.proname='record_group_meat_sale_nonclosing' and n.nspname in ('public','economics_v2')),'no overload or same-name public wrapper');
  perform pg_temp.check_true(pg_temp.metadata()=(select b.metadata from pg_temp.baseline b),
    'existing relation/function ACL, owners, RLS and bodies unchanged; target metadata validated separately AFTER first call');
  perform pg_temp.assert_batch(v_r,v_f.editor,v_f.editor_op);
end;
$replay_and_private_contract$;
set constraints all immediate;
select jsonb_build_object('result','group_economics_forward_group_sale_nonclosing_pass',
  'assertion_count',(select count(*) from assertions),'fixture_ids',(select to_jsonb(i) from ids i),
  'receipts',(select jsonb_agg(to_jsonb(r) order by r.label) from receipts r),
  'position_issuance',(select jsonb_agg(to_jsonb(g) order by g.before_position) from gaps g),
  'private_group_sale_nonclosing_producer_proven',true,'explicit_animal_binding_proven',true,'sale_disposition_integrated',true,
  'proof_scope','private_nonclosing_group_only','real_sale_closure_proven',false,'public_api_activated',false,
  'individual_sale_integrated',false,'http_proven',false,'production_proven',false,
  'exclusive_private_provenance_proven',false,'locking_evidence','sequential_only','independent_review','pending') evidence;
rollback;
