-- GOG-074, issue #39: read-only catalog inspection before the 0002 migration.
-- Run in the isolated GOGDELY Homologacao project. Compare every result with
-- database/migrations/0001_cloud_foundation.sql; counts alone are not a dump.

SELECT
    (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'gogdely' AND c.relkind = 'r') AS tables,
    (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'gogdely' AND c.relkind = 'r'
       AND c.relrowsecurity AND c.relforcerowsecurity) AS forced_rls_tables,
    (SELECT count(*) FROM pg_policies WHERE schemaname = 'gogdely') AS policies,
    (SELECT count(*) FROM pg_constraint con
     JOIN pg_class c ON c.oid = con.conrelid
     JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'gogdely') AS constraints,
    (SELECT count(*) FROM pg_indexes WHERE schemaname = 'gogdely') AS indexes,
    has_schema_privilege('anon', 'gogdely', 'USAGE') AS anon_schema_usage,
    has_schema_privilege('authenticated', 'gogdely', 'USAGE') AS authenticated_schema_usage,
    (SELECT bool_or(has_table_privilege('anon', c.oid, 'SELECT'))
     FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'gogdely' AND c.relkind = 'r') AS anon_any_select,
    (SELECT bool_or(has_table_privilege('authenticated', c.oid, 'SELECT'))
     FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'gogdely' AND c.relkind = 'r') AS authenticated_any_select;

SELECT table_name,
       string_agg(column_name || ':' || data_type || ':' || is_nullable || ':' ||
                  coalesce(column_default, ''), ', ' ORDER BY ordinal_position) AS columns
FROM information_schema.columns
WHERE table_schema = 'gogdely'
GROUP BY table_name
ORDER BY table_name;

SELECT c.relname AS table_name, con.conname AS name,
       pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'gogdely'
ORDER BY c.relname, con.conname;

SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'gogdely'
ORDER BY indexname;
