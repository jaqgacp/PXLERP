-- =============================================================================
-- PXL ERP - Migration 017D: Sales + Purchasing RLS Policies
-- =============================================================================
-- Release        : v4.0-database-freeze
-- Architecture   : docs/architecture/ (frozen - DO NOT MODIFY)
-- PostgreSQL     : 16
-- Supabase       : Compatible
-- Idempotent     : Yes - DROP POLICY IF EXISTS before CREATE POLICY
-- Depends On     : 017a_rls_foundation.sql, 017b_setup_security_policies.sql,
--                  017c_master_data_policies.sql
-- Scope          : Sales + Purchasing transaction tables only
-- =============================================================================
--
-- PURPOSE
-- -------
-- Adds company-scoped RLS policies for Migration 007 sales tables and
-- Migration 008 purchasing tables.
--
-- This migration intentionally does not add triggers, views, seed data,
-- helper functions, schema changes, column-level privileges, or policies for
-- setup/security, master data, inventory, fixed assets, accounting, posting,
-- compliance, audit, or import/export tables.
--
-- 017A helpers reused here:
--   - auth.user_company_ids()
--   - auth.user_branch_ids() is intentionally not used; Doc09 keeps branch
--     access as a UI/query filter in Phase 1.
--   - auth.has_permission(...) is intentionally not used; Doc09 has exact
--     permission codes for only some of these document tables, so 017D follows
--     the requested company-access-only Phase 1 pattern.
--   - public.is_super_admin()
--
-- Standard company-scoped pattern:
--   SELECT/INSERT/UPDATE allowed when company_id is in auth.user_company_ids()
--   or public.is_super_admin() returns true.
--
-- Header update guard:
--   UPDATE is denied when status is posted, voided, reversed, or cancelled.
--
-- No DELETE policies are created in this migration.
--
-- POLICY COUNT
-- ------------
-- Status-bearing headers : 17 tables x 3 policies = 51 policies
-- Line/non-status tables : 17 tables x 3 policies = 51 policies
-- Total expected         : 102 policies across 34 tables
-- =============================================================================

-- =============================================================================
-- SECTION 1: STATUS-BEARING TRANSACTION HEADERS
-- =============================================================================
-- Sales headers:
--   quotations, sales_orders, delivery_receipts, sales_invoices, cash_sales,
--   receipts, sales_credit_memos, sales_debit_memos, customer_returns
--
-- Purchasing headers:
--   purchase_orders, receiving_reports, vendor_bills, cash_purchases,
--   payment_vouchers, vendor_credits, supplier_debit_memos, purchase_returns
-- =============================================================================

DO $migration$
DECLARE
    target_table text;
BEGIN
    FOREACH target_table IN ARRAY ARRAY[
        'quotations',
        'sales_orders',
        'delivery_receipts',
        'sales_invoices',
        'cash_sales',
        'receipts',
        'sales_credit_memos',
        'sales_debit_memos',
        'customer_returns',
        'purchase_orders',
        'receiving_reports',
        'vendor_bills',
        'cash_purchases',
        'payment_vouchers',
        'vendor_credits',
        'supplier_debit_memos',
        'purchase_returns'
    ]
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017d_sel',
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
        $sql$, 'p_' || target_table || '_017d_sel', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017d_ins',
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
        $sql$, 'p_' || target_table || '_017d_ins', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017d_upd',
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
                    AND status::text NOT IN ('posted', 'voided', 'reversed', 'cancelled')
                )
                WITH CHECK (
                    (
                        public.is_super_admin()
                        OR company_id = ANY(auth.user_company_ids())
                    )
                    AND status::text NOT IN ('posted', 'voided', 'reversed', 'cancelled')
                )
        $sql$, 'p_' || target_table || '_017d_upd', target_table);
    END LOOP;
END
$migration$;

-- =============================================================================
-- SECTION 2: LINE AND NON-STATUS TRANSACTION TABLES
-- =============================================================================
-- Sales lines:
--   quotation_lines, sales_order_lines, delivery_receipt_lines,
--   sales_invoice_lines, cash_sale_lines, receipt_lines,
--   sales_credit_memo_lines, sales_debit_memo_lines, customer_return_lines
--
-- Purchasing lines:
--   purchase_order_lines, receiving_report_lines, vendor_bill_lines,
--   cash_purchase_lines, payment_voucher_lines, vendor_credit_lines,
--   supplier_debit_memo_lines, purchase_return_lines
-- =============================================================================

DO $migration$
DECLARE
    target_table text;
BEGIN
    FOREACH target_table IN ARRAY ARRAY[
        'quotation_lines',
        'sales_order_lines',
        'delivery_receipt_lines',
        'sales_invoice_lines',
        'cash_sale_lines',
        'receipt_lines',
        'sales_credit_memo_lines',
        'sales_debit_memo_lines',
        'customer_return_lines',
        'purchase_order_lines',
        'receiving_report_lines',
        'vendor_bill_lines',
        'cash_purchase_lines',
        'payment_voucher_lines',
        'vendor_credit_lines',
        'supplier_debit_memo_lines',
        'purchase_return_lines'
    ]
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017d_sel',
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
        $sql$, 'p_' || target_table || '_017d_sel', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017d_ins',
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
        $sql$, 'p_' || target_table || '_017d_ins', target_table);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON public.%I',
            'p_' || target_table || '_017d_upd',
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
        $sql$, 'p_' || target_table || '_017d_upd', target_table);
    END LOOP;
END
$migration$;

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================
-- Expected 017D policy count: 102 policies across 34 tables.
--
-- SELECT COUNT(*) AS policy_count
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017d\_%' ESCAPE '\';
--
-- SELECT tablename, cmd, COUNT(*) AS policies
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017d\_%' ESCAPE '\'
-- GROUP BY tablename, cmd
-- ORDER BY tablename, cmd;
--
-- SELECT tablename, policyname
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017d\_%' ESCAPE '\'
--   AND cmd = 'DELETE';
--
-- SELECT tablename, policyname, cmd, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename IN (
--       'quotations',
--       'quotation_lines',
--       'sales_orders',
--       'sales_order_lines',
--       'delivery_receipts',
--       'delivery_receipt_lines',
--       'sales_invoices',
--       'sales_invoice_lines',
--       'cash_sales',
--       'cash_sale_lines',
--       'receipts',
--       'receipt_lines',
--       'sales_credit_memos',
--       'sales_credit_memo_lines',
--       'sales_debit_memos',
--       'sales_debit_memo_lines',
--       'customer_returns',
--       'customer_return_lines',
--       'purchase_orders',
--       'purchase_order_lines',
--       'receiving_reports',
--       'receiving_report_lines',
--       'vendor_bills',
--       'vendor_bill_lines',
--       'cash_purchases',
--       'cash_purchase_lines',
--       'payment_vouchers',
--       'payment_voucher_lines',
--       'vendor_credits',
--       'vendor_credit_lines',
--       'supplier_debit_memos',
--       'supplier_debit_memo_lines',
--       'purchase_returns',
--       'purchase_return_lines'
--   )
-- ORDER BY tablename, policyname;
--
-- Status guard check for header UPDATE policies:
--
-- SELECT tablename, policyname, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE 'p\_%\_017d\_upd' ESCAPE '\'
--   AND tablename IN (
--       'quotations',
--       'sales_orders',
--       'delivery_receipts',
--       'sales_invoices',
--       'cash_sales',
--       'receipts',
--       'sales_credit_memos',
--       'sales_debit_memos',
--       'customer_returns',
--       'purchase_orders',
--       'receiving_reports',
--       'vendor_bills',
--       'cash_purchases',
--       'payment_vouchers',
--       'vendor_credits',
--       'supplier_debit_memos',
--       'purchase_returns'
--   )
-- ORDER BY tablename;
-- =============================================================================
