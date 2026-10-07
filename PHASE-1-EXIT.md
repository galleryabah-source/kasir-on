# Phase 1 Exit Gate

## Scope
Canonical Core only. Phase 2 is not included.

## Delivered
- PostgreSQL canonical schema
- tenant/brand/outlet/warehouse/device/user/role
- product/SKU/variant/versioned price
- order/order item
- payment primitive
- sales ledger
- cash ledger
- inventory ledger
- audit log
- idempotency record
- immutable-ledger triggers
- composite tenant foreign keys
- forced RLS
- domain contracts/invariants
- CI with PostgreSQL 16 service
- migration and integrity scenario execution

## Acceptance
Static contracts: PASS.
Domain tests: PASS locally.
Live PostgreSQL: delegated to GitHub Actions gate.

## Important
Phase 1 is not considered PASS until the GitHub Actions run for this commit succeeds. No Phase 2 work should start before that evidence is reviewed and accepted.
