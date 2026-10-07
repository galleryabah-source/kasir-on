# KASIRA — Business Operating System for Retail & F&B

KASIRA adalah platform POS premium Indonesia yang dirancang bukan sekadar sebagai kasir, tetapi sebagai Business Operating System untuk retail, F&B, jasa, dan multi-outlet.

## Vision

Membangun POS yang tetap dapat bertransaksi saat offline, menjaga integritas uang dan stok, memiliki audit trail yang dapat ditelusuri, dan menyediakan analytics/AI di atas data bisnis canonical.

## Core Differentiators

- Offline-first transaction processing
- Canonical transaction, stock, cash, and payment ledgers
- Deterministic sync + idempotency + reconciliation
- Multi-tenant dan multi-outlet
- Device trust dan RBAC/approval matrix
- Auditability dan forensic reconstruction
- Indonesia-ready: QRIS, e-wallet, tax, printer/hardware ecosystem
- Analytics dan AI berbasis semantic business layer

## Architectural North Star

```
POS / Back Office / Owner / Self-order
                |
                v
        API / Sync Gateway
                |
        Modular Monolith Core
                |
   +------------+-------------+
   |            |             |
Sales Ledger  Stock Ledger  Cash/Payment Ledger
   |            |             |
   +------------+-------------+
                |
         Canonical Data Layer
                |
      Reporting / Analytics / AI
```

## Engineering Rule

**UI tidak boleh menjadi sumber kebenaran bisnis.**

Semua perubahan bisnis penting harus melewati domain command/service dan menghasilkan immutable business records/events. Projection seperti dashboard, saldo stok, dan laporan dibangun dari canonical data.

## Initial Technology Direction

- POS: Flutter + SQLite
- Back Office: Next.js
- Backend: NestJS modular monolith
- Database: PostgreSQL
- Cache / queue: Redis
- Object storage: S3-compatible
- Deployment awal: Docker + CI/CD
- Observability: structured logs + metrics + Sentry

Kubernetes tidak menjadi prasyarat MVP. Platform dioptimalkan untuk correctness dan operability terlebih dahulu.

## Project Status

Repository ini dimulai sebagai architecture-first foundation. Fase pertama adalah membangun canonical core, offline engine, sync, reconciliation, dan financial/inventory integrity sebelum memperluas feature surface.

## Documentation

- [Blueprint](docs/BLUEPRINT.md)
- [Engineering Constitution](docs/ENGINEERING-CONSTITUTION.md)
- [Roadmap](docs/ROADMAP.md)
- [Canonical Domain Model](docs/CANONICAL-DOMAIN.md)
- [Offline & Sync Protocol](docs/OFFLINE-SYNC.md)
- [Security & Privacy](docs/SECURITY-PRIVACY.md)
- [Observability & Operations](docs/OBSERVABILITY.md)
- [Disaster Recovery](docs/DISASTER-RECOVERY.md)
- [AI Governance](docs/AI-GOVERNANCE.md)
- [MVP Backlog](docs/MVP-BACKLOG.md)
