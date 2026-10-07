-- Phase 4 integration gate: inventory FIFO, projections, cash closing, payment reconciliation, variance.
BEGIN;
SET LOCAL app.tenant_id='00000000-0000-0000-0000-000000000001';

-- Canonical master IDs from scripts/integration.sql
\set tenant '''00000000-0000-0000-0000-000000000001'''
\set outlet '''00000000-0000-0000-0000-000000000001'''
\set warehouse '''00000000-0000-0000-0000-000000000001'''
\set variant '''00000000-0000-0000-0000-000000000001'''

-- Purchase order is the commercial source for the first receipt.
INSERT INTO kasira.purchase_order(id,tenant_id,outlet_id,supplier_name,supplier_reference,total_minor,occurred_at)
VALUES('00000000-0000-0000-0000-000000000301',:'tenant'::uuid,:'outlet'::uuid,'Supplier A','PO-1',10000,now());
INSERT INTO kasira.purchase_order_line(tenant_id,purchase_order_id,product_variant_id,quantity,unit_cost_minor,line_total_minor)
VALUES(:'tenant'::uuid,'00000000-0000-0000-0000-000000000301',:'variant'::uuid,10,1000,10000);

-- Two receipts establish FIFO cost layers: 10 @ 1000 and 5 @ 1200.
SELECT kasira.post_inventory_event(:'tenant'::uuid,:'warehouse'::uuid,:'variant'::uuid,
 '00000000-0000-0000-0000-000000000401','PURCHASE',10,1000,now(),NULL,NULL,
 '00000000-0000-0000-0000-000000000451',NULL,'{"source":"GR-1"}');
SELECT kasira.post_inventory_event(:'tenant'::uuid,:'warehouse'::uuid,:'variant'::uuid,
 '00000000-0000-0000-0000-000000000402','PURCHASE',5,1200,now(),NULL,NULL,
 '00000000-0000-0000-0000-000000000452',NULL,'{"source":"GR-2"}');

INSERT INTO kasira.goods_receipt(tenant_id,purchase_order_id,warehouse_id,receipt_number,occurred_at)
VALUES(:'tenant'::uuid,'00000000-0000-0000-0000-000000000301',:'warehouse'::uuid,'GR-1',now());
INSERT INTO kasira.goods_receipt_line(tenant_id,goods_receipt_id,product_variant_id,quantity,unit_cost_minor,inventory_event_id)
SELECT :'tenant'::uuid,id,:'variant'::uuid,10,1000,'00000000-0000-0000-0000-000000000401'::uuid
FROM kasira.goods_receipt WHERE tenant_id=:'tenant'::uuid AND receipt_number='GR-1';

-- FIFO sale of 12 units must consume 10@1000 + 2@1200 = 12400 COGS.
DO $$
DECLARE c numeric;
BEGIN
 c:=kasira.post_inventory_sale('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000403',12,now(),NULL,NULL,
 '00000000-0000-0000-0000-000000000453',NULL,'{"order":"ORD-1"}');
 IF c<>12400 THEN RAISE EXCEPTION 'FIFO COGS mismatch: %',c; END IF;
END $$;

-- Redelivery of the same inventory event is idempotent and must not consume FIFO twice.
DO $
DECLARE c numeric; q numeric;
BEGIN
 c:=kasira.post_inventory_sale('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000403',12,now(),NULL,NULL,
 '00000000-0000-0000-0000-000000000453',NULL);
 SELECT quantity_on_hand INTO q FROM kasira.inventory_projection
 WHERE tenant_id=:'tenant'::uuid AND warehouse_id=:'warehouse'::uuid AND product_variant_id=:'variant'::uuid;
 IF c<>12400 OR q<>3 THEN RAISE EXCEPTION 'inventory idempotency failed: cost %, qty %',c,q; END IF;
END $;

-- Ledger value and projection must be identical.
DO $$
DECLARE ledger_qty numeric; ledger_value numeric; projection_qty numeric; projection_value numeric; layer_qty numeric;
BEGIN
 SELECT COALESCE(SUM(quantity),0),COALESCE(SUM(quantity*unit_cost_minor),0)
 INTO ledger_qty,ledger_value FROM kasira.inventory_ledger
 WHERE tenant_id=:'tenant'::uuid AND warehouse_id=:'warehouse'::uuid AND product_variant_id=:'variant'::uuid;
 SELECT quantity_on_hand,inventory_value_minor INTO projection_qty,projection_value
 FROM kasira.inventory_projection WHERE tenant_id=:'tenant'::uuid AND warehouse_id=:'warehouse'::uuid AND product_variant_id=:'variant'::uuid;
 SELECT COALESCE(SUM(remaining_quantity),0) INTO layer_qty FROM kasira.cost_layer
 WHERE tenant_id=:'tenant'::uuid AND warehouse_id=:'warehouse'::uuid AND product_variant_id=:'variant'::uuid;
 IF ledger_qty<>projection_qty OR ledger_value<>projection_value OR layer_qty<>projection_qty
 THEN RAISE EXCEPTION 'LEDGER_PROJECTION_MISMATCH qty %, % value %, % layer %',ledger_qty,projection_qty,ledger_value,projection_value,layer_qty; END IF;
 IF projection_qty<>3 OR projection_value<>3600 THEN RAISE EXCEPTION 'Unexpected FIFO projection: % / %',projection_qty,projection_value; END IF;
END $$;

-- Insufficient stock must fail atomically.
DO $$
BEGIN
 BEGIN
  PERFORM kasira.post_inventory_sale('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000404',99,now(),NULL,NULL,
   '00000000-0000-0000-0000-000000000454',NULL);
  RAISE EXCEPTION 'insufficient stock unexpectedly passed';
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM NOT LIKE 'INSUFFICIENT_STOCK%' THEN RAISE; END IF;
 END;
END $$;

-- Stock opname posts a -0.5 variance at current cost.
INSERT INTO kasira.stock_opname(tenant_id,warehouse_id,opname_number,occurred_at)
VALUES(:'tenant'::uuid,:'warehouse'::uuid,'OP-1',now());
INSERT INTO kasira.stock_opname_line(tenant_id,stock_opname_id,product_variant_id,system_quantity,counted_quantity,unit_cost_minor)
SELECT :'tenant'::uuid,id,:'variant'::uuid,3,2.5,1200 FROM kasira.stock_opname WHERE tenant_id=:'tenant'::uuid AND opname_number='OP-1';
SELECT kasira.post_inventory_event(:'tenant'::uuid,:'warehouse'::uuid,:'variant'::uuid,
 '00000000-0000-0000-0000-000000000405','OPNAME',-0.5,1200,now(),NULL,NULL,
 '00000000-0000-0000-0000-000000000455',NULL,'{"opname":"OP-1"}');
UPDATE kasira.stock_opname SET status='POSTED',posted_at=now() WHERE tenant_id=:'tenant'::uuid AND opname_number='OP-1';
UPDATE kasira.stock_opname_line SET inventory_event_id='00000000-0000-0000-0000-000000000405'
WHERE tenant_id=:'tenant'::uuid AND stock_opname_id=(SELECT id FROM kasira.stock_opname WHERE tenant_id=:'tenant'::uuid AND opname_number='OP-1');

-- Server-side cash shift and atomic closing/variance workflow.
INSERT INTO kasira.cash_shift(id,tenant_id,outlet_id,business_date,opening_cash_minor,opened_at)
VALUES('00000000-0000-0000-0000-000000000501',:'tenant'::uuid,:'outlet'::uuid,CURRENT_DATE,100000,now());
INSERT INTO kasira.cash_ledger(tenant_id,outlet_id,cash_shift_id,event_id,event_type,amount_minor,business_date,occurred_at,correlation_id)
VALUES(:'tenant'::uuid,:'outlet'::uuid,'00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-000000000504','SALE',10000,CURRENT_DATE,now(),'00000000-0000-0000-0000-000000000505');
SELECT kasira.close_cash_shift_from_ledger(:'tenant'::uuid,'00000000-0000-0000-0000-000000000501',CURRENT_DATE,110000,NULL,now());

-- Closing and settlement creation are retry-safe for identical inputs.
DO $
DECLARE a uuid; b uuid;
BEGIN
 a:=kasira.close_cash_shift_from_ledger(:'tenant'::uuid,'00000000-0000-0000-0000-000000000501',CURRENT_DATE,110000,NULL,now());
 b:=kasira.close_cash_shift_from_ledger(:'tenant'::uuid,'00000000-0000-0000-0000-000000000501',CURRENT_DATE,110000,NULL,now());
 IF a<>b THEN RAISE EXCEPTION 'cash closing idempotency failed'; END IF;
END $;

-- Payment reconciliation: one matched settlement and one explicit variance.
INSERT INTO kasira.payment(tenant_id,order_id,method,provider,status,amount_minor,occurred_at)
VALUES(:'tenant'::uuid,'00000000-0000-0000-0000-000000000101','QRIS','PROVIDER-X','CAPTURED',10000,now());
SELECT kasira.create_payment_reconciliation(:'tenant'::uuid,:'outlet'::uuid,'PROVIDER-X','SETTLE-1',CURRENT_DATE,CURRENT_DATE,10000);
INSERT INTO kasira.payment_reconciliation_item(tenant_id,reconciliation_id,payment_id,provider_reference,internal_amount_minor,external_amount_minor,status)
SELECT :'tenant'::uuid,r.id,p.id,'PX-1',10000,10000,'MATCHED'
FROM kasira.payment_reconciliation r, kasira.payment p
WHERE r.tenant_id=:'tenant'::uuid AND r.settlement_reference='SETTLE-1' AND p.tenant_id=:'tenant'::uuid AND p.order_id='00000000-0000-0000-0000-000000000101';

SELECT kasira.create_payment_reconciliation(:'tenant'::uuid,:'outlet'::uuid,'PROVIDER-X','SETTLE-2',CURRENT_DATE,CURRENT_DATE,9500);

-- Final ledger/projection/cost-layer invariant after stock opname.
DO $
DECLARE ledger_qty numeric; ledger_value numeric; projection_qty numeric; projection_value numeric; layer_qty numeric;
BEGIN
 SELECT COALESCE(SUM(quantity),0),COALESCE(SUM(quantity*unit_cost_minor),0)
 INTO ledger_qty,ledger_value FROM kasira.inventory_ledger
 WHERE tenant_id=:'tenant'::uuid AND warehouse_id=:'warehouse'::uuid AND product_variant_id=:'variant'::uuid;
 SELECT quantity_on_hand,inventory_value_minor INTO projection_qty,projection_value
 FROM kasira.inventory_projection WHERE tenant_id=:'tenant'::uuid AND warehouse_id=:'warehouse'::uuid AND product_variant_id=:'variant'::uuid;
 SELECT COALESCE(SUM(remaining_quantity),0) INTO layer_qty FROM kasira.cost_layer
 WHERE tenant_id=:'tenant'::uuid AND warehouse_id=:'warehouse'::uuid AND product_variant_id=:'variant'::uuid;
 IF ledger_qty<>projection_qty OR ledger_value<>projection_value OR layer_qty<>projection_qty
 THEN RAISE EXCEPTION 'FINAL_LEDGER_PROJECTION_LAYER_MISMATCH qty %, % layer % value %, %',ledger_qty,projection_qty,layer_qty,ledger_value,projection_value; END IF;
END $;

-- Final canonical evidence.
SELECT
 (SELECT quantity_on_hand FROM kasira.inventory_projection WHERE tenant_id=:'tenant'::uuid AND warehouse_id=:'warehouse'::uuid AND product_variant_id=:'variant'::uuid)=2.5 AS inventory_projection_ok,
 (SELECT inventory_value_minor FROM kasira.inventory_projection WHERE tenant_id=:'tenant'::uuid AND warehouse_id=:'warehouse'::uuid AND product_variant_id=:'variant'::uuid)=3000 AS inventory_value_ok,
 (SELECT status FROM kasira.cash_closing WHERE tenant_id=:'tenant'::uuid AND cash_shift_id='00000000-0000-0000-0000-000000000501')='BALANCED' AS cash_closing_ok,
 (SELECT status FROM kasira.payment_reconciliation WHERE tenant_id=:'tenant'::uuid AND settlement_reference='SETTLE-1')='MATCHED' AS payment_match_ok,
 (SELECT status FROM kasira.payment_reconciliation WHERE tenant_id=:'tenant'::uuid AND settlement_reference='SETTLE-2')='VARIANCE' AS payment_variance_ok,
 (SELECT count(*) FROM kasira.variance_case WHERE tenant_id=:'tenant'::uuid AND status='OPEN')=1 AS variance_workflow_ok;
COMMIT;
