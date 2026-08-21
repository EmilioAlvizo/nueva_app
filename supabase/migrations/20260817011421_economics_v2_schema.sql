create schema economics_v2;
revoke all on schema economics_v2 from public, anon;
grant usage on schema economics_v2 to authenticated;

alter table public.cat_proposito_animal
  add column codigo_calculo text,
  add constraint cat_proposito_animal_codigo_calculo_check
    check (codigo_calculo is null or codigo_calculo in ('postura', 'carne', 'ornamental'));

insert into public.cat_proposito_animal (nombre, codigo_calculo, activo)
select purpose_name, purpose_code, true
from (values ('Postura', 'postura'), ('Carne', 'carne'), ('Ornamental', 'ornamental')) as purpose(purpose_name, purpose_code)
where not exists (
  select 1 from public.cat_proposito_animal existing
  where existing.codigo_calculo = purpose.purpose_code
);

create table economics_v2.feature_flags (
  granja_id uuid primary key references public.granjas(id) on delete cascade,
  economics_v2_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

create table economics_v2.cycles (
  id uuid primary key default gen_random_uuid(),
  granja_id uuid not null references public.granjas(id),
  proposito_id uuid not null references public.cat_proposito_animal(id),
  starts_on date not null,
  ends_on date,
  status text not null default 'open' check (status in ('open', 'closed')),
  created_by uuid not null references public.perfiles(id),
  created_at timestamptz not null default now(),
  check (ends_on is null or ends_on >= starts_on)
);

create table economics_v2.cycle_animals (
  cycle_id uuid not null references economics_v2.cycles(id) on delete cascade,
  animal_id uuid not null references public.animales(id),
  joined_on date not null,
  left_on date,
  sold_by_sale_id uuid,
  primary key (cycle_id, animal_id),
  check (left_on is null or left_on >= joined_on)
);

create table economics_v2.cycle_expenses (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references economics_v2.cycles(id) on delete cascade,
  granja_id uuid not null references public.granjas(id),
  occurred_on date not null,
  amount numeric not null check (amount >= 0),
  note text,
  created_by uuid not null references public.perfiles(id),
  created_at timestamptz not null default now()
);

create table economics_v2.cycle_feeds (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references economics_v2.cycles(id) on delete cascade,
  granja_id uuid not null references public.granjas(id),
  mezcla_id uuid references public.mezcla(id),
  starts_on date not null,
  ends_on date,
  created_by uuid not null references public.perfiles(id),
  created_at timestamptz not null default now(),
  check (ends_on is null or ends_on >= starts_on)
);

create table economics_v2.projections (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references economics_v2.cycles(id) on delete cascade,
  granja_id uuid not null references public.granjas(id),
  assumptions jsonb not null default '{}'::jsonb,
  created_by uuid not null references public.perfiles(id),
  created_at timestamptz not null default now()
);

create table economics_v2.final_results (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null unique references economics_v2.cycles(id),
  granja_id uuid not null references public.granjas(id),
  calculation_version text not null,
  input_snapshot jsonb not null,
  result_snapshot jsonb not null,
  created_by uuid not null references public.perfiles(id),
  created_at timestamptz not null default now()
);

create index cycles_granja_status_idx on economics_v2.cycles (granja_id, status);
create index cycles_proposito_idx on economics_v2.cycles (proposito_id);
create index cycles_created_by_idx on economics_v2.cycles (created_by);
create index cycle_animals_animal_idx on economics_v2.cycle_animals (animal_id);
create index cycle_expenses_cycle_idx on economics_v2.cycle_expenses (cycle_id, occurred_on);
create index cycle_expenses_granja_idx on economics_v2.cycle_expenses (granja_id);
create index cycle_expenses_created_by_idx on economics_v2.cycle_expenses (created_by);
create index cycle_feeds_cycle_idx on economics_v2.cycle_feeds (cycle_id, starts_on);
create index cycle_feeds_granja_idx on economics_v2.cycle_feeds (granja_id);
create index cycle_feeds_mezcla_idx on economics_v2.cycle_feeds (mezcla_id);
create index cycle_feeds_created_by_idx on economics_v2.cycle_feeds (created_by);
create index projections_cycle_idx on economics_v2.projections (cycle_id);
create index projections_granja_idx on economics_v2.projections (granja_id);
create index projections_created_by_idx on economics_v2.projections (created_by);
create index final_results_granja_idx on economics_v2.final_results (granja_id);
create index final_results_created_by_idx on economics_v2.final_results (created_by);

alter table public.venta_animal alter column animal_id drop not null;
alter table public.venta_animal add column baja_id uuid unique references public.bajas_animales(id);
alter table public.venta_animal add column record_kind text not null default 'individual'
  check (record_kind in ('individual', 'legacy_batch'));
alter table public.venta_animal add column quantity integer not null default 1 check (quantity > 0);
alter table public.venta_animal add column total_amount numeric not null default 0 check (total_amount >= 0);
alter table public.venta_animal add constraint venta_animal_individual_or_legacy_batch_check
  check ((record_kind = 'legacy_batch' and animal_id is null) or (record_kind = 'individual' and animal_id is not null));
update public.venta_animal set total_amount = coalesce(precio, 0) where total_amount = 0;
create index venta_animal_granja_fecha_idx on public.venta_animal (granja_id, fecha_venta);
create index venta_animal_grupo_idx on public.venta_animal (grupo_id);
create index venta_animal_tipo_animal_idx on public.venta_animal (tipo_animal_id);
create index venta_animal_animal_idx on public.venta_animal (animal_id);
create index venta_animal_created_by_idx on public.venta_animal (created_by);

alter table economics_v2.feature_flags enable row level security;
alter table economics_v2.cycles enable row level security;
alter table economics_v2.cycle_animals enable row level security;
alter table economics_v2.cycle_expenses enable row level security;
alter table economics_v2.cycle_feeds enable row level security;
alter table economics_v2.projections enable row level security;
alter table economics_v2.final_results enable row level security;

create policy economics_v2_private_deny_direct on economics_v2.feature_flags for all to authenticated using (false) with check (false);
create policy economics_v2_private_deny_direct on economics_v2.cycles for all to authenticated using (false) with check (false);
create policy economics_v2_private_deny_direct on economics_v2.cycle_animals for all to authenticated using (false) with check (false);
create policy economics_v2_private_deny_direct on economics_v2.cycle_expenses for all to authenticated using (false) with check (false);
create policy economics_v2_private_deny_direct on economics_v2.cycle_feeds for all to authenticated using (false) with check (false);
create policy economics_v2_private_deny_direct on economics_v2.projections for all to authenticated using (false) with check (false);
create policy economics_v2_private_deny_direct on economics_v2.final_results for all to authenticated using (false) with check (false);

create or replace function economics_v2.read_cycle_economics_impl(p_granja_id uuid)
returns table(cycle_id uuid, granja_id uuid, status text)
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.miembros_granja m
    join economics_v2.feature_flags f on f.granja_id = m.granja_id and f.economics_v2_enabled
    where m.granja_id = p_granja_id and m.user_id = auth.uid()
  ) then raise exception using errcode = '42501', message = 'Economics V2 access denied'; end if;
  return query select c.id, c.granja_id, c.status from economics_v2.cycles c where c.granja_id = p_granja_id;
end;
$$;

create or replace function economics_v2.record_animal_sale_impl(
  p_granja_id uuid, p_animal_ids uuid[], p_fecha_venta date, p_total_amount numeric, p_peso numeric, p_notas text
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid(); v_farm_id uuid; v_type_id uuid; v_reason_id uuid;
  v_baja_id uuid; v_sale_id uuid; v_count integer;
begin
  if v_user_id is null then raise exception using errcode = '42501', message = 'Authentication required'; end if;
  if p_fecha_venta is null or p_total_amount is null or p_total_amount < 0 then
    raise exception using errcode = '22023', message = 'A non-negative dated sale is required';
  end if;
  if p_animal_ids is null or cardinality(p_animal_ids) = 0 or cardinality(p_animal_ids) <> cardinality(array(select distinct unnest(p_animal_ids))) then
    raise exception using errcode = '22023', message = 'Animal IDs must be present and unique';
  end if;
  select a.granja_id, a.tipo_animal_id into v_farm_id, v_type_id
  from public.animales a where a.id = any(p_animal_ids) order by a.id limit 1 for update;
  if v_farm_id is null or v_farm_id <> p_granja_id
    or not exists (select 1 from public.miembros_granja m where m.granja_id = v_farm_id and m.user_id = v_user_id and m.rol in ('owner','editor'))
    or not exists (select 1 from economics_v2.feature_flags f where f.granja_id = v_farm_id and f.economics_v2_enabled) then
    raise exception using errcode = '42501', message = 'Sale access denied';
  end if;
  perform a.id from public.animales a where a.id = any(p_animal_ids) order by a.id for update;
  select count(*) into v_count from public.animales a
  where a.id = any(p_animal_ids) and a.granja_id = v_farm_id and a.tipo_animal_id = v_type_id and a.activo and a.baja_id is null;
  if v_count <> cardinality(p_animal_ids) then raise exception using errcode = '42501', message = 'Animals must be active and belong to one farm and type'; end if;
  select r.id into v_reason_id from public.cat_razon_baja r
  where r.genera_ingreso and r.activo and (r.granja_id is null or r.granja_id = v_farm_id) order by r.id limit 1 for key share;
  if v_reason_id is null then raise exception using errcode = '23503', message = 'A sale baja reason is required'; end if;
  insert into public.bajas_animales (granja_id, tipo_animal_id, razon_baja_id, fecha_baja, cantidad_animales, importe_total, notas, created_by)
  values (v_farm_id, v_type_id, v_reason_id, p_fecha_venta, v_count, p_total_amount, nullif(trim(p_notas), ''), v_user_id) returning id into v_baja_id;
  insert into public.venta_animal (granja_id, tipo_animal_id, animal_id, fecha_venta, precio, peso, created_by, baja_id, record_kind, quantity, total_amount)
  values (v_farm_id, v_type_id, p_animal_ids[1], p_fecha_venta, null, p_peso, v_user_id, v_baja_id, 'individual', v_count, p_total_amount) returning id into v_sale_id;
  update public.animales a set activo = false, baja_id = v_baja_id where a.id = any(p_animal_ids) and a.granja_id = v_farm_id;
  update economics_v2.cycle_animals ca set left_on = p_fecha_venta, sold_by_sale_id = v_sale_id
  where ca.animal_id = any(p_animal_ids) and ca.left_on is null;
  return v_sale_id;
end;
$$;

create or replace function economics_v2.canonicalize_legacy_sales_impl()
returns void language sql security definer set search_path = '' as $$
  insert into public.venta_animal (granja_id, tipo_animal_id, animal_id, fecha_venta, created_by, baja_id, record_kind, quantity, total_amount)
  select b.granja_id, b.tipo_animal_id, null, b.fecha_baja, b.created_by, b.id, 'legacy_batch', b.cantidad_animales, b.importe_total
  from public.bajas_animales b join public.cat_razon_baja r on r.id = b.razon_baja_id
  where r.genera_ingreso and b.importe_total is not null
  on conflict (baja_id) do nothing;
$$;

select economics_v2.canonicalize_legacy_sales_impl();

create or replace function economics_v2.create_cycle_impl() returns void language plpgsql security definer set search_path = '' as $$ begin raise exception 'Unit 3 lifecycle implementation is not part of this migration'; end; $$;
create or replace function economics_v2.assign_cycle_animal_impl() returns void language plpgsql security definer set search_path = '' as $$ begin raise exception 'Unit 3 lifecycle implementation is not part of this migration'; end; $$;
create or replace function economics_v2.record_cycle_expense_impl() returns void language plpgsql security definer set search_path = '' as $$ begin raise exception 'Unit 3 lifecycle implementation is not part of this migration'; end; $$;
create or replace function economics_v2.link_cycle_feed_impl() returns void language plpgsql security definer set search_path = '' as $$ begin raise exception 'Unit 3 lifecycle implementation is not part of this migration'; end; $$;
create or replace function economics_v2.calculate_cycle_impl(
  p_granja_id uuid, p_cycle_id uuid
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_farm_id uuid;
  v_purpose_code text;
  v_starts_on date;
  v_ends_on date;
  v_feed_cost numeric := 0;
  v_direct_cost numeric := 0;
  v_egg_production numeric := 0;
  v_egg_revenue numeric := 0;
  v_animal_sale_revenue numeric := 0;
  v_sold_members numeric := 0;
  v_production_units numeric := 0;
  v_revenue numeric := 0;
  v_total_cost numeric := 0;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  select c.granja_id, p.codigo_calculo, c.starts_on, coalesce(c.ends_on, current_date + 1)
  into v_farm_id, v_purpose_code, v_starts_on, v_ends_on
  from economics_v2.cycles c
  join public.cat_proposito_animal p on p.id = c.proposito_id
  where c.id = p_cycle_id and c.granja_id = p_granja_id;

  if v_farm_id is null
    or not exists (
      select 1
      from public.miembros_granja m
      join economics_v2.feature_flags f
        on f.granja_id = m.granja_id and f.economics_v2_enabled
      where m.granja_id = v_farm_id
        and m.user_id = v_user_id
        and m.rol in ('owner', 'editor')
    ) then
    raise exception using errcode = '42501', message = 'Cycle calculation access denied';
  end if;

  if v_purpose_code not in ('postura', 'carne', 'ornamental') then
    raise exception using errcode = '22023', message = 'Cycle purpose is not supported by calculation version v1';
  end if;

  select coalesce(sum(mc.cantidad * coalesce(food.precio, 0)), 0)
  into v_feed_cost
  from (
    select distinct cf.mezcla_id
    from economics_v2.cycle_feeds cf
    where cf.cycle_id = p_cycle_id
      and cf.granja_id = v_farm_id
      and cf.mezcla_id is not null
      and cf.starts_on < v_ends_on
      and coalesce(cf.ends_on, v_ends_on) > v_starts_on
  ) linked_feeds
  join public.mezcla mix on mix.id = linked_feeds.mezcla_id and mix.granja_id = v_farm_id
  join public.mezcla_comida mc on mc.mezcla_id = mix.id and mc.granja_id = v_farm_id
  join public.comida food on food.id = mc.comida_id and food.granja_id = v_farm_id;

  select coalesce(sum(e.amount), 0)
  into v_direct_cost
  from economics_v2.cycle_expenses e
  where e.cycle_id = p_cycle_id
    and e.granja_id = v_farm_id
    and e.occurred_on >= v_starts_on
    and e.occurred_on < v_ends_on;

  if v_purpose_code = 'postura' then
    select coalesce(sum(h.buenos), 0)
    into v_egg_production
    from public.recoleccion_huevo h
    where h.granja_id = v_farm_id
      and h.fecha_recoleccion >= v_starts_on
      and h.fecha_recoleccion < v_ends_on
      and exists (
        select 1
        from economics_v2.cycle_animals ca
        join public.animales a on a.id = ca.animal_id and a.granja_id = v_farm_id
        where ca.cycle_id = p_cycle_id and a.grupo_id = h.grupo_id
      )
      and exists (
        select 1
        from economics_v2.cycle_feeds cf
        join public.mezcla mix on mix.id = cf.mezcla_id and mix.granja_id = v_farm_id
        where cf.cycle_id = p_cycle_id
          and cf.granja_id = v_farm_id
          and mix.grupo_id = h.grupo_id
          and h.fecha_recoleccion >= greatest(v_starts_on, cf.starts_on, mix.fecha_inicio)
          and h.fecha_recoleccion < least(v_ends_on, coalesce(cf.ends_on, v_ends_on), coalesce(mix.fecha_termino, v_ends_on))
      );

    select coalesce(sum(s.cantidad * s.precio), 0)
    into v_egg_revenue
    from public.venta_huevo s
    where s.granja_id = v_farm_id
      and s.fecha_venta >= v_starts_on
      and s.fecha_venta < v_ends_on
      and exists (
        select 1
        from economics_v2.cycle_animals ca
        join public.animales a on a.id = ca.animal_id and a.granja_id = v_farm_id
        where ca.cycle_id = p_cycle_id and a.grupo_id = s.grupo_id
      )
      and exists (
        select 1
        from economics_v2.cycle_feeds cf
        join public.mezcla mix on mix.id = cf.mezcla_id and mix.granja_id = v_farm_id
        where cf.cycle_id = p_cycle_id
          and cf.granja_id = v_farm_id
          and mix.grupo_id = s.grupo_id
          and s.fecha_venta >= greatest(v_starts_on, cf.starts_on, mix.fecha_inicio)
          and s.fecha_venta < least(v_ends_on, coalesce(cf.ends_on, v_ends_on), coalesce(mix.fecha_termino, v_ends_on))
      );

    v_production_units := v_egg_production;
    v_revenue := v_egg_revenue;
  else
    select coalesce(sum(s.total_amount), 0), count(*)
    into v_animal_sale_revenue, v_sold_members
    from economics_v2.cycle_animals ca
    join public.venta_animal s on s.id = ca.sold_by_sale_id
    where ca.cycle_id = p_cycle_id
      and ca.left_on is not null
      and ca.left_on >= v_starts_on
      and ca.left_on < v_ends_on
      and s.granja_id = v_farm_id
      and s.record_kind = 'individual';

    v_production_units := v_sold_members;
    v_revenue := v_animal_sale_revenue;
  end if;

  v_total_cost := v_feed_cost + v_direct_cost;

  if v_purpose_code = 'postura' then
    return jsonb_build_object(
      'kind', 'actual',
      'calculation_version', 'v1',
      'cycle_id', p_cycle_id,
      'purpose_code', v_purpose_code,
      'production_basis', 'eggs',
      'production_units', v_production_units,
      'egg_production', v_egg_production,
      'egg_revenue', v_egg_revenue,
      'animal_sale_revenue', null::numeric,
      'sold_members', null::numeric,
      'revenue', v_revenue,
      'feed_cost', v_feed_cost,
      'direct_cost', v_direct_cost,
      'total_cost', v_total_cost,
      'margin', v_revenue - v_total_cost,
      'break_even', case when v_production_units > 0 then v_total_cost / v_production_units else null end
    );
  end if;

  return jsonb_build_object(
    'kind', 'actual',
    'calculation_version', 'v1',
    'cycle_id', p_cycle_id,
    'purpose_code', v_purpose_code,
    'production_basis', case when v_purpose_code = 'carne' then 'sold_animals' else 'specimens' end,
    'production_units', v_production_units,
    'egg_production', null::numeric,
    'egg_revenue', null::numeric,
    'animal_sale_revenue', v_animal_sale_revenue,
    'sold_members', v_sold_members,
    'revenue', v_revenue,
    'feed_cost', v_feed_cost,
    'direct_cost', v_direct_cost,
    'total_cost', v_total_cost,
    'margin', v_revenue - v_total_cost,
    'break_even', case when v_production_units > 0 then v_total_cost / v_production_units else null end
  );
end;
$$;

create or replace function economics_v2.project_cycle_impl(
  p_granja_id uuid, p_cycle_id uuid, p_assumptions jsonb
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_actual jsonb;
  v_expected_units numeric;
  v_unit_price numeric;
begin
  if p_assumptions is null or jsonb_typeof(p_assumptions) <> 'object' then
    raise exception using errcode = '22023', message = 'Projection assumptions must be an object';
  end if;

  begin
    v_expected_units := (p_assumptions ->> 'expected_units')::numeric;
    v_unit_price := (p_assumptions ->> 'unit_price')::numeric;
  exception when invalid_text_representation then
    raise exception using errcode = '22023', message = 'Projection assumptions must contain numeric expected_units and unit_price';
  end;

  if v_expected_units is null or v_unit_price is null or v_expected_units < 0 or v_unit_price < 0 then
    raise exception using errcode = '22023', message = 'Projection assumptions must contain non-negative expected_units and unit_price';
  end if;

  v_actual := economics_v2.calculate_cycle_impl(p_granja_id, p_cycle_id);

  return jsonb_build_object(
    'kind', 'projection',
    'calculation_version', 'v1',
    'cycle_id', p_cycle_id,
    'purpose_code', v_actual ->> 'purpose_code',
    'production_basis', v_actual ->> 'production_basis',
    'expected_units', v_expected_units,
    'unit_price', v_unit_price,
    'projected_revenue', v_expected_units * v_unit_price,
    'projected_total_cost', (v_actual ->> 'total_cost')::numeric,
    'projected_margin', (v_expected_units * v_unit_price) - (v_actual ->> 'total_cost')::numeric
  );
end;
$$;

create or replace function economics_v2.finalize_cycle_impl(
  p_granja_id uuid, p_cycle_id uuid
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_user_id uuid := auth.uid();
  v_farm_id uuid;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'Authentication required';
  end if;

  select c.granja_id
  into v_farm_id
  from economics_v2.cycles c
  where c.id = p_cycle_id and c.granja_id = p_granja_id
  for update;

  if v_farm_id is null
    or not exists (
      select 1
      from public.miembros_granja m
      join economics_v2.feature_flags f
        on f.granja_id = m.granja_id and f.economics_v2_enabled
      where m.granja_id = v_farm_id
        and m.user_id = v_user_id
        and m.rol in ('owner', 'editor')
    ) then
    raise exception using errcode = '42501', message = 'Cycle finalization access denied';
  end if;

  perform 1
  from economics_v2.final_results fr
  where fr.cycle_id = p_cycle_id
  for update;

  if found then
    raise exception using errcode = '23505', message = 'Cycle has already been finalized';
  end if;

  v_result := economics_v2.calculate_cycle_impl(p_granja_id, p_cycle_id);

  insert into economics_v2.final_results (
    cycle_id, granja_id, calculation_version, input_snapshot, result_snapshot, created_by
  ) values (
    p_cycle_id,
    v_farm_id,
    'v1',
    jsonb_build_object(
      'calculation_version', 'v1',
      'cycle_id', p_cycle_id,
      'granja_id', v_farm_id,
      'starts_on', (select c.starts_on from economics_v2.cycles c where c.id = p_cycle_id),
      'ends_on', (select c.ends_on from economics_v2.cycles c where c.id = p_cycle_id)
    ),
    v_result,
    v_user_id
  );

  return jsonb_build_object(
    'cycle_id', p_cycle_id,
    'calculation_version', 'v1',
    'result', v_result
  );
end;
$$;

create or replace function economics_v2.prevent_final_result_mutation()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  raise exception using errcode = '23514', message = 'final results are immutable';
end;
$$;

create trigger final_results_immutable
before update or delete on economics_v2.final_results
for each row execute function economics_v2.prevent_final_result_mutation();

create or replace function public.registrar_venta_animal_v2(
  p_granja_id uuid, p_animal_ids uuid[], p_fecha_venta date, p_total_amount numeric, p_peso numeric, p_notas text
) returns uuid language sql security invoker set search_path = '' as $$
  select economics_v2.record_animal_sale_impl(p_granja_id, p_animal_ids, p_fecha_venta, p_total_amount, p_peso, p_notas);
$$;

create or replace function public.calcular_ciclo_v2(
  p_granja_id uuid, p_cycle_id uuid
) returns jsonb language sql security invoker set search_path = '' as $$
  select economics_v2.calculate_cycle_impl(p_granja_id, p_cycle_id);
$$;

create or replace function public.proyectar_ciclo_v2(
  p_granja_id uuid, p_cycle_id uuid, p_assumptions jsonb
) returns jsonb language sql security invoker set search_path = '' as $$
  select economics_v2.project_cycle_impl(p_granja_id, p_cycle_id, p_assumptions);
$$;

create or replace function public.finalizar_ciclo_v2(
  p_granja_id uuid, p_cycle_id uuid
) returns jsonb language sql security invoker set search_path = '' as $$
  select economics_v2.finalize_cycle_impl(p_granja_id, p_cycle_id);
$$;

create or replace view public.economics_v2_cycle_economics with (security_invoker = true) as
select economics.* from public.granjas farm cross join lateral economics_v2.read_cycle_economics_impl(farm.id) economics;

revoke all on all tables in schema economics_v2 from public, anon, authenticated;
revoke all on all functions in schema economics_v2 from public, anon;
revoke execute on function public.registrar_venta_animal_v2(uuid, uuid[], date, numeric, numeric, text) from public, anon;
revoke execute on function public.calcular_ciclo_v2(uuid, uuid) from public, anon;
revoke execute on function public.proyectar_ciclo_v2(uuid, uuid, jsonb) from public, anon;
revoke execute on function public.finalizar_ciclo_v2(uuid, uuid) from public, anon;
grant execute on function public.registrar_venta_animal_v2(uuid, uuid[], date, numeric, numeric, text) to authenticated;
grant execute on function public.calcular_ciclo_v2(uuid, uuid), public.proyectar_ciclo_v2(uuid, uuid, jsonb), public.finalizar_ciclo_v2(uuid, uuid) to authenticated;
grant execute on function economics_v2.read_cycle_economics_impl(uuid), economics_v2.record_animal_sale_impl(uuid, uuid[], date, numeric, numeric, text), economics_v2.create_cycle_impl(), economics_v2.assign_cycle_animal_impl(), economics_v2.record_cycle_expense_impl(), economics_v2.link_cycle_feed_impl(), economics_v2.calculate_cycle_impl(uuid, uuid), economics_v2.project_cycle_impl(uuid, uuid, jsonb), economics_v2.finalize_cycle_impl(uuid, uuid) to authenticated;
grant select on public.economics_v2_cycle_economics to authenticated;
