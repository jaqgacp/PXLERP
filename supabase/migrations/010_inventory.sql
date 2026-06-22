-- =============================================================================
-- Migration 010: Inventory — Modules 6 (deferred) + 14
-- =============================================================================
-- Tables created (12, in FK dependency order):
--
-- Deferred from Migration 006 (master data):
--   inventory_balances (#59)               — ledger, mutable, no audit cols
--   inventory_cost_layers (#60)            — ledger, partial-mutable†
--
-- MODULE 14 — INVENTORY TRANSACTIONS (all Immutable=YES, Soft Delete=NO):
--   stock_adjustments (#109)               — transaction header
--   stock_adjustment_lines (#110)          — transaction lines
--   stock_transfers (#111)                 — transaction header
--   stock_transfer_lines (#112)            — transaction lines
--   goods_issues (#113)                    — transaction header
--   goods_issue_lines (#114)               — transaction lines
--   physical_count_entries (#115)          — transaction header
--   physical_count_lines (#116)            — transaction lines
--   inventory_movements (#117)             — ledger, no standard audit cols
--   inventory_cost_layer_consumption (#118) — ledger, append-only
--
-- †inventory_cost_layers: append-only for new rows (original_quantity and
--   unit_cost never change), but remaining_quantity and is_exhausted ARE
--   updated by the posting engine on FIFO consumption (Decision 007).
--
-- Intentionally deferred:
--   journal_entry_id — inventory transaction headers do NOT have
--     journal_entry_id per Doc03. GL linkage for inventory transactions is
--     handled via document_relationships (Module 16, Migration 016).
--   import_batch_id FK  → import_batches (Migration 023); column present on
--     all applicable transaction headers as part of standard transaction header.
--   RLS policies        → Migration 017.
--   Triggers            → dedicated trigger migration.
--
-- FK dependency order:
--   Group A: inventory_balances (refs companies, warehouses, items)
--   Group B: inventory_cost_layers (refs companies, items, warehouses;
--            source_document_id is polymorphic — no DB FK)
--   Group C: transaction headers — stock_adjustments (refs warehouses),
--            stock_transfers (refs warehouses), goods_issues (refs warehouses),
--            physical_count_entries (refs warehouses)
--   Group D: transaction line tables — stock_adjustment_lines,
--            stock_transfer_lines, goods_issue_lines, physical_count_lines
--   Group E: inventory_movements (refs companies, items, warehouses,
--            fiscal_periods; entity_id is polymorphic — no DB FK)
--   Group F: inventory_cost_layer_consumption (refs inventory_cost_layers,
--            inventory_movements — both available now)
--
-- Cross-migration relationships:
--   Migration 006 (master data): items, warehouses, units_of_measure
--   Migration 007 (sales): sales_invoice, cash_sale, customer_return lines
--     write inventory_movements at posting; source_document_type set accordingly
--   Migration 008 (purchasing): receiving_report_lines write inventory IN;
--     purchase_return_lines write inventory OUT
--   Migration 009 (petty cash / bank): no inventory relationship
--
-- Posting engine dependencies:
--   inventory_balances — upserted (INSERT ... ON CONFLICT DO UPDATE) by posting
--     engine at every inventory IN/OUT. Service role only.
--   inventory_cost_layers — new row inserted by posting engine on every IN.
--     remaining_quantity decremented and is_exhausted set on each OUT (FIFO).
--   inventory_cost_layer_consumption — inserted by posting engine on each OUT
--     to record which cost layers were consumed and by how much.
--   inventory_movements — inserted by posting engine for every IN/OUT event
--     regardless of source transaction type.
--   GL entries for inventory adjustments / goods issues / count variances are
--     linked via document_relationships (Module 16), NOT via journal_entry_id
--     on these headers (per Doc03 specification).
--
-- Inventory valuation:
--   Phase 1: FIFO costing (first-in first-out) enforced by cost layer ordering.
--   inventory_cost_layers ordered by layer_date ASC for FIFO depletion.
--   Weighted average cost (WAC) is computable from inventory_movements history
--     but is NOT the Phase 1 primary valuation method.
--   inventory_balances holds no cost column — current cost derived from the
--     oldest non-exhausted inventory_cost_layers row for a given item/warehouse.
--
-- Compliance dependencies:
--   inventory_movements is the master record for:
--     - COGS computation (DR COGS, CR Inventory) via document_relationships JE
--     - Physical inventory certification (BIR CAS requirements for stock cards)
--     - DAT export: inventory transactions feed CAS Stock Card export format
--   stock_adjustment and physical_count variances: DR/CR Inventory Gain/Loss
--     via document_relationships when posted.
--   entity_type CHECK in inventory_movements per Doc03 specification —
--     'customer_return' and 'purchase_return' are NOT in the Doc03 list
--     (see backlog item M-010-2 — gap to resolve in FINAL REVIEW PASS).
--
-- Standard transaction header status CHECK:
--   ('draft','submitted','approved','posted','voided','reversed','cancelled')
-- =============================================================================

-- =============================================================================
-- GROUP A: inventory_balances — mutable ledger, no audit columns
-- =============================================================================

-- #59 inventory_balances
-- Running on-hand stock balance per item per warehouse.
-- Upserted by posting engine (service role) on every inventory IN/OUT.
-- quantity_available = quantity_on_hand − quantity_reserved; maintained
-- by posting engine and order reservation processes — NOT user-editable.
-- No standard audit columns per Doc03 specification.
CREATE TABLE public.inventory_balances (
    id                  uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id          uuid          NOT NULL REFERENCES public.companies(id),
    warehouse_id        uuid          NOT NULL REFERENCES public.warehouses(id),
    item_id             uuid          NOT NULL REFERENCES public.items(id),
    quantity_on_hand    numeric(10,4) NOT NULL DEFAULT 0,
    quantity_reserved   numeric(10,4) NOT NULL DEFAULT 0,
    quantity_available  numeric(10,4) NOT NULL DEFAULT 0,
    last_updated_at     timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT pk_inventory_balances PRIMARY KEY (id),
    CONSTRAINT uq_inventory_balances_item_warehouse UNIQUE (company_id, warehouse_id, item_id),
    CONSTRAINT ck_ib_qty_on_hand CHECK (quantity_on_hand >= 0),
    CONSTRAINT ck_ib_qty_reserved CHECK (quantity_reserved >= 0),
    CONSTRAINT ck_ib_qty_reserved_lte_on_hand CHECK (quantity_reserved <= quantity_on_hand)
);

COMMENT ON TABLE public.inventory_balances
    IS 'Running on-hand stock balance per item per warehouse. Upserted by posting engine (service role) on every inventory movement. Application users must NOT write to this table directly. RLS policy in Migration 017 must restrict writes to service role only.';
COMMENT ON COLUMN public.inventory_balances.quantity_available
    IS 'quantity_on_hand − quantity_reserved. Maintained by posting engine and order reservation processes. Must not diverge from this formula — no DB-computed column because reservation updates are batch-applied. Application must recompute on every reservation change.';
COMMENT ON COLUMN public.inventory_balances.quantity_reserved
    IS 'Quantity allocated to confirmed, unshipped sales orders. Incremented by SO confirmation; decremented by DR posting or SO cancellation.';

CREATE INDEX ix_inventory_balances_item
    ON public.inventory_balances (company_id, item_id);

CREATE INDEX ix_inventory_balances_warehouse
    ON public.inventory_balances (company_id, warehouse_id);

ALTER TABLE public.inventory_balances ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP B: inventory_cost_layers — append-only with controlled mutability
-- =============================================================================

-- #60 inventory_cost_layers
-- FIFO cost layers per item per warehouse. One layer created per IN event.
-- source_document_type IN ('receiving_report','stock_adjustment','opening_stock').
-- IMPORTANT: remaining_quantity and is_exhausted are updated by the posting
-- engine on each FIFO consumption (OUT event). original_quantity and unit_cost
-- NEVER change after creation. See Decision 007.
CREATE TABLE public.inventory_cost_layers (
    id                    uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id            uuid          NOT NULL REFERENCES public.companies(id),
    item_id               uuid          NOT NULL REFERENCES public.items(id),
    warehouse_id          uuid          NOT NULL REFERENCES public.warehouses(id),
    source_document_type  text          NOT NULL,
    -- polymorphic: receiving_reports.id, stock_adjustments.id, or opening stock
    source_document_id    uuid          NOT NULL,
    -- polymorphic: receiving_report_lines.id, stock_adjustment_lines.id, NULL for opening
    source_line_id        uuid          NULL,
    layer_date            date          NOT NULL,
    original_quantity     numeric(18,4) NOT NULL,
    -- updated by posting engine on FIFO consumption — see Decision 007
    remaining_quantity    numeric(18,4) NOT NULL,
    unit_cost             numeric(18,4) NOT NULL,
    total_cost            numeric(18,4) NOT NULL,
    -- set to true by posting engine when remaining_quantity reaches 0
    is_exhausted          boolean       NOT NULL DEFAULT false,
    created_at            timestamptz   NOT NULL DEFAULT now(),
    created_by            uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_inventory_cost_layers PRIMARY KEY (id),
    CONSTRAINT ck_icl_source_document_type CHECK (
        source_document_type IN ('receiving_report','stock_adjustment','opening_stock')
    ),
    CONSTRAINT ck_icl_original_quantity CHECK (original_quantity > 0),
    CONSTRAINT ck_icl_remaining_quantity CHECK (remaining_quantity >= 0),
    CONSTRAINT ck_icl_remaining_lte_original CHECK (remaining_quantity <= original_quantity),
    CONSTRAINT ck_icl_unit_cost CHECK (unit_cost >= 0),
    CONSTRAINT ck_icl_total_cost CHECK (total_cost >= 0)
);

COMMENT ON TABLE public.inventory_cost_layers
    IS 'FIFO cost layers. Rows are append-only — never deleted. original_quantity and unit_cost are immutable after creation. remaining_quantity and is_exhausted are updated by the posting engine on each FIFO OUT event. See Decision 007.';
COMMENT ON COLUMN public.inventory_cost_layers.remaining_quantity
    IS 'Quantity not yet consumed by OUT movements. Decremented by posting engine on each FIFO consumption. Backlog M-010-1: Migration 017 RLS must restrict writes to service role only.';
COMMENT ON COLUMN public.inventory_cost_layers.source_document_id
    IS 'Polymorphic FK: receiving_reports.id, stock_adjustments.id, or NULL-equivalent for opening_stock type. No DB-level FK constraint — resolved by posting engine based on source_document_type.';

-- FIFO query pattern: ORDER BY layer_date ASC, id ASC WHERE NOT is_exhausted
CREATE INDEX ix_inventory_cost_layers_fifo
    ON public.inventory_cost_layers (company_id, item_id, warehouse_id, layer_date, id)
    WHERE is_exhausted = false;

CREATE INDEX ix_inventory_cost_layers_item
    ON public.inventory_cost_layers (company_id, item_id, warehouse_id);

ALTER TABLE public.inventory_cost_layers ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP C: Transaction headers — Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #109 stock_adjustments
-- Inventory adjustment header. Single warehouse scope per adjustment document.
-- adjustment_type drives GL account routing:
--   write_off/damage/expiry → Inventory Loss
--   count_adjustment        → Inventory Gain/Loss (sign of quantity_adjusted)
--   other                   → Inventory Adjustment (configurable account)
CREATE TABLE public.stock_adjustments (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.stock_adjustments(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- stock_adjustments-specific
    warehouse_id         uuid          NOT NULL REFERENCES public.warehouses(id),
    adjustment_type      text          NOT NULL,
    adjustment_reason    text          NULL,
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_stock_adjustments PRIMARY KEY (id),
    CONSTRAINT uq_sa_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_sa_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_sa_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_sa_adjustment_type CHECK (
        adjustment_type IN ('write_off','count_adjustment','damage','expiry','other')
    )
);

COMMENT ON TABLE public.stock_adjustments
    IS 'Inventory adjustment header. GL entries generated at posting are linked via document_relationships (Module 16), not via journal_entry_id on this table (per Doc03 specification).';

CREATE INDEX ix_stock_adjustments_company_date
    ON public.stock_adjustments (company_id, document_date);

CREATE INDEX ix_stock_adjustments_warehouse
    ON public.stock_adjustments (warehouse_id);

CREATE INDEX ix_stock_adjustments_status
    ON public.stock_adjustments (company_id, status);

ALTER TABLE public.stock_adjustments ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #111 stock_transfers
-- Inter-warehouse transfer header.
-- At posting: OUT from from_warehouse, IN to to_warehouse.
-- No GL entry for same-company transfers (inventory account stays the same).
-- Unit cost from FIFO cost layer of from_warehouse is transferred to to_warehouse.
CREATE TABLE public.stock_transfers (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.stock_transfers(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- stock_transfers-specific
    from_warehouse_id    uuid          NOT NULL REFERENCES public.warehouses(id),
    to_warehouse_id      uuid          NOT NULL REFERENCES public.warehouses(id),
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_stock_transfers PRIMARY KEY (id),
    CONSTRAINT uq_st_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_st_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_st_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_st_warehouses_differ CHECK (from_warehouse_id != to_warehouse_id)
);

COMMENT ON TABLE public.stock_transfers
    IS 'Inter-warehouse stock transfer. Posting engine writes OUT movement for from_warehouse and IN movement for to_warehouse with same unit_cost (FIFO cost layer transferred). No GL entry for intra-company transfers — inventory account is unchanged. GL linkage via document_relationships if an inter-branch GL clearing entry is needed.';

CREATE INDEX ix_stock_transfers_company_date
    ON public.stock_transfers (company_id, document_date);

CREATE INDEX ix_stock_transfers_from_warehouse
    ON public.stock_transfers (from_warehouse_id);

CREATE INDEX ix_stock_transfers_to_warehouse
    ON public.stock_transfers (to_warehouse_id);

ALTER TABLE public.stock_transfers ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #113 goods_issues
-- Internal goods issue header. Used for internal consumption: production,
-- repair, donation, samples. Reduces inventory and books expense at FIFO cost.
-- issue_purpose drives GL account selection in posting rule set.
CREATE TABLE public.goods_issues (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.goods_issues(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- goods_issues-specific
    warehouse_id         uuid          NOT NULL REFERENCES public.warehouses(id),
    issue_purpose        text          NOT NULL,
    requested_by         uuid          NULL     REFERENCES public.profiles(id),
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_goods_issues PRIMARY KEY (id),
    CONSTRAINT uq_gi_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_gi_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_gi_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_gi_issue_purpose CHECK (
        issue_purpose IN ('production','repair','donation','sample','other')
    )
);

CREATE INDEX ix_goods_issues_company_date
    ON public.goods_issues (company_id, document_date);

CREATE INDEX ix_goods_issues_warehouse
    ON public.goods_issues (warehouse_id);

ALTER TABLE public.goods_issues ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #115 physical_count_entries
-- Physical inventory count session header per warehouse.
-- count_type = 'full' → count all items; 'cycle' → subset of items.
-- At posting: count_adjustment stock_adjustment rows are generated for each
-- physical_count_line where variance != 0.
CREATE TABLE public.physical_count_entries (
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
    reversed_by_doc_id   uuid          NULL     REFERENCES public.physical_count_entries(id),
    source_document_id   uuid          NULL,
    source_document_type text          NULL,
    import_batch_id      uuid          NULL,
    -- physical_count_entries-specific
    warehouse_id         uuid          NOT NULL REFERENCES public.warehouses(id),
    count_date           date          NOT NULL,
    count_type           text          NOT NULL,
    initiated_by         uuid          NOT NULL REFERENCES public.profiles(id),
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_physical_count_entries PRIMARY KEY (id),
    CONSTRAINT uq_pce_company_doc UNIQUE (company_id, document_no),
    CONSTRAINT ck_pce_status CHECK (
        status IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
    ),
    CONSTRAINT ck_pce_exchange_rate CHECK (exchange_rate > 0),
    CONSTRAINT ck_pce_count_type CHECK (count_type IN ('full','cycle'))
);

COMMENT ON TABLE public.physical_count_entries
    IS 'Physical inventory count session. At posting, the engine generates count_adjustment stock_adjustment rows for each physical_count_line with variance != 0, then posts inventory_movements for those variances.';

CREATE INDEX ix_physical_count_entries_company_date
    ON public.physical_count_entries (company_id, count_date);

CREATE INDEX ix_physical_count_entries_warehouse
    ON public.physical_count_entries (warehouse_id);

ALTER TABLE public.physical_count_entries ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP D: Transaction line tables — Immutable=YES, Soft Delete=NO
-- =============================================================================

-- #110 stock_adjustment_lines
-- Lines of a stock adjustment. quantity_adjusted is signed:
--   positive = inventory increase (found qty, correction IN)
--   negative = inventory decrease (write-off, damage, correction OUT)
-- quantity_after is a snapshot at the time of posting for audit purposes.
-- unit_cost = FIFO cost at time of adjustment.
CREATE TABLE public.stock_adjustment_lines (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id           uuid          NOT NULL REFERENCES public.companies(id),
    stock_adjustment_id  uuid          NOT NULL REFERENCES public.stock_adjustments(id),
    line_no              integer       NOT NULL,
    item_id              uuid          NOT NULL REFERENCES public.items(id),
    quantity_before      numeric(10,4) NOT NULL,
    -- signed: positive = IN, negative = OUT
    quantity_adjusted    numeric(10,4) NOT NULL,
    quantity_after       numeric(10,4) NOT NULL,
    unit_cost            numeric(18,4) NOT NULL,
    total_cost           numeric(18,4) NOT NULL,
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_stock_adjustment_lines PRIMARY KEY (id),
    CONSTRAINT ck_sal_line_no CHECK (line_no > 0),
    CONSTRAINT ck_sal_quantity_before CHECK (quantity_before >= 0),
    CONSTRAINT ck_sal_quantity_adjusted CHECK (quantity_adjusted != 0),
    CONSTRAINT ck_sal_quantity_after CHECK (quantity_after >= 0),
    CONSTRAINT ck_sal_unit_cost CHECK (unit_cost >= 0)
);

COMMENT ON COLUMN public.stock_adjustment_lines.quantity_adjusted
    IS 'Signed quantity: positive = inventory increase (IN), negative = decrease (OUT). Zero is not permitted — use a separate reversal document instead.';
COMMENT ON COLUMN public.stock_adjustment_lines.total_cost
    IS 'abs(quantity_adjusted) × unit_cost. Always non-negative. Sign of inventory movement inferred from quantity_adjusted.';

CREATE INDEX ix_stock_adjustment_lines_adj
    ON public.stock_adjustment_lines (stock_adjustment_id);

CREATE INDEX ix_stock_adjustment_lines_item
    ON public.stock_adjustment_lines (item_id);

ALTER TABLE public.stock_adjustment_lines ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #112 stock_transfer_lines
-- Lines of a stock transfer. quantity_transferred ≤ quantity_requested
-- (partial transfer allowed). unit_cost = FIFO cost from from_warehouse.
CREATE TABLE public.stock_transfer_lines (
    id                    uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id            uuid          NOT NULL REFERENCES public.companies(id),
    stock_transfer_id     uuid          NOT NULL REFERENCES public.stock_transfers(id),
    line_no               integer       NOT NULL,
    item_id               uuid          NOT NULL REFERENCES public.items(id),
    quantity_requested    numeric(10,4) NOT NULL,
    quantity_transferred  numeric(10,4) NOT NULL DEFAULT 0,
    unit_cost             numeric(18,4) NOT NULL,
    total_cost            numeric(18,4) NOT NULL DEFAULT 0,
    -- standard audit (Immutable=YES)
    created_at            timestamptz   NOT NULL DEFAULT now(),
    created_by            uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_stock_transfer_lines PRIMARY KEY (id),
    CONSTRAINT ck_stl_line_no CHECK (line_no > 0),
    CONSTRAINT ck_stl_qty_requested CHECK (quantity_requested > 0),
    CONSTRAINT ck_stl_qty_transferred CHECK (quantity_transferred >= 0),
    CONSTRAINT ck_stl_qty_partial CHECK (quantity_transferred <= quantity_requested),
    CONSTRAINT ck_stl_unit_cost CHECK (unit_cost >= 0),
    CONSTRAINT ck_stl_total_cost CHECK (total_cost >= 0)
);

CREATE INDEX ix_stock_transfer_lines_transfer
    ON public.stock_transfer_lines (stock_transfer_id);

CREATE INDEX ix_stock_transfer_lines_item
    ON public.stock_transfer_lines (item_id);

ALTER TABLE public.stock_transfer_lines ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #114 goods_issue_lines
-- Lines of a goods issue. account_id is the DR expense account for this line.
-- unit_cost = FIFO cost from warehouse at time of issue.
-- Posting engine: DR account_id, CR Inventory (from system_account_config INVENTORY_CONTROL).
CREATE TABLE public.goods_issue_lines (
    id               uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id       uuid          NOT NULL REFERENCES public.companies(id),
    goods_issue_id   uuid          NOT NULL REFERENCES public.goods_issues(id),
    line_no          integer       NOT NULL,
    item_id          uuid          NOT NULL REFERENCES public.items(id),
    quantity         numeric(10,4) NOT NULL,
    unit_cost        numeric(18,4) NOT NULL,
    total_cost       numeric(18,4) NOT NULL,
    account_id       uuid          NOT NULL REFERENCES public.chart_of_accounts(id),
    -- standard audit (Immutable=YES)
    created_at       timestamptz   NOT NULL DEFAULT now(),
    created_by       uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_goods_issue_lines PRIMARY KEY (id),
    CONSTRAINT ck_gil_line_no CHECK (line_no > 0),
    CONSTRAINT ck_gil_quantity CHECK (quantity > 0),
    CONSTRAINT ck_gil_unit_cost CHECK (unit_cost >= 0),
    CONSTRAINT ck_gil_total_cost CHECK (total_cost >= 0)
);

COMMENT ON COLUMN public.goods_issue_lines.account_id
    IS 'DR expense account for this issue line. Posting engine: DR this account, CR INVENTORY_CONTROL (from system_account_config). account_id must be an expense-type account — application must validate at entry.';

CREATE INDEX ix_goods_issue_lines_issue
    ON public.goods_issue_lines (goods_issue_id);

CREATE INDEX ix_goods_issue_lines_item
    ON public.goods_issue_lines (item_id);

ALTER TABLE public.goods_issue_lines ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------

-- #116 physical_count_lines
-- Per-item lines of a physical count session.
-- system_quantity: snapshot from inventory_balances at the time the count
--   sheet is initiated (NOT a live join — captured to preserve audit integrity).
-- variance: counted_quantity − system_quantity (signed; negative = shortage).
-- variance_cost: abs(variance) × unit_cost (always positive; sign from variance).
CREATE TABLE public.physical_count_lines (
    id                   uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id           uuid          NOT NULL REFERENCES public.companies(id),
    physical_count_id    uuid          NOT NULL REFERENCES public.physical_count_entries(id),
    item_id              uuid          NOT NULL REFERENCES public.items(id),
    system_quantity      numeric(10,4) NOT NULL,
    counted_quantity     numeric(10,4) NOT NULL,
    variance             numeric(10,4) NOT NULL DEFAULT 0,
    unit_cost            numeric(18,4) NOT NULL,
    variance_cost        numeric(18,4) NOT NULL DEFAULT 0,
    -- standard audit (Immutable=YES)
    created_at           timestamptz   NOT NULL DEFAULT now(),
    created_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_physical_count_lines PRIMARY KEY (id),
    CONSTRAINT ck_pcl_system_quantity CHECK (system_quantity >= 0),
    CONSTRAINT ck_pcl_counted_quantity CHECK (counted_quantity >= 0),
    CONSTRAINT ck_pcl_unit_cost CHECK (unit_cost >= 0),
    CONSTRAINT ck_pcl_variance_cost CHECK (variance_cost >= 0)
);

COMMENT ON COLUMN public.physical_count_lines.system_quantity
    IS 'Snapshot of inventory_balances.quantity_on_hand at count initiation time. NOT a live join — captured for audit immutability so post-count adjustments to other documents do not retroactively change the variance.';

-- One line per item per count session
CREATE UNIQUE INDEX uq_physical_count_lines_item
    ON public.physical_count_lines (physical_count_id, item_id);

CREATE INDEX ix_physical_count_lines_count
    ON public.physical_count_lines (physical_count_id);

CREATE INDEX ix_physical_count_lines_item
    ON public.physical_count_lines (item_id);

ALTER TABLE public.physical_count_lines ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP E: inventory_movements — ledger, Immutable=YES, no standard audit cols
-- =============================================================================

-- #117 inventory_movements
-- Unified inventory movement ledger. One row per IN/OUT event regardless of
-- source transaction type. Written exclusively by posting engine (service role).
-- entity_type + entity_id identify the source document (polymorphic reference).
-- quantity is always positive — direction indicated by movement_type.
-- IMPORTANT: 'customer_return' and 'purchase_return' are not in the Doc03
-- entity_type CHECK list. See backlog item M-010-2.
CREATE TABLE public.inventory_movements (
    id                uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id        uuid          NOT NULL REFERENCES public.companies(id),
    entity_type       text          NOT NULL,
    -- polymorphic FK to the source document — no DB constraint
    entity_id         uuid          NOT NULL,
    -- polymorphic FK to the source document line — no DB constraint
    entity_line_id    uuid          NULL,
    item_id           uuid          NOT NULL REFERENCES public.items(id),
    warehouse_id      uuid          NOT NULL REFERENCES public.warehouses(id),
    movement_type     text          NOT NULL,
    quantity          numeric(10,4) NOT NULL,
    unit_cost         numeric(18,4) NOT NULL,
    total_cost        numeric(18,4) NOT NULL,
    movement_date     date          NOT NULL,
    fiscal_period_id  uuid          NOT NULL REFERENCES public.fiscal_periods(id),
    -- no standard audit columns per Doc03 — only system-generated timestamps
    created_at        timestamptz   NOT NULL DEFAULT now(),
    created_by        uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_inventory_movements PRIMARY KEY (id),
    CONSTRAINT ck_im_entity_type CHECK (
        entity_type IN (
            'sales_invoice',
            'cash_sale',
            'vendor_bill',
            'cash_purchase',
            'stock_adjustment',
            'stock_transfer',
            'goods_issue',
            'physical_count_entry',
            'receiving_report'
        )
    ),
    CONSTRAINT ck_im_movement_type CHECK (movement_type IN ('IN','OUT')),
    CONSTRAINT ck_im_quantity CHECK (quantity > 0),
    CONSTRAINT ck_im_unit_cost CHECK (unit_cost >= 0),
    CONSTRAINT ck_im_total_cost CHECK (total_cost >= 0)
);

COMMENT ON TABLE public.inventory_movements
    IS 'Unified inventory movement ledger. Written exclusively by posting engine (service role). Never modified after creation. entity_type + entity_id provide source document traceability. See backlog M-010-2: customer_return and purchase_return are not in entity_type CHECK per frozen Doc03 — FINAL REVIEW PASS required.';
COMMENT ON COLUMN public.inventory_movements.entity_id
    IS 'Polymorphic FK to source document. Resolves to the PK of the table named by entity_type. No DB-level FK constraint.';
COMMENT ON COLUMN public.inventory_movements.quantity
    IS 'Always positive. Direction of movement determined by movement_type (IN/OUT).';

-- Primary lookup pattern: all movements for an item in a warehouse over time
CREATE INDEX idx_inv_movements_item_warehouse
    ON public.inventory_movements (company_id, item_id, warehouse_id, movement_date);

-- Period-based reporting and period close
CREATE INDEX idx_inv_movements_period
    ON public.inventory_movements (company_id, fiscal_period_id);

-- Source document traceability
CREATE INDEX ix_inventory_movements_entity
    ON public.inventory_movements (entity_type, entity_id);

ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- GROUP F: inventory_cost_layer_consumption — ledger, append-only
-- =============================================================================

-- #118 inventory_cost_layer_consumption
-- Records FIFO cost layer depletion on each OUT movement.
-- Written by posting engine when inventory is reduced (sales, issues, returns,
-- adjustments, transfers). Provides complete FIFO consumption audit trail.
-- inventory_movement_id links to the OUT movement that triggered this consumption.
-- Multiple rows per movement are possible when a single OUT spans multiple layers.
CREATE TABLE public.inventory_cost_layer_consumption (
    id                    uuid          NOT NULL DEFAULT gen_random_uuid(),
    company_id            uuid          NOT NULL REFERENCES public.companies(id),
    cost_layer_id         uuid          NOT NULL REFERENCES public.inventory_cost_layers(id),
    inventory_movement_id uuid          NOT NULL REFERENCES public.inventory_movements(id),
    consumed_quantity     numeric(18,4) NOT NULL,
    unit_cost             numeric(18,4) NOT NULL,
    total_cost            numeric(18,4) NOT NULL,
    consumed_at           timestamptz   NOT NULL DEFAULT now(),
    consumed_by           uuid          NOT NULL REFERENCES public.profiles(id),

    CONSTRAINT pk_inventory_cost_layer_consumption PRIMARY KEY (id),
    CONSTRAINT ck_iclc_consumed_quantity CHECK (consumed_quantity > 0),
    CONSTRAINT ck_iclc_unit_cost CHECK (unit_cost >= 0),
    CONSTRAINT ck_iclc_total_cost CHECK (total_cost >= 0)
);

COMMENT ON TABLE public.inventory_cost_layer_consumption
    IS 'FIFO cost layer depletion records. One row per layer consumed per OUT movement. Multiple rows per inventory_movement_id when a single OUT depletes across multiple cost layers. Written exclusively by posting engine. Provides complete COGS / inventory valuation audit trail.';

-- Lookup: all consumptions from a specific cost layer (FIFO analysis)
CREATE INDEX ix_cost_layer_consumption_layer
    ON public.inventory_cost_layer_consumption (cost_layer_id);

-- Lookup: all layer consumptions for a specific OUT movement
CREATE INDEX ix_cost_layer_consumption_movement
    ON public.inventory_cost_layer_consumption (inventory_movement_id);

-- Company-scoped reporting
CREATE INDEX ix_cost_layer_consumption_company
    ON public.inventory_cost_layer_consumption (company_id, consumed_at);

ALTER TABLE public.inventory_cost_layer_consumption ENABLE ROW LEVEL SECURITY;
