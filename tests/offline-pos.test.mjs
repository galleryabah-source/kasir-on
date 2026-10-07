import test from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { SQLiteLocalStore } from "../src/offline/store.mjs";
import { OfflinePOSEngine } from "../src/offline/engine.mjs";
import { DeterministicTestServer, SyncEngine } from "../src/offline/sync.mjs";
import { ERR } from "../src/offline/errors.mjs";
function fixture(){
  const store=new SQLiteLocalStore(), ids={tenantId:randomUUID(),outletId:randomUUID(),deviceId:randomUUID(),actorId:randomUUID(),shiftId:randomUUID(),variantId:randomUUID()};
  store.createDevice(ids); return {store,engine:new OfflinePOSEngine(store,ids.deviceId),ids};
}
function saleArgs(ids, orderId=randomUUID()){ return {orderId,items:[{productVariantId:ids.variantId,quantity:2,unitPriceMinor:5000,lineTotalMinor:10000}],subtotalMinor:10000,discountMinor:0,taxMinor:0,totalMinor:10000,paymentMinor:10000}; }
test("device trust and shift gate",()=>{
  const {store,engine}=fixture(); assert.throws(()=>engine.sell(saleArgs({variantId:randomUUID()})),e=>e.code===ERR.SHIFT_NOT_OPEN);
  store.setDeviceTrust(engine.deviceId,"REVOKED"); assert.throws(()=>engine.openShift({}),e=>e.code===ERR.DEVICE_NOT_TRUSTED); store.close();
});
test("standard sale commits atomically while server is unavailable",()=>{
  const {store,engine,ids}=fixture(); engine.openShift({shiftId:ids.shiftId,openingCashMinor:100000}); const orderId=randomUUID(),r=engine.sell(saleArgs(ids,orderId));
  assert.equal(r.duplicate,false); assert.equal(r.order.status,"PAID"); assert.equal(r.order.payment.amount_minor,10000); assert.equal(store.pendingOutbox().length,1); store.close();
});
test("duplicate local submission has one business effect",()=>{
  const {store,engine,ids}=fixture(); engine.openShift({shiftId:ids.shiftId}); const orderId=randomUUID(),args=saleArgs(ids,orderId),a=engine.sell(args),b=engine.sell(args);
  assert.equal(a.duplicate,false); assert.equal(b.duplicate,true); assert.equal(store.all("SELECT COUNT(*) AS n FROM order_header").at(0).n,1); assert.equal(store.all("SELECT COUNT(*) AS n FROM outbox").at(0).n,1); store.close();
});
test("sync retry preserves local transaction",async()=>{
  const {store,engine,ids}=fixture(); engine.openShift({shiftId:ids.shiftId}); const orderId=randomUUID(); engine.sell(saleArgs(ids,orderId));
  let calls=0; const server={accept:async()=>{calls++; if(calls===1) throw new Error("API_UNAVAILABLE"); return {status:"ACK"};}},sync=new SyncEngine(store,server);
  const first=await sync.drain(); assert.equal(first[0].status,"RETRY"); assert.equal(store.getOrder(orderId).status,"PAID");
  store.exec("UPDATE outbox SET next_attempt_at=NULL WHERE aggregate_id=?",[orderId]); const second=await sync.drain(); assert.equal(second[0].status,"ACKED"); assert.equal(store.outboxStatus(first[0].eventId).status,"ACKED"); store.close();
});
test("same order with different payload is an idempotency conflict",()=>{
  const {store,engine,ids}=fixture(); engine.openShift({shiftId:ids.shiftId});
  const orderId=randomUUID(), args=saleArgs(ids,orderId); engine.sell(args);
  assert.throws(()=>engine.sell({...args,subtotalMinor:9000,totalMinor:9000,paymentMinor:9000,items:[{...args.items[0],unitPriceMinor:4500,lineTotalMinor:9000}]}),/IDEMPOTENCY_CONFLICT/);
  assert.equal(store.all("SELECT COUNT(*) AS n FROM order_header").at(0).n,1); store.close();
});
test("file-backed SQLite survives store reopen",()=>{
  const dir=mkdtempSync(join(tmpdir(),"kasira-offline-")), file=join(dir,"pos.db"), ids={tenantId:randomUUID(),outletId:randomUUID(),deviceId:randomUUID(),actorId:randomUUID(),shiftId:randomUUID(),variantId:randomUUID()};
  const first=new SQLiteLocalStore(file); first.createDevice(ids); const engine=new OfflinePOSEngine(first,ids.deviceId); engine.openShift({shiftId:ids.shiftId});
  const orderId=randomUUID(); engine.sell(saleArgs(ids,orderId)); first.close();
  const second=new SQLiteLocalStore(file); assert.equal(second.getOrder(orderId).status,"PAID"); assert.equal(second.pendingOutbox().length,1); second.close(); rmSync(dir,{recursive:true,force:true});
});
test("server idempotency makes duplicate delivery harmless",async()=>{
  const {store,engine,ids}=fixture(); engine.openShift({shiftId:ids.shiftId}); const orderId=randomUUID(); engine.sell(saleArgs(ids,orderId));
  const server=new DeterministicTestServer(),sync=new SyncEngine(store,server); const first=await sync.drain(); assert.equal(first[0].status,"ACKED");
  const row=store.all("SELECT * FROM outbox").at(0); store.exec("UPDATE outbox SET status='RETRY',next_attempt_at=NULL WHERE event_id=?",[row.event_id]);
  const second=await sync.drain(); assert.equal(second[0].status,"ACKED"); assert.equal(server.events.size,1); store.close();
});
test("revoked device becomes explicit sync conflict, never silent retry",async()=>{
  const {store,engine,ids}=fixture(); engine.openShift({shiftId:ids.shiftId}); const orderId=randomUUID(); engine.sell(saleArgs(ids,orderId));
  const server=new DeterministicTestServer(); server.revokeDevice(ids.deviceId); const result=await new SyncEngine(store,server).drain();
  assert.equal(result[0].status,"CONFLICT"); assert.equal(store.conflicts().length,1); assert.equal(store.outboxStatus(result[0].eventId).status,"CONFLICT"); store.close();
});
test("tenant identity is carried through every offline event",()=>{
  const {store,engine,ids}=fixture(); engine.openShift({shiftId:ids.shiftId}); const orderId=randomUUID(); engine.sell(saleArgs(ids,orderId));
  const row=store.all("SELECT tenant_id,payload_json FROM outbox").at(0); assert.equal(row.tenant_id,ids.tenantId); assert.equal(JSON.parse(row.payload_json).tenantId,ids.tenantId); store.close();
});
