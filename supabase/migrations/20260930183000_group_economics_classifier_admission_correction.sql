alter table economics_v2.cycle_group_classifications
  add column if not exists evidence_history jsonb not null default '[]'::jsonb;

create or replace function economics_v2.classify_legacy_cycle(p_cycle_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c record;
  v_class text;
  v_reason text;
  v_period uuid;
  v_candidates uuid[];
  v_provenance jsonb;
  v_members jsonb;
  v_feeds jsonb;
  v_expenses jsonb;
  v_sales jsonb;
  v_member_count integer;
  v_valid_members integer;
  v_bad_farm boolean;
  v_same_day boolean;
  v_bad_expense boolean;
  v_bad_sale boolean;
begin
  select cycle.*, purpose.codigo_calculo into c
  from economics_v2.cycles cycle
  join public.cat_proposito_animal purpose on purpose.id = cycle.proposito_id
  where cycle.id = p_cycle_id;
  if not found then raise exception using errcode = '22023', message = 'Unknown legacy cycle'; end if;

  select coalesce(jsonb_agg(jsonb_build_object('source_id', member.cycle_id::text || ':' || member.animal_id::text,
    'source_version', 'cycle-animals.v1', 'digest', md5(jsonb_build_array(member.animal_id, member.joined_on, member.left_on, member.sold_by_sale_id)::text),
    'animal_id', member.animal_id, 'joined_on', member.joined_on, 'left_on', member.left_on, 'sale_id', member.sold_by_sale_id) order by member.animal_id), '[]'::jsonb), count(*)
  into v_members, v_member_count from economics_v2.cycle_animals member where member.cycle_id = c.id;
  select coalesce(jsonb_agg(jsonb_build_object('source_id', feed.id, 'source_version', 'cycle-feeds.v1',
    'digest', md5(jsonb_build_array(feed.id, feed.granja_id, feed.starts_on, feed.ends_on, feed.group_name_snapshot)::text),
    'starts_on', feed.starts_on, 'ends_on', feed.ends_on) order by feed.id), '[]'::jsonb)
  into v_feeds from economics_v2.cycle_feeds feed where feed.cycle_id = c.id;
  select coalesce(jsonb_agg(jsonb_build_object('source_id', expense.id, 'source_version', 'cycle-expenses.v1',
    'digest', md5(jsonb_build_array(expense.id, expense.granja_id, expense.occurred_on, expense.amount)::text),
    'occurred_on', expense.occurred_on) order by expense.id), '[]'::jsonb)
  into v_expenses from economics_v2.cycle_expenses expense where expense.cycle_id = c.id;
  select coalesce(jsonb_agg(jsonb_build_object('source_id', sale.id, 'source_version', 'venta-animal.v1',
    'digest', md5(jsonb_build_array(sale.id, sale.granja_id, sale.group_id, sale.animal_id, sale.fecha_venta, sale.total_amount)::text),
    'animal_id', sale.animal_id, 'fecha_venta', sale.fecha_venta) order by sale.id), '[]'::jsonb)
  into v_sales from public.venta_animal sale join economics_v2.cycle_animals member on member.animal_id = sale.animal_id
  where member.cycle_id = c.id and sale.granja_id = c.granja_id and sale.fecha_venta between c.starts_on and c.ends_on;

  select array_agg(distinct period.id order by period.id), count(distinct member.animal_id)
  into v_candidates, v_valid_members
  from economics_v2.cycle_animals member
  join public.animales animal on animal.id = member.animal_id and animal.granja_id = c.granja_id
  join economics_v2.group_occupancy_memberships membership on membership.animal_id = member.animal_id and membership.granja_id = c.granja_id
  join economics_v2.group_occupancy_periods period on period.id = membership.period_id and period.granja_id = c.granja_id
  join public.grupos group_source on group_source.id = period.group_id and group_source.granja_id = c.granja_id
  join public.cat_proposito_animal purpose on purpose.id = period.purpose_id and purpose.granja_id = c.granja_id and purpose.id = c.proposito_id
  where member.cycle_id = c.id and member.joined_on is not null and member.left_on is not null
    and period.starts_on < member.joined_on and member.left_on < period.closed_on
    and exists (select 1 from economics_v2.group_occupancy_events event where event.membership_id = membership.id and event.event_position = membership.start_position and event.action in ('enter', 'reactivate', 'purpose_change') and event.effective_on < member.joined_on)
    and exists (select 1 from economics_v2.group_occupancy_events event where event.membership_id = membership.id and event.event_position = membership.end_position and event.action in ('exit', 'transfer', 'purpose_change', 'delete') and event.effective_on > member.left_on)
  group by member.cycle_id;
  select exists (select 1 from economics_v2.cycle_animals member left join public.animales animal on animal.id = member.animal_id
    where member.cycle_id = c.id and (animal.id is null or animal.granja_id <> c.granja_id))
    or exists (select 1 from economics_v2.cycle_feeds feed where feed.cycle_id = c.id and feed.granja_id <> c.granja_id)
    or exists (select 1 from economics_v2.cycle_expenses expense where expense.cycle_id = c.id and expense.granja_id <> c.granja_id)
  into v_bad_farm;
  select exists (select 1 from economics_v2.cycle_animals member join economics_v2.group_occupancy_memberships membership on membership.animal_id = member.animal_id
    join economics_v2.group_occupancy_periods period on period.id = membership.period_id
    where member.cycle_id = c.id and period.granja_id = c.granja_id and period.purpose_id = c.proposito_id
      and (member.joined_on = period.starts_on or member.left_on = period.closed_on)) into v_same_day;

  if c.codigo_calculo <> 'carne' then v_class := 'non_mappable'; v_reason := 'non_meat_purpose';
  elsif c.ends_on is null or v_member_count = 0 then v_class := 'compatible_but_unresolved'; v_reason := 'missing_evidence';
  elsif v_bad_farm then v_class := 'compatible_but_unresolved'; v_reason := 'ownership_mismatch';
  elsif v_same_day then v_class := 'compatible_but_unresolved'; v_reason := 'legacy_same_day_order_unknown';
  elsif v_valid_members <> v_member_count then v_class := 'compatible_but_unresolved'; v_reason := 'missing_member_interval_evidence';
  elsif cardinality(v_candidates) <> 1 then v_class := 'compatible_but_unresolved'; v_reason := case when cardinality(v_candidates) > 1 then 'multi_group' else 'ambiguous_period' end;
  elsif jsonb_array_length(v_feeds) <> 0 then v_class := 'compatible_but_unresolved'; v_reason := 'missing_feed_attribution';
  else
    v_period := v_candidates[1];
    select exists (select 1 from economics_v2.cycle_expenses expense join economics_v2.group_occupancy_periods period on period.id = v_period
      where expense.cycle_id = c.id and (expense.granja_id <> c.granja_id or not (c.starts_on < expense.occurred_on and expense.occurred_on < c.ends_on and period.starts_on < expense.occurred_on and expense.occurred_on < period.closed_on))) into v_bad_expense;
    select exists (select 1 from economics_v2.cycle_animals member left join public.venta_animal sale on sale.id = member.sold_by_sale_id
      where member.cycle_id = c.id and member.sold_by_sale_id is not null and (sale.id is null or sale.granja_id <> c.granja_id or sale.group_id <> (select group_id from economics_v2.group_occupancy_periods where id = v_period) or sale.animal_id <> member.animal_id or sale.record_kind <> 'individual' or not (member.joined_on < sale.fecha_venta and sale.fecha_venta < member.left_on)))
      or exists (select 1 from public.venta_animal sale join economics_v2.cycle_animals member on member.animal_id = sale.animal_id
        where member.cycle_id = c.id and sale.granja_id = c.granja_id and sale.fecha_venta between c.starts_on and c.ends_on and sale.id is distinct from member.sold_by_sale_id) into v_bad_sale;
    if v_bad_expense then v_class := 'compatible_but_unresolved'; v_reason := 'expense_attribution_ambiguous';
    elsif v_bad_sale then v_class := 'compatible_but_unresolved'; v_reason := 'contradictory_sale_evidence';
    else v_class := 'exact'; v_reason := 'complete_date_evidence'; end if;
  end if;

  v_provenance := jsonb_build_object('cycle_id', c.id, 'granja_id', c.granja_id, 'purpose_id', c.proposito_id,
    'temporal_precision', 'date', 'member_sources', v_members, 'feed_sources', v_feeds,
    'expense_sources', v_expenses, 'sale_sources', v_sales, 'candidate_period_ids', coalesce(to_jsonb(v_candidates), '[]'::jsonb));
  insert into economics_v2.cycle_group_classifications as classification (cycle_id, granja_id, classification, reason_code, candidate_period_id, source_provenance, source_digest, evidence_history)
  values (c.id, c.granja_id, v_class, v_reason, v_period, v_provenance, md5(v_provenance::text), jsonb_build_array(jsonb_build_object('source_digest', md5(v_provenance::text), 'classification', v_class, 'reason_code', v_reason, 'provenance', v_provenance)))
  on conflict (cycle_id) do update set classification = excluded.classification, reason_code = excluded.reason_code, candidate_period_id = excluded.candidate_period_id, source_provenance = excluded.source_provenance, source_digest = excluded.source_digest,
    evidence_history = case when classification.evidence_history @> jsonb_build_array(jsonb_build_object('source_digest', excluded.source_digest)) then classification.evidence_history else classification.evidence_history || jsonb_build_array(jsonb_build_object('source_digest', excluded.source_digest, 'classification', excluded.classification, 'reason_code', excluded.reason_code, 'provenance', excluded.source_provenance)) end;
  if v_class <> 'exact' then
    insert into economics_v2.group_economics_quarantines as quarantine (cycle_id, granja_id, classification, reason_code, source_provenance)
    values (c.id, c.granja_id, v_class, v_reason, v_provenance)
    on conflict (cycle_id) do update set classification = excluded.classification, reason_code = excluded.reason_code, source_provenance = excluded.source_provenance, updated_at = now();
  end if;
  return jsonb_build_object('cycle_id', c.id, 'classification', v_class, 'reason_code', v_reason, 'candidate_period_id', v_period, 'source_digest', md5(v_provenance::text));
end;
$$;

create or replace function economics_v2.resolve_group_economics_quarantine_impl(
  p_granja_id uuid, p_quarantine_id uuid, p_operation_id uuid, p_action text, p_period_id uuid, p_evidence text
) returns jsonb language sql security definer set search_path = '' as $$
  select economics_v2.group_economics_not_activated();
$$;
comment on function economics_v2.resolve_group_economics_quarantine_impl(uuid, uuid, uuid, text, uuid, text)
  is 'CU2-A safety interlock: quarantine resolution remains disabled until CU2-B authorization and serialization controls.';

create policy cycle_group_classifications_deny_direct on economics_v2.cycle_group_classifications for all to authenticated using (false) with check (false);
create policy group_economics_quarantines_deny_direct on economics_v2.group_economics_quarantines for all to authenticated using (false) with check (false);
create policy cycle_period_mappings_deny_direct on economics_v2.cycle_period_mappings for all to authenticated using (false) with check (false);
create policy group_economics_quarantine_operations_deny_direct on economics_v2.group_economics_quarantine_operations for all to authenticated using (false) with check (false);
