-- GOG-041: read-only verification after migrations 0002..0007 and courier seed.
SELECT
  (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='gogdely' AND c.relkind='r') AS gogdely_tables,
  (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='gogdely' AND c.relkind='r'
      AND c.relrowsecurity AND c.relforcerowsecurity) AS tables_with_forced_rls,
  (SELECT count(*) FROM pg_policies WHERE schemaname='gogdely') AS policies,
  (SELECT count(*) FROM gogdely.tenants
    WHERE tenant_id='c95d5aca-8eea-4ad4-8b50-53117abe3f01') AS fictitious_tenants,
  (SELECT count(*) FROM gogdely.branches
    WHERE tenant_id='c95d5aca-8eea-4ad4-8b50-53117abe3f01') AS fictitious_branches,
  (SELECT count(*) FROM gogdely.menu_items
    WHERE tenant_id='c95d5aca-8eea-4ad4-8b50-53117abe3f01') AS fictitious_items,
  (SELECT count(*) FROM gogdely.courier_memberships
    WHERE tenant_id='c95d5aca-8eea-4ad4-8b50-53117abe3f01'
      AND active) AS active_couriers,
  (SELECT count(*) FROM gogdely.delivery_compensation
    WHERE tenant_id='c95d5aca-8eea-4ad4-8b50-53117abe3f01'
      AND mode='fixed' AND fixed_cents=800) AS fixed_test_compensations;

SELECT table_name, copied_rows FROM (
  SELECT 'tenants' AS table_name, count(*) AS copied_rows
    FROM gogdely_snapshot_20261025.tenants
  UNION ALL SELECT 'branches', count(*) FROM gogdely_snapshot_20261025.branches
  UNION ALL SELECT 'memberships', count(*) FROM gogdely_snapshot_20261025.memberships
  UNION ALL SELECT 'menu_items', count(*) FROM gogdely_snapshot_20261025.menu_items
) snapshot ORDER BY table_name;
