CREATE TABLE IF NOT EXISTS kasira.cash_ledger (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id), outlet_id uuid NOT NULL,
 event_id uuid NOT NULL UNIQUE, event_type text NOT NULL CHECK(event_type IN ('OPENING','SALE','CASH_IN','CASH_OUT','REFUND','CLOSING','ADJUSTMENT')),
 amount_minor bigint NOT NULL, currency char(3) NOT NULL DEFAULT 'IDR', business_date date NOT NULL,
 occurred_at timestamptz NOT NULL, actor_id uuid, device_id uuid, correlation_id uuid NOT NULL, causation_id uuid,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id),
 FOREIGN KEY(tenant_id,actor_id) REFERENCES kasira.app_user(tenant_id,id),
 FOREIGN KEY(tenant_id,device_id) REFERENCES kasira.device(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.inventory_ledger (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id), warehouse_id uuid NOT NULL,
 product_variant_id uuid NOT NULL, event_id uuid NOT NULL UNIQUE,
 event_type text NOT NULL CHECK(event_type IN ('OPENING','PURCHASE','SALE','TRANSFER_IN','TRANSFER_OUT','ADJUSTMENT','OPNAME','RETURN')),
 quantity numeric(18,6) NOT NULL CHECK(quantity<>0), unit_cost_minor bigint CHECK(unit_cost_minor IS NULL OR unit_cost_minor>=0),
 occurred_at timestamptz NOT NULL, actor_id uuid, device_id uuid, correlation_id uuid NOT NULL, causation_id uuid,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,warehouse_id) REFERENCES kasira.warehouse(tenant_id,id),
 FOREIGN KEY(tenant_id,product_variant_id) REFERENCES kasira.product_variant(tenant_id,id),
 FOREIGN KEY(tenant_id,actor_id) REFERENCES kasira.app_user(tenant_id,id),
 FOREIGN KEY(tenant_id,device_id) REFERENCES kasira.device(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.audit_log (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id), actor_id uuid, device_id uuid,
 action text NOT NULL, entity_type text NOT NULL, entity_id uuid, before_state jsonb, after_state jsonb,
 correlation_id uuid NOT NULL, causation_id uuid, occurred_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,actor_id) REFERENCES kasira.app_user(tenant_id,id),
 FOREIGN KEY(tenant_id,device_id) REFERENCES kasira.device(tenant_id,id)
);
CREATE OR REPLACE FUNCTION kasira.current_tenant_id() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT NULLIF(current_setting('app.tenant_id',true),'')::uuid
$$;
CREATE OR REPLACE FUNCTION kasira.prevent_ledger_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Immutable ledger: % cannot be updated or deleted',TG_TABLE_NAME; END;
$$;
CREATE OR REPLACE FUNCTION kasira.prevent_audit_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Immutable audit log'; END;
$$;
DROP TRIGGER IF EXISTS sales_ledger_immutable ON kasira.sales_ledger;
CREATE TRIGGER sales_ledger_immutable BEFORE UPDATE OR DELETE ON kasira.sales_ledger FOR EACH ROW EXECUTE FUNCTION kasira.prevent_ledger_mutation();
DROP TRIGGER IF EXISTS cash_ledger_immutable ON kasira.cash_ledger;
CREATE TRIGGER cash_ledger_immutable BEFORE UPDATE OR DELETE ON kasira.cash_ledger FOR EACH ROW EXECUTE FUNCTION kasira.prevent_ledger_mutation();
DROP TRIGGER IF EXISTS inventory_ledger_immutable ON kasira.inventory_ledger;
CREATE TRIGGER inventory_ledger_immutable BEFORE UPDATE OR DELETE ON kasira.inventory_ledger FOR EACH ROW EXECUTE FUNCTION kasira.prevent_ledger_mutation();
DROP TRIGGER IF EXISTS audit_log_immutable ON kasira.audit_log;
CREATE TRIGGER audit_log_immutable BEFORE UPDATE OR DELETE ON kasira.audit_log FOR EACH ROW EXECUTE FUNCTION kasira.prevent_audit_mutation();
DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['brand','outlet','warehouse','device','app_user','role','user_role','product','product_variant','price_version','order_header','order_item','idempotency_record','payment','sales_ledger','cash_ledger','inventory_ledger','audit_log'] LOOP
  EXECUTE format('ALTER TABLE kasira.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('ALTER TABLE kasira.%I FORCE ROW LEVEL SECURITY',t);
  EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON kasira.%I',t);
  EXECUTE format('CREATE POLICY tenant_isolation ON kasira.%I AS RESTRICTIVE FOR ALL USING (tenant_id=kasira.current_tenant_id()) WITH CHECK (tenant_id=kasira.current_tenant_id())',t);
 END LOOP;
END $$;
