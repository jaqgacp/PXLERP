-- =============================================================================
-- Migration 006: Master Data — Modules 6, 7, 8
-- =============================================================================
-- Tables created (21, in FK dependency order):
--
-- MODULE 6 — MASTER DATA: PARTIES
--   payment_terms, payment_term_lines,
--   customers, suppliers,
--   customer_addresses, customer_contacts, customer_credit_profiles,
--   customer_tax_profiles,
--   supplier_addresses, supplier_contacts, supplier_tax_profiles,
--   supplier_bank_details,
--   personnel
--
-- MODULE 7 — MASTER DATA: ITEMS & SERVICES
--   item_categories, units_of_measure, uom_conversions,
--   items, item_prices, services
--
-- MODULE 8 — INVENTORY MASTER
--   warehouses, warehouse_stock_settings
--
-- Intentionally deferred:
--   inventory_balances (#59)    — type=ledger; no audit cols; upserted by
--                                 posting engine; belongs with inventory txn
--   inventory_cost_layers (#60) — type=ledger; Immutable=yes; written at
--                                 goods receipt; belongs with inventory txn
--   import_batch_id FKs on customers, suppliers, items, payment_terms —
--                                 import_batches table created in a later
--                                 migration; columns included as uuid NULL,
--                                 FK constraint added then
-- =============================================================================

-- ---------------------------------------------------------------------------
-- GROUP 1: No cross-module deps within this migration
-- ---------------------------------------------------------------------------

-- #50 payment_terms
-- Shared payment terms (Net 30, COD, CIA, etc.).
CREATE TABLE public.payment_terms (
    id               uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id       uuid          NOT NULL REFERENCES public.companies(id),
    code             text          NOT NULL,
    name             text          NOT NULL,
    description      text          NULL,
    due_days         integer       NOT NULL DEFAULT 0,
    discount_days    integer       NULL,
    discount_percent numeric(10,6) NULL,
    is_active        boolean       NOT NULL DEFAULT true,
    -- import_batch_id: FK to import_batches added in a later migration
    import_batch_id  uuid          NULL,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_payment_terms PRIMARY KEY (id),
    CONSTRAINT ck_payment_terms_due_days CHECK (due_days >= 0),
    CONSTRAINT ck_payment_terms_discount_days CHECK (
        discount_days IS NULL OR discount_days >= 0
    ),
    CONSTRAINT ck_payment_terms_discount_pct CHECK (
        discount_percent IS NULL OR (discount_percent >= 0 AND discount_percent <= 1)
    )
);

CREATE UNIQUE INDEX uq_payment_terms_company_code
    ON public.payment_terms (company_id, code)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_payment_terms_company
    ON public.payment_terms (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.payment_terms ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- payment_term_lines (Doc03 §21 — child of payment_terms)
-- Instalment schedule; 1+ lines whose percent_due sums to 1.0.
-- Not separately numbered in Doc02; required by payment_terms design.
-- ---------------------------------------------------------------------------
CREATE TABLE public.payment_term_lines (
    id               uuid          NOT NULL DEFAULT gen_random_uuid(),
    payment_term_id  uuid          NOT NULL REFERENCES public.payment_terms(id),
    sequence_no      integer       NOT NULL DEFAULT 1,
    days_due         integer       NOT NULL DEFAULT 0,
    percent_due      numeric(10,6) NOT NULL DEFAULT 1.000000,

    CONSTRAINT pk_payment_term_lines PRIMARY KEY (id),
    CONSTRAINT ck_payment_term_lines_sequence CHECK (sequence_no >= 1),
    CONSTRAINT ck_payment_term_lines_days CHECK (days_due >= 0),
    CONSTRAINT ck_payment_term_lines_percent CHECK (percent_due > 0 AND percent_due <= 1),
    CONSTRAINT uq_payment_term_lines_seq UNIQUE (payment_term_id, sequence_no)
);

CREATE INDEX ix_payment_term_lines_term
    ON public.payment_term_lines (payment_term_id);

-- No RLS — child of payment_terms; access governed by parent.
-- No soft delete — lines replaced via payment_terms edit workflow.

-- ---------------------------------------------------------------------------
-- #51 item_categories
-- Hierarchical item categories (self-referential).
-- ---------------------------------------------------------------------------
CREATE TABLE public.item_categories (
    id                 uuid    NOT NULL DEFAULT gen_random_uuid(),
    company_id         uuid    NOT NULL REFERENCES public.companies(id),
    code               text    NOT NULL,
    name               text    NOT NULL,
    -- NULL = root category
    parent_category_id uuid    NULL     REFERENCES public.item_categories(id),
    is_active          boolean NOT NULL DEFAULT true,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_item_categories PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uq_item_categories_company_code
    ON public.item_categories (company_id, code)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_item_categories_company
    ON public.item_categories (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.item_categories ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #52 units_of_measure
-- UOM master (PC, KG, LTR, BOX, etc.).
-- ---------------------------------------------------------------------------
CREATE TABLE public.units_of_measure (
    id         uuid    NOT NULL DEFAULT gen_random_uuid(),
    company_id uuid    NOT NULL REFERENCES public.companies(id),
    code       text    NOT NULL,
    name       text    NOT NULL,
    symbol     text    NOT NULL,
    is_active  boolean NOT NULL DEFAULT true,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_units_of_measure PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uq_units_of_measure_company_code
    ON public.units_of_measure (company_id, code)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_units_of_measure_company
    ON public.units_of_measure (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.units_of_measure ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #57 warehouses
-- Warehouse / storage location master. Belongs to a branch.
-- ---------------------------------------------------------------------------
CREATE TABLE public.warehouses (
    id         uuid    NOT NULL DEFAULT gen_random_uuid(),
    company_id uuid    NOT NULL REFERENCES public.companies(id),
    branch_id  uuid    NOT NULL REFERENCES public.branches(id),
    code       text    NOT NULL,
    name       text    NOT NULL,
    address    text    NULL,
    is_default boolean NOT NULL DEFAULT false,
    is_active  boolean NOT NULL DEFAULT true,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_warehouses PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uq_warehouses_company_code
    ON public.warehouses (company_id, code)
    WHERE deleted_at IS NULL;

-- One default warehouse per branch at a time
CREATE UNIQUE INDEX uq_warehouses_branch_default
    ON public.warehouses (company_id, branch_id)
    WHERE is_default = true AND deleted_at IS NULL;

CREATE INDEX ix_warehouses_company
    ON public.warehouses (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- GROUP 2: Reference payment_terms
-- ---------------------------------------------------------------------------

-- #39 customers
-- Customer master. Two separate columns: vat_registration_status and
-- party_special_class (v3 split per Doc02 Module 6 note).
CREATE TABLE public.customers (
    id                     uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id             uuid          NOT NULL REFERENCES public.companies(id),
    customer_code          text          NOT NULL,
    customer_name          text          NOT NULL,
    trade_name             text          NULL,
    customer_type          text          NOT NULL DEFAULT 'business',
    tin                    text          NULL,
    vat_registration_status text         NOT NULL DEFAULT 'vat',
    -- NULL = regular entity; see Doc02 Module 6 note
    party_special_class    text          NULL,
    payment_terms_id       uuid          NULL     REFERENCES public.payment_terms(id),
    ar_account_id          uuid          NULL     REFERENCES public.chart_of_accounts(id),
    sales_account_id       uuid          NULL     REFERENCES public.chart_of_accounts(id),
    is_ewt_agent           boolean       NOT NULL DEFAULT false,
    default_ewt_atc_id     uuid          NULL     REFERENCES public.atc_codes(id),
    credit_limit           numeric(18,4) NOT NULL DEFAULT 0,
    currency_id            uuid          NOT NULL REFERENCES public.currencies(id),
    is_active              boolean       NOT NULL DEFAULT true,
    -- FK to import_batches added in a later migration
    import_batch_id        uuid          NULL,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_customers PRIMARY KEY (id),
    CONSTRAINT ck_customers_type CHECK (
        customer_type IN ('individual','business','government')
    ),
    CONSTRAINT ck_customers_vat_reg CHECK (
        vat_registration_status IN ('vat','non_vat')
    ),
    CONSTRAINT ck_customers_special_class CHECK (
        party_special_class IS NULL OR
        party_special_class IN ('government','peza','boi','foreign_entity')
    ),
    CONSTRAINT ck_customers_credit_limit CHECK (credit_limit >= 0)
);

CREATE UNIQUE INDEX uq_customers_company_code
    ON public.customers (company_id, customer_code)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_customers_company
    ON public.customers (company_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_customers_tin
    ON public.customers (company_id, tin)
    WHERE tin IS NOT NULL AND deleted_at IS NULL;

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #44 suppliers
-- Supplier master. Mirrors customers with AP/EWT orientation.
-- ---------------------------------------------------------------------------
CREATE TABLE public.suppliers (
    id                      uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid          NOT NULL REFERENCES public.companies(id),
    supplier_code           text          NOT NULL,
    supplier_name           text          NOT NULL,
    trade_name              text          NULL,
    supplier_type           text          NOT NULL DEFAULT 'business',
    tin                     text          NULL,
    vat_registration_status text          NOT NULL DEFAULT 'vat',
    -- NULL = regular entity; see Doc02 Module 6 note
    party_special_class     text          NULL,
    payment_terms_id        uuid          NULL     REFERENCES public.payment_terms(id),
    ap_account_id           uuid          NULL     REFERENCES public.chart_of_accounts(id),
    expense_account_id      uuid          NULL     REFERENCES public.chart_of_accounts(id),
    ewt_subject             boolean       NOT NULL DEFAULT true,
    default_ewt_atc_id      uuid          NULL     REFERENCES public.atc_codes(id),
    currency_id             uuid          NOT NULL REFERENCES public.currencies(id),
    is_active               boolean       NOT NULL DEFAULT true,
    -- FK to import_batches added in a later migration
    import_batch_id         uuid          NULL,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_suppliers PRIMARY KEY (id),
    CONSTRAINT ck_suppliers_type CHECK (
        supplier_type IN ('individual','business','government')
    ),
    CONSTRAINT ck_suppliers_vat_reg CHECK (
        vat_registration_status IN ('vat','non_vat')
    ),
    CONSTRAINT ck_suppliers_special_class CHECK (
        party_special_class IS NULL OR
        party_special_class IN ('government','peza','boi','foreign_entity')
    )
);

CREATE UNIQUE INDEX uq_suppliers_company_code
    ON public.suppliers (company_id, supplier_code)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_suppliers_company
    ON public.suppliers (company_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_suppliers_tin
    ON public.suppliers (company_id, tin)
    WHERE tin IS NOT NULL AND deleted_at IS NULL;

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- GROUP 3: Reference customers / suppliers
-- ---------------------------------------------------------------------------

-- #40 customer_addresses
CREATE TABLE public.customer_addresses (
    id           uuid    NOT NULL DEFAULT gen_random_uuid(),
    company_id   uuid    NOT NULL REFERENCES public.companies(id),
    customer_id  uuid    NOT NULL REFERENCES public.customers(id),
    address_type text    NOT NULL,
    address_line1 text   NOT NULL,
    address_line2 text   NULL,
    city         text    NOT NULL,
    province     text    NOT NULL,
    zip_code     text    NULL,
    country      text    NOT NULL DEFAULT 'PH',
    is_primary   boolean NOT NULL DEFAULT false,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_customer_addresses PRIMARY KEY (id),
    CONSTRAINT ck_customer_addresses_type CHECK (
        address_type IN ('billing','shipping','both')
    )
);

-- One primary address per customer per type at a time
CREATE UNIQUE INDEX uq_customer_addresses_primary
    ON public.customer_addresses (company_id, customer_id, address_type)
    WHERE is_primary = true AND deleted_at IS NULL;

CREATE INDEX ix_customer_addresses_customer
    ON public.customer_addresses (company_id, customer_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.customer_addresses ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #41 customer_contacts
CREATE TABLE public.customer_contacts (
    id          uuid    NOT NULL DEFAULT gen_random_uuid(),
    company_id  uuid    NOT NULL REFERENCES public.companies(id),
    customer_id uuid    NOT NULL REFERENCES public.customers(id),
    first_name  text    NOT NULL,
    last_name   text    NOT NULL,
    position    text    NULL,
    email       text    NULL,
    phone       text    NULL,
    is_primary  boolean NOT NULL DEFAULT false,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_customer_contacts PRIMARY KEY (id)
);

-- One primary contact per customer at a time
CREATE UNIQUE INDEX uq_customer_contacts_primary
    ON public.customer_contacts (company_id, customer_id)
    WHERE is_primary = true AND deleted_at IS NULL;

CREATE INDEX ix_customer_contacts_customer
    ON public.customer_contacts (company_id, customer_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.customer_contacts ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #43 customer_credit_profiles
CREATE TABLE public.customer_credit_profiles (
    id                  uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid          NOT NULL REFERENCES public.companies(id),
    customer_id         uuid          NOT NULL REFERENCES public.customers(id),
    credit_limit        numeric(18,4) NOT NULL DEFAULT 0,
    current_outstanding numeric(18,4) NOT NULL DEFAULT 0,
    payment_terms_id    uuid          NULL     REFERENCES public.payment_terms(id),
    credit_hold         boolean       NOT NULL DEFAULT false,
    last_review_date    date          NULL,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_customer_credit_profiles PRIMARY KEY (id),
    CONSTRAINT ck_customer_credit_profiles_limit CHECK (credit_limit >= 0),
    CONSTRAINT ck_customer_credit_profiles_outstanding CHECK (current_outstanding >= 0)
);

CREATE UNIQUE INDEX uq_customer_credit_profiles_company_customer
    ON public.customer_credit_profiles (company_id, customer_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.customer_credit_profiles ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #42 customer_tax_profiles
-- Versioned per Principle 11. One active profile per (company_id, customer_id).
CREATE TABLE public.customer_tax_profiles (
    id                    uuid    NOT NULL DEFAULT gen_random_uuid(),
    customer_id           uuid    NOT NULL REFERENCES public.customers(id),
    company_id            uuid    NOT NULL REFERENCES public.companies(id),
    tin                   text    NOT NULL,
    bir_registered_address text   NULL,
    bir_rdo_code          text    NULL,
    vat_registration_no   text    NULL,
    is_ewt_agent          boolean NOT NULL DEFAULT false,
    default_ewt_atc_id    uuid    NULL     REFERENCES public.atc_codes(id),
    effective_from        date    NOT NULL,
    effective_to          date    NULL,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_customer_tax_profiles PRIMARY KEY (id),
    CONSTRAINT ck_customer_tax_profiles_dates CHECK (
        effective_to IS NULL OR effective_to > effective_from
    ),
    CONSTRAINT uq_customer_tax_profiles_versioned
        UNIQUE (company_id, customer_id, effective_from)
);

-- One active profile per (company_id, customer_id) at a time
CREATE UNIQUE INDEX uq_customer_tax_profiles_active
    ON public.customer_tax_profiles (company_id, customer_id)
    WHERE effective_to IS NULL AND deleted_at IS NULL;

CREATE INDEX ix_customer_tax_profiles_customer
    ON public.customer_tax_profiles (company_id, customer_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.customer_tax_profiles ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #45 supplier_addresses
CREATE TABLE public.supplier_addresses (
    id            uuid    NOT NULL DEFAULT gen_random_uuid(),
    company_id    uuid    NOT NULL REFERENCES public.companies(id),
    supplier_id   uuid    NOT NULL REFERENCES public.suppliers(id),
    address_type  text    NOT NULL,
    address_line1 text    NOT NULL,
    address_line2 text    NULL,
    city          text    NOT NULL,
    province      text    NOT NULL,
    zip_code      text    NULL,
    country       text    NOT NULL DEFAULT 'PH',
    is_primary    boolean NOT NULL DEFAULT false,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_supplier_addresses PRIMARY KEY (id),
    CONSTRAINT ck_supplier_addresses_type CHECK (
        address_type IN ('billing','remittance','both')
    )
);

CREATE UNIQUE INDEX uq_supplier_addresses_primary
    ON public.supplier_addresses (company_id, supplier_id, address_type)
    WHERE is_primary = true AND deleted_at IS NULL;

CREATE INDEX ix_supplier_addresses_supplier
    ON public.supplier_addresses (company_id, supplier_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.supplier_addresses ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #46 supplier_contacts
CREATE TABLE public.supplier_contacts (
    id          uuid    NOT NULL DEFAULT gen_random_uuid(),
    company_id  uuid    NOT NULL REFERENCES public.companies(id),
    supplier_id uuid    NOT NULL REFERENCES public.suppliers(id),
    first_name  text    NOT NULL,
    last_name   text    NOT NULL,
    position    text    NULL,
    email       text    NULL,
    phone       text    NULL,
    is_primary  boolean NOT NULL DEFAULT false,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_supplier_contacts PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uq_supplier_contacts_primary
    ON public.supplier_contacts (company_id, supplier_id)
    WHERE is_primary = true AND deleted_at IS NULL;

CREATE INDEX ix_supplier_contacts_supplier
    ON public.supplier_contacts (company_id, supplier_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.supplier_contacts ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #47 supplier_tax_profiles
-- Mirror of customer_tax_profiles for suppliers. Versioned per Principle 11.
CREATE TABLE public.supplier_tax_profiles (
    id                    uuid    NOT NULL DEFAULT gen_random_uuid(),
    supplier_id           uuid    NOT NULL REFERENCES public.suppliers(id),
    company_id            uuid    NOT NULL REFERENCES public.companies(id),
    tin                   text    NOT NULL,
    bir_registered_address text   NULL,
    bir_rdo_code          text    NULL,
    vat_registration_no   text    NULL,
    is_ewt_subject        boolean NOT NULL DEFAULT true,
    default_ewt_atc_id    uuid    NULL     REFERENCES public.atc_codes(id),
    effective_from        date    NOT NULL,
    effective_to          date    NULL,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_supplier_tax_profiles PRIMARY KEY (id),
    CONSTRAINT ck_supplier_tax_profiles_dates CHECK (
        effective_to IS NULL OR effective_to > effective_from
    ),
    CONSTRAINT uq_supplier_tax_profiles_versioned
        UNIQUE (company_id, supplier_id, effective_from)
);

-- One active profile per (company_id, supplier_id) at a time
CREATE UNIQUE INDEX uq_supplier_tax_profiles_active
    ON public.supplier_tax_profiles (company_id, supplier_id)
    WHERE effective_to IS NULL AND deleted_at IS NULL;

CREATE INDEX ix_supplier_tax_profiles_supplier
    ON public.supplier_tax_profiles (company_id, supplier_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.supplier_tax_profiles ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #48 supplier_bank_details
CREATE TABLE public.supplier_bank_details (
    id             uuid    NOT NULL DEFAULT gen_random_uuid(),
    company_id     uuid    NOT NULL REFERENCES public.companies(id),
    supplier_id    uuid    NOT NULL REFERENCES public.suppliers(id),
    bank_name      text    NOT NULL,
    bank_branch    text    NULL,
    account_name   text    NOT NULL,
    account_number text    NOT NULL,
    account_type   text    NOT NULL,
    swift_code     text    NULL,
    is_primary     boolean NOT NULL DEFAULT false,
    is_active      boolean NOT NULL DEFAULT true,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_supplier_bank_details PRIMARY KEY (id),
    CONSTRAINT ck_supplier_bank_details_type CHECK (
        account_type IN ('savings','checking','payroll')
    )
);

CREATE UNIQUE INDEX uq_supplier_bank_details_primary
    ON public.supplier_bank_details (company_id, supplier_id)
    WHERE is_primary = true AND deleted_at IS NULL;

CREATE INDEX ix_supplier_bank_details_supplier
    ON public.supplier_bank_details (company_id, supplier_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.supplier_bank_details ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #49 personnel
-- Employee lite records — approver name resolution only; NOT payroll.
CREATE TABLE public.personnel (
    id            uuid    NOT NULL DEFAULT gen_random_uuid(),
    company_id    uuid    NOT NULL REFERENCES public.companies(id),
    employee_no   text    NOT NULL,
    first_name    text    NOT NULL,
    last_name     text    NOT NULL,
    position      text    NULL,
    department_id uuid    NULL     REFERENCES public.departments(id),
    is_active     boolean NOT NULL DEFAULT true,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_personnel PRIMARY KEY (id)
);

CREATE UNIQUE INDEX uq_personnel_company_employee_no
    ON public.personnel (company_id, employee_no)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_personnel_company
    ON public.personnel (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.personnel ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- GROUP 4: Module 7 — Items & Services
-- ---------------------------------------------------------------------------

-- #53 uom_conversions — references units_of_measure
CREATE TABLE public.uom_conversions (
    id                uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id        uuid          NOT NULL REFERENCES public.companies(id),
    from_uom_id       uuid          NOT NULL REFERENCES public.units_of_measure(id),
    to_uom_id         uuid          NOT NULL REFERENCES public.units_of_measure(id),
    conversion_factor numeric(10,6) NOT NULL,
    is_active         boolean       NOT NULL DEFAULT true,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_uom_conversions PRIMARY KEY (id),
    CONSTRAINT ck_uom_conversions_factor CHECK (conversion_factor > 0),
    -- prevent circular self-conversion
    CONSTRAINT ck_uom_conversions_different CHECK (from_uom_id <> to_uom_id)
);

CREATE UNIQUE INDEX uq_uom_conversions_pair
    ON public.uom_conversions (company_id, from_uom_id, to_uom_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.uom_conversions ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #54 items
-- Inventory item master. FKs to vat_codes, atc_codes, chart_of_accounts from
-- earlier migrations.
CREATE TABLE public.items (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id           uuid          NOT NULL REFERENCES public.companies(id),
    item_code            text          NOT NULL,
    name                 text          NOT NULL,
    description          text          NULL,
    item_category_id     uuid          NULL     REFERENCES public.item_categories(id),
    item_type            text          NOT NULL DEFAULT 'inventory',
    base_uom_id          uuid          NOT NULL REFERENCES public.units_of_measure(id),
    sales_vat_code_id    uuid          NULL     REFERENCES public.vat_codes(id),
    purchase_vat_code_id uuid          NULL     REFERENCES public.vat_codes(id),
    ewt_atc_id           uuid          NULL     REFERENCES public.atc_codes(id),
    sales_account_id     uuid          NULL     REFERENCES public.chart_of_accounts(id),
    cogs_account_id      uuid          NULL     REFERENCES public.chart_of_accounts(id),
    inventory_account_id uuid          NULL     REFERENCES public.chart_of_accounts(id),
    purchase_account_id  uuid          NULL     REFERENCES public.chart_of_accounts(id),
    standard_cost        numeric(18,4) NOT NULL DEFAULT 0,
    standard_price       numeric(18,4) NOT NULL DEFAULT 0,
    is_tracked           boolean       NOT NULL DEFAULT true,
    is_active            boolean       NOT NULL DEFAULT true,
    -- FK to import_batches added in a later migration
    import_batch_id      uuid          NULL,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_items PRIMARY KEY (id),
    CONSTRAINT ck_items_type CHECK (
        item_type IN ('inventory','non_inventory','service','fixed_asset')
    ),
    CONSTRAINT ck_items_standard_cost CHECK (standard_cost >= 0),
    CONSTRAINT ck_items_standard_price CHECK (standard_price >= 0)
);

CREATE UNIQUE INDEX uq_items_company_code
    ON public.items (company_id, item_code)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_items_company
    ON public.items (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #55 item_prices
-- Price list by item, date range, and optional customer group.
CREATE TABLE public.item_prices (
    id              uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id      uuid          NOT NULL REFERENCES public.companies(id),
    item_id         uuid          NOT NULL REFERENCES public.items(id),
    price_list_name text          NOT NULL DEFAULT 'standard',
    unit_price      numeric(18,4) NOT NULL,
    min_quantity    numeric(10,4) NOT NULL DEFAULT 1,
    customer_group  text          NULL,
    effective_from  date          NOT NULL,
    effective_to    date          NULL,
    is_active       boolean       NOT NULL DEFAULT true,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_item_prices PRIMARY KEY (id),
    CONSTRAINT ck_item_prices_unit_price CHECK (unit_price >= 0),
    CONSTRAINT ck_item_prices_min_qty CHECK (min_quantity > 0),
    CONSTRAINT ck_item_prices_dates CHECK (
        effective_to IS NULL OR effective_to > effective_from
    )
);

CREATE INDEX ix_item_prices_item
    ON public.item_prices (company_id, item_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.item_prices ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #56 services
-- Service master for non-inventory line items.
CREATE TABLE public.services (
    id                  uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid          NOT NULL REFERENCES public.companies(id),
    code                text          NOT NULL,
    name                text          NOT NULL,
    description         text          NULL,
    default_account_id  uuid          NOT NULL REFERENCES public.chart_of_accounts(id),
    default_vat_code_id uuid          NULL     REFERENCES public.vat_codes(id),
    default_ewt_code_id uuid          NULL     REFERENCES public.ewt_codes(id),
    unit_price          numeric(18,4) NULL,
    is_active           boolean       NOT NULL DEFAULT true,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_services PRIMARY KEY (id),
    CONSTRAINT ck_services_unit_price CHECK (unit_price IS NULL OR unit_price >= 0)
);

CREATE UNIQUE INDEX uq_services_company_code
    ON public.services (company_id, code)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_services_company
    ON public.services (company_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- GROUP 5: Module 8 — Inventory Master (master/config only; ledger deferred)
-- ---------------------------------------------------------------------------

-- #58 warehouse_stock_settings
-- Min/max/reorder config per item per warehouse.
CREATE TABLE public.warehouse_stock_settings (
    id            uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id    uuid          NOT NULL REFERENCES public.companies(id),
    warehouse_id  uuid          NOT NULL REFERENCES public.warehouses(id),
    item_id       uuid          NOT NULL REFERENCES public.items(id),
    min_quantity  numeric(10,4) NOT NULL DEFAULT 0,
    max_quantity  numeric(10,4) NOT NULL DEFAULT 0,
    reorder_point numeric(10,4) NOT NULL DEFAULT 0,
    -- standard audit
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    updated_by  uuid        NOT NULL REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_warehouse_stock_settings PRIMARY KEY (id),
    CONSTRAINT ck_wss_min_qty CHECK (min_quantity >= 0),
    CONSTRAINT ck_wss_max_qty CHECK (max_quantity >= 0),
    CONSTRAINT ck_wss_reorder CHECK (reorder_point >= 0)
);

CREATE UNIQUE INDEX uq_warehouse_stock_settings
    ON public.warehouse_stock_settings (company_id, warehouse_id, item_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_warehouse_stock_settings_warehouse
    ON public.warehouse_stock_settings (company_id, warehouse_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.warehouse_stock_settings ENABLE ROW LEVEL SECURITY;
