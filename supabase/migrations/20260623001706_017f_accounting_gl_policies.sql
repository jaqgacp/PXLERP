-- =============================================================================
-- PXL ERP - Migration 017F: Accounting + GL RLS Policies
-- =============================================================================
-- Release        : v4.0-database-freeze
-- Architecture   : docs/architecture/ (frozen - DO NOT MODIFY)
-- PostgreSQL     : 16
-- Supabase       : Compatible
-- Idempotent     : Yes - DROP POLICY IF EXISTS before CREATE POLICY
-- Depends On     : 017a_rls_foundation.sql, 017b_setup_security_policies.sql,
--                  017c_master_data_policies.sql,
--                  017d_sales_purchasing_policies.sql,
--                  017e_assets_policies.sql
-- Scope          : Accounting, GL, posting runtime, budgets, schedules only
-- =============================================================================
--
-- PURPOSE
-- -------
-- Adds company-scoped RLS policies for accounting configuration, General Ledger
-- runtime tables, posting runtime tables, budgets, and accounting schedules.
--
-- This migration intentionally does not add triggers, views, seed data,
-- helper functions, schema changes, column-level privileges, or policies for
-- setup/security, master data, sales, purchasing, assets, compliance, audit,
-- or import/export tables.
--
-- 017A helpers reused here:
--   - public.user_company_ids()
--   - public.user_branch_ids() is intentionally not used; Doc09 keeps branch
--     access as a UI/query filter in Phase 1.
--   - public.has_permission(...) is intentionally not used; 017F follows the
--     requested company-access-only Phase 1 pattern.
--   - public.is_super_admin()
--
-- Standard company-scoped pattern:
--   SELECT/INSERT/UPDATE allowed when company_id is in public.user_company_ids()
--   or public.is_super_admin() returns true.
--
-- Editable status guard:
--   UPDATE is denied when status is posted, voided, reversed, cancelled,
--   or completed.
--
-- Service-role-only runtime policy:
--   SELECT is allowed by company scope. No authenticated INSERT/UPDATE/DELETE
--   policies are created, so service role remains the writer through RLS bypass.
--
-- No DELETE policies are created in this migration.
--
-- POLICY COUNT
-- ------------
-- Service-role-only runtime : 12 tables x 1 policy  = 12 policies
-- Editable status tables    :  6 tables x 3 policies = 18 policies
-- Editable non-status tables:  5 tables x 3 policies = 15 policies
-- Total expected            : 45 policies across 23 tables
-- =============================================================================

-- =============================================================================
-- SECTION 1: SERVICE-ROLE-ONLY RUNTIME TABLES
-- =============================================================================

DO $migration$
DECLARE
    target_table text;
BEGIN
    FOREACH target_table IN ARRAY ARRAY[
        'posting_batches',
        'posting_errors',
        'journal_entries',
        'journal_lines',
        'gl_balances',
        'subsidiary_ledger_entries',
        'document_relationships',
        'amortization_runs',
        'amortization_run_details',
        'revenue_recognition_runs',
        'revenue_recognition_run_details',
        'auto_reversal_runs'
    ]
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017f_sel',
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
        $sql$, 'p_' || target_table || '_017f_sel', target_table);
    END LOOP;
END
$migration$;

-- =============================================================================
-- SECTION 2: EDITABLE STATUS-BEARING ACCOUNTING TABLES
-- =============================================================================

DO $migration$
DECLARE
    target_table text;
BEGIN
    FOREACH target_table IN ARRAY ARRAY[
        'budgets',
        'recurring_journal_templates',
        'amortization_schedules',
        'amortization_schedule_lines',
        'revenue_recognition_schedules',
        'revenue_recognition_schedule_lines'
    ]
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017f_sel',
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
        $sql$, 'p_' || target_table || '_017f_sel', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017f_ins',
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
        $sql$, 'p_' || target_table || '_017f_ins', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017f_upd',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR UPDATE
                TO authenticated
                USING (
                    (
                        public.is_super_admin()
                        OR company_id = ANY(public.user_company_ids())
                    )
                    AND status::text NOT IN (
                        'posted',
                        'voided',
                        'reversed',
                        'cancelled',
                        'completed'
                    )
                )
                WITH CHECK (
                    (
                        public.is_super_admin()
                        OR company_id = ANY(public.user_company_ids())
                    )
                    AND status::text NOT IN (
                        'posted',
                        'voided',
                        'reversed',
                        'cancelled',
                        'completed'
                    )
                )
        $sql$, 'p_' || target_table || '_017f_upd', target_table);
    END LOOP;
END
$migration$;

-- =============================================================================
-- SECTION 3: EDITABLE NON-STATUS ACCOUNTING TABLES
-- =============================================================================

DO $migration$
DECLARE
    target_table text;
BEGIN
    FOREACH target_table IN ARRAY ARRAY[
        'opening_balance_entries',
        'posting_rule_sets',
        'posting_rule_lines',
        'budget_lines',
        'recurring_journal_template_lines'
    ]
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017f_sel',
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
        $sql$, 'p_' || target_table || '_017f_sel', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017f_ins',
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
        $sql$, 'p_' || target_table || '_017f_ins', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017f_upd',
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
        $sql$, 'p_' || target_table || '_017f_upd', target_table);
    END LOOP;
END
$migration$;

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================
-- Expected 017F policy count: 45 policies across 23 tables.
--
-- SELECT COUNT(*) AS policy_count
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017f\_%' ESCAPE '\';
--
-- SELECT tablename, cmd, COUNT(*) AS policies
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017f\_%' ESCAPE '\'
-- GROUP BY tablename, cmd
-- ORDER BY tablename, cmd;
--
-- SELECT tablename, policyname
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017f\_%' ESCAPE '\'
--   AND cmd = 'DELETE';
--
-- Service-role-only runtime SELECT-only check:
--
-- SELECT tablename, cmd, COUNT(*) AS policies
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename IN (
--       'posting_batches',
--       'posting_errors',
--       'journal_entries',
--       'journal_lines',
--       'gl_balances',
--       'subsidiary_ledger_entries',
--       'document_relationships',
--       'amortization_runs',
--       'amortization_run_details',
--       'revenue_recognition_runs',
--       'revenue_recognition_run_details',
--       'auto_reversal_runs'
--   )
--   AND policyname LIKE 'p\_%\_017f\_%' ESCAPE '\'
-- GROUP BY tablename, cmd
-- ORDER BY tablename, cmd;
--
-- Status guard check:
--
-- SELECT tablename, policyname, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017f\_upd' ESCAPE '\'
--   AND tablename IN (
--       'budgets',
--       'recurring_journal_templates',
--       'amortization_schedules',
--       'amortization_schedule_lines',
--       'revenue_recognition_schedules',
--       'revenue_recognition_schedule_lines'
--   )
-- ORDER BY tablename;
-- =============================================================================

