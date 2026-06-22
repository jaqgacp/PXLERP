-- =============================================================================
-- Migration 012 — Chart of Accounts Foundation (Completion)
-- Modules 4 (remaining), 16 (config), 26 (budget)
-- Doc02 §4, Doc03 §3/§9/§26/§27/§30/§32, Doc06 §2/§8
-- =============================================================================
--
-- STATUS OF CHART OF ACCOUNTS INFRASTRUCTURE
-- ============================================
-- The following Module 4 tables were created in Migration 004:
--   ✓ account_types          (#27)  — setup, Immutable=YES
--   ✓ currencies             (#28)  — master, Soft Delete=YES
--   ✓ exchange_rates         (#29)  — ledger, Immutable=YES
--   ✓ chart_of_accounts      (#26)  — master, Soft Delete=YES
--   ✓ system_account_config  (#32)  — config, Soft Delete=YES
--
-- This migration completes the COA foundation by:
--   1. Adding deferred FK constraints from Migration 011 (fixed_assets tables)
--      → chart_of_accounts.id (could not be added as inline FKs in Migration 011
--        because the author incorrectly treated COA as post-011; corrected here).
--   2. Creating opening_balance_entries (#30) — was deferred in Migration 004.
--   3. Creating posting_rule_sets (#136) + posting_rule_lines (#137) — Module 16
--      COA-dependent config tables; posting runtime tables go in Migration 013.
--   4. Creating budgets (#183) + budget_lines (#184) — Module 26.
--
-- Depends on:
--   004_core_setup.sql    — chart_of_accounts, companies, branches, departments,
--                           cost_centers, fiscal_years, fiscal_periods, profiles
--   011_fixed_assets.sql  — fixed_assets, asset_categories, asset_disposals
--
-- Deferred FK columns created here (resolved in future migrations):
--   opening_balance_entries.journal_entry_id → Migration 013 (journal_entries)
--   import_batch_id on all tables            → Migration 023 (import_batches)
--
-- =============================================================================

-- =============================================================================
-- SECTION 1 — DEFERRED FK CONSTRAINTS FROM MIGRATION 011
-- Adds FK constraints to chart_of_accounts on fixed asset tables.
-- These were declared as plain uuid columns in Migration 011 due to an error
-- in the deferred-dependency chain (chart_of_accounts exists since Migration 004).
-- =============================================================================

-- asset_categories.depreciation_expense_account_id
-- GL account for DR Depreciation Expense. See Doc06 §Asset Depreciation Posting.
ALTER TABLE public.asset_categories
    ADD CONSTRAINT fk_asset_categories_depreciation_expense_account
        FOREIGN KEY (depreciation_expense_account_id)
        REFERENCES public.chart_of_accounts(id);

-- fixed_assets.asset_account_id
-- GL account for Fixed Asset at Cost (e.g., 16100 PP&E).
ALTER TABLE public.fixed_assets
    ADD CONSTRAINT fk_fixed_assets_asset_account
        FOREIGN KEY (asset_account_id)
        REFERENCES public.chart_of_accounts(id);

-- fixed_assets.depreciation_account_id
-- Per-asset Depreciation Expense account override.
ALTER TABLE public.fixed_assets
    ADD CONSTRAINT fk_fixed_assets_depreciation_account
        FOREIGN KEY (depreciation_account_id)
        REFERENCES public.chart_of_accounts(id);

-- fixed_assets.accumulated_depreciation_account_id
-- Accumulated Depreciation contra-asset account.
ALTER TABLE public.fixed_assets
    ADD CONSTRAINT fk_fixed_assets_accumulated_depreciation_account
        FOREIGN KEY (accumulated_depreciation_account_id)
        REFERENCES public.chart_of_accounts(id);

-- asset_disposals.disposal_account_id
-- GL account for Gain/Loss on Disposal.
ALTER TABLE public.asset_disposals
    ADD CONSTRAINT fk_asset_disposals_disposal_account
        FOREIGN KEY (disposal_account_id)
        REFERENCES public.chart_of_accounts(id);

-- =============================================================================
-- SECTION 2 — OPENING BALANCE ENTRIES (#30)
-- Module 4: Accounting Setup. Deferred from Migration 004.
-- =============================================================================

-- #30 opening_balance_entries
-- Captures account balances as of the day before ERP go-live (pre-system migration
-- balances). One row per account per branch per company. On posting the system
-- generates a single journal entry that establishes the opening GL position.
-- Doc03 §30 table #30. Immutable=YES. No soft delete.
--
-- Note: journal_entry_id FK deferred to Migration 013 (journal_entries).
-- import_batch_id FK deferred to Migration 023 (import_batches).
CREATE TABLE public.opening_balance_entries (
    id               uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id       uuid          NOT NULL REFERENCES public.companies(id),
    branch_id        uuid          NULL     REFERENCES public.branches(id),
    -- GL account to which this opening balance applies.
    account_id       uuid          NOT NULL REFERENCES public.chart_of_accounts(id),
    -- First fiscal period of the company's first fiscal year in PXL ERP.
    fiscal_period_id uuid          NOT NULL REFERENCES public.fiscal_periods(id),
    -- Balance date: the last day of operation in the prior system (day before go-live).
    as_of_date       date          NOT NULL,
    -- Opening debit balance for this account (0 for credit-normal accounts).
    debit_amount     numeric(18,4) NOT NULL DEFAULT 0,
    -- Opening credit balance for this account (0 for debit-normal accounts).
    credit_amount    numeric(18,4) NOT NULL DEFAULT 0,
    -- False until the opening balance posting batch is executed.
    is_posted        boolean       NOT NULL DEFAULT false,
    posted_at        timestamptz   NULL,
    -- journal_entry_id FK deferred to Migration 013.
    -- Set by posting engine when opening balance JE is generated.
    journal_entry_id uuid          NULL,
    -- import_batch_id FK deferred to Migration 023.
    import_batch_id  uuid          NULL,
    -- Immutable audit (Immutable=YES)
    created_at       timestamptz   NOT NULL DEFAULT now(),
    created_by       uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at       timestamptz   NULL,
    updated_by       uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_opening_balance_entries PRIMARY KEY (id),
    -- One opening balance row per account per branch (NULL branch = company-wide).
    -- Two partial unique indexes to handle NULL branch_id correctly.
    CONSTRAINT ck_obe_amounts CHECK (
        debit_amount >= 0 AND credit_amount >= 0
    ),
    -- An account should have either a debit or credit balance, not both.
    -- (Except during data migration — validated at app layer.)
    CONSTRAINT ck_obe_one_side CHECK (
        NOT (debit_amount > 0 AND credit_amount > 0)
    )
);

COMMENT ON TABLE public.opening_balance_entries IS
    'Pre-go-live account balances per account per branch. Captures migration balances '
    'from the prior system. On posting generates a single opening balance journal entry '
    'that establishes the initial GL position. One row per account/branch combination. '
    'Doc03 §30 table #30. Immutable after posting.';
COMMENT ON COLUMN public.opening_balance_entries.as_of_date IS
    'Balance as of this date — typically the last day of the prior system operation '
    '(one day before ERP go-live). This date becomes the opening balance date for GL.';
COMMENT ON COLUMN public.opening_balance_entries.journal_entry_id IS
    'FK → journal_entries.id — FK constraint added in Migration 013. '
    'Set by the posting engine when the opening balance JE is generated.';
COMMENT ON COLUMN public.opening_balance_entries.debit_amount IS
    'Debit-side balance. Non-zero for debit-normal accounts (assets, expenses). '
    'Zero for credit-normal accounts.';
COMMENT ON COLUMN public.opening_balance_entries.credit_amount IS
    'Credit-side balance. Non-zero for credit-normal accounts (liabilities, equity, revenue). '
    'Zero for debit-normal accounts.';

-- Two separate partial unique indexes to handle NULL branch_id (NULL != NULL in PG).
-- Company-wide opening balance (branch_id IS NULL) — one per account per company.
CREATE UNIQUE INDEX uq_obe_company_account_no_branch
    ON public.opening_balance_entries (company_id, account_id)
    WHERE branch_id IS NULL AND is_posted = false;

-- Branch-specific opening balance — one per account per branch.
CREATE UNIQUE INDEX uq_obe_company_account_branch
    ON public.opening_balance_entries (company_id, account_id, branch_id)
    WHERE branch_id IS NOT NULL AND is_posted = false;

CREATE INDEX ix_opening_balance_entries_company
    ON public.opening_balance_entries (company_id)
    WHERE is_posted = false;

CREATE INDEX ix_opening_balance_entries_account
    ON public.opening_balance_entries (account_id);

ALTER TABLE public.opening_balance_entries ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- SECTION 3 — POSTING RULE SETS (#136) and POSTING RULE LINES (#137)
-- Module 16: Accounting — posting configuration tables.
-- Defines DR/CR rules per transaction type. Used by the posting engine (Doc06).
-- =============================================================================

-- #136 posting_rule_sets
-- One rule set per transaction type per company. Effective-date versioned to
-- allow rule changes without affecting historical posts.
-- Doc03 §9 / Doc06 §2. Soft Delete=YES. Immutable=NO.
--
-- Transaction types (per Doc06 §2):
--   sales_invoice, cash_sale, receipt, sales_credit_memo, sales_debit_memo,
--   customer_return, vendor_bill, cash_purchase, payment_voucher,
--   supplier_debit_memo, purchase_return, vendor_credit,
--   petty_cash_voucher, petty_cash_replenishment,
--   stock_adjustment, stock_transfer, inter_branch_transfer,
--   bank_fund_transfer, bank_adjustment,
--   asset_acquisition, asset_depreciation, asset_disposal,
--   journal_entry
--
-- Effective-Date Non-Overlap Rule (Doc03 §3 v3.2 BLOCKER 7):
--   Application must validate non-overlapping effective date ranges before INSERT.
--   The partial unique index on effective_to IS NULL prevents two simultaneous
--   active rules per code per company but does not prevent overlapping closed ranges.
CREATE TABLE public.posting_rule_sets (
    id               uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id       uuid        NOT NULL REFERENCES public.companies(id),
    -- Unique code for this rule set (e.g., 'SALES_INVOICE_POST').
    rule_set_code    text        NOT NULL,
    -- Transaction type this rule set governs. See Doc06 §2 for the full list.
    transaction_type text        NOT NULL,
    description      text        NULL,
    is_active        boolean     NOT NULL DEFAULT true,
    -- System rules cannot be deleted or deactivated by company users.
    is_system        boolean     NOT NULL DEFAULT false,
    effective_from   date        NOT NULL,
    effective_to     date        NULL,
    -- import_batch_id FK deferred to Migration 023
    import_batch_id  uuid        NULL,
    -- standard audit (Soft Delete=YES, Immutable=NO)
    created_at       timestamptz NOT NULL DEFAULT now(),
    created_by       uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at       timestamptz NULL,
    updated_by       uuid        NULL     REFERENCES public.profiles(id),
    deleted_at       timestamptz NULL,
    deleted_by       uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_posting_rule_sets PRIMARY KEY (id),
    CONSTRAINT uq_prs_code_from UNIQUE (company_id, rule_set_code, effective_from),
    CONSTRAINT ck_prs_transaction_type CHECK (
        transaction_type IN (
            'sales_invoice','cash_sale','receipt','sales_credit_memo','sales_debit_memo',
            'customer_return','vendor_bill','cash_purchase','payment_voucher',
            'supplier_debit_memo','purchase_return','vendor_credit',
            'petty_cash_voucher','petty_cash_replenishment',
            'stock_adjustment','stock_transfer','inter_branch_transfer',
            'bank_fund_transfer','bank_adjustment',
            'asset_acquisition','asset_depreciation','asset_disposal',
            'journal_entry'
        )
    ),
    CONSTRAINT ck_prs_effective_dates CHECK (
        effective_to IS NULL OR effective_to > effective_from
    )
);

COMMENT ON TABLE public.posting_rule_sets IS
    'Posting rule set header per transaction type per company. Effective-date versioned '
    'to allow rule changes without affecting historical posts. The posting engine selects '
    'the active rule set at transaction post time. System rules (is_system=true) cannot '
    'be deleted or deactivated. Doc03 §9, Doc06 §2.';
COMMENT ON COLUMN public.posting_rule_sets.rule_set_code IS
    'Unique identifier for this rule set, e.g. SALES_INVOICE_POST. '
    'Used by the posting engine to locate the active rule set for a transaction type.';
COMMENT ON COLUMN public.posting_rule_sets.transaction_type IS
    'Transaction type this rule governs. Full list in Doc06 §2 §transaction_type_registry.';
COMMENT ON COLUMN public.posting_rule_sets.is_system IS
    'System rules are seeded at company setup and cannot be deleted or deactivated '
    'by company users. Protects core transaction posting from accidental misconfiguration.';
COMMENT ON COLUMN public.posting_rule_sets.effective_from IS
    'Rule takes effect from this date. The posting engine selects the rule set with '
    'the most recent effective_from <= transaction posting_date AND effective_to IS NULL '
    'or effective_to > posting_date.';

-- One active rule set per code per company.
CREATE UNIQUE INDEX uq_prs_code_active
    ON public.posting_rule_sets (company_id, rule_set_code)
    WHERE effective_to IS NULL AND deleted_at IS NULL;

CREATE INDEX ix_posting_rule_sets_company
    ON public.posting_rule_sets (company_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_posting_rule_sets_txn_type
    ON public.posting_rule_sets (company_id, transaction_type)
    WHERE effective_to IS NULL AND deleted_at IS NULL;

ALTER TABLE public.posting_rule_sets ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #137 posting_rule_lines
-- Individual DR or CR rule lines within a posting rule set.
-- Each line defines one side of one journal entry line: which account to use,
-- how to compute the amount, and whether to create a subsidiary ledger entry.
-- Config table. Immutable once deployed per Doc03 §9 ("Immutable once deployed").
-- Since posting_rule_sets has effective-date versioning, the approach is to create
-- a new rule set with new lines rather than modifying existing lines.
-- Soft Delete=YES (supports deactivation of individual lines during rule authoring).
CREATE TABLE public.posting_rule_lines (
    id                       uuid    NOT NULL DEFAULT gen_random_uuid(),
    company_id               uuid    NOT NULL REFERENCES public.companies(id),
    posting_rule_set_id      uuid    NOT NULL REFERENCES public.posting_rule_sets(id),
    -- Execution order within the rule set (lower = executed first).
    line_no                  integer NOT NULL,
    -- Which side of the journal entry this line writes.
    entry_side               text    NOT NULL,
    -- How to resolve the GL account for this line.
    -- 'fixed'             = always use fixed_account_id
    -- 'from_system_config' = look up system_account_config by account_config_key
    -- 'from_item'         = read account from the source document's item/asset record
    -- 'from_customer'     = read account from the customer master record
    -- 'from_supplier'     = read account from the supplier master record
    -- 'from_line'         = read account from the transaction line itself
    account_source           text    NOT NULL,
    -- Fixed GL account (used when account_source='fixed').
    -- FK → chart_of_accounts.id already exists (Migration 004).
    fixed_account_id         uuid    NULL     REFERENCES public.chart_of_accounts(id),
    -- system_account_config key (used when account_source='from_system_config').
    account_config_key       text    NULL,
    -- Amount computation strategy:
    -- 'line_subtotal'           = pre-tax line amount
    -- 'line_vat'                = VAT amount from the line
    -- 'line_ewt'                = EWT amount from the line
    -- 'header_total'            = transaction total_amount
    -- 'computed'                = formula in amount_formula (for split rules, etc.)
    amount_source            text    NOT NULL,
    -- SQL-style expression used when amount_source='computed'.
    amount_formula           text    NULL,
    -- Which lines this rule applies to.
    -- 'all'                      = all lines
    -- 'vat_lines_only'           = lines where vat_amount > 0
    -- 'ewt_lines_only'           = lines where ewt_amount > 0
    -- 'zero_vat_lines'           = lines where vat_classification='zero_rated'
    -- 'capital_goods_lines_only' = lines where vat_classification='capital_goods'
    -- 'pt_lines_only'            = lines subject to percentage tax
    applies_to               text    NOT NULL DEFAULT 'all',
    -- Whether this line should also write a subsidiary_ledger_entry record.
    creates_subsidiary_ledger boolean NOT NULL DEFAULT false,
    subsidiary_ledger_type   text    NULL,
    -- Whether to include the branch_id dimension on the generated journal line.
    use_branch_dimension     boolean NOT NULL DEFAULT true,
    -- Whether to include the department_id dimension on the generated journal line.
    use_department_dimension boolean NOT NULL DEFAULT false,
    -- Whether to include the cost_center_id dimension on the generated journal line.
    use_cost_center_dimension boolean NOT NULL DEFAULT false,
    -- Template for the journal line description (e.g., 'Invoice {doc_no} — {customer_name}').
    description_template     text    NULL,
    -- standard audit (Soft Delete=YES — for authoring; system lines not deleted)
    created_at               timestamptz NOT NULL DEFAULT now(),
    created_by               uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at               timestamptz NULL,
    updated_by               uuid        NULL     REFERENCES public.profiles(id),
    deleted_at               timestamptz NULL,
    deleted_by               uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_posting_rule_lines PRIMARY KEY (id),
    -- Line numbers must be unique within a rule set.
    CONSTRAINT uq_prl_set_line UNIQUE (posting_rule_set_id, line_no),
    CONSTRAINT ck_prl_entry_side CHECK (entry_side IN ('debit','credit')),
    CONSTRAINT ck_prl_account_source CHECK (
        account_source IN (
            'fixed','from_system_config','from_item',
            'from_customer','from_supplier','from_line'
        )
    ),
    CONSTRAINT ck_prl_amount_source CHECK (
        amount_source IN (
            'line_subtotal','line_vat','line_ewt','header_total','computed'
        )
    ),
    CONSTRAINT ck_prl_applies_to CHECK (
        applies_to IN (
            'all','vat_lines_only','ewt_lines_only','zero_vat_lines',
            'capital_goods_lines_only','pt_lines_only'
        )
    ),
    -- fixed_account_id must be provided when account_source='fixed'.
    CONSTRAINT ck_prl_fixed_account CHECK (
        account_source <> 'fixed' OR fixed_account_id IS NOT NULL
    ),
    -- account_config_key must be provided when account_source='from_system_config'.
    CONSTRAINT ck_prl_config_key CHECK (
        account_source <> 'from_system_config' OR account_config_key IS NOT NULL
    ),
    -- amount_formula must be provided when amount_source='computed'.
    CONSTRAINT ck_prl_formula CHECK (
        amount_source <> 'computed' OR amount_formula IS NOT NULL
    ),
    -- subsidiary_ledger_type required when creates_subsidiary_ledger=true.
    CONSTRAINT ck_prl_sub_ledger_type CHECK (
        creates_subsidiary_ledger = false
        OR subsidiary_ledger_type IN ('ar','ap','inventory','fixed_asset')
    )
);

COMMENT ON TABLE public.posting_rule_lines IS
    'Individual DR/CR rule lines within a posting rule set. Each line defines '
    'one journal entry line: account source, amount computation, and subsidiary '
    'ledger behavior. The posting engine processes lines in line_no order. '
    'Doc03 §9, Doc06 §2 and §8. Config — effectively immutable once a rule set '
    'is active (create a new versioned rule set instead of modifying lines).';
COMMENT ON COLUMN public.posting_rule_lines.account_source IS
    'How the posting engine resolves the GL account for this line. '
    '''fixed'' = hardcoded; ''from_system_config'' = via system_account_config key; '
    '''from_item'' = from item/asset GL account fields; '
    '''from_customer'' = customer.ar_account_id or sales_account_id; '
    '''from_supplier'' = supplier.ap_account_id or expense_account_id; '
    '''from_line'' = account_id column on the transaction line itself.';
COMMENT ON COLUMN public.posting_rule_lines.creates_subsidiary_ledger IS
    'When true the posting engine also writes a subsidiary_ledger_entries row '
    '(ledger_type per subsidiary_ledger_type). Enables AR/AP/FA/Inventory ledger drill-down.';
COMMENT ON COLUMN public.posting_rule_lines.description_template IS
    'Handlebars-style template for the JE line narration. '
    'Supported tokens: {doc_no}, {customer_name}, {supplier_name}, {item_name}, '
    '{period_name}, {asset_no}. Populated at post time by the posting engine.';

CREATE INDEX ix_posting_rule_lines_rule_set
    ON public.posting_rule_lines (posting_rule_set_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_posting_rule_lines_fixed_account
    ON public.posting_rule_lines (fixed_account_id)
    WHERE fixed_account_id IS NOT NULL;

ALTER TABLE public.posting_rule_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- SECTION 4 — BUDGETS (#183) AND BUDGET LINES (#184)
-- Module 26: Budget. References COA, fiscal setup, branches, departments.
-- =============================================================================

-- #183 budgets
-- Annual budget header per company per fiscal year. Supports re-budgeting via
-- version numbers. Budget vs actual comparison reads gl_balances.
-- Doc03 §21 table #183. Soft Delete=YES. Immutable=NO.
CREATE TABLE public.budgets (
    id              uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id      uuid        NOT NULL REFERENCES public.companies(id),
    fiscal_year_id  uuid        NOT NULL REFERENCES public.fiscal_years(id),
    budget_name     text        NOT NULL,
    -- Version number for re-budgeting (1=original, 2=revised, etc.).
    version         integer     NOT NULL DEFAULT 1,
    -- draft → approved → active → superseded (when a new version becomes active).
    status          text        NOT NULL DEFAULT 'draft',
    approved_by     uuid        NULL     REFERENCES public.profiles(id),
    approved_at     timestamptz NULL,
    notes           text        NULL,
    -- standard audit (Soft Delete=YES, Immutable=NO)
    created_at      timestamptz NOT NULL DEFAULT now(),
    created_by      uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at      timestamptz NULL,
    updated_by      uuid        NULL     REFERENCES public.profiles(id),
    deleted_at      timestamptz NULL,
    deleted_by      uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_budgets PRIMARY KEY (id),
    CONSTRAINT uq_budgets_year_version UNIQUE (company_id, fiscal_year_id, version),
    CONSTRAINT ck_budgets_status CHECK (
        status IN ('draft','approved','active','superseded')
    ),
    CONSTRAINT ck_budgets_version CHECK (version > 0)
);

COMMENT ON TABLE public.budgets IS
    'Annual budget header per company per fiscal year. Supports re-budgeting '
    'via version numbers (1=original, 2=revised, etc.). Budget-vs-actual variance '
    'analysis reads gl_balances joined to budget_lines. Doc03 §21 table #183.';
COMMENT ON COLUMN public.budgets.version IS
    'Budget version for re-budgeting. Original = 1. When a revised budget is '
    'approved, the prior version status transitions to ''superseded''.';
COMMENT ON COLUMN public.budgets.status IS
    '''active'' = the current approved budget used for variance reporting. '
    'Only one budget per fiscal year should be active at a time (app-layer enforced).';

CREATE INDEX ix_budgets_company_year
    ON public.budgets (company_id, fiscal_year_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_budgets_active
    ON public.budgets (company_id, fiscal_year_id)
    WHERE status = 'active' AND deleted_at IS NULL;

ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #184 budget_lines
-- Per-account per-period budget amounts. Branch and department dimension allows
-- branch-level and departmental P&L budget comparison.
-- Doc03 §21 table #184. Soft Delete=YES. Immutable=NO.
CREATE TABLE public.budget_lines (
    id               uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id       uuid          NOT NULL REFERENCES public.companies(id),
    budget_id        uuid          NOT NULL REFERENCES public.budgets(id),
    account_id       uuid          NOT NULL REFERENCES public.chart_of_accounts(id),
    -- NULL branch_id = company-wide budget (applies to all branches).
    branch_id        uuid          NULL     REFERENCES public.branches(id),
    department_id    uuid          NULL     REFERENCES public.departments(id),
    fiscal_period_id uuid          NOT NULL REFERENCES public.fiscal_periods(id),
    -- Budgeted amount for this account/branch/department/period combination.
    -- Always positive regardless of account normal_balance; sign convention
    -- is resolved at display time using chart_of_accounts.normal_balance.
    budgeted_amount  numeric(18,4) NOT NULL DEFAULT 0,
    notes            text          NULL,
    -- standard audit (Soft Delete=YES, Immutable=NO)
    created_at       timestamptz   NOT NULL DEFAULT now(),
    created_by       uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at       timestamptz   NULL,
    updated_by       uuid          NULL     REFERENCES public.profiles(id),
    deleted_at       timestamptz   NULL,
    deleted_by       uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_budget_lines PRIMARY KEY (id),
    CONSTRAINT uq_budget_lines_key UNIQUE (
        budget_id, account_id, branch_id, department_id, fiscal_period_id
    ),
    CONSTRAINT ck_budget_lines_amount CHECK (budgeted_amount >= 0)
);

COMMENT ON TABLE public.budget_lines IS
    'Per-account per-period budget amounts within a budget version. '
    'branch_id=NULL means company-wide (not branch-specific). '
    'Budget-vs-actual variance = gl_balances.net_movement − budget_lines.budgeted_amount '
    'for the same account/branch/period combination. Doc03 §21 table #184.';
COMMENT ON COLUMN public.budget_lines.budgeted_amount IS
    'Always stored as a positive amount regardless of account normal_balance. '
    'Display layer applies sign convention using chart_of_accounts.normal_balance '
    'for variance reporting (debit-normal accounts: actual debit > budget = unfavorable; '
    'credit-normal revenue accounts: actual credit > budget = favorable).';
COMMENT ON COLUMN public.budget_lines.branch_id IS
    'NULL = company-wide budget line. Non-null = branch-specific allocation. '
    'Branch variance reports filter budget_lines by branch_id.';

CREATE INDEX ix_budget_lines_budget
    ON public.budget_lines (budget_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_budget_lines_account_period
    ON public.budget_lines (company_id, account_id, fiscal_period_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_budget_lines_branch
    ON public.budget_lines (company_id, branch_id, fiscal_period_id)
    WHERE branch_id IS NOT NULL AND deleted_at IS NULL;

ALTER TABLE public.budget_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- END OF MIGRATION 012
-- =============================================================================
--
-- Deferred FK constraints added:
--   asset_categories.depreciation_expense_account_id → chart_of_accounts (5 constraints)
--
-- Tables created (5):
--   opening_balance_entries  — Module 4 #30
--   posting_rule_sets        — Module 16 #136
--   posting_rule_lines       — Module 16 #137
--   budgets                  — Module 26 #183
--   budget_lines             — Module 26 #184
--
-- Deferred FK columns in this migration:
--   opening_balance_entries.journal_entry_id → Migration 013 (journal_entries)
--   import_batch_id on all tables             → Migration 023 (import_batches)
--
-- Remaining Module 16 tables (deferred to Migration 013 — GL/Journal Entries):
--   journal_entries, journal_lines, subsidiary_ledger_entries,
--   recurring_journal_templates, recurring_journal_template_lines,
--   gl_balances, document_relationships, posting_batches, posting_errors
--
-- Backlog items: M-012-1 (active budget uniqueness), L-012-1 (OBE unique per posted)
-- =============================================================================
