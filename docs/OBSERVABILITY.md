# KASIRA Observability & Operations

## Required correlation fields
- trace_id
- correlation_id
- causation_id
- tenant_id
- outlet_id
- device_id
- actor_id
- transaction_id

## Metrics

### POS
- checkout latency
- local commit latency
- print latency
- device crash-free sessions

### Sync
- queue depth
- sync latency
- failed sync rate
- conflict rate
- oldest pending item age

### Payments
- success rate
- provider latency
- reconciliation mismatch

### Inventory
- negative-stock incidents
- ledger/projection mismatch
- adjustment frequency

### Platform
- API latency
- error rate
- database latency
- worker queue depth
- uptime

## Owner-facing health

```
Outlet
  -> POS health
  -> Sync health
  -> Payment health
  -> Printer health
  -> Inventory integrity
```

## Incident severity
- P0: financial/data integrity or broad outage
- P1: major business workflow unavailable
- P2: degraded non-critical capability
- P3: cosmetic/minor issue

Every P0/P1 incident gets an incident record and post-incident review.
