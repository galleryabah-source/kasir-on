BEGIN;
SET LOCAL app.tenant_id='00000000-0000-0000-0000-000000000001';
DO $
DECLARE run_id uuid:=gen_random_uuid(); outlet_id uuid; i integer; now_ts timestamptz:=now(); brand_id uuid;
BEGIN
 SELECT id INTO brand_id FROM kasira.brand WHERE tenant_id='00000000-0000-0000-0000-000000000001' ORDER BY id LIMIT 1;
 FOR i IN 1..5 LOOP
   INSERT INTO kasira.outlet(tenant_id,brand_id,code,name) VALUES('00000000-0000-0000-0000-000000000001',brand_id,'PILOT-'||i,'CI Pilot Outlet '||i) ON CONFLICT (tenant_id,code) DO NOTHING;
 END LOOP
 INSERT INTO kasira.pilot_run(id,tenant_id,name,outlet_target,started_at,status)
 VALUES(run_id,'00000000-0000-0000-0000-000000000001','CI Pilot Readiness',5,now_ts,'RUNNING');
 FOR outlet_id IN SELECT id FROM kasira.outlet WHERE tenant_id='00000000-0000-0000-0000-000000000001' AND code LIKE 'PILOT-%' ORDER BY code LIMIT 5 LOOP
   INSERT INTO kasira.pilot_outlet(tenant_id,pilot_run_id,outlet_id,cashier_target,cashier_active,first_seen_at,last_seen_at,status)
   VALUES('00000000-0000-0000-0000-000000000001',run_id,outlet_id,2,2,now_ts,now_ts,'COMPLETED');
   INSERT INTO kasira.uptime_heartbeat(tenant_id,pilot_run_id,outlet_id,observed_at,status,latency_ms)
   VALUES('00000000-0000-0000-0000-000000000001',run_id,outlet_id,now_ts,'UP',20);
 END LOOP;
 INSERT INTO kasira.pilot_metric(tenant_id,pilot_run_id,metric_name,metric_value,unit,observed_at)
 VALUES
 ('00000000-0000-0000-0000-000000000001',run_id,'checkout_latency_p95_ms',50,'ms',now_ts),
 ('00000000-0000-0000-0000-000000000001',run_id,'offline_duration_hours',24,'hours',now_ts),
 ('00000000-0000-0000-0000-000000000001',run_id,'sync_success_rate_pct',100,'pct',now_ts),
 ('00000000-0000-0000-0000-000000000001',run_id,'reconciliation_exception_rate_pct',0,'pct',now_ts),
 ('00000000-0000-0000-0000-000000000001',run_id,'payment_success_rate_pct',100,'pct',now_ts),
 ('00000000-0000-0000-0000-000000000001',run_id,'inventory_integrity_pct',100,'pct',now_ts),
 ('00000000-0000-0000-0000-000000000001',run_id,'cashier_adoption_pct',100,'pct',now_ts);
 UPDATE kasira.pilot_run SET status=(SELECT status FROM kasira.pilot_gate('00000000-0000-0000-0000-000000000001',run_id)),ended_at=now() WHERE id=run_id;
 IF (SELECT status FROM kasira.pilot_run WHERE id=run_id)<>'PASS' THEN RAISE EXCEPTION 'PHASE5 PILOT GATE FAILED'; END IF;
 RAISE NOTICE 'PHASE5 PILOT GATE PASS run=%',run_id;
END $$;
COMMIT;
