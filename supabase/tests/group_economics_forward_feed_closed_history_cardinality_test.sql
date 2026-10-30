begin;

-- HUMAN Sandbox only; review/run the FULL transaction and report the first error.
-- Authoring only: no RED, execution, concurrency or business-closure evidence yet.
-- Budget: complete fixture <=450 + future guard migration <=350 = <=800 lines.
-- Migration forecast includes H/check_group/enforce/period_after/deferred callback,
-- fences, DDL, ACL and comments. The 350-line ceiling is not an implementation promise.
-- ADMIN synthetic occupancy has NO memberships/events: containment is vacuous.
-- Real feed creation supplies sources/digests; ADMIN finalization/snapshot below
-- are structural test facts, NOT proofs of finalization or snapshot producers.
-- Future H is structural, never a token or the exemption marker alone: unique
-- farm/mixture allocation, matching period/farm/Group, finite finalized_at,
-- exact occurred_on/source_updated_at, BOTH valid closing bounds, reader-v3 snapshot.
-- O = open headers excluding H. Only a unique qualified OPEN meat period permits
-- multiple O. Preserve H markers, dates, versions, allocation and ingredient facts.
-- Defer ONLY same-identity/start-metadata feed-bearing meat OPEN->CLOSED writes;
-- re-read final state at the boundary, including all allocations and snapshot.
-- Reopening must not erase the queued closure obligation. Other metadata stays immediate.
-- The future closer still owns ingredient integrity validation under complete locks.
-- No future classifier/helper is called: first RED must be today's existing trigger,
-- NOT 42883. Retain direct-client guard, index, admission, fences and history immutability.

create temp table ids as select gen_random_uuid() actor,gen_random_uuid() farm,
  gen_random_uuid() foreign_farm,gen_random_uuid() animal_type,gen_random_uuid() meat,
  gen_random_uuid() posture,gen_random_uuid() grp,gen_random_uuid() other_grp,
  gen_random_uuid() period,gen_random_uuid() other_period,gen_random_uuid() category,
  gen_random_uuid() mixture_a,gen_random_uuid() mixture_b;
create temp table assertions(label text not null);
create function pg_temp.check_true(p_ok boolean,p_label text)
returns void language plpgsql security invoker set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%',p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
insert into auth.users(id,aud,role,raw_user_meta_data)
select actor,'authenticated','authenticated',jsonb_build_object('fixture','closed-history-cardinality') from ids;
insert into public.granjas(id,owner_id,nombre,created_by)
select f,actor,'Synthetic history farm '||f,actor from ids
cross join lateral unnest(array[farm,foreign_farm]) f;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled) select farm,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select animal_type,farm,'Synthetic history type',actor from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat,farm,'Synthetic meat','carne',actor from ids
union all select posture,farm,'Synthetic posture','postura',actor from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select g,farm,animal_type,'Synthetic history Group '||g,actor from ids
cross join lateral unnest(array[grp,other_grp]) g;
insert into public.cat_comida(id,granja_id,nombre,activo,created_by)
select category,farm,'History ingredient',true,actor from ids;
-- Explicit positions avoid fabricating events or consuming the event-position sequence.
insert into economics_v2.group_occupancy_periods
  (id,granja_id,group_id,purpose_id,starts_on,start_position)
select period,farm,grp,meat,current_date-7,100 from ids;
-- Unrelated synthetic CLOSED row deliberately has no snapshot. No global retro-check.
insert into economics_v2.group_occupancy_periods
  (id,granja_id,group_id,purpose_id,starts_on,start_position,closed_on,end_position)
select other_period,farm,other_grp,meat,current_date-7,10,current_date-1,20 from ids;
select set_config('request.jwt.claim.sub',actor::text,true),
  set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated')::text,true) from ids;
do $access$
begin
  execute format('grant usage on schema %I to authenticated',pg_my_temp_schema()::regnamespace::text);
end;
$access$;
grant select on pg_temp.ids to authenticated;
create temp table captures(result jsonb);
grant insert on pg_temp.captures to authenticated;
set local role authenticated;
insert into pg_temp.captures select public.crear_mezcla_grupo_v1(
  p_granja_id=>farm,p_operation_id=>gen_random_uuid(),p_period_id=>period,p_mezcla_id=>m,
  p_fecha_inicio=>current_date-3,p_grupo_id=>grp,p_ingredientes=>jsonb_build_array(
    jsonb_build_object('categoria_id',category,'cantidad_kg',1,'costo_total',4)))
from pg_temp.ids cross join lateral unnest(array[mixture_a,mixture_b]) m;
reset role;
-- Synthetic closing fact; no validator result is promoted into write authority.
update economics_v2.group_period_feed_allocations set finalized_at=transaction_timestamp()
where period_id=(select period from ids);
create temp table source_headers as select m.* from public.mezcla m join ids i
  on m.id in(i.mixture_a,i.mixture_b);
create temp table source_allocations as select a.* from economics_v2.group_period_feed_allocations a
  join ids i on a.period_id=i.period;
create temp table metric_keys as select array[
  'acquisition_cost','active_animal_count','animal_count','animal_sale_revenue',
  'balance_per_animal','break_even_kg','direct_expense_total','exited_animal_count','feed_cost',
  'feed_kg_total','feed_source_count','profit','realized_price_per_kg','sale_count','saleable_kg',
  'sold_animal_count','total_cost']::text[] keys;
create temp table snapshot_payload as select jsonb_build_object(
  'group_name','Synthetic history Group','purpose_code','carne',
  'metrics',(select jsonb_object_agg(k,0) from metric_keys cross join lateral unnest(keys) k)) payload;
-- Deliberately synthetic exact17 values: these are NOT calculated economic outcomes.
select pg_temp.check_true((select count(*)=2 and bool_and(fecha_termino is null
  and group_feed_meat_exempt and isfinite(updated_at)) from source_headers)
  and (select count(*)=2 and bool_and(isfinite(finalized_at)) from source_allocations),
  'two canonical open-date sources and two ADMIN-finalized allocations');
set constraints all immediate;
set constraints all deferred;

-- Sequential whole-state oracle. Probe rollback includes fences; no assertion that
-- legitimate successful guard writes are pure. Sequence state is explicit because
-- nextval is NOT rolled back; a changed sequence fails restoration rather than hiding it.
create function pg_temp.business_state()
returns jsonb language plpgsql security invoker set search_path='' as $$
declare r record; rows jsonb; result jsonb:='{}';
begin
  for r in select n.nspname,c.relname,c.relkind from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where (n.nspname in('public','economics_v2','group_feed_integrity')
      or (n.nspname='auth' and c.relname='users')) and c.relkind in('r','p','S')
    order by n.nspname,c.relname loop
    if r.relkind='S' then
      execute format('select jsonb_build_object(''last_value'',last_value,''log_cnt'',log_cnt,
        ''is_called'',is_called) from %I.%I',r.nspname,r.relname) into rows;
    else
      execute format('select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),''[]''::jsonb)
        from %I.%I t',r.nspname,r.relname) into rows;
    end if;
    result:=result||jsonb_build_object(r.nspname||'.'||r.relname,rows);
  end loop;
  select jsonb_agg(to_jsonb(x) order by x.kind,x.id) into rows from (
    select 'relation' kind,c.oid id,c.relacl::text value from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname in('public','economics_v2','group_feed_integrity','auth')
    union all select 'function',p.oid,p.proacl::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname in('public','economics_v2','group_feed_integrity','auth')
    union all select 'schema',n.oid,n.nspacl::text from pg_namespace n
      where n.nspname in('public','economics_v2','group_feed_integrity','auth')
    union all select 'trigger',t.oid,pg_get_triggerdef(t.oid) from pg_trigger t
      join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace
      where n.nspname in('public','economics_v2','group_feed_integrity')
    union all select 'index',i.indexrelid,pg_get_indexdef(i.indexrelid) from pg_index i
      join pg_class c on c.oid=i.indrelid join pg_namespace n on n.oid=c.relnamespace
      where n.nspname in('public','economics_v2','group_feed_integrity')) x;
  return result||jsonb_build_object('catalog',rows);
end;
$$;
create temp table baseline as select pg_temp.business_state() state;

-- FIRST uncaught behavioral RED: current period_after -> check_group raises 23514,
-- "Metadata change would remove the multiple-mixture meat exemption" at this UPDATE.
-- The snapshot intentionally does NOT exist until AFTER the period write.
do $first$
begin
  begin
    update economics_v2.group_occupancy_periods set closed_on=current_date-1,end_position=200
    where id=(select period from pg_temp.ids);
    insert into economics_v2.group_meat_snapshots(period_id,granja_id,snapshot_version,payload)
    select period,farm,'group-meat-snapshot.forward.v3',payload from pg_temp.ids cross join pg_temp.snapshot_payload;
    set constraints all immediate;
    raise exception using errcode='Z0001',message='Restore first complete synthetic closure';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=(select state from pg_temp.baseline),
    'first synthetic close accepted at deferred boundary and exactly restored');
end;
$first$;

create function pg_temp.write_close(p_mode text default 'valid')
returns void language plpgsql security invoker set search_path='' as $$
declare i record; payload jsonb;
begin
  select * into i from pg_temp.ids;
  select s.payload into payload from pg_temp.snapshot_payload s;
  update economics_v2.group_occupancy_periods
  set closed_on=case when p_mode='infinite_date' then 'infinity'::date else current_date-1 end,
    end_position=200 where id=i.period;
  if p_mode<>'missing_snapshot' then
    if p_mode='metrics_missing' then payload:=jsonb_set(payload,'{metrics}',(payload->'metrics')-'profit'); end if;
    if p_mode='metrics_extra' then payload:=jsonb_set(payload,'{metrics}',(payload->'metrics')||'{"extra":0}'); end if;
    if p_mode='metrics_shape' then payload:=jsonb_set(payload,'{metrics}','[]'); end if;
    if p_mode='group_name' then payload:=jsonb_set(payload,'{group_name}','null'); end if;
    if p_mode='purpose_code' then payload:=jsonb_set(payload,'{purpose_code}','"postura"'); end if;
    insert into economics_v2.group_meat_snapshots(period_id,granja_id,snapshot_version,payload)
    values(i.period,case when p_mode='snapshot_farm' then i.foreign_farm else i.farm end,
      case when p_mode='snapshot_version' then 'group-meat-snapshot.v0' else 'group-meat-snapshot.forward.v3' end,payload);
  end if;
  if p_mode='reopen' then
    update economics_v2.group_occupancy_periods set closed_on=null,end_position=null where id=i.period;
  end if;
end;
$$;
-- Preparation must SUCCEED outside the refusal catcher: an unrelated prep failure
-- cannot masquerade as successful validation of a malformed closing candidate.
create function pg_temp.reject_close(p_mode text,p_prepare text default null)
returns void language plpgsql security invoker set search_path='' as $$
declare before_state jsonb:=pg_temp.business_state(); rejected boolean:=false;
begin
  begin
    if p_prepare is not null then execute p_prepare; end if;
    begin
      perform pg_temp.write_close(p_mode);
      set constraints all immediate;
    exception when check_violation then rejected:=true;
    end;
    if not rejected then raise exception 'Expected closing 23514: %',p_mode; end if;
    raise exception using errcode='Z0001',message='Restore negative closure probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=before_state,'complete rollback: '||p_mode);
  set constraints all deferred;
end;
$$;
do $negative$
declare mode text; probe record;
begin
  for mode in select unnest(array['missing_snapshot','snapshot_farm','snapshot_version',
    'metrics_missing','metrics_extra','metrics_shape','group_name','purpose_code','reopen','infinite_date']) loop
    perform pg_temp.reject_close(mode);
  end loop;
  for probe in select * from (values
    ('missing_allocation','delete from economics_v2.group_period_feed_allocations where period_id=(select period from pg_temp.ids)'),
    ('unfinished','update economics_v2.group_period_feed_allocations set finalized_at=null where period_id=(select period from pg_temp.ids)'),
    ('one_unfinished','update economics_v2.group_period_feed_allocations set finalized_at=null where mixture_id=(select mixture_a from pg_temp.ids)'),
    ('infinite_finalization','update economics_v2.group_period_feed_allocations set finalized_at=''infinity'' where period_id=(select period from pg_temp.ids)'),
    ('captured_date','update economics_v2.group_period_feed_allocations set occurred_on=current_date-2 where period_id=(select period from pg_temp.ids)'),
    ('captured_version','update economics_v2.group_period_feed_allocations set source_updated_at=source_updated_at+interval ''1 second'' where period_id=(select period from pg_temp.ids)'),
    ('wrong_group_period','update economics_v2.group_period_feed_allocations set period_id=(select other_period from pg_temp.ids) where period_id=(select period from pg_temp.ids)')) p(label,sql) loop
    perform pg_temp.reject_close(probe.label,probe.sql);
  end loop;
end;
$negative$;

-- These ordinary changes must fail AT THE STATEMENT, not merely on SET CONSTRAINTS.
do $immediate$
declare sql text; before_state jsonb; rejected boolean;
begin
  for sql in select unnest(array[
    'update public.cat_proposito_animal set codigo_calculo=''postura'' where id=(select meat from pg_temp.ids)',
    'update economics_v2.group_occupancy_periods set purpose_id=(select posture from pg_temp.ids) where id=(select period from pg_temp.ids)',
    'update economics_v2.group_occupancy_periods set group_id=(select other_grp from pg_temp.ids) where id=(select period from pg_temp.ids)',
    'update economics_v2.group_occupancy_periods set starts_on=current_date where id=(select period from pg_temp.ids)',
    'update economics_v2.group_occupancy_periods set closed_on=current_date-1,end_position=200,start_position=101 where id=(select period from pg_temp.ids)',
    'update economics_v2.group_occupancy_periods set closed_on=current_date-1 where id=(select period from pg_temp.ids)',
    'update economics_v2.group_occupancy_periods set end_position=200 where id=(select period from pg_temp.ids)']) loop
    before_state:=pg_temp.business_state(); rejected:=false;
    begin execute sql; exception when check_violation then rejected:=true; end;
    perform pg_temp.check_true(rejected and pg_temp.business_state()=before_state,'immediate metadata refusal: '||sql);
  end loop;
end;
$immediate$;

-- Successful synthetic closure: allowed persistent delta is ONLY this period,
-- this snapshot and private fences. Source/finalization baselines remain exact.
select pg_temp.write_close();
set constraints all immediate;
set constraints all deferred;
create temp table closed_state as select pg_temp.business_state() state;
select pg_temp.check_true((select state-array['economics_v2.group_occupancy_periods',
  'economics_v2.group_meat_snapshots','group_feed_integrity.fences'] from closed_state)
  =(select state-array['economics_v2.group_occupancy_periods',
  'economics_v2.group_meat_snapshots','group_feed_integrity.fences'] from baseline),
  'closure changes no other business table, sequence, ACL, index or trigger');
-- Do not mask unrelated rows just because their TABLE is an allowed write target.
select pg_temp.check_true(
  (select jsonb_agg(r order by r::text) from closed_state c,
    lateral jsonb_array_elements(c.state->'economics_v2.group_occupancy_periods') r
    where r->>'id'<>(select period::text from ids)) is not distinct from
  (select jsonb_agg(r order by r::text) from baseline b,
    lateral jsonb_array_elements(b.state->'economics_v2.group_occupancy_periods') r
    where r->>'id'<>(select period::text from ids)), 'unrelated periods unchanged, including synthetic closed row');
select pg_temp.check_true(
  (select to_jsonb(p)-array['closed_on','end_position','position_span']
    from economics_v2.group_occupancy_periods p join ids i on p.id=i.period)
  =(select r-array['closed_on','end_position','position_span'] from baseline b,
    lateral jsonb_array_elements(b.state->'economics_v2.group_occupancy_periods') r
    where r->>'id'=(select period::text from ids))
  and (select closed_on=current_date-1 and end_position=200
    from economics_v2.group_occupancy_periods p join ids i on p.id=i.period),
  'only exact closing bounds changed on the target period');
select pg_temp.check_true(
  (select coalesce(jsonb_agg(r order by r::text),'[]'::jsonb) from closed_state c,
    lateral jsonb_array_elements(c.state->'economics_v2.group_meat_snapshots') r
    where r->>'period_id'<>(select period::text from ids))
  =(select b.state->'economics_v2.group_meat_snapshots' from baseline b)
  and not exists(select 1 from closed_state c,
    lateral jsonb_array_elements(c.state->'group_feed_integrity.fences') r
    where not exists(select 1 from baseline b,
      lateral jsonb_array_elements(b.state->'group_feed_integrity.fences') old
      where old=r) and not (r->>'scope'='group' and r->>'entity_id'=(select grp::text from ids)
        or r->>'scope'='purpose' and r->>'entity_id'=(select meat::text from ids)))
  and not exists(select 1 from baseline b,
    lateral jsonb_array_elements(b.state->'group_feed_integrity.fences') old
    where not exists(select 1 from closed_state c,
      lateral jsonb_array_elements(c.state->'group_feed_integrity.fences') r
      where r->>'scope'=old->>'scope' and r->>'entity_id'=old->>'entity_id'
        and (r->>'revision')::bigint>=(old->>'revision')::bigint)),
  'only target snapshot added; fences retain identities and only target revisions may advance');
select pg_temp.check_true((select count(*)=1 from economics_v2.group_meat_snapshots s join ids i
  on s.period_id=i.period and s.granja_id=i.farm cross join snapshot_payload x
  where s.snapshot_version='group-meat-snapshot.forward.v3' and s.payload=x.payload)
  and not exists(select 1 from source_allocations a join economics_v2.group_period_feed_allocations b
    on b.id=a.id where to_jsonb(a)<>to_jsonb(b)), 'exact synthetic snapshot and unchanged finalized allocation facts');
select pg_temp.check_true(exists(select 1 from pg_trigger t join pg_proc p on p.oid=t.tgfoid
  join pg_namespace n on n.oid=p.pronamespace
  where t.tgrelid='economics_v2.group_occupancy_periods'::regclass
    and t.tgconstraint<>0 and t.tgdeferrable and t.tginitdeferred
    and n.nspname='group_feed_integrity' and t.tgenabled='O'),
  'enabled initially-deferred period constraint in the private integrity boundary');

-- H must be excluded from BOTH fallback chronology and sibling auto-close UPDATE.
-- Older fallback dates are intentional. These ADMIN writes exercise cardinality,
-- not a client gateway: retained direct-client conservatism is tested separately.
do $fallback$
declare mode text; i record; first_id uuid; second_id uuid; before_state jsonb;
begin
  select * into i from pg_temp.ids;
  for mode in select unnest(array['unclassified','nonmeat','ambiguous']) loop
    before_state:=pg_temp.business_state(); first_id:=gen_random_uuid(); second_id:=gen_random_uuid();
    begin
      if mode<>'unclassified' then
        insert into economics_v2.group_occupancy_periods
          (granja_id,group_id,purpose_id,starts_on,start_position)
        values(i.farm,i.grp,i.posture,current_date-7,300);
      end if;
      if mode='ambiguous' then
        insert into economics_v2.group_occupancy_periods
          (granja_id,group_id,purpose_id,starts_on,start_position)
        values(i.farm,i.grp,i.meat,current_date-7,300);
      end if;
      insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
      values(first_id,i.farm,i.grp,current_date-5,i.actor);
      insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
      values(second_id,i.farm,i.grp,current_date-4,i.actor);
      update public.mezcla set fecha_inicio=fecha_inicio where id in(i.mixture_a,i.mixture_b);
      if not (select fecha_termino=current_date-4 and not group_feed_meat_exempt
        from public.mezcla where id=first_id) or not (select fecha_termino is null
        and not group_feed_meat_exempt from public.mezcla where id=second_id) then
        raise exception 'Fallback singleton/date-end semantics changed: %',mode;
      end if;
      if exists(select 1 from pg_temp.source_headers h left join public.mezcla m on m.id=h.id
        where to_jsonb(m) is distinct from to_jsonb(h)) then raise exception 'Historical header changed: %',mode; end if;
      set constraints all immediate;
      if pg_temp.business_state()-array['public.mezcla','economics_v2.group_occupancy_periods',
        'group_feed_integrity.fences'] <> before_state-array['public.mezcla',
        'economics_v2.group_occupancy_periods','group_feed_integrity.fences'] then
        raise exception 'Fallback changed ingredients, allocations, snapshots or unrelated state: %',mode;
      end if;
      raise exception using errcode='Z0001',message='Restore successful fallback probe';
    exception when sqlstate 'Z0001' then null;
    end;
    perform pg_temp.check_true(pg_temp.business_state()=before_state,'history preserved through fallback: '||mode);
    set constraints all deferred;
  end loop;
end;
$fallback$;

-- A later qualified OPEN meat period admits its own operational headers without
-- reclassifying old H, assigning it to the new period or changing captured facts.
do $next_period$
declare i record; p uuid:=gen_random_uuid(); before_state jsonb:=pg_temp.business_state();
begin
  select * into i from pg_temp.ids;
  begin
    insert into economics_v2.group_occupancy_periods(id,granja_id,group_id,purpose_id,starts_on,start_position)
    values(p,i.farm,i.grp,i.meat,current_date,300);
    insert into public.mezcla(granja_id,grupo_id,fecha_inicio,created_by)
    values(i.farm,i.grp,current_date,i.actor),(i.farm,i.grp,current_date,i.actor);
    update public.mezcla set fecha_inicio=fecha_inicio where id in(i.mixture_a,i.mixture_b);
    perform group_feed_integrity.check_group(i.grp);
    if (select count(*) from public.mezcla where grupo_id=i.grp and fecha_termino is null
      and group_feed_meat_exempt)<>4 then raise exception 'Qualified operational admission failed'; end if;
    if exists(select 1 from pg_temp.source_headers h left join public.mezcla m on m.id=h.id
      where to_jsonb(m) is distinct from to_jsonb(h)) or exists(
      select 1 from economics_v2.group_period_feed_allocations where period_id=p) then
      raise exception 'Historical source was mutated or recaptured';
    end if;
    set constraints all immediate;
    if pg_temp.business_state()-array['public.mezcla','economics_v2.group_occupancy_periods',
      'group_feed_integrity.fences'] <> before_state-array['public.mezcla',
      'economics_v2.group_occupancy_periods','group_feed_integrity.fences'] then
      raise exception 'Next-period admission changed ingredients, allocations or snapshot history';
    end if;
    raise exception using errcode='Z0001',message='Restore next-period probe';
  exception when sqlstate 'Z0001' then null;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=before_state,'new meat admission preserves H and allocations');
end;
$next_period$;

-- Actual authenticated direct UPDATE remains conservative on captured history.
-- No GUC conveys authority: claims identify the real owner; SQL role is authenticated.
grant insert on pg_temp.assertions to authenticated;
set local role authenticated;
do $client$
declare rejected boolean:=false; detail text;
begin
  begin
    update public.mezcla set fecha_inicio=fecha_inicio where id=(select mixture_a from pg_temp.ids);
  exception when check_violation then
    get stacked diagnostics detail=pg_exception_detail;
    rejected:=detail::jsonb->>'code'='forward_group_period_required';
  end;
  perform pg_temp.check_true(rejected,'direct captured header write retains typed client denial');
end;
$client$;
reset role;
select pg_temp.check_true(pg_temp.business_state()=(select state from closed_state),
  'client denial preserves whole business/catalog/sequence state');
do $immutable$
declare rejected boolean:=false;
begin
  begin
    update economics_v2.group_meat_snapshots set payload=payload where period_id=(select period from pg_temp.ids);
  exception when check_violation then rejected:=true;
  end;
  perform pg_temp.check_true(rejected and pg_temp.business_state()=(select state from pg_temp.closed_state),
    'snapshot immutability retained without trigger bypass');
end;
$immutable$;
set constraints all immediate;
select jsonb_build_object('result','group_economics_forward_feed_closed_history_cardinality_pass',
  'assertion_count',(select count(*) from assertions),
  'feed_closed_history_cardinality_compatibility_proven',true,'deferred_feed_closure_boundary_proven',true,
  'historical_feed_not_autoclosed',true,'real_closure_proven',false,'last_animal_exit_integrated',false,
  'feed_finalization_producer_proven',false,'snapshot_producer_proven',false,'http_proven',false,
  'production_proven',false,'independent_review','pending','locking_evidence','sequential_only',
  'fixture_ids',(select to_jsonb(i) from ids i),'captures',(select jsonb_agg(result) from captures)) as evidence;
rollback;
