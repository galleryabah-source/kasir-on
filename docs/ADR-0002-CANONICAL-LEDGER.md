# ADR-0002 — Canonical Ledger over Mutable Business Balances

Status: Accepted in Phase 0.

## Decision

Financial, payment, cash, and inventory state are represented through append-oriented canonical records. Balances are projections.

## Consequences

Positive:
- forensic traceability
- rebuildable projections
- safer offline sync
- reconciliation
- dispute investigation

Tradeoff:
- more domain modeling
- projection maintenance
- more explicit correction workflows

## Rule

Never repair a historical financial transaction by mutating it silently. Use compensating/adjusting records.
