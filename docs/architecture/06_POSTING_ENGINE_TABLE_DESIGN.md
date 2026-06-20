# PXL ERP — Posting Engine Table Design
**Version:** 2.0 — Revised for Implementation Readiness
**Status:** For CPA and Developer Review

---

## Changes Applied (v1 → v2)

- Added Cash Sales (`cash_sales`) and Cash Purchases (`cash_purchases`) as valid `transaction_type` values on `posting_rule_sets`
- Added notification dispatch as Step 13 in posting engine process flow
- Updated `journal_entries.document_number` → `document_no`; `entry_date` → `document_date`
- Updated `subsidiary_ledger_entries.document_number` → `document_no`
- Clarified that Cash Sales and Cash Purchases do NOT create `subsidiary_ledger_entries` (no AR/AP impact)
- Added `source_document_type` values for `cash_sale` and `cash_purchase` to `journal_entries`
- Added `period_close_checklist_id` as optional link from posting step to period close context
- Updated posting process flow to reference `notifications` dispatch after audit log insert
- Added "Posting Rules for Cash Sales and Cash Purchases" section (Section 8)
- Confirmed `posting_rule_sets` table name (was `posting_rules` in v1 doc 02 — now consistent)

---

## Open Decisions Remaining

| OD # | Question | Status |
|---|---|---|
| OD-13 | Should the posting engine write `vat_entries` and `ewt_entries` directly, or should those be written by the source document save step before posting? | Recommended: written at document SAVE (before posting), read by posting engine at post time. Confirm before Edge Function implementation. |
| OD-14 | Should `recurring_journal_template_lines` support dynamic amounts (e.g., percentage of another account balance)? | Phase 2 — Phase 1 supports fixed amounts only. |

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
Defines the top-level rule set for each transaction type.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `rule_set_code` | text | UNIQUE per company, NOT NULL | e.g., 'SALES_INV_VAT', 'PV_EWT', 'CASH_SALE_VAT', 'CASH_PUR_EWT' |
| `transaction_type` | text | NOT NULL | See transaction types below |
| `description` | text | NULL | |
| `is_active` | boolean | NOT NULL DEFAULT true | |
| `is_system` | boolean | NOT NULL DEFAULT false | System rules cannot be deleted |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |
| `created_by` | uuid | FK auth.users | |
| `updated_at` | timestamptz | NULL | |
| `updated_by` | uuid | FK auth.users | |

**Valid `transaction_type` values:**
`sales_invoice` | `vendor_bill` | `receipt` | `payment_voucher` | `cash_sale` | `cash_purchase` | `petty_cash_voucher` | `inventory_adjustment` | `asset_depreciation` | `bank_deposit` | `bank_withdrawal` | `bank_transfer` | `journal_entry` | `stock_transfer` | `asset_disposal`

---

### `posting_rule_lines`
Each line in a rule set defines one DR or CR entry.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `rule_set_id` | uuid | FK posting_rule_sets, NOT NULL | |
| `line_order` | integer | NOT NULL | Execution order |
| `entry_side` | text | CHECK IN ('DEBIT','CREDIT'), NOT NULL | |
| `account_source` | text | NOT NULL | 'FIXED' \| 'FROM_ITEM' \| 'FROM_CUSTOMER' \| 'FROM_SUPPLIER' \| 'FROM_RULE_PARAM' \| 'FROM_SYSTEM_CONFIG' |
| `fixed_account_id` | uuid | FK chart_of_accounts, NULL | Used if account_source='FIXED' |
| `account_config_key` | text | NULL | Used if account_source='FROM_SYSTEM_CONFIG'; e.g., 'AR_TRADE', 'OUTPUT_VAT', 'AP_TRADE', 'CASH_ON_HAND' |
| `amount_source` | text | NOT NULL | 'LINE_SUBTOTAL' \| 'LINE_VAT' \| 'LINE_EWT' \| 'HEADER_TOTAL' \| 'COMPUTED' |
| `amount_formula` | text | NULL | SQL expression for computed amounts |
| `applies_to` | text | NOT NULL DEFAULT 'ALL' | 'ALL' \| 'VAT_LINES_ONLY' \| 'EWT_LINES_ONLY' \| 'ZERO_VAT_LINES' |
| `creates_subsidiary_ledger` | boolean | NOT NULL DEFAULT false | Whether this line creates a subsidiary_ledger_entry |
| `subsidiary_ledger_type` | text | NULL | 'AR' \| 'AP' \| 'INVENTORY' \| 'FIXED_ASSET' — NULL for cash_sale/cash_purchase lines |
| `use_branch_dimension` | boolean | NOT NULL DEFAULT true | |
| `use_department_dimension` | boolean | NOT NULL DEFAULT false | |
| `use_cost_center_dimension` | boolean | NOT NULL DEFAULT false | |
| `description_template` | text | NULL | e.g., 'Sales Invoice {doc_no} - {customer_name}' |

---

### `system_account_config`
Maps semantic account keys to actual GL accounts per company.

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

**Standard config keys:**
`AR_TRADE` | `AP_TRADE` | `OUTPUT_VAT` | `INPUT_VAT` | `INPUT_VAT_DEFERRED` | `INPUT_VAT_CAPITAL_GOODS` | `EWT_PAYABLE` | `CASH_ON_HAND` | `CASH_IN_BANK` | `INVENTORY_CONTROL` | `COST_OF_GOODS_SOLD` | `RETAINED_EARNINGS` | `INCOME_SUMMARY`

---

## 3. Journal Entry Tables

### `journal_entries`
Header record for every set of balanced DR/CR lines.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `branch_id` | uuid | FK branches, NULL | |
| `document_date` | date | NOT NULL | Accounting date |
| `document_no` | text | NOT NULL | System-assigned JE number |
| `entry_type` | text | NOT NULL | 'AUTO' \| 'MANUAL' \| 'REVERSAL' \| 'OPENING' \| 'RECURRING' \| 'ADJUSTMENT' |
| `fiscal_year_id` | uuid | FK fiscal_years, NOT NULL | |
| `fiscal_period_id` | uuid | FK fiscal_periods, NOT NULL | |
| `source_document_type` | text | NULL | 'sales_invoice' \| 'vendor_bill' \| 'receipt' \| 'payment_voucher' \| 'cash_sale' \| 'cash_purchase' \| 'petty_cash_voucher' \| 'inventory_adjustment' \| 'asset_depreciation' \| 'bank_deposit' \| 'bank_withdrawal' \| 'bank_transfer' \| 'asset_disposal' |
| `source_document_id` | uuid | NULL | FK to the source document |
| `rule_set_id` | uuid | FK posting_rule_sets, NULL | NULL for manual JEs |
| `description` | text | NOT NULL | |
| `reference` | text | NULL | External reference |
| `currency_code` | text | NOT NULL DEFAULT 'PHP' | |
| `exchange_rate` | numeric(10,6) | NOT NULL DEFAULT 1 | |
| `status` | text | CHECK IN ('DRAFT','POSTED','REVERSED') | |
| `posted_at` | timestamptz | NULL | When POSTED |
| `posted_by` | uuid | FK auth.users, NULL | |
| `reversed_by_entry_id` | uuid | FK journal_entries, NULL | |
| `reversal_of_entry_id` | uuid | FK journal_entries, NULL | |
| `recurring_template_id` | uuid | FK recurring_journal_templates, NULL | |
| `notes` | text | NULL | |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |
| `created_by` | uuid | FK auth.users, NOT NULL | |
| `updated_at` | timestamptz | NULL | |
| `updated_by` | uuid | FK auth.users | |

CONSTRAINT: Cannot update any column if `status = 'POSTED'` — enforced by `enforce_posted_immutability()` trigger.

---

### `journal_lines`
Individual debit/credit lines within a journal entry.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `journal_entry_id` | uuid | FK journal_entries, NOT NULL | |
| `line_number` | integer | NOT NULL | Order within entry |
| `account_id` | uuid | FK chart_of_accounts, NOT NULL | |
| `branch_id` | uuid | FK branches, NULL | |
| `department_id` | uuid | FK departments, NULL | |
| `cost_center_id` | uuid | FK cost_centers, NULL | |
| `debit_amount` | numeric(18,4) | NOT NULL DEFAULT 0 | |
| `credit_amount` | numeric(18,4) | NOT NULL DEFAULT 0 | |
| `base_currency_debit` | numeric(18,4) | NOT NULL DEFAULT 0 | PHP equivalent |
| `base_currency_credit` | numeric(18,4) | NOT NULL DEFAULT 0 | PHP equivalent |
| `description` | text | NOT NULL | |
| `subsidiary_ledger_type` | text | NULL | 'AR' \| 'AP' \| 'INVENTORY' \| 'FIXED_ASSET' |
| `subsidiary_entity_type` | text | NULL | 'customer' \| 'supplier' \| 'item' \| 'fixed_asset' |
| `subsidiary_entity_id` | uuid | NULL | FK to respective entity |
| `source_line_type` | text | NULL | 'invoice_line' \| 'vat_entry' \| 'ewt_entry' \| 'header' |
| `source_line_id` | uuid | NULL | FK to source line |

CONSTRAINT: `CHECK (debit_amount = 0 OR credit_amount = 0)` — a line is either DR or CR, not both.
CONSTRAINT per entry: `SUM(debit_amount) = SUM(credit_amount)` — enforced by posting engine before commit.

---

### `gl_balances`
Materialized running balances per account per period.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `account_id` | uuid | FK chart_of_accounts, NOT NULL | |
| `branch_id` | uuid | FK branches, NULL | NULL = company-wide |
| `fiscal_year_id` | uuid | FK fiscal_years, NOT NULL | |
| `fiscal_period_id` | uuid | FK fiscal_periods, NOT NULL | |
| `opening_balance` | numeric(18,4) | NOT NULL DEFAULT 0 | |
| `period_debit` | numeric(18,4) | NOT NULL DEFAULT 0 | Sum of DR this period |
| `period_credit` | numeric(18,4) | NOT NULL DEFAULT 0 | Sum of CR this period |
| `closing_balance` | numeric(18,4) | NOT NULL DEFAULT 0 | opening + DR - CR (or reverse for credit-normal) |
| `ytd_debit` | numeric(18,4) | NOT NULL DEFAULT 0 | Year-to-date DR |
| `ytd_credit` | numeric(18,4) | NOT NULL DEFAULT 0 | Year-to-date CR |
| `last_updated_at` | timestamptz | NOT NULL | |

UNIQUE: `(company_id, account_id, branch_id, fiscal_period_id)`

---

### `subsidiary_ledger_entries`
Detailed ledger per customer (AR), supplier (AP), item (inventory), asset. Not created for Cash Sales or Cash Purchases.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `ledger_type` | text | CHECK IN ('AR','AP','INVENTORY','FIXED_ASSET'), NOT NULL | |
| `entity_id` | uuid | NOT NULL | FK to customer/supplier/item/fixed_asset |
| `journal_entry_id` | uuid | FK journal_entries, NOT NULL | |
| `journal_line_id` | uuid | FK journal_lines, NOT NULL | |
| `transaction_date` | date | NOT NULL | |
| `document_type` | text | NOT NULL | |
| `document_no` | text | NOT NULL | |
| `debit_amount` | numeric(18,4) | NOT NULL DEFAULT 0 | |
| `credit_amount` | numeric(18,4) | NOT NULL DEFAULT 0 | |
| `running_balance` | numeric(18,4) | NOT NULL | AR/AP outstanding balance |
| `fiscal_period_id` | uuid | FK fiscal_periods | |
| `due_date` | date | NULL | For AR/AP aging |
| `is_open` | boolean | NOT NULL DEFAULT true | False when fully applied/paid |
| `applied_amount` | numeric(18,4) | NOT NULL DEFAULT 0 | Amount applied/paid |

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
| `relationship_type` | text | NOT NULL | 'BILLED_FROM' \| 'PAID_BY' \| 'REVERSED_BY' \| 'DELIVERED_FROM' \| 'RECEIVED_FROM' \| 'APPLIED_TO' \| 'REPLENISHED_BY' |
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
| `status` | text | CHECK IN ('OPEN','CLOSED','LOCKED') | |
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
| `status` | text | CHECK IN ('OPEN','CLOSED','LOCKED') | |
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

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `template_name` | text | NOT NULL | |
| `description` | text | NULL | |
| `frequency` | text | CHECK IN ('MONTHLY','QUARTERLY','ANNUALLY') | |
| `day_of_month` | integer | NULL | Day to generate (1–28) |
| `start_date` | date | NOT NULL | |
| `end_date` | date | NULL | NULL = no end |
| `last_generated_date` | date | NULL | |
| `next_generation_date` | date | NULL | |
| `is_active` | boolean | NOT NULL DEFAULT true | |
| `auto_post` | boolean | NOT NULL DEFAULT false | If true, post immediately on generation |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |
| `created_by` | uuid | FK auth.users | |

### `recurring_journal_template_lines`

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `template_id` | uuid | FK recurring_journal_templates, NOT NULL | |
| `line_number` | integer | NOT NULL | |
| `account_id` | uuid | FK chart_of_accounts, NOT NULL | |
| `branch_id` | uuid | FK branches, NULL | |
| `department_id` | uuid | FK departments, NULL | |
| `cost_center_id` | uuid | FK cost_centers, NULL | |
| `entry_side` | text | CHECK IN ('DEBIT','CREDIT'), NOT NULL | |
| `amount` | numeric(18,4) | NOT NULL | Fixed amount (Phase 1 only) |
| `description` | text | NOT NULL | |

---

## 7. Posting Engine Process Flow

```
1.  VALIDATE source document (all required fields present, status = APPROVED or DRAFT if no approval required)
2.  CHECK fiscal period is OPEN via fiscal_locks (abort if CLOSED or LOCKED)
3.  LOAD posting_rule_set for transaction_type
4.  FOR EACH posting_rule_line:
    a. RESOLVE account (fixed | FROM_SYSTEM_CONFIG | FROM_LINE)
    b. COMPUTE amount (subtotal | VAT | EWT | header_total)
    c. BUILD journal_line record
5.  VERIFY SUM(debit) = SUM(credit) → ABORT if unbalanced
6.  INSERT journal_entries (status='POSTED', posted_at=now())
7.  INSERT journal_lines (all lines)
8.  UPSERT gl_balances (per account per period, INSERT ... ON CONFLICT DO UPDATE)
9.  INSERT subsidiary_ledger_entries (AR / AP / inventory / FA)
    → SKIP for cash_sale and cash_purchase transaction types
10. UPDATE source document status → 'POSTED', posting_date = now()
11. INSERT document_relationships (source → JE)
12. INSERT audit_logs (event_type='DOCUMENT_POSTED')
13. DISPATCH notifications (async, fire-and-forget — does not participate in this transaction)
    → notify document owner (POSTED), notify approvers if applicable
```

All steps 1–12 execute within a single database transaction. Step 13 is async.

---

## 8. Posting Rules for Cash Sales and Cash Purchases

### Cash Sale Posting (No AR Created)

```
DR: Cash / Bank (cash_sales.payment_amount)           account: FROM_SYSTEM_CONFIG 'CASH_ON_HAND' or 'CASH_IN_BANK'
CR: Revenue Account (cash_sale_lines.net_amount)       account: FROM_ITEM or FROM_LINE (revenue_account_id)
CR: Output VAT Payable (vat_entries.vat_amount)        account: FROM_SYSTEM_CONFIG 'OUTPUT_VAT'
```
- No `subsidiary_ledger_entries` with ledger_type='AR'
- `cash_sale_lines` reduce inventory (inventory_movements OUT) if item is a stocked item

### Cash Purchase Posting (No AP Created)

```
DR: Inventory / Expense Account (cash_purchase_lines.net_amount)    account: FROM_ITEM or FROM_LINE
DR: Input VAT (vat_entries.vat_amount)                              account: FROM_SYSTEM_CONFIG 'INPUT_VAT'
CR: Cash / Bank (cash_purchases.net_payable_amount)                 account: FROM_SYSTEM_CONFIG 'CASH_ON_HAND' or 'CASH_IN_BANK'
DR: EWT Payable (ewt_entries.ewt_amount)     [if EWT-subject line]  account: FROM_SYSTEM_CONFIG 'EWT_PAYABLE'
```
- `net_payable_amount = gross_amount - ewt_amount`
- No `subsidiary_ledger_entries` with ledger_type='AP'
- EWT is captured at purchase time; no deferred payment step required
