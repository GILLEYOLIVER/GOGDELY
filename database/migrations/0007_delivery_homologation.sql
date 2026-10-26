-- GOG-017/041/042/052: tenant-scoped courier test flow.
-- Apply only after 0002..0006, verified backup (or isolated fictitious
-- homologation snapshot) and schema comparison.
-- No payments or real compensation are processed by these tables.
BEGIN;

CREATE TABLE gogdely.courier_memberships (
    tenant_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, branch_id, user_id),
    FOREIGN KEY (tenant_id, branch_id)
        REFERENCES gogdely.branches(tenant_id, branch_id)
);

CREATE TABLE gogdely.delivery_compensation (
    tenant_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    mode TEXT NOT NULL DEFAULT 'salary'
        CHECK (mode IN ('fixed', 'percent', 'salary')),
    fixed_cents INTEGER NOT NULL DEFAULT 0 CHECK (fixed_cents >= 0),
    percent NUMERIC(5,2) NOT NULL DEFAULT 0
        CHECK (percent >= 0 AND percent <= 100),
    updated_by UUID NOT NULL REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, branch_id),
    FOREIGN KEY (tenant_id, branch_id)
        REFERENCES gogdely.branches(tenant_id, branch_id)
);

CREATE TABLE gogdely.delivery_assignments (
    tenant_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    order_id UUID NOT NULL,
    courier_user_id UUID,
    status TEXT NOT NULL DEFAULT 'available'
        CHECK (status IN ('available', 'accepted', 'in_delivery', 'completed')),
    earning_cents INTEGER NOT NULL DEFAULT 0 CHECK (earning_cents >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    accepted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    PRIMARY KEY (tenant_id, branch_id, order_id),
    FOREIGN KEY (tenant_id, branch_id, order_id)
        REFERENCES gogdely.orders(tenant_id, branch_id, order_id),
    FOREIGN KEY (tenant_id, branch_id, courier_user_id)
        REFERENCES gogdely.courier_memberships(tenant_id, branch_id, user_id),
    CHECK ((status = 'available' AND courier_user_id IS NULL)
        OR (status <> 'available' AND courier_user_id IS NOT NULL))
);
CREATE INDEX delivery_assignments_courier_idx
    ON gogdely.delivery_assignments(courier_user_id, status, created_at DESC);

ALTER TABLE gogdely.courier_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.courier_memberships FORCE ROW LEVEL SECURITY;
ALTER TABLE gogdely.delivery_compensation ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.delivery_compensation FORCE ROW LEVEL SECURITY;
ALTER TABLE gogdely.delivery_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.delivery_assignments FORCE ROW LEVEL SECURITY;
REVOKE ALL ON gogdely.courier_memberships, gogdely.delivery_compensation,
    gogdely.delivery_assignments FROM PUBLIC, anon, authenticated;

-- FastAPI owns writes and applies verified Auth identity plus branch checks.
-- The gogdely schema remains outside the Supabase Data API.
COMMIT;
