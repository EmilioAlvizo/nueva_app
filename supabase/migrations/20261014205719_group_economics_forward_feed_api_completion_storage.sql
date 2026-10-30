-- Private completion storage v1 only; no helpers, gateways or business mutations.
-- CHECKs and the ledger FK enforce shape and durable identity, not semantic bindings.
create table economics_v2.group_feed_api_completions (
  granja_id uuid not null,
  operation_id uuid not null,
  bridge_version text not null default 'group-feed-api-completion.v1',
  operation_kind text not null,
  actor_id uuid not null,
  period_id uuid not null,
  mixture_id uuid not null,
  group_id uuid,
  expected_allocation_updated_at timestamptz not null,
  predecessor_source_updated_at timestamptz not null,
  predecessor_source_digest text not null,
  public_payload_hash text not null,
  core_payload_hash text not null,
  core_result_hash text not null,
  constraint group_feed_api_completions_pkey
    primary key (granja_id, operation_id),
  constraint group_feed_api_completions_operation_fkey
    foreign key (granja_id, operation_id)
    references economics_v2.group_occupancy_operations (granja_id, operation_id)
    on update no action on delete no action,
  constraint group_feed_api_completions_bridge_version_check
    check (bridge_version = 'group-feed-api-completion.v1'),
  constraint group_feed_api_completions_operation_kind_check
    check (operation_kind in ('feed_update', 'feed_delete')),
  constraint group_feed_api_completions_group_id_check
    check ((operation_kind = 'feed_update' and group_id is not null)
      or (operation_kind = 'feed_delete' and group_id is null)),
  constraint group_feed_api_completions_allocation_timestamp_check
    check (pg_catalog.isfinite(expected_allocation_updated_at)),
  constraint group_feed_api_completions_source_timestamp_check
    check (pg_catalog.isfinite(predecessor_source_updated_at)),
  constraint group_feed_api_completions_source_digest_check
    check (predecessor_source_digest ~ '^[0-9a-f]{64}$'),
  constraint group_feed_api_completions_public_payload_hash_check
    check (public_payload_hash ~ '^[0-9a-f]{64}$'),
  constraint group_feed_api_completions_core_payload_hash_check
    check (core_payload_hash ~ '^[0-9a-f]{64}$'),
  constraint group_feed_api_completions_core_result_hash_check
    check (core_result_hash ~ '^[0-9a-f]{64}$')
);

alter table economics_v2.group_feed_api_completions owner to postgres;
alter table economics_v2.group_feed_api_completions enable row level security;
alter table economics_v2.group_feed_api_completions force row level security;

create policy group_feed_api_completions_deny_direct
  on economics_v2.group_feed_api_completions
  for all to anon, authenticated
  using (false) with check (false);

revoke all on table economics_v2.group_feed_api_completions
  from public, anon, authenticated, service_role;

comment on table economics_v2.group_feed_api_completions is
  'Private v1 completion context; application append-only, not a receipt copy or superuser immutability guarantee. Future guarded gateways must verify semantic bindings under the farm operation lock before insertion.';
-- Actor and target UUIDs intentionally have no FKs: retain historical context
-- after source/allocation deletion or account cleanup; only the durable ledger is referenced.
comment on column economics_v2.group_feed_api_completions.actor_id is
  'Historical actor UUID retained without an auth user FK; not independently authenticated by storage.';
comment on column economics_v2.group_feed_api_completions.expected_allocation_updated_at is
  'Original client allocation concurrency token, distinct from the captured source predecessor clock.';
comment on column economics_v2.group_feed_api_completions.predecessor_source_updated_at is
  'Original source predecessor timestamp captured from the allocation; future gateways verify it against the actual source.';
comment on column economics_v2.group_feed_api_completions.predecessor_source_digest is
  'Original source predecessor digest captured from the allocation; storage validates format only.';
comment on column economics_v2.group_feed_api_completions.core_result_hash is
  'Canonical hash of the actual stored non-replayed core receipt, not a receipt copy; future guarded gateways must verify this binding.';
