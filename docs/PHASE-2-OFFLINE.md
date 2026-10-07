# Phase 2 — Offline POS Engine

## Scope
A standard cash sale must commit locally without an API connection. Local state is durable in SQLite, the receipt is created in the same local transaction, and a single outbox record carries the canonical sync envelope.

## Guarantees
- Device trust is checked before shift or sale operations.
- A sale requires an open shift.
- Order, line items, cash payment, receipt, and outbox are one SQLite transaction.
- Local duplicate submission by order identity creates no second business effect.
- Every sync event has tenant identity, aggregate identity, correlation identity and an idempotency key.
- Server delivery is at-least-once; server idempotency turns duplicate delivery into a harmless ACK.
- Network failure leaves the paid order and receipt intact and schedules outbox retry.
- Device revocation is an explicit conflict, not an infinite retry.
- No last-write-wins mutation is used for financial records.
- Canonical PostgreSQL ledgers remain server-side authority after successful sync.

## State model
~~~text
LOCAL COMMIT -> PENDING -> SENDING -> ACKED
                         \-> RETRY -> SENDING
                         \-> CONFLICT
~~~

## Phase 2 non-goals
- No dashboard/reporting work.
- No online payment-provider integration.
- No stock deduction while offline.
- No Phase 3 UI.
- No changes to canonical ledger immutability/RLS.

## Evidence gate
npm run test:offline, npm run offline:integration, and npm run check must all pass in CI before Phase 2 is closed.
