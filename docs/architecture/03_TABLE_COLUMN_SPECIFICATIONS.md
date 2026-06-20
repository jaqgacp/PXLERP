# PXL ERP — Table Column Specifications
**Version:** 2.0 — Revised for Implementation Readiness
**Status:** For CPA and Developer Review

> Money fields use `numeric(18,4)`. Rates use `numeric(10,6)`. All timestamps are `timestamptz`. All PKs are `uuid DEFAULT gen_random_uuid()`.
> Standard audit columns are listed once and assumed on all tables marked with Audit or Soft Delete in the inventory.

---

## Changes Applied (v2 → v2.1) — Principle Alignment

- Added `company_compliance_profiles` column spec (new table — Principles 1, 6, 11)
- Added `company_feature_settings` column spec (new table — Principles 1, 7)
- Added `percentage_tax_entries`, `percentage_tax_period_summaries`, `percentage_tax_return_filings` column specs
- Added `fwt_remittances_1601fq` column spec
- Added `income_tax_return_filings` column spec
- Updated `customers.vat_status` CHECK to include `'government','peza','boi','foreign_entity'` (Principle 5)
- Updated `suppliers.vat_status` CHECK to include `'government','peza','boi','foreign_entity'` (Principle 5)
- Added `atc_codes.effective_from` and `atc_codes.effective_to` (Principle 11)

## Changes Applied (v1 → v2)

- Standardized `document_no` (not `document_number`) on all transaction headers
- Standardized `document_date` (not `invoice_date`, `bill_date`, `entry_date`) on all transaction headers
- Standardized `tin` on master tables (`companies`, `customers`, `suppliers`) — not `bir_tin`
- `vat_entries`: renamed `taxable_amount` → consistent with `net_amount` on lines; `vat_type` split into `vat_direction` (output/input) + `vat_classification` (vatable/zero_rated/exempt)
- `ewt_entries`: standardized `ewt_base_amount` (not `tax_base_amount`)
- `profiles`: uses `first_name` + `last_name` (not `full_name`) consistent with doc 09 resolved
- Resolved `profiles` inconsistency: doc 09 had `full_name`, doc 03 had `first_name`+`last_name` — use `first_name` + `last_name` + computed `full_name`
- Added column specs for: `cash_sales`, `cash_purchases`, `inventory_cost_layer_consumption`, `bank_statement_lines`, `petty_cash_voucher_lines`, `notifications`, `notification_templates`, `document_templates`, `generated_documents`, `budgets`, `budget_lines`, `period_close_checklists`, `period_close_tasks`
- Removed duplicate `number_series` definition (canonical spec now in doc 07)
- Added missing `import_batch_id` column note to all master data tables

---

## Standard Column Sets (Referenced Throughout)

### Standard Audit Columns (all tables)
```
created_at    timestamptz  NOT NULL  DEFAULT now()
created_by    uuid         NOT NULL  FK → profiles.id
updated_at    timestamptz  NULL
updated_by    uuid         NULL      FK → profiles.id
deleted_at    timestamptz  NULL      -- NULL = active, non-NULL = soft deleted
deleted_by    uuid         NULL      FK → profiles.id
```

> Tables marked **Immutable** do not have `updated_*` columns. Tables marked **Soft Delete** have `deleted_*` columns.

### Standard Dimension Columns (operational tables)
```
company_id      uuid  NOT NULL  FK → companies.id
branch_id       uuid  NULL      FK → branches.id
department_id   uuid  NULL      FK → departments.id
cost_center_id  uuid  NULL      FK → cost_centers.id
```

### Standard Transaction Header Columns
```
document_no          text          NOT NULL  UNIQUE per company (assigned from number_series)
document_date        date          NOT NULL  (date on the document — may differ from posting date)
posting_date         date          NULL      (set when document is posted)
fiscal_year_id       uuid          NOT NULL  FK → fiscal_years.id
fiscal_period_id     uuid          NOT NULL  FK → fiscal_periods.id
currency_id          uuid          NOT NULL  FK → currencies.id  DEFAULT PHP
exchange_rate        numeric(10,6) NOT NULL  DEFAULT 1.000000
status               text          NOT NULL  CHECK IN ('draft','submitted','approved','posted','voided','reversed','cancelled')
subtotal_amount      numeric(18,4) NOT NULL  DEFAULT 0  (before VAT)
vat_amount           numeric(18,4) NOT NULL  DEFAULT 0
withholding_amount   numeric(18,4) NOT NULL  DEFAULT 0  (EWT if applicable)
total_amount         numeric(18,4) NOT NULL  DEFAULT 0  (subtotal + VAT - EWT for PV)
remarks              text          NULL
posted_at            timestamptz   NULL
posted_by            uuid          NULL      FK → profiles.id
voided_at            timestamptz   NULL
voided_by            uuid          NULL      FK → profiles.id
void_reason          text          NULL
reversed_by_doc_id   uuid          NULL      FK to same table (reversal document)
source_document_id   uuid          NULL      FK to originating document
source_document_type text          NULL      'sales_invoice' | 'vendor_bill' | 'sales_order' | etc.
import_batch_id      uuid          NULL      FK → import_batches.id
```

---

## SECTION 1: ORGANIZATION

### `companies`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| code | text | NOT NULL | — | Short company code |
| name | text | NOT NULL | — | Full registered company name |
| trade_name | text | NULL | — | Trade/brand name |
| tin | text | NOT NULL | — | BIR TIN (format: 000-000-000-000) |
| rdo_code | text | NULL | — | Revenue District Office code |
| bir_registered_address | text | NOT NULL | — | Address on BIR registration |
| industry_classification | text | NULL | — | PSIC industry code |
| tax_type | text | NOT NULL | — | CHECK IN ('vat','non_vat','exempt') |
| business_type | text | NOT NULL | — | CHECK IN ('corporation','partnership','sole_proprietorship','cooperative') |
| sec_registration_no | text | NULL | — | SEC registration number |
| dti_registration_no | text | NULL | — | DTI registration (sole props) |
| logo_url | text | NULL | — | Supabase Storage URL |
| functional_currency_id | uuid | NOT NULL | — | FK → currencies.id (default PHP) |
| fiscal_year_start_month | integer | NOT NULL | 1 | Month fiscal year starts (1=January) |
| is_active | boolean | NOT NULL | true | |
| *+ standard audit columns* | | | | |

**Indexes:** `idx_companies_tin`, `idx_companies_code`
**Constraints:** `UNIQUE(tin)`, `UNIQUE(code)`

---

### `branches`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| code | text | NOT NULL | — | Branch code |
| name | text | NOT NULL | — | Branch name |
| address | text | NULL | — | Physical address |
| tin_suffix | text | NULL | — | Branch TIN suffix (000, 001…) |
| bir_registered | boolean | NOT NULL | false | Has separate BIR registration |
| is_head_office | boolean | NOT NULL | false | Marks head office branch |
| is_active | boolean | NOT NULL | true | |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, code)`

---

### `departments`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| branch_id | uuid | NULL | — | FK → branches.id (NULL = company-wide) |
| code | text | NOT NULL | — | Department code |
| name | text | NOT NULL | — | Department name |
| parent_department_id | uuid | NULL | — | FK → departments.id (self-ref hierarchy) |
| is_active | boolean | NOT NULL | true | |
| *+ standard audit columns* | | | | |

---

### `cost_centers`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| department_id | uuid | NULL | — | FK → departments.id |
| code | text | NOT NULL | — | Cost center code |
| name | text | NOT NULL | — | Cost center name |
| is_active | boolean | NOT NULL | true | |
| *+ standard audit columns* | | | | |

---

### `company_bank_accounts`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| branch_id | uuid | NULL | — | FK → branches.id |
| bank_name | text | NOT NULL | — | Bank name |
| bank_branch | text | NULL | — | Bank branch name |
| account_name | text | NOT NULL | — | Account name on record |
| account_number | text | NOT NULL | — | Bank account number |
| account_type | text | NOT NULL | — | CHECK IN ('checking','savings','time_deposit') |
| currency_id | uuid | NOT NULL | — | FK → currencies.id |
| gl_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| is_active | boolean | NOT NULL | true | |
| *+ standard audit columns* | | | | |

---

### `company_compliance_profiles`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| taxpayer_type | text | NOT NULL | — | CHECK IN ('vat','non_vat') |
| income_tax_regime | text | NOT NULL | — | CHECK IN ('corporate','individual','partnership','cooperative') |
| legal_type | text | NOT NULL | — | CHECK IN ('sole_proprietor','regular_corporation','opc','partnership','cooperative') |
| withholding_agent_status | text | NOT NULL | 'registered' | CHECK IN ('registered','not_registered') |
| rdo_code | text | NOT NULL | — | BIR Revenue District Office code |
| bir_registered_at | date | NOT NULL | — | Date of original BIR registration |
| filing_obligations | text[] | NOT NULL | '{}' | e.g. '{2550m,1601eq,2551q}' — forms this company must file |
| effective_from | date | NOT NULL | — | Date this profile takes effect |
| effective_to | date | NULL | — | NULL = currently active profile |
| notes | text | NULL | — | |
| *+ standard audit columns* | | | | |

**Constraints:** UNIQUE on `(company_id, effective_from)`. Only one record per company may have `effective_to IS NULL` (enforced by partial unique index).

**Principle 11 Note:** When taxpayer type changes (e.g., NON-VAT → VAT), do NOT update existing row. Set `effective_to` on the current row and INSERT a new row with the new `effective_from`. Historical transactions use the profile effective on their `document_date`.

---

### `company_feature_settings`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id (UNIQUE) |
| inventory_enabled | boolean | NOT NULL | false | Shows/hides Inventory module menus and dashboards |
| fixed_assets_enabled | boolean | NOT NULL | false | Shows/hides Fixed Assets module |
| petty_cash_enabled | boolean | NOT NULL | false | Shows/hides Petty Cash module |
| bank_recon_enabled | boolean | NOT NULL | true | Shows/hides Bank Reconciliation module |
| budgeting_enabled | boolean | NOT NULL | false | Shows/hides Budget module |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id)` — one settings row per company
**Principle 7:** These flags control UI visibility only. Disabling inventory does NOT prevent inventory GL accounts from being used in journal entries.

---

### `cas_registrations`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| cas_permit_no | text | NOT NULL | — | BIR CAS permit number |
| date_issued | date | NOT NULL | — | Permit issue date |
| date_valid_from | date | NOT NULL | — | Validity start |
| date_valid_to | date | NULL | — | Validity end (NULL = no expiry stated) |
| system_name | text | NOT NULL | 'PXL ERP' | Registered system name |
| components_covered | text[] | NOT NULL | — | e.g., '{GL,AR,AP,INV}' |
| bir_rdo_code | text | NOT NULL | — | RDO code of filing |
| bir_form_submitted | text | NULL | — | e.g., 'BIR Form 1900' |
| is_active | boolean | NOT NULL | true | |
| *+ standard audit columns* | | | | |

---

## SECTION 2: SYSTEM CONTROLS

### `approval_matrix`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| document_type | text | NOT NULL | — | 'sales_invoice','payment_voucher', etc. |
| name | text | NOT NULL | — | Matrix name |
| amount_threshold_min | numeric(18,4) | NULL | — | Apply when amount ≥ this |
| amount_threshold_max | numeric(18,4) | NULL | — | Apply when amount < this (NULL = no upper limit) |
| approval_type | text | NOT NULL | 'sequential' | CHECK IN ('sequential','parallel','any_one') |
| is_active | boolean | NOT NULL | true | |
| *+ standard audit columns* | | | | |

---

### `approval_matrix_steps`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| approval_matrix_id | uuid | NOT NULL | — | FK → approval_matrix.id |
| step_order | integer | NOT NULL | — | Sequence (1, 2, 3…) |
| approver_role_id | uuid | NULL | — | FK → roles.id (role-based) |
| approver_user_id | uuid | NULL | — | FK → profiles.id (specific user) |
| escalate_after_hours | integer | NULL | — | Hours before escalation |
| escalate_to_user_id | uuid | NULL | — | FK → profiles.id |
| is_required | boolean | NOT NULL | true | |
| *+ standard audit columns* | | | | |

---

## SECTION 3: ACCOUNTING SETUP

### `fiscal_years`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| year_code | text | NOT NULL | — | e.g., 'FY2025' |
| date_from | date | NOT NULL | — | Fiscal year start |
| date_to | date | NOT NULL | — | Fiscal year end |
| is_current | boolean | NOT NULL | false | Only one TRUE per company |
| status | text | NOT NULL | 'open' | CHECK IN ('open','closed') |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, year_code)`, only one `is_current = true` per company (enforced by trigger)

---

### `fiscal_periods`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| fiscal_year_id | uuid | NOT NULL | — | FK → fiscal_years.id |
| period_number | integer | NOT NULL | — | 1–12 for monthly |
| period_name | text | NOT NULL | — | e.g., 'January 2025' |
| date_from | date | NOT NULL | — | Period start |
| date_to | date | NOT NULL | — | Period end |
| quarter | integer | NOT NULL | — | 1–4 |
| status | text | NOT NULL | 'open' | CHECK IN ('open','closed','locked') |
| *+ standard audit columns* | | | | |

---

### `fiscal_locks`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| fiscal_period_id | uuid | NOT NULL | — | FK → fiscal_periods.id |
| locked_at | timestamptz | NOT NULL | now() | |
| locked_by | uuid | NOT NULL | — | FK → profiles.id |
| lock_reason | text | NULL | — | |
| unlocked_at | timestamptz | NULL | — | Exception unlock |
| unlocked_by | uuid | NULL | — | FK → profiles.id |
| unlock_reason | text | NULL | — | Required if unlocked |

**Constraints:** `UNIQUE(company_id, fiscal_period_id)`

---

### `chart_of_accounts`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| account_code | text | NOT NULL | — | e.g., '1010-001' |
| account_name | text | NOT NULL | — | |
| account_type_id | uuid | NOT NULL | — | FK → account_types.id |
| parent_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| level | integer | NOT NULL | 1 | Hierarchy level (1=group) |
| is_detail_account | boolean | NOT NULL | true | Only detail accounts can have JE lines |
| normal_balance | text | NOT NULL | — | CHECK IN ('debit','credit') |
| is_cash_equivalent | boolean | NOT NULL | false | For Cash Flow statement |
| fs_line_mapping | text | NULL | — | Financial statement line reference |
| vat_account_type | text | NULL | — | 'input_vat','output_vat','vat_payable', etc. |
| is_active | boolean | NOT NULL | true | |
| import_batch_id | uuid | NULL | — | FK → import_batches.id |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, account_code)`

---

### `account_types`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| code | text | NOT NULL | — | 'asset','liability','equity','revenue','expense','contra_asset','contra_revenue' |
| name | text | NOT NULL | — | |
| normal_balance | text | NOT NULL | — | CHECK IN ('debit','credit') |
| fs_category | text | NOT NULL | — | 'balance_sheet','income_statement' |
| sort_order | integer | NOT NULL | 0 | Display order |

---

### `budgets`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| fiscal_year_id | uuid | NOT NULL | — | FK → fiscal_years.id |
| budget_name | text | NOT NULL | — | e.g., 'FY2025 Annual Budget' |
| version | integer | NOT NULL | 1 | Version number (re-budgeting) |
| status | text | NOT NULL | 'draft' | CHECK IN ('draft','approved','active','superseded') |
| approved_by | uuid | NULL | — | FK → profiles.id |
| approved_at | timestamptz | NULL | — | |
| notes | text | NULL | — | |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, fiscal_year_id, version)`

---

### `budget_lines`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| budget_id | uuid | NOT NULL | — | FK → budgets.id |
| account_id | uuid | NOT NULL | — | FK → chart_of_accounts.id |
| branch_id | uuid | NULL | — | FK → branches.id (NULL = company-wide) |
| department_id | uuid | NULL | — | FK → departments.id |
| fiscal_period_id | uuid | NOT NULL | — | FK → fiscal_periods.id |
| budgeted_amount | numeric(18,4) | NOT NULL | 0 | |
| notes | text | NULL | — | |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(budget_id, account_id, branch_id, department_id, fiscal_period_id)`

---

## SECTION 4: MASTER DATA

### `customers`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| customer_code | text | NOT NULL | — | Unique customer code |
| customer_name | text | NOT NULL | — | Registered business name |
| trade_name | text | NULL | — | |
| customer_type | text | NOT NULL | 'business' | CHECK IN ('individual','business','government') |
| tin | text | NULL | — | TIN (required for VAT customers and SLSP) |
| vat_status | text | NOT NULL | 'vat' | CHECK IN ('vat','non_vat','exempt','zero_rated','government','peza','boi','foreign_entity') |
| payment_terms_id | uuid | NULL | — | FK → payment_terms.id |
| ar_account_id | uuid | NULL | — | FK → chart_of_accounts.id (override) |
| sales_account_id | uuid | NULL | — | FK → chart_of_accounts.id (default revenue) |
| is_ewt_agent | boolean | NOT NULL | false | Customer withholds EWT from us |
| default_ewt_atc_id | uuid | NULL | — | FK → atc_codes.id |
| credit_limit | numeric(18,4) | NOT NULL | 0 | 0 = no limit |
| currency_id | uuid | NOT NULL | — | FK → currencies.id (default PHP) |
| is_active | boolean | NOT NULL | true | |
| import_batch_id | uuid | NULL | — | FK → import_batches.id |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, customer_code)`
**Note:** `tin` stored WITHOUT dashes internally; formatted with dashes on display. Validation at application layer.

---

### `customer_tax_profiles`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| customer_id | uuid | NOT NULL | — | FK → customers.id |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| tin | text | NOT NULL | — | Customer TIN |
| bir_registered_address | text | NULL | — | |
| bir_rdo_code | text | NULL | — | |
| vat_registration_no | text | NULL | — | |
| is_ewt_agent | boolean | NOT NULL | false | |
| default_ewt_atc_id | uuid | NULL | — | FK → atc_codes.id |
| effective_date | date | NOT NULL | — | When this profile takes effect |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(customer_id)` — one tax profile per customer

---

### `suppliers`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| supplier_code | text | NOT NULL | — | Unique supplier code |
| supplier_name | text | NOT NULL | — | Registered business name |
| trade_name | text | NULL | — | |
| supplier_type | text | NOT NULL | 'business' | CHECK IN ('individual','business','government') |
| tin | text | NULL | — | TIN (required for 2307) |
| vat_status | text | NOT NULL | 'vat' | CHECK IN ('vat','non_vat','exempt','zero_rated','government','peza','boi','foreign_entity') |
| payment_terms_id | uuid | NULL | — | FK → payment_terms.id |
| ap_account_id | uuid | NULL | — | FK → chart_of_accounts.id (override) |
| expense_account_id | uuid | NULL | — | FK → chart_of_accounts.id (default) |
| ewt_subject | boolean | NOT NULL | true | Subject to EWT on payments |
| default_ewt_atc_id | uuid | NULL | — | FK → atc_codes.id |
| currency_id | uuid | NOT NULL | — | FK → currencies.id |
| is_active | boolean | NOT NULL | true | |
| import_batch_id | uuid | NULL | — | FK → import_batches.id |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, supplier_code)`

---

### `payment_terms`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| code | text | NOT NULL | — | 'NET30','COD','CIA', etc. |
| name | text | NOT NULL | — | |
| due_days | integer | NOT NULL | 0 | Days until due (0 = COD) |
| discount_days | integer | NULL | — | Days to qualify for early payment discount |
| discount_percent | numeric(10,6) | NULL | — | Early payment discount % |
| is_active | boolean | NOT NULL | true | |
| import_batch_id | uuid | NULL | — | FK → import_batches.id |
| *+ standard audit columns* | | | | |

---

### `items`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| item_code | text | NOT NULL | — | Unique item code |
| item_name | text | NOT NULL | — | |
| description | text | NULL | — | |
| item_category_id | uuid | NULL | — | FK → item_categories.id |
| base_uom_id | uuid | NOT NULL | — | FK → units_of_measure.id |
| item_type | text | NOT NULL | 'inventory' | CHECK IN ('inventory','non_inventory','service','fixed_asset') |
| sales_vat_code_id | uuid | NULL | — | FK → vat_codes.id |
| purchase_vat_code_id | uuid | NULL | — | FK → vat_codes.id |
| ewt_atc_id | uuid | NULL | — | FK → atc_codes.id (if EWT-subject when purchased) |
| sales_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| cogs_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| inventory_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| purchase_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| standard_cost | numeric(18,4) | NULL | — | Standard cost (for reference; actual cost from FIFO layers) |
| standard_price | numeric(18,4) | NULL | — | Default selling price |
| is_tracked | boolean | NOT NULL | true | Track inventory quantity |
| is_active | boolean | NOT NULL | true | |
| import_batch_id | uuid | NULL | — | FK → import_batches.id |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, item_code)`

---

### `warehouses`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| branch_id | uuid | NOT NULL | — | FK → branches.id |
| code | text | NOT NULL | — | Warehouse code |
| name | text | NOT NULL | — | |
| address | text | NULL | — | Physical location |
| is_default | boolean | NOT NULL | false | Default warehouse for branch |
| is_active | boolean | NOT NULL | true | |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, code)`

---

## SECTION 5: SALES TRANSACTIONS

### `sales_invoices`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| *+ standard dimension columns* | | | | |
| *+ standard transaction header columns* | | | | |
| customer_id | uuid | NOT NULL | — | FK → customers.id |
| customer_name | text | NOT NULL | — | Snapshot at time of invoice |
| customer_tin | text | NULL | — | Snapshot for SLSP |
| customer_address | text | NULL | — | Snapshot |
| sales_order_id | uuid | NULL | — | FK → sales_orders.id |
| delivery_receipt_id | uuid | NULL | — | FK → delivery_receipts.id |
| due_date | date | NULL | — | Payment due date |
| payment_terms_id | uuid | NULL | — | FK → payment_terms.id |
| is_vat_inclusive | boolean | NOT NULL | false | Whether line prices include VAT |
| invoice_type | text | NOT NULL | 'regular' | CHECK IN ('regular','vat_official','non_vat') |
| atp_usage_id | uuid | NULL | — | FK → atp_usage_logs.id |
| journal_entry_id | uuid | NULL | — | FK → journal_entries.id (set on post) |
| *+ standard audit columns* | | | | |

**Indexes:** `idx_si_company_date`, `idx_si_customer_id`, `idx_si_status`, `idx_si_fiscal_period_id`

---

### `sales_invoice_lines`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| sales_invoice_id | uuid | NOT NULL | — | FK → sales_invoices.id |
| line_no | integer | NOT NULL | — | Line sequence |
| item_id | uuid | NULL | — | FK → items.id (NULL for free-text service line) |
| service_id | uuid | NULL | — | FK → services.id |
| description | text | NOT NULL | — | Line description (snapshot) |
| quantity | numeric(18,4) | NOT NULL | — | |
| uom_id | uuid | NOT NULL | — | FK → units_of_measure.id |
| unit_price | numeric(18,4) | NOT NULL | — | |
| discount_percent | numeric(10,6) | NOT NULL | 0 | |
| discount_amount | numeric(18,4) | NOT NULL | 0 | |
| net_amount | numeric(18,4) | NOT NULL | — | After discount, before VAT |
| vat_code_id | uuid | NULL | — | FK → vat_codes.id |
| vat_direction | text | NOT NULL | 'output' | CHECK IN ('output','zero_rated','exempt','government') |
| vat_rate | numeric(10,6) | NOT NULL | 0 | Snapshot of rate |
| vat_amount | numeric(18,4) | NOT NULL | 0 | |
| total_amount | numeric(18,4) | NOT NULL | — | net_amount + vat_amount |
| revenue_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| warehouse_id | uuid | NULL | — | FK → warehouses.id (for inventory items) |
| *+ standard audit columns* | | | | |

---

### `cash_sales`
Cash sales — immediate collection, no AR created.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| *+ standard dimension columns* | | | | |
| *+ standard transaction header columns* | | | | |
| customer_id | uuid | NULL | — | FK → customers.id (NULL for walk-in/anonymous) |
| customer_name | text | NOT NULL | 'Walk-in' | Snapshot or 'Walk-in' |
| customer_tin | text | NULL | — | Snapshot for SLSP (if known) |
| payment_method | text | NOT NULL | — | CHECK IN ('cash','check','bank_transfer','online') |
| check_no | text | NULL | — | |
| check_date | date | NULL | — | |
| bank_account_id | uuid | NULL | — | FK → company_bank_accounts.id |
| is_vat_inclusive | boolean | NOT NULL | false | |
| receipt_type | text | NOT NULL | 'official_receipt' | CHECK IN ('official_receipt','non_vat_receipt') |
| atp_usage_id | uuid | NULL | — | FK → atp_usage_logs.id |
| journal_entry_id | uuid | NULL | — | FK → journal_entries.id (set on post) |
| *+ standard audit columns* | | | | |

---

### `cash_sale_lines`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| cash_sale_id | uuid | NOT NULL | — | FK → cash_sales.id |
| line_no | integer | NOT NULL | — | |
| item_id | uuid | NULL | — | FK → items.id |
| service_id | uuid | NULL | — | FK → services.id |
| description | text | NOT NULL | — | |
| quantity | numeric(18,4) | NOT NULL | — | |
| uom_id | uuid | NOT NULL | — | FK → units_of_measure.id |
| unit_price | numeric(18,4) | NOT NULL | — | |
| discount_percent | numeric(10,6) | NOT NULL | 0 | |
| discount_amount | numeric(18,4) | NOT NULL | 0 | |
| net_amount | numeric(18,4) | NOT NULL | — | |
| vat_code_id | uuid | NULL | — | FK → vat_codes.id |
| vat_direction | text | NOT NULL | 'output' | CHECK IN ('output','zero_rated','exempt','government') |
| vat_rate | numeric(10,6) | NOT NULL | 0 | |
| vat_amount | numeric(18,4) | NOT NULL | 0 | |
| total_amount | numeric(18,4) | NOT NULL | — | |
| revenue_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| warehouse_id | uuid | NULL | — | FK → warehouses.id |
| *+ standard audit columns* | | | | |

---

### `receipts`
AR collection — applied against sales invoices.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| *+ standard dimension columns* | | | | |
| *+ standard transaction header columns* | | | | |
| customer_id | uuid | NOT NULL | — | FK → customers.id |
| customer_name | text | NOT NULL | — | Snapshot |
| customer_tin | text | NULL | — | Snapshot |
| payment_method | text | NOT NULL | — | CHECK IN ('cash','check','bank_transfer','online') |
| check_no | text | NULL | — | |
| check_date | date | NULL | — | |
| bank_account_id | uuid | NULL | — | FK → company_bank_accounts.id |
| bank_deposit_date | date | NULL | — | Date cleared in bank |
| atp_usage_id | uuid | NULL | — | FK → atp_usage_logs.id |
| journal_entry_id | uuid | NULL | — | FK → journal_entries.id |
| *+ standard audit columns* | | | | |

---

### `receipt_lines`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| receipt_id | uuid | NOT NULL | — | FK → receipts.id |
| line_no | integer | NOT NULL | — | |
| applied_to_type | text | NOT NULL | — | CHECK IN ('sales_invoice','sales_debit_memo','advance') |
| applied_to_id | uuid | NULL | — | FK to applied document |
| applied_amount | numeric(18,4) | NOT NULL | — | Amount applied to this document |
| ewt_amount_received | numeric(18,4) | NOT NULL | 0 | 2307 amount withheld by customer |
| ewt_atc_id | uuid | NULL | — | FK → atc_codes.id |
| discount_taken | numeric(18,4) | NOT NULL | 0 | Early payment discount |

---

## SECTION 6: PURCHASING TRANSACTIONS

### `vendor_bills`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| *+ standard dimension columns* | | | | |
| *+ standard transaction header columns* | | | | |
| supplier_id | uuid | NOT NULL | — | FK → suppliers.id |
| supplier_name | text | NOT NULL | — | Snapshot |
| supplier_tin | text | NULL | — | Snapshot for RELIEF and 2307 |
| supplier_address | text | NULL | — | Snapshot |
| supplier_invoice_no | text | NULL | — | Supplier's own invoice number |
| supplier_invoice_date | date | NULL | — | Date on supplier's invoice |
| receiving_report_id | uuid | NULL | — | FK → receiving_reports.id |
| purchase_order_id | uuid | NULL | — | FK → purchase_orders.id |
| due_date | date | NULL | — | |
| payment_terms_id | uuid | NULL | — | FK → payment_terms.id |
| is_vat_inclusive | boolean | NOT NULL | false | |
| journal_entry_id | uuid | NULL | — | FK → journal_entries.id |
| *+ standard audit columns* | | | | |

---

### `vendor_bill_lines`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| vendor_bill_id | uuid | NOT NULL | — | FK → vendor_bills.id |
| line_no | integer | NOT NULL | — | |
| item_id | uuid | NULL | — | FK → items.id |
| service_id | uuid | NULL | — | FK → services.id |
| description | text | NOT NULL | — | |
| quantity | numeric(18,4) | NOT NULL | — | |
| uom_id | uuid | NOT NULL | — | FK → units_of_measure.id |
| unit_cost | numeric(18,4) | NOT NULL | — | |
| net_amount | numeric(18,4) | NOT NULL | — | Before VAT |
| input_vat_code_id | uuid | NULL | — | FK → vat_codes.id |
| vat_direction | text | NOT NULL | 'input' | CHECK IN ('input','input_deferred','capital_goods','exempt','zero_rated') |
| input_vat_rate | numeric(10,6) | NOT NULL | 0 | Snapshot |
| input_vat_amount | numeric(18,4) | NOT NULL | 0 | |
| total_amount | numeric(18,4) | NOT NULL | — | net_amount + vat_amount |
| ewt_atc_id | uuid | NULL | — | FK → atc_codes.id |
| ewt_rate | numeric(10,6) | NOT NULL | 0 | |
| ewt_amount | numeric(18,4) | NOT NULL | 0 | |
| expense_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| warehouse_id | uuid | NULL | — | FK → warehouses.id |
| *+ standard audit columns* | | | | |

---

### `cash_purchases`
Cash purchases — immediate payment, no AP created.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| *+ standard dimension columns* | | | | |
| *+ standard transaction header columns* | | | | |
| supplier_id | uuid | NULL | — | FK → suppliers.id (NULL for one-time vendor) |
| supplier_name | text | NOT NULL | — | Snapshot |
| supplier_tin | text | NULL | — | Snapshot for RELIEF (if applicable) |
| payment_method | text | NOT NULL | — | CHECK IN ('cash','check','bank_transfer','online') |
| check_no | text | NULL | — | |
| check_date | date | NULL | — | |
| bank_account_id | uuid | NULL | — | FK → company_bank_accounts.id |
| is_vat_inclusive | boolean | NOT NULL | false | |
| journal_entry_id | uuid | NULL | — | FK → journal_entries.id |
| *+ standard audit columns* | | | | |

---

### `cash_purchase_lines`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| cash_purchase_id | uuid | NOT NULL | — | FK → cash_purchases.id |
| line_no | integer | NOT NULL | — | |
| item_id | uuid | NULL | — | FK → items.id |
| service_id | uuid | NULL | — | FK → services.id |
| description | text | NOT NULL | — | |
| quantity | numeric(18,4) | NOT NULL | — | |
| uom_id | uuid | NOT NULL | — | FK → units_of_measure.id |
| unit_cost | numeric(18,4) | NOT NULL | — | |
| net_amount | numeric(18,4) | NOT NULL | — | |
| input_vat_code_id | uuid | NULL | — | FK → vat_codes.id |
| vat_direction | text | NOT NULL | 'input' | CHECK IN ('input','input_deferred','capital_goods','exempt','zero_rated') |
| input_vat_rate | numeric(10,6) | NOT NULL | 0 | |
| input_vat_amount | numeric(18,4) | NOT NULL | 0 | |
| total_amount | numeric(18,4) | NOT NULL | — | |
| ewt_atc_id | uuid | NULL | — | FK → atc_codes.id |
| ewt_rate | numeric(10,6) | NOT NULL | 0 | |
| ewt_amount | numeric(18,4) | NOT NULL | 0 | |
| expense_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| warehouse_id | uuid | NULL | — | FK → warehouses.id |
| *+ standard audit columns* | | | | |

---

### `payment_vouchers`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| *+ standard dimension columns* | | | | |
| *+ standard transaction header columns* | | | | |
| supplier_id | uuid | NOT NULL | — | FK → suppliers.id |
| supplier_name | text | NOT NULL | — | Snapshot |
| supplier_tin | text | NULL | — | Snapshot |
| payment_method | text | NOT NULL | — | CHECK IN ('cash','check','bank_transfer','online') |
| check_no | text | NULL | — | |
| check_date | date | NULL | — | |
| bank_account_id | uuid | NULL | — | FK → company_bank_accounts.id |
| gross_amount | numeric(18,4) | NOT NULL | 0 | Total before EWT deduction |
| total_ewt_amount | numeric(18,4) | NOT NULL | 0 | Total EWT withheld |
| net_of_ewt_amount | numeric(18,4) | NOT NULL | 0 | Actual cash paid (gross - EWT) |
| journal_entry_id | uuid | NULL | — | FK → journal_entries.id |
| *+ standard audit columns* | | | | |

---

### `payment_voucher_lines`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| payment_voucher_id | uuid | NOT NULL | — | FK → payment_vouchers.id |
| line_no | integer | NOT NULL | — | |
| applied_to_type | text | NOT NULL | — | CHECK IN ('vendor_bill','supplier_debit_memo','advance') |
| applied_to_id | uuid | NULL | — | FK to applied document |
| gross_amount | numeric(18,4) | NOT NULL | — | Bill amount being paid |
| ewt_amount | numeric(18,4) | NOT NULL | 0 | EWT withheld this line |
| ewt_atc_id | uuid | NULL | — | FK → atc_codes.id |
| net_amount | numeric(18,4) | NOT NULL | — | gross - ewt |
| discount_taken | numeric(18,4) | NOT NULL | 0 | |

---

### `petty_cash_vouchers`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| *+ standard dimension columns* | | | | |
| *+ standard transaction header columns* | | | | |
| petty_cash_fund_id | uuid | NOT NULL | — | FK → petty_cash_funds.id |
| payee_name | text | NOT NULL | — | Who was paid |
| payee_type | text | NOT NULL | 'supplier' | CHECK IN ('supplier','employee','other') |
| payee_id | uuid | NULL | — | FK to supplier/personnel.id |
| payment_method | text | NOT NULL | 'cash' | CHECK IN ('cash') |
| approved_by | uuid | NULL | — | FK → profiles.id |
| journal_entry_id | uuid | NULL | — | FK → journal_entries.id |
| *+ standard audit columns* | | | | |

---

### `petty_cash_voucher_lines`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| petty_cash_voucher_id | uuid | NOT NULL | — | FK → petty_cash_vouchers.id |
| line_no | integer | NOT NULL | — | |
| description | text | NOT NULL | — | |
| expense_account_id | uuid | NOT NULL | — | FK → chart_of_accounts.id |
| net_amount | numeric(18,4) | NOT NULL | — | Before VAT |
| vat_code_id | uuid | NULL | — | FK → vat_codes.id |
| vat_amount | numeric(18,4) | NOT NULL | 0 | |
| ewt_atc_id | uuid | NULL | — | FK → atc_codes.id (if EWT applies) |
| ewt_amount | numeric(18,4) | NOT NULL | 0 | |
| total_amount | numeric(18,4) | NOT NULL | — | |

---

## SECTION 7: BANK

### `bank_statement_lines`
Imported bank statement lines for reconciliation matching.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| bank_account_id | uuid | NOT NULL | — | FK → company_bank_accounts.id |
| bank_reconciliation_id | uuid | NULL | — | FK → bank_reconciliations.id (set when matched) |
| statement_date | date | NOT NULL | — | Date on bank statement |
| value_date | date | NULL | — | Value date if different |
| description | text | NOT NULL | — | Bank statement narration |
| reference | text | NULL | — | Bank reference number |
| debit_amount | numeric(18,4) | NOT NULL | 0 | |
| credit_amount | numeric(18,4) | NOT NULL | 0 | |
| balance | numeric(18,4) | NULL | — | Running balance per bank statement |
| reconciliation_status | text | NOT NULL | 'unmatched' | CHECK IN ('unmatched','matched','cleared','exception') |
| matched_to_type | text | NULL | — | 'receipt','payment_voucher','bank_adjustment','journal_entry' |
| matched_to_id | uuid | NULL | — | FK to matched record |
| import_batch_id | uuid | NULL | — | FK → import_batches.id |
| *+ standard audit columns* | | | | |

---

## SECTION 8: INVENTORY

### `inventory_cost_layers`
FIFO cost layers per item per warehouse. Written at goods receipt.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| item_id | uuid | NOT NULL | — | FK → items.id |
| warehouse_id | uuid | NOT NULL | — | FK → warehouses.id |
| source_document_type | text | NOT NULL | — | 'receiving_report','stock_adjustment','opening_stock' |
| source_document_id | uuid | NOT NULL | — | FK to source |
| source_line_id | uuid | NULL | — | FK to source line |
| layer_date | date | NOT NULL | — | Date of receipt/creation |
| original_quantity | numeric(18,4) | NOT NULL | — | Quantity received in this layer |
| remaining_quantity | numeric(18,4) | NOT NULL | — | Quantity not yet consumed |
| unit_cost | numeric(18,4) | NOT NULL | — | Cost per unit |
| total_cost | numeric(18,4) | NOT NULL | — | original_quantity × unit_cost |
| is_exhausted | boolean | NOT NULL | false | True when remaining_quantity = 0 |
| created_at | timestamptz | NOT NULL | now() | |
| created_by | uuid | NOT NULL | — | FK → profiles.id |

---

### `inventory_cost_layer_consumption`
Records FIFO cost layer depletion when inventory is reduced.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| cost_layer_id | uuid | NOT NULL | — | FK → inventory_cost_layers.id |
| inventory_movement_id | uuid | NOT NULL | — | FK → inventory_movements.id (the OUT movement) |
| consumed_quantity | numeric(18,4) | NOT NULL | — | Quantity consumed from this layer |
| unit_cost | numeric(18,4) | NOT NULL | — | Cost snapshot from layer |
| total_cost | numeric(18,4) | NOT NULL | — | consumed_quantity × unit_cost |
| consumed_at | timestamptz | NOT NULL | now() | |
| consumed_by | uuid | NOT NULL | — | FK → profiles.id (posting engine) |

---

## SECTION 9: ACCOUNTING

### `journal_entries`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| *+ standard dimension columns* | | | | |
| document_no | text | NOT NULL | — | JE number (from number_series) |
| document_date | date | NOT NULL | — | Accounting date |
| posting_date | date | NOT NULL | — | |
| fiscal_year_id | uuid | NOT NULL | — | FK → fiscal_years.id |
| fiscal_period_id | uuid | NOT NULL | — | FK → fiscal_periods.id |
| je_type | text | NOT NULL | — | CHECK IN ('manual','system','reversal','opening','recurring','adjustment') |
| source_document_type | text | NULL | — | 'sales_invoice','vendor_bill','cash_sale','cash_purchase', etc. |
| source_document_id | uuid | NULL | — | FK to source |
| description | text | NOT NULL | — | |
| total_debit | numeric(18,4) | NOT NULL | 0 | Must equal total_credit when posted |
| total_credit | numeric(18,4) | NOT NULL | 0 | |
| status | text | NOT NULL | 'draft' | CHECK IN ('draft','posted','reversed') |
| is_auto_generated | boolean | NOT NULL | false | True if system-generated from posting |
| reversal_of_je_id | uuid | NULL | — | FK → journal_entries.id |
| reversed_by_je_id | uuid | NULL | — | FK → journal_entries.id |
| recurring_template_id | uuid | NULL | — | FK → recurring_journal_templates.id |
| posted_at | timestamptz | NULL | — | |
| posted_by | uuid | NULL | — | FK → profiles.id |
| *+ standard audit columns* | | | | |

**Constraint:** `CHECK(total_debit = total_credit)` when status = 'posted'

---

### `journal_lines`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| journal_entry_id | uuid | NOT NULL | — | FK → journal_entries.id |
| line_no | integer | NOT NULL | — | |
| account_id | uuid | NOT NULL | — | FK → chart_of_accounts.id |
| branch_id | uuid | NULL | — | FK → branches.id |
| department_id | uuid | NULL | — | FK → departments.id |
| cost_center_id | uuid | NULL | — | FK → cost_centers.id |
| debit_amount | numeric(18,4) | NOT NULL | 0 | |
| credit_amount | numeric(18,4) | NOT NULL | 0 | |
| currency_id | uuid | NOT NULL | — | FK → currencies.id |
| exchange_rate | numeric(10,6) | NOT NULL | 1 | |
| functional_debit | numeric(18,4) | NOT NULL | 0 | In PHP |
| functional_credit | numeric(18,4) | NOT NULL | 0 | In PHP |
| description | text | NULL | — | Line narration |
| party_type | text | NULL | — | 'customer','supplier' |
| party_id | uuid | NULL | — | FK to customer or supplier |
| source_line_type | text | NULL | — | 'invoice_line','vat_entry','ewt_entry','header' |
| source_line_id | uuid | NULL | — | FK to source line |
| *+ standard audit columns* | | | | |

**Constraint:** `CHECK(debit_amount = 0 OR credit_amount = 0)`

---

### `gl_balances`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| account_id | uuid | NOT NULL | — | FK → chart_of_accounts.id |
| branch_id | uuid | NULL | — | NULL = company-wide total |
| fiscal_year_id | uuid | NOT NULL | — | FK → fiscal_years.id |
| fiscal_period_id | uuid | NOT NULL | — | FK → fiscal_periods.id |
| opening_debit | numeric(18,4) | NOT NULL | 0 | |
| opening_credit | numeric(18,4) | NOT NULL | 0 | |
| period_debit | numeric(18,4) | NOT NULL | 0 | |
| period_credit | numeric(18,4) | NOT NULL | 0 | |
| closing_debit | numeric(18,4) | NOT NULL | 0 | |
| closing_credit | numeric(18,4) | NOT NULL | 0 | |
| ytd_debit | numeric(18,4) | NOT NULL | 0 | Year-to-date |
| ytd_credit | numeric(18,4) | NOT NULL | 0 | |
| updated_at | timestamptz | NOT NULL | now() | |

**Unique:** `(company_id, account_id, branch_id, fiscal_period_id)`

---

## SECTION 10: COMPLIANCE

### `vat_entries`
Immutable. One row per taxable line per source document.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| branch_id | uuid | NULL | — | |
| fiscal_period_id | uuid | NOT NULL | — | FK → fiscal_periods.id |
| transaction_date | date | NOT NULL | — | |
| document_type | text | NOT NULL | — | 'sales_invoice','cash_sale','vendor_bill','cash_purchase', etc. |
| document_id | uuid | NOT NULL | — | FK to source document |
| document_no | text | NOT NULL | — | Snapshot |
| line_id | uuid | NOT NULL | — | FK to source document line |
| party_type | text | NOT NULL | — | CHECK IN ('customer','supplier') |
| party_id | uuid | NOT NULL | — | FK to customer/supplier |
| party_name | text | NOT NULL | — | Snapshot |
| party_tin | text | NULL | — | Snapshot — CRITICAL for SLSP/RELIEF |
| vat_direction | text | NOT NULL | — | CHECK IN ('output','input') |
| vat_classification | text | NOT NULL | — | CHECK IN ('vatable','zero_rated','exempt','government') |
| vat_code_id | uuid | NOT NULL | — | FK → vat_codes.id |
| net_amount | numeric(18,4) | NOT NULL | 0 | Amount before VAT (taxable base) |
| vat_amount | numeric(18,4) | NOT NULL | 0 | |
| total_amount | numeric(18,4) | NOT NULL | 0 | net_amount + vat_amount |

**Immutable. Never updated after creation.**

---

### `ewt_entries`
Immutable. One row per ATC per line per source document.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| branch_id | uuid | NULL | — | |
| fiscal_period_id | uuid | NOT NULL | — | FK → fiscal_periods.id |
| quarter | integer | NOT NULL | — | 1–4 |
| year | integer | NOT NULL | — | Calendar year |
| transaction_date | date | NOT NULL | — | |
| document_type | text | NOT NULL | — | 'vendor_bill','cash_purchase','payment_voucher','petty_cash_voucher' |
| document_id | uuid | NOT NULL | — | FK to source |
| document_no | text | NOT NULL | — | Snapshot |
| line_id | uuid | NULL | — | FK to source line (NULL if header-level EWT) |
| supplier_id | uuid | NOT NULL | — | FK → suppliers.id |
| supplier_name | text | NOT NULL | — | Snapshot |
| supplier_tin | text | NOT NULL | — | Snapshot — CRITICAL for 2307/QAP |
| supplier_address | text | NULL | — | Snapshot |
| atc_id | uuid | NOT NULL | — | FK → atc_codes.id |
| atc_code | text | NOT NULL | — | Snapshot e.g., 'WC010' |
| ewt_base_amount | numeric(18,4) | NOT NULL | 0 | Gross income subject to EWT |
| ewt_rate | numeric(10,6) | NOT NULL | 0 | Rate snapshot |
| ewt_amount | numeric(18,4) | NOT NULL | 0 | ewt_base_amount × ewt_rate |
| certificate_2307_id | uuid | NULL | — | FK → certificates_2307_issued.id (set on certificate generation) |

**Immutable. Never updated after creation.**

---

### `certificates_2307_issued`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| supplier_id | uuid | NOT NULL | — | FK → suppliers.id |
| supplier_name | text | NOT NULL | — | Snapshot |
| supplier_tin | text | NOT NULL | — | Snapshot |
| quarter | integer | NOT NULL | — | 1–4 |
| year | integer | NOT NULL | — | |
| certificate_no | text | NOT NULL | — | Sequential per company |
| date_issued | date | NOT NULL | — | |
| total_income_payments | numeric(18,4) | NOT NULL | 0 | |
| total_ewt_withheld | numeric(18,4) | NOT NULL | 0 | |
| atc_breakdown | jsonb | NOT NULL | '[]' | Per-ATC monthly breakdown [{atc, m1_base, m1_ewt, m2_base, m2_ewt, m3_base, m3_ewt}] |
| is_issued | boolean | NOT NULL | false | |
| issued_at | timestamptz | NULL | — | |
| issued_to | text | NULL | — | Email or method of delivery |
| generated_document_id | uuid | NULL | — | FK → generated_documents.id (PDF) |
| generated_at | timestamptz | NOT NULL | now() | |
| generated_by | uuid | NOT NULL | — | FK → profiles.id |

**Constraints:** `UNIQUE(company_id, supplier_id, quarter, year)` — one 2307 per supplier per quarter

---

### `certificates_2307_received`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| customer_id | uuid | NOT NULL | — | FK → customers.id |
| customer_name | text | NOT NULL | — | Snapshot |
| customer_tin | text | NOT NULL | — | Snapshot |
| receipt_id | uuid | NULL | — | FK → receipts.id (if tied to a specific receipt) |
| quarter | integer | NOT NULL | — | |
| year | integer | NOT NULL | — | |
| certificate_no | text | NOT NULL | — | Certificate number from customer |
| atc_code | text | NOT NULL | — | ATC code on received 2307 |
| income_payment_amount | numeric(18,4) | NOT NULL | 0 | |
| ewt_withheld_amount | numeric(18,4) | NOT NULL | 0 | |
| date_received | date | NOT NULL | — | |
| attachment_id | uuid | NULL | — | FK → attachments.id (scanned copy) |
| *+ standard audit columns* | | | | |

---

## SECTION 11: AUDIT

### `audit_logs`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NULL | — | NULL for platform-level events |
| user_id | uuid | NULL | — | FK → profiles.id |
| event_type | text | NOT NULL | — | See event type list in doc 07 |
| table_name | text | NOT NULL | — | Source table |
| record_id | uuid | NULL | — | Source record PK |
| document_no | text | NULL | — | For quick reference |
| description | text | NOT NULL | — | Human-readable |
| old_status | text | NULL | — | Previous status (for transitions) |
| new_status | text | NULL | — | New status |
| ip_address | inet | NULL | — | Client IP |
| user_agent | text | NULL | — | Browser/device |
| occurred_at | timestamptz | NOT NULL | now() | |
| session_id | text | NULL | — | |
| metadata | jsonb | NULL | — | Additional context |

**Immutable. No update. No delete.**

---

### `field_change_history`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NULL | — | |
| table_name | text | NOT NULL | — | |
| record_id | uuid | NOT NULL | — | PK of changed record |
| field_name | text | NOT NULL | — | Column name |
| old_value | text | NULL | — | Cast to text |
| new_value | text | NULL | — | Cast to text |
| change_type | text | NOT NULL | — | CHECK IN ('insert','update','delete') |
| changed_by | uuid | NOT NULL | — | FK → profiles.id |
| changed_at | timestamptz | NOT NULL | now() | |
| operation_id | uuid | NULL | — | Groups all field changes from one save |
| audit_log_id | uuid | NULL | — | FK → audit_logs.id |

---

### `document_void_register`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| document_type | text | NOT NULL | — | |
| document_id | uuid | NOT NULL | — | |
| document_no | text | NOT NULL | — | |
| document_date | date | NOT NULL | — | |
| original_amount | numeric(18,4) | NOT NULL | — | |
| void_reason | text | NOT NULL | — | Required |
| voided_at | timestamptz | NOT NULL | now() | |
| voided_by | uuid | NOT NULL | — | FK → profiles.id |
| reversal_je_id | uuid | NULL | — | FK → journal_entries.id |
| approved_by | uuid | NULL | — | FK → profiles.id (if void requires approval) |
| approved_at | timestamptz | NULL | — | |

---

## SECTION 12: NOTIFICATIONS

### `notification_templates`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NULL | — | NULL = platform-level template |
| event_type | text | NOT NULL | — | Matches `audit_logs.event_type` |
| channel | text | NOT NULL | — | CHECK IN ('in_app','email') |
| subject_template | text | NULL | — | Email subject (supports {variables}) |
| body_template | text | NOT NULL | — | Message body (supports {variables}) |
| is_active | boolean | NOT NULL | true | |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, event_type, channel)`

---

### `notifications`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| recipient_user_id | uuid | NOT NULL | — | FK → profiles.id |
| event_type | text | NOT NULL | — | |
| title | text | NOT NULL | — | Short title |
| body | text | NOT NULL | — | Full message |
| entity_type | text | NULL | — | Related table name |
| entity_id | uuid | NULL | — | Related record PK |
| entity_no | text | NULL | — | Related document_no (denormalized) |
| is_read | boolean | NOT NULL | false | |
| read_at | timestamptz | NULL | — | |
| created_at | timestamptz | NOT NULL | now() | |
| expires_at | timestamptz | NULL | — | Auto-dismiss after expiry |

---

### `notification_delivery_logs`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| notification_id | uuid | NOT NULL | — | FK → notifications.id |
| channel | text | NOT NULL | — | CHECK IN ('in_app','email') |
| status | text | NOT NULL | — | CHECK IN ('pending','sent','failed','skipped') |
| attempted_at | timestamptz | NOT NULL | now() | |
| delivered_at | timestamptz | NULL | — | |
| error_message | text | NULL | — | |
| retry_count | integer | NOT NULL | 0 | |

---

## SECTION 13: DOCUMENT TEMPLATES & GENERATED OUTPUT

### `document_templates`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| document_type | text | NOT NULL | — | 'sales_invoice','receipt','payment_voucher','2307', etc. |
| template_name | text | NOT NULL | — | |
| template_html | text | NOT NULL | — | HTML/Handlebars template content |
| is_default | boolean | NOT NULL | false | Default template for this doc type |
| paper_size | text | NOT NULL | 'a4' | CHECK IN ('a4','letter','legal') |
| orientation | text | NOT NULL | 'portrait' | CHECK IN ('portrait','landscape') |
| is_active | boolean | NOT NULL | true | |
| *+ standard audit columns* | | | | |

---

### `generated_documents`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| document_type | text | NOT NULL | — | Source document type |
| document_id | uuid | NOT NULL | — | FK to source document |
| document_no | text | NOT NULL | — | Snapshot |
| template_id | uuid | NULL | — | FK → document_templates.id |
| file_name | text | NOT NULL | — | Generated filename |
| storage_path | text | NOT NULL | — | Supabase Storage path |
| file_size_bytes | bigint | NULL | — | |
| file_hash_sha256 | text | NULL | — | Integrity check |
| version | integer | NOT NULL | 1 | |
| generated_at | timestamptz | NOT NULL | now() | |
| generated_by | uuid | NOT NULL | — | FK → profiles.id |
| expires_at | timestamptz | NULL | — | Auto-cleanup from storage |

---

### `generated_document_versions`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| generated_document_id | uuid | NOT NULL | — | FK → generated_documents.id (current version) |
| company_id | uuid | NOT NULL | — | |
| version | integer | NOT NULL | — | Version number superseded |
| storage_path | text | NOT NULL | — | Old storage path |
| file_hash_sha256 | text | NULL | — | |
| replaced_at | timestamptz | NOT NULL | now() | |
| replaced_by | uuid | NOT NULL | — | FK → profiles.id |

---

## SECTION 14: PERIOD CLOSE

### `period_close_checklists`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| fiscal_period_id | uuid | NOT NULL | — | FK → fiscal_periods.id |
| status | text | NOT NULL | 'in_progress' | CHECK IN ('in_progress','pending_lock','locked') |
| initiated_by | uuid | NOT NULL | — | FK → profiles.id |
| initiated_at | timestamptz | NOT NULL | now() | |
| completed_at | timestamptz | NULL | — | All tasks done |
| locked_at | timestamptz | NULL | — | Period locked |

**Constraints:** `UNIQUE(company_id, fiscal_period_id)`

---

### `period_close_tasks`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| checklist_id | uuid | NOT NULL | — | FK → period_close_checklists.id |
| task_code | text | NOT NULL | — | e.g., 'BANK_RECON','AR_AGREE','DEPRECIATION_RUN' |
| task_name | text | NOT NULL | — | Display label |
| is_mandatory | boolean | NOT NULL | true | Cannot waive |
| status | text | NOT NULL | 'pending' | CHECK IN ('pending','in_progress','completed','waived') |
| assigned_to | uuid | NULL | — | FK → profiles.id |
| completed_by | uuid | NULL | — | FK → profiles.id |
| completed_at | timestamptz | NULL | — | |
| waived_by | uuid | NULL | — | FK → profiles.id |
| waived_at | timestamptz | NULL | — | |
| waive_reason | text | NULL | — | Required if waived |
| notes | text | NULL | — | |

---

## SECTION 15: IMPORT / EXPORT

### `import_batches`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| import_type | text | NOT NULL | — | See import types in doc 08 |
| batch_name | text | NOT NULL | — | User-provided label |
| file_name | text | NOT NULL | — | Original uploaded filename |
| storage_path | text | NOT NULL | — | Supabase Storage path |
| file_format | text | NOT NULL | — | CHECK IN ('csv','xlsx','json') |
| column_mapping | jsonb | NULL | — | File column → DB column mapping |
| import_options | jsonb | NULL | — | skip_duplicates, update_existing, etc. |
| total_rows | integer | NOT NULL | 0 | |
| valid_rows | integer | NOT NULL | 0 | |
| error_rows | integer | NOT NULL | 0 | |
| imported_rows | integer | NOT NULL | 0 | |
| skipped_rows | integer | NOT NULL | 0 | |
| status | text | NOT NULL | 'pending' | CHECK IN ('pending','validating','validated','importing','completed','failed','rolled_back') |
| validation_completed_at | timestamptz | NULL | — | |
| import_started_at | timestamptz | NULL | — | |
| import_completed_at | timestamptz | NULL | — | |
| rolled_back_at | timestamptz | NULL | — | |
| rolled_back_by | uuid | NULL | — | FK → profiles.id |
| rollback_reason | text | NULL | — | |
| *+ standard audit columns* | | | | |

---

### `import_rows`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| import_batch_id | uuid | NOT NULL | — | FK → import_batches.id |
| row_number | integer | NOT NULL | — | Row in source file (1-based) |
| raw_data | jsonb | NOT NULL | — | Original row data |
| mapped_data | jsonb | NULL | — | After column mapping |
| status | text | NOT NULL | 'pending' | CHECK IN ('pending','valid','invalid','imported','skipped','rolled_back') |
| created_record_id | uuid | NULL | — | PK of created record |
| created_record_type | text | NULL | — | Table name |
| error_count | integer | NOT NULL | 0 | |
| processed_at | timestamptz | NULL | — | |

---

### `import_validation_errors`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | |
| import_batch_id | uuid | NOT NULL | — | FK → import_batches.id |
| import_row_id | uuid | NOT NULL | — | FK → import_rows.id |
| row_number | integer | NOT NULL | — | Denormalized |
| field_name | text | NOT NULL | — | |
| raw_value | text | NULL | — | |
| error_code | text | NOT NULL | — | |
| error_message | text | NOT NULL | — | |
| severity | text | NOT NULL | 'error' | CHECK IN ('error','warning') |
| created_at | timestamptz | NOT NULL | now() | |

---

## SECTION 16: SECURITY

### `profiles`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | — | PK = FK → auth.users.id |
| first_name | text | NOT NULL | — | |
| last_name | text | NOT NULL | — | |
| email | text | NOT NULL | — | Mirror of auth.users.email |
| phone | text | NULL | — | |
| avatar_url | text | NULL | — | Supabase Storage URL |
| job_title | text | NULL | — | |
| is_active | boolean | NOT NULL | true | |
| is_super_admin | boolean | NOT NULL | false | Platform-level admin only |
| last_login_at | timestamptz | NULL | — | |
| timezone | text | NOT NULL | 'Asia/Manila' | |
| locale | text | NOT NULL | 'en-PH' | |
| *+ standard audit columns* | | | | |

> `full_name` is a computed/virtual column: `first_name || ' ' || last_name` — not stored.

---

### `roles`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NULL | — | NULL = system role |
| code | text | NOT NULL | — | 'COMPANY_ADMIN','ACCOUNTANT','AR_CLERK', etc. |
| name | text | NOT NULL | — | |
| description | text | NULL | — | |
| is_system_role | boolean | NOT NULL | false | Cannot be deleted |
| is_active | boolean | NOT NULL | true | |
| *+ standard audit columns* | | | | |

---

### `permissions`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| module | text | NOT NULL | — | 'sales','purchasing','accounting','compliance', etc. |
| resource | text | NOT NULL | — | 'sales_invoices','journal_entries', etc. |
| action | text | NOT NULL | — | CHECK IN ('view','create','edit','delete','post','void','approve','export','admin') |
| code | text | NOT NULL | — | e.g., 'sales.sales_invoices.post' |
| description | text | NULL | — | |

**Constraints:** `UNIQUE(code)`

---

### `user_company_access`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| user_id | uuid | NOT NULL | — | FK → profiles.id |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| is_company_admin | boolean | NOT NULL | false | Admin for this company |
| is_active | boolean | NOT NULL | true | |
| granted_by | uuid | NOT NULL | — | FK → profiles.id |
| granted_at | timestamptz | NOT NULL | now() | |
| revoked_at | timestamptz | NULL | — | |
| revoked_by | uuid | NULL | — | FK → profiles.id |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(user_id, company_id)`

---

---

## SECTION 17: PERCENTAGE TAX (NON-VAT COMPANIES)

### `percentage_tax_entries`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| fiscal_year_id | uuid | NOT NULL | — | FK → fiscal_years.id |
| fiscal_period_id | uuid | NOT NULL | — | FK → fiscal_periods.id |
| source_document_id | uuid | NOT NULL | — | FK to cash_sales or sales_invoices |
| source_document_type | text | NOT NULL | — | 'cash_sales' or 'sales_invoices' |
| percentage_tax_code_id | uuid | NULL | — | FK → percentage_tax_codes.id |
| gross_receipts_amount | numeric(18,4) | NOT NULL | — | Gross receipts subject to PT |
| pt_rate | numeric(10,6) | NOT NULL | — | Rate applied (e.g., 0.030000 = 3%) |
| pt_amount | numeric(18,4) | NOT NULL | — | Computed PT amount |
| transaction_date | date | NOT NULL | — | Date of the source transaction |
| *+ standard audit columns* | | | | |

---

### `percentage_tax_period_summaries`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| fiscal_year_id | uuid | NOT NULL | — | FK → fiscal_years.id |
| fiscal_period_id | uuid | NOT NULL | — | FK → fiscal_periods.id |
| quarter | integer | NOT NULL | — | 1–4 |
| gross_receipts_total | numeric(18,4) | NOT NULL | 0 | Total gross receipts for the period |
| pt_amount_total | numeric(18,4) | NOT NULL | 0 | Total percentage tax for the period |
| status | text | NOT NULL | 'open' | CHECK IN ('open','filed') |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, fiscal_period_id)`

---

### `percentage_tax_return_filings`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| fiscal_year_id | uuid | NOT NULL | — | FK → fiscal_years.id |
| quarter | integer | NOT NULL | — | 1–4 |
| quarter_date_from | date | NOT NULL | — | Quarter start |
| quarter_date_to | date | NOT NULL | — | Quarter end |
| gross_receipts_amount | numeric(18,4) | NOT NULL | 0 | |
| pt_amount_due | numeric(18,4) | NOT NULL | 0 | |
| pt_amount_paid | numeric(18,4) | NOT NULL | 0 | |
| filing_status | text | NOT NULL | 'draft' | CHECK IN ('draft','filed','amended') |
| filing_date | date | NULL | — | Date actually filed |
| bir_confirmation_no | text | NULL | — | BIR confirmation number on filing |
| period_summary_id | uuid | NULL | — | FK → percentage_tax_period_summaries.id |
| export_job_id | uuid | NULL | — | FK → export_jobs.id |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, fiscal_year_id, quarter)`

---

## SECTION 18: FWT REMITTANCE

### `fwt_remittances_1601fq`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| fiscal_year_id | uuid | NOT NULL | — | FK → fiscal_years.id |
| quarter | integer | NOT NULL | — | 1–4 |
| quarter_date_from | date | NOT NULL | — | Quarter start |
| quarter_date_to | date | NOT NULL | — | Quarter end |
| fwt_amount_total | numeric(18,4) | NOT NULL | 0 | Total FWT due for quarter |
| fwt_amount_remitted | numeric(18,4) | NOT NULL | 0 | Amount remitted |
| filing_status | text | NOT NULL | 'draft' | CHECK IN ('draft','filed','amended') |
| filing_date | date | NULL | — | |
| bir_confirmation_no | text | NULL | — | |
| export_job_id | uuid | NULL | — | FK → export_jobs.id |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, fiscal_year_id, quarter)`

---

## SECTION 19: INCOME TAX RETURN FILINGS

### `income_tax_return_filings`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| fiscal_year_id | uuid | NOT NULL | — | FK → fiscal_years.id |
| filing_type | text | NOT NULL | — | CHECK IN ('quarterly','annual') |
| quarter | integer | NULL | — | 1–4 for quarterly; NULL for annual |
| form_code | text | NOT NULL | — | '1701Q','1701','1702Q','1702RT' — derived from income_tax_regime |
| taxable_income_amount | numeric(18,4) | NOT NULL | 0 | |
| income_tax_due | numeric(18,4) | NOT NULL | 0 | |
| mcit_amount | numeric(18,4) | NOT NULL | 0 | 0 if individual/partnership |
| income_tax_payable | numeric(18,4) | NOT NULL | 0 | Tax due minus creditable taxes |
| filing_status | text | NOT NULL | 'draft' | CHECK IN ('draft','filed','amended') |
| filing_date | date | NULL | — | |
| bir_confirmation_no | text | NULL | — | |
| itr_working_paper_id | uuid | NULL | — | FK → itr_working_papers.id |
| export_job_id | uuid | NULL | — | FK → export_jobs.id |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, fiscal_year_id, filing_type, quarter)`

---

## Open Decisions on Column Specifications

| # | Question | Affected Tables |
|---|---|---|
| OD-CS-01 | Store TIN with or without dashes? | Recommended: WITHOUT dashes internally, formatted on display. Validation at application layer. | companies, customers, suppliers, vat_entries, ewt_entries |
| OD-CS-02 | `atc_breakdown` jsonb in `certificates_2307_issued` — acceptable or normalize to separate table? | Recommended: jsonb for Phase 1 (3 months × 2 fields = small). Normalize in Phase 2 if query needs arise. | certificates_2307_issued |
| OD-CS-03 | `inventory_cost_layers.unit_cost` — store with or without VAT? | Recommended: EXCLUDING VAT (net cost only). Input VAT goes to its own GL account. | inventory_cost_layers |
| OD-CS-04 | GL balance updates: trigger-based or application-level (Edge Function)? | Recommended: Edge Function (posting engine) for atomicity and testability. Trigger as fallback guard. | gl_balances |
| OD-CS-05 | `document_no` assigned at DRAFT or at POST? | Recommended: At DRAFT (allocated from `number_series` with SELECT FOR UPDATE). Voided drafts consume their number per ATP rules. | all transaction tables |
| OD-CS-06 | `cash_sales.customer_id` — require or allow NULL for walk-in customers? | Recommended: NULL allowed. BIR allows aggregated walk-in sales below PHP threshold in SLSP. | cash_sales |

## Implementation Notes

- All `{party}_tin` snapshot columns on compliance tables (`vat_entries`, `ewt_entries`, etc.) must be populated at document posting time by copying from the master record. They must NOT be updated if the master TIN changes later.
- `vat_direction` replaces the ambiguous `vat_type` column from v1. Direction is either 'output' (sales) or 'input' (purchases). Classification (vatable/zero_rated/exempt) is separate.
- `cash_sales` and `cash_purchases` share the same structural pattern as `sales_invoices` and `vendor_bills` but have no AR/AP ledger impact.
- `petty_cash_voucher_lines` was missing in v1 — now fully specified. EWT on petty cash is captured at the line level, not deferred to replenishment.
