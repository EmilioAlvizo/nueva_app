-- Authoritative destructive deletion for Economics V2 cycles.
-- Final results remain immutable except when PostgreSQL cascades deletion from
-- an already-deleted parent cycle.

alter table economics_v2.final_results
  drop constraint final_results_cycle_id_fkey,
  add constraint final_results_cycle_id_fkey
    foreign key (cycle_id)
    references economics_v2.cycles(id)
    on delete cascade;

create or replace function economics_v2.prevent_final_result_mutation()
returns trigger
language plpgsql
security definer
set search_path = '' as $$
begin
  if tg_op = 'DELETE'
    and not exists (
      select 1
      from economics_v2.cycles cycle
      where cycle.id = old.cycle_id
    ) then
    return old;
  end if;

  raise exception using
    errcode = '23514',
    message = 'final results are immutable';
end;
$$;

create or replace function economics_v2.delete_cycle_impl(
  p_granja_id uuid,
  p_cycle_id uuid
) returns uuid
language plpgsql
security definer
set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_cycle_id uuid;
begin
  if v_user_id is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication required';
  end if;

  select cycle.id
  into v_cycle_id
  from economics_v2.cycles cycle
  where cycle.id = p_cycle_id
    and cycle.granja_id = p_granja_id
  for update;

  if v_cycle_id is null
    or not exists (
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
      message = 'Cycle deletion access denied';
  end if;

  delete from economics_v2.cycles cycle
  where cycle.id = p_cycle_id
    and cycle.granja_id = p_granja_id;

  return v_cycle_id;
end;
$$;

create or replace function public.eliminar_ciclo_v2(
  p_granja_id uuid,
  p_cycle_id uuid
) returns uuid
language sql
security invoker
set search_path = '' as $$
  select economics_v2.delete_cycle_impl(p_granja_id, p_cycle_id);
$$;

revoke all on function economics_v2.delete_cycle_impl(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.eliminar_ciclo_v2(uuid, uuid)
  from public, anon, authenticated;

grant execute on function economics_v2.delete_cycle_impl(uuid, uuid)
  to authenticated;
grant execute on function public.eliminar_ciclo_v2(uuid, uuid)
  to authenticated;
