-- Phase 5: Pilot Readiness operational evidence.
CREATE TABLE IF NOT EXISTS kasira.pilot_run (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 name text NOT NULL, outlet_target integer NOT NULL CHECK(outlet_target BETWEEN 5 AND 10),
 started_at timestamptz NOT NULL, ended_at timestamptz,
 status text NOT NULL DEFAULT 'RUNNING' CHECK(status IN ('RUNNING','PASS','FAIL')),
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.pilot_outlet (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 pilot_run_id uuid NOT NULL, outlet_id uuid NOT NULL, cashier_target integer NOT NULL CHECK(cashier_target>0),
 cashier_active integer NOT NULL DEFAULT 0 CHECK(cashier_active>=0 AND cashier_active<=cashier_target),
 first_seen_at timestamptz NOT NULL, last_seen_at timestamptz,
 status text NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','BLOCKED','COMPLETED')),
 UNIQUE(tenant_id,pilot_run_id,outlet_id), UNIQUE(tenant_id,id),
 FOREIGN KEY(tenant_id,pilot_run_id) REFERENCES kasira.pilot_run(tenant_id,id),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.pilot_metric (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 pilot_run_id uuid NOT NULL, outlet_id uuid, metric_name text NOT NULL,
 metric_value numeric(30,6) NOT NULL, unit text NOT NULL, observed_at timestamptz NOT NULL,
 evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
 UNIQUE(tenant_id,pilot_run_id,metric_name,outlet_id,observed_at),
 FOREIGN KEY(tenant_id,pilot_run_id) REFERENCES kasira.pilot_run(tenant_id,id),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.support_incident (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 pilot_run_id uuid NOT NULL, outlet_id uuid, severity text NOT NULL CHECK(severity IN ('P0','P1','P2','P3')),
 category text NOT NULL, status text NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','RESOLVED','ACCEPTED')),
 opened_at timestamptz NOT NULL, resolved_at timestamptz, description text NOT NULL,
 UNIQUE(tenant_id,id), FOREIGN KEY(tenant_id,pilot_run_id) REFERENCES kasira.pilot_run(tenant_id,id),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.uptime_heartbeat (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 pilot_run_id uuid NOT NULL, outlet_id uuid NOT NULL, device_id uuid,
 observed_at timestamptz NOT NULL, status text NOT NULL CHECK(status IN ('UP','DOWN')),
 latency_ms integer CHECK(latency_ms>=0), evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
 UNIQUE(tenant_id,pilot_run_id,outlet_id,observed_at),
 FOREIGN KEY(tenant_id,pilot_run_id) REFERENCES kasira.pilot_run(tenant_id,id),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id),
 FOREIGN KEY(tenant_id,device_id) REFERENCES kasira.device(tenant_id,id)
);
CREATE INDEX IF NOT EXISTS idx_pilot_metric_lookup ON kasira.pilot_metric(tenant_id,pilot_run_id,metric_name,observed_at);
CREATE INDEX IF NOT EXISTS idx_pilot_heartbeat_lookup ON kasira.uptime_heartbeat(tenant_id,pilot_run_id,outlet_id,observed_at);
CREATE INDEX IF NOT EXISTS idx_support_incident_lookup ON kasira.support_incident(tenant_id,pilot_run_id,status,severity);

ALTER TABLE kasira.pilot_run ENABLE ROW LEVEL SECURITY;
ALTER TABLE kasira.pilot_outlet ENABLE ROW LEVEL SECURITY;
ALTER TABLE kasira.pilot_metric ENABLE ROW LEVEL SECURITY;
ALTER TABLE kasira.support_incident ENABLE ROW LEVEL SECURITY;
ALTER TABLE kasira.uptime_heartbeat ENABLE ROW LEVEL SECURITY;
ALTER TABLE kasira.pilot_run FORCE ROW LEVEL SECURITY;
ALTER TABLE kasira.pilot_outlet FORCE ROW LEVEL SECURITY;
ALTER TABLE kasira.pilot_metric FORCE ROW LEVEL SECURITY;
ALTER TABLE kasira.support_incident FORCE ROW LEVEL SECURITY;
ALTER TABLE kasira.uptime_heartbeat FORCE ROW LEVEL SECURITY;

DO $ BEGIN CREATE POLICY pilot_run_tenant ON kasira.pilot_run USING (tenant_id=kasira.current_tenant_id()) WITH CHECK (tenant_id=kasira.current_tenant_id()); EXCEPTION WHEN duplicate_object THEN NULL; END $;
DO $ BEGIN CREATE POLICY pilot_outlet_tenant ON kasira.pilot_outlet USING (tenant_id=kasira.current_tenant_id()) WITH CHECK (tenant_id=kasira.current_tenant_id()); EXCEPTION WHEN duplicate_object THEN NULL; END $;
DO $ BEGIN CREATE POLICY pilot_metric_tenant ON kasira.pilot_metric USING (tenant_id=kasira.current_tenant_id()) WITH CHECK (tenant_id=kasira.current_tenant_id()); EXCEPTION WHEN duplicate_object THEN NULL; END $;
DO $ BEGIN CREATE POLICY support_incident_tenant ON kasira.support_incident USING (tenant_id=kasira.current_tenant_id()) WITH CHECK (tenant_id=kasira.current_tenant_id()); EXCEPTION WHEN duplicate_object THEN NULL; END $;
DO $ BEGIN CREATE POLICY uptime_heartbeat_tenant ON kasira.uptime_heartbeat USING (tenant_id=kasira.current_tenant_id()) WITH CHECK (tenant_id=kasira.current_tenant_id()); EXCEPTION WHEN duplicate_object THEN NULL; END $;

CREATE OR REPLACE FUNCTION kasira.pilot_gate(p_tenant_id uuid,p_pilot_run_id uuid)
RETURNS TABLE(status text,reason text) LANGUAGE sql AS $$
WITH m AS (
 SELECT metric_name, AVG(metric_value) value FROM kasira.pilot_metric WHERE tenant_id=p_tenant_id AND pilot_run_id=p_pilot_run_id GROUP BY metric_name
), u AS (
 SELECT COALESCE(100.0*AVG((status='UP')::int),0) uptime_pct FROM kasira.uptime_heartbeat WHERE tenant_id=p_tenant_id AND pilot_run_id=p_pilot_run_id
), i AS (
 SELECT COUNT(*) FILTER (WHERE status='OPEN' AND severity IN ('P0','P1')) critical_incidents FROM kasira.support_incident WHERE tenant_id=p_tenant_id AND pilot_run_id=p_pilot_run_id
), o AS (
 SELECT COUNT(*) outlets, COUNT(*) FILTER (WHERE status='COMPLETED') completed FROM kasira.pilot_outlet WHERE tenant_id=p_tenant_id AND pilot_run_id=p_pilot_run_id
)
SELECT CASE WHEN o.outlets BETWEEN 5 AND 10 AND o.completed=o.outlets
 AND COALESCE((SELECT value FROM m WHERE metric_name='checkout_latency_p95_ms'),999999)<=1500
 AND COALESCE((SELECT value FROM m WHERE metric_name='offline_duration_hours'),0)>=24
 AND COALESCE((SELECT value FROM m WHERE metric_name='sync_success_rate_pct'),0)>=99
 AND COALESCE((SELECT value FROM m WHERE metric_name='reconciliation_exception_rate_pct'),999999)<=1
 AND COALESCE((SELECT value FROM m WHERE metric_name='payment_success_rate_pct'),0)>=99
 AND COALESCE((SELECT value FROM m WHERE metric_name='inventory_integrity_pct'),0)>=100
 AND COALESCE((SELECT value FROM m WHERE metric_name='cashier_adoption_pct'),0)>=80
 AND u.uptime_pct>=99 AND i.critical_incidents=0
 THEN 'PASS' ELSE 'FAIL' END,
 CASE WHEN o.outlets NOT BETWEEN 5 AND 10 THEN 'OUTLET_COUNT'
 WHEN o.completed<>o.outlets THEN 'OUTLET_COMPLETION'
 WHEN COALESCE((SELECT value FROM m WHERE metric_name='checkout_latency_p95_ms'),999999)>1500 THEN 'CHECKOUT_LATENCY'
 WHEN COALESCE((SELECT value FROM m WHERE metric_name='offline_duration_hours'),0)<24 THEN 'OFFLINE_DURATION'
 WHEN COALESCE((SELECT value FROM m WHERE metric_name='sync_success_rate_pct'),0)<99 THEN 'SYNC_SUCCESS'
 WHEN COALESCE((SELECT value FROM m WHERE metric_name='reconciliation_exception_rate_pct'),999999)>1 THEN 'RECONCILIATION'
 WHEN COALESCE((SELECT value FROM m WHERE metric_name='payment_success_rate_pct'),0)<99 THEN 'PAYMENT_SUCCESS'
 WHEN COALESCE((SELECT value FROM m WHERE metric_name='inventory_integrity_pct'),0)<100 THEN 'INVENTORY_INTEGRITY'
 WHEN COALESCE((SELECT value FROM m WHERE metric_name='cashier_adoption_pct'),0)<80 THEN 'CASHIER_ADOPTION'
 WHEN u.uptime_pct<99 THEN 'UPTIME'
 WHEN i.critical_incidents>0 THEN 'CRITICAL_INCIDENT'
 ELSE 'UNKNOWN' END
FROM o,u,i;
$$;
