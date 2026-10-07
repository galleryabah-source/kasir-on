# KASIRA Phase 0 PRD

## Product thesis

KASIRA is a Business Operating System for Indonesian F&B operators. POS is the primary transaction surface; the platform's durable value comes from trustworthy transaction, payment, cash, inventory, customer, and operational data.

## Initial ICP

Primary:
- F&B owner/operator
- 1–3 outlets
- 1–5 POS terminals per outlet
- meaningful inventory/recipe complexity
- owner needs remote visibility
- operational pain when internet or devices fail

Secondary after pilot:
- 4–20 outlet F&B chains
- franchise operators
- retail businesses with similar transaction/inventory needs

## Primary jobs-to-be-done

1. Complete a sale quickly even when internet is unavailable.
2. Know that payment, cash, and sale totals reconcile.
3. Know why stock changed.
4. Close a shift without spreadsheet reconciliation.
5. Owner can see business health remotely.
6. Recover confidently from device/network/provider failures.

## MVP value proposition

"Kasir tetap jalan saat internet mati, dan ketika online kembali KASIRA memastikan transaksi, pembayaran, kas, dan stok tersinkron tanpa transaksi ganda serta dapat diaudit."

## MVP boundaries

### Included
- catalog
- barcode/search
- cart/checkout
- cash
- QRIS integration boundary
- receipt
- shift/cash closing
- offline local transaction
- sync/outbox/idempotency
- reconciliation
- stock ledger foundation
- audit
- owner operational dashboard foundation

### Deferred
- broad marketplace integrations
- full CRM campaigns
- loyalty
- KDS
- self-order
- AI autonomous actions
- franchise management
- public API marketplace

## Non-functional product requirements

- standard local checkout must not wait for server
- duplicate business effect on retry: zero
- every financial mutation auditable
- tenant isolation mandatory
- projection must be reconstructable from canonical records
- production deployment must have rollback path
- backup restore must be tested

## Success metrics for pilot

- median local checkout <= 1 second target
- sync success >= 99.9% target after stable release
- duplicate business effect = 0
- unresolved reconciliation exceptions = 0 before financial closing
- crash-free POS sessions >= 99.5% target
- support tickets per active outlet tracked weekly
- successful shift closing >= 99.9%

Targets are engineering/product hypotheses and must be validated during pilot.

## Pricing hypothesis

Initial packaging should optimize for adoption rather than maximum feature gating:
- Starter: core POS for one outlet
- Pro: inventory, multi-terminal, advanced controls, analytics
- Premium: multi-outlet, advanced reconciliation, CRM/AI, integrations
- Enterprise: custom controls, SLA, franchise, advanced integration

Exact prices are intentionally not frozen in Phase 0; willingness-to-pay research must precede commercial lock.
