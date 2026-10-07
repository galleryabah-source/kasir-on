import { DatabaseSync } from "node:sqlite";
import { randomUUID } from "node:crypto";

const SCHEMA = `
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = FULL;
CREATE TABLE IF NOT EXISTS device (
  device_id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, outlet_id TEXT NOT NULL, actor_id TEXT NOT NULL,
  trust_status TEXT NOT NULL CHECK (trust_status IN ('ACTIVE','REVOKED')), created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS shift (
  shift_id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, outlet_id TEXT NOT NULL, device_id TEXT NOT NULL, actor_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('OPEN','CLOSED')), opening_cash_minor INTEGER NOT NULL CHECK(opening_cash_minor >= 0),
  closing_cash_minor INTEGER, opened_at TEXT NOT NULL, closed_at TEXT
);
CREATE TABLE IF NOT EXISTS order_header (
  order_id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, outlet_id TEXT NOT NULL, device_id TEXT NOT NULL, actor_id TEXT NOT NULL,
  shift_id TEXT NOT NULL, business_date TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('PAID','VOIDED')),
  currency TEXT NOT NULL DEFAULT 'IDR', subtotal_minor INTEGER NOT NULL CHECK(subtotal_minor >= 0),
  discount_minor INTEGER NOT NULL CHECK(discount_minor >= 0), tax_minor INTEGER NOT NULL CHECK(tax_minor >= 0),
  total_minor INTEGER NOT NULL CHECK(total_minor >= 0), occurred_at TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS order_item (
  order_item_id TEXT PRIMARY KEY, order_id TEXT NOT NULL REFERENCES order_header(order_id), product_variant_id TEXT NOT NULL,
  quantity REAL NOT NULL CHECK(quantity > 0), unit_price_minor INTEGER NOT NULL CHECK(unit_price_minor >= 0),
  discount_minor INTEGER NOT NULL CHECK(discount_minor >= 0), tax_minor INTEGER NOT NULL CHECK(tax_minor >= 0),
  line_total_minor INTEGER NOT NULL CHECK(line_total_minor >= 0)
);
CREATE TABLE IF NOT EXISTS payment (
  payment_id TEXT PRIMARY KEY, order_id TEXT NOT NULL REFERENCES order_header(order_id), method TEXT NOT NULL CHECK(method = 'CASH'),
  status TEXT NOT NULL CHECK(status = 'CAPTURED'), amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
  currency TEXT NOT NULL DEFAULT 'IDR', occurred_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS local_idempotency (
  idempotency_key TEXT PRIMARY KEY, request_hash TEXT NOT NULL, order_id TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS receipt (
  receipt_id TEXT PRIMARY KEY, order_id TEXT NOT NULL UNIQUE REFERENCES order_header(order_id),
  receipt_number TEXT NOT NULL UNIQUE, payload_json TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS outbox (
  event_id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, aggregate_id TEXT NOT NULL, event_type TEXT NOT NULL,
  event_version INTEGER NOT NULL, occurred_at TEXT NOT NULL, idempotency_key TEXT NOT NULL UNIQUE,
  correlation_id TEXT NOT NULL, causation_id TEXT, payload_json TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('PENDING','SENDING','ACKED','CONFLICT','RETRY')),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK(attempts >= 0), next_attempt_at TEXT, last_error TEXT, created_at TEXT NOT NULL, local_sequence INTEGER NOT NULL, server_sequence INTEGER, server_cursor INTEGER
);
CREATE TABLE IF NOT EXISTS sync_telemetry (id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, device_id TEXT, event_id TEXT, idempotency_key TEXT, attempt INTEGER NOT NULL, outcome TEXT NOT NULL, latency_ms INTEGER, error_code TEXT, observed_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS sync_conflict (
  conflict_id TEXT PRIMARY KEY, event_id TEXT NOT NULL UNIQUE, code TEXT NOT NULL, message TEXT NOT NULL,
  server_response_json TEXT, created_at TEXT NOT NULL, resolved_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_outbox_pending ON outbox(status, next_attempt_at, created_at);
CREATE INDEX IF NOT EXISTS idx_orders_shift ON order_header(shift_id, created_at);
`;

export class SQLiteLocalStore {
  constructor(filename = ":memory:") { this.db = new DatabaseSync(filename); this.db.exec(SCHEMA); }
  close() { this.db.close(); }
  tx(fn) {
    this.db.exec("BEGIN IMMEDIATE");
    try { const result = fn(); this.db.exec("COMMIT"); return result; }
    catch (e) { try { this.db.exec("ROLLBACK"); } catch {} throw e; }
  }
  exec(sql, params = []) { return this.db.prepare(sql).run(...params); }
  get(sql, params = []) { return this.db.prepare(sql).get(...params); }
  all(sql, params = []) { return this.db.prepare(sql).all(...params); }
  createDevice({deviceId, tenantId, outletId, actorId}) {
    this.exec("INSERT INTO device(device_id,tenant_id,outlet_id,actor_id,trust_status,created_at) VALUES(?,?,?,?,?,?)",
      [deviceId,tenantId,outletId,actorId,"ACTIVE",new Date().toISOString()]);
  }
  setDeviceTrust(deviceId, status) {
    if (!["ACTIVE","REVOKED"].includes(status)) throw new Error("invalid trust status");
    this.exec("UPDATE device SET trust_status=? WHERE device_id=?", [status,deviceId]);
  }
  getDevice(deviceId) { return this.get("SELECT * FROM device WHERE device_id=?", [deviceId]); }
  createShift({shiftId,tenantId,outletId,deviceId,actorId,openingCashMinor,openedAt}) {
    return this.tx(() => {
      const active = this.get("SELECT shift_id FROM shift WHERE device_id=? AND status='OPEN'", [deviceId]);
      if (active) throw new Error("SHIFT_ALREADY_OPEN");
      this.exec("INSERT INTO shift VALUES(?,?,?,?,?,?,?,?,?,?)",
        [shiftId,tenantId,outletId,deviceId,actorId,"OPEN",openingCashMinor,null,openedAt,null]);
      return this.get("SELECT * FROM shift WHERE shift_id=?", [shiftId]);
    });
  }
  closeShift({shiftId,closingCashMinor,closedAt}) {
    return this.tx(() => {
      const s=this.get("SELECT * FROM shift WHERE shift_id=?", [shiftId]);
      if (!s || s.status !== "OPEN") throw new Error("SHIFT_NOT_OPEN");
      this.exec("UPDATE shift SET status='CLOSED',closing_cash_minor=?,closed_at=? WHERE shift_id=?",
        [closingCashMinor,closedAt,shiftId]);
      return this.get("SELECT * FROM shift WHERE shift_id=?", [shiftId]);
    });
  }
  openShiftForDevice(deviceId) { return this.get("SELECT * FROM shift WHERE device_id=? AND status='OPEN'", [deviceId]); }
  insertSaleAtomic({order,items,payment,receipt,outbox,requestHash}) {
    return this.tx(() => {
      const existing=this.get("SELECT * FROM local_idempotency WHERE idempotency_key=?", [outbox.idempotencyKey]);
      if (existing) {
        if (existing.request_hash !== requestHash) throw new Error("IDEMPOTENCY_CONFLICT");
        return {duplicate:true, order:this.getOrder(existing.order_id)};
      }
      this.exec("INSERT INTO local_idempotency VALUES(?,?,?,?)",[outbox.idempotencyKey,requestHash,order.orderId,order.createdAt]);
      this.exec("INSERT INTO order_header VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        [order.orderId,order.tenantId,order.outletId,order.deviceId,order.actorId,order.shiftId,order.businessDate,
         "PAID","IDR",order.subtotalMinor,order.discountMinor,order.taxMinor,order.totalMinor,order.occurredAt,order.createdAt]);
      for (const item of items) this.exec("INSERT INTO order_item VALUES(?,?,?,?,?,?,?,?)",
        [item.orderItemId,order.orderId,item.productVariantId,item.quantity,item.unitPriceMinor,item.discountMinor,item.taxMinor,item.lineTotalMinor]);
      this.exec("INSERT INTO payment VALUES(?,?,?,?,?,?,?)",
        [payment.paymentId,order.orderId,"CASH","CAPTURED",payment.amountMinor,"IDR",payment.occurredAt]);
      this.exec("INSERT INTO receipt VALUES(?,?,?,?,?)",
        [receipt.receiptId,order.orderId,receipt.receiptNumber,JSON.stringify(receipt.payload),receipt.createdAt]);
      this.exec("INSERT INTO outbox VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        [outbox.eventId,outbox.tenantId,outbox.aggregateId,outbox.eventType,outbox.eventVersion,outbox.occurredAt,
         outbox.idempotencyKey,outbox.correlationId,outbox.causationId,JSON.stringify(outbox.payload),
         "PENDING",0,null,null,outbox.createdAt,outbox.localSequence,null,null]);
      return {duplicate:false, order:this.getOrder(order.orderId), receipt:this.getReceipt(order.orderId)};
    });
  }
  getOrder(orderId) {
    const order=this.get("SELECT * FROM order_header WHERE order_id=?", [orderId]);
    if (!order) return null;
    return {...order,items:this.all("SELECT * FROM order_item WHERE order_id=? ORDER BY rowid", [orderId]),
      payment:this.get("SELECT * FROM payment WHERE order_id=?", [orderId]), receipt:this.getReceipt(orderId)};
  }
  getReceipt(orderId) {
    const r=this.get("SELECT * FROM receipt WHERE order_id=?", [orderId]);
    return r ? {...r,payload:JSON.parse(r.payload_json)} : null;
  }
  pendingOutbox(limit=20) {
    return this.all("SELECT * FROM outbox WHERE status IN ('PENDING','RETRY','SENDING') AND (next_attempt_at IS NULL OR next_attempt_at<=?) ORDER BY created_at LIMIT ?",
      [new Date().toISOString(),limit]);
  }
  markSending(eventId) { this.exec("UPDATE outbox SET status='SENDING',attempts=attempts+1 WHERE event_id=? AND status IN ('PENDING','RETRY','SENDING')",[eventId]); }
  ack(eventId) { this.exec("UPDATE outbox SET status='ACKED',last_error=NULL WHERE event_id=?",[eventId]); }
  ackWithCursor(eventId,serverCursor,serverSequence) { this.exec("UPDATE outbox SET status='ACKED',last_error=NULL,server_cursor=?,server_sequence=? WHERE event_id=?",[serverCursor,serverSequence,eventId]); }
  nextLocalSequence(tenantId,deviceId) { const r=this.get("SELECT COALESCE(MAX(local_sequence),0)+1 AS n FROM outbox WHERE tenant_id=? AND json_extract(payload_json,'$.deviceId')=?",[tenantId,deviceId]); return r.n; }
  recordTelemetry(row,outcome,latencyMs,errorCode) { const payload=JSON.parse(row.payload_json); this.exec("INSERT INTO sync_telemetry VALUES(?,?,?,?,?,?,?,?,?,?)",[randomUUID(),row.tenant_id,payload.deviceId,row.event_id,row.idempotency_key,row.attempts,outcome,latencyMs,errorCode,new Date().toISOString()]); }
  localTotals({tenantId,deviceId}) { const r=this.get("SELECT COUNT(*) AS transactionCount,COALESCE(SUM(total_minor),0) AS totalMinor FROM order_header WHERE tenant_id=? AND device_id=? AND status='PAID'",[tenantId,deviceId]); const p=this.get("SELECT COALESCE(SUM(p.amount_minor),0) AS paymentTotalMinor FROM payment p JOIN order_header o ON o.order_id=p.order_id WHERE o.tenant_id=? AND o.device_id=? AND o.status='PAID'",[tenantId,deviceId]); const o=this.get("SELECT COUNT(*) AS n FROM outbox WHERE tenant_id=? AND status NOT IN ('ACKED')",[tenantId]); return {transactionCount:r.transactionCount,totalMinor:r.totalMinor,paymentTotalMinor:p.paymentTotalMinor,outstandingSyncCount:o.n}; }
  retry(eventId,error,nextAttemptAt) { this.exec("UPDATE outbox SET status='RETRY',last_error=?,next_attempt_at=? WHERE event_id=?",[error,nextAttemptAt,eventId]); }
  conflict(eventId,code,message,response) {
    return this.tx(() => {
      this.exec("UPDATE outbox SET status='CONFLICT',last_error=? WHERE event_id=?",[message,eventId]);
      const id=randomUUID();
      this.exec("INSERT INTO sync_conflict VALUES(?,?,?,?,?,?,?)",[id,eventId,code,message,response?JSON.stringify(response):null,new Date().toISOString(),null]);
      return id;
    });
  }
  outboxStatus(eventId) { return this.get("SELECT * FROM outbox WHERE event_id=?",[eventId]); }
  conflicts() { return this.all("SELECT * FROM sync_conflict ORDER BY created_at"); }
}
