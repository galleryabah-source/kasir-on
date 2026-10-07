# ADR-0003 — Local Commit + Outbox + Idempotent Server Ingestion

Status: Accepted in Phase 0.

## Decision

A POS transaction is committed locally before asynchronous server synchronization.

## Protocol

Local:
1. validate
2. write transaction
3. write outbox entry atomically
4. acknowledge cashier

Cloud:
1. authenticate device
2. validate schema
3. check idempotency
4. append canonical records
5. acknowledge with server identity/cursor

## Repeated delivery

Same idempotency key must not create a second business effect.

## Conflict

Conflicts are explicit records. No silent last-write-wins for financial state.
