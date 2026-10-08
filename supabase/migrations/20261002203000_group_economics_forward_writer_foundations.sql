-- Private invokers run under a guarded implementation's privileges, never its JWT identity.
create function economics_v2.raise_group_writer_error(p_state text,p_code text,p_field text,p_entity uuid)
returns void language plpgsql security invoker set search_path='' as $$
begin
  raise exception using errcode=p_state,message='Invalid Group writer request',
    detail=jsonb_build_object('contract_version','group-economics.forward.v3',
      'code',p_code,'field',p_field,'entity_id',p_entity)::text;
end;
$$;

create function economics_v2.assert_group_writer_actor(p_granja_id uuid)
returns uuid language plpgsql security invoker set search_path='' as $$
begin
  if auth.uid() is null then
    perform economics_v2.raise_group_writer_error('42501','forbidden','granja_id',p_granja_id);
  end if;
  if p_granja_id is null then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','granja_id',null);
  end if;
  if not exists(select 1 from public.miembros_granja m
    join economics_v2.feature_flags f on f.granja_id=m.granja_id and f.economics_v2_enabled
    where m.granja_id=p_granja_id and m.user_id=auth.uid() and m.rol::text in ('owner','editor')) then
    perform economics_v2.raise_group_writer_error('42501','forbidden','granja_id',p_granja_id);
  end if;
  return auth.uid();
end;
$$;

-- JSON object order and numeric scale are not semantic request differences; array order is.
create function economics_v2.canonical_group_request(p_value jsonb)
returns jsonb language plpgsql immutable security invoker set search_path='' as $$
declare v_result jsonb;
begin
  case jsonb_typeof(p_value)
    when 'number' then return to_jsonb(trim_scale((p_value #>> '{}')::numeric));
    when 'object' then
      select coalesce(jsonb_object_agg(key,economics_v2.canonical_group_request(value)),'{}'::jsonb)
      into v_result from jsonb_each(p_value);
    when 'array' then
      select coalesce(jsonb_agg(economics_v2.canonical_group_request(value) order by ordinal),'[]'::jsonb)
      into v_result from jsonb_array_elements(p_value) with ordinality as a(value,ordinal);
    else return p_value;
  end case;
  return v_result;
end;
$$;

-- Callers derive the COMPLETE affected scope. Fact locks follow this prefix in later units.
create function economics_v2.lock_group_writer_scope(p_granja_id uuid,p_group_ids uuid[],
  p_animal_ids uuid[],p_period_ids uuid[],p_effective_on date)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_actor uuid; v_id uuid; v_row record; v_groups uuid[]; v_animals uuid[]; v_periods uuid[];
begin
  v_actor:=economics_v2.assert_group_writer_actor(p_granja_id);
  if p_group_ids is null or p_animal_ids is null or p_period_ids is null
    or exists(select 1 from unnest(p_group_ids||p_animal_ids||p_period_ids) id where id is null)
    or p_effective_on is null or not isfinite(p_effective_on) or p_effective_on>current_date then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','scope',null);
  end if;
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  select coalesce(array_agg(distinct id order by id),'{}'::uuid[]) into v_groups from unnest(p_group_ids) id;
  select coalesce(array_agg(distinct id order by id),'{}'::uuid[]) into v_animals from unnest(p_animal_ids) id;
  select coalesce(array_agg(distinct id order by id),'{}'::uuid[]) into v_periods from unnest(p_period_ids) id;
  foreach v_id in array v_groups loop
    perform 1 from public.grupos where granja_id=p_granja_id and id=v_id for update;
    if not found then perform economics_v2.raise_group_writer_error('42501','forbidden','group_id',v_id); end if;
  end loop;
  foreach v_id in array v_animals loop
    select * into v_row from public.animales where granja_id=p_granja_id and id=v_id for update;
    if not found then perform economics_v2.raise_group_writer_error('42501','forbidden','animal_id',v_id); end if;
    if v_row.fecha_adquisicion>p_effective_on then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',v_id);
    end if;
  end loop;
  foreach v_id in array v_periods loop
    select * into v_row from economics_v2.group_occupancy_periods where granja_id=p_granja_id and id=v_id for update;
    if not found then perform economics_v2.raise_group_writer_error('42501','forbidden','period_id',v_id); end if;
    if v_row.end_position is not null or v_row.closed_on is not null then
      perform economics_v2.raise_group_writer_error('23514','closed_period_immutable','period_id',v_id);
    end if;
    if v_row.starts_on>p_effective_on then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',v_id);
    end if;
  end loop;
  perform 1 from economics_v2.group_animal_acquisition_basis
    where granja_id=p_granja_id and animal_id=any(v_animals) order by animal_id for update;
  if exists(select 1 from economics_v2.group_occupancy_events
    where granja_id=p_granja_id and (animal_id=any(v_animals) or period_id=any(v_periods))
      and effective_on>p_effective_on) then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',null);
  end if;
  return jsonb_build_object('actor_id',v_actor,'group_ids',v_groups,'animal_ids',v_animals,'period_ids',v_periods);
end;
$$;

-- Preparation never inserts a ledger reservation or completes a business operation.
-- Replay precedes current-state/date-bound scope checks. Trusted callers reconstruct the original source.
create function economics_v2.prepare_group_operation(p_granja_id uuid,p_operation_id uuid,p_request jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare v_actor uuid; v_request jsonb; v_key text; v_uuid uuid; v_date date; v_hash text; v_stored record;
begin
  v_actor:=economics_v2.assert_group_writer_actor(p_granja_id);
  if p_operation_id is null or jsonb_typeof(p_request) is distinct from 'object' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','request',p_operation_id);
  end if;
  if not p_request ?& array['action','animal_id','source_period_id','destination_group_id',
      'destination_purpose_id','sale_id','effective_on','payload']
    or (select count(*) from jsonb_object_keys(p_request))<>8
    or p_request->>'action' is null or p_request->>'action' not in ('enter','transfer','purpose_change','exit','reactivate','delete')
    or jsonb_typeof(p_request->'payload') is distinct from 'object' then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','request',p_operation_id);
  end if;
  v_request:=p_request;
  begin
    foreach v_key in array array['animal_id','source_period_id','destination_group_id','destination_purpose_id','sale_id'] loop
      if jsonb_typeof(p_request->v_key) not in ('string','null') then
        perform economics_v2.raise_group_writer_error('22023','invalid_request',v_key,p_operation_id);
      end if;
      v_uuid:=(p_request->>v_key)::uuid;
      if v_key='animal_id' and v_uuid is null then
        perform economics_v2.raise_group_writer_error('22023','invalid_request',v_key,p_operation_id);
      end if;
      v_request:=jsonb_set(v_request,array[v_key],coalesce(to_jsonb(v_uuid),'null'::jsonb));
    end loop;
    v_date:=(p_request->>'effective_on')::date;
    if v_date is null or not isfinite(v_date) or v_date>current_date then
      perform economics_v2.raise_group_writer_error('22023','invalid_request','effective_on',p_operation_id);
    end if;
    v_request:=jsonb_set(v_request,'{effective_on}',to_jsonb(v_date));
  exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow then
    perform economics_v2.raise_group_writer_error('22023','invalid_request','request',p_operation_id);
  end;
  v_hash:=encode(sha256(convert_to(economics_v2.canonical_group_request(jsonb_build_object(
    'contract_version','group-economics.forward.v3','granja_id',p_granja_id,'actor_id',v_actor,
    'operation_id',p_operation_id,'request',v_request))::text,'UTF8')),'hex');
  perform pg_advisory_xact_lock(hashtextextended('group-economics:'||p_granja_id::text,0));
  select * into v_stored from economics_v2.group_occupancy_operations
    where granja_id=p_granja_id and operation_id=p_operation_id;
  if found then
    if v_stored.payload_hash<>v_hash then
      perform economics_v2.raise_group_writer_error('22023','operation_payload_conflict','operation_id',p_operation_id);
    end if;
    if jsonb_typeof(v_stored.result) is distinct from 'object' then
      perform economics_v2.raise_group_writer_error('23514','invariant_violation','operation_id',p_operation_id);
    end if;
    return jsonb_build_object('payload_hash',v_hash,'replayed',true,
      'result',v_stored.result||jsonb_build_object('replayed',true));
  end if;
  return jsonb_build_object('payload_hash',v_hash,'replayed',false,'result',null);
end;
$$;

revoke all on function economics_v2.raise_group_writer_error(text,text,text,uuid) from public,anon,authenticated;
revoke all on function economics_v2.assert_group_writer_actor(uuid) from public,anon,authenticated;
revoke all on function economics_v2.canonical_group_request(jsonb) from public,anon,authenticated;
revoke all on function economics_v2.lock_group_writer_scope(uuid,uuid[],uuid[],uuid[],date) from public,anon,authenticated;
revoke all on function economics_v2.prepare_group_operation(uuid,uuid,jsonb) from public,anon,authenticated;
