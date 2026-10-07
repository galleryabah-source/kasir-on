BEGIN;
SET LOCAL app.tenant_id = '00000000-0000-0000-0000-000000000001';

INSERT INTO kasira.tenant(id,code,name) VALUES
('00000000-0000-0000-0000-000000000001','T1','Tenant One'),
('00000000-0000-0000-0000-000000000002','T2','Tenant Two');

INSERT INTO kasira.brand(tenant_id,code,name) VALUES
('00000000-0000-0000-0000-000000000001','B1','Brand One'),
('00000000-0000-0000-0000-000000000002','B2','Brand Two');

INSERT INTO kasira.outlet(tenant_id,brand_id,code,name) VALUES
('00000000-0000-0000-0000-000000000001',(SELECT id FROM kasira.brand WHERE tenant_id='00000000-0000-0000-0000-000000000001'),'O1','Outlet One'),
('00000000-0000-0000-0000-000000000002',(SELECT id FROM kasira.brand WHERE tenant_id='00000000-0000-0000-0000-000000000002'),'O2','Outlet Two');

INSERT INTO kasira.product(tenant_id,sku,name) VALUES
('00000000-0000-0000-0000-000000000001','SKU-1','Coffee');

INSERT INTO kasira.product_variant(tenant_id,product_id,sku,name) VALUES
('00000000-0000-0000-0000-000000000001',(SELECT id FROM kasira.product WHERE sku='SKU-1'),'VAR-1','Coffee Regular');

INSERT INTO kasira.warehouse(tenant_id,outlet_id,code,name) VALUES
('00000000-0000-0000-0000-000000000001',(SELECT id FROM kasira.outlet WHERE code='O1'),'W1','Warehouse One');

INSERT INTO kasira.order_header(id,tenant_id,outlet_id,order_number,business_date,status,subtotal_minor,discount_minor,tax_minor,total_minor,occurred_at)
VALUES('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000001',(SELECT id FROM kasira.outlet WHERE code='O1'),'ORD-1',CURRENT_DATE,'PAID',10000,0,0,10000,now());

INSERT INTO kasira.order_item(tenant_id,order_id,product_variant_id,quantity,unit_price_minor,line_total_minor)
VALUES('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000101',(SELECT id FROM kasira.product_variant WHERE sku='VAR-1'),1,10000,10000);

INSERT INTO kasira.sales_ledger(tenant_id,outlet_id,order_id,event_id,event_type,amount_minor,occurred_at,correlation_id)
VALUES('00000000-0000-0000-0000-000000000001',(SELECT id FROM kasira.outlet WHERE code='O1'),'00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000201','SALE_CREATED',10000,now(),'00000000-0000-0000-0000-000000000301');

DO $$
BEGIN
  BEGIN
    INSERT INTO kasira.order_header(id,tenant_id,outlet_id,order_number,business_date,status,subtotal_minor,total_minor,occurred_at)
    VALUES('00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000002',(SELECT id FROM kasira.outlet WHERE code='O1'),'CROSS-TENANT',CURRENT_DATE,'PAID',1,1,now());
    RAISE EXCEPTION 'cross-tenant FK test unexpectedly passed';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;
END $$;

DO $$
BEGIN
  BEGIN
    UPDATE kasira.sales_ledger SET amount_minor=1 WHERE event_id='00000000-0000-0000-0000-000000000201';
    RAISE EXCEPTION 'immutable ledger test unexpectedly passed';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM NOT LIKE 'Immutable ledger:%' THEN RAISE; END IF;
  END;
END $$;

COMMIT;
