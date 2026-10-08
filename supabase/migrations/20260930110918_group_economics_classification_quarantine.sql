create table economics_v2.cycle_group_classifications (
  cycle_id uuid primary key references economics_v2.cycles(id),
  granja_id uuid not null references public.granjas(id),
  classification text not null check (classification in ('exact', 'compatible_but_unresolved', 'non_mappable')),
  reason_code text not null, candidate_period_id uuid references economics_v2.group_occupancy_periods(id),
  source_provenance jsonb not null, source_digest text not null, classified_at timestamptz not null default now()
);
create table economics_v2.group_economics_quarantines (
  id uuid primary key default gen_random_uuid(), cycle_id uuid not null unique references economics_v2.cycles(id),
  granja_id uuid not null references public.granjas(id), classification text not null, reason_code text not null,
  source_provenance jsonb not null, status text not null default 'open', resolution_history jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table economics_v2.cycle_period_mappings (
  id uuid primary key default gen_random_uuid(), cycle_id uuid not null unique references economics_v2.cycles(id),
  period_id uuid not null unique references economics_v2.group_occupancy_periods(id), source_digest text not null,
  evidence_digest text not null, mapped_at timestamptz not null default now()
);
create table economics_v2.group_economics_quarantine_operations (
  granja_id uuid not null references public.granjas(id), operation_id uuid not null, payload_hash text not null,
  result jsonb not null, created_at timestamptz not null default now(), primary key (granja_id, operation_id)
);

create or replace function economics_v2.classify_legacy_cycle(p_cycle_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c record; names text[]; candidates uuid[]; v_class text; v_reason text; v_period uuid; v_provenance jsonb;
begin
  select cycle.*, purpose.codigo_calculo into c from economics_v2.cycles cycle
  join public.cat_proposito_animal purpose on purpose.id = cycle.proposito_id where cycle.id = p_cycle_id;
  if not found then raise exception using errcode = '22023', message = 'Unknown legacy cycle'; end if;
  select array_agg(distinct member.group_name_snapshot order by member.group_name_snapshot) filter (where member.group_name_snapshot is not null)
  into names from economics_v2.cycle_animals member where member.cycle_id = c.id;
  if c.codigo_calculo <> 'carne' then v_class := 'non_mappable'; v_reason := 'non_meat_purpose';
  elsif coalesce(cardinality(names), 0) = 0 then v_class := 'compatible_but_unresolved'; v_reason := 'missing_evidence';
  elsif cardinality(names) > 1 then v_class := 'compatible_but_unresolved'; v_reason := 'multi_group';
  else
    select array_agg(period.id order by period.id) into candidates
    from public.grupos group_source join economics_v2.group_occupancy_periods period on period.group_id = group_source.id
    where group_source.granja_id = c.granja_id and group_source.nombre = names[1] and period.purpose_id = c.proposito_id
      and period.starts_on < c.starts_on and c.ends_on is not null and period.closed_on is not null and c.ends_on < period.closed_on;
    if cardinality(candidates) = 1 then v_class := 'exact'; v_reason := 'unique_date_evidence'; v_period := candidates[1];
    elsif exists (select 1 from public.grupos group_source join economics_v2.group_occupancy_periods period on period.group_id = group_source.id where group_source.granja_id = c.granja_id and group_source.nombre = names[1] and period.purpose_id = c.proposito_id and (period.starts_on = c.starts_on or period.closed_on = c.ends_on)) then v_class := 'compatible_but_unresolved'; v_reason := 'legacy_same_day_order_unknown';
    else v_class := 'compatible_but_unresolved'; v_reason := 'ambiguous_period'; end if;
  end if;
  v_provenance := jsonb_build_object('cycle_id', c.id, 'granja_id', c.granja_id, 'purpose_id', c.proposito_id, 'starts_on', c.starts_on, 'ends_on', c.ends_on, 'member_group_names', coalesce(to_jsonb(names), '[]'::jsonb), 'candidate_period_ids', coalesce(to_jsonb(candidates), '[]'::jsonb), 'temporal_precision', 'date');
  insert into economics_v2.cycle_group_classifications as classification (cycle_id, granja_id, classification, reason_code, candidate_period_id, source_provenance, source_digest)
  values (c.id, c.granja_id, v_class, v_reason, v_period, v_provenance, md5(v_provenance::text))
  on conflict (cycle_id) do update set classification = excluded.classification, reason_code = excluded.reason_code, candidate_period_id = excluded.candidate_period_id, source_provenance = excluded.source_provenance, source_digest = excluded.source_digest, classified_at = now();
  if v_class <> 'exact' then insert into economics_v2.group_economics_quarantines as quarantine (cycle_id, granja_id, classification, reason_code, source_provenance)
    values (c.id, c.granja_id, v_class, v_reason, v_provenance) on conflict (cycle_id) do update set classification = excluded.classification, reason_code = excluded.reason_code, source_provenance = excluded.source_provenance, updated_at = now(); end if;
  return jsonb_build_object('cycle_id', c.id, 'classification', v_class, 'reason_code', v_reason, 'candidate_period_id', v_period, 'source_digest', md5(v_provenance::text));
end;
$$;

create or replace function economics_v2.resolve_group_economics_quarantine_impl(p_granja_id uuid, p_quarantine_id uuid, p_operation_id uuid, p_action text, p_period_id uuid, p_evidence text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare q economics_v2.group_economics_quarantines%rowtype; c economics_v2.cycle_group_classifications%rowtype; v_hash text; v_result jsonb; v_mapping uuid; v_user uuid := auth.uid();
begin
  if v_user is null or not public.fn_es_owner_granja(p_granja_id) then raise exception using errcode = '42501', message = 'Owner access required'; end if;
  select * into q from economics_v2.group_economics_quarantines where id = p_quarantine_id and granja_id = p_granja_id for update;
  if not found or p_action not in ('attach_evidence', 'map_exact', 'confirm_non_mappable') or btrim(coalesce(p_evidence, '')) = '' or (p_action = 'map_exact') <> (p_period_id is not null) then raise exception using errcode = '22023', message = 'Invalid quarantine resolution'; end if;
  v_hash := md5(jsonb_build_object('quarantine_id', p_quarantine_id, 'action', p_action, 'period_id', p_period_id, 'evidence', p_evidence)::text);
  select result into v_result from economics_v2.group_economics_quarantine_operations where granja_id = p_granja_id and operation_id = p_operation_id;
  if found then if (select payload_hash = v_hash from economics_v2.group_economics_quarantine_operations where granja_id = p_granja_id and operation_id = p_operation_id) then return v_result || jsonb_build_object('replayed', true); else raise exception using errcode = '22023', message = 'Conflicting quarantine operation'; end if; end if;
  if p_action = 'map_exact' then
    perform economics_v2.classify_legacy_cycle(q.cycle_id); select * into c from economics_v2.cycle_group_classifications where cycle_id = q.cycle_id;
    if c.classification <> 'exact' or c.candidate_period_id <> p_period_id then raise exception using errcode = '22023', message = 'Fresh classifier evidence does not support this mapping'; end if;
    insert into economics_v2.cycle_period_mappings (cycle_id, period_id, source_digest, evidence_digest) values (q.cycle_id, p_period_id, c.source_digest, md5(p_evidence)) on conflict (cycle_id) do nothing;
    select id into v_mapping from economics_v2.cycle_period_mappings where cycle_id = q.cycle_id and period_id = p_period_id;
    if v_mapping is null then raise exception using errcode = '22023', message = 'Cycle is already mapped to a different period'; end if;
  elsif p_action = 'confirm_non_mappable' and q.classification <> 'non_mappable' then raise exception using errcode = '22023', message = 'Only non-mappable classifications can be confirmed'; end if;
  update economics_v2.group_economics_quarantines set status = case p_action when 'map_exact' then 'mapped' when 'confirm_non_mappable' then 'confirmed_non_mappable' else status end, resolution_history = resolution_history || jsonb_build_array(jsonb_build_object('action', p_action, 'evidence_digest', md5(p_evidence), 'actor_id', v_user, 'at', now())), updated_at = now() where id = q.id;
  v_result := jsonb_build_object('contract_version', 'group-economics.v2', 'quarantine_id', q.id, 'classification', coalesce(c.classification, q.classification), 'mapping_id', v_mapping, 'period_id', p_period_id, 'resolution_action', p_action, 'evidence_digest', md5(p_evidence), 'resolved_by', v_user, 'resolved_at', now(), 'replayed', false);
  insert into economics_v2.group_economics_quarantine_operations values (p_granja_id, p_operation_id, v_hash, v_result); return v_result;
end;
$$;

alter table economics_v2.cycle_group_classifications enable row level security; alter table economics_v2.cycle_group_classifications force row level security;
alter table economics_v2.group_economics_quarantines enable row level security; alter table economics_v2.group_economics_quarantines force row level security;
alter table economics_v2.cycle_period_mappings enable row level security; alter table economics_v2.cycle_period_mappings force row level security;
alter table economics_v2.group_economics_quarantine_operations enable row level security; alter table economics_v2.group_economics_quarantine_operations force row level security;
revoke all on table economics_v2.cycle_group_classifications, economics_v2.group_economics_quarantines, economics_v2.cycle_period_mappings, economics_v2.group_economics_quarantine_operations from public, anon, authenticated;
revoke all on function economics_v2.classify_legacy_cycle(uuid) from public, anon, authenticated;
revoke all on function economics_v2.resolve_group_economics_quarantine_impl(uuid, uuid, uuid, text, uuid, text) from public, anon;
grant usage on schema economics_v2 to authenticated;
grant execute on function economics_v2.resolve_group_economics_quarantine_impl(uuid, uuid, uuid, text, uuid, text) to authenticated;
