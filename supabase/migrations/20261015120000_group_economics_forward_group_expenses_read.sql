-- Group expense projection only; existing fact tables and their ACLs stay private.

create function economics_v2.read_group_finance_expenses_impl(
  p_granja_id uuid
) returns jsonb
language plpgsql
security definer
stable
set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_role text;
  v_can_edit boolean;
  v_code text;
  v_state text := '42501';
  v_result jsonb;
begin
  -- Resolve the actual subject against farm ownership/membership, never JWT roles.
  select case when farm.owner_id = v_user_id then 'owner' else membership.rol::text end
  into v_role
  from public.granjas farm
  join economics_v2.feature_flags flag
    on flag.granja_id = farm.id and flag.economics_v2_enabled
  left join public.miembros_granja membership
    on membership.granja_id = farm.id and membership.user_id = v_user_id
  where farm.id = p_granja_id
    and (farm.owner_id = v_user_id or membership.rol::text in ('owner', 'editor', 'viewer'));

  if v_user_id is null or v_role is null then
    v_code := 'forbidden';
  end if;
  -- Preserve the Group reader's authenticated NULL-farm error precedence.
  if v_user_id is not null and p_granja_id is null then
    v_code := 'invalid_request';
    v_state := '22023';
  end if;
  if v_code is not null then
    raise exception using errcode = v_state, message = 'Invalid Group economics read',
      detail = jsonb_build_object(
        'contract_version', 'group-economics.forward.v3',
        'code', v_code,
        'field', 'granja_id',
        'entity_id', null
      )::text;
  end if;
  v_can_edit := v_role in ('owner', 'editor');

  -- One shared projection keeps expense and selectable target labels identical.
  -- Historical expenses do not require memberships, metrics or closure snapshots.
  with owned_meat_periods as (
    select
      period.id,
      period.granja_id,
      period.starts_on,
      period.closed_on,
      period.closed_on is null and period.end_position is null as is_open,
      'group-period:' || period.id as stable_key,
      animal_group.nombre || ' (' || to_char(period.starts_on, 'YYYY-MM-DD') || ')' as target_label
    from economics_v2.group_occupancy_periods period
    join public.grupos animal_group
      on animal_group.id = period.group_id and animal_group.granja_id = period.granja_id
    join public.cat_proposito_animal purpose
      on purpose.id = period.purpose_id and purpose.granja_id = period.granja_id
    where period.granja_id = p_granja_id and purpose.codigo_calculo = 'carne'
  ), targets as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'target_kind', 'group_period',
          'target_id', period.id,
          'stable_key', period.stable_key,
          'target_label', period.target_label,
          'starts_on', period.starts_on,
          'closed_on', period.closed_on,
          'status', 'open',
          'can_mutate', v_can_edit
        ) order by period.starts_on desc, period.id
      ), '[]'::jsonb
    ) as items
    from owned_meat_periods period
    where period.is_open
  ), expenses as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'expense_id', expense.id,
          'target_kind', 'group_period',
          'target_id', expense.period_id,
          'stable_target_key', period.stable_key,
          'target_label', period.target_label,
          'occurred_on', expense.occurred_on,
          'amount', expense.amount,
          'category', expense.category,
          'note', expense.note,
          'created_by', expense.created_by,
          'created_at', expense.created_at,
          'updated_at', expense.updated_at,
          'can_mutate', v_can_edit and period.is_open
        ) order by expense.occurred_on desc, expense.id
      ), '[]'::jsonb
    ) as items
    from economics_v2.group_period_expenses expense
    join owned_meat_periods period
      on period.id = expense.period_id and period.granja_id = expense.granja_id
    where expense.granja_id = p_granja_id
  )
  select jsonb_build_object(
    'contract_version', 'group-economics.forward.v3',
    'granja_id', p_granja_id,
    'role', v_role,
    'can_edit', v_can_edit,
    'targets', targets.items,
    'expenses', expenses.items
  ) into v_result
  from targets cross join expenses;

  return v_result;
end;
$$;

create function public.list_group_finance_expenses_v1(
  p_granja_id uuid
) returns jsonb
language plpgsql
security invoker
stable
set search_path = '' as $$
begin
  return economics_v2.read_group_finance_expenses_impl(p_granja_id => p_granja_id);
end;
$$;

alter function economics_v2.read_group_finance_expenses_impl(uuid) owner to postgres;
alter function public.list_group_finance_expenses_v1(uuid) owner to postgres;

revoke all on function economics_v2.read_group_finance_expenses_impl(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.list_group_finance_expenses_v1(uuid)
  from public, anon, authenticated, service_role;
grant execute on function economics_v2.read_group_finance_expenses_impl(uuid) to authenticated;
grant execute on function public.list_group_finance_expenses_v1(uuid) to authenticated;
