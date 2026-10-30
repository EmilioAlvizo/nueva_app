-- Authorized expense creation only; no occupancy positions or food completion sidecars.
-- Historical receipts precede mutable target admission and remain valid without the fact.
create function economics_v2.create_group_finance_expense_impl(
  p_granja_id uuid, p_operation_id uuid, p_period_id uuid, p_occurred_on date,
  p_amount numeric, p_category text, p_note text
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
  v_actor uuid;
  v_hash text;
  v_stored economics_v2.group_occupancy_operations%rowtype;
  v_period economics_v2.group_occupancy_periods%rowtype;
  v_group public.grupos%rowtype;
  v_purpose public.cat_proposito_animal%rowtype;
  v_expense economics_v2.group_period_expenses%rowtype;
  v_group_id uuid;
  v_expense_id uuid;
  v_version timestamptz;
  v_receipt_version timestamptz;
  v_result jsonb;
begin
  v_actor := economics_v2.assert_group_writer_actor(p_granja_id);
  if p_operation_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','operation_id',null);
  end if;
  if p_period_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','period_id',null);
  end if;
  if p_occurred_on is null or not isfinite(p_occurred_on) or p_occurred_on>current_date then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','occurred_on',p_period_id);
  end if;
  if p_amount is null or p_amount<=0
    or p_amount in ('NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','amount',p_period_id);
  end if;
  if p_category is null or btrim(p_category)='' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','category',p_period_id);
  end if;
  -- Text is opaque: only numeric scale is canonicalized by the existing helper.
  v_hash := encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','operation_domain','group-expense-create.v1',
    'granja_id',p_granja_id,'actor_id',v_actor,'operation_id',p_operation_id,
    'request',jsonb_build_object('action','expense_create','period_id',p_period_id,
      'occurred_on',p_occurred_on,'amount',p_amount,'category',p_category,'note',p_note)))::text,'UTF8')),'hex');
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
      or v_stored.result->'period_id' is distinct from to_jsonb(p_period_id)
      or v_stored.result->'replayed' is distinct from 'false'::jsonb
      or jsonb_typeof(v_stored.result->'expense_id') is distinct from 'string'
      or jsonb_typeof(v_stored.result->'updated_at') is distinct from 'string' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    if (v_stored.result->>'expense_id') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      or (v_stored.result->>'updated_at') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    -- Convert only inside this narrow block; malformed stored data is a typed invariant.
    begin
      v_expense_id := (v_stored.result->>'expense_id')::uuid;
      v_receipt_version := (v_stored.result->>'updated_at')::timestamptz;
    exception when data_exception then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end;
    if v_receipt_version is null or not isfinite(v_receipt_version) then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    return v_stored.result||jsonb_build_object('replayed',true);
  end if;

  -- Fresh admission requires current history; replay above has no mutable target reads.
  if current_setting('transaction_isolation')<>'read committed' then
    perform economics_v2.raise_group_writer_error('40001','stale_write','period_id',p_period_id);
  end if;
  select p.* into v_period from economics_v2.group_occupancy_periods p
  where p.id=p_period_id and p.granja_id=p_granja_id;
  if not found then
    perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',p_period_id);
  end if;
  v_group_id := v_period.group_id;
  -- There is one target Group, so its UUID-ordered lock set is a singleton.
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
  if v_period.starts_on is null or not isfinite(v_period.starts_on) or v_period.starts_on>current_date then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','period_id',p_period_id);
  end if;
  -- An explicit period is the discriminator; no unique-open-purpose or headcount gate.
  if p_occurred_on<v_period.starts_on
    or exists(select 1 from economics_v2.group_occupancy_events e
      where e.granja_id=p_granja_id and e.period_id=p_period_id and e.effective_on>p_occurred_on)
    or exists(select 1 from economics_v2.group_occupancy_periods p
      where p.granja_id=p_granja_id and p.group_id=v_group_id
        and p.purpose_id=v_period.purpose_id and p.starts_on>p_occurred_on) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','occurred_on',p_period_id);
  end if;

  v_expense_id := gen_random_uuid();
  v_version := clock_timestamp();
  insert into economics_v2.group_period_expenses(
    id,granja_id,period_id,occurred_on,amount,category,note,created_by,created_at,updated_at)
  values(v_expense_id,p_granja_id,p_period_id,p_occurred_on,p_amount,p_category,p_note,v_actor,v_version,v_version)
  returning * into v_expense;
  -- Check actual storage, including any typmod coercion or silent BEFORE-trigger refusal.
  if not found or v_expense.id is distinct from v_expense_id
    or v_expense.granja_id is distinct from p_granja_id or v_expense.period_id is distinct from p_period_id
    or v_expense.occurred_on is distinct from p_occurred_on or v_expense.amount is distinct from p_amount
    or v_expense.category is distinct from p_category or v_expense.note is distinct from p_note
    or v_expense.created_by is distinct from v_actor
    or v_expense.created_at is distinct from v_version or v_expense.updated_at is distinct from v_version
    or not isfinite(v_expense.created_at) or not isfinite(v_expense.updated_at) then
    perform economics_v2.raise_group_writer_error('23514','invariant_violation','expense_id',v_expense_id);
  end if;
  v_result := jsonb_build_object('contract_version','group-economics.forward.v3','operation_id',p_operation_id,
    'expense_id',v_expense.id,'period_id',v_expense.period_id,'updated_at',v_expense.updated_at,'replayed',false);
  -- Completion LAST. Errors propagate; expense and receipt share the caller's transaction.
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

create function public.create_group_finance_expense_v1(
  p_granja_id uuid, p_operation_id uuid, p_period_id uuid, p_occurred_on date,
  p_amount numeric, p_category text, p_note text
) returns jsonb language plpgsql volatile security invoker set search_path='' as $$
begin
  return economics_v2.create_group_finance_expense_impl(
    p_granja_id=>p_granja_id, p_operation_id=>p_operation_id, p_period_id=>p_period_id,
    p_occurred_on=>p_occurred_on, p_amount=>p_amount, p_category=>p_category, p_note=>p_note);
end;
$$;

alter function economics_v2.create_group_finance_expense_impl(uuid,uuid,uuid,date,numeric,text,text) owner to postgres;
alter function public.create_group_finance_expense_v1(uuid,uuid,uuid,date,numeric,text,text) owner to postgres;
revoke all on function economics_v2.create_group_finance_expense_impl(uuid,uuid,uuid,date,numeric,text,text)
from public,anon,authenticated,service_role;
revoke all on function public.create_group_finance_expense_v1(uuid,uuid,uuid,date,numeric,text,text)
from public,anon,authenticated,service_role;
grant execute on function economics_v2.create_group_finance_expense_impl(uuid,uuid,uuid,date,numeric,text,text) to authenticated;
grant execute on function public.create_group_finance_expense_v1(uuid,uuid,uuid,date,numeric,text,text) to authenticated;
