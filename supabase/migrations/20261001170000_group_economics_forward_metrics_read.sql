create or replace function economics_v2.calculate_group_period_live_metrics(
  p_granja_id uuid,
  p_period_id uuid
) returns jsonb
language plpgsql
security invoker
stable
set search_path = '' as $$
declare v_metrics jsonb;
begin
  if p_granja_id is null then
    raise exception using
      errcode = '22023',
      message = 'Invalid Group economics metrics request',
      detail = jsonb_build_object(
        'contract_version', 'group-economics.forward.v3',
        'code', 'invalid_request', 'field', 'granja_id', 'entity_id', null
      )::text;
  end if;

  if p_period_id is null then
    raise exception using
      errcode = '22023',
      message = 'Invalid Group economics metrics request',
      detail = jsonb_build_object(
        'contract_version', 'group-economics.forward.v3',
        'code', 'invalid_request', 'field', 'period_id', 'entity_id', null
      )::text;
  end if;

  if not exists (
    select 1 from economics_v2.group_occupancy_periods
    where id = p_period_id and granja_id = p_granja_id
  ) then
    if exists (select 1 from economics_v2.group_occupancy_periods where id = p_period_id) then
      raise exception using
        errcode = '42501',
        message = 'Group economics period is forbidden',
        detail = jsonb_build_object(
          'contract_version', 'group-economics.forward.v3',
          'code', 'forbidden', 'field', 'period_id', 'entity_id', p_period_id
        )::text;
    end if;
    raise exception using
      errcode = '22023',
      message = 'Invalid Group economics metrics request',
      detail = jsonb_build_object(
        'contract_version', 'group-economics.forward.v3',
        'code', 'invalid_request', 'field', 'period_id', 'entity_id', p_period_id
      )::text;
  end if;

  with members as (
    select animal_id, bool_or(end_position is null) as is_active
    from economics_v2.group_occupancy_memberships
    where granja_id = p_granja_id and period_id = p_period_id
    group by animal_id
  ), member_metrics as (
    select count(*) as animal_count,
      count(*) filter (where is_active) as active_animal_count,
      count(*) filter (where not is_active) as exited_animal_count
    from members
  ), feed_metrics as (
    select count(*) as feed_source_count,
      coalesce(sum(quantity_kg), 0::numeric) as feed_kg_total,
      coalesce(sum(total_cost), 0::numeric) as feed_cost
    from economics_v2.group_period_feed_allocations
    where granja_id = p_granja_id and period_id = p_period_id
  ), expense_metrics as (
    select coalesce(sum(amount), 0::numeric) as direct_expense_total
    from economics_v2.group_period_expenses
    where granja_id = p_granja_id and period_id = p_period_id
  ), sale_metrics as (
    select count(*) as sale_count,
      coalesce(sum(quantity), 0::numeric) as sold_animal_count,
      coalesce(sum(saleable_kg), 0::numeric) as saleable_kg,
      coalesce(sum(total_amount), 0::numeric) as animal_sale_revenue
    from economics_v2.group_period_sale_bindings
    where granja_id = p_granja_id and period_id = p_period_id
  ), basis_metrics as (
    select coalesce(sum(signed_amount), 0::numeric) as acquisition_cost
    from economics_v2.group_acquisition_basis_entries
    where granja_id = p_granja_id and period_id = p_period_id and account_kind = 'period'
  ), raw_metrics as (
    select member_metrics.*, feed_metrics.*, expense_metrics.*, sale_metrics.*, basis_metrics.*
    from member_metrics cross join feed_metrics cross join expense_metrics
    cross join sale_metrics cross join basis_metrics
  ), calculated_metrics as (
    select *, feed_cost + acquisition_cost + direct_expense_total as total_cost,
      animal_sale_revenue - (feed_cost + acquisition_cost + direct_expense_total) as profit
    from raw_metrics
  )
  select jsonb_build_object(
    'animal_count', animal_count,
    'active_animal_count', active_animal_count,
    'exited_animal_count', exited_animal_count,
    'sold_animal_count', sold_animal_count,
    'feed_source_count', feed_source_count,
    'feed_kg_total', feed_kg_total,
    'feed_cost', feed_cost,
    'acquisition_cost', acquisition_cost,
    'direct_expense_total', direct_expense_total,
    'sale_count', sale_count,
    'saleable_kg', saleable_kg,
    'animal_sale_revenue', animal_sale_revenue,
    'total_cost', total_cost,
    'profit', profit,
    'realized_price_per_kg', case when saleable_kg > 0 then animal_sale_revenue / saleable_kg end,
    'break_even_kg', case when animal_sale_revenue > 0 and saleable_kg > 0 then total_cost / (animal_sale_revenue / saleable_kg) end,
    'balance_per_animal', case when animal_count > 0 then profit / animal_count end
  ) into v_metrics
  from calculated_metrics;

  return v_metrics;
end;
$$;

revoke all on function economics_v2.calculate_group_period_live_metrics(uuid, uuid)
  from public, anon, authenticated;
