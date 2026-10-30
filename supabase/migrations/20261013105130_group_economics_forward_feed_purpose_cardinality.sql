-- Header cardinality only. No business producer, allocation, receipt or closure core changes.
-- Existing headers remain conservatively unclassified; there is no purpose backfill.
-- Internal fences live outside public/economics_v2: serialization is not an economic fact.
create schema group_feed_integrity;
revoke all on schema group_feed_integrity from public, anon, authenticated, service_role;

create table group_feed_integrity.fences (
  scope text not null check (scope in ('group', 'purpose')),
  entity_id uuid not null,
  revision bigint not null default 0,
  primary key (scope, entity_id)
);
alter table group_feed_integrity.fences enable row level security;
alter table group_feed_integrity.fences force row level security;
revoke all on table group_feed_integrity.fences from public, anon, authenticated, service_role;

alter table public.mezcla
  add column group_feed_meat_exempt boolean not null default false;
comment on column public.mezcla.group_feed_meat_exempt is
  'Server-maintained header exemption; never a caller-supplied purpose claim.';

-- UPDATE, not just a lock: a waiter with an older Repeatable Read snapshot must abort.
-- Upsert also fences first use of a previously unseen Group/purpose.
create function group_feed_integrity.touch(p_scope text, p_ids uuid[])
returns void language plpgsql volatile security invoker set search_path='' as $$
declare v_id uuid;
begin
  for v_id in select distinct u.id from pg_catalog.unnest(p_ids) u(id)
    where u.id is not null order by u.id
  loop
    insert into group_feed_integrity.fences as f(scope,entity_id,revision)
    values(p_scope,v_id,1)
    on conflict(scope,entity_id) do update set revision=f.revision+1;
  end loop;
end;
$$;

-- Count every open purpose before testing ownership/code. Invalid metadata is fallback,
-- not a reason to ignore another open period. No animal membership or allocation lookup.
create function group_feed_integrity.meat_period(p_group uuid, p_farm uuid)
returns economics_v2.group_occupancy_periods
language plpgsql volatile security invoker set search_path='' as $$
declare v_period economics_v2.group_occupancy_periods%rowtype;
begin
  if (select pg_catalog.count(*) from economics_v2.group_occupancy_periods p
    where p.group_id=p_group and p.granja_id=p_farm
      and p.closed_on is null and p.end_position is null) <> 1 then
    return null;
  end if;
  select p.* into v_period
  from economics_v2.group_occupancy_periods p
  join public.cat_proposito_animal c on c.id=p.purpose_id and c.granja_id=p.granja_id
  join public.grupos g on g.id=p.group_id and g.granja_id=p.granja_id
  where p.group_id=p_group and p.granja_id=p_farm
    and p.closed_on is null and p.end_position is null
    and c.codigo_calculo='carne'
    and pg_catalog.isfinite(p.starts_on) and p.starts_on<=current_date;
  return v_period;
end;
$$;

-- Date history gates admission/re-admission, not retroactive expiry of accepted headers
-- when a later animal event occurs. Period identity/start changes are guarded below.
create function group_feed_integrity.admissible(
  p_period economics_v2.group_occupancy_periods, p_start date, p_end date
) returns boolean language sql volatile security invoker set search_path='' as $$
  select (p_period).id is not null and p_start is not null
    and pg_catalog.isfinite(p_start) and p_start<=current_date
    and p_start>=(p_period).starts_on
    and (p_end is null or (pg_catalog.isfinite(p_end)
      and p_end>=p_start and p_end<=current_date))
    and not exists(select 1 from economics_v2.group_occupancy_events e
      where e.granja_id=(p_period).granja_id and e.period_id=(p_period).id
        and e.effective_on>p_start)
    and not exists(select 1 from economics_v2.group_occupancy_periods p
      where p.granja_id=(p_period).granja_id and p.group_id=(p_period).group_id
        and p.purpose_id=(p_period).purpose_id and p.starts_on>p_start);
$$;

-- Called after metadata DML, under the same Group write fence used by every header DML.
-- Losing eligibility with multiple active headers is refused, never repaired by ending
-- or deleting sources. With <=1 active header, stale exemption markers can be revoked.
create function group_feed_integrity.check_group(p_group uuid)
returns void language plpgsql volatile security invoker set search_path='' as $$
declare v_farm uuid; v_period economics_v2.group_occupancy_periods%rowtype;
begin
  select g.granja_id into v_farm from public.grupos g where g.id=p_group;
  v_period := group_feed_integrity.meat_period(p_group,v_farm);
  if (select pg_catalog.count(*) from public.mezcla m
    where m.grupo_id=p_group and m.fecha_termino is null)>1
    and (v_period.id is null or exists(select 1 from public.mezcla m
      where m.grupo_id=p_group and m.fecha_termino is null
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

-- Replace the existing runtime function, not its retained migration or grants.
create or replace function public.enforce_group_active_mixture()
returns trigger language plpgsql volatile security definer set search_path='' as $$
declare
  v_groups uuid[];
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_admissible boolean;
  v_business_change boolean := true;
begin
  -- Event INSERTs are outside this migration's trigger scope. Their committed history
  -- must be visible to each fresh VOLATILE admission query: reject transaction snapshots
  -- rather than silently admitting against stale event history at stronger isolation.
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
      and m.fecha_inicio>new.fecha_inicio) then
    raise exception using errcode='22023',
      message='An active mixture cannot start before the current group mixture';
  end if;
  -- Retained singleton date-end semantics still invoke the untouched posture sync.
  update public.mezcla m
  set fecha_termino=new.fecha_inicio,updated_at=pg_catalog.now()
  where m.grupo_id=new.grupo_id and m.granja_id=new.granja_id
    and m.fecha_termino is null and m.id<>new.id;
  return new;
end;
$$;

drop trigger mezcla_one_active_per_group on public.mezcla;
create trigger mezcla_one_active_per_group
before insert or update or delete on public.mezcla
for each row execute function public.enforce_group_active_mixture();

drop index public.mezcla_one_active_per_group_idx;
create unique index mezcla_one_active_per_group_idx on public.mezcla(grupo_id)
where grupo_id is not null and fecha_termino is null and not group_feed_meat_exempt;

-- Period DML fences both old/new purposes first, then both old/new Groups in UUID order.
-- Purpose fences prevent a concurrent first reference from escaping a purpose change.
create function group_feed_integrity.period_before()
returns trigger language plpgsql volatile security definer set search_path='' as $$
declare v_groups uuid[]; v_purposes uuid[];
begin
  if tg_op='INSERT' then
    v_groups := array[new.group_id]; v_purposes := array[new.purpose_id];
  elsif tg_op='DELETE' then
    v_groups := array[old.group_id]; v_purposes := array[old.purpose_id];
  else
    v_groups := array[old.group_id,new.group_id];
    v_purposes := array[old.purpose_id,new.purpose_id];
  end if;
  perform group_feed_integrity.touch('purpose',v_purposes);
  perform group_feed_integrity.touch('group',v_groups);
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

create function group_feed_integrity.period_after()
returns trigger language plpgsql volatile security definer set search_path='' as $$
declare v_groups uuid[]; v_id uuid;
begin
  if tg_op='INSERT' then v_groups := array[new.group_id];
  elsif tg_op='DELETE' then v_groups := array[old.group_id];
  else v_groups := array[old.group_id,new.group_id]; end if;
  for v_id in select distinct u.id from pg_catalog.unnest(v_groups) u(id) order by u.id loop
    perform group_feed_integrity.check_group(v_id);
  end loop;
  return null;
end;
$$;

create trigger group_feed_cardinality_period_before
before insert or update or delete on economics_v2.group_occupancy_periods
for each row execute function group_feed_integrity.period_before();
create trigger group_feed_cardinality_period_after
after insert or update or delete on economics_v2.group_occupancy_periods
for each row execute function group_feed_integrity.period_after();

create function group_feed_integrity.purpose_before()
returns trigger language plpgsql volatile security definer set search_path='' as $$
declare v_groups uuid[];
begin
  perform group_feed_integrity.touch('purpose',array[old.id]);
  select pg_catalog.array_agg(distinct p.group_id order by p.group_id) into v_groups
  from economics_v2.group_occupancy_periods p where p.purpose_id=old.id;
  perform group_feed_integrity.touch('group',v_groups);
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;

create function group_feed_integrity.purpose_after()
returns trigger language plpgsql volatile security definer set search_path='' as $$
declare v_id uuid;
begin
  for v_id in select distinct p.group_id from economics_v2.group_occupancy_periods p
    where p.purpose_id=old.id order by p.group_id
  loop
    perform group_feed_integrity.check_group(v_id);
  end loop;
  return null;
end;
$$;

create trigger group_feed_cardinality_purpose_before
before update of id,granja_id,codigo_calculo or delete on public.cat_proposito_animal
for each row execute function group_feed_integrity.purpose_before();
create trigger group_feed_cardinality_purpose_after
after update of id,granja_id,codigo_calculo or delete on public.cat_proposito_animal
for each row execute function group_feed_integrity.purpose_after();

-- No helper is a callable business API. Trigger definers only maintain this invariant;
-- table/RPC authorization and every preexisting function grant remain unchanged.
revoke all on all functions in schema group_feed_integrity
from public, anon, authenticated, service_role;
