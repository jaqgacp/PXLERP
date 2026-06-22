-- =============================================================================
-- Migration 007: Sales — Modules 9 & 10
-- =============================================================================
-- Tables created (18, in FK dependency order):
--
-- MODULE 9 — SALES CYCLE (Soft Delete=YES, Immutable=NO, full audit)
--   quotations, sales_orders, quotation_lines, sales_order_lines,
--   delivery_receipts, delivery_receipt_lines
--
-- MODULE 10 — SALES TRANSACTIONS (Immutable=YES, Soft Delete=NO)
--   sales_invoices, sales_invoice_lines,
--   cash_sales, cash_sale_lines,
--   receipts, receipt_lines,
--   sales_credit_memos, sales_credit_memo_lines,
--   sales_debit_memos, sales_debit_memo_lines,
--   customer_returns, customer_return_lines
--
-- Intentionally deferred:
--   journal_entry_id FK → journal_entries (Migration 016)
--   import_batch_id  FK → import_batches  (Migration 023)
--   Column is present on all applicable tables; FK constraint added later.
--
-- FK dependency order:
--   Group A: quotations (no cross-Module-9 deps; converted_to_so_id deferred)
--   Group B: sales_orders (refs quotations)
--   Group C: FK patch — quotations.converted_to_so_id → sales_orders
--   Group D: quotation_lines, sales_order_lines (line tables)
--   Group E: delivery_receipts → customers, sales_orders
--   Group F: delivery_receipt_lines → delivery_receipts, items, warehouses
--   Group G: Module 10 headers (sales_invoices, cash_sales, receipts,
--            sales_credit_memos, sales_debit_memos, customer_returns)
--   Group H: Module 10 line tables
--
-- Posting dependencies:
--   journal_entry_id (uuid NULL) — set by posting engine at post time;
--   FK to journal_entries deferred to Migration 016.
--
-- Compliance dependencies:
--   Customer name/TIN/address snapshots stored on transaction headers for
--   SLSP, SAWT, and 2307 generation without joining live customer record.
--   atp_usage_id refs atp_usage_logs (Migration 004) — available.
--   vat_direction = 'output' on all sales lines (enforced by CHECK).
--   vat_classification on lines drives SLSP category; 'government' is derived
--   at posting from customers.party_special_class and stored on vat_entries,
--   NOT on sales lines (per Doc03 §5 v3 note).
--
-- Immutable table pattern (Module 10):
--   Only created_at, created_by from standard audit.
--   No updated_* columns. No deleted_* columns.
--   State changes (post, void, reversal) tracked via standard transaction
--   header columns (posted_at, posted_by, voided_at, voided_by, void_reason,
--   reversed_by_doc_id) — these are NOT audit columns.
--
-- Standard dimension columns on all headers:
--   company_id, branch_id, department_id, cost_center_id
--
-- Standard transaction header status CHECK:
--   ('draft','submitted','approved','posted','voided','reversed','cancelled')
-- =============================================================================

-- =============================================================================
-- GROUP A: quotations (no cross-Module-9 deps at creation time)
-- converted_to_so_id FK patched in Group C after sales_orders is created.
-- =============================================================================

-- #61 quotations
-- Sales quotation header. Mutable until converted or cancelled.
CREATE TABLE public.quotations (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.quotations(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    -- import_batch_id FK to import_batches deferred to Migration 023
    import_batch_id      uuid          NULL,
    -- quotation-specific
    customer_id          uuid          NOT NULL REFERENCES public.customers(id),
    expiry_date          date          NULL,
    -- FK patched in Group C after sales_orders is created
    converted_to_so_id   uuid          NULL,
    -- standard audit (Soft Delete=YES)
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NULL,
    updated_by  uuid        NULL     REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_quotations PRIMARY KEY (id),
    CONSTRAINT uq_quotations_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_quotations_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_quotations_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_quotations_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    )
);

CREATE INDEX ix_quotations_company_date
    ON public.quotations (company_id, document_date)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_quotations_customer
    ON public.quotations (company_id, customer_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_quotations_status
    ON public.quotations (company_id, status)
    WHERE deleted_at IS NULL;

ALTER TABLE public.quotations ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP B: sales_orders (refs quotations)
-- =============================================================================

-- #63 sales_orders
-- Sales order header. Mutable until fully invoiced or cancelled.
CREATE TABLE public.sales_orders (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.sales_orders(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- sales_order-specific
    customer_id          uuid          NOT NULL REFERENCES public.customers(id),
    -- customer PO reference for SLSP and payment matching
    customer_po_no       text          NULL,
    delivery_date        date          NULL,
    delivery_address     text          NULL,
    quotation_id         uuid          NULL     REFERENCES public.quotations(id),
    -- standard audit (Soft Delete=YES)
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NULL,
    updated_by  uuid        NULL     REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_sales_orders PRIMARY KEY (id),
    CONSTRAINT uq_sales_orders_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_sales_orders_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_sales_orders_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_sales_orders_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    )
);

CREATE INDEX ix_sales_orders_company_date
    ON public.sales_orders (company_id, document_date)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_sales_orders_customer
    ON public.sales_orders (company_id, customer_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_sales_orders_status
    ON public.sales_orders (company_id, status)
    WHERE deleted_at IS NULL;

ALTER TABLE public.sales_orders ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP C: FK patch — quotations.converted_to_so_id → sales_orders
-- Circular reference resolved by deferring this FK until sales_orders exists.
-- =============================================================================

ALTER TABLE public.quotations
    ADD CONSTRAINT fk_quotations_converted_so
        FOREIGN KEY (converted_to_so_id) REFERENCES public.sales_orders(id);

-- =============================================================================
-- GROUP D: Line tables for Module 9 cycle documents
-- =============================================================================

-- #62 quotation_lines
CREATE TABLE public.quotation_lines (
    id              uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id      uuid          NOT NULL REFERENCES public.companies(id),
    quotation_id    uuid          NOT NULL REFERENCES public.quotations(id),
    line_no         integer       NOT NULL,
    item_id         uuid          NULL     REFERENCES public.items(id),
    service_id      uuid          NULL     REFERENCES public.services(id),
    description     text          NOT NULL,
    quantity        numeric(10,4) NOT NULL,
    unit_price      numeric(18,4) NOT NULL,
    vat_code_id     uuid          NULL     REFERENCES public.vat_codes(id),
    vat_direction   text          NOT NULL DEFAULT 'output',
    vat_classification text       NOT NULL,
    net_amount      numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount      numeric(18,4) NOT NULL DEFAULT 0,
    gross_amount    numeric(18,4) NOT NULL DEFAULT 0,
    -- standard audit (Soft Delete=YES — mirrors parent)
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NULL,
    updated_by  uuid        NULL     REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_quotation_lines PRIMARY KEY (id),
    CONSTRAINT uq_quotation_lines_seq UNIQUE (quotation_id, line_no),
    CONSTRAINT ck_quotation_lines_direction CHECK (vat_direction = 'output'),
    CONSTRAINT ck_quotation_lines_classification CHECK (
        vat_classification IN ('vatable','zero_rated','exempt')
    ),
    CONSTRAINT ck_quotation_lines_qty CHECK (quantity > 0),
    CONSTRAINT ck_quotation_lines_price CHECK (unit_price >= 0),
    CONSTRAINT ck_quotation_lines_amounts CHECK (
        net_amount >= 0 AND vat_amount >= 0 AND gross_amount >= 0
    )
);

CREATE INDEX ix_quotation_lines_quotation
    ON public.quotation_lines (quotation_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.quotation_lines ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #64 sales_order_lines
-- delivered_qty and invoiced_qty updated by downstream documents (DR, SI).
CREATE TABLE public.sales_order_lines (
    id               uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id       uuid          NOT NULL REFERENCES public.companies(id),
    sales_order_id   uuid          NOT NULL REFERENCES public.sales_orders(id),
    line_no          integer       NOT NULL,
    item_id          uuid          NULL     REFERENCES public.items(id),
    service_id       uuid          NULL     REFERENCES public.services(id),
    description      text          NOT NULL,
    quantity         numeric(10,4) NOT NULL,
    unit_price       numeric(18,4) NOT NULL,
    -- cumulative qty fulfilled/invoiced; updated by posting engine
    delivered_qty    numeric(10,4) NOT NULL DEFAULT 0,
    invoiced_qty     numeric(10,4) NOT NULL DEFAULT 0,
    vat_code_id      uuid          NULL     REFERENCES public.vat_codes(id),
    vat_direction    text          NOT NULL DEFAULT 'output',
    vat_classification text        NOT NULL,
    net_amount       numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount       numeric(18,4) NOT NULL DEFAULT 0,
    gross_amount     numeric(18,4) NOT NULL DEFAULT 0,
    -- standard audit (Soft Delete=YES)
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NULL,
    updated_by  uuid        NULL     REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_sales_order_lines PRIMARY KEY (id),
    CONSTRAINT uq_sales_order_lines_seq UNIQUE (sales_order_id, line_no),
    CONSTRAINT ck_sol_direction CHECK (vat_direction = 'output'),
    CONSTRAINT ck_sol_classification CHECK (
        vat_classification IN ('vatable','zero_rated','exempt')
    ),
    CONSTRAINT ck_sol_qty CHECK (quantity > 0),
    CONSTRAINT ck_sol_price CHECK (unit_price >= 0),
    CONSTRAINT ck_sol_delivered CHECK (delivered_qty >= 0),
    CONSTRAINT ck_sol_invoiced CHECK (invoiced_qty >= 0)
);

CREATE INDEX ix_sales_order_lines_order
    ON public.sales_order_lines (sales_order_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.sales_order_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP E: delivery_receipts (refs customers, sales_orders)
-- =============================================================================

-- #65 delivery_receipts
-- Internal delivery document. Does not post to GL directly; confirms physical
-- delivery and triggers invoice eligibility.
CREATE TABLE public.delivery_receipts (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.delivery_receipts(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- delivery_receipt-specific
    customer_id          uuid          NOT NULL REFERENCES public.customers(id),
    sales_order_id       uuid          NULL     REFERENCES public.sales_orders(id),
    delivered_by         text          NULL,
    received_by          text          NULL,
    -- standard audit (Soft Delete=YES)
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NULL,
    updated_by  uuid        NULL     REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_delivery_receipts PRIMARY KEY (id),
    CONSTRAINT uq_delivery_receipts_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_delivery_receipts_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_delivery_receipts_exchange_rate CHECK (exchange_rate > 0)
);

CREATE INDEX ix_delivery_receipts_company_date
    ON public.delivery_receipts (company_id, document_date)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_delivery_receipts_customer
    ON public.delivery_receipts (company_id, customer_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_delivery_receipts_sales_order
    ON public.delivery_receipts (company_id, sales_order_id)
    WHERE sales_order_id IS NOT NULL AND deleted_at IS NULL;

ALTER TABLE public.delivery_receipts ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP F: delivery_receipt_lines
-- =============================================================================

-- #66 delivery_receipt_lines
CREATE TABLE public.delivery_receipt_lines (
    id                    uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id            uuid          NOT NULL REFERENCES public.companies(id),
    delivery_receipt_id   uuid          NOT NULL REFERENCES public.delivery_receipts(id),
    line_no               integer       NOT NULL,
    item_id               uuid          NOT NULL REFERENCES public.items(id),
    sales_order_line_id   uuid          NULL     REFERENCES public.sales_order_lines(id),
    quantity_requested    numeric(10,4) NOT NULL,
    quantity_delivered    numeric(10,4) NOT NULL,
    -- source warehouse for inventory movement
    warehouse_id          uuid          NOT NULL REFERENCES public.warehouses(id),
    -- standard audit (Soft Delete=YES)
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),
    updated_at  timestamptz NULL,
    updated_by  uuid        NULL     REFERENCES public.profiles(id),
    deleted_at  timestamptz NULL,
    deleted_by  uuid        NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_delivery_receipt_lines PRIMARY KEY (id),
    CONSTRAINT uq_delivery_receipt_lines_seq UNIQUE (delivery_receipt_id, line_no),
    CONSTRAINT ck_drl_qty_requested CHECK (quantity_requested > 0),
    CONSTRAINT ck_drl_qty_delivered CHECK (quantity_delivered >= 0)
);

CREATE INDEX ix_delivery_receipt_lines_dr
    ON public.delivery_receipt_lines (delivery_receipt_id)
    WHERE deleted_at IS NULL;

ALTER TABLE public.delivery_receipt_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP G: Module 10 transaction headers (Immutable — only created_at/created_by)
-- Standard transaction header included. No updated_* or deleted_* columns.
-- =============================================================================

-- #67 sales_invoices
-- AR invoice. Posted to GL via journal_entry_id (FK deferred to Migration 016).
-- Customer name/TIN/address snapshotted at invoice time for SLSP compliance.
CREATE TABLE public.sales_invoices (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.sales_invoices(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- sales_invoice-specific
    customer_id          uuid          NOT NULL REFERENCES public.customers(id),
    -- SLSP snapshots — stored at invoice time, not joined from customers at report time
    customer_name        text          NOT NULL,
    customer_tin         text          NULL,
    customer_address     text          NULL,
    sales_order_id       uuid          NULL     REFERENCES public.sales_orders(id),
    delivery_receipt_id  uuid          NULL     REFERENCES public.delivery_receipts(id),
    due_date             date          NULL,
    payment_terms_id     uuid          NULL     REFERENCES public.payment_terms(id),
    is_vat_inclusive     boolean       NOT NULL DEFAULT false,
    invoice_type         text          NOT NULL DEFAULT 'regular',
    atp_usage_id         uuid          NULL     REFERENCES public.atp_usage_logs(id),
    -- FK to journal_entries deferred to Migration 016
    journal_entry_id     uuid          NULL,
    -- Immutable: only created_at, created_by
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_sales_invoices PRIMARY KEY (id),
    CONSTRAINT uq_sales_invoices_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_sales_invoices_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_sales_invoices_invoice_type CHECK (
        invoice_type IN ('regular','vat_official','non_vat')
    ),
    CONSTRAINT ck_sales_invoices_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_sales_invoices_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    )
);

-- High-volume: specific indexes per Doc03 §5
CREATE INDEX ix_sales_invoices_company_date
    ON public.sales_invoices (company_id, document_date);

CREATE INDEX ix_sales_invoices_customer
    ON public.sales_invoices (company_id, customer_id);

CREATE INDEX ix_sales_invoices_status
    ON public.sales_invoices (company_id, status);

CREATE INDEX ix_sales_invoices_fiscal_period
    ON public.sales_invoices (company_id, fiscal_period_id);

ALTER TABLE public.sales_invoices ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #68 sales_invoice_lines
-- vat_direction = 'output' enforced. vat_classification drives SLSP category.
-- 'government' is NOT stored here — derived at posting from customers.party_special_class.
CREATE TABLE public.sales_invoice_lines (
    id                  uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid          NOT NULL REFERENCES public.companies(id),
    sales_invoice_id    uuid          NOT NULL REFERENCES public.sales_invoices(id),
    line_no             integer       NOT NULL,
    item_id             uuid          NULL     REFERENCES public.items(id),
    service_id          uuid          NULL     REFERENCES public.services(id),
    description         text          NOT NULL,
    quantity            numeric(18,4) NOT NULL,
    uom_id              uuid          NOT NULL REFERENCES public.units_of_measure(id),
    unit_price          numeric(18,4) NOT NULL,
    discount_percent    numeric(10,6) NOT NULL DEFAULT 0,
    discount_amount     numeric(18,4) NOT NULL DEFAULT 0,
    net_amount          numeric(18,4) NOT NULL,
    vat_code_id         uuid          NULL     REFERENCES public.vat_codes(id),
    vat_direction       text          NOT NULL DEFAULT 'output',
    vat_classification  text          NOT NULL DEFAULT 'vatable',
    -- rate snapshot at posting time (0 until posted)
    vat_rate            numeric(10,6) NOT NULL DEFAULT 0,
    vat_amount          numeric(18,4) NOT NULL DEFAULT 0,
    total_amount        numeric(18,4) NOT NULL,
    revenue_account_id  uuid          NULL     REFERENCES public.chart_of_accounts(id),
    warehouse_id        uuid          NULL     REFERENCES public.warehouses(id),
    -- Immutable: only created_at, created_by
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_sales_invoice_lines PRIMARY KEY (id),
    CONSTRAINT uq_sil_seq UNIQUE (sales_invoice_id, line_no),
    CONSTRAINT ck_sil_direction CHECK (vat_direction = 'output'),
    CONSTRAINT ck_sil_classification CHECK (
        vat_classification IN ('vatable','zero_rated','exempt')
    ),
    CONSTRAINT ck_sil_qty CHECK (quantity > 0),
    CONSTRAINT ck_sil_price CHECK (unit_price >= 0),
    CONSTRAINT ck_sil_discount_pct CHECK (
        discount_percent >= 0 AND discount_percent <= 1
    ),
    CONSTRAINT ck_sil_discount_amt CHECK (discount_amount >= 0),
    CONSTRAINT ck_sil_vat_rate CHECK (vat_rate >= 0 AND vat_rate <= 1)
);

CREATE INDEX ix_sales_invoice_lines_invoice
    ON public.sales_invoice_lines (sales_invoice_id);

CREATE INDEX ix_sales_invoice_lines_item
    ON public.sales_invoice_lines (company_id, item_id)
    WHERE item_id IS NOT NULL;

ALTER TABLE public.sales_invoice_lines ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #69 cash_sales
-- Immediate cash collection — no AR created. customer_id NULL = walk-in.
CREATE TABLE public.cash_sales (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.cash_sales(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- cash_sale-specific
    customer_id          uuid          NULL     REFERENCES public.customers(id),
    customer_name        text          NOT NULL DEFAULT 'Walk-in',
    customer_tin         text          NULL,
    payment_method       text          NOT NULL,
    check_no             text          NULL,
    check_date           date          NULL,
    bank_account_id      uuid          NULL     REFERENCES public.company_bank_accounts(id),
    is_vat_inclusive     boolean       NOT NULL DEFAULT false,
    receipt_type         text          NOT NULL DEFAULT 'official_receipt',
    atp_usage_id         uuid          NULL     REFERENCES public.atp_usage_logs(id),
    journal_entry_id     uuid          NULL,
    -- Immutable: only created_at, created_by
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_cash_sales PRIMARY KEY (id),
    CONSTRAINT uq_cash_sales_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_cash_sales_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_cash_sales_payment_method CHECK (
        payment_method IN ('cash','check','bank_transfer','online')
    ),
    CONSTRAINT ck_cash_sales_receipt_type CHECK (
        receipt_type IN ('official_receipt','non_vat_receipt')
    ),
    CONSTRAINT ck_cash_sales_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_cash_sales_check CHECK (
        payment_method <> 'check' OR (check_no IS NOT NULL AND check_date IS NOT NULL)
    )
);

CREATE INDEX ix_cash_sales_company_date
    ON public.cash_sales (company_id, document_date);

CREATE INDEX ix_cash_sales_customer
    ON public.cash_sales (company_id, customer_id)
    WHERE customer_id IS NOT NULL;

CREATE INDEX ix_cash_sales_status
    ON public.cash_sales (company_id, status);

ALTER TABLE public.cash_sales ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #70 cash_sale_lines
CREATE TABLE public.cash_sale_lines (
    id                 uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id         uuid          NOT NULL REFERENCES public.companies(id),
    cash_sale_id       uuid          NOT NULL REFERENCES public.cash_sales(id),
    line_no            integer       NOT NULL,
    item_id            uuid          NULL     REFERENCES public.items(id),
    service_id         uuid          NULL     REFERENCES public.services(id),
    description        text          NOT NULL,
    quantity           numeric(18,4) NOT NULL,
    uom_id             uuid          NOT NULL REFERENCES public.units_of_measure(id),
    unit_price         numeric(18,4) NOT NULL,
    discount_percent   numeric(10,6) NOT NULL DEFAULT 0,
    discount_amount    numeric(18,4) NOT NULL DEFAULT 0,
    net_amount         numeric(18,4) NOT NULL,
    vat_code_id        uuid          NULL     REFERENCES public.vat_codes(id),
    vat_direction      text          NOT NULL DEFAULT 'output',
    vat_classification text          NOT NULL DEFAULT 'vatable',
    vat_rate           numeric(10,6) NOT NULL DEFAULT 0,
    vat_amount         numeric(18,4) NOT NULL DEFAULT 0,
    total_amount       numeric(18,4) NOT NULL,
    revenue_account_id uuid          NULL     REFERENCES public.chart_of_accounts(id),
    warehouse_id       uuid          NULL     REFERENCES public.warehouses(id),
    -- Immutable
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_cash_sale_lines PRIMARY KEY (id),
    CONSTRAINT uq_csl_seq UNIQUE (cash_sale_id, line_no),
    CONSTRAINT ck_csl_direction CHECK (vat_direction = 'output'),
    CONSTRAINT ck_csl_classification CHECK (
        vat_classification IN ('vatable','zero_rated','exempt')
    ),
    CONSTRAINT ck_csl_qty CHECK (quantity > 0),
    CONSTRAINT ck_csl_price CHECK (unit_price >= 0),
    CONSTRAINT ck_csl_discount_pct CHECK (
        discount_percent >= 0 AND discount_percent <= 1
    ),
    CONSTRAINT ck_csl_vat_rate CHECK (vat_rate >= 0 AND vat_rate <= 1)
);

CREATE INDEX ix_cash_sale_lines_sale
    ON public.cash_sale_lines (cash_sale_id);

ALTER TABLE public.cash_sale_lines ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #71 receipts
-- AR collection — applied to sales_invoices via receipt_lines.
CREATE TABLE public.receipts (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.receipts(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- receipt-specific
    customer_id          uuid          NOT NULL REFERENCES public.customers(id),
    customer_name        text          NOT NULL,
    customer_tin         text          NULL,
    payment_method       text          NOT NULL,
    check_no             text          NULL,
    check_date           date          NULL,
    bank_account_id      uuid          NULL     REFERENCES public.company_bank_accounts(id),
    bank_deposit_date    date          NULL,
    atp_usage_id         uuid          NULL     REFERENCES public.atp_usage_logs(id),
    journal_entry_id     uuid          NULL,
    -- Immutable
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_receipts PRIMARY KEY (id),
    CONSTRAINT uq_receipts_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_receipts_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_receipts_payment_method CHECK (
        payment_method IN ('cash','check','bank_transfer','online')
    ),
    CONSTRAINT ck_receipts_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_receipts_check CHECK (
        payment_method <> 'check' OR (check_no IS NOT NULL AND check_date IS NOT NULL)
    )
);

CREATE INDEX ix_receipts_company_date
    ON public.receipts (company_id, document_date);

CREATE INDEX ix_receipts_customer
    ON public.receipts (company_id, customer_id);

CREATE INDEX ix_receipts_status
    ON public.receipts (company_id, status);

ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #72 receipt_lines
-- Application lines: each row applies a portion of the receipt to a document.
CREATE TABLE public.receipt_lines (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id           uuid          NOT NULL REFERENCES public.companies(id),
    receipt_id           uuid          NOT NULL REFERENCES public.receipts(id),
    line_no              integer       NOT NULL,
    applied_to_type      text          NOT NULL,
    -- polymorphic FK to sales_invoices, sales_debit_memos, or advance record
    applied_to_id        uuid          NULL,
    applied_amount       numeric(18,4) NOT NULL,
    -- 2307 amount withheld by customer; reduces net cash received
    ewt_amount_received  numeric(18,4) NOT NULL DEFAULT 0,
    ewt_atc_id           uuid          NULL     REFERENCES public.atc_codes(id),
    discount_taken       numeric(18,4) NOT NULL DEFAULT 0,
    -- Immutable
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_receipt_lines PRIMARY KEY (id),
    CONSTRAINT uq_rl_seq UNIQUE (receipt_id, line_no),
    CONSTRAINT ck_rl_applied_type CHECK (
        applied_to_type IN ('sales_invoice','sales_debit_memo','advance')
    ),
    CONSTRAINT ck_rl_applied_amount CHECK (applied_amount > 0),
    CONSTRAINT ck_rl_ewt CHECK (ewt_amount_received >= 0),
    CONSTRAINT ck_rl_discount CHECK (discount_taken >= 0)
);

CREATE INDEX ix_receipt_lines_receipt
    ON public.receipt_lines (receipt_id);

-- Applied-to lookup for AR aging and clearing
CREATE INDEX ix_receipt_lines_applied
    ON public.receipt_lines (company_id, applied_to_type, applied_to_id)
    WHERE applied_to_id IS NOT NULL;

ALTER TABLE public.receipt_lines ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #73 sales_credit_memos
-- Reduces AR balance. References original invoice for compliance traceability.
CREATE TABLE public.sales_credit_memos (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id           uuid          NOT NULL REFERENCES public.companies(id),
    branch_id            uuid          NULL     REFERENCES public.branches(id),
    department_id        uuid          NULL     REFERENCES public.departments(id),
    cost_center_id       uuid          NULL     REFERENCES public.cost_centers(id),
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.sales_credit_memos(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    customer_id          uuid          NOT NULL REFERENCES public.customers(id),
    original_invoice_id  uuid          NULL     REFERENCES public.sales_invoices(id),
    credit_reason        text          NULL,
    journal_entry_id     uuid          NULL,
    -- Immutable
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_sales_credit_memos PRIMARY KEY (id),
    CONSTRAINT uq_scm_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_scm_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_scm_exchange_rate CHECK (exchange_rate > 0)
);

CREATE INDEX ix_sales_credit_memos_company_date
    ON public.sales_credit_memos (company_id, document_date);

CREATE INDEX ix_sales_credit_memos_customer
    ON public.sales_credit_memos (company_id, customer_id);

CREATE INDEX ix_sales_credit_memos_status
    ON public.sales_credit_memos (company_id, status);

ALTER TABLE public.sales_credit_memos ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #74 sales_credit_memo_lines
CREATE TABLE public.sales_credit_memo_lines (
    id                    uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id            uuid          NOT NULL REFERENCES public.companies(id),
    sales_credit_memo_id  uuid          NOT NULL REFERENCES public.sales_credit_memos(id),
    line_no               integer       NOT NULL,
    item_id               uuid          NULL     REFERENCES public.items(id),
    service_id            uuid          NULL     REFERENCES public.services(id),
    description           text          NOT NULL,
    quantity              numeric(10,4) NOT NULL,
    unit_price            numeric(18,4) NOT NULL,
    vat_code_id           uuid          NULL     REFERENCES public.vat_codes(id),
    vat_direction         text          NOT NULL DEFAULT 'output',
    vat_classification    text          NOT NULL DEFAULT 'vatable',
    net_amount            numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount            numeric(18,4) NOT NULL DEFAULT 0,
    gross_amount          numeric(18,4) NOT NULL DEFAULT 0,
    -- Immutable
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_sales_credit_memo_lines PRIMARY KEY (id),
    CONSTRAINT uq_scml_seq UNIQUE (sales_credit_memo_id, line_no),
    CONSTRAINT ck_scml_direction CHECK (vat_direction = 'output'),
    CONSTRAINT ck_scml_classification CHECK (
        vat_classification IN ('vatable','zero_rated','exempt')
    ),
    CONSTRAINT ck_scml_qty CHECK (quantity > 0),
    CONSTRAINT ck_scml_price CHECK (unit_price >= 0)
);

CREATE INDEX ix_sales_credit_memo_lines_cm
    ON public.sales_credit_memo_lines (sales_credit_memo_id);

ALTER TABLE public.sales_credit_memo_lines ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #75 sales_debit_memos
-- Increases AR balance (additional charges to customer).
CREATE TABLE public.sales_debit_memos (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id           uuid          NOT NULL REFERENCES public.companies(id),
    branch_id            uuid          NULL     REFERENCES public.branches(id),
    department_id        uuid          NULL     REFERENCES public.departments(id),
    cost_center_id       uuid          NULL     REFERENCES public.cost_centers(id),
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.sales_debit_memos(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    customer_id          uuid          NOT NULL REFERENCES public.customers(id),
    original_invoice_id  uuid          NULL     REFERENCES public.sales_invoices(id),
    debit_reason         text          NULL,
    journal_entry_id     uuid          NULL,
    -- Immutable
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_sales_debit_memos PRIMARY KEY (id),
    CONSTRAINT uq_sdm_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_sdm_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_sdm_exchange_rate CHECK (exchange_rate > 0)
);

CREATE INDEX ix_sales_debit_memos_company_date
    ON public.sales_debit_memos (company_id, document_date);

CREATE INDEX ix_sales_debit_memos_customer
    ON public.sales_debit_memos (company_id, customer_id);

ALTER TABLE public.sales_debit_memos ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #76 sales_debit_memo_lines
CREATE TABLE public.sales_debit_memo_lines (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id           uuid          NOT NULL REFERENCES public.companies(id),
    sales_debit_memo_id  uuid          NOT NULL REFERENCES public.sales_debit_memos(id),
    line_no              integer       NOT NULL,
    item_id              uuid          NULL     REFERENCES public.items(id),
    service_id           uuid          NULL     REFERENCES public.services(id),
    description          text          NOT NULL,
    quantity             numeric(10,4) NOT NULL,
    unit_price           numeric(18,4) NOT NULL,
    vat_code_id          uuid          NULL     REFERENCES public.vat_codes(id),
    vat_direction        text          NOT NULL DEFAULT 'output',
    vat_classification   text          NOT NULL DEFAULT 'vatable',
    net_amount           numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount           numeric(18,4) NOT NULL DEFAULT 0,
    gross_amount         numeric(18,4) NOT NULL DEFAULT 0,
    -- Immutable
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_sales_debit_memo_lines PRIMARY KEY (id),
    CONSTRAINT uq_sdml_seq UNIQUE (sales_debit_memo_id, line_no),
    CONSTRAINT ck_sdml_direction CHECK (vat_direction = 'output'),
    CONSTRAINT ck_sdml_classification CHECK (
        vat_classification IN ('vatable','zero_rated','exempt')
    ),
    CONSTRAINT ck_sdml_qty CHECK (quantity > 0),
    CONSTRAINT ck_sdml_price CHECK (unit_price >= 0)
);

CREATE INDEX ix_sales_debit_memo_lines_dm
    ON public.sales_debit_memo_lines (sales_debit_memo_id);

ALTER TABLE public.sales_debit_memo_lines ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #77 customer_returns
-- Inventory reversal header for goods returned by customer.
-- Triggers inventory movement (IN) and reversal of COGS/revenue at posting.
CREATE TABLE public.customer_returns (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id           uuid          NOT NULL REFERENCES public.companies(id),
    branch_id            uuid          NULL     REFERENCES public.branches(id),
    department_id        uuid          NULL     REFERENCES public.departments(id),
    cost_center_id       uuid          NULL     REFERENCES public.cost_centers(id),
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.customer_returns(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    customer_id          uuid          NOT NULL REFERENCES public.customers(id),
    original_invoice_id  uuid          NULL     REFERENCES public.sales_invoices(id),
    return_reason        text          NULL,
    journal_entry_id     uuid          NULL,
    -- Immutable
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_customer_returns PRIMARY KEY (id),
    CONSTRAINT uq_cr_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_cr_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_cr_exchange_rate CHECK (exchange_rate > 0)
);

CREATE INDEX ix_customer_returns_company_date
    ON public.customer_returns (company_id, document_date);

CREATE INDEX ix_customer_returns_customer
    ON public.customer_returns (company_id, customer_id);

ALTER TABLE public.customer_returns ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- #78 customer_return_lines
-- unit_cost = FIFO cost at time of original sale; used for inventory reversal.
CREATE TABLE public.customer_return_lines (
    id                  uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid          NOT NULL REFERENCES public.companies(id),
    customer_return_id  uuid          NOT NULL REFERENCES public.customer_returns(id),
    line_no             integer       NOT NULL,
    item_id             uuid          NULL     REFERENCES public.items(id),
    description         text          NOT NULL,
    quantity            numeric(10,4) NOT NULL,
    -- FIFO cost snapshot from original sale; set by posting engine
    unit_cost           numeric(18,4) NOT NULL,
    -- return-to warehouse
    warehouse_id        uuid          NOT NULL REFERENCES public.warehouses(id),
    vat_direction       text          NOT NULL DEFAULT 'output',
    vat_classification  text          NOT NULL DEFAULT 'vatable',
    net_amount          numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount          numeric(18,4) NOT NULL DEFAULT 0,
    -- Immutable
    created_at  timestamptz NOT NULL DEFAULT now(),
    created_by  uuid        NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_customer_return_lines PRIMARY KEY (id),
    CONSTRAINT uq_crl_seq UNIQUE (customer_return_id, line_no),
    CONSTRAINT ck_crl_direction CHECK (vat_direction = 'output'),
    CONSTRAINT ck_crl_classification CHECK (
        vat_classification IN ('vatable','zero_rated','exempt')
    ),
    CONSTRAINT ck_crl_qty CHECK (quantity > 0),
    CONSTRAINT ck_crl_unit_cost CHECK (unit_cost >= 0)
);

CREATE INDEX ix_customer_return_lines_return
    ON public.customer_return_lines (customer_return_id);

ALTER TABLE public.customer_return_lines ENABLE ROW LEVEL SECURITY;
