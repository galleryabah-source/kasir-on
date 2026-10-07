# Phase 6B — Runtime Outlet Isolation

## Purpose
Prove that runtime authorization cannot cross an explicitly assigned outlet boundary or tenant boundary.

## Canonical rules
- tenant context is mandatory
- assigned outlet scope is allowed
- unassigned outlet scope is denied
- `outlet.scope_all` is an explicit tenant-wide permission
- cross-tenant access is denied
- trusted devices are bound to their outlet
- revoked devices are denied
- this phase changes authorization only; it does not change ledger semantics

## Evidence gate
The regression must prove:
1. assigned outlet PASS
2. unassigned outlet DENY
3. `outlet.scope_all` PASS
4. cross-tenant DENY
5. device outlet mismatch DENY
6. revoked device DENY
7. RLS remains FORCE RLS
8. full CI regression GREEN

Phase 6B engineering PASS does not imply Phase 5 production UAT PASS.
