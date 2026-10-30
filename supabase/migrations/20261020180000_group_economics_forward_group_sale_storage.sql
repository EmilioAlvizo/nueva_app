-- Expand sale storage only; this does not implement a canonical Group sale.
-- Retain both historical branches, including individual quantities above one,
-- nullable/nonfinite historical weights and historical nonfinite amounts.
-- Existing defaults, NOT NULL, other CHECKs, FKs, indexes, RLS and ACLs stay intact.
alter table public.venta_animal
  drop constraint venta_animal_record_kind_check,
  drop constraint venta_animal_individual_or_legacy_batch_check,
  add constraint venta_animal_record_kind_check
    check (record_kind in ('individual', 'legacy_batch', 'group')),
  add constraint venta_animal_individual_or_legacy_batch_check
    check (
      (
        (record_kind = 'legacy_batch' and animal_id is null)
        or (record_kind = 'individual' and animal_id is not null)
        or (
          record_kind = 'group'
          and animal_id is null
          and grupo_id is not null
          and quantity >= 2
          and peso is not null
          and peso > 0
          and peso not in (
            'NaN'::numeric,
            'Infinity'::numeric,
            '-Infinity'::numeric
          )
          and total_amount is not null
          and total_amount >= 0
          and total_amount not in (
            'NaN'::numeric,
            'Infinity'::numeric,
            '-Infinity'::numeric
          )
        )
      ) is true
    );

-- Capture real SQL authority in an invoker before any definer can replace it.
-- JWT claims, caller-controlled GUCs and session_user confer no authority here.
create function economics_v2.guard_direct_group_sale()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $trigger$
declare
  v_sql_role name := current_user;
  v_protected boolean := false;
  v_privileged boolean := false;
begin
  -- Separate operation branches never inspect an unavailable OLD/NEW record.
  if tg_op = 'INSERT' then
    v_protected := new.record_kind = 'group';
  elsif tg_op = 'UPDATE' then
    -- Protect both promotion and demotion, not just rows remaining Group sales.
    v_protected := old.record_kind = 'group' or new.record_kind = 'group';
  elsif tg_op = 'DELETE' then
    v_protected := old.record_kind = 'group';
  else
    raise exception using
      errcode = '22023',
      message = 'Unsupported direct Group sale trigger operation';
  end if;

  if v_protected then
    -- Both effective bypass authority and this operation's table ACL are needed.
    -- pg_roles is publicly readable; restricted pg_authid access is unnecessary.
    v_privileged := coalesce(
      exists (
        select 1
        from pg_catalog.pg_roles as r
        where r.rolname = v_sql_role
          and (r.rolsuper or r.rolbypassrls)
      )
      and pg_catalog.has_table_privilege(v_sql_role, tg_relid, tg_op),
      false
    );

    if not v_privileged then
      raise exception using
        errcode = '42501',
        message = 'Direct Group sale writes are forbidden';
    end if;
  end if;

  -- Historical rows retain their existing operations and RLS behavior.
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$trigger$;

alter function economics_v2.guard_direct_group_sale() owner to postgres;

-- Only the new function's ACL changes. No client EXECUTE or schema ACL is added.
-- PostgreSQL trigger invocation does not require client function EXECUTE.
revoke all on function economics_v2.guard_direct_group_sale()
  from public, anon, authenticated, service_role;

create trigger venta_animal_group_writer_guard
before insert or update or delete on public.venta_animal
for each row execute function economics_v2.guard_direct_group_sale();

-- A future private postgres-owned definer may write through this authority gate.
-- This is not exclusive function provenance, canonical animal binding, a baja,
-- a disposition, a snapshot, a closing integration or composite farm validation.
