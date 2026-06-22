-- =============================================================================
-- Migration 016 — Pre-RLS Security & Constraints Patch
-- =============================================================================
-- Release        : v4.0-database-freeze
-- Audited commit : acbd3f365461973e7fe375b8b4e03229ff7040a5
-- Architecture   : docs/architecture/ (frozen — DO NOT MODIFY)
-- Depends On     : 001–015
-- Must Run Before: 017 (RLS Policies)
--
-- PURPOSE
-- -------
-- Remediation pass addressing Codex Audit blockers before RLS policies are
-- applied in Migration 017. No new tables are created. No columns added.
-- No table redesign. All fixes are additive (ENABLE RLS, new indexes, new
-- constraints, constraint replacement for NULL-branch uniqueness).
--
-- SECTIONS
-- ─────────
-- 1.  ENABLE ROW LEVEL SECURITY — Migration 004 (32 tables)
-- 2.  ENABLE ROW LEVEL SECURITY — Migration 006 (payment_term_lines)
-- 3.  ENABLE ROW LEVEL SECURITY — Migration 013 (9 tables)
-- 4.  ENABLE ROW LEVEL SECURITY — Migration 014 (9 tables)
-- 5.  ENABLE ROW LEVEL SECURITY — Migration 015 (24 tables)
-- 6.  NULL-branch uniqueness fix — number_series
-- 7.  NULL-branch uniqueness fix — system_account_config
-- 8.  NULL-branch uniqueness fix — user_roles
-- 9.  role_code uniqueness — system roles / company roles
-- 10. department code uniqueness
-- 11. cost_center code uniqueness
-- 12. CAS guards — date check + permit_no uniqueness
-- 13. ATP guard — atp_no uniqueness
-- 14. inventory_movements entity_type — add customer_return / purchase_return
--
-- BACKLOG ITEMS RESOLVED BY THIS MIGRATION
-- ─────────────────────────────────────────
--   C-1  (number_series NULL-branch unique)          → RESOLVED
--   C-2  (system_account_config NULL-branch unique)  → RESOLVED
--   C-3  (user_roles NULL-branch unique)             → RESOLVED
--   C-4  (roles role_code uniqueness)                → RESOLVED
--   H-1  (departments code uniqueness)               → RESOLVED
--   H-2  (cost_centers code uniqueness)              → RESOLVED
--   M-3  (cas_registrations date guard + unique)     → RESOLVED
--   M-4  (number_series_atp atp_no uniqueness)       → RESOLVED
--   M-010-2 (inventory_movements entity_type gap)    → RESOLVED
--   H-001 (RLS not enabled on 013/014/015 tables)   → RESOLVED
--
-- NOT FIXED IN THIS MIGRATION (backlog items deferred to Migration 017+)
-- ───────────────────────────────────────────────────────────────────────
--   All RLS POLICY definitions          → Migration 017
--   Service-role write-only guards      → Migration 017
--   M-001/M-002 audit column gaps       → FINAL REVIEW PASS
--   L-015-4 nolco remaining_balance     → FINAL REVIEW PASS
--   All other MEDIUM/LOW backlog items  → FINAL REVIEW PASS
-- =============================================================================

-- =============================================================================
-- SECTION 1: ENABLE ROW LEVEL SECURITY — Migration 004 (32 tables)
-- =============================================================================
-- Migration 004 comment block noted "RLS: 0 (deferred to Migration 017)".
-- RLS must be ENABLED on each table before policies can be applied.
-- Enabling RLS without policies defaults to DENY-ALL for non-owners,
-- which is correct for Supabase (service role bypasses RLS regardless).
-- =============================================================================

ALTER TABLE public.account_types              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.currencies                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.companies                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.branches                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cost_centers               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fiscal_years               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fiscal_periods             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fiscal_locks               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chart_of_accounts          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exchange_rates             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_account_config      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_compliance_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_feature_settings   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cas_registrations          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_bank_accounts      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles                      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_company_access        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_branch_access         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_department_access     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approval_matrix            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approval_matrix_steps      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.number_series              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.number_series_atp          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.atp_usage_logs             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_controls          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.validation_rules           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_parameters          ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- SECTION 2: ENABLE ROW LEVEL SECURITY — Migration 006 (payment_term_lines)
-- =============================================================================
-- payment_terms itself is covered by its migration's RLS declaration.
-- payment_term_lines has no company_id; RLS policy in Migration 017 will
-- use a correlated subquery through payment_terms (backlog H-006-2).
-- =============================================================================

ALTER TABLE public.payment_term_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- SECTION 3: ENABLE ROW LEVEL SECURITY — Migration 013 (9 tables)
-- =============================================================================
-- Migration 013 did not call ENABLE ROW LEVEL SECURITY on any of its tables
-- (H-001 finding from Accounting Core Review Gate).
-- =============================================================================

ALTER TABLE public.recurring_journal_templates      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recurring_journal_template_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posting_batches                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posting_errors                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_lines                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gl_balances                      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subsidiary_ledger_entries        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_relationships           ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- SECTION 4: ENABLE ROW LEVEL SECURITY — Migration 014 (9 tables)
-- =============================================================================

ALTER TABLE public.amortization_schedules               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.amortization_schedule_lines          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.amortization_runs                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.amortization_run_details             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.revenue_recognition_schedules        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.revenue_recognition_schedule_lines   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.revenue_recognition_runs             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.revenue_recognition_run_details      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auto_reversal_runs                   ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- SECTION 5: ENABLE ROW LEVEL SECURITY — Migration 015 (24 tables)
-- =============================================================================

-- Module 17 — VAT
ALTER TABLE public.vat_entries                          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vat_period_summaries                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vat_return_filings                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.slsp_exports                         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.relief_exports                       ENABLE ROW LEVEL SECURITY;

-- Module 18 — Withholding Tax
ALTER TABLE public.certificates_2307_issued             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certificates_2307_received           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ewt_entries                          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ewt_period_summaries                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ewt_remittances_1601eq               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fwt_entries                          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certificates_2306_issued             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fwt_remittances_1601fq               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qap_exports                          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sawt_exports                         ENABLE ROW LEVEL SECURITY;

-- Module 29 — Percentage Tax
ALTER TABLE public.percentage_tax_entries               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.percentage_tax_period_summaries      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.percentage_tax_return_filings        ENABLE ROW LEVEL SECURITY;

-- Module 19 — Income Tax
ALTER TABLE public.income_tax_return_filings            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.itr_computation_runs                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.income_tax_computation_lines         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.book_tax_reconciliations             ENABLE ROW LEVEL SECURITY;

-- Module 19 + 30
ALTER TABLE public.tax_credits_schedules                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nolco_tracking                       ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- SECTION 6: NULL-BRANCH UNIQUENESS FIX — number_series  (backlog C-1)
-- =============================================================================
-- Problem: PostgreSQL NULL != NULL in B-tree unique indexes. The existing
-- index uq_number_series_active on (company_id, branch_id, series_type)
-- WHERE is_active = true treats NULL branch_id as distinct for every row —
-- so two active company-wide series of the same type are not prevented.
--
-- Fix: Drop the composite index; replace with two split partial indexes:
--   • One for the company-wide case (branch_id IS NULL)
--   • One for the branch-specific case (branch_id IS NOT NULL)
-- Both add deleted_at IS NULL to exclude soft-deleted rows from uniqueness.
-- =============================================================================

DROP INDEX IF EXISTS public.uq_number_series_active;

-- Company-wide series: one active series per (company_id, series_type) when
-- no branch is assigned.
CREATE UNIQUE INDEX uq_number_series_active_no_branch
    ON public.number_series (company_id, series_type)
    WHERE branch_id IS NULL
      AND is_active = true
      AND deleted_at IS NULL;

-- Branch-scoped series: one active series per (company_id, branch_id, series_type)
-- when a branch is assigned.
CREATE UNIQUE INDEX uq_number_series_active_with_branch
    ON public.number_series (company_id, branch_id, series_type)
    WHERE branch_id IS NOT NULL
      AND is_active = true
      AND deleted_at IS NULL;

-- =============================================================================
-- SECTION 7: NULL-BRANCH UNIQUENESS FIX — system_account_config  (backlog C-2)
-- =============================================================================
-- Problem: The inline UNIQUE constraint uq_system_account_config_key_branch_from
-- includes branch_id in the key. When branch_id IS NULL (company-wide config),
-- PostgreSQL does not enforce the uniqueness — two company-wide configs for the
-- same (company_id, config_key, effective_from) can coexist.
--
-- Fix: Drop the original constraint; replace with two partial unique indexes.
-- =============================================================================

ALTER TABLE public.system_account_config
    DROP CONSTRAINT IF EXISTS uq_system_account_config_key_branch_from;

-- Company-wide config: one active config per (company_id, config_key,
-- effective_from) when no branch is specified.
CREATE UNIQUE INDEX uq_sac_key_from_no_branch
    ON public.system_account_config (company_id, config_key, effective_from)
    WHERE branch_id IS NULL
      AND deleted_at IS NULL;

-- Branch-specific config: one active config per
-- (company_id, config_key, branch_id, effective_from).
CREATE UNIQUE INDEX uq_sac_key_from_with_branch
    ON public.system_account_config (company_id, config_key, branch_id, effective_from)
    WHERE branch_id IS NOT NULL
      AND deleted_at IS NULL;

-- =============================================================================
-- SECTION 8: NULL-BRANCH UNIQUENESS FIX — user_roles  (backlog C-3)
-- =============================================================================
-- Problem: uq_user_roles_active on (user_id, role_id, company_id, branch_id)
-- WHERE is_active = true — the NULL branch_id path is not enforced, allowing
-- a user to hold the same company-level role twice while both rows are active.
--
-- Fix: Drop existing partial unique index; replace with two split indexes.
-- =============================================================================

DROP INDEX IF EXISTS public.uq_user_roles_active;

-- Company-level role (no branch scope): a user may hold a role within a company
-- only once while active.
CREATE UNIQUE INDEX uq_user_roles_active_no_branch
    ON public.user_roles (user_id, role_id, company_id)
    WHERE branch_id IS NULL
      AND is_active = true;

-- Branch-scoped role: a user may hold a role within a company+branch combo
-- only once while active.
CREATE UNIQUE INDEX uq_user_roles_active_with_branch
    ON public.user_roles (user_id, role_id, company_id, branch_id)
    WHERE branch_id IS NOT NULL
      AND is_active = true;

-- =============================================================================
-- SECTION 9: ROLE_CODE UNIQUENESS  (backlog C-4)
-- =============================================================================
-- Problem: No uniqueness constraint on role_code. Two roles with the same code
-- can coexist within the same scope (system or company), making role lookup
-- by code ambiguous.
--
-- Fix: Two partial unique indexes — one for system roles (company_id IS NULL),
-- one for company-scoped roles (company_id IS NOT NULL).
-- Note: roles uses deleted_at for soft delete (no deleted_by — immutable-adjacent).
-- =============================================================================

-- System roles are platform-wide; their code must be globally unique.
CREATE UNIQUE INDEX uq_roles_system_code
    ON public.roles (role_code)
    WHERE company_id IS NULL
      AND deleted_at IS NULL;

-- Company-scoped roles: code must be unique within the company.
CREATE UNIQUE INDEX uq_roles_company_code
    ON public.roles (company_id, role_code)
    WHERE company_id IS NOT NULL
      AND deleted_at IS NULL;

-- =============================================================================
-- SECTION 10: DEPARTMENT CODE UNIQUENESS  (backlog H-1)
-- =============================================================================
-- Problem: No UNIQUE constraint on (company_id, code) for departments.
-- Duplicate department codes allowed within a company, causing ambiguity in
-- cost allocation and reporting.
-- =============================================================================

CREATE UNIQUE INDEX uq_departments_company_code
    ON public.departments (company_id, code)
    WHERE deleted_at IS NULL;

-- =============================================================================
-- SECTION 11: COST CENTER CODE UNIQUENESS  (backlog H-2)
-- =============================================================================
-- Problem: No UNIQUE constraint on (company_id, code) for cost_centers.
-- Duplicate cost center codes break GL dimension reporting and journal line
-- cost center assignments.
-- =============================================================================

CREATE UNIQUE INDEX uq_cost_centers_company_code
    ON public.cost_centers (company_id, code)
    WHERE deleted_at IS NULL;

-- =============================================================================
-- SECTION 12: CAS REGISTRATION GUARDS  (backlog M-3)
-- =============================================================================
-- Problem 1: No CHECK preventing date_valid_to from being <= date_issued.
--            A CAS record with an expiry before its issue date is meaningless.
-- Problem 2: No unique constraint on cas_permit_no. Two registrations with the
--            same BIR-issued permit number can coexist, violating BIR audit
--            traceability.
--
-- Note: cas_registrations is immutable (no deleted_at, no updated_* columns).
-- The CHECK is added as a table constraint; the unique index has no soft-delete
-- filter because rows are never soft-deleted.
-- =============================================================================

ALTER TABLE public.cas_registrations
    ADD CONSTRAINT ck_cas_date_valid_to
        CHECK (date_valid_to IS NULL OR date_valid_to > date_issued);

CREATE UNIQUE INDEX uq_cas_registrations_permit_no
    ON public.cas_registrations (company_id, cas_permit_no);

-- =============================================================================
-- SECTION 13: ATP NUMBER UNIQUENESS  (backlog M-4)
-- =============================================================================
-- Problem: No unique constraint on atp_no within a company. Duplicate BIR
-- ATP permit numbers allowed — violates BIR ATP uniqueness requirement and
-- corrupts number series authorization tracking.
--
-- Note: number_series_atp is immutable (no deleted_at). Plain unique index.
-- =============================================================================

CREATE UNIQUE INDEX uq_number_series_atp_no
    ON public.number_series_atp (company_id, atp_no);

-- =============================================================================
-- SECTION 14: INVENTORY MOVEMENTS ENTITY_TYPE — PRE-POSTING BLOCKER
-- (backlog M-010-2 — ESCALATED to pre-posting blocker, resolved here)
-- =============================================================================
-- Problem: inventory_movements.entity_type CHECK was frozen per Doc03 column
-- spec and did NOT include 'customer_return' or 'purchase_return'. Both
-- document types from Migrations 007 (sales_returns / customer_returns) and
-- 008 (purchase_returns) generate inventory IN/OUT movements via the posting
-- engine. Without these values in the CHECK, every inventory movement from a
-- return document will fail the constraint at posting time.
--
-- Decision: Escalated from MEDIUM backlog to PRE-POSTING BLOCKER. Resolved in
-- this patch per architecture review. The two values are unambiguous: they map
-- directly to the customer_returns and purchase_returns tables in 007/008.
-- Doc03 omission treated as a documentation gap, not a design intent.
--
-- Method: DROP the existing named CHECK constraint; ADD it back with the two
-- additional entity_type values.
-- =============================================================================

ALTER TABLE public.inventory_movements
    DROP CONSTRAINT ck_im_entity_type;

ALTER TABLE public.inventory_movements
    ADD CONSTRAINT ck_im_entity_type
        CHECK (
            entity_type IN (
                'sales_invoice',
                'cash_sale',
                'vendor_bill',
                'cash_purchase',
                'stock_adjustment',
                'stock_transfer',
                'goods_issue',
                'physical_count_entry',
                'receiving_report',
                'customer_return',
                'purchase_return'
            )
        );

COMMENT ON COLUMN public.inventory_movements.entity_type IS
    'Source document type. Polymorphic reference — resolves to PK of the named '
    'table via entity_id. customer_return and purchase_return added in Migration 016 '
    '(pre-posting blocker, previously M-010-2 in backlog). Doc03 omission treated '
    'as documentation gap per architecture review.';

-- =============================================================================
-- END OF MIGRATION 016
-- =============================================================================
-- Tables with RLS enabled (net-new in this migration):
--   Migration 004 : 32 tables
--   Migration 006 : 1  table  (payment_term_lines)
--   Migration 013 : 9  tables
--   Migration 014 : 9  tables
--   Migration 015 : 24 tables
--   Total         : 75 tables
--   (Migration 012 tables already had RLS — not repeated here)
--
-- Indexes / constraints added:
--   number_series             : 2 new partial unique indexes (replaces 1 dropped)
--   system_account_config     : 2 new partial unique indexes (replaces 1 dropped)
--   user_roles                : 2 new partial unique indexes (replaces 1 dropped)
--   roles                     : 2 new partial unique indexes
--   departments               : 1 new partial unique index
--   cost_centers              : 1 new partial unique index
--   cas_registrations         : 1 new CHECK + 1 new unique index
--   number_series_atp         : 1 new unique index
--   inventory_movements       : 1 replaced CHECK constraint
--   Total new indexes/checks  : 13 (replacing 3 dropped)
--
-- Backlog items resolved: C-1, C-2, C-3, C-4, H-1, H-2, M-3, M-4,
--                         M-010-2, H-001 (all 42 tables + 33 from 004/006)
--
-- Backlog items NOT fixed (unchanged — deferred to 017 or FINAL REVIEW PASS):
--   All MEDIUM/LOW items not listed above
-- =============================================================================
