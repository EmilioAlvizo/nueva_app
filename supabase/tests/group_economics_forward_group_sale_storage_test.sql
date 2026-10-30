begin;

-- HUMAN Sandbox only: run this FULL file, stop at the first error, then ROLLBACK.
-- Authoring only. FIRST RED: uncaught 23514 at $first_structural_insert$ below,
-- from either retained kind/shape CHECK; their evaluation order is unspecified.
-- No new function lookup precedes that INSERT. No migration is supplied here.
-- Budget: target fixture 420-450 + future COMPLETE migration 110-150, cap 800.
-- Structural storage only: privileged Group rows are NOT canonical sale evidence.
-- Future kind/shape CHECKs retain BOTH legacy branches exactly, including nullable
-- peso and individual quantity >1. Group alone requires animal NULL, Group present,
-- quantity >=2, finite positive peso, finite nonnegative total_amount, IS TRUE.
-- Preserve defaults/NOT NULL/quantity/amount CHECKs/FKs/indexes/grants/RLS/data.
-- Future BEFORE ROW guard: SECURITY INVOKER, postgres owner, empty search_path;
-- revoke EXECUTE from PUBLIC/anon/authenticated/service_role. Trigger invocation
-- does not require client EXECUTE. Protect INSERT NEW, UPDATE OLD OR NEW, DELETE OLD.
-- Authority: actual current_user rolsuper OR rolbypassrls AND operation table ACL.
-- JWT/GUC/session_user are not authority. This does NOT prove private provenance.
-- Plain 42501: 'Direct Group sale writes are forbidden'; no invented typed API.
-- AFTER ROW observer only: BEFORE STATEMENT would reject the expected SQL attempt.
-- Sequential/exclusive Sandbox traffic only; global snapshots intentionally include
-- every business row and sequence. ROLLBACK does not rewind consumed sequences.
-- Existing independent FKs do NOT prove composite farm/Group/type ownership.

create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() owner_b,gen_random_uuid() editor_a,
  gen_random_uuid() viewer_a,gen_random_uuid() outsider,gen_random_uuid() farm_a,
  gen_random_uuid() farm_b,gen_random_uuid() type_a,gen_random_uuid() type_b,
  gen_random_uuid() group_a,gen_random_uuid() group_b,gen_random_uuid() eggs,
  gen_random_uuid() animal_a,gen_random_uuid() animal_b,gen_random_uuid() reason,
  gen_random_uuid() group_sale,gen_random_uuid() individual_sale,
  gen_random_uuid() batch_sale,gen_random_uuid() candidate_sale,gen_random_uuid() missing_group;
create temp table assertions(label text not null);
create temp table rpc_ids(sale_id uuid,baja_id uuid,animal_ids uuid[]);
create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
create function pg_temp.jwt(p_actor uuid)
returns void language plpgsql security invoker set search_path='' as $$
begin
  perform set_config('request.jwt.claim.sub',p_actor::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',p_actor,'role','authenticated')::text,true);
end;
$$;
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated',jsonb_build_object('fixture','group-sale-storage','tag',farm_a)
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a,outsider]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Sale storage A '||farm_a,owner_a from ids
union all select farm_b,owner_b,'Sale storage B '||farm_b,owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Sale storage A',owner_a from ids
union all select type_b,farm_b,'Sale storage B',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_a,farm_a,type_a,'Sale storage A',owner_a from ids
union all select group_b,farm_b,type_b,'Sale storage B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select eggs,farm_a,'Sale storage eggs','postura',owner_a from ids;
insert into public.cat_razon_baja(id,granja_id,nombre,genera_ingreso,activo,created_by)
select reason,farm_a,'Sale storage reason',true,true,owner_a from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,created_by)
select a,farm_a,type_a,group_a,eggs,current_date-4,7,owner_a from ids
cross join lateral unnest(array[animal_a,animal_b]) a;

-- Snapshot helpers are read-only TEMP definers, never business writers/proxies.
create function pg_temp.business_state(p_ignore_group_sale boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_t record; v_rows jsonb; v_result jsonb:='{}'; v_filter text;
begin
  for v_t in select n.nspname,c.relname,c.relkind from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where (n.nspname in ('public','economics_v2','group_feed_integrity') and c.relkind in ('r','p','S'))
      or (n.nspname='auth' and c.relname='users' and c.relkind='r')
    order by n.nspname,c.relname loop
    if v_t.relkind='S' then
      execute format('select jsonb_build_object(''last_value'',s.last_value,
        ''log_cnt'',s.log_cnt,''is_called'',s.is_called) from %I.%I s',v_t.nspname,v_t.relname) into v_rows;
    else
      v_filter:='';
      if p_ignore_group_sale and v_t.nspname='public' and v_t.relname='venta_animal' then
        v_filter:=' where r.id<>(select i.group_sale from pg_temp.ids i)';
      end if;
      execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
        from %I.%I r%s',v_t.nspname,v_t.relname,v_filter) into v_rows;
    end if;
    v_result:=v_result||jsonb_build_object(v_t.nspname||'.'||v_t.relname,v_rows);
  end loop;
  return v_result;
end;
$$;
create function pg_temp.metadata_state()
returns jsonb language sql security definer set search_path='' as $$
  select coalesce(jsonb_agg(q.item order by q.item::text),'[]'::jsonb) from (
    select jsonb_build_object('table',c.oid,'acl',c.relacl,'rls',c.relrowsecurity,
      'force',c.relforcerowsecurity,'owner',c.relowner) item
    from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','economics_v2','group_feed_integrity','auth')
    union all select jsonb_build_object('function',p.oid,'acl',p.proacl,'owner',p.proowner,
      'definition',pg_catalog.pg_get_functiondef(p.oid))
    from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('public','economics_v2','group_feed_integrity') and p.prokind='f'
    union all select jsonb_build_object('constraint',c.oid,'definition',pg_catalog.pg_get_constraintdef(c.oid),
      'validated',c.convalidated) from pg_catalog.pg_constraint c
    join pg_catalog.pg_namespace n on n.oid=c.connamespace
    where n.nspname in ('public','economics_v2','group_feed_integrity')
    union all select jsonb_build_object('index',i.indexrelid,'definition',pg_catalog.pg_get_indexdef(i.indexrelid))
    from pg_catalog.pg_index i join pg_catalog.pg_class c on c.oid=i.indrelid
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','economics_v2','group_feed_integrity')
    union all select jsonb_build_object('policy',to_jsonb(p)) from pg_catalog.pg_policies p
    where p.schemaname in ('public','economics_v2','group_feed_integrity')
    union all select jsonb_build_object('trigger',t.oid,'definition',pg_catalog.pg_get_triggerdef(t.oid))
    from pg_catalog.pg_trigger t join pg_catalog.pg_class c on c.oid=t.tgrelid
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','economics_v2','group_feed_integrity') and not t.tgisinternal
  ) q;
$$;
create function pg_temp.sale_sql(p_patch jsonb default '{}')
returns text language sql security invoker set search_path='' as $$
  select format('insert into public.venta_animal(id,granja_id,grupo_id,tipo_animal_id,animal_id,
    fecha_venta,peso,created_by,record_kind,quantity,total_amount)
    select r.id,r.granja_id,r.grupo_id,r.tipo_animal_id,r.animal_id,r.fecha_venta,r.peso,
      r.created_by,r.record_kind,r.quantity,r.total_amount
    from jsonb_populate_record(null::public.venta_animal,%L::jsonb) r',
    jsonb_build_object('id',i.candidate_sale,'granja_id',i.farm_a,'grupo_id',i.group_a,
      'tipo_animal_id',i.type_a,'animal_id',null,'fecha_venta',current_date,'peso',3.5,
      'created_by',i.owner_a,'record_kind','group','quantity',2,'total_amount',0)||p_patch)
  from pg_temp.ids i;
$$;
create temp table baseline as select pg_temp.business_state(true) state;
do $first_structural_insert$
declare v_f record; v_id uuid;
begin
  select * into v_f from pg_temp.ids;
  -- FIRST expected RED is this real, uncaught INSERT, not a metadata assertion.
  insert into public.venta_animal(id,granja_id,grupo_id,tipo_animal_id,animal_id,
    fecha_venta,peso,created_by,record_kind,quantity,total_amount)
  values(v_f.group_sale,v_f.farm_a,v_f.group_a,v_f.type_a,null,
    current_date,3.5,v_f.owner_a,'group',2,0) returning id into v_id;
  perform pg_temp.check_true(v_id=v_f.group_sale,'privileged structural INSERT returns real UUID');
  perform pg_temp.check_true((select count(*)=1 and min(quantity)=2 and min(peso)=3.5
    and min(total_amount)=0 from public.venta_animal where id=v_id),
    'one Group storage row, quantity two, total weight 3.5, zero amount');
  perform pg_temp.check_true(pg_temp.business_state(true)=(select b.state from pg_temp.baseline b),
    'structural INSERT creates no baja, binding, disposition, ledger, basis or snapshot');
end;
$first_structural_insert$;

create sequence pg_temp.group_dml_attempts;
create function pg_temp.observe_group_dml()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if current_setting('sale_storage_observer.armed',true)='on'
    and ((tg_op<>'DELETE' and new.record_kind='group') or (tg_op<>'INSERT' and old.record_kind='group')) then
    perform nextval('pg_temp.group_dml_attempts'::regclass);
    raise exception using errcode='P0001',message='Unauthorized Group sale reached AFTER ROW';
  end if;
  return null;
end;
$$;
create trigger sale_storage_after_observer after insert or update or delete on public.venta_animal
for each row execute function pg_temp.observe_group_dml();
create function pg_temp.counter_state()
returns jsonb language sql security definer set search_path='' as $$
  select jsonb_build_object('last_value',s.last_value,'log_cnt',s.log_cnt,'is_called',s.is_called)
  from pg_temp.group_dml_attempts s;
$$;
create temp table metadata_baseline as select pg_temp.metadata_state() state;
create function pg_temp.expect_failure(p_sql text,p_state text,p_guard boolean default false)
returns void language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_counter jsonb; v_state text; v_message text; v_failed boolean:=false;
begin
  v_before:=pg_temp.business_state(); v_counter:=pg_temp.counter_state();
  perform set_config('sale_storage_observer.armed',case when p_guard then 'on' else 'off' end,true);
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics v_state=returned_sqlstate,v_message=message_text;
    if v_state<>p_state then raise; end if;
    if p_guard and v_message<>'Direct Group sale writes are forbidden' then raise; end if;
    v_failed:=true;
  end;
  perform set_config('sale_storage_observer.armed','off',true);
  perform pg_temp.check_true(v_failed,'statement refuses with exact expected SQLSTATE '||p_state);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'failed statement preserves full business state');
  perform pg_temp.check_true(pg_temp.counter_state()=v_counter,'no unauthorized Group AFTER ROW attempt');
end;
$$;
do $shape_and_metadata$
declare v_f record; v_case record; v_before jsonb;
begin
  select * into v_f from pg_temp.ids;
  perform pg_temp.check_true(exists(select 1 from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    join pg_catalog.pg_roles r on r.oid=p.proowner
    where n.nspname='economics_v2' and p.proname='guard_direct_group_sale' and p.pronargs=0
      and p.prorettype='pg_catalog.trigger'::regtype and not p.prosecdef and r.rolname='postgres'
      and p.proconfig=array['search_path=""']::text[]
      and not has_function_privilege('anon',p.oid,'EXECUTE')
      and not has_function_privilege('authenticated',p.oid,'EXECUTE')
      and not has_function_privilege('service_role',p.oid,'EXECUTE')
      and not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
        where a.grantee=0 and a.privilege_type='EXECUTE')), 'private invoker trigger metadata and ACL');
  perform pg_temp.check_true(exists(select 1 from pg_catalog.pg_trigger t
    where t.tgrelid='public.venta_animal'::regclass and t.tgname='venta_animal_group_writer_guard'
      and t.tgtype=31 and t.tgenabled='O'
      and t.tgfoid='economics_v2.guard_direct_group_sale()'::regprocedure), 'enabled BEFORE ROW I/U/D guard');
  perform pg_temp.check_true((select r.rolsuper or r.rolbypassrls from pg_catalog.pg_roles r
    where r.rolname=current_user) and not exists(select 1 from unnest(array['INSERT','UPDATE','DELETE']) a(op)
      where not has_table_privilege(current_user,'public.venta_animal',a.op)),
    'structural administrator has effective SQL authority and table permissions');
  perform pg_temp.check_true(not exists(select 1 from unnest(array['SELECT','INSERT','UPDATE','DELETE']) a(op)
    where not has_table_privilege('authenticated','public.venta_animal',a.op))
    and (select c.relrowsecurity and not c.relforcerowsecurity from pg_catalog.pg_class c
      where c.oid='public.venta_animal'::regclass), 'retained direct CRUD ACL and enabled RLS');
  perform pg_temp.check_true((select count(*)=8 and bool_and(a.attnotnull)
    from pg_catalog.pg_attribute a where a.attrelid='public.venta_animal'::regclass
      and a.attname=any(array['id','granja_id','tipo_animal_id','fecha_venta',
        'created_at','record_kind','quantity','total_amount'])), 'retained required storage columns');
  for v_case in select * from (values
    ('{"grupo_id":null}'::jsonb,'23514'),(jsonb_build_object('animal_id',v_f.animal_a),'23514'),
    ('{"quantity":0}','23514'),('{"quantity":1}','23514'),('{"quantity":null}','23502'),
    ('{"peso":null}','23514'),('{"peso":0}','23514'),('{"peso":-1}','23514'),
    ('{"peso":"NaN"}','23514'),('{"peso":"Infinity"}','23514'),('{"peso":"-Infinity"}','23514'),
    ('{"total_amount":null}','23502'),('{"total_amount":-1}','23514'),
    ('{"total_amount":"NaN"}','23514'),('{"total_amount":"Infinity"}','23514'),
    ('{"total_amount":"-Infinity"}','23514'),('{"record_kind":"unknown"}','23514'),
    ('{"record_kind":null}','23502'),('{"tipo_animal_id":null}','23502'),
    (jsonb_build_object('grupo_id',v_f.missing_group),'23503')) q(patch,expected_state) loop
    perform pg_temp.expect_failure(pg_temp.sale_sql(v_case.patch),v_case.expected_state);
  end loop;
  perform pg_temp.expect_failure(format('update public.venta_animal set peso=null where id=%L',v_f.group_sale),'23514');
  perform pg_temp.expect_failure(format('update public.venta_animal set quantity=1 where id=%L',v_f.group_sale),'23514');
  perform pg_temp.expect_failure(format('update public.venta_animal set total_amount=''Infinity'' where id=%L',
    v_f.group_sale),'23514');
  v_before:=pg_temp.business_state();
  begin
    update public.venta_animal set quantity=3,peso=4,total_amount=12 where id=v_f.group_sale;
    perform pg_temp.check_true((select quantity=3 and peso=4 and total_amount=12 from public.venta_animal
      where id=v_f.group_sale),'privileged Group UPDATE is structurally permitted');
    delete from public.venta_animal where id=v_f.group_sale;
    perform pg_temp.check_true(not exists(select 1 from public.venta_animal where id=v_f.group_sale),
      'privileged Group DELETE is permitted, not a canonical business operation');
    raise exception using errcode='Z0001',message='Restore privileged storage probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'privileged probe completely restored');
  -- Legacy branches must not acquire the new Group-only finite/positive rule.
  v_before:=pg_temp.business_state();
  begin
    insert into public.venta_animal(id,granja_id,tipo_animal_id,animal_id)
    values(v_f.candidate_sale,v_f.farm_a,v_f.type_a,v_f.animal_a);
    perform pg_temp.check_true((select record_kind='individual' and quantity=1 and total_amount=0
      and peso is null and fecha_venta=current_date and created_at is not null
      from public.venta_animal where id=v_f.candidate_sale),'retained actual omitted-column defaults');
    delete from public.venta_animal where id=v_f.candidate_sale;
    for v_case in select * from (values ('individual'::text,v_f.animal_a),
      ('legacy_batch',null::uuid)) q(kind,animal_id) loop
      execute pg_temp.sale_sql(jsonb_build_object('record_kind',v_case.kind,
        'animal_id',v_case.animal_id,'peso','NaN','total_amount','Infinity'));
      perform pg_temp.check_true((select quantity=2 and peso='NaN'::numeric and total_amount='Infinity'::numeric
        from public.venta_animal where id=v_f.candidate_sale),'historical numeric shape remains accepted');
      delete from public.venta_animal where id=v_f.candidate_sale;
    end loop;
    raise exception using errcode='Z0001',message='Restore historical numeric shape probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'historical shape probe fully restored');
end;
$shape_and_metadata$;

-- Retain historical shapes; no forward period or synthetic business binding is seeded.
insert into public.venta_animal(id,granja_id,grupo_id,tipo_animal_id,animal_id,peso,record_kind,quantity,total_amount)
select individual_sale,farm_a,group_a,type_a,animal_a,null::numeric,'individual',2,0 from ids
union all select batch_sale,farm_a,group_a,type_a,null::uuid,null::numeric,'legacy_batch',2,0 from ids;
do $access$
begin
  execute format('grant usage on schema %I to authenticated',pg_my_temp_schema()::regnamespace::text);
end;
$access$;
grant select on pg_temp.ids to authenticated;
grant insert on pg_temp.assertions to authenticated;
revoke all on function pg_temp.business_state(boolean),pg_temp.metadata_state(),pg_temp.counter_state(),
  pg_temp.observe_group_dml() from public;
grant execute on function pg_temp.business_state(boolean),pg_temp.counter_state() to authenticated;
do $client_guards$
declare v_f record; v_actor uuid; v_sql text; v_before jsonb; v_count bigint;
begin
  select * into v_f from pg_temp.ids;
  foreach v_actor in array array[v_f.owner_a,v_f.editor_a] loop
    perform pg_temp.jwt(v_actor);
    set local role authenticated;
    perform pg_temp.check_true(current_user='authenticated' and (select count(*)=1 from public.venta_animal
      where id=v_f.group_sale),'real owner/editor SQL role can SELECT protected Group row');
    perform pg_temp.expect_failure(pg_temp.sale_sql(),'42501',true);
    foreach v_sql in array array[
      format('update public.venta_animal set record_kind=''group'',animal_id=null,peso=3.5 where id=%L',v_f.individual_sale),
      format('update public.venta_animal set total_amount=1 where id=%L',v_f.group_sale),
      format('update public.venta_animal set record_kind=''individual'',animal_id=%L where id=%L',v_f.animal_a,v_f.group_sale),
      format('update public.venta_animal set record_kind=''legacy_batch'' where id=%L',v_f.group_sale),
      format('delete from public.venta_animal where id=%L',v_f.group_sale)] loop
      perform pg_temp.expect_failure(v_sql,'42501',true);
    end loop;
    -- Opaque caller data cannot turn the actual SQL role into a bypass role.
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_actor,'role','service_role',
      'app_metadata',jsonb_build_object('role','postgres'))::text,true);
    perform pg_temp.expect_failure(pg_temp.sale_sql(),'42501',true);
    reset role;
    perform pg_temp.jwt(v_actor);
    v_before:=pg_temp.business_state();
    begin
      set local role authenticated;
      execute pg_temp.sale_sql(jsonb_build_object('record_kind','individual','animal_id',v_f.animal_a,'peso',null));
      update public.venta_animal set quantity=3 where id=v_f.candidate_sale;
      get diagnostics v_count=row_count;
      perform pg_temp.check_true(v_count=1 and (select quantity=3 and peso is null and record_kind='individual'
        from public.venta_animal where id=v_f.candidate_sale),'owner/editor legacy INSERT/UPDATE readback');
      delete from public.venta_animal where id=v_f.candidate_sale;
      get diagnostics v_count=row_count;
      perform pg_temp.check_true(v_count=1,'owner/editor legacy DELETE accepted');
      reset role;
      raise exception using errcode='Z0001',message='Restore legacy CRUD probe';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'legacy CRUD changes no unrelated business state');
  end loop;
  foreach v_actor in array array[v_f.viewer_a,v_f.owner_b,v_f.outsider] loop
    perform pg_temp.jwt(v_actor);
    v_before:=pg_temp.business_state();
    set local role authenticated;
    perform pg_temp.check_true((select count(*)=case when v_actor=v_f.viewer_a then 1 else 0 end
      from public.venta_animal where id=v_f.group_sale),'viewer SELECT versus foreign/outsider invisibility');
    perform pg_temp.expect_failure(pg_temp.sale_sql(),'42501',true);
    update public.venta_animal set total_amount=1 where id=v_f.group_sale;
    get diagnostics v_count=row_count;
    perform pg_temp.check_true(v_count=0,'viewer/foreign/outsider Group UPDATE retains RLS zero rows');
    delete from public.venta_animal where id=v_f.group_sale;
    get diagnostics v_count=row_count;
    perform pg_temp.check_true(v_count=0,'viewer/foreign/outsider Group DELETE retains RLS zero rows');
    -- Legacy-shaped INSERT isolates existing RLS, rather than Group guard precedence.
    perform pg_temp.expect_failure(pg_temp.sale_sql(jsonb_build_object('record_kind','individual',
      'animal_id',v_f.animal_a,'peso',null)),'42501');
    update public.venta_animal set total_amount=1 where id=v_f.individual_sale;
    get diagnostics v_count=row_count;
    perform pg_temp.check_true(v_count=0,'viewer/foreign/outsider UPDATE is RLS zero rows');
    delete from public.venta_animal where id=v_f.individual_sale;
    get diagnostics v_count=row_count;
    perform pg_temp.check_true(v_count=0,'viewer/foreign/outsider DELETE is RLS zero rows');
    reset role;
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'existing RLS preserves full business state');
  end loop;
end;
$client_guards$;

-- Real six-argument legacy RPC, rolled back after exact side-effect readback.
do $legacy_rpc$
declare v_f record; v_before jsonb; v_sale uuid; v_baja uuid; v_expected jsonb;
begin
  select * into v_f from pg_temp.ids;
  perform pg_temp.jwt(v_f.owner_a);
  v_before:=pg_temp.business_state();
  begin
    set local role authenticated;
    v_sale:=public.registrar_venta_animal_v2(v_f.farm_a,array[v_f.animal_a,v_f.animal_b],
      current_date,0::numeric,null::numeric,'Sale storage compatibility');
    reset role;
    select baja_id into strict v_baja from public.venta_animal where id=v_sale;
    perform pg_temp.check_true((select record_kind='individual' and quantity=2 and peso is null
      and total_amount=0 and animal_id=v_f.animal_a and granja_id=v_f.farm_a and tipo_animal_id=v_f.type_a
      and fecha_venta=current_date and created_by=v_f.owner_a from public.venta_animal where id=v_sale),
      'actual legacy RPC keeps literal individual, count two and nullable non-meat weight');
    perform pg_temp.check_true((select count(*)=2 from public.animales where id=any(array[v_f.animal_a,v_f.animal_b])
      and not activo and baja_id=v_baja) and (select cantidad_animales=2 and importe_total=0
      and granja_id=v_f.farm_a and tipo_animal_id=v_f.type_a and fecha_baja=current_date
      and notas='Sale storage compatibility' and created_by=v_f.owner_a
      from public.bajas_animales where id=v_baja),'real RPC baja and both animal deactivations');
    v_expected:=pg_temp.business_state();
    -- Normalize ONLY this returned sale/baja and the two declared animal fields.
    v_expected:=jsonb_set(v_expected,'{public.venta_animal}',coalesce((select jsonb_agg(x order by x::text)
      from jsonb_array_elements(v_expected->'public.venta_animal') x where x->>'id'<>v_sale::text),'[]'));
    v_expected:=jsonb_set(v_expected,'{public.bajas_animales}',coalesce((select jsonb_agg(x order by x::text)
      from jsonb_array_elements(v_expected->'public.bajas_animales') x where x->>'id'<>v_baja::text),'[]'));
    v_expected:=jsonb_set(v_expected,'{public.animales}',(select jsonb_agg(y.row_value order by y.row_value::text)
      from (select case when x->>'id'=any(array[v_f.animal_a::text,v_f.animal_b::text])
        then jsonb_set(jsonb_set(x,'{activo}','true'),'{baja_id}','null') else x end row_value
        from jsonb_array_elements(v_expected->'public.animales') x) y));
    perform pg_temp.check_true(v_expected=v_before,'RPC has exactly declared legacy side effects, no Group business effects');
    set constraints all immediate;
    raise exception using errcode='Z0001',message='Restore real RPC compatibility probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'RPC rollback restores full business state and sequences');
  insert into pg_temp.rpc_ids values(v_sale,v_baja,array[v_f.animal_a,v_f.animal_b]);
  perform pg_temp.check_true(v_sale is not null and v_baja is not null
    and not exists(select 1 from public.venta_animal where id=v_sale)
    and not exists(select 1 from public.bajas_animales where id=v_baja),
    'actual legacy RPC returned identifiers and its probe rows are absent');
end;
$legacy_rpc$;
select pg_temp.check_true((select count(*)=2 and bool_and(quantity=2 and peso is null)
  from public.venta_animal where id in (select individual_sale from ids union all select batch_sale from ids)),
  'both historical individual and legacy_batch shapes remain unchanged');
select pg_temp.check_true(pg_temp.metadata_state()=(select b.state from metadata_baseline b),
  'all preexisting function bodies, ACLs, RLS, owners, triggers, constraints and indexes retained');
set constraints all immediate;
select jsonb_build_object(
  'result','group_economics_forward_group_sale_storage_pass',
  'assertion_count',(select count(*) from assertions),
  'fixture_ids',jsonb_build_object('setup',(select to_jsonb(i) from ids i),
    'rolled_back_rpc',(select jsonb_agg(to_jsonb(r)) from rpc_ids r)),
  'group_sale_storage_shape_proven',true,'group_sale_direct_client_guard_proven',true,
  'legacy_sale_shape_compatibility_proven',true,'legacy_sale_rpc_compatibility_proven',true,
  'canonical_group_sale_producer_proven',false,'explicit_animal_binding_proven',false,
  'sale_disposition_integrated',false,'real_sale_closure_proven',false,
  'http_proven',false,'production_proven',false,'independent_review','pending',
  'locking_evidence','sequential_only','private_producer_provenance_proven',false) evidence;
rollback;
