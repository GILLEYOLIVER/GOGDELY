-- GOG-016: remove only the known fictitious seed, after migration 0007.
-- Never run for real stores.
BEGIN;
DELETE FROM gogdely.delivery_assignments WHERE tenant_id = 'c95d5aca-8eea-4ad4-8b50-53117abe3f01';
DELETE FROM gogdely.delivery_compensation WHERE tenant_id = 'c95d5aca-8eea-4ad4-8b50-53117abe3f01';
DELETE FROM gogdely.courier_memberships WHERE tenant_id = 'c95d5aca-8eea-4ad4-8b50-53117abe3f01';
DELETE FROM gogdely.order_events WHERE tenant_id = 'c95d5aca-8eea-4ad4-8b50-53117abe3f01';
DELETE FROM gogdely.order_items WHERE tenant_id = 'c95d5aca-8eea-4ad4-8b50-53117abe3f01';
DELETE FROM gogdely.orders WHERE tenant_id = 'c95d5aca-8eea-4ad4-8b50-53117abe3f01';
DELETE FROM gogdely.menu_items WHERE tenant_id = 'c95d5aca-8eea-4ad4-8b50-53117abe3f01';
DELETE FROM gogdely.membership_branches WHERE tenant_id = 'c95d5aca-8eea-4ad4-8b50-53117abe3f01';
DELETE FROM gogdely.memberships WHERE tenant_id = 'c95d5aca-8eea-4ad4-8b50-53117abe3f01';
DELETE FROM gogdely.branches WHERE tenant_id = 'c95d5aca-8eea-4ad4-8b50-53117abe3f01';
DELETE FROM gogdely.tenants WHERE tenant_id = 'c95d5aca-8eea-4ad4-8b50-53117abe3f01';
COMMIT;
