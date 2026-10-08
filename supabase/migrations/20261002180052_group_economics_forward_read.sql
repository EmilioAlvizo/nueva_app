-- Forward reads retain the private metrics helper and never grant direct fact access.
create function economics_v2.list_group_economics_impl(
  p_granja_id uuid, p_page_size integer, p_cursor_starts_on date,
  p_cursor_period_id uuid, p_cursor_read_position bigint
) returns jsonb language plpgsql security definer stable set search_path = '' as $$
declare
  v_current_position bigint;
  v_read_position bigint;
  v_cursor_count integer := num_nonnulls(p_cursor_starts_on,p_cursor_period_id,p_cursor_read_position);
  v_code text;
  v_state text := '22023';
  v_field text;
  v_items jsonb := '[]';
  v_item jsonb;
  v_snapshot economics_v2.group_meat_snapshots%rowtype;
  v_period record;
  v_has_more boolean := false;
begin
  if auth.uid() is null or not exists (
    select 1 from public.miembros_granja m
    join economics_v2.feature_flags f on f.granja_id=m.granja_id and f.economics_v2_enabled
    where m.granja_id=p_granja_id and m.user_id=auth.uid() and m.rol::text in ('owner','editor','viewer')
  ) then
    v_code := 'forbidden';
    v_state := '42501';
    v_field := 'granja_id';
  end if;
  if auth.uid() is not null and p_granja_id is null then
    v_code := 'invalid_request';
    v_state := '22023';
    v_field := 'granja_id';
  end if;
  if v_code is null and (p_page_size is null or p_page_size not between 1 and 50) then
    v_code := 'invalid_request';
    v_field := 'page_size';
  end if;
  if v_code is not null then
    raise exception using errcode=v_state, message='Invalid Group economics read',
      detail=jsonb_build_object('contract_version','group-economics.forward.v3',
        'code',v_code,'field',v_field,'entity_id',null)::text;
  end if;
  select coalesce(max(event_position),0) into v_current_position
  from economics_v2.group_occupancy_events where granja_id=p_granja_id;
  v_read_position := coalesce(p_cursor_read_position,v_current_position);
  if v_cursor_count not in (0,3) or (v_cursor_count=3 and (
    p_cursor_read_position<=0 or p_cursor_read_position>v_current_position
    or p_cursor_starts_on>current_date or not exists (
      select 1 from economics_v2.group_occupancy_periods p
      join public.cat_proposito_animal purpose on purpose.id=p.purpose_id and purpose.granja_id=p.granja_id
      where p.id=p_cursor_period_id and p.granja_id=p_granja_id
        and p.starts_on=p_cursor_starts_on and purpose.codigo_calculo='carne'
        and p.start_position<=p_cursor_read_position
    )
  )) then
    raise exception using errcode='22023', message='Invalid Group economics cursor',
      detail=jsonb_build_object('contract_version','group-economics.forward.v3',
        'code','invalid_cursor','field','cursor','entity_id',p_cursor_period_id)::text;
  end if;

  for v_period in
    select p.*,g.nombre as group_name,purpose.codigo_calculo as purpose_code
    from economics_v2.group_occupancy_periods p
    join public.grupos g on g.id=p.group_id and g.granja_id=p.granja_id
    join public.cat_proposito_animal purpose on purpose.id=p.purpose_id and purpose.granja_id=p.granja_id
    where p.granja_id=p_granja_id and purpose.codigo_calculo='carne'
      and p.start_position<=v_read_position
      and (v_cursor_count=0 or (p.starts_on,p.id)<(p_cursor_starts_on,p_cursor_period_id))
    order by p.starts_on desc,p.id desc limit p_page_size+1
  loop
    if jsonb_array_length(v_items)=p_page_size then
      v_has_more := true;
      exit;
    end if;
    v_item := jsonb_build_object(
      'stable_key','group-period:' || v_period.id,'period_id',v_period.id,
      'granja_id',v_period.granja_id,'group_id',v_period.group_id,'purpose_id',v_period.purpose_id,
      'starts_on',v_period.starts_on,'closed_on',v_period.closed_on,
      'start_position',v_period.start_position,'end_position',v_period.end_position);
    if v_period.end_position is null then
      v_item := v_item || jsonb_build_object('status','open','group_name',v_period.group_name,
        'purpose_code',v_period.purpose_code,'metrics_source','live',
        'metrics_version','group-economics.forward.v3','snapshot_id',null,
        'metrics',economics_v2.calculate_group_period_live_metrics(p_granja_id,v_period.id));
    else
      select * into v_snapshot from economics_v2.group_meat_snapshots
      where period_id=v_period.id and granja_id=p_granja_id;
      if not found then
        raise exception using errcode='23514', message='Closed Group snapshot is missing',
          detail=jsonb_build_object('contract_version','group-economics.forward.v3',
            'code','missing_closed_snapshot','field','period_id','entity_id',v_period.id)::text;
      end if;
      if v_snapshot.snapshot_version<>'group-meat-snapshot.forward.v3'
        or jsonb_typeof(v_snapshot.payload->'group_name') is distinct from 'string'
        or v_snapshot.payload->>'purpose_code' is distinct from 'carne'
        or jsonb_typeof(v_snapshot.payload->'metrics') is distinct from 'object' then
        raise exception using errcode='23514', message='Closed Group snapshot is invalid',
          detail=jsonb_build_object('contract_version','group-economics.forward.v3',
            'code','invariant_violation','field','snapshot_id','entity_id',v_snapshot.id)::text;
      end if;
      if (select array_agg(k order by k) from jsonb_object_keys(v_snapshot.payload->'metrics') k)
        is distinct from array['acquisition_cost','active_animal_count','animal_count','animal_sale_revenue',
          'balance_per_animal','break_even_kg','direct_expense_total','exited_animal_count','feed_cost',
          'feed_kg_total','feed_source_count','profit','realized_price_per_kg','sale_count','saleable_kg',
          'sold_animal_count','total_cost'] then
        raise exception using errcode='23514', message='Closed Group metrics are incomplete',
          detail=jsonb_build_object('contract_version','group-economics.forward.v3',
            'code','invariant_violation','field','snapshot_id','entity_id',v_snapshot.id)::text;
      end if;
      v_item := v_item || jsonb_build_object('status','closed',
        'group_name',v_snapshot.payload->'group_name','purpose_code',v_snapshot.payload->'purpose_code',
        'metrics_source','snapshot','metrics_version',v_snapshot.snapshot_version,
        'snapshot_id',v_snapshot.id,'metrics',v_snapshot.payload->'metrics');
    end if;
    v_items := v_items || jsonb_build_array(v_item);
  end loop;
  return jsonb_build_object('contract_version','group-economics.forward.v3',
    'item_version','group-economics-item.forward.v3','cursor_version','period-start-id-position.v1',
    'read_position',v_read_position,'items',v_items,'has_more',v_has_more,
    'next_cursor',case when v_has_more then jsonb_build_object(
      'starts_on',v_item->'starts_on','period_id',v_item->'period_id','read_position',v_read_position) end);
end;
$$;

create function public.list_group_economics(
  p_granja_id uuid, p_page_size integer default 25, p_cursor_starts_on date default null,
  p_cursor_period_id uuid default null, p_cursor_read_position bigint default null
) returns jsonb language sql security invoker stable set search_path = '' as $$
  select economics_v2.list_group_economics_impl(p_granja_id,p_page_size,
    p_cursor_starts_on,p_cursor_period_id,p_cursor_read_position);
$$;

revoke all on function public.list_group_economics(uuid,integer,date,uuid) from public,anon,authenticated;
revoke all on function economics_v2.list_group_economics_impl(uuid,integer,date,uuid) from public,anon,authenticated;
revoke all on function public.list_group_economics(uuid,integer,date,uuid,bigint) from public,anon,authenticated;
revoke all on function economics_v2.list_group_economics_impl(uuid,integer,date,uuid,bigint) from public,anon,authenticated;
grant execute on function public.list_group_economics(uuid,integer,date,uuid,bigint) to authenticated;
grant execute on function economics_v2.list_group_economics_impl(uuid,integer,date,uuid,bigint) to authenticated;
