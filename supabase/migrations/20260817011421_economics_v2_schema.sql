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
create or replace function economics_v2.calculate_cycle_impl() returns void language plpgsql security definer set search_path = '' as $$ begin raise exception 'Unit 3 calculation implementation is not part of this migration'; end; $$;
create or replace function economics_v2.project_cycle_impl() returns void language plpgsql security definer set search_path = '' as $$ begin raise exception 'Unit 3 projection implementation is not part of this migration'; end; $$;
create or replace function economics_v2.finalize_cycle_impl() returns void language plpgsql security definer set search_path = '' as $$ begin raise exception 'Unit 3 finalization implementation is not part of this migration'; end; $$;

create or replace function public.registrar_venta_animal_v2(
  p_granja_id uuid, p_animal_ids uuid[], p_fecha_venta date, p_total_amount numeric, p_peso numeric, p_notas text
) returns uuid language sql security invoker set search_path = '' as $$
  select economics_v2.record_animal_sale_impl(p_granja_id, p_animal_ids, p_fecha_venta, p_total_amount, p_peso, p_notas);
$$;

create or replace view public.economics_v2_cycle_economics with (security_invoker = true) as
select economics.* from public.granjas farm cross join lateral economics_v2.read_cycle_economics_impl(farm.id) economics;

revoke all on all tables in schema economics_v2 from public, anon, authenticated;
revoke all on all functions in schema economics_v2 from public, anon;
revoke execute on function public.registrar_venta_animal_v2(uuid, uuid[], date, numeric, numeric, text) from public, anon;
grant execute on function public.registrar_venta_animal_v2(uuid, uuid[], date, numeric, numeric, text) to authenticated;
grant execute on function economics_v2.read_cycle_economics_impl(uuid), economics_v2.record_animal_sale_impl(uuid, uuid[], date, numeric, numeric, text), economics_v2.create_cycle_impl(), economics_v2.assign_cycle_animal_impl(), economics_v2.record_cycle_expense_impl(), economics_v2.link_cycle_feed_impl(), economics_v2.calculate_cycle_impl(), economics_v2.project_cycle_impl(), economics_v2.finalize_cycle_impl() to authenticated;
grant select on public.economics_v2_cycle_economics to authenticated;
