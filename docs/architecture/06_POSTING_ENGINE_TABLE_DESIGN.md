# PXL ERP — Posting Engine Table Design
**Version:** 4.0 — Canonical Release
**Status:** v4.0 — DATABASE FREEZE CANDIDATE. Pending human sign-off (see Doc10 Sections 47–53).

---

## Resolved Architectural Decisions

| Decision | Resolution |
|---|---|
| `posting_rule_sets` — company-specific or system-seeded? | System-seeded with `is_system=true`. At company onboarding, the setup wizard seeds one active `posting_rule_set` per standard `transaction_type`. Companies may clone a system rule (INSERT new row with `is_system=false`) to customize. System rules cannot be deleted or deactivated. Cloned rules take precedence when `effective_from` matches or is later. At post time, load rule where `company_id=? AND transaction_type=? AND effective_from<=document_date AND (effective_to IS NULL OR effective_to>document_date)` ORDER BY `is_system ASC, effective_from DESC` LIMIT 1. |
| When `taxpayer_type='non_vat'`, write to `vat_entries` or `pt_entries`? | Skip `vat_entries` entirely. Insert `percentage_tax_entries` only. The posting engine checks `company_compliance_profiles.taxpayer_type` at step 11. If `'non_vat'`: do NOT write to `vat_entries`; INSERT `percentage_tax_entries` with `pt_rate` from `percentage_tax_codes` effective on `document_date`. If `'vat'`: write `vat_entries` as normal; no `percentage_tax_entries`. No mixing. |
| Capital goods input VAT (>PHP 1M) — Phase 1 handling? | Phase 1: classify the input VAT as `INPUT_VAT_CAPITAL_GOODS` at posting time (book full amount to deferred capital goods VAT account). Monthly amortization is computed manually at filing time. Phase 2 will add a recurring JE generator. At posting, check `cash_purchase_lines.input_vat_amount > 1_000_000`; if true, route to `INPUT_VAT_CAPITAL_GOODS` system config key instead of `INPUT_VAT`. |
| Posting engine writes compliance entries or document save step? | Posting engine writes all immutable compliance entries (§7 Step 11). Document save writes draft preview fields only. |
| `recurring_journal_template_lines` dynamic amounts? | Phase 2 deferred. Phase 1 supports fixed amounts only. |

---

## Implementation Notes

- All posting steps execute within a single database transaction. Failure at any step rolls back entirely.
- Notification dispatch (Step 13) is async fire-and-forget — it does NOT participate in the posting transaction. Notification failure does not roll back the post.
- Cash Sales and Cash Purchases posting rules must explicitly exclude `subsidiary_ledger_entries` creation. The posting rule lines for these transaction types do not include an AR or AP rule line.
- `gl_balances` upsert uses `INSERT ... ON CONFLICT DO UPDATE` — this must be atomic within the posting transaction.
- `system_account_config` keys must be fully populated before any posting rule set can be activated. Missing config keys cause posting to abort.
- The posting engine is implemented as a Supabase Edge Function using the service role. Application users cannot directly INSERT into `journal_entries` or `journal_lines`.

---

## 1. Overview

The posting engine converts source documents (invoices, receipts, vouchers, cash sales, cash purchases) into balanced journal entries following pre-defined posting rule sets. This document covers all tables that power the posting engine.

---

## 2. Posting Rules Tables

### `posting_rule_sets`
Defines the top-level rule set for each transaction type. Full column spec: Doc03 §9. This section retains transaction_type context and posting notes.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `rule_set_code` | text | UNIQUE per company, NOT NULL | e.g., 'SALES_INV_VAT', 'PV_EWT', 'CASH_SALE_VAT', 'CASH_PUR_EWT' |
| `transaction_type` | text | NOT NULL | See transaction types below |
| `description` | text | NULL | |
| `is_active` | boolean | NOT NULL DEFAULT true | |
| `is_system` | boolean | NOT NULL DEFAULT false | System rules cannot be deleted |
| `effective_from` | date | NOT NULL | Date this rule set takes effect |
| `effective_to` | date | NULL | NULL = currently active |
| *+ standard audit columns* | | | |

**Constraints:** `UNIQUE(company_id, rule_set_code, effective_from)`. Partial unique index `WHERE effective_to IS NULL` ensures one active rule per code per company.

**Principle 11:** If BIR changes VAT rate or EWT rates, a new `posting_rule_set` with updated `effective_from` is inserted. Historical transactions use the rule set active on their `document_date`. Do NOT update existing active rule sets — insert new versions.

**Valid `transaction_type` values:**
`sales_invoice` | `vendor_bill` | `receipt` | `payment_voucher` | `cash_sale` | `cash_purchase` | `petty_cash_voucher` | `petty_cash_replenishment` | `stock_adjustment` | `stock_transfer` | `customer_return` | `purchase_return` | `sales_credit_memo` | `vendor_credit` | `sales_debit_memo` | `supplier_debit_memo` | `asset_acquisition` | `asset_depreciation` | `asset_disposal` | `bank_fund_transfer` | `bank_adjustment` | `inter_branch_transfer` | `journal_entry`

> **Percentage Tax Note (Principle 3 Driver 1):** `sales_invoice` and `cash_sale` posting rules check `company_compliance_profiles.taxpayer_type` at post time. If `taxpayer_type = 'non_vat'`, the posting engine creates `percentage_tax_entries` instead of `vat_entries`. No separate `transaction_type` is needed — the same source documents drive different compliance entries depending on the company's taxpayer type.

> **FWT Note:** `fwt_entries` are created during posting of vendor_bill, cash_purchase, or payment_voucher lines where the `ewt_atc_id` references a WF-series ATC code. These flow to `fwt_remittances_1601fq` instead of `ewt_remittances_1601eq`.

---

### `posting_rule_lines`
Each line in a rule set defines one DR or CR entry. Full column spec: Doc03 §9.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `posting_rule_set_id` | uuid | FK posting_rule_sets, NOT NULL | |
| `line_no` | integer | NOT NULL | Execution order |
| `entry_side` | text | CHECK IN ('debit','credit'), NOT NULL | |
| `account_source` | text | NOT NULL | CHECK IN ('fixed','from_system_config','from_item','from_customer','from_supplier','from_line') |
| `fixed_account_id` | uuid | FK chart_of_accounts, NULL | Used if account_source='fixed' |
| `account_config_key` | text | NULL | Used if account_source='from_system_config'; e.g., 'AR_TRADE', 'OUTPUT_VAT', 'AP_TRADE', 'CASH_ON_HAND' |
| `amount_source` | text | NOT NULL | CHECK IN ('line_subtotal','line_vat','line_ewt','header_total','computed') |
| `amount_formula` | text | NULL | SQL expression for computed amounts |
| `applies_to` | text | NOT NULL DEFAULT 'all' | CHECK IN ('all','vat_lines_only','ewt_lines_only','zero_vat_lines','capital_goods_lines_only','pt_lines_only') |
| `creates_subsidiary_ledger` | boolean | NOT NULL DEFAULT false | Whether this line creates a subsidiary_ledger_entry |
| `subsidiary_ledger_type` | text | NULL | CHECK IN ('ar','ap','inventory','fixed_asset') |
| `use_branch_dimension` | boolean | NOT NULL DEFAULT true | |
| `use_department_dimension` | boolean | NOT NULL DEFAULT false | |
| `use_cost_center_dimension` | boolean | NOT NULL DEFAULT false | |
| `description_template` | text | NULL | e.g., 'Sales Invoice {doc_no} - {customer_name}' |

---

### `system_account_config`
Maps semantic account keys to actual GL accounts per company. Full column spec: Doc03 §29.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `config_key` | text | NOT NULL | See standard keys below |
| `account_id` | uuid | FK chart_of_accounts, NOT NULL | |
| `branch_id` | uuid | FK branches, NULL | NULL = applies to all branches |
| `effective_from` | date | NOT NULL | |
| `effective_to` | date | NULL | NULL = still active |

UNIQUE: `(company_id, config_key, branch_id, effective_from)`

**Standard config keys (v3 expanded):**

| Key | Description | COA control_account_type |
|---|---|---|
| `AR_TRADE` | Accounts Receivable — Trade | AR_CONTROL |
| `AP_TRADE` | Accounts Payable — Trade | AP_CONTROL |
| `OUTPUT_VAT` | Output VAT Payable (VAT companies) | OUTPUT_VAT_CONTROL |
| `INPUT_VAT` | Input VAT (standard 12%) | INPUT_VAT_CONTROL |
| `INPUT_VAT_DEFERRED` | Input VAT — Deferred (pending validation) | INPUT_VAT_CONTROL |
| `INPUT_VAT_CAPITAL_GOODS` | Input VAT — Capital Goods (amortized) | INPUT_VAT_CONTROL |
| `EWT_PAYABLE` | Expanded Withholding Tax Payable (1601EQ) | EWT_PAYABLE_CONTROL |
| `FWT_PAYABLE` | Final Withholding Tax Payable (1601FQ) | FWT_PAYABLE_CONTROL |
| `PERCENTAGE_TAX_PAYABLE` | Percentage Tax Payable (2551Q, non-VAT) | PT_PAYABLE_CONTROL |
| `INCOME_TAX_PAYABLE` | Income Tax Payable (1702Q/1701Q quarterly) | INCOME_TAX_PAYABLE_CONTROL |
| `CASH_ON_HAND` | Cash on Hand (petty cash, over-the-counter) | — |
| `CASH_IN_BANK` | Cash in Bank (default checking account) | — |
| `INVENTORY_CONTROL` | Inventory — Trading Goods / Raw Materials | INVENTORY_CONTROL |
| `COST_OF_GOODS_SOLD` | Cost of Goods Sold | — |
| `RETAINED_EARNINGS` | Retained Earnings (year-end closing) | — |
| `INCOME_SUMMARY` | Income Summary (closing account) | — |

**Setup requirement:** `PERCENTAGE_TAX_PAYABLE`, `FWT_PAYABLE`, and `INCOME_TAX_PAYABLE` are required at company setup when the corresponding compliance obligation is enabled in `company_compliance_profiles.filing_obligations`. Missing config keys cause posting engine abort.

---

## 3. Journal Entry Tables

### `journal_entries`
> Column spec: See Doc03 Section 9 (`journal_entries`). This document retains the posting context notes and process flow; the authoritative column list lives in Doc03.

---

### `journal_lines`
> Column spec: See Doc03 Section 9 (`journal_lines`). See Doc03 Section 9.

---

### `gl_balances`
> Column spec: See Doc03 Section 9 (`gl_balances`). UNIQUE: `(company_id, account_id, branch_id, fiscal_period_id)`.

---

### `subsidiary_ledger_entries`
> Column spec: See Doc03 Section 9 (`subsidiary_ledger_entries`). Not created for Cash Sales or Cash Purchases (no AR/AP impact).

---

## 4. Document Relationships Table

### `document_relationships`
Tracks all source-to-target relationships across document types.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `source_document_type` | text | NOT NULL | |
| `source_document_id` | uuid | NOT NULL | |
| `target_document_type` | text | NOT NULL | |
| `target_document_id` | uuid | NOT NULL | |
| `relationship_type` | text | NOT NULL | 'billed_from' \| 'paid_by' \| 'reversed_by' \| 'delivered_from' \| 'received_from' \| 'applied_to' \| 'replenished_by' |
| `amount_applied` | numeric(18,4) | NULL | For partial applications |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |
| `created_by` | uuid | FK auth.users | |

---

## 5. Fiscal Control Tables

### `fiscal_years`

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `year_label` | text | NOT NULL | e.g., 'FY2025' |
| `start_date` | date | NOT NULL | |
| `end_date` | date | NOT NULL | |
| `status` | text | CHECK IN ('open','closed','locked') | |
| `closed_at` | timestamptz | NULL | |
| `closed_by` | uuid | FK auth.users, NULL | |

### `fiscal_periods`

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `fiscal_year_id` | uuid | FK fiscal_years, NOT NULL | |
| `period_number` | integer | NOT NULL | 1–12 for monthly |
| `quarter_number` | integer | NOT NULL | 1–4 |
| `period_name` | text | NOT NULL | e.g., 'January 2025' |
| `start_date` | date | NOT NULL | |
| `end_date` | date | NOT NULL | |
| `status` | text | CHECK IN ('open','closed','locked') | |
| `closed_at` | timestamptz | NULL | |
| `closed_by` | uuid | FK auth.users, NULL | |

### `fiscal_locks`
Prevents posting to closed periods.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `fiscal_period_id` | uuid | FK fiscal_periods, NOT NULL | |
| `locked_at` | timestamptz | NOT NULL | |
| `locked_by` | uuid | FK auth.users, NOT NULL | |
| `unlock_reason` | text | NULL | Required if unlocked |
| `unlocked_at` | timestamptz | NULL | |
| `unlocked_by` | uuid | FK auth.users, NULL | |

UNIQUE: `(company_id, fiscal_period_id)`

---

## 6. Recurring Journal Tables

### `recurring_journal_templates`
> Column spec: See Doc03 Section 9 (`recurring_journal_templates`).

### `recurring_journal_template_lines`
> Column spec: See Doc03 Section 9 (`recurring_journal_template_lines`). Phase 1 supports fixed amounts only (no dynamic amount formulas — see OD-14).

---

## 7. Posting Engine Process Flow

> **v3.2 — Three additions:** (a) Idempotency check at step 0; (b) Compliance entry writes (vat_entries, ewt_entries, fwt_entries, percentage_tax_entries) made explicit at step 7 — **BLOCKER 4 RESOLVED**; (c) Status values normalized to lowercase.

```
0.  CHECK idempotency: IF posting_batches.idempotency_key already processed → RETURN existing batch_id (ABORT, not error)
1.  VALIDATE source document (all required fields present, status = 'approved' or 'draft' if no approval workflow)
2.  CHECK fiscal period is 'open' via fiscal_locks (abort if 'closed' or 'locked')
3.  CHECK posting not already done: IF journal_entries WHERE source_document_id = ? AND status = 'posted' exists → ABORT (duplicate posting guard)
4.  LOAD posting_rule_set for transaction_type effective on document_date
5.  FOR EACH posting_rule_line:
    a. RESOLVE account (fixed | from_system_config | from_item | from_line)
    b. COMPUTE amount (line_subtotal | line_vat | line_ewt | header_total | computed)
    c. BUILD journal_line record
6.  VERIFY SUM(debit) = SUM(credit) → ABORT if unbalanced
7.  INSERT journal_entries (status='posted', posted_at=now()) — links posting_batch_id + idempotency_key
8.  INSERT journal_lines (all lines)
9.  UPSERT gl_balances (per account per period, INSERT ... ON CONFLICT DO UPDATE)
10. INSERT subsidiary_ledger_entries (ar / ap / fixed_asset) AND inventory writes:
    → SKIP subsidiary_ledger_entries for cash_sale and cash_purchase transaction types (no AR/AP)
    → For inventory-impacting transactions (sales_invoice, cash_sale, vendor_bill, cash_purchase,
       stock_adjustment, stock_transfer, customer_return, purchase_return):
       a. INSERT inventory_movements (one per line item per inventory change):
          - item_id, warehouse_id, movement_type ('sale_out','purchase_in','return_in','return_out',
            'transfer_in','transfer_out','adjustment_in','adjustment_out'), quantity, unit_cost,
            total_cost, source_document_type, source_document_id, fiscal_period_id
       b. UPSERT inventory_balances (per item per warehouse):
          - quantity_on_hand += movement quantity (+ for IN, − for OUT)
          - average_unit_cost recomputed (weighted average for IN; unchanged for OUT in FIFO Phase 1)
          - UNIQUE: (company_id, item_id, warehouse_id)
11. WRITE compliance entries (within same transaction — immutable snapshots):
    a. INSERT vat_entries (one per taxable line) — tax_period_id, vat_direction, vat_classification, amounts
    b. INSERT ewt_entries (one per EWT-subject line per ATC) — payee snapshot fields, ewt_amount
    c. INSERT fwt_entries (if FWT-subject transaction) — payee snapshot fields, fwt_amount
    d. INSERT percentage_tax_entries (if non-VAT taxpayer_type) — pt_amount, atc_code
    e. UPSERT vat_period_summaries (VAT companies only):
       - UNIQUE: (company_id, tax_period_id, vat_direction, vat_classification)
       - total_base_amount += line.base_amount; total_vat_amount += line.vat_amount
       - This is the aggregate source for BIR Form 2550M/2550Q schedule population
    f. UPSERT ewt_period_summaries (if any ewt_entries written):
       - UNIQUE: (company_id, tax_period_id, ewt_atc_id)
       - total_base_amount += ewt_entry.ewt_base_amount; total_ewt_amount += ewt_entry.ewt_amount
       - This is the aggregate source for 1601EQ schedule population
    g. UPSERT percentage_tax_period_summaries (non-VAT companies only, if percentage_tax_entries written):
       - UNIQUE: (company_id, tax_period_id, atc_code)
       - total_gross_receipts += line.gross_amount; total_pt_amount += line.pt_amount
       - This is the aggregate source for BIR Form 2551Q schedule population
    → If document was previously in draft and had preview/draft entries, DELETE them before INSERT
    → Void/reversal: INSERT reversal entries (negative amounts), never silent DELETE or UPDATE
12. UPDATE source document status → 'posted', posting_date = now()
13. INSERT document_relationships (source → journal_entry)
14. INSERT audit_logs (event_type='document_posted')
15. UPDATE posting_batches.status → 'completed' (or 'partial_fail' if any entity failed)
16. DISPATCH notifications (async, fire-and-forget — NOT part of this transaction)
    → notify document owner (posted), notify approvers if applicable
```

**All steps 1–15 execute within a single database transaction. Step 16 is async.**

### Idempotency Design (v3.2)

- `posting_batches.idempotency_key` (text, UNIQUE) — set by Edge Function caller using `source_document_type + ':' + source_document_id + ':' + attempt_token`
- On Edge Function retry: same idempotency_key → returns existing batch result, no re-processing
- `journal_entries` duplicate guard: UNIQUE(company_id, source_document_type, source_document_id) WHERE je_type = 'system' — prevents double-posting even without idempotency_key. Posting-engine-generated JEs use je_type = 'system' (see Doc03 §9 for canonical je_type CHECK values).
- Compliance entry deduplication: posting engine checks existence before INSERT; abort if found for same source document and status = 'posted'

---

## 8. Posting Rules for Cash Sales and Cash Purchases

### Cash Sale Posting (No AR Created)

```
DR: Cash / Bank (cash_sales.total_amount)              account: FROM_SYSTEM_CONFIG 'CASH_ON_HAND' or 'CASH_IN_BANK'
CR: Revenue Account (cash_sale_lines.net_amount)       account: FROM_ITEM or FROM_LINE (revenue_account_id)
CR: Output VAT Payable (vat_entries.vat_amount)        account: FROM_SYSTEM_CONFIG 'OUTPUT_VAT'
```
- No `subsidiary_ledger_entries` with ledger_type='AR'
- `cash_sale_lines` reduce inventory (inventory_movements OUT) if item is a stocked item

### Cash Purchase Posting (No AP Created)

```
DR: Inventory / Expense Account (cash_purchase_lines.net_amount)    account: FROM_ITEM or FROM_LINE
DR: Input VAT (cash_purchase_lines.input_vat_amount)                account: FROM_SYSTEM_CONFIG 'INPUT_VAT'
CR: Cash / Bank                                                      account: FROM_SYSTEM_CONFIG 'CASH_ON_HAND' or 'CASH_IN_BANK'
CR: EWT Payable (ewt_entries.ewt_amount)     [if EWT-subject line]  account: FROM_SYSTEM_CONFIG 'EWT_PAYABLE'
CR: FWT Payable (fwt_entries.fwt_amount)     [if FWT-subject line]  account: FROM_SYSTEM_CONFIG 'FWT_PAYABLE'
```
Column reference: `net_amount` = cost before VAT; `input_vat_amount` = VAT portion; `total_amount` = net_amount + input_vat_amount.
Cash paid = `total_amount - ewt_amount` (or `total_amount - fwt_amount` for FWT lines).
- `net_payable_amount = net_amount + input_vat_amount - ewt_amount` (or - fwt_amount for FWT lines)
- EWT Payable is **credited** because the company withholds from the supplier and owes that amount to the BIR — it is a liability, not a deduction from the expense.
- No `subsidiary_ledger_entries` with ledger_type='AP'
- EWT is captured at purchase time; no deferred payment step required

---

### Petty Cash Voucher Posting

```
DR: Expense Account (petty_cash_voucher_lines.account_id)    FROM_LINE
CR: Petty Cash Fund (petty_cash_funds.account_id)            FROM_SYSTEM_CONFIG 'CASH_ON_HAND'
CR: EWT Payable (ewt_entries.ewt_amount)  [if EWT-subject]  FROM_SYSTEM_CONFIG 'EWT_PAYABLE'
```
- No AR/AP subsidiary ledger entries
- EWT captured at voucher line level

---

### Stock Adjustment Posting

```
DR: Inventory Control (adjustment qty > 0 — increase)  FROM_SYSTEM_CONFIG 'INVENTORY_CONTROL'  amount: qty × unit_cost
CR: Inventory Adjustment Offset (contra account)        FROM_LINE (adjustment_account_id)
```
For negative adjustments (decrease):
```
DR: Inventory Adjustment Offset                          FROM_LINE (adjustment_account_id)
CR: Inventory Control                                    FROM_SYSTEM_CONFIG 'INVENTORY_CONTROL'
```
- Writes `inventory_movements` record (IN or OUT)
- transaction_type = `'stock_adjustment'` on posting_rule_sets

---

### Asset Depreciation Posting

```
DR: Depreciation Expense (asset_categories.depreciation_expense_account_id)    FROM_ITEM (asset category)
CR: Accumulated Depreciation (fixed_assets.accumulated_depreciation_account_id) FROM_ITEM (fixed asset)
```
- Generated per active asset per depreciation run (see Section 6 — depreciation_runs)
- je_type = `'amortization'` on journal_entries (reuses amortization pattern)
- transaction_type = `'asset_depreciation'` on posting_rule_sets

---

### Asset Disposal Posting

```
DR: Accumulated Depreciation   (full accumulated to date)   FROM_ITEM
DR: Loss on Disposal            [if book value > proceeds]  FROM_SYSTEM_CONFIG or FROM_LINE
CR: Asset at Cost               (original acquisition cost)  FROM_ITEM
CR: Cash / Proceeds Receivable  [if any proceeds]           FROM_LINE
CR: Gain on Disposal            [if proceeds > book value]  FROM_LINE
```
- transaction_type = `'asset_disposal'` on posting_rule_sets
- Writes `asset_disposals` record; updates `fixed_assets.status = 'disposed'`

---

### Bank Fund Transfer Posting

```
DR: Destination Bank Account (bank_fund_transfers.destination_account_id → company_bank_accounts → chart_of_accounts)
CR: Source Bank Account (bank_fund_transfers.source_account_id → company_bank_accounts → chart_of_accounts)
```
- transaction_type = `'bank_fund_transfer'` on posting_rule_sets
- No VAT, no EWT, no subsidiary ledger entries

---

### Sales Credit Memo Posting

```
DR: Sales Returns / Revenue Account   (reverse original revenue)   FROM_ITEM or FROM_LINE
DR: Output VAT Payable (reversed VAT amount)                       FROM_SYSTEM_CONFIG 'OUTPUT_VAT'
CR: Accounts Receivable (AR_TRADE)                                 FROM_SYSTEM_CONFIG 'AR_TRADE'
```
- Writes negative `vat_entries` record (reversal)
- Updates `subsidiary_ledger_entries` (AR credit)
- transaction_type = `'sales_credit_memo'`
---

### Vendor Credit Memo Posting

```
DR: Accounts Payable (AP_TRADE)                                    FROM_SYSTEM_CONFIG 'AP_TRADE'
CR: Purchase Returns / Expense Account  (reverse original cost)    FROM_ITEM or FROM_LINE
CR: Input VAT (reversed input VAT amount)                          FROM_SYSTEM_CONFIG 'INPUT_VAT'
```
- Writes negative `vat_entries` record (reversal of input VAT)
- Updates `subsidiary_ledger_entries` (AP debit)
- transaction_type = `'vendor_credit'`
---

## 8b. Complete Posting Rules — All Remaining Transaction Types (v3.7)

> Every transaction type listed in `posting_rule_sets.transaction_type` has a documented posting rule in Section 8 or Section 8b. No transaction type may be posted without a rule in these sections.

---

### Sales Invoice Posting (AR Created)

**Source document:** `sales_invoices` + `sales_invoice_lines`
**Posting trigger:** `sales_invoices.status` transitions from `'approved'` to `'posted'`

```
DR: Accounts Receivable (sales_invoices.total_amount)              FROM_SYSTEM_CONFIG 'AR_TRADE'
CR: Revenue Account (per sales_invoice_lines.net_amount)           FROM_ITEM (revenue_account_id) or FROM_CUSTOMER (sales_account_id)
CR: Output VAT Payable (per sales_invoice_lines.vat_amount)        FROM_SYSTEM_CONFIG 'OUTPUT_VAT'
CR: EWT Payable (ewt_entries.ewt_amount) [if EWT-subject]          FROM_SYSTEM_CONFIG 'EWT_PAYABLE'
```

**Note on AR amount:** `AR_TRADE` debit = `total_amount - ewt_amount`. EWT withheld by the customer reduces cash receivable; it does NOT reduce the revenue or the VAT — EWT is a pre-payment of the seller's income tax collected at source.

**Journal lines detail:**
- Line 1: DR `AR_TRADE` — `total_amount - ewt_amount` (net receivable after EWT)
- Line 2: CR Revenue per line — `net_amount` (sum across all lines)
- Line 3: CR `OUTPUT_VAT` — `vat_amount` (sum across all vat lines)
- Line 4: CR `EWT_PAYABLE` — `ewt_amount` [only if customer `is_ewt_agent=true`]

**Compliance writes (Step 11):**
- INSERT `vat_entries` (one per line): `vat_direction='output'`, `vat_classification` derived from `customers.party_special_class` ('government' if government, 'zero_rated' if PEZA/BOI/foreign_entity, 'vatable' otherwise)
- INSERT `ewt_entries` (if applicable): payee snapshot from `customer_tax_profiles` effective on `document_date`

**Subsidiary ledger:** INSERT `subsidiary_ledger_entries` with `ledger_type='ar'`, `document_type='sales_invoice'`, `document_id=sales_invoice.id`, `debit_amount=total_amount-ewt_amount`

**Audit write:** INSERT `audit_logs` (`event_type='document_posted'`, `entity_type='sales_invoices'`, `entity_id=sales_invoice.id`)

**Idempotency:** UNIQUE `(company_id, source_document_type, source_document_id) WHERE je_type='system'` on `journal_entries` prevents duplicate posting.

**Period validation:** `document_date` must fall in a `fiscal_period` with `status='open'`. Abort if `'closed'` or `'locked'`.

**Reversal:** Sales Invoice reversal = Sales Credit Memo (separate document). No direct JE reversal of a sales_invoice.

---

### Vendor Bill Posting (AP Created)

**Source document:** `vendor_bills` + `vendor_bill_lines`
**Posting trigger:** `vendor_bills.status` transitions from `'approved'` to `'posted'`

```
DR: Inventory / Expense Account (per vendor_bill_lines.net_amount)   FROM_ITEM or FROM_LINE
DR: Input VAT (per vendor_bill_lines.input_vat_amount)               FROM_SYSTEM_CONFIG 'INPUT_VAT' (or 'INPUT_VAT_CAPITAL_GOODS' if capital goods)
CR: Accounts Payable (vendor_bills.total_amount - ewt_amount)        FROM_SYSTEM_CONFIG 'AP_TRADE'
CR: EWT Payable (ewt_entries.ewt_amount) [if EWT-subject]            FROM_SYSTEM_CONFIG 'EWT_PAYABLE'
CR: FWT Payable (fwt_entries.fwt_amount) [if FWT-subject ATC]        FROM_SYSTEM_CONFIG 'FWT_PAYABLE'
```

**Note on AP amount:** `AP_TRADE` credit = `total_amount - ewt_amount` (or `- fwt_amount`). The net amount owed to the supplier is reduced by the withholding tax the company is obligated to remit to BIR on the supplier's behalf.

**VAT routing (per line):**
- `vat_classification='vatable'` → `INPUT_VAT`
- `vat_classification='capital_goods'` → `INPUT_VAT_CAPITAL_GOODS` (if input_vat_amount > 1,000,000, Phase 1 books full amount here; accountant computes monthly amortization manually on 2550M)
- `vat_classification='services'` → `INPUT_VAT` (services VAT treated same as standard input VAT in Phase 1)
- `vat_classification='zero_rated'` or `'exempt'` → no VAT entry

**Compliance writes (Step 11):**
- INSERT `vat_entries` (one per taxable line): `vat_direction='input'`
- INSERT `ewt_entries` (one per EWT-subject line): ATC from `vendor_bill_lines.ewt_atc_id`; payee snapshot from `supplier_tax_profiles` effective on `document_date`
- INSERT `fwt_entries` (one per FWT-subject line): ATC starts with 'WF'

**Subsidiary ledger:** INSERT `subsidiary_ledger_entries` with `ledger_type='ap'`, `document_type='vendor_bill'`, `credit_amount=total_amount-ewt_amount`

**Audit/Idempotency/Period/Reversal:** Same pattern as Sales Invoice. Reversal = Vendor Credit Memo (separate document).

---

### Receipt Posting (AR Collection)

**Source document:** `receipts` (official receipts, collection receipts)
**Posting trigger:** `receipts.status` transitions from `'approved'` to `'posted'`

```
DR: Cash / Bank (receipts.amount_received)                          FROM_LINE (receipts.bank_account_id → gl_account) or FROM_SYSTEM_CONFIG 'CASH_ON_HAND'
CR: Accounts Receivable (receipts.amount_applied)                   FROM_SYSTEM_CONFIG 'AR_TRADE'
CR: Unearned Discount (if early-payment discount applied)           FROM_LINE (discount_account_id)
```

**Application logic:**
- A receipt applies to one or more open `subsidiary_ledger_entries` (AR). The `amount_applied` per invoice is recorded via `document_relationships` (relationship_type='paid_by') linking receipt to sales_invoice.
- After posting: UPDATE `subsidiary_ledger_entries.is_open = false` for fully applied AR lines. For partial applications, the `amount_applied` column on the subsidiary ledger entry tracks remaining balance.
- `receipts.unapplied_amount = amount_received - total(amount_applied)` → if > 0, a credit to Advances from Customers (unearned revenue account) is posted.

**Compliance writes (Step 11):**
- No new `vat_entries` — VAT was already captured at sales_invoice posting.
- If receipt issues an Official Receipt under BIR's CAS: ATP series number must be pre-allocated (`atp_series_allocations`); number written to `receipts.or_number`.

**Subsidiary ledger:** UPDATE/close `subsidiary_ledger_entries` records that are fully settled.

**Period/Idempotency/Audit:** Standard pattern.

**Reversal:** If receipt is voided, reverse JE: DR AR_TRADE / CR Cash. INSERT `document_void_register`.

---

### Payment Voucher Posting (AP Payment)

**Source document:** `payment_vouchers` + `payment_voucher_lines`
**Posting trigger:** `payment_vouchers.status` transitions from `'approved'` to `'posted'`

```
DR: Accounts Payable (payment_vouchers.total_amount - ewt_amount)    FROM_SYSTEM_CONFIG 'AP_TRADE'
DR: EWT Payable (ewt_entries.ewt_amount) [if EWT was pre-booked]     FROM_SYSTEM_CONFIG 'EWT_PAYABLE'
CR: Cash / Bank (net_amount_paid)                                     FROM_LINE (bank_account_id → gl_account)
```

**EWT detection algorithm (determines which path to execute):**
- Query: `SELECT COUNT(*) FROM ewt_entries WHERE source_document_id = (linked vendor_bill_id) AND source_document_type = 'vendor_bill'`
- If COUNT > 0 → EWT was pre-booked at bill posting → PATH A
- If COUNT = 0 → EWT was not pre-booked → PATH B
- PATH A (EWT pre-booked): DR `EWT_PAYABLE` (clears the existing liability), no new ewt_entries INSERT. The `payment_voucher_lines.ewt_atc_id` must match the ATC from the original bill's ewt_entries.
- PATH B (EWT not pre-booked, e.g., PV issued directly without prior bill): CR `EWT_PAYABLE` + INSERT `ewt_entries` at this step with source_document_type='payment_voucher'.
- `net_amount_paid = total_amount - ewt_amount` (cash actually transferred to supplier).

**Application logic:** Links to one or more `vendor_bills` via `document_relationships` (relationship_type='paid_by'). After posting: UPDATE `subsidiary_ledger_entries.is_open = false` for fully applied AP lines.

**Compliance writes (Step 11):**
- If EWT first booked here (not at bill): INSERT `ewt_entries`.
- INSERT `audit_logs` (`event_type='document_posted'`).

**Subsidiary ledger:** UPDATE/close `subsidiary_ledger_entries` (AP) for applied bills.

**Period/Idempotency/Reversal:** Standard pattern. Reversal = void the PV; reverse JE re-opens the AP lines.

---

### Petty Cash Replenishment Posting

**Source document:** `petty_cash_replenishments`
**Posting trigger:** `petty_cash_replenishments.status` transitions from `'approved'` to `'posted'`

```
DR: Petty Cash Fund (petty_cash_funds.account_id)                   FROM_LINE (petty_cash_fund_id → account)
CR: Cash in Bank (replenishment check account)                       FROM_LINE (bank_account_id → gl_account) or FROM_SYSTEM_CONFIG 'CASH_IN_BANK'
```

**Logic:** A petty cash replenishment restores the petty cash fund to its imprest amount. The total replenishment amount = sum of all fully posted petty cash vouchers since last replenishment. The individual expenses were already posted at voucher time (DR Expense / CR Petty Cash Fund). The replenishment reverses the cash fund depletion: DR Petty Cash Fund / CR Bank.

**Compliance:** No VAT or EWT entries — those were captured at individual voucher posting.

**Audit:** INSERT `audit_logs` (`event_type='document_posted'`). Link replenishment to vouchers via `document_relationships` (relationship_type='replenished_by').

**Period/Idempotency/Reversal:** Standard pattern.

---

### Customer Return Posting

**Source document:** `customer_returns` (goods returned by customer)
**Posting trigger:** `customer_returns.status` transitions from `'approved'` to `'posted'`

```
DR: Sales Returns / Revenue Account (customer_return_lines.net_amount)      FROM_LINE (contra_revenue_account_id)
DR: Output VAT Payable (reversed VAT)                                        FROM_SYSTEM_CONFIG 'OUTPUT_VAT'
CR: Accounts Receivable (AR_TRADE)                                           FROM_SYSTEM_CONFIG 'AR_TRADE'
```

**Inventory (if item is tracked):**
```
DR: Inventory Control (qty × unit_cost)                                      FROM_SYSTEM_CONFIG 'INVENTORY_CONTROL'
CR: COGS (reversed COGS for returned goods)                                  FROM_SYSTEM_CONFIG 'COST_OF_GOODS_SOLD'
```

**Compliance writes (Step 11):**
- INSERT negative `vat_entries` (reversal of original output VAT).
- INSERT `inventory_movements` (type='return_in', direction='IN').

**Subsidiary ledger:** INSERT/UPDATE `subsidiary_ledger_entries` (AR credit to reduce receivable). Links to original `sales_invoice` via `document_relationships` (relationship_type='reversed_by').

**Period/Idempotency/Audit/Reversal:** Standard pattern.

---

### Purchase Return Posting

**Source document:** `purchase_returns` (goods returned to supplier)
**Posting trigger:** `purchase_returns.status` transitions from `'approved'` to `'posted'`

```
DR: Accounts Payable (AP_TRADE)                                              FROM_SYSTEM_CONFIG 'AP_TRADE'
CR: Inventory / Expense Account (purchase_return_lines.net_amount)           FROM_ITEM or FROM_LINE
CR: Input VAT (reversed input VAT)                                           FROM_SYSTEM_CONFIG 'INPUT_VAT'
```

**Inventory (if item is tracked):**
```
DR: COGS (reversed COGS for returned goods)                                  FROM_SYSTEM_CONFIG 'COST_OF_GOODS_SOLD'
CR: Inventory Control (qty × unit_cost)                                      FROM_SYSTEM_CONFIG 'INVENTORY_CONTROL'
```

**Compliance writes (Step 11):**
- INSERT negative `vat_entries` (reversal of input VAT).
- INSERT `inventory_movements` (type='return_out', direction='OUT').

**Subsidiary ledger:** INSERT `subsidiary_ledger_entries` (AP debit to reduce payable). Links to original `vendor_bill` via `document_relationships` (relationship_type='reversed_by').

**Period/Idempotency/Audit/Reversal:** Standard pattern.

---

### Sales Debit Memo Posting

**Source document:** `sales_debit_memos` (issued to customer to increase amount owed)
**Posting trigger:** `sales_debit_memos.status` transitions from `'approved'` to `'posted'`

```
DR: Accounts Receivable (AR_TRADE)                                           FROM_SYSTEM_CONFIG 'AR_TRADE'
CR: Revenue Account (per lines.net_amount)                                   FROM_ITEM or FROM_LINE
CR: Output VAT (per lines.vat_amount)                                        FROM_SYSTEM_CONFIG 'OUTPUT_VAT'
```

**Use case:** Issued when the original invoice undercharged the customer, or to bill for additional charges (freight, penalties). Treated as an additional receivable.

**Compliance writes (Step 11):** INSERT positive `vat_entries` (additional output VAT).

**Subsidiary ledger:** INSERT `subsidiary_ledger_entries` (AR debit — increases receivable). Links to original sales_invoice or standalone.

**Period/Idempotency/Audit/Reversal:** Standard pattern.

---

### Supplier Debit Memo Posting

**Source document:** `supplier_debit_memos` (issued by us to supplier — we claim a credit from them)
**Posting trigger:** `supplier_debit_memos.status` transitions from `'approved'` to `'posted'`

```
DR: Accounts Payable (AP_TRADE)                                              FROM_SYSTEM_CONFIG 'AP_TRADE'
CR: Purchase Returns / Expense Adjustment (per lines.net_amount)             FROM_LINE
CR: Input VAT (reversed input VAT if applicable)                             FROM_SYSTEM_CONFIG 'INPUT_VAT'
```

**Use case:** Issued when the original vendor bill overcharged us, or to claim a penalty against the supplier. Reduces our AP balance.

**Compliance writes (Step 11):** INSERT negative `vat_entries` (input VAT reduction) if applicable.

**Subsidiary ledger:** INSERT `subsidiary_ledger_entries` (AP debit — reduces payable). Links to original vendor_bill if applicable.

**Period/Idempotency/Audit/Reversal:** Standard pattern.

---

### Asset Acquisition Posting

**Source document:** `fixed_assets` record created with acquisition data; OR `vendor_bill` with `is_asset_acquisition=true` flag (Phase 1: asset creation linked to vendor bill)
**Posting trigger:** Asset `status` transitions from `'pending'` to `'active'`; OR vendor_bill posting that creates a fixed asset record.

**Pattern A — Direct asset acquisition (cash purchase):**
```
DR: Fixed Asset at Cost (fixed_assets.acquisition_cost)                      FROM_LINE (fixed_assets.asset_account_id)
CR: Cash / Bank                                                               FROM_SYSTEM_CONFIG 'CASH_IN_BANK' or 'CASH_ON_HAND'
DR: Input VAT (vat_amount, if applicable)                                     FROM_SYSTEM_CONFIG 'INPUT_VAT_CAPITAL_GOODS'
```

**Pattern B — Asset acquired via vendor bill:**
The vendor_bill posting handles the AP side (DR Asset Account / DR Input VAT / CR AP_TRADE). No separate JE is posted at asset activation — the vendor_bill post IS the acquisition post. Asset record is created and linked to the vendor_bill via `document_relationships` (relationship_type='billed_from').

**Depreciation schedule:** After posting, the system auto-creates `asset_depreciation_schedules` and `asset_depreciation_schedule_lines` based on `fixed_assets.depreciation_method`, `useful_life_months`, `salvage_value`, and `acquisition_date`. This is a record creation, not a posting step.

**Compliance writes:** INSERT `vat_entries` if applicable (same as vendor_bill pattern).

**Audit:** INSERT `audit_logs` (`event_type='asset_acquired'`).

---

### Bank Adjustment Posting

**Source document:** `bank_adjustments` (reconciliation adjustments, bank charges, interest earned, error corrections)
**Posting trigger:** `bank_adjustments.status` transitions from `'approved'` to `'posted'`

```
DR: [debit_account_id]   (bank_adjustments.debit_account_id)                FROM_LINE
CR: [credit_account_id]  (bank_adjustments.credit_account_id)               FROM_LINE
```

**Use cases:**
- Bank service charge: DR Bank Charges Expense / CR Cash in Bank
- Interest earned: DR Cash in Bank / CR Interest Income
- NSF check (bounced check): DR AR_TRADE (re-open) / CR Cash in Bank
- Error correction: DR/CR as needed with `adjustment_reason` text

**No compliance entries** (no VAT, no EWT) unless the adjustment involves a taxable item (e.g., bank interest may be subject to FWT in some cases — accountant must manually create a separate FWT entry in that case via Journal Entry; Phase 1 does not auto-detect).

**Audit:** INSERT `audit_logs` (`event_type='document_posted'`).

**Period/Idempotency/Reversal:** Standard pattern.

---

### Stock Transfer Posting

**Source document:** `stock_transfers` (movement between warehouses within same company)
**Posting trigger:** `stock_transfers.status` transitions from `'approved'` to `'posted'`

```
DR: Inventory Control — Destination Warehouse   (qty × unit_cost)            FROM_SYSTEM_CONFIG 'INVENTORY_CONTROL' with branch_id = destination_branch_id
CR: Inventory Control — Source Warehouse        (qty × unit_cost)            FROM_SYSTEM_CONFIG 'INVENTORY_CONTROL' with branch_id = source_branch_id
```

**Note:** If source and destination are in the same branch (warehouse to warehouse within same branch), only `inventory_movements` are created — no JE needed (no GL account change). If source and destination are in different branches, the posting engine creates two JE lines to reflect the inter-branch inventory movement in each branch's GL.

**Compliance writes:** INSERT two `inventory_movements` records (type='transfer_out' for source, type='transfer_in' for destination).

**No VAT, no EWT.** Intra-company stock transfer is not a taxable event.

**Audit/Period/Idempotency/Reversal:** Standard pattern.

---

### Inter-Branch Transfer Posting

**Source document:** `inter_branch_transfers` (table #102 — cash/fund transfers between company branches)
**Posting trigger:** `inter_branch_transfers.status` transitions from `'approved'` to `'posted'`

```
DR: Inter-Branch Receivable / Cash — Destination Branch                      FROM_LINE (destination_account_id or CASH_IN_BANK for destination branch)
CR: Inter-Branch Payable / Cash — Source Branch                              FROM_LINE (source_account_id or CASH_IN_BANK for source branch)
```

**Note:** This covers CASH fund movement between branches (e.g., Head Office sends funds to Branch). Distinct from `bank_fund_transfers` (#101) which covers transfers between bank accounts. For Phase 1 (company-level RLS, no branch-level books), the JE uses two lines with different `branch_id` dimension values — the branch filter is application-layer only.

**No VAT, no EWT.** Intra-company fund transfer is not a taxable event.

**Audit/Period/Idempotency/Reversal:** Standard pattern.

---

## 9. CPA-Correct Period-End Closing Sequence (v3.2)

> Required before `fiscal_periods.status` can be set to `'locked'`. Steps must be executed in this order. Each step is idempotent and resumable.

```
PERIOD-END SEQUENCE — recommended order for Philippine MSME:

1.  ENSURE all source documents for the period are finalized (invoices, bills, ORs, DVs)
    → Check: no documents with status = 'draft' or 'approved' dated in the closing period

2.  POST all pending approved documents
    → Run bulk_post_batch for each document type in order: sales_invoices, vendor_bills,
       receipts, payment_vouchers, cash_sales, cash_purchases, petty_cash_vouchers

3.  RUN amortization (prepaid expenses / deferred charges)
    → amortization_runs for all active amortization_schedules with lines due this period

4.  RUN revenue recognition (deferred revenue schedules)
    → revenue_recognition_runs for all active revenue_recognition_schedules due this period

5.  POST accrual journal entries (manual or recurring templates)
    → Process recurring_journal_templates with frequency matching current period
    → Accountant reviews and approves manual accruals before posting

6.  RUN depreciation
    → depreciation_runs for all active fixed_assets (straight_line, declining_balance, UOP)

7.  REVIEW and post adjusting journal entries
    → Accountant inputs: reclassifications, corrections, additional accruals

8.  REVIEW reversing entries scheduled for next period
    → Confirm auto_reversal_flag entries from prior period will reverse on 1st of next period

9.  GENERATE tax working papers
    → VAT: vat_period_summaries → review output/input/net payable
    → EWT: ewt_period_summaries → review withholding obligation
    → PT: percentage_tax_period_summaries (if applicable)
    → Income Tax: itr_computation_runs → taxable income preview

10. RECONCILE subledgers
    → AR: trial balance AR_CONTROL vs sum(subsidiary_ledger_entries WHERE ledger_type='ar' AND is_open=true)
    → AP: trial balance AP_CONTROL vs sum(subsidiary_ledger_entries WHERE ledger_type='ap' AND is_open=true)
    → Inventory: inventory_balances vs sum(inventory_movements) by item/warehouse
    → Fixed Assets: fixed_assets.net_book_value vs depreciation_schedules

11. REVIEW trial balance
    → Generate trial balance from gl_balances (all accounts, current period)
    → Verify total debits = total credits
    → CPA reviews and signs off

12. CERTIFY subledger close
    → INSERT subledger_close_certifications (one per subledger type: AR, AP, INV, FA)
    → certified_by must be a user with CONTROLLER or COMPANY_ADMIN role

13. LOCK fiscal period
    → INSERT fiscal_locks (company_id, fiscal_period_id, locked_by)
    → fiscal_periods.status → 'locked'
    → No further posting allowed; any correction requires fiscal_locks unlock (with reason)
```

**Period-end validation rules:**
- Steps 3–6 (amortization, revenue recognition, depreciation) are non-blocking if no active schedules exist.
- Steps 1–2 are blocking — do not close until all period documents are posted.
- Step 12 (subledger certification) is a control gate — required for CAS compliance.
- Step 13 (lock) is irreversible without explicit unlock (which requires `unlock_reason`).

---

## 10. Amortization Run Posting Process (Enhancement Round)

The amortization run is an async batch operation (Principle 17). It processes all active `amortization_schedule_lines` where `fiscal_period_id` matches the target period and `status = 'pending'`.

```
1.  INSERT amortization_runs (status='processing', run_by, run_at)
2.  FOR EACH amortization_schedule_line (target period, status='pending'):
    a. CHECK fiscal period is OPEN (abort line if CLOSED)
    b. LOAD amortization_schedule:
       - debit_account  = amortization_schedules.expense_account_id
       - credit_account = amortization_schedules.prepaid_account_id
       - amount         = amortization_schedule_lines.period_amount
    c. INSERT journal_entries:
       - je_type             = 'amortization'
       - source_document_type = 'amortization_schedules'
       - source_document_id   = amortization_schedule_id
       - amortization_run_detail_id = [set after step d]
    d. INSERT journal_lines:
       - DR [expense_account_id] period_amount
       - CR [prepaid_account_id] period_amount
    e. UPSERT gl_balances (expense account DR, prepaid account CR)
    f. INSERT amortization_run_details:
       - run_id, amortization_schedule_id, amortization_schedule_line_id
       - journal_entry_id = (JE created in step c)
       - status = 'success'
    g. UPDATE amortization_schedule_lines: status='processed', journal_entry_id=(JE id)
    h. UPDATE amortization_schedules.amount_amortized += period_amount
    i. INSERT audit_logs (event_type='AMORTIZATION_ENTRY_CREATED')
3.  UPDATE amortization_runs: status='completed', entries_created=N, completed_at=now()
4.  INSERT audit_logs (event_type='AMORTIZATION_RUN_COMPLETED')
```

**No posting_rule_sets used.** Amortization entries are hard-coded DR expense / CR prepaid using account IDs from the schedule. The posting rule is embedded in the schedule itself.

---

## 11. Revenue Recognition Run Posting Process (Enhancement Round)

Same pattern as amortization. Processes all active `revenue_recognition_schedule_lines` for the target period.

```
DR [deferred_revenue_account_id] period_amount
CR [revenue_account_id]          period_amount
```

- `je_type = 'revenue_recognition'`
- `revenue_recognition_run_detail_id` set on the generated JE
- `source_document_type = 'revenue_recognition_schedules'`
- Traceability: revenue_recognition_schedules → lines → runs → run_details → journal_entries → journal_lines → gl_balances

---

## 12. Auto Reversal Run Process (Enhancement Round)

Executed at the start of each fiscal period. Processes all `journal_entries` where:
- `auto_reversal_flag = true`
- `auto_reversal_date` falls within the new period (or = today)
- `auto_reversal_run_id IS NULL` (not yet reversed)
- `status = 'posted'`

```
1.  INSERT auto_reversal_runs (status='processing', fiscal_period_id, run_by)
2.  FOR EACH qualifying journal_entry:
    a. CHECK fiscal period of auto_reversal_date is OPEN
    b. INSERT journal_entries (reversal):
       - je_type             = 'auto_reversal'
       - is_auto_reversal    = true
       - reversal_of_je_id   = original JE id
       - auto_reversal_run_id = current run id
       - document_date       = auto_reversal_date
       - description         = 'Auto-reversal of: ' + original description
    c. INSERT journal_lines (all lines DR/CR swapped):
       - debit_amount  = original credit_amount
       - credit_amount = original debit_amount
    d. UPSERT gl_balances (reversed per account)
    e. UPDATE original journal_entry:
       - reversed_by_je_id   = new reversal JE id
       - auto_reversal_run_id = current run id
    f. INSERT audit_logs (event_type='AUTO_REVERSAL_CREATED')
3.  UPDATE auto_reversal_runs: status='completed', entries_reversed=N
4.  INSERT audit_logs (event_type='AUTO_REVERSAL_RUN_COMPLETED')
```

**Applicable to all source JE types:** manual accruals, system-generated recurring JEs with auto_reverse=true, and any JE marked auto_reversal_flag=true.

---

## 13. Year-End Closing Process (v3.8)

> **Prerequisite:** ALL fiscal periods for the fiscal year must have `status='locked'` before year-end close can execute. The year-end close process locks the fiscal year itself.

### Year-End Closing JE Sequence

Year-end closing transfers net income to Retained Earnings and resets nominal accounts (Revenue, Expense, COGS) to zero. This is a 3-step JE sequence executed in a single database transaction.

```
STEP 1 — Close Revenue and Other Income to Income Summary
  DR: Each Revenue account (reverse their credit balances)   FROM gl_balances for fiscal_year
  DR: Each Other Income account (reverse their credit balances)
  CR: Income Summary (FROM_SYSTEM_CONFIG 'INCOME_SUMMARY')
  → Amount per account = SUM(period_credit - period_debit) for all periods in fiscal_year WHERE account_type IN ('revenue','other_income','contra_expense')

STEP 2 — Close Expense Accounts to Income Summary
  DR: Income Summary (FROM_SYSTEM_CONFIG 'INCOME_SUMMARY')
  CR: Each Expense account (reverse their debit balances)
  CR: Each COGS account (reverse their debit balances)
  CR: Each Other Expense account (reverse their debit balances)
  → Amount per account = SUM(period_debit - period_credit) for all periods in fiscal_year WHERE account_type IN ('expense','cost_of_sales','other_expense','contra_revenue')

STEP 3 — Close Income Summary to Retained Earnings
  IF Income Summary balance > 0 (net income):
    DR: Income Summary (FROM_SYSTEM_CONFIG 'INCOME_SUMMARY')
    CR: Retained Earnings (FROM_SYSTEM_CONFIG 'RETAINED_EARNINGS')
    → Amount = net income for the fiscal year
  IF Income Summary balance < 0 (net loss):
    DR: Retained Earnings (FROM_SYSTEM_CONFIG 'RETAINED_EARNINGS')
    CR: Income Summary (FROM_SYSTEM_CONFIG 'INCOME_SUMMARY')
    → Amount = net loss (absolute value)
```

**Implementation rules:**
- `je_type = 'closing'` on all three closing JEs
- `source_document_type = 'fiscal_years'`, `source_document_id = fiscal_year.id`
- All three JEs must be posted in one DB transaction; if any step fails, all three roll back
- UPSERT `gl_balances` for each closing line (these will show in the Balance Sheet)
- After posting all three closing JEs:
  - UPDATE `fiscal_years.status = 'closed'`
  - If company policy requires: UPDATE `fiscal_years.status = 'locked'` immediately (no further adjustments)
- INSERT `audit_logs` (event_type='YEAR_END_CLOSE_COMPLETED', entity_type='fiscal_years', entity_id=fiscal_year.id)
- Idempotency: check `journal_entries WHERE source_document_type='fiscal_years' AND source_document_id=fiscal_year.id AND je_type='closing'` before executing — abort if already found

### Year-End Close Trigger

Year-end close is initiated manually by a user with CONTROLLER or COMPANY_ADMIN role. It is NOT automated. The user navigates to Fiscal Year → [Year] → Close Year. The system validates:
1. All 12 (or 13) fiscal periods for the year are `status='locked'`
2. No open or approved (unposted) documents remain in the year
3. Depreciation run completed for the last period
4. Amortization run completed for the last period

If any validation fails, the close is aborted with a specific error message.

### Post-Close Behavior

- Opening balances for the new fiscal year are NOT automatically created. The `opening_balances` table carries forward Balance Sheet accounts manually or via a "New Year Opening" process where the accountant reviews and posts opening JEs (`je_type='opening'`).
- The Retained Earnings balance after closing = prior Retained Earnings + current year net income (or − net loss).
- Revenue, Expense, COGS accounts show zero balance in the new fiscal year — confirmed because closing JEs zero them out in `gl_balances`.

---

## 14. Background Jobs (Scheduled Processes)

> **Platform:** Supabase pg_cron. All jobs run under service role. Failure is logged to `import_batches` (for import jobs) or `audit_logs` (for compliance jobs). Each job is idempotent.

| Job Name | Schedule | Trigger | Description | Idempotency |
|---|---|---|---|---|
| `recurring_journal_generator` | Daily, 00:05 AM | pg_cron | Processes `recurring_journal_templates` with `next_run_date = today`. Generates JEs, updates `next_run_date`. | CHECK for existing JE with `recurring_template_id + fiscal_period_id` before INSERT |
| `auto_reversal_processor` | Daily, 00:10 AM | pg_cron | Processes `journal_entries WHERE auto_reversal_flag=true AND auto_reversal_date=today AND auto_reversal_run_id IS NULL`. | `auto_reversal_run_id` set after processing prevents reprocessing |
| `atp_gap_detector` | Nightly, 02:00 AM | pg_cron | Checks `atp_usage_logs` for gaps in OR/invoice sequences (skipped numbers). Inserts `system_alerts` for any detected gaps. | Checks last_checked_number stored on `number_series`; only scans new numbers |
| `notification_cleanup` | Nightly, 03:00 AM | pg_cron | Soft-deletes `notifications` older than 90 days where `is_read=true`. | Idempotent DELETE by date threshold |
| `export_job_processor` | Continuous (Edge Function triggered by `export_jobs` INSERT via Supabase Realtime) | INSERT on `export_jobs` | Processes pending `export_jobs` (SLSP, RELIEF, QAP, SAWT, DAT). Sets status 'processing' then 'completed' or 'failed'. | `export_jobs.status` prevents re-processing; UNIQUE job key per request |
| `import_job_processor` | Continuous (Edge Function triggered by `import_batches` INSERT) | INSERT on `import_batches` | Processes pending import batches for all master data types. | `import_batches.status` gate; row-level idempotency via external_id if provided |
| `depreciation_runner` | Manual (triggered by user from Period Close Checklist) | User action | Processes `asset_depreciation_schedule_lines` for target period. See Section 10 (amortization pattern — same process). | `depreciation_schedule_lines.status='processed'` prevents re-run |
| `vat_period_summary_refresh` | On-demand (called by posting engine — Step 11e) | Posting transaction | UPSERT `vat_period_summaries` per posted document. No standalone job needed — summaries are maintained in real time by the posting engine. | UPSERT ON CONFLICT DO UPDATE — inherently idempotent |

**Failure handling:** If a pg_cron job fails, Supabase logs the error to pg_cron.job_run_details. The system also INSERTs a `system_alerts` record with `alert_type='job_failure'`, `entity_type='cron_job'`, `message=error_text`. The alert appears on the admin dashboard. Jobs retry on next scheduled execution.

**Retry logic (export/import Edge Functions):** On failure, `export_jobs.status` is set to 'failed' with `error_message`. The user can manually re-trigger. No automatic retry — prevents duplicate file generation.
