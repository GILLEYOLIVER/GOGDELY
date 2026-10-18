-- GOG-072/074/114, issue #33: isolated test foundation.
-- Apply once to the GOGDELY Testes Supabase project only, after review.
-- The gogdely schema is not exposed by the Data API. No anon/authenticated
-- grants or RLS policies are created: application access is denied by default.
BEGIN;

CREATE SCHEMA gogdely;
REVOKE ALL ON SCHEMA gogdely FROM PUBLIC, anon, authenticated;

CREATE TABLE gogdely.tenants (
    tenant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'active', 'suspended')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE gogdely.branches (
    tenant_id UUID NOT NULL REFERENCES gogdely.tenants(tenant_id),
    branch_id UUID NOT NULL DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'active', 'suspended')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, branch_id),
    UNIQUE (slug)
);

CREATE TABLE gogdely.memberships (
    tenant_id UUID NOT NULL REFERENCES gogdely.tenants(tenant_id),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    role TEXT NOT NULL CHECK (role IN ('owner', 'manager', 'staff')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, user_id)
);

CREATE TABLE gogdely.membership_branches (
    tenant_id UUID NOT NULL,
    user_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    PRIMARY KEY (tenant_id, user_id, branch_id),
    FOREIGN KEY (tenant_id, user_id)
        REFERENCES gogdely.memberships(tenant_id, user_id) ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, branch_id)
        REFERENCES gogdely.branches(tenant_id, branch_id) ON DELETE CASCADE
);

CREATE TABLE gogdely.menu_items (
    tenant_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    item_id UUID NOT NULL DEFAULT gen_random_uuid(),
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    description TEXT NOT NULL DEFAULT '',
    category_name TEXT NOT NULL,
    price_cents INTEGER NOT NULL CHECK (price_cents >= 0),
    image_path TEXT,
    available BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, branch_id, item_id),
    FOREIGN KEY (tenant_id, branch_id)
        REFERENCES gogdely.branches(tenant_id, branch_id)
);
CREATE INDEX menu_items_branch_order_idx
    ON gogdely.menu_items(tenant_id, branch_id, category_name, sort_order);

CREATE TABLE gogdely.orders (
    tenant_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    order_id UUID NOT NULL DEFAULT gen_random_uuid(),
    idempotency_key UUID NOT NULL,
    channel TEXT NOT NULL CHECK (channel IN ('delivery', 'pickup', 'table', 'counter')),
    table_code TEXT,
    address_label TEXT,
    status TEXT NOT NULL DEFAULT 'created'
        CHECK (status IN ('created', 'accepted', 'preparing', 'ready',
                          'dispatched', 'completed', 'cancelled')),
    subtotal_cents INTEGER NOT NULL CHECK (subtotal_cents >= 0),
    delivery_fee_cents INTEGER NOT NULL DEFAULT 0 CHECK (delivery_fee_cents >= 0),
    total_cents INTEGER NOT NULL CHECK (total_cents >= 0),
    payment_state TEXT NOT NULL DEFAULT 'not_processed'
        CHECK (payment_state IN ('not_processed', 'pending',
                                'provider_confirmed', 'refunded')),
    payment_provider_ref TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, branch_id, order_id),
    UNIQUE (tenant_id, idempotency_key),
    CHECK (total_cents = subtotal_cents + delivery_fee_cents),
    CHECK (payment_state <> 'provider_confirmed' OR payment_provider_ref IS NOT NULL),
    FOREIGN KEY (tenant_id, branch_id)
        REFERENCES gogdely.branches(tenant_id, branch_id)
);
CREATE INDEX orders_branch_created_idx
    ON gogdely.orders(tenant_id, branch_id, created_at DESC);

CREATE TABLE gogdely.order_items (
    tenant_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    order_id UUID NOT NULL,
    line_no INTEGER NOT NULL CHECK (line_no > 0),
    item_id UUID,
    name_snapshot TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price_cents INTEGER NOT NULL CHECK (unit_price_cents >= 0),
    PRIMARY KEY (tenant_id, branch_id, order_id, line_no),
    FOREIGN KEY (tenant_id, branch_id, order_id)
        REFERENCES gogdely.orders(tenant_id, branch_id, order_id)
        ON DELETE CASCADE,
    FOREIGN KEY (tenant_id, branch_id, item_id)
        REFERENCES gogdely.menu_items(tenant_id, branch_id, item_id)
);

CREATE TABLE gogdely.order_events (
    tenant_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    order_id UUID NOT NULL,
    event_id BIGINT GENERATED ALWAYS AS IDENTITY,
    from_status TEXT,
    to_status TEXT NOT NULL,
    actor_user_id UUID,
    reason TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, branch_id, order_id, event_id),
    FOREIGN KEY (tenant_id, branch_id, order_id)
        REFERENCES gogdely.orders(tenant_id, branch_id, order_id)
        ON DELETE CASCADE
);

ALTER TABLE gogdely.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.tenants FORCE ROW LEVEL SECURITY;
ALTER TABLE gogdely.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.branches FORCE ROW LEVEL SECURITY;
ALTER TABLE gogdely.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.memberships FORCE ROW LEVEL SECURITY;
ALTER TABLE gogdely.membership_branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.membership_branches FORCE ROW LEVEL SECURITY;
ALTER TABLE gogdely.menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.menu_items FORCE ROW LEVEL SECURITY;
ALTER TABLE gogdely.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.orders FORCE ROW LEVEL SECURITY;
ALTER TABLE gogdely.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.order_items FORCE ROW LEVEL SECURITY;
ALTER TABLE gogdely.order_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.order_events FORCE ROW LEVEL SECURITY;

REVOKE ALL ON ALL TABLES IN SCHEMA gogdely FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA gogdely FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA gogdely
    REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA gogdely
    REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated;

COMMIT;
