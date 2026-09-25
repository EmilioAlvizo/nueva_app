-- Extend cycle summaries with auditable meat economics while preserving the
-- public wrapper and its existing authorization contract.

create or replace function economics_v2.read_cycle_summaries_impl(
  p_granja_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
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
    raise exception using errcode = '42501', message = 'Cycle summary access denied';
  end if;

  with cycle_base as (
    select
      cycle.id as cycle_id,
      cycle.granja_id,
      cycle.status,
      cycle.starts_on,
      cycle.ends_on,
      cycle.production_closed_on,
      purpose.id as purpose_id,
      purpose.nombre as purpose_name,
      purpose.codigo_calculo as purpose_code
    from economics_v2.cycles cycle
    join public.cat_proposito_animal purpose
      on purpose.id = cycle.proposito_id
    where cycle.granja_id = p_granja_id
  ), animal_totals as (
    select
      member.cycle_id,
      count(*)::integer as animal_count,
      count(*) filter (where member.left_on is null)::integer as active_count,
      count(*) filter (where member.left_on is not null)::integer as exited_count,
      count(*) filter (
        where member.sold_by_sale_id is not null
      )::integer as sold_animal_count,
      coalesce(sum(coalesce(member.acquisition_cost_snapshot, 0)), 0) as acquisition_cost
    from economics_v2.cycle_animals member
    join cycle_base cycle on cycle.cycle_id = member.cycle_id
    group by member.cycle_id
  ), expense_totals as (
    select
      expense.cycle_id,
      coalesce(sum(expense.amount), 0) as direct_expense_total
    from economics_v2.cycle_expenses expense
    join cycle_base cycle
      on cycle.cycle_id = expense.cycle_id
     and cycle.granja_id = expense.granja_id
    group by expense.cycle_id
  ), distinct_linked_mixtures as (
    select distinct
      feed.cycle_id,
      feed.granja_id,
      feed.mezcla_id
    from economics_v2.cycle_feeds feed
    join cycle_base cycle
      on cycle.cycle_id = feed.cycle_id
     and cycle.granja_id = feed.granja_id
    where feed.mezcla_id is not null
  ), mixture_totals as (
    select
      linked.cycle_id,
      linked.mezcla_id,
      coalesce(sum(coalesce(food.precio, 0)), 0) as feed_cost,
      coalesce(sum(coalesce(component.cantidad, 0)), 0) as feed_kg_total
    from distinct_linked_mixtures linked
    join public.mezcla mixture
      on mixture.id = linked.mezcla_id
     and mixture.granja_id = linked.granja_id
    left join public.mezcla_comida component
      on component.mezcla_id = mixture.id
     and component.granja_id = linked.granja_id
    left join public.comida food
      on food.id = component.comida_id
     and food.granja_id = linked.granja_id
    group by linked.cycle_id, linked.mezcla_id
  ), feed_totals as (
    select
      mixture.cycle_id,
      count(*)::integer as linked_mixture_count,
      coalesce(sum(mixture.feed_cost), 0) as feed_cost,
      coalesce(sum(mixture.feed_kg_total), 0) as feed_kg_total
    from mixture_totals mixture
    group by mixture.cycle_id
  ), latest_linked_feed as (
    select distinct on (feed.cycle_id)
      feed.cycle_id,
      coalesce(
        nullif(btrim(feed.group_name_snapshot), ''),
        animal_group.nombre
      ) as group_name
    from economics_v2.cycle_feeds feed
    join cycle_base cycle
      on cycle.cycle_id = feed.cycle_id
     and cycle.granja_id = feed.granja_id
    left join public.mezcla mixture
      on mixture.id = feed.mezcla_id
     and mixture.granja_id = feed.granja_id
    left join public.grupos animal_group
      on animal_group.id = mixture.grupo_id
     and animal_group.granja_id = feed.granja_id
    order by feed.cycle_id, feed.starts_on desc, feed.id desc
  ), distinct_sales as (
    select distinct
      member.cycle_id,
      sale.id as sale_id,
      sale.total_amount
    from economics_v2.cycle_animals member
    join cycle_base cycle on cycle.cycle_id = member.cycle_id
    join public.venta_animal sale
      on sale.id = member.sold_by_sale_id
     and sale.granja_id = cycle.granja_id
    where member.sold_by_sale_id is not null
  ), sale_totals as (
    select
      sale.cycle_id,
      count(*)::integer as sale_count,
      coalesce(sum(sale.total_amount), 0) as animal_sale_revenue
    from distinct_sales sale
    group by sale.cycle_id
  ), summary_values as (
    select
      cycle.*,
      coalesce(animals.animal_count, 0) as animal_count,
      coalesce(animals.active_count, 0) as active_animal_count,
      coalesce(animals.exited_count, 0) as exited_animal_count,
      coalesce(animals.sold_animal_count, 0) as sold_animal_count,
      coalesce(animals.acquisition_cost, 0) as acquisition_cost,
      coalesce(expenses.direct_expense_total, 0) as direct_expense_total,
      coalesce(feeds.linked_mixture_count, 0) as linked_mixture_count,
      coalesce(feeds.feed_cost, 0) as feed_cost,
      coalesce(feeds.feed_kg_total, 0) as feed_kg_total,
      latest_feed.group_name as latest_linked_group_name,
      coalesce(sales.sale_count, 0) as sale_count,
      coalesce(sales.animal_sale_revenue, 0) as animal_sale_revenue
    from cycle_base cycle
    left join animal_totals animals on animals.cycle_id = cycle.cycle_id
    left join expense_totals expenses on expenses.cycle_id = cycle.cycle_id
    left join feed_totals feeds on feeds.cycle_id = cycle.cycle_id
    left join latest_linked_feed latest_feed
      on latest_feed.cycle_id = cycle.cycle_id
    left join sale_totals sales on sales.cycle_id = cycle.cycle_id
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'cycle_id', summary.cycle_id,
        'granja_id', summary.granja_id,
        'status', summary.status,
        'starts_on', summary.starts_on,
        'ends_on', summary.ends_on,
        'production_closed_on', summary.production_closed_on,
        'purpose_id', summary.purpose_id,
        'purpose_name', summary.purpose_name,
        'purpose_code', summary.purpose_code,
        'active_animal_count', summary.active_animal_count,
        'exited_animal_count', summary.exited_animal_count,
        'animal_count', summary.animal_count,
        'direct_expense_total', summary.direct_expense_total,
        'linked_mixture_count', summary.linked_mixture_count,
        'latest_linked_group_name', summary.latest_linked_group_name,
        'feed_cost', summary.feed_cost,
        'feed_kg_total', summary.feed_kg_total,
        'acquisition_cost', summary.acquisition_cost,
        'total_cost', summary.feed_cost
          + summary.direct_expense_total
          + summary.acquisition_cost,
        'animal_sale_revenue', summary.animal_sale_revenue,
        'sale_count', summary.sale_count,
        'sold_animal_count', summary.sold_animal_count,
        'profit', summary.animal_sale_revenue
          - summary.feed_cost
          - summary.direct_expense_total
          - summary.acquisition_cost,
        'balance_per_animal', case
          when summary.animal_count = 0 then null
          else (
            summary.animal_sale_revenue
            - summary.feed_cost
            - summary.direct_expense_total
            - summary.acquisition_cost
          ) / summary.animal_count
        end
      )
      order by summary.starts_on desc, summary.cycle_id
    ),
    '[]'::jsonb
  )
  into v_result
  from summary_values summary;

  return v_result;
end;
$$;
