# Phase 4 — Inventory & Finance Integrity

## Objective
Membangun inventory dan finance capability tanpa membuat saldo mutable menjadi source of truth.

## Canonical model
- inventory_ledger tetap immutable canonical truth.
- cash_ledger tetap immutable canonical truth.
- payment adalah canonical payment lifecycle.
- cost_layer menyimpan layer biaya; remaining_quantity berubah hanya melalui FIFO consumption.
- inventory_projection adalah projection/rebuild target, bukan source of truth.
- cash_closing, payment_reconciliation, dan variance_case menyimpan operational control evidence.

## Inventory
- Purchase/goods receipt creates positive inventory ledger entries and cost layers.
- Sale consumes cost layers FIFO under row locks.
- Negative stock is rejected.
- Projection quantity/value is updated in the same database transaction as the ledger mutation.
- Stock opname records counted vs system quantity and posts an explicit adjustment event.
- A failed stock mutation rolls back both ledger and projection changes.

## Finance
- Server cash shift lifecycle supports opening -> closing.
- Closing computes explicit variance and creates a variance case when non-zero.
- Payment settlement reconciliation compares internal and external totals.
- Provider/payment mismatch is never silently repaired; it becomes an explicit variance.

## Concurrency
Inventory projection rows and FIFO cost layers are locked during mutation. PostgreSQL row-locking makes concurrent conflicting updates wait until the first transaction commits or rolls back.

## Non-goals
- No accounting general ledger.
- No tax engine.
- No supplier master ERP.
- No automatic financial repair.
- No Phase 5 production pilot.

## Exit gate
1. Phase 4 SQL integration PASS.
2. Ledger/projection/cost-layer integrity PASS.
3. Insufficient stock atomic failure PASS.
4. Cash closing + variance workflow PASS.
5. Payment reconciliation + variance workflow PASS.
6. RLS/tenant contract PASS.
7. Phase 1–3 regression PASS.
8. Final main branch contains only accepted Phase 4 changes.
