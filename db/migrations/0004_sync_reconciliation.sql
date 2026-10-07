CREATE TABLE IF NOT EXISTS kasira.sync_inbox (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 device_id uuid,
 event_id uuid NOT NULL,
 aggregate_id uuid NOT NULL,
 event_type text NOT NULL,
 event_version integer NOT NULL CHECK(event_version>0),
 idempotency_key text NOT NULL,
 request_hash text NOT NULL,
 correlation_id uuid NOT NULL,
 causation_id uuid,
 payload jsonb NOT NULL,
 status text NOT NULL CHECK(status IN ('ACCEPTED','DUPLICATE','CONFLICT','REJECTED')),
 server_sequence bigint,
 server_cursor bigint,
 response_code integer,
 response_body jsonb,
 received_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,event_id),
 UNIQUE(tenant_id,idempotency_key),
 FOREIGN KEY(tenant_id,device_id) REFERENCES kasira.device(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.device_sync_cursor (
 tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 device_id uuid NOT NULL,
 next_server_cursor bigint NOT NULL DEFAULT 1 CHECK(next_server_cursor>0),
 last_acked_sequence bigint NOT NULL DEFAULT 0 CHECK(last_acked_sequence>=0),
 pending_count bigint NOT NULL DEFAULT 0 CHECK(pending_count>=0),
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(tenant_id,device_id),
 FOREIGN KEY(tenant_id,device_id) REFERENCES kasira.device(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.sync_telemetry (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 device_id uuid, event_id uuid, idempotency_key text,
 attempt integer NOT NULL CHECK(attempt>=1),
 outcome text NOT NULL CHECK(outcome IN ('ACK','DUPLICATE','RETRY','CONFLICT','REJECTED')),
 latency_ms integer CHECK(latency_ms>=0), error_code text, observed_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,device_id) REFERENCES kasira.device(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.reconciliation_run (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 outlet_id uuid, device_id uuid, period_start date NOT NULL, period_end date NOT NULL,
 local_transaction_count bigint NOT NULL CHECK(local_transaction_count>=0),
 server_transaction_count bigint NOT NULL CHECK(server_transaction_count>=0),
 local_total_minor bigint NOT NULL CHECK(local_total_minor>=0),
 server_total_minor bigint NOT NULL CHECK(server_total_minor>=0),
 local_payment_total_minor bigint NOT NULL CHECK(local_payment_total_minor>=0),
 server_payment_total_minor bigint NOT NULL CHECK(server_payment_total_minor>=0),
 outstanding_sync_count bigint NOT NULL CHECK(outstanding_sync_count>=0),
 status text NOT NULL CHECK(status IN ('PASS','RECONCILIATION_REQUIRED')), mismatch_reason text,
 created_at timestamptz NOT NULL DEFAULT now(), CHECK(period_end>=period_start),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id),
 FOREIGN KEY(tenant_id,device_id) REFERENCES kasira.device(tenant_id,id)
);
CREATE INDEX IF NOT EXISTS idx_sync_inbox_cursor ON kasira.sync_inbox(tenant_id,server_cursor);
CREATE INDEX IF NOT EXISTS idx_sync_telemetry_event ON kasira.sync_telemetry(tenant_id,event_id,observed_at);
ALTER TABLE kasira.device_sync_cursor ENABLE ROW LEVEL SECURITY;
ALTER TABLE kasira.sync_inbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE kasira.sync_telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE kasira.reconciliation_run ENABLE ROW LEVEL SECURITY;
ALTER TABLE kasira.device_sync_cursor FORCE ROW LEVEL SECURITY;
ALTER TABLE kasira.sync_inbox FORCE ROW LEVEL SECURITY;
ALTER TABLE kasira.sync_telemetry FORCE ROW LEVEL SECURITY;
ALTER TABLE kasira.reconciliation_run FORCE ROW LEVEL SECURITY;
CREATE POLICY sync_cursor_tenant ON kasira.device_sync_cursor USING (tenant_id=kasira.current_tenant_id()) WITH CHECK (tenant_id=kasira.current_tenant_id());
CREATE POLICY sync_inbox_tenant ON kasira.sync_inbox USING (tenant_id=kasira.current_tenant_id()) WITH CHECK (tenant_id=kasira.current_tenant_id());
CREATE POLICY sync_telemetry_tenant ON kasira.sync_telemetry USING (tenant_id=kasira.current_tenant_id()) WITH CHECK (tenant_id=kasira.current_tenant_id());
CREATE POLICY reconciliation_tenant ON kasira.reconciliation_run USING (tenant_id=kasira.current_tenant_id()) WITH CHECK (tenant_id=kasira.current_tenant_id());
