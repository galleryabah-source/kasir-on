# KASIRA Engineering Constitution

## A. Canonical Truth
1. Ledger/event menjadi sumber kebenaran.
2. Projection dapat dibangun ulang.
3. Financial records immutable.
4. Hard delete untuk transaksi bisnis dilarang.

## B. Transaction Integrity
1. Semua mutation memiliki UUID/event identity.
2. Semua API mutation mendukung idempotency bila operasi dapat di-retry.
3. Retry tidak boleh menyebabkan duplicate business effect.
4. Void/refund dilakukan melalui compensating event.

## C. Offline Safety
1. POS tidak boleh memerlukan server untuk menyelesaikan transaksi.
2. Local commit terjadi sebelum sync.
3. Sync dapat diulang tanpa duplicate.
4. Conflict menghasilkan evidence.

## D. Multi-Tenancy
1. Setiap business row memiliki tenant boundary.
2. Authorization diperiksa di service layer.
3. Database RLS menjadi defense-in-depth bila sesuai.
4. Tidak ada cross-tenant query yang tidak disengaja.

## E. Release Governance
Definition of Done minimum:
- functional test
- unit test
- integration test
- authorization test
- migration test
- offline test
- sync test
- financial/inventory integrity test
- observability check
- UAT
- production verification

## F. Auditability

Sistem harus dapat menjawab:
- siapa
- perangkat mana
- outlet mana
- kapan
- melakukan apa
- berdasarkan transaksi apa
- mengubah state apa
- hasil akhirnya apa

## G. Operational Safety
- feature flag untuk risky changes
- canary rollout
- backup verification
- restore test
- incident runbook
- rollback path

## H. UX Principle

Kasir mendapat jalur tercepat. Complex controls berada di back office atau approval workflow. Error harus actionable dan tidak menghilangkan transaksi lokal yang sudah committed.
