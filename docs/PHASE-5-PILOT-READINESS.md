# Phase 5 — Pilot Readiness: 5–10 Outlets

## Objective
Prove KASIRA is operationally ready for a controlled real-world pilot without changing the canonical transaction, sync, inventory, or finance lifecycle.

## Pilot gate thresholds
| Evidence | PASS threshold |
|---|---:|
| Pilot outlets | 5–10 completed |
| Checkout p95 | <= 1,500 ms |
| Offline duration | >= 24 h |
| Sync success | >= 99% |
| Reconciliation exceptions | <= 1% |
| Payment success | >= 99% |
| Inventory integrity | 100% |
| Cashier adoption | >= 80% |
| Uptime | >= 99% |
| Open P0/P1 incidents | 0 |

## Evidence model
- `pilot_run`: pilot identity and gate status.
- `pilot_outlet`: participating outlets and cashier adoption.
- `pilot_metric`: measured operational metrics with evidence payload.
- `support_incident`: operational support and severity tracking.
- `uptime_heartbeat`: availability evidence.
- `pilot_gate(...)`: deterministic server-side readiness gate.

All Phase 5 operational tables are tenant-scoped and FORCE RLS.

## Synthetic gate
`scripts/phase5-pilot.mjs` runs a five-outlet offline-first pilot:
- 100 local transactions.
- local atomic checkout timing.
- 24-hour disconnected operation is represented by evidence state; the harness does not sleep for 24 hours.
- one post-acceptance ACK timeout exercises retry/idempotency.
- all transactions are synchronized.
- reconciliation is required to PASS for every outlet.
- payment and cashier adoption are measured.
- no P0/P1 incidents and 100% uptime are asserted in the synthetic environment.

This is a readiness harness, not proof that a production organization has already operated for 24 hours.

## Production UAT
A real pilot requires evidence from the selected 5–10 outlets:
1. Record actual checkout latency samples.
2. Record actual offline intervals.
3. Record every sync attempt/outcome.
4. Run reconciliation at each pilot close.
5. Record payment provider success/variance.
6. Run inventory ledger/projection integrity checks.
7. Record active vs enrolled cashiers.
8. Record every support incident.
9. Emit periodic uptime heartbeats.
10. Run `kasira.pilot_gate(...)` before declaring operational readiness.

## Non-goals
- No Phase 6 capability.
- No new POS business workflow.
- No automatic reconciliation repair.
- No production data fabrication.
- No bypass of the canonical ledger.

## Exit
Phase 5 closes only when the automated readiness harness and controlled production UAT evidence both pass. Phase 6 remains blocked until explicit approval.
