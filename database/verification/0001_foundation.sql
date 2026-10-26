-- GOG-072/074/114. Read-only assertions for the test project.
DO $$
DECLARE
    actual_tables INTEGER;
    unsafe_tables INTEGER;
    policy_count INTEGER;
    bucket_count INTEGER;
BEGIN
    SELECT count(*) INTO actual_tables
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'gogdely' AND c.relkind = 'r';
    IF actual_tables <> 8 THEN
        RAISE EXCEPTION 'Expected 8 gogdely tables, found %', actual_tables;
    END IF;

    SELECT count(*) INTO unsafe_tables
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'gogdely' AND c.relkind = 'r'
      AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity);
    IF unsafe_tables <> 0 THEN
        RAISE EXCEPTION '% gogdely tables lack forced RLS', unsafe_tables;
    END IF;

    SELECT count(*) INTO policy_count
    FROM pg_policies WHERE schemaname = 'gogdely';
    IF policy_count <> 0 THEN
        RAISE EXCEPTION 'Unexpected policies on gogdely schema: %', policy_count;
    END IF;

    SELECT count(*) INTO bucket_count
    FROM storage.buckets
    WHERE id = 'gogdely-menu-testes' AND public = FALSE;
    IF bucket_count <> 1 THEN
        RAISE EXCEPTION 'Private GOGDELY test bucket missing';
    END IF;
END $$;

SELECT 'gogdely test foundation: verified' AS result;
