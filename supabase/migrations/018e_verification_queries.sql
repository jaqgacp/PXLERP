-- MIGRATION 018E: VERIFICATION QUERIES
-- Scope: Final database foundation assertion script.
-- Status: Fails the migration process if the 219 target or RLS mandates are missed.

DO $$
DECLARE
    active_table_count INT;
    tables_without_rls INT;
    target_count CONSTANT INT := 219;
BEGIN
    -- 1. Verify exact table count in public schema
    SELECT count(*)
    INTO active_table_count
    FROM pg_tables
    WHERE schemaname = 'public';

    IF active_table_count != target_count THEN
        RAISE EXCEPTION 'Verification Failed: Expected exactly % active tables, but found %.', target_count, active_table_count;
    END IF;

    -- 2. Verify ALL tables have RLS enabled
    SELECT count(*)
    INTO tables_without_rls
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r' -- regular tables
      AND c.relrowsecurity = false;

    IF tables_without_rls > 0 THEN
        RAISE EXCEPTION 'Verification Failed: Found % tables without Row Level Security enabled. Zero-Trust mandate violated.', tables_without_rls;
    END IF;

    -- If we reach here, the foundation freeze has passed verification!
    RAISE NOTICE 'SUCCESS: PXL ERP Phase 1 Foundation Freeze Verified. Active Tables: %, All RLS Enabled: TRUE.', active_table_count;
END $$;
