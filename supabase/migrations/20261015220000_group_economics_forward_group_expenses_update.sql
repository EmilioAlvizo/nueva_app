-- Existing expense edits only; no occupancy positions or food completion sidecars.
-- Historical receipts precede mutable target admission, including CLOSED/deleted facts.
create function economics_v2.update_group_finance_expense_impl(
  p_granja_id uuid, p_operation_id uuid, p_expense_id uuid, p_period_id uuid,
  p_expected_updated_at timestamptz, p_occurred_on date,
  p_amount numeric, p_category text, p_note text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  v_actor uuid;
  v_hash text;
  v_stored economics_v2.group_occupancy_operations%rowtype;
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_group public.grupos%rowtype;
  v_purpose public.cat_proposito_animal%rowtype;
  v_old economics_v2.group_period_expenses%rowtype;
  v_expense economics_v2.group_period_expenses%rowtype;
  v_group_id uuid;
  v_version timestamptz;
  v_receipt_version timestamptz;
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
  if p_occurred_on is null or not isfinite(p_occurred_on) or p_occurred_on>current_date then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','occurred_on',p_period_id);
  end if;
  if p_amount is null or p_amount<=0
    or p_amount in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','amount',p_expense_id);
  end if;
  if p_category is null or btrim(p_category)='' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','category',p_expense_id);
  end if;
  -- Text stays opaque; the expected instant uses UTC independent of session TimeZone.
  -- The existing canonicalizer normalizes numeric scale, never category/note text.
  v_hash := encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-expense-update.v1',
    'granja_id',p_granja_id,'actor_id',v_actor,'operation_id',p_operation_id,
    'request',jsonb_build_object('action','expense_update','expense_id',p_expense_id,'period_id',p_period_id,
      'expected_updated_at',p_expected_updated_at at time zone 'UTC','occurred_on',p_occurred_on,
      'amount',p_amount,'category',p_category,'note',p_note)))::text,'UTF8')),'hex');
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  perform economics_v2.assert_group_writer_actor(p_granja_id);
  select o.* into v_stored from economics_v2.group_occupancy_operations o
  where o.granja_id=p_granja_id and o.operation_id=p_operation_id for update;
  if found then
    if v_stored.payload_hash is distinct from v_hash then
      perform economics_v2.raise_group_writer_error('22023','operation_payload_conflict','operation_id',p_operation_id);
    end if;
    if jsonb_typeof(v_stored.result) is distinct from 'object' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    if v_stored.event_position is not null or not v_stored.result ?& array[
        'contract_version','operation_id','expense_id','period_id','updated_at','replayed']
      or (select count(*) from jsonb_object_keys(v_stored.result))<>6
      or v_stored.result->'contract_version' is distinct from to_jsonb('group-economics.forward.v3'::text)
      or v_stored.result->'operation_id' is distinct from to_jsonb(p_operation_id)
      or v_stored.result->'expense_id' is distinct from to_jsonb(p_expense_id)
      or v_stored.result->'period_id' is distinct from to_jsonb(p_period_id)
      or v_stored.result->'replayed' is distinct from 'false'::jsonb
      or jsonb_typeof(v_stored.result->'updated_at') is distinct from 'string' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    if (v_stored.result->>'updated_at') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    -- Only receipt conversion is caught; business/ledger failures must roll back.
    begin
      v_receipt_version := (v_stored.result->>'updated_at')::timestamptz;
    exception when data_exception then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end;
    if v_receipt_version is null or not isfinite(v_receipt_version) then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    return v_stored.result||jsonb_build_object('replayed',true);
  end if;

  -- Fresh admission: farm advisory -> singleton Group -> period -> existing expense.
  if current_setting('transaction_isolation')<>'read committed' then
    perform economics_v2.raise_group_writer_error('40001','stale_write','period_id',p_period_id);
  end if;
  select p.* into v_period from economics_v2.group_occupancy_periods p
  where p.id=p_period_id and p.granja_id=p_granja_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id);
  end if;
  v_group_id := v_period.group_id;
  select g.* into v_group from public.grupos g
  where g.id=v_group_id and g.granja_id=p_granja_id order by g.id for update;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_group_id);
  end if;
  select p.* into v_period from economics_v2.group_occupancy_periods p
  where p.id=p_period_id and p.granja_id=p_granja_id for update;
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
  -- Explicit period identity, not headcount or unique-open-purpose admission.
  if p_occurred_on<v_period.starts_on
    or exists(select 1 from economics_v2.group_occupancy_events e
      where e.granja_id=p_granja_id and e.period_id=p_period_id and e.effective_on>p_occurred_on)
    or exists(select 1 from economics_v2.group_occupancy_periods p
      where p.granja_id=p_granja_id and p.group_id=v_group_id
        and p.purpose_id=v_period.purpose_id and p.starts_on>p_occurred_on) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','occurred_on',p_period_id);
  end if;

  -- No sleep: every accepted edit advances its server-owned token, even within one tick.
  begin
    v_version := greatest(clock_timestamp(),v_old.updated_at+interval '1 microsecond');
  exception when datetime_field_overflow then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','expense_id',p_expense_id);
  end;
  if v_version is null or not isfinite(v_version) or v_version<=v_old.updated_at then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','expense_id',p_expense_id);
  end if;
  update economics_v2.group_period_expenses e
  set occurred_on=p_occurred_on,amount=p_amount,category=p_category,note=p_note,updated_at=v_version
  where e.id=p_expense_id and e.granja_id=p_granja_id and e.period_id=p_period_id
    and e.updated_at=p_expected_updated_at
  returning e.* into v_expense;
  -- Validate actual storage, including BEFORE-trigger refusal or field rewriting.
  if not found or v_expense.id is distinct from v_old.id
    or v_expense.granja_id is distinct from v_old.granja_id or v_expense.period_id is distinct from v_old.period_id
    or v_expense.created_by is distinct from v_old.created_by or v_expense.created_at is distinct from v_old.created_at
    or v_expense.occurred_on is distinct from p_occurred_on or v_expense.amount is distinct from p_amount
    or v_expense.category is distinct from p_category or v_expense.note is distinct from p_note
    or v_expense.updated_at is distinct from v_version or not isfinite(v_expense.updated_at)
    or v_expense.updated_at<=v_old.updated_at then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','expense_id',p_expense_id);
  end if;
  v_result := jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'expense_id',v_expense.id,'period_id',v_expense.period_id,'updated_at',v_expense.updated_at,'replayed',false);
  -- Completion LAST. A late ledger fault rolls back both the real edit and receipt.
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

create function public.update_group_finance_expense_v1(
  p_granja_id uuid, p_operation_id uuid, p_expense_id uuid, p_period_id uuid,
  p_expected_updated_at timestamptz, p_occurred_on date,
  p_amount numeric, p_category text, p_note text
) returns jsonb language plpgsql volatile security invoker set search_path='' as $$
begin
  return economics_v2.update_group_finance_expense_impl(
    p_granja_id=>p_granja_id, p_operation_id=>p_operation_id, p_expense_id=>p_expense_id,
    p_period_id=>p_period_id, p_expected_updated_at=>p_expected_updated_at,
    p_occurred_on=>p_occurred_on, p_amount=>p_amount, p_category=>p_category, p_note=>p_note);
end;
$$;

alter function economics_v2.update_group_finance_expense_impl(uuid,uuid,uuid,uuid,timestamptz,date,numeric,text,text) owner to postgres;
alter function public.update_group_finance_expense_v1(uuid,uuid,uuid,uuid,timestamptz,date,numeric,text,text) owner to postgres;
revoke all on function economics_v2.update_group_finance_expense_impl(uuid,uuid,uuid,uuid,timestamptz,date,numeric,text,text)
from public,anon,authenticated,service_role;
revoke all on function public.update_group_finance_expense_v1(uuid,uuid,uuid,uuid,timestamptz,date,numeric,text,text)
from public,anon,authenticated,service_role;
grant execute on function economics_v2.update_group_finance_expense_impl(uuid,uuid,uuid,uuid,timestamptz,date,numeric,text,text) to authenticated;
grant execute on function public.update_group_finance_expense_v1(uuid,uuid,uuid,uuid,timestamptz,date,numeric,text,text) to authenticated;
