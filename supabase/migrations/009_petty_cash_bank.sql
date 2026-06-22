-- =============================================================================
-- Migration 009: Petty Cash & Bank — Modules 12–13
-- =============================================================================
-- Tables created (14, in FK dependency order):
--
-- MODULE 12 — PETTY CASH
--   petty_cash_funds (#95)          — master, Soft Delete=YES, Immutable=NO
--   petty_cash_vouchers (#96)        — transaction, Immutable=YES
--   petty_cash_voucher_lines (#97)   — transaction, Immutable=YES
--   petty_cash_replenishments (#98)  — transaction, Immutable=YES
--   petty_cash_count_sheets (#99)    — transaction, Immutable=YES
--   petty_cash_count_lines (#100)    — transaction, Immutable=YES
--
-- MODULE 13 — BANK
--   bank_fund_transfers (#101)        — transaction, Immutable=YES
--   inter_branch_transfers (#102)     — transaction, Immutable=YES
--   bank_adjustments (#103)           — transaction, Immutable=YES
--   bank_reconciliations (#104)       — transaction, Immutable=YES
--   bank_reconciliation_lines (#105)  — transaction, Immutable=YES
--   bank_statement_lines (#106)       — transaction, Immutable=YES
--   outstanding_checks (#107)         — ledger, Immutable=NO (mutable by recon process)
--   deposits_in_transit (#108)        — ledger, Immutable=NO (mutable by recon process)
--
-- Intentionally deferred:
--   journal_entry_id FK  → journal_entries  (Migration 016)
--     Affects: petty_cash_vouchers, petty_cash_replenishments, bank_fund_transfers,
--              inter_branch_transfers, bank_adjustments, bank_reconciliations
--   bank_reconciliation_lines.source_journal_entry_id FK → journal_entries (Mig 016)
--   import_batch_id FK   → import_batches   (Migration 023)
--     Affects: bank_statement_lines (standard header column)
--   RLS policies         → Migration 017
--   Triggers / functions → dedicated trigger migration
--
-- FK dependency order:
--   Group A: petty_cash_funds (refs companies, branches, profiles)
--   Group B: petty_cash_vouchers (refs petty_cash_funds)
--            petty_cash_voucher_lines (refs petty_cash_vouchers,
--              chart_of_accounts, vat_codes, atc_codes)
--   Group C: petty_cash_replenishments (refs petty_cash_funds, payment_vouchers)
--            petty_cash_count_sheets (refs petty_cash_funds)
--            petty_cash_count_lines (refs petty_cash_count_sheets)
--   Group D: bank_fund_transfers (refs company_bank_accounts)
--            inter_branch_transfers (refs branches, company_bank_accounts)
--            bank_adjustments (refs company_bank_accounts)
--            bank_reconciliations (refs company_bank_accounts)
--   Group E: bank_reconciliation_lines (refs bank_reconciliations)
--            bank_statement_lines (refs company_bank_accounts, bank_reconciliations)
--   Group F: outstanding_checks (refs company_bank_accounts, payment_vouchers)
--            deposits_in_transit (refs company_bank_accounts, receipts)
--
-- Posting dependencies:
--   petty_cash_vouchers.journal_entry_id — set at posting; FK deferred Mig 016
--   petty_cash_replenishments is linked to a payment_voucher (Migration 008 table)
--     for the replenishment check — FK available now, added.
--   bank_fund_transfers, inter_branch_transfers, bank_adjustments,
--   bank_reconciliations — all carry journal_entry_id; FK deferred Mig 016
--   bank_reconciliation_lines.source_journal_entry_id — deferred Mig 016
--
-- Compliance dependencies (OD-09 resolved):
--   EWT on petty cash captured at petty_cash_voucher LINE level (ewt_atc_id,
--   ewt_amount). Posting engine writes ewt_entries at voucher posting.
--   Replenishment payment voucher does NOT re-capture EWT.
--   This matches cash_purchase treatment for QAP / 1601EQ sourcing.
--
-- Special patterns:
--   petty_cash_funds.current_balance — mutable; updated by posting engine
--     (service role only). Same guard pattern as
--     customer_credit_profiles.current_outstanding (backlog M-009-1).
--   outstanding_checks / deposits_in_transit — ledger tables, Immutable=NO;
--     cleared_date set by bank reconciliation process. Full standard audit
--     columns included (updated_at/updated_by) because they are mutable ledgers.
-- =============================================================================

-- =============================================================================
-- MODULE 12: PETTY CASH
-- =============================================================================

-- =============================================================================
-- GROUP A: petty_cash_funds — master, Soft Delete=YES, Immutable=NO
-- =============================================================================

-- #95 petty_cash_funds
-- Imprest petty cash fund per branch. One fund can exist per branch/custodian
-- combination. current_balance is maintained by the posting engine.
CREATE TABLE public.petty_cash_funds (
    id               uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id       uuid          NOT NULL REFERENCES public.companies(id),
    branch_id        uuid          NOT NULL REFERENCES public.branches(id),
    fund_name        text          NOT NULL,
    custodian_id     uuid          NULL     REFERENCES public.profiles(id),
    imprest_amount   numeric(18,4) NOT NULL,
    -- maintained exclusively by posting engine (service role)
    current_balance  numeric(18,4) NOT NULL,
    is_active        boolean       NOT NULL DEFAULT true,
    -- standard audit (Soft Delete=YES, Immutable=NO)
    created_at       timestamptz   NOT NULL DEFAULT now(),
    created_by       uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at       timestamptz   NULL,
    updated_by       uuid          NULL     REFERENCES public.profiles(id),
    deleted_at       timestamptz   NULL,
    deleted_by       uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_petty_cash_funds PRIMARY KEY (id),
    CONSTRAINT ck_pcf_imprest CHECK (imprest_amount > 0),
    CONSTRAINT ck_pcf_balance CHECK (current_balance >= 0)
);

COMMENT ON COLUMN public.petty_cash_funds.current_balance
    IS 'Maintained exclusively by the petty cash posting engine (service role). Application users must NOT update this column directly. RLS policy in Migration 017 must RESTRICT writes to service role only.';

-- One active fund per company+branch+name combination
CREATE UNIQUE INDEX uq_petty_cash_funds_active
    ON public.petty_cash_funds (company_id, branch_id, fund_name)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_petty_cash_funds_branch
    ON public.petty_cash_funds (company_id, branch_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.petty_cash_funds ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP B: petty_cash_vouchers + petty_cash_voucher_lines
--          Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #96 petty_cash_vouchers
-- Individual petty cash disbursement. Immutable once posted.
-- payee_id is polymorphic: references suppliers.id or personnel.id depending
-- on payee_type. No DB FK — application resolves target table.
-- EWT is captured at LINE level per OD-09 (not at replenishment).
CREATE TABLE public.petty_cash_vouchers (
    id                    uuid          NOT NULL DEFAULT gen_random_uuid(),
    -- standard dimension columns
    company_id            uuid          NOT NULL REFERENCES public.companies(id),
    branch_id             uuid          NULL     REFERENCES public.branches(id),
    department_id         uuid          NULL     REFERENCES public.departments(id),
    cost_center_id        uuid          NULL     REFERENCES public.cost_centers(id),
    -- standard transaction header
    document_no           text          NOT NULL,
    document_date         date          NOT NULL,
    posting_date          date          NULL,
    fiscal_year_id        uuid          NOT NULL REFERENCES public.fiscal_years(id),
    fiscal_period_id      uuid          NOT NULL REFERENCES public.fiscal_periods(id),
    currency_id           uuid          NOT NULL REFERENCES public.currencies(id),
    exchange_rate         numeric(10,6) NOT NULL DEFAULT 1.000000,
    status                text          NOT NULL DEFAULT 'draft',
    subtotal_amount       numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount            numeric(18,4) NOT NULL DEFAULT 0,
    withholding_amount    numeric(18,4) NOT NULL DEFAULT 0,
    total_amount          numeric(18,4) NOT NULL DEFAULT 0,
    remarks               text          NULL,
    posted_at             timestamptz   NULL,
    posted_by             uuid          NULL     REFERENCES public.profiles(id),
    voided_at             timestamptz   NULL,
    voided_by             uuid          NULL     REFERENCES public.profiles(id),
    void_reason           text          NULL,
    reversed_by_doc_id    uuid          NULL     REFERENCES public.petty_cash_vouchers(id),
    source_document_id    uuid          NULL,
    source_document_type  text          NULL,
    import_batch_id       uuid          NULL,
    -- petty_cash_vouchers-specific
    petty_cash_fund_id    uuid          NOT NULL REFERENCES public.petty_cash_funds(id),
    payee_name            text          NOT NULL,
    payee_type            text          NOT NULL DEFAULT 'supplier',
    -- polymorphic: supplier.id or personnel.id — no DB FK
    payee_id              uuid          NULL,
    payment_method        text          NOT NULL DEFAULT 'cash',
    approved_by           uuid          NULL     REFERENCES public.profiles(id),
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id      uuid          NULL,
    -- standard audit (Immutable=YES)
    created_at            timestamptz   NOT NULL DEFAULT now(),
    created_by            uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_petty_cash_vouchers PRIMARY KEY (id),
    CONSTRAINT uq_pcv_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_pcv_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_pcv_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_pcv_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND
        withholding_amount >= 0 AND total_amount >= 0
    ),
    CONSTRAINT ck_pcv_payee_type CHECK (
        payee_type IN ('supplier','employee','other')
    ),
    CONSTRAINT ck_pcv_payment_method CHECK (payment_method IN ('cash'))
);

COMMENT ON COLUMN public.petty_cash_vouchers.payee_id
    IS 'Polymorphic FK: references suppliers.id when payee_type=''supplier'', personnel.id when payee_type=''employee''. No DB-level FK; application resolves target table based on payee_type.';
COMMENT ON COLUMN public.petty_cash_vouchers.journal_entry_id
    IS 'FK to journal_entries deferred to Migration 016. Column present; constraint added when journal_entries table is created.';

CREATE INDEX ix_petty_cash_vouchers_company_date
    ON public.petty_cash_vouchers (company_id, document_date);

CREATE INDEX ix_petty_cash_vouchers_fund
    ON public.petty_cash_vouchers (petty_cash_fund_id);

CREATE INDEX ix_petty_cash_vouchers_status
    ON public.petty_cash_vouchers (company_id, status);

ALTER TABLE public.petty_cash_vouchers ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #97 petty_cash_voucher_lines
-- Expense lines on a petty cash voucher. EWT captured here per OD-09.
-- expense_account_id is NOT NULL — every petty cash line must map to a GL account.
CREATE TABLE public.petty_cash_voucher_lines (
    id                      uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid          NOT NULL REFERENCES public.companies(id),
    petty_cash_voucher_id   uuid          NOT NULL REFERENCES public.petty_cash_vouchers(id),
    line_no                 integer       NOT NULL,
    description             text          NOT NULL,
    expense_account_id      uuid          NOT NULL REFERENCES public.chart_of_accounts(id),
    net_amount              numeric(18,4) NOT NULL,
    vat_code_id             uuid          NULL     REFERENCES public.vat_codes(id),
    vat_amount              numeric(18,4) NOT NULL DEFAULT 0,
    -- EWT captured at voucher line level per OD-09 resolved decision
    ewt_atc_id              uuid          NULL     REFERENCES public.atc_codes(id),
    ewt_amount              numeric(18,4) NOT NULL DEFAULT 0,
    total_amount            numeric(18,4) NOT NULL,
    -- standard audit (Immutable=YES)
    created_at              timestamptz   NOT NULL DEFAULT now(),
    created_by              uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_petty_cash_voucher_lines PRIMARY KEY (id),
    CONSTRAINT ck_pcvl_line_no CHECK (line_no > 0),
    CONSTRAINT ck_pcvl_net_amount CHECK (net_amount >= 0),
    CONSTRAINT ck_pcvl_amounts CHECK (
        vat_amount >= 0 AND ewt_amount >= 0 AND total_amount >= 0
    )
);

COMMENT ON COLUMN public.petty_cash_voucher_lines.ewt_atc_id
    IS 'EWT is captured at voucher LINE level per OD-09. Posting engine writes ewt_entries from this column. Replenishment payment_voucher does NOT re-capture EWT — it is already booked at this level.';

CREATE INDEX ix_petty_cash_voucher_lines_voucher
    ON public.petty_cash_voucher_lines (petty_cash_voucher_id);

CREATE INDEX ix_petty_cash_voucher_lines_ewt
    ON public.petty_cash_voucher_lines (ewt_atc_id)
    WHERE ewt_atc_id IS NOT NULL;

ALTER TABLE public.petty_cash_voucher_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP C: petty_cash_replenishments, petty_cash_count_sheets,
--          petty_cash_count_lines — Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #98 petty_cash_replenishments
-- Replenishment request — restores the fund back to its imprest amount.
-- A payment_voucher (Migration 008) is issued to settle the replenishment check.
-- replenishment_amount = imprest_amount − current_balance at time of request.
-- total_vouchers_amount = sum of petty_cash_vouchers since last replenishment.
CREATE TABLE public.petty_cash_replenishments (
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
    reversed_by_doc_id      uuid          NULL     REFERENCES public.petty_cash_replenishments(id),
    source_document_id      uuid          NULL,
    source_document_type    text          NULL,
    import_batch_id         uuid          NULL,
    -- petty_cash_replenishments-specific
    fund_id                 uuid          NOT NULL REFERENCES public.petty_cash_funds(id),
    replenishment_amount    numeric(18,4) NOT NULL,
    total_vouchers_amount   numeric(18,4) NOT NULL,
    approved_by             uuid          NULL     REFERENCES public.profiles(id),
    -- FK to payment_vouchers (Migration 008) — available now
    payment_voucher_id      uuid          NULL     REFERENCES public.payment_vouchers(id),
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id        uuid          NULL,
    -- standard audit (Immutable=YES)
    created_at              timestamptz   NOT NULL DEFAULT now(),
    created_by              uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_petty_cash_replenishments PRIMARY KEY (id),
    CONSTRAINT uq_pcr_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_pcr_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_pcr_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_pcr_amounts CHECK (
        replenishment_amount > 0 AND total_vouchers_amount >= 0
    )
);

COMMENT ON COLUMN public.petty_cash_replenishments.journal_entry_id
    IS 'FK to journal_entries deferred to Migration 016.';
COMMENT ON COLUMN public.petty_cash_replenishments.payment_voucher_id
    IS 'The payment_voucher issued to fund this replenishment. EWT is NOT re-captured on the replenishment PV — it was already captured at petty_cash_voucher_line level per OD-09.';

CREATE INDEX ix_petty_cash_replenishments_fund
    ON public.petty_cash_replenishments (fund_id);

CREATE INDEX ix_petty_cash_replenishments_company_date
    ON public.petty_cash_replenishments (company_id, document_date);

ALTER TABLE public.petty_cash_replenishments ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #99 petty_cash_count_sheets
-- Physical cash count header for a specific fund.
-- overage_shortage = physical_count_amount − book_balance.
-- Positive = overage; negative = shortage.
CREATE TABLE public.petty_cash_count_sheets (
    id                    uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id            uuid          NOT NULL REFERENCES public.companies(id),
    branch_id             uuid          NOT NULL REFERENCES public.branches(id),
    fund_id               uuid          NOT NULL REFERENCES public.petty_cash_funds(id),
    count_date            date          NOT NULL,
    physical_count_amount numeric(18,4) NOT NULL,
    book_balance          numeric(18,4) NOT NULL,
    overage_shortage      numeric(18,4) NOT NULL DEFAULT 0,
    counted_by            uuid          NOT NULL REFERENCES public.profiles(id),
    verified_by           uuid          NULL     REFERENCES public.profiles(id),
    -- standard audit (Immutable=YES)
    created_at            timestamptz   NOT NULL DEFAULT now(),
    created_by            uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_petty_cash_count_sheets PRIMARY KEY (id),
    CONSTRAINT ck_pccs_amounts CHECK (physical_count_amount >= 0 AND book_balance >= 0)
);

CREATE INDEX ix_petty_cash_count_sheets_fund
    ON public.petty_cash_count_sheets (fund_id);

CREATE INDEX ix_petty_cash_count_sheets_date
    ON public.petty_cash_count_sheets (company_id, count_date);

ALTER TABLE public.petty_cash_count_sheets ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #100 petty_cash_count_lines
-- Denomination breakdown of a physical cash count.
-- subtotal = denomination × quantity (computed by application, stored for audit).
CREATE TABLE public.petty_cash_count_lines (
    id              uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id      uuid          NOT NULL REFERENCES public.companies(id),
    count_sheet_id  uuid          NOT NULL REFERENCES public.petty_cash_count_sheets(id),
    denomination    numeric(18,4) NOT NULL,
    quantity        integer       NOT NULL,
    subtotal        numeric(18,4) NOT NULL,
    -- standard audit (Immutable=YES)
    created_at      timestamptz   NOT NULL DEFAULT now(),
    created_by      uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_petty_cash_count_lines PRIMARY KEY (id),
    CONSTRAINT ck_pccl_denomination CHECK (denomination > 0),
    CONSTRAINT ck_pccl_quantity CHECK (quantity >= 0),
    CONSTRAINT ck_pccl_subtotal CHECK (subtotal >= 0)
);

CREATE INDEX ix_petty_cash_count_lines_sheet
    ON public.petty_cash_count_lines (count_sheet_id);

ALTER TABLE public.petty_cash_count_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- MODULE 13: BANK
-- =============================================================================

-- =============================================================================
-- GROUP D: Bank transaction headers — Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #101 bank_fund_transfers
-- Transfer of funds between two of the company's own bank accounts.
-- Generates two journal lines: debit target account, credit source account.
-- transfer_fee reduces the from_account and is booked as bank charges expense.
CREATE TABLE public.bank_fund_transfers (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.bank_fund_transfers(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- bank_fund_transfers-specific
    from_account_id      uuid          NOT NULL REFERENCES public.company_bank_accounts(id),
    to_account_id        uuid          NOT NULL REFERENCES public.company_bank_accounts(id),
    transfer_amount      numeric(18,4) NOT NULL,
    transfer_fee         numeric(18,4) NOT NULL DEFAULT 0,
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id     uuid          NULL,
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_bank_fund_transfers PRIMARY KEY (id),
    CONSTRAINT uq_bft_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_bft_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_bft_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_bft_transfer_amount CHECK (transfer_amount > 0),
    CONSTRAINT ck_bft_transfer_fee CHECK (transfer_fee >= 0),
    CONSTRAINT ck_bft_accounts_differ CHECK (from_account_id != to_account_id)
);

COMMENT ON COLUMN public.bank_fund_transfers.journal_entry_id
    IS 'FK to journal_entries deferred to Migration 016.';

CREATE INDEX ix_bank_fund_transfers_company_date
    ON public.bank_fund_transfers (company_id, document_date);

CREATE INDEX ix_bank_fund_transfers_from_account
    ON public.bank_fund_transfers (from_account_id);

CREATE INDEX ix_bank_fund_transfers_to_account
    ON public.bank_fund_transfers (to_account_id);

ALTER TABLE public.bank_fund_transfers ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #102 inter_branch_transfers
-- Fund transfer between branches of the same company. Uses due-to / due-from
-- accounts (inter-branch clearing) in the posting engine.
CREATE TABLE public.inter_branch_transfers (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.inter_branch_transfers(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- inter_branch_transfers-specific
    from_branch_id       uuid          NOT NULL REFERENCES public.branches(id),
    to_branch_id         uuid          NOT NULL REFERENCES public.branches(id),
    from_account_id      uuid          NOT NULL REFERENCES public.company_bank_accounts(id),
    to_account_id        uuid          NOT NULL REFERENCES public.company_bank_accounts(id),
    transfer_amount      numeric(18,4) NOT NULL,
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id     uuid          NULL,
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_inter_branch_transfers PRIMARY KEY (id),
    CONSTRAINT uq_ibt_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_ibt_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_ibt_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_ibt_transfer_amount CHECK (transfer_amount > 0),
    CONSTRAINT ck_ibt_branches_differ CHECK (from_branch_id != to_branch_id)
);

COMMENT ON TABLE public.inter_branch_transfers
    IS 'Inter-branch fund transfer. Posting engine uses due-to/due-from inter-company clearing accounts. from_branch_id and to_branch_id must belong to the same company_id.';
COMMENT ON COLUMN public.inter_branch_transfers.journal_entry_id
    IS 'FK to journal_entries deferred to Migration 016.';

CREATE INDEX ix_inter_branch_transfers_company_date
    ON public.inter_branch_transfers (company_id, document_date);

CREATE INDEX ix_inter_branch_transfers_from_branch
    ON public.inter_branch_transfers (from_branch_id);

CREATE INDEX ix_inter_branch_transfers_to_branch
    ON public.inter_branch_transfers (to_branch_id);

ALTER TABLE public.inter_branch_transfers ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #103 bank_adjustments
-- Bank debit/credit memos and charges (e.g., service fees, interest income,
-- returned check charges). is_debit=true reduces book balance (DR bank charges,
-- CR cash); is_debit=false increases book balance (DR cash, CR interest income).
CREATE TABLE public.bank_adjustments (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.bank_adjustments(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- bank_adjustments-specific
    bank_account_id      uuid          NOT NULL REFERENCES public.company_bank_accounts(id),
    adjustment_type      text          NOT NULL,
    amount               numeric(18,4) NOT NULL,
    is_debit             boolean       NOT NULL,
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id     uuid          NULL,
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_bank_adjustments PRIMARY KEY (id),
    CONSTRAINT uq_ba_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_ba_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_ba_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_ba_amount CHECK (amount > 0),
    CONSTRAINT ck_ba_adjustment_type CHECK (
        adjustment_type IN ('debit_memo','credit_memo','bank_charge','interest_income','other')
    )
);

COMMENT ON COLUMN public.bank_adjustments.is_debit
    IS 'true = reduces book cash balance (e.g., bank charge, returned check fee). false = increases book cash balance (e.g., interest earned, credit memo).';
COMMENT ON COLUMN public.bank_adjustments.journal_entry_id
    IS 'FK to journal_entries deferred to Migration 016.';

CREATE INDEX ix_bank_adjustments_company_date
    ON public.bank_adjustments (company_id, document_date);

CREATE INDEX ix_bank_adjustments_bank_account
    ON public.bank_adjustments (bank_account_id);

ALTER TABLE public.bank_adjustments ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #104 bank_reconciliations
-- Bank reconciliation header per bank account per statement period.
-- reconciled_balance = book balance ± all reconciling items.
-- is_reconciled = true only when book-adjusted balance equals bank-adjusted balance.
CREATE TABLE public.bank_reconciliations (
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
    reversed_by_doc_id        uuid          NULL     REFERENCES public.bank_reconciliations(id),
    source_document_id        uuid          NULL,
    source_document_type      text          NULL,
    import_batch_id           uuid          NULL,
    -- bank_reconciliations-specific
    bank_account_id           uuid          NOT NULL REFERENCES public.company_bank_accounts(id),
    statement_date            date          NOT NULL,
    statement_ending_balance  numeric(18,4) NOT NULL,
    book_ending_balance       numeric(18,4) NOT NULL,
    reconciled_balance        numeric(18,4) NOT NULL DEFAULT 0,
    is_reconciled             boolean       NOT NULL DEFAULT false,
    reconciled_at             timestamptz   NULL,
    reconciled_by             uuid          NULL     REFERENCES public.profiles(id),
    -- journal_entry_id FK deferred to Migration 016 (for book adjustment JEs)
    journal_entry_id          uuid          NULL,
    -- standard audit (Immutable=YES)
    created_at                timestamptz   NOT NULL DEFAULT now(),
    created_by                uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_bank_reconciliations PRIMARY KEY (id),
    CONSTRAINT uq_br_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_br_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_br_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_br_reconciled CHECK (
        is_reconciled = false OR reconciled_at IS NOT NULL
    )
);

-- One reconciliation per account per statement date
CREATE UNIQUE INDEX uq_bank_reconciliations_account_period
    ON public.bank_reconciliations (bank_account_id, statement_date)
    WHERE status NOT IN ('voided','cancelled');

COMMENT ON COLUMN public.bank_reconciliations.journal_entry_id
    IS 'FK to journal_entries deferred to Migration 016. Used when book adjustment JEs are generated at reconciliation finalization.';

CREATE INDEX ix_bank_reconciliations_company_date
    ON public.bank_reconciliations (company_id, document_date);

CREATE INDEX ix_bank_reconciliations_bank_account
    ON public.bank_reconciliations (bank_account_id);

ALTER TABLE public.bank_reconciliations ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP E: bank_reconciliation_lines, bank_statement_lines — Immutable=YES
-- =============================================================================

-- #105 bank_reconciliation_lines
-- Individual reconciling items (outstanding checks, deposits in transit,
-- book adjustments). source_journal_entry_id FK deferred to Migration 016.
CREATE TABLE public.bank_reconciliation_lines (
    id                        uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id                uuid          NOT NULL REFERENCES public.companies(id),
    bank_reconciliation_id    uuid          NOT NULL REFERENCES public.bank_reconciliations(id),
    line_type                 text          NOT NULL,
    -- source_journal_entry_id FK to journal_entries deferred to Migration 016
    source_journal_entry_id   uuid          NULL,
    description               text          NOT NULL,
    amount                    numeric(18,4) NOT NULL,
    is_cleared                boolean       NOT NULL DEFAULT false,
    cleared_date              date          NULL,
    -- standard audit (Immutable=YES)
    created_at                timestamptz   NOT NULL DEFAULT now(),
    created_by                uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_bank_reconciliation_lines PRIMARY KEY (id),
    CONSTRAINT ck_brl_line_type CHECK (
        line_type IN ('outstanding_check','deposit_in_transit','bank_adjustment','book_adjustment')
    ),
    CONSTRAINT ck_brl_cleared CHECK (
        is_cleared = false OR cleared_date IS NOT NULL
    )
);

COMMENT ON COLUMN public.bank_reconciliation_lines.source_journal_entry_id
    IS 'FK to journal_entries deferred to Migration 016. Column present; constraint added when journal_entries table is created.';

CREATE INDEX ix_bank_reconciliation_lines_recon
    ON public.bank_reconciliation_lines (bank_reconciliation_id);

ALTER TABLE public.bank_reconciliation_lines ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #106 bank_statement_lines
-- Imported bank statement lines for auto-matching during reconciliation.
-- matched_to_id is polymorphic: receipt.id, payment_voucher.id,
-- bank_adjustment.id, or journal_entry.id depending on matched_to_type.
-- import_batch_id FK deferred to Migration 023.
CREATE TABLE public.bank_statement_lines (
    id                      uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid          NOT NULL REFERENCES public.companies(id),
    bank_account_id         uuid          NOT NULL REFERENCES public.company_bank_accounts(id),
    -- bank_reconciliation_id set when line is matched and reconciliation is opened
    bank_reconciliation_id  uuid          NULL     REFERENCES public.bank_reconciliations(id),
    statement_date          date          NOT NULL,
    value_date              date          NULL,
    description             text          NOT NULL,
    reference               text          NULL,
    debit_amount            numeric(18,4) NOT NULL DEFAULT 0,
    credit_amount           numeric(18,4) NOT NULL DEFAULT 0,
    balance                 numeric(18,4) NULL,
    reconciliation_status   text          NOT NULL DEFAULT 'unmatched',
    -- polymorphic: 'receipt' | 'payment_voucher' | 'bank_adjustment' | 'journal_entry'
    matched_to_type         text          NULL,
    matched_to_id           uuid          NULL,
    -- import_batch_id FK deferred to Migration 023
    import_batch_id         uuid          NULL,
    -- standard audit (Immutable=YES)
    created_at              timestamptz   NOT NULL DEFAULT now(),
    created_by              uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_bank_statement_lines PRIMARY KEY (id),
    CONSTRAINT ck_bsl_reconciliation_status CHECK (
        reconciliation_status IN ('unmatched','matched','cleared','exception')
    ),
    CONSTRAINT ck_bsl_matched_to_type CHECK (
        matched_to_type IS NULL OR
        matched_to_type IN ('receipt','payment_voucher','bank_adjustment','journal_entry')
    ),
    CONSTRAINT ck_bsl_amounts CHECK (debit_amount >= 0 AND credit_amount >= 0),
    -- A statement line is either a debit or a credit, not both
    CONSTRAINT ck_bsl_debit_or_credit CHECK (
        debit_amount = 0 OR credit_amount = 0
    )
);

COMMENT ON COLUMN public.bank_statement_lines.matched_to_id
    IS 'Polymorphic FK: references receipts.id, payment_vouchers.id, bank_adjustments.id, or journal_entries.id depending on matched_to_type. No DB-level FK; application resolves target table.';
COMMENT ON COLUMN public.bank_statement_lines.import_batch_id
    IS 'FK to import_batches deferred to Migration 023. Column present; constraint added when import_batches table is created.';

CREATE INDEX ix_bank_statement_lines_bank_account
    ON public.bank_statement_lines (bank_account_id, statement_date);

CREATE INDEX ix_bank_statement_lines_status
    ON public.bank_statement_lines (company_id, reconciliation_status)
    WHERE reconciliation_status != 'cleared';

CREATE INDEX ix_bank_statement_lines_recon
    ON public.bank_statement_lines (bank_reconciliation_id)
    WHERE bank_reconciliation_id IS NOT NULL;

ALTER TABLE public.bank_statement_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP F: Ledger tables — Immutable=NO (updated by reconciliation process)
-- =============================================================================

-- #107 outstanding_checks
-- Running register of checks issued but not yet cleared by the bank.
-- cleared_date set by bank reconciliation process when check clears.
-- Full standard audit columns because this is a mutable ledger (Immutable=NO
-- per Doc02 — reconciliation process updates cleared_date).
CREATE TABLE public.outstanding_checks (
    id                  uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid          NOT NULL REFERENCES public.companies(id),
    bank_account_id     uuid          NOT NULL REFERENCES public.company_bank_accounts(id),
    check_no            text          NOT NULL,
    payee               text          NOT NULL,
    amount              numeric(18,4) NOT NULL,
    check_date          date          NOT NULL,
    issued_date         date          NOT NULL,
    cleared_date        date          NULL,
    payment_voucher_id  uuid          NULL     REFERENCES public.payment_vouchers(id),
    -- standard audit (Immutable=NO — updated when check clears)
    created_at          timestamptz   NOT NULL DEFAULT now(),
    created_by          uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at          timestamptz   NULL,
    updated_by          uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_outstanding_checks PRIMARY KEY (id),
    CONSTRAINT ck_oc_amount CHECK (amount > 0),
    CONSTRAINT ck_oc_issued_date CHECK (issued_date >= check_date)
);

-- One outstanding check per bank account per check number (active)
CREATE UNIQUE INDEX uq_outstanding_checks_active
    ON public.outstanding_checks (bank_account_id, check_no)
    WHERE cleared_date IS NULL;

CREATE INDEX ix_outstanding_checks_bank_account
    ON public.outstanding_checks (bank_account_id, cleared_date);

CREATE INDEX ix_outstanding_checks_company
    ON public.outstanding_checks (company_id)
    WHERE cleared_date IS NULL;

ALTER TABLE public.outstanding_checks ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #108 deposits_in_transit
-- Deposits recorded in the books but not yet reflected on the bank statement.
-- cleared_date set by bank reconciliation process when deposit appears on statement.
CREATE TABLE public.deposits_in_transit (
    id               uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id       uuid          NOT NULL REFERENCES public.companies(id),
    bank_account_id  uuid          NOT NULL REFERENCES public.company_bank_accounts(id),
    deposit_date     date          NOT NULL,
    amount           numeric(18,4) NOT NULL,
    receipt_id       uuid          NULL     REFERENCES public.receipts(id),
    cleared_date     date          NULL,
    -- standard audit (Immutable=NO — updated when deposit clears)
    created_at       timestamptz   NOT NULL DEFAULT now(),
    created_by       uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at       timestamptz   NULL,
    updated_by       uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_deposits_in_transit PRIMARY KEY (id),
    CONSTRAINT ck_dit_amount CHECK (amount > 0)
);

CREATE INDEX ix_deposits_in_transit_bank_account
    ON public.deposits_in_transit (bank_account_id, cleared_date);

CREATE INDEX ix_deposits_in_transit_company
    ON public.deposits_in_transit (company_id)
    WHERE cleared_date IS NULL;

ALTER TABLE public.deposits_in_transit ENABLE ROW LEVEL SECURITY;
