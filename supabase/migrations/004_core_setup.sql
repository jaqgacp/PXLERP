-- =============================================================================
-- PXL ERP — Migration 004: Core Setup Tables
-- =============================================================================
-- Release        : v4.0-database-freeze
-- Architecture   : docs/architecture/ (frozen — DO NOT MODIFY)
-- PostgreSQL     : 16
-- Supabase       : Compatible
-- Idempotent     : No — CREATE TABLE (run once; use supabase db reset for dev)
-- Depends On     : 001_extensions.sql, 002_enums.sql, 003_shared_functions.sql
-- Must Run Before: 005 and all subsequent migrations
-- =============================================================================
--
-- OVERVIEW
-- --------
-- Creates 32 core setup tables spanning Modules 1-4. These tables provide the
-- organizational, accounting, and security scaffolding required by all other
-- modules. No triggers, no RLS, no seed data — those belong in later migrations.
--
-- CREATION ORDER (FK dependency order)
-- ─────────────────────────────────────
-- Group A — Bootstrap (no app-table dependencies)
--   01. account_types
--   02. profiles
--   03. currencies
--
-- Group B — Organization
--   04. companies
--   05. branches
--   06. departments
--   07. cost_centers
--
-- Group C — Accounting Setup
--   08. fiscal_years
--   09. fiscal_periods
--   10. fiscal_locks
--   11. chart_of_accounts
--   12. exchange_rates
--   13. system_account_config
--
-- Group D — Organization Extended
--   14. company_compliance_profiles
--   15. company_feature_settings
--   16. cas_registrations
--   17. company_bank_accounts
--
-- Group E — Security (Module 1)
--   18. roles
--   19. permissions
--   20. role_permissions
--   21. user_roles
--   22. user_company_access
--   23. user_branch_access
--   24. user_department_access
--
-- Group F — System Controls (Module 3)
--   25. approval_matrix
--   26. approval_matrix_steps
--   27. number_series
--   28. number_series_atp
--   29. atp_usage_logs
--   30. document_controls
--   31. validation_rules
--   32. system_parameters
--
-- DEFERRED TABLES (with rationale)
-- ─────────────────────────────────
--   opening_balance_entries  → Depends on journal_entries (Migration 006+)
--   budgets, budget_lines    → Module 26; not core setup
--   chart_of_accounts.import_batch_id FK → Added in Migration 010 (import_batches)
--   All Module 5 tax setup   → vat_codes, atc_codes, bir_form_configurations, etc.
--   All master data tables   → customers, suppliers, items, etc.
--   All GL/transaction tables → journal_entries, posted_gl, etc.
--
-- STANDARD CONVENTIONS
-- ─────────────────────
-- • PK: id uuid PRIMARY KEY DEFAULT gen_random_uuid()
-- • Standard audit: created_at timestamptz NOT NULL DEFAULT now(),
--                   created_by uuid NOT NULL REFERENCES public.profiles(id),
--                   updated_at timestamptz NULL,
--                   updated_by uuid NULL REFERENCES public.profiles(id),
--                   deleted_at timestamptz NULL,
--                   deleted_by uuid NULL REFERENCES public.profiles(id)
-- • Immutable tables: no updated_* columns; may have no audit at all
-- • Soft Delete tables: have deleted_at / deleted_by columns
-- • Module 1 security tables: use auth.users(id) FKs (not profiles) per Doc09
-- • Hard DELETE is REVOKE'd at application layer; soft delete via deleted_at
--
-- SOURCE DOCUMENTS
-- ─────────────────
--   docs/architecture/02_COMPLETE_TABLE_INVENTORY.md
--   docs/architecture/03_TABLE_COLUMN_SPECIFICATIONS.md
--   docs/architecture/09_SECURITY_RLS_DESIGN.md
--
-- =============================================================================

-- =============================================================================
-- GROUP A — BOOTSTRAP
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 01. account_types
-- ---------------------------------------------------------------------------
-- Lookup table for the 5 fundamental account classifications (Asset, Liability,
-- Equity, Revenue, Expense). No company_id — shared across all tenants.
-- Seeded in a later migration. Immutable: no audit columns.
-- ---------------------------------------------------------------------------
CREATE TABLE public.account_types (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    code            public.pxl_account_type_code NOT NULL UNIQUE,
    name            text        NOT NULL,
    normal_balance  public.pxl_normal_balance    NOT NULL,
    fs_category     public.pxl_fs_category       NOT NULL,
    sort_order      integer     NOT NULL DEFAULT 0
);

COMMENT ON TABLE  public.account_types IS 'Lookup: five fundamental account classifications (Asset, Liability, Equity, Revenue, Expense). Shared across tenants. Immutable — seeded once, no tenant writes. Doc03 §23.';
COMMENT ON COLUMN public.account_types.code           IS 'Enum discriminator (pxl_account_type_code): ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE.';
COMMENT ON COLUMN public.account_types.normal_balance IS 'DEBIT or CREDIT — determines sign convention for GL movement.';
COMMENT ON COLUMN public.account_types.fs_category   IS 'Financial-statement presentation category (pxl_fs_category).';
COMMENT ON COLUMN public.account_types.sort_order    IS 'Display ordering on FS reports; lower values appear first.';

-- ---------------------------------------------------------------------------
-- 02. profiles
-- ---------------------------------------------------------------------------
-- Extends auth.users with application-level user data. One row per Supabase
-- auth user. id mirrors auth.users(id); CASCADE ensures cleanup on auth delete.
-- No created_by/updated_by/deleted_by — no self-referential bootstrap problem.
-- ---------------------------------------------------------------------------
CREATE TABLE public.profiles (
    id              uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name      text        NOT NULL,
    last_name       text        NOT NULL,
    display_name    text        NULL,
    avatar_url      text        NULL,
    phone           text        NULL,
    job_title       text        NULL,
    is_active       boolean     NOT NULL DEFAULT true,
    is_super_admin  boolean     NOT NULL DEFAULT false,
    timezone        text        NOT NULL DEFAULT 'Asia/Manila',
    locale          text        NOT NULL DEFAULT 'en-PH',
    last_login_at   timestamptz NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NULL,
    deleted_at      timestamptz NULL
);

COMMENT ON TABLE  public.profiles IS 'Application user profiles extending auth.users. One row per Supabase auth user; id is a FK to auth.users cascading on delete. Doc03 §2; Doc09 §2.';
COMMENT ON COLUMN public.profiles.is_super_admin  IS 'Platform-level super admin; bypasses company RLS for administrative tasks only. Super admins cannot post transactions. Doc09 §1.';
COMMENT ON COLUMN public.profiles.timezone        IS 'IANA timezone string; used for date display and fiscal period boundary calculations.';
COMMENT ON COLUMN public.profiles.last_login_at   IS 'Stamped by application layer on successful auth; not managed by DB triggers.';

-- ---------------------------------------------------------------------------
-- 03. currencies
-- ---------------------------------------------------------------------------
-- ISO 4217 currency master. Shared across tenants (no company_id).
-- PHP is the base currency (is_base_currency = true). Only one base currency
-- is enforced at the application layer.
-- ---------------------------------------------------------------------------
CREATE TABLE public.currencies (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    code                text        NOT NULL UNIQUE,
    name                text        NOT NULL,
    symbol              text        NOT NULL,
    is_base_currency    boolean     NOT NULL DEFAULT false,
    is_active           boolean     NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    created_by          uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at          timestamptz NULL,
    updated_by          uuid        NULL     REFERENCES public.profiles(id),
    deleted_at          timestamptz NULL,
    deleted_by          uuid        NULL     REFERENCES public.profiles(id)
);

COMMENT ON TABLE  public.currencies IS 'ISO 4217 currency master. Shared across tenants. PHP is base currency; exactly one row should have is_base_currency=true (enforced at app layer). Doc03 §30.';
COMMENT ON COLUMN public.currencies.code             IS 'ISO 4217 three-letter currency code (e.g. PHP, USD, EUR).';
COMMENT ON COLUMN public.currencies.is_base_currency IS 'True for the platform functional currency (PHP). Application enforces uniqueness of this flag.';

-- =============================================================================
-- GROUP B — ORGANIZATION
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 04. companies
-- ---------------------------------------------------------------------------
-- Top-level tenant entity. Every multi-tenant table has a company_id FK here.
-- tax_type and business_type are plain text with CHECK constraints — the
-- architecture uses text not enums for these fields (per Doc03).
-- ---------------------------------------------------------------------------
CREATE TABLE public.companies (
    id                          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    code                        text        NOT NULL UNIQUE,
    name                        text        NOT NULL,
    trade_name                  text        NULL,
    tin                         text        NOT NULL UNIQUE,
    rdo_code                    text        NULL,
    bir_registered_address      text        NOT NULL,
    industry_classification     text        NULL,
    tax_type                    text        NOT NULL CHECK (tax_type IN ('vat', 'non_vat')),
    business_type               text        NOT NULL CHECK (business_type IN ('corporation', 'partnership', 'sole_proprietorship', 'cooperative')),
    sec_registration_no         text        NULL,
    dti_registration_no         text        NULL,
    logo_url                    text        NULL,
    functional_currency_id      uuid        NOT NULL REFERENCES public.currencies(id),
    fiscal_year_start_month     integer     NOT NULL DEFAULT 1 CHECK (fiscal_year_start_month BETWEEN 1 AND 12),
    is_active                   boolean     NOT NULL DEFAULT true,
    created_at                  timestamptz NOT NULL DEFAULT now(),
    created_by                  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at                  timestamptz NULL,
    updated_by                  uuid        NULL     REFERENCES public.profiles(id),
    deleted_at                  timestamptz NULL,
    deleted_by                  uuid        NULL     REFERENCES public.profiles(id)
);

COMMENT ON TABLE  public.companies IS 'Top-level tenant entity. Every multi-tenant table carries a company_id FK to this table. RLS policies isolate data by company. Doc03 §9.';
COMMENT ON COLUMN public.companies.tin                      IS 'BIR Tax Identification Number; must be unique across the platform.';
COMMENT ON COLUMN public.companies.tax_type                 IS 'vat or non_vat; determines VAT applicability for all transactions. Superseded by company_compliance_profiles.taxpayer_type for detailed compliance — kept here for quick filtering.';
COMMENT ON COLUMN public.companies.business_type            IS 'Legal form: corporation, partnership, sole_proprietorship, or cooperative.';
COMMENT ON COLUMN public.companies.functional_currency_id   IS 'Reporting currency for this company; must reference an active currency.';
COMMENT ON COLUMN public.companies.fiscal_year_start_month  IS 'Month (1-12) the fiscal year begins; 1 = January.';

-- ---------------------------------------------------------------------------
-- 05. branches
-- ---------------------------------------------------------------------------
CREATE TABLE public.branches (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES public.companies(id),
    code                text        NOT NULL,
    name                text        NOT NULL,
    address             text        NULL,
    tin_suffix          text        NULL,
    bir_registered      boolean     NOT NULL DEFAULT false,
    is_head_office      boolean     NOT NULL DEFAULT false,
    is_active           boolean     NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    created_by          uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at          timestamptz NULL,
    updated_by          uuid        NULL     REFERENCES public.profiles(id),
    deleted_at          timestamptz NULL,
    deleted_by          uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT uq_branches_company_code UNIQUE (company_id, code)
);

COMMENT ON TABLE  public.branches IS 'Physical or logical operating locations within a company. Branch is the primary dimension for BIR VAT Returns and Sales Reports (RR16-2005). Doc03 §10.';
COMMENT ON COLUMN public.branches.tin_suffix     IS 'BIR-assigned branch code appended to company TIN for VAT documents (e.g. 000 for head office).';
COMMENT ON COLUMN public.branches.bir_registered IS 'True if this branch is separately registered with BIR for VAT purposes.';
COMMENT ON COLUMN public.branches.is_head_office IS 'Exactly one branch per company should be the head office (enforced at app layer).';

-- ---------------------------------------------------------------------------
-- 06. departments
-- ---------------------------------------------------------------------------
CREATE TABLE public.departments (
    id                      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id              uuid        NOT NULL REFERENCES public.companies(id),
    branch_id               uuid        NULL     REFERENCES public.branches(id),
    code                    text        NOT NULL,
    name                    text        NOT NULL,
    parent_department_id    uuid        NULL     REFERENCES public.departments(id),
    is_active               boolean     NOT NULL DEFAULT true,
    created_at              timestamptz NOT NULL DEFAULT now(),
    created_by              uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at              timestamptz NULL,
    updated_by              uuid        NULL     REFERENCES public.profiles(id),
    deleted_at              timestamptz NULL,
    deleted_by              uuid        NULL     REFERENCES public.profiles(id)
);

COMMENT ON TABLE  public.departments IS 'Organizational units within a company, optionally scoped to a branch. Supports hierarchical structure via parent_department_id self-reference. Doc03 §11.';
COMMENT ON COLUMN public.departments.parent_department_id IS 'Self-referential FK enabling department hierarchy (e.g. Finance → Accounts Payable). NULL = root department.';

-- ---------------------------------------------------------------------------
-- 07. cost_centers
-- ---------------------------------------------------------------------------
CREATE TABLE public.cost_centers (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id      uuid        NOT NULL REFERENCES public.companies(id),
    department_id   uuid        NULL     REFERENCES public.departments(id),
    code            text        NOT NULL,
    name            text        NOT NULL,
    is_active       boolean     NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    created_by      uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at      timestamptz NULL,
    updated_by      uuid        NULL     REFERENCES public.profiles(id),
    deleted_at      timestamptz NULL,
    deleted_by      uuid        NULL     REFERENCES public.profiles(id)
);

COMMENT ON TABLE  public.cost_centers IS 'Profit/cost tracking units, optionally linked to a department. Used as an optional dimension on GL journal lines. Doc03 §12.';

-- =============================================================================
-- GROUP C — ACCOUNTING SETUP
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 08. fiscal_years
-- ---------------------------------------------------------------------------
CREATE TABLE public.fiscal_years (
    id          uuid                    PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id  uuid                    NOT NULL REFERENCES public.companies(id),
    year_code   text                    NOT NULL,
    date_from   date                    NOT NULL,
    date_to     date                    NOT NULL,
    is_current  boolean                 NOT NULL DEFAULT false,
    status      public.pxl_fiscal_status NOT NULL DEFAULT 'open',
    created_at  timestamptz             NOT NULL DEFAULT now(),
    created_by  uuid                    NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz             NULL,
    updated_by  uuid                    NULL     REFERENCES public.profiles(id),
    deleted_at  timestamptz             NULL,
    deleted_by  uuid                    NULL     REFERENCES public.profiles(id),

    CONSTRAINT uq_fiscal_years_company_year_code UNIQUE (company_id, year_code),
    CONSTRAINT chk_fiscal_years_dates CHECK (date_to > date_from)
);

-- Partial unique: only one current fiscal year per company
CREATE UNIQUE INDEX uq_fiscal_years_current
    ON public.fiscal_years (company_id)
    WHERE is_current = true;

COMMENT ON TABLE  public.fiscal_years IS 'Fiscal year calendar per company. Controls accounting period boundaries and closing workflows. Doc03 §23.';
COMMENT ON COLUMN public.fiscal_years.is_current IS 'Exactly one fiscal year per company is current; enforced by partial unique index uq_fiscal_years_current.';
COMMENT ON COLUMN public.fiscal_years.status     IS 'pxl_fiscal_status: open, closed, locked. Progression is one-way; locking is enforced by fiscal_locks.';

-- ---------------------------------------------------------------------------
-- 09. fiscal_periods
-- ---------------------------------------------------------------------------
CREATE TABLE public.fiscal_periods (
    id              uuid                    PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id      uuid                    NOT NULL REFERENCES public.companies(id),
    fiscal_year_id  uuid                    NOT NULL REFERENCES public.fiscal_years(id),
    period_number   integer                 NOT NULL CHECK (period_number BETWEEN 1 AND 12),
    period_name     text                    NOT NULL,
    date_from       date                    NOT NULL,
    date_to         date                    NOT NULL,
    quarter         integer                 NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    status          public.pxl_fiscal_status NOT NULL DEFAULT 'open',
    created_at      timestamptz             NOT NULL DEFAULT now(),
    created_by      uuid                    NOT NULL REFERENCES public.profiles(id),
    updated_at      timestamptz             NULL,
    updated_by      uuid                    NULL     REFERENCES public.profiles(id),
    deleted_at      timestamptz             NULL,
    deleted_by      uuid                    NULL     REFERENCES public.profiles(id),

    CONSTRAINT uq_fiscal_periods_year_number UNIQUE (company_id, fiscal_year_id, period_number),
    CONSTRAINT chk_fiscal_periods_dates CHECK (date_to > date_from)
);

COMMENT ON TABLE  public.fiscal_periods IS 'Monthly accounting periods within a fiscal year. Transactions are posted to a fiscal_period_id; period status gates posting. Doc03 §24.';
COMMENT ON COLUMN public.fiscal_periods.quarter IS 'Fiscal quarter (1-4); used for quarterly BIR returns (VAT, income tax). Derived from period_number at insert time by application layer.';

-- ---------------------------------------------------------------------------
-- 10. fiscal_locks
-- ---------------------------------------------------------------------------
-- Immutable records of period lock/unlock events. No updated_* columns.
-- A locked period prevents any further posting regardless of fiscal_periods.status.
-- ---------------------------------------------------------------------------
CREATE TABLE public.fiscal_locks (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES public.companies(id),
    fiscal_period_id    uuid        NOT NULL REFERENCES public.fiscal_periods(id),
    locked_at           timestamptz NOT NULL DEFAULT now(),
    locked_by           uuid        NOT NULL REFERENCES public.profiles(id),
    lock_reason         text        NULL,
    unlocked_at         timestamptz NULL,
    unlocked_by         uuid        NULL     REFERENCES public.profiles(id),
    unlock_reason       text        NULL,

    CONSTRAINT uq_fiscal_locks_period UNIQUE (company_id, fiscal_period_id)
);

COMMENT ON TABLE  public.fiscal_locks IS 'Audit log of period lock and unlock events. One active lock per period per company (unique constraint). Immutable rows — unlock is recorded via unlocked_at/unlocked_by, not DELETE. Doc03 §25.';
COMMENT ON COLUMN public.fiscal_locks.unlocked_at IS 'NULL = currently locked. Non-null = period was unlocked; posting temporarily permitted.';

-- ---------------------------------------------------------------------------
-- 11. chart_of_accounts
-- ---------------------------------------------------------------------------
-- import_batch_id is created WITHOUT a FK constraint. The FK to
-- import_batches(id) is added in Migration 010 when that table exists.
-- ---------------------------------------------------------------------------
CREATE TABLE public.chart_of_accounts (
    id                      uuid                        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id              uuid                        NOT NULL REFERENCES public.companies(id),
    account_code            text                        NOT NULL,
    account_name            text                        NOT NULL,
    account_type_id         uuid                        NOT NULL REFERENCES public.account_types(id),
    parent_account_id       uuid                        NULL     REFERENCES public.chart_of_accounts(id),
    level                   integer                     NOT NULL DEFAULT 1,
    is_detail_account       boolean                     NOT NULL DEFAULT true,
    normal_balance          public.pxl_normal_balance   NOT NULL,
    fs_section              public.pxl_fs_section       NULL,
    fs_group                text                        NULL,
    fs_line_mapping         text                        NULL,
    fs_sort_order           integer                     NULL,
    cash_flow_category      public.pxl_cash_flow_category NULL,
    is_cash_equivalent      boolean                     NOT NULL DEFAULT false,
    control_account_type    public.pxl_control_account_type NULL,
    vat_account_type        text                        NULL
        CHECK (vat_account_type IN ('input_vat', 'output_vat', 'vat_payable', 'input_vat_deferred', 'input_vat_capital_goods')),
    is_mcit_gross_income    boolean                     NOT NULL DEFAULT false,
    is_osd_gross_revenue    boolean                     NOT NULL DEFAULT false,
    tax_deductibility       public.pxl_tax_deductibility NOT NULL DEFAULT 'fully_deductible',
    is_active               boolean                     NOT NULL DEFAULT true,
    import_batch_id         uuid                        NULL,
    -- FK to import_batches(id) deferred to Migration 010
    created_at              timestamptz                 NOT NULL DEFAULT now(),
    created_by              uuid                        NOT NULL REFERENCES public.profiles(id),
    updated_at              timestamptz                 NULL,
    updated_by              uuid                        NULL     REFERENCES public.profiles(id),
    deleted_at              timestamptz                 NULL,
    deleted_by              uuid                        NULL     REFERENCES public.profiles(id),

    CONSTRAINT uq_chart_of_accounts_company_code UNIQUE (company_id, account_code)
);

COMMENT ON TABLE  public.chart_of_accounts IS 'General ledger account master per company. Supports hierarchical structure via parent_account_id. Detail accounts (is_detail_account=true) are the only accounts that accept journal entries. Doc03 §26.';
COMMENT ON COLUMN public.chart_of_accounts.import_batch_id      IS 'FK to import_batches(id) — constraint deferred to Migration 010 when import_batches table is created.';
COMMENT ON COLUMN public.chart_of_accounts.control_account_type IS 'pxl_control_account_type: designates subsidiary-ledger control accounts (AR, AP, etc.). NULL = non-control account.';
COMMENT ON COLUMN public.chart_of_accounts.vat_account_type     IS 'Classifies VAT-specific GL accounts for automated VAT journal generation.';
COMMENT ON COLUMN public.chart_of_accounts.is_mcit_gross_income IS 'True if this account is included in MCIT gross income computation (BIR minimum corporate income tax).';
COMMENT ON COLUMN public.chart_of_accounts.is_osd_gross_revenue IS 'True if this account is included in OSD gross revenue (optional standard deduction basis).';
COMMENT ON COLUMN public.chart_of_accounts.tax_deductibility    IS 'pxl_tax_deductibility: fully_deductible, partially_deductible, non_deductible. Used for income tax expense classification.';

-- ---------------------------------------------------------------------------
-- 12. exchange_rates
-- ---------------------------------------------------------------------------
-- Immutable — no updated_* columns. New rates are inserted; old rates are not
-- modified. Effective-date versioning: one rate per currency pair per date.
-- ---------------------------------------------------------------------------
CREATE TABLE public.exchange_rates (
    id                  uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid            NOT NULL REFERENCES public.companies(id),
    base_currency_id    uuid            NOT NULL REFERENCES public.currencies(id),
    target_currency_id  uuid            NOT NULL REFERENCES public.currencies(id),
    rate                numeric(10,6)   NOT NULL CHECK (rate > 0),
    effective_date      date            NOT NULL,
    source              text            NULL,
    created_at          timestamptz     NOT NULL DEFAULT now(),
    created_by          uuid            NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT uq_exchange_rates_pair_date
        UNIQUE (company_id, base_currency_id, target_currency_id, effective_date),
    CONSTRAINT chk_exchange_rates_diff_currencies
        CHECK (base_currency_id <> target_currency_id)
);

COMMENT ON TABLE  public.exchange_rates IS 'Daily exchange rates per company. Immutable rows — new rates are inserted; historical rates are never modified. Rate lookup uses the most recent effective_date <= transaction date. Doc03 §31.';
COMMENT ON COLUMN public.exchange_rates.source IS 'Optional reference to rate source (e.g. BSP, manual, bank feed). For audit trail only.';

-- ---------------------------------------------------------------------------
-- 13. system_account_config
-- ---------------------------------------------------------------------------
-- Maps system account keys (e.g. AR_CONTROL, VAT_OUTPUT) to specific GL
-- accounts. Supports effective-date versioning and optional branch scoping.
-- ---------------------------------------------------------------------------
CREATE TABLE public.system_account_config (
    id              uuid                        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id      uuid                        NOT NULL REFERENCES public.companies(id),
    config_key      public.pxl_system_account_key NOT NULL,
    account_id      uuid                        NOT NULL REFERENCES public.chart_of_accounts(id),
    branch_id       uuid                        NULL     REFERENCES public.branches(id),
    effective_from  date                        NOT NULL,
    effective_to    date                        NULL,
    created_at      timestamptz                 NOT NULL DEFAULT now(),
    created_by      uuid                        NOT NULL REFERENCES public.profiles(id),
    updated_at      timestamptz                 NULL,
    updated_by      uuid                        NULL     REFERENCES public.profiles(id),
    deleted_at      timestamptz                 NULL,
    deleted_by      uuid                        NULL     REFERENCES public.profiles(id),

    CONSTRAINT uq_system_account_config_key_branch_from
        UNIQUE (company_id, config_key, branch_id, effective_from),
    CONSTRAINT chk_system_account_config_dates
        CHECK (effective_to IS NULL OR effective_to > effective_from)
);

COMMENT ON TABLE  public.system_account_config IS 'Maps pxl_system_account_key values to company GL accounts with effective-date versioning. The posting engine looks up accounts by config_key at transaction time. Doc03 §32.';
COMMENT ON COLUMN public.system_account_config.config_key    IS 'pxl_system_account_key: 17 UPPERCASE keys (AR_CONTROL, AP_CONTROL, VAT_OUTPUT, etc.) identifying system-managed GL accounts.';
COMMENT ON COLUMN public.system_account_config.branch_id     IS 'NULL = company-wide default. Non-null = branch-specific override for this key.';
COMMENT ON COLUMN public.system_account_config.effective_from IS 'Inclusive start date. Application selects the row with the most recent effective_from <= transaction date.';
COMMENT ON COLUMN public.system_account_config.effective_to  IS 'Exclusive end date. NULL = currently active.';

-- =============================================================================
-- GROUP D — ORGANIZATION EXTENDED
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 14. company_compliance_profiles
-- ---------------------------------------------------------------------------
-- Effective-date versioned compliance settings per company. Exactly one active
-- row per company (effective_to IS NULL) via partial unique index.
-- ---------------------------------------------------------------------------
CREATE TABLE public.company_compliance_profiles (
    id                          uuid                        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id                  uuid                        NOT NULL REFERENCES public.companies(id),
    taxpayer_type               public.pxl_taxpayer_type    NOT NULL,
    income_tax_regime           public.pxl_income_tax_regime NOT NULL,
    deduction_method            public.pxl_deduction_method NOT NULL DEFAULT 'itemized',
    legal_type                  public.pxl_legal_type       NOT NULL,
    withholding_agent_status    text                        NOT NULL DEFAULT 'registered'
        CHECK (withholding_agent_status IN ('registered', 'not_registered')),
    rdo_code                    text                        NOT NULL,
    bir_registered_at           date                        NOT NULL,
    filing_obligations          text[]                      NOT NULL DEFAULT '{}',
    effective_from              date                        NOT NULL,
    effective_to                date                        NULL,
    notes                       text                        NULL,
    created_at                  timestamptz                 NOT NULL DEFAULT now(),
    created_by                  uuid                        NOT NULL REFERENCES public.profiles(id),
    updated_at                  timestamptz                 NULL,
    updated_by                  uuid                        NULL     REFERENCES public.profiles(id),
    deleted_at                  timestamptz                 NULL,
    deleted_by                  uuid                        NULL     REFERENCES public.profiles(id),

    CONSTRAINT uq_company_compliance_profiles_from
        UNIQUE (company_id, effective_from),
    CONSTRAINT chk_company_compliance_profiles_dates
        CHECK (effective_to IS NULL OR effective_to > effective_from)
);

-- Partial unique: only one active compliance profile per company
CREATE UNIQUE INDEX uq_company_compliance_profiles_active
    ON public.company_compliance_profiles (company_id)
    WHERE effective_to IS NULL;

COMMENT ON TABLE  public.company_compliance_profiles IS 'Effective-date versioned BIR compliance settings per company. Exactly one active row per company (effective_to IS NULL). Drives tax computation and BIR filing generation. Doc03 §13.';
COMMENT ON COLUMN public.company_compliance_profiles.filing_obligations IS 'Array of BIR form codes this company is required to file (e.g. {''2550Q'', ''1702RT'', ''1601-EQ''}).';
COMMENT ON COLUMN public.company_compliance_profiles.effective_from     IS 'Date this compliance profile takes effect; application uses most recent effective_from <= transaction date.';

-- ---------------------------------------------------------------------------
-- 15. company_feature_settings
-- ---------------------------------------------------------------------------
-- One row per company (unique on company_id). Feature flags for optional modules.
-- ---------------------------------------------------------------------------
CREATE TABLE public.company_feature_settings (
    id                      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id              uuid        NOT NULL UNIQUE REFERENCES public.companies(id),
    inventory_enabled       boolean     NOT NULL DEFAULT false,
    fixed_assets_enabled    boolean     NOT NULL DEFAULT false,
    petty_cash_enabled      boolean     NOT NULL DEFAULT false,
    bank_recon_enabled      boolean     NOT NULL DEFAULT true,
    budgeting_enabled       boolean     NOT NULL DEFAULT false,
    created_at              timestamptz NOT NULL DEFAULT now(),
    created_by              uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at              timestamptz NULL,
    updated_by              uuid        NULL     REFERENCES public.profiles(id),
    deleted_at              timestamptz NULL,
    deleted_by              uuid        NULL     REFERENCES public.profiles(id)
);

COMMENT ON TABLE  public.company_feature_settings IS 'Feature flag toggles per company. Controls which optional ERP modules are visible and accessible for a given tenant. One row per company. Doc03 §14.';

-- ---------------------------------------------------------------------------
-- 16. cas_registrations
-- ---------------------------------------------------------------------------
-- BIR Certificate of Authority to print (CAS) or use computerized accounting
-- system registrations. Immutable records — no update columns.
-- ---------------------------------------------------------------------------
CREATE TABLE public.cas_registrations (
    id                      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id              uuid        NOT NULL REFERENCES public.companies(id),
    cas_permit_no           text        NOT NULL,
    date_issued             date        NOT NULL,
    date_valid_from         date        NOT NULL,
    date_valid_to           date        NULL,
    system_name             text        NOT NULL DEFAULT 'PXL ERP',
    components_covered      text[]      NOT NULL,
    bir_rdo_code            text        NOT NULL,
    bir_form_submitted      text        NULL,
    is_active               boolean     NOT NULL DEFAULT true,
    created_at              timestamptz NOT NULL DEFAULT now(),
    created_by              uuid        NOT NULL REFERENCES public.profiles(id)
);

COMMENT ON TABLE  public.cas_registrations IS 'BIR Certificate of Authority to use a computerized accounting system. Immutable records per BIR compliance audit trail. Active registration governs valid document series. Doc03 §14b.';
COMMENT ON COLUMN public.cas_registrations.components_covered IS 'BIR-approved system components (e.g. {''Sales'', ''Purchases'', ''Payroll''}).';
COMMENT ON COLUMN public.cas_registrations.cas_permit_no     IS 'BIR-issued permit number; identifies the registered CAS.';

-- ---------------------------------------------------------------------------
-- 17. company_bank_accounts
-- ---------------------------------------------------------------------------
CREATE TABLE public.company_bank_accounts (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id      uuid        NOT NULL REFERENCES public.companies(id),
    branch_id       uuid        NULL     REFERENCES public.branches(id),
    bank_name       text        NOT NULL,
    bank_branch     text        NULL,
    account_name    text        NOT NULL,
    account_number  text        NOT NULL,
    account_type    text        NOT NULL
        CHECK (account_type IN ('checking', 'savings', 'time_deposit')),
    currency_id     uuid        NOT NULL REFERENCES public.currencies(id),
    gl_account_id   uuid        NULL     REFERENCES public.chart_of_accounts(id),
    is_active       boolean     NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    created_by      uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at      timestamptz NULL,
    updated_by      uuid        NULL     REFERENCES public.profiles(id),
    deleted_at      timestamptz NULL,
    deleted_by      uuid        NULL     REFERENCES public.profiles(id)
);

COMMENT ON TABLE  public.company_bank_accounts IS 'Company bank accounts linked to GL cash/bank accounts. Used by bank reconciliation and payment modules. Doc03 §14a.';
COMMENT ON COLUMN public.company_bank_accounts.gl_account_id IS 'Optional link to the corresponding GL chart-of-accounts entry; NULL until GL account is configured.';

-- =============================================================================
-- GROUP E — SECURITY (MODULE 1)
-- =============================================================================
-- Per Doc09: Module 1 security tables use auth.users(id) FKs for user_id,
-- granted_by, and revoked_by columns — NOT profiles(id). This avoids a
-- chicken-and-egg problem at user creation time and matches Supabase auth.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 18. roles
-- ---------------------------------------------------------------------------
-- System roles (is_system=true) are shared across companies (company_id NULL).
-- Company roles are scoped to a specific company.
-- ---------------------------------------------------------------------------
CREATE TABLE public.roles (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id  uuid        NULL     REFERENCES public.companies(id),
    role_code   text        NOT NULL,
    role_name   text        NOT NULL,
    description text        NULL,
    is_system   boolean     NOT NULL DEFAULT false,
    is_active   boolean     NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NULL     REFERENCES auth.users(id),
    deleted_at  timestamptz NULL
);

COMMENT ON TABLE  public.roles IS 'Role definitions for RBAC. System roles (is_system=true, company_id NULL) are platform-wide; company roles are tenant-scoped. Doc09 §4.';
COMMENT ON COLUMN public.roles.company_id IS 'NULL for system roles shared across all companies; non-null for company-specific custom roles.';
COMMENT ON COLUMN public.roles.created_by IS 'References auth.users (not profiles) to allow system role seeding before profiles exist.';

-- ---------------------------------------------------------------------------
-- 19. permissions
-- ---------------------------------------------------------------------------
-- Static seed table. No audit columns — immutable platform data.
-- ---------------------------------------------------------------------------
CREATE TABLE public.permissions (
    id              uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    permission_code text    NOT NULL UNIQUE,
    module          text    NOT NULL,
    action          public.pxl_permission_action NOT NULL,
    resource        text    NOT NULL,
    description     text    NOT NULL
);

COMMENT ON TABLE  public.permissions IS 'Enumerated permission definitions; seeded by platform and never modified at runtime. Immutable — no audit columns. Doc09 §4.';
COMMENT ON COLUMN public.permissions.permission_code IS 'Canonical dot-notation code, e.g. sales.invoices.create. Must be globally unique.';
COMMENT ON COLUMN public.permissions.action          IS 'pxl_permission_action: create, read, update, delete, post, void, approve, export, etc.';

-- ---------------------------------------------------------------------------
-- 20. role_permissions
-- ---------------------------------------------------------------------------
CREATE TABLE public.role_permissions (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id         uuid        NOT NULL REFERENCES public.roles(id),
    permission_id   uuid        NOT NULL REFERENCES public.permissions(id),
    granted_at      timestamptz NOT NULL DEFAULT now(),
    granted_by      uuid        NOT NULL REFERENCES auth.users(id),
    deleted_at      timestamptz NULL,

    CONSTRAINT uq_role_permissions UNIQUE (role_id, permission_id)
);

COMMENT ON TABLE  public.role_permissions IS 'Many-to-many junction between roles and permissions. Soft-deleted via deleted_at when a permission is revoked from a role. Doc09 §4.';

-- ---------------------------------------------------------------------------
-- 21. user_roles
-- ---------------------------------------------------------------------------
CREATE TABLE public.user_roles (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL REFERENCES auth.users(id),
    role_id     uuid        NOT NULL REFERENCES public.roles(id),
    company_id  uuid        NOT NULL REFERENCES public.companies(id),
    branch_id   uuid        NULL     REFERENCES public.branches(id),
    granted_by  uuid        NOT NULL REFERENCES auth.users(id),
    granted_at  timestamptz NOT NULL DEFAULT now(),
    expires_at  timestamptz NULL,
    revoked_at  timestamptz NULL,
    revoked_by  uuid        NULL     REFERENCES auth.users(id),
    is_active   boolean     NOT NULL DEFAULT true
);

-- Partial unique: a user may hold a role in a company+branch combo only once while active
CREATE UNIQUE INDEX uq_user_roles_active
    ON public.user_roles (user_id, role_id, company_id, branch_id)
    WHERE is_active = true;

COMMENT ON TABLE  public.user_roles IS 'Assigns roles to users within a company scope, optionally scoped to a branch. is_active=false replaces hard delete for audit trail preservation. Doc09 §5.';
COMMENT ON COLUMN public.user_roles.expires_at IS 'Optional role expiry; application treats expired rows as inactive. NULL = no expiry.';

-- ---------------------------------------------------------------------------
-- 22. user_company_access
-- ---------------------------------------------------------------------------
CREATE TABLE public.user_company_access (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid        NOT NULL REFERENCES auth.users(id),
    company_id          uuid        NOT NULL REFERENCES public.companies(id),
    is_company_admin    boolean     NOT NULL DEFAULT false,
    is_active           boolean     NOT NULL DEFAULT true,
    granted_by          uuid        NOT NULL REFERENCES auth.users(id),
    granted_at          timestamptz NOT NULL DEFAULT now(),
    revoked_at          timestamptz NULL,
    revoked_by          uuid        NULL     REFERENCES auth.users(id),

    CONSTRAINT uq_user_company_access UNIQUE (user_id, company_id)
);

COMMENT ON TABLE  public.user_company_access IS 'Controls which companies a user can access. Required for company-level RLS. auth.user_company_ids() (Migration 017) queries this table. Doc09 §5.';
COMMENT ON COLUMN public.user_company_access.is_company_admin IS 'Company-level admin; can manage users and settings within the company but cannot bypass global RLS.';

-- ---------------------------------------------------------------------------
-- 23. user_branch_access
-- ---------------------------------------------------------------------------
CREATE TABLE public.user_branch_access (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL REFERENCES auth.users(id),
    company_id  uuid        NOT NULL REFERENCES public.companies(id),
    branch_id   uuid        NOT NULL REFERENCES public.branches(id),
    is_active   boolean     NOT NULL DEFAULT true,
    granted_by  uuid        NOT NULL REFERENCES auth.users(id),
    granted_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT uq_user_branch_access UNIQUE (user_id, branch_id)
);

COMMENT ON TABLE  public.user_branch_access IS 'Controls which branches a user can access (UI filter; company-level RLS is the security boundary per Doc09 Option A). auth.user_branch_ids() (Migration 017) queries this table. Doc09 §5.';

-- ---------------------------------------------------------------------------
-- 24. user_department_access
-- ---------------------------------------------------------------------------
CREATE TABLE public.user_department_access (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid        NOT NULL REFERENCES auth.users(id),
    company_id      uuid        NOT NULL REFERENCES public.companies(id),
    department_id   uuid        NOT NULL REFERENCES public.departments(id),
    is_active       boolean     NOT NULL DEFAULT true,
    granted_by      uuid        NOT NULL REFERENCES auth.users(id),
    granted_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT uq_user_department_access UNIQUE (user_id, department_id)
);

COMMENT ON TABLE  public.user_department_access IS 'Controls which departments a user can access. Used as a UI-layer filter; does not replace company-level RLS. Doc09 §5.';

-- =============================================================================
-- GROUP F — SYSTEM CONTROLS (MODULE 3)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 25. approval_matrix
-- ---------------------------------------------------------------------------
CREATE TABLE public.approval_matrix (
    id                      uuid                        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id              uuid                        NOT NULL REFERENCES public.companies(id),
    document_type           public.pxl_transaction_type NOT NULL,
    name                    text                        NOT NULL,
    amount_threshold_min    numeric(18,4)               NULL,
    amount_threshold_max    numeric(18,4)               NULL,
    approval_type           public.pxl_approval_type    NOT NULL DEFAULT 'sequential',
    is_active               boolean                     NOT NULL DEFAULT true,
    created_at              timestamptz                 NOT NULL DEFAULT now(),
    created_by              uuid                        NOT NULL REFERENCES public.profiles(id),
    updated_at              timestamptz                 NULL,
    updated_by              uuid                        NULL     REFERENCES public.profiles(id),
    deleted_at              timestamptz                 NULL,
    deleted_by              uuid                        NULL     REFERENCES public.profiles(id),

    CONSTRAINT chk_approval_matrix_threshold
        CHECK (
            amount_threshold_min IS NULL
            OR amount_threshold_max IS NULL
            OR amount_threshold_max > amount_threshold_min
        )
);

COMMENT ON TABLE  public.approval_matrix IS 'Defines approval routing rules per document type and optional amount threshold. Approval steps are defined in approval_matrix_steps. Doc03 §20.';
COMMENT ON COLUMN public.approval_matrix.approval_type IS 'pxl_approval_type: sequential (all approvers in order), parallel (any one approver), majority.';

-- ---------------------------------------------------------------------------
-- 26. approval_matrix_steps
-- ---------------------------------------------------------------------------
CREATE TABLE public.approval_matrix_steps (
    id                      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id              uuid        NOT NULL REFERENCES public.companies(id),
    approval_matrix_id      uuid        NOT NULL REFERENCES public.approval_matrix(id),
    step_order              integer     NOT NULL,
    approver_role_id        uuid        NULL     REFERENCES public.roles(id),
    approver_user_id        uuid        NULL     REFERENCES public.profiles(id),
    escalate_after_hours    integer     NULL,
    escalate_to_user_id     uuid        NULL     REFERENCES public.profiles(id),
    is_required             boolean     NOT NULL DEFAULT true,
    created_at              timestamptz NOT NULL DEFAULT now(),
    created_by              uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at              timestamptz NULL,
    updated_by              uuid        NULL     REFERENCES public.profiles(id),
    deleted_at              timestamptz NULL,
    deleted_by              uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT chk_approval_matrix_steps_approver
        CHECK (approver_role_id IS NOT NULL OR approver_user_id IS NOT NULL)
);

COMMENT ON TABLE  public.approval_matrix_steps IS 'Individual steps within an approval matrix. Either a role or a specific user must be designated as approver per step. Doc03 §21.';
COMMENT ON COLUMN public.approval_matrix_steps.step_order         IS 'Execution sequence (1, 2, 3…) for sequential approval type. Lower values are requested first.';
COMMENT ON COLUMN public.approval_matrix_steps.escalate_after_hours IS 'If set, the approval escalates to escalate_to_user_id after this many hours without action.';

-- ---------------------------------------------------------------------------
-- 27. number_series
-- ---------------------------------------------------------------------------
-- Document numbering configuration per series type and company/branch.
-- Number allocation (next_sequence increment) is done via Supabase Edge
-- Functions using SELECT FOR UPDATE — not a DB stored procedure (Doc06 §6.11).
-- ---------------------------------------------------------------------------
CREATE TABLE public.number_series (
    id                  uuid                        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid                        NOT NULL REFERENCES public.companies(id),
    branch_id           uuid                        NULL     REFERENCES public.branches(id),
    series_type         public.pxl_series_type      NOT NULL,
    prefix              text                        NOT NULL,
    padding_length      integer                     NOT NULL DEFAULT 6,
    next_sequence       bigint                      NOT NULL DEFAULT 1,
    min_value           bigint                      NOT NULL DEFAULT 1,
    max_value           bigint                      NOT NULL DEFAULT 999999999,
    reset_frequency     public.pxl_reset_frequency  NULL,
    last_reset_at       timestamptz                 NULL,
    is_active           boolean                     NOT NULL DEFAULT true,
    created_at          timestamptz                 NOT NULL DEFAULT now(),
    created_by          uuid                        NOT NULL REFERENCES public.profiles(id),
    updated_at          timestamptz                 NULL,
    updated_by          uuid                        NULL     REFERENCES public.profiles(id),
    deleted_at          timestamptz                 NULL,
    deleted_by          uuid                        NULL     REFERENCES public.profiles(id),

    CONSTRAINT chk_number_series_range
        CHECK (next_sequence >= min_value AND max_value > min_value)
);

-- Partial unique: one active series per type per company+branch
CREATE UNIQUE INDEX uq_number_series_active
    ON public.number_series (company_id, branch_id, series_type)
    WHERE is_active = true;

COMMENT ON TABLE  public.number_series IS 'Document number series configuration per pxl_series_type and company/branch. Sequence allocation uses SELECT FOR UPDATE in Edge Functions (Doc06 §6.11) to prevent duplicates under concurrency. Doc03 §15.';
COMMENT ON COLUMN public.number_series.next_sequence IS 'The next sequence number to issue. Incremented atomically by the number allocation Edge Function.';

-- ---------------------------------------------------------------------------
-- 28. number_series_atp
-- ---------------------------------------------------------------------------
-- BIR Authority to Print records. Immutable — no updated_* columns.
-- ---------------------------------------------------------------------------
CREATE TABLE public.number_series_atp (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES public.companies(id),
    number_series_id    uuid        NOT NULL REFERENCES public.number_series(id),
    atp_no              text        NOT NULL,
    series_from         bigint      NOT NULL,
    series_to           bigint      NOT NULL,
    valid_until         date        NULL,
    approved_at         date        NOT NULL,
    is_active           boolean     NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    created_by          uuid        NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT chk_number_series_atp_range CHECK (series_to > series_from)
);

COMMENT ON TABLE  public.number_series_atp IS 'BIR Authority to Print (ATP) records per number series. Immutable — new records are inserted when ATP is renewed; old records are deactivated via is_active. Doc03 §16.';
COMMENT ON COLUMN public.number_series_atp.atp_no      IS 'BIR-issued Authority to Print permit number.';
COMMENT ON COLUMN public.number_series_atp.series_from IS 'Inclusive start of the BIR-authorized number range.';
COMMENT ON COLUMN public.number_series_atp.series_to   IS 'Inclusive end of the BIR-authorized number range.';

-- ---------------------------------------------------------------------------
-- 29. atp_usage_logs
-- ---------------------------------------------------------------------------
-- Insert-only audit log. No standard audit columns — used_by / used_at serve
-- the same purpose and the table is never updated or soft-deleted.
-- ---------------------------------------------------------------------------
CREATE TABLE public.atp_usage_logs (
    id                      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id              uuid        NOT NULL REFERENCES public.companies(id),
    number_series_atp_id    uuid        NOT NULL REFERENCES public.number_series_atp(id),
    allocated_number        bigint      NOT NULL,
    document_no             text        NOT NULL,
    entity_type             text        NOT NULL,
    entity_id               uuid        NOT NULL,
    used_by                 uuid        NOT NULL REFERENCES public.profiles(id),
    used_at                 timestamptz NOT NULL DEFAULT now(),
    is_voided               boolean     NOT NULL DEFAULT false
);

COMMENT ON TABLE  public.atp_usage_logs IS 'Insert-only audit log of BIR ATP number allocations. One row per document number issued. is_voided=true when the associated document is voided (number is consumed, not reused). Doc03 §17.';
COMMENT ON COLUMN public.atp_usage_logs.entity_type IS 'Name of the entity table that consumed this number (e.g. ''sales_invoices'', ''official_receipts'').';

-- ---------------------------------------------------------------------------
-- 30. document_controls
-- ---------------------------------------------------------------------------
CREATE TABLE public.document_controls (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES public.companies(id),
    document_type       text        NOT NULL,
    allows_void         boolean     NOT NULL DEFAULT true,
    allows_reversal     boolean     NOT NULL DEFAULT true,
    requires_approval   boolean     NOT NULL DEFAULT false,
    auto_post           boolean     NOT NULL DEFAULT false,
    editable_statuses   text[]      NOT NULL DEFAULT '{draft}',
    void_requires_reason boolean    NOT NULL DEFAULT true,
    created_at          timestamptz NOT NULL DEFAULT now(),
    created_by          uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at          timestamptz NULL,
    updated_by          uuid        NULL     REFERENCES public.profiles(id),
    deleted_at          timestamptz NULL,
    deleted_by          uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT uq_document_controls UNIQUE (company_id, document_type)
);

COMMENT ON TABLE  public.document_controls IS 'Per-company configuration of document lifecycle rules (void, reversal, approval, auto-post). One row per document type per company. Doc03 §19.';
COMMENT ON COLUMN public.document_controls.editable_statuses IS 'Array of document statuses that allow field edits (e.g. {''draft'', ''pending_approval''}). Enforced by application layer.';

-- ---------------------------------------------------------------------------
-- 31. validation_rules
-- ---------------------------------------------------------------------------
CREATE TABLE public.validation_rules (
    id                  uuid                            PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid                            NOT NULL REFERENCES public.companies(id),
    rule_code           text                            NOT NULL,
    document_type       text                            NOT NULL,
    rule_expression     text                            NOT NULL,
    error_message       text                            NOT NULL,
    severity            public.pxl_validation_severity  NOT NULL DEFAULT 'error',
    is_active           boolean                         NOT NULL DEFAULT true,
    created_at          timestamptz                     NOT NULL DEFAULT now(),
    created_by          uuid                            NOT NULL REFERENCES public.profiles(id),
    updated_at          timestamptz                     NULL,
    updated_by          uuid                            NULL     REFERENCES public.profiles(id),
    deleted_at          timestamptz                     NULL,
    deleted_by          uuid                            NULL     REFERENCES public.profiles(id),

    CONSTRAINT uq_validation_rules UNIQUE (company_id, rule_code)
);

COMMENT ON TABLE  public.validation_rules IS 'Configurable business rule expressions evaluated at document save/post time. Severity error blocks the operation; warning allows with acknowledgment. Doc03 §21b.';
COMMENT ON COLUMN public.validation_rules.rule_expression IS 'SQL-compatible boolean expression or named rule reference evaluated by the validation engine.';
COMMENT ON COLUMN public.validation_rules.severity        IS 'pxl_validation_severity: error (blocks action), warning (requires acknowledgment), info (display only).';

-- ---------------------------------------------------------------------------
-- 32. system_parameters
-- ---------------------------------------------------------------------------
CREATE TABLE public.system_parameters (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id  uuid        NOT NULL REFERENCES public.companies(id),
    param_key   text        NOT NULL,
    param_value text        NOT NULL,
    description text        NULL,
    is_system   boolean     NOT NULL DEFAULT false,
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NULL,
    updated_by  uuid        NULL     REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT uq_system_parameters UNIQUE (company_id, param_key)
);

COMMENT ON TABLE  public.system_parameters IS 'Key-value configuration store per company. is_system=true parameters are managed by the platform and cannot be deleted by tenant admins. Doc03 §22.';
COMMENT ON COLUMN public.system_parameters.is_system IS 'True = platform-managed parameter; tenant admins may read but not delete. Application layer enforces this restriction.';

-- =============================================================================
-- EXPECTED OBJECTS CREATED
-- =============================================================================
--   Schema modified : public (existing)
--   Tables          : 32
--
--     Group A — Bootstrap
--       public.account_types
--       public.profiles
--       public.currencies
--
--     Group B — Organization
--       public.companies
--       public.branches
--       public.departments
--       public.cost_centers
--
--     Group C — Accounting Setup
--       public.fiscal_years
--       public.fiscal_periods
--       public.fiscal_locks
--       public.chart_of_accounts
--       public.exchange_rates
--       public.system_account_config
--
--     Group D — Organization Extended
--       public.company_compliance_profiles
--       public.company_feature_settings
--       public.cas_registrations
--       public.company_bank_accounts
--
--     Group E — Security
--       public.roles
--       public.permissions
--       public.role_permissions
--       public.user_roles
--       public.user_company_access
--       public.user_branch_access
--       public.user_department_access
--
--     Group F — System Controls
--       public.approval_matrix
--       public.approval_matrix_steps
--       public.number_series
--       public.number_series_atp
--       public.atp_usage_logs
--       public.document_controls
--       public.validation_rules
--       public.system_parameters
--
--   Partial Indexes : 4
--     uq_fiscal_years_current
--     uq_company_compliance_profiles_active
--     uq_user_roles_active
--     uq_number_series_active
--
--   Triggers  : 0  (deferred to Migration 019)
--   RLS       : 0  (deferred to Migration 017)
--   Seed Data : 0  (deferred to Migration 020+)
-- =============================================================================
