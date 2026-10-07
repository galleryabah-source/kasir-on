export class CanonicalSyncServer {
  constructor(){this.idempotency=new Map();this.events=new Map();this.sequence=0;this.cursor=0;this.rejectedDevices=new Set();}
  revokeDevice(deviceId){this.rejectedDevices.add(deviceId);}
  accept(event){
    if(this.rejectedDevices.has(event.payload?.deviceId))return {status:"CONFLICT",code:"DEVICE_REVOKED",message:"Device revoked"};
    const requestHash=event.requestHash??JSON.stringify(event.payload),existing=this.idempotency.get(event.idempotencyKey);
    if(existing){
      if(existing.requestHash!==requestHash)return {status:"CONFLICT",code:"IDEMPOTENCY_KEY_REUSE",message:"Idempotency key reused with different payload"};
      return {status:"DUPLICATE",serverEventId:existing.eventId,serverSequence:existing.serverSequence,serverCursor:existing.serverCursor};
    }
    this.sequence++;this.cursor++;
    const record={eventId:event.eventId,tenantId:event.tenantId,aggregateId:event.aggregateId,idempotencyKey:event.idempotencyKey,requestHash,event,serverSequence:this.sequence,serverCursor:this.cursor};
    this.idempotency.set(event.idempotencyKey,record);this.events.set(event.eventId,record);
    return {status:"ACK",serverEventId:event.eventId,serverSequence:this.sequence,serverCursor:this.cursor};
  }
  reconciliationTotals({tenantId,deviceId}){
    const accepted=[...this.events.values()].filter(x=>x.tenantId===tenantId&&(!deviceId||x.event.payload?.deviceId===deviceId));
    return {transactionCount:accepted.length,totalMinor:accepted.reduce((n,x)=>n+(x.event.payload?.totalMinor??0),0),paymentTotalMinor:accepted.reduce((n,x)=>n+(x.event.payload?.payment?.amountMinor??0),0),outstandingSyncCount:0};
  }
}
