\set ON_ERROR_STOP on
BEGIN;
INSERT INTO kasira.tenant(code,name) VALUES
 ('PHASE6B-TENANT','Phase 6B Tenant'),
 ('PHASE6B-OTHER','Phase 6B Other Tenant')
ON CONFLICT(code) DO NOTHING;
SELECT set_config('app.tenant_id',(SELECT id::text FROM kasira.tenant WHERE code='PHASE6B-TENANT'),true);

DO $phase6b_test$
DECLARE
  t uuid; other_t uuid; b uuid; o1 uuid; o2 uuid; u uuid; u_all uuid;
  r uuid; r_all uuid; p_read uuid; p_all uuid; d uuid; other_o uuid;
BEGIN
  SELECT id INTO t FROM kasira.tenant WHERE code='PHASE6B-TENANT';
  SELECT id INTO other_t FROM kasira.tenant WHERE code='PHASE6B-OTHER';

  INSERT INTO kasira.brand(tenant_id,code,name) VALUES(t,'P6B','Phase6B')
    ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name RETURNING id INTO b;
  INSERT INTO kasira.outlet(tenant_id,brand_id,code,name) VALUES
    (t,b,'P6B-01','Outlet 1'),(t,b,'P6B-02','Outlet 2')
    ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name;
  SELECT id INTO o1 FROM kasira.outlet WHERE tenant_id=t AND code='P6B-01';
  SELECT id INTO o2 FROM kasira.outlet WHERE tenant_id=t AND code='P6B-02';

  INSERT INTO kasira.brand(tenant_id,code,name) VALUES(other_t,'OTHER','Other')
    ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name RETURNING id INTO b;
  INSERT INTO kasira.outlet(tenant_id,brand_id,code,name) VALUES(other_t,b,'OTHER-01','Other Tenant Outlet')
    ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name RETURNING id INTO other_o;

  INSERT INTO kasira.app_user(tenant_id,email,display_name) VALUES(t,'phase6b@example.invalid','Phase6B User')
    ON CONFLICT(tenant_id,email) DO UPDATE SET display_name=EXCLUDED.display_name RETURNING id INTO u;
  INSERT INTO kasira.app_user(tenant_id,email,display_name) VALUES(t,'phase6b-all@example.invalid','Phase6B All')
    ON CONFLICT(tenant_id,email) DO UPDATE SET display_name=EXCLUDED.display_name RETURNING id INTO u_all;

  INSERT INTO kasira.role(tenant_id,code,name) VALUES(t,'P6B-OUTLET','Phase6B Outlet')
    ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name RETURNING id INTO r;
  INSERT INTO kasira.role(tenant_id,code,name) VALUES(t,'P6B-ALL','Phase6B All Scope')
    ON CONFLICT(tenant_id,code) DO UPDATE SET name=EXCLUDED.name RETURNING id INTO r_all;

  SELECT id INTO p_read FROM kasira.permission WHERE code='outlet.read';
  SELECT id INTO p_all FROM kasira.permission WHERE code='outlet.scope_all';

  INSERT INTO kasira.role_permission(tenant_id,role_id,permission_id)
  VALUES(t,r,p_read),(t,r_all,p_read),(t,r_all,p_all)
  ON CONFLICT DO NOTHING;
  INSERT INTO kasira.user_role(tenant_id,user_id,role_id)
  VALUES(t,u,r),(t,u_all,r_all)
  ON CONFLICT DO NOTHING;
  INSERT INTO kasira.user_outlet_scope(tenant_id,user_id,outlet_id)
  VALUES(t,u,o1)
  ON CONFLICT DO NOTHING;

  IF NOT kasira.has_outlet_access(t,u,o1) THEN RAISE EXCEPTION 'ASSIGNED_OUTLET_NOT_ALLOWED'; END IF;
  IF kasira.has_outlet_access(t,u,o2) THEN RAISE EXCEPTION 'UNASSIGNED_OUTLET_ALLOWED'; END IF;
  BEGIN
    PERFORM kasira.assert_outlet_access(t,u,o2);
    RAISE EXCEPTION 'DENIAL_NOT_ENFORCED';
  EXCEPTION WHEN others THEN
    IF SQLERRM <> 'OUTLET_SCOPE_DENIED' THEN RAISE; END IF;
  END;

  IF NOT kasira.has_outlet_access(t,u_all,o2) THEN RAISE EXCEPTION 'SCOPE_ALL_NOT_ALLOWED'; END IF;
  IF kasira.has_outlet_access(other_t,u,o1) THEN RAISE EXCEPTION 'CROSS_TENANT_BYPASS'; END IF;

  INSERT INTO kasira.device(tenant_id,outlet_id,device_code,platform,app_version,trust_status,last_attested_at)
    VALUES(t,o1,'P6B-DEVICE','TEST','1.0.0','TRUSTED',now())
    ON CONFLICT(tenant_id,device_code) DO UPDATE SET outlet_id=EXCLUDED.outlet_id,trust_status='TRUSTED'
    RETURNING id INTO d;
  IF NOT kasira.assert_trusted_device(t,d,o1) THEN RAISE EXCEPTION 'TRUSTED_DEVICE_ALLOWED_CHECK_FAILED'; END IF;
  IF kasira.assert_trusted_device(t,d,o2) THEN RAISE EXCEPTION 'DEVICE_OUTLET_BYPASS'; END IF;

  UPDATE kasira.device SET trust_status='REVOKED',revoked_reason='PHASE6B_TEST' WHERE tenant_id=t AND id=d;
  IF kasira.assert_trusted_device(t,d,o1) THEN RAISE EXCEPTION 'REVOKED_DEVICE_BYPASS'; END IF;

  RAISE NOTICE 'PHASE 6B RUNTIME OUTLET ISOLATION: PASS';
END $phase6b_test$;
ROLLBACK;
