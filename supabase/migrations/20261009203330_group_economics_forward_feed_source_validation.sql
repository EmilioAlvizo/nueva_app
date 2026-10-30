-- Private source inspection only: no allocation, operation receipt or finalization.
-- Returned context is not an authorization token. Writers must acquire their ordered
-- scope/fact locks and recheck the actual source version AND digest before capture.
-- VOLATILE matches the retained actor/error helpers; this body performs only reads.
create function economics_v2.validate_group_feed_source(
  p_granja_id uuid, p_period_id uuid, p_mixture_id uuid,
  p_expected_updated_at timestamptz
) returns jsonb language plpgsql volatile security invoker set search_path='' as $$
declare
  v_actor uuid;
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_mixture public.mezcla%rowtype;
  v_component record;
  v_categories uuid[] := '{}'::uuid[];
  v_components jsonb := '[]'::jsonb;
  v_count integer := 0;
  v_quantity numeric := 0;
  v_cost numeric := 0;
  v_snapshot jsonb;
begin
  v_actor := economics_v2.assert_group_writer_actor(p_granja_id);
  if p_period_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','period_id',null);
  end if;
  if p_mixture_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','mixture_id',null);
  end if;
  if p_expected_updated_at is null or not isfinite(p_expected_updated_at) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','expected_updated_at',p_mixture_id);
  end if;

  select p.* into v_period from economics_v2.group_occupancy_periods p
  where p.id=p_period_id and p.granja_id=p_granja_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id);
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
  if v_period.starts_on is null or not isfinite(v_period.starts_on) or v_period.starts_on>current_date then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',p_period_id);
  end if;

  select m.* into v_mixture from public.mezcla m
  where m.id=p_mixture_id and m.granja_id=p_granja_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','mixture_id',p_mixture_id);
  end if;
  if v_mixture.grupo_id is distinct from v_period.group_id then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_mixture.grupo_id);
  end if;
  -- An ended mixture is still a legitimate historical source for this OPEN period.
  -- Date admission precedes stale-version refusal, including corrupted source dates.
  if v_mixture.fecha_inicio is null or not isfinite(v_mixture.fecha_inicio)
    or v_mixture.fecha_inicio>current_date or v_mixture.fecha_inicio<v_period.starts_on
    or (v_mixture.fecha_termino is not null and (not isfinite(v_mixture.fecha_termino)
      or v_mixture.fecha_termino>current_date or v_mixture.fecha_termino<v_mixture.fecha_inicio)) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','occurred_on',p_mixture_id);
  end if;
  if exists(select 1 from economics_v2.group_occupancy_events e
    where e.granja_id=p_granja_id and e.period_id=p_period_id and e.effective_on>v_mixture.fecha_inicio)
    or exists(select 1 from economics_v2.group_occupancy_periods p
      where p.granja_id=p_granja_id and p.group_id=v_period.group_id and p.purpose_id=v_period.purpose_id
        and p.starts_on>v_mixture.fecha_inicio) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','occurred_on',p_mixture_id);
  end if;
  if v_mixture.updated_at is null or not isfinite(v_mixture.updated_at) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;
  if v_mixture.updated_at is distinct from p_expected_updated_at then
    perform economics_v2.raise_group_writer_error('40001','stale_write','mixture_id',p_mixture_id);
  end if;

  -- LEFT joins retain incomplete components rather than silently excluding them.
  -- No creator filter: current farm authorization is independent of source authorship.
  for v_component in
    select mc.id as component_id, mc.granja_id as component_farm, mc.comida_id as referenced_food,
      mc.cantidad as quantity_kg, c.id as food_id, c.granja_id as food_farm,
      c.cat_comida_id as category_id, c.precio as total_cost,
      cc.id as category_row_id, cc.granja_id as category_farm
    from public.mezcla_comida mc
    left join public.comida c on c.id=mc.comida_id
    left join public.cat_comida cc on cc.id=c.cat_comida_id
    where mc.mezcla_id=p_mixture_id order by mc.id
  loop
    if v_component.component_farm is distinct from p_granja_id then
      perform economics_v2.raise_group_writer_error('42501','forbidden','component_id',v_component.component_id);
    end if;
    if v_component.food_id is null then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
    end if;
    if v_component.food_farm is distinct from p_granja_id then
      perform economics_v2.raise_group_writer_error('42501','forbidden','food_id',v_component.food_id);
    end if;
    if v_component.category_row_id is null then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
    end if;
    if v_component.category_farm is distinct from p_granja_id then
      perform economics_v2.raise_group_writer_error('42501','forbidden','category_id',v_component.category_id);
    end if;
    -- Dedicated purchases cannot be shared, even through a foreign-farm component.
    if exists(select 1 from public.mezcla_comida other_component
      where other_component.comida_id=v_component.food_id and other_component.mezcla_id<>p_mixture_id)
      or v_component.category_id=any(v_categories) then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
    end if;
    if v_component.quantity_kg is null or v_component.quantity_kg<=0
      or v_component.quantity_kg in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric)
      or v_component.total_cost is null or v_component.total_cost<0
      or v_component.total_cost in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric) then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
    end if;
    -- Archived referenced categories remain valid. Stock c.cantidad and cc.activo
    -- are neither ingredient kg nor economic cost and never enter this snapshot.
    v_categories := array_append(v_categories,v_component.category_id);
    v_count := v_count+1;
    begin
      v_quantity := v_quantity+v_component.quantity_kg;
      v_cost := v_cost+v_component.total_cost;
    exception when numeric_value_out_of_range then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
    end;
    v_components := v_components||jsonb_build_array(jsonb_build_object(
      'component_id',v_component.component_id,'food_id',v_component.food_id,
      'category_id',v_component.category_id,'quantity_kg',v_component.quantity_kg,
      'total_cost',v_component.total_cost));
  end loop;
  if v_count=0 or v_quantity<=0 or v_quantity in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric)
    or v_cost<0 or v_cost in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','mixture_id',p_mixture_id);
  end if;

  v_snapshot := economics_v2.canonical_group_request(jsonb_build_object(
    'source_version','group-feed-source.v1','granja_id',p_granja_id,
    'mixture_id',v_mixture.id,'group_id',v_mixture.grupo_id,
    'fecha_inicio',v_mixture.fecha_inicio,'fecha_termino',v_mixture.fecha_termino,
    'updated_at_utc',to_char(v_mixture.updated_at at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
    'components',v_components));
  return jsonb_build_object(
    'context_version','group-feed-source-context.v1','actor_id',v_actor,
    'granja_id',p_granja_id,'period_id',v_period.id,'mixture_id',v_mixture.id,
    'source_updated_at',v_mixture.updated_at,'occurred_on',v_mixture.fecha_inicio,
    'component_count',v_count,'quantity_kg',v_quantity,'total_cost',v_cost,
    'source_digest',encode(sha256(convert_to(v_snapshot::text,'UTF8')),'hex'),
    'source_snapshot',v_snapshot);
end;
$$;

revoke all on function economics_v2.validate_group_feed_source(uuid,uuid,uuid,timestamptz)
from public,anon,authenticated;
