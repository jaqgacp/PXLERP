-- =============================================================================
-- Migration 018f: Grant Access Privileges
-- =============================================================================
-- The local development database's `postgres` role lacked the standard default 
-- privileges for `authenticated` and `service_role` schemas. As a result,
-- all tables created in previous migrations lacked `SELECT`, `INSERT`, `UPDATE`,
-- and `DELETE` privileges, which caused RLS evaluation to be bypassed entirely 
-- and returned 403 Forbidden on all PostgREST queries.
-- =============================================================================

-- 1. Ensure basic schema usage
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- 2. Grant table permissions (RLS will restrict actual data access)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;

-- 3. Set future default privileges so new tables inherit properly
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT SELECT ON TABLES TO anon;

-- 4. Grant sequence permissions (needed for serial columns/ID generation)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, service_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT USAGE, SELECT ON SEQUENCES TO authenticated, service_role;
