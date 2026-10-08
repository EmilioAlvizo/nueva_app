create or replace function economics_v2.assert_group_membership_integrity()
returns trigger
language plpgsql
security definer
set search_path = '' as $$
declare membership economics_v2.group_occupancy_memberships%rowtype;
begin
  select * into membership
  from economics_v2.group_occupancy_memberships
  where id = new.id;
  if not found then return null; end if;
  if not exists (
    select 1
    from economics_v2.group_occupancy_periods period
    join public.animales animal on animal.id = membership.animal_id
    where period.id = membership.period_id
      and period.granja_id = membership.granja_id
      and animal.granja_id = membership.granja_id
      and membership.position_span <@ period.position_span
  ) then
    raise exception using errcode = '23514', message = 'Group membership must be farm-matched and contained by its period';
  end if;
  return null;
end;
$$;

create or replace function economics_v2.assert_group_period_membership_containment()
returns trigger
language plpgsql
security definer
set search_path = '' as $$
declare period economics_v2.group_occupancy_periods%rowtype;
begin
  select * into period
  from economics_v2.group_occupancy_periods
  where id = new.id;
  if not found then return null; end if;
  if exists (
    select 1 from economics_v2.group_occupancy_memberships membership
    where membership.period_id = period.id
      and (membership.granja_id <> period.granja_id or not (membership.position_span <@ period.position_span))
  ) then
    raise exception using errcode = '23514', message = 'Group period must contain every membership';
  end if;
  return null;
end;
$$;

revoke all on function economics_v2.assert_group_membership_integrity() from public, anon, authenticated;
revoke all on function economics_v2.assert_group_period_membership_containment() from public, anon, authenticated;
