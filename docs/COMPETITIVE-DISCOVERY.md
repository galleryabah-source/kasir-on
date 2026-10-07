# Competitive Discovery — Indonesia POS

Research date: 2026-10-07.

## Competitor observations

### Olsera
Public product material positions Olsera around offline/online POS, inventory, multi-outlet, restaurant tables, split bills, kitchen display, recipes, CRM, promotions and multiple payment types. This means "feature completeness" alone is not a sufficient KASIRA moat.

Source: https://www.olsera.com/id/pos/features

### majoo
Public product material covers POS, accounting, inventory, CRM, owner app, employees, business analysis and online orders. Its F&B offering also covers multi-outlet operations and QR ordering. Inventory includes COGS, purchase orders, production, transfers, serial/batch and warehouse capabilities.

Sources:
https://majoo.id/produk
https://majoo.id/aplikasi-inventori

### iSeller / Qasir / other competitors
These remain relevant to the competitive landscape, but Phase 0 will not assume feature parity from unverified claims. Product decisions must be based on verified product behavior and actual customer interviews.

## Competitive conclusion

Do not compete on:
- "more features"
- generic dashboard count
- generic AI chatbot
- generic multi-outlet claims

Compete on:
1. Offline transaction correctness.
2. Deterministic sync and idempotency.
3. Reconciliation as a first-class product capability.
4. Immutable financial/inventory auditability.
5. Device trust and operational control.
6. Evidence-based business AI over canonical semantic data.

## Indonesia-specific constraints

QRIS should be integrated through licensed payment providers rather than treating QRIS as an independent arbitrary payment rail. Bank Indonesia directs merchants to use licensed PJP providers and obtain merchant identity through the provider.

Source: https://www.bi.go.id/id/publikasi/ruang-media/cerita-bi/Pages/cara-membuat-qris.aspx

Tax/e-invoice capability must remain integration-ready and versioned against current DJP requirements rather than hard-coded into the POS UI.

Sources:
https://www.pajak.go.id/id/peraturan/faktur-pajak-berbentuk-elektronik-e-faktur
https://www.pajak.go.id/id/peraturan/tata-cara-pembuatan-dan-pelaporan-faktur-pajak-berbentuk-elektronik

## Strategic implication

KASIRA should be "reliability-first POS" rather than "another all-in-one POS".
