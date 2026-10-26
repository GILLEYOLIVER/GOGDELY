-- GOG-041: in-database snapshot for fictitious homologation data only.
-- Not an off-site backup. Run only if the preflight shows exactly the
-- expected isolated tenant, 8 foundation tables and no real orders.
BEGIN;
DO $$
BEGIN
    IF to_regnamespace('gogdely_snapshot_20261025') IS NOT NULL THEN
        RAISE EXCEPTION 'Snapshot schema already exists';
    END IF;
    IF (SELECT count(*) FROM auth.users) <> 1
       OR (SELECT count(*) FROM gogdely.tenants) <> 1
       OR (SELECT count(*) FROM gogdely.branches) <> 1
       OR (SELECT count(*) FROM gogdely.memberships) <> 1
       OR (SELECT count(*) FROM gogdely.menu_items) <> 12
       OR (SELECT count(*) FROM gogdely.orders) <> 0
       OR (SELECT count(*) FROM pg_policies WHERE schemaname='gogdely') <> 0
       OR (SELECT count(*) FROM pg_class c JOIN pg_namespace n
           ON n.oid=c.relnamespace WHERE n.nspname='gogdely' AND c.relkind='r') <> 8
       OR NOT EXISTS (SELECT 1 FROM gogdely.tenants
           WHERE tenant_id='c95d5aca-8eea-4ad4-8b50-53117abe3f01') THEN
        RAISE EXCEPTION 'Homologation database differs from the reviewed state';
    END IF;
END;
$$;
CREATE SCHEMA gogdely_snapshot_20261025;
CREATE TABLE gogdely_snapshot_20261025.tenants AS TABLE gogdely.tenants;
CREATE TABLE gogdely_snapshot_20261025.branches AS TABLE gogdely.branches;
CREATE TABLE gogdely_snapshot_20261025.memberships AS TABLE gogdely.memberships;
CREATE TABLE gogdely_snapshot_20261025.membership_branches AS TABLE gogdely.membership_branches;
CREATE TABLE gogdely_snapshot_20261025.menu_items AS TABLE gogdely.menu_items;
CREATE TABLE gogdely_snapshot_20261025.orders AS TABLE gogdely.orders;
CREATE TABLE gogdely_snapshot_20261025.order_items AS TABLE gogdely.order_items;
CREATE TABLE gogdely_snapshot_20261025.order_events AS TABLE gogdely.order_events;
REVOKE ALL ON SCHEMA gogdely_snapshot_20261025 FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA gogdely_snapshot_20261025
    FROM PUBLIC, anon, authenticated;
COMMIT;

SELECT 'tenants' AS table_name, count(*) AS copied_rows
  FROM gogdely_snapshot_20261025.tenants
UNION ALL SELECT 'branches', count(*) FROM gogdely_snapshot_20261025.branches
UNION ALL SELECT 'memberships', count(*) FROM gogdely_snapshot_20261025.memberships
UNION ALL SELECT 'membership_branches', count(*) FROM gogdely_snapshot_20261025.membership_branches
UNION ALL SELECT 'menu_items', count(*) FROM gogdely_snapshot_20261025.menu_items
UNION ALL SELECT 'orders', count(*) FROM gogdely_snapshot_20261025.orders
UNION ALL SELECT 'order_items', count(*) FROM gogdely_snapshot_20261025.order_items
UNION ALL SELECT 'order_events', count(*) FROM gogdely_snapshot_20261025.order_events;
