export function assertPositiveQuantity(quantity:number):void {
  if(!Number.isFinite(quantity)||quantity<=0) throw new Error("quantity must be greater than zero");
}
export function assertNonNegativeMoney(amountMinor:bigint):void {
  if(amountMinor<0n) throw new Error("money amount cannot be negative");
}
export function assertTenantContext(tenantId?:string|null):asserts tenantId is string {
  if(!tenantId) throw new Error("tenant context is required");
}