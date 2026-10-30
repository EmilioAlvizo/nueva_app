begin;

-- HUMAN Sandbox only: run the FULL file, stop at the first error, then ROLLBACK.
-- Authoring only; expected first RED is uncaught 42883 at $first$'s named call.
-- This fixture does not implement, install, activate or proxy the new writer.
-- Scoped budget: fixture <=740 + future COMPLETE migration <=460 = <=1200.
-- Other units retain 800. Count complete definitions/ACL/comments, not just additions.
-- Forecast is not proof of fit; stop if the complete implementation exceeds reserve.
-- Required private contract: economics_v2.exit_group_meat_closing with exactly five
-- required arguments p_granja_id/p_operation_id/p_animal_id/p_effective_on/p_payload,
-- returns jsonb, VOLATILE SECURITY INVOKER, postgres owner, empty search_path.
-- Revoke EXECUTE from PUBLIC/anon/authenticated/service_role; no public wrapper.
-- SQL postgres STILL requires a real current owner/editor JWT and enabled flag.
-- Ordinary exit ONLY: writer receives ACTIVE animal and performs its deactivation.
-- Payload exact3: provenance_version=group-disposition-provenance.v1,
-- disposition_kind=ordinary_exit, metadata object. {} is NOT this provenance grammar.
-- Metadata is opaque provenance, never permission to sell/delete/reactivate/baja.
-- Hash envelope below freezes operation_domain=group-meat-closing-exit.v1 and
-- request action=ordinary_exit; do not reuse the nonclosing eight-field request.
-- Authorize before fresh/replay; exact receipt replay precedes mutable source checks.
-- Fresh READ COMMITTED: farm advisory, ordered Group/animals/history/period/basis,
-- membership, allocations/header/components/food/catalog, expense/sale facts and
-- existing scope fences. Re-read under locks; no context/token supplied by caller.
-- Exactly one active member, captured basis/entry/start-event lineage, same-farm
-- Group/type/meat purpose, finite nonfuture date >= every affected historical fact.
-- Check ALL relevant headers, including missing allocations; never infer capture by
-- date/Group. Exclude qualified closed H history from current-source obligations.
-- Validate each allocation with the existing pure inspector while OPEN/unfinalized.
-- This ordinary slice REFUSES relevant existing sale facts/bindings with
-- 23514/period_close_unfinalized_facts/source_period_id, including unbound sales.
-- This is NOT a permanent global saleless policy or an F4 sale producer.
-- Sale negatives use existing individual/legacy_batch rows, never an invented
-- record_kind=group or a claim that the unresolved Group-sale producer works.
-- Sequence: issue position/reserve ledger; deactivate; end membership; exit event;
-- dispose basis (no negative acquisition entry); inspect/finalize all feed; close
-- period at SAME exit boundary; calculate final17 metrics; insert actual v3 snapshot;
-- verify final storage; complete business receipt LAST. No COMMIT/swallowed failure.
-- Caller forces deferred constraints; writer need not change global constraint mode.
-- Real sequential evidence only: no HTTP/concurrency/production/public CRUD proof.

create temp table ids as select gen_random_uuid() owner_a,gen_random_uuid() owner_b,
  gen_random_uuid() editor_a,gen_random_uuid() viewer_a,gen_random_uuid() outsider,
  gen_random_uuid() farm_a,gen_random_uuid() farm_b,gen_random_uuid() type_a,
  gen_random_uuid() type_b,gen_random_uuid() wrong_type,gen_random_uuid() meat,
  gen_random_uuid() other_meat,gen_random_uuid() eggs,gen_random_uuid() foreign_purpose,
  gen_random_uuid() category,gen_random_uuid() foreign_group,gen_random_uuid() egg_group;
create temp table scenarios as select label,gen_random_uuid() group_id,
  gen_random_uuid() animal_id,gen_random_uuid() operation_id,gen_random_uuid() mixture_a,
  gen_random_uuid() mixture_b,null::uuid period_id
from (values('owner'),('editor'),('nonlast')) s(label);
create temp table controls as select gen_random_uuid() foreign_animal,
  gen_random_uuid() egg_animal,gen_random_uuid() anchor_animal;
create temp table payload as select
  '{"provenance_version":"group-disposition-provenance.v1","disposition_kind":"ordinary_exit","metadata":{"reference":1}}'::jsonb value;
create temp table assertions(label text not null);
create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
create function pg_temp.jwt(p_actor uuid,p_role text default 'authenticated')
returns void language plpgsql security invoker set search_path='' as $$
begin
  perform set_config('request.jwt.claim.sub',coalesce(p_actor::text,''),true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',p_actor,'role',p_role)::text,true);
end;
$$;
insert into auth.users(id,aud,role,raw_user_meta_data)
select u,'authenticated','authenticated',jsonb_build_object('fixture','closing-exit','tag',farm_a)
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a,outsider]) u;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Closing exit A '||farm_a,owner_a from ids
union all select farm_b,owner_b,'Closing exit B '||farm_b,owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select t,farm_a,'Closing type '||t,owner_a from ids
cross join lateral unnest(array[type_a,wrong_type]) t
union all select type_b,farm_b,'Foreign type',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select p,farm_a,'Closing purpose '||p,case when p=eggs then 'postura' else 'carne' end,owner_a
from ids cross join lateral unnest(array[meat,other_meat,eggs]) p
union all select foreign_purpose,farm_b,'Foreign purpose','carne',owner_b from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select s.group_id,f.farm_a,f.type_a,'Closing Group '||s.label,f.owner_a from scenarios s cross join ids f
union all select egg_group,farm_a,type_a,'Egg control',owner_a from ids
union all select foreign_group,farm_b,type_b,'Foreign control',owner_b from ids;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select category,farm_a,'Closing ingredient',true,owner_a from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,created_by)
select s.animal_id,f.farm_a,f.type_a,s.group_id,f.meat,current_date-4,300,f.owner_a
from scenarios s cross join ids f
union all select c.anchor_animal,f.farm_a,f.type_a,s.group_id,f.meat,current_date-4,0,f.owner_a
from controls c cross join ids f cross join scenarios s where s.label='nonlast'
union all select c.egg_animal,f.farm_a,f.type_a,f.egg_group,f.eggs,current_date-4,7,f.owner_a
from controls c cross join ids f
union all select c.foreign_animal,f.farm_b,f.type_b,f.foreign_group,f.foreign_purpose,current_date-4,9,f.owner_b
from controls c cross join ids f;
select pg_temp.jwt(owner_a) from ids;
create temp table admissions as select s.label,economics_v2.enter_group_meat_initial(
  f.farm_a,gen_random_uuid(),s.animal_id,current_date-4,s.group_id,f.meat,'{}') result
from scenarios s cross join ids f;
update scenarios s set period_id=(a.result->>'destination_period_id')::uuid from admissions a where a.label=s.label;
select economics_v2.enter_group_meat_initial(f.farm_a,gen_random_uuid(),c.anchor_animal,
  current_date-4,s.group_id,f.meat,'{}') from ids f cross join controls c cross join scenarios s where s.label='nonlast';
do $access$
begin
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$access$;
grant select on pg_temp.ids,pg_temp.scenarios to authenticated;
create temp table producer_receipts(kind text,scenario text,result jsonb);
grant insert on pg_temp.producer_receipts to authenticated;
set local role authenticated;
insert into pg_temp.producer_receipts select 'feed',s.label,public.crear_mezcla_grupo_v1(
  p_granja_id=>f.farm_a,p_operation_id=>gen_random_uuid(),p_period_id=>s.period_id,
  p_mezcla_id=>v.mixture,p_fecha_inicio=>current_date-v.days_ago,p_grupo_id=>s.group_id,
  p_ingredientes=>jsonb_build_array(jsonb_build_object('categoria_id',f.category,
    'cantidad_kg',v.kg,'costo_total',v.cost)))
from pg_temp.scenarios s cross join pg_temp.ids f
cross join lateral (values(s.mixture_a,3,1,40),(s.mixture_b,2,2,60)) v(mixture,days_ago,kg,cost)
where s.label in ('owner','editor');
insert into pg_temp.producer_receipts select 'expense',s.label,public.create_group_finance_expense_v1(
  p_granja_id=>f.farm_a,p_operation_id=>gen_random_uuid(),p_period_id=>s.period_id,
  p_occurred_on=>current_date-1,p_amount=>50,p_category=>'care',p_note=>'Closing exit fixture')
from pg_temp.scenarios s cross join pg_temp.ids f where s.label in ('owner','editor');
reset role;
set constraints all immediate;
set constraints all deferred;
create temp table originals(kind text,id uuid,value jsonb);
insert into originals select 'animal',id,to_jsonb(a) from public.animales a
where granja_id in(select farm_a from ids union all select farm_b from ids);
insert into originals select 'basis',animal_id,to_jsonb(b) from economics_v2.group_animal_acquisition_basis b
where granja_id=(select farm_a from ids);
insert into originals select 'entry',id,to_jsonb(e) from economics_v2.group_acquisition_basis_entries e
where granja_id=(select farm_a from ids);
insert into originals select 'allocation',id,to_jsonb(a) from economics_v2.group_period_feed_allocations a
where granja_id=(select farm_a from ids);
insert into originals select 'period',id,to_jsonb(p) from economics_v2.group_occupancy_periods p
where granja_id=(select farm_a from ids);
insert into originals select 'member',id,to_jsonb(m) from economics_v2.group_occupancy_memberships m
where granja_id=(select farm_a from ids);
create temp table expected_metrics as select
  '{"animal_count":1,"active_animal_count":0,"exited_animal_count":1,"sold_animal_count":0,"feed_source_count":2,"feed_kg_total":3,"feed_cost":100,"acquisition_cost":300,"direct_expense_total":50,"sale_count":0,"saleable_kg":0,"animal_sale_revenue":0,"total_cost":450,"profit":-450,"realized_price_per_kg":null,"break_even_kg":null,"balance_per_animal":-450}'::jsonb value;
create temp table receipts(label text,result jsonb);
create temp table retained_gaps(stage text,before_position bigint,after_position bigint);

-- Whole business schemas, including legacy/egg controls, source rows and fences.
-- Run in an isolated Sandbox: unrelated concurrent traffic invalidates comparisons.
create temp table watched as select n.nspname schema_name,c.relname table_name
from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind in ('r','p')
and (n.nspname in ('public','economics_v2','group_feed_integrity') or (n.nspname='auth' and c.relname='users'));
create temp table watched_sequences as select n.nspname schema_name,c.relname sequence_name
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity');
create temp sequence attempted_dml;
create function pg_temp.sequence_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; v jsonb; r jsonb:='{}';
begin
  for t in select * from pg_temp.watched_sequences order by schema_name,sequence_name loop
    execute format('select jsonb_build_object(''last_value'',last_value,''log_cnt'',log_cnt,''is_called'',is_called) from %I.%I',
      t.schema_name,t.sequence_name) into v;
    r:=r||jsonb_build_object(t.schema_name||'.'||t.sequence_name,v);
  end loop;
  return r;
end;
$$;
create function pg_temp.business_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; v jsonb; r jsonb:='{}';
begin
  for t in select * from pg_temp.watched order by schema_name,table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),''[]''::jsonb) from %I.%I r',
      t.schema_name,t.table_name) into v;
    r:=r||jsonb_build_object(t.schema_name||'.'||t.table_name,v);
  end loop;
  return r;
end;
$$;
create function pg_temp.observe_dml()
returns trigger language plpgsql set search_path='' as $$
begin
  if current_setting('closing_exit.observe',true)='on' then
    perform nextval('pg_temp.attempted_dml'::regclass);
    raise exception using errcode='P0001',message='Closing exit attempted forbidden DML';
  end if;
  return null;
end;
$$;
do $observers$
declare t record;
begin
  for t in select * from pg_temp.watched loop
    execute format('create trigger closing_exit_observer before insert or update or delete or truncate on %I.%I
      for each statement execute function pg_temp.observe_dml()',t.schema_name,t.table_name);
  end loop;
end;
$observers$;
create function pg_temp.checked(p_sql text,p_state text default null,p_code text default null,
  p_field text default null,p_entity uuid default null)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare b jsonb; q jsonb; a jsonb; r jsonb; st text; d text;
begin
  b:=pg_temp.business_state(); q:=pg_temp.sequence_state();
  select jsonb_build_object('last_value',last_value,'log_cnt',log_cnt,'is_called',is_called) into a from pg_temp.attempted_dml;
  perform set_config('closing_exit.observe','on',true);
  begin execute p_sql into r;
  exception when others then
    if p_state is null then raise; end if;
    get stacked diagnostics st=returned_sqlstate,d=pg_exception_detail;
  end;
  perform set_config('closing_exit.observe','off',true);
  perform pg_temp.check_true(pg_temp.business_state()=b and pg_temp.sequence_state()=q,'refusal/replay preserves every row and business sequence');
  perform pg_temp.check_true((select jsonb_build_object('last_value',last_value,'log_cnt',log_cnt,'is_called',is_called)
    from pg_temp.attempted_dml)=a,'no zero-row or swallowed DML attempts');
  if p_state is null then
    perform pg_temp.check_true(r is not null,'nonempty replay receipt');
  else
    perform pg_temp.check_true(st=p_state,'expected SQLSTATE '||p_state||': '||p_sql);
    if p_code is not null then
      perform pg_temp.check_true(d::jsonb=jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',p_code,'field',p_field,'entity_id',p_entity),'exact4 typed error DETAIL');
    end if;
  end if;
  return r;
end;
$$;
grant usage,select on sequence pg_temp.attempted_dml to authenticated,anon;
grant insert on pg_temp.assertions to authenticated,anon;
revoke all on function pg_temp.business_state(),pg_temp.sequence_state(),
  pg_temp.checked(text,text,text,text,uuid),pg_temp.check_true(boolean,text) from public;
grant execute on function pg_temp.business_state(),pg_temp.sequence_state(),
  pg_temp.checked(text,text,text,text,uuid),pg_temp.check_true(boolean,text) to authenticated,anon;

create temp table initial_state as select pg_temp.business_state() business_rows,pg_temp.sequence_state() sequences;
do $first$
declare f record; s record; r jsonb; q jsonb;
begin
  select * into f from pg_temp.ids;
  select * into s from pg_temp.scenarios where label='owner';
  perform pg_temp.check_true(exists(select 1 from public.animales where id=s.animal_id and activo is true)
    and (select count(*)=1 from economics_v2.group_occupancy_memberships where period_id=s.period_id and end_position is null)
    and (select count(*)=2 and bool_and(finalized_at is null) from economics_v2.group_period_feed_allocations where period_id=s.period_id)
    and (select count(*)=2 and bool_and(fecha_termino is null) from public.mezcla where id in(s.mixture_a,s.mixture_b))
    and not exists(select 1 from economics_v2.group_meat_snapshots where period_id=s.period_id),'real ACTIVE last-member setup, two unfinalized sources');
  -- FIRST new-function reference: no cast, wrapper, exception catcher or admin exit.
  r:=economics_v2.exit_group_meat_closing(p_granja_id=>f.farm_a,p_operation_id=>s.operation_id,
    p_animal_id=>s.animal_id,p_effective_on=>current_date,p_payload=>(select value from pg_temp.payload));
  insert into pg_temp.receipts values('owner',r);
  q:=(select sequences from pg_temp.initial_state);
  perform pg_temp.check_true(pg_temp.sequence_state()-'economics_v2.group_economics_event_position_seq'
    =q-'economics_v2.group_economics_event_position_seq'
    and (r->>'event_position')::bigint=(q->'economics_v2.group_economics_event_position_seq'->>'last_value')::bigint+1
    and (pg_temp.sequence_state()->'economics_v2.group_economics_event_position_seq'->>'last_value')::bigint=(r->>'event_position')::bigint,
    'first real close issues exactly one exit position and no other sequence');
end;
$first$;
set constraints all immediate;
set constraints all deferred;

-- A shared assertion helper only OBSERVES actual producer output. Literal450 is the
-- independent oracle; the live calculator is an additional comparison, not its source.
create function pg_temp.verify_close(p_label text,p_result jsonb,p_actor uuid)
returns void language plpgsql security invoker set search_path='' as $$
declare f record; s record; e uuid; pos bigint; snap economics_v2.group_meat_snapshots%rowtype;
  expected jsonb; card jsonb; h text;
begin
  select * into f from pg_temp.ids;
  select * into s from pg_temp.scenarios where label=p_label;
  e:=(p_result->'membership_event_ids'->>0)::uuid; pos:=(p_result->>'event_position')::bigint;
  select * into snap from economics_v2.group_meat_snapshots where period_id=s.period_id;
  perform pg_temp.check_true(found and snap.id=(p_result->>'snapshot_id')::uuid
    and snap.granja_id=f.farm_a and snap.snapshot_version='group-meat-snapshot.forward.v3'
    and isfinite(snap.created_at) and (select count(*)=1 from economics_v2.group_meat_snapshots where period_id=s.period_id),'actual unique v3 snapshot identity');
  expected:=jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',s.operation_id,
    'action','exit','animal_id',s.animal_id,'source_period_id',s.period_id,'destination_period_id',null,
    'membership_event_ids',jsonb_build_array(e),'effective_on',current_date,'event_position',pos,
    'source_end_position',pos,'destination_start_position',null,'basis_entry_ids','[]'::jsonb,
    'basis_before',300,'basis_after',0,'source_status','closed','destination_status',null,
    'snapshot_id',snap.id,'state_version',1,'replayed',false);
  perform pg_temp.check_true(p_result=expected and (select count(*)=19 from jsonb_object_keys(p_result)),'exact19 closing transition receipt');
  perform pg_temp.check_true(exists(select 1 from public.animales a join pg_temp.originals o on o.kind='animal' and o.id=a.id
    where a.id=s.animal_id and to_jsonb(a)-'updated_at'=(o.value||'{"activo":false}'::jsonb)-'updated_at' and a.baja_id is null)
    and exists(select 1 from economics_v2.group_occupancy_memberships m join pg_temp.originals o on o.kind='member' and o.id=m.id
      where m.animal_id=s.animal_id and to_jsonb(m)=o.value||jsonb_build_object('end_position',pos,'position_span',int8range(m.start_position,pos,'[)')))
    and exists(select 1 from economics_v2.group_occupancy_events ev join economics_v2.group_occupancy_memberships m on m.id=ev.membership_id
      where ev.id=e and ev.granja_id=f.farm_a and ev.animal_id=s.animal_id and ev.period_id=s.period_id
        and ev.operation_id=s.operation_id and ev.action='exit' and ev.event_position=pos and pos>m.start_position
        and m.end_position=pos and ev.effective_on=current_date and ev.sale_id is null and ev.basis_transfer_id is null
        and ev.reason=economics_v2.canonical_group_request((select value from pg_temp.payload))::text),'actual deactivation, ended membership, immutable ordinary exit provenance');
  perform pg_temp.check_true(exists(select 1 from economics_v2.group_animal_acquisition_basis b
    join pg_temp.originals o on o.kind='basis' and o.id=b.animal_id where b.animal_id=s.animal_id
    and to_jsonb(b)=o.value||jsonb_build_object('remaining_basis',0,'status','disposed','current_account_kind','disposed',
      'current_period_id',null,'disposed_event_id',e,'version',1)),'exact disposed basis delta retains captured300');
  perform pg_temp.check_true(exists(select 1 from economics_v2.group_occupancy_periods p
    join pg_temp.originals o on o.kind='period' and o.id=p.id where p.id=s.period_id
      and to_jsonb(p)=o.value||jsonb_build_object('closed_on',current_date,'end_position',pos,'position_span',int8range(p.start_position,pos,'[)')))
    and not exists(select 1 from economics_v2.group_occupancy_memberships where period_id=s.period_id and end_position is null),'same exit boundary closes original period without changing start identity');
  perform pg_temp.check_true((select count(*)=2 and bool_and(a.finalized_at is not null and isfinite(a.finalized_at)
    and to_jsonb(a)-'finalized_at'-'updated_at'=o.value-'finalized_at'-'updated_at')
    from economics_v2.group_period_feed_allocations a join pg_temp.originals o on o.kind='allocation' and o.id=a.id
    where a.period_id=s.period_id),'both real feed allocations finalized, source fields unchanged');
  perform pg_temp.check_true(snap.payload->'metrics'=(select value from pg_temp.expected_metrics)
    and (select count(*)=17 from jsonb_object_keys(snap.payload->'metrics'))
    and snap.payload->>'group_name'='Closing Group '||s.label and snap.payload->>'purpose_code'='carne'
    and economics_v2.calculate_group_period_live_metrics(f.farm_a,s.period_id)=snap.payload->'metrics','literal17 final metrics: acquisition300 + feed100 + expense50 =450; no sales/null ratios');
  h:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-meat-closing-exit.v1',
    'granja_id',f.farm_a,'actor_id',p_actor,'operation_id',s.operation_id,'request',jsonb_build_object(
      'action','ordinary_exit','animal_id',s.animal_id,'effective_on',current_date,'payload',(select value from pg_temp.payload))))::text,'UTF8')),'hex');
  perform pg_temp.check_true(exists(select 1 from economics_v2.group_occupancy_operations where granja_id=f.farm_a
    and operation_id=s.operation_id and result=expected and event_position=pos and payload_hash=h),'actual actor/domain-bound canonical completed ledger');
  select item into card from jsonb_array_elements(economics_v2.list_group_economics_impl(f.farm_a,50,null,null,null)->'items') item
    where item->>'period_id'=s.period_id::text;
  perform pg_temp.check_true(card->>'status'='closed' and card->>'metrics_source'='snapshot'
    and card->>'snapshot_id'=snap.id::text and card->'metrics'=snap.payload->'metrics'
    and card->'group_name'=snap.payload->'group_name','CLOSED reader uses actual frozen snapshot, not live fallback');
end;
$$;
select pg_temp.verify_close('owner',r.result,f.owner_a) from receipts r cross join ids f where r.label='owner';

-- Fault hooks are AFTER actual storage, not BEFORE promises. Each has an exact
-- unique SQLSTATE/message; a preceding guard/missing helper cannot masquerade as it.
create function pg_temp.late_fault()
returns trigger language plpgsql security invoker set search_path='' as $$
declare mode text:=current_setting('closing_exit.fault',true); s record; pos bigint; ev uuid; complete boolean;
begin
  if mode is null or mode='off' then return null; end if;
  select * into s from pg_temp.scenarios where label='editor';
  if (tg_table_name='group_period_feed_allocations' and mode<>'feed')
    or (tg_table_name='group_occupancy_periods' and mode<>'period')
    or (tg_table_name='group_meat_snapshots' and mode<>'snapshot')
    or (tg_table_name='group_occupancy_operations' and mode<>'completion') then return null; end if;
  if tg_table_name='group_occupancy_operations' then
    if new.operation_id<>s.operation_id or not(new.result ? 'snapshot_id') then return null; end if;
  elsif tg_table_name='group_occupancy_periods' then
    if new.id<>s.period_id then return null; end if;
  elsif new.period_id<>s.period_id then return null;
  end if;
  select event_position,id into pos,ev from economics_v2.group_occupancy_events where operation_id=s.operation_id and action='exit';
  perform pg_temp.check_true(pos is not null and exists(select 1 from public.animales where id=s.animal_id and activo=false and baja_id is null)
    and exists(select 1 from economics_v2.group_occupancy_memberships where animal_id=s.animal_id and end_position=pos)
    and exists(select 1 from economics_v2.group_animal_acquisition_basis where animal_id=s.animal_id and status='disposed'
      and remaining_basis=0 and disposed_event_id=ev),'late fault observes actual animal/member/event/basis');
  if mode='feed' then
    perform pg_temp.check_true(old.finalized_at is null and exists(select 1 from economics_v2.group_period_feed_allocations
      where id=new.id and finalized_at is not null and isfinite(finalized_at))
      and exists(select 1 from economics_v2.group_occupancy_periods where id=s.period_id and end_position is null and closed_on is null)
      and not exists(select 1 from economics_v2.group_meat_snapshots where period_id=s.period_id),'feed fault reached actual finalization while OPEN');
  else
    perform pg_temp.check_true((select count(*)=2 and bool_and(finalized_at is not null) from economics_v2.group_period_feed_allocations where period_id=s.period_id)
      and exists(select 1 from economics_v2.group_occupancy_periods where id=s.period_id and end_position=pos and closed_on=current_date),'late stage observes all feed finalized and actual closing bounds');
    if mode='period' then
      perform pg_temp.check_true(not exists(select 1 from economics_v2.group_meat_snapshots where period_id=s.period_id),'period fault precedes snapshot');
    else
      perform pg_temp.check_true(exists(select 1 from economics_v2.group_meat_snapshots where period_id=s.period_id
        and snapshot_version='group-meat-snapshot.forward.v3' and payload->>'group_name'='Closing Group editor'
        and payload->>'purpose_code'='carne' and payload->'metrics'=(select value from pg_temp.expected_metrics)),
        'late stage observes actual persisted v3 snapshot450 and label/purpose audit');
    end if;
  end if;
  select result ? 'snapshot_id' into complete from economics_v2.group_occupancy_operations where operation_id=s.operation_id;
  if mode='completion' then
    perform pg_temp.check_true(complete is true,'completion hook observes actual persisted completed ledger');
    perform pg_temp.verify_close('editor',new.result,(select editor_a from pg_temp.ids));
  else
    perform pg_temp.check_true(complete is distinct from true,'business receipt is not completed before final stage');
  end if;
  raise exception using errcode='ZC001',message='Closing exit reached late fault: '||mode;
end;
$$;
create trigger closing_exit_feed_fault after update on economics_v2.group_period_feed_allocations
for each row execute function pg_temp.late_fault();
create trigger closing_exit_period_fault after update on economics_v2.group_occupancy_periods
for each row execute function pg_temp.late_fault();
create trigger closing_exit_snapshot_fault after insert on economics_v2.group_meat_snapshots
for each row execute function pg_temp.late_fault();
create trigger closing_exit_completion_fault after insert or update on economics_v2.group_occupancy_operations
for each row execute function pg_temp.late_fault();

do $proof$
declare f record; s record; o record; n record; c record; p record; proc record;
  sql text; original_sql text; body jsonb; r jsonb; b jsonb; q jsonb; st text; msg text;
  allocation uuid; food uuid; fault text;
begin
  select * into f from pg_temp.ids;
  select * into s from pg_temp.scenarios where label='editor';
  select * into o from pg_temp.scenarios where label='owner';
  select * into n from pg_temp.scenarios where label='nonlast';
  select * into c from pg_temp.controls;
  select value into body from pg_temp.payload;
  select id into allocation from economics_v2.group_period_feed_allocations where mixture_id=s.mixture_a;
  select comida_id into food from public.mezcla_comida where mezcla_id=s.mixture_a;
  sql:=format('select economics_v2.exit_group_meat_closing(%L,%L,%L,current_date,%L::jsonb)',f.farm_a,s.operation_id,s.animal_id,body);
  original_sql:=format('select economics_v2.exit_group_meat_closing(%L,%L,%L,current_date,%L::jsonb)',f.farm_a,o.operation_id,o.animal_id,body);
  r:=pg_temp.checked(original_sql);
  perform pg_temp.check_true(r=(select result||'{"replayed":true}'::jsonb from pg_temp.receipts where label='owner'),'replay after real closure/inactivity returns original receipt');
  perform pg_temp.check_true(pg_temp.checked(format('select economics_v2.exit_group_meat_closing(%L,%L,%L,current_date,%L::jsonb)',
    f.farm_a,o.operation_id,o.animal_id,jsonb_set(body,'{metadata,reference}','1.00')))=r,'canonical numeric-scale replay');
  perform pg_temp.checked(format('select economics_v2.exit_group_meat_closing(%L,%L,%L,current_date,%L::jsonb)',
    f.farm_a,o.operation_id,o.animal_id,jsonb_set(body,'{metadata,reference}','2')),'22023','operation_payload_conflict','operation_id',o.operation_id);
  for p in select unnest(array[f.viewer_a,f.outsider,f.owner_b]) actor loop
    perform pg_temp.jwt(p.actor);
    perform pg_temp.checked(sql,'42501','forbidden','granja_id',f.farm_a);
    perform pg_temp.checked(original_sql,'42501','forbidden','granja_id',f.farm_a);
  end loop;
  perform pg_temp.jwt(f.editor_a);
  perform pg_temp.checked(original_sql,'22023','operation_payload_conflict','operation_id',o.operation_id);
  perform pg_temp.jwt(null,'anon');
  perform pg_temp.checked(sql,'42501','forbidden','granja_id',f.farm_a);
  perform pg_temp.jwt(f.owner_a);
  perform pg_temp.checked(format('select economics_v2.exit_group_meat_closing(%L,null::uuid,%L,current_date,%L::jsonb)',
    f.farm_a,s.animal_id,body),'22023','invalid_request','operation_id',null);
  for p in select * from (values(f.owner_a,'authenticated'),(f.editor_a,'authenticated'),(null::uuid,'anon')) a(actor,role_name) loop
    perform pg_temp.jwt(p.actor,p.role_name);
    execute format('set local role %I',p.role_name);
    perform pg_temp.checked(sql,'42501');
    reset role;
  end loop;
  perform pg_temp.jwt(f.owner_a);
  for p in select * from (values
    (null::uuid,s.animal_id,current_date,'22023','invalid_request','granja_id',null::uuid),
    (f.farm_b,s.animal_id,current_date,'42501','forbidden','granja_id',f.farm_b),
    (f.farm_a,c.foreign_animal,current_date,'42501','forbidden','animal_id',c.foreign_animal),
    (f.farm_a,c.egg_animal,current_date,'23514','invariant_violation','animal_id',c.egg_animal),
    (f.farm_a,null::uuid,current_date,'22023','invalid_request','animal_id',null::uuid),
    (f.farm_a,s.animal_id,null::date,'22023','invalid_request','effective_on',s.animal_id),
    (f.farm_a,s.animal_id,'infinity'::date,'22023','invalid_request','effective_on',s.animal_id),
    (f.farm_a,s.animal_id,current_date+1,'22023','invalid_request','effective_on',s.animal_id),
    (f.farm_a,s.animal_id,current_date-5,'22023','invalid_request','effective_on',s.animal_id),
    (f.farm_a,s.animal_id,current_date-2,'22023','invalid_request','effective_on',s.animal_id),
    (f.farm_a,n.animal_id,current_date,'23514','period_close_unfinalized_facts','source_period_id',n.period_id),
    (f.farm_a,o.animal_id,current_date,'23514','invariant_violation','animal_id',o.animal_id))
    v(farm,animal,day,state,code,field,entity) loop
    perform pg_temp.checked(format('select economics_v2.exit_group_meat_closing(%L::uuid,%L,%L::uuid,%L::date,%L::jsonb)',
      p.farm,gen_random_uuid(),p.animal,p.day,body),p.state,p.code,p.field,p.entity);
  end loop;
  for p in select v from (values('{}'::jsonb),('[]'::jsonb),('null'::jsonb),
    (jsonb_set(body,'{disposition_kind}','"sale"')),(jsonb_set(body,'{disposition_kind}','"baja"')),
    (jsonb_set(body,'{disposition_kind}','"delete"')),(jsonb_set(body,'{disposition_kind}','"reactivate"')),
    (body||'{"authority":true}'::jsonb)) x(v) loop
    perform pg_temp.checked(format('select economics_v2.exit_group_meat_closing(%L,%L,%L,current_date,%L::jsonb)',
      f.farm_a,gen_random_uuid(),s.animal_id,p.v),'22023','invalid_request','payload',s.animal_id);
  end loop;
  -- Every mutation is isolated and uses installed admin permissions, not bypassed
  -- constraints/triggers. Observer is enabled ONLY around the actual refusal.
  for p in select * from (values
    ('disabled','42501','forbidden','granja_id',f.farm_a),
    ('inactive','23514','invariant_violation','animal_id',s.animal_id),
    ('foreign_group','42501','forbidden','group_id',f.foreign_group),
    ('null_group','42501','forbidden','group_id',null::uuid),
    ('wrong_type','23514','invariant_violation','group_id',s.group_id),
    ('foreign_purpose','42501','forbidden','purpose_id',f.foreign_purpose),
    ('null_purpose','42501','forbidden','purpose_id',null::uuid),
    ('other_purpose','42501','forbidden','purpose_id',f.other_meat),
    ('nonmeat','22023','invalid_request','purpose_id',f.meat),
    ('missing_basis','23514','invariant_violation','animal_id',s.animal_id),
    ('missing_entry','23514','invariant_violation','animal_id',s.animal_id),
    ('start_lineage','23514','invariant_violation','animal_id',s.animal_id),
    ('basis_drift','23514','invariant_violation','animal_id',s.animal_id),
    ('missing_allocation','23514','period_close_unfinalized_facts','source_period_id',s.period_id),
    ('wrong_allocation_period','23514','period_close_unfinalized_facts','source_period_id',s.period_id),
    ('digest','23514','invariant_violation','allocation_id',allocation),
    ('cost','23514','invariant_violation','allocation_id',allocation),
    ('version','23514','invariant_violation','allocation_id',allocation),
    ('source_cost','23514','invariant_violation','allocation_id',allocation),
    ('source_kg','23514','invariant_violation','allocation_id',allocation),
    ('missing_price','23514','invariant_violation','mixture_id',s.mixture_a),
    ('foreign_food','42501','forbidden','food_id',food),
    ('empty_source','23514','invariant_violation','mixture_id',s.mixture_a),
    ('prefinalized','23514','invariant_violation','allocation_id',allocation),
    ('expense_date','23514','period_close_unfinalized_facts','source_period_id',s.period_id),
    ('unbound_sale','23514','period_close_unfinalized_facts','source_period_id',s.period_id),
    ('group_sale','23514','period_close_unfinalized_facts','source_period_id',s.period_id),
    ('bound_sale','23514','period_close_unfinalized_facts','source_period_id',s.period_id))
    v(mode,state,code,field,entity) loop
    b:=pg_temp.business_state(); q:=pg_temp.sequence_state();
    begin
      case p.mode
        when 'disabled' then update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=f.farm_a;
        when 'inactive' then update public.animales set activo=false where id=s.animal_id;
        when 'foreign_group' then update public.animales set grupo_id=f.foreign_group where id=s.animal_id;
        when 'null_group' then update public.animales set grupo_id=null where id=s.animal_id;
        when 'wrong_type' then update public.grupos set tipo_animal_id=f.wrong_type where id=s.group_id;
        when 'foreign_purpose' then update public.animales set proposito_id=f.foreign_purpose where id=s.animal_id;
        when 'null_purpose' then update public.animales set proposito_id=null where id=s.animal_id;
        when 'other_purpose' then update public.animales set proposito_id=f.other_meat where id=s.animal_id;
        when 'nonmeat' then update public.animales set proposito_id=f.eggs where id=s.animal_id;
        when 'missing_basis' then
          delete from economics_v2.group_acquisition_basis_entries where animal_id=s.animal_id;
          delete from economics_v2.group_animal_acquisition_basis where animal_id=s.animal_id;
        when 'missing_entry' then delete from economics_v2.group_acquisition_basis_entries where animal_id=s.animal_id;
        when 'start_lineage' then update economics_v2.group_occupancy_memberships set start_position=start_position+1 where animal_id=s.animal_id;
        when 'basis_drift' then update economics_v2.group_animal_acquisition_basis set remaining_basis=299 where animal_id=s.animal_id;
        when 'missing_allocation' then delete from economics_v2.group_period_feed_allocations where id=allocation;
        when 'wrong_allocation_period' then update economics_v2.group_period_feed_allocations set period_id=n.period_id where id=allocation;
        when 'digest' then update economics_v2.group_period_feed_allocations set source_digest=repeat('0',64) where id=allocation;
        when 'cost' then update economics_v2.group_period_feed_allocations set total_cost=41 where id=allocation;
        when 'version' then update economics_v2.group_period_feed_allocations set source_updated_at=source_updated_at+interval '1 second' where id=allocation;
        when 'source_cost' then update public.comida set precio=41 where id=food;
        when 'source_kg' then update public.mezcla_comida set cantidad=2 where mezcla_id=s.mixture_a;
        when 'missing_price' then update public.comida set precio=null where id=food;
        when 'foreign_food' then update public.comida set granja_id=f.farm_b where id=food;
        when 'empty_source' then delete from public.mezcla_comida where mezcla_id=s.mixture_a;
        when 'prefinalized' then update economics_v2.group_period_feed_allocations set finalized_at=clock_timestamp() where id=allocation;
        when 'expense_date' then update economics_v2.group_period_expenses set occurred_on=current_date-5 where period_id=s.period_id;
        when 'group_sale' then
          insert into public.venta_animal(granja_id,grupo_id,tipo_animal_id,animal_id,fecha_venta,record_kind,quantity,total_amount)
          values(f.farm_a,s.group_id,f.type_a,null,current_date-1,'legacy_batch',1,1);
        when 'unbound_sale','bound_sale' then
          insert into public.venta_animal(granja_id,grupo_id,tipo_animal_id,animal_id,fecha_venta,record_kind,quantity,peso,total_amount)
          values(f.farm_a,s.group_id,f.type_a,s.animal_id,current_date-1,'individual',1,1,1);
          if p.mode='bound_sale' then
            insert into economics_v2.group_period_sale_bindings(sale_id,granja_id,period_id,record_kind,quantity,saleable_kg,total_amount,source_digest)
            select id,f.farm_a,s.period_id,'individual',1,1,1,'unsupported-negative-probe' from public.venta_animal where animal_id=s.animal_id;
          end if;
      end case;
      perform pg_temp.checked(sql,p.state,p.code,p.field,p.entity);
      if p.mode='disabled' then perform pg_temp.checked(original_sql,'42501','forbidden','granja_id',f.farm_a); end if;
      raise exception using errcode='ZR001',message='Restore closing refusal probe';
    exception when sqlstate 'ZR001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=b and pg_temp.sequence_state()=q,'complete isolated probe restored: '||p.mode);
  end loop;
  -- Cross-domain conflict uses a REAL existing nonclosing receipt, not a forged ledger.
  perform economics_v2.validate_group_meat_nonclosing_source(f.farm_a,n.animal_id,current_date);
  update public.animales set activo=false where id=n.animal_id;
  perform economics_v2.exit_group_meat_nonclosing(f.farm_a,n.operation_id,n.animal_id,current_date,body);
  perform pg_temp.checked(format('select economics_v2.exit_group_meat_closing(%L,%L,%L,current_date,%L::jsonb)',
    f.farm_a,n.operation_id,n.animal_id,body),'22023','operation_payload_conflict','operation_id',n.operation_id);
  perform pg_temp.jwt(f.editor_a);
  for fault in select unnest(array['feed','period','snapshot','completion']) loop
    b:=pg_temp.business_state(); q:=pg_temp.sequence_state(); st:=null; msg:=null;
    perform set_config('closing_exit.fault',fault,true);
    begin execute sql into r;
    exception when others then get stacked diagnostics st=returned_sqlstate,msg=message_text;
    end;
    perform set_config('closing_exit.fault','off',true);
    perform pg_temp.check_true(st='ZC001' and msg='Closing exit reached late fault: '||fault,'independently reached actual late stage: '||fault);
    perform pg_temp.check_true(pg_temp.business_state()=b,'ALL business rows including fences/animal/receipt roll back: '||fault);
    perform pg_temp.check_true(pg_temp.sequence_state()-'economics_v2.group_economics_event_position_seq'
      =q-'economics_v2.group_economics_event_position_seq','every other business sequence unchanged: '||fault);
    perform pg_temp.check_true((pg_temp.sequence_state()->'economics_v2.group_economics_event_position_seq'->>'last_value')::bigint
      =(q->'economics_v2.group_economics_event_position_seq'->>'last_value')::bigint+1,'exactly one issued exit position survives rollback: '||fault);
    insert into pg_temp.retained_gaps values(fault,(q->'economics_v2.group_economics_event_position_seq'->>'last_value')::bigint,
      (pg_temp.sequence_state()->'economics_v2.group_economics_event_position_seq'->>'last_value')::bigint);
    set constraints all immediate;
    set constraints all deferred;
  end loop;
  -- Successful editor JWT, still SQL postgres: no client execution privilege added.
  q:=pg_temp.sequence_state();
  execute sql into r;
  insert into pg_temp.receipts values('editor',r);
  set constraints all immediate;
  set constraints all deferred;
  perform pg_temp.verify_close('editor',r,f.editor_a);
  perform pg_temp.check_true(pg_temp.sequence_state()-'economics_v2.group_economics_event_position_seq'
    =q-'economics_v2.group_economics_event_position_seq'
    and (r->>'event_position')::bigint=(q->'economics_v2.group_economics_event_position_seq'->>'last_value')::bigint+1
    and (pg_temp.sequence_state()->'economics_v2.group_economics_event_position_seq'->>'last_value')::bigint=(r->>'event_position')::bigint,
    'editor close issues exactly one exit position, separately from retained fault gaps');
  perform pg_temp.check_true(pg_temp.checked(sql)=r||'{"replayed":true}'::jsonb,'editor replay after actual closure');
  select * into proc from pg_proc where oid='economics_v2.exit_group_meat_closing(uuid,uuid,uuid,date,jsonb)'::regprocedure;
  perform pg_temp.check_true(proc.prorettype='jsonb'::regtype and proc.provolatile='v' and not proc.prosecdef
    and proc.proowner='postgres'::regrole and proc.proconfig @> array['search_path=""'] and proc.pronargdefaults=0
    and proc.pronargs=5 and proc.proargnames=array['p_granja_id','p_operation_id','p_animal_id','p_effective_on','p_payload']::text[]
    and not exists(select 1 from aclexplode(coalesce(proc.proacl,acldefault('f',proc.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE')
    and not has_function_privilege('anon',proc.oid,'EXECUTE') and not has_function_privilege('authenticated',proc.oid,'EXECUTE')
    and not has_function_privilege('service_role',proc.oid,'EXECUTE'),'exact private5 VOLATILE INVOKER owner/path/ACL');
  perform pg_temp.check_true(not exists(select 1 from pg_proc routine join pg_namespace ns on ns.oid=routine.pronamespace
    where ns.nspname='public' and routine.proname='exit_group_meat_closing'),'no public wrapper');
  perform pg_temp.checked(format('select economics_v2.transition_group_occupancy_impl(%L,%L,''exit'',%L,current_date,null::uuid,null::uuid,null::uuid)',
    f.farm_a,gen_random_uuid(),s.animal_id),'0A000');
  b:=pg_temp.business_state();
  begin
    update economics_v2.group_occupancy_operations set result='{}' where granja_id=f.farm_a and operation_id=s.operation_id;
    perform pg_temp.checked(sql,'23514','invariant_violation','operation_id',s.operation_id);
    raise exception using errcode='ZR001',message='Restore malformed receipt';
  exception when sqlstate 'ZR001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=b,'incomplete receipt restored without business mutation');
end;
$proof$;

-- Frozen label proof: authorized rename is isolated; history payload is never edited.
do $frozen$
declare s record; f record; b jsonb; item jsonb;
begin
  select * into f from pg_temp.ids;
  select * into s from pg_temp.scenarios where label='owner';
  perform pg_temp.jwt(f.owner_a); b:=pg_temp.business_state();
  begin
    update public.grupos set nombre='Renamed after real closure' where id=s.group_id;
    select x into item from jsonb_array_elements(economics_v2.list_group_economics_impl(f.farm_a,50,null,null,null)->'items') x
      where x->>'period_id'=s.period_id::text;
    perform pg_temp.check_true(item->>'group_name'='Closing Group owner' and item->>'metrics_source'='snapshot','reader retains frozen label after real Group rename');
    raise exception using errcode='ZR001',message='Restore Group rename';
  exception when sqlstate 'ZR001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=b,'rename fully restored');
end;
$frozen$;

-- Real same-date, zero-basis successor in the SAME Group. Old two-header H history
-- must not be misclassified as missing allocations for this new current period.
-- Roll back the entire extra positive, retaining its two issued sequence positions.
do $successor$
declare f record; s record; a uuid:=gen_random_uuid(); op uuid:=gen_random_uuid(); admission jsonb;
  r jsonb; b jsonb; q jsonb; expected jsonb; successor_period uuid;
begin
  select * into f from pg_temp.ids;
  select * into s from pg_temp.scenarios where label='owner';
  b:=pg_temp.business_state(); q:=pg_temp.sequence_state();
  begin
    insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,fecha_adquisicion,costo_adquisicion,created_by)
    values(a,f.farm_a,f.type_a,s.group_id,f.meat,current_date,0,f.owner_a);
    admission:=economics_v2.enter_group_meat_initial(f.farm_a,gen_random_uuid(),a,current_date,s.group_id,f.meat,'{}');
    successor_period:=(admission->>'destination_period_id')::uuid;
    perform public.crear_mezcla_grupo_v1(f.farm_a,gen_random_uuid(),successor_period,gen_random_uuid(),current_date,s.group_id,
      jsonb_build_array(jsonb_build_object('categoria_id',f.category,'cantidad_kg',1,'costo_total',0)));
    r:=economics_v2.exit_group_meat_closing(f.farm_a,op,a,current_date,(select value from pg_temp.payload));
    set constraints all immediate;
    set constraints all deferred;
    expected:=(select value from pg_temp.expected_metrics)||jsonb_build_object('feed_source_count',1,'feed_kg_total',1,
      'feed_cost',0,'acquisition_cost',0,'direct_expense_total',0,'total_cost',0,'profit',0,'balance_per_animal',0);
    perform pg_temp.check_true(r->>'source_period_id'=successor_period::text and r->>'source_status'='closed'
      and r->'basis_before'='0'::jsonb and r->'basis_after'='0'::jsonb and r->'basis_entry_ids'='[]'::jsonb
      and exists(select 1 from economics_v2.group_meat_snapshots snap where snap.id=(r->>'snapshot_id')::uuid
        and snap.period_id=successor_period and snap.snapshot_version='group-meat-snapshot.forward.v3' and snap.payload->'metrics'=expected)
      and exists(select 1 from public.animales where id=a and activo=false),'same-date real zero-basis closure accepts two retained H sources');
    perform pg_temp.check_true((select count(*)=2 from public.mezcla m join economics_v2.group_period_feed_allocations x on x.mixture_id=m.id
      where x.period_id=s.period_id and m.fecha_termino is null and group_feed_integrity.is_closed_feed_history(m)),
      'prior real feed remains qualified H without date/version/source rewriting');
    raise exception using errcode='ZR001',message='Restore complete real successor';
  exception when sqlstate 'ZR001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=b and pg_temp.sequence_state()-'economics_v2.group_economics_event_position_seq'
    =q-'economics_v2.group_economics_event_position_seq','extra real positive rolls back all rows and other sequences');
  perform pg_temp.check_true((pg_temp.sequence_state()->'economics_v2.group_economics_event_position_seq'->>'last_value')::bigint
    =(q->'economics_v2.group_economics_event_position_seq'->>'last_value')::bigint+2,'real successor retains exactly entry/exit sequence gaps');
end;
$successor$;

-- Full-schema comparison admits ONLY the explicitly verified row families. No
-- legacy/expense/food/header/catalog/foreign/egg row can disappear behind a farm filter.
create function pg_temp.allowed_delta(p_table text,p_row jsonb)
returns boolean language sql stable security invoker set search_path='' as $$
  select case p_table
    when 'public.animales' then exists(select 1 from pg_temp.scenarios where animal_id::text=p_row->>'id')
    when 'economics_v2.group_animal_acquisition_basis' then exists(select 1 from pg_temp.scenarios where animal_id::text=p_row->>'animal_id')
    when 'economics_v2.group_occupancy_memberships' then exists(select 1 from pg_temp.scenarios where animal_id::text=p_row->>'animal_id')
    when 'economics_v2.group_occupancy_periods' then exists(select 1 from pg_temp.scenarios where label<>'nonlast' and period_id::text=p_row->>'id')
    when 'economics_v2.group_period_feed_allocations' then exists(select 1 from pg_temp.scenarios where label<>'nonlast' and period_id::text=p_row->>'period_id')
    when 'economics_v2.group_meat_snapshots' then exists(select 1 from pg_temp.scenarios where label<>'nonlast' and period_id::text=p_row->>'period_id')
    when 'economics_v2.group_occupancy_events' then exists(select 1 from pg_temp.scenarios where operation_id::text=p_row->>'operation_id')
    when 'economics_v2.group_occupancy_operations' then exists(select 1 from pg_temp.scenarios where operation_id::text=p_row->>'operation_id')
    when 'group_feed_integrity.fences' then exists(select 1 from pg_temp.scenarios where group_id::text=p_row->>'entity_id')
      or exists(select 1 from pg_temp.ids where meat::text=p_row->>'entity_id')
    else false end;
$$;
do $isolation$
declare before_rows jsonb; after_rows jsonb; t record; b jsonb; a jsonb;
begin
  select business_rows into before_rows from pg_temp.initial_state;
  after_rows:=pg_temp.business_state();
  for t in select key from jsonb_each(before_rows) loop
    select coalesce(jsonb_agg(x order by x::text),'[]'::jsonb) into b
      from jsonb_array_elements(before_rows->t.key) x where not pg_temp.allowed_delta(t.key,x);
    select coalesce(jsonb_agg(x order by x::text),'[]'::jsonb) into a
      from jsonb_array_elements(after_rows->t.key) x where not pg_temp.allowed_delta(t.key,x);
    perform pg_temp.check_true(a=b,'all unrelated full rows unchanged: '||t.key);
  end loop;
  perform pg_temp.check_true((select count(*)=2 from economics_v2.group_meat_snapshots where granja_id=(select farm_a from pg_temp.ids))
    and (select count(*)=3 from economics_v2.group_occupancy_events where granja_id=(select farm_a from pg_temp.ids) and action='exit')
    and not exists(select 1 from economics_v2.group_acquisition_basis_entries e join pg_temp.scenarios s on s.operation_id=e.operation_id)
    and (select sum(signed_amount)=900 from economics_v2.group_acquisition_basis_entries where granja_id=(select farm_a from pg_temp.ids)),
    'only two real closures plus one qualified nonclosing exit; initial900 retained, no negative exit entry');
  perform pg_temp.check_true((select count(*)=4 from economics_v2.group_occupancy_memberships where granja_id=(select farm_a from pg_temp.ids))
    and (select count(*)=7 from economics_v2.group_occupancy_events where granja_id=(select farm_a from pg_temp.ids))
    and (select count(*)=13 from economics_v2.group_occupancy_operations where granja_id=(select farm_a from pg_temp.ids)),
    'no extra memberships/events/ledger reservations, including hidden target-row writes');
  perform pg_temp.check_true(not exists(select 1 from jsonb_array_elements(before_rows->'group_feed_integrity.fences') old_fence
    where not exists(select 1 from group_feed_integrity.fences live where live.scope=old_fence->>'scope'
      and live.entity_id::text=old_fence->>'entity_id' and live.revision>=(old_fence->>'revision')::bigint))
    and jsonb_array_length(after_rows->'group_feed_integrity.fences')=jsonb_array_length(before_rows->'group_feed_integrity.fences'),
    'existing fence identities retained; revisions never rewind and no extra scope invented');
end;
$isolation$;

set constraints all immediate;
select jsonb_build_object('result','group_economics_forward_closing_exit_pass',
  'assertion_count',(select count(*) from assertions),'locking_evidence','sequential_only',
  'public_api_activated',false,'sale_or_baja_integrated',false,'http_proven',false,
  'production_proven',false,'independent_review','pending',
  'retained_fault_gaps',(select jsonb_agg(to_jsonb(g) order by g.stage) from retained_gaps g),
  'fixture_ids',(select to_jsonb(f) from ids f),'receipts',(select jsonb_agg(to_jsonb(r)) from receipts r)) as evidence;
rollback;
