begin;

-- HUMAN Sandbox Dashboard: standalone additional REQUIRED qualification, NOT first RED.
-- Run ONLY AFTER base DELETE fixture GREEN, against the UNCHANGED installed gateway.
-- Preparation only; authoring supplies no runtime proof or independent review PASS.
-- Exact5 PUBLIC/authorized implementation, exact7 receipt, exact14 nullable-Group
-- completion remain unchanged. All security logic must exist BEFORE base GREEN;
-- moving these probes to another review unit does NOT defer implementation security.
-- Autonomous real CREATE/UPDATE/DELETE setup; no forged receipts, implementation copy,
-- producer proxy, persistent helper, psql include, FK disabling or orphan fabrication.
-- Normal FK prevents orphan context: that corruption branch is explicitly NOT tested.
-- ADMIN corruption probes restore all state; they are NOT privileged-business provenance.
-- API request4/private request6 and original predecessor binding remain the protocol.
-- Historical delegation to actual core, absence of mutable-first queries and lock order
-- need future SOURCE inspection: JSON replay equality is NOT runtime call tracing.
-- Source drift must fail using captured allocation predecessors, never refreshed ones.
-- Fresh header-token distinction is conditional on actual CREATE clocks differing;
-- coincident clocks leave a declared evidence gap, never fabricate a +1 header clock.
-- Base retains UUID-recreation history, original UPDATE replay and late physical-delete
-- companion-failure rollback. Those proofs are not replaced by this integrity matrix.
-- Both fixtures + remaining composed/native/transport gates are required for readiness.
-- Separate test-only review unit; aggregate fixtures + gateway is NOT claimed <=800.
-- Sequential SQL RPC only; isolate Sandbox. Setup sequence issuance is not rewound.

create temp table ids as select
  gen_random_uuid() owner_a,gen_random_uuid() editor_a,gen_random_uuid() farm_a,
  gen_random_uuid() type_a,gen_random_uuid() meat_a,gen_random_uuid() category_a,
  gen_random_uuid() group_a,gen_random_uuid() group_aux,gen_random_uuid() animal_a,gen_random_uuid() animal_aux,
  gen_random_uuid() source_a,gen_random_uuid() source_aux,gen_random_uuid() source_private,
  gen_random_uuid() create_op,gen_random_uuid() aux_create_op,gen_random_uuid() private_create_op,
  gen_random_uuid() update_op,gen_random_uuid() delete_op,gen_random_uuid() aux_delete_op,
  gen_random_uuid() private_op,gen_random_uuid() entry_op,gen_random_uuid() aux_entry_op;
create temp table assertions(label text not null);
create temp table evidence(fresh_header_token_rejection_observed boolean not null);
insert into evidence values(false);
create temp table creations(mixture_id uuid primary key,result jsonb not null);
create temp table calls(operation_id uuid primary key,mixture_id uuid,period_id uuid,allocation_id uuid,
  allocation_stamp timestamptz,source_stamp timestamptz,source_digest text,result jsonb);
create temp table watched as
select n.nspname schema_name,c.relname table_name from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where c.relkind in ('r','p') and (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users'));
create temp table sequences as
select n.nspname schema_name,c.relname sequence_name from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity');
create temp table protected_acl as
select 'table' kind,c.oid,to_jsonb(c.relacl) acl from pg_class c
join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','economics_v2','group_feed_integrity')
union all select 'function',p.oid,to_jsonb(p.proacl) from pg_proc p
join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','economics_v2','group_feed_integrity');

create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
-- Read-only private evidence access; full snapshots have NO target/operation exclusions.
create function pg_temp.business_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; v_rows jsonb; v_state jsonb:='{}';
begin
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r',t.schema_name,t.table_name) into v_rows;
    v_state:=v_state||jsonb_build_object(t.schema_name||'.'||t.table_name,v_rows);
  end loop;
  for t in select * from pg_temp.sequences order by schema_name,sequence_name loop
    execute format('select jsonb_build_object(''last_value'',last_value,''is_called'',is_called)
      from %I.%I',t.schema_name,t.sequence_name) into v_rows;
    v_state:=v_state||jsonb_build_object(t.schema_name||'.'||t.sequence_name,v_rows);
  end loop;
  return v_state;
end;
$$;
create function pg_temp.api_sql(p_farm uuid,p_op uuid,p_period uuid,p_source uuid,
  p_stamp timestamptz,p_impl boolean default false)
returns text language plpgsql security invoker set search_path='' as $$
begin
  return format('select %s(p_granja_id=>%L::uuid,p_operation_id=>%L::uuid,p_period_id=>%L::uuid,
    p_mezcla_id=>%L::uuid,p_expected_updated_at=>%L::timestamptz)',
    case when p_impl then 'economics_v2.delete_group_feed_impl' else 'public.eliminar_mezcla_grupo_v1' end,
    p_farm,p_op,p_period,p_source,p_stamp);
end;
$$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,
  p_field text default null,p_entity uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_before jsonb; v_result jsonb; v_state text; v_detail text;
begin
  v_before:=pg_temp.business_state();
  perform set_config('feed_delete_integrity.observe','on',true);
  begin execute p_sql into v_result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics v_state=returned_sqlstate,v_detail=pg_exception_detail;
  end;
  perform set_config('feed_delete_integrity.observe','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'no source/food/fact/ledger/context/fence/sequence change');
  if p_state is null then perform pg_temp.check_true(v_result is not null,'nonempty historical replay');
  else
    perform pg_temp.check_true(v_state=p_state,'expected SQLSTATE '||p_state);
    if p_code is not null then
      perform pg_temp.check_true(v_detail::jsonb=jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field,'entity_id',p_entity),'exact4 typed refusal');
    end if;
  end if;
  return v_result;
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"feed-delete-api-integrity"}'::jsonb from ids
cross join lateral unnest(array[owner_a,editor_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'DELETE integrity farm',owner_a from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled) select farm_a,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'DELETE integrity type',owner_a from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'DELETE integrity meat','carne',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'DELETE integrity Group '||g::text,owner_a from ids
cross join lateral unnest(array[group_a,group_aux]) g;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select category_a,farm_a,'DELETE integrity category',true,owner_a from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,created_by)
select animal_a,farm_a,type_a,group_a,meat_a,current_date-7,300,owner_a from ids
union all select animal_aux,farm_a,type_a,group_aux,meat_a,current_date-7,0,owner_a from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
create temp table targets as select f.*,
  (economics_v2.enter_group_meat_initial(farm_a,entry_op,animal_a,current_date-4,group_a,meat_a,'{}')->>'destination_period_id')::uuid period_a,
  (economics_v2.enter_group_meat_initial(farm_a,aux_entry_op,animal_aux,current_date-4,group_aux,meat_a,'{}')->>'destination_period_id')::uuid period_aux,
  jsonb_build_array(jsonb_build_object('categoria_id',category_a,'cantidad_kg',2,'costo_total',10)) recipe from ids f;
do $access$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$access$;
grant select on pg_temp.targets,pg_temp.calls to authenticated,anon;
grant insert on pg_temp.assertions to authenticated,anon;
revoke all on function pg_temp.check_true(boolean,text),pg_temp.business_state(),
  pg_temp.api_sql(uuid,uuid,uuid,uuid,timestamptz,boolean),pg_temp.checked(text,text,text,text,uuid) from public;
grant execute on function pg_temp.check_true(boolean,text),pg_temp.business_state(),
  pg_temp.api_sql(uuid,uuid,uuid,uuid,timestamptz,boolean),pg_temp.checked(text,text,text,text,uuid) to authenticated,anon;
do $real_contexts$
declare f record; q record; a record; r jsonb; v_stamp timestamptz;
begin
  select * into f from pg_temp.targets;
  for q in select * from (values(f.source_a,f.create_op,f.period_a,f.group_a),
    (f.source_aux,f.aux_create_op,f.period_aux,f.group_aux),
    (f.source_private,f.private_create_op,f.period_a,f.group_a)) sources(id,op,period_id,group_id) loop
    set local role authenticated;
    r:=public.crear_mezcla_grupo_v1(p_granja_id=>f.farm_a,p_operation_id=>q.op,p_period_id=>q.period_id,
      p_mezcla_id=>q.id,p_fecha_inicio=>current_date-2,p_grupo_id=>q.group_id,p_ingredientes=>f.recipe);
    reset role;
    insert into pg_temp.creations values(q.id,r);
  end loop;
  select * into a from economics_v2.group_period_feed_allocations x where x.mixture_id=f.source_private;
  -- Actual ADMIN private completion without companion, not a fabricated namespace row.
  perform economics_v2.delete_group_feed_allocation(f.farm_a,f.private_op,f.period_a,f.source_private,
    a.updated_at,a.source_updated_at,a.source_digest);
  select (c.result->>'updated_at')::timestamptz into v_stamp from pg_temp.creations c where c.mixture_id=f.source_a;
  set local role authenticated;
  r:=public.actualizar_mezcla_grupo_v1(p_mezcla_id=>f.source_a,p_granja_id=>f.farm_a,p_operation_id=>f.update_op,
    p_period_id=>f.period_a,p_expected_updated_at=>v_stamp,p_fecha_inicio=>current_date-2,
    p_fecha_termino=>null::date,p_grupo_id=>f.group_a,p_ingredientes=>f.recipe);
  reset role;
  insert into pg_temp.calls
  select seed.op,seed.source,seed.period_id,fact.id,(seed.response->>'updated_at')::timestamptz,fact.source_updated_at,fact.source_digest,null
  from (values(f.delete_op,f.source_a,f.period_a,r),
    (f.aux_delete_op,f.source_aux,f.period_aux,(select c.result from pg_temp.creations c where c.mixture_id=f.source_aux)))
    seed(op,source,period_id,response) join economics_v2.group_period_feed_allocations fact on fact.mixture_id=seed.source;
  select * into a from pg_temp.calls x where x.operation_id=f.delete_op;
  set local role authenticated;
  r:=public.eliminar_mezcla_grupo_v1(p_granja_id=>f.farm_a,p_operation_id=>a.operation_id,p_period_id=>a.period_id,
    p_mezcla_id=>a.mixture_id,p_expected_updated_at=>a.allocation_stamp);
  reset role;
  update pg_temp.calls x set result=r where x.operation_id=f.delete_op;
  perform pg_temp.check_true(r=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',f.delete_op,
    'mixture_id',a.mixture_id,'period_id',a.period_id,'allocation_id',a.allocation_id,'deleted',true,'replayed',false)
    and not exists(select 1 from public.mezcla m where m.id=a.mixture_id)
    and not exists(select 1 from economics_v2.group_period_feed_allocations fact where fact.mixture_id=a.mixture_id),
    'actual canonical DELETE establishes durable exact7 receipt after real source/fact removal');
  perform pg_temp.check_true((select count(*)=1 from economics_v2.group_feed_api_completions c
    join economics_v2.group_occupancy_operations o using(granja_id,operation_id)
    where c.granja_id=f.farm_a and c.operation_id=f.delete_op and c.operation_kind='feed_delete' and c.group_id is null
      and c.actor_id=f.owner_a and c.period_id=a.period_id and c.mixture_id=a.mixture_id
      and c.expected_allocation_updated_at=a.allocation_stamp and c.predecessor_source_updated_at=a.source_stamp
      and c.predecessor_source_digest=a.source_digest and c.core_payload_hash=o.payload_hash and o.result=r and o.event_position is null
      and c.core_result_hash=encode(sha256(convert_to(economics_v2.canonical_group_request(o.result)::text,'UTF8')),'hex')),
    'real gateway context retains actual original actor/token/source predecessors and stored result binding');
end;
$real_contexts$;
set constraints all immediate;

create function pg_temp.observe_dml()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_setting('feed_delete_integrity.observe',true)='on' then
    raise exception 'DELETE integrity replay/refusal attempted DML: %.% %',tg_table_schema,tg_table_name,tg_op;
  end if;
  return null;
end;
$$;
do $observers$
declare t record;
begin
  for t in select * from pg_temp.watched loop
    execute format('create trigger feed_delete_integrity_observer before insert or update or delete or truncate
      on %I.%I for each statement execute function pg_temp.observe_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;

do $fresh_tokens_and_drift$
declare f record; c record; m record; v_probe text; v_before jsonb; v_field text; r jsonb; v_observed boolean:=false;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls x where x.operation_id=f.aux_delete_op;
  select * into m from public.mezcla x where x.id=c.mixture_id;
  perform pg_temp.check_true(m.updated_at=c.source_stamp,'auxiliary target is unmodified genuine canonical CREATE');
  set local role authenticated;
  if m.updated_at is distinct from c.allocation_stamp then
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),c.period_id,c.mixture_id,m.updated_at),
      '40001','stale_write','allocation_id',c.allocation_id);
    v_observed:=true;
  end if;
  -- Explicit wrong-period admission uses real owned period, not an unknown UUID.
  perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),f.period_a,c.mixture_id,c.allocation_stamp),
    '42501','forbidden','period_id',f.period_a);
  foreach v_probe in array array['null','infinity','-infinity'] loop
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),c.period_id,c.mixture_id,
      case when v_probe='null' then null::timestamptz else v_probe::timestamptz end),
      '22023','invalid_request','expected_allocation_updated_at',c.mixture_id);
  end loop;
  reset role;
  foreach v_probe in array array['source_stamp','source_price'] loop
    v_before:=pg_temp.business_state();
    begin
      if v_probe='source_stamp' then
        update public.mezcla set updated_at=clock_timestamp() where id=c.mixture_id;
        v_field:='mixture_id';
      else
        update public.comida set precio=precio+1 where id=(select mc.comida_id from public.mezcla_comida mc where mc.mezcla_id=c.mixture_id limit 1);
        v_field:='source_digest';
      end if;
      perform pg_temp.check_true((select a.updated_at=c.allocation_stamp and a.source_updated_at=c.source_stamp
        and a.source_digest=c.source_digest from economics_v2.group_period_feed_allocations a where a.id=c.allocation_id),
        'ADMIN drift leaves allocation clock and captured source predecessor unchanged');
      perform pg_temp.check_true((select case when v_probe='source_stamp' then header.updated_at is distinct from c.source_stamp
        else header.updated_at=c.source_stamp end from public.mezcla header where header.id=c.mixture_id),
        'timestamp drift is real; price-only drift leaves the source header timestamp unchanged');
      set local role authenticated;
      perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),c.period_id,c.mixture_id,c.allocation_stamp),
        '40001','stale_write',v_field,c.mixture_id);
      reset role;
      raise exception using errcode='ZR001',message='Restore ADMIN source drift probe';
    exception when sqlstate 'ZR001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'source drift probe fully restored: '||v_probe);
  end loop;
  v_before:=pg_temp.business_state();
  begin
    set local role authenticated;
    r:=public.eliminar_mezcla_grupo_v1(p_granja_id=>f.farm_a,p_operation_id=>c.operation_id,p_period_id=>c.period_id,
      p_mezcla_id=>c.mixture_id,p_expected_updated_at=>c.allocation_stamp);
    reset role;
    perform pg_temp.check_true(r=jsonb_build_object('contract_version','group-economics.forward.v3',
      'operation_id',c.operation_id,'mixture_id',c.mixture_id,'period_id',c.period_id,
      'allocation_id',c.allocation_id,'deleted',true,'replayed',false)
      and not exists(select 1 from public.mezcla x where x.id=c.mixture_id),
      'correct actual CREATE allocation token admits real canonical DELETE after drift restoration');
    raise exception using errcode='ZR001',message='Restore auxiliary positive DELETE';
  exception when sqlstate 'ZR001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'auxiliary DELETE restores all rows, completion and fences without sequence drift');
  begin
    -- Produce a genuinely stale token on THIS allocation through actual canonical UPDATE.
    set local role authenticated;
    r:=public.actualizar_mezcla_grupo_v1(p_mezcla_id=>c.mixture_id,p_granja_id=>f.farm_a,p_operation_id=>gen_random_uuid(),
      p_period_id=>c.period_id,p_expected_updated_at=>c.allocation_stamp,p_fecha_inicio=>current_date-1,
      p_fecha_termino=>null::date,p_grupo_id=>f.group_aux,p_ingredientes=>f.recipe);
    reset role;
    perform pg_temp.check_true((r->>'updated_at')::timestamptz>c.allocation_stamp,'real UPDATE advances actual allocation token');
    set local role authenticated;
    perform pg_temp.checked(pg_temp.api_sql(f.farm_a,gen_random_uuid(),c.period_id,c.mixture_id,c.allocation_stamp),
      '40001','stale_write','allocation_id',c.allocation_id);
    reset role;
    raise exception using errcode='ZR001',message='Restore real stale-allocation-token probe';
  exception when sqlstate 'ZR001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'real stale-token sample and UPDATE receipt fully restored');
  update pg_temp.evidence set fresh_header_token_rejection_observed=v_observed;
  perform pg_temp.check_true(true,case when v_observed then 'fresh header-token rejection actually observed'
    else 'CREATE clocks coincide: fresh header-token distinction NOT proven' end);
end;
$fresh_tokens_and_drift$;

do $namespace_and_identity$
declare f record; c record; q record; v_impl boolean; v_sql text;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls x where x.operation_id=f.delete_op;
  foreach v_impl in array array[false,true] loop
    v_sql:=pg_temp.api_sql(f.farm_a,c.operation_id,c.period_id,c.mixture_id,c.allocation_stamp,v_impl);
    set local role authenticated;
    perform pg_temp.check_true(pg_temp.checked(v_sql)=c.result||'{"replayed":true}'::jsonb,'public/direct implementation replay after source deletion');
    for q in select * from (values(f.create_op),(f.update_op),(f.entry_op),(f.private_op)) operations(op) loop
      perform pg_temp.checked(pg_temp.api_sql(f.farm_a,q.op,c.period_id,c.mixture_id,c.allocation_stamp,v_impl),
        '22023','operation_payload_conflict','operation_id',q.op);
    end loop;
    for q in select * from (values(c.period_id,c.mixture_id,c.allocation_stamp+interval '1 second'),
      (f.period_aux,c.mixture_id,c.allocation_stamp),(c.period_id,f.source_aux,c.allocation_stamp)) changes(period_id,source,stamp) loop
      perform pg_temp.checked(pg_temp.api_sql(f.farm_a,c.operation_id,q.period_id,q.source,q.stamp,v_impl),
        '22023','operation_payload_conflict','operation_id',c.operation_id);
    end loop;
    reset role;
    perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated')::text,true);
    set local role authenticated;
    perform pg_temp.checked(v_sql,'22023','operation_payload_conflict','operation_id',c.operation_id);
    reset role;
    perform set_config('request.jwt.claim.sub',f.owner_a::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',f.owner_a,'role','authenticated')::text,true);
  end loop;
end;
$namespace_and_identity$;

do $stored_binding_and_current_flag$
declare f record; c record; v_probe text; v_before jsonb; v_state text; v_code text; v_sql text; v_impl boolean;
begin
  select * into f from pg_temp.targets;
  select * into c from pg_temp.calls x where x.operation_id=f.delete_op;
  foreach v_probe in array array['missing_companion','core_payload_hash','ledger_payload_hash','core_result_hash','allocation_id','deleted','flag'] loop
    v_before:=pg_temp.business_state();
    begin
      v_state:='23514'; v_code:='invariant_violation';
      if v_probe='missing_companion' then
        delete from economics_v2.group_feed_api_completions where granja_id=f.farm_a and operation_id=c.operation_id;
        v_state:='22023'; v_code:='operation_payload_conflict';
      elsif v_probe in ('core_payload_hash','core_result_hash') then
        execute format('update economics_v2.group_feed_api_completions set %I=%L where granja_id=$1 and operation_id=$2',
          v_probe,repeat('0',64)) using f.farm_a,c.operation_id;
      elsif v_probe='ledger_payload_hash' then
        update economics_v2.group_occupancy_operations set payload_hash=repeat('0',64)
          where granja_id=f.farm_a and operation_id=c.operation_id;
      elsif v_probe='allocation_id' then
        update economics_v2.group_occupancy_operations set result=jsonb_set(result,'{allocation_id}',to_jsonb(gen_random_uuid()))
          where granja_id=f.farm_a and operation_id=c.operation_id;
      elsif v_probe='deleted' then
        update economics_v2.group_occupancy_operations set result=jsonb_set(result,'{deleted}','false'::jsonb)
          where granja_id=f.farm_a and operation_id=c.operation_id;
      else
        update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
      end if;
      foreach v_impl in array array[false,true] loop
        v_sql:=pg_temp.api_sql(f.farm_a,c.operation_id,c.period_id,c.mixture_id,c.allocation_stamp,v_impl);
        set local role authenticated;
        if v_probe='flag' then perform pg_temp.checked(v_sql,'42501');
        else perform pg_temp.checked(v_sql,v_state,v_code,'operation_id',c.operation_id);
        end if;
        reset role;
      end loop;
      raise exception using errcode='ZR001',message='Restore ADMIN durable binding/current authorization probe';
    exception when sqlstate 'ZR001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=v_before,'shape-valid durable integrity/flag probe fully restored: '||v_probe);
  end loop;
end;
$stored_binding_and_current_flag$;

do $metadata_and_client_storage$
declare p record; v_role text; v_sql text;
begin
  -- These casts occur AFTER actual public DELETE, never as missing-function preflight.
  for p in select q.*,n.nspname from pg_proc q join pg_namespace n on n.oid=q.pronamespace
    where q.oid in ('public.eliminar_mezcla_grupo_v1(uuid,uuid,uuid,uuid,timestamptz)'::regprocedure,
      'economics_v2.delete_group_feed_impl(uuid,uuid,uuid,uuid,timestamptz)'::regprocedure) loop
    perform pg_temp.check_true(p.prosecdef=(p.nspname='economics_v2') and p.proowner='postgres'::regrole
      and p.prorettype='jsonb'::regtype and p.provolatile='v' and p.pronargs=5 and p.pronargdefaults=0
      and p.proargnames=array['p_granja_id','p_operation_id','p_period_id','p_mezcla_id','p_expected_updated_at']
      and p.proconfig @> array['search_path=""'] and has_function_privilege('authenticated',p.oid,'EXECUTE')
      and not has_function_privilege('anon',p.oid,'EXECUTE') and not has_function_privilege('service_role',p.oid,'EXECUTE')
      and not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) x
        where x.grantee=0 and x.privilege_type='EXECUTE'),'exact5 required authorized capability metadata and ACL');
  end loop;
  perform pg_temp.check_true(not exists(select 1 from pg_proc q join pg_namespace n on n.oid=q.pronamespace
    where n.nspname='economics_v2' and q.proname in ('create_group_feed_allocation','update_group_feed_allocation',
      'delete_group_feed_allocation','assert_group_writer_actor','raise_group_writer_error','validate_group_feed_source',
      'canonical_group_request','normalize_group_feed_api_ingredients','group_feed_api_payload_hash')
    and (has_function_privilege('authenticated',q.oid,'EXECUTE') or has_function_privilege('anon',q.oid,'EXECUTE'))),
    'all retained cores, validators, authorizer and pure helpers remain client inaccessible');
  foreach v_role in array array['authenticated','anon'] loop
    perform pg_temp.check_true(not has_table_privilege(v_role,'economics_v2.group_feed_api_completions','SELECT,INSERT,UPDATE,DELETE')
      and not has_any_column_privilege(v_role,'economics_v2.group_feed_api_completions','SELECT,INSERT,UPDATE,REFERENCES'),
      'no completion table or column privilege capability');
    execute format('set local role %I',v_role);
    foreach v_sql in array array['select * from economics_v2.group_feed_api_completions',
      'insert into economics_v2.group_feed_api_completions default values',
      'update economics_v2.group_feed_api_completions set bridge_version=bridge_version',
      'delete from economics_v2.group_feed_api_completions'] loop
      perform pg_temp.checked(v_sql,'42501');
    end loop;
    reset role;
  end loop;
  perform pg_temp.check_true(not exists(select 1 from pg_temp.protected_acl b
    left join pg_class c on b.kind='table' and c.oid=b.oid left join pg_proc q on b.kind='function' and q.oid=b.oid
    where b.acl is distinct from case b.kind when 'table' then to_jsonb(c.relacl) else to_jsonb(q.proacl) end),
    'installed gateway/core/helper/table ACLs unchanged throughout integrity qualification');
end;
$metadata_and_client_storage$;

set constraints all immediate;
select jsonb_build_object(
  'result','group_economics_forward_feed_delete_api_integrity_pass','assertion_count',(select count(*) from assertions),
  'fixture_ids',(select to_jsonb(f) from targets f),'base_gateway_required_green',true,'extended_delete_integrity_proven',true,
  'fresh_header_token_rejection_observed',(select fresh_header_token_rejection_observed from evidence),
  'locking_evidence','sequential_only','independent_review','pending','real_closure_proven',false,
  'production_gateway_integrated',false,'canonical_group_food_delete_api_integrated',true,'canonical_group_food_api_integrated',false,
  'sql_rpc_path_proven',true,'http_transport_proven',false,'metadata_atomic_business_rollback_proven',false,
  'orphan_context_corruption_proven',false,'full_delete_qualification_proven',false,'production_release_ready',false,
  'all_legacy_mutation_paths_guarded',false,'privileged_business_provenance_proven',false) evidence;
rollback;
