-- =============================================================================
-- Migration 015 — Compliance (Modules 17, 18, 19, 29, 30)
-- =============================================================================
-- Scope: All BIR compliance ledger and return-tracking tables.
--
-- Module 17 — VAT:
--   vat_entries (#140), vat_period_summaries (#141), vat_return_filings (#142),
--   slsp_exports (#143), relief_exports (#144)
--
-- Module 18 — Withholding Tax:
--   ewt_entries (#145), fwt_entries (#146),
--   certificates_2307_issued (#147), certificates_2307_received (#148),
--   certificates_2306_issued (#149),
--   ewt_remittances_1601eq (#150), fwt_remittances_1601fq (#150a),
--   qap_exports (#151), sawt_exports (#152), ewt_period_summaries (#153)
--
-- Module 19 — Income Tax:
--   income_tax_return_filings (#158a), itr_computation_runs (#154),
--   income_tax_computation_lines (#199), book_tax_reconciliations (#155),
--   tax_credits_schedules (#158), nolco_tracking (#200)
--
-- Module 29 — Percentage Tax:
--   percentage_tax_entries (#190), percentage_tax_period_summaries (#191),
--   percentage_tax_return_filings (#192)
--
-- Tables created: 24
--
-- Deferred FKs (referenced tables not yet created):
--   export_jobs.id — Module 23 (Import/Export) — deferred to that migration
--   generated_documents.id — Module 25 (Document Templates) — deferred
--   attachments.id — Module 21 (Attachments) — deferred
--
-- Circular FK resolution:
--   income_tax_return_filings.itr_computation_run_id is created as plain uuid
--   NULL (deferred), then ALTER TABLE ADD CONSTRAINT after itr_computation_runs
--   is created (within this migration).
--
-- Architecture: Database Freeze v4.0. Read-only sources: Doc02, Doc03, Doc05.
-- =============================================================================

-- =============================================================================
-- MODULE 17: COMPLIANCE — VAT
-- =============================================================================

-- ---------------------------------------------------------------------------
-- SECTION 1: vat_entries
-- ---------------------------------------------------------------------------
-- Immutable. One row per taxable line per source document. Written by posting
-- engine (service role) at document post time.
-- ---------------------------------------------------------------------------

CREATE TABLE public.vat_entries (
    id                      uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid            NOT NULL,
    branch_id               uuid            NULL,
    fiscal_period_id        uuid            NOT NULL,
    transaction_date        date            NOT NULL,
    document_type           text            NOT NULL,
    document_id             uuid            NOT NULL,
    document_no             text            NOT NULL,
    line_id                 uuid            NOT NULL,
    party_type              text            NOT NULL,
    party_id                uuid            NOT NULL,
    party_name              text            NOT NULL,
    party_tin               text            NULL,
    vat_direction           text            NOT NULL,
    vat_classification      text            NOT NULL,
    vat_code_id             uuid            NOT NULL,
    net_amount              numeric(18,4)   NOT NULL DEFAULT 0,
    vat_amount              numeric(18,4)   NOT NULL DEFAULT 0,
    total_amount            numeric(18,4)   NOT NULL DEFAULT 0,

    CONSTRAINT pk_vat_entries PRIMARY KEY (id),
    CONSTRAINT fk_ve_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_ve_branch
        FOREIGN KEY (branch_id) REFERENCES public.branches(id),
    CONSTRAINT fk_ve_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_ve_vat_code
        FOREIGN KEY (vat_code_id) REFERENCES public.vat_codes(id),

    CONSTRAINT ck_ve_party_type
        CHECK (party_type IN ('customer','supplier')),
    CONSTRAINT ck_ve_vat_direction
        CHECK (vat_direction IN ('output','input')),
    CONSTRAINT ck_ve_vat_classification
        CHECK (vat_classification IN ('vatable','zero_rated','exempt','government')),
    CONSTRAINT ck_ve_net_amount_nneg
        CHECK (net_amount >= 0),
    CONSTRAINT ck_ve_vat_amount_nneg
        CHECK (vat_amount >= 0)
);

COMMENT ON TABLE public.vat_entries IS
    'Immutable VAT ledger. One row per taxable line per source document. '
    'Written by posting engine (service role) at document post time. '
    'party_tin snapshot is CRITICAL for SLSP/RELIEF export compliance. '
    'government classification handles CWT on VAT for government customers (BIR rules).';

COMMENT ON COLUMN public.vat_entries.party_tin IS
    'TIN snapshot at transaction time. CRITICAL for SLSP/RELIEF — BIR requires '
    'TIN on all SLSP purchase/sales list entries.';

CREATE INDEX idx_vat_entries_period
    ON public.vat_entries (company_id, fiscal_period_id, vat_direction);

CREATE INDEX idx_vat_entries_document
    ON public.vat_entries (company_id, document_type, document_id);

CREATE INDEX idx_vat_entries_party
    ON public.vat_entries (company_id, party_type, party_id);

-- ---------------------------------------------------------------------------
-- SECTION 2: vat_period_summaries
-- ---------------------------------------------------------------------------
-- Aggregated VAT per fiscal period. Immutable once locked (is_final=true).
-- ---------------------------------------------------------------------------

CREATE TABLE public.vat_period_summaries (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                  uuid            NOT NULL,
    fiscal_period_id            uuid            NOT NULL,
    total_output_vat            numeric(18,4)   NOT NULL DEFAULT 0,
    total_input_vat             numeric(18,4)   NOT NULL DEFAULT 0,
    total_vatable_sales         numeric(18,4)   NOT NULL DEFAULT 0,
    total_zero_rated_sales      numeric(18,4)   NOT NULL DEFAULT 0,
    total_exempt_sales          numeric(18,4)   NOT NULL DEFAULT 0,
    total_government_sales      numeric(18,4)   NOT NULL DEFAULT 0,
    total_vatable_purchases     numeric(18,4)   NOT NULL DEFAULT 0,
    total_capital_goods_vat     numeric(18,4)   NOT NULL DEFAULT 0,
    total_services_vat          numeric(18,4)   NOT NULL DEFAULT 0,
    net_vat_payable             numeric(18,4)   NOT NULL DEFAULT 0,
    is_final                    boolean         NOT NULL DEFAULT false,

    -- Standard audit columns
    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NULL,
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NULL,

    CONSTRAINT pk_vat_period_summaries PRIMARY KEY (id),
    CONSTRAINT uq_vat_period_summaries_period
        UNIQUE (company_id, fiscal_period_id),
    CONSTRAINT fk_vps_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_vps_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_vps_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_vps_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id)
);

COMMENT ON TABLE public.vat_period_summaries IS
    'Aggregated VAT totals per fiscal period. is_final=true locks the summary '
    'after 2550M/Q filing. Source for 2550M and 2550Q return computation.';

-- ---------------------------------------------------------------------------
-- SECTION 3: vat_return_filings
-- ---------------------------------------------------------------------------
-- VAT return filing records (2550M monthly and 2550Q quarterly).
-- Immutable (Doc02 Soft Delete=NO).
-- ---------------------------------------------------------------------------

CREATE TABLE public.vat_return_filings (
    id                  uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid            NOT NULL,
    fiscal_period_id    uuid            NOT NULL,
    form_type           text            NOT NULL,
    tax_due             numeric(18,4)   NOT NULL DEFAULT 0,
    tax_credits         numeric(18,4)   NOT NULL DEFAULT 0,
    net_tax_payable     numeric(18,4)   NOT NULL DEFAULT 0,
    surcharge           numeric(18,4)   NOT NULL DEFAULT 0,
    interest            numeric(18,4)   NOT NULL DEFAULT 0,
    compromise          numeric(18,4)   NOT NULL DEFAULT 0,
    total_amount_due    numeric(18,4)   NOT NULL DEFAULT 0,
    filing_status       text            NOT NULL DEFAULT 'draft',
    filed_at            timestamptz     NULL,
    confirmation_no     text            NULL,

    -- Standard audit columns
    created_at          timestamptz     NOT NULL DEFAULT now(),
    created_by          uuid            NULL,
    updated_at          timestamptz     NOT NULL DEFAULT now(),
    updated_by          uuid            NULL,

    CONSTRAINT pk_vat_return_filings PRIMARY KEY (id),
    CONSTRAINT fk_vrf_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_vrf_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_vrf_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_vrf_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_vrf_form_type
        CHECK (form_type IN ('2550M','2550Q')),
    CONSTRAINT ck_vrf_filing_status
        CHECK (filing_status IN ('draft','filed','amended')),
    CONSTRAINT ck_vrf_amounts_nneg
        CHECK (tax_due >= 0 AND total_amount_due >= 0)
);

COMMENT ON TABLE public.vat_return_filings IS
    'VAT return filing records. form_type 2550M = monthly (VAT taxpayers); '
    '2550Q = quarterly. confirmation_no is the eFPS/eBIRForms confirmation number.';

CREATE INDEX idx_vat_return_filings_period
    ON public.vat_return_filings (company_id, fiscal_period_id);

-- ---------------------------------------------------------------------------
-- SECTION 4: slsp_exports
-- ---------------------------------------------------------------------------
-- SLSP (Summary List of Sales/Purchases) export batch records.
-- Immutable output. No soft delete.
-- ---------------------------------------------------------------------------

CREATE TABLE public.slsp_exports (
    id                  uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL,
    fiscal_period_id    uuid        NOT NULL,
    export_type         text        NOT NULL,
    record_count        integer     NOT NULL DEFAULT 0,
    file_path           text        NULL,
    exported_at         timestamptz NOT NULL DEFAULT now(),
    exported_by         uuid        NOT NULL,

    CONSTRAINT pk_slsp_exports PRIMARY KEY (id),
    CONSTRAINT fk_slsp_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_slsp_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_slsp_exported_by
        FOREIGN KEY (exported_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_slsp_export_type
        CHECK (export_type IN ('sales','purchases')),
    CONSTRAINT ck_slsp_record_count_nneg
        CHECK (record_count >= 0)
);

COMMENT ON TABLE public.slsp_exports IS
    'SLSP Summary List of Sales/Purchases export batch records. '
    'file_path points to the generated DAT/CSV file in Supabase Storage. '
    'BIR RELIEF requirement: quarterly SLSP submission for VAT taxpayers.';

COMMENT ON COLUMN public.slsp_exports.file_path IS
    'Supabase Storage path to the generated SLSP DAT file.';

CREATE INDEX idx_slsp_exports_period
    ON public.slsp_exports (company_id, fiscal_period_id);

-- ---------------------------------------------------------------------------
-- SECTION 5: relief_exports
-- ---------------------------------------------------------------------------
-- RELIEF (Reconciliation of Listing for Enforcement) export batch records.
-- Immutable output.
-- ---------------------------------------------------------------------------

CREATE TABLE public.relief_exports (
    id                  uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL,
    fiscal_period_id    uuid        NOT NULL,
    record_count        integer     NOT NULL DEFAULT 0,
    file_path           text        NULL,
    exported_at         timestamptz NOT NULL DEFAULT now(),
    exported_by         uuid        NOT NULL,

    CONSTRAINT pk_relief_exports PRIMARY KEY (id),
    CONSTRAINT fk_re_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_re_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_re_exported_by
        FOREIGN KEY (exported_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_re_record_count_nneg
        CHECK (record_count >= 0)
);

COMMENT ON TABLE public.relief_exports IS
    'RELIEF (Reconciliation of Listing for Enforcement) export records. '
    'Generated from vat_entries for cross-matching by BIR.';

CREATE INDEX idx_relief_exports_period
    ON public.relief_exports (company_id, fiscal_period_id);

-- =============================================================================
-- MODULE 18: COMPLIANCE — WITHHOLDING TAX
-- =============================================================================

-- ---------------------------------------------------------------------------
-- SECTION 6: certificates_2307_issued
-- ---------------------------------------------------------------------------
-- 2307 Certificates of Creditable Withholding Tax at Source, issued to
-- suppliers. Immutable output. One certificate per supplier per quarter.
-- generated_document_id FK deferred to Module 25 (generated_documents).
-- ---------------------------------------------------------------------------

CREATE TABLE public.certificates_2307_issued (
    id                      uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid            NOT NULL,
    supplier_id             uuid            NOT NULL,
    supplier_name           text            NOT NULL,
    supplier_tin            text            NOT NULL,
    quarter                 integer         NOT NULL,
    year                    integer         NOT NULL,
    certificate_no          text            NOT NULL,
    date_issued             date            NOT NULL,
    total_income_payments   numeric(18,4)   NOT NULL DEFAULT 0,
    total_ewt_withheld      numeric(18,4)   NOT NULL DEFAULT 0,
    atc_breakdown           jsonb           NOT NULL DEFAULT '[]',
    is_issued               boolean         NOT NULL DEFAULT false,
    issued_at               timestamptz     NULL,
    issued_to               text            NULL,
    -- FK → generated_documents.id — deferred to Module 25 migration
    generated_document_id   uuid            NULL,
    generated_at            timestamptz     NOT NULL DEFAULT now(),
    generated_by            uuid            NOT NULL,

    CONSTRAINT pk_certificates_2307_issued PRIMARY KEY (id),
    CONSTRAINT uq_cert_2307_supplier_quarter
        UNIQUE (company_id, supplier_id, quarter, year),
    CONSTRAINT fk_c2307i_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_c2307i_supplier
        FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id),
    CONSTRAINT fk_c2307i_generated_by
        FOREIGN KEY (generated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_c2307i_quarter
        CHECK (quarter BETWEEN 1 AND 4),
    CONSTRAINT ck_c2307i_year_valid
        CHECK (year >= 2000),
    CONSTRAINT ck_c2307i_totals_nneg
        CHECK (total_income_payments >= 0 AND total_ewt_withheld >= 0)
);

COMMENT ON TABLE public.certificates_2307_issued IS
    'BIR Form 2307 Certificates issued to suppliers. One per supplier per quarter. '
    'atc_breakdown jsonb: [{atc, m1_base, m1_ewt, m2_base, m2_ewt, m3_base, m3_ewt}] '
    '(Doc03 OD-CS-02: jsonb for Phase 1 — normalize in Phase 2 if query needs arise). '
    'generated_document_id FK deferred to Module 25 migration (generated_documents).';

COMMENT ON COLUMN public.certificates_2307_issued.atc_breakdown IS
    'Per-ATC monthly breakdown: [{atc, m1_base, m1_ewt, m2_base, m2_ewt, m3_base, m3_ewt}]. '
    'jsonb for Phase 1 per Doc03 OD-CS-02. Normalize to separate table in Phase 2.';

COMMENT ON COLUMN public.certificates_2307_issued.generated_document_id IS
    'FK → generated_documents.id — FK constraint deferred to Module 25 migration.';

CREATE INDEX idx_c2307i_supplier
    ON public.certificates_2307_issued (company_id, supplier_id);

CREATE INDEX idx_c2307i_period
    ON public.certificates_2307_issued (company_id, year, quarter);

-- ---------------------------------------------------------------------------
-- SECTION 7: certificates_2307_received
-- ---------------------------------------------------------------------------
-- 2307 Certificates received from customers (withheld on our sales).
-- These are creditable against income tax (1701Q/1702Q).
-- attachment_id FK deferred to Module 21 (attachments).
-- ---------------------------------------------------------------------------

CREATE TABLE public.certificates_2307_received (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                  uuid            NOT NULL,
    customer_id                 uuid            NOT NULL,
    customer_name               text            NOT NULL,
    customer_tin                text            NOT NULL,
    receipt_id                  uuid            NULL,
    quarter                     integer         NOT NULL,
    year                        integer         NOT NULL,
    certificate_no              text            NOT NULL,
    atc_code                    text            NOT NULL,
    income_payment_amount       numeric(18,4)   NOT NULL DEFAULT 0,
    ewt_withheld_amount         numeric(18,4)   NOT NULL DEFAULT 0,
    date_received               date            NOT NULL,
    -- FK → attachments.id — deferred to Module 21 migration
    attachment_id               uuid            NULL,

    -- Standard audit columns
    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NULL,
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NULL,

    CONSTRAINT pk_certificates_2307_received PRIMARY KEY (id),
    CONSTRAINT fk_c2307r_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_c2307r_customer
        FOREIGN KEY (customer_id) REFERENCES public.customers(id),
    CONSTRAINT fk_c2307r_receipt
        FOREIGN KEY (receipt_id) REFERENCES public.receipts(id),
    CONSTRAINT fk_c2307r_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_c2307r_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_c2307r_quarter
        CHECK (quarter BETWEEN 1 AND 4),
    CONSTRAINT ck_c2307r_year_valid
        CHECK (year >= 2000),
    CONSTRAINT ck_c2307r_amounts_nneg
        CHECK (income_payment_amount >= 0 AND ewt_withheld_amount >= 0)
);

COMMENT ON TABLE public.certificates_2307_received IS
    'BIR Form 2307 Certificates received from customers. '
    'ewt_withheld_amount is creditable against income tax due (1701Q/1702Q). '
    'attachment_id FK deferred to Module 21 migration (attachments).';

COMMENT ON COLUMN public.certificates_2307_received.attachment_id IS
    'FK → attachments.id — FK constraint deferred to Module 21 migration.';

CREATE INDEX idx_c2307r_customer
    ON public.certificates_2307_received (company_id, customer_id);

CREATE INDEX idx_c2307r_period
    ON public.certificates_2307_received (company_id, year, quarter);

-- ---------------------------------------------------------------------------
-- SECTION 8: ewt_entries
-- ---------------------------------------------------------------------------
-- Immutable EWT ledger. One row per ATC per line per source document.
-- Written by posting engine (service role). Normalized payee columns per
-- Doc03 BLOCKER 4 resolution (supports EWT on both supplier and customer
-- payments — e.g., professional fees paid to individuals on AR side).
-- certificate_2307_id set on certificate generation (within this migration).
-- ---------------------------------------------------------------------------

CREATE TABLE public.ewt_entries (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                  uuid            NOT NULL,
    branch_id                   uuid            NULL,
    fiscal_period_id            uuid            NOT NULL,
    quarter                     integer         NOT NULL,
    year                        integer         NOT NULL,
    transaction_date            date            NOT NULL,
    document_type               text            NOT NULL,
    document_id                 uuid            NOT NULL,
    document_no                 text            NOT NULL,
    line_id                     uuid            NULL,
    payee_id                    uuid            NULL,
    payee_type                  text            NOT NULL,
    payee_tin                   text            NOT NULL,
    payee_registered_name       text            NOT NULL,
    payee_registered_address    text            NULL,
    atc_id                      uuid            NOT NULL,
    atc_code                    text            NOT NULL,
    ewt_base_amount             numeric(18,4)   NOT NULL DEFAULT 0,
    ewt_rate                    numeric(10,6)   NOT NULL DEFAULT 0,
    ewt_amount                  numeric(18,4)   NOT NULL DEFAULT 0,
    certificate_2307_id         uuid            NULL,

    CONSTRAINT pk_ewt_entries PRIMARY KEY (id),
    CONSTRAINT fk_ewt_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_ewt_branch
        FOREIGN KEY (branch_id) REFERENCES public.branches(id),
    CONSTRAINT fk_ewt_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_ewt_atc
        FOREIGN KEY (atc_id) REFERENCES public.atc_codes(id),
    CONSTRAINT fk_ewt_certificate_2307
        FOREIGN KEY (certificate_2307_id) REFERENCES public.certificates_2307_issued(id),

    CONSTRAINT ck_ewt_payee_type
        CHECK (payee_type IN ('supplier','customer')),
    CONSTRAINT ck_ewt_document_type
        CHECK (document_type IN ('vendor_bill','cash_purchase','payment_voucher',
                                  'petty_cash_voucher')),
    CONSTRAINT ck_ewt_quarter
        CHECK (quarter BETWEEN 1 AND 4),
    CONSTRAINT ck_ewt_year_valid
        CHECK (year >= 2000),
    CONSTRAINT ck_ewt_amounts_nneg
        CHECK (ewt_base_amount >= 0 AND ewt_rate >= 0 AND ewt_amount >= 0)
);

COMMENT ON TABLE public.ewt_entries IS
    'Immutable EWT ledger. One row per ATC per line per source document. '
    'Written by posting engine (service role). '
    'Payee columns normalized per Doc03 BLOCKER 4: supports EWT on both '
    'supplier and customer payments. payee_tin snapshot CRITICAL for 2307/QAP. '
    'certificate_2307_id set when 2307 is generated (ref: certificates_2307_issued).';

COMMENT ON COLUMN public.ewt_entries.payee_tin IS
    'TIN snapshot at transaction time. CRITICAL for 2307 certificates and QAP export.';

CREATE INDEX idx_ewt_entries_payee_tin
    ON public.ewt_entries (company_id, payee_tin);

CREATE INDEX idx_ewt_entries_fiscal_period
    ON public.ewt_entries (company_id, fiscal_period_id);

CREATE INDEX idx_ewt_entries_document
    ON public.ewt_entries (company_id, document_type, document_id);

-- ---------------------------------------------------------------------------
-- SECTION 9: ewt_period_summaries
-- ---------------------------------------------------------------------------
-- Aggregated EWT per ATC per fiscal period. Source for 1601EQ return.
-- ---------------------------------------------------------------------------

CREATE TABLE public.ewt_period_summaries (
    id                      uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid            NOT NULL,
    fiscal_period_id        uuid            NOT NULL,
    atc_code_id             uuid            NOT NULL,
    income_payment_total    numeric(18,4)   NOT NULL DEFAULT 0,
    ewt_total               numeric(18,4)   NOT NULL DEFAULT 0,
    is_final                boolean         NOT NULL DEFAULT false,

    CONSTRAINT pk_ewt_period_summaries PRIMARY KEY (id),
    CONSTRAINT uq_ewt_period_summaries
        UNIQUE (company_id, fiscal_period_id, atc_code_id),
    CONSTRAINT fk_eps_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_eps_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_eps_atc_code
        FOREIGN KEY (atc_code_id) REFERENCES public.atc_codes(id),

    CONSTRAINT ck_eps_amounts_nneg
        CHECK (income_payment_total >= 0 AND ewt_total >= 0)
);

COMMENT ON TABLE public.ewt_period_summaries IS
    'Aggregated EWT per ATC per fiscal period. is_final=true locks after 1601EQ filing. '
    'Source for 1601EQ quarterly remittance return computation.';

CREATE INDEX idx_ewt_period_summaries_period
    ON public.ewt_period_summaries (company_id, fiscal_period_id);

-- ---------------------------------------------------------------------------
-- SECTION 10: ewt_remittances_1601eq
-- ---------------------------------------------------------------------------
-- 1601EQ quarterly remittance return filing. Immutable.
-- ---------------------------------------------------------------------------

CREATE TABLE public.ewt_remittances_1601eq (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                  uuid            NOT NULL,
    fiscal_period_id            uuid            NOT NULL,
    quarter                     integer         NOT NULL,
    tax_due                     numeric(18,4)   NOT NULL DEFAULT 0,
    less_prior_quarter_payments numeric(18,4)   NOT NULL DEFAULT 0,
    tax_still_due               numeric(18,4)   NOT NULL DEFAULT 0,
    surcharge                   numeric(18,4)   NOT NULL DEFAULT 0,
    interest                    numeric(18,4)   NOT NULL DEFAULT 0,
    compromise                  numeric(18,4)   NOT NULL DEFAULT 0,
    total_amount_due            numeric(18,4)   NOT NULL DEFAULT 0,
    filing_status               text            NOT NULL DEFAULT 'draft',
    filed_at                    timestamptz     NULL,
    confirmation_no             text            NULL,

    -- Standard audit columns
    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NULL,
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NULL,

    CONSTRAINT pk_ewt_remittances_1601eq PRIMARY KEY (id),
    CONSTRAINT fk_1601eq_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_1601eq_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_1601eq_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_1601eq_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_1601eq_quarter
        CHECK (quarter BETWEEN 1 AND 4),
    CONSTRAINT ck_1601eq_filing_status
        CHECK (filing_status IN ('draft','filed','amended')),
    CONSTRAINT ck_1601eq_amounts_nneg
        CHECK (tax_due >= 0 AND total_amount_due >= 0)
);

COMMENT ON TABLE public.ewt_remittances_1601eq IS
    'BIR Form 1601EQ Quarterly Remittance Return of Creditable Income Tax Withheld. '
    'tax_still_due = tax_due − less_prior_quarter_payments. '
    'confirmation_no is eFPS/eBIRForms confirmation number.';

CREATE INDEX idx_1601eq_period
    ON public.ewt_remittances_1601eq (company_id, fiscal_period_id);

-- ---------------------------------------------------------------------------
-- SECTION 11: fwt_entries
-- ---------------------------------------------------------------------------
-- Immutable FWT ledger. WF-series ATC codes only (final withholding tax).
-- Written by posting engine. is_remitted updated when 1601FQ is filed.
-- ---------------------------------------------------------------------------

CREATE TABLE public.fwt_entries (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                  uuid            NOT NULL,
    source_entity_type          text            NOT NULL,
    source_entity_id            uuid            NOT NULL,
    source_line_id              uuid            NULL,
    payee_id                    uuid            NULL,
    payee_type                  text            NOT NULL,
    payee_tin                   text            NOT NULL,
    payee_registered_name       text            NOT NULL,
    payee_registered_address    text            NULL,
    atc_code_id                 uuid            NOT NULL,
    fwt_code_id                 uuid            NOT NULL,
    income_payment_amount       numeric(18,4)   NOT NULL,
    fwt_rate                    numeric(10,6)   NOT NULL,
    fwt_amount                  numeric(18,4)   NOT NULL,
    fiscal_period_id            uuid            NOT NULL,
    transaction_date            date            NOT NULL,
    is_remitted                 boolean         NOT NULL DEFAULT false,

    CONSTRAINT pk_fwt_entries PRIMARY KEY (id),
    CONSTRAINT fk_fwt_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_fwt_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_fwt_atc_code
        FOREIGN KEY (atc_code_id) REFERENCES public.atc_codes(id),
    CONSTRAINT fk_fwt_fwt_code
        FOREIGN KEY (fwt_code_id) REFERENCES public.fwt_codes(id),

    CONSTRAINT ck_fwt_payee_type
        CHECK (payee_type IN ('supplier','customer')),
    CONSTRAINT ck_fwt_source_type
        CHECK (source_entity_type IN ('vendor_bill','payment_voucher','cash_purchase')),
    CONSTRAINT ck_fwt_amounts_pos
        CHECK (income_payment_amount >= 0 AND fwt_rate >= 0 AND fwt_amount >= 0)
);

COMMENT ON TABLE public.fwt_entries IS
    'Immutable Final Withholding Tax (FWT) ledger. WF-series ATC codes only. '
    'Written by posting engine (service role). '
    'is_remitted updated to true when 1601FQ is filed. '
    'FWT is FINAL — income is taxed at source; payee cannot credit against ITR '
    '(Doc03 BLOCKER 6 note: fwt_2306 REMOVED from tax_credits_schedules.credit_type).';

COMMENT ON COLUMN public.fwt_entries.payee_tin IS
    'TIN snapshot at transaction time. CRITICAL for 2306 certificates and 1601FQ.';

CREATE INDEX idx_fwt_entries_company_period
    ON public.fwt_entries (company_id, fiscal_period_id);

CREATE INDEX idx_fwt_entries_payee_tin
    ON public.fwt_entries (company_id, payee_tin);

-- ---------------------------------------------------------------------------
-- SECTION 12: certificates_2306_issued
-- ---------------------------------------------------------------------------
-- BIR Form 2306 Final Withholding Tax Certificates issued to payees.
-- Immutable output. generated_document_id deferred to Module 25.
-- ---------------------------------------------------------------------------

CREATE TABLE public.certificates_2306_issued (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                  uuid            NOT NULL,
    payee_id                    uuid            NULL,
    payee_tin                   text            NOT NULL,
    payee_registered_name       text            NOT NULL,
    payee_registered_address    text            NULL,
    atc_code_id                 uuid            NOT NULL,
    calendar_year               integer         NOT NULL,
    quarter                     integer         NOT NULL,
    total_income_payment        numeric(18,4)   NOT NULL,
    total_fwt_withheld          numeric(18,4)   NOT NULL,
    certificate_no              text            NULL,
    generated_at                timestamptz     NOT NULL DEFAULT now(),
    generated_by                uuid            NOT NULL,
    -- FK → generated_documents.id — deferred to Module 25 migration
    generated_document_id       uuid            NULL,

    CONSTRAINT pk_certificates_2306_issued PRIMARY KEY (id),
    CONSTRAINT fk_c2306_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_c2306_atc_code
        FOREIGN KEY (atc_code_id) REFERENCES public.atc_codes(id),
    CONSTRAINT fk_c2306_generated_by
        FOREIGN KEY (generated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_c2306_quarter
        CHECK (quarter BETWEEN 1 AND 4),
    CONSTRAINT ck_c2306_year_valid
        CHECK (calendar_year >= 2000),
    CONSTRAINT ck_c2306_amounts_nneg
        CHECK (total_income_payment >= 0 AND total_fwt_withheld >= 0)
);

COMMENT ON TABLE public.certificates_2306_issued IS
    'BIR Form 2306 Final Withholding Tax Certificates. Issued by company to payees. '
    'generated_document_id FK deferred to Module 25 migration (generated_documents). '
    'FWT is FINAL: payees cannot credit 2306 against ITR.';

COMMENT ON COLUMN public.certificates_2306_issued.generated_document_id IS
    'FK → generated_documents.id — FK constraint deferred to Module 25 migration.';

CREATE INDEX idx_c2306_payee
    ON public.certificates_2306_issued (company_id, payee_tin);

CREATE INDEX idx_c2306_period
    ON public.certificates_2306_issued (company_id, calendar_year, quarter);

-- ---------------------------------------------------------------------------
-- SECTION 13: fwt_remittances_1601fq
-- ---------------------------------------------------------------------------
-- 1601FQ quarterly final withholding tax remittance filing. Immutable.
-- export_job_id deferred to Module 23 (export_jobs).
-- ---------------------------------------------------------------------------

CREATE TABLE public.fwt_remittances_1601fq (
    id                      uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid            NOT NULL,
    fiscal_year_id          uuid            NOT NULL,
    quarter                 integer         NOT NULL,
    quarter_date_from       date            NOT NULL,
    quarter_date_to         date            NOT NULL,
    fwt_amount_total        numeric(18,4)   NOT NULL DEFAULT 0,
    fwt_amount_remitted     numeric(18,4)   NOT NULL DEFAULT 0,
    filing_status           text            NOT NULL DEFAULT 'draft',
    filing_date             date            NULL,
    bir_confirmation_no     text            NULL,
    -- FK → export_jobs.id — deferred to Module 23 migration
    export_job_id           uuid            NULL,

    -- Standard audit columns
    created_at              timestamptz     NOT NULL DEFAULT now(),
    created_by              uuid            NULL,
    updated_at              timestamptz     NOT NULL DEFAULT now(),
    updated_by              uuid            NULL,

    CONSTRAINT pk_fwt_remittances_1601fq PRIMARY KEY (id),
    CONSTRAINT uq_1601fq_company_year_quarter
        UNIQUE (company_id, fiscal_year_id, quarter),
    CONSTRAINT fk_1601fq_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_1601fq_fiscal_year
        FOREIGN KEY (fiscal_year_id) REFERENCES public.fiscal_years(id),
    CONSTRAINT fk_1601fq_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_1601fq_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_1601fq_quarter
        CHECK (quarter BETWEEN 1 AND 4),
    CONSTRAINT ck_1601fq_date_range
        CHECK (quarter_date_to >= quarter_date_from),
    CONSTRAINT ck_1601fq_filing_status
        CHECK (filing_status IN ('draft','filed','amended')),
    CONSTRAINT ck_1601fq_amounts_nneg
        CHECK (fwt_amount_total >= 0 AND fwt_amount_remitted >= 0)
);

COMMENT ON TABLE public.fwt_remittances_1601fq IS
    'BIR Form 1601FQ Quarterly Remittance Return of Final Income Taxes Withheld. '
    'export_job_id FK deferred to Module 23 migration (export_jobs).';

COMMENT ON COLUMN public.fwt_remittances_1601fq.export_job_id IS
    'FK → export_jobs.id — FK constraint deferred to Module 23 migration.';

-- ---------------------------------------------------------------------------
-- SECTION 14: qap_exports
-- ---------------------------------------------------------------------------
-- QAP (Quarterly Alphalist of Payees) export batch records — source for
-- 1604E annual alphalist. Immutable output.
-- ---------------------------------------------------------------------------

CREATE TABLE public.qap_exports (
    id                  uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL,
    fiscal_period_id    uuid        NOT NULL,
    quarter             integer     NOT NULL,
    record_count        integer     NOT NULL DEFAULT 0,
    file_path           text        NULL,
    exported_at         timestamptz NOT NULL DEFAULT now(),
    exported_by         uuid        NOT NULL,

    CONSTRAINT pk_qap_exports PRIMARY KEY (id),
    CONSTRAINT fk_qap_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_qap_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_qap_exported_by
        FOREIGN KEY (exported_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_qap_quarter
        CHECK (quarter BETWEEN 1 AND 4),
    CONSTRAINT ck_qap_record_count_nneg
        CHECK (record_count >= 0)
);

COMMENT ON TABLE public.qap_exports IS
    'QAP (Quarterly Alphalist of Payees) export records. '
    'Source data for 1604E Annual Alphalist. Sourced from ewt_entries. '
    'File format per BIR SAWT/QAP DAT file specification.';

CREATE INDEX idx_qap_exports_period
    ON public.qap_exports (company_id, fiscal_period_id);

-- ---------------------------------------------------------------------------
-- SECTION 15: sawt_exports
-- ---------------------------------------------------------------------------
-- SAWT (Summary Alphalist of Withholding Tax at Source) export records.
-- Required with each 1701Q/1702Q quarterly filing.
-- ---------------------------------------------------------------------------

CREATE TABLE public.sawt_exports (
    id                  uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL,
    fiscal_period_id    uuid        NOT NULL,
    quarter             integer     NOT NULL,
    record_count        integer     NOT NULL DEFAULT 0,
    file_path           text        NULL,
    exported_at         timestamptz NOT NULL DEFAULT now(),
    exported_by         uuid        NOT NULL,

    CONSTRAINT pk_sawt_exports PRIMARY KEY (id),
    CONSTRAINT fk_sawt_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_sawt_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_sawt_exported_by
        FOREIGN KEY (exported_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_sawt_quarter
        CHECK (quarter BETWEEN 1 AND 4),
    CONSTRAINT ck_sawt_record_count_nneg
        CHECK (record_count >= 0)
);

COMMENT ON TABLE public.sawt_exports IS
    'SAWT (Summary Alphalist of Withholding Tax at Source) export records. '
    'Must accompany each quarterly ITR filing (1701Q/1702Q) per BIR rules. '
    'Sourced from certificates_2307_received. '
    'File format per BIR SAWT DAT file specification.';

CREATE INDEX idx_sawt_exports_period
    ON public.sawt_exports (company_id, fiscal_period_id);

-- =============================================================================
-- MODULE 29: COMPLIANCE — PERCENTAGE TAX
-- =============================================================================

-- ---------------------------------------------------------------------------
-- SECTION 16: percentage_tax_entries
-- ---------------------------------------------------------------------------
-- Percentage tax entries aggregated from NON-VAT company sales transactions.
-- Applicable only when company_compliance_profiles.taxpayer_type = 'non_vat'.
-- Immutable. Written by posting engine.
-- ---------------------------------------------------------------------------

CREATE TABLE public.percentage_tax_entries (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                  uuid            NOT NULL,
    fiscal_year_id              uuid            NOT NULL,
    fiscal_period_id            uuid            NOT NULL,
    source_document_id          uuid            NOT NULL,
    source_document_type        text            NOT NULL,
    percentage_tax_code_id      uuid            NULL,
    gross_receipts_amount       numeric(18,4)   NOT NULL,
    pt_rate                     numeric(10,6)   NOT NULL,
    pt_amount                   numeric(18,4)   NOT NULL,
    transaction_date            date            NOT NULL,

    -- Standard audit columns
    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NULL,
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NULL,

    CONSTRAINT pk_percentage_tax_entries PRIMARY KEY (id),
    CONSTRAINT fk_pte_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_pte_fiscal_year
        FOREIGN KEY (fiscal_year_id) REFERENCES public.fiscal_years(id),
    CONSTRAINT fk_pte_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_pte_pt_code
        FOREIGN KEY (percentage_tax_code_id) REFERENCES public.percentage_tax_codes(id),
    CONSTRAINT fk_pte_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_pte_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_pte_source_type
        CHECK (source_document_type IN ('cash_sales','sales_invoices')),
    CONSTRAINT ck_pte_amounts_nneg
        CHECK (gross_receipts_amount >= 0 AND pt_rate >= 0 AND pt_amount >= 0)
);

COMMENT ON TABLE public.percentage_tax_entries IS
    'Percentage Tax (PT) ledger for non-VAT taxpayers. '
    'Applicable only when company_compliance_profiles.taxpayer_type = non_vat. '
    'Posting engine creates PT entries instead of VAT entries for non-VAT companies. '
    'Source for 2551Q quarterly percentage tax return.';

CREATE INDEX idx_pte_period
    ON public.percentage_tax_entries (company_id, fiscal_period_id);

-- ---------------------------------------------------------------------------
-- SECTION 17: percentage_tax_period_summaries
-- ---------------------------------------------------------------------------

CREATE TABLE public.percentage_tax_period_summaries (
    id                      uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid            NOT NULL,
    fiscal_year_id          uuid            NOT NULL,
    fiscal_period_id        uuid            NOT NULL,
    quarter                 integer         NOT NULL,
    gross_receipts_total    numeric(18,4)   NOT NULL DEFAULT 0,
    pt_amount_total         numeric(18,4)   NOT NULL DEFAULT 0,
    status                  text            NOT NULL DEFAULT 'open',

    -- Standard audit columns
    created_at              timestamptz     NOT NULL DEFAULT now(),
    created_by              uuid            NULL,
    updated_at              timestamptz     NOT NULL DEFAULT now(),
    updated_by              uuid            NULL,

    CONSTRAINT pk_percentage_tax_period_summaries PRIMARY KEY (id),
    CONSTRAINT uq_ptps_period
        UNIQUE (company_id, fiscal_period_id),
    CONSTRAINT fk_ptps_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_ptps_fiscal_year
        FOREIGN KEY (fiscal_year_id) REFERENCES public.fiscal_years(id),
    CONSTRAINT fk_ptps_fiscal_period
        FOREIGN KEY (fiscal_period_id) REFERENCES public.fiscal_periods(id),
    CONSTRAINT fk_ptps_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_ptps_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_ptps_quarter
        CHECK (quarter BETWEEN 1 AND 4),
    CONSTRAINT ck_ptps_status
        CHECK (status IN ('open','filed')),
    CONSTRAINT ck_ptps_amounts_nneg
        CHECK (gross_receipts_total >= 0 AND pt_amount_total >= 0)
);

COMMENT ON TABLE public.percentage_tax_period_summaries IS
    'Aggregated percentage tax totals per fiscal period. '
    'status = filed after 2551Q is submitted.';

-- ---------------------------------------------------------------------------
-- SECTION 18: percentage_tax_return_filings
-- ---------------------------------------------------------------------------
-- 2551Q quarterly percentage tax filing tracking. Immutable.
-- export_job_id deferred to Module 23 (export_jobs).
-- ---------------------------------------------------------------------------

CREATE TABLE public.percentage_tax_return_filings (
    id                      uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid            NOT NULL,
    fiscal_year_id          uuid            NOT NULL,
    quarter                 integer         NOT NULL,
    quarter_date_from       date            NOT NULL,
    quarter_date_to         date            NOT NULL,
    gross_receipts_amount   numeric(18,4)   NOT NULL DEFAULT 0,
    pt_amount_due           numeric(18,4)   NOT NULL DEFAULT 0,
    pt_amount_paid          numeric(18,4)   NOT NULL DEFAULT 0,
    filing_status           text            NOT NULL DEFAULT 'draft',
    filing_date             date            NULL,
    bir_confirmation_no     text            NULL,
    period_summary_id       uuid            NULL,
    -- FK → export_jobs.id — deferred to Module 23 migration
    export_job_id           uuid            NULL,

    -- Standard audit columns
    created_at              timestamptz     NOT NULL DEFAULT now(),
    created_by              uuid            NULL,
    updated_at              timestamptz     NOT NULL DEFAULT now(),
    updated_by              uuid            NULL,

    CONSTRAINT pk_percentage_tax_return_filings PRIMARY KEY (id),
    CONSTRAINT uq_ptrf_year_quarter
        UNIQUE (company_id, fiscal_year_id, quarter),
    CONSTRAINT fk_ptrf_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_ptrf_fiscal_year
        FOREIGN KEY (fiscal_year_id) REFERENCES public.fiscal_years(id),
    CONSTRAINT fk_ptrf_period_summary
        FOREIGN KEY (period_summary_id) REFERENCES public.percentage_tax_period_summaries(id),
    CONSTRAINT fk_ptrf_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_ptrf_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_ptrf_quarter
        CHECK (quarter BETWEEN 1 AND 4),
    CONSTRAINT ck_ptrf_date_range
        CHECK (quarter_date_to >= quarter_date_from),
    CONSTRAINT ck_ptrf_filing_status
        CHECK (filing_status IN ('draft','filed','amended')),
    CONSTRAINT ck_ptrf_amounts_nneg
        CHECK (gross_receipts_amount >= 0 AND pt_amount_due >= 0 AND pt_amount_paid >= 0)
);

COMMENT ON TABLE public.percentage_tax_return_filings IS
    'BIR Form 2551Q Quarterly Percentage Tax Return. '
    'export_job_id FK deferred to Module 23 migration (export_jobs).';

COMMENT ON COLUMN public.percentage_tax_return_filings.export_job_id IS
    'FK → export_jobs.id — FK constraint deferred to Module 23 migration.';

-- =============================================================================
-- MODULE 19: COMPLIANCE — INCOME TAX
-- =============================================================================

-- ---------------------------------------------------------------------------
-- SECTION 19: income_tax_return_filings
-- ---------------------------------------------------------------------------
-- ITR filing tracking per company per fiscal year per period.
-- itr_computation_run_id declared as plain uuid NULL (circular FK — resolved
-- via ALTER TABLE ADD CONSTRAINT at end of this migration after
-- itr_computation_runs is created).
-- export_job_id deferred to Module 23.
-- ---------------------------------------------------------------------------

CREATE TABLE public.income_tax_return_filings (
    id                      uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid            NOT NULL,
    fiscal_year_id          uuid            NOT NULL,
    filing_type             text            NOT NULL,
    quarter                 integer         NULL,
    form_code               text            NOT NULL,
    taxable_income_amount   numeric(18,4)   NOT NULL DEFAULT 0,
    income_tax_due          numeric(18,4)   NOT NULL DEFAULT 0,
    mcit_amount             numeric(18,4)   NOT NULL DEFAULT 0,
    income_tax_payable      numeric(18,4)   NOT NULL DEFAULT 0,
    filing_status           text            NOT NULL DEFAULT 'draft',
    filing_date             date            NULL,
    bir_confirmation_no     text            NULL,
    -- Circular FK resolved via ALTER TABLE after itr_computation_runs is created
    itr_computation_run_id  uuid            NULL,
    -- FK → export_jobs.id — deferred to Module 23 migration
    export_job_id           uuid            NULL,

    -- Standard audit columns
    created_at              timestamptz     NOT NULL DEFAULT now(),
    created_by              uuid            NULL,
    updated_at              timestamptz     NOT NULL DEFAULT now(),
    updated_by              uuid            NULL,

    CONSTRAINT pk_income_tax_return_filings PRIMARY KEY (id),
    CONSTRAINT uq_itrf_filing
        UNIQUE (company_id, fiscal_year_id, filing_type, quarter),
    CONSTRAINT fk_itrf_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_itrf_fiscal_year
        FOREIGN KEY (fiscal_year_id) REFERENCES public.fiscal_years(id),
    CONSTRAINT fk_itrf_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_itrf_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_itrf_filing_type
        CHECK (filing_type IN ('quarterly','annual')),
    CONSTRAINT ck_itrf_quarter
        CHECK (quarter IS NULL OR quarter BETWEEN 1 AND 4),
    CONSTRAINT ck_itrf_quarter_consistency
        CHECK (filing_type <> 'quarterly' OR quarter IS NOT NULL),
    CONSTRAINT ck_itrf_annual_no_quarter
        CHECK (filing_type <> 'annual' OR quarter IS NULL),
    CONSTRAINT ck_itrf_form_code
        CHECK (form_code IN ('1701Q','1701','1702Q','1702RT')),
    CONSTRAINT ck_itrf_filing_status
        CHECK (filing_status IN ('draft','filed','amended')),
    CONSTRAINT ck_itrf_amounts_nneg
        CHECK (taxable_income_amount >= 0 AND income_tax_due >= 0 AND
               mcit_amount >= 0 AND income_tax_payable >= 0)
);

COMMENT ON TABLE public.income_tax_return_filings IS
    'Income tax return filing tracking per company per fiscal year per period. '
    'form_code derived from income_tax_regime: individual→1701Q/1701, '
    'corporate→1702Q/1702RT. mcit_amount=0 for individual/partnership. '
    'itr_computation_run_id FK wired via ALTER TABLE after itr_computation_runs '
    'is created (circular dependency resolution within this migration). '
    'export_job_id FK deferred to Module 23 migration.';

COMMENT ON COLUMN public.income_tax_return_filings.itr_computation_run_id IS
    'FK → itr_computation_runs.id — circular FK wired via ALTER TABLE '
    'in Section 25 of this migration.';

COMMENT ON COLUMN public.income_tax_return_filings.export_job_id IS
    'FK → export_jobs.id — FK constraint deferred to Module 23 migration.';

CREATE INDEX idx_itrf_company_year
    ON public.income_tax_return_filings (company_id, fiscal_year_id);

-- ---------------------------------------------------------------------------
-- SECTION 20: itr_computation_runs
-- ---------------------------------------------------------------------------
-- Header for each ITR computation run. Multiple runs may exist per filing
-- (e.g., amended computations). itr_filing_id → income_tax_return_filings.id.
-- ---------------------------------------------------------------------------

CREATE TABLE public.itr_computation_runs (
    id                          uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id                  uuid            NOT NULL,
    itr_filing_id               uuid            NOT NULL,
    run_sequence                integer         NOT NULL DEFAULT 1,
    regime_snapshot             text            NOT NULL,
    deduction_method_snapshot   text            NOT NULL,
    gross_income_amount         numeric(18,4)   NOT NULL DEFAULT 0,
    gross_revenue_osd           numeric(18,4)   NOT NULL DEFAULT 0,
    osd_rate                    numeric(10,6)   NULL,
    osd_amount                  numeric(18,4)   NOT NULL DEFAULT 0,
    taxable_income_amount       numeric(18,4)   NOT NULL DEFAULT 0,
    regular_tax_amount          numeric(18,4)   NOT NULL DEFAULT 0,
    mcit_amount                 numeric(18,4)   NOT NULL DEFAULT 0,
    tax_due_amount              numeric(18,4)   NOT NULL DEFAULT 0,
    nolco_applied               numeric(18,4)   NOT NULL DEFAULT 0,
    notes                       text            NULL,
    run_at                      timestamptz     NOT NULL DEFAULT now(),
    run_by                      uuid            NOT NULL,

    -- Standard audit columns
    created_at                  timestamptz     NOT NULL DEFAULT now(),
    created_by                  uuid            NULL,
    updated_at                  timestamptz     NOT NULL DEFAULT now(),
    updated_by                  uuid            NULL,

    CONSTRAINT pk_itr_computation_runs PRIMARY KEY (id),
    CONSTRAINT uq_itr_run_sequence
        UNIQUE (itr_filing_id, run_sequence),
    CONSTRAINT fk_icr_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_icr_itr_filing
        FOREIGN KEY (itr_filing_id) REFERENCES public.income_tax_return_filings(id),
    CONSTRAINT fk_icr_run_by
        FOREIGN KEY (run_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_icr_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_icr_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_icr_deduction_method
        CHECK (deduction_method_snapshot IN ('itemized','osd','eight_percent')),
    CONSTRAINT ck_icr_run_sequence_pos
        CHECK (run_sequence >= 1),
    CONSTRAINT ck_icr_amounts_nneg
        CHECK (gross_income_amount >= 0 AND taxable_income_amount >= 0 AND
               regular_tax_amount >= 0 AND mcit_amount >= 0 AND tax_due_amount >= 0 AND
               nolco_applied >= 0)
);

COMMENT ON TABLE public.itr_computation_runs IS
    'ITR computation run header. run_sequence: 1=initial, 2+=recomputed/amended. '
    'regime_snapshot and deduction_method_snapshot capture state at run time for auditability. '
    'tax_due_amount = MAX(regular_tax_amount, mcit_amount) — enforced by application. '
    'mcit_amount: 2% × gross income (1% under CREATE Act). '
    'OSD rate snapshot preserved per applicable BIR rules at computation time.';

CREATE INDEX idx_icr_filing
    ON public.itr_computation_runs (itr_filing_id);

-- ---------------------------------------------------------------------------
-- SECTION 21: income_tax_computation_lines
-- ---------------------------------------------------------------------------
-- Per-account breakdown used when computing ITR. Populated on-demand per run
-- from gl_balances + COA.fs_section classification. Immutable.
-- ---------------------------------------------------------------------------

CREATE TABLE public.income_tax_computation_lines (
    id                      uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid            NOT NULL,
    computation_run_id      uuid            NOT NULL,
    account_id              uuid            NOT NULL,
    account_code            text            NOT NULL,
    account_name            text            NOT NULL,
    fs_section              text            NOT NULL,
    tax_deductibility       text            NOT NULL,
    is_mcit_gross_income    boolean         NOT NULL DEFAULT false,
    is_osd_gross_revenue    boolean         NOT NULL DEFAULT false,
    period_ytd_debit        numeric(18,4)   NOT NULL DEFAULT 0,
    period_ytd_credit       numeric(18,4)   NOT NULL DEFAULT 0,
    book_amount             numeric(18,4)   NOT NULL DEFAULT 0,
    tax_adjustment          numeric(18,4)   NOT NULL DEFAULT 0,
    taxable_amount          numeric(18,4)   NOT NULL DEFAULT 0,
    computed_at             timestamptz     NOT NULL DEFAULT now(),
    computed_by             uuid            NOT NULL,

    CONSTRAINT pk_income_tax_computation_lines PRIMARY KEY (id),
    CONSTRAINT uq_itcl_run_account
        UNIQUE (computation_run_id, account_id),
    CONSTRAINT fk_itcl_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_itcl_computation_run
        FOREIGN KEY (computation_run_id) REFERENCES public.itr_computation_runs(id),
    CONSTRAINT fk_itcl_account
        FOREIGN KEY (account_id) REFERENCES public.chart_of_accounts(id),
    CONSTRAINT fk_itcl_computed_by
        FOREIGN KEY (computed_by) REFERENCES public.profiles(id)
);

COMMENT ON TABLE public.income_tax_computation_lines IS
    'Per-account ITR computation breakdown. Populated from gl_balances + COA '
    'at computation time. Snapshots (account_code, account_name, fs_section, '
    'tax_deductibility, is_mcit_gross_income, is_osd_gross_revenue) preserve '
    'the COA state at computation time for audit trail.';

CREATE INDEX idx_itcl_run
    ON public.income_tax_computation_lines (computation_run_id);

-- ---------------------------------------------------------------------------
-- SECTION 22: book_tax_reconciliations
-- ---------------------------------------------------------------------------
-- Book-to-tax reconciliation schedule per computation run. Immutable.
-- ---------------------------------------------------------------------------

CREATE TABLE public.book_tax_reconciliations (
    id                      uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid            NOT NULL,
    computation_run_id      uuid            NOT NULL,
    reconciliation_type     text            NOT NULL,
    description             text            NOT NULL,
    account_id              uuid            NULL,
    book_amount             numeric(18,4)   NOT NULL DEFAULT 0,
    tax_amount              numeric(18,4)   NOT NULL DEFAULT 0,
    difference_amount       numeric(18,4)   NOT NULL DEFAULT 0,
    sequence_no             integer         NOT NULL DEFAULT 1,

    -- Standard audit columns
    created_at              timestamptz     NOT NULL DEFAULT now(),
    created_by              uuid            NULL,
    updated_at              timestamptz     NOT NULL DEFAULT now(),
    updated_by              uuid            NULL,

    CONSTRAINT pk_book_tax_reconciliations PRIMARY KEY (id),
    CONSTRAINT fk_btr_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_btr_computation_run
        FOREIGN KEY (computation_run_id) REFERENCES public.itr_computation_runs(id),
    CONSTRAINT fk_btr_account
        FOREIGN KEY (account_id) REFERENCES public.chart_of_accounts(id),
    CONSTRAINT fk_btr_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_btr_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_btr_reconciliation_type
        CHECK (reconciliation_type IN ('add_back','deduction','permanent','temporary')),
    CONSTRAINT ck_btr_sequence_pos
        CHECK (sequence_no >= 1)
);

COMMENT ON TABLE public.book_tax_reconciliations IS
    'Book-to-tax reconciliation schedule per ITR computation run. '
    'Permanent differences: non-deductible expenses, exempt income. '
    'Temporary differences: timing differences (depreciation, etc). '
    'difference_amount = tax_amount - book_amount.';

CREATE INDEX idx_btr_run
    ON public.book_tax_reconciliations (computation_run_id);

-- ---------------------------------------------------------------------------
-- SECTION 23: tax_credits_schedules
-- ---------------------------------------------------------------------------
-- Creditable withholding taxes applied against income tax due.
-- Only EWT/2307 received certificates are creditable (NOT 2306 — FWT is final).
-- ---------------------------------------------------------------------------

CREATE TABLE public.tax_credits_schedules (
    id                  uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid            NOT NULL,
    itr_filing_id       uuid            NOT NULL,
    credit_type         text            NOT NULL,
    certificate_id      uuid            NULL,
    credit_period_from  date            NOT NULL,
    credit_period_to    date            NOT NULL,
    credit_amount       numeric(18,4)   NOT NULL DEFAULT 0,
    payor_name          text            NULL,
    payor_tin           text            NULL,

    -- Standard audit columns
    created_at          timestamptz     NOT NULL DEFAULT now(),
    created_by          uuid            NULL,
    updated_at          timestamptz     NOT NULL DEFAULT now(),
    updated_by          uuid            NULL,
    deleted_at          timestamptz     NULL,
    deleted_by          uuid            NULL,

    CONSTRAINT pk_tax_credits_schedules PRIMARY KEY (id),
    CONSTRAINT fk_tcs_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_tcs_itr_filing
        FOREIGN KEY (itr_filing_id) REFERENCES public.income_tax_return_filings(id),
    CONSTRAINT fk_tcs_certificate
        FOREIGN KEY (certificate_id) REFERENCES public.certificates_2307_received(id),
    CONSTRAINT fk_tcs_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_tcs_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_tcs_deleted_by
        FOREIGN KEY (deleted_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_tcs_credit_type
        CHECK (credit_type IN ('ewt_2307','prior_quarter_overpayment','soa_payment')),
    CONSTRAINT ck_tcs_date_range
        CHECK (credit_period_to >= credit_period_from),
    CONSTRAINT ck_tcs_credit_amount_nneg
        CHECK (credit_amount >= 0)
);

COMMENT ON TABLE public.tax_credits_schedules IS
    'Tax credits applied against income tax due per ITR filing. '
    'CRITICAL: credit_type does NOT include fwt_2306 — FWT is FINAL withholding '
    'tax; payees CANNOT credit 2306 against ITR per Doc03 BLOCKER 6 and Doc05 §7. '
    'certificate_id refs certificates_2307_received (2307 only, not 2306).';

COMMENT ON COLUMN public.tax_credits_schedules.credit_type IS
    'ewt_2307=creditable EWT from 2307 certificates received; '
    'prior_quarter_overpayment=overpayment from prior Q; '
    'soa_payment=SOA advance payment credit. '
    'fwt_2306 is EXCLUDED: Final Withholding Tax is non-creditable.';

CREATE INDEX idx_tcs_filing
    ON public.tax_credits_schedules (itr_filing_id)
    WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- SECTION 24: nolco_tracking
-- ---------------------------------------------------------------------------
-- Net Operating Loss Carry-Over per fiscal year.
-- 3-year carry-over per NIRC. Applies to corporate and individual using
-- itemized deductions only (not OSD users).
-- ---------------------------------------------------------------------------

CREATE TABLE public.nolco_tracking (
    id                  uuid            NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid            NOT NULL,
    fiscal_year_id      uuid            NOT NULL,
    nolco_amount        numeric(18,4)   NOT NULL DEFAULT 0,
    applied_fy1_amount  numeric(18,4)   NOT NULL DEFAULT 0,
    applied_fy2_amount  numeric(18,4)   NOT NULL DEFAULT 0,
    applied_fy3_amount  numeric(18,4)   NOT NULL DEFAULT 0,
    remaining_balance   numeric(18,4)   NOT NULL DEFAULT 0,
    is_expired          boolean         NOT NULL DEFAULT false,

    -- Standard audit columns
    created_at          timestamptz     NOT NULL DEFAULT now(),
    created_by          uuid            NULL,
    updated_at          timestamptz     NOT NULL DEFAULT now(),
    updated_by          uuid            NULL,

    CONSTRAINT pk_nolco_tracking PRIMARY KEY (id),
    CONSTRAINT uq_nolco_company_year
        UNIQUE (company_id, fiscal_year_id),
    CONSTRAINT fk_nolco_company
        FOREIGN KEY (company_id) REFERENCES public.companies(id),
    CONSTRAINT fk_nolco_fiscal_year
        FOREIGN KEY (fiscal_year_id) REFERENCES public.fiscal_years(id),
    CONSTRAINT fk_nolco_created_by
        FOREIGN KEY (created_by) REFERENCES public.profiles(id),
    CONSTRAINT fk_nolco_updated_by
        FOREIGN KEY (updated_by) REFERENCES public.profiles(id),

    CONSTRAINT ck_nolco_amounts_nneg
        CHECK (nolco_amount >= 0 AND applied_fy1_amount >= 0 AND
               applied_fy2_amount >= 0 AND applied_fy3_amount >= 0 AND
               remaining_balance >= 0)
);

COMMENT ON TABLE public.nolco_tracking IS
    'Net Operating Loss Carry-Over tracking per fiscal year. '
    '3-year carry-over deduction per NIRC. is_expired=true after 3-year window lapses. '
    'Applies ONLY to income_tax_regime = corporate or individual using itemized '
    'deductions — OSD users may NOT carry over losses. '
    'remaining_balance = nolco_amount − sum(applied_fy1 + applied_fy2 + applied_fy3). '
    'Application must enforce remaining_balance invariant at update time.';

-- ---------------------------------------------------------------------------
-- SECTION 25: ALTER TABLE — Resolve circular FK on income_tax_return_filings
-- ---------------------------------------------------------------------------
-- income_tax_return_filings was created with itr_computation_run_id as plain
-- uuid NULL. itr_computation_runs now exists — add the FK constraint.
-- ---------------------------------------------------------------------------

ALTER TABLE public.income_tax_return_filings
    ADD CONSTRAINT fk_itrf_itr_computation_run
        FOREIGN KEY (itr_computation_run_id) REFERENCES public.itr_computation_runs(id);

-- ---------------------------------------------------------------------------
-- END OF MIGRATION 015
-- ---------------------------------------------------------------------------
-- Tables created: 24
--   Module 17 VAT (5): vat_entries, vat_period_summaries, vat_return_filings,
--     slsp_exports, relief_exports
--   Module 18 Withholding Tax (10): certificates_2307_issued,
--     certificates_2307_received, ewt_entries, ewt_period_summaries,
--     ewt_remittances_1601eq, fwt_entries, certificates_2306_issued,
--     fwt_remittances_1601fq, qap_exports, sawt_exports
--   Module 29 Percentage Tax (3): percentage_tax_entries,
--     percentage_tax_period_summaries, percentage_tax_return_filings
--   Module 19 Income Tax (4): income_tax_return_filings, itr_computation_runs,
--     income_tax_computation_lines, book_tax_reconciliations
--   Module 19 + 30 (2): tax_credits_schedules, nolco_tracking
--
-- ALTER TABLE ADD CONSTRAINT: 1 (circular FK — income_tax_return_filings
--   .itr_computation_run_id → itr_computation_runs)
--
-- Deferred FKs (tables not yet created):
--   certificates_2307_issued.generated_document_id → generated_documents.id
--     (Module 25 migration)
--   certificates_2307_received.attachment_id → attachments.id
--     (Module 21 migration)
--   certificates_2306_issued.generated_document_id → generated_documents.id
--     (Module 25 migration)
--   fwt_remittances_1601fq.export_job_id → export_jobs.id
--     (Module 23 migration)
--   percentage_tax_return_filings.export_job_id → export_jobs.id
--     (Module 23 migration)
--   income_tax_return_filings.export_job_id → export_jobs.id
--     (Module 23 migration)
-- ---------------------------------------------------------------------------
