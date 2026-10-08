begin;

create temp table fixture_scope as
select gen_random_uuid() owner_a, gen_random_uuid() owner_b, gen_random_uuid() editor,
  gen_random_uuid() viewer, gen_random_uuid() outsider, gen_random_uuid() farm_a,
  gen_random_uuid() farm_b, gen_random_uuid() farm_empty, gen_random_uuid() farm_off,
  gen_random_uuid() type_a, gen_random_uuid() type_b, gen_random_uuid() meat_a,
  gen_random_uuid() meat_b, gen_random_uuid() eggs_a;
create temp table fixture_periods as
select n, gen_random_uuid() period_id, gen_random_uuid() group_id
from generate_series(1, 55) n;

create function pg_temp.check_true(ok boolean, label text) returns void language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'F1BR: %', label; end if;
end;
$$;
create function pg_temp.expect_error(statement text, expected_state text, expected_code text default null)
returns void language plpgsql as $$
declare actual_state text; actual_detail text;
begin
  begin
    execute statement;
  exception when others then
    get stacked diagnostics actual_state = returned_sqlstate, actual_detail = pg_exception_detail;
    perform pg_temp.check_true(actual_state = expected_state, statement || ': ' || actual_state);
    if expected_code is not null then
      perform pg_temp.check_true(actual_detail::jsonb->>'code' = expected_code
        and actual_detail::jsonb->>'contract_version' = 'group-economics.forward.v3'
        and actual_detail::jsonb ?& array['field','entity_id'], 'typed error detail');
    end if;
    return;
  end;
  raise exception 'F1BR: expected error for %', statement;
end;
$$;
create function pg_temp.read_page(farm uuid, size integer default 25, anchor date default null,
  period uuid default null, read_position bigint default null) returns jsonb language plpgsql as $$
begin
  return public.list_group_economics(p_granja_id => farm, p_page_size => size,
    p_cursor_starts_on => anchor, p_cursor_period_id => period, p_cursor_read_position => read_position);
end;
$$;

select pg_temp.check_true(
  not exists(select 1 from auth.users where raw_user_meta_data->>'fixture' = 'f1br-forward-public-read')
  and not exists(select 1 from public.granjas where nombre like 'F1BR %'), 'empty marker baseline');
insert into auth.users(id, aud, role, raw_user_meta_data, created_at, updated_at)
select actor, 'authenticated', 'authenticated', '{"fixture":"f1br-forward-public-read"}', now(), now()
from fixture_scope s cross join lateral unnest(array[owner_a,owner_b,editor,viewer,outsider]) actor;
insert into public.granjas(id, owner_id, nombre, created_by)
select farm, owner, 'F1BR ' || label, owner from fixture_scope s
cross join lateral (values (farm_a,owner_a,'A'),(farm_b,owner_b,'B'),
  (farm_empty,owner_a,'empty'),(farm_off,owner_a,'off')) v(farm,owner,label);
insert into public.miembros_granja(granja_id,user_id,rol)
select farm_a, editor, 'editor'::public.rol_miembro from fixture_scope
union all select farm_a, viewer, 'viewer'::public.rol_miembro from fixture_scope;
insert into economics_v2.feature_flags(granja_id,economics_v2_enabled)
select farm, enabled from fixture_scope s
cross join lateral (values (farm_a,true),(farm_b,true),(farm_empty,true),(farm_off,false)) v(farm,enabled);
insert into public.tipo_animal(id,granja_id,nombre,created_by)
select type_a,farm_a,'F1BR A',owner_a from fixture_scope
union all select type_b,farm_b,'F1BR B',owner_b from fixture_scope;
insert into public.cat_proposito_animal(id,granja_id,nombre,codigo_calculo,created_by)
select purpose,farm,code,code,owner from fixture_scope s cross join lateral
  (values (meat_a,farm_a,'carne',owner_a),(meat_b,farm_b,'carne',owner_b),
    (eggs_a,farm_a,'postura',owner_a)) v(purpose,farm,code,owner);
insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
select group_id,case when n=55 then farm_b else farm_a end,
  case when n=55 then type_b else type_a end,'F1BR live ' || n,
  case when n=55 then owner_b else owner_a end from fixture_periods cross join fixture_scope;
insert into economics_v2.group_occupancy_periods(id,granja_id,group_id,purpose_id,starts_on,closed_on,start_position,end_position)
select period_id,case when n=55 then farm_b else farm_a end,group_id,
  case when n=55 then meat_b when n=53 then eggs_a else meat_a end,
  current_date - (52-least(n,52))/2,case when n<>52 then current_date end,
  case when n=54 then 101 else n end,case when n<>52 then n+102 end
from fixture_periods cross join fixture_scope;
insert into economics_v2.group_occupancy_events(granja_id,period_id,event_position,effective_on,action)
select farm_a,period_id,100,current_date,'enter' from fixture_periods cross join fixture_scope where n=52
union all select farm_b,period_id,1000,current_date,'enter' from fixture_periods cross join fixture_scope where n=55;
insert into economics_v2.group_meat_snapshots(period_id,granja_id,snapshot_version,payload)
select p.id,p.granja_id,'group-meat-snapshot.forward.v3',jsonb_build_object(
  'group_name','F1BR frozen ' || f.n,'purpose_code','carne',
  'metrics',economics_v2.calculate_group_period_live_metrics(p.granja_id,p.id))
from economics_v2.group_occupancy_periods p join fixture_periods f on f.period_id=p.id where f.n<=51 or f.n=54;
insert into economics_v2.group_period_expenses(granja_id,period_id,occurred_on,amount,category,created_by)
select farm_a,period_id,current_date,case when n=52 then 7 else 99 end,'F1BR probe',owner_a
from fixture_periods cross join fixture_scope where n in (51,52);
set constraints all immediate;
grant select on fixture_scope,fixture_periods to authenticated;

do $proof$
declare s record; a record; first_page jsonb; page jsonb; cursor jsonb; item jsonb;
  expected jsonb; seen jsonb := '[]'; actor uuid; bad record; statement text;
begin
  select * into s from fixture_scope;
  perform set_config('request.jwt.claim.sub',s.owner_a::text,true);
  set local role authenticated;
  first_page := pg_temp.read_page(s.farm_a,1);
  perform pg_temp.check_true(first_page @> '{"contract_version":"group-economics.forward.v3",
    "item_version":"group-economics-item.forward.v3","cursor_version":"period-start-id-position.v1",
    "read_position":100,"has_more":true}', 'versions and farm-bound position');
  perform pg_temp.check_true((select array_agg(k order by k) from jsonb_object_keys(first_page) k)
    = array['contract_version','cursor_version','has_more','item_version','items','next_cursor','read_position'], 'exact page keys');
  select jsonb_agg(period_id::text order by current_date-(52-n)/2 desc,period_id desc)
    into expected from fixture_periods where n<=52;
  for actor in select unnest(array[s.owner_a,s.editor,s.viewer]) loop
    perform set_config('request.jwt.claim.sub',actor::text,true);
    for size in 1..50 loop
      page := pg_temp.read_page(s.farm_a,size);
      perform pg_temp.check_true(jsonb_array_length(page->'items')=size, 'accepted page size and reader role');
    end loop;
  end loop;
  perform set_config('request.jwt.claim.sub',s.owner_a::text,true);
  page := pg_temp.read_page(s.farm_a,50);
  loop
    for item in select value from jsonb_array_elements(page->'items') loop
      seen := seen || jsonb_build_array(item->>'period_id');
      perform pg_temp.check_true((select array_agg(k order by k) from jsonb_object_keys(item) k)
        = array['closed_on','end_position','granja_id','group_id','group_name','metrics','metrics_source',
          'metrics_version','period_id','purpose_code','purpose_id','snapshot_id','stable_key','start_position','starts_on','status'], 'exact item keys');
      perform pg_temp.check_true(item->>'stable_key'='group-period:' || (item->>'period_id'), 'stable key');
      if item->>'status'='open' then
        perform pg_temp.check_true(item->>'metrics_source'='live' and item->'snapshot_id'='null'::jsonb
          and item->>'metrics_version'='group-economics.forward.v3'
          and item->'metrics'->>'total_cost'='7' and item->>'group_name' like 'F1BR live %', 'OPEN live facts');
      else
        perform pg_temp.check_true(item->>'status'='closed' and item->>'metrics_source'='snapshot'
          and item->>'metrics_version'='group-meat-snapshot.forward.v3'
          and item->'metrics'->>'total_cost'='0' and item->>'group_name' like 'F1BR frozen %'
          and item->>'snapshot_id' is not null, 'CLOSED snapshot-only facts and labels');
      end if;
    end loop;
    exit when not (page->>'has_more')::boolean;
    cursor := page->'next_cursor';
    perform pg_temp.check_true((select array_agg(k order by k) from jsonb_object_keys(cursor) k)
      = array['period_id','read_position','starts_on'] and cursor->'read_position'=page->'read_position'
      and cursor->'period_id'=page->'items'->-1->'period_id'
      and cursor->'starts_on'=page->'items'->-1->'starts_on', 'exact nonterminal cursor');
    page := pg_temp.read_page(s.farm_a,50,(cursor->>'starts_on')::date,
      (cursor->>'period_id')::uuid,(cursor->>'read_position')::bigint);
  end loop;
  perform pg_temp.check_true(seen=expected and page->'next_cursor'='null'::jsonb, 'complete descending date/id seek');
  page := pg_temp.read_page(s.farm_empty);
  perform pg_temp.check_true(page @> '{"read_position":0,"items":[],"has_more":false,"next_cursor":null}', 'empty zero position');
  foreach actor in array array[s.outsider,s.owner_b] loop
    perform set_config('request.jwt.claim.sub',actor::text,true);
    perform pg_temp.expect_error(format('select pg_temp.read_page(%L)',s.farm_a),'42501','forbidden');
    perform pg_temp.expect_error(format('select economics_v2.list_group_economics_impl(%L,25,null,null,null)',
      s.farm_a),'42501','forbidden');
  end loop;
  perform set_config('request.jwt.claim.sub','',true);
  perform pg_temp.expect_error(format('select pg_temp.read_page(%L)',s.farm_a),'42501','forbidden');
  perform set_config('request.jwt.claim.sub',s.owner_a::text,true);
  perform pg_temp.expect_error(format('select pg_temp.read_page(%L)',s.farm_off),'42501','forbidden');
  for bad in select unnest(array[null,0,51,-1]) size loop
    perform pg_temp.expect_error(format('select pg_temp.read_page(%L,%L)',s.farm_a,bad.size),'22023','invalid_request');
  end loop;
  perform pg_temp.expect_error('select pg_temp.read_page(null)','22023','invalid_request');
  cursor := first_page->'next_cursor';
  for bad in select * from (values
    (null::date,null::uuid,100::bigint),(current_date,null::uuid,100::bigint),
    (current_date,null::uuid,null::bigint),(null::date,(cursor->>'period_id')::uuid,null::bigint),
    (null::date,(cursor->>'period_id')::uuid,100::bigint),
    ((cursor->>'starts_on')::date,(cursor->>'period_id')::uuid,null::bigint),
    ((cursor->>'starts_on')::date,(cursor->>'period_id')::uuid,-1::bigint),
    ((cursor->>'starts_on')::date,(cursor->>'period_id')::uuid,101::bigint),
    ((cursor->>'starts_on')::date,(cursor->>'period_id')::uuid,0::bigint),
    (current_date+1,(cursor->>'period_id')::uuid,100::bigint),
    (current_date-100,(cursor->>'period_id')::uuid,100::bigint),
    (current_date,gen_random_uuid(),100::bigint)) v(anchor,period,read_position)
    union all select current_date,period_id,100 from fixture_periods where n in (53,54,55)
  loop
    perform pg_temp.expect_error(format('select pg_temp.read_page(%L,25,%L,%L,%L)',
      s.farm_a,bad.anchor,bad.period,bad.read_position),'22023','invalid_cursor');
  end loop;
  -- Retained four-parameter stubs and five-parameter defaults overlap in PostgreSQL.
  -- Resolve their old function identities explicitly: neither may retain EXECUTE.
  perform pg_temp.check_true(
    not has_function_privilege('authenticated','public.list_group_economics(uuid,integer,date,uuid)','execute')
    and not has_function_privilege('authenticated','economics_v2.list_group_economics_impl(uuid,integer,date,uuid)','execute'),
    'both old signatures revoked');
  for statement in select unnest(array[
    format('select public.list_group_economics(%L::uuid,25,null::date,null::uuid)',s.farm_a),
    format('select economics_v2.list_group_economics_impl(%L::uuid,25,null::date,null::uuid)',s.farm_a)]) loop
    perform pg_temp.expect_error(statement,case when statement like 'select public.%' then '42725' else '42501' end);
  end loop;
  -- Invalid wire types fail at PostgreSQL binding, before the typed reader body.
  perform pg_temp.expect_error(format('select pg_temp.read_page(%L,25,current_date,''wrong'',100)',s.farm_a),'22P02');
  perform pg_temp.expect_error(format('select pg_temp.read_page(%L,25,''not-a-date'',null,100)',s.farm_a),'22007');
  perform pg_temp.expect_error(format('select pg_temp.read_page(%L,25,current_date,null,''wrong'')',s.farm_a),'22P02');
  for statement in select unnest(array[
    format('select economics_v2.calculate_group_period_live_metrics(%L,%L)',s.farm_a,cursor->>'period_id'),
    'select * from economics_v2.group_occupancy_periods']) loop
    perform pg_temp.expect_error(statement,'42501');
  end loop;
  reset role;
  set local role anon;
  perform pg_temp.expect_error(format('select public.list_group_economics(%L,25,null,null,null)',s.farm_a),'42501');
  reset role;
end;
$proof$;

do $history$
declare s record; boundary jsonb; page jsonb; group_id uuid := gen_random_uuid();
  later_id uuid := gen_random_uuid(); missing_id uuid := gen_random_uuid();
begin
  select * into s from fixture_scope;
  boundary := pg_temp.read_page(s.farm_a,1)->'next_cursor';
  insert into public.grupos(id,granja_id,tipo_animal_id,nombre,created_by)
  values(group_id,s.farm_a,s.type_a,'F1BR later',s.owner_a);
  insert into economics_v2.group_occupancy_periods(id,granja_id,group_id,purpose_id,starts_on,start_position)
  values(later_id,s.farm_a,group_id,s.meat_a,current_date-10,110);
  insert into economics_v2.group_occupancy_events(granja_id,period_id,event_position,effective_on,action)
  values(s.farm_a,later_id,110,current_date,'enter');
  page := pg_temp.read_page(s.farm_a,50,(boundary->>'starts_on')::date,
    (boundary->>'period_id')::uuid,(boundary->>'read_position')::bigint);
  perform pg_temp.check_true(page->>'read_position'='100'
    and not exists(select 1 from jsonb_array_elements(page->'items') i where i->>'period_id'=later_id::text), 'later history excluded');
  perform pg_temp.check_true(pg_temp.read_page(s.farm_a,50)->>'read_position'='110', 'fresh page advances position');
  insert into economics_v2.group_occupancy_periods(id,granja_id,group_id,purpose_id,starts_on,closed_on,start_position,end_position)
  select missing_id,s.farm_a,f.group_id,s.meat_a,current_date,current_date,111,112
  from fixture_periods f where n=53;
  insert into economics_v2.group_occupancy_events(granja_id,period_id,event_position,effective_on,action)
  values(s.farm_a,missing_id,111,current_date,'exit');
  perform pg_temp.expect_error(format('select pg_temp.read_page(%L,50)',s.farm_a),'23514','missing_closed_snapshot');
  insert into economics_v2.group_meat_snapshots(period_id,granja_id,snapshot_version,payload)
  values(missing_id,s.farm_a,'wrong-version','{}');
  perform pg_temp.expect_error(format('select pg_temp.read_page(%L,50)',s.farm_a),'23514','invariant_violation');
  perform pg_temp.expect_error('update economics_v2.group_meat_snapshots set payload=''{}''
    where period_id in (select period_id from fixture_periods)','23514');
  perform pg_temp.expect_error('delete from economics_v2.group_meat_snapshots
    where period_id in (select period_id from fixture_periods)','23514');
end;
$history$;

select pg_temp.check_true(
  (select not p.prosecdef and p.proconfig @> array['search_path=""']
    and p.proargnames=array['p_granja_id','p_page_size','p_cursor_starts_on','p_cursor_period_id','p_cursor_read_position']
    and has_function_privilege('authenticated',p.oid,'execute')
    and not has_function_privilege('anon',p.oid,'execute')
    and not has_function_privilege('public',p.oid,'execute')
    from pg_proc p where p.oid='public.list_group_economics(uuid,integer,date,uuid,bigint)'::regprocedure)
  and (select p.prosecdef and p.proconfig @> array['search_path=""']
    from pg_proc p where p.oid='economics_v2.list_group_economics_impl(uuid,integer,date,uuid,bigint)'::regprocedure),
  'five-parameter invoker and guarded private definer');
select jsonb_build_object('result','group_economics_forward_read_pass',
  'roles',3,'accepted_page_sizes',50,'bounded_periods',52,'invalid_cursor_cases',15) as evidence;
rollback;
