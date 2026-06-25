-- =============================================================================
-- PXL ERP - Migration 017B: Setup & Security RLS Policies
-- =============================================================================
-- Release        : v4.0-database-freeze
-- Architecture   : docs/architecture/ (frozen - DO NOT MODIFY)
-- PostgreSQL     : 16
-- Supabase       : Compatible
-- Idempotent     : Yes - DROP POLICY IF EXISTS before CREATE POLICY
-- Depends On     : 017a_rls_foundation.sql
-- Scope          : Setup & Security tables only
-- =============================================================================
--
-- PURPOSE
-- -------
-- Adds the first company-scoped RLS policies for setup and security tables.
-- This migration intentionally does not add triggers, views, seed data,
-- helper functions, column-level privileges, or policies for transaction,
-- master data, accounting, inventory, fixed asset, or compliance tables.
--
-- 017A helpers reused here:
--   - public.user_company_ids()
--   - public.has_permission(permission_code text, target_company_id uuid)
--   - public.is_super_admin()
--
-- Permission-code mapping uses only Doc09 canonical settings permissions:
--   - settings.users.manage
--   - settings.roles.manage
--   - settings.coa.manage
--   - settings.approval.manage
--   - settings.document_templates.manage
--   - settings.feature_settings.manage
--
-- No DELETE policies are created in this migration.
--
-- TARGET NOTES
-- ------------
-- - permissions already received global read-only SELECT in 017A.
-- - posting_rules is not an active table name; architecture renamed it to
--   posting_rule_sets / posting_rule_lines. Those are accounting/COA tables
--   and are deferred out of this setup/security-only batch.
-- - profiles self-write is intentionally not granted here because
--   profiles.is_super_admin exists and this task excludes column-level
--   privilege hardening.
-- =============================================================================

-- =============================================================================
-- SECTION 1: PROFILES
-- =============================================================================

DROP POLICY IF EXISTS profiles_017b_select_self_or_super_admin
    ON public.profiles;

CREATE POLICY profiles_017b_select_self_or_super_admin
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (
        id = auth.uid()
        OR public.is_super_admin()
    );

DROP POLICY IF EXISTS profiles_017b_insert_super_admin
    ON public.profiles;

CREATE POLICY profiles_017b_insert_super_admin
    ON public.profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
    );

DROP POLICY IF EXISTS profiles_017b_update_super_admin
    ON public.profiles;

CREATE POLICY profiles_017b_update_super_admin
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
    )
    WITH CHECK (
        public.is_super_admin()
    );

-- =============================================================================
-- SECTION 2: ORGANIZATION SETUP
-- =============================================================================

DROP POLICY IF EXISTS companies_017b_select_company_or_super_admin
    ON public.companies;

CREATE POLICY companies_017b_select_company_or_super_admin
    ON public.companies
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS companies_017b_insert_super_admin
    ON public.companies;

CREATE POLICY companies_017b_insert_super_admin
    ON public.companies
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
    );

DROP POLICY IF EXISTS companies_017b_update_company_settings
    ON public.companies;

CREATE POLICY companies_017b_update_company_settings
    ON public.companies
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            id = ANY(public.user_company_ids())
            AND public.has_permission('settings.feature_settings.manage', id)
        )
    );

DROP POLICY IF EXISTS branches_017b_select_company_or_super_admin
    ON public.branches;

CREATE POLICY branches_017b_select_company_or_super_admin
    ON public.branches
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS branches_017b_insert_company_admin
    ON public.branches;

CREATE POLICY branches_017b_insert_company_admin
    ON public.branches
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    );

DROP POLICY IF EXISTS branches_017b_update_company_admin
    ON public.branches;

CREATE POLICY branches_017b_update_company_admin
    ON public.branches
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    );

DROP POLICY IF EXISTS departments_017b_select_company_or_super_admin
    ON public.departments;

CREATE POLICY departments_017b_select_company_or_super_admin
    ON public.departments
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS departments_017b_insert_company_admin
    ON public.departments;

CREATE POLICY departments_017b_insert_company_admin
    ON public.departments
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    );

DROP POLICY IF EXISTS departments_017b_update_company_admin
    ON public.departments;

CREATE POLICY departments_017b_update_company_admin
    ON public.departments
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    );

DROP POLICY IF EXISTS cost_centers_017b_select_company_or_super_admin
    ON public.cost_centers;

CREATE POLICY cost_centers_017b_select_company_or_super_admin
    ON public.cost_centers
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS cost_centers_017b_insert_company_admin
    ON public.cost_centers;

CREATE POLICY cost_centers_017b_insert_company_admin
    ON public.cost_centers
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    );

DROP POLICY IF EXISTS cost_centers_017b_update_company_admin
    ON public.cost_centers;

CREATE POLICY cost_centers_017b_update_company_admin
    ON public.cost_centers
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    );

-- =============================================================================
-- SECTION 3: ACCOUNTING SETUP TABLES IN 017B SCOPE
-- =============================================================================

DROP POLICY IF EXISTS fiscal_years_017b_select_company_or_super_admin
    ON public.fiscal_years;

CREATE POLICY fiscal_years_017b_select_company_or_super_admin
    ON public.fiscal_years
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS fiscal_years_017b_insert_accounting_setup
    ON public.fiscal_years;

CREATE POLICY fiscal_years_017b_insert_accounting_setup
    ON public.fiscal_years
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.coa.manage', company_id)
        )
    );

DROP POLICY IF EXISTS fiscal_years_017b_update_accounting_setup
    ON public.fiscal_years;

CREATE POLICY fiscal_years_017b_update_accounting_setup
    ON public.fiscal_years
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.coa.manage', company_id)
        )
    );

DROP POLICY IF EXISTS fiscal_periods_017b_select_company_or_super_admin
    ON public.fiscal_periods;

CREATE POLICY fiscal_periods_017b_select_company_or_super_admin
    ON public.fiscal_periods
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS fiscal_periods_017b_insert_accounting_setup
    ON public.fiscal_periods;

CREATE POLICY fiscal_periods_017b_insert_accounting_setup
    ON public.fiscal_periods
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.coa.manage', company_id)
        )
    );

DROP POLICY IF EXISTS fiscal_periods_017b_update_accounting_setup
    ON public.fiscal_periods;

CREATE POLICY fiscal_periods_017b_update_accounting_setup
    ON public.fiscal_periods
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.coa.manage', company_id)
        )
    );

DROP POLICY IF EXISTS system_account_config_017b_select_company_or_super_admin
    ON public.system_account_config;

CREATE POLICY system_account_config_017b_select_company_or_super_admin
    ON public.system_account_config
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS system_account_config_017b_insert_accounting_setup
    ON public.system_account_config;

CREATE POLICY system_account_config_017b_insert_accounting_setup
    ON public.system_account_config
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.coa.manage', company_id)
        )
    );

DROP POLICY IF EXISTS system_account_config_017b_update_accounting_setup
    ON public.system_account_config;

CREATE POLICY system_account_config_017b_update_accounting_setup
    ON public.system_account_config
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.coa.manage', company_id)
        )
    );

-- =============================================================================
-- SECTION 4: SECURITY AND RBAC TABLES
-- =============================================================================

DROP POLICY IF EXISTS roles_017b_select_company_system_or_super_admin
    ON public.roles;

CREATE POLICY roles_017b_select_company_system_or_super_admin
    ON public.roles
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id IS NULL
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS roles_017b_insert_role_manager
    ON public.roles;

CREATE POLICY roles_017b_insert_role_manager
    ON public.roles
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id IS NOT NULL
            AND company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.roles.manage', company_id)
        )
    );

DROP POLICY IF EXISTS roles_017b_update_role_manager
    ON public.roles;

CREATE POLICY roles_017b_update_role_manager
    ON public.roles
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR (
            company_id IS NOT NULL
            AND company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.roles.manage', company_id)
        )
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id IS NOT NULL
            AND company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.roles.manage', company_id)
        )
    );

DROP POLICY IF EXISTS role_permissions_017b_select_visible_roles
    ON public.role_permissions;

CREATE POLICY role_permissions_017b_select_visible_roles
    ON public.role_permissions
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.roles AS r
            WHERE r.id = role_id
              AND (
                  r.company_id IS NULL
                  OR r.company_id = ANY(public.user_company_ids())
              )
        )
    );

DROP POLICY IF EXISTS role_permissions_017b_insert_role_manager
    ON public.role_permissions;

CREATE POLICY role_permissions_017b_insert_role_manager
    ON public.role_permissions
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.roles AS r
            WHERE r.id = role_id
              AND r.company_id IS NOT NULL
              AND r.company_id = ANY(public.user_company_ids())
              AND public.has_permission('settings.roles.manage', r.company_id)
        )
    );

DROP POLICY IF EXISTS role_permissions_017b_update_role_manager
    ON public.role_permissions;

CREATE POLICY role_permissions_017b_update_role_manager
    ON public.role_permissions
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.roles AS r
            WHERE r.id = role_id
              AND (
                  r.company_id IS NULL
                  OR r.company_id = ANY(public.user_company_ids())
              )
        )
    )
    WITH CHECK (
        public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.roles AS r
            WHERE r.id = role_id
              AND r.company_id IS NOT NULL
              AND r.company_id = ANY(public.user_company_ids())
              AND public.has_permission('settings.roles.manage', r.company_id)
        )
    );

DROP POLICY IF EXISTS user_roles_017b_select_self_or_role_manager
    ON public.user_roles;

CREATE POLICY user_roles_017b_select_self_or_role_manager
    ON public.user_roles
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR user_id = auth.uid()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.roles.manage', company_id)
        )
    );

DROP POLICY IF EXISTS user_roles_017b_insert_role_manager
    ON public.user_roles;

CREATE POLICY user_roles_017b_insert_role_manager
    ON public.user_roles
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.roles.manage', company_id)
        )
    );

DROP POLICY IF EXISTS user_roles_017b_update_role_manager
    ON public.user_roles;

CREATE POLICY user_roles_017b_update_role_manager
    ON public.user_roles
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.roles.manage', company_id)
        )
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.roles.manage', company_id)
        )
    );

DROP POLICY IF EXISTS user_company_access_017b_select_self_or_user_manager
    ON public.user_company_access;

CREATE POLICY user_company_access_017b_select_self_or_user_manager
    ON public.user_company_access
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR user_id = auth.uid()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    );

DROP POLICY IF EXISTS user_company_access_017b_insert_user_manager
    ON public.user_company_access;

CREATE POLICY user_company_access_017b_insert_user_manager
    ON public.user_company_access
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    );

DROP POLICY IF EXISTS user_company_access_017b_update_user_manager
    ON public.user_company_access;

CREATE POLICY user_company_access_017b_update_user_manager
    ON public.user_company_access
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    );

DROP POLICY IF EXISTS user_branch_access_017b_select_self_or_user_manager
    ON public.user_branch_access;

CREATE POLICY user_branch_access_017b_select_self_or_user_manager
    ON public.user_branch_access
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR user_id = auth.uid()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    );

DROP POLICY IF EXISTS user_branch_access_017b_insert_user_manager
    ON public.user_branch_access;

CREATE POLICY user_branch_access_017b_insert_user_manager
    ON public.user_branch_access
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    );

DROP POLICY IF EXISTS user_branch_access_017b_update_user_manager
    ON public.user_branch_access;

CREATE POLICY user_branch_access_017b_update_user_manager
    ON public.user_branch_access
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.users.manage', company_id)
        )
    );

-- =============================================================================
-- SECTION 5: DOCUMENT NUMBERING AND SYSTEM CONTROLS
-- =============================================================================

DROP POLICY IF EXISTS number_series_017b_select_company_or_super_admin
    ON public.number_series;

CREATE POLICY number_series_017b_select_company_or_super_admin
    ON public.number_series
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS number_series_017b_insert_document_setup
    ON public.number_series;

CREATE POLICY number_series_017b_insert_document_setup
    ON public.number_series
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.document_templates.manage', company_id)
        )
    );

DROP POLICY IF EXISTS number_series_017b_update_document_setup
    ON public.number_series;

CREATE POLICY number_series_017b_update_document_setup
    ON public.number_series
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.document_templates.manage', company_id)
        )
    );

DROP POLICY IF EXISTS number_series_atp_017b_select_company_or_super_admin
    ON public.number_series_atp;

CREATE POLICY number_series_atp_017b_select_company_or_super_admin
    ON public.number_series_atp
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS number_series_atp_017b_insert_document_setup
    ON public.number_series_atp;

CREATE POLICY number_series_atp_017b_insert_document_setup
    ON public.number_series_atp
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.document_templates.manage', company_id)
        )
    );

DROP POLICY IF EXISTS number_series_atp_017b_update_document_setup
    ON public.number_series_atp;

CREATE POLICY number_series_atp_017b_update_document_setup
    ON public.number_series_atp
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.document_templates.manage', company_id)
        )
    );

DROP POLICY IF EXISTS approval_matrix_017b_select_company_or_super_admin
    ON public.approval_matrix;

CREATE POLICY approval_matrix_017b_select_company_or_super_admin
    ON public.approval_matrix
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS approval_matrix_017b_insert_approval_manager
    ON public.approval_matrix;

CREATE POLICY approval_matrix_017b_insert_approval_manager
    ON public.approval_matrix
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.approval.manage', company_id)
        )
    );

DROP POLICY IF EXISTS approval_matrix_017b_update_approval_manager
    ON public.approval_matrix;

CREATE POLICY approval_matrix_017b_update_approval_manager
    ON public.approval_matrix
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.approval.manage', company_id)
        )
    );

DROP POLICY IF EXISTS validation_rules_017b_select_company_or_super_admin
    ON public.validation_rules;

CREATE POLICY validation_rules_017b_select_company_or_super_admin
    ON public.validation_rules
    FOR SELECT
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    );

DROP POLICY IF EXISTS validation_rules_017b_insert_settings_manager
    ON public.validation_rules;

CREATE POLICY validation_rules_017b_insert_settings_manager
    ON public.validation_rules
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.approval.manage', company_id)
        )
    );

DROP POLICY IF EXISTS validation_rules_017b_update_settings_manager
    ON public.validation_rules;

CREATE POLICY validation_rules_017b_update_settings_manager
    ON public.validation_rules
    FOR UPDATE
    TO authenticated
    USING (
        public.is_super_admin()
        OR company_id = ANY(public.user_company_ids())
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            company_id = ANY(public.user_company_ids())
            AND public.has_permission('settings.approval.manage', company_id)
        )
    );

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================
-- Expected 017B policy count: 51 policies across 17 tables.
--
-- SELECT COUNT(*) AS policy_count
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE '%017b%';
--
-- SELECT tablename, cmd, COUNT(*) AS policies
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE '%017b%'
-- GROUP BY tablename, cmd
-- ORDER BY tablename, cmd;
--
-- SELECT tablename, policyname
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND policyname LIKE '%017b%'
--   AND cmd = 'DELETE';
--
-- SELECT tablename, policyname, cmd
-- FROM pg_policies
-- WHERE schemaname = 'public'
--   AND tablename IN (
--       'profiles',
--       'companies',
--       'branches',
--       'departments',
--       'cost_centers',
--       'fiscal_years',
--       'fiscal_periods',
--       'roles',
--       'role_permissions',
--       'user_roles',
--       'user_company_access',
--       'user_branch_access',
--       'number_series',
--       'number_series_atp',
--       'system_account_config',
--       'approval_matrix',
--       'validation_rules'
--   )
-- ORDER BY tablename, policyname;
-- =============================================================================

