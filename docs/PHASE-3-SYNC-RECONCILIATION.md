# Phase 3 — Sync & Reconciliation

## Guarantees
- Server assigns monotonic sequence/cursor.
- ACK timeout followed by retry cannot duplicate business effect.
- Reusing an idempotency key with a different payload is an explicit conflict.
- Retry is used for transient transport failures; domain conflicts are not silently retried.
- Reconciliation compares transaction count, sales total, payment total, and outstanding sync count.
- Mismatch becomes RECONCILIATION_REQUIRED; no silent financial repair.
- Telemetry records attempts, outcomes, latency and error classification.
- Tenant/device identity remain attached to every sync event.

## State
PENDING -> SENDING -> ACKED
SENDING -> RETRY -> SENDING
SENDING -> CONFLICT
SENDING -> REJECTED

## Non-goals
Inventory/COGS, financial closing, provider settlement, analytics, and Phase 4.

## Exit gate
npm run test:sync
npm run phase3:integration
npm run check
canonical PostgreSQL migration/integrity regression
