-- Header-only authority boundary; retained producers, RLS and cardinality stay unchanged.
-- No business provenance is inferred from privileged SQL authority. Components/foods
-- and their UUID-only cascading foreign keys require a separate boundary.
create function economics_v2.assert_direct_feed_header_allowed(
  p_operation text, p_old public.mezcla, p_new public.mezcla
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $guard$
declare
  v_header public.mezcla%rowtype;
  v_source public.mezcla%rowtype;
  v_index integer;
  v_entity uuid;
  v_ids uuid[];
  v_groups uuid[];
  v_may_close_siblings boolean := false;
begin
  -- VOLATILE history reads require fresh statement snapshots, as at the boundary.
  if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
    raise exception using errcode = '40001',
      message = 'Feed header writes require a Read Committed transaction';
  end if;
  -- Composite arguments enforce column types; reject invalid operation/row shapes.
  if p_operation is null or p_operation not in ('INSERT', 'UPDATE', 'DELETE')
    or (p_operation = 'INSERT' and p_old is distinct from null::public.mezcla)
    or (p_operation = 'DELETE' and p_new is distinct from null::public.mezcla)
    or (p_operation <> 'DELETE' and (p_new.id is null or p_new.granja_id is null))
    or (p_operation <> 'INSERT' and (p_old.id is null or p_old.granja_id is null)) then
    raise exception using errcode = '22023', message = 'Invalid direct header guard request';
  end if;
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'An authenticated session is required';
  end if;

  -- NEW authorization comes first, including a changed farm or destination Group.
  -- Never trust a caller-supplied OLD/NEW farm as proof of source UUID ownership.
  for v_index in 1..2 loop
    if v_index = 1 then
      v_header := p_new;
    else
      v_header := p_old;
    end if;
    if v_header.id is null then
      continue;
    end if;
    if not coalesce(public.fn_es_miembro_granja(v_header.granja_id), false)
      or not coalesce(public.fn_puede_editar_granja(v_header.granja_id), false) then
      raise exception using errcode = '42501', message = 'Farm editing permission is required',
        detail = pg_catalog.jsonb_build_object(
          'contract_version', 'group-economics.forward.v3', 'code', 'forbidden',
          'field', 'granja_id', 'entity_id', v_header.granja_id)::text;
    end if;
    if v_header.grupo_id is not null and not exists (
      select 1 from public.grupos as g
      where g.id = v_header.grupo_id and g.granja_id = v_header.granja_id
    ) then
      raise exception using errcode = '42501', message = 'Group access is not authorized',
        detail = pg_catalog.jsonb_build_object(
          'contract_version', 'group-economics.forward.v3', 'code', 'forbidden',
          'field', 'group_id', 'entity_id', v_header.grupo_id)::text;
    end if;
  end loop;

  v_ids := array[p_old.id, p_new.id];
  v_groups := array[p_old.grupo_id, p_new.grupo_id];
  -- Reentrant with the incoming UPDATE/DELETE row lock. Immediate allocation FK
  -- KEY SHARE conflicts with FOR UPDATE, including NEW UUID collisions.
  for v_source in
    select m.* from public.mezcla as m
    where m.id = any(v_ids) order by m.id for update
  loop
    if p_operation <> 'INSERT' and v_source.id = p_old.id then
      if v_source.granja_id is distinct from p_old.granja_id
        or v_source.grupo_id is distinct from p_old.grupo_id then
        raise exception using errcode = '42501', message = 'Source identity is not authorized',
          detail = pg_catalog.jsonb_build_object(
            'contract_version', 'group-economics.forward.v3', 'code', 'forbidden',
            'field', 'mixture_id', 'entity_id', p_old.id)::text;
      end if;
    end if;
    if p_operation <> 'DELETE' and v_source.id = p_new.id then
      -- A destination UUID already owned by another farm is not a history oracle.
      if v_source.granja_id is distinct from p_new.granja_id then
        raise exception using errcode = '42501', message = 'Destination UUID is not authorized',
          detail = pg_catalog.jsonb_build_object(
            'contract_version', 'group-economics.forward.v3', 'code', 'forbidden',
            'field', 'mixture_id', 'entity_id', p_new.id)::text;
      end if;
    end if;
    if v_source.grupo_id is not null then
      if not exists (
        select 1 from public.grupos as g
        where g.id = v_source.grupo_id and g.granja_id = v_source.granja_id
      ) then
        raise exception using errcode = '42501', message = 'Source Group is not authorized',
          detail = pg_catalog.jsonb_build_object(
            'contract_version', 'group-economics.forward.v3', 'code', 'forbidden',
            'field', 'group_id', 'entity_id', v_source.grupo_id)::text;
      end if;
      v_groups := pg_catalog.array_append(v_groups, v_source.grupo_id);
    end if;
  end loop;
  if p_operation <> 'INSERT' and not exists (
    select 1 from public.mezcla as m
    where m.id = p_old.id and m.granja_id = p_old.granja_id
      and m.grupo_id is not distinct from p_old.grupo_id
  ) then
    raise exception using errcode = '42501', message = 'Source identity is not authorized',
      detail = pg_catalog.jsonb_build_object(
        'contract_version', 'group-economics.forward.v3', 'code', 'forbidden',
        'field', 'mixture_id', 'entity_id', p_old.id)::text;
  end if;

  -- Group FOR UPDATE also covers first-use absence of a fence or NEW header row.
  -- Immediate period references and qualified allocation creation lock this parent.
  perform g.id from public.grupos as g
  where g.id = any(v_groups) order by g.id for update;
  -- Recheck supplied Group ownership after a possible wait, before private history.
  for v_index in 1..2 loop
    if v_index = 1 then
      v_header := p_new;
    else
      v_header := p_old;
    end if;
    if v_header.grupo_id is not null and not exists (
      select 1 from public.grupos as g
      where g.id = v_header.grupo_id and g.granja_id = v_header.granja_id
    ) then
      raise exception using errcode = '42501', message = 'Group access is not authorized',
        detail = pg_catalog.jsonb_build_object(
          'contract_version', 'group-economics.forward.v3', 'code', 'forbidden',
          'field', 'group_id', 'entity_id', v_header.grupo_id)::text;
    end if;
  end loop;
  -- Actual collision-source Groups must also remain owned after parent lock waits.
  if exists (
    select 1 from public.mezcla as m
    where m.id = any(v_ids) and m.grupo_id is not null and not exists (
      select 1 from public.grupos as g
      where g.id = m.grupo_id and g.granja_id = m.granja_id
    )
  ) then
    raise exception using errcode = '42501', message = 'Source Group ownership changed';
  end if;

  -- Closed periods and non-meat purposes are locked too, preventing reopening or
  -- classification changes after inspection. Never INSERT/UPDATE a missing fence.
  perform p.id from economics_v2.group_occupancy_periods as p
  where p.group_id = any(v_groups) order by p.id for share;
  perform c.id from public.cat_proposito_animal as c
  where exists (
    select 1 from economics_v2.group_occupancy_periods as p
    where p.group_id = any(v_groups) and p.purpose_id = c.id
  ) order by c.id for share;
  perform f.entity_id from group_feed_integrity.fences as f
  where f.scope = 'group' and f.entity_id = any(v_groups)
  order by f.entity_id for update;

  if p_operation = 'INSERT' then
    v_entity := p_new.id;
    v_may_close_siblings := p_new.fecha_termino is null;
  elsif p_operation = 'UPDATE' then
    v_entity := p_old.id;
    -- Match all retained fallback business changes, not just movement/reopening.
    v_may_close_siblings := p_new.fecha_termino is null and (
      p_new.grupo_id is distinct from p_old.grupo_id
      or p_new.granja_id is distinct from p_old.granja_id
      or p_new.fecha_inicio is distinct from p_old.fecha_inicio
      or p_new.fecha_termino is distinct from p_old.fecha_termino
    );
  else
    v_entity := p_old.id;
  end if;
  if v_may_close_siblings then
    -- Do not silently omit corrupt foreign-farm siblings under an owned Group.
    -- Stabilize source classification/capture before the definer can auto-close.
    perform m.id from public.mezcla as m
    where m.grupo_id = p_new.grupo_id and m.fecha_termino is null
      and m.id <> p_new.id order by m.id for update;
  end if;

  -- Source ownership precedes ANY UUID allocation read: no allocation farm filter,
  -- marker exemption, feature flag gate, closure test or singleton meat shortcut.
  if exists (
    select 1 from economics_v2.group_period_feed_allocations as a
    where a.mixture_id = any(v_ids)
  ) or exists (
    select 1 from economics_v2.group_occupancy_periods as p
    join public.grupos as g on g.id = p.group_id and g.granja_id = p.granja_id
    join public.cat_proposito_animal as c
      on c.id = p.purpose_id and c.granja_id = p.granja_id
    where p.group_id = any(array[p_old.grupo_id, p_new.grupo_id])
      and p.closed_on is null and p.end_position is null and c.codigo_calculo = 'carne'
  ) or (v_may_close_siblings and exists (
    select 1 from public.mezcla as m
    join economics_v2.group_period_feed_allocations as a on a.mixture_id = m.id
    where m.grupo_id = p_new.grupo_id and m.fecha_termino is null and m.id <> p_new.id
  )) then
    raise exception using errcode = '23514',
      message = 'Direct feed header writes require the forward Group period path',
      detail = pg_catalog.jsonb_build_object(
        'contract_version', 'group-economics.forward.v3',
        'code', 'forward_group_period_required',
        'field', 'mixture_id', 'entity_id', v_entity)::text;
  end if;
  -- Locks last to transaction end. Incoming row/metadata lock orders may deadlock
  -- and abort, not bypass admission. Concurrency and stronger isolation are unproven.
end;
$guard$;

create function public.guard_direct_feed_header()
returns trigger
language plpgsql
volatile
security invoker
set search_path = ''
as $trigger$
declare
  v_privileged boolean;
begin
  -- Read actual effective SQL authority BEFORE entering any definer helper/trigger.
  -- pg_roles is publicly readable; never require restricted pg_authid access.
  v_privileged := exists (
    select 1 from pg_catalog.pg_roles as r
    where r.rolname = current_user and (r.rolsuper or r.rolbypassrls)
  ) and pg_catalog.has_table_privilege(current_user, tg_relid, tg_op);
  if not v_privileged then
    -- Separate branches never resolve nonexistent OLD/NEW trigger record fields.
    if tg_op = 'INSERT' then
      perform economics_v2.assert_direct_feed_header_allowed(tg_op, null::public.mezcla, new);
    elsif tg_op = 'UPDATE' then
      perform economics_v2.assert_direct_feed_header_allowed(tg_op, old, new);
    elsif tg_op = 'DELETE' then
      perform economics_v2.assert_direct_feed_header_allowed(tg_op, old, null::public.mezcla);
    else
      raise exception using errcode = '22023', message = 'Unsupported direct header trigger operation';
    end if;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$trigger$;

-- Only NEW functions receive ACL changes. Existing economics_v2 USAGE suffices.
-- Direct helper calls authorize real identities and only read/lock/raise, never mint
-- authority. Trigger function EXECUTE is checked for its creator at CREATE TRIGGER.
revoke all on function economics_v2.assert_direct_feed_header_allowed(text, public.mezcla, public.mezcla)
  from public, anon, authenticated, service_role;
grant execute on function economics_v2.assert_direct_feed_header_allowed(text, public.mezcla, public.mezcla)
  to authenticated;
revoke all on function public.guard_direct_feed_header()
  from public, anon, authenticated, service_role;

-- PostgreSQL orders same-kind row triggers alphabetically: this sorts BEFORE the
-- retained mezcla_one_active_per_group definer. Parent must verify live catalog order.
create trigger mezcla_forward_header_guard
before insert or update or delete on public.mezcla
for each row execute function public.guard_direct_feed_header();
