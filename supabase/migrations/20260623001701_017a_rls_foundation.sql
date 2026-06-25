-- =============================================================================
-- Migration 017A - RLS Foundation
-- =============================================================================
-- Release        : v4.0-database-freeze
-- Depends On     : 001-016
-- Scope          : RLS helper functions + global read-only policy foundation
--
-- PURPOSE
-- -------
-- This is intentionally a small foundation migration. It creates only the
-- helper functions needed by later RLS policy batches and read-only policies
-- for true global lookup/reference tables.
--
-- OUT OF SCOPE FOR 017A
-- ---------------------
-- - Company-scoped business table policies
-- - Child-table correlated policies such as payment_term_lines
-- - Service-role-only mutation guard policies
-- - Column-level privilege hardening
-- - Triggers, views, seed data, cron jobs, and schema redesign
-- =============================================================================

-- =============================================================================
-- SECTION 1: RLS HELPER FUNCTIONS
-- =============================================================================
-- SECURITY DEFINER is required because these helpers read access-control tables
-- that already have RLS enabled. They must work before policies on those tables
-- are created. All referenced objects are schema-qualified to avoid search-path
-- surprises and policy recursion.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.user_company_ids()
RETURNS uuid[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $function$
    SELECT COALESCE(
        array_agg(uca.company_id ORDER BY uca.company_id),
        ARRAY[]::uuid[]
    )
    FROM public.user_company_access AS uca
    WHERE uca.user_id = auth.uid()
      AND uca.is_active = true
      AND uca.revoked_at IS NULL;
$function$;

COMMENT ON FUNCTION public.user_company_ids() IS
    'Returns company IDs available to the current authenticated user. SECURITY DEFINER so future RLS policies can evaluate company access even while access tables themselves have RLS enabled.';

CREATE OR REPLACE FUNCTION public.user_branch_ids()
RETURNS uuid[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $function$
    SELECT COALESCE(
        array_agg(uba.branch_id ORDER BY uba.branch_id),
        ARRAY[]::uuid[]
    )
    FROM public.user_branch_access AS uba
    WHERE uba.user_id = auth.uid()
      AND uba.is_active = true
      AND EXISTS (
          SELECT 1
          FROM public.user_company_access AS uca
          WHERE uca.user_id = uba.user_id
            AND uca.company_id = uba.company_id
            AND uca.is_active = true
            AND uca.revoked_at IS NULL
      );
$function$;

COMMENT ON FUNCTION public.user_branch_ids() IS
    'Returns branch IDs available to the current authenticated user, limited to active company access. Used by application query filters and future optional branch-aware RLS policies.';

CREATE OR REPLACE FUNCTION public.has_permission(permission_code text, target_company_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM public.user_roles AS ur
        JOIN public.roles AS r
          ON r.id = ur.role_id
        JOIN public.role_permissions AS rp
          ON rp.role_id = r.id
        JOIN public.permissions AS p
          ON p.id = rp.permission_id
        WHERE auth.uid() IS NOT NULL
          AND $1 IS NOT NULL
          AND $2 IS NOT NULL
          AND ur.user_id = auth.uid()
          AND ur.company_id = $2
          AND ur.is_active = true
          AND ur.revoked_at IS NULL
          AND (ur.expires_at IS NULL OR ur.expires_at > now())
          AND r.is_active = true
          AND r.deleted_at IS NULL
          AND (r.company_id IS NULL OR r.company_id = $2)
          AND rp.deleted_at IS NULL
          AND p.permission_code = $1
          AND EXISTS (
              SELECT 1
              FROM public.user_company_access AS uca
              WHERE uca.user_id = ur.user_id
                AND uca.company_id = ur.company_id
                AND uca.is_active = true
                AND uca.revoked_at IS NULL
          )
    );
$function$;

COMMENT ON FUNCTION public.has_permission(text, uuid) IS
    'Checks whether the current authenticated user has a permission code inside a target company. Does not grant super-admin bypass; platform bypass is handled separately by public.is_super_admin().';

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles AS p
        WHERE p.id = auth.uid()
          AND p.is_active = true
          AND p.is_super_admin = true
          AND p.deleted_at IS NULL
    );
$function$;

COMMENT ON FUNCTION public.is_super_admin() IS
    'Returns true when the current authenticated user is an active platform super admin. Intended for future platform-level administrative policies only.';

-- =============================================================================
-- SECTION 2: RLS ENABLEMENT STATUS
-- =============================================================================
-- Migration 016 enabled RLS on all previously missing tables.
-- Static verification before authoring 017A:
--   created tables      : 178
--   unique RLS-enabled  : 178
--   missing RLS enables : 0
--
-- Therefore 017A does not repeat ALTER TABLE ... ENABLE ROW LEVEL SECURITY.
-- =============================================================================

-- =============================================================================
-- SECTION 3: GLOBAL LOOKUP TABLE POLICIES
-- =============================================================================
-- These tables are true global lookup/reference tables:
--   - account_types: platform accounting classification lookup
--   - currencies: ISO currency master shared across tenants
--   - permissions: platform permission catalog
--   - atc_codes: BIR ATC reference codes shared across tenants
--
-- Policy pattern for 017A:
--   SELECT allowed to authenticated
--   No INSERT/UPDATE/DELETE policy for authenticated
--   Service role bypasses RLS
-- =============================================================================

DROP POLICY IF EXISTS account_types_select_global_authenticated
    ON public.account_types;

CREATE POLICY account_types_select_global_authenticated
    ON public.account_types
    FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS currencies_select_global_authenticated
    ON public.currencies;

CREATE POLICY currencies_select_global_authenticated
    ON public.currencies
    FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS permissions_select_global_authenticated
    ON public.permissions;

CREATE POLICY permissions_select_global_authenticated
    ON public.permissions
    FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS atc_codes_select_global_authenticated
    ON public.atc_codes;

CREATE POLICY atc_codes_select_global_authenticated
    ON public.atc_codes
    FOR SELECT
    TO authenticated
    USING (true);

-- =============================================================================
-- SECTION 4: VERIFICATION QUERIES
-- =============================================================================
-- Helper functions:
--
-- SELECT n.nspname AS schema_name,
--        p.proname AS function_name,
--        p.provolatile AS volatility,
--        p.prosecdef AS security_definer
-- FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE (n.nspname, p.proname) IN (
--     ('auth', 'user_company_ids'),
--     ('auth', 'user_branch_ids'),
--     ('auth', 'has_permission'),
--     ('public', 'is_super_admin')
-- )
-- ORDER BY n.nspname, p.proname;
--
-- Global policies:
--
-- SELECT schemaname, tablename, policyname, cmd, roles, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename IN ('account_types', 'currencies', 'permissions', 'atc_codes')
-- ORDER BY tablename, policyname;
--
-- Confirm no authenticated DML policies were added to global tables:
--
-- SELECT tablename, policyname, cmd, roles
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename IN ('account_types', 'currencies', 'permissions', 'atc_codes')
--   AND cmd <> 'SELECT';
--
-- Confirm all current public tables have RLS enabled:
--
-- SELECT COUNT(*) FILTER (WHERE relrowsecurity) AS rls_enabled,
--        COUNT(*) AS total_tables
-- FROM pg_class c
-- JOIN pg_namespace n ON n.oid = c.relnamespace
-- WHERE n.nspname = 'public'
--   AND c.relkind = 'r';
--
-- Smoke calls under an authenticated request context:
--
-- SELECT public.user_company_ids();
-- SELECT public.user_branch_ids();
-- SELECT public.has_permission('settings.company.read', '<company_uuid>'::uuid);
-- SELECT public.is_super_admin();
-- =============================================================================

-- =============================================================================
-- END OF MIGRATION 017A
-- =============================================================================

