-- Unified Finance > Expenses contract for current break-even cards.
-- Public APIs are fixed-search-path invokers. Privileged implementations live
-- in economics_v2 and perform their own actor, farm, target, and date checks.

alter table economics_v2.cycle_expenses
  add column if not exists updated_at timestamptz not null default now();

create table public.legacy_mixture_expenses (
  id uuid primary key default gen_random_uuid(),
  mixture_id uuid not null references public.mezcla(id) on delete cascade,
  granja_id uuid not null references public.granjas(id) on delete cascade,
  occurred_on date not null,
  amount numeric not null check (
    amount > 0
    and amount not in ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric)
  ),
  category text not null check (btrim(category) <> ''),
  note text,
  created_by uuid not null references public.perfiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index legacy_mixture_expenses_farm_date_idx
  on public.legacy_mixture_expenses (granja_id, occurred_on desc);
create index legacy_mixture_expenses_target_idx
  on public.legacy_mixture_expenses (granja_id, mixture_id);
create index legacy_mixture_expenses_creator_idx
  on public.legacy_mixture_expenses (created_by);

alter table public.legacy_mixture_expenses enable row level security;

create policy legacy_mixture_expenses_select_members
on public.legacy_mixture_expenses
for select
to authenticated
using (
  exists (
    select 1
    from public.miembros_granja membership
    where membership.granja_id = legacy_mixture_expenses.granja_id
      and membership.user_id = (select auth.uid())
  )
);

revoke all on table public.legacy_mixture_expenses
  from public, anon, authenticated;
grant select, insert, update, delete on table public.legacy_mixture_expenses
  to service_role;
grant select on table public.legacy_mixture_expenses to authenticated;

create or replace function economics_v2.assert_finance_expense_actor_impl(
  p_granja_id uuid,
  p_mutation boolean
) returns text
language plpgsql
security definer
set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_role text;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  select membership.rol::text
  into v_role
  from public.miembros_granja membership
  where membership.granja_id = p_granja_id
    and membership.user_id = v_user_id;

  if v_role is null or (p_mutation and v_role not in ('owner', 'editor')) then
    raise exception using errcode = '42501', message = 'Finance expense access denied';
  end if;

  return v_role;
end;
$$;

create or replace function economics_v2.validate_finance_expense_target_impl(
  p_granja_id uuid,
  p_target_kind text,
  p_target_id uuid,
  p_occurred_on date
) returns void
language plpgsql
security definer
set search_path = '' as $$
declare
  v_cycle economics_v2.cycles;
  v_mixture_start date;
  v_mixture_end date;
begin
  if p_target_kind not in ('cycle', 'legacy_mixture') or p_target_id is null then
    raise exception using errcode = '22023', message = 'Unsupported finance expense target';
  end if;
  if p_occurred_on is null or p_occurred_on > current_date then
    raise exception using errcode = '22023', message = 'Expense date must not be in the future';
  end if;

  if p_target_kind = 'cycle' then
    select cycle.*
    into v_cycle
    from economics_v2.cycles cycle
    join public.cat_proposito_animal purpose on purpose.id = cycle.proposito_id
    join economics_v2.feature_flags flag
      on flag.granja_id = cycle.granja_id
     and flag.economics_v2_enabled
    where cycle.id = p_target_id
      and cycle.granja_id = p_granja_id
      and purpose.codigo_calculo = 'carne'
    for update of cycle;

    if v_cycle.id is null then
      raise exception using errcode = '42501', message = 'Cycle expense target access denied';
    end if;
    if v_cycle.status = 'settled' then
      raise exception using errcode = '23514', message = 'Settled cycle expenses are immutable';
    end if;
    if p_occurred_on < v_cycle.starts_on
       or (v_cycle.ends_on is not null and p_occurred_on >= v_cycle.ends_on) then
      raise exception using errcode = '22023', message = 'Expense date is outside the cycle window';
    end if;
    return;
  end if;

  select
    mixture.fecha_inicio,
    coalesce(
      mixture.fecha_termino,
      (
        select min(next_mixture.fecha_inicio)
        from public.mezcla next_mixture
        where next_mixture.granja_id = mixture.granja_id
          and next_mixture.grupo_id = mixture.grupo_id
          and (
            next_mixture.fecha_inicio > mixture.fecha_inicio
            or (
              next_mixture.fecha_inicio = mixture.fecha_inicio
              and next_mixture.id > mixture.id
            )
          )
      )
    )
  into v_mixture_start, v_mixture_end
  from public.mezcla mixture
  where mixture.id = p_target_id
    and mixture.granja_id = p_granja_id
  for update;

  if v_mixture_start is null then
    raise exception using errcode = '42501', message = 'Legacy mixture expense target access denied';
  end if;
  if current_date < v_mixture_start
     or (v_mixture_end is not null and current_date >= v_mixture_end) then
    raise exception using errcode = '23514', message = 'Legacy mixture is no longer current';
  end if;
  if p_occurred_on < v_mixture_start
     or (v_mixture_end is not null and p_occurred_on >= v_mixture_end) then
    raise exception using errcode = '22023', message = 'Expense date is outside the mixture window';
  end if;
end;
$$;

create or replace function economics_v2.read_finance_expenses_impl(
  p_granja_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_role text;
  v_can_edit boolean;
  v_v2_enabled boolean;
  v_targets jsonb;
  v_expenses jsonb;
begin
  v_role := economics_v2.assert_finance_expense_actor_impl(p_granja_id, false);
  v_can_edit := v_role in ('owner', 'editor');
  select coalesce(flag.economics_v2_enabled, false)
  into v_v2_enabled
  from economics_v2.feature_flags flag
  where flag.granja_id = p_granja_id;
  v_v2_enabled := coalesce(v_v2_enabled, false);

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
  ), cycle_targets as (
    select
      cycle.id,
      cycle.granja_id,
      coalesce(
        nullif(btrim(cycle.name), ''),
        nullif(btrim(latest_feed.group_name_snapshot), ''),
        purpose.nombre
      ) as target_label,
      cycle.starts_on,
      cycle.ends_on
    from economics_v2.cycles cycle
    join public.cat_proposito_animal purpose
      on purpose.id = cycle.proposito_id
     and purpose.codigo_calculo = 'carne'
    left join lateral (
      select feed.group_name_snapshot
      from economics_v2.cycle_feeds feed
      where feed.cycle_id = cycle.id
        and feed.granja_id = cycle.granja_id
      order by feed.starts_on desc, feed.id desc
      limit 1
    ) latest_feed on true
    where v_v2_enabled
      and cycle.granja_id = p_granja_id
      and cycle.status in ('open', 'production_closed')
      and cycle.starts_on <= current_date
      and (cycle.ends_on is null or cycle.ends_on > cycle.starts_on)
  ), targets as (
    select
      'cycle'::text as target_kind,
      cycle.id as target_id,
      cycle.target_label,
      cycle.starts_on,
      cycle.ends_on
    from cycle_targets cycle
    union all
    select
      'legacy_mixture'::text,
      legacy.id,
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
  ), cycle_rows as (
    select
      expense.id as expense_id,
      'cycle'::text as target_kind,
      expense.cycle_id as target_id,
      coalesce(
        nullif(btrim(cycle.name), ''),
        nullif(btrim(latest_feed.group_name_snapshot), ''),
        purpose.nombre
      ) as target_label,
      expense.occurred_on,
      expense.amount,
      coalesce(nullif(btrim(expense.category), ''), '') as category,
      expense.note,
      expense.created_at,
      expense.updated_at,
      v_can_edit and cycle.status <> 'settled' as can_mutate
    from economics_v2.cycle_expenses expense
    join economics_v2.cycles cycle
      on cycle.id = expense.cycle_id
     and cycle.granja_id = expense.granja_id
    join public.cat_proposito_animal purpose
      on purpose.id = cycle.proposito_id
     and purpose.codigo_calculo = 'carne'
    left join lateral (
      select feed.group_name_snapshot
      from economics_v2.cycle_feeds feed
      where feed.cycle_id = cycle.id
        and feed.granja_id = cycle.granja_id
      order by feed.starts_on desc, feed.id desc
      limit 1
    ) latest_feed on true
    where v_v2_enabled
      and expense.granja_id = p_granja_id
      and cycle.status in ('open', 'production_closed')
      and cycle.starts_on <= current_date
      and (cycle.ends_on is null or cycle.ends_on > cycle.starts_on)
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
    select * from cycle_rows
    union all
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

-- Keep the existing cycle workspace create path and its optional category, but
-- enforce positive finite amounts, settled immutability, and the end boundary.
create or replace function economics_v2.record_cycle_expense_with_category_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_occurred_on date,
  p_amount numeric,
  p_category text,
  p_note text
) returns uuid
language plpgsql
security definer
set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_cycle economics_v2.cycles;
  v_expense_id uuid;
begin
  if p_occurred_on is null
     or p_occurred_on > current_date
     or p_amount is null
     or p_amount <= 0
     or p_amount in ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric) then
    raise exception using errcode = '22023', message = 'A positive finite non-future dated expense is required';
  end if;

  v_cycle := economics_v2.assert_cycle_access_impl(p_granja_id, p_cycle_id, true);
  select cycle.*
  into strict v_cycle
  from economics_v2.cycles cycle
  where cycle.id = p_cycle_id
    and cycle.granja_id = p_granja_id
  for update;

  if v_cycle.status = 'settled' then
    raise exception using errcode = '23514', message = 'Settled cycle expenses are immutable';
  end if;
  if p_occurred_on < v_cycle.starts_on
     or (v_cycle.ends_on is not null and p_occurred_on >= v_cycle.ends_on) then
    raise exception using errcode = '22023', message = 'Expense date is outside the cycle window';
  end if;

  insert into economics_v2.cycle_expenses (
    cycle_id, granja_id, occurred_on, amount, category, note, created_by
  ) values (
    p_cycle_id, p_granja_id, p_occurred_on, p_amount,
    nullif(btrim(p_category), ''), nullif(btrim(p_note), ''), v_user_id
  ) returning id into v_expense_id;

  update economics_v2.cycles set updated_at = now() where id = p_cycle_id;
  return v_expense_id;
end;
$$;

create or replace function economics_v2.record_cycle_expense_impl(
  p_granja_id uuid,
  p_cycle_id uuid,
  p_occurred_on date,
  p_amount numeric,
  p_note text
) returns uuid
language sql
security definer
set search_path = '' as $$
  select economics_v2.record_cycle_expense_with_category_impl(
    p_granja_id,
    p_cycle_id,
    p_occurred_on,
    p_amount,
    null,
    p_note
  );
$$;

create or replace function public.list_finance_expenses(
  p_granja_id uuid
) returns jsonb
language sql
security invoker
set search_path = '' as $$
  select economics_v2.read_finance_expenses_impl(p_granja_id);
$$;

create or replace function public.create_finance_expense(
  p_granja_id uuid,
  p_target_kind text,
  p_target_id uuid,
  p_occurred_on date,
  p_amount numeric,
  p_category text,
  p_note text
) returns jsonb
language sql
security invoker
set search_path = '' as $$
  select economics_v2.create_finance_expense_impl(
    p_granja_id, p_target_kind, p_target_id, p_occurred_on,
    p_amount, p_category, p_note
  );
$$;

create or replace function public.update_finance_expense(
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
language sql
security invoker
set search_path = '' as $$
  select economics_v2.update_finance_expense_impl(
    p_granja_id, p_expense_id, p_target_kind, p_target_id,
    p_expected_updated_at, p_occurred_on, p_amount, p_category, p_note
  );
$$;

create or replace function public.delete_finance_expense(
  p_granja_id uuid,
  p_expense_id uuid,
  p_target_kind text,
  p_target_id uuid,
  p_expected_updated_at timestamptz
) returns uuid
language sql
security invoker
set search_path = '' as $$
  select economics_v2.delete_finance_expense_impl(
    p_granja_id, p_expense_id, p_target_kind, p_target_id,
    p_expected_updated_at
  );
$$;

revoke all on function economics_v2.assert_finance_expense_actor_impl(uuid, boolean)
  from public, anon, authenticated;
revoke all on function economics_v2.validate_finance_expense_target_impl(uuid, text, uuid, date)
  from public, anon, authenticated;
revoke all on function economics_v2.read_finance_expenses_impl(uuid)
  from public, anon, authenticated;
revoke all on function economics_v2.create_finance_expense_impl(uuid, text, uuid, date, numeric, text, text)
  from public, anon, authenticated;
revoke all on function economics_v2.update_finance_expense_impl(uuid, uuid, text, uuid, timestamptz, date, numeric, text, text)
  from public, anon, authenticated;
revoke all on function economics_v2.delete_finance_expense_impl(uuid, uuid, text, uuid, timestamptz)
  from public, anon, authenticated;
revoke all on function public.list_finance_expenses(uuid)
  from public, anon, authenticated;
revoke all on function public.create_finance_expense(uuid, text, uuid, date, numeric, text, text)
  from public, anon, authenticated;
revoke all on function public.update_finance_expense(uuid, uuid, text, uuid, timestamptz, date, numeric, text, text)
  from public, anon, authenticated;
revoke all on function public.delete_finance_expense(uuid, uuid, text, uuid, timestamptz)
  from public, anon, authenticated;

grant execute on function economics_v2.assert_finance_expense_actor_impl(uuid, boolean)
  to authenticated;
grant execute on function economics_v2.validate_finance_expense_target_impl(uuid, text, uuid, date)
  to authenticated;
grant execute on function economics_v2.read_finance_expenses_impl(uuid)
  to authenticated;
grant execute on function economics_v2.create_finance_expense_impl(uuid, text, uuid, date, numeric, text, text)
  to authenticated;
grant execute on function economics_v2.update_finance_expense_impl(uuid, uuid, text, uuid, timestamptz, date, numeric, text, text)
  to authenticated;
grant execute on function economics_v2.delete_finance_expense_impl(uuid, uuid, text, uuid, timestamptz)
  to authenticated;
grant execute on function public.list_finance_expenses(uuid)
  to authenticated;
grant execute on function public.create_finance_expense(uuid, text, uuid, date, numeric, text, text)
  to authenticated;
grant execute on function public.update_finance_expense(uuid, uuid, text, uuid, timestamptz, date, numeric, text, text)
  to authenticated;
grant execute on function public.delete_finance_expense(uuid, uuid, text, uuid, timestamptz)
  to authenticated;

create or replace view public.puntos_equilibrio_huevos
with (security_invoker = true)
as
with mixture_windows as (
  select
    mixture.id as mezcla_id,
    mixture.granja_id,
    mixture.grupo_id,
    animal_group.nombre as grupo_nombre,
    mixture.fecha_inicio,
    mixture.fecha_termino,
    lead(mixture.fecha_inicio) over (
      partition by mixture.grupo_id
      order by mixture.fecha_inicio, mixture.id
    ) as siguiente_inicio
  from public.mezcla mixture
  join public.grupos animal_group on animal_group.id = mixture.grupo_id
), periods as (
  select
    mixture_window.*,
    coalesce(
      mixture_window.fecha_termino,
      mixture_window.siguiente_inicio,
      current_date
    )
      as fecha_fin_calculada,
    case
      when mixture_window.fecha_termino is null
        and mixture_window.siguiente_inicio is null
        then current_date + 1
      else coalesce(
        mixture_window.fecha_termino,
        mixture_window.siguiente_inicio,
        current_date
      )
    end as fecha_fin_exclusiva
  from mixture_windows mixture_window
), aggregates as (
  select
    period.*,
    greatest(period.fecha_fin_exclusiva - period.fecha_inicio, 1) as dias_mezcla,
    coalesce((
      select sum(collection.buenos)
      from public.recoleccion_huevo collection
      where collection.grupo_id = period.grupo_id
        and collection.fecha_recoleccion >= period.fecha_inicio
        and collection.fecha_recoleccion < period.fecha_fin_exclusiva
    ), 0::bigint) as buenos,
    coalesce((
      select sum(collection.rotos)
      from public.recoleccion_huevo collection
      where collection.grupo_id = period.grupo_id
        and collection.fecha_recoleccion >= period.fecha_inicio
        and collection.fecha_recoleccion < period.fecha_fin_exclusiva
    ), 0::bigint) as rotos,
    coalesce((
      select sum(coalesce(component.cantidad, food.cantidad))
      from public.mezcla_comida component
      join public.comida food on food.id = component.comida_id
      where component.mezcla_id = period.mezcla_id
    ), 0::numeric) as consumo_total,
    coalesce((
      select sum(
        case
          when food.cantidad > 0 then coalesce(food.precio, 0::numeric)
            * coalesce(component.cantidad, food.cantidad) / food.cantidad
          else 0::numeric
        end
      )
      from public.mezcla_comida component
      join public.comida food on food.id = component.comida_id
      where component.mezcla_id = period.mezcla_id
    ), 0::numeric) as total_costo_comidas,
    coalesce((
      select sum(expense.amount)
      from public.legacy_mixture_expenses expense
      where expense.granja_id = period.granja_id
        and expense.mixture_id = period.mezcla_id
    ), 0::numeric) as total_gastos_directos,
    coalesce((
      select sum(
        greatest(
          least(coalesce(removal.fecha_baja, period.fecha_fin_exclusiva), period.fecha_fin_exclusiva)
          - greatest(animal.fecha_adquisicion, period.fecha_inicio),
          0
        )
      )::numeric
      from public.animales animal
      left join public.bajas_animales removal on removal.id = animal.baja_id
      where animal.grupo_id = period.grupo_id
        and animal.fecha_adquisicion < period.fecha_fin_exclusiva
        and (removal.fecha_baja is null or removal.fecha_baja > period.fecha_inicio)
    ), 0::numeric) as ave_dias,
    (
      select sum(sale.precio * sale.cantidad) / nullif(sum(sale.cantidad), 0)
      from public.venta_huevo sale
      where sale.grupo_id = period.grupo_id
        and sale.fecha_venta >= period.fecha_inicio
        and sale.fecha_venta < period.fecha_fin_exclusiva
    ) as precio_venta_promedio
  from periods period
), base_metrics as (
  select
    aggregate.*,
    aggregate.total_costo_comidas + aggregate.total_gastos_directos as costo_total,
    (aggregate.total_costo_comidas + aggregate.total_gastos_directos)
      / nullif(aggregate.buenos, 0) as punto_de_equilibrio,
    aggregate.ave_dias / aggregate.dias_mezcla as aves_promedio_ponderado,
    aggregate.buenos::numeric / aggregate.dias_mezcla as huevos_por_dia,
    aggregate.consumo_total / aggregate.dias_mezcla as consumo_por_dia
  from aggregates aggregate
), final_metrics as (
  select
    base.*,
    base.huevos_por_dia / nullif(base.aves_promedio_ponderado, 0)
      as huevos_por_dia_ave,
    base.consumo_por_dia / nullif(base.aves_promedio_ponderado, 0)
      as consumo_por_dia_ave,
    (base.precio_venta_promedio - base.punto_de_equilibrio)
      / nullif(base.punto_de_equilibrio, 0) * 100 as margen_porcentaje
  from base_metrics base
)
select
  fecha_inicio,
  fecha_termino,
  mezcla_id,
  grupo_nombre,
  buenos,
  rotos,
  total_costo_comidas,
  punto_de_equilibrio,
  granja_id,
  grupo_id,
  fecha_fin_calculada,
  dias_mezcla,
  consumo_total,
  aves_promedio_ponderado,
  huevos_por_dia,
  huevos_por_dia_ave,
  consumo_por_dia,
  consumo_por_dia_ave,
  precio_venta_promedio,
  margen_porcentaje,
  total_gastos_directos,
  costo_total
from final_metrics
order by fecha_inicio;

comment on column public.puntos_equilibrio_huevos.total_costo_comidas is
  'Food-only cost retained for backward-compatible reporting.';
comment on column public.puntos_equilibrio_huevos.total_gastos_directos is
  'Direct legacy expenses attributed to this farm and mixture only.';
comment on column public.puntos_equilibrio_huevos.costo_total is
  'Total cost: food cost plus direct legacy expenses.';

revoke all privileges on table public.puntos_equilibrio_huevos from public, anon;
grant select on table public.puntos_equilibrio_huevos to authenticated, service_role;
