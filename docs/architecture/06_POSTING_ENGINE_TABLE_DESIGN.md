# PXL ERP — Posting Engine Table Design
**Version:** 3.7 — Implementation Readiness Fix Pass
**Status:** v3.7 — All open decisions resolved. Complete posting rules for all 21 transaction types. Freeze pending Section 52 sign-off.

---

## v3 Architecture Review Changes Applied

- **`posting_rule_sets`**: Added `effective_from` and `effective_to` columns (Principle 11 — all rule/rate tables must be versioned)
- **`system_account_config`**: Added missing keys: `PERCENTAGE_TAX_PAYABLE`, `FWT_PAYABLE`, `INCOME_TAX_PAYABLE`, `OUTPUT_VAT_NON_VAT` (for PT companies posting gross receipts without VAT)
- **`posting_rule_lines.applies_to`**: Expanded to include `'CAPITAL_GOODS_LINES_ONLY'` and `'PT_LINES_ONLY'` for routing non-VAT company lines
- **vat_classification routing**: Posting engine now reads `vat_classification` (not `vat_direction`) from line tables to route to `INPUT_VAT`, `INPUT_VAT_CAPITAL_GOODS`, or `INPUT_VAT_DEFERRED` per Principle 11 v3 fix
- **Government customer routing (v3)**: When posting a sales document, the engine reads `customers.party_special_class`. If `party_special_class = 'government'`, the resulting `vat_entries` record is written with `vat_classification = 'government'`. This value is NOT stored on `sales_invoice_lines` or `cash_sale_lines` — it is derived and set at posting time. Party_special_class values: NULL (regular), 'government', 'peza', 'boi', 'foreign_entity'. Only 'government' triggers a special vat_entries classification; others affect zero-rating rules (PEZA/BOI zero-rated, foreign = export zero-rated).
- Confirmed: EWT line routing uses ATC code series prefix (WC/WI = EWT → 1601EQ; WF = FWT → 1601FQ)

## v3 Open Decisions — ALL RESOLVED (v3.7)

| OD# | Decision | **RESOLUTION** |
|---|---|---|
| OD-PE-01 | `posting_rule_sets` — company-specific or system-seeded? | **RESOLVED v3.7:** System-seeded with `is_system=true`. At company onboarding, the setup wizard seeds one active `posting_rule_set` per standard `transaction_type` with `is_system=true`. Companies may clone a system rule (INSERT new row with `is_system=false`) to customize. System rules cannot be deleted or deactivated. Cloned rules take precedence over system rules when `effective_from` matches or is later. Implementation: at post time, load rule where `company_id=? AND transaction_type=? AND effective_from<=document_date AND (effective_to IS NULL OR effective_to>document_date)` ORDER BY `is_system ASC, effective_from DESC` LIMIT 1. |
| OD-PE-02 | When `taxpayer_type='non_vat'`, vat_entries or pt_entries? | **RESOLVED v3.7:** Skip `vat_entries` entirely. Insert `percentage_tax_entries` only. The posting engine checks `company_compliance_profiles.taxpayer_type` at step 11. If `'non_vat'`: (a) do NOT write to `vat_entries`; (b) INSERT `percentage_tax_entries` with `pt_rate` from `percentage_tax_codes` effective on `document_date`. If `'vat'`: write `vat_entries` as normal; no `percentage_tax_entries`. No mixing. |
| OD-PE-03 | Capital goods input VAT (>PHP 1M) — Phase 1 handling? | **RESOLVED v3.7:** Phase 1: classify the input VAT as `INPUT_VAT_CAPITAL_GOODS` at posting time (book full amount to deferred capital goods VAT account). Compute amortized monthly amounts at filing time (outside the posting engine — accountant manually computes on 2550M). Phase 2 will add a recurring JE generator for monthly capital goods VAT amortization. Developer action: at posting, check `cash_purchase_lines.input_vat_amount > 1_000_000` OR the aggregate capital goods amount; if true, route to `INPUT_VAT_CAPITAL_GOODS` system config key instead of `INPUT_VAT`. |

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
| OD-13 | Should the posting engine write `vat_entries` and `ewt_entries` directly, or should those be written by the source document save step before posting? | **RESOLVED v3.3:** Posting engine writes all immutable compliance entries (§7 Step 11). Document save writes draft preview fields only. See Doc 05 OD-13. |
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
`sales_invoice` | `vendor_bill` | `receipt` | `payment_voucher` | `cash_sale` | `cash_purchase` | `petty_cash_voucher` | `petty_cash_replenishment` | `stock_adjustment` | `stock_transfer` | `customer_return` | `purchase_return` | `sales_debit_memo` | `supplier_debit_memo` | `asset_acquisition` | `asset_depreciation` | `asset_disposal` | `bank_fund_transfer` | `bank_adjustment` | `inter_branch_transfer` | `journal_entry`

**[v3.7: added 8 previously missing transaction types — petty_cash_replenishment, stock_transfer, customer_return, purchase_return, sales_debit_memo, supplier_debit_memo, asset_acquisition, bank_adjustment, inter_branch_transfer. Each has a documented posting rule in Section 8.]**

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
| `entry_side` | text | CHECK IN ('debit','credit'), NOT NULL | |
| `account_source` | text | NOT NULL | 'fixed' \| 'from_item' \| 'from_customer' \| 'from_supplier' \| 'from_rule_param' \| 'from_system_config' |
| `fixed_account_id` | uuid | FK chart_of_accounts, NULL | Used if account_source='fixed' |
| `account_config_key` | text | NULL | Used if account_source='from_system_config'; e.g., 'AR_TRADE', 'OUTPUT_VAT', 'AP_TRADE', 'CASH_ON_HAND' |
| `amount_source` | text | NOT NULL | 'line_subtotal' \| 'line_vat' \| 'line_ewt' \| 'header_total' \| 'computed' |
| `amount_formula` | text | NULL | SQL expression for computed amounts |
| `applies_to` | text | NOT NULL DEFAULT 'all' | 'all' \| 'vat_lines_only' \| 'ewt_lines_only' \| 'zero_vat_lines' |
| `creates_subsidiary_ledger` | boolean | NOT NULL DEFAULT false | Whether this line creates a subsidiary_ledger_entry |
| `subsidiary_ledger_type` | text | NULL | 'ar' \| 'ap' \| 'inventory' \| 'fixed_asset' — NULL for cash_sale/cash_purchase lines |
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
10. INSERT subsidiary_ledger_entries (ar / ap / inventory / fixed_asset)
    → SKIP for cash_sale and cash_purchase transaction types
11. WRITE compliance entries (within same transaction — immutable snapshots):
    a. INSERT vat_entries (one per taxable line) — tax_period_id, vat_direction, vat_classification, amounts
    b. INSERT ewt_entries (one per EWT-subject line per ATC) — payee snapshot fields, ewt_amount
    c. INSERT fwt_entries (if FWT-subject transaction) — payee snapshot fields, fwt_amount
    d. INSERT percentage_tax_entries (if non-VAT taxpayer_type) — pt_amount, atc_code
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
- `journal_entries` duplicate guard: UNIQUE(company_id, source_document_type, source_document_id) WHERE je_type = 'system' — prevents double-posting even without idempotency_key **[v3.6 fix: 'auto' is not a canonical je_type value; Doc03 canonical list is CHECK IN ('manual','system','reversal','opening','recurring','adjustment','amortization','revenue_recognition','auto_reversal'); posting-engine-generated JEs use je_type = 'system']**
- Compliance entry deduplication: posting engine checks existence before INSERT; abort if found for same source document and status = 'posted'

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
- transaction_type = `'sales_credit_memo'` — **[B-8 addition]**

---

### Vendor Credit Memo Posting

```
DR: Accounts Payable (AP_TRADE)                                    FROM_SYSTEM_CONFIG 'AP_TRADE'
CR: Purchase Returns / Expense Account  (reverse original cost)    FROM_ITEM or FROM_LINE
CR: Input VAT (reversed input VAT amount)                          FROM_SYSTEM_CONFIG 'INPUT_VAT'
```
- Writes negative `vat_entries` record (reversal of input VAT)
- Updates `subsidiary_ledger_entries` (AP debit)
- transaction_type = `'vendor_credit'` — **[B-8 addition]**

---

## 8b. Complete Posting Rules — All Remaining Transaction Types (v3.7)

> **v3.7 note:** These rules complete the posting engine. Every transaction type listed in `posting_rule_sets.transaction_type` now has a documented rule. No transaction type may be posted without a rule in this section or Section 8.

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

**EWT handling:**
- If EWT was pre-booked at vendor_bill posting: DR `EWT_PAYABLE` (removes the liability), no new ewt_entries INSERT.
- If EWT was NOT pre-booked (cash purchase without prior bill): CR `EWT_PAYABLE` + INSERT `ewt_entries` at this step.
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
