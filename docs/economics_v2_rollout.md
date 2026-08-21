# Economics V2 rollout and rollback

Economics V2 is additive and must remain disabled until an approved release explicitly enables it. Sandbox evidence verifies a candidate only; it never authorizes a production release.

## Prerequisites

- Confirm the normalized nine-migration repository history matches the target environment.
- Confirm the focused security, sale, calculation, and reconciliation suites pass in the authorized disposable sandbox.
- Confirm the focused Flutter suite, full Flutter suite, static analysis, and security and performance advisor reviews have recorded results.
- Confirm legacy `puntos_equilibrio_huevos` behavior remains independent of Economics V2 data and flags.

## Default and staged rollout

1. Keep the client `economics_v2_enabled` build-time flag off by default; the route redirects to Finanzas when it is off.
2. Keep the farm-scoped `economics_v2.feature_flags.economics_v2_enabled` value false until an authorized, documented rollout decision.
3. For an approved staged rollout, enable access only for an authorized farm cohort and observe the checks below before expanding the cohort.
4. Do not infer production approval from sandbox tests, migration parity, or advisor results.

## Observable checks

| Check | Expected result |
|---|---|
| V2 route with client flag off, no farm, or viewer role | Redirects to Finanzas; no V2 entry is available. |
| Direct private-table access | Denied to `authenticated` and `anon`; only named wrappers/functions are available. |
| Canonical animal revenue | Economics V2 recognizes animal-sale revenue from `venta_animal` only. Linked `bajas_animales` remain administrative and add no second revenue amount. |
| Historical reconciliation | Each eligible sale baja has one `legacy_batch` sale linked by `baja_id`; reruns preserve the original total and add neither rows nor revenue. |
| Finalization | One versioned input/result snapshot is retained; repeat finalization and snapshot mutation are rejected. |
| Legacy finance | `puntos_equilibrio_huevos` routing, inputs, calculations, and results are unchanged by V2 data or either flag state. |

## Rollback and data retention

1. Disable the client V2 flag and set the affected farm V2 flag false through an authorized operational change.
2. Verify the V2 route again redirects to Finanzas and legacy finance still behaves normally.
3. Retain additive V2 cycles, snapshots, canonical `venta_animal` links, and administrative bajas. Disabling access is not a request to delete or recompute financial history.
4. If an access rollback also requires privilege removal, revoke only the named Economics V2 function execution and private-schema usage according to the migration's least-privilege model. Do not grant private-table access and do not treat bajas as revenue.

## Advisor interpretation

Security and performance advisors are evidence, not release switches. Record each finding as candidate-caused, base-only, or informational, then resolve candidate-caused blockers before any rollout decision. Re-check advisor evidence when migration identity or target environment changes.

## Release boundary

This document records operational guidance and sandbox proof only. It does not enable Economics V2, release an application, change remote production data, or provide production credentials.
