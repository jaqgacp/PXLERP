-- =============================================================================
-- Migration 014 — Posting Engine Support (Module 31: Accounting Schedules)
-- =============================================================================
-- Scope: Module 31 — Amortization schedules, revenue recognition schedules,
--        and auto-reversal run tables. These are the canonical posting-engine
--        support tables deferred from Migration 013.
--
-- Module 16 (GL runtime) is complete: migrations 012/013 created all 11
-- Module 16 tables (posting_rule_sets, posting_rule_lines, posting_batches,
-- posting_errors, journal_entries, journal_lines, gl_balances,
-- subsidiary_ledger_entries, document_relationships, recurring_journal_templates,
-- recurring_journal_template_lines). No new Module 16 tables are required.
--
-- Tables created: 9 (Module 31 — Accounting Schedules)
--   amortization_schedules
--   amortization_schedule_lines
--   amortization_runs
--   amortization_run_details
--   revenue_recognition_schedules
--   revenue_recognition_schedule_lines
--   revenue_recognition_runs
--   revenue_recognition_run_details
--   auto_reversal_runs
--
-- ALTER TABLE ADD CONSTRAINT: 3
--   journal_entries.auto_reversal_run_id → auto_reversal_runs.id
--   journal_entries.amortization_run_detail_id → amortization_run_details.id
--   journal_entries.revenue_recognition_run_detail_id → revenue_recognition_run_details.id
--   (These were declared plain uuid NULL in Migration 013 with deferral comment)
--
-- FK dependency order:
--   amortization_schedules
--   → amortization_schedule_lines (refs amortization_schedules)
--   → amortization_runs (refs fiscal_periods)
--   → amortization_run_details (refs amortization_runs, schedule_lines, journal_entries)
--   revenue_recognition_schedules
--   → revenue_recognition_schedule_lines
--   → revenue_recognition_runs
--   → revenue_recognition_run_details
--   auto_reversal_runs (standalone — refs fiscal_periods)
--
-- Traceability chain:
--   amortization_schedules → amortization_schedule_lines →
--   amortization_runs → amortization_run_details →
--   journal_entries → journal_lines → gl_balances
--   (same chain for revenue recognition)
--
-- Architecture: Database Freeze v4.0. Read-only sources: Doc02, Doc03.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- SECTION 1: amortization_schedules
-- ---------------------------------------------------------------------------
-- Master header for each prepaid expense or deferred charge being amortized.
-- Covers prepaid rent, insurance, software, professional fees, deferred charges.
-- Phase 1: straight-line method only.
-- ---------------------------------------------------------------------------

CREATE TABLE public.amortization_schedules (
    id                      uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid            NOT NULL,
    name                    text            NOT NULL,
    prepaid_type            text            NOT NULL,
    source_document_type    text            NULL,
    source_document_id      uuid            NULL,
    prepaid_account_id      uuid            NOT NULL,
    expense_account_id      uuid            NOT NULL,
    total_amount            numeric(18,4)   NOT NULL DEFAULT 0,
    amount_amortized        numeric(18,4)   NOT NULL DEFAULT 0,
    amount_remaining        numeric(18,4)   NOT NULL DEFAULT 0,
    start_date              date            NOT NULL,
    end_date                date            NOT NULL,
    frequency               text            NOT NULL DEFAULT 'monthly',
    amortization_method     text            NOT NULL DEFAULT 'straight_line',
    status                  text            NOT NULL DEFAULT 'active',

    -- Standard audit columns
    created_at              timestamptz     NOT NULL DEFAULT now(),
    created_by              uuid            NULL,
    updated_at              timestamptz     NOT NULL DEFAULT now(),
    updated_by              uuid            NULL,
    deleted_at              timestamptz     NULL,
    deleted_by              uuid            NULL,

    CONSTRAINT pk_amortization_schedules PRIMARY KEY (id),
    CONSTRAINT fk_as_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_as_prepaid_account
        FOREIGN KEY (prepaid_account_id) REFERENCES public.chart_of_accounts(id),
    CONSTRAINT fk_as_expense_account
        FOREIGN KEY (expense_account_id) REFERENCES public.chart_of_accounts(id),
    CONSTRAINT fk_as_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_as_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_as_deleted_by
        FOREIGN KEY (deleted_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_as_prepaid_type
        CHECK (prepaid_type IN ('prepaid_rent','prepaid_insurance','prepaid_software',
                                'prepaid_professional_fees','deferred_charge','other')),
    CONSTRAINT ck_as_frequency
        CHECK (frequency IN ('monthly','quarterly','annually')),
    CONSTRAINT ck_as_method
        CHECK (amortization_method IN ('straight_line')),
    CONSTRAINT ck_as_status
        CHECK (status IN ('active','completed','cancelled')),
    CONSTRAINT ck_as_date_range
        CHECK (end_date >= start_date),
    CONSTRAINT ck_as_total_amount_nneg
        CHECK (total_amount >= 0),
    CONSTRAINT ck_as_amortized_nneg
        CHECK (amount_amortized >= 0),
    CONSTRAINT ck_as_remaining_nneg
        CHECK (amount_remaining >= 0)
);

COMMENT ON TABLE public.amortization_schedules IS
    'Master header for prepaid expense / deferred charge amortization schedules. '
    'Phase 1: straight-line only. Posting engine reads active schedules each period '
    'and processes amortization_run_details to create journal entries.';

CREATE UNIQUE INDEX uq_amortization_schedules_name
    ON public.amortization_schedules (company_id, name)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_amortization_schedules_status
    ON public.amortization_schedules (company_id, status)
    WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- SECTION 2: amortization_schedule_lines
-- ---------------------------------------------------------------------------
-- Pre-computed amortization table — one row per period. Generated when the
-- schedule is created, allowing full preview before any run executes.
-- Not immutable — status and journal_entry_id are updated by the posting engine.
-- ---------------------------------------------------------------------------

CREATE TABLE public.amortization_schedule_lines (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                  uuid            NOT NULL,
    amortization_schedule_id    uuid            NOT NULL,
    period_date                 date            NOT NULL,
    fiscal_year_id              uuid            NOT NULL,
    fiscal_period_id            uuid            NOT NULL,
    line_no                     integer         NOT NULL,
    period_amount               numeric(18,4)   NOT NULL DEFAULT 0,
    cumulative_amount           numeric(18,4)   NOT NULL DEFAULT 0,
    remaining_after             numeric(18,4)   NOT NULL DEFAULT 0,
    status                      text            NOT NULL DEFAULT 'pending',
    journal_entry_id            uuid            NULL,

    CONSTRAINT pk_amortization_schedule_lines PRIMARY KEY (id),
    CONSTRAINT fk_asl_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_asl_schedule
        FOREIGN KEY (amortization_schedule_id) REFERENCES public.amortization_schedules(id),
    CONSTRAINT fk_asl_fiscal_year
        FOREIGN KEY (fiscal_year_id) REFERENCES public.fiscal_years(id),
    CONSTRAINT fk_asl_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_asl_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id),

    CONSTRAINT uq_asl_schedule_period
        UNIQUE (amortization_schedule_id, fiscal_period_id),

    CONSTRAINT ck_asl_status
        CHECK (status IN ('pending','processed','skipped')),
    CONSTRAINT ck_asl_period_amount_nneg
        CHECK (period_amount >= 0),
    CONSTRAINT ck_asl_cumulative_nneg
        CHECK (cumulative_amount >= 0)
);

COMMENT ON TABLE public.amortization_schedule_lines IS
    'Pre-computed amortization periods for a schedule. One row per fiscal period. '
    'journal_entry_id set by posting engine when processed. '
    'status transitions: pending → processed (or skipped if period is closed).';

CREATE INDEX idx_asl_schedule
    ON public.amortization_schedule_lines (amortization_schedule_id, status);

CREATE INDEX idx_asl_period
    ON public.amortization_schedule_lines (company_id, fiscal_period_id, status);

-- ---------------------------------------------------------------------------
-- SECTION 3: amortization_runs
-- ---------------------------------------------------------------------------
-- Batch execution header — one record per amortization run per fiscal period.
-- Supports async processing (Doc02 Principle 17).
-- Immutable once created (Doc02 Immutable=YES).
-- ---------------------------------------------------------------------------

CREATE TABLE public.amortization_runs (
    id                      uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid        NOT NULL,
    fiscal_year_id          uuid        NOT NULL,
    fiscal_period_id        uuid        NOT NULL,
    run_date                date        NOT NULL,
    status                  text        NOT NULL DEFAULT 'pending',
    schedules_included      integer     NOT NULL DEFAULT 0,
    entries_created         integer     NOT NULL DEFAULT 0,
    entries_failed          integer     NOT NULL DEFAULT 0,
    run_by                  uuid        NOT NULL,
    run_at                  timestamptz NOT NULL DEFAULT now(),
    completed_at            timestamptz NULL,
    error_message           text        NULL,

    -- Standard audit columns
    created_at              timestamptz NOT NULL DEFAULT now(),
    created_by              uuid        NULL,
    updated_at              timestamptz NOT NULL DEFAULT now(),
    updated_by              uuid        NULL,

    CONSTRAINT pk_amortization_runs PRIMARY KEY (id),
    CONSTRAINT fk_ar_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_ar_fiscal_year
        FOREIGN KEY (fiscal_year_id) REFERENCES public.fiscal_years(id),
    CONSTRAINT fk_ar_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_ar_run_by
        FOREIGN KEY (run_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_ar_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_ar_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_ar_status
        CHECK (status IN ('pending','processing','completed','failed','rolled_back')),
    CONSTRAINT ck_ar_counts_nneg
        CHECK (schedules_included >= 0 AND entries_created >= 0 AND entries_failed >= 0)
);

COMMENT ON TABLE public.amortization_runs IS
    'Batch execution header for amortization processing per fiscal period. '
    'Immutable once created (Doc02). Async pattern: Edge Function creates run '
    'record, processes schedule lines, updates counts atomically.';

CREATE INDEX idx_amortization_runs_company_period
    ON public.amortization_runs (company_id, fiscal_period_id);

-- ---------------------------------------------------------------------------
-- SECTION 4: amortization_run_details
-- ---------------------------------------------------------------------------
-- Traceability link: run → schedule line → generated journal entry.
-- One record per schedule line processed in a run. Immutable (Doc02).
-- ---------------------------------------------------------------------------

CREATE TABLE public.amortization_run_details (
    id                              uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                      uuid            NOT NULL,
    run_id                          uuid            NOT NULL,
    amortization_schedule_id        uuid            NOT NULL,
    amortization_schedule_line_id   uuid            NOT NULL,
    journal_entry_id                uuid            NULL,
    period_amount                   numeric(18,4)   NOT NULL DEFAULT 0,
    status                          text            NOT NULL DEFAULT 'pending',
    error_message                   text            NULL,

    CONSTRAINT pk_amortization_run_details PRIMARY KEY (id),
    CONSTRAINT fk_ard_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_ard_run
        FOREIGN KEY (run_id) REFERENCES public.amortization_runs(id),
    CONSTRAINT fk_ard_schedule
        FOREIGN KEY (amortization_schedule_id) REFERENCES public.amortization_schedules(id),
    CONSTRAINT fk_ard_schedule_line
        FOREIGN KEY (amortization_schedule_line_id) REFERENCES public.amortization_schedule_lines(id),
    CONSTRAINT fk_ard_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id),

    CONSTRAINT uq_ard_run_line
        UNIQUE (run_id, amortization_schedule_line_id),

    CONSTRAINT ck_ard_status
        CHECK (status IN ('pending','success','failed','rolled_back')),
    CONSTRAINT ck_ard_period_amount_nneg
        CHECK (period_amount >= 0)
);

COMMENT ON TABLE public.amortization_run_details IS
    'Traceability link: amortization run → schedule line → journal entry. '
    'journal_entry_id NULL when status = failed or pending. '
    'Enables full drill-down from JE back to the originating amortization schedule.';

CREATE INDEX idx_ard_run
    ON public.amortization_run_details (run_id);

CREATE INDEX idx_ard_schedule
    ON public.amortization_run_details (amortization_schedule_id);

-- ---------------------------------------------------------------------------
-- SECTION 5: revenue_recognition_schedules
-- ---------------------------------------------------------------------------
-- Master header for each deferred revenue item being recognized over time.
-- Covers annual retainers, service contracts, subscriptions, advance billings.
-- Phase 1: straight-line only.
-- ---------------------------------------------------------------------------

CREATE TABLE public.revenue_recognition_schedules (
    id                              uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                      uuid            NOT NULL,
    name                            text            NOT NULL,
    deferred_revenue_type           text            NOT NULL,
    source_document_type            text            NULL,
    source_document_id              uuid            NULL,
    customer_id                     uuid            NULL,
    deferred_revenue_account_id     uuid            NOT NULL,
    revenue_account_id              uuid            NOT NULL,
    total_amount                    numeric(18,4)   NOT NULL DEFAULT 0,
    amount_recognized               numeric(18,4)   NOT NULL DEFAULT 0,
    amount_remaining                numeric(18,4)   NOT NULL DEFAULT 0,
    start_date                      date            NOT NULL,
    end_date                        date            NOT NULL,
    frequency                       text            NOT NULL DEFAULT 'monthly',
    recognition_method              text            NOT NULL DEFAULT 'straight_line',
    status                          text            NOT NULL DEFAULT 'active',

    -- Standard audit columns
    created_at                      timestamptz     NOT NULL DEFAULT now(),
    created_by                      uuid            NULL,
    updated_at                      timestamptz     NOT NULL DEFAULT now(),
    updated_by                      uuid            NULL,
    deleted_at                      timestamptz     NULL,
    deleted_by                      uuid            NULL,

    CONSTRAINT pk_revenue_recognition_schedules PRIMARY KEY (id),
    CONSTRAINT fk_rrs_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_rrs_customer
        FOREIGN KEY (customer_id) REFERENCES public.customers(id),
    CONSTRAINT fk_rrs_deferred_revenue_account
        FOREIGN KEY (deferred_revenue_account_id) REFERENCES public.chart_of_accounts(id),
    CONSTRAINT fk_rrs_revenue_account
        FOREIGN KEY (revenue_account_id) REFERENCES public.chart_of_accounts(id),
    CONSTRAINT fk_rrs_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_rrs_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_rrs_deleted_by
        FOREIGN KEY (deleted_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_rrs_deferred_type
        CHECK (deferred_revenue_type IN ('annual_retainer','service_contract',
                                         'subscription','advance_billing','other')),
    CONSTRAINT ck_rrs_frequency
        CHECK (frequency IN ('monthly','quarterly','annually')),
    CONSTRAINT ck_rrs_method
        CHECK (recognition_method IN ('straight_line')),
    CONSTRAINT ck_rrs_status
        CHECK (status IN ('active','completed','cancelled')),
    CONSTRAINT ck_rrs_date_range
        CHECK (end_date >= start_date),
    CONSTRAINT ck_rrs_total_amount_nneg
        CHECK (total_amount >= 0)
);

COMMENT ON TABLE public.revenue_recognition_schedules IS
    'Master header for deferred revenue recognition schedules. '
    'DR Deferred Revenue → CR Revenue Account on each recognition run. '
    'Phase 1: straight-line only. source_document_type = sales_invoice or cash_sale.';

CREATE INDEX idx_rrs_company_status
    ON public.revenue_recognition_schedules (company_id, status)
    WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- SECTION 6: revenue_recognition_schedule_lines
-- ---------------------------------------------------------------------------

CREATE TABLE public.revenue_recognition_schedule_lines (
    id                              uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                      uuid            NOT NULL,
    revenue_recognition_schedule_id uuid            NOT NULL,
    period_date                     date            NOT NULL,
    fiscal_year_id                  uuid            NOT NULL,
    fiscal_period_id                uuid            NOT NULL,
    line_no                         integer         NOT NULL,
    period_amount                   numeric(18,4)   NOT NULL DEFAULT 0,
    cumulative_amount               numeric(18,4)   NOT NULL DEFAULT 0,
    remaining_after                 numeric(18,4)   NOT NULL DEFAULT 0,
    status                          text            NOT NULL DEFAULT 'pending',
    journal_entry_id                uuid            NULL,

    CONSTRAINT pk_revenue_recognition_schedule_lines PRIMARY KEY (id),
    CONSTRAINT fk_rrsl_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_rrsl_schedule
        FOREIGN KEY (revenue_recognition_schedule_id) REFERENCES public.revenue_recognition_schedules(id),
    CONSTRAINT fk_rrsl_fiscal_year
        FOREIGN KEY (fiscal_year_id) REFERENCES public.fiscal_years(id),
    CONSTRAINT fk_rrsl_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_rrsl_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id),

    CONSTRAINT uq_rrsl_schedule_period
        UNIQUE (revenue_recognition_schedule_id, fiscal_period_id),

    CONSTRAINT ck_rrsl_status
        CHECK (status IN ('pending','processed','skipped')),
    CONSTRAINT ck_rrsl_period_amount_nneg
        CHECK (period_amount >= 0)
);

COMMENT ON TABLE public.revenue_recognition_schedule_lines IS
    'Pre-computed revenue recognition periods — one row per fiscal period. '
    'journal_entry_id set when processed by revenue recognition run.';

CREATE INDEX idx_rrsl_schedule
    ON public.revenue_recognition_schedule_lines (revenue_recognition_schedule_id, status);

CREATE INDEX idx_rrsl_period
    ON public.revenue_recognition_schedule_lines (company_id, fiscal_period_id, status);

-- ---------------------------------------------------------------------------
-- SECTION 7: revenue_recognition_runs
-- ---------------------------------------------------------------------------

CREATE TABLE public.revenue_recognition_runs (
    id                  uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL,
    fiscal_year_id      uuid        NOT NULL,
    fiscal_period_id    uuid        NOT NULL,
    run_date            date        NOT NULL,
    status              text        NOT NULL DEFAULT 'pending',
    schedules_included  integer     NOT NULL DEFAULT 0,
    entries_created     integer     NOT NULL DEFAULT 0,
    entries_failed      integer     NOT NULL DEFAULT 0,
    run_by              uuid        NOT NULL,
    run_at              timestamptz NOT NULL DEFAULT now(),
    completed_at        timestamptz NULL,
    error_message       text        NULL,

    -- Standard audit columns
    created_at          timestamptz NOT NULL DEFAULT now(),
    created_by          uuid        NULL,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          uuid        NULL,

    CONSTRAINT pk_revenue_recognition_runs PRIMARY KEY (id),
    CONSTRAINT fk_rrr_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_rrr_fiscal_year
        FOREIGN KEY (fiscal_year_id) REFERENCES public.fiscal_years(id),
    CONSTRAINT fk_rrr_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_rrr_run_by
        FOREIGN KEY (run_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_rrr_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_rrr_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_rrr_status
        CHECK (status IN ('pending','processing','completed','failed','rolled_back')),
    CONSTRAINT ck_rrr_counts_nneg
        CHECK (schedules_included >= 0 AND entries_created >= 0 AND entries_failed >= 0)
);

COMMENT ON TABLE public.revenue_recognition_runs IS
    'Batch execution header for revenue recognition processing per fiscal period. '
    'Mirrors amortization_runs pattern (Doc02 Principle 17 async).';

CREATE INDEX idx_rrr_company_period
    ON public.revenue_recognition_runs (company_id, fiscal_period_id);

-- ---------------------------------------------------------------------------
-- SECTION 8: revenue_recognition_run_details
-- ---------------------------------------------------------------------------

CREATE TABLE public.revenue_recognition_run_details (
    id                                      uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                              uuid            NOT NULL,
    run_id                                  uuid            NOT NULL,
    revenue_recognition_schedule_id         uuid            NOT NULL,
    revenue_recognition_schedule_line_id    uuid            NOT NULL,
    journal_entry_id                        uuid            NULL,
    period_amount                           numeric(18,4)   NOT NULL DEFAULT 0,
    status                                  text            NOT NULL DEFAULT 'pending',
    error_message                           text            NULL,

    CONSTRAINT pk_revenue_recognition_run_details PRIMARY KEY (id),
    CONSTRAINT fk_rrrd_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_rrrd_run
        FOREIGN KEY (run_id) REFERENCES public.revenue_recognition_runs(id),
    CONSTRAINT fk_rrrd_schedule
        FOREIGN KEY (revenue_recognition_schedule_id) REFERENCES public.revenue_recognition_schedules(id),
    CONSTRAINT fk_rrrd_schedule_line
        FOREIGN KEY (revenue_recognition_schedule_line_id) REFERENCES public.revenue_recognition_schedule_lines(id),
    CONSTRAINT fk_rrrd_journal_entry
        FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id),

    CONSTRAINT uq_rrrd_run_line
        UNIQUE (run_id, revenue_recognition_schedule_line_id),

    CONSTRAINT ck_rrrd_status
        CHECK (status IN ('pending','success','failed','rolled_back')),
    CONSTRAINT ck_rrrd_period_amount_nneg
        CHECK (period_amount >= 0)
);

COMMENT ON TABLE public.revenue_recognition_run_details IS
    'Traceability link: revenue recognition run → schedule line → journal entry. '
    'journal_entry_id NULL when status = failed or pending. '
    'Mirrors amortization_run_details pattern.';

CREATE INDEX idx_rrrd_run
    ON public.revenue_recognition_run_details (run_id);

CREATE INDEX idx_rrrd_schedule
    ON public.revenue_recognition_run_details (revenue_recognition_schedule_id);

-- ---------------------------------------------------------------------------
-- SECTION 9: auto_reversal_runs
-- ---------------------------------------------------------------------------
-- Batch execution header for auto-reversal processing at period start.
-- Processes all journal_entries WHERE auto_reversal_flag=true AND
-- auto_reversal_date falls within the new period.
-- Immutable (Doc02). No soft delete.
-- ---------------------------------------------------------------------------

CREATE TABLE public.auto_reversal_runs (
    id                  uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL,
    fiscal_year_id      uuid        NOT NULL,
    fiscal_period_id    uuid        NOT NULL,
    run_date            date        NOT NULL,
    status              text        NOT NULL DEFAULT 'pending',
    entries_reversed    integer     NOT NULL DEFAULT 0,
    entries_failed      integer     NOT NULL DEFAULT 0,
    run_by              uuid        NOT NULL,
    run_at              timestamptz NOT NULL DEFAULT now(),
    completed_at        timestamptz NULL,

    -- Standard audit columns
    created_at          timestamptz NOT NULL DEFAULT now(),
    created_by          uuid        NULL,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          uuid        NULL,

    CONSTRAINT pk_auto_reversal_runs PRIMARY KEY (id),
    CONSTRAINT fk_arr_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_arr_fiscal_year
        FOREIGN KEY (fiscal_year_id) REFERENCES public.fiscal_years(id),
    CONSTRAINT fk_arr_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_arr_run_by
        FOREIGN KEY (run_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_arr_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_arr_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_arr_status
        CHECK (status IN ('pending','processing','completed','failed')),
    CONSTRAINT ck_arr_counts_nneg
        CHECK (entries_reversed >= 0 AND entries_failed >= 0)
);

COMMENT ON TABLE public.auto_reversal_runs IS
    'Batch execution header for auto-reversal processing. At period start, the '
    'posting engine processes all journal_entries WHERE auto_reversal_flag=true '
    'AND auto_reversal_date falls in the new period. For each processed JE: '
    '(1) creates reversal JE with is_auto_reversal=true, reversal_of_je_id=original.id, '
    'auto_reversal_run_id=this.id; (2) updates original JE auto_reversal_run_id and '
    'reversed_by_je_id (Doc03 §v3 Note).';

CREATE INDEX idx_auto_reversal_runs_company_period
    ON public.auto_reversal_runs (company_id, fiscal_period_id);

-- ---------------------------------------------------------------------------
-- SECTION 10: ALTER TABLE — Wire deferred FKs to Module 31 tables
-- ---------------------------------------------------------------------------
-- Migration 013 declared these three journal_entries columns as plain uuid NULL
-- with comment "FK constraint deferred to Module 31 migration."
-- Module 31 tables now exist — add the FK constraints.
-- ---------------------------------------------------------------------------

ALTER TABLE public.journal_entries
    ADD CONSTRAINT fk_je_auto_reversal_run
        FOREIGN KEY (auto_reversal_run_id) REFERENCES public.auto_reversal_runs(id);

ALTER TABLE public.journal_entries
    ADD CONSTRAINT fk_je_amortization_run_detail
        FOREIGN KEY (amortization_run_detail_id) REFERENCES public.amortization_run_details(id);

ALTER TABLE public.journal_entries
    ADD CONSTRAINT fk_je_revenue_recognition_run_detail
        FOREIGN KEY (revenue_recognition_run_detail_id) REFERENCES public.revenue_recognition_run_details(id);

-- ---------------------------------------------------------------------------
-- END OF MIGRATION 014
-- ---------------------------------------------------------------------------
-- Tables created: 9 (Module 31 — Accounting Schedules)
-- ALTER TABLE ADD CONSTRAINT: 3 (deferred FKs on journal_entries from Mig 013)
--
-- Posting engine support is now complete:
--   Modules 12/13: posting_rule_sets, posting_rule_lines (Migration 012)
--   Module 16 GL runtime: 9 tables (Migration 013)
--   Module 31 schedules: 9 tables (this migration)
--
-- No further posting-engine runtime tables remain unbuilt.
-- ---------------------------------------------------------------------------
