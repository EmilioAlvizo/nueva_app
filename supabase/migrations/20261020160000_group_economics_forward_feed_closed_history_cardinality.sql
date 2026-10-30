-- Structural compatibility only: no finalization, digest refresh or snapshot producer.
-- H is a private classification, not authorization; the direct-client guard is unchanged.
create function group_feed_integrity.is_closed_feed_history(p_header public.mezcla)
returns boolean language plpgsql volatile security invoker set search_path='' as $$
begin
  return exists (
    select 1 from economics_v2.group_period_feed_allocations a
    join economics_v2.group_occupancy_periods p
      on p.id=a.period_id and p.granja_id=a.granja_id
    join public.grupos g on g.id=p.group_id and g.granja_id=p.granja_id
    join public.cat_proposito_animal c on c.id=p.purpose_id and c.granja_id=p.granja_id
    join economics_v2.group_meat_snapshots s
      on s.period_id=p.id and s.granja_id=p.granja_id
    where a.mixture_id=p_header.id and a.granja_id=p_header.granja_id
      and p.group_id=p_header.grupo_id and c.codigo_calculo='carne'
      and p.closed_on is not null and p.end_position is not null
      and pg_catalog.isfinite(p.starts_on) and pg_catalog.isfinite(p.closed_on)
      and p.starts_on<=p.closed_on and p.end_position>p.start_position
      and a.finalized_at is not null and pg_catalog.isfinite(a.finalized_at)
      and pg_catalog.isfinite(p_header.fecha_inicio)
      and p_header.fecha_inicio between p.starts_on and p.closed_on
      and a.occurred_on=p_header.fecha_inicio
      and pg_catalog.isfinite(p_header.updated_at)
      and a.source_updated_at=p_header.updated_at
      and s.snapshot_version='group-meat-snapshot.forward.v3'
      and pg_catalog.jsonb_typeof(s.payload->'group_name')='string'
      and s.payload->>'purpose_code'='carne'
      -- CASE, not planner-dependent AND order, protects object_keys from arrays.
      and case when pg_catalog.jsonb_typeof(s.payload->'metrics')='object' then
        (select pg_catalog.array_agg(k order by k)
         from pg_catalog.jsonb_object_keys(s.payload->'metrics') k)
        = array['acquisition_cost','active_animal_count','animal_count','animal_sale_revenue',
          'balance_per_animal','break_even_kg','direct_expense_total','exited_animal_count','feed_cost',
          'feed_kg_total','feed_source_count','profit','realized_price_per_kg','sale_count','saleable_kg',
          'sold_animal_count','total_cost']::text[]
      else false end
  );
end;
$$;

-- Shared immediate/queue gate: WHEN captures feed presence at the original UPDATE,
-- so later deletion/reopening cannot erase the deferred obligation. No new lock scope.
create function group_feed_integrity.is_feed_closure_transition(
  p_old economics_v2.group_occupancy_periods, p_new economics_v2.group_occupancy_periods
) returns boolean language sql volatile security invoker set search_path='' as $$
  select p_old.closed_on is null and p_old.end_position is null
    and p_new.closed_on is not null and p_new.end_position is not null
    and row(p_old.id,p_old.granja_id,p_old.group_id,p_old.purpose_id,p_old.starts_on,p_old.start_position)
      is not distinct from
        row(p_new.id,p_new.granja_id,p_new.group_id,p_new.purpose_id,p_new.starts_on,p_new.start_position)
    and pg_catalog.isfinite(p_new.starts_on) and pg_catalog.isfinite(p_new.closed_on)
    and p_new.starts_on<=p_new.closed_on and p_new.end_position>p_new.start_position
    and exists(select 1 from public.cat_proposito_animal c
      join public.grupos g on g.id=p_new.group_id and g.granja_id=p_new.granja_id
      where c.id=p_new.purpose_id and c.granja_id=p_new.granja_id and c.codigo_calculo='carne')
    and exists(select 1 from economics_v2.group_period_feed_allocations a where a.period_id=p_new.id);
$$;

-- O = date-open headers minus H. Retain all original operational date/window checks.
create or replace function group_feed_integrity.check_group(p_group uuid)
returns void language plpgsql volatile security invoker set search_path='' as $$
declare v_farm uuid; v_period economics_v2.group_occupancy_periods%rowtype;
begin
  select g.granja_id into v_farm from public.grupos g where g.id=p_group;
  v_period := group_feed_integrity.meat_period(p_group,v_farm);
  if (select pg_catalog.count(*) from public.mezcla m
    where m.grupo_id=p_group and m.fecha_termino is null
      and not group_feed_integrity.is_closed_feed_history(m))>1
    and (v_period.id is null or exists(select 1 from public.mezcla m
      where m.grupo_id=p_group and m.fecha_termino is null
        and not group_feed_integrity.is_closed_feed_history(m)
        and (m.granja_id is distinct from v_farm
          or m.fecha_inicio is null or not pg_catalog.isfinite(m.fecha_inicio)
          or m.fecha_inicio<v_period.starts_on or m.fecha_inicio>current_date
          or exists(select 1 from economics_v2.group_occupancy_periods p
            where p.granja_id=v_farm and p.group_id=p_group
              and p.purpose_id=v_period.purpose_id and p.starts_on>m.fecha_inicio)))) then
    raise exception using errcode='23514',
      message='Metadata change would remove the multiple-mixture meat exemption';
  end if;
  update public.mezcla m set group_feed_meat_exempt=false
  where m.grupo_id=p_group and m.group_feed_meat_exempt
    and not group_feed_integrity.is_closed_feed_history(m)
    and (v_period.id is null or m.granja_id is distinct from v_farm
      or m.fecha_inicio is null or not pg_catalog.isfinite(m.fecha_inicio)
      or m.fecha_inicio<v_period.starts_on or m.fecha_inicio>current_date
      or exists(select 1 from economics_v2.group_occupancy_periods p
        where p.granja_id=v_farm and p.group_id=p_group
          and p.purpose_id=v_period.purpose_id and p.starts_on>m.fecha_inicio)
      or (m.fecha_termino is not null and (not pg_catalog.isfinite(m.fecha_termino)
        or m.fecha_termino<m.fecha_inicio or m.fecha_termino>current_date)));
end;
$$;

create or replace function public.enforce_group_active_mixture()
returns trigger language plpgsql volatile security definer set search_path='' as $$
declare
  v_groups uuid[];
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_admissible boolean;
  v_business_change boolean := true;
begin
  -- Retain fresh-snapshot admission and the original Group fence order.
  if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
    raise exception using errcode='40001',
      message='Feed header writes require a Read Committed transaction';
  end if;
  if tg_op='INSERT' then
    v_groups := array[new.grupo_id];
  elsif tg_op='DELETE' then
    v_groups := array[old.grupo_id];
  else
    v_groups := array[old.grupo_id,new.grupo_id];
    v_business_change := new.grupo_id is distinct from old.grupo_id
      or new.granja_id is distinct from old.granja_id
      or new.fecha_inicio is distinct from old.fecha_inicio
      or new.fecha_termino is distinct from old.fecha_termino;
  end if;
  perform group_feed_integrity.touch('group',v_groups);
  -- Classify OLD before inspecting NEW: a changed date/version cannot demote H.
  if tg_op<>'INSERT' then
    if group_feed_integrity.is_closed_feed_history(old) then
      if tg_op='DELETE' then
        raise exception using errcode='23514', message='Closed feed history is immutable';
      end if;
      if new is distinct from old then
        raise exception using errcode='23514', message='Closed feed history is immutable';
      end if;
      return old;
    end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  new.group_feed_meat_exempt := false;
  if new.grupo_id is null then return new; end if;
  if not exists(select 1 from public.grupos g
    where g.id=new.grupo_id and g.granja_id=new.granja_id) then
    raise exception using errcode='23503',
      message='Feed mixture group must belong to the same farm';
  end if;
  v_period := group_feed_integrity.meat_period(new.grupo_id,new.granja_id);
  if v_period.id is not null then
    v_admissible := group_feed_integrity.admissible(v_period,new.fecha_inicio,new.fecha_termino);
    if v_admissible is distinct from true and v_business_change then
      raise exception using errcode='22023',
        message='Feed mixture dates are not admissible for the open meat period';
    end if;
    -- Metadata-only writes cannot spoof a marker or trigger sibling auto-closure.
    new.group_feed_meat_exempt := v_admissible is true;
    return new;
  end if;
  if new.fecha_termino is not null or not v_business_change then return new; end if;
  if exists(select 1 from public.mezcla m
    where m.grupo_id=new.grupo_id and m.granja_id=new.granja_id
      and m.fecha_termino is null and m.id<>new.id
      and not group_feed_integrity.is_closed_feed_history(m)
      and m.fecha_inicio>new.fecha_inicio) then
    raise exception using errcode='22023',
      message='An active mixture cannot start before the current group mixture';
  end if;
  -- Preserve singleton date-end semantics and the untouched posture sync.
  update public.mezcla m
  set fecha_termino=new.fecha_inicio,updated_at=pg_catalog.now()
  where m.grupo_id=new.grupo_id and m.granja_id=new.granja_id
    and m.fecha_termino is null and m.id<>new.id
    and not group_feed_integrity.is_closed_feed_history(m);
  return new;
end;
$$;

create or replace function group_feed_integrity.period_after()
returns trigger language plpgsql volatile security definer set search_path='' as $$
declare v_groups uuid[]; v_id uuid;
begin
  if tg_op='UPDATE' then
    if group_feed_integrity.is_feed_closure_transition(old,new) then return null; end if;
  end if;
  if tg_op='INSERT' then v_groups := array[new.group_id];
  elsif tg_op='DELETE' then v_groups := array[old.group_id];
  else v_groups := array[old.group_id,new.group_id]; end if;
  for v_id in select distinct u.id from pg_catalog.unnest(v_groups) u(id) order by u.id loop
    perform group_feed_integrity.check_group(v_id);
  end loop;
  return null;
end;
$$;

create function group_feed_integrity.check_feed_closure()
returns trigger language plpgsql volatile security definer set search_path='' as $$
declare v_period economics_v2.group_occupancy_periods%rowtype;
begin
  -- Same purpose->Group fences as period_before; no new entities or lock family.
  perform group_feed_integrity.touch('purpose',array[new.purpose_id]);
  perform group_feed_integrity.touch('group',array[new.group_id]);
  select p.* into v_period from economics_v2.group_occupancy_periods p where p.id=new.id;
  -- Queued NEW is authoritative. In particular, an OPEN final row is not a no-op.
  if not found or row(v_period.id,v_period.granja_id,v_period.group_id,v_period.purpose_id,
      v_period.starts_on,v_period.start_position,v_period.closed_on,v_period.end_position)
    is distinct from row(new.id,new.granja_id,new.group_id,new.purpose_id,
      new.starts_on,new.start_position,new.closed_on,new.end_position) then
    raise exception using errcode='23514', message='Feed closure identity or bounds changed';
  end if;
  if not exists(select 1 from economics_v2.group_period_feed_allocations a where a.period_id=new.id)
    or exists(select 1 from economics_v2.group_period_feed_allocations a
      left join public.mezcla m on m.id=a.mixture_id
      where a.period_id=new.id and (m.id is null
        or not group_feed_integrity.is_closed_feed_history(m))) then
    raise exception using errcode='23514', message='Feed closure requires finalized matching sources and snapshot';
  end if;
  -- Missing/unqualified sources remain O; only actual H receives the exemption.
  perform group_feed_integrity.check_group(new.group_id);
  return null;
end;
$$;

-- WHEN is evaluated at UPDATE time, not at deferred callback execution time.
create constraint trigger group_feed_cardinality_closed_history
after update on economics_v2.group_occupancy_periods
deferrable initially deferred for each row
when (group_feed_integrity.is_feed_closure_transition(old,new))
execute function group_feed_integrity.check_feed_closure();

-- CREATE OR REPLACE retains existing owners/ACLs. Only new private objects get ACL DDL.
alter function group_feed_integrity.is_closed_feed_history(public.mezcla) owner to postgres;
alter function group_feed_integrity.is_feed_closure_transition(
  economics_v2.group_occupancy_periods,economics_v2.group_occupancy_periods) owner to postgres;
alter function group_feed_integrity.check_feed_closure() owner to postgres;
revoke all on function group_feed_integrity.is_closed_feed_history(public.mezcla)
  from public, anon, authenticated, service_role;
revoke all on function group_feed_integrity.is_feed_closure_transition(
  economics_v2.group_occupancy_periods,economics_v2.group_occupancy_periods)
  from public, anon, authenticated, service_role;
revoke all on function group_feed_integrity.check_feed_closure()
  from public, anon, authenticated, service_role;
