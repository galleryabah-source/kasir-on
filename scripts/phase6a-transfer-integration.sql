\set ON_ERROR_STOP on
BEGIN;
SET LOCAL app.tenant_id='00000000-0000-0000-0000-000000000001';

DO $phase6$
DECLARE
  t uuid := '00000000-0000-0000-0000-000000000001';
  b uuid;
  source_outlet uuid;
  dest_outlet uuid;
  source_wh uuid;
  dest_wh uuid;
  variant uuid;
  manager uuid;
  source_only uuid;
  role_id uuid;
  permission_id uuid;
  transfer_id uuid;
  retry_id uuid;
  source_qty numeric;
  source_value numeric;
  dest_qty numeric;
  dest_value numeric;
  dest_layers numeric;
BEGIN
  SELECT id INTO b FROM kasira.brand WHERE tenant_id=t AND code='B1';

  INSERT INTO kasira.outlet(tenant_id,brand_id,code,name)
  VALUES(t,b,'O6A-SRC','Phase6 Source')
  ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name
  RETURNING id INTO source_outlet;

  INSERT INTO kasira.outlet(tenant_id,brand_id,code,name)
  VALUES(t,b,'O6A-DST','Phase6 Destination')
  ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name
  RETURNING id INTO dest_outlet;

  INSERT INTO kasira.warehouse(tenant_id,outlet_id,code,name)
  VALUES(t,source_outlet,'W6A-SRC','Phase6 Source Warehouse')
  ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name,outlet_id=EXCLUDED.outlet_id
  RETURNING id INTO source_wh;

  INSERT INTO kasira.warehouse(tenant_id,outlet_id,code,name)
  VALUES(t,dest_outlet,'W6A-DST','Phase6 Destination Warehouse')
  ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name,outlet_id=EXCLUDED.outlet_id
  RETURNING id INTO dest_wh;

  SELECT id INTO variant FROM kasira.product_variant
  WHERE tenant_id=t AND sku='VAR-1';

  INSERT INTO kasira.app_user(tenant_id,email,display_name)
  VALUES(t,'phase6-manager@example.invalid','Phase6 Manager')
  ON CONFLICT(tenant_id,email) DO UPDATE SET display_name=EXCLUDED.display_name
  RETURNING id INTO manager;

  INSERT INTO kasira.role(tenant_id,code,name)
  VALUES(t,'PHASE6_MANAGER','Phase6 Manager')
  ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name
  RETURNING id INTO role_id;

  SELECT id INTO permission_id FROM kasira.permission WHERE code='inventory.adjust';
  INSERT INTO kasira.role_permission(tenant_id,role_id,permission_id)
  VALUES(t,role_id,permission_id) ON CONFLICT DO NOTHING;
  INSERT INTO kasira.user_role(tenant_id,user_id,role_id)
  VALUES(t,manager,role_id) ON CONFLICT DO NOTHING;
  INSERT INTO kasira.user_outlet_scope(tenant_id,user_id,outlet_id)
  VALUES(t,manager,source_outlet),(t,manager,dest_outlet)
  ON CONFLICT DO NOTHING;

  PERFORM kasira.post_inventory_event(t,source_wh,variant,
    '00000000-0000-0000-0000-000000006001','PURCHASE',10,1000,now()-interval '1 hour',
    manager,NULL,'00000000-0000-0000-0000-000000006101',NULL,'{"phase":"6A"}');

  PERFORM kasira.post_inventory_event(t,source_wh,variant,
    '00000000-0000-0000-0000-000000006002','PURCHASE',5,1200,now()-interval '30 minutes',
    manager,NULL,'00000000-0000-0000-0000-000000006102',NULL,'{"phase":"6A"}');

  INSERT INTO kasira.inventory_transfer(
    tenant_id,transfer_number,source_outlet_id,source_warehouse_id,
    destination_outlet_id,destination_warehouse_id,correlation_id,occurred_at
  ) VALUES(
    t,'TRF-6A-001',source_outlet,source_wh,dest_outlet,dest_wh,
    '00000000-0000-0000-0000-000000006103',now()
  ) RETURNING id INTO transfer_id;

  INSERT INTO kasira.inventory_transfer_line(tenant_id,transfer_id,product_variant_id,quantity)
  VALUES(t,transfer_id,variant,12);

  PERFORM kasira.post_inventory_transfer(t,transfer_id,manager,now());
  retry_id:=kasira.post_inventory_transfer(t,transfer_id,manager,now());
  IF retry_id<>transfer_id THEN RAISE EXCEPTION 'TRANSFER_IDEMPOTENCY_FAILED'; END IF;

  SELECT quantity_on_hand,inventory_value_minor INTO source_qty,source_value
  FROM kasira.inventory_projection
  WHERE tenant_id=t AND warehouse_id=source_wh AND product_variant_id=variant;

  SELECT quantity_on_hand,inventory_value_minor INTO dest_qty,dest_value
  FROM kasira.inventory_projection
  WHERE tenant_id=t AND warehouse_id=dest_wh AND product_variant_id=variant;

  SELECT COALESCE(SUM(remaining_quantity),0) INTO dest_layers
  FROM kasira.cost_layer
  WHERE tenant_id=t AND warehouse_id=dest_wh AND product_variant_id=variant;

  IF source_qty<>3 OR source_value<>3600 THEN
    RAISE EXCEPTION 'SOURCE_INVARIANT_FAILED qty %, value %',source_qty,source_value;
  END IF;
  IF dest_qty<>12 OR dest_value<>12400 OR dest_layers<>12 THEN
    RAISE EXCEPTION 'DESTINATION_INVARIANT_FAILED qty %, value %, layers %',dest_qty,dest_value,dest_layers;
  END IF;

  IF (SELECT count(*) FROM kasira.inventory_ledger
      WHERE tenant_id=t AND metadata->>'transfer_id'=transfer_id::text)=3
  IS NOT TRUE THEN
    RAISE EXCEPTION 'TRANSFER_LEDGER_EVIDENCE_FAILED';
  END IF;

  INSERT INTO kasira.app_user(tenant_id,email,display_name)
  VALUES(t,'phase6-source-only@example.invalid','Phase6 Source Only')
  ON CONFLICT(tenant_id,email) DO UPDATE SET display_name=EXCLUDED.display_name
  RETURNING id INTO source_only;
  INSERT INTO kasira.user_role(tenant_id,user_id,role_id) VALUES(t,source_only,role_id) ON CONFLICT DO NOTHING;
  INSERT INTO kasira.user_outlet_scope(tenant_id,user_id,outlet_id)
  VALUES(t,source_only,source_outlet) ON CONFLICT DO NOTHING;

  INSERT INTO kasira.inventory_transfer(
    tenant_id,transfer_number,source_outlet_id,source_warehouse_id,
    destination_outlet_id,destination_warehouse_id,correlation_id,occurred_at
  ) VALUES(
    t,'TRF-6A-DENY',source_outlet,source_wh,dest_outlet,dest_wh,
    '00000000-0000-0000-0000-000000006104',now()
  ) RETURNING id INTO transfer_id;
  INSERT INTO kasira.inventory_transfer_line(tenant_id,transfer_id,product_variant_id,quantity)
  VALUES(t,transfer_id,variant,1);

  BEGIN
    PERFORM kasira.post_inventory_transfer(t,transfer_id,source_only,now());
    RAISE EXCEPTION 'DESTINATION_SCOPE_BYPASS';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM NOT LIKE 'INVENTORY_TRANSFER_DESTINATION_SCOPE_DENIED%' THEN RAISE; END IF;
  END;

  RAISE NOTICE 'PHASE 6A INVENTORY TRANSFER GATE: PASS';
END $phase6$;
ROLLBACK;
