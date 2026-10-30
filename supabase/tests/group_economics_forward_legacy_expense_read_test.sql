begin;
set local timezone = 'UTC';

-- HUMAN isolated sandbox only: review, then run this COMPLETE BEGIN/ROLLBACK file.
-- Fixture FIRST; no reader replacement, migration, mutation RPC or canonical API.
-- Expected first boundary RED: the real authenticated public READ still exposes
-- the valid seeded meat Cycle in targets AND expenses. Do not filter its result.
-- Future change removes ONLY the two Cycle projections from the retained reader.
-- Preserve legacy_mixture membership/current [start,end) semantics, not an egg gate.
-- Historical finance_expenses_vertical_slice_test.sql Cycle READ expectations are
-- deliberately superseded by this slice; that historical fixture is not modified.
-- Budget: fixture <=500 + complete future reader <=215 + DDL reserve85 <=800.
-- Sequential evidence only; unrelated traffic invalidates full-table snapshots.
-- Setup is ADMIN seeding, NOT legacy CREATE/forward admission/real closure proof.
-- record_cycle_expense helper paths remain outside this slice; neither all legacy
-- mutation guards nor canonical Group APIs are claimed integrated by these reads.
-- ROLLBACK removes fixtures/observers, but cannot rewind consumed sequence values.

create temp table ids as select
  gen_random_uuid() owner_a, gen_random_uuid() owner_b,
  gen_random_uuid() editor_a, gen_random_uuid() viewer_a, gen_random_uuid() outsider,
  gen_random_uuid() farm_a, gen_random_uuid() farm_b,
  gen_random_uuid() type_a, gen_random_uuid() type_b,
  gen_random_uuid() meat_a, gen_random_uuid() eggs_a, gen_random_uuid() egg_animal,
  gen_random_uuid() group_a, gen_random_uuid() group_sibling, gen_random_uuid() group_foreign,
  gen_random_uuid() mixture_a, gen_random_uuid() mixture_sibling,
  gen_random_uuid() mixture_ended, gen_random_uuid() mixture_foreign,
  gen_random_uuid() cycle_a, gen_random_uuid() cycle_expense,
  gen_random_uuid() expense_a, gen_random_uuid() expense_tie, gen_random_uuid() expense_earlier_time,
  gen_random_uuid() expense_older, gen_random_uuid() expense_sibling,
  gen_random_uuid() expense_ended, gen_random_uuid() expense_foreign;
create temp table assertions(label text not null);
create temp sequence attempted_dml;
create function pg_temp.check_true(p_ok boolean, p_label text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_ok is distinct from true then raise exception '%', p_label; end if;
  insert into pg_temp.assertions values(p_label);
end;
$$;
create temp table watched as
select n.nspname schema_name, c.relname table_name
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where c.relkind in ('r','p') and (n.nspname in ('public','economics_v2','group_feed_integrity')
  or (n.nspname='auth' and c.relname='users'));
create temp table watched_sequences as
select n.nspname schema_name, c.relname sequence_name
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
where c.relkind='S' and n.nspname in ('public','economics_v2','group_feed_integrity','auth');
create function pg_temp.business_state() returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_table record; v_rows jsonb; v_result jsonb := '{}';
begin
  for v_table in select w.* from pg_temp.watched w order by w.schema_name,w.table_name loop
    execute format('select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),
      ''[]''::jsonb) from %I.%I r',v_table.schema_name,v_table.table_name) into v_rows;
    v_result := v_result || jsonb_build_object(v_table.schema_name||'.'||v_table.table_name,v_rows);
  end loop;
  for v_table in select s.* from pg_temp.watched_sequences s order by s.schema_name,s.sequence_name loop
    -- Sequence relations cannot be converted with whole-row to_jsonb.
    execute format('select jsonb_build_object(''last_value'',s.last_value,
      ''log_cnt'',s.log_cnt,''is_called'',s.is_called) from %I.%I s',
      v_table.schema_name,v_table.sequence_name) into v_rows;
    v_result := v_result || jsonb_build_object(v_table.schema_name||'.'||v_table.sequence_name,v_rows);
  end loop;
  select coalesce(jsonb_agg(to_jsonb(p) order by p.oid),'[]') into v_rows
  from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname in ('public','economics_v2','group_feed_integrity');
  v_result := v_result || jsonb_build_object('functions_and_acls',v_rows);
  select coalesce(jsonb_agg(jsonb_build_array(c.oid,c.relacl,c.relowner,c.relrowsecurity,
    c.relforcerowsecurity) order by c.oid),'[]') into v_rows
  from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
  where n.nspname in ('public','economics_v2','group_feed_integrity','auth');
  v_result := v_result || jsonb_build_object('relation_acls',v_rows);
  select coalesce(jsonb_agg(jsonb_build_array(n.oid,n.nspowner,n.nspacl) order by n.oid),'[]')
    into v_rows from pg_catalog.pg_namespace n
    where n.nspname in ('public','economics_v2','group_feed_integrity','auth');
  return v_result || jsonb_build_object('schema_acls',v_rows);
end;
$$;

insert into auth.users(id,aud,role,raw_user_meta_data)
select v_actor,'authenticated','authenticated',
  '{"fixture":"forward-legacy-expense-read"}'::jsonb
from ids cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a,outsider]) v_actor;
insert into public.perfiles(id,nombre)
select v_actor,'Legacy expense read actor' from ids
cross join lateral unnest(array[owner_a,owner_b,editor_a,viewer_a,outsider]) v_actor
on conflict(id) do nothing;
insert into public.granjas(id,owner_id,nombre,created_by)
select farm_a,owner_a,'Legacy expense read farm A',owner_a from ids
union all select farm_b,owner_b,'Legacy expense read farm B',owner_b from ids;
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a,owner_a,'owner'::public.rol_miembro from ids
union all select farm_b,owner_b,'owner'::public.rol_miembro from ids
union all select farm_a,editor_a,'editor'::public.rol_miembro from ids
union all select farm_a,viewer_a,'viewer'::public.rol_miembro from ids
on conflict(granja_id,user_id) do update set rol=excluded.rol;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm_a,true from ids union all select farm_b,true from ids;
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'Read bird A',owner_a from ids
union all select type_b,farm_b,'Read bird B',owner_b from ids;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select meat_a,farm_a,'Read meat','carne',owner_a from ids
union all select eggs_a,farm_a,'Read eggs','postura',owner_a from ids;
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_a,farm_a,type_a,'  Read Group A  ',owner_a from ids
union all select group_sibling,farm_a,type_a,'Read sibling',owner_a from ids
union all select group_foreign,farm_b,type_b,'Read foreign',owner_b from ids;
insert into public.animales(id,granja_id,tipo_animal_id,grupo_id,proposito_id,
  fecha_adquisicion,costo_adquisicion,created_by)
select egg_animal,farm_a,type_a,group_a,eggs_a,current_date-30,10,owner_a from ids;
-- Ended history is inserted first. It ends exactly at today's exclusive boundary;
-- its explicit end wins over the next mixture's earlier start in the source COALESCE.
insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,fecha_termino,created_by)
select mixture_ended,farm_a,group_a,current_date-20,current_date,owner_a from ids;
insert into public.mezcla(id,granja_id,grupo_id,fecha_inicio,created_by)
select mixture_a,farm_a,group_a,current_date-10,owner_a from ids
union all select mixture_sibling,farm_a,group_sibling,current_date,owner_a from ids
union all select mixture_foreign,farm_b,group_foreign,current_date-5,owner_b from ids;
insert into economics_v2.cycles(id,granja_id,proposito_id,name,starts_on,ends_on,
  production_closed_on,status,created_by)
select cycle_a,farm_a,meat_a,'Read valid meat Cycle',current_date-10,null,null,'open',owner_a from ids;
insert into economics_v2.cycle_expenses(id,cycle_id,granja_id,occurred_on,amount,category,note,created_by)
select cycle_expense,cycle_a,farm_a,current_date-1,7,'Seed Cycle','Must disappear',owner_a from ids;

-- Fixed timestamps and a UUID tie exercise all expense ordering keys. Raw category,
-- blank note and NULL note are ADMIN persistence controls, not CREATE normalization.
create temp table legacy_seed as
select v.* from ids i cross join lateral (values
  (i.expense_a,i.mixture_a,i.farm_a,current_date-1,11.25::numeric,'  Raw category  ','  Raw note  ',
    '2026-01-03 10:00:00+00'::timestamptz,'2026-01-04 11:00:00.000001+00'::timestamptz,i.owner_a),
  (i.expense_tie,i.mixture_a,i.farm_a,current_date-1,12::numeric,'Tie',null::text,
    '2026-01-03 10:00:00+00'::timestamptz,'2026-01-04 11:00:00.000002+00'::timestamptz,i.owner_a),
  (i.expense_earlier_time,i.mixture_a,i.farm_a,current_date-1,12.5::numeric,'Earlier time','Time order',
    '2026-01-02 10:00:00+00'::timestamptz,'2026-01-02 11:00:00+00'::timestamptz,i.owner_a),
  (i.expense_older,i.mixture_a,i.farm_a,current_date-2,13::numeric,'Older date','',
    '2026-01-05 10:00:00+00'::timestamptz,'2026-01-05 11:00:00+00'::timestamptz,i.owner_a),
  (i.expense_sibling,i.mixture_sibling,i.farm_a,current_date,14::numeric,'Sibling','Sibling note',
    '2026-01-02 10:00:00+00'::timestamptz,'2026-01-02 11:00:00+00'::timestamptz,i.owner_a),
  (i.expense_ended,i.mixture_ended,i.farm_a,current_date-1,15::numeric,'Ended','Hidden ended',
    '2026-01-02 10:00:00+00'::timestamptz,'2026-01-02 11:00:00+00'::timestamptz,i.owner_a),
  (i.expense_foreign,i.mixture_foreign,i.farm_b,current_date-1,16::numeric,'Foreign','Hidden foreign',
    '2026-01-02 10:00:00+00'::timestamptz,'2026-01-02 11:00:00+00'::timestamptz,i.owner_b)
) v(id,mixture_id,granja_id,occurred_on,amount,category,note,created_at,updated_at,created_by);
insert into public.legacy_mixture_expenses(id,mixture_id,granja_id,occurred_on,amount,
  category,note,created_at,updated_at,created_by)
select s.* from legacy_seed s;
set constraints all immediate;

-- Independent ADMIN preconditions prove the exact retained Cycle projection's
-- joins/predicates admit these rows. No RPC, target validator, or locking helper.
do $preconditions$
declare v_ids record;
begin
  select i.* into v_ids from pg_temp.ids i;
  perform pg_temp.check_true(exists(select 1 from economics_v2.cycles c
    join public.cat_proposito_animal p on p.id=c.proposito_id and p.codigo_calculo='carne'
    join economics_v2.feature_flags f on f.granja_id=c.granja_id and f.economics_v2_enabled
    join economics_v2.cycle_expenses e on e.cycle_id=c.id and e.granja_id=c.granja_id
    join public.miembros_granja m on m.granja_id=c.granja_id and m.user_id=v_ids.owner_a
    where c.id=v_ids.cycle_a and c.granja_id=v_ids.farm_a and m.rol='owner'
      and c.status='open' and c.starts_on<=current_date and c.ends_on is null
      and c.production_closed_on is null and e.id=v_ids.cycle_expense),
    'ADMIN precondition: real authorized flag-ON meat Cycle target AND expense are projectable');
  perform pg_temp.check_true((select count(*)=7 from public.legacy_mixture_expenses e
    join pg_temp.legacy_seed s on s.id=e.id and to_jsonb(e) @> to_jsonb(s)),
    'ADMIN precondition: all seven exact compatibility seed rows persisted');
end;
$preconditions$;
create temp table baseline as select pg_temp.business_state() state;
create function pg_temp.guard_dml() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if current_setting('expense_read.armed',true)='on' then
    perform nextval('pg_temp.attempted_dml'::regclass);
    raise exception using errcode='P0001',message='Legacy expense READ attempted persistent DML',
      detail=tg_table_schema||'.'||tg_table_name||' '||tg_op;
  end if;
  return null;
end;
$$;
do $observers$
declare v_table record;
begin
  for v_table in select w.* from pg_temp.watched w loop
    execute format('create trigger legacy_expense_read_observer
      before insert or update or delete or truncate on %I.%I
      for each statement execute function pg_temp.guard_dml()',v_table.schema_name,v_table.table_name);
  end loop;
  execute format('grant usage on schema %I to authenticated,anon',pg_my_temp_schema()::regnamespace::text);
end;
$observers$;
create function pg_temp.attempt_count() returns bigint
language sql security definer set search_path='' as $$
  select case when s.is_called then s.last_value else 0 end from pg_temp.attempted_dml s;
$$;
create function pg_temp.expected_result(p_role text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_ids record; v_expenses jsonb;
begin
  select i.* into v_ids from pg_temp.ids i;
  select jsonb_agg(jsonb_build_object(
    'expense_id',s.id,'target_kind','legacy_mixture','target_id',s.mixture_id,
    'target_label',case when s.mixture_id=v_ids.mixture_a then '  Read Group A  ' else 'Read sibling' end,
    'occurred_on',s.occurred_on,'amount',s.amount,'category',s.category,'note',s.note,
    'created_at',s.created_at,'updated_at',s.updated_at,'can_mutate',p_role in ('owner','editor'))
    order by s.occurred_on desc,s.created_at desc,s.id) into v_expenses
  from pg_temp.legacy_seed s where s.id in
    (v_ids.expense_a,v_ids.expense_tie,v_ids.expense_earlier_time,v_ids.expense_older,v_ids.expense_sibling);
  return jsonb_build_object('granja_id',v_ids.farm_a,'role',p_role,
    'can_edit',p_role in ('owner','editor'),'targets',jsonb_build_array(
      jsonb_build_object('target_kind','legacy_mixture','target_id',v_ids.mixture_sibling,
        'target_label','Read sibling','starts_on',current_date,'ends_on_exclusive',null),
      jsonb_build_object('target_kind','legacy_mixture','target_id',v_ids.mixture_a,
        'target_label','  Read Group A  ','starts_on',current_date-10,'ends_on_exclusive',null)),
    'expenses',v_expenses);
end;
$$;
-- INVOKER dispatch is deliberate: privileged helpers only collect evidence.
create function pg_temp.read_result(p_private boolean,p_farm uuid) returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  perform pg_temp.check_true(current_user in ('authenticated','anon'),'Real client SQL role executes READ');
  if p_private then return economics_v2.read_finance_expenses_impl(p_farm); end if;
  return public.list_finance_expenses(p_farm);
end;
$$;
create function pg_temp.check_pure(p_before jsonb,p_attempts bigint) returns void
language plpgsql security invoker set search_path='' as $$
begin
  perform pg_temp.check_true(pg_temp.attempt_count()=p_attempts,'READ made no DML attempt, even caught/zero-row');
  perform pg_temp.check_true(pg_temp.business_state()=p_before,
    'READ preserves full business rows, Group facts/ledger, Cycle tokens, ACLs, definitions and sequences');
end;
$$;
create function pg_temp.expect_denied(p_private boolean,p_farm uuid,p_message text) returns void
language plpgsql security invoker set search_path='' as $$
declare v_before jsonb := pg_temp.business_state(); v_attempts bigint := pg_temp.attempt_count();
  v_denied boolean := false; v_state text; v_message text;
begin
  begin
    perform pg_temp.read_result(p_private,p_farm);
  exception when others then
    get stacked diagnostics v_state=returned_sqlstate,v_message=message_text;
    -- Preserve the original first unexpected SQLSTATE/message/DETAIL/context.
    if v_state is distinct from '42501' or v_message is distinct from p_message then raise; end if;
    v_denied := true;
  end;
  perform pg_temp.check_true(v_denied,'Actual READ denied: '||p_message);
  perform pg_temp.check_pure(v_before,v_attempts);
end;
$$;
-- Explicit temp-only grants avoid relying on the administrator's default ACLs.
revoke all on function pg_temp.check_true(boolean,text),pg_temp.business_state(),
  pg_temp.attempt_count(),pg_temp.expected_result(text),pg_temp.read_result(boolean,uuid),
  pg_temp.check_pure(jsonb,bigint),pg_temp.expect_denied(boolean,uuid,text) from public;
grant execute on function pg_temp.check_true(boolean,text),pg_temp.business_state(),
  pg_temp.attempt_count(),pg_temp.expected_result(text),pg_temp.read_result(boolean,uuid),
  pg_temp.check_pure(jsonb,bigint),pg_temp.expect_denied(boolean,uuid,text) to authenticated,anon;
grant select on pg_temp.ids to authenticated;

do $read_contract$
declare v_ids record; v_result jsonb; v_public jsonb; v_private jsonb;
  v_before jsonb; v_attempts bigint; v_actor record; v_direct boolean;
begin
  select i.* into v_ids from pg_temp.ids i;
  perform set_config('request.jwt.claim.sub',v_ids.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_ids.owner_a,'role','authenticated')::text,true);
  perform set_config('expense_read.armed','on',true);
  v_before := pg_temp.business_state();
  v_attempts := pg_temp.attempt_count();
  set local role authenticated;
  -- FIRST actual, unwrapped READ: do not catch, transform, or filter this result.
  v_result := public.list_finance_expenses(v_ids.farm_a);
  perform pg_temp.check_true(not exists(select 1 from jsonb_array_elements(v_result->'targets') t
      where t->>'target_kind'='cycle')
    and not exists(select 1 from jsonb_array_elements(v_result->'expenses') e
      where e->>'target_kind'='cycle'),
    'HUMAN RED: legacy READ still exposes Cycle targets/expenses; remove BOTH projections only');
  perform pg_temp.check_pure(v_before,v_attempts);
  perform pg_temp.check_true(v_result=pg_temp.expected_result('owner'),
    'Owner exact five-field legacy envelope, target five-fields and expense eleven-fields; no contract_version');
  reset role;

  for v_actor in select * from (values (v_ids.owner_a,'owner'),
    (v_ids.editor_a,'editor'),(v_ids.viewer_a,'viewer')) a(user_id,role_name) loop
    perform set_config('request.jwt.claim.sub',v_actor.user_id::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',v_actor.user_id,'role','authenticated')::text,true);
    v_before := pg_temp.business_state();
    v_attempts := pg_temp.attempt_count();
    set local role authenticated;
    v_public := pg_temp.read_result(false,v_ids.farm_a);
    perform pg_temp.check_pure(v_before,v_attempts);
    v_private := pg_temp.read_result(true,v_ids.farm_a);
    perform pg_temp.check_pure(v_before,v_attempts);
    perform pg_temp.check_true(v_public=v_private and v_public=pg_temp.expected_result(v_actor.role_name),
      'Public/private exact compatibility: '||v_actor.role_name||
      '; raw labels/text/notes, UUIDs, amounts, time tokens, array order, current/ended/foreign filtering');
    reset role;
  end loop;

  perform set_config('request.jwt.claim.sub',v_ids.owner_a::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',v_ids.owner_a,'role','authenticated')::text,true);
  v_before := pg_temp.business_state();
  begin
    -- Only deliberate ADMIN flag setup is unarmed. ALL metadata is restored by
    -- exception rollback, including trigger-updated timestamps and any side effects.
    perform set_config('expense_read.armed','off',true);
    update economics_v2.feature_flags set economics_v2_enabled=false where granja_id=v_ids.farm_a;
    perform set_config('expense_read.armed','on',true);
    declare v_off_state jsonb := pg_temp.business_state();
    begin
      set local role authenticated;
      v_public := pg_temp.read_result(false,v_ids.farm_a);
      perform pg_temp.check_pure(v_off_state,v_attempts);
      v_private := pg_temp.read_result(true,v_ids.farm_a);
      perform pg_temp.check_pure(v_off_state,v_attempts);
      perform pg_temp.check_true(v_public=v_private and v_public=pg_temp.expected_result('owner'),
        'Flag OFF: no Cycle target/expense; identical legacy mixtures remain readable');
      reset role;
    end;
    raise exception using errcode='Z0001',message='Restore complete flag probe';
  exception when sqlstate 'Z0001' then
    if sqlerrm <> 'Restore complete flag probe' then raise; end if;
  end;
  perform pg_temp.check_true(pg_temp.business_state()=v_before,'Entire flag probe metadata/state restored');
  perform pg_temp.check_true(pg_temp.attempt_count()=v_attempts,'Flag probe made no hidden READ DML attempt');
  -- Assertions inside the sentinel subtransaction rolled back too; record the
  -- successfully obtained OFF results again outside it for durable temp evidence.
  perform pg_temp.check_true(v_public=v_private and v_public=pg_temp.expected_result('owner'),
    'Completed flag-OFF public/private reads preserve exact legacy compatibility');

  foreach v_direct in array array[false,true] loop
    for v_actor in select * from (values (v_ids.outsider,v_ids.farm_a),
      (v_ids.owner_b,v_ids.farm_a),(v_ids.owner_a,v_ids.farm_b),(null::uuid,v_ids.farm_a)) a(user_id,farm_id) loop
      perform set_config('request.jwt.claim.sub',coalesce(v_actor.user_id::text,''),true);
      perform set_config('request.jwt.claims',case when v_actor.user_id is null then '{}'
        else jsonb_build_object('sub',v_actor.user_id,'role','authenticated')::text end,true);
      set local role authenticated;
      perform pg_temp.expect_denied(v_direct,v_actor.farm_id,case when v_actor.user_id is null
        then 'Authentication required' else 'Finance expense access denied' end);
      reset role;
    end loop;
  end loop;
  perform set_config('request.jwt.claim.sub','',true);
  perform set_config('request.jwt.claims','{}',true);
  set local role anon;
  perform pg_temp.expect_denied(false,v_ids.farm_a,'permission denied for function list_finance_expenses');
  reset role;
end;
$read_contract$;

do $catalog_contract$
declare v_proc record;
begin
  perform pg_temp.check_true((select count(*)=2 from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='public' and p.proname='list_finance_expenses')
      or (n.nspname='economics_v2' and p.proname='read_finance_expenses_impl')),
    'Exactly one public and one private reader; no overload');
  for v_proc in select p.*,n.nspname from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where p.oid in ('public.list_finance_expenses(uuid)'::regprocedure,
      'economics_v2.read_finance_expenses_impl(uuid)'::regprocedure) loop
    perform pg_temp.check_true(v_proc.prorettype='jsonb'::regtype
      and v_proc.pronargs=1 and v_proc.proargtypes[0]='uuid'::regtype
      and v_proc.proargnames=array['p_granja_id']
      and v_proc.pronargdefaults=0 and not v_proc.proretset and v_proc.provolatile='v'
      and v_proc.prosecdef=(v_proc.nspname='economics_v2')
      and v_proc.proconfig @> array['search_path=""']
      and has_function_privilege('authenticated',v_proc.oid,'EXECUTE')
      and not has_function_privilege('anon',v_proc.oid,'EXECUTE')
      and not exists(select 1 from aclexplode(coalesce(v_proc.proacl,acldefault('f',v_proc.proowner))) x
        where x.grantee=0 and x.privilege_type='EXECUTE'),
      'Reader keeps UUID named input/no defaults, JSONB VOLATILE, invoker/definer, empty path and EXECUTE ACL');
  end loop;
  perform pg_temp.check_true(pg_temp.business_state()=(select b.state from pg_temp.baseline b)
    and pg_temp.attempt_count()=0,'Final exact baseline and zero persistent DML attempts');
end;
$catalog_contract$;

-- Emitted ONLY if the human execution reaches every assertion. No HTTP/runtime
-- result or canonical/mutation regression proof is implied by authoring this file.
select 'group_economics_forward_legacy_expense_read_pass' evidence,
  (select count(*) from assertions) assertion_count,to_jsonb(i) fixture_ids,
  true legacy_finance_read_cycle_projection_removed,true legacy_mixture_read_compatibility_proven,
  false legacy_expense_guards_integrated,false all_legacy_mutation_paths_guarded,
  false canonical_api_integrated,false http,false production,'pending' independent_review,
  'sequential_only' locking,false realclosure
from ids i;

rollback;
