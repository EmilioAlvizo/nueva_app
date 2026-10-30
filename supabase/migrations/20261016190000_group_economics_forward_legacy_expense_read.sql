create or replace function economics_v2.read_finance_expenses_impl(
  p_granja_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_role text;
  v_can_edit boolean;
  v_targets jsonb;
  v_expenses jsonb;
begin
  v_role := economics_v2.assert_finance_expense_actor_impl(p_granja_id, false);
  v_can_edit := v_role in ('owner', 'editor');

  with legacy_windows as (
    select
      mixture.id,
      mixture.granja_id,
      mixture.grupo_id,
      animal_group.nombre as target_label,
      mixture.fecha_inicio as starts_on,
      coalesce(
        mixture.fecha_termino,
        lead(mixture.fecha_inicio) over (
          partition by mixture.grupo_id
          order by mixture.fecha_inicio, mixture.id
        )
      ) as ends_on
    from public.mezcla mixture
    join public.grupos animal_group
      on animal_group.id = mixture.grupo_id
     and animal_group.granja_id = mixture.granja_id
    where mixture.granja_id = p_granja_id
  ), targets as (
    select
      'legacy_mixture'::text as target_kind,
      legacy.id as target_id,
      legacy.target_label,
      legacy.starts_on,
      legacy.ends_on
    from legacy_windows legacy
    where current_date >= legacy.starts_on
      and (legacy.ends_on is null or current_date < legacy.ends_on)
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'target_kind', target.target_kind,
        'target_id', target.target_id,
        'target_label', target.target_label,
        'starts_on', target.starts_on,
        'ends_on_exclusive', target.ends_on
      ) order by target.target_kind, target.starts_on desc, target.target_id
    ),
    '[]'::jsonb
  )
  into v_targets
  from targets target;

  with legacy_windows as (
    select
      mixture.id,
      mixture.granja_id,
      animal_group.nombre as target_label,
      mixture.fecha_inicio as starts_on,
      coalesce(
        mixture.fecha_termino,
        lead(mixture.fecha_inicio) over (
          partition by mixture.grupo_id
          order by mixture.fecha_inicio, mixture.id
        )
      ) as ends_on
    from public.mezcla mixture
    join public.grupos animal_group
      on animal_group.id = mixture.grupo_id
     and animal_group.granja_id = mixture.granja_id
    where mixture.granja_id = p_granja_id
  ), legacy_rows as (
    select
      expense.id as expense_id,
      'legacy_mixture'::text as target_kind,
      expense.mixture_id as target_id,
      legacy.target_label,
      expense.occurred_on,
      expense.amount,
      expense.category,
      expense.note,
      expense.created_at,
      expense.updated_at,
      v_can_edit
        and current_date >= legacy.starts_on
        and (legacy.ends_on is null or current_date < legacy.ends_on)
        as can_mutate
    from public.legacy_mixture_expenses expense
    join legacy_windows legacy
      on legacy.id = expense.mixture_id
     and legacy.granja_id = expense.granja_id
    where expense.granja_id = p_granja_id
      and current_date >= legacy.starts_on
      and (legacy.ends_on is null or current_date < legacy.ends_on)
  ), rows as (
    select * from legacy_rows
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'expense_id', expense.expense_id,
        'target_kind', expense.target_kind,
        'target_id', expense.target_id,
        'target_label', expense.target_label,
        'occurred_on', expense.occurred_on,
        'amount', expense.amount,
        'category', expense.category,
        'note', expense.note,
        'created_at', expense.created_at,
        'updated_at', expense.updated_at,
        'can_mutate', expense.can_mutate
      ) order by expense.occurred_on desc, expense.created_at desc, expense.expense_id
    ),
    '[]'::jsonb
  )
  into v_expenses
  from rows expense;

  return jsonb_build_object(
    'granja_id', p_granja_id,
    'role', v_role,
    'can_edit', v_can_edit,
    'targets', v_targets,
    'expenses', v_expenses
  );
end;
$$;
