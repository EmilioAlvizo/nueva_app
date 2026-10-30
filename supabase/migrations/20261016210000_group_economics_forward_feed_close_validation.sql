-- Historical captured-source inspection only; this is not closure authority.
-- A future closer must lock the complete scope and facts, then revalidate in its
-- transaction. This result is informative, not a token or authorization receipt.
create function economics_v2.validate_group_feed_allocation_for_close(
  p_granja_id uuid, p_period_id uuid, p_allocation_id uuid
) returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_allocation economics_v2.group_period_feed_allocations%rowtype;
  v_mixture public.mezcla%rowtype;
  v_component record;
  v_categories uuid[] := '{}'::uuid[];
  v_components jsonb := '[]'::jsonb;
  v_count integer := 0;
  v_quantity numeric := 0;
  v_cost numeric := 0;
  v_digest text;
begin
  if p_granja_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','granja_id',null);
  end if;
  if p_period_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','period_id',null);
  end if;
  if p_allocation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','allocation_id',null);
  end if;
  -- Even a postgres invoker must supply a real authorized owner/editor JWT.
  -- The retained actor/error helpers only read or raise; no mutator is called.
  perform economics_v2.assert_group_writer_actor(p_granja_id);

  select p.* into v_period from economics_v2.group_occupancy_periods p
  where p.id=p_period_id and p.granja_id=p_granja_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id);
  end if;
  select a.* into v_allocation from economics_v2.group_period_feed_allocations a
  where a.id=p_allocation_id and a.granja_id=p_granja_id and a.period_id=p_period_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','allocation_id',p_allocation_id);
  end if;
  if v_period.closed_on is not null or v_period.end_position is not null then
    perform economics_v2.raise_group_writer_error('23514','closed_period_immutable','period_id',p_period_id);
  end if;
  if not exists(select 1 from public.grupos g join public.tipo_animal t
    on t.id=g.tipo_animal_id and t.granja_id=g.granja_id
    where g.id=v_period.group_id and g.granja_id=p_granja_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_period.group_id);
  end if;
  if not exists(select 1 from public.cat_proposito_animal c
    where c.id=v_period.purpose_id and c.granja_id=p_granja_id) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',v_period.purpose_id);
  end if;
  if not exists(select 1 from public.cat_proposito_animal c
    where c.id=v_period.purpose_id and c.granja_id=p_granja_id and c.codigo_calculo='carne') then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','purpose_id',v_period.purpose_id);
  end if;
  if v_period.starts_on is null or not isfinite(v_period.starts_on) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',p_period_id);
  end if;
  -- A finalized allocation in an OPEN period is not a valid pre-close fact.
  if v_allocation.finalized_at is not null then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','allocation_id',p_allocation_id);
  end if;

  select m.* into v_mixture from public.mezcla m
  where m.id=v_allocation.mixture_id and m.granja_id=p_granja_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','mixture_id',v_allocation.mixture_id);
  end if;
  if v_mixture.grupo_id is distinct from v_period.group_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_mixture.grupo_id);
  end if;
  -- Retain source date integrity, not calendar or occupancy admission policy.
  -- Later legitimate entries and other periods do not invalidate captured feed.
  if v_mixture.fecha_inicio is null or not isfinite(v_mixture.fecha_inicio)
    or v_mixture.fecha_inicio<v_period.starts_on
    or (v_mixture.fecha_termino is not null and (not isfinite(v_mixture.fecha_termino)
      or v_mixture.fecha_termino<v_mixture.fecha_inicio)) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','occurred_on',v_mixture.id);
  end if;
  if v_mixture.updated_at is null or not isfinite(v_mixture.updated_at) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',v_mixture.id);
  end if;

  -- LEFT joins preserve missing references for explicit refusal. Joining only
  -- primary-key parents avoids fanout; sharing is checked separately below.
  for v_component in
    select mc.id as component_id, mc.granja_id as component_farm,
      mc.cantidad as quantity_kg, c.id as food_id, c.granja_id as food_farm,
      c.cat_comida_id as category_id, c.precio as total_cost,
      cc.id as category_row_id, cc.granja_id as category_farm
    from public.mezcla_comida mc
    left join public.comida c on c.id=mc.comida_id
    left join public.cat_comida cc on cc.id=c.cat_comida_id
    where mc.mezcla_id=v_mixture.id order by mc.id
  loop
    if v_component.component_farm is distinct from p_granja_id then
      perform economics_v2.raise_group_writer_error('42501','forbidden','component_id',v_component.component_id);
    end if;
    if v_component.food_id is null then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',v_mixture.id);
    end if;
    if v_component.food_farm is distinct from p_granja_id then
      perform economics_v2.raise_group_writer_error('42501','forbidden','food_id',v_component.food_id);
    end if;
    if v_component.category_row_id is null then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',v_mixture.id);
    end if;
    if v_component.category_farm is distinct from p_granja_id then
      perform economics_v2.raise_group_writer_error('42501','forbidden','category_id',v_component.category_id);
    end if;
    -- A purchase must remain dedicated, including against foreign-farm references.
    if exists(select 1 from public.mezcla_comida other_component
      where other_component.comida_id=v_component.food_id and other_component.id<>v_component.component_id)
      or v_component.category_id=any(v_categories) then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',v_mixture.id);
    end if;
    if v_component.quantity_kg is null or v_component.quantity_kg<=0
      or v_component.quantity_kg in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric)
      or v_component.total_cost is null or v_component.total_cost<0
      or v_component.total_cost in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric) then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',v_mixture.id);
    end if;
    -- comida.precio is TOTAL purchase cost, never a unit price multiplier.
    -- Stock and category archival status are deliberately not inspected/hashed.
    v_categories := array_append(v_categories,v_component.category_id);
    begin
      v_count := v_count+1;
      v_quantity := v_quantity+v_component.quantity_kg;
      v_cost := v_cost+v_component.total_cost;
    exception when numeric_value_out_of_range then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',v_mixture.id);
    end;
    v_components := v_components||jsonb_build_array(jsonb_build_object(
      'component_id',v_component.component_id,'food_id',v_component.food_id,
      'category_id',v_component.category_id,'quantity_kg',v_component.quantity_kg,
      'total_cost',v_component.total_cost));
  end loop;
  if v_count=0 or v_quantity<=0 or v_quantity in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric)
    or v_cost<0 or v_cost in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',v_mixture.id);
  end if;

  -- Preserve group-feed-source.v1 exactly: eight header keys, five component
  -- keys in UUID order, numeric normalization and opaque strings unchanged.
  v_digest := encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'source_version','group-feed-source.v1','granja_id',v_mixture.granja_id,
    'mixture_id',v_mixture.id,'group_id',v_mixture.grupo_id,
    'fecha_inicio',v_mixture.fecha_inicio,'fecha_termino',v_mixture.fecha_termino,
    'updated_at_utc',to_char(v_mixture.updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'components',v_components))::text,'UTF8')),'hex');
  -- Never trust cached allocation values as inputs to the independent digest.
  if v_allocation.occurred_on is distinct from v_mixture.fecha_inicio
    or v_allocation.source_updated_at is distinct from v_mixture.updated_at
    or v_allocation.source_digest is distinct from v_digest
    or v_allocation.component_count is distinct from v_count
    or v_allocation.quantity_kg is distinct from v_quantity
    or v_allocation.total_cost is distinct from v_cost then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','allocation_id',p_allocation_id);
  end if;
  return jsonb_build_object(
    'contract_version','group-economics.forward.v3','allocation_id',v_allocation.id,
    'mixture_id',v_mixture.id,'period_id',v_period.id,
    'source_updated_at',v_mixture.updated_at,'source_digest',v_digest,
    'component_count',v_count,'quantity_kg',v_quantity,'total_cost',v_cost);
end;
$$;

alter function economics_v2.validate_group_feed_allocation_for_close(uuid,uuid,uuid) owner to postgres;
revoke execute on function economics_v2.validate_group_feed_allocation_for_close(uuid,uuid,uuid)
from public,anon,authenticated,service_role;
