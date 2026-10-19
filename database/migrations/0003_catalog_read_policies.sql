-- GOG-016/074, issue #49. Apply after 0002, schema review and recoverable backup.
-- The gogdely schema stays outside the Supabase Data API. The FastAPI server
-- assumes anon/authenticated only inside a transaction; no write grant here.
BEGIN;

GRANT USAGE ON SCHEMA gogdely TO anon;
GRANT SELECT ON gogdely.tenants, gogdely.branches,
    gogdely.menu_items TO anon;
GRANT SELECT ON gogdely.menu_items TO authenticated;

CREATE POLICY tenants_read_public_active ON gogdely.tenants
    FOR SELECT TO anon
    USING (status = 'active');

CREATE POLICY branches_read_public_active ON gogdely.branches
    FOR SELECT TO anon
    USING (
        status = 'active' AND EXISTS (
            SELECT 1 FROM gogdely.tenants t
            WHERE t.tenant_id = branches.tenant_id AND t.status = 'active'
        )
    );

CREATE POLICY menu_items_read_public_available ON gogdely.menu_items
    FOR SELECT TO anon
    USING (
        available AND EXISTS (
            SELECT 1 FROM gogdely.branches b
            JOIN gogdely.tenants t ON t.tenant_id = b.tenant_id
            WHERE b.tenant_id = menu_items.tenant_id
              AND b.branch_id = menu_items.branch_id
              AND b.status = 'active' AND t.status = 'active'
        )
    );

CREATE POLICY menu_items_read_member ON gogdely.menu_items
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM gogdely.memberships m
            WHERE m.tenant_id = menu_items.tenant_id
              AND m.user_id = (SELECT auth.uid())
              AND (
                  m.role = 'owner' OR EXISTS (
                      SELECT 1 FROM gogdely.membership_branches mb
                      WHERE mb.tenant_id = menu_items.tenant_id
                        AND mb.branch_id = menu_items.branch_id
                        AND mb.user_id = (SELECT auth.uid())
                  )
              )
        )
    );

COMMIT;
