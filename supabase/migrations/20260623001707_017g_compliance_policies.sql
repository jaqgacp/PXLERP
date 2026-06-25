-- =============================================================================
-- PXL ERP - Migration 017G: Compliance RLS Policies
-- =============================================================================
-- Release        : v4.0-database-freeze
-- Architecture   : docs/architecture/ (frozen - DO NOT MODIFY)
-- PostgreSQL     : 16
-- Supabase       : Compatible
-- Idempotent     : Yes - DROP POLICY IF EXISTS before CREATE POLICY
-- Depends On     : 017a_rls_foundation.sql, 017b_setup_security_policies.sql,
--                  017c_master_data_policies.sql,
--                  017d_sales_purchasing_policies.sql,
--                  017e_assets_policies.sql,
--                  017f_accounting_gl_policies.sql
-- Scope          : Tax setup and compliance tables only
-- =============================================================================
--
-- PURPOSE
-- -------
-- Adds company-scoped RLS policies for Migration 005 tax setup tables and
-- Migration 015 compliance tables.
--
-- This migration intentionally does not add triggers, views, seed data,
-- helper functions, schema changes, column-level privileges, or policies for
-- setup/security, master data, sales, purchasing, assets, accounting, audit,
-- import/export, or later final verification tables.
--
-- 017A helpers reused here:
--   - public.user_company_ids()
--   - public.user_branch_ids() is intentionally not used; Doc09 keeps branch
--     access as a UI/query filter in Phase 1.
--   - public.has_permission(permission_code text, target_company_id uuid)
--   - public.is_super_admin()
--
-- Standard company-scoped SELECT pattern:
--   SELECT allowed when company_id is in public.user_company_ids() or
--   public.is_super_admin() returns true.
--
-- Tax setup/config write pattern:
--   INSERT/UPDATE allowed only to super admins or users with
--   settings.compliance_profile.manage for the target company.
--
-- Service-role-only compliance policy:
--   SELECT is allowed by company scope. No authenticated INSERT/UPDATE/DELETE
--   policies are created, so service role remains the writer through RLS bypass.
--
-- User-managed compliance write pattern:
--   INSERT/UPDATE allowed by company scope. Exact Doc09 permission codes are
--   applied only where the table maps cleanly to the named action.
--
-- No DELETE policies are created in this migration.
--
-- POLICY COUNT
-- ------------
-- Tax setup/config             :  7 tables x 3 policies = 21 policies
-- Service-role-only compliance : 13 tables x 1 policy  = 13 policies
-- User-managed with permissions:  5 tables x 3 policies = 15 policies
-- User-managed company scoped  :  6 tables x 3 policies = 18 policies
-- Total expected               : 67 policies across 31 tables
-- =============================================================================

-- =============================================================================
-- SECTION 1: TAX SETUP / COMPLIANCE CONFIG TABLES
-- =============================================================================

DO $migration$
DECLARE
    target_table text;
BEGIN
    FOREACH target_table IN ARRAY ARRAY[
        'bir_form_configurations',
        'tax_codes',
        'vat_codes',
        'ewt_codes',
        'fwt_codes',
        'percentage_tax_codes',
        'tax_calendar'
    ]
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017g_sel',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR SELECT
                TO authenticated
                USING (
                    public.is_super_admin()
                    OR company_id = ANY(public.user_company_ids())
                )
        $sql$, 'p_' || target_table || '_017g_sel', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017g_ins',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR INSERT
                TO authenticated
                WITH CHECK (
                    public.is_super_admin()
                    OR public.has_permission(
                        'settings.compliance_profile.manage',
                        company_id
                    )
                )
        $sql$, 'p_' || target_table || '_017g_ins', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017g_upd',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR UPDATE
                TO authenticated
                USING (
                    public.is_super_admin()
                    OR public.has_permission(
                        'settings.compliance_profile.manage',
                        company_id
                    )
                )
                WITH CHECK (
                    public.is_super_admin()
                    OR public.has_permission(
                        'settings.compliance_profile.manage',
                        company_id
                    )
                )
        $sql$, 'p_' || target_table || '_017g_upd', target_table);
    END LOOP;
END
$migration$;

-- =============================================================================
-- SECTION 2: SERVICE-ROLE-ONLY COMPLIANCE LEDGERS / EXPORTS / COMPUTATIONS
-- =============================================================================

DO $migration$
DECLARE
    target_table text;
BEGIN
    FOREACH target_table IN ARRAY ARRAY[
        'vat_entries',
        'vat_period_summaries',
        'slsp_exports',
        'relief_exports',
        'ewt_entries',
        'ewt_period_summaries',
        'fwt_entries',
        'percentage_tax_entries',
        'percentage_tax_period_summaries',
        'itr_computation_runs',
        'income_tax_computation_lines',
        'qap_exports',
        'sawt_exports'
    ]
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017g_sel',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR SELECT
                TO authenticated
                USING (
                    public.is_super_admin()
                    OR company_id = ANY(public.user_company_ids())
                )
        $sql$, 'p_' || target_table || '_017g_sel', target_table);
    END LOOP;
END
$migration$;

-- =============================================================================
-- SECTION 3: USER-MANAGED COMPLIANCE TABLES WITH EXACT DOC09 PERMISSIONS
-- =============================================================================

DO $migration$
DECLARE
    target_table text;
    permission_code text;
BEGIN
    FOR target_table, permission_code IN
        SELECT *
        FROM (VALUES
            ('certificates_2307_issued', 'compliance.2307.generate'),
            ('ewt_remittances_1601eq', 'compliance.1601eq.file'),
            ('fwt_remittances_1601fq', 'compliance.1601fq.file'),
            ('percentage_tax_return_filings', 'compliance.2551q.file'),
            ('income_tax_return_filings', 'compliance.itr.file')
        ) AS mapped(target_table, permission_code)
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017g_sel',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR SELECT
                TO authenticated
                USING (
                    public.is_super_admin()
                    OR company_id = ANY(public.user_company_ids())
                )
        $sql$, 'p_' || target_table || '_017g_sel', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017g_ins',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR INSERT
                TO authenticated
                WITH CHECK (
                    public.is_super_admin()
                    OR (
                        company_id = ANY(public.user_company_ids())
                        AND public.has_permission(%L, company_id)
                    )
                )
        $sql$, 'p_' || target_table || '_017g_ins', target_table, permission_code);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017g_upd',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR UPDATE
                TO authenticated
                USING (
                    public.is_super_admin()
                    OR (
                        company_id = ANY(public.user_company_ids())
                        AND public.has_permission(%L, company_id)
                    )
                )
                WITH CHECK (
                    public.is_super_admin()
                    OR (
                        company_id = ANY(public.user_company_ids())
                        AND public.has_permission(%L, company_id)
                    )
                )
        $sql$,
            'p_' || target_table || '_017g_upd',
            target_table,
            permission_code,
            permission_code
        );
    END LOOP;
END
$migration$;

-- =============================================================================
-- SECTION 4: USER-MANAGED COMPLIANCE TABLES WITH COMPANY-SCOPED WRITES
-- =============================================================================

DO $migration$
DECLARE
    target_table text;
BEGIN
    FOREACH target_table IN ARRAY ARRAY[
        'vat_return_filings',
        'certificates_2307_received',
        'certificates_2306_issued',
        'book_tax_reconciliations',
        'tax_credits_schedules',
        'nolco_tracking'
    ]
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017g_sel',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR SELECT
                TO authenticated
                USING (
                    public.is_super_admin()
                    OR company_id = ANY(public.user_company_ids())
                )
        $sql$, 'p_' || target_table || '_017g_sel', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017g_ins',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR INSERT
                TO authenticated
                WITH CHECK (
                    public.is_super_admin()
                    OR company_id = ANY(public.user_company_ids())
                )
        $sql$, 'p_' || target_table || '_017g_ins', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017g_upd',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR UPDATE
                TO authenticated
                USING (
                    public.is_super_admin()
                    OR company_id = ANY(public.user_company_ids())
                )
                WITH CHECK (
                    public.is_super_admin()
                    OR company_id = ANY(public.user_company_ids())
                )
        $sql$, 'p_' || target_table || '_017g_upd', target_table);
    END LOOP;
END
$migration$;

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================
-- Expected 017G policy count: 67 policies across 31 tables.
--
-- SELECT COUNT(*) AS policy_count
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017g\_%' ESCAPE '\';
--
-- SELECT tablename, cmd, COUNT(*) AS policies
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017g\_%' ESCAPE '\'
-- GROUP BY tablename, cmd
-- ORDER BY tablename, cmd;
--
-- SELECT tablename, policyname
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017g\_%' ESCAPE '\'
--   AND cmd = 'DELETE';
--
-- Broad true-expression check:
--
-- SELECT tablename, policyname, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017g\_%' ESCAPE '\'
--   AND (
--       qual ~* '(^|[^[:alpha:]_])true([^[:alpha:]_]|$)'
--       OR with_check ~* '(^|[^[:alpha:]_])true([^[:alpha:]_]|$)'
--   );
--
-- Service-role-only SELECT-only check:
--
-- SELECT tablename, cmd, COUNT(*) AS policies
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename IN (
--       'vat_entries',
--       'vat_period_summaries',
--       'slsp_exports',
--       'relief_exports',
--       'ewt_entries',
--       'ewt_period_summaries',
--       'fwt_entries',
--       'percentage_tax_entries',
--       'percentage_tax_period_summaries',
--       'itr_computation_runs',
--       'income_tax_computation_lines',
--       'qap_exports',
--       'sawt_exports'
--   )
--   AND policyname LIKE 'p\_%\_017g\_%' ESCAPE '\'
-- GROUP BY tablename, cmd
-- ORDER BY tablename, cmd;
--
-- Permission-gated write policy check:
--
-- SELECT tablename, policyname, cmd, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017g\_%' ESCAPE '\'
--   AND (
--       qual LIKE '%auth.has_permission%'
--       OR with_check LIKE '%auth.has_permission%'
--   )
-- ORDER BY tablename, policyname;
-- =============================================================================

-- =============================================================================
-- END OF MIGRATION 017G
-- =============================================================================

