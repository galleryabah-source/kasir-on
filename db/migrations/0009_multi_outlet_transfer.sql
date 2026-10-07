-- Phase 6A: bounded multi-outlet inventory transfer.
-- Canonical rule: one atomic command creates immutable transfer ledger evidence.
CREATE TABLE IF NOT EXISTS kasira.inventory_transfer (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
  transfer_number text NOT NULL,
  source_outlet_id uuid NOT NULL,
  source_warehouse_id uuid NOT NULL,
  destination_outlet_id uuid NOT NULL,
  destination_warehouse_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','POSTED','CANCELLED')),
  actor_id uuid,
  correlation_id uuid,
  occurred_at timestamptz NOT NULL,
  posted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,id),
  UNIQUE(tenant_id,transfer_number),
  FOREIGN KEY(tenant_id,source_outlet_id) REFERENCES kasira.outlet(tenant_id,id),
  FOREIGN KEY(tenant_id,destination_outlet_id) REFERENCES kasira.outlet(tenant_id,id),
  FOREIGN KEY(tenant_id,source_warehouse_id) REFERENCES kasira.warehouse(tenant_id,id),
  FOREIGN KEY(tenant_id,destination_warehouse_id) REFERENCES kasira.warehouse(tenant_id,id),
  FOREIGN KEY(tenant_id,actor_id) REFERENCES kasira.app_user(tenant_id,id)
);

CREATE TABLE IF NOT EXISTS kasira.inventory_transfer_line (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
  transfer_id uuid NOT NULL,
  product_variant_id uuid NOT NULL,
  quantity numeric(18,6) NOT NULL CHECK(quantity>0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,id),
  UNIQUE(tenant_id,transfer_id,product_variant_id),
  FOREIGN KEY(tenant_id,transfer_id) REFERENCES kasira.inventory_transfer(tenant_id,id),
  FOREIGN KEY(tenant_id,product_variant_id) REFERENCES kasira.product_variant(tenant_id,id)
);

ALTER TABLE kasira.inventory_transfer ENABLE ROW LEVEL SECURITY;
ALTER TABLE kasira.inventory_transfer FORCE ROW LEVEL SECURITY;
ALTER TABLE kasira.inventory_transfer_line ENABLE ROW LEVEL SECURITY;
ALTER TABLE kasira.inventory_transfer_line FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tenant_isolation ON kasira.inventory_transfer;
CREATE POLICY tenant_isolation ON kasira.inventory_transfer AS RESTRICTIVE FOR ALL
USING (tenant_id=kasira.current_tenant_id())
WITH CHECK (tenant_id=kasira.current_tenant_id());

DROP POLICY IF EXISTS tenant_isolation ON kasira.inventory_transfer_line;
CREATE POLICY tenant_isolation ON kasira.inventory_transfer_line AS RESTRICTIVE FOR ALL
USING (tenant_id=kasira.current_tenant_id())
WITH CHECK (tenant_id=kasira.current_tenant_id());

CREATE INDEX IF NOT EXISTS idx_inventory_transfer_source
  ON kasira.inventory_transfer(tenant_id,source_outlet_id,status,occurred_at);
CREATE INDEX IF NOT EXISTS idx_inventory_transfer_destination
  ON kasira.inventory_transfer(tenant_id,destination_outlet_id,status,occurred_at);

CREATE OR REPLACE FUNCTION kasira.post_inventory_transfer(
  p_tenant_id uuid,
  p_transfer_id uuid,
  p_actor_id uuid,
  p_occurred_at timestamptz
) RETURNS uuid
LANGUAGE plpgsql
AS $transfer$
DECLARE
  t kasira.inventory_transfer;
  l record;
  layer record;
  source_qty numeric;
  source_value numeric;
  remaining numeric;
  take_qty numeric;
  moved_value numeric;
  total_cost numeric;
  source_event_id uuid;
  destination_event_id uuid;
  destination_value numeric;
BEGIN
  IF p_tenant_id<>kasira.current_tenant_id() THEN
    RAISE EXCEPTION 'TENANT_CONTEXT_REQUIRED';
  END IF;

  SELECT * INTO t
  FROM kasira.inventory_transfer
  WHERE tenant_id=p_tenant_id AND id=p_transfer_id
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'INVENTORY_TRANSFER_NOT_FOUND'; END IF;
  IF t.status='POSTED' THEN RETURN t.id; END IF;
  IF t.status<>'OPEN' THEN RAISE EXCEPTION 'INVENTORY_TRANSFER_NOT_OPEN'; END IF;
  IF t.source_warehouse_id=t.destination_warehouse_id THEN
    RAISE EXCEPTION 'INVENTORY_TRANSFER_SAME_WAREHOUSE';
  END IF;
  IF NOT kasira.has_permission(p_tenant_id,p_actor_id,'inventory.adjust') THEN
    RAISE EXCEPTION 'INVENTORY_TRANSFER_PERMISSION_DENIED';
  END IF;
  IF NOT kasira.has_outlet_access(p_tenant_id,p_actor_id,t.source_outlet_id) THEN
    RAISE EXCEPTION 'INVENTORY_TRANSFER_SOURCE_SCOPE_DENIED';
  END IF;
  IF NOT kasira.has_outlet_access(p_tenant_id,p_actor_id,t.destination_outlet_id) THEN
    RAISE EXCEPTION 'INVENTORY_TRANSFER_DESTINATION_SCOPE_DENIED';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM kasira.warehouse
    WHERE tenant_id=p_tenant_id AND id=t.source_warehouse_id AND outlet_id=t.source_outlet_id
  ) THEN RAISE EXCEPTION 'SOURCE_WAREHOUSE_OUTLET_MISMATCH'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM kasira.warehouse
    WHERE tenant_id=p_tenant_id AND id=t.destination_warehouse_id AND outlet_id=t.destination_outlet_id
  ) THEN RAISE EXCEPTION 'DESTINATION_WAREHOUSE_OUTLET_MISMATCH'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM kasira.inventory_transfer_line
    WHERE tenant_id=p_tenant_id AND transfer_id=t.id
  ) THEN RAISE EXCEPTION 'INVENTORY_TRANSFER_EMPTY'; END IF;

  FOR l IN
    SELECT product_variant_id, quantity
    FROM kasira.inventory_transfer_line
    WHERE tenant_id=p_tenant_id AND transfer_id=t.id
    ORDER BY id
  LOOP
    SELECT COALESCE(quantity_on_hand,0), COALESCE(inventory_value_minor,0)
    INTO source_qty, source_value
    FROM kasira.inventory_projection
    WHERE tenant_id=p_tenant_id
      AND warehouse_id=t.source_warehouse_id
      AND product_variant_id=l.product_variant_id
    FOR UPDATE;

    IF NOT FOUND OR source_qty<l.quantity THEN
      RAISE EXCEPTION 'INSUFFICIENT_STOCK';
    END IF;

    source_event_id:=gen_random_uuid();
    total_cost:=0;
    remaining:=l.quantity;

    FOR layer IN
      SELECT id,remaining_quantity,unit_cost_minor
      FROM kasira.cost_layer
      WHERE tenant_id=p_tenant_id
        AND warehouse_id=t.source_warehouse_id
        AND product_variant_id=l.product_variant_id
        AND remaining_quantity>0
      ORDER BY received_at,id
      FOR UPDATE
    LOOP
      EXIT WHEN remaining<=0;
      take_qty:=LEAST(remaining,layer.remaining_quantity);
      moved_value:=take_qty*layer.unit_cost_minor;
      total_cost:=total_cost+moved_value;

      UPDATE kasira.cost_layer
      SET remaining_quantity=remaining_quantity-take_qty,
          status=CASE WHEN remaining_quantity-take_qty=0 THEN 'EXHAUSTED' ELSE 'OPEN' END
      WHERE tenant_id=p_tenant_id AND id=layer.id;

      INSERT INTO kasira.inventory_projection(
        tenant_id,warehouse_id,product_variant_id
      ) VALUES(
        p_tenant_id,t.destination_warehouse_id,l.product_variant_id
      ) ON CONFLICT DO NOTHING;

      destination_event_id:=gen_random_uuid();
      INSERT INTO kasira.inventory_ledger(
        tenant_id,warehouse_id,product_variant_id,event_id,event_type,
        quantity,unit_cost_minor,value_minor,occurred_at,actor_id,
        correlation_id,metadata
      ) VALUES(
        p_tenant_id,t.destination_warehouse_id,l.product_variant_id,destination_event_id,'TRANSFER_IN',
        take_qty,layer.unit_cost_minor,moved_value,p_occurred_at,p_actor_id,
        t.correlation_id,
        jsonb_build_object('transfer_id',t.id,'transfer_number',t.transfer_number,'source_event_id',source_event_id)
      );

      INSERT INTO kasira.cost_layer(
        tenant_id,warehouse_id,product_variant_id,source_event_id,received_at,
        unit_cost_minor,original_quantity,remaining_quantity
      ) VALUES(
        p_tenant_id,t.destination_warehouse_id,l.product_variant_id,destination_event_id,p_occurred_at,
        layer.unit_cost_minor,take_qty,take_qty
      );

      remaining:=remaining-take_qty;
    END LOOP;

    IF remaining>0 THEN RAISE EXCEPTION 'INSUFFICIENT_STOCK'; END IF;

    destination_value:=total_cost;

    INSERT INTO kasira.inventory_ledger(
      tenant_id,warehouse_id,product_variant_id,event_id,event_type,
      quantity,unit_cost_minor,value_minor,occurred_at,actor_id,
      correlation_id,metadata
    ) VALUES(
      p_tenant_id,t.source_warehouse_id,l.product_variant_id,source_event_id,'TRANSFER_OUT',
      -l.quantity,
      floor(total_cost/l.quantity)::bigint,
      -destination_value,
      p_occurred_at,p_actor_id,t.correlation_id,
      jsonb_build_object('transfer_id',t.id,'transfer_number',t.transfer_number,'destination_warehouse_id',t.destination_warehouse_id)
    );

    UPDATE kasira.inventory_projection
    SET quantity_on_hand=quantity_on_hand-l.quantity,
        inventory_value_minor=inventory_value_minor-destination_value,
        updated_at=now()
    WHERE tenant_id=p_tenant_id
      AND warehouse_id=t.source_warehouse_id
      AND product_variant_id=l.product_variant_id;

    UPDATE kasira.inventory_projection
    SET updated_at=now()
    WHERE tenant_id=p_tenant_id
      AND warehouse_id=t.destination_warehouse_id
      AND product_variant_id=l.product_variant_id;
  END LOOP;

  UPDATE kasira.inventory_transfer
  SET status='POSTED',actor_id=p_actor_id,occurred_at=p_occurred_at,posted_at=now()
  WHERE tenant_id=p_tenant_id AND id=p_transfer_id;

  RETURN p_transfer_id;
END;
$transfer$;

COMMENT ON FUNCTION kasira.post_inventory_transfer(uuid,uuid,uuid,timestamptz)
IS 'Phase 6A canonical multi-outlet inventory transfer: atomic FIFO-preserving transfer with tenant/outlet authorization and idempotent POSTED retry.';
