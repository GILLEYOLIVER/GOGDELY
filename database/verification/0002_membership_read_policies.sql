-- GOG-074/076, issue #39. Run only in the isolated GOGDELY Homologacao project.
-- Prerequisites: reviewed 0002 migration and two disposable Supabase Auth users
-- with the exact reserved-domain emails below. No real customer identities.
-- All fixture rows are rolled back, including when the assertions pass.
BEGIN;

DO $$
DECLARE
    user_a UUID;
    user_b UUID;
    tenant_a UUID := gen_random_uuid();
    tenant_b UUID := gen_random_uuid();
    branch_a1 UUID := gen_random_uuid();
    branch_a2 UUID := gen_random_uuid();
    branch_b1 UUID := gen_random_uuid();
    policy_count INTEGER;
BEGIN
    SELECT id INTO user_a FROM auth.users
    WHERE email = 'gogdely-rls-a@example.invalid';
    SELECT id INTO user_b FROM auth.users
    WHERE email = 'gogdely-rls-b@example.invalid';
    IF user_a IS NULL OR user_b IS NULL OR user_a = user_b THEN
        RAISE EXCEPTION 'Create two disposable GOGDELY Auth test users before running this verification';
    END IF;

    SELECT count(*) INTO policy_count FROM pg_policies
    WHERE schemaname = 'gogdely'
      AND (tablename, policyname) IN (
          ('memberships', 'memberships_read_self'),
          ('membership_branches', 'membership_branches_read_self'),
          ('tenants', 'tenants_read_member'),
          ('branches', 'branches_read_member')
      ) AND cmd = 'SELECT' AND 'authenticated' = ANY(roles);
    IF policy_count <> 4 THEN
        RAISE EXCEPTION 'Expected four authenticated membership SELECT policies, found %', policy_count;
    END IF;
    SELECT count(*) INTO policy_count FROM pg_policies
    WHERE schemaname = 'gogdely'
      AND tablename IN ('tenants', 'branches', 'memberships', 'membership_branches');
    IF policy_count <> 4 THEN
        RAISE EXCEPTION 'Unexpected extra membership policies: % total', policy_count;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'gogdely'
          AND c.relname IN ('tenants', 'branches', 'memberships', 'membership_branches')
          AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity)
    ) THEN
        RAISE EXCEPTION 'Membership tables must have forced RLS';
    END IF;

    PERFORM set_config('gogdely.test_user_a', user_a::text, true);
    PERFORM set_config('gogdely.test_user_b', user_b::text, true);
    PERFORM set_config('gogdely.test_tenant_a', tenant_a::text, true);
    PERFORM set_config('gogdely.test_tenant_b', tenant_b::text, true);
    PERFORM set_config('gogdely.test_branch_a1', branch_a1::text, true);
    PERFORM set_config('gogdely.test_branch_a2', branch_a2::text, true);
    PERFORM set_config('gogdely.test_branch_b1', branch_b1::text, true);

    INSERT INTO gogdely.tenants (tenant_id, name)
    VALUES (tenant_a, 'GOGDELY RLS test A'), (tenant_b, 'GOGDELY RLS test B');
    INSERT INTO gogdely.branches (tenant_id, branch_id, slug, name)
    VALUES
        (tenant_a, branch_a1, 'rls-' || replace(branch_a1::text, '-', ''), 'A1'),
        (tenant_a, branch_a2, 'rls-' || replace(branch_a2::text, '-', ''), 'A2'),
        (tenant_b, branch_b1, 'rls-' || replace(branch_b1::text, '-', ''), 'B1');
    INSERT INTO gogdely.memberships (tenant_id, user_id, role)
    VALUES (tenant_a, user_a, 'manager'), (tenant_b, user_b, 'staff');
    INSERT INTO gogdely.membership_branches (tenant_id, user_id, branch_id)
    VALUES (tenant_a, user_a, branch_a1), (tenant_b, user_b, branch_b1);
END $$;

-- Manager A may see A and branch A1, but neither A2 nor tenant B.
SELECT set_config('request.jwt.claim.sub', current_setting('gogdely.test_user_a'), true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
    a UUID := current_setting('gogdely.test_tenant_a')::uuid;
    b UUID := current_setting('gogdely.test_tenant_b')::uuid;
    a1 UUID := current_setting('gogdely.test_branch_a1')::uuid;
    a2 UUID := current_setting('gogdely.test_branch_a2')::uuid;
BEGIN
    IF (SELECT count(*) FROM gogdely.memberships WHERE tenant_id IN (a, b)) <> 1
       OR (SELECT count(*) FROM gogdely.membership_branches WHERE tenant_id IN (a, b)) <> 1
       OR (SELECT count(*) FROM gogdely.tenants WHERE tenant_id IN (a, b)) <> 1
       OR (SELECT count(*) FROM gogdely.branches WHERE tenant_id IN (a, b)) <> 1
       OR (SELECT count(*) FROM gogdely.branches WHERE branch_id = a1) <> 1
       OR (SELECT count(*) FROM gogdely.branches WHERE branch_id = a2) <> 0
       OR (SELECT count(*) FROM gogdely.tenants WHERE tenant_id = b) <> 0 THEN
        RAISE EXCEPTION 'Manager A escaped its tenant or branch scope';
    END IF;
    BEGIN
        INSERT INTO gogdely.tenants (name) VALUES ('forbidden write');
        RAISE EXCEPTION 'Authenticated role unexpectedly wrote a tenant';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
END $$;
RESET ROLE;

-- Staff B may see only B and branch B1.
SELECT set_config('request.jwt.claim.sub', current_setting('gogdely.test_user_b'), true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
    a UUID := current_setting('gogdely.test_tenant_a')::uuid;
    b UUID := current_setting('gogdely.test_tenant_b')::uuid;
    b1 UUID := current_setting('gogdely.test_branch_b1')::uuid;
BEGIN
    IF (SELECT count(*) FROM gogdely.memberships WHERE tenant_id IN (a, b)) <> 1
       OR (SELECT count(*) FROM gogdely.membership_branches WHERE tenant_id IN (a, b)) <> 1
       OR (SELECT count(*) FROM gogdely.tenants WHERE tenant_id IN (a, b)) <> 1
       OR (SELECT count(*) FROM gogdely.branches WHERE tenant_id IN (a, b)) <> 1
       OR (SELECT count(*) FROM gogdely.branches WHERE branch_id = b1) <> 1
       OR (SELECT count(*) FROM gogdely.tenants WHERE tenant_id = a) <> 0 THEN
        RAISE EXCEPTION 'Staff B escaped its tenant or branch scope';
    END IF;
END $$;
RESET ROLE;

-- Owner A sees both branches in A, still no tenant B.
UPDATE gogdely.memberships SET role = 'owner'
WHERE tenant_id = current_setting('gogdely.test_tenant_a')::uuid
  AND user_id = current_setting('gogdely.test_user_a')::uuid;
SELECT set_config('request.jwt.claim.sub', current_setting('gogdely.test_user_a'), true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
    a UUID := current_setting('gogdely.test_tenant_a')::uuid;
    b UUID := current_setting('gogdely.test_tenant_b')::uuid;
BEGIN
    IF (SELECT count(*) FROM gogdely.branches WHERE tenant_id IN (a, b)) <> 2
       OR (SELECT count(*) FROM gogdely.tenants WHERE tenant_id = b) <> 0 THEN
        RAISE EXCEPTION 'Owner A branch or tenant scope is incorrect';
    END IF;
END $$;
RESET ROLE;

-- Removing the membership must revoke access on the next query.
DELETE FROM gogdely.memberships
WHERE tenant_id = current_setting('gogdely.test_tenant_a')::uuid
  AND user_id = current_setting('gogdely.test_user_a')::uuid;
SELECT set_config('request.jwt.claim.sub', current_setting('gogdely.test_user_a'), true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE
    a UUID := current_setting('gogdely.test_tenant_a')::uuid;
BEGIN
    IF (SELECT count(*) FROM gogdely.memberships WHERE tenant_id = a) <> 0
       OR (SELECT count(*) FROM gogdely.membership_branches WHERE tenant_id = a) <> 0
       OR (SELECT count(*) FROM gogdely.tenants WHERE tenant_id = a) <> 0
       OR (SELECT count(*) FROM gogdely.branches WHERE tenant_id = a) <> 0 THEN
        RAISE EXCEPTION 'Revoked user A can still read tenant A';
    END IF;
END $$;
RESET ROLE;

-- Anonymous database role must not even have schema/table read privileges.
SET LOCAL ROLE anon;
DO $$
BEGIN
    BEGIN
        PERFORM count(*) FROM gogdely.tenants;
        RAISE EXCEPTION 'Anonymous role unexpectedly read the private schema';
    EXCEPTION WHEN insufficient_privilege THEN
        NULL;
    END;
END $$;
RESET ROLE;

DO $$ BEGIN
    RAISE NOTICE 'GOGDELY membership RLS verification passed; rolling back fixtures';
END $$;
ROLLBACK;
