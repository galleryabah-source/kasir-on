-- Phase 4: Inventory & Finance Integrity
-- Canonical rule: ledgers are immutable truth; projections are rebuildable state.
CREATE TABLE IF NOT EXISTS kasira.purchase_order (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 outlet_id uuid NOT NULL, supplier_name text NOT NULL, supplier_reference text,
 status text NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','RECEIVED','CANCELLED')),
 currency char(3) NOT NULL DEFAULT 'IDR', total_minor bigint NOT NULL DEFAULT 0 CHECK(total_minor>=0),
 occurred_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,id), UNIQUE(tenant_id,supplier_reference),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.purchase_order_line (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 purchase_order_id uuid NOT NULL, product_variant_id uuid NOT NULL,
 quantity numeric(18,6) NOT NULL CHECK(quantity>0), unit_cost_minor bigint NOT NULL CHECK(unit_cost_minor>=0),
 line_total_minor bigint NOT NULL CHECK(line_total_minor=(quantity*unit_cost_minor)::bigint),
 FOREIGN KEY(tenant_id,purchase_order_id) REFERENCES kasira.purchase_order(tenant_id,id),
 FOREIGN KEY(tenant_id,product_variant_id) REFERENCES kasira.product_variant(tenant_id,id),
 UNIQUE(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.goods_receipt (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 purchase_order_id uuid, warehouse_id uuid NOT NULL, receipt_number text NOT NULL,
 status text NOT NULL DEFAULT 'POSTED' CHECK(status IN ('POSTED','VOIDED')),
 occurred_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,receipt_number), UNIQUE(tenant_id,id),
 FOREIGN KEY(tenant_id,purchase_order_id) REFERENCES kasira.purchase_order(tenant_id,id),
 FOREIGN KEY(tenant_id,warehouse_id) REFERENCES kasira.warehouse(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.goods_receipt_line (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 goods_receipt_id uuid NOT NULL, product_variant_id uuid NOT NULL, quantity numeric(18,6) NOT NULL CHECK(quantity>0),
 unit_cost_minor bigint NOT NULL CHECK(unit_cost_minor>=0), inventory_event_id uuid NOT NULL,
 FOREIGN KEY(tenant_id,goods_receipt_id) REFERENCES kasira.goods_receipt(tenant_id,id),
 FOREIGN KEY(tenant_id,product_variant_id) REFERENCES kasira.product_variant(tenant_id,id),
 UNIQUE(tenant_id,inventory_event_id)
);
CREATE TABLE IF NOT EXISTS kasira.cost_layer (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 warehouse_id uuid NOT NULL, product_variant_id uuid NOT NULL, source_event_id uuid NOT NULL,
 received_at timestamptz NOT NULL, unit_cost_minor bigint NOT NULL CHECK(unit_cost_minor>=0),
 original_quantity numeric(18,6) NOT NULL CHECK(original_quantity>0),
 remaining_quantity numeric(18,6) NOT NULL CHECK(remaining_quantity>=0 AND remaining_quantity<=original_quantity),
 status text NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','EXHAUSTED')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,source_event_id), UNIQUE(tenant_id,id),
 FOREIGN KEY(tenant_id,warehouse_id) REFERENCES kasira.warehouse(tenant_id,id),
 FOREIGN KEY(tenant_id,product_variant_id) REFERENCES kasira.product_variant(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.inventory_projection (
 tenant_id uuid NOT NULL REFERENCES kasira.tenant(id), warehouse_id uuid NOT NULL, product_variant_id uuid NOT NULL,
 quantity_on_hand numeric(18,6) NOT NULL DEFAULT 0 CHECK(quantity_on_hand>=0),
 inventory_value_minor numeric(30,6) NOT NULL DEFAULT 0 CHECK(inventory_value_minor>=0),
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,warehouse_id,product_variant_id),
 FOREIGN KEY(tenant_id,warehouse_id) REFERENCES kasira.warehouse(tenant_id,id),
 FOREIGN KEY(tenant_id,product_variant_id) REFERENCES kasira.product_variant(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.stock_opname (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 warehouse_id uuid NOT NULL, opname_number text NOT NULL,
 status text NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT','POSTED','CANCELLED')),
 occurred_at timestamptz NOT NULL, posted_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,opname_number), UNIQUE(tenant_id,id),
 FOREIGN KEY(tenant_id,warehouse_id) REFERENCES kasira.warehouse(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.stock_opname_line (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 stock_opname_id uuid NOT NULL, product_variant_id uuid NOT NULL,
 system_quantity numeric(18,6) NOT NULL, counted_quantity numeric(18,6) NOT NULL CHECK(counted_quantity>=0),
 variance_quantity numeric(18,6) GENERATED ALWAYS AS (counted_quantity-system_quantity) STORED,
 unit_cost_minor bigint NOT NULL CHECK(unit_cost_minor>=0), inventory_event_id uuid,
 FOREIGN KEY(tenant_id,stock_opname_id) REFERENCES kasira.stock_opname(tenant_id,id),
 FOREIGN KEY(tenant_id,product_variant_id) REFERENCES kasira.product_variant(tenant_id,id),
 UNIQUE(tenant_id,stock_opname_id,product_variant_id)
);
CREATE TABLE IF NOT EXISTS kasira.cash_shift (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 outlet_id uuid NOT NULL, device_id uuid, actor_id uuid,
 business_date date NOT NULL, opening_cash_minor bigint NOT NULL CHECK(opening_cash_minor>=0),
 status text NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','CLOSED','VARIANCE')),
 opened_at timestamptz NOT NULL, closed_at timestamptz,
 UNIQUE(tenant_id,id), UNIQUE(tenant_id,outlet_id,device_id,business_date),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id),
 FOREIGN KEY(tenant_id,device_id) REFERENCES kasira.device(tenant_id,id),
 FOREIGN KEY(tenant_id,actor_id) REFERENCES kasira.app_user(tenant_id,id),
 CHECK((status='OPEN' AND closed_at IS NULL) OR (status IN ('CLOSED','VARIANCE') AND closed_at IS NOT NULL))
);
CREATE TABLE IF NOT EXISTS kasira.cash_closing (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 cash_shift_id uuid NOT NULL, business_date date NOT NULL,
 expected_cash_minor bigint NOT NULL CHECK(expected_cash_minor>=0),
 actual_cash_minor bigint NOT NULL CHECK(actual_cash_minor>=0),
 variance_minor bigint GENERATED ALWAYS AS (actual_cash_minor-expected_cash_minor) STORED,
 status text NOT NULL CHECK(status IN ('BALANCED','VARIANCE')),
 actor_id uuid, occurred_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,cash_shift_id),
 FOREIGN KEY(tenant_id,cash_shift_id) REFERENCES kasira.cash_shift(tenant_id,id),
 FOREIGN KEY(tenant_id,actor_id) REFERENCES kasira.app_user(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.payment_reconciliation (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 outlet_id uuid NOT NULL, provider text NOT NULL, settlement_reference text NOT NULL,
 period_start date NOT NULL, period_end date NOT NULL,
 internal_total_minor bigint NOT NULL CHECK(internal_total_minor>=0),
 external_total_minor bigint NOT NULL CHECK(external_total_minor>=0),
 variance_minor bigint GENERATED ALWAYS AS (external_total_minor-internal_total_minor) STORED,
 status text NOT NULL CHECK(status IN ('MATCHED','VARIANCE','RESOLVED')),
 resolved_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,id), UNIQUE(tenant_id,settlement_reference),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id),
 CHECK(period_end>=period_start)
);
CREATE TABLE IF NOT EXISTS kasira.payment_reconciliation_item (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 reconciliation_id uuid NOT NULL, payment_id uuid NOT NULL,
 provider_reference text, internal_amount_minor bigint NOT NULL CHECK(internal_amount_minor>=0),
 external_amount_minor bigint, status text NOT NULL CHECK(status IN ('MATCHED','MISSING_EXTERNAL','MISSING_INTERNAL','AMOUNT_MISMATCH')),
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,reconciliation_id) REFERENCES kasira.payment_reconciliation(tenant_id,id),
 FOREIGN KEY(tenant_id,payment_id) REFERENCES kasira.payment(tenant_id,id),
 UNIQUE(tenant_id,reconciliation_id,payment_id)
);
CREATE TABLE IF NOT EXISTS kasira.variance_case (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 case_type text NOT NULL CHECK(case_type IN ('STOCK','CASH','PAYMENT')),
 source_id uuid NOT NULL, reason text NOT NULL,
 variance_minor numeric(30,6), status text NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','RESOLVED','REJECTED')),
 resolution text, actor_id uuid, resolved_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,case_type,source_id),
 FOREIGN KEY(tenant_id,actor_id) REFERENCES kasira.app_user(tenant_id,id)
);
CREATE INDEX IF NOT EXISTS idx_inventory_ledger_stock ON kasira.inventory_ledger(tenant_id,warehouse_id,product_variant_id,occurred_at,id);
CREATE INDEX IF NOT EXISTS idx_cost_layer_fifo ON kasira.cost_layer(tenant_id,warehouse_id,product_variant_id,received_at,id) WHERE remaining_quantity>0;
CREATE INDEX IF NOT EXISTS idx_payment_reconciliation_period ON kasira.payment_reconciliation(tenant_id,outlet_id,period_start,period_end);

CREATE OR REPLACE FUNCTION kasira.post_inventory_event(
 p_tenant_id uuid, p_warehouse_id uuid, p_product_variant_id uuid, p_event_id uuid, p_event_type text,
 p_quantity numeric, p_unit_cost_minor bigint, p_occurred_at timestamptz, p_actor_id uuid, p_device_id uuid,
 p_correlation_id uuid, p_causation_id uuid, p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE current_qty numeric; current_value numeric; new_qty numeric; value_delta numeric;
BEGIN
 IF p_quantity=0 THEN RAISE EXCEPTION 'inventory quantity cannot be zero'; END IF;
 IF p_unit_cost_minor IS NULL OR p_unit_cost_minor<0 THEN RAISE EXCEPTION 'inventory cost is required and must be non-negative'; END IF;
 INSERT INTO kasira.inventory_projection(tenant_id,warehouse_id,product_variant_id)
 VALUES(p_tenant_id,p_warehouse_id,p_product_variant_id) ON CONFLICT DO NOTHING;
 SELECT quantity_on_hand,inventory_value_minor INTO current_qty,current_value
 FROM kasira.inventory_projection
 WHERE tenant_id=p_tenant_id AND warehouse_id=p_warehouse_id AND product_variant_id=p_product_variant_id FOR UPDATE;
 new_qty:=current_qty+p_quantity;
 IF new_qty<0 THEN RAISE EXCEPTION 'INSUFFICIENT_STOCK'; END IF;
 value_delta:=p_quantity*p_unit_cost_minor;
 IF current_value+value_delta<0 THEN RAISE EXCEPTION 'INVENTORY_VALUE_UNDERFLOW'; END IF;
 INSERT INTO kasira.inventory_ledger(tenant_id,warehouse_id,product_variant_id,event_id,event_type,quantity,unit_cost_minor,occurred_at,actor_id,device_id,correlation_id,causation_id,metadata)
 VALUES(p_tenant_id,p_warehouse_id,p_product_variant_id,p_event_id,p_event_type,p_quantity,p_unit_cost_minor,p_occurred_at,p_actor_id,p_device_id,p_correlation_id,p_causation_id,p_metadata);
 UPDATE kasira.inventory_projection SET quantity_on_hand=new_qty,inventory_value_minor=current_value+value_delta,updated_at=now()
 WHERE tenant_id=p_tenant_id AND warehouse_id=p_warehouse_id AND product_variant_id=p_product_variant_id;
 IF p_quantity>0 THEN
   INSERT INTO kasira.cost_layer(tenant_id,warehouse_id,product_variant_id,source_event_id,received_at,unit_cost_minor,original_quantity,remaining_quantity)
   VALUES(p_tenant_id,p_warehouse_id,p_product_variant_id,p_event_id,p_occurred_at,p_unit_cost_minor,p_quantity,p_quantity);
 END IF;
 RETURN p_event_id;
END $$;

CREATE OR REPLACE FUNCTION kasira.consume_inventory_fifo(
 p_tenant_id uuid, p_warehouse_id uuid, p_product_variant_id uuid, p_quantity numeric
) RETURNS numeric LANGUAGE plpgsql AS $$
DECLARE layer record; take_qty numeric; remaining numeric:=p_quantity; total_cost numeric:=0;
BEGIN
 IF p_quantity<=0 THEN RAISE EXCEPTION 'FIFO consumption quantity must be positive'; END IF;
 FOR layer IN
   SELECT id,remaining_quantity,unit_cost_minor FROM kasira.cost_layer
   WHERE tenant_id=p_tenant_id AND warehouse_id=p_warehouse_id AND product_variant_id=p_product_variant_id AND remaining_quantity>0
   ORDER BY received_at,id FOR UPDATE
 LOOP
   EXIT WHEN remaining<=0;
   take_qty:=LEAST(remaining,layer.remaining_quantity);
   UPDATE kasira.cost_layer SET remaining_quantity=remaining_quantity-take_qty,
     status=CASE WHEN remaining_quantity-take_qty=0 THEN 'EXHAUSTED' ELSE 'OPEN' END WHERE id=layer.id;
   total_cost:=total_cost+(take_qty*layer.unit_cost_minor);
   remaining:=remaining-take_qty;
 END LOOP;
 IF remaining>0 THEN RAISE EXCEPTION 'INSUFFICIENT_STOCK'; END IF;
 RETURN total_cost;
END $$;

CREATE OR REPLACE FUNCTION kasira.post_inventory_sale(
 p_tenant_id uuid, p_warehouse_id uuid, p_product_variant_id uuid, p_event_id uuid, p_quantity numeric,
 p_occurred_at timestamptz, p_actor_id uuid, p_device_id uuid, p_correlation_id uuid, p_causation_id uuid,
 p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS numeric LANGUAGE plpgsql AS $$
DECLARE total_cost numeric;
BEGIN
 total_cost:=kasira.consume_inventory_fifo(p_tenant_id,p_warehouse_id,p_product_variant_id,p_quantity);
 PERFORM kasira.post_inventory_event(p_tenant_id,p_warehouse_id,p_product_variant_id,p_event_id,'SALE',-p_quantity,
   CASE WHEN p_quantity=0 THEN 0 ELSE total_cost/p_quantity END,p_occurred_at,p_actor_id,p_device_id,p_correlation_id,p_causation_id,
   p_metadata||jsonb_build_object('cogs_total_minor',total_cost));
 RETURN total_cost;
END $$;

CREATE OR REPLACE FUNCTION kasira.close_cash_shift(
 p_tenant_id uuid, p_shift_id uuid, p_business_date date, p_expected_cash_minor bigint,
 p_actual_cash_minor bigint, p_actor_id uuid, p_occurred_at timestamptz
) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE shift kasira.cash_shift;
DECLARE closing_id uuid:=gen_random_uuid(); variance bigint;
BEGIN
 SELECT * INTO shift FROM kasira.cash_shift WHERE tenant_id=p_tenant_id AND id=p_shift_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'CASH_SHIFT_NOT_FOUND'; END IF;
 IF shift.status<>'OPEN' THEN RAISE EXCEPTION 'CASH_SHIFT_ALREADY_CLOSED'; END IF;
 variance:=p_actual_cash_minor-p_expected_cash_minor;
 INSERT INTO kasira.cash_closing(tenant_id,cash_shift_id,business_date,expected_cash_minor,actual_cash_minor,status,actor_id,occurred_at)
 VALUES(p_tenant_id,p_shift_id,p_business_date,p_expected_cash_minor,p_actual_cash_minor,CASE WHEN variance=0 THEN 'BALANCED' ELSE 'VARIANCE' END,p_actor_id,p_occurred_at);
 UPDATE kasira.cash_shift SET status=CASE WHEN variance=0 THEN 'CLOSED' ELSE 'VARIANCE' END,closed_at=p_occurred_at WHERE tenant_id=p_tenant_id AND id=p_shift_id;
 IF variance<>0 THEN
   INSERT INTO kasira.variance_case(tenant_id,case_type,source_id,reason,variance_minor,actor_id)
   VALUES(p_tenant_id,'CASH',closing_id,'CASH_CLOSING_VARIANCE',variance,p_actor_id);
 END IF;
 RETURN closing_id;
END $$;

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['purchase_order','purchase_order_line','goods_receipt','goods_receipt_line','cost_layer','inventory_projection','stock_opname','stock_opname_line','cash_shift','cash_closing','payment_reconciliation','payment_reconciliation_item','variance_case'] LOOP
  EXECUTE format('ALTER TABLE kasira.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('ALTER TABLE kasira.%I FORCE ROW LEVEL SECURITY',t);
  EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON kasira.%I',t);
  EXECUTE format('CREATE POLICY tenant_isolation ON kasira.%I AS RESTRICTIVE FOR ALL USING (tenant_id=kasira.current_tenant_id()) WITH CHECK (tenant_id=kasira.current_tenant_id())',t);
 END LOOP;
END $$;

-- Phase 4 hardening: sync-safe idempotency and canonical cash/payment calculations.
DO $$
BEGIN
 IF NOT EXISTS (
   SELECT 1 FROM pg_constraint WHERE conname='cash_ledger_cash_shift_fk'
 ) THEN
   ALTER TABLE kasira.cash_ledger ADD CONSTRAINT cash_ledger_cash_shift_fk
     FOREIGN KEY(tenant_id,cash_shift_id) REFERENCES kasira.cash_shift(tenant_id,id);
 END IF;
END $$;

CREATE OR REPLACE FUNCTION kasira.post_inventory_event(
 p_tenant_id uuid, p_warehouse_id uuid, p_product_variant_id uuid, p_event_id uuid, p_event_type text,
 p_quantity numeric, p_unit_cost_minor bigint, p_occurred_at timestamptz, p_actor_id uuid, p_device_id uuid,
 p_correlation_id uuid, p_causation_id uuid, p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE current_qty numeric; current_value numeric; new_qty numeric; value_delta numeric;
DECLARE existing kasira.inventory_ledger;
BEGIN
 SELECT * INTO existing FROM kasira.inventory_ledger WHERE tenant_id=p_tenant_id AND event_id=p_event_id;
 IF FOUND THEN
   IF existing.warehouse_id<>p_warehouse_id OR existing.product_variant_id<>p_product_variant_id
      OR existing.event_type<>p_event_type OR existing.quantity<>p_quantity
      OR existing.unit_cost_minor IS DISTINCT FROM p_unit_cost_minor
   THEN RAISE EXCEPTION 'INVENTORY_EVENT_ID_REUSE'; END IF;
   RETURN p_event_id;
 END IF;
 IF p_quantity=0 THEN RAISE EXCEPTION 'inventory quantity cannot be zero'; END IF;
 IF p_unit_cost_minor IS NULL OR p_unit_cost_minor<0 THEN RAISE EXCEPTION 'inventory cost is required and must be non-negative'; END IF;
 INSERT INTO kasira.inventory_projection(tenant_id,warehouse_id,product_variant_id)
 VALUES(p_tenant_id,p_warehouse_id,p_product_variant_id) ON CONFLICT DO NOTHING;
 SELECT quantity_on_hand,inventory_value_minor INTO current_qty,current_value
 FROM kasira.inventory_projection
 WHERE tenant_id=p_tenant_id AND warehouse_id=p_warehouse_id AND product_variant_id=p_product_variant_id FOR UPDATE;
 new_qty:=current_qty+p_quantity;
 IF new_qty<0 THEN RAISE EXCEPTION 'INSUFFICIENT_STOCK'; END IF;
 value_delta:=p_quantity*p_unit_cost_minor;
 IF current_value+value_delta<0 THEN RAISE EXCEPTION 'INVENTORY_VALUE_UNDERFLOW'; END IF;
 INSERT INTO kasira.inventory_ledger(tenant_id,warehouse_id,product_variant_id,event_id,event_type,quantity,unit_cost_minor,occurred_at,actor_id,device_id,correlation_id,causation_id,metadata)
 VALUES(p_tenant_id,p_warehouse_id,p_product_variant_id,p_event_id,p_event_type,p_quantity,p_unit_cost_minor,p_occurred_at,p_actor_id,p_device_id,p_correlation_id,p_causation_id,p_metadata);
 UPDATE kasira.inventory_projection SET quantity_on_hand=new_qty,inventory_value_minor=current_value+value_delta,updated_at=now()
 WHERE tenant_id=p_tenant_id AND warehouse_id=p_warehouse_id AND product_variant_id=p_product_variant_id;
 IF p_quantity>0 THEN
   INSERT INTO kasira.cost_layer(tenant_id,warehouse_id,product_variant_id,source_event_id,received_at,unit_cost_minor,original_quantity,remaining_quantity)
   VALUES(p_tenant_id,p_warehouse_id,p_product_variant_id,p_event_id,p_occurred_at,p_unit_cost_minor,p_quantity,p_quantity);
 END IF;
 RETURN p_event_id;
END $$;

CREATE OR REPLACE FUNCTION kasira.post_inventory_sale(
 p_tenant_id uuid, p_warehouse_id uuid, p_product_variant_id uuid, p_event_id uuid, p_quantity numeric,
 p_occurred_at timestamptz, p_actor_id uuid, p_device_id uuid, p_correlation_id uuid, p_causation_id uuid,
 p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS numeric LANGUAGE plpgsql AS $$
DECLARE total_cost numeric; existing kasira.inventory_ledger;
BEGIN
 SELECT * INTO existing FROM kasira.inventory_ledger WHERE tenant_id=p_tenant_id AND event_id=p_event_id;
 IF FOUND THEN
   IF existing.event_type<>'SALE' OR existing.quantity<>-p_quantity THEN RAISE EXCEPTION 'INVENTORY_EVENT_ID_REUSE'; END IF;
   RETURN COALESCE((existing.metadata->>'cogs_total_minor')::numeric,abs(existing.quantity*existing.unit_cost_minor));
 END IF;
 total_cost:=kasira.consume_inventory_fifo(p_tenant_id,p_warehouse_id,p_product_variant_id,p_quantity);
 PERFORM kasira.post_inventory_event(p_tenant_id,p_warehouse_id,p_product_variant_id,p_event_id,'SALE',-p_quantity,
   total_cost/p_quantity,p_occurred_at,p_actor_id,p_device_id,p_correlation_id,p_causation_id,
   p_metadata||jsonb_build_object('cogs_total_minor',total_cost));
 RETURN total_cost;
END $$;

CREATE OR REPLACE FUNCTION kasira.close_cash_shift(
 p_tenant_id uuid, p_shift_id uuid, p_business_date date, p_expected_cash_minor bigint,
 p_actual_cash_minor bigint, p_actor_id uuid, p_occurred_at timestamptz
) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE shift kasira.cash_shift; prior kasira.cash_closing;
DECLARE closing_id uuid:=gen_random_uuid(); variance bigint;
BEGIN
 SELECT * INTO shift FROM kasira.cash_shift WHERE tenant_id=p_tenant_id AND id=p_shift_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'CASH_SHIFT_NOT_FOUND'; END IF;
 SELECT * INTO prior FROM kasira.cash_closing WHERE tenant_id=p_tenant_id AND cash_shift_id=p_shift_id;
 IF FOUND THEN
   IF prior.expected_cash_minor<>p_expected_cash_minor OR prior.actual_cash_minor<>p_actual_cash_minor
   THEN RAISE EXCEPTION 'CASH_CLOSING_IDEMPOTENCY_CONFLICT'; END IF;
   RETURN prior.id;
 END IF;
 IF shift.status<>'OPEN' THEN RAISE EXCEPTION 'CASH_SHIFT_ALREADY_CLOSED'; END IF;
 IF shift.business_date<>p_business_date THEN RAISE EXCEPTION 'CASH_BUSINESS_DATE_MISMATCH'; END IF;
 variance:=p_actual_cash_minor-p_expected_cash_minor;
 INSERT INTO kasira.cash_closing(tenant_id,cash_shift_id,business_date,expected_cash_minor,actual_cash_minor,status,actor_id,occurred_at)
 VALUES(p_tenant_id,p_shift_id,p_business_date,p_expected_cash_minor,p_actual_cash_minor,CASE WHEN variance=0 THEN 'BALANCED' ELSE 'VARIANCE' END,p_actor_id,p_occurred_at);
 UPDATE kasira.cash_shift SET status=CASE WHEN variance=0 THEN 'CLOSED' ELSE 'VARIANCE' END,closed_at=p_occurred_at WHERE tenant_id=p_tenant_id AND id=p_shift_id;
 IF variance<>0 THEN
   INSERT INTO kasira.variance_case(tenant_id,case_type,source_id,reason,variance_minor,actor_id)
   VALUES(p_tenant_id,'CASH',closing_id,'CASH_CLOSING_VARIANCE',variance,p_actor_id)
   ON CONFLICT DO NOTHING;
 END IF;
 RETURN closing_id;
END $$;

CREATE OR REPLACE FUNCTION kasira.close_cash_shift_from_ledger(
 p_tenant_id uuid, p_shift_id uuid, p_business_date date, p_actual_cash_minor bigint,
 p_actor_id uuid, p_occurred_at timestamptz
) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE expected_cash bigint;
BEGIN
 SELECT cs.opening_cash_minor + COALESCE(SUM(cl.amount_minor),0)
 INTO expected_cash
 FROM kasira.cash_shift cs LEFT JOIN kasira.cash_ledger cl
   ON cl.tenant_id=cs.tenant_id AND cl.cash_shift_id=cs.id
 WHERE cs.tenant_id=p_tenant_id AND cs.id=p_shift_id
 GROUP BY cs.id,cs.opening_cash_minor;
 IF expected_cash IS NULL THEN RAISE EXCEPTION 'CASH_SHIFT_NOT_FOUND'; END IF;
 RETURN kasira.close_cash_shift(p_tenant_id,p_shift_id,p_business_date,expected_cash,p_actual_cash_minor,p_actor_id,p_occurred_at);
END $$;

CREATE OR REPLACE FUNCTION kasira.create_payment_reconciliation(
 p_tenant_id uuid, p_outlet_id uuid, p_provider text, p_settlement_reference text,
 p_period_start date, p_period_end date, p_external_total_minor bigint
) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE internal_total bigint; rid uuid; prior kasira.payment_reconciliation;
BEGIN
 SELECT * INTO prior FROM kasira.payment_reconciliation
 WHERE tenant_id=p_tenant_id AND settlement_reference=p_settlement_reference;
 IF FOUND THEN
   IF prior.external_total_minor<>p_external_total_minor THEN RAISE EXCEPTION 'PAYMENT_RECONCILIATION_IDEMPOTENCY_CONFLICT'; END IF;
   RETURN prior.id;
 END IF;
 SELECT COALESCE(SUM(CASE WHEN status='REFUNDED' THEN -amount_minor ELSE amount_minor END),0)
 INTO internal_total FROM kasira.payment
 WHERE tenant_id=p_tenant_id AND provider=p_provider AND occurred_at>=p_period_start::timestamptz
   AND occurred_at<(p_period_end+1)::timestamptz AND status IN ('CAPTURED','REFUNDED');
 rid:=gen_random_uuid();
 INSERT INTO kasira.payment_reconciliation(id,tenant_id,outlet_id,provider,settlement_reference,period_start,period_end,internal_total_minor,external_total_minor,status)
 VALUES(rid,p_tenant_id,p_outlet_id,p_provider,p_settlement_reference,p_period_start,p_period_end,internal_total,p_external_total_minor,
   CASE WHEN internal_total=p_external_total_minor THEN 'MATCHED' ELSE 'VARIANCE' END);
 IF internal_total<>p_external_total_minor THEN
   INSERT INTO kasira.variance_case(tenant_id,case_type,source_id,reason,variance_minor)
   VALUES(p_tenant_id,'PAYMENT',rid,'PAYMENT_SETTLEMENT_VARIANCE',p_external_total_minor-internal_total)
   ON CONFLICT DO NOTHING;
 END IF;
 RETURN rid;
END $$;
