-- GOGDELY — 0001_foundation.sql (GOG-114)
-- Esquema de referência para o banco gerenciado futuro (Supabase PostgreSQL
-- ou equivalente). NÃO aplicado a nenhum ambiente: o laboratório local usa
-- SQLite (services/api/gogdely_api/local_orders.py). Ao homologar a
-- hospedagem, revisar tipos, índices, RLS e aplicar via ferramenta aprovada.
--
-- Princípios do Documento Mestre:
--   * tenant_id em todas as linhas (GOG-074);
--   * RLS + autorização independente no backend (GOG-074);
--   * pagamentos somente com liquidação confirmada por provedor (GOG-055);
--   * auditoria de alterações críticas (GOG-038/082).

BEGIN;

CREATE TABLE IF NOT EXISTS tenants (
    tenant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS companies (
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    store_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
    plan_id TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS companies_tenant_idx ON companies(tenant_id);

CREATE TABLE IF NOT EXISTS company_branches (
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    branch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES companies(store_id),
    name TEXT NOT NULL,
    address_label TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS branches_tenant_idx ON company_branches(tenant_id, store_id);

CREATE TABLE IF NOT EXISTS menu_items (
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    store_id UUID NOT NULL REFERENCES companies(store_id),
    product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    category TEXT NOT NULL,
    price_cents INTEGER NOT NULL CHECK (price_cents >= 0),
    promo_percent INTEGER NOT NULL DEFAULT 0 CHECK (promo_percent BETWEEN 0 AND 100),
    image_ref TEXT NOT NULL DEFAULT '',
    available BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS menu_tenant_idx ON menu_items(tenant_id, store_id);

CREATE TABLE IF NOT EXISTS orders (
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES companies(store_id),
    order_channel TEXT NOT NULL CHECK (order_channel IN ('delivery', 'pickup', 'counter', 'table')),
    address_label TEXT NOT NULL,
    table_code TEXT,
    items_json JSONB NOT NULL,
    subtotal_cents INTEGER NOT NULL CHECK (subtotal_cents >= 0),
    delivery_fee_cents INTEGER NOT NULL DEFAULT 0 CHECK (delivery_fee_cents >= 0),
    total_cents INTEGER NOT NULL CHECK (total_cents >= 0),
    status TEXT NOT NULL,
    payment_method TEXT NOT NULL DEFAULT 'unselected',
    -- Liquidação somente com confirmação de provedor; simulação local é
    -- sempre 'simulated' e nunca 'confirmed' (GOG-055).
    payment_state TEXT NOT NULL DEFAULT 'not_processed'
        CHECK (payment_state IN ('not_processed', 'simulated', 'provider_confirmed')),
    request_key UUID NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS orders_tenant_idx ON orders(tenant_id, store_id, created_at DESC);

CREATE TABLE IF NOT EXISTS order_events (
    event_id BIGSERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenants(tenant_id),
    order_id UUID NOT NULL REFERENCES orders(order_id),
    from_status TEXT,
    to_status TEXT NOT NULL,
    actor TEXT NOT NULL,
    reason TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS order_events_order_idx ON order_events(order_id, event_id);

-- RLS base: cada papel autenticado enxerga apenas o próprio tenant.
-- Funções de membership ficam pendentes da definição de auth (GOG-075).
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON companies
    USING (tenant_id = current_setting('gogdely.tenant_id', true)::UUID);
CREATE POLICY tenant_isolation ON company_branches
    USING (tenant_id = current_setting('gogdely.tenant_id', true)::UUID);
CREATE POLICY tenant_isolation ON menu_items
    USING (tenant_id = current_setting('gogdely.tenant_id', true)::UUID);
CREATE POLICY tenant_isolation ON orders
    USING (tenant_id = current_setting('gogdely.tenant_id', true)::UUID);
CREATE POLICY tenant_isolation ON order_events
    USING (tenant_id = current_setting('gogdely.tenant_id', true)::UUID);

COMMIT;
