begin;

-- Run the FULL file in the sandbox SQL Editor; stop on any error.
-- Expected first RED is 42883 at the first REAL exit_group_meat_nonclosing call.
-- No deployed helper, public RPC, sale, baja, closure or reactivation is implemented here.
-- Unit forecast: standalone fixture <=550 + future private helper <=250 = <=800 lines.
-- SQL Editor temporary-object creation must not enable RLS on business tables.
-- Same-TX seam: replay first; active source validator/complete prefix BEFORE animal DML;
-- trusted caller sets inactive; mutator independently rereads POST-DML authoritative rows.
-- The existing active-only validator must NEVER be called after that update by the mutator.
-- No INTERNAL13 JSON context crosses the mutator API; payload is provenance, not authority.
-- Locks alone do not attest prior validation: production gateway integration remains deferred.
-- Payload has exact3 keys: fixed provenance_version/disposition_kind, metadata object.
-- The fixed kind is ordinary_exit ONLY; metadata cannot authorize sale/baja/delete/history.
create temp table ids as select
  gen_random_uuid() owner_a, gen_random_uuid() owner_b,
  gen_random_uuid() editor_a, gen_random_uuid() viewer_a,
  gen_random_uuid() farm_a, gen_random_uuid() farm_b,
  gen_random_uuid() type_a, gen_random_uuid() type_wrong, gen_random_uuid() type_b,
  gen_random_uuid() meat, gen_random_uuid() other_meat,
  gen_random_uuid() eggs, gen_random_uuid() purpose_b,
  gen_random_uuid() group_a, gen_random_uuid() group_alone,
  gen_random_uuid() group_zero, gen_random_uuid() group_b,
  gen_random_uuid() animal_a, gen_random_uuid() anchor_a,
  gen_random_uuid() animal_zero, gen_random_uuid() anchor_zero,
  gen_random_uuid() animal_alone, gen_random_uuid() animal_unentered,
  gen_random_uuid() animal_b, gen_random_uuid() operation_a, gen_random_uuid() operation_zero;
create temp table assertions(label text not null);
create temp table payload as select
  '{"provenance_version":"group-disposition-provenance.v1","disposition_kind":"ordinary_exit","metadata":{"reference":1}}'::jsonb value;

create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;

-- Full rows from all10 forward business/core tables and public authoritative sources.
create temp table watched_tables(schema_name text,table_name text,primary key(schema_name,table_name));
insert into watched_tables values
  ('economics_v2','group_occupancy_operations'),('economics_v2','group_occupancy_periods'),
  ('economics_v2','group_occupancy_memberships'),('economics_v2','group_occupancy_events'),
  ('economics_v2','group_animal_acquisition_basis'),('economics_v2','group_acquisition_basis_entries'),
  ('economics_v2','group_period_feed_allocations'),('economics_v2','group_period_expenses'),
  ('economics_v2','group_period_sale_bindings'),('economics_v2','group_meat_snapshots'),
  ('public','animales'),('public','bajas_animales'),('public','venta_animal'),
  ('public','tipo_animal'),('public','grupos'),('public','cat_proposito_animal'),
  ('public','cat_razon_baja'),('public','cat_tipo_adquisicion'),('public','altas_animales'),
  ('public','miembros_granja'),('economics_v2','feature_flags');
create function pg_temp.business_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; rows jsonb; result jsonb:='{}'; farms uuid[]; actors uuid[];
begin
  select array[farm_a,farm_b],array[owner_a,owner_b,editor_a,viewer_a]
    into farms,actors from pg_temp.ids;
  for t in select * from pg_temp.watched_tables order by schema_name,table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb)
      from %I.%I r where granja_id=any($1) or granja_id is null',t.schema_name,t.table_name)
      into rows using farms;
    result:=result||jsonb_build_object(t.schema_name||'.'||t.table_name,rows);
  end loop;
  return result||jsonb_build_object(
    'farms',(select jsonb_agg(to_jsonb(r) order by id) from public.granjas r where id=any(farms)),
    'users',(select jsonb_agg(to_jsonb(r) order by id) from auth.users r where id=any(actors)),
    'profiles',(select jsonb_agg(to_jsonb(r) order by id) from public.perfiles r where id=any(actors)));
end;
$$;
create function pg_temp.position_state()
returns jsonb language sql security definer set search_path='' as $$
  select jsonb_build_object('last_value',last_value,'is_called',is_called)
  from economics_v2.group_economics_event_position_seq;
$$;

-- Refusals/replays must not even ATTEMPT a zero-row write, including ledger reservation.
create function pg_temp.no_write()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_setting('f2dx.no_write',true)='on' then
    raise exception using errcode='P0001',message='F2DX unexpected business DML';
  end if;
  return null;
end;
$$;
do $blockers$
declare t record;
begin
  for t in select * from pg_temp.watched_tables
    where schema_name='economics_v2' and table_name<>'feature_flags'
      or schema_name='public' and table_name in ('animales','bajas_animales','venta_animal') loop
    execute format('create trigger f2dx_no_write before insert or update or delete on %I.%I
      for each statement execute function pg_temp.no_write()',t.schema_name,t.table_name);
  end loop;
end;
$blockers$;

create function pg_temp.checked(p_sql text,p_state text default null,
  p_code text default null,p_field text default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare before_rows jsonb; before_seq jsonb; result jsonb; state text; detail text;
begin
  before_rows:=pg_temp.business_state();
  before_seq:=pg_temp.position_state();
  perform set_config('f2dx.no_write','on',true);
  begin
    execute p_sql into result;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics state=returned_sqlstate,detail=pg_exception_detail;
  end;
  perform set_config('f2dx.no_write','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=before_rows,'full rows unchanged: '||p_sql);
  perform pg_temp.check_true(pg_temp.position_state()=before_seq,'sequence unchanged: '||p_sql);
  if p_state is null then
    perform pg_temp.check_true(result is not null,'nonempty replay result');
  else
    perform pg_temp.check_true(state=p_state,'expected SQLSTATE '||p_state||': '||p_sql);
    if p_code is not null then
      perform pg_temp.check_true(detail::jsonb @> jsonb_build_object(
        'contract_version','group-economics.forward.v3','code',p_code,'field',p_field)
        and detail::jsonb ? 'entity_id','typed refusal: '||p_sql);
    end if;
  end if;
  return result;
end;
$$;

-- Temporary trusted gateway only, never a deployed implementation or mutator stub.
-- Replay reconstructs ORIGINAL source before current-state/chronology validation or DML.
-- POST-DML mutator must repeat all authoritative source invariants except active=true,
-- instead requiring inactive/null baja; it cannot trust this caller's working context.
create function pg_temp.exit_gateway(p_farm uuid,p_operation uuid,p_animal uuid,p_date date,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare stored jsonb; source_id uuid; prepared jsonb; context jsonb; affected bigint;
begin
  perform economics_v2.assert_group_writer_actor(p_farm);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_farm::text,0));
  select result into stored from economics_v2.group_occupancy_operations
    where granja_id=p_farm and operation_id=p_operation;
  if found then
    -- The actual mutator, not this fixture, validates completeness and hash on replay.
    return economics_v2.exit_group_meat_nonclosing(p_farm,p_operation,p_animal,p_date,p_payload);
  end if;
  select period_id into source_id from economics_v2.group_occupancy_memberships
    where granja_id=p_farm and animal_id=p_animal and end_position is null;
  prepared:=economics_v2.prepare_group_operation(p_farm,p_operation,jsonb_build_object(
    'action','exit','animal_id',p_animal,'source_period_id',source_id,
    'destination_group_id',null,'destination_purpose_id',null,'sale_id',null,
    'effective_on',p_date,'payload',p_payload));
  context:=economics_v2.validate_group_meat_nonclosing_source(p_farm,p_animal,p_date);
  perform pg_temp.check_true(context->>'actor_id'=auth.uid()::text
    and context->>'source_period_id'=source_id::text,'pre-DML prefix and actual actor');
  update public.animales set activo=false where granja_id=p_farm and id=p_animal
    and activo is true and baja_id is null;
  get diagnostics affected=row_count;
  if affected<>1 then
    perform economics_v2.raise_group_writer_error('40001','stale_write','animal_id',p_animal);
  end if;
  -- FIRST missing-function call occurs here AFTER real initial setup and valid caller DML.
  return economics_v2.exit_group_meat_nonclosing(p_farm,p_operation,p_animal,p_date,p_payload);
end;
$$;

select pg_temp.check_true(
  not exists(select 1 from auth.users where raw_user_meta_data->>'fixture'='group-exit-disposition')
  and not exists(select 1 from public.granjas where nombre like 'F2DX %'),'empty fixture baseline');
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated','{"fixture":"group-exit-disposition"}'::jsonb
from ids f cross join lateral unnest(array[f.owner_a,f.owner_b,f.editor_a,f.viewer_a]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'F2DX farm A',owner_a from ids
union all select farm_b,owner_b,'F2DX farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F2DX type A',owner_a from ids
union all select type_wrong,farm_a,'F2DX wrong type',owner_a from ids
union all select type_b,farm_b,'F2DX foreign type',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat,farm_a,'F2DX meat','carne',owner_a from ids
union all select other_meat,farm_a,'F2DX other meat','carne',owner_a from ids
union all select eggs,farm_a,'F2DX eggs','postura',owner_a from ids
union all select purpose_b,farm_b,'F2DX foreign meat','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm_a,type_a,'F2DX group '||g::text,owner_a
from ids cross join lateral unnest(array[group_a,group_zero,group_alone]) g
union all select group_b,farm_b,type_b,'F2DX foreign group',owner_b from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,notas,created_by)
select a,farm_a,type_a,case when a in(animal_zero,anchor_zero) then group_zero
  when a=animal_alone then group_alone else group_a end,meat,current_date-4,
  case when a=animal_a then 300 else 0 end,'F2DX animal',owner_a
from ids cross join lateral unnest(array[animal_a,anchor_a,animal_zero,anchor_zero,animal_alone,animal_unentered]) a
union all select animal_b,farm_b,type_b,group_b,purpose_b,current_date-4,0,'F2DX foreign',owner_b from ids;
select set_config('request.jwt.claim.sub',owner_a::text,true) from ids;
select set_config('request.jwt.claims',jsonb_build_object('sub',owner_a,'role','authenticated')::text,true) from ids;
set constraints all immediate;
set constraints all deferred;

-- Five REAL qualified initial operations: shared300+0, shared0+0 and a last-member0.
create temp table initial as select a animal_id,economics_v2.enter_group_meat_initial(
  farm_a,gen_random_uuid(),a,current_date-3,
  case when a in(animal_zero,anchor_zero) then group_zero when a=animal_alone then group_alone else group_a end,
  meat,'{}') result
from ids cross join lateral unnest(array[animal_a,anchor_a,animal_zero,anchor_zero,animal_alone]) a;
set constraints all immediate;
set constraints all deferred;
create temp table captures as select animal_id,to_jsonb(b) basis
from economics_v2.group_animal_acquisition_basis b where granja_id=(select farm_a from ids);
create temp table original_entries as select to_jsonb(b) full_row
from economics_v2.group_acquisition_basis_entries b where granja_id=(select farm_a from ids);
-- Public cost edits after REAL capture never alter source_cost/initial_basis/captured_at.
update public.animales set costo_adquisicion=999 where id=(select animal_a from ids);

-- FIRST new-mutator execution: missing private function must escape, never become a PASS.
-- Its gateway changes the actual animal only after the existing active-only validator.
create temp table receipts as select animal_a animal_id,pg_temp.exit_gateway(
  farm_a,operation_a,animal_a,current_date-1,(select value from payload)) result from ids;

-- All permission checks below occur only AFTER the initial missing-function boundary.
do $grants$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$grants$;
grant execute on function pg_temp.exit_gateway(uuid,uuid,uuid,date,jsonb),
  pg_temp.checked(text,text,text,text),pg_temp.check_true(boolean,text),
  pg_temp.business_state(),pg_temp.position_state() to authenticated,anon;

-- Independent late UPDATE faults. Sequence gaps survive the failed subtransaction,
-- but BUSINESS rows must all roll back; no sequence rewind is permitted or claimed.
create function pg_temp.late_fault()
returns trigger language plpgsql set search_path='' as $$
begin
  if tg_table_name='group_animal_acquisition_basis' then
    if current_setting('f2dx.fault',true)='basis' and new.status='disposed' then
      raise exception using errcode='P0001',message='F2DX injected basis disposal failure';
    end if;
  elsif tg_table_name='group_occupancy_operations' then
    if current_setting('f2dx.fault',true) is distinct from 'completion' or not(new.result ? 'state_version') then
      return new;
    end if;
    -- Completion must be LAST: caller state, ended membership, event and disposed basis exist.
    perform pg_temp.check_true(exists(select 1 from public.animales a
      join economics_v2.group_animal_acquisition_basis b on b.animal_id=a.id and b.granja_id=a.granja_id
      join economics_v2.group_occupancy_events e on e.id=b.disposed_event_id
      join economics_v2.group_occupancy_memberships m on m.id=e.membership_id
      where e.operation_id=new.operation_id and e.granja_id=new.granja_id and a.activo=false
        and a.baja_id is null and b.status='disposed' and b.remaining_basis=0
        and m.end_position=e.event_position),'final completion occurs after all authoritative writes');
    raise exception using errcode='P0001',message='F2DX injected final completion failure';
  end if;
  return new;
end;
$$;
create trigger f2dx_late_basis before update on economics_v2.group_animal_acquisition_basis
for each row execute function pg_temp.late_fault();
create trigger f2dx_late_completion before update on economics_v2.group_occupancy_operations
for each row execute function pg_temp.late_fault();

do $proof$
declare f record; r jsonb; z jsonb; repeated jsonb; baseline jsonb; before_seq jsonb;
  source_id uuid; member_id uuid; event_id uuid; position bigint; proc record; probe record;
  sql text; state text; message text; actor record; payload jsonb; prepared jsonb; source_zero uuid;
begin
  select * into f from pg_temp.ids;
  select value into payload from pg_temp.payload;
  select result into r from pg_temp.receipts where animal_id=f.animal_a;
  source_id:=(r->>'source_period_id')::uuid;
  position:=(r->>'event_position')::bigint;
  event_id:=(r->'membership_event_ids'->>0)::uuid;
  select id into member_id from economics_v2.group_occupancy_memberships
    where granja_id=f.farm_a and animal_id=f.animal_a;
  perform pg_temp.check_true((select array_agg(k order by k) from jsonb_object_keys(r) k)=array[
    'action','animal_id','basis_after','basis_before','basis_entry_ids','contract_version',
    'destination_period_id','destination_start_position','destination_status','effective_on','event_position',
    'membership_event_ids','operation_id','replayed','snapshot_id','source_end_position','source_period_id',
    'source_status','state_version'],'exact19 result keys');
  perform pg_temp.check_true(r=jsonb_build_object('contract_version','group-economics.forward.v3',
    'operation_id',f.operation_a,'action','exit','animal_id',f.animal_a,'source_period_id',source_id,
    'destination_period_id',null,'membership_event_ids',jsonb_build_array(event_id),'effective_on',current_date-1,
    'event_position',position,'source_end_position',position,'destination_start_position',null,
    'basis_entry_ids','[]'::jsonb,'basis_before',300,'basis_after',0,'source_status','open',
    'destination_status',null,'snapshot_id',null,'state_version',1,'replayed',false),'exact ordinary exit receipt');
  perform pg_temp.check_true(exists(select 1 from economics_v2.group_occupancy_events
    where id=event_id and granja_id=f.farm_a and animal_id=f.animal_a and period_id=source_id
      and membership_id=member_id and operation_id=f.operation_a and event_position=position
      and effective_on=current_date-1 and action='exit' and sale_id is null and basis_transfer_id is null
      and reason=economics_v2.canonical_group_request(payload)::text),'real immutable exit/versioned provenance');
  perform pg_temp.check_true(exists(select 1 from economics_v2.group_occupancy_memberships
    where id=member_id and end_position=position and start_position<position)
    and exists(select 1 from economics_v2.group_occupancy_periods
      where id=source_id and end_position is null and closed_on is null),
    'source_end_position ends membership, NOT period');
  perform pg_temp.check_true(exists(select 1 from economics_v2.group_animal_acquisition_basis b
    join pg_temp.captures c using(animal_id) where b.animal_id=f.animal_a
      and to_jsonb(b)=c.basis||jsonb_build_object('remaining_basis',0,'status','disposed',
        'current_account_kind','disposed','current_period_id',null,'disposed_event_id',event_id,'version',1))
    and exists(select 1 from public.animales where id=f.animal_a and activo=false
      and baja_id is null and costo_adquisicion=999),'disposed basis: exact delta; immutable captured300/timestamp');
  perform pg_temp.check_true(economics_v2.calculate_group_period_live_metrics(f.farm_a,source_id) @>
    '{"animal_count":2,"active_animal_count":1,"exited_animal_count":1,"acquisition_cost":300,"total_cost":300,"animal_sale_revenue":0,"sale_count":0}'::jsonb,
    'source live metrics retain realized300 and change active count only');
  prepared:=economics_v2.prepare_group_operation(f.farm_a,f.operation_a,jsonb_build_object(
    'action','exit','animal_id',f.animal_a,'source_period_id',source_id,'destination_group_id',null,
    'destination_purpose_id',null,'sale_id',null,'effective_on',current_date-1,'payload',payload));
  perform pg_temp.check_true(prepared->'result'=r||'{"replayed":true}'::jsonb
    and exists(select 1 from economics_v2.group_occupancy_operations where granja_id=f.farm_a
      and operation_id=f.operation_a and result=r and payload_hash=prepared->>'payload_hash'
      and event_position=position),'exact canonical8 request hash and completed ledger');

  sql:=format('select pg_temp.exit_gateway(%L,%L,%L,current_date-1,%L::jsonb)',
    f.farm_a,f.operation_a,f.animal_a,payload);
  repeated:=pg_temp.checked(sql);
  perform pg_temp.check_true(repeated=r||'{"replayed":true}'::jsonb,'replay while actually disposed');
  repeated:=pg_temp.checked(format('select pg_temp.exit_gateway(%L,%L,%L,current_date-1,%L::jsonb)',
    f.farm_a,f.operation_a,f.animal_a,jsonb_set(payload,'{metadata,reference}','1.00')));
  perform pg_temp.check_true(repeated=r||'{"replayed":true}'::jsonb,'numeric scale normalized, no basis charge');
  perform pg_temp.checked(format('select pg_temp.exit_gateway(%L,%L,%L,current_date-1,%L::jsonb)',
    f.farm_a,f.operation_a,f.animal_a,jsonb_set(payload,'{metadata,reference}','2')),
    '22023','operation_payload_conflict','operation_id');
  -- A later REAL initial entry changes source chronology, not disposed history.
  perform economics_v2.enter_group_meat_initial(f.farm_a,gen_random_uuid(),f.animal_unentered,
    current_date,f.group_a,f.meat,'{}');
  repeated:=pg_temp.checked(format('select pg_temp.exit_gateway(%L,%L,%L,%L::date,%L::jsonb)',
    f.farm_a,f.operation_a,f.animal_a,current_date-1,payload));
  perform pg_temp.check_true(repeated=r||'{"replayed":true}'::jsonb,'original source reconstructed on replay');

  -- Refusals must precede position issuance AND every business DML attempt.
  for probe in select * from (values
    (null::uuid,f.animal_zero,current_date,'22023','invalid_request','granja_id'),
    (f.farm_b,f.animal_zero,current_date,'42501','forbidden','granja_id'),
    (f.farm_a,f.animal_b,current_date,'42501','forbidden','animal_id'),
    (f.farm_a,gen_random_uuid(),current_date,'42501','forbidden','animal_id'),
    (f.farm_a,null::uuid,current_date,'22023','invalid_request','animal_id'),
    (f.farm_a,f.animal_zero,null::date,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_zero,'infinity'::date,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_zero,current_date+1,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_zero,current_date-5,'22023','invalid_request','effective_on'),
    (f.farm_a,f.animal_alone,current_date,'23514','period_close_unfinalized_facts','source_period_id'),
    (f.farm_a,f.animal_a,current_date,'23514','invariant_violation','animal_id'))
    v(farm,animal,effective_on,state,code,field) loop
    perform pg_temp.checked(format('select pg_temp.exit_gateway(%L::uuid,%L,%L::uuid,%L::date,%L::jsonb)',
      probe.farm,gen_random_uuid(),probe.animal,probe.effective_on,payload),probe.state,probe.code,probe.field);
  end loop;
  -- Direct core requires POST-DML inactive state, never authorizes animal CRUD itself.
  perform pg_temp.checked(format('select economics_v2.exit_group_meat_nonclosing(%L,%L,%L,current_date,%L::jsonb)',
    f.farm_a,gen_random_uuid(),f.animal_zero,payload),'23514','invariant_violation','animal_id');

  baseline:=pg_temp.business_state();
  for probe in select * from (values
    ('disabled',format('update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=%L',f.farm_a),'42501','forbidden','granja_id'),
    ('inactive',format('update public.animales set activo=false where id=%L',f.animal_zero),'23514','invariant_violation','animal_id'),
    ('foreign_group',format('update public.animales set grupo_id=%L where id=%L',f.group_b,f.animal_zero),'42501','forbidden','group_id'),
    ('type_mismatch',format('update public.grupos set tipo_animal_id=%L where id=%L',f.type_wrong,f.group_zero),'23514','invariant_violation','group_id'),
    ('foreign_purpose',format('update public.animales set proposito_id=%L where id=%L',f.purpose_b,f.animal_zero),'42501','forbidden','purpose_id'),
    ('purpose_mismatch',format('update public.animales set proposito_id=%L where id=%L',f.other_meat,f.animal_zero),'42501','forbidden','purpose_id'),
    ('nonmeat',format('update public.cat_proposito_animal set codigo_calculo=''postura'' where id=%L',f.meat),'22023','invalid_request','purpose_id'),
    ('basis_mismatch',format('update economics_v2.group_animal_acquisition_basis set remaining_basis=1 where animal_id=%L',f.animal_zero),'23514','invariant_violation','animal_id'))
    v(label,setup_sql,state,code,field) loop
    begin
      execute probe.setup_sql;
      perform pg_temp.checked(format('select pg_temp.exit_gateway(%L,%L,%L,current_date,%L::jsonb)',
        f.farm_a,gen_random_uuid(),f.animal_zero,payload),probe.state,probe.code,probe.field);
      raise exception using errcode='Z0001',message='F2DX restore isolated refusal';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'full refusal probe restored: '||probe.label);
  end loop;

  -- Incomplete ledger {}, not fabricated disposed/reactivation history.
  begin
    update economics_v2.group_occupancy_operations set result='{}'
      where granja_id=f.farm_a and operation_id=f.operation_a;
    perform pg_temp.checked(sql,'23514','invariant_violation','operation_id');
    raise exception using errcode='Z0001',message='F2DX restore incomplete receipt';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=baseline,'incomplete ledger fully restored');

  -- Independently test POST-DML rereads: validate/lock first, update the actual animal,
  -- then alter locked authoritative rows. No context JSON is submitted to the core.
  -- A core that trusts the gateway's earlier validation must fail these no-write probes.
  for probe in select * from (values
    ('post_type',format('update public.grupos set tipo_animal_id=%L where id=%L',f.type_wrong,f.group_zero),'23514','invariant_violation','group_id'),
    ('post_foreign_group',format('update public.animales set grupo_id=%L where id=%L',f.group_b,f.animal_zero),'42501','forbidden','group_id'),
    ('post_purpose',format('update public.animales set proposito_id=%L where id=%L',f.other_meat,f.animal_zero),'42501','forbidden','purpose_id'),
    ('post_basis',format('update economics_v2.group_animal_acquisition_basis set remaining_basis=1 where animal_id=%L',f.animal_zero),'23514','invariant_violation','animal_id'))
    v(label,setup_sql,state,code,field) loop
    begin
      perform economics_v2.validate_group_meat_nonclosing_source(f.farm_a,f.animal_zero,current_date);
      update public.animales set activo=false where id=f.animal_zero;
      execute probe.setup_sql;
      perform pg_temp.checked(format('select economics_v2.exit_group_meat_nonclosing(%L,%L,%L,current_date,%L::jsonb)',
        f.farm_a,gen_random_uuid(),f.animal_zero,payload),probe.state,probe.code,probe.field);
      raise exception using errcode='Z0001',message='F2DX restore post-DML probe';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'post-DML rows fully restored: '||probe.label);
  end loop;
  perform pg_temp.checked(format('select economics_v2.exit_group_meat_nonclosing(%L,%L,%L,current_date,%L::jsonb)',
    f.farm_a,gen_random_uuid(),f.animal_zero,jsonb_set(payload,'{disposition_kind}','"sale"')),
    '22023','invalid_request','payload');

  for actor in select * from (values
    (f.viewer_a,'authenticated'),(null::uuid,'anon'),(f.editor_a,'authenticated')) v(id,role_name) loop
    perform set_config('request.jwt.claim.sub',coalesce(actor.id::text,''),true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',actor.id,'role',actor.role_name)::text,true);
    execute format('set local role %I',actor.role_name);
    if actor.id=f.editor_a then
      perform pg_temp.checked(sql,'22023','operation_payload_conflict','operation_id');
    else
      perform pg_temp.checked(sql,'42501','forbidden','granja_id');
    end if;
    perform pg_temp.checked(format('select economics_v2.exit_group_meat_nonclosing(%L,%L,%L,current_date,%L::jsonb)',
      f.farm_a,f.operation_a,f.animal_a,payload),'42501');
    reset role;
  end loop;
  perform set_config('request.jwt.claim.sub',f.editor_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',f.editor_a,'role','authenticated')::text,true);

  -- Each late fault must roll back the gateway's animal UPDATE as well as every economics row.
  -- No expected exception may hide an earlier fault or a missing function.
  for probe in select * from (values('basis'),('completion')) v(kind) loop
    baseline:=pg_temp.business_state();
    before_seq:=pg_temp.position_state();
    state:=null;
    message:=null;
    perform set_config('f2dx.fault',probe.kind,true);
    begin
      perform pg_temp.exit_gateway(f.farm_a,f.operation_zero,f.animal_zero,current_date,payload);
    exception when others then
      get stacked diagnostics state=returned_sqlstate,message=message_text;
    end;
    perform set_config('f2dx.fault','off',true);
    perform pg_temp.check_true(state='P0001' and message=case when probe.kind='basis'
      then 'F2DX injected basis disposal failure' else 'F2DX injected final completion failure' end,
      'independent reached late fault: '||probe.kind);
    perform pg_temp.check_true(pg_temp.business_state()=baseline,'all10 plus public caller rows rollback: '||probe.kind);
    perform pg_temp.check_true((pg_temp.position_state()->>'last_value')::bigint>
      (before_seq->>'last_value')::bigint,'late fault issued a real position; gap retained: '||probe.kind);
    set constraints all immediate;
    set constraints all deferred;
  end loop;

  -- Actual EDITOR mutation under authenticated role, not merely editor validation/replay.
  set local role authenticated;
  z:=pg_temp.exit_gateway(f.farm_a,f.operation_zero,f.animal_zero,current_date,payload);
  reset role;
  source_zero:=(z->>'source_period_id')::uuid;
  perform pg_temp.check_true(z=jsonb_build_object('contract_version','group-economics.forward.v3',
    'operation_id',f.operation_zero,'action','exit','animal_id',f.animal_zero,'source_period_id',source_zero,
    'destination_period_id',null,'membership_event_ids',z->'membership_event_ids','effective_on',current_date,
    'event_position',z->'event_position','source_end_position',z->'event_position','destination_start_position',null,
    'basis_entry_ids','[]'::jsonb,'basis_before',0,'basis_after',0,'source_status','open',
    'destination_status',null,'snapshot_id',null,'state_version',1,'replayed',false)
    and jsonb_array_length(z->'membership_event_ids')=1,'zero exit exact19 values');
  perform pg_temp.check_true((select count(*)=19 from jsonb_object_keys(z))
    and z->>'action'='exit' and z->'basis_before'='0'::jsonb and z->'basis_after'='0'::jsonb
    and z->'basis_entry_ids'='[]'::jsonb and z->'state_version'='1'::jsonb
    and z->'source_status'='"open"'::jsonb and z->'replayed'='false'::jsonb,'real zero-basis editor exit');
  perform pg_temp.check_true(exists(select 1 from economics_v2.group_animal_acquisition_basis b
    join pg_temp.captures c using(animal_id) where b.animal_id=f.animal_zero
      and to_jsonb(b)=c.basis||jsonb_build_object('remaining_basis',0,'status','disposed',
        'current_account_kind','disposed','current_period_id',null,
        'disposed_event_id',(z->'membership_event_ids'->>0)::uuid,'version',1))
    and economics_v2.calculate_group_period_live_metrics(f.farm_a,source_zero) @>
      '{"animal_count":2,"active_animal_count":1,"exited_animal_count":1,"acquisition_cost":0}'::jsonb,
    'zero capture preserved and no group sum loss');
  perform pg_temp.check_true(exists(select 1 from economics_v2.group_occupancy_events e
    join economics_v2.group_occupancy_memberships m on m.id=e.membership_id
    where e.id=(z->'membership_event_ids'->>0)::uuid and e.granja_id=f.farm_a
      and e.animal_id=f.animal_zero and e.period_id=source_zero and e.operation_id=f.operation_zero
      and e.action='exit' and e.event_position=(z->>'event_position')::bigint and e.effective_on=current_date
      and e.sale_id is null and e.basis_transfer_id is null and m.end_position=e.event_position
      and e.reason=economics_v2.canonical_group_request(payload)::text),'zero exit real event and member end');

  select * into proc from pg_proc
    where oid='economics_v2.exit_group_meat_nonclosing(uuid,uuid,uuid,date,jsonb)'::regprocedure;
  perform pg_temp.check_true(proc.prorettype='jsonb'::regtype and not proc.prosecdef
    and proc.proconfig @> array['search_path=""']
    and not exists(select 1 from aclexplode(coalesce(proc.proacl,acldefault('f',proc.proowner))) acl
      where acl.grantee=0 and acl.privilege_type='EXECUTE')
    and not has_function_privilege('anon',proc.oid,'EXECUTE')
    and not has_function_privilege('authenticated',proc.oid,'EXECUTE'),'private invoker/empty path/PUBLIC grantee0 absent');
  perform pg_temp.checked('with attempt as (update public.animales set activo=activo where false returning id)
    select to_jsonb(attempt) from attempt','P0001');
  perform pg_temp.check_true((select count(*)=13 from pg_trigger where tgname='f2dx_no_write'),
    'all10 and authoritative animal/baja/sale statement blockers');
  set constraints all immediate;
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_occupancy_periods p
    where p.granja_id=f.farm_a and (p.end_position is not null or p.closed_on is not null
      or not exists(select 1 from economics_v2.group_occupancy_memberships m
        where m.period_id=p.id and m.end_position is null)))
    and not exists(select 1 from economics_v2.group_occupancy_memberships m
      join economics_v2.group_occupancy_periods p on p.id=m.period_id
      where m.granja_id=f.farm_a and not(m.position_span<@p.position_span)),
    'forced containment; all open periods remain nonempty');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_meat_snapshots where granja_id=f.farm_a)
    and not exists(select 1 from public.bajas_animales where granja_id=f.farm_a)
    and not exists(select 1 from public.venta_animal where granja_id=f.farm_a)
    and (select count(*)=2 from economics_v2.group_occupancy_events where granja_id=f.farm_a and action='exit')
    and not exists(select 1 from economics_v2.group_occupancy_events where granja_id=f.farm_a
      and action in('delete','reactivate')),'only two real ordinary exits; no other branch or F5 facts');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_acquisition_basis_entries b
    where b.granja_id=f.farm_a and b.operation_id in(f.operation_a,f.operation_zero))
    and (select sum(signed_amount)=300 from economics_v2.group_acquisition_basis_entries where granja_id=f.farm_a)
    and not exists(select 1 from pg_temp.original_entries o where not exists(
      select 1 from economics_v2.group_acquisition_basis_entries b where to_jsonb(b)=o.full_row)),
    'original signed entries unchanged; no exit entries/pairs/holding/recapture');
  perform pg_temp.check_true(not exists(select 1 from economics_v2.group_animal_acquisition_basis b
    join pg_temp.captures c using(animal_id) where b.animal_id not in(f.animal_a,f.animal_zero)
      and to_jsonb(b)<>c.basis),'all non-exiting captures fully unchanged');
end;
$proof$;

-- PASS is possible only after the real helper exists and the FULL runtime proof succeeds.
select jsonb_build_object('result','group_economics_forward_exit_disposition_pass',
  'assertion_count',(select count(*) from assertions),'locking_evidence','sequential_only',
  'production_gateway_integrated',false,'reactivation_proven',false,
  'fixture_ids',(select to_jsonb(ids) from ids)) as evidence;
rollback;
