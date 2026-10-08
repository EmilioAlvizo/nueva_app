create unique index if not exists grupos_granja_id_id_key on public.grupos (granja_id, id);
create unique index if not exists cat_proposito_animal_granja_id_id_key on public.cat_proposito_animal (granja_id, id);
create unique index if not exists animales_granja_id_id_key on public.animales (granja_id, id);
create unique index if not exists mezcla_granja_id_id_key on public.mezcla (granja_id, id);
create unique index if not exists venta_animal_granja_id_id_key on public.venta_animal (granja_id, id);
create unique index if not exists group_occupancy_events_granja_id_id_key
  on economics_v2.group_occupancy_events (granja_id, id);

alter table economics_v2.group_occupancy_periods
  add constraint group_occupancy_periods_granja_group_fkey
    foreign key (granja_id, group_id) references public.grupos (granja_id, id),
  add constraint group_occupancy_periods_granja_purpose_fkey
    foreign key (granja_id, purpose_id) references public.cat_proposito_animal (granja_id, id);

alter table economics_v2.group_occupancy_events
  add column operation_id uuid,
  add column sale_id uuid,
  add column basis_transfer_id uuid,
  add column reason text,
  add constraint group_occupancy_events_sale_fkey
    foreign key (sale_id) references public.venta_animal (id),
  add constraint group_occupancy_events_granja_sale_fkey
    foreign key (granja_id, sale_id) references public.venta_animal (granja_id, id),
  add constraint group_occupancy_events_granja_operation_fkey
    foreign key (granja_id, operation_id)
    references economics_v2.group_occupancy_operations (granja_id, operation_id);

create table economics_v2.group_period_feed_allocations (
  id uuid primary key default gen_random_uuid(),
  granja_id uuid not null,
  period_id uuid not null,
  mixture_id uuid not null unique,
  occurred_on date not null check (occurred_on <= current_date),
  source_updated_at timestamptz not null,
  component_count integer not null check (component_count > 0),
  quantity_kg numeric not null check (quantity_kg > 0 and quantity_kg not in ('NaN', 'Infinity', '-Infinity')),
  total_cost numeric not null check (total_cost >= 0 and total_cost not in ('NaN', 'Infinity', '-Infinity')),
  source_digest text not null check (btrim(source_digest) <> ''),
  finalized_at timestamptz,
  updated_at timestamptz not null default now(),
  foreign key (granja_id, period_id) references economics_v2.group_occupancy_periods (granja_id, id),
  foreign key (granja_id, mixture_id) references public.mezcla (granja_id, id)
);

create table economics_v2.group_period_expenses (
  id uuid primary key default gen_random_uuid(),
  granja_id uuid not null,
  period_id uuid not null,
  occurred_on date not null check (occurred_on <= current_date),
  amount numeric not null check (amount > 0 and amount not in ('NaN', 'Infinity', '-Infinity')),
  category text not null check (btrim(category) <> ''),
  note text,
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (granja_id, period_id) references economics_v2.group_occupancy_periods (granja_id, id)
);

create table economics_v2.group_period_sale_bindings (
  sale_id uuid primary key references public.venta_animal (id),
  granja_id uuid not null,
  period_id uuid not null,
  record_kind text not null check (record_kind in ('individual', 'group')),
  quantity integer not null check (quantity > 0),
  saleable_kg numeric not null check (saleable_kg > 0 and saleable_kg not in ('NaN', 'Infinity', '-Infinity')),
  total_amount numeric not null check (total_amount >= 0 and total_amount not in ('NaN', 'Infinity', '-Infinity')),
  source_digest text not null check (btrim(source_digest) <> ''),
  created_at timestamptz not null default now(),
  foreign key (granja_id, period_id) references economics_v2.group_occupancy_periods (granja_id, id),
  foreign key (granja_id, sale_id) references public.venta_animal (granja_id, id)
);

create table economics_v2.group_animal_acquisition_basis (
  granja_id uuid not null,
  animal_id uuid not null,
  initial_basis numeric not null check (initial_basis >= 0 and initial_basis not in ('NaN', 'Infinity', '-Infinity')),
  remaining_basis numeric not null check (remaining_basis >= 0 and remaining_basis not in ('NaN', 'Infinity', '-Infinity')),
  status text not null check (status in ('active', 'disposed')),
  current_account_kind text not null check (current_account_kind in ('period', 'holding', 'disposed')),
  current_period_id uuid,
  source_cost numeric not null check (source_cost >= 0 and source_cost not in ('NaN', 'Infinity', '-Infinity')),
  captured_at timestamptz not null default now(),
  disposed_event_id uuid,
  version bigint not null default 0 check (version >= 0),
  primary key (granja_id, animal_id),
  check ((current_account_kind = 'period') = (current_period_id is not null)),
  foreign key (granja_id, animal_id) references public.animales (granja_id, id),
  foreign key (granja_id, current_period_id) references economics_v2.group_occupancy_periods (granja_id, id),
  foreign key (granja_id, disposed_event_id) references economics_v2.group_occupancy_events (granja_id, id)
);

create table economics_v2.group_acquisition_basis_entries (
  id uuid primary key default gen_random_uuid(),
  granja_id uuid not null,
  animal_id uuid not null,
  operation_id uuid not null,
  event_id uuid,
  entry_pair_id uuid,
  entry_kind text not null check (entry_kind in ('initial', 'transfer_in', 'transfer_out', 'purpose_in', 'purpose_out')),
  account_kind text not null check (account_kind in ('period', 'holding')),
  period_id uuid,
  signed_amount numeric not null check (signed_amount not in ('NaN', 'Infinity', '-Infinity')),
  created_at timestamptz not null default now(),
  check ((account_kind = 'period') = (period_id is not null)),
  foreign key (granja_id, animal_id)
    references economics_v2.group_animal_acquisition_basis (granja_id, animal_id),
  foreign key (granja_id, operation_id)
    references economics_v2.group_occupancy_operations (granja_id, operation_id),
  foreign key (granja_id, event_id) references economics_v2.group_occupancy_events (granja_id, id),
  foreign key (granja_id, period_id) references economics_v2.group_occupancy_periods (granja_id, id)
);

create index group_period_feed_allocations_period_idx on economics_v2.group_period_feed_allocations (granja_id, period_id);
create index group_period_feed_allocations_mixture_idx on economics_v2.group_period_feed_allocations (granja_id, mixture_id);
create index group_period_expenses_period_idx on economics_v2.group_period_expenses (granja_id, period_id);
create index group_period_sale_bindings_period_idx on economics_v2.group_period_sale_bindings (granja_id, period_id);
create index group_animal_acquisition_basis_period_idx on economics_v2.group_animal_acquisition_basis (granja_id, current_period_id);
create index group_acquisition_basis_entries_animal_idx on economics_v2.group_acquisition_basis_entries (granja_id, animal_id);
create index group_acquisition_basis_entries_event_idx on economics_v2.group_acquisition_basis_entries (granja_id, event_id);
create index group_acquisition_basis_entries_period_idx on economics_v2.group_acquisition_basis_entries (granja_id, period_id);

create or replace function economics_v2.assert_group_period_membership_containment()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if exists (
    select 1 from economics_v2.group_occupancy_memberships membership
    where membership.period_id = new.id
      and (membership.granja_id <> new.granja_id or not (membership.position_span <@ new.position_span))
  ) then
    raise exception using errcode = '23514', message = 'Group period must contain every membership';
  end if;
  return null;
end;
$$;
create constraint trigger group_occupancy_periods_membership_containment
after update of granja_id, start_position, end_position on economics_v2.group_occupancy_periods
deferrable initially deferred for each row
execute function economics_v2.assert_group_period_membership_containment();

do $security$
declare table_name text;
begin
  foreach table_name in array array[
    'group_period_feed_allocations', 'group_period_expenses', 'group_period_sale_bindings',
    'group_animal_acquisition_basis', 'group_acquisition_basis_entries'
  ] loop
    execute format('alter table economics_v2.%I enable row level security', table_name);
    execute format('alter table economics_v2.%I force row level security', table_name);
    execute format('create policy %I on economics_v2.%I for all to anon, authenticated using (false) with check (false)', table_name || '_deny_direct', table_name);
    execute format('revoke all on table economics_v2.%I from public, anon, authenticated', table_name);
  end loop;
end;
$security$;

revoke all on sequence economics_v2.group_economics_event_position_seq from public, anon, authenticated;
revoke all on function economics_v2.assert_group_period_membership_containment() from public, anon, authenticated;
revoke all on function public.group_economics_parity(uuid, uuid) from public, anon, authenticated;
revoke all on function public.resolve_group_economics_quarantine(uuid, uuid, uuid, text, uuid, text) from public, anon, authenticated;
revoke all on function economics_v2.group_economics_parity_impl(uuid, uuid) from public, anon, authenticated;
revoke all on function economics_v2.resolve_group_economics_quarantine_impl(uuid, uuid, uuid, text, uuid, text) from public, anon, authenticated;
