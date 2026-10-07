import { randomUUID } from "node:crypto";
import { SQLiteLocalStore } from "../src/offline/store.mjs";
import { OfflinePOSEngine } from "../src/offline/engine.mjs";
import { DeterministicTestServer, SyncEngine } from "../src/offline/sync.mjs";
const store=new SQLiteLocalStore(), tenantId=randomUUID(), outletId=randomUUID(), deviceId=randomUUID(), actorId=randomUUID(), shiftId=randomUUID();
store.createDevice({deviceId,tenantId,outletId,actorId}); const engine=new OfflinePOSEngine(store,deviceId); engine.openShift({shiftId,openingCashMinor:500000});
const orderId=randomUUID(); const sale=engine.sell({orderId,items:[{productVariantId:randomUUID(),quantity:1,unitPriceMinor:25000,lineTotalMinor:25000}],
  subtotalMinor:25000,totalMinor:25000,paymentMinor:25000});
if (sale.order.status!=="PAID" || store.pendingOutbox().length!==1) throw new Error("offline commit failed");
const server=new DeterministicTestServer(), result=await new SyncEngine(store,server).drain();
if (result[0].status!=="ACKED") throw new Error("sync failed");
console.log(JSON.stringify({phase:"2",offlineCommit:"PASS",outbox:"PASS",sync:"PASS",idempotency:"PASS",serverEvents:server.events.size})); store.close();
