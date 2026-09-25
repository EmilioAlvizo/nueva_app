-- Resolve cycle deletion authorization through the canonical membership and
-- Economics V2 feature-flag tables.

create or replace function economics_v2.delete_cycle_impl(
  p_granja_id uuid,
  p_cycle_id uuid
) returns uuid
language plpgsql
security definer
set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_cycle economics_v2.cycles;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication required';
  end if;

  select cycle.*
  into v_cycle
  from economics_v2.cycles cycle
  where cycle.id = p_cycle_id
    and cycle.granja_id = p_granja_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Cycle not found';
  end if;

  if not exists (
    select 1
    from public.miembros_granja membership
    join economics_v2.feature_flags flag
      on flag.granja_id = membership.granja_id
     and flag.economics_v2_enabled
    where membership.granja_id = p_granja_id
      and membership.user_id = v_user_id
      and membership.rol in ('owner', 'editor')
  ) then
    raise exception using
      errcode = '42501',
      message = 'Cycle deletion requires an owner or editor';
  end if;

  delete from economics_v2.cycles cycle
  where cycle.id = p_cycle_id
    and cycle.granja_id = p_granja_id;

  return p_cycle_id;
end;
$$;

revoke all on function economics_v2.delete_cycle_impl(uuid, uuid)
from public, anon, authenticated;

grant execute on function economics_v2.delete_cycle_impl(uuid, uuid)
to authenticated;
