-- Legacy DELETE only: refuse before source, component, food or private fence DML.
-- Business deletion remains invoker-only; this authorized definer only reads/locks.
create function economics_v2.assert_legacy_feed_delete_allowed(
  p_granja_id uuid,
  p_mixture_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $guard$
declare
  v_source_group_id uuid;
begin
  -- Independently authorize direct callers before inspecting private history.
  if (select auth.uid()) is null then
    raise exception using errcode = '42501', message = 'An authenticated session is required.';
  end if;
  if not coalesce(public.fn_es_miembro_granja(p_granja_id), false)
     or not coalesce(public.fn_puede_editar_granja(p_granja_id), false) then
    raise exception using errcode = '42501', message = 'Farm editing permission is required.';
  end if;

  -- Reentrant with the RPC header lock. Immediate allocation/source FK checks
  -- require KEY SHARE on this source, conflicting with FOR UPDATE.
  select m.grupo_id into v_source_group_id
  from public.mezcla as m
  where m.id = p_mixture_id and m.granja_id = p_granja_id
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'Mixture access is not authorized.';
  end if;

  -- Preserve ordinary older NULL-Group sources, but never skip allocation checks.
  -- A non-NULL Group must belong to the authorized farm before private reads.
  if v_source_group_id is not null then
    perform g.id
    from public.grupos as g
    where g.id = v_source_group_id and g.granja_id = p_granja_id
    for update;
    if not found then
      raise exception using errcode = '42501', message = 'Group access is not authorized.';
    end if;
  end if;

  -- Fresh VOLATILE statement snapshots match the existing header boundary.
  if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
    raise exception using errcode = '40001',
      message = 'Feed header writes require a Read Committed transaction';
  end if;

  -- The immediate period/Group FK stabilizes new references. Lock closed rows
  -- too, so an existing period cannot reopen after classification is checked.
  perform p.id
  from economics_v2.group_occupancy_periods as p
  where p.granja_id = p_granja_id and p.group_id = v_source_group_id
  order by p.id
  for share;

  -- Stabilize every referenced purpose, including currently non-meat purposes.
  perform c.id
  from public.cat_proposito_animal as c
  where exists (
    select 1 from economics_v2.group_occupancy_periods as p
    where p.granja_id = p_granja_id and p.group_id = v_source_group_id
      and p.purpose_id = c.id
  )
  order by c.id
  for share;

  -- Join existing Group fences without writing or creating a missing fence.
  -- Source/Group/period/purpose locks do not depend on fence existence.
  perform f.entity_id
  from group_feed_integrity.fences as f
  where f.scope = 'group' and f.entity_id = v_source_group_id
  for update;

  -- ANY source allocation blocks deletion regardless of closure, purpose or flag.
  -- Source ownership was checked above; do not hide inconsistent allocation farms.
  -- ANY owned open meat period blocks an unallocated source, without a singleton gate.
  if exists (
    select 1 from economics_v2.group_period_feed_allocations as a
    where a.mixture_id = p_mixture_id
  ) or exists (
    select 1
    from economics_v2.group_occupancy_periods as p
    join public.cat_proposito_animal as c
      on c.id = p.purpose_id and c.granja_id = p.granja_id
    where p.granja_id = p_granja_id and p.group_id = v_source_group_id
      and p.closed_on is null and p.end_position is null
      and c.codigo_calculo = 'carne'
  ) then
    raise exception using
      errcode = '23514',
      message = 'Legacy feed deletion requires the forward Group period path.',
      detail = pg_catalog.jsonb_build_object(
        'contract_version', 'group-economics.forward.v3',
        'code', 'forward_group_period_required',
        'field', 'mixture_id',
        'entity_id', p_mixture_id
      )::text;
  end if;
  -- Locks last until transaction end. Other lock orders may deadlock and abort;
  -- concurrency is not proven here. No private producer or fence writer is called.
end;
$guard$;

-- Use existing schema USAGE; expose neither private tables nor producer helpers.
revoke all on function economics_v2.assert_legacy_feed_delete_allowed(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function economics_v2.assert_legacy_feed_delete_allowed(uuid, uuid)
  to authenticated;

-- Preserve the full retained DELETE body, its signature, messages and no-op branch.
create or replace function public.eliminar_mezcla_completa(
  p_granja_id uuid,
  p_mezcla_id uuid
)
returns void
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_locked_id uuid;
  v_food_ids uuid[] := array[]::uuid[];
begin
  if (select auth.uid()) is null then
    raise exception using
      errcode = '42501',
      message = 'Se requiere una sesión autenticada.';
  end if;

  if not coalesce(public.fn_es_miembro_granja(p_granja_id), false)
     or not coalesce(public.fn_puede_editar_granja(p_granja_id), false) then
    raise exception using
      errcode = '42501',
      message = 'No tienes permisos para editar esta granja.';
  end if;

  select m.id
  into v_locked_id
  from public.mezcla as m
  where m.id = p_mezcla_id
    and m.granja_id = p_granja_id
  for update;

  if v_locked_id is null then
    return;
  end if;

  -- Read/authorize the old source Group before ANY persistent DML or fence write.
  perform economics_v2.assert_legacy_feed_delete_allowed(p_granja_id, p_mezcla_id);

  perform mc.id
  from public.mezcla_comida as mc
  where mc.mezcla_id = p_mezcla_id
  order by mc.id
  for update;

  select coalesce(
    pg_catalog.array_agg(mc.comida_id order by mc.comida_id),
    array[]::uuid[]
  )
  into v_food_ids
  from public.mezcla_comida as mc
  where mc.mezcla_id = p_mezcla_id;

  perform c.id
  from public.comida as c
  where c.id = any(v_food_ids)
  order by c.id
  for update;

  if exists (
    select 1
    from public.mezcla_comida as mc
    where mc.comida_id = any(v_food_ids)
      and mc.mezcla_id <> p_mezcla_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'La mezcla contiene compras compartidas y no puede eliminarse de forma segura.';
  end if;

  delete from public.mezcla
  where id = p_mezcla_id
    and granja_id = p_granja_id;

  delete from public.comida
  where id = any(v_food_ids)
    and granja_id = p_granja_id;
end;
$function$;

-- Retain authenticated-only EXECUTE and the invoker business-write boundary.
revoke all on function public.eliminar_mezcla_completa(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.eliminar_mezcla_completa(uuid, uuid)
  to authenticated;
