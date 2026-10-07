# KASIRA Threat Model — Phase 0

## Assets

- money/payment state
- inventory state
- customer PII
- credentials
- device identity
- tenant data
- audit history
- business reports

## Threats

| Threat | Impact | Primary control |
|---|---|---|
| Lost POS device | High | device trust + revoke + local encryption |
| Duplicate sync | Critical | idempotency |
| Cross-tenant access | Critical | tenant scoping + RLS defense |
| Privilege escalation | Critical | RBAC + approval matrix |
| Fraudulent void/refund | High | approval + immutable audit |
| Stock manipulation | High | ledger + authorization |
| Payment mismatch | Critical | payment ledger + reconciliation |
| Secret leak | High | secret manager + rotation |
| Database corruption | Critical | backups + restore drills |
| Supply-chain compromise | High | dependency scanning + signed/reviewed releases |
| PII leakage | High | minimization + access logging + retention |

## Security gates before production

- tenant isolation tests
- authorization matrix tests
- device revoke test
- idempotency abuse test
- audit tamper-resistance test
- backup restore test
- dependency/security scan
