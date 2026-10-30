-- Food-only boundary: no changes to existing guards, producers, RLS or table ACLs.
-- Privileged effective SQL authority is not proof of business provenance.
create function economics_v2.assert_direct_feed_food_allowed(
  p_operation text, p_old public.comida, p_new public.comida
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $guard$
declare
  v_actual public.comida;
  v_food public.comida;
  v_farm uuid;
  v_foods uuid[];
  v_parents uuid[];
  v_fresh_parents uuid[];
  v_groups uuid[];
  v_categories uuid[];
  v_entity uuid;
  v_phase integer;
  v_index integer;
begin
  -- Lock waits cannot refresh stronger-isolation snapshots. Refuse admission.
  if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
    raise exception using errcode = '40001',
      message = 'Feed food writes require a Read Committed transaction';
  end if;
  if p_operation is null or p_operation not in ('INSERT', 'UPDATE', 'DELETE')
    or (p_operation = 'INSERT' and p_old is distinct from null::public.comida)
    or (p_operation = 'DELETE' and p_new is distinct from null::public.comida)
    or (p_operation <> 'INSERT' and (p_old.id is null or p_old.granja_id is null))
    or (p_operation <> 'DELETE' and (p_new.id is null or p_new.granja_id is null)) then
    raise exception using errcode = '22023', message = 'Invalid direct food guard request';
  end if;
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'An authenticated session is required';
  end if;
  v_farm := coalesce(p_old.granja_id, p_new.granja_id);
  v_foods := array[p_old.id, p_new.id];
  if p_operation = 'UPDATE' and p_new.granja_id is distinct from p_old.granja_id then
    raise exception using errcode = '42501', message = 'Food farm reassignment is not authorized';
  end if;
  if not coalesce(public.fn_es_miembro_granja(v_farm), false)
    or not coalesce(public.fn_puede_editar_granja(v_farm), false) then
    raise exception using errcode = '42501', message = 'Farm editing permission is required';
  end if;

  -- Lock actual identities, including destination collisions, in UUID order.
  -- Incoming UPDATE/DELETE already owns its row lock; cross-order deadlocks may abort.
  for v_actual in
    select c.* from public.comida as c
    where c.id = any(v_foods) order by c.id for update
  loop
    if v_actual.granja_id is distinct from v_farm then
      raise exception using errcode = '42501', message = 'Food identity is not authorized';
    end if;
  end loop;

  -- Bounded discovery/locking, then fresh authorization after every public lock wait.
  -- No private allocation/period lookup precedes actual public graph authorization.
  for v_phase in 1..2 loop
    if not coalesce(public.fn_es_miembro_granja(v_farm), false)
      or not coalesce(public.fn_puede_editar_granja(v_farm), false) then
      raise exception using errcode = '42501', message = 'Farm editing permission is required';
    end if;
    if p_operation <> 'INSERT' then
      select c.* into v_actual from public.comida as c where c.id = p_old.id;
      if not found or v_actual is distinct from p_old then
        raise exception using errcode = '42501', message = 'Actual OLD food identity is not authorized';
      end if;
    end if;
    for v_index in 1..2 loop
      if v_index = 1 then
        v_food := p_old;
      else
        v_food := p_new;
      end if;
      if v_food.id is null then
        continue;
      end if;
      -- NULL category validity remains the existing table constraint's decision.
      -- Do not introduce new price/stock domain checks or infer a standalone Group.
      if v_food.granja_id is distinct from v_farm or (v_food.cat_comida_id is not null
        and not exists (
          select 1 from public.cat_comida as cc
          where cc.id = v_food.cat_comida_id and cc.granja_id = v_farm
        )) then
        raise exception using errcode = '42501', message = 'Food category ownership is not authorized';
      end if;
    end loop;
    if exists (
      select 1 from public.comida as c
      left join public.cat_comida as cc on cc.id = c.cat_comida_id
      where c.id = any(v_foods) and (c.granja_id is distinct from v_farm
        or (c.cat_comida_id is not null and cc.granja_id is distinct from v_farm))
    ) then
      raise exception using errcode = '42501', message = 'Actual food references are not authorized';
    end if;

    -- No farm filter: malformed foreign components/parents must not disappear.
    if exists (
      select 1 from public.mezcla_comida as mc
      left join public.mezcla as m on m.id = mc.mezcla_id
      left join public.comida as c on c.id = mc.comida_id
      left join public.cat_comida as cc on cc.id = c.cat_comida_id
      where mc.comida_id = any(v_foods) and (mc.granja_id is distinct from v_farm
        or m.granja_id is distinct from v_farm or c.granja_id is distinct from v_farm
        or (c.cat_comida_id is not null and cc.granja_id is distinct from v_farm))
    ) then
      raise exception using errcode = '42501', message = 'Linked purchase ownership is not authorized';
    end if;
    select coalesce(pg_catalog.array_agg(s.id order by s.id), '{}'::uuid[]) into v_fresh_parents
    from (
      select distinct mc.mezcla_id as id from public.mezcla_comida as mc
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
      -- Food FOR UPDATE blocks new immediate FK references. Existing reference
      -- rows need SHARE too: same-food unlink/reparent need not acquire a new FK lock.
      perform mc.id from public.mezcla_comida as mc
      where mc.comida_id = any(v_foods) order by mc.id for share;
      perform m.id from public.mezcla as m
      where m.id = any(v_parents) order by m.id for update;
      select coalesce(pg_catalog.array_agg(distinct m.grupo_id order by m.grupo_id), '{}'::uuid[])
        into v_groups from public.mezcla as m
      where m.id = any(v_parents) and m.grupo_id is not null;
      perform g.id from public.grupos as g
      where g.id = any(v_groups) order by g.id for update;
      select pg_catalog.array_agg(distinct s.id order by s.id) into v_categories
      from (
        select p_old.cat_comida_id as id union select p_new.cat_comida_id
        union select c.cat_comida_id from public.comida as c where c.id = any(v_foods)
      ) as s where s.id is not null;
      perform cc.id from public.cat_comida as cc
      where cc.id = any(v_categories) order by cc.id for share;
    elsif exists (
      select 1 from pg_catalog.unnest(v_fresh_parents) as s(id)
      where not s.id = any(v_parents)
    ) or exists (
      select 1 from public.mezcla as m where m.id = any(v_fresh_parents)
        and m.grupo_id is not null and not m.grupo_id = any(v_groups)
    ) then
      raise exception using errcode = '40001', message = 'Linked feed source graph changed; retry';
    end if;
  end loop;

  -- Groups stabilize first-use period/fence absence. Lock all periods, including
  -- closed/non-meat ones, their purposes, and only already-existing Group fences.
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

  -- ANY allocation protects independently of flags, purpose and closure, with no
  -- allocation farm filter. Shared egg/open-meat sources still protect the purchase.
  select m.id into v_entity from public.mezcla as m
  where m.id = any(v_fresh_parents) and (
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
      message = 'Direct feed food writes require the forward Group period path',
      detail = pg_catalog.jsonb_build_object(
        'contract_version', 'group-economics.forward.v3',
        'code', 'forward_group_period_required',
        'field', 'mixture_id', 'entity_id', v_entity)::text;
  end if;
  -- precio is TOTAL purchase cost, cantidad is stock, not component ingredient kg.
  -- Refuse every protected purchase mutation, not merely digest-changing fields.
  -- Read/lock/raise only: no receipt, counter, reservation, missing fence or authority.
  -- Locks last to transaction end; deadlocks abort. Concurrency remains unproven.
end;
$guard$;

create function public.guard_direct_feed_food()
returns trigger
language plpgsql
volatile
security invoker
set search_path = ''
as $trigger$
declare
  v_privileged boolean;
begin
  -- Capture actual effective role BEFORE the definer helper. No JWT/config flag,
  -- session_user, role-name allowlist or trigger-depth exemption grants authority.
  v_privileged := exists (
    select 1 from pg_catalog.pg_roles as r
    where r.rolname = current_user and (r.rolsuper or r.rolbypassrls)
  ) and pg_catalog.has_table_privilege(current_user, tg_relid, tg_op);
  if not v_privileged then
    -- Separate branches preserve actual typed OLD/NEW operation shapes.
    if tg_op = 'INSERT' then
      perform economics_v2.assert_direct_feed_food_allowed(tg_op, null::public.comida, new);
    elsif tg_op = 'UPDATE' then
      perform economics_v2.assert_direct_feed_food_allowed(tg_op, old, new);
    elsif tg_op = 'DELETE' then
      perform economics_v2.assert_direct_feed_food_allowed(tg_op, old, null::public.comida);
    else
      raise exception using errcode = '22023', message = 'Unsupported direct food trigger operation';
    end if;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$trigger$;

-- New-function ACLs only; no private producer/error EXECUTE or table SELECT grants.
revoke all on function economics_v2.assert_direct_feed_food_allowed(text, public.comida, public.comida)
  from public, anon, authenticated, service_role;
grant execute on function economics_v2.assert_direct_feed_food_allowed(text, public.comida, public.comida)
  to authenticated;
revoke all on function public.guard_direct_feed_food()
  from public, anon, authenticated, service_role;

-- BEFORE ROW refuses before food persistence and DELETE's component FK cascade.
-- Parent must preflight actual catalog/schema/trigger order before Sandbox install.
create trigger comida_forward_food_guard
before insert or update or delete on public.comida
for each row execute function public.guard_direct_feed_food();
