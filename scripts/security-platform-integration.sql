\set ON_ERROR_STOP on
BEGIN;
INSERT INTO kasira.tenant(code,name) VALUES ('SECURITY-GATE','Security Gate Tenant') ON CONFLICT(code) DO NOTHING;
SELECT set_config('app.tenant_id',(SELECT id::text FROM kasira.tenant WHERE code='SECURITY-GATE'),true);
DO $$ DECLARE t uuid; b uuid; o1 uuid; o2 uuid; u uuid; r uuid; p uuid; d uuid;
BEGIN
 SELECT id INTO t FROM kasira.tenant WHERE code='SECURITY-GATE';
 INSERT INTO kasira.brand(tenant_id,code,name) VALUES(t,'SEC','Security') ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name RETURNING id INTO b;
 INSERT INTO kasira.outlet(tenant_id,brand_id,code,name) VALUES(t,b,'SEC-01','Security Outlet 1') ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name RETURNING id INTO o1;
 INSERT INTO kasira.outlet(tenant_id,brand_id,code,name) VALUES(t,b,'SEC-02','Security Outlet 2') ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name RETURNING id INTO o2;
 INSERT INTO kasira.app_user(tenant_id,email,display_name) VALUES(t,'security-gate@example.invalid','Security Tester') ON CONFLICT(tenant_id,email) DO UPDATE SET display_name=EXCLUDED.display_name RETURNING id INTO u;
 INSERT INTO kasira.role(tenant_id,code,name) VALUES(t,'OUTLET_MANAGER','Outlet Manager') ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name RETURNING id INTO r;
 SELECT id INTO p FROM kasira.permission WHERE code='outlet.read';
 INSERT INTO kasira.role_permission(tenant_id,role_id,permission_id) VALUES(t,r,p) ON CONFLICT DO NOTHING;
 INSERT INTO kasira.user_role(tenant_id,user_id,role_id) VALUES(t,u,r) ON CONFLICT DO NOTHING;
 INSERT INTO kasira.user_outlet_scope(tenant_id,user_id,outlet_id) VALUES(t,u,o1) ON CONFLICT DO NOTHING;
 INSERT INTO kasira.device(tenant_id,outlet_id,device_code,platform,app_version,trust_status,last_attested_at) VALUES(t,o1,'SEC-DEVICE-01','TEST','1.0.0','TRUSTED',now()) ON CONFLICT(tenant_id,device_code) DO UPDATE SET trust_status='TRUSTED',outlet_id=EXCLUDED.outlet_id RETURNING id INTO d;
 IF NOT kasira.has_permission(t,u,'outlet.read') THEN RAISE EXCEPTION 'PERMISSION_CHECK_FAILED'; END IF;
 IF NOT kasira.has_outlet_access(t,u,o1) THEN RAISE EXCEPTION 'OUTLET_SCOPE_CHECK_FAILED'; END IF;
 IF kasira.has_outlet_access(t,u,o2) THEN RAISE EXCEPTION 'CROSS_OUTLET_SCOPE_BYPASS'; END IF;
 IF NOT kasira.assert_trusted_device(t,d,o1) THEN RAISE EXCEPTION 'TRUSTED_DEVICE_CHECK_FAILED'; END IF;
 UPDATE kasira.device SET trust_status='REVOKED',revoked_reason='SECURITY_TEST',last_attested_at=now() WHERE tenant_id=t AND id=d;
 IF kasira.assert_trusted_device(t,d,o1) THEN RAISE EXCEPTION 'REVOKED_DEVICE_BYPASS'; END IF;
 RAISE NOTICE 'SECURITY PLATFORM GATE: PASS';
END $$;
ROLLBACK;
