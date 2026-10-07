# UX Discovery — Phase 0

## Primary checkout flow

```
Open Shift
 -> Search/Scan
 -> Cart
 -> Discount (if allowed)
 -> Payment
 -> Receipt
 -> Ready for next customer
```

## Offline UX

The cashier must see:
- clear offline indicator
- transaction success after local commit
- sync status without blocking checkout
- actionable error only when business action is actually required

Do not expose technical jargon such as "HTTP 503" to cashiers.

## Sync UX

Back office/device diagnostics can show:
- pending transactions
- last successful sync
- oldest pending transaction
- conflict/reconciliation warning

## Error principles

1. Never erase a locally committed transaction because sync failed.
2. Never force a cashier to retry payment blindly.
3. Always show whether an operation is committed, pending, failed, or requires review.
4. High-risk actions require explicit approval.

## Owner dashboard Phase 0 scope

Only operational signals:
- today's net sales
- payment mix
- cash variance
- pending sync
- inventory exceptions
- outlet health

Detailed analytics are later.
