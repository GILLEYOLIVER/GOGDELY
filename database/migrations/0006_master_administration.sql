-- GOG-004/025/082/096: audited platform administration in homologation.
-- Apply only after a verified backup and schema comparison. Never expose this
-- schema to the Data API or grant access to anon/authenticated.
BEGIN;

CREATE TABLE gogdely.master_audit (
    audit_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    request_id UUID NOT NULL UNIQUE,
    actor_user_id UUID NOT NULL REFERENCES auth.users(id),
    tenant_id UUID REFERENCES gogdely.tenants(tenant_id),
    action TEXT NOT NULL CHECK (action IN
        ('company.created', 'company.owner_linked',
         'company.status_changed', 'commission.changed')),
    reason TEXT NOT NULL CHECK (length(trim(reason)) BETWEEN 8 AND 500),
    before_state JSONB NOT NULL DEFAULT '{}'::jsonb,
    after_state JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX master_audit_tenant_time_idx
    ON gogdely.master_audit(tenant_id, created_at DESC);

CREATE FUNCTION gogdely.reject_master_audit_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'master audit events are immutable';
END;
$$;
CREATE TRIGGER master_audit_immutable
    BEFORE UPDATE OR DELETE ON gogdely.master_audit
    FOR EACH ROW EXECUTE FUNCTION gogdely.reject_master_audit_change();

CREATE TABLE gogdely.tenant_commission_settings (
    tenant_id UUID PRIMARY KEY REFERENCES gogdely.tenants(tenant_id),
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    percentage NUMERIC(5,2) NOT NULL DEFAULT 0
        CHECK (percentage >= 0 AND percentage <= 100),
    updated_by UUID NOT NULL REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE gogdely.master_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.master_audit FORCE ROW LEVEL SECURITY;
ALTER TABLE gogdely.tenant_commission_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.tenant_commission_settings FORCE ROW LEVEL SECURITY;
REVOKE ALL ON gogdely.master_audit, gogdely.tenant_commission_settings
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE gogdely.master_audit_audit_id_seq
    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION gogdely.reject_master_audit_change()
    FROM PUBLIC, anon, authenticated;

COMMIT;
