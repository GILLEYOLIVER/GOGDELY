-- GOG-041: read-only checks before the isolated homologation migrations.
-- Run in the GOGDELY Homologacao SQL Editor and inspect every row first.
SELECT current_database() AS database_name,
       current_user AS executed_as,
       (SELECT count(*) FROM auth.users) AS auth_users,
       (SELECT count(*) FROM gogdely.tenants) AS tenants,
       (SELECT count(*) FROM gogdely.branches) AS branches,
       (SELECT count(*) FROM gogdely.memberships) AS memberships,
       (SELECT count(*) FROM gogdely.menu_items) AS menu_items,
       (SELECT count(*) FROM gogdely.orders) AS orders,
       (SELECT count(*) FROM pg_policies WHERE schemaname = 'gogdely') AS policies,
       (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='gogdely' AND c.relkind='r') AS gogdely_tables,
       to_regclass('gogdely.menu_item_events') AS menu_item_events,
       to_regclass('gogdely.table_settings') AS table_settings,
       to_regclass('gogdely.master_audit') AS master_audit,
       to_regclass('gogdely.delivery_assignments') AS delivery_assignments;

SELECT tenant_id, status FROM gogdely.tenants
 WHERE tenant_id='c95d5aca-8eea-4ad4-8b50-53117abe3f01';
SELECT branch_id, slug, status FROM gogdely.branches
 WHERE tenant_id='c95d5aca-8eea-4ad4-8b50-53117abe3f01';
