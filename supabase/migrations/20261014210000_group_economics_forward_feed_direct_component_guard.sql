-- Component-only boundary. Existing headers, producers, RLS and ACLs stay unchanged.
-- Privileged SQL authority is not business provenance. Direct food writes are separate.
create function economics_v2.assert_direct_feed_component_allowed(
  p_operation text, p_old public.mezcla_comida, p_new public.mezcla_comida
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $guard$
declare
  v_component public.mezcla_comida;
  v_actual public.mezcla_comida;
  v_farm uuid;
  v_foods uuid[];
  v_parents uuid[];
  v_fresh_parents uuid[];
  v_groups uuid[];
  v_entity uuid;
  v_phase integer;
  v_index integer;
begin
  -- Lock waits do not refresh Repeatable Read snapshots. Fail before admission.
  if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
    raise exception using errcode = '40001',
      message = 'Feed component writes require a Read Committed transaction';
  end if;
  if p_operation is null or p_operation not in ('INSERT', 'UPDATE', 'DELETE')
    or (p_operation = 'INSERT' and p_old is distinct from null::public.mezcla_comida)
    or (p_operation = 'DELETE' and p_new is distinct from null::public.mezcla_comida)
    or (p_operation <> 'INSERT' and (p_old.id is null or p_old.granja_id is null
      or p_old.mezcla_id is null or p_old.comida_id is null))
    or (p_operation <> 'DELETE' and (p_new.id is null or p_new.granja_id is null
      or p_new.mezcla_id is null or p_new.comida_id is null)) then
    raise exception using errcode = '22023', message = 'Invalid direct component guard request';
  end if;
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'An authenticated session is required';
  end if;
  v_farm := coalesce(p_old.granja_id, p_new.granja_id);
  if p_operation = 'UPDATE' and p_new.granja_id is distinct from p_old.granja_id then
    raise exception using errcode = '42501', message = 'Component farm reassignment is not authorized';
  end if;
  if not coalesce(public.fn_es_miembro_granja(v_farm), false)
    or not coalesce(public.fn_puede_editar_granja(v_farm), false) then
    raise exception using errcode = '42501', message = 'Farm editing permission is required';
  end if;

  -- Reentrant incoming row lock and actual NEW UUID collision, never composite proof.
  for v_actual in
    select mc.* from public.mezcla_comida as mc
    where mc.id = any(array[p_old.id, p_new.id]) order by mc.id for update
  loop
    if v_actual.granja_id is distinct from v_farm then
      raise exception using errcode = '42501', message = 'Component identity is not authorized';
    end if;
  end loop;
  v_foods := array[p_old.comida_id, p_new.comida_id];

  -- Two bounded passes: authorize/discover, lock, then reread actual ownership/graph.
  -- Public reference lookups precede private allocation/period history on every path.
  for v_phase in 1..2 loop
    if not coalesce(public.fn_es_miembro_granja(v_farm), false)
      or not coalesce(public.fn_puede_editar_granja(v_farm), false) then
      raise exception using errcode = '42501', message = 'Farm editing permission is required';
    end if;
    if p_operation <> 'INSERT' then
      select mc.* into v_actual from public.mezcla_comida as mc where mc.id = p_old.id;
      if not found or v_actual is distinct from p_old then
        raise exception using errcode = '42501', message = 'Actual OLD component identity is not authorized';
      end if;
    end if;
    for v_index in 1..2 loop
      if v_index = 1 then
        v_component := p_old;
      else
        v_component := p_new;
      end if;
      if v_component.id is null then
        continue;
      end if;
      if v_component.granja_id is distinct from v_farm or not exists (
        select 1 from public.mezcla as m
        where m.id = v_component.mezcla_id and m.granja_id = v_component.granja_id
      ) or not exists (
        select 1 from public.comida as c
        where c.id = v_component.comida_id and c.granja_id = v_component.granja_id
      ) then
        raise exception using errcode = '42501', message = 'Component references are not authorized';
      end if;
    end loop;
    -- A collision must not expose another farm's pointers through a supplied NEW UUID.
    if exists (
      select 1 from public.mezcla_comida as mc
      left join public.mezcla as m on m.id = mc.mezcla_id
      left join public.comida as c on c.id = mc.comida_id
      where mc.id = p_new.id and (mc.granja_id is distinct from v_farm
        or m.granja_id is distinct from v_farm or c.granja_id is distinct from v_farm)
    ) then
      raise exception using errcode = '42501', message = 'Destination component identity is not authorized';
    end if;

    -- No component-farm filter: foreign linked parents must refuse, not disappear.
    if exists (
      select 1 from public.mezcla_comida as mc
      left join public.mezcla as m on m.id = mc.mezcla_id
      left join public.comida as c on c.id = mc.comida_id
      where mc.comida_id = any(v_foods) and (mc.granja_id is distinct from v_farm
        or m.granja_id is distinct from v_farm or c.granja_id is distinct from v_farm)
    ) then
      raise exception using errcode = '42501', message = 'Linked purchase ownership is not authorized';
    end if;
    select pg_catalog.array_agg(s.id order by s.id) into v_fresh_parents
    from (
      select p_old.mezcla_id as id where p_old.mezcla_id is not null
      union select p_new.mezcla_id where p_new.mezcla_id is not null
      union select mc.mezcla_id from public.mezcla_comida as mc
        where mc.comida_id = any(v_foods)
    ) as s;
    if exists (
      select 1 from public.mezcla as m
      where m.id = any(v_fresh_parents) and (m.granja_id is distinct from v_farm
        or (m.grupo_id is not null and not exists (
          select 1 from public.grupos as g
          where g.id = m.grupo_id and g.granja_id = m.granja_id
        )))
    ) then
      raise exception using errcode = '42501', message = 'Source Group ownership is not authorized';
    end if;

    if v_phase = 1 then
      v_parents := v_fresh_parents;
      -- Immediate FK KEY SHARE conflicts with these parent FOR UPDATE locks.
      perform m.id from public.mezcla as m
      where m.id = any(v_parents) order by m.id for update;
      perform c.id from public.comida as c
      where c.id = any(v_foods) order by c.id for update;
      select pg_catalog.array_agg(distinct m.grupo_id order by m.grupo_id) into v_groups
      from public.mezcla as m where m.id = any(v_parents) and m.grupo_id is not null;
      perform g.id from public.grupos as g
      where g.id = any(v_groups) order by g.id for update;
    elsif exists (
      select 1 from pg_catalog.unnest(v_fresh_parents) as s(id)
      where not s.id = any(v_parents)
    ) then
      -- A newly discovered parent was not locked. Retry; never use a stale graph.
      raise exception using errcode = '40001', message = 'Linked feed source graph changed; retry';
    end if;
  end loop;

  -- Lock closed periods/non-meat purposes too. Groups cover first-use fence absence.
  -- Only existing fences are locked: no business DML, reservation or counter issuance.
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

  -- Actual owned source UUIDs, not caller row ID, flag, closure or purpose shortcuts.
  -- Allocation protection is independent of classification and has no farm filter.
  select m.id into v_entity from public.mezcla as m
  where m.id = any(v_parents) and (
    exists (
      select 1 from economics_v2.group_period_feed_allocations as a
      where a.mixture_id = m.id
    ) or exists (
      select 1 from economics_v2.group_occupancy_periods as p
      join public.grupos as g on g.id = p.group_id and g.granja_id = p.granja_id
      join public.cat_proposito_animal as c
        on c.id = p.purpose_id and c.granja_id = p.granja_id
      where p.group_id = m.grupo_id and p.granja_id = m.granja_id
        and p.closed_on is null and p.end_position is null and c.codigo_calculo = 'carne'
    )
  ) order by m.id limit 1;
  if v_entity is not null then
    raise exception using errcode = '23514',
      message = 'Direct feed component writes require the forward Group period path',
      detail = pg_catalog.jsonb_build_object(
        'contract_version', 'group-economics.forward.v3',
        'code', 'forward_group_period_required',
        'field', 'mixture_id', 'entity_id', v_entity)::text;
  end if;
  -- Locks persist to transaction end. Component/header/core lock orders may deadlock
  -- and abort, never grant admission. Races and stronger isolation remain unproven.
end;
$guard$;

create function public.guard_direct_feed_component()
returns trigger
language plpgsql
volatile
security invoker
set search_path = ''
as $trigger$
declare
  v_privileged boolean;
begin
  -- Actual effective SQL role is checked BEFORE entering any definer helper.
  -- Session identity, role names, JWT flags and trigger depth grant no authority.
  v_privileged := exists (
    select 1 from pg_catalog.pg_roles as r
    where r.rolname = current_user and (r.rolsuper or r.rolbypassrls)
  ) and pg_catalog.has_table_privilege(current_user, tg_relid, tg_op);
  if not v_privileged then
    -- Separate branches avoid resolving missing OLD/NEW trigger record fields.
    if tg_op = 'INSERT' then
      perform economics_v2.assert_direct_feed_component_allowed(
        tg_op, null::public.mezcla_comida, new);
    elsif tg_op = 'UPDATE' then
      perform economics_v2.assert_direct_feed_component_allowed(tg_op, old, new);
    elsif tg_op = 'DELETE' then
      perform economics_v2.assert_direct_feed_component_allowed(
        tg_op, old, null::public.mezcla_comida);
    else
      raise exception using errcode = '22023', message = 'Unsupported direct component trigger operation';
    end if;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$trigger$;

-- Only new-function ACLs. Helper direct calls read/lock/raise, never mint authority.
revoke all on function economics_v2.assert_direct_feed_component_allowed(
  text, public.mezcla_comida, public.mezcla_comida) from public, anon, authenticated, service_role;
grant execute on function economics_v2.assert_direct_feed_component_allowed(
  text, public.mezcla_comida, public.mezcla_comida) to authenticated;
revoke all on function public.guard_direct_feed_component()
  from public, anon, authenticated, service_role;

-- Parent must verify catalog privileges, row-trigger order and schema before install.
create trigger mezcla_comida_forward_component_guard
before insert or update or delete on public.mezcla_comida
for each row execute function public.guard_direct_feed_component();
