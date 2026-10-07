# Phase 4 Gate Notes

## Design decisions
- Reused the existing immutable inventory and cash ledgers instead of creating parallel canonical ledgers.
- Added projections and cost layers only as derived operational state.
- FIFO consumption is deterministic and concurrency-safe through row locking.
- Payment and cash mismatches produce explicit variance cases; no silent repair.
- All new persistent tables are tenant-scoped with forced RLS.
- Phase 4 does not change the offline/sync protocol contract.

## Required evidence
- Migration applies cleanly on PostgreSQL 16.
- Inventory FIFO COGS is exact for the integration fixture.
- Ledger quantity/value equals projection quantity/value.
- Insufficient stock rolls back atomically.
- Cash balanced closing is recorded as BALANCED.
- Payment settlement mismatch is recorded as VARIANCE and creates an OPEN variance case.
- Phase 1, Phase 2, and Phase 3 tests remain green.

## Final gate note
Exact inventory event valuation is represented by inventory_ledger.value_minor; unit_cost_minor remains the reporting unit cost.
