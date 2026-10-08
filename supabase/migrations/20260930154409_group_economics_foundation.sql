create extension if not exists btree_gist;

create sequence economics_v2.group_economics_event_position_seq;

create table economics_v2.group_occupancy_periods (
  id uuid primary key default gen_random_uuid(),
  granja_id uuid not null references public.granjas(id),
  group_id uuid not null references public.grupos(id),
  purpose_id uuid not null references public.cat_proposito_animal(id),
  starts_on date not null,
  closed_on date,
  start_position bigint not null default nextval('economics_v2.group_economics_event_position_seq'),
  end_position bigint,
  position_span int8range generated always as (
    int8range(start_position, end_position, '[)')
  ) stored,
  check (closed_on is null or closed_on >= starts_on),
  check (end_position is null or end_position > start_position),
  unique (granja_id, id),
  constraint group_occupancy_periods_no_overlap exclude using gist (
    group_id with =, purpose_id with =, position_span with &&
  )
);

create unique index group_occupancy_periods_one_open
  on economics_v2.group_occupancy_periods (group_id, purpose_id)
  where end_position is null;

create table economics_v2.group_occupancy_memberships (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null,
  granja_id uuid not null,
  animal_id uuid not null references public.animales(id),
  start_position bigint not null,
  end_position bigint,
  position_span int8range generated always as (
    int8range(start_position, end_position, '[)')
  ) stored,
  check (end_position is null or end_position > start_position),
  foreign key (granja_id, period_id)
    references economics_v2.group_occupancy_periods (granja_id, id)
    deferrable initially deferred,
  constraint group_occupancy_memberships_no_overlap exclude using gist (
    animal_id with =, position_span with &&
  )
);

create unique index group_occupancy_memberships_one_open
  on economics_v2.group_occupancy_memberships (animal_id)
  where end_position is null;

create table economics_v2.group_occupancy_events (
  id uuid primary key default gen_random_uuid(),
  granja_id uuid not null references public.granjas(id),
  period_id uuid references economics_v2.group_occupancy_periods(id),
  membership_id uuid references economics_v2.group_occupancy_memberships(id),
  animal_id uuid references public.animales(id),
  event_position bigint not null default nextval('economics_v2.group_economics_event_position_seq'),
  effective_on date not null,
  action text not null check (action in (
    'enter', 'transfer', 'purpose_change', 'exit', 'reactivate', 'delete'
  )),
  created_at timestamptz not null default now()
);

create table economics_v2.group_occupancy_operations (
  granja_id uuid not null references public.granjas(id),
  operation_id uuid not null,
  payload_hash text not null check (btrim(payload_hash) <> ''),
  result jsonb not null,
  event_position bigint,
  created_at timestamptz not null default now(),
  primary key (granja_id, operation_id)
);

create table economics_v2.group_meat_snapshots (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null unique references economics_v2.group_occupancy_periods(id),
  granja_id uuid not null references public.granjas(id),
  snapshot_version text not null check (btrim(snapshot_version) <> ''),
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create or replace function economics_v2.assert_group_membership_integrity()
returns trigger
language plpgsql
security definer
set search_path = '' as $$
begin
  if not exists (
    select 1
    from economics_v2.group_occupancy_periods period
    join public.animales animal on animal.id = new.animal_id
    where period.id = new.period_id
      and period.granja_id = new.granja_id
      and animal.granja_id = new.granja_id
      and new.position_span <@ period.position_span
  ) then
    raise exception using errcode = '23514', message = 'Group membership must be farm-matched and contained by its period';
  end if;
  return null;
end;
$$;

create constraint trigger group_occupancy_memberships_integrity
after insert or update on economics_v2.group_occupancy_memberships
deferrable initially deferred
for each row execute function economics_v2.assert_group_membership_integrity();

create or replace function economics_v2.reject_group_economics_history_mutation()
returns trigger
language plpgsql
security definer
set search_path = '' as $$
begin
  raise exception using errcode = '23514', message = 'Group economics history is immutable';
end;
$$;

create trigger group_occupancy_events_immutable
before update or delete on economics_v2.group_occupancy_events
for each row execute function economics_v2.reject_group_economics_history_mutation();

create trigger group_meat_snapshots_immutable
before update or delete on economics_v2.group_meat_snapshots
for each row execute function economics_v2.reject_group_economics_history_mutation();

alter table economics_v2.group_occupancy_periods enable row level security;
alter table economics_v2.group_occupancy_memberships enable row level security;
alter table economics_v2.group_occupancy_events enable row level security;
alter table economics_v2.group_occupancy_operations enable row level security;
alter table economics_v2.group_meat_snapshots enable row level security;
alter table economics_v2.group_occupancy_periods force row level security;
alter table economics_v2.group_occupancy_memberships force row level security;
alter table economics_v2.group_occupancy_events force row level security;
alter table economics_v2.group_occupancy_operations force row level security;
alter table economics_v2.group_meat_snapshots force row level security;

create policy group_occupancy_periods_deny_direct on economics_v2.group_occupancy_periods
for all to authenticated using (false) with check (false);
create policy group_occupancy_memberships_deny_direct on economics_v2.group_occupancy_memberships
for all to authenticated using (false) with check (false);
create policy group_occupancy_events_deny_direct on economics_v2.group_occupancy_events
for all to authenticated using (false) with check (false);
create policy group_occupancy_operations_deny_direct on economics_v2.group_occupancy_operations
for all to authenticated using (false) with check (false);
create policy group_meat_snapshots_deny_direct on economics_v2.group_meat_snapshots
for all to authenticated using (false) with check (false);

create or replace function economics_v2.group_economics_not_activated()
returns jsonb
language plpgsql
security definer
set search_path = '' as $$
begin
  raise exception using errcode = '0A000', message = 'Group economics activation is not enabled';
end;
$$;

create or replace function economics_v2.transition_group_occupancy_impl(
  p_granja_id uuid, p_operation_id uuid, p_action text, p_animal_id uuid,
  p_effective_on date, p_destination_group_id uuid, p_destination_purpose_id uuid,
  p_sale_id uuid
) returns jsonb language sql security definer set search_path = '' as $$
  select economics_v2.group_economics_not_activated();
$$;

create or replace function economics_v2.list_group_economics_impl(
  p_granja_id uuid, p_page_size integer, p_cursor_starts_on date, p_cursor_period_id uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if p_page_size not between 1 and 50
    or (p_cursor_starts_on is null) <> (p_cursor_period_id is null) then
    raise exception using errcode = '22023', message = 'Invalid Group economics page request';
  end if;
  return economics_v2.group_economics_not_activated();
end;
$$;

create or replace function economics_v2.group_economics_parity_impl(
  p_granja_id uuid, p_cycle_period_mapping_id uuid
) returns jsonb language sql security definer set search_path = '' as $$
  select economics_v2.group_economics_not_activated();
$$;

create or replace function economics_v2.resolve_group_economics_quarantine_impl(
  p_granja_id uuid, p_quarantine_id uuid, p_operation_id uuid, p_action text,
  p_period_id uuid, p_evidence text
) returns jsonb language sql security definer set search_path = '' as $$
  select economics_v2.group_economics_not_activated();
$$;

create or replace function public.transition_group_occupancy(
  p_granja_id uuid, p_operation_id uuid, p_action text, p_animal_id uuid,
  p_effective_on date, p_destination_group_id uuid default null,
  p_destination_purpose_id uuid default null, p_sale_id uuid default null
) returns jsonb language sql security invoker set search_path = '' as $$
  select economics_v2.transition_group_occupancy_impl(
    p_granja_id, p_operation_id, p_action, p_animal_id, p_effective_on,
    p_destination_group_id, p_destination_purpose_id, p_sale_id
  );
$$;

create or replace function public.list_group_economics(
  p_granja_id uuid, p_page_size integer default 25,
  p_cursor_starts_on date default null, p_cursor_period_id uuid default null
) returns jsonb language sql security invoker set search_path = '' as $$
  select economics_v2.list_group_economics_impl(
    p_granja_id, p_page_size, p_cursor_starts_on, p_cursor_period_id
  );
$$;

create or replace function public.group_economics_parity(
  p_granja_id uuid, p_cycle_period_mapping_id uuid
) returns jsonb language sql security invoker set search_path = '' as $$
  select economics_v2.group_economics_parity_impl(p_granja_id, p_cycle_period_mapping_id);
$$;

create or replace function public.resolve_group_economics_quarantine(
  p_granja_id uuid, p_quarantine_id uuid, p_operation_id uuid, p_action text,
  p_period_id uuid default null, p_evidence text default null
) returns jsonb language sql security invoker set search_path = '' as $$
  select economics_v2.resolve_group_economics_quarantine_impl(
    p_granja_id, p_quarantine_id, p_operation_id, p_action, p_period_id, p_evidence
  );
$$;

revoke all on table economics_v2.group_occupancy_periods from public, anon, authenticated;
revoke all on table economics_v2.group_occupancy_memberships from public, anon, authenticated;
revoke all on table economics_v2.group_occupancy_events from public, anon, authenticated;
revoke all on table economics_v2.group_occupancy_operations from public, anon, authenticated;
revoke all on table economics_v2.group_meat_snapshots from public, anon, authenticated;
revoke all on sequence economics_v2.group_economics_event_position_seq from public, anon, authenticated;
revoke all on function economics_v2.assert_group_membership_integrity() from public, anon, authenticated;
revoke all on function economics_v2.reject_group_economics_history_mutation() from public, anon, authenticated;
revoke all on function economics_v2.group_economics_not_activated() from public, anon, authenticated;
revoke all on function economics_v2.transition_group_occupancy_impl(uuid, uuid, text, uuid, date, uuid, uuid, uuid) from public, anon;
revoke all on function economics_v2.list_group_economics_impl(uuid, integer, date, uuid) from public, anon;
revoke all on function economics_v2.group_economics_parity_impl(uuid, uuid) from public, anon;
revoke all on function economics_v2.resolve_group_economics_quarantine_impl(uuid, uuid, uuid, text, uuid, text) from public, anon;
revoke all on function public.transition_group_occupancy(uuid, uuid, text, uuid, date, uuid, uuid, uuid) from public, anon;
revoke all on function public.list_group_economics(uuid, integer, date, uuid) from public, anon;
revoke all on function public.group_economics_parity(uuid, uuid) from public, anon;
revoke all on function public.resolve_group_economics_quarantine(uuid, uuid, uuid, text, uuid, text) from public, anon;
grant execute on function economics_v2.transition_group_occupancy_impl(uuid, uuid, text, uuid, date, uuid, uuid, uuid) to authenticated;
grant execute on function economics_v2.list_group_economics_impl(uuid, integer, date, uuid) to authenticated;
grant execute on function economics_v2.group_economics_parity_impl(uuid, uuid) to authenticated;
grant execute on function economics_v2.resolve_group_economics_quarantine_impl(uuid, uuid, uuid, text, uuid, text) to authenticated;
grant execute on function public.transition_group_occupancy(uuid, uuid, text, uuid, date, uuid, uuid, uuid) to authenticated;
grant execute on function public.list_group_economics(uuid, integer, date, uuid) to authenticated;
grant execute on function public.group_economics_parity(uuid, uuid) to authenticated;
grant execute on function public.resolve_group_economics_quarantine(uuid, uuid, uuid, text, uuid, text) to authenticated;
