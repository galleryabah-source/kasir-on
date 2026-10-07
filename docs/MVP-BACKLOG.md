# KASIRA MVP Backlog

## P0 — Must have

### Platform
- [ ] repository/monorepo structure
- [ ] environment strategy
- [ ] CI baseline
- [ ] migration runner
- [ ] structured logging
- [ ] error tracking

### Identity
- [ ] tenant
- [ ] outlet
- [ ] warehouse
- [ ] device
- [ ] user
- [ ] role/permission
- [ ] device registration/revocation

### Catalog
- [ ] product
- [ ] SKU
- [ ] variant
- [ ] barcode
- [ ] versioned price
- [ ] outlet price

### POS
- [ ] cart
- [ ] sale
- [ ] local persistence
- [ ] cash payment
- [ ] QRIS integration boundary
- [ ] receipt
- [ ] hold/resume
- [ ] refund/void approval boundary

### Shift/Cash
- [ ] opening
- [ ] movement
- [ ] expected cash
- [ ] actual cash
- [ ] closing
- [ ] variance

### Inventory
- [ ] stock ledger
- [ ] opening stock
- [ ] goods receipt
- [ ] sale deduction
- [ ] adjustment
- [ ] stock opname
- [ ] cost model

### Sync
- [ ] outbox
- [ ] idempotency
- [ ] server ACK
- [ ] retry
- [ ] cursor
- [ ] conflict record
- [ ] reconciliation

### Audit
- [ ] audit log
- [ ] correlation IDs
- [ ] high-risk action trail

## P1 — After pilot
- [ ] tables/floor plan
- [ ] KDS
- [ ] BOM/recipe
- [ ] loyalty
- [ ] campaign messaging
- [ ] multi-outlet transfers
- [ ] accounting exports

## P2 — Premium
- [ ] AI assistant
- [ ] anomaly detection
- [ ] demand forecasting
- [ ] menu engineering
- [ ] semantic BI
- [ ] omnichannel
- [ ] franchise/white-label

## Never bypass

A feature cannot be marked done if it changes business state without:
1. domain validation
2. auditability
3. idempotency where applicable
4. authorization
5. test evidence
6. rollback/migration plan when schema changes
