const backoff=(attempt)=>new Date(Date.now()+Math.min(300000,1000*2**Math.max(0,attempt-1))).toISOString();

export class SyncProtocol {
  constructor(store,server,{telemetry=true}={}){this.store=store;this.server=server;this.telemetry=telemetry;}
  async drain(limit=20){
    const rows=this.store.pendingOutbox(limit),results=[];
    for(const row of rows){
      const started=Date.now(); this.store.markSending(row.event_id);
      try{
        const event={eventId:row.event_id,tenantId:row.tenant_id,aggregateId:row.aggregate_id,eventType:row.event_type,eventVersion:row.event_version,
          sequence:row.local_sequence,idempotencyKey:row.idempotency_key,correlationId:row.correlation_id,causationId:row.causation_id,payload:JSON.parse(row.payload_json)};
        const response=await this.server.accept(event),elapsed=Date.now()-started;
        if(response?.status==="ACK"||response?.status==="DUPLICATE"){
          this.store.ackWithCursor(row.event_id,response.serverCursor??null,response.serverSequence??null);
          if(this.telemetry)this.store.recordTelemetry(row,response.status==="DUPLICATE"?"DUPLICATE":"ACK",elapsed,null);
          results.push({eventId:row.event_id,status:"ACKED",serverCursor:response.serverCursor??null}); continue;
        }
        if(response?.status==="CONFLICT"||response?.status==="REJECTED"){
          const code=response.code??"SYNC_CONFLICT"; this.store.conflict(row.event_id,code,response.message??"Sync conflict",response);
          if(this.telemetry)this.store.recordTelemetry(row,response.status,elapsed,code);
          results.push({eventId:row.event_id,status:response.status,code}); continue;
        }
        throw new Error(response?.message??"Unknown sync response");
      }catch(error){
        this.store.retry(row.event_id,error.message,backoff(row.attempts+1));
        if(this.telemetry)this.store.recordTelemetry(row,"RETRY",Date.now()-started,"NETWORK_OR_TRANSIENT");
        results.push({eventId:row.event_id,status:"RETRY",error:error.message});
      }
    } return results;
  }
}

export class ReconciliationEngine {
  constructor(store,server){this.store=store;this.server=server;}
  run({tenantId,deviceId,periodStart,periodEnd}){
    const local=this.store.localTotals({tenantId,deviceId}),server=this.server.reconciliationTotals({tenantId,deviceId,periodStart,periodEnd}),reasons=[];
    if(local.transactionCount!==server.transactionCount)reasons.push("TRANSACTION_COUNT_MISMATCH");
    if(local.totalMinor!==server.totalMinor)reasons.push("SALES_TOTAL_MISMATCH");
    if(local.paymentTotalMinor!==server.paymentTotalMinor)reasons.push("PAYMENT_TOTAL_MISMATCH");
    if(local.outstandingSyncCount!==server.outstandingSyncCount)reasons.push("OUTSTANDING_SYNC_MISMATCH");
    return {status:reasons.length?"RECONCILIATION_REQUIRED":"PASS",reasons,local,server};
  }
}
