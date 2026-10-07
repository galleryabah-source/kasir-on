# KASIRA Blueprint

## 1. Product Positioning

KASIRA adalah Business Operating System dengan POS sebagai entry point. Produk dibangun untuk UMKM naik kelas, restoran/kafe, retail multi-cabang, dan franchise.

### Priority wedge

Mulai dari F&B 1–3 outlet, tetapi core domain dibuat generic sehingga retail/service dapat ditambahkan sebagai vertical modules tanpa membuat core kedua.

## 2. Capability Architecture

```
                         KASIRA
             BUSINESS OPERATING SYSTEM
                           |
        +------------------+------------------+
        |                  |                  |
   TRANSACTION           LEDGER             IDENTITY
        |                  |                  |
      Sales             Stock               User
      Orders            Cash                Device
      Payments           COGS               Outlet
        |                  |                  |
        +------------------+------------------+
                           |
                  SYNC / RECONCILIATION
                           |
                  CANONICAL DATA LAYER
                           |
             +-------------+-------------+
             |             |             |
          Reporting     Analytics       AI
```

## 3. Canonical Ledgers

### Sales Ledger
Order creation, item, discount, tax, void, refund, settlement references.

### Inventory Ledger
Purchase receipt, sale deduction, transfer, adjustment, stock opname, cost layers.

### Cash Ledger
Opening float, sale settlement, cash-in/out, expected cash, actual cash, variance, closing.

### Payment Ledger
Payment intent, authorization, capture, failure, refund, settlement/reconciliation.

**Saldo adalah projection. Ledger adalah canonical truth.**

## 4. Identity Chain

Setiap business mutation membawa:
- tenant_id
- outlet_id
- device_id
- actor_id
- event_id
- transaction_id
- aggregate_id
- event_type
- event_version
- occurred_at
- recorded_at
- idempotency_key
- correlation_id
- causation_id

## 5. Offline-First

POS harus dapat menyelesaikan transaksi tanpa server.

```
UI -> Local DB commit -> Outbox -> Sync -> Server accept -> ACK -> Reconciliation
```

Sync states:
- LOCAL_ONLY
- QUEUED
- SYNCING
- SYNCED
- CONFLICT
- FAILED
- RECONCILED

## 6. Conflict Resolution

Konflik tidak boleh diselesaikan secara diam-diam.

Jenis konflik:
- duplicate
- update collision
- stock collision
- payment collision
- master-data conflict

Policy konflik harus deterministik dan menghasilkan evidence/reconciliation record.

## 7. Reconciliation

Minimal reconciliation chain:

```
Device local transactions
          =
Server canonical transactions
          =
Ledger totals
          =
Projection totals
```

Mismatch menghasilkan status RECONCILIATION_REQUIRED.

## 8. Master Data

```
Product
  -> SKU
    -> Variant
      -> Outlet Price
      -> Inventory
```

Gunakan global product identity dan versioned pricing.

## 9. Pricing Engine

Pricing tidak boleh berada di UI.

```
Base Price
 -> Outlet Price
 -> Customer Tier
 -> Promotion
 -> Voucher
 -> Discount
 -> Tax
 -> Rounding
 -> Final Price
```

Engine harus deterministic.

## 10. Security

- tenant isolation
- RBAC
- MFA untuk privileged accounts
- device trust/revocation
- encrypted transport
- secret management
- audit trail
- no card PAN storage
- tokenized payment integrations
- PDP-aware data governance

## 11. Operational Control Plane

SaaS operator membutuhkan control plane untuk:
- tenants
- outlets
- devices
- app versions
- sync health
- payment health
- incidents
- feature flags
- subscription state
- audit

## 12. Feature Flags

Release capability secara bertahap:
1 outlet -> pilot tenant -> 10% -> 50% -> 100%.

## 13. Hardware Abstraction

Gunakan KASIRA Hardware Interface:
- printer
- scanner
- cash drawer
- scale
- EDC
- QR display

Vendor-specific drivers berada di adapter layer.

## 14. Data & AI

AI hanya membaca canonical semantic layer untuk query analytics. AI tidak boleh mengubah financial/stock records tanpa human approval dan domain validation.

## 15. Non-goals untuk MVP

- Kubernetes sebagai requirement
- public plugin marketplace
- arbitrary marketplace integrations
- unrestricted AI actions
- full franchise white-label
- every hardware vendor
- multi-vertical parity

Semua itu setelah core reliability terbukti.
