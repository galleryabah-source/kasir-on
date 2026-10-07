-- Security foundation: explicit outlet scope, permissions, and device attestation/revocation evidence.
CREATE TABLE IF NOT EXISTS kasira.permission (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text NOT NULL UNIQUE, name text NOT NULL
);
CREATE TABLE IF NOT EXISTS kasira.role_permission (
 tenant_id uuid NOT NULL REFERENCES kasira.tenant(id), role_id uuid NOT NULL, permission_id uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(tenant_id,role_id,permission_id),
 FOREIGN KEY(tenant_id,role_id) REFERENCES kasira.role(tenant_id,id), FOREIGN KEY(permission_id) REFERENCES kasira.permission(id)
);
CREATE TABLE IF NOT EXISTS kasira.user_outlet_scope (
 tenant_id uuid NOT NULL REFERENCES kasira.tenant(id), user_id uuid NOT NULL, outlet_id uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(tenant_id,user_id,outlet_id),
 FOREIGN KEY(tenant_id,user_id) REFERENCES kasira.app_user(tenant_id,id), FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id)
);
ALTER TABLE kasira.device ADD COLUMN IF NOT EXISTS revoked_reason text;
ALTER TABLE kasira.device ADD COLUMN IF NOT EXISTS last_attested_at timestamptz;
ALTER TABLE kasira.device ADD COLUMN IF NOT EXISTS minimum_app_version text;
INSERT INTO kasira.permission(code,name) VALUES
 ('outlet.read','Read outlet data'),('outlet.manage','Manage outlet data'),('outlet.scope_all','Access all outlets in tenant'),
 ('device.manage','Register/revoke devices'),('finance.approve','Approve high-risk financial actions'),('inventory.adjust','Post inventory adjustments'),
 ('audit.read','Read audit evidence') ON CONFLICT(code) DO NOTHING;
DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['role_permission','user_outlet_scope'] LOOP
 EXECUTE format('ALTER TABLE kasira.%I ENABLE ROW LEVEL SECURITY',t); EXECUTE format('ALTER TABLE kasira.%I FORCE ROW LEVEL SECURITY',t);
 EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON kasira.%I',t);
 EXECUTE format('CREATE POLICY tenant_isolation ON kasira.%I AS RESTRICTIVE FOR ALL USING (tenant_id=kasira.current_tenant_id()) WITH CHECK (tenant_id=kasira.current_tenant_id())',t);
END LOOP; END $$;
CREATE OR REPLACE FUNCTION kasira.has_permission(p_tenant_id uuid,p_user_id uuid,p_permission_code text)
RETURNS boolean LANGUAGE sql STABLE AS $$
 SELECT p_tenant_id=kasira.current_tenant_id() AND EXISTS (
   SELECT 1 FROM kasira.user_role ur JOIN kasira.role_permission rp ON rp.tenant_id=ur.tenant_id AND rp.role_id=ur.role_id
   JOIN kasira.permission p ON p.id=rp.permission_id
   WHERE ur.tenant_id=p_tenant_id AND ur.user_id=p_user_id AND p.code=p_permission_code
 ); $$;
CREATE OR REPLACE FUNCTION kasira.has_outlet_access(p_tenant_id uuid,p_user_id uuid,p_outlet_id uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
 SELECT p_tenant_id=kasira.current_tenant_id() AND EXISTS (
   SELECT 1 FROM kasira.user_outlet_scope s WHERE s.tenant_id=p_tenant_id AND s.user_id=p_user_id AND s.outlet_id=p_outlet_id
 ) OR kasira.has_permission(p_tenant_id,p_user_id,'outlet.scope_all'); $$;
CREATE OR REPLACE FUNCTION kasira.assert_trusted_device(p_tenant_id uuid,p_device_id uuid,p_outlet_id uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
 SELECT EXISTS (SELECT 1 FROM kasira.device d WHERE d.tenant_id=p_tenant_id AND d.id=p_device_id AND d.outlet_id=p_outlet_id AND d.trust_status='TRUSTED' AND (d.minimum_app_version IS NULL OR d.minimum_app_version<=d.app_version)); $$;
