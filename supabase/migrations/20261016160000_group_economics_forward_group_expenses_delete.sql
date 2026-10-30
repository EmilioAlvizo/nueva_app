-- Existing expense deletion only; no occupancy positions or food completion sidecars.
-- Historical receipts precede mutable target admission, including CLOSED/re-created facts.
create function economics_v2.delete_group_finance_expense_impl(
  p_granja_id uuid, p_operation_id uuid, p_expense_id uuid, p_period_id uuid,
  p_expected_updated_at timestamptz
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  v_actor uuid;
  v_hash text;
  v_stored economics_v2.group_occupancy_operations%rowtype;
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_group public.grupos%rowtype;
  v_purpose public.cat_proposito_animal%rowtype;
  v_old economics_v2.group_period_expenses%rowtype;
  v_deleted economics_v2.group_period_expenses%rowtype;
  v_group_id uuid;
  v_result jsonb;
begin
  v_actor := economics_v2.assert_group_writer_actor(p_granja_id);
  if p_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','operation_id',null);
  end if;
  if p_expense_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','expense_id',null);
  end if;
  if p_period_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','period_id',null);
  end if;
  if p_expected_updated_at is null or not isfinite(p_expected_updated_at) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','expected_updated_at',p_expense_id);
  end if;
  -- Match UPDATE's UTC instant convention; the shared canonicalizer stays unchanged.
  v_hash := encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-expense-delete.v1',
    'granja_id',p_granja_id,'actor_id',v_actor,'operation_id',p_operation_id,
    'request',jsonb_build_object('action','expense_delete','expense_id',p_expense_id,'period_id',p_period_id,
      'expected_updated_at',p_expected_updated_at at time zone 'UTC')))::text,'UTF8')),'hex');
  v_result := jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'expense_id',p_expense_id,'period_id',p_period_id,'deleted',true,'replayed',false);
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  select o.* into v_stored from economics_v2.group_occupancy_operations o
  where o.granja_id=p_granja_id and o.operation_id=p_operation_id for update;
  if found then
    if v_stored.payload_hash is distinct from v_hash then
      perform economics_v2.raise_group_writer_error('22023','operation_payload_conflict','operation_id',p_operation_id);
    end if;
    -- Whole-object equality requires exactly six keys, their types, and original IDs.
    if v_stored.event_position is not null or v_stored.result is distinct from v_result then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    return v_stored.result||jsonb_build_object('replayed',true);
  end if;

  -- Fresh admission: farm advisory -> singleton Group -> period -> existing expense.
  if current_setting('transaction_isolation')<>'read committed' then
    perform economics_v2.raise_group_writer_error('40001','stale_write','period_id',p_period_id);
  end if;
  select op.* into v_period from economics_v2.group_occupancy_periods op
  where op.id=p_period_id and op.granja_id=p_granja_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id);
  end if;
  v_group_id := v_period.group_id;
  select g.* into v_group from public.grupos g
  where g.id=v_group_id and g.granja_id=p_granja_id order by g.id for update;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_group_id);
  end if;
  select op.* into v_period from economics_v2.group_occupancy_periods op
  where op.id=p_period_id and op.granja_id=p_granja_id for update;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id);
  end if;
  if v_period.group_id is distinct from v_group_id then
    perform economics_v2.raise_group_writer_error('40001','stale_write','period_id',p_period_id);
  end if;
  if v_period.closed_on is not null or v_period.end_position is not null then
    perform economics_v2.raise_group_writer_error('23514','closed_period_immutable','period_id',p_period_id);
  end if;
  if v_group.tipo_animal_id is not null then
    perform t.id from public.tipo_animal t
    where t.id=v_group.tipo_animal_id and t.granja_id=p_granja_id for share;
    if not found then
      perform economics_v2.raise_group_writer_error('42501','forbidden','tipo_animal_id',v_group.tipo_animal_id);
    end if;
  end if;
  select c.* into v_purpose from public.cat_proposito_animal c
  where c.id=v_period.purpose_id and c.granja_id=p_granja_id for share;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','purpose_id',v_period.purpose_id);
  end if;
  if v_purpose.codigo_calculo is distinct from 'carne' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','purpose_id',v_period.purpose_id);
  end if;
  select e.* into v_old from economics_v2.group_period_expenses e
  where e.id=p_expense_id and e.granja_id=p_granja_id and e.period_id=p_period_id for update;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','expense_id',p_expense_id);
  end if;
  if v_old.updated_at is null or not isfinite(v_old.updated_at)
    or v_old.created_at is null or not isfinite(v_old.created_at) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','expense_id',p_expense_id);
  end if;
  if v_old.updated_at is distinct from p_expected_updated_at then
    perform economics_v2.raise_group_writer_error('40001','stale_write','expected_updated_at',p_expense_id);
  end if;
  if v_period.starts_on is null or not isfinite(v_period.starts_on) or v_period.starts_on>current_date then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',p_period_id);
  end if;

  -- There is no delete date or new backdating rule: the explicit target must be OPEN.
  delete from economics_v2.group_period_expenses e
  where e.id=p_expense_id and e.granja_id=p_granja_id and e.period_id=p_period_id
    and e.updated_at=p_expected_updated_at
  returning e.* into v_deleted;
  -- Check the entire deleted original, including silent BEFORE-trigger suppression.
  if not found or v_deleted is distinct from v_old then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','expense_id',p_expense_id);
  end if;
  -- AFTER triggers must not leave a replacement row with the same expense identity.
  if exists(select 1 from economics_v2.group_period_expenses e where e.id=p_expense_id) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','expense_id',p_expense_id);
  end if;
  -- Completion LAST. No exception handler: a late fault restores deletion and receipt.
  insert into economics_v2.group_occupancy_operations(granja_id,operation_id,payload_hash,result,event_position)
  values(p_granja_id,p_operation_id,v_hash,v_result,null) returning * into v_stored;
  if not found or v_stored.granja_id is distinct from p_granja_id
    or v_stored.operation_id is distinct from p_operation_id or v_stored.payload_hash is distinct from v_hash
    or v_stored.result is distinct from v_result or v_stored.event_position is not null then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
  end if;
  return v_result;
end;
$$;

create function public.delete_group_finance_expense_v1(
  p_granja_id uuid, p_operation_id uuid, p_expense_id uuid, p_period_id uuid,
  p_expected_updated_at timestamptz
) returns jsonb language plpgsql volatile security invoker set search_path='' as $$
begin
  return economics_v2.delete_group_finance_expense_impl(
    p_granja_id=>p_granja_id, p_operation_id=>p_operation_id, p_expense_id=>p_expense_id,
    p_period_id=>p_period_id, p_expected_updated_at=>p_expected_updated_at);
end;
$$;

alter function economics_v2.delete_group_finance_expense_impl(uuid,uuid,uuid,uuid,timestamptz) owner to postgres;
alter function public.delete_group_finance_expense_v1(uuid,uuid,uuid,uuid,timestamptz) owner to postgres;
revoke all on function economics_v2.delete_group_finance_expense_impl(uuid,uuid,uuid,uuid,timestamptz)
from public,anon,authenticated,service_role;
revoke all on function public.delete_group_finance_expense_v1(uuid,uuid,uuid,uuid,timestamptz)
from public,anon,authenticated,service_role;
grant execute on function economics_v2.delete_group_finance_expense_impl(uuid,uuid,uuid,uuid,timestamptz) to authenticated;
grant execute on function public.delete_group_finance_expense_v1(uuid,uuid,uuid,uuid,timestamptz) to authenticated;
