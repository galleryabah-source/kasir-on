CREATE TABLE IF NOT EXISTS kasira.product (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 sku text NOT NULL, name text NOT NULL,
 product_type text NOT NULL DEFAULT 'STANDARD' CHECK(product_type IN ('STANDARD','SERVICE','BUNDLE','RECIPE')),
 status text NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','INACTIVE')),
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,sku), UNIQUE(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.product_variant (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 product_id uuid NOT NULL, sku text NOT NULL, name text NOT NULL, barcode text,
 unit text NOT NULL DEFAULT 'PCS', created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,sku), UNIQUE(tenant_id,id), UNIQUE(tenant_id,barcode),
 FOREIGN KEY(tenant_id,product_id) REFERENCES kasira.product(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.price_version (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 product_variant_id uuid NOT NULL, outlet_id uuid, currency char(3) NOT NULL DEFAULT 'IDR',
 amount_minor bigint NOT NULL CHECK(amount_minor>=0), effective_from timestamptz NOT NULL,
 effective_until timestamptz, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,product_variant_id) REFERENCES kasira.product_variant(tenant_id,id),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id),
 CHECK(effective_until IS NULL OR effective_until>effective_from)
);
CREATE TABLE IF NOT EXISTS kasira.order_header (
 id uuid PRIMARY KEY, tenant_id uuid NOT NULL REFERENCES kasira.tenant(id), outlet_id uuid NOT NULL, device_id uuid,
 order_number text NOT NULL, business_date date NOT NULL,
 status text NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','PAID','VOIDED','REFUNDED')),
 currency char(3) NOT NULL DEFAULT 'IDR',
 subtotal_minor bigint NOT NULL DEFAULT 0 CHECK(subtotal_minor>=0),
 discount_minor bigint NOT NULL DEFAULT 0 CHECK(discount_minor>=0),
 tax_minor bigint NOT NULL DEFAULT 0 CHECK(tax_minor>=0),
 total_minor bigint NOT NULL DEFAULT 0 CHECK(total_minor>=0),
 occurred_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,order_number),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id),
 FOREIGN KEY(tenant_id,device_id) REFERENCES kasira.device(tenant_id,id),
 CHECK(total_minor=subtotal_minor-discount_minor+tax_minor)
);
CREATE TABLE IF NOT EXISTS kasira.order_item (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 order_id uuid NOT NULL, product_variant_id uuid NOT NULL, quantity numeric(18,6) NOT NULL CHECK(quantity>0),
 unit_price_minor bigint NOT NULL CHECK(unit_price_minor>=0), discount_minor bigint NOT NULL DEFAULT 0 CHECK(discount_minor>=0),
 tax_minor bigint NOT NULL DEFAULT 0 CHECK(tax_minor>=0), line_total_minor bigint NOT NULL CHECK(line_total_minor>=0),
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,order_id) REFERENCES kasira.order_header(tenant_id,id),
 FOREIGN KEY(tenant_id,product_variant_id) REFERENCES kasira.product_variant(tenant_id,id),
 CHECK(line_total_minor=(unit_price_minor*quantity)::bigint-discount_minor+tax_minor)
);
CREATE TABLE IF NOT EXISTS kasira.idempotency_record (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id), device_id uuid,
 idempotency_key text NOT NULL, operation text NOT NULL, request_hash text NOT NULL,
 response_code integer, response_body jsonb, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,idempotency_key), FOREIGN KEY(tenant_id,device_id) REFERENCES kasira.device(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.payment (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id), order_id uuid NOT NULL,
 method text NOT NULL CHECK(method IN ('CASH','QRIS','CARD','EWALLET','TRANSFER','CREDIT')),
 provider text, provider_reference text,
 status text NOT NULL CHECK(status IN ('PENDING','AUTHORIZED','CAPTURED','FAILED','REFUNDED','VOIDED')),
 amount_minor bigint NOT NULL CHECK(amount_minor>=0), currency char(3) NOT NULL DEFAULT 'IDR',
 occurred_at timestamptz NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,order_id) REFERENCES kasira.order_header(tenant_id,id)
);
CREATE TABLE IF NOT EXISTS kasira.sales_ledger (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES kasira.tenant(id),
 outlet_id uuid NOT NULL, order_id uuid NOT NULL, event_id uuid NOT NULL UNIQUE,
 event_type text NOT NULL CHECK(event_type IN ('SALE_CREATED','SALE_VOIDED','SALE_REFUNDED','SALE_ADJUSTED')),
 amount_minor bigint NOT NULL, currency char(3) NOT NULL DEFAULT 'IDR',
 occurred_at timestamptz NOT NULL, actor_id uuid, device_id uuid, correlation_id uuid NOT NULL, causation_id uuid,
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(tenant_id,outlet_id) REFERENCES kasira.outlet(tenant_id,id),
 FOREIGN KEY(tenant_id,order_id) REFERENCES kasira.order_header(tenant_id,id),
 FOREIGN KEY(tenant_id,actor_id) REFERENCES kasira.app_user(tenant_id,id),
 FOREIGN KEY(tenant_id,device_id) REFERENCES kasira.device(tenant_id,id)
);
