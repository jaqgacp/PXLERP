-- =============================================================================
-- Migration 011 — Fixed Assets
-- Module 15: Fixed Assets (Doc02 §15, Doc03 §24)
-- Tables: 119–128 (10 tables)
-- =============================================================================
--
-- Depends on:
--   001_extensions.sql   — pgcrypto / gen_random_uuid()
--   002_enums.sql        — (no FA-specific enums; method/status enforced via CHECK)
--   003_shared_functions.sql
--   004_core_setup.sql   — companies, branches, departments, cost_centers,
--                          fiscal_years, fiscal_periods, currencies, profiles
--   005_tax_setup.sql
--   006_master_data.sql  — suppliers, items (item_type='fixed_asset' supported)
--   007_sales.sql
--   008_purchasing.sql   — vendor_bills, payment_vouchers (referenced by asset_acquisitions)
--   009_petty_cash_bank.sql
--   010_inventory.sql
--
-- Deferred FK dependencies (cannot reference yet):
--   chart_of_accounts    → Migration 012 (GL/Accounting)
--     Columns deferred:
--       asset_categories.depreciation_expense_account_id
--       fixed_assets.asset_account_id
--       fixed_assets.depreciation_account_id
--       fixed_assets.accumulated_depreciation_account_id
--       asset_disposals.disposal_account_id
--   journal_entries      → Migration 016 (Journal Entries)
--     Columns deferred:
--       asset_acquisitions.journal_entry_id
--       depreciation_run_lines.journal_entry_id
--       asset_disposals.journal_entry_id
--       asset_transfers.journal_entry_id
--       asset_impairments.journal_entry_id
--   import_batches       → Migration 023 (Import Engine)
--     Columns deferred:
--       import_batch_id on all transaction headers
--
-- Immutability conventions:
--   Immutable=YES  → only created_at + created_by; no updated_*, no deleted_*
--   Immutable=NO   → full standard audit (created/updated/deleted)
--
-- GL linkage for Fixed Assets:
--   - asset_acquisitions, asset_disposals, asset_transfers, asset_impairments
--     carry journal_entry_id (standard transaction header pattern).
--   - depreciation_run_lines carry journal_entry_id (one JE per line per period).
--   - FA subsidiary ledger entries are written by the posting engine into
--     subsidiary_ledger_entries (ledger_type='fixed_asset') in Migration 016.
--
-- =============================================================================

-- =============================================================================
-- GROUP A: Master Data — Soft Delete=YES, Immutable=NO
-- =============================================================================

-- #120 depreciation_profiles
-- Defines depreciation method, rate, and useful life used by fixed assets.
-- Per Doc03 §24. Soft Delete=YES. Immutable=NO.
CREATE TABLE public.depreciation_profiles (
    id                  uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid          NOT NULL REFERENCES public.companies(id),
    code                text          NOT NULL,
    name                text          NOT NULL,
    -- Depreciation method: straight_line, declining_balance, sum_of_years_digits,
    -- units_of_production. Determines the depreciation computation algorithm used
    -- by the depreciation runner.
    method              text          NOT NULL,
    -- Total useful life in months (e.g., 60 = 5 years). Used by posting engine
    -- to generate asset_depreciation_schedules at asset acquisition.
    useful_life_months  integer       NOT NULL,
    -- Residual value as a percentage of original cost (e.g., 0.10 = 10%).
    -- salvage_value = cost * salvage_rate; depreciable base = cost - salvage_value.
    salvage_rate        numeric(10,6) NOT NULL DEFAULT 0,
    is_active           boolean       NOT NULL DEFAULT true,
    -- standard audit (Soft Delete=YES, Immutable=NO)
    created_at          timestamptz   NOT NULL DEFAULT now(),
    created_by          uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at          timestamptz   NULL,
    updated_by          uuid          NULL     REFERENCES public.profiles(id),
    deleted_at          timestamptz   NULL,
    deleted_by          uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_depreciation_profiles PRIMARY KEY (id),
    CONSTRAINT uq_depreciation_profiles_code UNIQUE (company_id, code),
    CONSTRAINT ck_dp_method CHECK (
        method IN ('straight_line','declining_balance','sum_of_years_digits','units_of_production')
    ),
    CONSTRAINT ck_dp_useful_life CHECK (useful_life_months > 0),
    CONSTRAINT ck_dp_salvage_rate CHECK (salvage_rate >= 0 AND salvage_rate < 1)
);

COMMENT ON TABLE public.depreciation_profiles IS
    'Depreciation method + rate + useful life configurations. Referenced by asset_categories '
    '(default) and fixed_assets (per-asset override). Doc03 §24 table #120.';
COMMENT ON COLUMN public.depreciation_profiles.salvage_rate IS
    'Fraction of original cost retained as residual/salvage value (0 = fully depreciated). '
    'Depreciable base = cost × (1 − salvage_rate).';
COMMENT ON COLUMN public.depreciation_profiles.useful_life_months IS
    'Total useful life in months. Posting engine uses this to generate the full '
    'asset_depreciation_schedules at asset activation.';

CREATE INDEX ix_depreciation_profiles_company
    ON public.depreciation_profiles (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.depreciation_profiles ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #119 asset_categories
-- Fixed asset category master (Land, Building, Equipment, Vehicle, etc.).
-- Each category may define a default depreciation profile and GL accounts used
-- by the posting engine. Doc03 §24 table #119. Soft Delete=YES. Immutable=NO.
--
-- NOTE (Backlog M-011-1): Doc03 column spec does NOT list depreciation_expense_account_id.
-- Doc06 §Asset Depreciation Posting explicitly reads
-- asset_categories.depreciation_expense_account_id as the FROM_ITEM source for
-- DR Depreciation Expense. The column is included here per Doc06 (frozen posting
-- engine spec is authoritative for GL account linkage requirements).
-- FK to chart_of_accounts is DEFERRED to Migration 012.
CREATE TABLE public.asset_categories (
    id                                  uuid    NOT NULL DEFAULT gen_random_uuid(),
    company_id                          uuid    NOT NULL REFERENCES public.companies(id),
    code                                text    NOT NULL,
    name                                text    NOT NULL,
    -- Default depreciation profile applied to new assets in this category.
    -- Can be overridden per individual fixed_asset record.
    default_depreciation_profile_id     uuid    NULL     REFERENCES public.depreciation_profiles(id),
    -- Depreciation Expense account (DR on depreciation posting).
    -- FK → chart_of_accounts.id — deferred to Migration 012.
    -- Doc06 §Asset Depreciation Posting: FROM_ITEM (asset category).
    depreciation_expense_account_id     uuid    NULL,
    is_active                           boolean NOT NULL DEFAULT true,
    -- standard audit (Soft Delete=YES, Immutable=NO)
    created_at                          timestamptz NOT NULL DEFAULT now(),
    created_by                          uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at                          timestamptz NULL,
    updated_by                          uuid        NULL     REFERENCES public.profiles(id),
    deleted_at                          timestamptz NULL,
    deleted_by                          uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_asset_categories PRIMARY KEY (id),
    CONSTRAINT uq_asset_categories_code UNIQUE (company_id, code)
);

COMMENT ON TABLE public.asset_categories IS
    'Fixed asset categories (Land, Building, Equipment, Vehicle, etc.). '
    'Each category carries a default depreciation profile and GL expense account. '
    'Doc03 §24 table #119.';
COMMENT ON COLUMN public.asset_categories.depreciation_expense_account_id IS
    'GL account for DR Depreciation Expense on each depreciation posting. '
    'FK → chart_of_accounts.id — FK constraint added in Migration 012. '
    'Per Doc06 §Asset Depreciation Posting (FROM_ITEM asset category pattern).';
COMMENT ON COLUMN public.asset_categories.default_depreciation_profile_id IS
    'Default profile applied to new assets. Overridable per asset record.';

CREATE INDEX ix_asset_categories_company
    ON public.asset_categories (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.asset_categories ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #121 fixed_assets
-- Fixed asset register. Each row is one asset. Mutable until disposed.
-- accumulated_depreciation and net_book_value are updated by the posting engine
-- after each depreciation run and on disposal/impairment.
-- Doc03 §24 table #121. Soft Delete=YES. Immutable=NO.
--
-- Doc03/Doc06 discrepancy (Backlog M-011-2):
--   Doc03 uses is_active + is_disposed boolean flags.
--   Doc06 refers to fixed_assets.status ('pending','active','disposed').
--   Implementing Doc03 boolean pattern as specified. See backlog M-011-2.
--
-- Deferred FK columns (chart_of_accounts — Migration 012):
--   asset_account_id                    — DR Fixed Asset at Cost on acquisition
--   depreciation_account_id             — CR Depreciation Expense (alternative per-asset override)
--   accumulated_depreciation_account_id — CR Accumulated Depreciation on depreciation posting
CREATE TABLE public.fixed_assets (
    id                                  uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id                          uuid          NOT NULL REFERENCES public.companies(id),
    branch_id                           uuid          NULL     REFERENCES public.branches(id),
    department_id                       uuid          NULL     REFERENCES public.departments(id),
    -- Unique asset number within the company (e.g., 'FA-2024-001').
    asset_no                            text          NOT NULL,
    category_id                         uuid          NOT NULL REFERENCES public.asset_categories(id),
    acquisition_date                    date          NOT NULL,
    -- Original acquisition cost (immutable after first posting).
    cost                                numeric(18,4) NOT NULL,
    -- Running accumulated depreciation balance. Updated by posting engine
    -- after each depreciation_run_lines post and on impairment/disposal.
    accumulated_depreciation            numeric(18,4) NOT NULL DEFAULT 0,
    -- Net book value = cost − accumulated_depreciation.
    -- Maintained by posting engine. Must satisfy the invariant on every update.
    net_book_value                      numeric(18,4) NOT NULL,
    depreciation_profile_id             uuid          NOT NULL REFERENCES public.depreciation_profiles(id),
    -- GL accounts (FKs deferred to Migration 012 — chart_of_accounts):
    -- asset_account_id: Fixed Asset at Cost account (e.g., 16100 Property, Plant & Equipment)
    asset_account_id                    uuid          NOT NULL,
    -- depreciation_account_id: Depreciation Expense account (per-asset override;
    -- if NULL the posting engine falls back to asset_categories.depreciation_expense_account_id)
    depreciation_account_id             uuid          NULL,
    -- accumulated_depreciation_account_id: Accumulated Depreciation contra-asset account
    accumulated_depreciation_account_id uuid          NOT NULL,
    -- Physical location description (building, floor, room, site).
    location                            text          NULL,
    -- Manufacturer or vendor serial number for physical identification.
    serial_no                           text          NULL,
    -- Set to true by posting engine when asset_disposals record is posted.
    is_disposed                         boolean       NOT NULL DEFAULT false,
    is_active                           boolean       NOT NULL DEFAULT true,
    -- standard audit (Soft Delete=YES, Immutable=NO)
    created_at                          timestamptz   NOT NULL DEFAULT now(),
    created_by                          uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at                          timestamptz   NULL,
    updated_by                          uuid          NULL     REFERENCES public.profiles(id),
    deleted_at                          timestamptz   NULL,
    deleted_by                          uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_fixed_assets PRIMARY KEY (id),
    CONSTRAINT uq_fixed_assets_asset_no UNIQUE (company_id, asset_no),
    CONSTRAINT ck_fa_cost CHECK (cost > 0),
    CONSTRAINT ck_fa_accum_depreciation CHECK (accumulated_depreciation >= 0),
    CONSTRAINT ck_fa_accum_lte_cost CHECK (accumulated_depreciation <= cost),
    -- Invariant: net_book_value must equal cost − accumulated_depreciation.
    -- Posting engine must update both columns atomically in a single UPDATE statement.
    CONSTRAINT ck_fa_nbv CHECK (net_book_value = cost - accumulated_depreciation)
);

COMMENT ON TABLE public.fixed_assets IS
    'Fixed asset register. One row per asset. Mutable until disposed. '
    'accumulated_depreciation and net_book_value are maintained by the posting engine '
    'and must satisfy: net_book_value = cost − accumulated_depreciation. Doc03 §24 table #121.';
COMMENT ON COLUMN public.fixed_assets.asset_account_id IS
    'GL account for Fixed Asset at Cost (e.g., 16100 PP&E). '
    'FK → chart_of_accounts.id — FK constraint added in Migration 012.';
COMMENT ON COLUMN public.fixed_assets.depreciation_account_id IS
    'Per-asset Depreciation Expense account override. NULL = use asset_categories.depreciation_expense_account_id. '
    'FK → chart_of_accounts.id — FK constraint added in Migration 012.';
COMMENT ON COLUMN public.fixed_assets.accumulated_depreciation_account_id IS
    'GL contra-asset account for Accumulated Depreciation (e.g., 16200 Accum. Depreciation). '
    'FK → chart_of_accounts.id — FK constraint added in Migration 012.';
COMMENT ON COLUMN public.fixed_assets.accumulated_depreciation IS
    'Running total of all posted depreciation amounts. Updated by posting engine '
    'on each depreciation_run_line post and on impairment. Service role only.';
COMMENT ON COLUMN public.fixed_assets.net_book_value IS
    'cost − accumulated_depreciation. Maintained atomically by posting engine. '
    'CHECK constraint enforces invariant. Service role only.';

CREATE INDEX ix_fixed_assets_company_active
    ON public.fixed_assets (company_id)
    WHERE deleted_at IS NULL AND is_disposed = false;

CREATE INDEX ix_fixed_assets_category
    ON public.fixed_assets (company_id, category_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_fixed_assets_branch
    ON public.fixed_assets (company_id, branch_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.fixed_assets ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP B: Asset Depreciation Schedule — Ledger, Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #122 asset_depreciation_schedules
-- Pre-computed depreciation schedule, one row per asset per fiscal period.
-- Generated by the posting engine at asset activation (or when the acquisition
-- is first posted). Immutable once generated. The posting engine sets
-- status = 'processed' when the period's depreciation_run_lines is posted.
-- Doc03 §24 table #122. Immutable=YES. No soft delete.
CREATE TABLE public.asset_depreciation_schedules (
    id                      uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid          NOT NULL REFERENCES public.companies(id),
    fixed_asset_id          uuid          NOT NULL REFERENCES public.fixed_assets(id),
    fiscal_period_id        uuid          NOT NULL REFERENCES public.fiscal_periods(id),
    -- Depreciation amount for this fiscal period only.
    period_depreciation     numeric(18,4) NOT NULL,
    -- Cumulative accumulated depreciation at the end of this period.
    accumulated_depreciation numeric(18,4) NOT NULL,
    -- Net book value at the end of this period.
    net_book_value_end      numeric(18,4) NOT NULL,
    -- 'pending' = not yet processed by a depreciation run.
    -- 'processed' = depreciation_run_lines has been posted for this period.
    -- Updated from 'pending' to 'processed' by the depreciation runner (service role).
    -- This is the only mutable column; the schedule row itself is otherwise immutable.
    status                  text          NOT NULL DEFAULT 'pending',
    -- Immutable audit (no updated_*, no deleted_*)
    created_at              timestamptz   NOT NULL DEFAULT now(),
    created_by              uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_asset_depreciation_schedules PRIMARY KEY (id),
    CONSTRAINT uq_ads_asset_period UNIQUE (company_id, fixed_asset_id, fiscal_period_id),
    CONSTRAINT ck_ads_status CHECK (status IN ('pending','processed')),
    CONSTRAINT ck_ads_period_depreciation CHECK (period_depreciation >= 0),
    CONSTRAINT ck_ads_accum_depreciation CHECK (accumulated_depreciation >= 0),
    CONSTRAINT ck_ads_nbv_end CHECK (net_book_value_end >= 0)
);

COMMENT ON TABLE public.asset_depreciation_schedules IS
    'Pre-computed depreciation schedule per asset per fiscal period. '
    'Generated at asset activation. Immutable once created except for status column '
    '(updated from pending to processed by depreciation runner). Doc03 §24 table #122.';
COMMENT ON COLUMN public.asset_depreciation_schedules.status IS
    'Updated to ''processed'' by the depreciation runner (service role) when the '
    'depreciation_run_lines record for this asset+period is posted. '
    'Prevents re-processing the same period. Mutable by service role only.';
COMMENT ON COLUMN public.asset_depreciation_schedules.period_depreciation IS
    'Depreciation amount for this period only (not cumulative).';

CREATE INDEX ix_ads_asset_id
    ON public.asset_depreciation_schedules (fixed_asset_id, fiscal_period_id);

CREATE INDEX ix_ads_pending
    ON public.asset_depreciation_schedules (company_id, fiscal_period_id)
    WHERE status = 'pending';

ALTER TABLE public.asset_depreciation_schedules ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP C: Asset Acquisition — Transaction, Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #123 asset_acquisitions
-- Asset acquisition transaction. Links a fixed asset to its source purchase
-- (either a direct acquisition or an AP vendor_bill route).
-- Posted acquisition triggers creation of asset_depreciation_schedules.
-- Doc03 §24 table #123. Immutable=YES. No soft delete.
CREATE TABLE public.asset_acquisitions (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid(),
    -- standard dimension columns
    company_id           uuid          NOT NULL REFERENCES public.companies(id),
    branch_id            uuid          NULL     REFERENCES public.branches(id),
    department_id        uuid          NULL     REFERENCES public.departments(id),
    cost_center_id       uuid          NULL     REFERENCES public.cost_centers(id),
    -- standard transaction header
    document_no          text          NOT NULL,
    document_date        date          NOT NULL,
    posting_date         date          NULL,
    fiscal_year_id       uuid          NOT NULL REFERENCES public.fiscal_years(id),
    fiscal_period_id     uuid          NOT NULL REFERENCES public.fiscal_periods(id),
    currency_id          uuid          NOT NULL REFERENCES public.currencies(id),
    exchange_rate        numeric(10,6) NOT NULL DEFAULT 1.000000,
    status               text          NOT NULL DEFAULT 'draft',
    subtotal_amount      numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount           numeric(18,4) NOT NULL DEFAULT 0,
    withholding_amount   numeric(18,4) NOT NULL DEFAULT 0,
    total_amount         numeric(18,4) NOT NULL DEFAULT 0,
    remarks              text          NULL,
    posted_at            timestamptz   NULL,
    posted_by            uuid          NULL     REFERENCES public.profiles(id),
    voided_at            timestamptz   NULL,
    voided_by            uuid          NULL     REFERENCES public.profiles(id),
    void_reason          text          NULL,
    reversed_by_doc_id   uuid          NULL     REFERENCES public.asset_acquisitions(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id     uuid          NULL,
    -- import_batch_id FK deferred to Migration 023
    import_batch_id      uuid          NULL,
    -- asset_acquisitions-specific
    fixed_asset_id       uuid          NOT NULL REFERENCES public.fixed_assets(id),
    -- Acquisition cost captured at the time of this transaction.
    acquisition_cost     numeric(18,4) NOT NULL,
    -- Source purchase link: vendor_bill (AP route) or payment_voucher (direct cash route).
    -- Both NULL for opening balance / data migration entries.
    vendor_bill_id       uuid          NULL     REFERENCES public.vendor_bills(id),
    payment_voucher_id   uuid          NULL     REFERENCES public.payment_vouchers(id),
    -- Immutable audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_asset_acquisitions PRIMARY KEY (id),
    CONSTRAINT uq_asset_acquisitions_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_aa_status CHECK (
        status IN ('draft','approved','posted','voided')
    ),
    CONSTRAINT ck_aa_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_aa_acquisition_cost CHECK (acquisition_cost > 0),
    CONSTRAINT ck_aa_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    ),
    -- An acquisition should not be linked to both a vendor_bill and a payment_voucher.
    CONSTRAINT ck_aa_source_exclusive CHECK (
        NOT (vendor_bill_id IS NOT NULL AND payment_voucher_id IS NOT NULL)
    )
);

COMMENT ON TABLE public.asset_acquisitions IS
    'Asset acquisition transaction. One record per asset acquisition event. '
    'Posting triggers: (a) creation of asset_depreciation_schedules for the full '
    'useful life; (b) GL journal entry (DR Fixed Asset / CR Cash or AP_TRADE). '
    'Doc03 §24 table #123. Immutable after posting.';
COMMENT ON COLUMN public.asset_acquisitions.journal_entry_id IS
    'FK → journal_entries.id — FK constraint added in Migration 016.';
COMMENT ON COLUMN public.asset_acquisitions.vendor_bill_id IS
    'Set when asset was acquired via credit purchase (AP route). '
    'vendor_bill posting handles DR Asset / CR AP_TRADE — no duplicate JE created.';
COMMENT ON COLUMN public.asset_acquisitions.payment_voucher_id IS
    'Set when asset was acquired via direct cash payment.';

CREATE INDEX ix_asset_acquisitions_company_date
    ON public.asset_acquisitions (company_id, document_date);

CREATE INDEX ix_asset_acquisitions_fixed_asset
    ON public.asset_acquisitions (fixed_asset_id);

CREATE INDEX ix_asset_acquisitions_status
    ON public.asset_acquisitions (company_id, status)
    WHERE status NOT IN ('posted','voided');

ALTER TABLE public.asset_acquisitions ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP D: Depreciation Runs — Transaction, Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #124 depreciation_runs
-- Batch header for a depreciation processing run. One run per fiscal period
-- per company. The depreciation runner processes all active assets with
-- pending asset_depreciation_schedules for the target period.
-- Doc03 §24 table #124. Immutable=YES. No soft delete.
CREATE TABLE public.depreciation_runs (
    id               uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id       uuid        NOT NULL REFERENCES public.companies(id),
    fiscal_period_id uuid        NOT NULL REFERENCES public.fiscal_periods(id),
    -- 'pending'    = created, not yet started
    -- 'processing' = currently running (prevents concurrent runs)
    -- 'completed'  = all assets processed successfully
    -- 'failed'     = one or more assets failed; see depreciation_run_lines.error_message
    status           text        NOT NULL DEFAULT 'pending',
    run_by           uuid        NOT NULL REFERENCES public.profiles(id),
    run_at           timestamptz NOT NULL DEFAULT now(),
    completed_at     timestamptz NULL,
    -- Counters set by the runner on completion.
    assets_processed integer     NOT NULL DEFAULT 0,
    assets_failed    integer     NOT NULL DEFAULT 0,
    -- standard audit (Immutable=YES — additional audit cols per Doc03 spec)
    created_at       timestamptz NOT NULL DEFAULT now(),
    created_by       uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at       timestamptz NULL,
    updated_by       uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_depreciation_runs PRIMARY KEY (id),
    -- Prevent duplicate completed runs for the same period.
    CONSTRAINT uq_depreciation_runs_period UNIQUE (company_id, fiscal_period_id)
        DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT ck_dr_status CHECK (
        status IN ('pending','processing','completed','failed')
    ),
    CONSTRAINT ck_dr_counts CHECK (assets_processed >= 0 AND assets_failed >= 0)
);

COMMENT ON TABLE public.depreciation_runs IS
    'Batch header for one depreciation processing run per company per fiscal period. '
    'The depreciation runner transitions status: pending→processing→completed|failed. '
    'Concurrent runs for the same period are prevented by the unique constraint. '
    'Doc03 §24 table #124.';
COMMENT ON COLUMN public.depreciation_runs.status IS
    'processing status prevents concurrent runs for the same period. '
    'Unique constraint is DEFERRABLE to allow the runner to update status within '
    'the same transaction that inserts the row.';

CREATE INDEX ix_depreciation_runs_company_period
    ON public.depreciation_runs (company_id, fiscal_period_id);

CREATE INDEX ix_depreciation_runs_status
    ON public.depreciation_runs (company_id, status)
    WHERE status NOT IN ('completed','failed');

ALTER TABLE public.depreciation_runs ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #125 depreciation_run_lines
-- Per-asset depreciation computed within a run. One row per asset per run.
-- Carries journal_entry_id linking to the JE posted for this depreciation.
-- Immutable once created. Doc03 §24 table #125. Immutable=YES. No soft delete.
CREATE TABLE public.depreciation_run_lines (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id           uuid          NOT NULL REFERENCES public.companies(id),
    depreciation_run_id  uuid          NOT NULL REFERENCES public.depreciation_runs(id),
    fixed_asset_id       uuid          NOT NULL REFERENCES public.fixed_assets(id),
    -- Depreciation amount computed for this asset in this run period.
    period_depreciation  numeric(18,4) NOT NULL,
    -- journal_entry_id FK deferred to Migration 016.
    -- One JE per line (DR Depreciation Expense / CR Accumulated Depreciation).
    journal_entry_id     uuid          NULL,
    -- 'pending'   = not yet posted
    -- 'processed' = JE posted; fixed_assets.accumulated_depreciation updated
    -- 'skipped'   = asset excluded (already disposed, fully depreciated, etc.)
    -- 'error'     = posting failed; see error_message
    status               text          NOT NULL DEFAULT 'pending',
    error_message        text          NULL,
    -- Immutable audit
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_depreciation_run_lines PRIMARY KEY (id),
    -- One line per asset per run
    CONSTRAINT uq_drl_run_asset UNIQUE (depreciation_run_id, fixed_asset_id),
    CONSTRAINT ck_drl_status CHECK (
        status IN ('pending','processed','skipped','error')
    ),
    CONSTRAINT ck_drl_period_depreciation CHECK (period_depreciation >= 0)
);

COMMENT ON TABLE public.depreciation_run_lines IS
    'Per-asset depreciation amount computed within a depreciation run. '
    'The posting engine writes journal_entry_id after posting DR Depreciation Expense / '
    'CR Accumulated Depreciation and updates fixed_assets.accumulated_depreciation. '
    'Doc03 §24 table #125. Immutable.';
COMMENT ON COLUMN public.depreciation_run_lines.journal_entry_id IS
    'FK → journal_entries.id — FK constraint added in Migration 016. '
    'One JE per line. Null until posting engine processes this line.';
COMMENT ON COLUMN public.depreciation_run_lines.status IS
    '''skipped'' includes: already disposed, fully depreciated (NBV = 0), or '
    'asset not yet active. ''error'' means posting failed — see error_message.';

CREATE INDEX ix_drl_run_id
    ON public.depreciation_run_lines (depreciation_run_id);

CREATE INDEX ix_drl_fixed_asset
    ON public.depreciation_run_lines (fixed_asset_id);

ALTER TABLE public.depreciation_run_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP E: Asset Disposal — Transaction, Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #126 asset_disposals
-- Records the disposal of a fixed asset (sale, write-off, or trade-in).
-- On posting the engine: (a) records gain/loss JE; (b) sets fixed_assets.is_disposed=true.
-- Doc03 §24 table #126. Immutable=YES. No soft delete.
CREATE TABLE public.asset_disposals (
    id                        uuid          NOT NULL DEFAULT gen_random_uuid(),
    -- standard dimension columns
    company_id                uuid          NOT NULL REFERENCES public.companies(id),
    branch_id                 uuid          NULL     REFERENCES public.branches(id),
    department_id             uuid          NULL     REFERENCES public.departments(id),
    cost_center_id            uuid          NULL     REFERENCES public.cost_centers(id),
    -- standard transaction header
    document_no               text          NOT NULL,
    document_date             date          NOT NULL,
    posting_date              date          NULL,
    fiscal_year_id            uuid          NOT NULL REFERENCES public.fiscal_years(id),
    fiscal_period_id          uuid          NOT NULL REFERENCES public.fiscal_periods(id),
    currency_id               uuid          NOT NULL REFERENCES public.currencies(id),
    exchange_rate             numeric(10,6) NOT NULL DEFAULT 1.000000,
    status                    text          NOT NULL DEFAULT 'draft',
    subtotal_amount           numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount                numeric(18,4) NOT NULL DEFAULT 0,
    withholding_amount        numeric(18,4) NOT NULL DEFAULT 0,
    total_amount              numeric(18,4) NOT NULL DEFAULT 0,
    remarks                   text          NULL,
    posted_at                 timestamptz   NULL,
    posted_by                 uuid          NULL     REFERENCES public.profiles(id),
    voided_at                 timestamptz   NULL,
    voided_by                 uuid          NULL     REFERENCES public.profiles(id),
    void_reason               text          NULL,
    reversed_by_doc_id        uuid          NULL     REFERENCES public.asset_disposals(id),
    source_document_id        uuid          NULL,
    source_document_type      text          NULL,
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id          uuid          NULL,
    -- import_batch_id FK deferred to Migration 023
    import_batch_id           uuid          NULL,
    -- asset_disposals-specific
    fixed_asset_id            uuid          NOT NULL REFERENCES public.fixed_assets(id),
    -- 'sale'      = sold to third party for proceeds
    -- 'write_off' = fully written off with no proceeds
    -- 'trade_in'  = traded in against a new asset purchase
    disposal_type             text          NOT NULL,
    -- Cash or fair value received. Zero for write_off.
    disposal_proceeds         numeric(18,4) NOT NULL DEFAULT 0,
    -- NBV snapshot at disposal date (cost − accumulated_depreciation at that moment).
    net_book_value_at_disposal numeric(18,4) NOT NULL,
    -- gain_loss = disposal_proceeds − net_book_value_at_disposal.
    -- Positive = gain (CR Gain on Disposal), negative = loss (DR Loss on Disposal).
    gain_loss                 numeric(18,4) NOT NULL DEFAULT 0,
    -- GL account for gain/loss on disposal (FK → chart_of_accounts.id deferred to Migration 012).
    disposal_account_id       uuid          NULL,
    -- Immutable audit
    created_at                timestamptz   NOT NULL DEFAULT now(),
    created_by                uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_asset_disposals PRIMARY KEY (id),
    CONSTRAINT uq_asset_disposals_doc UNIQUE (company_id, document_no),
    -- An asset can only be disposed once.
    CONSTRAINT uq_asset_disposals_asset UNIQUE (fixed_asset_id),
    CONSTRAINT ck_ad_status CHECK (
        status IN ('draft','approved','posted','voided')
    ),
    CONSTRAINT ck_ad_disposal_type CHECK (
        disposal_type IN ('sale','write_off','trade_in')
    ),
    CONSTRAINT ck_ad_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_ad_disposal_proceeds CHECK (disposal_proceeds >= 0),
    CONSTRAINT ck_ad_nbv CHECK (net_book_value_at_disposal >= 0),
    CONSTRAINT ck_ad_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    )
);

COMMENT ON TABLE public.asset_disposals IS
    'Fixed asset disposal transaction. Records sale, write-off, or trade-in. '
    'Posting: DR Accumulated Depreciation / CR Fixed Asset at Cost / DR|CR Gain/Loss. '
    'Sets fixed_assets.is_disposed=true. One disposal per asset (unique constraint). '
    'Doc03 §24 table #126. Immutable after posting.';
COMMENT ON COLUMN public.asset_disposals.gain_loss IS
    'disposal_proceeds − net_book_value_at_disposal. Positive = gain, negative = loss. '
    'Posting engine posts CR Gain on Disposal (if positive) or DR Loss on Disposal (if negative).';
COMMENT ON COLUMN public.asset_disposals.disposal_account_id IS
    'GL account for Gain/Loss on Disposal. '
    'FK → chart_of_accounts.id — FK constraint added in Migration 012.';
COMMENT ON COLUMN public.asset_disposals.journal_entry_id IS
    'FK → journal_entries.id — FK constraint added in Migration 016.';

CREATE INDEX ix_asset_disposals_company_date
    ON public.asset_disposals (company_id, document_date);

CREATE INDEX ix_asset_disposals_fixed_asset
    ON public.asset_disposals (fixed_asset_id);

CREATE INDEX ix_asset_disposals_status
    ON public.asset_disposals (company_id, status)
    WHERE status NOT IN ('posted','voided');

ALTER TABLE public.asset_disposals ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP F: Asset Transfer — Transaction, Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #127 asset_transfers
-- Records the transfer of a fixed asset between branches or departments.
-- On posting the engine updates fixed_assets.branch_id / department_id to
-- reflect the new location. Doc03 §24 table #127. Immutable=YES. No soft delete.
CREATE TABLE public.asset_transfers (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid(),
    -- standard dimension columns (represent originating company/branch context)
    company_id           uuid          NOT NULL REFERENCES public.companies(id),
    branch_id            uuid          NULL     REFERENCES public.branches(id),
    department_id        uuid          NULL     REFERENCES public.departments(id),
    cost_center_id       uuid          NULL     REFERENCES public.cost_centers(id),
    -- standard transaction header
    document_no          text          NOT NULL,
    document_date        date          NOT NULL,
    posting_date         date          NULL,
    fiscal_year_id       uuid          NOT NULL REFERENCES public.fiscal_years(id),
    fiscal_period_id     uuid          NOT NULL REFERENCES public.fiscal_periods(id),
    currency_id          uuid          NOT NULL REFERENCES public.currencies(id),
    exchange_rate        numeric(10,6) NOT NULL DEFAULT 1.000000,
    status               text          NOT NULL DEFAULT 'draft',
    subtotal_amount      numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount           numeric(18,4) NOT NULL DEFAULT 0,
    withholding_amount   numeric(18,4) NOT NULL DEFAULT 0,
    total_amount         numeric(18,4) NOT NULL DEFAULT 0,
    remarks              text          NULL,
    posted_at            timestamptz   NULL,
    posted_by            uuid          NULL     REFERENCES public.profiles(id),
    voided_at            timestamptz   NULL,
    voided_by            uuid          NULL     REFERENCES public.profiles(id),
    void_reason          text          NULL,
    reversed_by_doc_id   uuid          NULL     REFERENCES public.asset_transfers(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id     uuid          NULL,
    -- import_batch_id FK deferred to Migration 023
    import_batch_id      uuid          NULL,
    -- asset_transfers-specific
    fixed_asset_id       uuid          NOT NULL REFERENCES public.fixed_assets(id),
    from_branch_id       uuid          NOT NULL REFERENCES public.branches(id),
    to_branch_id         uuid          NOT NULL REFERENCES public.branches(id),
    from_department_id   uuid          NULL     REFERENCES public.departments(id),
    to_department_id     uuid          NULL     REFERENCES public.departments(id),
    transfer_reason      text          NULL,
    -- Immutable audit
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_asset_transfers PRIMARY KEY (id),
    CONSTRAINT uq_asset_transfers_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_at_status CHECK (
        status IN ('draft','approved','posted','voided')
    ),
    CONSTRAINT ck_at_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_at_branch_diff CHECK (from_branch_id <> to_branch_id),
    CONSTRAINT ck_at_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    )
);

COMMENT ON TABLE public.asset_transfers IS
    'Fixed asset transfer between branches or departments. '
    'On posting the engine updates fixed_assets.branch_id and department_id to '
    'the destination values. from_branch_id <> to_branch_id enforced by CHECK. '
    'Doc03 §24 table #127. Immutable after posting.';
COMMENT ON COLUMN public.asset_transfers.journal_entry_id IS
    'FK → journal_entries.id — FK constraint added in Migration 016.';
COMMENT ON COLUMN public.asset_transfers.from_branch_id IS
    'Branch the asset is transferred FROM. Snapshot of fixed_assets.branch_id '
    'at transfer time.';
COMMENT ON COLUMN public.asset_transfers.to_branch_id IS
    'Branch the asset is transferred TO. Posting engine updates fixed_assets.branch_id '
    'to this value.';

CREATE INDEX ix_asset_transfers_company_date
    ON public.asset_transfers (company_id, document_date);

CREATE INDEX ix_asset_transfers_fixed_asset
    ON public.asset_transfers (fixed_asset_id);

ALTER TABLE public.asset_transfers ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP G: Asset Impairments — Transaction, Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #128 asset_impairments
-- Records a write-down of a fixed asset's carrying value due to impairment
-- (IAS 36 / PFRS for SMEs Section 27). On posting the engine reduces
-- fixed_assets.net_book_value and increases accumulated_depreciation.
-- Doc03 §24 table #128. Immutable=YES. No soft delete.
CREATE TABLE public.asset_impairments (
    id                      uuid          NOT NULL DEFAULT gen_random_uuid(),
    -- standard dimension columns
    company_id              uuid          NOT NULL REFERENCES public.companies(id),
    branch_id               uuid          NULL     REFERENCES public.branches(id),
    department_id           uuid          NULL     REFERENCES public.departments(id),
    cost_center_id          uuid          NULL     REFERENCES public.cost_centers(id),
    -- standard transaction header
    document_no             text          NOT NULL,
    document_date           date          NOT NULL,
    posting_date            date          NULL,
    fiscal_year_id          uuid          NOT NULL REFERENCES public.fiscal_years(id),
    fiscal_period_id        uuid          NOT NULL REFERENCES public.fiscal_periods(id),
    currency_id             uuid          NOT NULL REFERENCES public.currencies(id),
    exchange_rate           numeric(10,6) NOT NULL DEFAULT 1.000000,
    status                  text          NOT NULL DEFAULT 'draft',
    subtotal_amount         numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount              numeric(18,4) NOT NULL DEFAULT 0,
    withholding_amount      numeric(18,4) NOT NULL DEFAULT 0,
    total_amount            numeric(18,4) NOT NULL DEFAULT 0,
    remarks                 text          NULL,
    posted_at               timestamptz   NULL,
    posted_by               uuid          NULL     REFERENCES public.profiles(id),
    voided_at               timestamptz   NULL,
    voided_by               uuid          NULL     REFERENCES public.profiles(id),
    void_reason             text          NULL,
    reversed_by_doc_id      uuid          NULL     REFERENCES public.asset_impairments(id),
    source_document_id      uuid          NULL,
    source_document_type    text          NULL,
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id        uuid          NULL,
    -- import_batch_id FK deferred to Migration 023
    import_batch_id         uuid          NULL,
    -- asset_impairments-specific
    fixed_asset_id          uuid          NOT NULL REFERENCES public.fixed_assets(id),
    -- Write-down amount (must be positive; reduces NBV by this amount).
    impairment_amount       numeric(18,4) NOT NULL,
    -- NBV snapshots for audit trail.
    net_book_value_before   numeric(18,4) NOT NULL,
    net_book_value_after    numeric(18,4) NOT NULL,
    impairment_reason       text          NOT NULL,
    -- Date the impairment test was performed (may differ from document_date).
    impairment_test_date    date          NOT NULL,
    -- Immutable audit
    created_at              timestamptz   NOT NULL DEFAULT now(),
    created_by              uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_asset_impairments PRIMARY KEY (id),
    CONSTRAINT uq_asset_impairments_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_ai_status CHECK (
        status IN ('draft','approved','posted','voided')
    ),
    CONSTRAINT ck_ai_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_ai_impairment_amount CHECK (impairment_amount > 0),
    CONSTRAINT ck_ai_nbv_before CHECK (net_book_value_before >= 0),
    CONSTRAINT ck_ai_nbv_after CHECK (net_book_value_after >= 0),
    -- Impairment cannot exceed NBV before.
    CONSTRAINT ck_ai_impairment_lte_nbv CHECK (
        impairment_amount <= net_book_value_before
    ),
    -- net_book_value_after invariant.
    CONSTRAINT ck_ai_nbv_after_eq CHECK (
        net_book_value_after = net_book_value_before - impairment_amount
    ),
    CONSTRAINT ck_ai_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    )
);

COMMENT ON TABLE public.asset_impairments IS
    'Fixed asset impairment write-down (IAS 36 / PFRS for SMEs §27). '
    'Posting: DR Impairment Loss / CR Accumulated Impairment (treated as accumulated depreciation). '
    'Updates fixed_assets.accumulated_depreciation += impairment_amount and '
    'net_book_value -= impairment_amount atomically. '
    'Doc03 §24 table #128. Immutable after posting.';
COMMENT ON COLUMN public.asset_impairments.journal_entry_id IS
    'FK → journal_entries.id — FK constraint added in Migration 016.';
COMMENT ON COLUMN public.asset_impairments.impairment_test_date IS
    'Date the formal impairment assessment was performed. Required for PFRS audit trail. '
    'May differ from document_date (the date the transaction is recorded in the system).';

CREATE INDEX ix_asset_impairments_company_date
    ON public.asset_impairments (company_id, document_date);

CREATE INDEX ix_asset_impairments_fixed_asset
    ON public.asset_impairments (fixed_asset_id);

ALTER TABLE public.asset_impairments ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- END OF MIGRATION 011
-- =============================================================================
--
-- Tables created (10):
--   Group A (master):      depreciation_profiles, asset_categories, fixed_assets
--   Group B (ledger):      asset_depreciation_schedules
--   Group C (transaction): asset_acquisitions
--   Group D (transaction): depreciation_runs, depreciation_run_lines
--   Group E (transaction): asset_disposals
--   Group F (transaction): asset_transfers
--   Group G (transaction): asset_impairments
--
-- Deferred FK columns:
--   → chart_of_accounts (Migration 012):
--       asset_categories.depreciation_expense_account_id
--       fixed_assets.asset_account_id
--       fixed_assets.depreciation_account_id
--       fixed_assets.accumulated_depreciation_account_id
--       asset_disposals.disposal_account_id
--   → journal_entries (Migration 016):
--       asset_acquisitions.journal_entry_id
--       depreciation_run_lines.journal_entry_id
--       asset_disposals.journal_entry_id
--       asset_transfers.journal_entry_id
--       asset_impairments.journal_entry_id
--   → import_batches (Migration 023):
--       import_batch_id on all transaction headers
--
-- Backlog items: M-011-1 (depreciation_expense_account_id Doc03 omission),
--                M-011-2 (fixed_assets boolean flags vs status enum Doc06 discrepancy),
--                M-011-3 (accumulated_depreciation / net_book_value service-role guard),
--                L-011-1 (asset_depreciation_schedules.status mutable — service role only),
--                L-011-2 (depreciation_runs unique constraint DEFERRABLE — see note)
-- =============================================================================
