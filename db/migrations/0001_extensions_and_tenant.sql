CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS kasira;
CREATE TABLE IF NOT EXISTS kasira.tenant (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text NOT NULL UNIQUE, name text NOT NULL,
 timezone text NOT NULL DEFAULT 'Asia/Jakarta', currency char(3) NOT NULL DEFAULT 'IDR',
 status text NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','SUSPENDED','CLOSED')),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS kasira.brand (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 code text NOT NULL, name text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,code), UNIQUE(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.outlet (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 brand_id uuid, code text NOT NULL, name text NOT NULL, timezone text NOT NULL DEFAULT 'Asia/Jakarta',
 business_day_cutoff time NOT NULL DEFAULT '04:00',
 status text NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','INACTIVE')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,code), UNIQUE(tenant_id,id),
 FOREIGN KEY(tenant_id,brand_id) REFERENCES kasira.brand(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.warehouse (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 outlet_id uuid, code text NOT NULL, name text NOT NULL,
 status text NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','INACTIVE')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,code), UNIQUE(tenant_id,id),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.device (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 outlet_id uuid NOT NULL, device_code text NOT NULL, platform text NOT NULL, app_version text NOT NULL,
 trust_status text NOT NULL DEFAULT 'PENDING' CHECK(trust_status IN ('PENDING','TRUSTED','REVOKED')),
 last_seen_at timestamptz, trusted_at timestamptz, revoked_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,device_code), UNIQUE(tenant_id,id),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.app_user (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 email text, display_name text NOT NULL,
 status text NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','SUSPENDED','DISABLED')),
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,email), UNIQUE(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.role (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 code text NOT NULL, name text NOT NULL, UNIQUE(tenant_id,code), UNIQUE(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.user_role (
 tenant_id uuid NOT NULL REFERENCES kasira.tenant(id), user_id uuid NOT NULL, role_id uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(tenant_id,user_id,role_id),
 FOREIGN KEY(tenant_id,user_id) REFERENCES kasira.app_user(tenant_id,id),
 FOREIGN KEY(tenant_id,role_id) REFERENCES kasira.role(tenant_id,id)
);
