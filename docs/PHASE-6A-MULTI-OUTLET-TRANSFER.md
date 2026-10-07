# Phase 6A — Multi-outlet Inventory Transfer

## Objective
Prove the first bounded Phase 6 business capability: inventory can move between two warehouses owned by two outlets in the same tenant without weakening canonical ledger integrity.

## Canonical command
`kasira.post_inventory_transfer(tenant_id, transfer_id, actor_id, occurred_at)`

The command:
1. validates tenant context;
2. validates source/destination warehouse-to-outlet identity;
3. requires `inventory.adjust`;
4. requires explicit outlet access to both source and destination;
5. consumes source FIFO layers;
6. creates immutable `TRANSFER_OUT` and `TRANSFER_IN` evidence;
7. moves exact FIFO value into destination cost layers;
8. updates both rebuildable projections atomically;
9. marks the transfer POSTED;
10. returns the same transfer ID on an identical retry.

## Invariants
- source quantity before = source quantity after + transferred quantity
- destination quantity after = destination quantity before + transferred quantity
- source value reduction = destination value increase = FIFO moved value
- retry of a POSTED transfer creates no additional ledger events or stock movement

## Security
- tenant context is mandatory;
- source and destination outlets are independently authorized;
- warehouse ownership is checked;
- cross-tenant foreign keys remain enforced;
- RLS/FORCE RLS applies to transfer header and lines.

## CI evidence
The Phase 6A regression proves FIFO transfer, stock/value conservation, immutable ledger evidence, idempotent retry, and denial of an unauthorized destination outlet.

## Boundary
No UI, KDS, BOM, loyalty, analytics, or payment features are added. Phase 5 production UAT remains a separate production gate.
