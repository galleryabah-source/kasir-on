# KASIRA Roadmap

Roadmap menggunakan capability gates, bukan hanya daftar fitur.

| Phase | Focus | Primary Gate |
|---|---|---|
| 0 | Discovery + Architecture | Architecture Review PASS |
| 1 | Canonical Core | Domain & Ledger Integrity PASS |
| 2 | Offline POS | Offline Transaction PASS |
| 3 | Sync + Reconciliation | Zero-loss / Idempotent Sync PASS |
| 4 | Inventory + Finance | Ledger Integrity PASS |
| 5 | Pilot 5–10 outlets | Production UAT PASS |
| 6 | Multi-outlet | Tenant/Outlet Isolation PASS |
| 7 | F&B | KDS/BOM Stability PASS |
| 8 | CRM + Loyalty | Points/Financial Integrity PASS |
| 9 | Analytics | Semantic Data Contract PASS |
| 10 | AI | AI Safety + Accuracy PASS |
| 11 | Omnichannel | Integration Contract PASS |
| 12 | Ecosystem | Public API Governance PASS |

## Phase 0 — Discovery & Architecture
Deliverables:
- PRD
- competitor analysis
- 15–20 user interviews
- UX prototype
- pricing hypothesis
- canonical domain model
- threat model
- ADR baseline

Exit: product scope + architecture review PASS.

## Phase 1 — Canonical Core
Build tenant/outlet/device/user, catalog, order/payment primitives, ledgers, audit, migrations, auth/RBAC.

Exit: deterministic business rules and green integrity tests.

## Phase 2 — Offline POS
Build SQLite local store, atomic local transaction, outbox, receipt, cash payment, shift, device trust, offline UX.

Exit: standard transaction succeeds with API unavailable.

## Phase 3 — Sync & Reconciliation
Build idempotency, sequence/cursor, retry, conflict model, reconciliation engine, telemetry.

Exit: repeated sync cannot duplicate business effects and reconciliation PASS.

## Phase 4 — Inventory & Finance
Build stock ledger, cost layer, purchase, stock opname, cash closing, payment reconciliation, variance workflow.

Exit: ledger/projection integrity PASS.

## Phase 5 — Pilot
Target 5–10 real outlets.

Measure checkout latency, offline time, sync success, reconciliation exceptions, cashier adoption, support tickets, uptime.

Exit: production UAT + operational readiness PASS.

## Phase 6–12
Expand only after core reliability is proven. Each phase requires design review, test plan, migration strategy, rollback path and production verification.

## Strategic product wedge
Initial commercial focus: F&B 1–3 outlets.

Then expand to retail, service, franchise, and pharmacy/minimarket as domain permits.

Core remains shared; vertical modules are isolated.
