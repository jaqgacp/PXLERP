-- =============================================================================
-- Migration 008: Purchasing — Module 11
-- =============================================================================
-- Tables created (16, in FK dependency order):
--
-- GROUP A — Purchase Cycle (Soft Delete=YES, Immutable=NO, full audit):
--   purchase_orders (#79), purchase_order_lines (#80)
--
-- GROUP B — Goods Receipt (Immutable=YES, Soft Delete=NO):
--   receiving_reports (#81), receiving_report_lines (#82)
--
-- GROUP C — AP Transactions (Immutable=YES, Soft Delete=NO):
--   vendor_bills (#83), vendor_bill_lines (#84)
--   cash_purchases (#85), cash_purchase_lines (#86)
--
-- GROUP D — AP Payments (Immutable=YES, Soft Delete=NO):
--   payment_vouchers (#87), payment_voucher_lines (#88)
--
-- GROUP E — Adjustments / Returns (Immutable=YES, Soft Delete=NO):
--   vendor_credits (#89), vendor_credit_lines (#90)
--   supplier_debit_memos (#91), supplier_debit_memo_lines (#92)
--   purchase_returns (#93), purchase_return_lines (#94)
--
-- Intentionally deferred:
--   journal_entry_id FK  → journal_entries  (Migration 016)
--   import_batch_id  FK  → import_batches   (Migration 023)
--   Columns present on all applicable headers; FK constraints added later.
--
-- Not included in this migration:
--   inventory_balances, inventory_cost_layers — ledger tables, separate migration
--   RLS policies — Migration 017
--   Triggers / functions — dedicated trigger migration
--   Petty Cash (Module 12) — separate migration
--
-- FK dependency order:
--   Group A: purchase_orders (no cross-module deps)
--          → purchase_order_lines (refs purchase_orders)
--   Group B: receiving_reports (refs purchase_orders, suppliers)
--          → receiving_report_lines (refs receiving_reports, purchase_order_lines,
--              items, warehouses)
--   Group C: vendor_bills (refs purchase_orders, receiving_reports, suppliers,
--              payment_terms)
--          → vendor_bill_lines (refs vendor_bills, items, services, vat_codes,
--              atc_codes, chart_of_accounts, warehouses)
--          → cash_purchases (refs suppliers, company_bank_accounts)
--          → cash_purchase_lines (refs cash_purchases, items, services, vat_codes,
--              atc_codes, chart_of_accounts, warehouses)
--   Group D: payment_vouchers (refs suppliers, company_bank_accounts)
--          → payment_voucher_lines (refs payment_vouchers, atc_codes;
--              applied_to_id is polymorphic — no DB FK)
--   Group E: vendor_credits (refs vendor_bills, suppliers)
--          → vendor_credit_lines (refs vendor_credits, items, vat_codes)
--          → supplier_debit_memos (refs vendor_bills, suppliers)
--          → supplier_debit_memo_lines (refs supplier_debit_memos)
--          → purchase_returns (refs receiving_reports, suppliers)
--          → purchase_return_lines (refs purchase_returns, items, warehouses)
--
-- Posting dependencies:
--   journal_entry_id (uuid NULL) set by posting engine at post time.
--   vendor_bill_lines.expense_account_id set by posting engine or user mapping.
--   vat_classification = 'capital_goods' triggers 60-month input VAT amortization
--   (BIR RMC, amounts > PHP 1M). Posting engine reads vat_classification.
--
-- Compliance dependencies:
--   Supplier snapshots (supplier_name, supplier_tin, supplier_address) on
--   vendor_bills, cash_purchases, payment_vouchers: required for RELIEF, SLSP
--   (purchase side), SAWT, and 2307 generation without joining live supplier record.
--   ewt_atc_id + ewt_amount on vendor_bill_lines and cash_purchase_lines: source
--   data for BIR Form 1601EQ and quarterly alphalist of payees (QAP / Form 1604E).
--   payment_voucher_lines.ewt_amount: actual EWT withheld at payment time for 2307.
--   atp_usage_id: NOT applicable to purchasing (ATP series is for selling documents).
--
-- Immutable table pattern (Groups B–E):
--   Only created_at, created_by from standard audit.
--   No updated_* columns. No deleted_* columns.
--   State changes tracked via standard transaction header columns (posted_at,
--   posted_by, voided_at, voided_by, void_reason, reversed_by_doc_id).
--
-- vat_direction on all purchasing lines = 'input' (enforced by CHECK).
-- vat_classification CHECK IN ('vatable','zero_rated','exempt','capital_goods','services')
--   on most purchasing lines. supplier_debit_memo_lines limited to the subset
--   ('vatable','zero_rated','exempt') per Doc03 §33.
-- =============================================================================

-- =============================================================================
-- GROUP A: Purchase Cycle — Soft Delete=YES, Immutable=NO
-- =============================================================================

-- #79 purchase_orders
-- Purchase order header. Mutable until goods are fully received or cancelled.
CREATE TABLE public.purchase_orders (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.purchase_orders(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    -- import_batch_id FK deferred to Migration 023
    import_batch_id      uuid          NULL,
    -- purchase_orders-specific
    supplier_id          uuid          NOT NULL REFERENCES public.suppliers(id),
    delivery_date        date          NULL,
    delivery_address     text          NULL,
    -- standard audit (Soft Delete=YES, Immutable=NO)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at           timestamptz   NULL,
    updated_by           uuid          NULL     REFERENCES public.profiles(id),
    deleted_at           timestamptz   NULL,
    deleted_by           uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_purchase_orders PRIMARY KEY (id),
    CONSTRAINT uq_purchase_orders_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_purchase_orders_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_purchase_orders_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_purchase_orders_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    )
);

CREATE INDEX ix_purchase_orders_company_date
    ON public.purchase_orders (company_id, document_date)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_purchase_orders_supplier
    ON public.purchase_orders (supplier_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_purchase_orders_status
    ON public.purchase_orders (company_id, status)
    WHERE deleted_at IS NULL;

ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #80 purchase_order_lines
-- Line items for a purchase order. One row per item/service ordered.
-- received_qty and billed_qty are updated by the posting engine when
-- receiving reports and vendor bills are posted against this PO.
CREATE TABLE public.purchase_order_lines (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id           uuid          NOT NULL REFERENCES public.companies(id),
    purchase_order_id    uuid          NOT NULL REFERENCES public.purchase_orders(id),
    line_no              integer       NOT NULL,
    item_id              uuid          NULL     REFERENCES public.items(id),
    service_id           uuid          NULL     REFERENCES public.services(id),
    description          text          NOT NULL,
    quantity             numeric(10,4) NOT NULL,
    unit_price           numeric(18,4) NOT NULL,
    -- received_qty / billed_qty updated by posting engine (service role)
    received_qty         numeric(10,4) NOT NULL DEFAULT 0,
    billed_qty           numeric(10,4) NOT NULL DEFAULT 0,
    vat_code_id          uuid          NULL     REFERENCES public.vat_codes(id),
    vat_direction        text          NOT NULL DEFAULT 'input',
    vat_classification   text          NOT NULL,
    net_amount           numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount           numeric(18,4) NOT NULL DEFAULT 0,
    gross_amount         numeric(18,4) NOT NULL DEFAULT 0,
    -- standard audit (Soft Delete=YES, Immutable=NO)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),
    updated_at           timestamptz   NULL,
    updated_by           uuid          NULL     REFERENCES public.profiles(id),
    deleted_at           timestamptz   NULL,
    deleted_by           uuid          NULL     REFERENCES public.profiles(id),

    CONSTRAINT pk_purchase_order_lines PRIMARY KEY (id),
    CONSTRAINT ck_pol_line_no CHECK (line_no > 0),
    CONSTRAINT ck_pol_item_or_service CHECK (
        item_id IS NOT NULL OR service_id IS NOT NULL
    ),
    CONSTRAINT ck_pol_quantity CHECK (quantity > 0),
    CONSTRAINT ck_pol_unit_price CHECK (unit_price >= 0),
    CONSTRAINT ck_pol_received_qty CHECK (received_qty >= 0),
    CONSTRAINT ck_pol_billed_qty CHECK (billed_qty >= 0),
    CONSTRAINT ck_pol_direction CHECK (vat_direction = 'input'),
    CONSTRAINT ck_pol_classification CHECK (
        vat_classification IN ('vatable','zero_rated','exempt','capital_goods','services')
    ),
    CONSTRAINT ck_pol_amounts CHECK (
        net_amount >= 0 AND vat_amount >= 0 AND gross_amount >= 0
    )
);

CREATE INDEX ix_purchase_order_lines_po
    ON public.purchase_order_lines (purchase_order_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_purchase_order_lines_item
    ON public.purchase_order_lines (item_id)
    WHERE item_id IS NOT NULL AND deleted_at IS NULL;

ALTER TABLE public.purchase_order_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP B: Goods Receipt — Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #81 receiving_reports
-- Goods receipt header. Created when supplier delivers goods.
-- Immutable once posted — triggers inventory IN and updates PO received_qty.
CREATE TABLE public.receiving_reports (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.receiving_reports(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- receiving_reports-specific
    supplier_id          uuid          NOT NULL REFERENCES public.suppliers(id),
    purchase_order_id    uuid          NULL     REFERENCES public.purchase_orders(id),
    received_by          text          NULL,
    -- standard audit (Immutable=YES — created_at/created_by only)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_receiving_reports PRIMARY KEY (id),
    CONSTRAINT uq_receiving_reports_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_rr_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_rr_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_rr_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    )
);

CREATE INDEX ix_receiving_reports_company_date
    ON public.receiving_reports (company_id, document_date);

CREATE INDEX ix_receiving_reports_supplier
    ON public.receiving_reports (supplier_id);

CREATE INDEX ix_receiving_reports_po
    ON public.receiving_reports (purchase_order_id)
    WHERE purchase_order_id IS NOT NULL;

CREATE INDEX ix_receiving_reports_status
    ON public.receiving_reports (company_id, status);

ALTER TABLE public.receiving_reports ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #82 receiving_report_lines
-- Line items for a receiving report. Records what was actually received.
CREATE TABLE public.receiving_report_lines (
    id                      uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid          NOT NULL REFERENCES public.companies(id),
    receiving_report_id     uuid          NOT NULL REFERENCES public.receiving_reports(id),
    line_no                 integer       NOT NULL,
    item_id                 uuid          NOT NULL REFERENCES public.items(id),
    purchase_order_line_id  uuid          NULL     REFERENCES public.purchase_order_lines(id),
    description             text          NOT NULL,
    quantity_ordered        numeric(10,4) NOT NULL,
    quantity_received       numeric(10,4) NOT NULL,
    unit_cost               numeric(18,4) NOT NULL,
    warehouse_id            uuid          NOT NULL REFERENCES public.warehouses(id),
    -- standard audit (Immutable=YES)
    created_at              timestamptz   NOT NULL DEFAULT now(),
    created_by              uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_receiving_report_lines PRIMARY KEY (id),
    CONSTRAINT ck_rrl_line_no CHECK (line_no > 0),
    CONSTRAINT ck_rrl_qty_ordered CHECK (quantity_ordered >= 0),
    CONSTRAINT ck_rrl_qty_received CHECK (quantity_received >= 0),
    CONSTRAINT ck_rrl_unit_cost CHECK (unit_cost >= 0)
);

CREATE INDEX ix_receiving_report_lines_rr
    ON public.receiving_report_lines (receiving_report_id);

CREATE INDEX ix_receiving_report_lines_item
    ON public.receiving_report_lines (item_id);

CREATE INDEX ix_receiving_report_lines_warehouse
    ON public.receiving_report_lines (warehouse_id);

ALTER TABLE public.receiving_report_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP C: AP Transactions — Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #83 vendor_bills
-- Vendor bill / purchase invoice header. Creates AP liability on posting.
-- Supplier snapshots (supplier_name, supplier_tin, supplier_address) stored at
-- creation time for RELIEF, SLSP (purchase side), SAWT, and 2307 without
-- joining live supplier record.
CREATE TABLE public.vendor_bills (
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
    reversed_by_doc_id    uuid          NULL     REFERENCES public.vendor_bills(id),
    source_document_id    uuid          NULL,
    source_document_type  text          NULL,
    -- import_batch_id FK deferred to Migration 023
    import_batch_id       uuid          NULL,
    -- vendor_bills-specific
    supplier_id           uuid          NOT NULL REFERENCES public.suppliers(id),
    -- compliance snapshots for RELIEF / SLSP / SAWT / 2307
    supplier_name         text          NOT NULL,
    supplier_tin          text          NULL,
    supplier_address      text          NULL,
    supplier_invoice_no   text          NULL,
    supplier_invoice_date date          NULL,
    receiving_report_id   uuid          NULL     REFERENCES public.receiving_reports(id),
    purchase_order_id     uuid          NULL     REFERENCES public.purchase_orders(id),
    due_date              date          NULL,
    payment_terms_id      uuid          NULL     REFERENCES public.payment_terms(id),
    is_vat_inclusive      boolean       NOT NULL DEFAULT false,
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id      uuid          NULL,
    -- standard audit (Immutable=YES)
    created_at            timestamptz   NOT NULL DEFAULT now(),
    created_by            uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_vendor_bills PRIMARY KEY (id),
    CONSTRAINT uq_vendor_bills_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_vb_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_vb_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_vb_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    )
);

COMMENT ON COLUMN public.vendor_bills.supplier_name
    IS 'Snapshot of supplier name at bill creation time. Used for RELIEF, SLSP, SAWT, and 2307 without joining live suppliers record.';
COMMENT ON COLUMN public.vendor_bills.supplier_tin
    IS 'Snapshot of supplier TIN. Required for RELIEF and 2307 reporting.';
COMMENT ON COLUMN public.vendor_bills.journal_entry_id
    IS 'FK to journal_entries deferred to Migration 016. Column present; constraint added when journal_entries table is created.';

CREATE INDEX ix_vendor_bills_company_date
    ON public.vendor_bills (company_id, document_date);

CREATE INDEX ix_vendor_bills_supplier
    ON public.vendor_bills (supplier_id);

CREATE INDEX ix_vendor_bills_status
    ON public.vendor_bills (company_id, status);

CREATE INDEX ix_vendor_bills_due_date
    ON public.vendor_bills (company_id, due_date)
    WHERE due_date IS NOT NULL AND status = 'posted';

ALTER TABLE public.vendor_bills ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #84 vendor_bill_lines
-- Line items for a vendor bill.
-- vat_classification = 'capital_goods' triggers 60-month input VAT amortization
-- (BIR rule: amounts > PHP 1M). Posting engine reads this column to route to
-- INPUT_VAT vs INPUT_VAT_CAPITAL_GOODS vs INPUT_VAT_DEFERRED GL accounts.
-- ewt_atc_id / ewt_amount: source data for 1601EQ and QAP (Form 1604E).
CREATE TABLE public.vendor_bill_lines (
    id                  uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid          NOT NULL REFERENCES public.companies(id),
    vendor_bill_id      uuid          NOT NULL REFERENCES public.vendor_bills(id),
    line_no             integer       NOT NULL,
    item_id             uuid          NULL     REFERENCES public.items(id),
    service_id          uuid          NULL     REFERENCES public.services(id),
    description         text          NOT NULL,
    quantity            numeric(18,4) NOT NULL,
    uom_id              uuid          NOT NULL REFERENCES public.units_of_measure(id),
    unit_cost           numeric(18,4) NOT NULL,
    net_amount          numeric(18,4) NOT NULL,
    input_vat_code_id   uuid          NULL     REFERENCES public.vat_codes(id),
    vat_direction       text          NOT NULL DEFAULT 'input',
    vat_classification  text          NOT NULL DEFAULT 'vatable',
    -- snapshot of rate at bill entry time (not derived at report time)
    input_vat_rate      numeric(10,6) NOT NULL DEFAULT 0,
    input_vat_amount    numeric(18,4) NOT NULL DEFAULT 0,
    total_amount        numeric(18,4) NOT NULL,
    ewt_atc_id          uuid          NULL     REFERENCES public.atc_codes(id),
    ewt_rate            numeric(10,6) NOT NULL DEFAULT 0,
    ewt_amount          numeric(18,4) NOT NULL DEFAULT 0,
    expense_account_id  uuid          NULL     REFERENCES public.chart_of_accounts(id),
    warehouse_id        uuid          NULL     REFERENCES public.warehouses(id),
    -- standard audit (Immutable=YES)
    created_at          timestamptz   NOT NULL DEFAULT now(),
    created_by          uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_vendor_bill_lines PRIMARY KEY (id),
    CONSTRAINT ck_vbl_line_no CHECK (line_no > 0),
    CONSTRAINT ck_vbl_quantity CHECK (quantity > 0),
    CONSTRAINT ck_vbl_unit_cost CHECK (unit_cost >= 0),
    CONSTRAINT ck_vbl_direction CHECK (vat_direction = 'input'),
    CONSTRAINT ck_vbl_classification CHECK (
        vat_classification IN ('vatable','zero_rated','exempt','capital_goods','services')
    ),
    CONSTRAINT ck_vbl_vat_rate CHECK (input_vat_rate >= 0 AND input_vat_rate <= 1),
    CONSTRAINT ck_vbl_ewt_rate CHECK (ewt_rate >= 0 AND ewt_rate <= 1),
    CONSTRAINT ck_vbl_amounts CHECK (
        net_amount >= 0 AND input_vat_amount >= 0 AND ewt_amount >= 0 AND total_amount >= 0
    )
);

COMMENT ON COLUMN public.vendor_bill_lines.vat_classification
    IS 'capital_goods: triggers 60-month input VAT amortization (BIR rule, amounts > PHP 1M). services: distinct RELIEF reporting treatment. Posting engine routes to INPUT_VAT, INPUT_VAT_CAPITAL_GOODS, or INPUT_VAT_DEFERRED based on this value.';

CREATE INDEX ix_vendor_bill_lines_bill
    ON public.vendor_bill_lines (vendor_bill_id);

CREATE INDEX ix_vendor_bill_lines_item
    ON public.vendor_bill_lines (item_id)
    WHERE item_id IS NOT NULL;

CREATE INDEX ix_vendor_bill_lines_ewt
    ON public.vendor_bill_lines (ewt_atc_id)
    WHERE ewt_atc_id IS NOT NULL;

ALTER TABLE public.vendor_bill_lines ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #85 cash_purchases
-- Cash purchase header — immediate payment, no AP created.
-- supplier_id is nullable to allow one-time / unnamed vendors.
-- Supplier snapshot (supplier_name, supplier_tin) for RELIEF compliance.
CREATE TABLE public.cash_purchases (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.cash_purchases(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- cash_purchases-specific
    supplier_id          uuid          NULL     REFERENCES public.suppliers(id),
    supplier_name        text          NOT NULL,
    supplier_tin         text          NULL,
    payment_method       text          NOT NULL,
    check_no             text          NULL,
    check_date           date          NULL,
    bank_account_id      uuid          NULL     REFERENCES public.company_bank_accounts(id),
    is_vat_inclusive     boolean       NOT NULL DEFAULT false,
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id     uuid          NULL,
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_cash_purchases PRIMARY KEY (id),
    CONSTRAINT uq_cash_purchases_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_cp_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_cp_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_cp_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    ),
    CONSTRAINT ck_cp_payment_method CHECK (
        payment_method IN ('cash','check','bank_transfer','online')
    ),
    CONSTRAINT ck_cp_check_data CHECK (
        payment_method != 'check' OR (check_no IS NOT NULL AND check_date IS NOT NULL)
    )
);

COMMENT ON COLUMN public.cash_purchases.supplier_name
    IS 'Snapshot of supplier name (or one-time vendor name) at entry time. Required for RELIEF reporting.';
COMMENT ON COLUMN public.cash_purchases.journal_entry_id
    IS 'FK to journal_entries deferred to Migration 016.';

CREATE INDEX ix_cash_purchases_company_date
    ON public.cash_purchases (company_id, document_date);

CREATE INDEX ix_cash_purchases_supplier
    ON public.cash_purchases (supplier_id)
    WHERE supplier_id IS NOT NULL;

CREATE INDEX ix_cash_purchases_status
    ON public.cash_purchases (company_id, status);

ALTER TABLE public.cash_purchases ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #86 cash_purchase_lines
-- Line items for a cash purchase. Same input VAT and EWT columns as vendor_bill_lines.
CREATE TABLE public.cash_purchase_lines (
    id                  uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid          NOT NULL REFERENCES public.companies(id),
    cash_purchase_id    uuid          NOT NULL REFERENCES public.cash_purchases(id),
    line_no             integer       NOT NULL,
    item_id             uuid          NULL     REFERENCES public.items(id),
    service_id          uuid          NULL     REFERENCES public.services(id),
    description         text          NOT NULL,
    quantity            numeric(18,4) NOT NULL,
    uom_id              uuid          NOT NULL REFERENCES public.units_of_measure(id),
    unit_cost           numeric(18,4) NOT NULL,
    net_amount          numeric(18,4) NOT NULL,
    input_vat_code_id   uuid          NULL     REFERENCES public.vat_codes(id),
    vat_direction       text          NOT NULL DEFAULT 'input',
    vat_classification  text          NOT NULL DEFAULT 'vatable',
    input_vat_rate      numeric(10,6) NOT NULL DEFAULT 0,
    input_vat_amount    numeric(18,4) NOT NULL DEFAULT 0,
    total_amount        numeric(18,4) NOT NULL,
    ewt_atc_id          uuid          NULL     REFERENCES public.atc_codes(id),
    ewt_rate            numeric(10,6) NOT NULL DEFAULT 0,
    ewt_amount          numeric(18,4) NOT NULL DEFAULT 0,
    expense_account_id  uuid          NULL     REFERENCES public.chart_of_accounts(id),
    warehouse_id        uuid          NULL     REFERENCES public.warehouses(id),
    -- standard audit (Immutable=YES)
    created_at          timestamptz   NOT NULL DEFAULT now(),
    created_by          uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_cash_purchase_lines PRIMARY KEY (id),
    CONSTRAINT ck_cpl_line_no CHECK (line_no > 0),
    CONSTRAINT ck_cpl_quantity CHECK (quantity > 0),
    CONSTRAINT ck_cpl_unit_cost CHECK (unit_cost >= 0),
    CONSTRAINT ck_cpl_direction CHECK (vat_direction = 'input'),
    CONSTRAINT ck_cpl_classification CHECK (
        vat_classification IN ('vatable','zero_rated','exempt','capital_goods','services')
    ),
    CONSTRAINT ck_cpl_vat_rate CHECK (input_vat_rate >= 0 AND input_vat_rate <= 1),
    CONSTRAINT ck_cpl_ewt_rate CHECK (ewt_rate >= 0 AND ewt_rate <= 1),
    CONSTRAINT ck_cpl_amounts CHECK (
        net_amount >= 0 AND input_vat_amount >= 0 AND ewt_amount >= 0 AND total_amount >= 0
    )
);

CREATE INDEX ix_cash_purchase_lines_cp
    ON public.cash_purchase_lines (cash_purchase_id);

CREATE INDEX ix_cash_purchase_lines_item
    ON public.cash_purchase_lines (item_id)
    WHERE item_id IS NOT NULL;

CREATE INDEX ix_cash_purchase_lines_ewt
    ON public.cash_purchase_lines (ewt_atc_id)
    WHERE ewt_atc_id IS NOT NULL;

ALTER TABLE public.cash_purchase_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP D: AP Payments — Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #87 payment_vouchers
-- Payment voucher header — AP payment disbursement.
-- Supplier snapshot required for 2307 and SAWT compliance.
-- gross_amount / total_ewt_amount / net_of_ewt_amount provide the payment
-- summary used by the posting engine to debit AP and credit Cash/Bank.
CREATE TABLE public.payment_vouchers (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.payment_vouchers(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- payment_vouchers-specific
    supplier_id          uuid          NOT NULL REFERENCES public.suppliers(id),
    supplier_name        text          NOT NULL,
    supplier_tin         text          NULL,
    payment_method       text          NOT NULL,
    check_no             text          NULL,
    check_date           date          NULL,
    bank_account_id      uuid          NULL     REFERENCES public.company_bank_accounts(id),
    -- payment totals (AP clearing amounts)
    gross_amount         numeric(18,4) NOT NULL DEFAULT 0,
    total_ewt_amount     numeric(18,4) NOT NULL DEFAULT 0,
    net_of_ewt_amount    numeric(18,4) NOT NULL DEFAULT 0,
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id     uuid          NULL,
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_payment_vouchers PRIMARY KEY (id),
    CONSTRAINT uq_payment_vouchers_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_pv_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_pv_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_pv_payment_method CHECK (
        payment_method IN ('cash','check','bank_transfer','online')
    ),
    CONSTRAINT ck_pv_check_data CHECK (
        payment_method != 'check' OR (check_no IS NOT NULL AND check_date IS NOT NULL)
    ),
    CONSTRAINT ck_pv_amounts CHECK (
        gross_amount >= 0 AND total_ewt_amount >= 0 AND net_of_ewt_amount >= 0
    )
);

COMMENT ON COLUMN public.payment_vouchers.supplier_name
    IS 'Snapshot at voucher creation time. Required for 2307 and SAWT generation.';
COMMENT ON COLUMN public.payment_vouchers.total_ewt_amount
    IS 'Sum of ewt_amount across all payment_voucher_lines. Represents EWT withheld for this payment.';
COMMENT ON COLUMN public.payment_vouchers.net_of_ewt_amount
    IS 'Actual cash disbursed: gross_amount - total_ewt_amount.';
COMMENT ON COLUMN public.payment_vouchers.journal_entry_id
    IS 'FK to journal_entries deferred to Migration 016.';

CREATE INDEX ix_payment_vouchers_company_date
    ON public.payment_vouchers (company_id, document_date);

CREATE INDEX ix_payment_vouchers_supplier
    ON public.payment_vouchers (supplier_id);

CREATE INDEX ix_payment_vouchers_status
    ON public.payment_vouchers (company_id, status);

ALTER TABLE public.payment_vouchers ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #88 payment_voucher_lines
-- Payment application lines — which bills/memos this voucher is paying.
-- applied_to_id is polymorphic (vendor_bill, supplier_debit_memo, or advance);
-- no DB-level FK constraint (polymorphic reference).
-- ewt_amount withheld this line feeds 2307 generation.
CREATE TABLE public.payment_voucher_lines (
    id                  uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid          NOT NULL REFERENCES public.companies(id),
    payment_voucher_id  uuid          NOT NULL REFERENCES public.payment_vouchers(id),
    line_no             integer       NOT NULL,
    -- polymorphic: 'vendor_bill' | 'supplier_debit_memo' | 'advance'
    applied_to_type     text          NOT NULL,
    -- no FK — polymorphic reference; application resolves based on applied_to_type
    applied_to_id       uuid          NULL,
    gross_amount        numeric(18,4) NOT NULL,
    ewt_amount          numeric(18,4) NOT NULL DEFAULT 0,
    ewt_atc_id          uuid          NULL     REFERENCES public.atc_codes(id),
    net_amount          numeric(18,4) NOT NULL,
    discount_taken      numeric(18,4) NOT NULL DEFAULT 0,
    -- standard audit (Immutable=YES)
    created_at          timestamptz   NOT NULL DEFAULT now(),
    created_by          uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_payment_voucher_lines PRIMARY KEY (id),
    CONSTRAINT ck_pvl_line_no CHECK (line_no > 0),
    CONSTRAINT ck_pvl_applied_to_type CHECK (
        applied_to_type IN ('vendor_bill','supplier_debit_memo','advance')
    ),
    CONSTRAINT ck_pvl_amounts CHECK (
        gross_amount >= 0 AND ewt_amount >= 0 AND net_amount >= 0 AND discount_taken >= 0
    )
);

COMMENT ON COLUMN public.payment_voucher_lines.applied_to_id
    IS 'Polymorphic FK — references vendor_bills.id, supplier_debit_memos.id, or an advance record depending on applied_to_type. No DB-level FK constraint; application resolves the target table.';

CREATE INDEX ix_payment_voucher_lines_pv
    ON public.payment_voucher_lines (payment_voucher_id);

CREATE INDEX ix_payment_voucher_lines_applied
    ON public.payment_voucher_lines (applied_to_type, applied_to_id)
    WHERE applied_to_id IS NOT NULL;

ALTER TABLE public.payment_voucher_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP E: Adjustments and Returns — Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #89 vendor_credits
-- Vendor credit note header — supplier issues credit to the company (e.g.,
-- for returned goods or overbilling). Reduces AP balance on posting.
CREATE TABLE public.vendor_credits (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.vendor_credits(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- vendor_credits-specific
    supplier_id          uuid          NOT NULL REFERENCES public.suppliers(id),
    original_bill_id     uuid          NULL     REFERENCES public.vendor_bills(id),
    credit_reason        text          NULL,
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id     uuid          NULL,
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_vendor_credits PRIMARY KEY (id),
    CONSTRAINT uq_vendor_credits_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_vc_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_vc_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_vc_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    )
);

CREATE INDEX ix_vendor_credits_company_date
    ON public.vendor_credits (company_id, document_date);

CREATE INDEX ix_vendor_credits_supplier
    ON public.vendor_credits (supplier_id);

CREATE INDEX ix_vendor_credits_original_bill
    ON public.vendor_credits (original_bill_id)
    WHERE original_bill_id IS NOT NULL;

ALTER TABLE public.vendor_credits ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #90 vendor_credit_lines
CREATE TABLE public.vendor_credit_lines (
    id                 uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id         uuid          NOT NULL REFERENCES public.companies(id),
    vendor_credit_id   uuid          NOT NULL REFERENCES public.vendor_credits(id),
    line_no            integer       NOT NULL,
    item_id            uuid          NULL     REFERENCES public.items(id),
    description        text          NOT NULL,
    quantity           numeric(10,4) NULL,
    unit_price         numeric(18,4) NOT NULL,
    vat_direction      text          NOT NULL DEFAULT 'input',
    vat_classification text          NOT NULL DEFAULT 'vatable',
    net_amount         numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount         numeric(18,4) NOT NULL DEFAULT 0,
    -- standard audit (Immutable=YES)
    created_at         timestamptz   NOT NULL DEFAULT now(),
    created_by         uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_vendor_credit_lines PRIMARY KEY (id),
    CONSTRAINT ck_vcl_line_no CHECK (line_no > 0),
    CONSTRAINT ck_vcl_unit_price CHECK (unit_price >= 0),
    CONSTRAINT ck_vcl_direction CHECK (vat_direction = 'input'),
    CONSTRAINT ck_vcl_classification CHECK (
        vat_classification IN ('vatable','zero_rated','exempt','capital_goods','services')
    ),
    CONSTRAINT ck_vcl_amounts CHECK (net_amount >= 0 AND vat_amount >= 0)
);

CREATE INDEX ix_vendor_credit_lines_vc
    ON public.vendor_credit_lines (vendor_credit_id);

ALTER TABLE public.vendor_credit_lines ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #91 supplier_debit_memos
-- Debit memo issued BY the company TO the supplier (e.g., for price disputes,
-- short deliveries, quality deductions). Reduces AP balance on posting.
CREATE TABLE public.supplier_debit_memos (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.supplier_debit_memos(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- supplier_debit_memos-specific
    supplier_id          uuid          NOT NULL REFERENCES public.suppliers(id),
    original_bill_id     uuid          NULL     REFERENCES public.vendor_bills(id),
    debit_reason         text          NULL,
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id     uuid          NULL,
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_supplier_debit_memos PRIMARY KEY (id),
    CONSTRAINT uq_supplier_debit_memos_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_sdm_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_sdm_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_sdm_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    )
);

CREATE INDEX ix_supplier_debit_memos_company_date
    ON public.supplier_debit_memos (company_id, document_date);

CREATE INDEX ix_supplier_debit_memos_supplier
    ON public.supplier_debit_memos (supplier_id);

CREATE INDEX ix_supplier_debit_memos_original_bill
    ON public.supplier_debit_memos (original_bill_id)
    WHERE original_bill_id IS NOT NULL;

ALTER TABLE public.supplier_debit_memos ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #92 supplier_debit_memo_lines
-- Doc03 §33: vat_classification limited to ('vatable','zero_rated','exempt') —
-- no capital_goods or services on debit memo lines per Doc03 specification.
CREATE TABLE public.supplier_debit_memo_lines (
    id                      uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id              uuid          NOT NULL REFERENCES public.companies(id),
    supplier_debit_memo_id  uuid          NOT NULL REFERENCES public.supplier_debit_memos(id),
    line_no                 integer       NOT NULL,
    description             text          NOT NULL,
    amount                  numeric(18,4) NOT NULL,
    vat_direction           text          NOT NULL DEFAULT 'input',
    vat_classification      text          NOT NULL DEFAULT 'vatable',
    net_amount              numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount              numeric(18,4) NOT NULL DEFAULT 0,
    -- standard audit (Immutable=YES)
    created_at              timestamptz   NOT NULL DEFAULT now(),
    created_by              uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_supplier_debit_memo_lines PRIMARY KEY (id),
    CONSTRAINT ck_sdml_line_no CHECK (line_no > 0),
    CONSTRAINT ck_sdml_amount CHECK (amount >= 0),
    CONSTRAINT ck_sdml_direction CHECK (vat_direction = 'input'),
    -- Doc03 §33: limited subset (no capital_goods, no services on debit memo lines)
    CONSTRAINT ck_sdml_classification CHECK (
        vat_classification IN ('vatable','zero_rated','exempt')
    ),
    CONSTRAINT ck_sdml_amounts CHECK (net_amount >= 0 AND vat_amount >= 0)
);

CREATE INDEX ix_supplier_debit_memo_lines_sdm
    ON public.supplier_debit_memo_lines (supplier_debit_memo_id);

ALTER TABLE public.supplier_debit_memo_lines ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #93 purchase_returns
-- Purchase return header — goods returned to supplier.
-- Triggers inventory OUT and input VAT reversal on posting.
CREATE TABLE public.purchase_returns (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.purchase_returns(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- purchase_returns-specific
    supplier_id          uuid          NOT NULL REFERENCES public.suppliers(id),
    original_rr_id       uuid          NULL     REFERENCES public.receiving_reports(id),
    return_reason        text          NULL,
    -- journal_entry_id FK deferred to Migration 016
    journal_entry_id     uuid          NULL,
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_purchase_returns PRIMARY KEY (id),
    CONSTRAINT uq_purchase_returns_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_pr_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_pr_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_pr_amounts CHECK (
        subtotal_amount >= 0 AND vat_amount >= 0 AND total_amount >= 0
    )
);

COMMENT ON TABLE public.purchase_returns
    IS 'Purchase return header. Posting triggers inventory OUT (reduces stock at original unit cost) and reverses the corresponding input VAT entries.';

CREATE INDEX ix_purchase_returns_company_date
    ON public.purchase_returns (company_id, document_date);

CREATE INDEX ix_purchase_returns_supplier
    ON public.purchase_returns (supplier_id);

CREATE INDEX ix_purchase_returns_original_rr
    ON public.purchase_returns (original_rr_id)
    WHERE original_rr_id IS NOT NULL;

ALTER TABLE public.purchase_returns ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #94 purchase_return_lines
-- unit_cost is the FIFO cost snapshot from the original receiving report;
-- used by the posting engine to correctly reverse inventory value.
CREATE TABLE public.purchase_return_lines (
    id                  uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid          NOT NULL REFERENCES public.companies(id),
    purchase_return_id  uuid          NOT NULL REFERENCES public.purchase_returns(id),
    line_no             integer       NOT NULL,
    item_id             uuid          NOT NULL REFERENCES public.items(id),
    quantity            numeric(10,4) NOT NULL,
    -- snapshot of the cost at which inventory was received (for reversal accuracy)
    unit_cost           numeric(18,4) NOT NULL,
    warehouse_id        uuid          NOT NULL REFERENCES public.warehouses(id),
    vat_direction       text          NOT NULL DEFAULT 'input',
    vat_classification  text          NOT NULL DEFAULT 'vatable',
    net_amount          numeric(18,4) NOT NULL DEFAULT 0,
    vat_amount          numeric(18,4) NOT NULL DEFAULT 0,
    -- standard audit (Immutable=YES)
    created_at          timestamptz   NOT NULL DEFAULT now(),
    created_by          uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_purchase_return_lines PRIMARY KEY (id),
    CONSTRAINT ck_prl_line_no CHECK (line_no > 0),
    CONSTRAINT ck_prl_quantity CHECK (quantity > 0),
    CONSTRAINT ck_prl_unit_cost CHECK (unit_cost >= 0),
    CONSTRAINT ck_prl_direction CHECK (vat_direction = 'input'),
    CONSTRAINT ck_prl_classification CHECK (
        vat_classification IN ('vatable','zero_rated','exempt','capital_goods','services')
    ),
    CONSTRAINT ck_prl_amounts CHECK (net_amount >= 0 AND vat_amount >= 0)
);

COMMENT ON COLUMN public.purchase_return_lines.unit_cost
    IS 'FIFO cost snapshot from the original receiving_report_lines.unit_cost. Used by posting engine to reverse inventory at correct cost.';

CREATE INDEX ix_purchase_return_lines_pr
    ON public.purchase_return_lines (purchase_return_id);

CREATE INDEX ix_purchase_return_lines_item
    ON public.purchase_return_lines (item_id);

CREATE INDEX ix_purchase_return_lines_warehouse
    ON public.purchase_return_lines (warehouse_id);

ALTER TABLE public.purchase_return_lines ENABLE ROW LEVEL SECURITY;
