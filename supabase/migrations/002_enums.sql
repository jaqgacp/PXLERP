-- =============================================================================
-- PXL ERP — Migration 002: Enum Types
-- =============================================================================
-- Release        : v4.0-database-freeze
-- Architecture   : docs/architecture/ (frozen — DO NOT MODIFY)
-- PostgreSQL     : 16
-- Supabase       : Compatible
-- Idempotent     : Yes — DO $$ ... EXCEPTION WHEN duplicate_object THEN NULL END $$
-- Depends On     : 001_extensions.sql
-- Must Run Before: 003_shared_functions.sql and all table migrations
-- =============================================================================
--
-- OVERVIEW
-- --------
-- Defines all PostgreSQL named enum types used by PXL ERP Phase 1.
-- No tables, functions, triggers, or RLS policies are created here.
-- All types live in the `public` schema (Supabase default application schema).
-- All type names use the `pxl_` prefix to prevent namespace collisions.
--
-- IDEMPOTENCY NOTE
-- ----------------
-- PostgreSQL 16 does NOT support CREATE TYPE IF NOT EXISTS for enum types.
-- Idempotency is achieved via the DO block pattern:
--
--   DO $$
--   BEGIN
--       CREATE TYPE public.pxl_xxx AS ENUM (...);
--   EXCEPTION
--       WHEN duplicate_object THEN NULL;
--   END
--   $$;
--
-- This silently ignores duplicate_object (error code 42710) if the type
-- already exists. The COMMENT ON TYPE statement outside the DO block is
-- idempotent on its own (replaces existing comment).
--
-- SOURCE DOCUMENTS
-- ----------------
-- Canonical source: docs/architecture/03_TABLE_COLUMN_SPECIFICATIONS.md
-- Supporting refs : docs/architecture/06_POSTING_ENGINE_TABLE_DESIGN.md (§2)
--                   docs/architecture/07_AUDIT_AND_CAS_TABLE_DESIGN.md (§2, §4)
--
-- =============================================================================
-- DECISION: ENUM TYPES vs CHECK CONSTRAINTS
-- =============================================================================
--
-- RULE APPLIED
-- ─────────────
-- Use a PostgreSQL ENUM type when the value set is:
--   (a) Shared across 2 or more columns/tables, OR
--   (b) Semantically central to the ERP domain (tax classification, posting
--       engine, transaction lifecycle), OR
--   (c) Complex (5+ values) and benefits from catalogued documentation
--
-- Keep as inline CHECK constraint (in later table migrations) when:
--   (a) The value set is used by a single column on a single table only, OR
--   (b) The value set is a context-restricted SUBSET of a parent enum type
--       (the parent enum type is created here; the table column uses the enum
--       type AND adds a CHECK to restrict which values are valid in context), OR
--   (c) The constraint is on an integer range (e.g. quarter CHECK (1,2,3,4)), OR
--   (d) The value set is expected to grow significantly (see audit_logs below)
--
-- ITEMS INTENTIONALLY LEFT AS CHECK CONSTRAINTS (not in this file)
-- ─────────────────────────────────────────────────────────────────
--
--  Column                                  Table                     Reason
--  ──────────────────────────────────────  ────────────────────────  ──────────────────────────
--  quarter CHECK (1,2,3,4)                 fiscal_periods,           Integer range, not text
--                                          ewt/fwt/pt tables
--  withholding_agent_status                company_compliance_       Single table, simple binary
--                                          profiles
--  account_type (checking/savings/td)      company_bank_accounts     Single table
--  account_type (savings/checking/payroll) employee_bank_accounts    Single table, different set
--  invoice_type                            sales_invoices            Single table
--  receipt_type                            receipts                  Single table
--  payee_type (supplier/employee/other)    petty_cash_vouchers       Single table, different set
--                                                                    from ewt_entries.payee_type
--  payee_type (supplier/customer)          ewt_entries               Single table, different set
--  applied_to_type (SI/SDM/advance)        receipts                  Single table
--  applied_to_type (VB/SPDM/advance)       payment_vouchers          Single table
--  address_type (billing/shipping/both)    customer_addresses        Single table
--  address_type (billing/remittance/both)  supplier_addresses        Single table; 'remittance'
--                                                                    differs from 'shipping'
--  paper_size                              document_templates        Single table, print-only
--  orientation                             document_templates        Single table, print-only
--  status (open/filed)                     vat_period_summaries      Single table
--  ewt_fwt_flag (ewt/fwt)                  tax_withholding_          Single table, 2 values
--                                          certificates
--  form_type (2550M/2550Q)                 vat_period_returns        Subset of pxl_bir_form_code;
--                                                                    use CHECK on that column
--  export_type (sales/purchases)           slsp_exports              Single table, 2 values
--  filing_type (quarterly/annual)          income_tax_return_        Single table, 2 values
--                                          filings
--
--  audit_logs.event_type                   audit_logs                48+ UPPERCASE event codes;
--                                                                    the list WILL grow as Phase 2
--                                                                    features are added. Adding
--                                                                    values to a CHECK constraint
--                                                                    (ALTER TABLE DROP/ADD CONSTRAINT)
--                                                                    is simpler operationally than
--                                                                    ALTER TYPE ADD VALUE for a
--                                                                    ~50-value insert-only table.
--                                                                    App-layer (Edge Functions)
--                                                                    enforces valid event types.
--
-- UPPERCASE EXCEPTION ENUMS
-- ─────────────────────────
-- Doc03 §0 defines two UPPERCASE exceptions: system_account_config.config_key
-- and chart_of_accounts.control_account_type. Both are created as enum types
-- with UPPERCASE values because type safety on these posting engine keys is
-- critical. The frozen doc is the contract; values are reproduced exactly.
--
-- CASING ANOMALY — movement_type
-- ─────────────────────────────
-- Doc03 specifies inventory_movements.movement_type CHECK IN ('IN','OUT').
-- This is uppercase and technically violates the "all status values lowercase"
-- rule stated in Doc03 §0. However, the architecture is frozen and the column
-- spec is the contract. The enum `pxl_movement_type` therefore uses UPPERCASE
-- values ('IN','OUT') as specified.
-- Future Proposal (v4.1): normalize movement_type to lowercase ('in','out').
--
-- =============================================================================
-- ENUM COUNT: 77 types
-- =============================================================================

-- =============================================================================
-- GROUP 1 — ORGANIZATION, COMPANY & SYSTEM CONTROLS
-- =============================================================================

-- 1. Taxpayer type — company tax registration category
--    Used by: companies.tax_type, company_compliance_profiles.taxpayer_type
--    Doc03 §1
DO $$
BEGIN
    CREATE TYPE public.pxl_taxpayer_type AS ENUM (
        'vat',
        'non_vat'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_taxpayer_type IS
    'BIR taxpayer registration category. vat=VAT-registered (files 2550M/Q); non_vat=Non-VAT (files 2551Q). Doc03 §1';

-- 2. Income tax regime — determines ITR form type
--    Used by: company_compliance_profiles.income_tax_regime,
--             itr_computation_runs.regime_snapshot
--    Doc03 §1
DO $$
BEGIN
    CREATE TYPE public.pxl_income_tax_regime AS ENUM (
        'corporate',
        'individual',
        'partnership',
        'cooperative'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_income_tax_regime IS
    'Income tax filing regime. Determines ITR form (1702RT=corporate, 1701=individual, partnership=1702). Doc03 §1';

-- 3. Legal entity type — company registration form
--    Used by: company_compliance_profiles.legal_type
--    Doc03 §1
DO $$
BEGIN
    CREATE TYPE public.pxl_legal_type AS ENUM (
        'sole_proprietor',
        'regular_corporation',
        'opc',
        'partnership',
        'cooperative'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_legal_type IS
    'Legal entity type per SEC/DTI registration. Doc03 §1';

-- 4. Deduction method — income tax deduction approach
--    Used by: company_compliance_profiles.deduction_method,
--             itr_computation_runs.deduction_method_snapshot
--    Doc03 §1
DO $$
BEGIN
    CREATE TYPE public.pxl_deduction_method AS ENUM (
        'itemized',
        'osd',
        'eight_percent'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_deduction_method IS
    'Income tax deduction method. osd=Optional Standard Deduction (40% of gross). eight_percent only for individual taxpayers within gross receipt threshold. Doc03 §1';

-- 5. Fiscal period/year status — lifecycle of accounting periods
--    Used by: fiscal_years.status, fiscal_periods.status
--    Doc03 §3
DO $$
BEGIN
    CREATE TYPE public.pxl_fiscal_status AS ENUM (
        'open',
        'closed',
        'locked'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_fiscal_status IS
    'Fiscal year/period lifecycle. open=posting allowed; closed=all periods closed; locked=year-end journal posted, no further posting. Doc03 §3';

-- 6. Approval workflow type — how approvers are evaluated
--    Used by: approval_matrix.approval_type
--    Doc03 §2
DO $$
BEGIN
    CREATE TYPE public.pxl_approval_type AS ENUM (
        'sequential',
        'parallel',
        'any_one'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_approval_type IS
    'Approval matrix evaluation mode. sequential=each step must complete; parallel=all simultaneously; any_one=first approval suffices. Doc03 §2';

-- 7. Budget lifecycle status
--    Used by: budgets.status
--    Doc03 §3
DO $$
BEGIN
    CREATE TYPE public.pxl_budget_status AS ENUM (
        'draft',
        'approved',
        'active',
        'superseded'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_budget_status IS
    'Budget version lifecycle. superseded=replaced by a newer version for same fiscal year. Doc03 §3';

-- =============================================================================
-- GROUP 2 — CHART OF ACCOUNTS
-- =============================================================================

-- 8. Account type code — fundamental accounting classification
--    Used by: account_types.code
--    Doc03 §3
DO $$
BEGIN
    CREATE TYPE public.pxl_account_type_code AS ENUM (
        'asset',
        'liability',
        'equity',
        'revenue',
        'cost_of_sales',
        'expense',
        'other_income',
        'other_expense',
        'contra_asset',
        'contra_liability',
        'contra_equity',
        'contra_revenue',
        'contra_expense'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_account_type_code IS
    'Fundamental account classification per PFRS for SMEs. cost_of_sales is separate from expense for P&L sub-sections. Contra variants for allowances, accumulated depreciation, returns. Doc03 §3';

-- 9. Normal balance side — which side increases the account
--    Used by: account_types.normal_balance, chart_of_accounts.normal_balance
--    Doc03 §3
DO $$
BEGIN
    CREATE TYPE public.pxl_normal_balance AS ENUM (
        'debit',
        'credit'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_normal_balance IS
    'Normal balance direction. debit=asset/expense increases on debit side; credit=liability/equity/revenue increases on credit side. Doc03 §3';

-- 10. Financial statement section — which FS section an account maps to
--     Used by: chart_of_accounts.fs_section
--     Doc03 §3
DO $$
BEGIN
    CREATE TYPE public.pxl_fs_section AS ENUM (
        'current_assets',
        'non_current_assets',
        'current_liabilities',
        'non_current_liabilities',
        'equity',
        'revenue',
        'cost_of_sales',
        'operating_expenses',
        'other_income',
        'other_expenses'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_fs_section IS
    'FS statement section for COA-embedded financial statement generation (Phase 1 approach). Drives Balance Sheet, P&L, SOCE grouping. Doc03 §3';

-- 11. Financial statement category — which statement the account appears on
--     Used by: account_types.fs_category
--     Doc03 §3
DO $$
BEGIN
    CREATE TYPE public.pxl_fs_category AS ENUM (
        'balance_sheet',
        'income_statement',
        'cost_of_sales_section',
        'other_income_expense_section'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_fs_category IS
    'Top-level FS statement grouping for account types. Drives which financial statement section receives the account type total. Doc03 §3';

-- 12. Cash flow category — indirect method cash flow classification
--     Used by: chart_of_accounts.cash_flow_category
--     Doc03 §3
DO $$
BEGIN
    CREATE TYPE public.pxl_cash_flow_category AS ENUM (
        'operating',
        'investing',
        'financing'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_cash_flow_category IS
    'Cash flow statement classification for balance sheet movement accounts. NULL on COA = account not directly classified in cash flow statement. Doc03 §3';

-- 13. Tax deductibility — income tax itemized deduction classification
--     Used by: chart_of_accounts.tax_deductibility
--     Doc03 §3
DO $$
BEGIN
    CREATE TYPE public.pxl_tax_deductibility AS ENUM (
        'fully_deductible',
        'partially_deductible',
        'non_deductible',
        'not_applicable'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_tax_deductibility IS
    'Income tax deductibility status for expense accounts under itemized deduction method. Drives book-to-tax reconciliation. Doc03 §3';

-- 14. Control account type — UPPERCASE system identifier (exception per Doc03 §0)
--     Used by: chart_of_accounts.control_account_type
--     Doc03 §3 — intentionally UPPERCASE per architecture specification
DO $$
BEGIN
    CREATE TYPE public.pxl_control_account_type AS ENUM (
        'AR_CONTROL',
        'AP_CONTROL',
        'INVENTORY_CONTROL',
        'OUTPUT_VAT_CONTROL',
        'INPUT_VAT_CONTROL',
        'EWT_PAYABLE_CONTROL',
        'PT_PAYABLE_CONTROL',
        'FWT_PAYABLE_CONTROL',
        'INCOME_TAX_PAYABLE_CONTROL'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_control_account_type IS
    'UPPERCASE exception (Doc03 §0): system technical identifiers mapping COA accounts to system_account_config keys. Prevents direct JE posting to control accounts at app layer. Doc03 §3';

-- 15. System account config key — UPPERCASE posting engine constants (exception per Doc03 §0)
--     Used by: system_account_config.config_key, posting_rule_lines.account_config_key
--     Doc03 §29 — 17 canonical keys — intentionally UPPERCASE per architecture specification
DO $$
BEGIN
    CREATE TYPE public.pxl_system_account_key AS ENUM (
        'CASH_ON_HAND',
        'CASH_IN_BANK',
        'AR_TRADE',
        'AP_TRADE',
        'INPUT_VAT',
        'OUTPUT_VAT',
        'INPUT_VAT_CAPITAL_GOODS',
        'INPUT_VAT_DEFERRED',
        'OUTPUT_VAT_NON_VAT',
        'EWT_PAYABLE',
        'FWT_PAYABLE',
        'PERCENTAGE_TAX_PAYABLE',
        'INCOME_TAX_PAYABLE',
        'INVENTORY_CONTROL',
        'COST_OF_GOODS_SOLD',
        'RETAINED_EARNINGS',
        'INCOME_SUMMARY'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_system_account_key IS
    'UPPERCASE exception (Doc03 §0): 17 canonical system account config keys used by the posting engine to resolve semantic accounts at post time. Doc03 §29, Doc06 §2';

-- =============================================================================
-- GROUP 3 — PARTY & MASTER DATA
-- =============================================================================

-- 16. Party entity type — legal form of the customer or supplier
--     Used by: customers.customer_type, suppliers.supplier_type
--     Doc03 §4
DO $$
BEGIN
    CREATE TYPE public.pxl_party_entity_type AS ENUM (
        'individual',
        'business',
        'government'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_party_entity_type IS
    'Legal form of the party. government here is the entity''s legal form (e.g. LGU, GOCCs), distinct from party_special_class which drives VAT routing. Doc03 §4';

-- 17. VAT registration status — is the party VAT-registered with BIR?
--     Used by: customers.vat_registration_status, suppliers.vat_registration_status
--     Doc03 §4
DO $$
BEGIN
    CREATE TYPE public.pxl_vat_registration_status AS ENUM (
        'vat',
        'non_vat'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_vat_registration_status IS
    'BIR VAT registration status of the counterparty. Drives input VAT credibility and SLSP/RELIEF inclusion. Doc03 §4';

-- 18. Party special class — BIR-significant special entity classification
--     Used by: customers.party_special_class, suppliers.party_special_class
--     Doc03 §4
DO $$
BEGIN
    CREATE TYPE public.pxl_party_special_class AS ENUM (
        'government',
        'peza',
        'boi',
        'foreign_entity'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_party_special_class IS
    'Special entity classification for compliance routing. government=posting engine sets vat_entries.vat_classification=''government'' for 2550M sales-to-government disclosure. peza/foreign_entity=zero-rated review. Doc03 §4';

-- 19. Item type — inventory and service item classification
--     Used by: items.item_type
--     Doc03 §5
DO $$
BEGIN
    CREATE TYPE public.pxl_item_type AS ENUM (
        'inventory',
        'non_inventory',
        'service',
        'fixed_asset'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_item_type IS
    'Item classification. inventory=tracked in inventory_balances; service=no inventory movement; fixed_asset=goes to asset register. Doc03 §5';

-- =============================================================================
-- GROUP 4 — TRANSACTIONS
-- =============================================================================

-- 20. Transaction type — canonical list of all 23 ERP document types
--     Used by: posting_rule_sets.transaction_type,
--              journal_entries.source_document_type,
--              approval_matrix.document_type,
--              document_relationships.source_document_type
--     Doc06 §2 (canonical 23-type list)
DO $$
BEGIN
    CREATE TYPE public.pxl_transaction_type AS ENUM (
        'sales_invoice',
        'vendor_bill',
        'receipt',
        'payment_voucher',
        'cash_sale',
        'cash_purchase',
        'petty_cash_voucher',
        'petty_cash_replenishment',
        'stock_adjustment',
        'stock_transfer',
        'customer_return',
        'purchase_return',
        'sales_credit_memo',
        'vendor_credit',
        'sales_debit_memo',
        'supplier_debit_memo',
        'asset_acquisition',
        'asset_depreciation',
        'asset_disposal',
        'bank_fund_transfer',
        'bank_adjustment',
        'inter_branch_transfer',
        'journal_entry'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_transaction_type IS
    'Canonical 23 ERP transaction/document types. Every posting_rule_set must reference exactly one of these. Doc06 §2';

-- 21. Transaction status — document lifecycle state machine
--     Used by: ALL transaction header tables (sales_invoices, vendor_bills,
--              receipts, payment_vouchers, cash_sales, cash_purchases, etc.)
--     Doc03 Standard Transaction Header Columns
DO $$
BEGIN
    CREATE TYPE public.pxl_transaction_status AS ENUM (
        'draft',
        'submitted',
        'approved',
        'posted',
        'voided',
        'reversed',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_transaction_status IS
    'Document lifecycle state machine shared by all transaction header tables. Posting blocked unless status=''approved''. Voided/reversed are terminal states. Doc03 Standard Transaction Header Columns';

-- 22. Payment method — how cash/funds move
--     Used by: receipts.payment_method, payment_vouchers.payment_method,
--              cash_sales.payment_method, cash_purchases.payment_method
--     Doc03 §6, §7
DO $$
BEGIN
    CREATE TYPE public.pxl_payment_method AS ENUM (
        'cash',
        'check',
        'bank_transfer',
        'online'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_payment_method IS
    'Payment settlement method. Used on receipts, payment vouchers, cash sales, and cash purchases. Doc03 §6, §7';

-- 23. VAT direction — which side of the VAT account is affected
--     Used by: sales_invoice_lines.vat_direction, cash_sale_lines.vat_direction,
--              vendor_bill_lines.vat_direction, cash_purchase_lines.vat_direction,
--              vat_entries.vat_direction
--     Doc03 §6, §7
DO $$
BEGIN
    CREATE TYPE public.pxl_vat_direction AS ENUM (
        'output',
        'input'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_vat_direction IS
    'VAT directional classification. output=sales-side VAT (OUTPUT_VAT); input=purchase-side VAT (INPUT_VAT). Immutable on a given transaction line. Doc03 §6, §7';

-- 24. VAT classification — the full superset of valid tax treatment codes
--     Used by: sales_invoice_lines.vat_classification (subset: vatable/zero_rated/exempt),
--              vendor_bill_lines.vat_classification (subset: adds capital_goods/services),
--              cash_sale_lines.vat_classification (subset: vatable/zero_rated/exempt),
--              cash_purchase_lines.vat_classification (subset: adds capital_goods/services),
--              vat_entries.vat_classification (subset: adds government, excludes capital_goods/services)
--     IMPORTANT: Each table column restricts to its valid subset via an additional CHECK
--     constraint applied in the table migration. This type covers all 6 possible values.
--     'government' is NEVER stored on transaction lines — it is DERIVED at posting from
--     customers.party_special_class and written only to vat_entries. Doc03 §0, Doc01.
--     Doc03 §6, §7, §10
DO $$
BEGIN
    CREATE TYPE public.pxl_vat_classification AS ENUM (
        'vatable',
        'zero_rated',
        'exempt',
        'government',
        'capital_goods',
        'services'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_vat_classification IS
    'Full superset of VAT classification values (6). Individual table columns restrict via CHECK to their valid subset. ''government'' is derived at posting from party_special_class — never stored on transaction lines. Doc03 §6, §7, §10';

-- =============================================================================
-- GROUP 5 — JOURNAL ENTRIES
-- =============================================================================

-- 25. Journal entry type — categorizes the JE origin and purpose
--     Used by: journal_entries.je_type
--     Doc03 §8
DO $$
BEGIN
    CREATE TYPE public.pxl_je_type AS ENUM (
        'manual',
        'system',
        'reversal',
        'opening',
        'recurring',
        'adjustment',
        'amortization',
        'revenue_recognition',
        'auto_reversal',
        'closing'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_je_type IS
    'Journal entry type. ''system'' is the idempotency guard for posting-engine-generated JEs. ''closing'' for year-end Income Summary → Retained Earnings sequence. Doc03 §8';

-- 26. Journal entry status — posting lifecycle
--     Used by: journal_entries.status
--     Doc03 §8
DO $$
BEGIN
    CREATE TYPE public.pxl_je_status AS ENUM (
        'draft',
        'posted',
        'reversed'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_je_status IS
    'Journal entry lifecycle. draft=not yet in GL; posted=GL impact applied; reversed=counter-JE posted. Doc03 §8';

-- 27. Recurring journal frequency
--     Used by: recurring_journal_templates.frequency,
--              amortization_schedules.frequency,
--              revenue_recognition_schedules.frequency
--     Doc03 §8, §33, §35
DO $$
BEGIN
    CREATE TYPE public.pxl_recurring_frequency AS ENUM (
        'monthly',
        'quarterly',
        'annually'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_recurring_frequency IS
    'Recurrence interval for recurring JE templates, amortization schedules, and revenue recognition schedules. Doc03 §8, §33, §35';

-- 28. Recurring journal template status
--     Used by: recurring_journal_templates.status
--     Doc03 §8
DO $$
BEGIN
    CREATE TYPE public.pxl_recurring_status AS ENUM (
        'active',
        'paused',
        'completed',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_recurring_status IS
    'Recurring journal template lifecycle. completed=all periods generated; paused=temporarily suspended. Doc03 §8';

-- =============================================================================
-- GROUP 6 — POSTING ENGINE
-- =============================================================================

-- 29. Entry side — debit or credit for a posting rule line
--     Used by: posting_rule_lines.entry_side
--     Doc03 §9, Doc06 §2
--     Note: same values as pxl_normal_balance but separate type for semantic clarity.
--     entry_side describes which SIDE of the JE to write; normal_balance describes
--     which side INCREASES an account. These are distinct concepts.
DO $$
BEGIN
    CREATE TYPE public.pxl_entry_side AS ENUM (
        'debit',
        'credit'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_entry_side IS
    'Which side of the journal entry a posting rule line writes to. Distinct from pxl_normal_balance (account property) — this is a rule property. Doc03 §9, Doc06 §2';

-- 30. Account source — how the posting engine resolves the GL account for a line
--     Used by: posting_rule_lines.account_source
--     Doc03 §9, Doc06 §2
DO $$
BEGIN
    CREATE TYPE public.pxl_account_source AS ENUM (
        'fixed',
        'from_system_config',
        'from_item',
        'from_customer',
        'from_supplier',
        'from_line'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_account_source IS
    'How the posting engine resolves the GL account for a rule line. fixed=literal account_id; from_system_config=looks up system_account_config by config_key; from_item/customer/supplier=reads account from master record; from_line=from transaction line override. Doc03 §9';

-- 31. Amount source — how the posting engine computes the line amount
--     Used by: posting_rule_lines.amount_source
--     Doc03 §9, Doc06 §2
DO $$
BEGIN
    CREATE TYPE public.pxl_amount_source AS ENUM (
        'line_subtotal',
        'line_vat',
        'line_ewt',
        'header_total',
        'computed'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_amount_source IS
    'How the posting engine computes the monetary amount for a rule line. computed uses amount_formula (SQL expression). Doc03 §9, Doc06 §2';

-- 32. Applies to — which subset of document lines this rule line applies to
--     Used by: posting_rule_lines.applies_to
--     Doc03 §9, Doc06 §2
DO $$
BEGIN
    CREATE TYPE public.pxl_applies_to AS ENUM (
        'all',
        'vat_lines_only',
        'ewt_lines_only',
        'zero_vat_lines',
        'capital_goods_lines_only',
        'pt_lines_only'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_applies_to IS
    'Restricts which document lines trigger this posting rule line. pt_lines_only for percentage tax entries on non-VAT companies. Doc03 §9, Doc06 §2';

-- 33. Subsidiary ledger type — which subledger receives the entry
--     Used by: posting_rule_lines.subsidiary_ledger_type,
--              subsidiary_ledger_entries.ledger_type,
--              document_relationships (ledger context)
--     Doc03 §9, §32
DO $$
BEGIN
    CREATE TYPE public.pxl_subsidiary_ledger_type AS ENUM (
        'ar',
        'ap',
        'inventory',
        'fixed_asset'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_subsidiary_ledger_type IS
    'Which subsidiary ledger receives the posting rule line entry. Determines which subledger balance record is updated at post time. Doc03 §9, §32';

-- 34. Posting batch status — async posting run lifecycle
--     Used by: posting_batches.status
--     Doc03 §9
DO $$
BEGIN
    CREATE TYPE public.pxl_posting_batch_status AS ENUM (
        'pending',
        'processing',
        'completed',
        'partial_fail',
        'failed'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_posting_batch_status IS
    'Async posting batch run lifecycle. partial_fail=some documents failed within the batch; failed=entire batch failed. Doc03 §9';

-- =============================================================================
-- GROUP 7 — NUMBER SERIES & ATP
-- =============================================================================

-- 35. Series type — BIR-reportable document series classification
--     Used by: number_series.series_type
--     Doc03 §25 — 18 values (subset overlap with pxl_transaction_type but distinct:
--     includes delivery_receipt/purchase_order/receiving_report; excludes
--     petty_cash_replenishment/customer_return/purchase_return/vendor_credit/
--     asset_depreciation/bank_fund_transfer/bank_adjustment/inter_branch_transfer)
DO $$
BEGIN
    CREATE TYPE public.pxl_series_type AS ENUM (
        'sales_invoice',
        'cash_sale',
        'receipt',
        'vendor_bill',
        'cash_purchase',
        'payment_voucher',
        'journal_entry',
        'delivery_receipt',
        'purchase_order',
        'receiving_report',
        'petty_cash_voucher',
        'stock_adjustment',
        'stock_transfer',
        'asset_acquisition',
        'asset_disposal',
        'sales_credit_memo',
        'sales_debit_memo',
        'supplier_debit_memo'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_series_type IS
    '18 BIR-reportable document types that require number series management and ATP tracking. Distinct from pxl_transaction_type (23 types): includes delivery docs; excludes internal movement types. Doc03 §25';

-- 36. Reset frequency — how often number series resets to 1
--     Used by: number_series.reset_frequency
--     Doc03 §25
DO $$
BEGIN
    CREATE TYPE public.pxl_reset_frequency AS ENUM (
        'never',
        'monthly',
        'annually'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_reset_frequency IS
    'Number series reset schedule. never=sequential forever; monthly/annually=resets next_sequence to min_value on schedule. Doc03 §25';

-- =============================================================================
-- GROUP 8 — AUDIT, CAS & ACTIVITY LOGGING
-- =============================================================================

-- 37. Change type — type of DML operation in field change history
--     Used by: field_change_history.change_type
--     Doc03 §41, Doc07 §3
DO $$
BEGIN
    CREATE TYPE public.pxl_change_type AS ENUM (
        'insert',
        'update',
        'delete'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_change_type IS
    'DML operation type recorded in field_change_history. Lowercase per Doc03 §0 casing rule. Doc03 §41, Doc07 §3';

-- 38. Activity type — user session and sensitive action event codes
--     Used by: user_activity_logs.activity_type
--     Doc03 §41, Doc07 §4
--     NOTE: audit_logs.event_type is intentionally NOT an enum — see decision section above.
DO $$
BEGIN
    CREATE TYPE public.pxl_activity_type AS ENUM (
        'login_success',
        'login_failed',
        'logout',
        'session_expired',
        'company_switched',
        'branch_switched',
        'report_viewed',
        'report_exported',
        'document_printed',
        'data_exported',
        'compliance_report_exported',
        'dat_file_downloaded',
        'settings_changed',
        'password_changed',
        'mfa_enabled',
        'mfa_disabled'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_activity_type IS
    '16 canonical user session activity codes for user_activity_logs. Lowercase per Doc03 §0. Doc03 §41, Doc07 §4';

-- 39. DAT file type — CAS DAT export file classification
--     Used by: dat_file_exports.dat_type
--     Doc03 §41, Doc07
DO $$
BEGIN
    CREATE TYPE public.pxl_dat_type AS ENUM (
        'journal',
        'sales',
        'purchases',
        'inventory'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_dat_type IS
    'BIR CAS DAT file classification. One DAT file per type per filing period. Doc03 §41, Doc07';

-- 40. Alert type — system alert category
--     Used by: system_alerts.alert_type
--     Doc03 §41
DO $$
BEGIN
    CREATE TYPE public.pxl_alert_type AS ENUM (
        'atp_nearing_limit',
        'number_gap_detected',
        'period_close_overdue',
        'compliance_deadline',
        'low_stock'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_alert_type IS
    'System alert category. number_gap_detected is raised by the nightly pg_cron ATP gap detection job. Doc03 §41';

-- 41. Alert severity — urgency level of a system alert
--     Used by: system_alerts.severity
--     Doc03 §41
DO $$
BEGIN
    CREATE TYPE public.pxl_alert_severity AS ENUM (
        'info',
        'warning',
        'critical'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_alert_severity IS
    'System alert urgency. critical=immediate action required (e.g. ATP exhausted); warning=action needed soon; info=informational. Doc03 §41';

-- =============================================================================
-- GROUP 9 — APPROVAL WORKFLOW & NOTIFICATIONS
-- =============================================================================

-- 42. Approval request status — document approval lifecycle
--     Used by: approval_requests.status
--     Doc03 §40
DO $$
BEGIN
    CREATE TYPE public.pxl_approval_request_status AS ENUM (
        'pending',
        'approved',
        'rejected',
        'returned',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_approval_request_status IS
    'Approval request lifecycle. returned=sent back to originator for correction (not rejected). cancelled=document itself was cancelled. Doc03 §40';

-- 43. Approval action — what an approver did
--     Used by: approval_actions.action
--     Doc03 §40
DO $$
BEGIN
    CREATE TYPE public.pxl_approval_action AS ENUM (
        'approve',
        'reject',
        'return',
        'escalate'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_approval_action IS
    'Action taken by an approver on an approval request. return=returned to originator for correction; escalate=forwarded up hierarchy. Doc03 §40';

-- 44. Notification channel — delivery medium
--     Used by: notifications.channel (all 3),
--              notification_templates.channel (in_app/email only — restricted via CHECK)
--     Doc03 §14, §15
DO $$
BEGIN
    CREATE TYPE public.pxl_notification_channel AS ENUM (
        'in_app',
        'email',
        'sms'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_notification_channel IS
    'Notification delivery channel. notification_templates uses only (in_app, email) — restricted via CHECK. notifications uses all 3. Doc03 §14, §15';

-- 45. Notification delivery status
--     Used by: notifications.status
--     Doc03 §14
DO $$
BEGIN
    CREATE TYPE public.pxl_notification_status AS ENUM (
        'pending',
        'sent',
        'failed',
        'delivered'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_notification_status IS
    'Notification delivery pipeline status. delivered=confirmed read/received at channel; sent=dispatched but delivery unconfirmed. Doc03 §14';

-- 46. Permission action — RBAC action code
--     Used by: permissions.action
--     Doc03 §39, Doc09
DO $$
BEGIN
    CREATE TYPE public.pxl_permission_action AS ENUM (
        'view',
        'create',
        'edit',
        'delete',
        'approve',
        'post',
        'void',
        'export',
        'admin'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_permission_action IS
    '9 RBAC action codes. Combined with module.resource prefix to form permission_code (e.g. ar.invoices.post). Hard DELETE is REVOKE''d on all app roles — ''delete'' here means soft delete. Doc03 §39, Doc09';

-- =============================================================================
-- GROUP 10 — PERIOD CLOSE
-- =============================================================================

-- 47. Period close process status — fiscal period close checklist lifecycle
--     Used by: period_close_checklists.status
--     Doc03 §17
DO $$
BEGIN
    CREATE TYPE public.pxl_period_close_status AS ENUM (
        'in_progress',
        'pending_lock',
        'locked'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_period_close_status IS
    'Period close checklist lifecycle. pending_lock=all tasks complete, awaiting lock confirmation; locked=fiscal period locked. Doc03 §17';

-- 48. Period close task status — individual checklist task completion
--     Used by: period_close_tasks.status
--     Doc03 §17
DO $$
BEGIN
    CREATE TYPE public.pxl_close_task_status AS ENUM (
        'pending',
        'in_progress',
        'completed',
        'waived'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_close_task_status IS
    'Individual period close task status. waived=intentionally skipped with documented reason. Doc03 §17';

-- =============================================================================
-- GROUP 11 — IMPORT & EXPORT
-- =============================================================================

-- 49. Import batch status — bulk import run lifecycle
--     Used by: import_batches.status
--     Doc03 §15, Doc08
DO $$
BEGIN
    CREATE TYPE public.pxl_import_batch_status AS ENUM (
        'pending',
        'validating',
        'validated',
        'importing',
        'completed',
        'failed',
        'rolled_back'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_import_batch_status IS
    'Import batch two-pass lifecycle. validated=first pass done, no errors; importing=second pass in progress; rolled_back=soft delete applied to all imported records. Doc03 §15, Doc08';

-- 50. Import row status — individual import record status
--     Used by: import_rows.status
--     Doc03 §15, Doc08
DO $$
BEGIN
    CREATE TYPE public.pxl_import_row_status AS ENUM (
        'pending',
        'valid',
        'invalid',
        'imported',
        'skipped',
        'rolled_back'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_import_row_status IS
    'Per-row status in an import batch. invalid=failed validation; skipped=duplicate or excluded row. Doc03 §15, Doc08';

-- 51. Import file format — accepted upload file types
--     Used by: import_batches.file_format
--     Doc03 §15, Doc08
DO $$
BEGIN
    CREATE TYPE public.pxl_import_file_format AS ENUM (
        'csv',
        'xlsx',
        'json'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_import_file_format IS
    'File format accepted by the two-pass import engine. Doc03 §15, Doc08';

-- 52. Export/report file format — generated output file types
--     Used by: export_jobs.format, generated_report_files.format,
--              generated_documents.format (superset)
--     Doc03 §16, §44, Doc08
DO $$
BEGIN
    CREATE TYPE public.pxl_export_format AS ENUM (
        'pdf',
        'xlsx',
        'csv',
        'dat',
        'json'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_export_format IS
    'Output file format for export jobs and generated documents. dat=BIR CAS DAT file format for CAS accreditation compliance. Doc03 §16, §44, Doc08';

-- 53. Export job status — async export run lifecycle
--     Used by: export_jobs.status
--     Doc03 §44, Doc08
DO $$
BEGIN
    CREATE TYPE public.pxl_export_status AS ENUM (
        'queued',
        'processing',
        'completed',
        'failed'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_export_status IS
    'Async export job lifecycle. queued=waiting for Edge Function to pick up; completed=file available in Supabase Storage. Doc03 §44, Doc08';

-- 54. Validation severity — import validation error severity
--     Used by: import_validation_errors.severity
--     Doc03 §15, Doc08
DO $$
BEGIN
    CREATE TYPE public.pxl_validation_severity AS ENUM (
        'error',
        'warning'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_validation_severity IS
    'Import validation issue severity. error=blocks import; warning=flagged but does not block. Doc03 §15, Doc08';

-- =============================================================================
-- GROUP 12 — BIR COMPLIANCE FILING
-- =============================================================================

-- 55. Filing status — BIR form filing lifecycle
--     Used by: vat_period_returns.filing_status,
--              ewt_remittances_1601eq.filing_status,
--              fwt_remittances_1601fq.filing_status,
--              income_tax_return_filings.filing_status (and other filing tables)
--     Doc03 §11, §12, §13
DO $$
BEGIN
    CREATE TYPE public.pxl_filing_status AS ENUM (
        'draft',
        'filed',
        'amended'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_filing_status IS
    'BIR form filing lifecycle. amended=filed but subsequently superseded by an amendment. Doc03 §11, §12, §13';

-- 56. BIR form code — all BIR forms PXL ERP handles in Phase 1
--     Used by: bir_form_configurations.form_code
--     Doc03 §27
DO $$
BEGIN
    CREATE TYPE public.pxl_bir_form_code AS ENUM (
        '2550M',
        '2550Q',
        '2551Q',
        '1601EQ',
        '1601FQ',
        '1604E',
        '1701Q',
        '1701',
        '1702Q',
        '1702RT'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_bir_form_code IS
    '10 BIR forms handled in Phase 1. 2550M/Q=VAT monthly/quarterly; 2551Q=percentage tax; 1601EQ=EWT quarterly; 1601FQ=FWT quarterly; 1604E=annual EWT (Phase 2 filing); 1701x=individual ITR; 1702x=corporate ITR. Doc03 §27';

-- 57. Filing frequency — how often a BIR form is filed
--     Used by: bir_form_configurations.filing_frequency
--     Doc03 §27
--     NOTE: 'annual' (not 'annually') per Doc03 §27 specification.
--     This is distinct from pxl_recurring_frequency which uses 'annually'.
DO $$
BEGIN
    CREATE TYPE public.pxl_filing_frequency AS ENUM (
        'monthly',
        'quarterly',
        'annual'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_filing_frequency IS
    'BIR form filing frequency. Uses ''annual'' (not ''annually'') per Doc03 §27 — distinct from pxl_recurring_frequency (which uses ''annually''). Doc03 §27';

-- 58. Tax account type — which tax regime an EWT/FWT entry belongs to
--     Used by: tax_withholding_entries context, atc_codes.tax_type
--     Doc03 §12
DO $$
BEGIN
    CREATE TYPE public.pxl_tax_account_type AS ENUM (
        'vat',
        'ewt',
        'fwt',
        'percentage_tax'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_tax_account_type IS
    'Tax regime classification for withholding tax and related entries. fwt=Final Withholding Tax (1601FQ/1604F); ewt=Creditable Withholding Tax (1601EQ/2307). Doc03 §12';

-- 59. Credit type — what constitutes a creditable tax offset against income tax
--     Used by: tax_credits_schedules.credit_type
--     Doc03 §13
DO $$
BEGIN
    CREATE TYPE public.pxl_credit_type AS ENUM (
        'ewt_2307',
        'prior_quarter_overpayment',
        'soa_payment'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_credit_type IS
    'Income tax credit type. ewt_2307=creditable withholding tax per 2307 received; fwt_2306 intentionally EXCLUDED per Doc03 §13 (FWT is final, not creditable against ITR). Doc03 §13';

-- 60. Book-to-tax reconciliation item type
--     Used by: book_tax_reconciliations.reconciliation_type (detail lines)
--     Doc03 §13
DO $$
BEGIN
    CREATE TYPE public.pxl_book_tax_reconciliation_type AS ENUM (
        'add_back',
        'deduction',
        'permanent',
        'temporary'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_book_tax_reconciliation_type IS
    'Classification of book-to-tax reconciliation adjustments. permanent=no reversal; temporary=reverses in future period (timing difference). Doc03 §13';

-- =============================================================================
-- GROUP 13 — INVENTORY
-- =============================================================================

-- 61. Inventory adjustment type — reason for stock count variance
--     Used by: stock_adjustments.adjustment_type (or stock_adjustment_lines)
--     Doc03 §20
DO $$
BEGIN
    CREATE TYPE public.pxl_inventory_adjustment_type AS ENUM (
        'write_off',
        'count_adjustment',
        'damage',
        'expiry',
        'other'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_inventory_adjustment_type IS
    'Reason for inventory adjustment entry. Each type maps to a different GL account treatment per posting rules. Doc03 §20';

-- 62. Inventory movement type — stock movement direction
--     Used by: inventory_movements.movement_type
--     Doc03 §20
--     CASING NOTE: Doc03 specifies ('IN','OUT') in UPPERCASE, which is an anomaly
--     relative to the lowercase rule in Doc03 §0. The frozen architecture is the
--     contract; values are reproduced exactly as specified.
--     Future Proposal (v4.1): normalize to lowercase ('in','out').
DO $$
BEGIN
    CREATE TYPE public.pxl_movement_type AS ENUM (
        'IN',
        'OUT'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_movement_type IS
    'Stock movement direction. UPPERCASE per Doc03 §20 frozen specification (anomaly vs lowercase rule — Future Proposal v4.1: normalize to lowercase). IN=stock received; OUT=stock issued/consumed. Doc03 §20';

-- =============================================================================
-- GROUP 14 — FIXED ASSETS
-- =============================================================================

-- 63. Depreciation method — how asset cost is expensed over useful life
--     Used by: asset_depreciation_schedules.method
--     Doc03 §24
DO $$
BEGIN
    CREATE TYPE public.pxl_depreciation_method AS ENUM (
        'straight_line',
        'declining_balance',
        'sum_of_years_digits',
        'units_of_production'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_depreciation_method IS
    'Asset depreciation computation method. Phase 1 CPA sign-off covers all 4 methods (Doc10 §53.8). sum_of_years_digits and units_of_production are less common but included per frozen spec. Doc03 §24';

-- 64. Asset disposal type — how the asset was removed from the register
--     Used by: asset_disposals.disposal_type
--     Doc03 §24
DO $$
BEGIN
    CREATE TYPE public.pxl_disposal_type AS ENUM (
        'sale',
        'write_off',
        'trade_in'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_disposal_type IS
    'Asset disposal basis. Each type has different GL treatment: sale=gain/loss on proceeds; write_off=full book value to loss; trade_in=offset against new asset acquisition. Doc03 §24';

-- 65. Depreciation run status — scheduled batch depreciation lifecycle
--     Used by: depreciation_runs.status (or asset_depreciation_runs)
--     Doc03 §24
DO $$
BEGIN
    CREATE TYPE public.pxl_depreciation_run_status AS ENUM (
        'pending',
        'processing',
        'completed',
        'failed'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_depreciation_run_status IS
    'Monthly depreciation batch run lifecycle. Triggered by pg_cron depreciation_runner job. Doc03 §24, Doc06 §14';

-- 66. Depreciation schedule entry status — per-entry status within a run
--     Used by: asset_depreciation_schedules.status (individual period entries)
--     Doc03 §24
DO $$
BEGIN
    CREATE TYPE public.pxl_depreciation_entry_status AS ENUM (
        'pending',
        'processed',
        'skipped',
        'error'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_depreciation_entry_status IS
    'Status of an individual depreciation schedule entry. skipped=period closed before run; error=JE creation failed for this entry. Doc03 §24';

-- =============================================================================
-- GROUP 15 — BANK RECONCILIATION
-- =============================================================================

-- 67. Reconciliation status — bank statement line matching status
--     Used by: bank_statement_lines.reconciliation_status (or bank_transactions)
--     Doc03 §21
DO $$
BEGIN
    CREATE TYPE public.pxl_reconciliation_status AS ENUM (
        'unmatched',
        'matched',
        'cleared',
        'exception'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_reconciliation_status IS
    'Bank reconciliation matching status per statement line. exception=manual review required (amount mismatch or duplicate). Doc03 §21';

-- 68. Bank adjustment type — category of manual bank reconciliation adjustment
--     Used by: bank_adjustments.adjustment_type
--     Doc03 §21
DO $$
BEGIN
    CREATE TYPE public.pxl_bank_adjustment_type AS ENUM (
        'debit_memo',
        'credit_memo',
        'bank_charge',
        'interest_income',
        'other'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_bank_adjustment_type IS
    'Bank reconciliation adjustment category. Each type determines the GL account treatment in the reconciliation JE. Doc03 §21';

-- 69. Reconciliation line type — classification of items in bank recon worksheet
--     Used by: bank_reconciliation_lines.line_type
--     Doc03 §21
DO $$
BEGIN
    CREATE TYPE public.pxl_recon_line_type AS ENUM (
        'outstanding_check',
        'deposit_in_transit',
        'bank_adjustment',
        'book_adjustment'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_recon_line_type IS
    'Bank reconciliation worksheet item type. outstanding_check=issued but not yet cleared; deposit_in_transit=deposited but not yet on statement. Doc03 §21';

-- =============================================================================
-- GROUP 16 — AMORTIZATION & REVENUE RECOGNITION SCHEDULES
-- =============================================================================

-- 70. Prepaid expense type — category of asset being amortized
--     Used by: amortization_schedules.prepaid_type
--     Doc03 §33
DO $$
BEGIN
    CREATE TYPE public.pxl_prepaid_type AS ENUM (
        'prepaid_rent',
        'prepaid_insurance',
        'prepaid_software',
        'prepaid_professional_fees',
        'deferred_charge',
        'other'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_prepaid_type IS
    'Category of prepaid expense or deferred charge being amortized. Determines default GL account treatment. Doc03 §33';

-- 71. Schedule status — shared by amortization and revenue recognition schedules
--     Used by: amortization_schedules.status,
--              revenue_recognition_schedules.status
--     Doc03 §33, §35
DO $$
BEGIN
    CREATE TYPE public.pxl_schedule_status AS ENUM (
        'active',
        'completed',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_schedule_status IS
    'Lifecycle status shared by amortization_schedules and revenue_recognition_schedules. completed=all periods processed; cancelled=voided before completion. Doc03 §33, §35';

-- 72. Deferred revenue type — category of revenue being recognized over time
--     Used by: revenue_recognition_schedules.deferred_revenue_type
--     Doc03 §35
DO $$
BEGIN
    CREATE TYPE public.pxl_deferred_revenue_type AS ENUM (
        'annual_retainer',
        'service_contract',
        'subscription',
        'advance_billing',
        'other'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_deferred_revenue_type IS
    'Category of deferred revenue. Required for PFRS 15 (Revenue from Contracts) compliance — Phase 1: straight-line only. Doc03 §35';

-- 73. Schedule run status — amortization/revenue recognition batch run lifecycle
--     Used by: amortization_runs.status, revenue_recognition_runs.status
--     Doc03 §33, §35
DO $$
BEGIN
    CREATE TYPE public.pxl_schedule_run_status AS ENUM (
        'pending',
        'processing',
        'completed',
        'failed',
        'rolled_back'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_schedule_run_status IS
    'Monthly schedule run batch lifecycle (amortization and revenue recognition). rolled_back=all generated JEs from this run have been reversed. Doc03 §33, §35';

-- 74. Run item status — per-entry processing status within a schedule run
--     Used by: amortization_run_details.status,
--              revenue_recognition_run_details.status
--     Doc03 §33, §35
DO $$
BEGIN
    CREATE TYPE public.pxl_run_item_status AS ENUM (
        'pending',
        'processed',
        'skipped'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_run_item_status IS
    'Per-schedule-line status within a run batch. skipped=period locked or line already processed. Doc03 §33, §35';

-- 75. Run detail result — outcome of processing a single schedule run detail
--     Used by: amortization_run_details.result (if separate from status),
--              revenue_recognition_run_details.result
--     Doc03 §33, §35
DO $$
BEGIN
    CREATE TYPE public.pxl_run_detail_status AS ENUM (
        'pending',
        'success',
        'failed',
        'rolled_back'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_run_detail_status IS
    'Outcome result of a single schedule entry within a run. failed=JE creation failed for this entry. Doc03 §33, §35';

-- =============================================================================
-- GROUP 17 — DOCUMENT RELATIONSHIPS & PARTY MANAGEMENT
-- =============================================================================

-- 76. Document relationship type — how two documents are linked
--     Used by: document_relationships.relationship_type
--     Doc03 §32
DO $$
BEGIN
    CREATE TYPE public.pxl_document_relationship_type AS ENUM (
        'generated_journal',
        'reversed_by',
        'paid_by',
        'credit_applied',
        'receipt_applied',
        'generated_from'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_document_relationship_type IS
    'Type of link between two ERP documents. generated_journal=source doc → JE; reversed_by=original doc → reversal doc; paid_by=invoice → receipt/PV. Doc03 §32';

-- 77. Party merge type — what kind of parties are being evaluated for deduplication
--     Used by: party_merge_candidates.party_type
--     Doc03 §19
DO $$
BEGIN
    CREATE TYPE public.pxl_party_merge_type AS ENUM (
        'customer',
        'supplier',
        'mixed'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;
COMMENT ON TYPE public.pxl_party_merge_type IS
    'What category of party records are being merged. mixed=same entity appears as both customer and supplier. Doc03 §19';

-- =============================================================================
-- VERIFICATION QUERIES
-- Run after applying this migration.
-- =============================================================================
--
-- 1. Confirm all 77 enum types exist:
--
--    SELECT typname, obj_description(oid, 'pg_type') AS comment
--    FROM   pg_type
--    WHERE  typname LIKE 'pxl_%'
--      AND  typtype = 'e'
--    ORDER  BY typname;
--    -- Expected: 77 rows
--
-- 2. Verify specific value counts:
--
--    SELECT typname, COUNT(*) AS value_count
--    FROM   pg_type t
--    JOIN   pg_enum e ON e.enumtypid = t.oid
--    WHERE  typname LIKE 'pxl_%'
--    GROUP  BY typname
--    ORDER  BY typname;
--
--    Expected counts (key types):
--      pxl_account_type_code       13
--      pxl_activity_type           16
--      pxl_bir_form_code           10
--      pxl_control_account_type     9
--      pxl_fs_section              10
--      pxl_je_type                 10
--      pxl_permission_action        9
--      pxl_series_type             18
--      pxl_system_account_key      17
--      pxl_transaction_type        23
--      pxl_vat_classification       6
--
-- 3. Spot-check enum values (UPPERCASE exception verification):
--
--    SELECT enumlabel FROM pg_enum e
--    JOIN pg_type t ON t.oid = e.enumtypid
--    WHERE t.typname = 'pxl_system_account_key'
--    ORDER BY enumsortorder;
--    -- Expected: 17 UPPERCASE values starting with CASH_ON_HAND
--
--    SELECT enumlabel FROM pg_enum e
--    JOIN pg_type t ON t.oid = e.enumtypid
--    WHERE t.typname = 'pxl_movement_type'
--    ORDER BY enumsortorder;
--    -- Expected: 'IN', 'OUT' (UPPERCASE per frozen spec)
--
-- 4. Confirm filing frequency anomaly:
--
--    SELECT enumlabel FROM pg_enum e
--    JOIN pg_type t ON t.oid = e.enumtypid
--    WHERE t.typname IN ('pxl_filing_frequency','pxl_recurring_frequency')
--    ORDER BY typname, enumsortorder;
--    -- pxl_filing_frequency has 'annual' (not 'annually')
--    -- pxl_recurring_frequency has 'annually' (not 'annual')
--
-- 5. Confirm no CREATE TYPE IF NOT EXISTS syntax was used (idempotency check):
--
--    -- All types use DO $$ ... EXCEPTION WHEN duplicate_object THEN NULL END $$
--    -- Re-running this migration on an existing database must produce zero errors.
--
-- =============================================================================

-- =============================================================================
-- ROLLBACK NOTES
-- =============================================================================
-- PostgreSQL enums cannot be individually dropped if they have dependent columns.
-- Rollback sequence (reverse order, development only):
--
--   DROP TYPE IF EXISTS public.pxl_party_merge_type CASCADE;
--   DROP TYPE IF EXISTS public.pxl_document_relationship_type CASCADE;
--   ... (all 77 types in reverse creation order)
--
-- CASCADE will drop all table columns typed with these enums. NEVER run CASCADE
-- on a database with data — all data in dependent columns will be lost.
--
-- For local dev: supabase db reset (re-applies all migrations from scratch)
-- For production: enums are a one-way gate. Corrections via new migrations only.
-- =============================================================================

-- =============================================================================
-- EXPECTED OBJECTS CREATED
-- =============================================================================
--   Schema: public (existing)
--   Enum types: 77
--
--   Group 1  — Organization & System (7):
--     pxl_taxpayer_type, pxl_income_tax_regime, pxl_legal_type,
--     pxl_deduction_method, pxl_fiscal_status, pxl_approval_type,
--     pxl_budget_status
--
--   Group 2  — Chart of Accounts (8):
--     pxl_account_type_code, pxl_normal_balance, pxl_fs_section,
--     pxl_fs_category, pxl_cash_flow_category, pxl_tax_deductibility,
--     pxl_control_account_type, pxl_system_account_key
--
--   Group 3  — Party & Master Data (4):
--     pxl_party_entity_type, pxl_vat_registration_status,
--     pxl_party_special_class, pxl_item_type
--
--   Group 4  — Transactions (5):
--     pxl_transaction_type, pxl_transaction_status, pxl_payment_method,
--     pxl_vat_direction, pxl_vat_classification
--
--   Group 5  — Journal Entries (4):
--     pxl_je_type, pxl_je_status, pxl_recurring_frequency,
--     pxl_recurring_status
--
--   Group 6  — Posting Engine (6):
--     pxl_entry_side, pxl_account_source, pxl_amount_source,
--     pxl_applies_to, pxl_subsidiary_ledger_type, pxl_posting_batch_status
--
--   Group 7  — Number Series (2):
--     pxl_series_type, pxl_reset_frequency
--
--   Group 8  — Audit & Activity (5):
--     pxl_change_type, pxl_activity_type, pxl_dat_type,
--     pxl_alert_type, pxl_alert_severity
--
--   Group 9  — Approval & Notifications (5):
--     pxl_approval_request_status, pxl_approval_action,
--     pxl_notification_channel, pxl_notification_status,
--     pxl_permission_action
--
--   Group 10 — Period Close (2):
--     pxl_period_close_status, pxl_close_task_status
--
--   Group 11 — Import & Export (6):
--     pxl_import_batch_status, pxl_import_row_status,
--     pxl_import_file_format, pxl_export_format,
--     pxl_export_status, pxl_validation_severity
--
--   Group 12 — BIR Compliance Filing (6):
--     pxl_filing_status, pxl_bir_form_code, pxl_filing_frequency,
--     pxl_tax_account_type, pxl_credit_type,
--     pxl_book_tax_reconciliation_type
--
--   Group 13 — Inventory (2):
--     pxl_inventory_adjustment_type, pxl_movement_type
--
--   Group 14 — Fixed Assets (4):
--     pxl_depreciation_method, pxl_disposal_type,
--     pxl_depreciation_run_status, pxl_depreciation_entry_status
--
--   Group 15 — Bank Reconciliation (3):
--     pxl_reconciliation_status, pxl_bank_adjustment_type,
--     pxl_recon_line_type
--
--   Group 16 — Schedules (6):
--     pxl_prepaid_type, pxl_schedule_status, pxl_deferred_revenue_type,
--     pxl_schedule_run_status, pxl_run_item_status, pxl_run_detail_status
--
--   Group 17 — Document Relationships & Party (2):
--     pxl_document_relationship_type, pxl_party_merge_type
--
--   Tables   : 0
--   Functions: 0
--   Triggers : 0
--   Indexes  : 0
-- =============================================================================
