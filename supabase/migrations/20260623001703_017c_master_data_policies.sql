-- =============================================================================
-- PXL ERP - Migration 017C: Master Data RLS Policies
-- =============================================================================
-- Release        : v4.0-database-freeze
-- Architecture   : docs/architecture/ (frozen - DO NOT MODIFY)
-- PostgreSQL     : 16
-- Supabase       : Compatible
-- Idempotent     : Yes - DROP POLICY IF EXISTS before CREATE POLICY
-- Depends On     : 017a_rls_foundation.sql, 017b_setup_security_policies.sql
-- Scope          : Master Data tables only
-- =============================================================================
--
-- PURPOSE
-- -------
-- Adds company-scoped RLS policies for master data tables from Migration 006.
-- This migration intentionally does not add triggers, views, seed data,
-- helper functions, column-level privileges, or policies for setup/security,
-- sales, purchasing, transaction inventory, fixed assets, accounting, posting,
-- compliance, audit, or import/export tables.
--
-- 017A helpers reused here:
--   - public.user_company_ids()
--   - public.user_branch_ids() is intentionally not used; Doc09 keeps branch
--     access as a UI/query filter in Phase 1.
--   - public.has_permission(...) is intentionally not used; 017C follows the
--     requested company-access-only master data strategy.
--   - public.is_super_admin()
--
-- Standard company-scoped pattern:
--   SELECT/INSERT/UPDATE allowed when company_id is in public.user_company_ids()
--   or public.is_super_admin() returns true.
--
-- No DELETE policies are created in this migration.
--
-- TARGET NOTES
-- ------------
-- - payment_term_lines has no company_id by frozen schema design. It uses a
--   parent-path policy through public.payment_terms.
-- - customer_credit_profiles.current_outstanding remains a known service-role
--   guard item for later privilege hardening / policy cleanup. No column-level
--   GRANT/REVOKE is used in this migration.
-- =============================================================================

-- =============================================================================
-- SECTION 1: PAYMENT TERMS
-- =============================================================================

DROP POLICY IF EXISTS payment_terms_017c_select_company_or_super_admin
    ON public.payment_terms;

CREATE POLICY payment_terms_017c_select_company_or_super_admin
    ON public.payment_terms
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS payment_terms_017c_insert_company_or_super_admin
    ON public.payment_terms;

CREATE POLICY payment_terms_017c_insert_company_or_super_admin
    ON public.payment_terms
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS payment_terms_017c_update_company_or_super_admin
    ON public.payment_terms;

CREATE POLICY payment_terms_017c_update_company_or_super_admin
    ON public.payment_terms
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS payment_term_lines_017c_select_parent_company_or_super_admin
    ON public.payment_term_lines;

CREATE POLICY payment_term_lines_017c_select_parent_company_or_super_admin
    ON public.payment_term_lines
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.payment_terms AS pt
            WHERE pt.id = payment_term_id
              AND pt.company_id = ANY(public.user_company_ids())
        )
    );

DROP POLICY IF EXISTS payment_term_lines_017c_insert_parent_company_or_super_admin
    ON public.payment_term_lines;

CREATE POLICY payment_term_lines_017c_insert_parent_company_or_super_admin
    ON public.payment_term_lines
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.payment_terms AS pt
            WHERE pt.id = payment_term_id
              AND pt.company_id = ANY(public.user_company_ids())
        )
    );

DROP POLICY IF EXISTS payment_term_lines_017c_update_parent_company_or_super_admin
    ON public.payment_term_lines;

CREATE POLICY payment_term_lines_017c_update_parent_company_or_super_admin
    ON public.payment_term_lines
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.payment_terms AS pt
            WHERE pt.id = payment_term_id
              AND pt.company_id = ANY(public.user_company_ids())
        )
    )
    WITH CHECK (
        public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.payment_terms AS pt
            WHERE pt.id = payment_term_id
              AND pt.company_id = ANY(public.user_company_ids())
        )
    );

-- =============================================================================
-- SECTION 2: CUSTOMER MASTER DATA
-- =============================================================================

DROP POLICY IF EXISTS customers_017c_select_company_or_super_admin
    ON public.customers;

CREATE POLICY customers_017c_select_company_or_super_admin
    ON public.customers
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customers_017c_insert_company_or_super_admin
    ON public.customers;

CREATE POLICY customers_017c_insert_company_or_super_admin
    ON public.customers
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customers_017c_update_company_or_super_admin
    ON public.customers;

CREATE POLICY customers_017c_update_company_or_super_admin
    ON public.customers
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customer_addresses_017c_select_company_or_super_admin
    ON public.customer_addresses;

CREATE POLICY customer_addresses_017c_select_company_or_super_admin
    ON public.customer_addresses
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customer_addresses_017c_insert_company_or_super_admin
    ON public.customer_addresses;

CREATE POLICY customer_addresses_017c_insert_company_or_super_admin
    ON public.customer_addresses
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customer_addresses_017c_update_company_or_super_admin
    ON public.customer_addresses;

CREATE POLICY customer_addresses_017c_update_company_or_super_admin
    ON public.customer_addresses
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customer_contacts_017c_select_company_or_super_admin
    ON public.customer_contacts;

CREATE POLICY customer_contacts_017c_select_company_or_super_admin
    ON public.customer_contacts
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customer_contacts_017c_insert_company_or_super_admin
    ON public.customer_contacts;

CREATE POLICY customer_contacts_017c_insert_company_or_super_admin
    ON public.customer_contacts
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customer_contacts_017c_update_company_or_super_admin
    ON public.customer_contacts;

CREATE POLICY customer_contacts_017c_update_company_or_super_admin
    ON public.customer_contacts
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customer_tax_profiles_017c_select_company_or_super_admin
    ON public.customer_tax_profiles;

CREATE POLICY customer_tax_profiles_017c_select_company_or_super_admin
    ON public.customer_tax_profiles
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customer_tax_profiles_017c_insert_company_or_super_admin
    ON public.customer_tax_profiles;

CREATE POLICY customer_tax_profiles_017c_insert_company_or_super_admin
    ON public.customer_tax_profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customer_tax_profiles_017c_update_company_or_super_admin
    ON public.customer_tax_profiles;

CREATE POLICY customer_tax_profiles_017c_update_company_or_super_admin
    ON public.customer_tax_profiles
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customer_credit_profiles_017c_select_company_or_super_admin
    ON public.customer_credit_profiles;

CREATE POLICY customer_credit_profiles_017c_select_company_or_super_admin
    ON public.customer_credit_profiles
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customer_credit_profiles_017c_insert_company_or_super_admin
    ON public.customer_credit_profiles;

CREATE POLICY customer_credit_profiles_017c_insert_company_or_super_admin
    ON public.customer_credit_profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS customer_credit_profiles_017c_update_company_or_super_admin
    ON public.customer_credit_profiles;

CREATE POLICY customer_credit_profiles_017c_update_company_or_super_admin
    ON public.customer_credit_profiles
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

-- =============================================================================
-- SECTION 3: SUPPLIER MASTER DATA
-- =============================================================================

DROP POLICY IF EXISTS suppliers_017c_select_company_or_super_admin
    ON public.suppliers;

CREATE POLICY suppliers_017c_select_company_or_super_admin
    ON public.suppliers
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS suppliers_017c_insert_company_or_super_admin
    ON public.suppliers;

CREATE POLICY suppliers_017c_insert_company_or_super_admin
    ON public.suppliers
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS suppliers_017c_update_company_or_super_admin
    ON public.suppliers;

CREATE POLICY suppliers_017c_update_company_or_super_admin
    ON public.suppliers
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS supplier_addresses_017c_select_company_or_super_admin
    ON public.supplier_addresses;

CREATE POLICY supplier_addresses_017c_select_company_or_super_admin
    ON public.supplier_addresses
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS supplier_addresses_017c_insert_company_or_super_admin
    ON public.supplier_addresses;

CREATE POLICY supplier_addresses_017c_insert_company_or_super_admin
    ON public.supplier_addresses
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS supplier_addresses_017c_update_company_or_super_admin
    ON public.supplier_addresses;

CREATE POLICY supplier_addresses_017c_update_company_or_super_admin
    ON public.supplier_addresses
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS supplier_contacts_017c_select_company_or_super_admin
    ON public.supplier_contacts;

CREATE POLICY supplier_contacts_017c_select_company_or_super_admin
    ON public.supplier_contacts
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS supplier_contacts_017c_insert_company_or_super_admin
    ON public.supplier_contacts;

CREATE POLICY supplier_contacts_017c_insert_company_or_super_admin
    ON public.supplier_contacts
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS supplier_contacts_017c_update_company_or_super_admin
    ON public.supplier_contacts;

CREATE POLICY supplier_contacts_017c_update_company_or_super_admin
    ON public.supplier_contacts
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS supplier_tax_profiles_017c_select_company_or_super_admin
    ON public.supplier_tax_profiles;

CREATE POLICY supplier_tax_profiles_017c_select_company_or_super_admin
    ON public.supplier_tax_profiles
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS supplier_tax_profiles_017c_insert_company_or_super_admin
    ON public.supplier_tax_profiles;

CREATE POLICY supplier_tax_profiles_017c_insert_company_or_super_admin
    ON public.supplier_tax_profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS supplier_tax_profiles_017c_update_company_or_super_admin
    ON public.supplier_tax_profiles;

CREATE POLICY supplier_tax_profiles_017c_update_company_or_super_admin
    ON public.supplier_tax_profiles
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS supplier_bank_details_017c_select_company_or_super_admin
    ON public.supplier_bank_details;

CREATE POLICY supplier_bank_details_017c_select_company_or_super_admin
    ON public.supplier_bank_details
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS supplier_bank_details_017c_insert_company_or_super_admin
    ON public.supplier_bank_details;

CREATE POLICY supplier_bank_details_017c_insert_company_or_super_admin
    ON public.supplier_bank_details
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS supplier_bank_details_017c_update_company_or_super_admin
    ON public.supplier_bank_details;

CREATE POLICY supplier_bank_details_017c_update_company_or_super_admin
    ON public.supplier_bank_details
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

-- =============================================================================
-- SECTION 4: PERSONNEL
-- =============================================================================

DROP POLICY IF EXISTS personnel_017c_select_company_or_super_admin
    ON public.personnel;

CREATE POLICY personnel_017c_select_company_or_super_admin
    ON public.personnel
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS personnel_017c_insert_company_or_super_admin
    ON public.personnel;

CREATE POLICY personnel_017c_insert_company_or_super_admin
    ON public.personnel
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS personnel_017c_update_company_or_super_admin
    ON public.personnel;

CREATE POLICY personnel_017c_update_company_or_super_admin
    ON public.personnel
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

-- =============================================================================
-- SECTION 5: ITEMS AND SERVICES MASTER DATA
-- =============================================================================

DROP POLICY IF EXISTS item_categories_017c_select_company_or_super_admin
    ON public.item_categories;

CREATE POLICY item_categories_017c_select_company_or_super_admin
    ON public.item_categories
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS item_categories_017c_insert_company_or_super_admin
    ON public.item_categories;

CREATE POLICY item_categories_017c_insert_company_or_super_admin
    ON public.item_categories
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS item_categories_017c_update_company_or_super_admin
    ON public.item_categories;

CREATE POLICY item_categories_017c_update_company_or_super_admin
    ON public.item_categories
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS units_of_measure_017c_select_company_or_super_admin
    ON public.units_of_measure;

CREATE POLICY units_of_measure_017c_select_company_or_super_admin
    ON public.units_of_measure
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS units_of_measure_017c_insert_company_or_super_admin
    ON public.units_of_measure;

CREATE POLICY units_of_measure_017c_insert_company_or_super_admin
    ON public.units_of_measure
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS units_of_measure_017c_update_company_or_super_admin
    ON public.units_of_measure;

CREATE POLICY units_of_measure_017c_update_company_or_super_admin
    ON public.units_of_measure
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS uom_conversions_017c_select_company_or_super_admin
    ON public.uom_conversions;

CREATE POLICY uom_conversions_017c_select_company_or_super_admin
    ON public.uom_conversions
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS uom_conversions_017c_insert_company_or_super_admin
    ON public.uom_conversions;

CREATE POLICY uom_conversions_017c_insert_company_or_super_admin
    ON public.uom_conversions
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS uom_conversions_017c_update_company_or_super_admin
    ON public.uom_conversions;

CREATE POLICY uom_conversions_017c_update_company_or_super_admin
    ON public.uom_conversions
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS items_017c_select_company_or_super_admin
    ON public.items;

CREATE POLICY items_017c_select_company_or_super_admin
    ON public.items
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS items_017c_insert_company_or_super_admin
    ON public.items;

CREATE POLICY items_017c_insert_company_or_super_admin
    ON public.items
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS items_017c_update_company_or_super_admin
    ON public.items;

CREATE POLICY items_017c_update_company_or_super_admin
    ON public.items
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS item_prices_017c_select_company_or_super_admin
    ON public.item_prices;

CREATE POLICY item_prices_017c_select_company_or_super_admin
    ON public.item_prices
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS item_prices_017c_insert_company_or_super_admin
    ON public.item_prices;

CREATE POLICY item_prices_017c_insert_company_or_super_admin
    ON public.item_prices
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS item_prices_017c_update_company_or_super_admin
    ON public.item_prices;

CREATE POLICY item_prices_017c_update_company_or_super_admin
    ON public.item_prices
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS services_017c_select_company_or_super_admin
    ON public.services;

CREATE POLICY services_017c_select_company_or_super_admin
    ON public.services
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS services_017c_insert_company_or_super_admin
    ON public.services;

CREATE POLICY services_017c_insert_company_or_super_admin
    ON public.services
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS services_017c_update_company_or_super_admin
    ON public.services;

CREATE POLICY services_017c_update_company_or_super_admin
    ON public.services
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

-- =============================================================================
-- SECTION 6: INVENTORY MASTER DATA
-- =============================================================================

DROP POLICY IF EXISTS warehouses_017c_select_company_or_super_admin
    ON public.warehouses;

CREATE POLICY warehouses_017c_select_company_or_super_admin
    ON public.warehouses
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS warehouses_017c_insert_company_or_super_admin
    ON public.warehouses;

CREATE POLICY warehouses_017c_insert_company_or_super_admin
    ON public.warehouses
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS warehouses_017c_update_company_or_super_admin
    ON public.warehouses;

CREATE POLICY warehouses_017c_update_company_or_super_admin
    ON public.warehouses
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS warehouse_stock_settings_017c_select_company_or_super_admin
    ON public.warehouse_stock_settings;

CREATE POLICY warehouse_stock_settings_017c_select_company_or_super_admin
    ON public.warehouse_stock_settings
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS warehouse_stock_settings_017c_insert_company_or_super_admin
    ON public.warehouse_stock_settings;

CREATE POLICY warehouse_stock_settings_017c_insert_company_or_super_admin
    ON public.warehouse_stock_settings
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS warehouse_stock_settings_017c_update_company_or_super_admin
    ON public.warehouse_stock_settings;

CREATE POLICY warehouse_stock_settings_017c_update_company_or_super_admin
    ON public.warehouse_stock_settings
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================
-- Expected 017C policy count: 63 policies across 21 tables.
--
-- SELECT COUNT(*) AS policy_count
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE '%017c%';
--
-- SELECT tablename, cmd, COUNT(*) AS policies
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE '%017c%'
-- GROUP BY tablename, cmd
-- ORDER BY tablename, cmd;
--
-- SELECT tablename, policyname
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE '%017c%'
--   AND cmd = 'DELETE';
--
-- SELECT tablename, policyname, cmd
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename IN (
--       'payment_terms',
--       'payment_term_lines',
--       'customers',
--       'customer_addresses',
--       'customer_contacts',
--       'customer_tax_profiles',
--       'customer_credit_profiles',
--       'suppliers',
--       'supplier_addresses',
--       'supplier_contacts',
--       'supplier_tax_profiles',
--       'supplier_bank_details',
--       'personnel',
--       'item_categories',
--       'units_of_measure',
--       'uom_conversions',
--       'items',
--       'item_prices',
--       'services',
--       'warehouses',
--       'warehouse_stock_settings'
--   )
-- ORDER BY tablename, policyname;
--
-- Parent-path policy smoke check:
--
-- SELECT policyname, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename = 'payment_term_lines'
--   AND policyname LIKE '%017c%'
-- ORDER BY policyname;
-- =============================================================================

