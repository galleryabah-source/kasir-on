# KASIRA Canonical Domain Model

## Hierarchy

```
Tenant
  -> Brand
    -> Outlet
      -> Warehouse
      -> Device
      -> User Assignment
      -> Shift

Product
  -> SKU
    -> Variant
      -> Modifier
      -> Recipe/BOM
      -> Price Version

Order
  -> OrderItem
  -> Discount
  -> Tax
  -> Payment

Inventory
  -> StockLedger
  -> CostLayer
  -> PurchaseOrder
  -> GoodsReceipt
  -> Transfer
  -> StockOpname

Customer
  -> LoyaltyAccount
  -> LoyaltyTransaction

Cash
  -> CashMovement
  -> CashClosing

Audit
  -> AuditLog
```

## Core aggregate boundaries

### Order
Owns order lifecycle. Does not directly mutate inventory balances.

### Payment
Owns payment lifecycle and provider reconciliation.

### Inventory
Owns stock ledger and stock projections.

### Shift
Owns operational cash lifecycle.

### Product
Owns canonical master data and versioned catalog state.

## Example transaction chain

```
SALE_CREATED
 -> PAYMENT_CAPTURED
 -> INVENTORY_DEDUCTED
 -> RECEIPT_ISSUED
 -> REPORTING_PROJECTION_UPDATED
```

Failure/retry must preserve causal identity and idempotency.
