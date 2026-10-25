-- GOG-041/052: the sole existing test Auth account can act as a courier only
-- for the dedicated fictitious store in homologation. Apply after 0007.
BEGIN;
DO $$
BEGIN
    IF (SELECT count(*) FROM auth.users) <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one pre-existing test user';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM gogdely.branches
                   WHERE tenant_id='c95d5aca-8eea-4ad4-8b50-53117abe3f01'
                     AND branch_id='d3bdc553-639a-47c4-9cea-aad6a06725ea') THEN
        RAISE EXCEPTION 'Fictitious store seed missing';
    END IF;
END;
$$;
INSERT INTO gogdely.courier_memberships (tenant_id,branch_id,user_id,active)
SELECT 'c95d5aca-8eea-4ad4-8b50-53117abe3f01',
       'd3bdc553-639a-47c4-9cea-aad6a06725ea',id,true
FROM auth.users WHERE true
ON CONFLICT (tenant_id,branch_id,user_id) DO NOTHING;
INSERT INTO gogdely.delivery_compensation
    (tenant_id,branch_id,mode,fixed_cents,percent,updated_by)
SELECT 'c95d5aca-8eea-4ad4-8b50-53117abe3f01',
       'd3bdc553-639a-47c4-9cea-aad6a06725ea',
       'fixed',800,0,id
FROM auth.users WHERE true
ON CONFLICT (tenant_id,branch_id) DO NOTHING;
COMMIT;
