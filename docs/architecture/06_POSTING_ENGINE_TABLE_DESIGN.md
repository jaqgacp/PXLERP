# PXL ERP — Posting Engine Table Design
**Version:** 3.0 — Final Architecture Review (Pre-Freeze)
**Status:** v3 In Review — Not Yet Approved for Database Freeze

---

## v3 Architecture Review Changes Applied

- **`posting_rule_sets`**: Added `effective_from` and `effective_to` columns (Principle 11 — all rule/rate tables must be versioned)
- **`system_account_config`**: Added missing keys: `PERCENTAGE_TAX_PAYABLE`, `FWT_PAYABLE`, `INCOME_TAX_PAYABLE`, `OUTPUT_VAT_NON_VAT` (for PT companies posting gross receipts without VAT)
- **`posting_rule_lines.applies_to`**: Expanded to include `'CAPITAL_GOODS_LINES_ONLY'` and `'PT_LINES_ONLY'` for routing non-VAT company lines
- **vat_classification routing**: Posting engine now reads `vat_classification` (not `vat_direction`) from line tables to route to `INPUT_VAT`, `INPUT_VAT_CAPITAL_GOODS`, or `INPUT_VAT_DEFERRED` per Principle 11 v3 fix
- **Government customer routing (v3)**: When posting a sales document, the engine reads `customers.party_special_class`. If `party_special_class = 'government'`, the resulting `vat_entries` record is written with `vat_classification = 'government'`. This value is NOT stored on `sales_invoice_lines` or `cash_sale_lines` — it is derived and set at posting time. Party_special_class values: NULL (regular), 'government', 'peza', 'boi', 'foreign_entity'. Only 'government' triggers a special vat_entries classification; others affect zero-rating rules (PEZA/BOI zero-rated, foreign = export zero-rated).
- Confirmed: EWT line routing uses ATC code series prefix (WC/WI = EWT → 1601EQ; WF = FWT → 1601FQ)

## v3 Remaining Open Decisions

| OD# | Decision | Options | Recommended |
|---|---|---|---|
| OD-PE-01 | `posting_rule_sets` — are rules company-specific or system-wide (seeded)? | Company-specific (customizable) / System-seeded (immutable) | System-seeded with `is_system=true`; companies get copies they can clone |
| OD-PE-02 | When `taxpayer_type = 'non_vat'`, do `vat_entries` get created with zero VAT or skipped entirely? | Create zero-rate vat_entries / Skip vat_entries, create pt_entries only | Skip vat_entries; create percentage_tax_entries directly |
| OD-PE-03 | Capital goods input VAT (>PHP 1M) — Phase 1: accrue monthly amortization via recurring JE or compute at filing time? | Recurring JE / Compute at filing | Phase 1: Compute at filing; recurring JE in Phase 2 |

## v3 Cross-Document Consistency Validation

- `posting_rule_lines.account_config_key` values match `system_account_config` keys (expanded list) ✓
- `vat_classification` values on line tables align with `posting_rule_lines.applies_to` routing logic ✓
- `percentage_tax_entries` → `PERCENTAGE_TAX_PAYABLE` config key → `chart_of_accounts.control_account_type = 'PT_PAYABLE_CONTROL'` ✓ (see doc 03 v3)
- `fwt_remittances_1601fq` → `FWT_PAYABLE` config key → `chart_of_accounts.control_account_type = 'FWT_PAYABLE_CONTROL'` ✓

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
| `effective_from` | date | NOT NULL | Date this rule set takes effect — **[v3 addition: Principle 11 versioning]** |
| `effective_to` | date | NULL | NULL = currently active — **[v3 addition: Principle 11]** |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |
| `created_by` | uuid | FK auth.users | |
| `updated_at` | timestamptz | NULL | |
| `updated_by` | uuid | FK auth.users | |

**Constraints:** `UNIQUE(company_id, rule_set_code, effective_from)`. Partial unique index `WHERE effective_to IS NULL` ensures one active rule per code per company.
**v3 Principle 11 Note:** If BIR changes VAT rate or EWT rates, a new `posting_rule_set` with updated `effective_from` is inserted. Historical transactions use the rule set active on their `document_date`. Do NOT update existing active rule sets — insert new versions.

**Valid `transaction_type` values:**
`sales_invoice` | `vendor_bill` | `receipt` | `payment_voucher` | `cash_sale` | `cash_purchase` | `petty_cash_voucher` | `inventory_adjustment` | `asset_depreciation` | `bank_deposit` | `bank_withdrawal` | `bank_transfer` | `journal_entry` | `stock_transfer` | `asset_disposal`

> **Percentage Tax Note (Principle 3 Driver 1):** `sales_invoice` and `cash_sale` posting rules check `company_compliance_profiles.taxpayer_type` at post time. If `taxpayer_type = 'non_vat'`, the posting engine creates `percentage_tax_entries` instead of `vat_entries`. No separate `transaction_type` is needed — the same source documents drive different compliance entries depending on the company's taxpayer type.

> **FWT Note:** `fwt_entries` are created during posting of vendor_bill, cash_purchase, or payment_voucher lines where the `ewt_atc_id` references a WF-series ATC code. These flow to `fwt_remittances_1601fq` instead of `ewt_remittances_1601eq`.

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
| `FWT_PAYABLE` | Final Withholding Tax Payable (1601FQ) — **[v3 addition]** | FWT_PAYABLE_CONTROL |
| `PERCENTAGE_TAX_PAYABLE` | Percentage Tax Payable (2551Q, non-VAT) — **[v3 addition]** | PT_PAYABLE_CONTROL |
| `INCOME_TAX_PAYABLE` | Income Tax Payable (1702Q/1701Q quarterly) — **[v3 addition]** | INCOME_TAX_PAYABLE_CONTROL |
| `CASH_ON_HAND` | Cash on Hand (petty cash, over-the-counter) | — |
| `CASH_IN_BANK` | Cash in Bank (default checking account) | — |
| `INVENTORY_CONTROL` | Inventory — Trading Goods / Raw Materials | INVENTORY_CONTROL |
| `COST_OF_GOODS_SOLD` | Cost of Goods Sold | — |
| `RETAINED_EARNINGS` | Retained Earnings (year-end closing) | — |
| `INCOME_SUMMARY` | Income Summary (closing account) | — |

**v3 Note:** `PERCENTAGE_TAX_PAYABLE`, `FWT_PAYABLE`, and `INCOME_TAX_PAYABLE` were missing in v2.1. Their absence would cause posting engine abort for non-VAT companies (PT posting) and companies with FWT/income tax obligations. These keys are now required at company setup — the setup wizard must prompt for account assignment when the corresponding compliance obligation is enabled in `company_compliance_profiles.filing_obligations`.

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


---

## 9. Amortization Run Posting Process (Enhancement Round)

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

## 10. Revenue Recognition Run Posting Process (Enhancement Round)

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

## 11. Auto Reversal Run Process (Enhancement Round)

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
