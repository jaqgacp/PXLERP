-- =============================================================================
-- PXL ERP - Migration 017E: Assets RLS Policies
-- =============================================================================
-- Release        : v4.0-database-freeze
-- Architecture   : docs/architecture/ (frozen - DO NOT MODIFY)
-- PostgreSQL     : 16
-- Supabase       : Compatible
-- Idempotent     : Yes - DROP POLICY IF EXISTS before CREATE POLICY
-- Depends On     : 017a_rls_foundation.sql, 017b_setup_security_policies.sql,
--                  017c_master_data_policies.sql,
--                  017d_sales_purchasing_policies.sql
-- Scope          : Petty cash, bank, inventory, and fixed assets only
-- =============================================================================
--
-- PURPOSE
-- -------
-- Adds company-scoped RLS policies for assets-related tables from Migrations
-- 009, 010, and 011.
--
-- This migration intentionally does not add triggers, views, seed data,
-- helper functions, schema changes, column-level privileges, or policies for
-- setup/security, master data, sales, purchasing, accounting, posting,
-- compliance, audit, or import/export tables.
--
-- 017A helpers reused here:
--   - auth.user_company_ids()
--   - auth.user_branch_ids() is intentionally not used; Doc09 keeps branch
--     access as a UI/query filter in Phase 1.
--   - auth.has_permission(...) is intentionally not used; 017E follows the
--     requested company-access-only Phase 1 pattern.
--   - public.is_super_admin()
--
-- Standard company-scoped pattern:
--   SELECT/INSERT/UPDATE allowed when company_id is in auth.user_company_ids()
--   or public.is_super_admin() returns true.
--
-- Header update guard:
--   UPDATE is denied when status is posted, voided, reversed, cancelled,
--   or completed.
--
-- Service-role-only ledger policy:
--   SELECT is allowed by company scope. No authenticated INSERT/UPDATE/DELETE
--   policies are created, so service role remains the writer through RLS bypass.
--
-- No DELETE policies are created in this migration.
--
-- TARGET NOTES
-- ------------
-- - physical_count_sheets was requested, but Migration 010's canonical table
--   is physical_count_entries. This migration covers physical_count_entries.
-- - inventory_valuation_snapshots and inventory_valuation_snapshot_lines are
--   not created in Migrations 010/011 and are not targeted here to avoid an
--   invalid migration.
-- - petty_cash_count_lines uses parent-path policies through
--   petty_cash_count_sheets as requested.
--
-- POLICY COUNT
-- ------------
-- Service-role-only ledgers :  6 tables x 1 policy  =  6 policies
-- Status-bearing tables     : 17 tables x 3 policies = 51 policies
-- Company-scoped tables     : 12 tables x 3 policies = 36 policies
-- Parent-path child table   :  1 table  x 3 policies =  3 policies
-- Total expected            : 96 policies across 36 existing tables
-- =============================================================================

-- =============================================================================
-- SECTION 1: SERVICE-ROLE-ONLY LEDGER TABLES
-- =============================================================================

DO $migration$
DECLARE
    target_table text;
BEGIN
    FOREACH target_table IN ARRAY ARRAY[
        'inventory_balances',
        'inventory_cost_layers',
        'inventory_movements',
        'inventory_cost_layer_consumption',
        'outstanding_checks',
        'deposits_in_transit'
    ]
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017e_sel',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR SELECT
                TO authenticated
                USING (
                    public.is_super_admin()
                    OR company_id = ANY(auth.user_company_ids())
                )
        $sql$, 'p_' || target_table || '_017e_sel', target_table);
    END LOOP;
END
$migration$;

-- =============================================================================
-- SECTION 2: STATUS-BEARING ASSETS TABLES
-- =============================================================================
-- Petty cash / bank:
--   petty_cash_vouchers, petty_cash_replenishments, bank_fund_transfers,
--   inter_branch_transfers, bank_adjustments, bank_reconciliations
--
-- Inventory:
--   stock_adjustments, stock_transfers, goods_issues, physical_count_entries
--
-- Fixed assets:
--   asset_depreciation_schedules, asset_acquisitions, depreciation_runs,
--   depreciation_run_lines, asset_disposals, asset_transfers, asset_impairments
-- =============================================================================

DO $migration$
DECLARE
    target_table text;
BEGIN
    FOREACH target_table IN ARRAY ARRAY[
        'petty_cash_vouchers',
        'petty_cash_replenishments',
        'bank_fund_transfers',
        'inter_branch_transfers',
        'bank_adjustments',
        'bank_reconciliations',
        'stock_adjustments',
        'stock_transfers',
        'goods_issues',
        'physical_count_entries',
        'asset_depreciation_schedules',
        'asset_acquisitions',
        'depreciation_runs',
        'depreciation_run_lines',
        'asset_disposals',
        'asset_transfers',
        'asset_impairments'
    ]
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017e_sel',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR SELECT
                TO authenticated
                USING (
                    public.is_super_admin()
                    OR company_id = ANY(auth.user_company_ids())
                )
        $sql$, 'p_' || target_table || '_017e_sel', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017e_ins',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR INSERT
                TO authenticated
                WITH CHECK (
                    public.is_super_admin()
                    OR company_id = ANY(auth.user_company_ids())
                )
        $sql$, 'p_' || target_table || '_017e_ins', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017e_upd',
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
                        OR company_id = ANY(auth.user_company_ids())
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
                        OR company_id = ANY(auth.user_company_ids())
                    )
                    AND status::text NOT IN (
                        'posted',
                        'voided',
                        'reversed',
                        'cancelled',
                        'completed'
                    )
                )
        $sql$, 'p_' || target_table || '_017e_upd', target_table);
    END LOOP;
END
$migration$;

-- =============================================================================
-- SECTION 3: COMPANY-SCOPED NON-STATUS TABLES
-- =============================================================================

DO $migration$
DECLARE
    target_table text;
BEGIN
    FOREACH target_table IN ARRAY ARRAY[
        'petty_cash_funds',
        'petty_cash_voucher_lines',
        'petty_cash_count_sheets',
        'bank_reconciliation_lines',
        'bank_statement_lines',
        'stock_adjustment_lines',
        'stock_transfer_lines',
        'goods_issue_lines',
        'physical_count_lines',
        'depreciation_profiles',
        'asset_categories',
        'fixed_assets'
    ]
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017e_sel',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR SELECT
                TO authenticated
                USING (
                    public.is_super_admin()
                    OR company_id = ANY(auth.user_company_ids())
                )
        $sql$, 'p_' || target_table || '_017e_sel', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017e_ins',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR INSERT
                TO authenticated
                WITH CHECK (
                    public.is_super_admin()
                    OR company_id = ANY(auth.user_company_ids())
                )
        $sql$, 'p_' || target_table || '_017e_ins', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017e_upd',
            target_table
        );

        EXECUTE format($sql$
            CREATE POLICY %I
                ON public.%I
                FOR UPDATE
                TO authenticated
                USING (
                    public.is_super_admin()
                    OR company_id = ANY(auth.user_company_ids())
                )
                WITH CHECK (
                    public.is_super_admin()
                    OR company_id = ANY(auth.user_company_ids())
                )
        $sql$, 'p_' || target_table || '_017e_upd', target_table);
    END LOOP;
END
$migration$;

-- =============================================================================
-- SECTION 4: PARENT-PATH CHILD TABLES
-- =============================================================================

DROP POLICY IF EXISTS p_petty_cash_count_lines_017e_sel
    ON public.petty_cash_count_lines;

CREATE POLICY p_petty_cash_count_lines_017e_sel
    ON public.petty_cash_count_lines
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.petty_cash_count_sheets AS pcs
            WHERE pcs.id = count_sheet_id
              AND pcs.company_id = ANY(auth.user_company_ids())
        )
    );

DROP POLICY IF EXISTS p_petty_cash_count_lines_017e_ins
    ON public.petty_cash_count_lines;

CREATE POLICY p_petty_cash_count_lines_017e_ins
    ON public.petty_cash_count_lines
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.petty_cash_count_sheets AS pcs
            WHERE pcs.id = count_sheet_id
              AND pcs.company_id = ANY(auth.user_company_ids())
        )
    );

DROP POLICY IF EXISTS p_petty_cash_count_lines_017e_upd
    ON public.petty_cash_count_lines;

CREATE POLICY p_petty_cash_count_lines_017e_upd
    ON public.petty_cash_count_lines
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.petty_cash_count_sheets AS pcs
            WHERE pcs.id = count_sheet_id
              AND pcs.company_id = ANY(auth.user_company_ids())
        )
    )
    WITH CHECK (
        public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.petty_cash_count_sheets AS pcs
            WHERE pcs.id = count_sheet_id
              AND pcs.company_id = ANY(auth.user_company_ids())
        )
    );

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================
-- Expected 017E policy count: 96 policies across 36 existing tables.
--
-- SELECT COUNT(*) AS policy_count
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017e\_%' ESCAPE '\';
--
-- SELECT tablename, cmd, COUNT(*) AS policies
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017e\_%' ESCAPE '\'
-- GROUP BY tablename, cmd
-- ORDER BY tablename, cmd;
--
-- SELECT tablename, policyname
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017e\_%' ESCAPE '\'
--   AND cmd = 'DELETE';
--
-- Service-role-only ledger SELECT-only check:
--
-- SELECT tablename, cmd, COUNT(*) AS policies
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename IN (
--       'inventory_balances',
--       'inventory_cost_layers',
--       'inventory_movements',
--       'inventory_cost_layer_consumption',
--       'outstanding_checks',
--       'deposits_in_transit'
--   )
--   AND policyname LIKE 'p\_%\_017e\_%' ESCAPE '\'
-- GROUP BY tablename, cmd
-- ORDER BY tablename, cmd;
--
-- Status guard check:
--
-- SELECT tablename, policyname, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017e\_upd' ESCAPE '\'
--   AND tablename IN (
--       'petty_cash_vouchers',
--       'petty_cash_replenishments',
--       'bank_fund_transfers',
--       'inter_branch_transfers',
--       'bank_adjustments',
--       'bank_reconciliations',
--       'stock_adjustments',
--       'stock_transfers',
--       'goods_issues',
--       'physical_count_entries',
--       'asset_depreciation_schedules',
--       'asset_acquisitions',
--       'depreciation_runs',
--       'depreciation_run_lines',
--       'asset_disposals',
--       'asset_transfers',
--       'asset_impairments'
--   )
-- ORDER BY tablename;
--
-- Parent-path policy check:
--
-- SELECT policyname, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename = 'petty_cash_count_lines'
--   AND policyname LIKE 'p\_petty\_cash\_count\_lines\_017e\_%' ESCAPE '\'
-- ORDER BY policyname;
-- =============================================================================
