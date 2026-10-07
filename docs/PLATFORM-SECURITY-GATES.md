# Platform & Security Gates (#7 / #8)

## Scope
This document separates governance capability issues #7 and #8 from product Phase numbering.

### #7 Platform
- CI executes canonical schema + unit/offline/sync/inventory/finance/pilot regression.
- Release records capture environment, commit SHA, status, deploy/rollback timestamps and correlation ID.
- Feature flags are tenant-scoped and environment-scoped.
- Operational events carry tenant/outlet/device/actor/transaction/correlation context.
- Rollback is represented explicitly as a release state; no mutation of canonical ledgers is required.

### #8 Security
- PostgreSQL remains defense-in-depth for tenant isolation.
- Permissions are explicit capabilities, separate from roles.
- User outlet scope is explicit; no implicit cross-outlet access is granted.
- Device trust is explicit and revocation is testable.
- High-risk capabilities can be permission-gated.

## Evidence gate
The CI workflow must pass schema, regression and security-platform integration checks. Production closure additionally requires runtime authorization verification, device revoke verification and rollback/observability evidence.

## Boundary
No business ledger, offline protocol, reconciliation semantics, or Phase 5 production data is fabricated or modified by these foundation migrations.
