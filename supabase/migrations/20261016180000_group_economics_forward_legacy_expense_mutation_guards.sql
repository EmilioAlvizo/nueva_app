-- Restrict legacy finance expense mutations after actor authorization.
-- Preserve existing function contracts and bodies apart from target guards.

create or replace function economics_v2.create_finance_expense_impl(
  p_granja_id uuid,
  p_target_kind text,
  p_target_id uuid,
  p_occurred_on date,
  p_amount numeric,
  p_category text,
  p_note text
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_expense_id uuid;
  v_updated_at timestamptz;
begin
  perform economics_v2.assert_finance_expense_actor_impl(p_granja_id, true);
  if p_target_kind is distinct from 'legacy_mixture' then
    raise exception using errcode = '22023', message = 'Unsupported finance expense target';
  end if;
  if p_amount is null
     or p_amount <= 0
     or p_amount in ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric) then
    raise exception using errcode = '22023', message = 'Expense amount must be positive';
  end if;
  if p_category is null or btrim(p_category) = '' then
    raise exception using errcode = '22023', message = 'Expense category is required';
  end if;
  perform economics_v2.validate_finance_expense_target_impl(
    p_granja_id, p_target_kind, p_target_id, p_occurred_on
  );

  if p_target_kind = 'cycle' then
    insert into economics_v2.cycle_expenses (
      cycle_id, granja_id, occurred_on, amount, category, note, created_by
    ) values (
      p_target_id, p_granja_id, p_occurred_on, p_amount,
      btrim(p_category), nullif(btrim(p_note), ''), v_user_id
    ) returning id, updated_at into v_expense_id, v_updated_at;
    update economics_v2.cycles set updated_at = now() where id = p_target_id;
  else
    insert into public.legacy_mixture_expenses (
      mixture_id, granja_id, occurred_on, amount, category, note, created_by
    ) values (
      p_target_id, p_granja_id, p_occurred_on, p_amount,
      btrim(p_category), nullif(btrim(p_note), ''), v_user_id
    ) returning id, updated_at into v_expense_id, v_updated_at;
  end if;

  return jsonb_build_object('expense_id', v_expense_id, 'updated_at', v_updated_at);
end;
$$;

create or replace function economics_v2.update_finance_expense_impl(
  p_granja_id uuid,
  p_expense_id uuid,
  p_target_kind text,
  p_target_id uuid,
  p_expected_updated_at timestamptz,
  p_occurred_on date,
  p_amount numeric,
  p_category text,
  p_note text
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_actual_target_id uuid;
  v_actual_updated_at timestamptz;
  v_updated_at timestamptz;
begin
  perform economics_v2.assert_finance_expense_actor_impl(p_granja_id, true);
  if p_target_kind is distinct from 'legacy_mixture' then
    raise exception using errcode = '22023', message = 'Unsupported finance expense target';
  end if;
  if p_amount is null
     or p_amount <= 0
     or p_amount in ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric) then
    raise exception using errcode = '22023', message = 'Expense amount must be positive';
  end if;
  if p_category is null or btrim(p_category) = '' then
    raise exception using errcode = '22023', message = 'Expense category is required';
  end if;

  if p_target_kind = 'cycle' then
    select expense.cycle_id, expense.updated_at
    into v_actual_target_id, v_actual_updated_at
    from economics_v2.cycle_expenses expense
    where expense.id = p_expense_id
      and expense.granja_id = p_granja_id
    for update;
  elsif p_target_kind = 'legacy_mixture' then
    select expense.mixture_id, expense.updated_at
    into v_actual_target_id, v_actual_updated_at
    from public.legacy_mixture_expenses expense
    where expense.id = p_expense_id
      and expense.granja_id = p_granja_id
    for update;
  else
    raise exception using errcode = '22023', message = 'Unsupported finance expense target';
  end if;

  if v_actual_target_id is null or v_actual_target_id <> p_target_id then
    raise exception using errcode = '42501', message = 'Finance expense target is immutable';
  end if;
  if p_expected_updated_at is null
     or v_actual_updated_at is distinct from p_expected_updated_at then
    raise exception using errcode = '40001', message = 'Finance expense changed since it was opened';
  end if;
  perform economics_v2.validate_finance_expense_target_impl(
    p_granja_id, p_target_kind, p_target_id, p_occurred_on
  );

  if p_target_kind = 'cycle' then
    update economics_v2.cycle_expenses expense
    set occurred_on = p_occurred_on,
        amount = p_amount,
        category = btrim(p_category),
        note = nullif(btrim(p_note), ''),
        updated_at = greatest(
          clock_timestamp(),
          expense.updated_at + interval '1 microsecond'
        )
    where expense.id = p_expense_id
      and expense.granja_id = p_granja_id
      and expense.cycle_id = p_target_id
    returning updated_at into v_updated_at;
    update economics_v2.cycles set updated_at = now() where id = p_target_id;
  else
    update public.legacy_mixture_expenses expense
    set occurred_on = p_occurred_on,
        amount = p_amount,
        category = btrim(p_category),
        note = nullif(btrim(p_note), ''),
        updated_at = greatest(
          clock_timestamp(),
          expense.updated_at + interval '1 microsecond'
        )
    where expense.id = p_expense_id
      and expense.granja_id = p_granja_id
      and expense.mixture_id = p_target_id
    returning updated_at into v_updated_at;
  end if;

  return jsonb_build_object('expense_id', p_expense_id, 'updated_at', v_updated_at);
end;
$$;

create or replace function economics_v2.delete_finance_expense_impl(
  p_granja_id uuid,
  p_expense_id uuid,
  p_target_kind text,
  p_target_id uuid,
  p_expected_updated_at timestamptz
) returns uuid
language plpgsql
security definer
set search_path = '' as $$
declare
  v_actual_target_id uuid;
  v_actual_updated_at timestamptz;
  v_occurred_on date;
begin
  perform economics_v2.assert_finance_expense_actor_impl(p_granja_id, true);
  if p_target_kind is distinct from 'legacy_mixture' then
    raise exception using errcode = '22023', message = 'Unsupported finance expense target';
  end if;

  if p_target_kind = 'cycle' then
    select expense.cycle_id, expense.updated_at, expense.occurred_on
    into v_actual_target_id, v_actual_updated_at, v_occurred_on
    from economics_v2.cycle_expenses expense
    where expense.id = p_expense_id
      and expense.granja_id = p_granja_id
    for update;
  elsif p_target_kind = 'legacy_mixture' then
    select expense.mixture_id, expense.updated_at, expense.occurred_on
    into v_actual_target_id, v_actual_updated_at, v_occurred_on
    from public.legacy_mixture_expenses expense
    where expense.id = p_expense_id
      and expense.granja_id = p_granja_id
    for update;
  else
    raise exception using errcode = '22023', message = 'Unsupported finance expense target';
  end if;

  if v_actual_target_id is null or v_actual_target_id <> p_target_id then
    raise exception using errcode = '42501', message = 'Finance expense target is immutable';
  end if;
  if p_expected_updated_at is null
     or v_actual_updated_at is distinct from p_expected_updated_at then
    raise exception using errcode = '40001', message = 'Finance expense changed since it was opened';
  end if;
  perform economics_v2.validate_finance_expense_target_impl(
    p_granja_id, p_target_kind, p_target_id, v_occurred_on
  );

  if p_target_kind = 'cycle' then
    delete from economics_v2.cycle_expenses expense
    where expense.id = p_expense_id
      and expense.granja_id = p_granja_id
      and expense.cycle_id = p_target_id;
    update economics_v2.cycles set updated_at = now() where id = p_target_id;
  else
    delete from public.legacy_mixture_expenses expense
    where expense.id = p_expense_id
      and expense.granja_id = p_granja_id
      and expense.mixture_id = p_target_id;
  end if;

  return p_expense_id;
end;
$$;
