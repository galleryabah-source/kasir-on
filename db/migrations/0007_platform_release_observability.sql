-- Phase 7 foundation: release governance, feature flags, and operational evidence.
CREATE TABLE IF NOT EXISTS kasira.feature_flag (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 flag_key text NOT NULL, enabled boolean NOT NULL DEFAULT false, rollout_pct integer NOT NULL DEFAULT 0 CHECK(rollout_pct BETWEEN 0 AND 100),
 environment text NOT NULL DEFAULT 'production' CHECK(environment IN ('development','staging','production')),
 updated_by uuid, updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,flag_key,environment), FOREIGN KEY(tenant_id,updated_by) REFERENCES kasira.app_user(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.release_record (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 release_version text NOT NULL, commit_sha text NOT NULL, environment text NOT NULL CHECK(environment IN ('development','staging','production')),
 status text NOT NULL CHECK(status IN ('PLANNED','CANARY','ACTIVE','ROLLED_BACK','FAILED')),
 deployed_at timestamptz, rolled_back_at timestamptz, rollback_reason text, correlation_id uuid NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,release_version,environment), UNIQUE(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.operational_event (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 event_type text NOT NULL, severity text NOT NULL CHECK(severity IN ('INFO','WARN','ERROR','P0','P1')),
 outlet_id uuid, device_id uuid, actor_id uuid, transaction_id uuid, correlation_id uuid NOT NULL, causation_id uuid,
 occurred_at timestamptz NOT NULL, payload jsonb NOT NULL DEFAULT '{}'::jsonb,
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id),
 FOREIGN KEY(tenant_id,device_id) REFERENCES kasira.device(tenant_id,id),
 FOREIGN KEY(tenant_id,actor_id) REFERENCES kasira.app_user(tenant_id,id)
);
DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['feature_flag','release_record','operational_event'] LOOP
 EXECUTE format('ALTER TABLE kasira.%I ENABLE ROW LEVEL SECURITY',t); EXECUTE format('ALTER TABLE kasira.%I FORCE ROW LEVEL SECURITY',t);
 EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON kasira.%I',t);
 EXECUTE format('CREATE POLICY tenant_isolation ON kasira.%I AS RESTRICTIVE FOR ALL USING (tenant_id=kasira.current_tenant_id()) WITH CHECK (tenant_id=kasira.current_tenant_id())',t);
END LOOP; END $$;
CREATE INDEX IF NOT EXISTS idx_operational_event_correlation ON kasira.operational_event(tenant_id,correlation_id,occurred_at);
CREATE INDEX IF NOT EXISTS idx_release_record_active ON kasira.release_record(tenant_id,environment,status,deployed_at);
