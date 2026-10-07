const backoff=(attempt)=>new Date(Date.now()+Math.min(300000,1000*2**Math.max(0,attempt-1))).toISOString();
export class SyncEngine {
  constructor(store, server) { this.store=store; this.server=server; }
  async drain(limit=20) {
    const events=this.store.pendingOutbox(limit), results=[];
    for (const row of events) {
      this.store.markSending(row.event_id);
      try {
        const response=await this.server.accept({
          eventId:row.event_id,tenantId:row.tenant_id,aggregateId:row.aggregate_id,eventType:row.event_type,
          eventVersion:row.event_version,idempotencyKey:row.idempotency_key,correlationId:row.correlation_id,
          causationId:row.causation_id,payload:JSON.parse(row.payload_json)
        });
        if (response?.status==="ACK" || response?.status==="DUPLICATE") {
          this.store.ack(row.event_id); results.push({eventId:row.event_id,status:"ACKED"}); continue;
        }
        if (response?.status==="CONFLICT") {
          const conflictId=this.store.conflict(row.event_id,response.code??"SYNC_CONFLICT",response.message??"Sync conflict",response);
          results.push({eventId:row.event_id,status:"CONFLICT",conflictId}); continue;
        }
        throw new Error(response?.message??"Unknown sync response");
      } catch (error) {
        this.store.retry(row.event_id,error.message,backoff(row.attempts+1));
        results.push({eventId:row.event_id,status:"RETRY",error:error.message});
      }
    }
    return results;
  }
}
export class DeterministicTestServer {
  constructor() { this.keys=new Map(); this.events=new Map(); this.revokedDevices=new Set(); }
  revokeDevice(deviceId){this.revokedDevices.add(deviceId);}
  async accept(event) {
    const deviceId=event.payload?.deviceId;
    if (this.revokedDevices.has(deviceId)) return {status:"CONFLICT",code:"DEVICE_REVOKED",message:"Device revoked"};
    const existing=this.keys.get(event.idempotencyKey);
    if (existing) return {status:"DUPLICATE",serverEventId:existing};
    this.keys.set(event.idempotencyKey,event.eventId); this.events.set(event.eventId,event);
    return {status:"ACK",serverEventId:event.eventId};
  }
}
