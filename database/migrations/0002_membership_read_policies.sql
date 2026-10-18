-- GOG-074/076, issue #39: read-only tenant and branch membership policies.
-- Apply only after reviewing the installed 0001 schema and taking a backup.
-- No write grants are added. Business mutations remain the FastAPI authority.
BEGIN;

GRANT USAGE ON SCHEMA gogdely TO authenticated;
GRANT SELECT ON gogdely.tenants, gogdely.branches,
    gogdely.memberships, gogdely.membership_branches TO authenticated;

CREATE POLICY memberships_read_self ON gogdely.memberships
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = user_id);

CREATE POLICY membership_branches_read_self ON gogdely.membership_branches
    FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = user_id);

CREATE POLICY tenants_read_member ON gogdely.tenants
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM gogdely.memberships m
            WHERE m.tenant_id = tenants.tenant_id
              AND m.user_id = (SELECT auth.uid())
        )
    );

CREATE POLICY branches_read_member ON gogdely.branches
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM gogdely.memberships m
            WHERE m.tenant_id = branches.tenant_id
              AND m.user_id = (SELECT auth.uid())
              AND (
                  m.role = 'owner'
                  OR EXISTS (
                      SELECT 1 FROM gogdely.membership_branches mb
                      WHERE mb.tenant_id = branches.tenant_id
                        AND mb.branch_id = branches.branch_id
                        AND mb.user_id = (SELECT auth.uid())
                  )
              )
        )
    );

COMMIT;
