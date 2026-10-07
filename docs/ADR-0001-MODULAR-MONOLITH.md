# ADR-0001 — Modular Monolith First

Status: Accepted in Phase 0.

## Decision

Start KASIRA as a modular monolith with strict domain boundaries.

## Rationale

Premature microservices would multiply:
- deployment complexity
- distributed transaction problems
- observability requirements
- schema/version coordination
- local development overhead

KASIRA's hard problem is correctness across offline/local/server state, not service count.

## Initial modules

- identity
- tenant
- catalog
- order
- payment
- cash
- inventory
- sync
- audit
- reporting

## Extraction rule

A module may become a service only after:
1. measurable scaling/ownership boundary exists
2. independent deployment provides material value
3. data ownership is explicit
4. failure mode is understood
5. operational cost is justified

No service extraction merely for architectural fashion.
