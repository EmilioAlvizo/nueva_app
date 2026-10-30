-- Creation-only gateway; existing private cores, guards and ACLs stay unchanged.
-- Current JWT authorization precedes delegation. The core owns request grammar,
-- canonical identity, historical replay, mutable admission and atomic persistence.
create function economics_v2.create_group_feed_impl(
  p_granja_id uuid,
  p_operation_id uuid,
  p_period_id uuid,
  p_mezcla_id uuid,
  p_fecha_inicio date,
  p_grupo_id uuid,
  p_ingredientes jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $implementation$
begin
  -- Use the existing typed owner/editor and feature-flag authorization contract.
  perform economics_v2.assert_group_writer_actor(p_granja_id);

  -- No mutable entity lookup may precede the core's historical receipt replay.
  return economics_v2.create_group_feed_allocation(
    p_granja_id => p_granja_id,
    p_operation_id => p_operation_id,
    p_period_id => p_period_id,
    p_mixture_id => p_mezcla_id,
    p_fecha_inicio => p_fecha_inicio,
    p_grupo_id => p_grupo_id,
    p_ingredientes => p_ingredientes
  );
end;
$implementation$;

alter function economics_v2.create_group_feed_impl(uuid, uuid, uuid, uuid, date, uuid, jsonb)
  owner to postgres;

-- Required named arguments only; no overload, defaults or client-supplied facts.
create function public.crear_mezcla_grupo_v1(
  p_granja_id uuid,
  p_operation_id uuid,
  p_period_id uuid,
  p_mezcla_id uuid,
  p_fecha_inicio date,
  p_grupo_id uuid,
  p_ingredientes jsonb
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $gateway$
begin
  return economics_v2.create_group_feed_impl(
    p_granja_id => p_granja_id,
    p_operation_id => p_operation_id,
    p_period_id => p_period_id,
    p_mezcla_id => p_mezcla_id,
    p_fecha_inicio => p_fecha_inicio,
    p_grupo_id => p_grupo_id,
    p_ingredientes => p_ingredientes
  );
end;
$gateway$;

alter function public.crear_mezcla_grupo_v1(uuid, uuid, uuid, uuid, date, uuid, jsonb)
  owner to postgres;

-- Only these two new functions receive ACL changes. Existing schema USAGE suffices.
-- Direct implementation access is deliberate and uses the same authorization/core.
revoke all on function economics_v2.create_group_feed_impl(uuid, uuid, uuid, uuid, date, uuid, jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.crear_mezcla_grupo_v1(uuid, uuid, uuid, uuid, date, uuid, jsonb)
  from public, anon, authenticated, service_role;

grant execute on function economics_v2.create_group_feed_impl(uuid, uuid, uuid, uuid, date, uuid, jsonb)
  to authenticated;
grant execute on function public.crear_mezcla_grupo_v1(uuid, uuid, uuid, uuid, date, uuid, jsonb)
  to authenticated;
