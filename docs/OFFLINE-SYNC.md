# KASIRA Offline & Sync Protocol

## Local-first transaction
1. Validate locally.
2. Persist transaction atomically in SQLite.
3. Persist outbox record in the same local transaction.
4. Render success to cashier.
5. Sync asynchronously.

## Server ingestion
1. Authenticate tenant/device.
2. Validate schema/version.
3. Check idempotency key.
4. Validate domain invariants.
5. Append canonical event/ledger records.
6. Update projections.
7. Return ACK with server event identity/cursor.

## Idempotency

Every syncable mutation must provide an idempotency key scoped appropriately (normally tenant + device + local transaction identity).

Repeated request with same key must produce the same business result.

## Cursoring

Device tracks:
- last uploaded local sequence
- last acknowledged server cursor
- pending outbox count

## Conflict

```
CONFLICT_DETECTED
 -> POLICY_APPLIED
 -> RESOLUTION_EVENT
 -> RECONCILIATION_REQUIRED
```

## Reconciliation

On demand and on scheduled operational checks:
- local transaction count vs server count
- local total vs server total
- payment totals
- stock ledger totals
- failed/outstanding sync entries

Any mismatch becomes an operational exception, not silently repaired data.

## Offline limits

Certain provider-dependent operations may be marked online-required or pending, but standard local sales remain usable offline.
