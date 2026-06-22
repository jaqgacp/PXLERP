-- =============================================================================
-- Migration 013 — General Ledger (Module 16 GL Runtime)
-- =============================================================================
-- Scope: Journal Entries, Journal Lines, GL Balances, Subsidiary Ledger,
--        Document Relationships, Posting Batches, Posting Errors,
--        Recurring Journal Templates and Lines.
--        ALTER TABLE ADD CONSTRAINT wires all deferred journal_entry_id FKs
--        from Migrations 007–012 (previously commented "FK deferred to
--        Migration 016").
--
-- Table count: 9 new tables
-- ALTER TABLE: 22 FK constraints (journal_entry_id) + 1 source_journal_entry_id
--
-- Dependency order (FK chain):
--   recurring_journal_templates
--   → recurring_journal_template_lines
--   → posting_batches
--   → posting_errors
--   → journal_entries (refs posting_batches, recurring_journal_templates)
--   → journal_lines (refs journal_entries)
--   → gl_balances (no journal_entries dep — updated via UPSERT by posting engine)
--   → subsidiary_ledger_entries (refs journal_entries, journal_lines)
--   → document_relationships (polymorphic — no hard FK deps)
--
-- Deferred FKs resolved (journal_entries now exists):
--   Mig 007: sales_invoices, cash_sales, receipts, sales_credit_memos,
--            sales_debit_memos, customer_returns
--   Mig 008: vendor_bills, cash_purchases, payment_vouchers, vendor_credits,
--            supplier_debit_memos, purchase_returns
--   Mig 009: petty_cash_vouchers, petty_cash_replenishments, bank_fund_transfers,
--            inter_branch_transfers, bank_adjustments, bank_reconciliations,
--            bank_reconciliation_lines (source_journal_entry_id)
--   Mig 011: asset_acquisitions, depreciation_run_lines, asset_disposals,
--            asset_transfers, asset_impairments
--   Mig 012: opening_balance_entries
--
-- Architecture: Database Freeze v4.0. Read-only sources: Doc02, Doc03.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- SECTION 1: recurring_journal_templates
-- ---------------------------------------------------------------------------
-- Template for system-scheduled recurring JEs (monthly rent, depreciation
-- provisions, prepaid amortization, etc.). auto_reverse=true generates
-- accrual-reversal JEs; replaces separate accrual_schedules table (Doc02 §v3.8).
-- ---------------------------------------------------------------------------

CREATE TABLE public.recurring_journal_templates (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                  uuid            NOT NULL,
    name                        text            NOT NULL,
    description                 text            NULL,
    frequency                   text            NOT NULL,
    start_date                  date            NOT NULL,
    end_date                    date            NULL,
    next_run_date               date            NULL,
    last_run_date               date            NULL,
    auto_reverse                boolean         NOT NULL DEFAULT false,
    auto_reversal_days_offset   integer         NOT NULL DEFAULT 1,
    je_type                     text            NOT NULL DEFAULT 'recurring',
    total_debit                 numeric(18,4)   NOT NULL DEFAULT 0,
    status                      text            NOT NULL DEFAULT 'active',

    -- Standard audit columns
    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NULL,
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NULL,
    deleted_at                  timestamptz     NULL,
    deleted_by                  uuid            NULL,

    CONSTRAINT pk_recurring_journal_templates PRIMARY KEY (id),
    CONSTRAINT fk_rjt_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_rjt_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_rjt_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_rjt_deleted_by
        FOREIGN KEY (deleted_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_rjt_frequency
        CHECK (frequency IN ('monthly','quarterly','annually')),
    CONSTRAINT ck_rjt_status
        CHECK (status IN ('active','paused','completed','cancelled')),
    CONSTRAINT ck_rjt_je_type
        CHECK (je_type IN ('manual','system','reversal','opening','recurring',
                           'adjustment','amortization','revenue_recognition',
                           'auto_reversal','closing')),
    CONSTRAINT ck_rjt_total_debit_nneg
        CHECK (total_debit >= 0)
);

COMMENT ON TABLE public.recurring_journal_templates IS
    'Templates for system-generated recurring journal entries. '
    'auto_reverse=true: generated JEs carry auto_reversal_flag=true so the '
    'auto-reversal run posts the reversing entry on auto_reversal_date. '
    'Replaces separate accrual_schedules table per Doc02 §v3.8 decision.';

COMMENT ON COLUMN public.recurring_journal_templates.auto_reversal_days_offset IS
    'Days after document_date for auto-reversal. Default 1 = day after posting '
    '(i.e., 1st of next month for month-end accruals).';

CREATE INDEX idx_rjt_company_status
    ON public.recurring_journal_templates (company_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_rjt_next_run
    ON public.recurring_journal_templates (company_id, next_run_date)
    WHERE status = 'active' AND deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- SECTION 2: recurring_journal_template_lines
-- ---------------------------------------------------------------------------

CREATE TABLE public.recurring_journal_template_lines (
    id              uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id      uuid            NOT NULL,
    template_id     uuid            NOT NULL,
    line_no         integer         NOT NULL,
    account_id      uuid            NOT NULL,
    debit_amount    numeric(18,4)   NOT NULL DEFAULT 0,
    credit_amount   numeric(18,4)   NOT NULL DEFAULT 0,
    description     text            NULL,
    branch_id       uuid            NULL,
    department_id   uuid            NULL,
    cost_center_id  uuid            NULL,

    -- Standard audit columns
    created_at      timestamptz     NOT NULL DEFAULT now(),
    created_by      uuid            NULL,
    updated_at      timestamptz     NOT NULL DEFAULT now(),
    updated_by      uuid            NULL,
    deleted_at      timestamptz     NULL,
    deleted_by      uuid            NULL,

    CONSTRAINT pk_recurring_journal_template_lines PRIMARY KEY (id),
    CONSTRAINT fk_rjtl_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_rjtl_template
        FOREIGN KEY (template_id) REFERENCES public.recurring_journal_templates(id),
    CONSTRAINT fk_rjtl_account
        FOREIGN KEY (account_id) REFERENCES public.chart_of_accounts(id),
    CONSTRAINT fk_rjtl_branch
        FOREIGN KEY (branch_id) REFERENCES public.branches(id),
    CONSTRAINT fk_rjtl_department
        FOREIGN KEY (department_id) REFERENCES public.departments(id),
    CONSTRAINT fk_rjtl_cost_center
        FOREIGN KEY (cost_center_id) REFERENCES public.cost_centers(id),
    CONSTRAINT fk_rjtl_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_rjtl_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_rjtl_deleted_by
        FOREIGN KEY (deleted_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_rjtl_one_side
        CHECK (debit_amount = 0 OR credit_amount = 0),
    CONSTRAINT ck_rjtl_debit_nneg
        CHECK (debit_amount >= 0),
    CONSTRAINT ck_rjtl_credit_nneg
        CHECK (credit_amount >= 0)
);

COMMENT ON TABLE public.recurring_journal_template_lines IS
    'Debit/credit lines for a recurring journal template. '
    'Constraint: only one of debit_amount or credit_amount may be non-zero per line.';

CREATE INDEX idx_rjtl_template
    ON public.recurring_journal_template_lines (template_id)
    WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- SECTION 3: posting_batches
-- ---------------------------------------------------------------------------
-- Batch posting session header. The posting engine (Edge Function) creates a
-- batch before processing, sets idempotency_key = source_doc_type:source_doc_id:
-- attempt_token. On retry, the same key returns the existing batch record —
-- no reprocessing. Immutable once created (Doc03 Immutable=YES).
-- ---------------------------------------------------------------------------

CREATE TABLE public.posting_batches (
    id                  uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL,
    idempotency_key     text        NOT NULL,
    batch_type          text        NOT NULL,
    entity_ids          uuid[]      NOT NULL,
    processed_count     integer     NOT NULL DEFAULT 0,
    failed_count        integer     NOT NULL DEFAULT 0,
    status              text        NOT NULL DEFAULT 'pending',
    started_at          timestamptz NULL,
    completed_at        timestamptz NULL,
    initiated_by        uuid        NOT NULL,

    -- Standard audit columns
    created_at          timestamptz NOT NULL DEFAULT now(),
    created_by          uuid        NULL,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          uuid        NULL,

    CONSTRAINT pk_posting_batches PRIMARY KEY (id),
    CONSTRAINT uq_posting_batches_idempotency
        UNIQUE (idempotency_key),
    CONSTRAINT fk_pb_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_pb_initiated_by
        FOREIGN KEY (initiated_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_pb_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_pb_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_pb_status
        CHECK (status IN ('pending','processing','completed','partial_fail','failed')),
    CONSTRAINT ck_pb_processed_count_nneg
        CHECK (processed_count >= 0),
    CONSTRAINT ck_pb_failed_count_nneg
        CHECK (failed_count >= 0)
);

COMMENT ON TABLE public.posting_batches IS
    'Batch posting session. idempotency_key = source_doc_type:source_doc_id:'
    'attempt_token. On retry, same key returns existing batch — no reprocessing. '
    'Immutable once created (Doc03 Immutable=YES).';

COMMENT ON COLUMN public.posting_batches.idempotency_key IS
    'Set by Edge Function as source_doc_type:source_doc_id:attempt_token. '
    'UNIQUE constraint guarantees idempotent posting on retry.';

-- Partial unique: prevent duplicate completed batches for the same single-doc post
CREATE UNIQUE INDEX uq_posting_batches_completed_entity
    ON public.posting_batches (company_id, batch_type, (entity_ids[1]))
    WHERE status = 'completed';

CREATE INDEX idx_posting_batches_company_status
    ON public.posting_batches (company_id, status);

-- ---------------------------------------------------------------------------
-- SECTION 4: posting_errors
-- ---------------------------------------------------------------------------
-- Immutable audit log of errors encountered during posting engine execution.
-- No standard audit columns beyond occurred_at (Doc03).
-- ---------------------------------------------------------------------------

CREATE TABLE public.posting_errors (
    id                  uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL,
    posting_batch_id    uuid        NULL,
    entity_type         text        NOT NULL,
    entity_id           uuid        NOT NULL,
    error_code          text        NOT NULL,
    error_message       text        NOT NULL,
    occurred_at         timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_posting_errors PRIMARY KEY (id),
    CONSTRAINT fk_pe_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_pe_posting_batch
        FOREIGN KEY (posting_batch_id) REFERENCES public.posting_batches(id)
);

COMMENT ON TABLE public.posting_errors IS
    'Immutable audit log of posting engine errors. '
    'No standard audit columns beyond occurred_at (Doc03 Audit=NO).';

COMMENT ON COLUMN public.posting_errors.error_code IS
    'e.g. PERIOD_CLOSED, MISSING_ACCOUNT_CONFIG, BALANCE_MISMATCH';

CREATE INDEX idx_posting_errors_batch
    ON public.posting_errors (posting_batch_id)
    WHERE posting_batch_id IS NOT NULL;

CREATE INDEX idx_posting_errors_entity
    ON public.posting_errors (company_id, entity_type, entity_id);

-- ---------------------------------------------------------------------------
-- SECTION 5: journal_entries
-- ---------------------------------------------------------------------------
-- Journal entry header. Immutable once posted — no deleted_at (Doc03
-- Soft Delete=NO). State transitions: draft → posted → reversed.
-- Debit = credit enforced only when status = 'posted' (conditional check).
--
-- Deferred FKs (Module 31 — not yet migrated):
--   auto_reversal_run_id → auto_reversal_runs.id
--   amortization_run_detail_id → amortization_run_details.id
--   revenue_recognition_run_detail_id → revenue_recognition_run_details.id
-- These are plain uuid NULL until the Module 31 migration adds the FKs.
-- ---------------------------------------------------------------------------

CREATE TABLE public.journal_entries (
    id                                  uuid            NOT NULL DEFAULT gen_random_uuid(),

    -- Standard dimension columns
    company_id                          uuid            NOT NULL,
    branch_id                           uuid            NULL,
    department_id                       uuid            NULL,
    cost_center_id                      uuid            NULL,

    document_no                         text            NOT NULL,
    document_date                       date            NOT NULL,
    posting_date                        date            NOT NULL,
    fiscal_year_id                      uuid            NOT NULL,
    fiscal_period_id                    uuid            NOT NULL,
    je_type                             text            NOT NULL,
    source_document_type                text            NULL,
    source_document_id                  uuid            NULL,
    posting_batch_id                    uuid            NULL,
    description                         text            NOT NULL,
    total_debit                         numeric(18,4)   NOT NULL DEFAULT 0,
    total_credit                        numeric(18,4)   NOT NULL DEFAULT 0,
    status                              text            NOT NULL DEFAULT 'draft',
    is_auto_generated                   boolean         NOT NULL DEFAULT false,
    reversal_of_je_id                   uuid            NULL,
    reversed_by_je_id                   uuid            NULL,
    recurring_template_id               uuid            NULL,
    auto_reversal_flag                  boolean         NOT NULL DEFAULT false,
    auto_reversal_date                  date            NULL,
    -- FK → auto_reversal_runs.id — deferred to Module 31 migration
    auto_reversal_run_id                uuid            NULL,
    is_auto_reversal                    boolean         NOT NULL DEFAULT false,
    -- FK → amortization_run_details.id — deferred to Module 31 migration
    amortization_run_detail_id          uuid            NULL,
    -- FK → revenue_recognition_run_details.id — deferred to Module 31 migration
    revenue_recognition_run_detail_id   uuid            NULL,
    posted_at                           timestamptz     NULL,
    posted_by                           uuid            NULL,

    -- Standard audit columns (Immutable pattern: no deleted_at/by per Doc03 Soft Delete=NO)
    created_at                          timestamptz     NOT NULL DEFAULT now(),
    created_by                          uuid            NULL,
    updated_at                          timestamptz     NOT NULL DEFAULT now(),
    updated_by                          uuid            NULL,

    CONSTRAINT pk_journal_entries PRIMARY KEY (id),
    CONSTRAINT fk_je_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_je_branch
        FOREIGN KEY (branch_id) REFERENCES public.branches(id),
    CONSTRAINT fk_je_department
        FOREIGN KEY (department_id) REFERENCES public.departments(id),
    CONSTRAINT fk_je_cost_center
        FOREIGN KEY (cost_center_id) REFERENCES public.cost_centers(id),
    CONSTRAINT fk_je_fiscal_year
        FOREIGN KEY (fiscal_year_id) REFERENCES public.fiscal_years(id),
    CONSTRAINT fk_je_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_je_posting_batch
        FOREIGN KEY (posting_batch_id) REFERENCES public.posting_batches(id),
    CONSTRAINT fk_je_reversal_of
        FOREIGN KEY (reversal_of_je_id) REFERENCES public.journal_entries(id),
    CONSTRAINT fk_je_reversed_by
        FOREIGN KEY (reversed_by_je_id) REFERENCES public.journal_entries(id),
    CONSTRAINT fk_je_recurring_template
        FOREIGN KEY (recurring_template_id) REFERENCES public.recurring_journal_templates(id),
    CONSTRAINT fk_je_posted_by
        FOREIGN KEY (posted_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_je_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_je_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_je_type
        CHECK (je_type IN ('manual','system','reversal','opening','recurring',
                           'adjustment','amortization','revenue_recognition',
                           'auto_reversal','closing')),
    CONSTRAINT ck_je_status
        CHECK (status IN ('draft','posted','reversed')),
    -- Debit = credit enforced only when posted
    CONSTRAINT ck_je_balanced_when_posted
        CHECK (status <> 'posted' OR total_debit = total_credit),
    CONSTRAINT ck_je_total_debit_nneg
        CHECK (total_debit >= 0),
    CONSTRAINT ck_je_total_credit_nneg
        CHECK (total_credit >= 0),
    -- auto_reversal_date required if auto_reversal_flag is set
    CONSTRAINT ck_je_auto_reversal_date
        CHECK (auto_reversal_flag = false OR auto_reversal_date IS NOT NULL)
);

COMMENT ON TABLE public.journal_entries IS
    'Journal entry header. Immutable once posted (no soft delete). '
    'Debit = credit enforced only on status = posted via ck_je_balanced_when_posted. '
    'Deferred FKs (Module 31 migration): auto_reversal_run_id, '
    'amortization_run_detail_id, revenue_recognition_run_detail_id.';

COMMENT ON COLUMN public.journal_entries.auto_reversal_run_id IS
    'FK → auto_reversal_runs.id — FK constraint deferred to Module 31 migration.';

COMMENT ON COLUMN public.journal_entries.amortization_run_detail_id IS
    'FK → amortization_run_details.id — FK constraint deferred to Module 31 migration.';

COMMENT ON COLUMN public.journal_entries.revenue_recognition_run_detail_id IS
    'FK → revenue_recognition_run_details.id — FK constraint deferred to Module 31 migration.';

CREATE UNIQUE INDEX uq_journal_entries_doc_no
    ON public.journal_entries (company_id, document_no);

CREATE INDEX idx_journal_entries_period
    ON public.journal_entries (company_id, fiscal_period_id, status);

CREATE INDEX idx_journal_entries_posting_date
    ON public.journal_entries (company_id, posting_date);

CREATE INDEX idx_journal_entries_source_doc
    ON public.journal_entries (company_id, source_document_type, source_document_id)
    WHERE source_document_id IS NOT NULL;

CREATE INDEX idx_journal_entries_auto_reversal
    ON public.journal_entries (company_id, auto_reversal_date)
    WHERE auto_reversal_flag = true AND is_auto_reversal = false;

-- ---------------------------------------------------------------------------
-- SECTION 6: journal_lines
-- ---------------------------------------------------------------------------
-- Individual debit/credit lines within a journal entry. Immutable once posted.
-- Constraint: exactly one of debit_amount or credit_amount must be non-zero.
-- ---------------------------------------------------------------------------

CREATE TABLE public.journal_lines (
    id                  uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid            NOT NULL,
    journal_entry_id    uuid            NOT NULL,
    line_no             integer         NOT NULL,
    account_id          uuid            NOT NULL,
    branch_id           uuid            NULL,
    department_id       uuid            NULL,
    cost_center_id      uuid            NULL,
    debit_amount        numeric(18,4)   NOT NULL DEFAULT 0,
    credit_amount       numeric(18,4)   NOT NULL DEFAULT 0,
    currency_id         uuid            NOT NULL,
    exchange_rate       numeric(10,6)   NOT NULL DEFAULT 1,
    functional_debit    numeric(18,4)   NOT NULL DEFAULT 0,
    functional_credit   numeric(18,4)   NOT NULL DEFAULT 0,
    description         text            NULL,
    party_type          text            NULL,
    party_id            uuid            NULL,
    source_line_type    text            NULL,
    source_line_id      uuid            NULL,

    -- Standard audit columns
    created_at          timestamptz     NOT NULL DEFAULT now(),
    created_by          uuid            NULL,
    updated_at          timestamptz     NOT NULL DEFAULT now(),
    updated_by          uuid            NULL,

    CONSTRAINT pk_journal_lines PRIMARY KEY (id),
    CONSTRAINT fk_jl_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_jl_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id),
    CONSTRAINT fk_jl_account
        FOREIGN KEY (account_id) REFERENCES public.chart_of_accounts(id),
    CONSTRAINT fk_jl_branch
        FOREIGN KEY (branch_id) REFERENCES public.branches(id),
    CONSTRAINT fk_jl_department
        FOREIGN KEY (department_id) REFERENCES public.departments(id),
    CONSTRAINT fk_jl_cost_center
        FOREIGN KEY (cost_center_id) REFERENCES public.cost_centers(id),
    CONSTRAINT fk_jl_currency
        FOREIGN KEY (currency_id) REFERENCES public.currencies(id),
    CONSTRAINT fk_jl_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_jl_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_jl_one_side
        CHECK (debit_amount = 0 OR credit_amount = 0),
    CONSTRAINT ck_jl_debit_nneg
        CHECK (debit_amount >= 0),
    CONSTRAINT ck_jl_credit_nneg
        CHECK (credit_amount >= 0),
    CONSTRAINT ck_jl_functional_debit_nneg
        CHECK (functional_debit >= 0),
    CONSTRAINT ck_jl_functional_credit_nneg
        CHECK (functional_credit >= 0),
    CONSTRAINT ck_jl_exchange_rate_pos
        CHECK (exchange_rate > 0),
    CONSTRAINT ck_jl_party_type
        CHECK (party_type IS NULL OR party_type IN ('customer','supplier'))
);

COMMENT ON TABLE public.journal_lines IS
    'Individual debit/credit lines of a journal entry. Immutable once the parent '
    'journal entry is posted. One of debit_amount or credit_amount must be zero.';

CREATE UNIQUE INDEX uq_journal_lines_entry_line_no
    ON public.journal_lines (journal_entry_id, line_no);

CREATE INDEX idx_journal_lines_account
    ON public.journal_lines (company_id, account_id);

CREATE INDEX idx_journal_lines_entry
    ON public.journal_lines (journal_entry_id);

-- ---------------------------------------------------------------------------
-- SECTION 7: gl_balances
-- ---------------------------------------------------------------------------
-- Running GL balance per account / fiscal period / optional branch.
-- Mutable ledger — updated via INSERT ... ON CONFLICT DO UPDATE by posting
-- engine on every posting. No standard audit columns except updated_at.
-- NULL branch_id means company-wide total — requires two separate partial
-- unique indexes because NULL != NULL in PostgreSQL unique constraints.
-- ---------------------------------------------------------------------------

CREATE TABLE public.gl_balances (
    id                  uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid            NOT NULL,
    account_id          uuid            NOT NULL,
    branch_id           uuid            NULL,
    fiscal_year_id      uuid            NOT NULL,
    fiscal_period_id    uuid            NOT NULL,
    opening_debit       numeric(18,4)   NOT NULL DEFAULT 0,
    opening_credit      numeric(18,4)   NOT NULL DEFAULT 0,
    period_debit        numeric(18,4)   NOT NULL DEFAULT 0,
    period_credit       numeric(18,4)   NOT NULL DEFAULT 0,
    closing_debit       numeric(18,4)   NOT NULL DEFAULT 0,
    closing_credit      numeric(18,4)   NOT NULL DEFAULT 0,
    ytd_debit           numeric(18,4)   NOT NULL DEFAULT 0,
    ytd_credit          numeric(18,4)   NOT NULL DEFAULT 0,
    updated_at          timestamptz     NOT NULL DEFAULT now(),

    CONSTRAINT pk_gl_balances PRIMARY KEY (id),
    CONSTRAINT fk_glb_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_glb_account
        FOREIGN KEY (account_id) REFERENCES public.chart_of_accounts(id),
    CONSTRAINT fk_glb_branch
        FOREIGN KEY (branch_id) REFERENCES public.branches(id),
    CONSTRAINT fk_glb_fiscal_year
        FOREIGN KEY (fiscal_year_id) REFERENCES public.fiscal_years(id),
    CONSTRAINT fk_glb_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),

    CONSTRAINT ck_glb_opening_debit_nneg    CHECK (opening_debit >= 0),
    CONSTRAINT ck_glb_opening_credit_nneg   CHECK (opening_credit >= 0),
    CONSTRAINT ck_glb_period_debit_nneg     CHECK (period_debit >= 0),
    CONSTRAINT ck_glb_period_credit_nneg    CHECK (period_credit >= 0),
    CONSTRAINT ck_glb_closing_debit_nneg    CHECK (closing_debit >= 0),
    CONSTRAINT ck_glb_closing_credit_nneg   CHECK (closing_credit >= 0),
    CONSTRAINT ck_glb_ytd_debit_nneg        CHECK (ytd_debit >= 0),
    CONSTRAINT ck_glb_ytd_credit_nneg       CHECK (ytd_credit >= 0)
);

COMMENT ON TABLE public.gl_balances IS
    'Mutable GL balance ledger — updated via UPSERT by the posting engine. '
    'Two partial unique indexes handle NULL branch_id (company-wide total) '
    'because NULL != NULL in PostgreSQL unique constraints.';

-- Two partial unique indexes for NULL branch_id handling (PostgreSQL NULL semantics)
CREATE UNIQUE INDEX uq_gl_balances_no_branch
    ON public.gl_balances (company_id, account_id, fiscal_period_id)
    WHERE branch_id IS NULL;

CREATE UNIQUE INDEX uq_gl_balances_with_branch
    ON public.gl_balances (company_id, account_id, branch_id, fiscal_period_id)
    WHERE branch_id IS NOT NULL;

CREATE INDEX idx_gl_balances_account_period
    ON public.gl_balances (company_id, account_id, fiscal_period_id);

CREATE INDEX idx_gl_balances_period
    ON public.gl_balances (company_id, fiscal_period_id);

-- ---------------------------------------------------------------------------
-- SECTION 8: subsidiary_ledger_entries
-- ---------------------------------------------------------------------------
-- AR/AP/Inventory/Fixed Asset subledger. Immutable. Written by posting engine
-- (service role only). No standard audit columns beyond created_at context
-- (Doc03: "No standard audit columns").
-- ---------------------------------------------------------------------------

CREATE TABLE public.subsidiary_ledger_entries (
    id                  uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid            NOT NULL,
    ledger_type         text            NOT NULL,
    entity_type         text            NOT NULL,
    entity_id           uuid            NOT NULL,
    entity_line_id      uuid            NULL,
    journal_entry_id    uuid            NOT NULL,
    journal_line_id     uuid            NOT NULL,
    debit_amount        numeric(18,4)   NOT NULL DEFAULT 0,
    credit_amount       numeric(18,4)   NOT NULL DEFAULT 0,
    running_balance     numeric(18,4)   NOT NULL DEFAULT 0,
    fiscal_period_id    uuid            NOT NULL,
    transaction_date    date            NOT NULL,

    CONSTRAINT pk_subsidiary_ledger_entries PRIMARY KEY (id),
    CONSTRAINT fk_sle_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_sle_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id),
    CONSTRAINT fk_sle_journal_line
        FOREIGN KEY (journal_line_id) REFERENCES public.journal_lines(id),
    CONSTRAINT fk_sle_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),

    CONSTRAINT ck_sle_ledger_type
        CHECK (ledger_type IN ('ar','ap','inventory','fixed_asset')),
    CONSTRAINT ck_sle_debit_nneg
        CHECK (debit_amount >= 0),
    CONSTRAINT ck_sle_credit_nneg
        CHECK (credit_amount >= 0)
);

COMMENT ON TABLE public.subsidiary_ledger_entries IS
    'AR/AP/Inventory/Fixed Asset subsidiary ledger. Immutable. Written by posting '
    'engine (service role). No standard audit columns (Doc03 specification). '
    'Provides subledger drill-down and AR/AP aging source data.';

CREATE INDEX idx_sub_ledger_type_entity
    ON public.subsidiary_ledger_entries (company_id, ledger_type, entity_id);

CREATE INDEX idx_sub_ledger_period
    ON public.subsidiary_ledger_entries (company_id, ledger_type, fiscal_period_id);

CREATE INDEX idx_sub_ledger_journal_entry
    ON public.subsidiary_ledger_entries (journal_entry_id);

-- ---------------------------------------------------------------------------
-- SECTION 9: document_relationships
-- ---------------------------------------------------------------------------
-- Bridge table linking source documents to journal entries and downstream docs.
-- Polymorphic via entity_type text (source table name) + entity_id uuid.
-- Immutable — no standard audit columns beyond created_at (Doc03).
-- relationship_type uses Doc03 canonical values.
-- ---------------------------------------------------------------------------

CREATE TABLE public.document_relationships (
    id                      uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid        NOT NULL,
    source_entity_type      text        NOT NULL,
    source_entity_id        uuid        NOT NULL,
    target_entity_type      text        NOT NULL,
    target_entity_id        uuid        NOT NULL,
    relationship_type       text        NOT NULL,
    created_at              timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT pk_document_relationships PRIMARY KEY (id),
    CONSTRAINT fk_dr_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),

    CONSTRAINT uq_document_relationships
        UNIQUE (company_id, source_entity_type, source_entity_id,
                target_entity_type, target_entity_id, relationship_type),

    CONSTRAINT ck_dr_relationship_type
        CHECK (relationship_type IN (
            'generated_journal',   -- doc → journal_entry (Doc03)
            'reversed_by',         -- je → reversal je (Doc03/Doc06)
            'paid_by',             -- invoice → payment (Doc03/Doc06)
            'credit_applied',      -- invoice → credit memo (Doc03)
            'receipt_applied',     -- invoice → receipt (Doc03)
            'generated_from',      -- generated doc → source doc (Doc03)
            'billed_from',         -- invoice → PO/RR (Doc06)
            'delivered_from',      -- invoice → DR (Doc06)
            'received_from',       -- vendor bill → RR (Doc06)
            'applied_to',          -- credit/debit memo applied to (Doc06)
            'replenished_by'       -- petty cash → replenishment PV (Doc06)
        ))
);

COMMENT ON TABLE public.document_relationships IS
    'Polymorphic bridge table linking source documents to JEs and downstream docs. '
    'Immutable — no audit columns beyond created_at (Doc03). '
    'relationship_type is the combined superset of Doc03 canonical values and Doc06 '
    'posting engine cross-references (Decision 011).';

CREATE INDEX idx_dr_source
    ON public.document_relationships (company_id, source_entity_type, source_entity_id);

CREATE INDEX idx_dr_target
    ON public.document_relationships (company_id, target_entity_type, target_entity_id);

-- ---------------------------------------------------------------------------
-- SECTION 10: ALTER TABLE — Wire deferred journal_entry_id FKs
-- ---------------------------------------------------------------------------
-- All transaction tables in Migrations 007–012 declared journal_entry_id as
-- plain uuid NULL with comment "FK deferred to Migration 016".
-- journal_entries now exists; add all FK constraints here.
-- ---------------------------------------------------------------------------

-- === Migration 007: Sales ===

ALTER TABLE public.sales_invoices
    ADD CONSTRAINT fk_sales_invoices_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.cash_sales
    ADD CONSTRAINT fk_cash_sales_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.receipts
    ADD CONSTRAINT fk_receipts_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.sales_credit_memos
    ADD CONSTRAINT fk_sales_credit_memos_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.sales_debit_memos
    ADD CONSTRAINT fk_sales_debit_memos_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.customer_returns
    ADD CONSTRAINT fk_customer_returns_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

-- === Migration 008: Purchasing ===

ALTER TABLE public.vendor_bills
    ADD CONSTRAINT fk_vendor_bills_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.cash_purchases
    ADD CONSTRAINT fk_cash_purchases_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.payment_vouchers
    ADD CONSTRAINT fk_payment_vouchers_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.vendor_credits
    ADD CONSTRAINT fk_vendor_credits_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.supplier_debit_memos
    ADD CONSTRAINT fk_supplier_debit_memos_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.purchase_returns
    ADD CONSTRAINT fk_purchase_returns_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

-- === Migration 009: Petty Cash & Banking ===

ALTER TABLE public.petty_cash_vouchers
    ADD CONSTRAINT fk_petty_cash_vouchers_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.petty_cash_replenishments
    ADD CONSTRAINT fk_petty_cash_replenishments_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.bank_fund_transfers
    ADD CONSTRAINT fk_bank_fund_transfers_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.inter_branch_transfers
    ADD CONSTRAINT fk_inter_branch_transfers_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.bank_adjustments
    ADD CONSTRAINT fk_bank_adjustments_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.bank_reconciliations
    ADD CONSTRAINT fk_bank_reconciliations_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.bank_reconciliation_lines
    ADD CONSTRAINT fk_bank_reconciliation_lines_source_journal_entry
        FOREIGN KEY (source_journal_entry_id) REFERENCES public.journal_entries(id);

-- === Migration 011: Fixed Assets ===

ALTER TABLE public.asset_acquisitions
    ADD CONSTRAINT fk_asset_acquisitions_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.depreciation_run_lines
    ADD CONSTRAINT fk_depreciation_run_lines_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.asset_disposals
    ADD CONSTRAINT fk_asset_disposals_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.asset_transfers
    ADD CONSTRAINT fk_asset_transfers_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

ALTER TABLE public.asset_impairments
    ADD CONSTRAINT fk_asset_impairments_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

-- === Migration 012: Chart of Accounts Foundation ===

ALTER TABLE public.opening_balance_entries
    ADD CONSTRAINT fk_opening_balance_entries_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);

-- ---------------------------------------------------------------------------
-- END OF MIGRATION 013
-- ---------------------------------------------------------------------------
-- Tables created: 9
--   recurring_journal_templates, recurring_journal_template_lines,
--   posting_batches, posting_errors, journal_entries, journal_lines,
--   gl_balances, subsidiary_ledger_entries, document_relationships
--
-- FK constraints added (deferred journal_entry_id wiring): 23
--   6 from Migration 007, 6 from Migration 008, 7 from Migration 009,
--   5 from Migration 011, 1 from Migration 012
--
-- Pending (Module 31 migration):
--   journal_entries.auto_reversal_run_id → auto_reversal_runs.id
--   journal_entries.amortization_run_detail_id → amortization_run_details.id
--   journal_entries.revenue_recognition_run_detail_id → revenue_recognition_run_details.id
-- ---------------------------------------------------------------------------
