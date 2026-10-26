-- GOG-043/074: tenant-scoped preference for payment on table orders.
-- Apply only after schema review and a verified backup or isolated fictitious
-- snapshot. This preference
-- never confirms, captures, or settles a payment without a provider.
BEGIN;

CREATE TABLE gogdely.table_settings (
    tenant_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    allow_online_payment BOOLEAN NOT NULL DEFAULT FALSE,
    updated_by UUID NOT NULL REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, branch_id),
    FOREIGN KEY (tenant_id, branch_id)
        REFERENCES gogdely.branches(tenant_id, branch_id)
);
ALTER TABLE gogdely.table_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.table_settings FORCE ROW LEVEL SECURITY;
REVOKE ALL ON gogdely.table_settings FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON gogdely.table_settings TO authenticated;

CREATE POLICY table_settings_read_member ON gogdely.table_settings
    FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 FROM gogdely.memberships m
        WHERE m.tenant_id = table_settings.tenant_id
          AND m.user_id = (SELECT auth.uid())
          AND (m.role = 'owner' OR EXISTS (
              SELECT 1 FROM gogdely.membership_branches mb
              WHERE mb.tenant_id = table_settings.tenant_id
                AND mb.branch_id = table_settings.branch_id
                AND mb.user_id = (SELECT auth.uid())
          ))
    ));

CREATE POLICY table_settings_insert_manager ON gogdely.table_settings
    FOR INSERT TO authenticated
    WITH CHECK (
        updated_by = (SELECT auth.uid())
        AND EXISTS (
            SELECT 1 FROM gogdely.memberships m
            WHERE m.tenant_id = table_settings.tenant_id
              AND m.user_id = (SELECT auth.uid())
              AND m.role IN ('owner', 'manager')
              AND (m.role = 'owner' OR EXISTS (
                  SELECT 1 FROM gogdely.membership_branches mb
                  WHERE mb.tenant_id = table_settings.tenant_id
                    AND mb.branch_id = table_settings.branch_id
                    AND mb.user_id = (SELECT auth.uid())
              ))
        )
    );

CREATE POLICY table_settings_update_manager ON gogdely.table_settings
    FOR UPDATE TO authenticated
    USING (EXISTS (
        SELECT 1 FROM gogdely.memberships m
        WHERE m.tenant_id = table_settings.tenant_id
          AND m.user_id = (SELECT auth.uid())
          AND m.role IN ('owner', 'manager')
          AND (m.role = 'owner' OR EXISTS (
              SELECT 1 FROM gogdely.membership_branches mb
              WHERE mb.tenant_id = table_settings.tenant_id
                AND mb.branch_id = table_settings.branch_id
                AND mb.user_id = (SELECT auth.uid())
          ))
    ))
    WITH CHECK (
        updated_by = (SELECT auth.uid())
        AND EXISTS (
            SELECT 1 FROM gogdely.memberships m
            WHERE m.tenant_id = table_settings.tenant_id
              AND m.user_id = (SELECT auth.uid())
              AND m.role IN ('owner', 'manager')
              AND (m.role = 'owner' OR EXISTS (
                  SELECT 1 FROM gogdely.membership_branches mb
                  WHERE mb.tenant_id = table_settings.tenant_id
                    AND mb.branch_id = table_settings.branch_id
                    AND mb.user_id = (SELECT auth.uid())
              ))
        )
    );

COMMIT;
