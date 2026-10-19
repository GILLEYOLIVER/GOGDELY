-- GOG-016/074, issue #50. Apply after 0002 and 0003, confirmed schema,
-- recoverable backup, and a tested rollback path. No client-side DB writes.
BEGIN;

CREATE TABLE gogdely.menu_item_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    item_id UUID NOT NULL,
    actor_user_id UUID NOT NULL REFERENCES auth.users(id),
    action TEXT NOT NULL CHECK (action IN ('created', 'updated')),
    snapshot JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (tenant_id, branch_id, item_id)
        REFERENCES gogdely.menu_items(tenant_id, branch_id, item_id)
);
CREATE INDEX menu_item_events_item_idx ON gogdely.menu_item_events
    (tenant_id, branch_id, item_id, created_at DESC);

ALTER TABLE gogdely.menu_item_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE gogdely.menu_item_events FORCE ROW LEVEL SECURITY;
REVOKE ALL ON gogdely.menu_item_events FROM PUBLIC, anon, authenticated;
GRANT INSERT, SELECT ON gogdely.menu_item_events TO authenticated;
GRANT INSERT, UPDATE ON gogdely.menu_items TO authenticated;

CREATE POLICY menu_items_insert_manager ON gogdely.menu_items
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM gogdely.memberships m
            WHERE m.tenant_id = menu_items.tenant_id
              AND m.user_id = (SELECT auth.uid())
              AND m.role IN ('owner', 'manager')
              AND (m.role = 'owner' OR EXISTS (
                  SELECT 1 FROM gogdely.membership_branches mb
                  WHERE mb.tenant_id = menu_items.tenant_id
                    AND mb.branch_id = menu_items.branch_id
                    AND mb.user_id = (SELECT auth.uid())
              ))
        )
    );

CREATE POLICY menu_items_update_manager ON gogdely.menu_items
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM gogdely.memberships m
            WHERE m.tenant_id = menu_items.tenant_id
              AND m.user_id = (SELECT auth.uid())
              AND m.role IN ('owner', 'manager')
              AND (m.role = 'owner' OR EXISTS (
                  SELECT 1 FROM gogdely.membership_branches mb
                  WHERE mb.tenant_id = menu_items.tenant_id
                    AND mb.branch_id = menu_items.branch_id
                    AND mb.user_id = (SELECT auth.uid())
              ))
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM gogdely.memberships m
            WHERE m.tenant_id = menu_items.tenant_id
              AND m.user_id = (SELECT auth.uid())
              AND m.role IN ('owner', 'manager')
              AND (m.role = 'owner' OR EXISTS (
                  SELECT 1 FROM gogdely.membership_branches mb
                  WHERE mb.tenant_id = menu_items.tenant_id
                    AND mb.branch_id = menu_items.branch_id
                    AND mb.user_id = (SELECT auth.uid())
              ))
        )
    );

CREATE POLICY menu_item_events_insert_manager ON gogdely.menu_item_events
    FOR INSERT TO authenticated
    WITH CHECK (
        actor_user_id = (SELECT auth.uid())
        AND EXISTS (
            SELECT 1 FROM gogdely.memberships m
            WHERE m.tenant_id = menu_item_events.tenant_id
              AND m.user_id = (SELECT auth.uid())
              AND m.role IN ('owner', 'manager')
              AND (m.role = 'owner' OR EXISTS (
                  SELECT 1 FROM gogdely.membership_branches mb
                  WHERE mb.tenant_id = menu_item_events.tenant_id
                    AND mb.branch_id = menu_item_events.branch_id
                    AND mb.user_id = (SELECT auth.uid())
              ))
        )
    );

CREATE POLICY menu_item_events_read_member ON gogdely.menu_item_events
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM gogdely.memberships m
            WHERE m.tenant_id = menu_item_events.tenant_id
              AND m.user_id = (SELECT auth.uid())
              AND (m.role = 'owner' OR EXISTS (
                  SELECT 1 FROM gogdely.membership_branches mb
                  WHERE mb.tenant_id = menu_item_events.tenant_id
                    AND mb.branch_id = menu_item_events.branch_id
                    AND mb.user_id = (SELECT auth.uid())
              ))
        )
    );

COMMIT;
