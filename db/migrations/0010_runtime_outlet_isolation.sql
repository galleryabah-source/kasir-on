-- Phase 6B: runtime outlet isolation
-- Authorization boundary only. No business ledger semantics are changed.
CREATE OR REPLACE FUNCTION kasira.has_outlet_access(
  p_tenant_id uuid,
  p_user_id uuid,
  p_outlet_id uuid
) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT p_tenant_id=kasira.current_tenant_id()
     AND (
       EXISTS (
         SELECT 1
         FROM kasira.user_outlet_scope s
         WHERE s.tenant_id=p_tenant_id
           AND s.user_id=p_user_id
           AND s.outlet_id=p_outlet_id
       )
       OR EXISTS (
         SELECT 1
         FROM kasira.user_role ur
         JOIN kasira.role_permission rp
           ON rp.tenant_id=ur.tenant_id
          AND rp.role_id=ur.role_id
         JOIN kasira.permission p
           ON p.id=rp.permission_id
         WHERE ur.tenant_id=p_tenant_id
           AND ur.user_id=p_user_id
           AND p.code='outlet.scope_all'
       )
     );
$$;

CREATE OR REPLACE FUNCTION kasira.assert_outlet_access(
  p_tenant_id uuid,
  p_user_id uuid,
  p_outlet_id uuid
) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_tenant_id IS DISTINCT FROM kasira.current_tenant_id() THEN
    RAISE EXCEPTION 'TENANT_CONTEXT_DENIED';
  END IF;
  IF NOT kasira.has_outlet_access(p_tenant_id,p_user_id,p_outlet_id) THEN
    RAISE EXCEPTION 'OUTLET_SCOPE_DENIED';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION kasira.assert_trusted_device(
  p_tenant_id uuid,
  p_device_id uuid,
  p_outlet_id uuid
) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT p_tenant_id=kasira.current_tenant_id()
     AND EXISTS (
       SELECT 1
       FROM kasira.device d
       WHERE d.tenant_id=p_tenant_id
         AND d.id=p_device_id
         AND d.outlet_id=p_outlet_id
         AND d.trust_status='TRUSTED'
         AND (d.minimum_app_version IS NULL OR d.minimum_app_version<=d.app_version)
     );
$$;

DO $phase6b_rls$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['user_outlet_scope','role_permission'] LOOP
    EXECUTE format('ALTER TABLE kasira.%I ENABLE ROW LEVEL SECURITY',t);
    EXECUTE format('ALTER TABLE kasira.%I FORCE ROW LEVEL SECURITY',t);
  END LOOP;
END $phase6b_rls$;
