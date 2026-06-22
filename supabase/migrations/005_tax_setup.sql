-- =============================================================================
-- Migration 005: Module 5 — Tax Setup
-- =============================================================================
-- Tables created (8, in FK dependency order):
--   bir_form_configurations, atc_codes, tax_codes, vat_codes,
--   percentage_tax_codes, ewt_codes, fwt_codes, tax_calendar
--
-- Intentionally deferred: none — all 8 Doc02 Module 5 tables are included.
--
-- FK dependency order:
--   Group A (no cross-Module-5 deps):
--     bir_form_configurations, atc_codes, tax_codes, vat_codes,
--     percentage_tax_codes
--   Group B (reference atc_codes):
--     ewt_codes, fwt_codes
--   Group C (logically last):
--     tax_calendar
--
-- All tables: RLS=enabled, Audit=standard, Soft Delete=yes, Immutable=no.
-- atc_codes is a global BIR reference table — no company_id, no per-company
--   RLS; rows are inserted by platform admins, read by all authenticated users.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- GROUP A: No cross-Module-5 foreign key dependencies
-- ---------------------------------------------------------------------------

-- #33 bir_form_configurations
-- BIR form setup per company; tracks which forms apply and their filing periods.
CREATE TABLE public.bir_form_configurations (
    id                  uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES public.companies(id),
    form_code           text        NOT NULL,
    filing_frequency    text        NOT NULL,
    is_mandatory        boolean     NOT NULL DEFAULT true,
    effective_from      date        NOT NULL,
    effective_to        date        NULL,
    -- standard audit
    created_at          timestamptz NOT NULL DEFAULT now(),
    created_by          uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at          timestamptz NULL,
    deleted_by          uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_bir_form_configurations PRIMARY KEY (id),
    CONSTRAINT ck_bir_form_configurations_form_code CHECK (
        form_code IN ('2550M','2550Q','2551Q','1601EQ','1601FQ','1604E','1701Q','1701','1702Q','1702RT')
    ),
    CONSTRAINT ck_bir_form_configurations_filing_frequency CHECK (
        filing_frequency IN ('monthly','quarterly','annual')
    ),
    CONSTRAINT ck_bir_form_configurations_effective_dates CHECK (
        effective_to IS NULL OR effective_to > effective_from
    )
);

-- One active record per company+form (effective_to IS NULL = currently active)
CREATE UNIQUE INDEX uq_bir_form_configurations_active
    ON public.bir_form_configurations (company_id, form_code)
    WHERE effective_to IS NULL AND deleted_at IS NULL;

CREATE INDEX ix_bir_form_configurations_company
    ON public.bir_form_configurations (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.bir_form_configurations ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #37 atc_codes
-- Global BIR ATC code master (WC=EWT, WI=EWT import, WF=FWT).
-- No company_id — issued by BIR; shared across all tenants.
-- ---------------------------------------------------------------------------
CREATE TABLE public.atc_codes (
    id                      uuid        NOT NULL DEFAULT gen_random_uuid(),
    code                    text        NOT NULL,
    description             text        NOT NULL,
    tax_type                text        NOT NULL,
    rate                    numeric(10,6) NOT NULL,
    income_payment_category text        NULL,
    effective_from          date        NOT NULL,
    effective_to            date        NULL,
    is_active               boolean     NOT NULL DEFAULT true,
    -- standard audit
    created_at              timestamptz NOT NULL DEFAULT now(),
    created_by              uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    updated_by              uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at              timestamptz NULL,
    deleted_by              uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_atc_codes PRIMARY KEY (id),
    CONSTRAINT ck_atc_codes_tax_type CHECK (tax_type IN ('ewt','fwt')),
    CONSTRAINT ck_atc_codes_rate CHECK (rate >= 0 AND rate <= 1),
    CONSTRAINT ck_atc_codes_effective_dates CHECK (
        effective_to IS NULL OR effective_to > effective_from
    )
);

-- One active record per BIR ATC code at any time
CREATE UNIQUE INDEX uq_atc_codes_active
    ON public.atc_codes (code)
    WHERE effective_to IS NULL AND deleted_at IS NULL;

CREATE INDEX ix_atc_codes_tax_type
    ON public.atc_codes (tax_type)
    WHERE deleted_at IS NULL;

ALTER TABLE public.atc_codes ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #34 tax_codes
-- General tax code master per company; bridges vat/ewt/fwt/pt under one roof.
-- ---------------------------------------------------------------------------
CREATE TABLE public.tax_codes (
    id          uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id  uuid          NOT NULL REFERENCES public.companies(id),
    code        text          NOT NULL,
    description text          NOT NULL,
    tax_type    text          NOT NULL,
    rate        numeric(10,6) NOT NULL DEFAULT 0,
    is_active   boolean       NOT NULL DEFAULT true,
    -- standard audit
    created_at  timestamptz   NOT NULL DEFAULT now(),
    created_by  uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz   NOT NULL DEFAULT now(),
    updated_by  uuid          NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz   NULL,
    deleted_by  uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_tax_codes PRIMARY KEY (id),
    CONSTRAINT ck_tax_codes_tax_type CHECK (
        tax_type IN ('vat','ewt','fwt','percentage_tax')
    ),
    CONSTRAINT ck_tax_codes_rate CHECK (rate >= 0 AND rate <= 1)
);

CREATE UNIQUE INDEX uq_tax_codes_company_code
    ON public.tax_codes (company_id, code)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_tax_codes_company
    ON public.tax_codes (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.tax_codes ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #35 vat_codes
-- VAT type codes per company with rate versioning via effective dates.
-- Canonical spec: Doc03 §21.
-- ---------------------------------------------------------------------------
CREATE TABLE public.vat_codes (
    id             uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id     uuid          NOT NULL REFERENCES public.companies(id),
    code           text          NOT NULL,
    description    text          NOT NULL,
    rate           numeric(10,6) NOT NULL,
    classification text          NOT NULL,
    effective_from date          NOT NULL,
    effective_to   date          NULL,
    is_active      boolean       NOT NULL DEFAULT true,
    -- standard audit
    created_at     timestamptz   NOT NULL DEFAULT now(),
    created_by     uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at     timestamptz   NOT NULL DEFAULT now(),
    updated_by     uuid          NOT NULL REFERENCES public.profiles(id),
    deleted_at     timestamptz   NULL,
    deleted_by     uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_vat_codes PRIMARY KEY (id),
    CONSTRAINT ck_vat_codes_classification CHECK (
        classification IN ('vatable','zero_rated','exempt')
    ),
    CONSTRAINT ck_vat_codes_rate CHECK (rate >= 0 AND rate <= 1),
    CONSTRAINT ck_vat_codes_effective_dates CHECK (
        effective_to IS NULL OR effective_to > effective_from
    )
);

-- One active record per company+code at any time (two indexes for NULL branch)
CREATE UNIQUE INDEX uq_vat_codes_active
    ON public.vat_codes (company_id, code)
    WHERE effective_to IS NULL AND deleted_at IS NULL;

CREATE INDEX ix_vat_codes_company
    ON public.vat_codes (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.vat_codes ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #36b percentage_tax_codes
-- Industry-specific percentage tax codes per NIRC section.
-- ---------------------------------------------------------------------------
CREATE TABLE public.percentage_tax_codes (
    id                 uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id         uuid          NOT NULL REFERENCES public.companies(id),
    code               text          NOT NULL,
    description        text          NOT NULL,
    rate               numeric(10,6) NOT NULL DEFAULT 0.03,
    applicable_section text          NULL,
    is_active          boolean       NOT NULL DEFAULT true,
    -- standard audit
    created_at         timestamptz   NOT NULL DEFAULT now(),
    created_by         uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at         timestamptz   NOT NULL DEFAULT now(),
    updated_by         uuid          NOT NULL REFERENCES public.profiles(id),
    deleted_at         timestamptz   NULL,
    deleted_by         uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_percentage_tax_codes PRIMARY KEY (id),
    CONSTRAINT ck_percentage_tax_codes_rate CHECK (rate >= 0 AND rate <= 1)
);

CREATE UNIQUE INDEX uq_percentage_tax_codes_company_code
    ON public.percentage_tax_codes (company_id, code)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_percentage_tax_codes_company
    ON public.percentage_tax_codes (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.percentage_tax_codes ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- GROUP B: Reference atc_codes
-- ---------------------------------------------------------------------------

-- #36 ewt_codes
-- Expanded withholding tax codes; WC or WI series ATC only.
CREATE TABLE public.ewt_codes (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id           uuid          NOT NULL REFERENCES public.companies(id),
    atc_code_id          uuid          NOT NULL REFERENCES public.atc_codes(id),
    description          text          NOT NULL,
    rate                 numeric(10,6) NOT NULL,
    income_payment_type  text          NOT NULL,
    is_active            boolean       NOT NULL DEFAULT true,
    -- standard audit
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at           timestamptz   NOT NULL DEFAULT now(),
    updated_by           uuid          NOT NULL REFERENCES public.profiles(id),
    deleted_at           timestamptz   NULL,
    deleted_by           uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_ewt_codes PRIMARY KEY (id),
    CONSTRAINT ck_ewt_codes_rate CHECK (rate >= 0 AND rate <= 1)
);

CREATE UNIQUE INDEX uq_ewt_codes_company_atc
    ON public.ewt_codes (company_id, atc_code_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_ewt_codes_company
    ON public.ewt_codes (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.ewt_codes ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #36a fwt_codes
-- Final withholding tax codes; WF series ATC only.
-- ---------------------------------------------------------------------------
CREATE TABLE public.fwt_codes (
    id          uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id  uuid          NOT NULL REFERENCES public.companies(id),
    atc_code_id uuid          NOT NULL REFERENCES public.atc_codes(id),
    description text          NOT NULL,
    rate        numeric(10,6) NOT NULL,
    is_active   boolean       NOT NULL DEFAULT true,
    -- standard audit
    created_at  timestamptz   NOT NULL DEFAULT now(),
    created_by  uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz   NOT NULL DEFAULT now(),
    updated_by  uuid          NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz   NULL,
    deleted_by  uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_fwt_codes PRIMARY KEY (id),
    CONSTRAINT ck_fwt_codes_rate CHECK (rate >= 0 AND rate <= 1)
);

CREATE UNIQUE INDEX uq_fwt_codes_company_atc
    ON public.fwt_codes (company_id, atc_code_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_fwt_codes_company
    ON public.fwt_codes (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.fwt_codes ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- GROUP C: Logically last
-- ---------------------------------------------------------------------------

-- #38 tax_calendar
-- BIR filing deadlines per company and form. form_code is text (not FK) to
-- allow calendar entries for forms not yet in bir_form_configurations.
CREATE TABLE public.tax_calendar (
    id                uuid        NOT NULL DEFAULT gen_random_uuid(),
    company_id        uuid        NOT NULL REFERENCES public.companies(id),
    form_code         text        NOT NULL,
    period_covered    text        NOT NULL,
    due_date          date        NOT NULL,
    extended_due_date date        NULL,
    is_filed          boolean     NOT NULL DEFAULT false,
    filed_at          timestamptz NULL,
    -- standard audit
    created_at        timestamptz NOT NULL DEFAULT now(),
    created_by        uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    updated_by        uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at        timestamptz NULL,
    deleted_by        uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_tax_calendar PRIMARY KEY (id),
    CONSTRAINT ck_tax_calendar_form_code CHECK (
        form_code IN ('2550M','2550Q','2551Q','1601EQ','1601FQ','1604E','1701Q','1701','1702Q','1702RT')
    ),
    CONSTRAINT ck_tax_calendar_extended_due CHECK (
        extended_due_date IS NULL OR extended_due_date >= due_date
    ),
    CONSTRAINT ck_tax_calendar_filed CHECK (
        is_filed = false OR filed_at IS NOT NULL
    )
);

CREATE UNIQUE INDEX uq_tax_calendar_company_form_period
    ON public.tax_calendar (company_id, form_code, period_covered)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_tax_calendar_company_due
    ON public.tax_calendar (company_id, due_date)
    WHERE deleted_at IS NULL AND is_filed = false;

ALTER TABLE public.tax_calendar ENABLE ROW LEVEL SECURITY;
