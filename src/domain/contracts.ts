export type UUID = string;
export interface TenantScoped { id: UUID; tenantId: UUID; }
export interface ActorContext {
  tenantId: UUID; outletId?: UUID; deviceId?: UUID; actorId?: UUID;
  correlationId: UUID; causationId?: UUID;
}
export type OrderStatus = "OPEN"|"PAID"|"VOIDED"|"REFUNDED";
export interface Money { currency:"IDR"; amountMinor: bigint; }
export interface OrderItemInput {
  productVariantId: UUID; quantity:number; unitPriceMinor:bigint;
}
export interface CreateOrderCommand {
  context:ActorContext; orderId:UUID; businessDate:string; items:OrderItemInput[];
}
export interface BusinessEvent {
  eventId:UUID; tenantId:UUID; aggregateId:UUID; eventType:string;
  eventVersion:number; occurredAt:string; recordedAt:string;
  idempotencyKey?:string; correlationId:UUID; causationId?:UUID;
}