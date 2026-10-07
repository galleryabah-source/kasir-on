import { randomUUID } from "node:crypto";
import { OfflineDomainError, ERR } from "./errors.mjs";
const now=()=>new Date().toISOString();
export class OfflinePOSEngine {
  constructor(store, deviceId) { this.store=store; this.deviceId=deviceId; }
  context() {
    const d=this.store.getDevice(this.deviceId);
    if (!d || d.trust_status !== "ACTIVE") throw new OfflineDomainError(ERR.DEVICE_NOT_TRUSTED,"Device is not trusted",{deviceId:this.deviceId});
    return d;
  }
  openShift({shiftId=randomUUID(),openingCashMinor=0}) {
    const d=this.context();
    return this.store.createShift({shiftId,tenantId:d.tenant_id,outletId:d.outlet_id,deviceId:d.device_id,actorId:d.actor_id,openingCashMinor,openedAt:now()});
  }
  closeShift({shiftId,closingCashMinor=0}) { this.context(); return this.store.closeShift({shiftId,closingCashMinor,closedAt:now()}); }
  sell({orderId=randomUUID(),businessDate=new Date().toISOString().slice(0,10),items,subtotalMinor,discountMinor=0,taxMinor=0,totalMinor,paymentMinor,receiptNumber}) {
    const d=this.context(), shift=this.store.openShiftForDevice(this.deviceId);
    if (!shift) throw new OfflineDomainError(ERR.SHIFT_NOT_OPEN,"An open shift is required");
    if (!Array.isArray(items) || items.length===0) throw new OfflineDomainError(ERR.INVALID_ORDER,"Sale requires at least one item");
    if (![subtotalMinor,discountMinor,taxMinor,totalMinor,paymentMinor].every(Number.isInteger)) throw new OfflineDomainError(ERR.INVALID_ORDER,"Money must be integer minor units");
    if (subtotalMinor<0||discountMinor<0||taxMinor<0||totalMinor<0||paymentMinor<0 || totalMinor!==subtotalMinor-discountMinor+taxMinor)
      throw new OfflineDomainError(ERR.INVALID_ORDER,"Order total invariant failed");
    if (paymentMinor!==totalMinor) throw new OfflineDomainError(ERR.INVALID_PAYMENT,"Cash payment must equal total");
    const normalized=items.map(i=>{
      if (!(i.quantity>0) || !Number.isFinite(i.quantity) || !Number.isInteger(i.unitPriceMinor) || i.unitPriceMinor<0)
        throw new OfflineDomainError(ERR.INVALID_ORDER,"Invalid line item");
      const discount=i.discountMinor??0, tax=i.taxMinor??0, line=Math.round(i.unitPriceMinor*i.quantity)-discount+tax;
      if (discount<0||tax<0||line<0||i.lineTotalMinor!==line) throw new OfflineDomainError(ERR.INVALID_ORDER,"Line total invariant failed");
      return {...i,orderItemId:i.orderItemId??randomUUID(),discountMinor:discount,taxMinor:tax,lineTotalMinor:line};
    });
    const occurredAt=now(), correlationId=randomUUID(), idemKey=`sale:${d.tenant_id}:${this.deviceId}:${orderId}`;
    const payload={orderId,tenantId:d.tenant_id,outletId:d.outlet_id,deviceId:d.device_id,actorId:d.actor_id,businessDate,
      subtotalMinor,discountMinor,taxMinor,totalMinor,items:normalized,payment:{method:"CASH",amountMinor:paymentMinor}};
    return this.store.insertSaleAtomic({
      order:{orderId,tenantId:d.tenant_id,outletId:d.outlet_id,deviceId:d.device_id,actorId:d.actor_id,shiftId:shift.shift_id,
        businessDate,subtotalMinor,discountMinor,taxMinor,totalMinor,occurredAt,createdAt:occurredAt},
      items:normalized,payment:{paymentId:randomUUID(),amountMinor:paymentMinor,occurredAt},
      receipt:{receiptId:randomUUID(),receiptNumber:receiptNumber??`R-${businessDate.replaceAll("-","")}-${orderId.slice(0,8).toUpperCase()}`,payload,createdAt:occurredAt},
      outbox:{eventId:randomUUID(),tenantId:d.tenant_id,aggregateId:orderId,eventType:"SALE_COMMIT",eventVersion:1,occurredAt,
        idempotencyKey:idemKey,correlationId,causationId:null,payload,createdAt:occurredAt}
    });
  }
}
