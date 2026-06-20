# PXL ERP — Table Column Specifications
**Version:** 1.0  
**Status:** For CPA and Developer Review

> Money fields use `numeric(18,4)`. Rates use `numeric(10,6)`. All timestamps are `timestamptz`. All PKs are `uuid`.  
> Standard audit columns (`created_at`, `created_by`, `updated_at`, `updated_by`, `deleted_at`, `deleted_by`) are listed once here and assumed on all tables marked with Soft Delete or Audit in the inventory.

---

## Standard Column Sets (Referenced Throughout)

### Standard Audit Columns (all tables)
```
created_at    timestamptz  NOT NULL  DEFAULT now()
created_by    uuid         NOT NULL  FK → profiles.id
updated_at    timestamptz  NULL
updated_by    uuid         NULL      FK → profiles.id
deleted_at    timestamptz  NULL      -- NULL = active, set = soft deleted
deleted_by    uuid         NULL      FK → profiles.id
```

### Standard Dimension Columns (operational tables)
```
company_id      uuid  NOT NULL  FK → companies.id
branch_id       uuid  NULL      FK → branches.id
department_id   uuid  NULL      FK → departments.id
cost_center_id  uuid  NULL      FK → cost_centers.id
```

### Standard Transaction Header Columns
```
document_no          text         NOT NULL  UNIQUE per company
document_date        date         NOT NULL
posting_date         date         NULL      -- set when posted
fiscal_year_id       uuid         NOT NULL  FK → fiscal_years.id
fiscal_period_id     uuid         NOT NULL  FK → fiscal_periods.id
currency_id          uuid         NOT NULL  FK → currencies.id  DEFAULT PHP
exchange_rate        numeric(10,6) NOT NULL DEFAULT 1.000000
status               text         NOT NULL  CHECK IN ('draft','submitted','approved','posted','voided','reversed')
subtotal_amount      numeric(18,4) NOT NULL DEFAULT 0
vat_amount           numeric(18,4) NOT NULL DEFAULT 0
withholding_amount   numeric(18,4) NOT NULL DEFAULT 0
total_amount         numeric(18,4) NOT NULL DEFAULT 0
remarks              text         NULL
posted_at            timestamptz  NULL
posted_by            uuid         NULL      FK → profiles.id
voided_at            timestamptz  NULL
voided_by            uuid         NULL      FK → profiles.id
void_reason          text         NULL
reversed_by_doc_id   uuid         NULL      -- FK to same table (reversal document)
source_document_id   uuid         NULL      -- FK to originating document
source_document_type text         NULL      -- 'sales_invoice', 'vendor_bill', etc.
```

---

## SECTION 1: ORGANIZATION

### `companies`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| code | text | NOT NULL | — | Short company code (unique) |
| name | text | NOT NULL | — | Full registered company name |
| trade_name | text | NULL | — | Trade/brand name |
| tin | text | NOT NULL | — | BIR Tax Identification Number (format: 000-000-000-000) |
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
| is_active | boolean | NOT NULL | true | — |
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
| is_active | boolean | NOT NULL | true | — |
| *+ standard audit columns* | | | | |

**Indexes:** `idx_branches_company_id`  
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
| parent_department_id | uuid | NULL | — | FK → departments.id (for hierarchy) |
| is_active | boolean | NOT NULL | true | — |
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
| is_active | boolean | NOT NULL | true | — |
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
| is_active | boolean | NOT NULL | true | — |
| *+ standard audit columns* | | | | |

---

### `cas_registrations`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| cas_permit_no | text | NOT NULL | — | BIR CAS permit number |
| date_issued | date | NOT NULL | — | Permit issue date |
| date_valid_from | date | NOT NULL | — | Validity start |
| date_valid_to | date | NULL | — | Validity end (NULL = no expiry) |
| system_name | text | NOT NULL | 'PXL ERP' | Registered system name |
| components_covered | text[] | NOT NULL | — | e.g., '{sales,purchasing,gl}' |
| atp_count | integer | NOT NULL | 0 | Number of ATPs under this CAS |
| *+ standard audit columns* | | | | |

---

## SECTION 2: SYSTEM CONTROLS

### `number_series`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| branch_id | uuid | NULL | — | FK → branches.id |
| document_type | text | NOT NULL | — | 'sales_invoice','receipt','vendor_bill', etc. |
| series_code | text | NOT NULL | — | Human label e.g. 'SI-2024' |
| prefix | text | NULL | — | Document prefix e.g. 'SI-' |
| suffix | text | NULL | — | Document suffix |
| pad_length | integer | NOT NULL | 6 | Zero-padding for number |
| current_number | bigint | NOT NULL | 0 | Last allocated number |
| min_number | bigint | NOT NULL | 1 | — |
| max_number | bigint | NOT NULL | 999999 | ATP upper limit |
| is_active | boolean | NOT NULL | true | — |
| effective_date | date | NOT NULL | — | When series takes effect |
| *+ standard audit columns* | | | | |

**Note:** `current_number` is updated with `SELECT FOR UPDATE` to prevent duplicates.

---

### `number_series_atp`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| number_series_id | uuid | NOT NULL | — | FK → number_series.id |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| atp_reference_no | text | NOT NULL | — | BIR ATP authority number |
| atp_date_issued | date | NOT NULL | — | — |
| atp_date_valid | date | NULL | — | Expiry date |
| range_from | bigint | NOT NULL | — | Starting number in ATP |
| range_to | bigint | NOT NULL | — | Ending number in ATP |
| *+ standard audit columns* | | | | |

---

### `approval_matrix`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| document_type | text | NOT NULL | — | 'sales_invoice','payment_voucher', etc. |
| name | text | NOT NULL | — | Matrix name |
| amount_threshold_min | numeric(18,4) | NULL | — | Apply when amount ≥ this |
| amount_threshold_max | numeric(18,4) | NULL | — | Apply when amount < this |
| approval_type | text | NOT NULL | 'sequential' | CHECK IN ('sequential','parallel','any_one') |
| is_active | boolean | NOT NULL | true | — |
| *+ standard audit columns* | | | | |

---

### `approval_matrix_steps`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| approval_matrix_id | uuid | NOT NULL | — | FK → approval_matrix.id |
| step_order | integer | NOT NULL | — | Sequence (1, 2, 3…) |
| approver_role_id | uuid | NULL | — | FK → roles.id (role-based) |
| approver_user_id | uuid | NULL | — | FK → profiles.id (specific user) |
| is_required | boolean | NOT NULL | true | — |
| *+ standard audit columns* | | | | |

---

### `fiscal_years`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| year_code | text | NOT NULL | — | e.g. 'FY2024' |
| date_from | date | NOT NULL | — | Fiscal year start |
| date_to | date | NOT NULL | — | Fiscal year end |
| is_current | boolean | NOT NULL | false | Only one TRUE per company |
| status | text | NOT NULL | 'open' | CHECK IN ('open','closed') |
| *+ standard audit columns* | | | | |

---

### `fiscal_periods`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| fiscal_year_id | uuid | NOT NULL | — | FK → fiscal_years.id |
| period_number | integer | NOT NULL | — | 1–12 for monthly |
| period_name | text | NOT NULL | — | e.g. 'January 2024' |
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
| locked_at | timestamptz | NOT NULL | now() | — |
| locked_by | uuid | NOT NULL | — | FK → profiles.id |
| lock_reason | text | NULL | — | — |
| unlocked_at | timestamptz | NULL | — | If unlocked (exception) |
| unlocked_by | uuid | NULL | — | FK → profiles.id |

---

## SECTION 3: CHART OF ACCOUNTS

### `chart_of_accounts`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| account_code | text | NOT NULL | — | e.g. '1010-001' |
| account_name | text | NOT NULL | — | — |
| account_type_id | uuid | NOT NULL | — | FK → account_types.id |
| parent_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| level | integer | NOT NULL | 1 | Hierarchy level (1=group, n=detail) |
| is_detail_account | boolean | NOT NULL | true | Only detail accounts can have JE lines |
| normal_balance | text | NOT NULL | — | CHECK IN ('debit','credit') |
| is_cash_equivalent | boolean | NOT NULL | false | For Cash Flow statement |
| fs_line_mapping | text | NULL | — | Financial statement line reference |
| vat_account_type | text | NULL | — | 'input_vat','output_vat','vat_payable', etc. |
| is_active | boolean | NOT NULL | true | — |
| *+ standard audit columns* | | | | |

**Indexes:** `idx_coa_company_code`, `idx_coa_parent`  
**Constraints:** `UNIQUE(company_id, account_code)`

---

### `account_types`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| code | text | NOT NULL | — | 'asset','liability','equity','revenue','expense' |
| name | text | NOT NULL | — | — |
| normal_balance | text | NOT NULL | — | CHECK IN ('debit','credit') |
| fs_category | text | NOT NULL | — | 'balance_sheet','income_statement' |
| sort_order | integer | NOT NULL | 0 | — |

---

## SECTION 4: MASTER DATA

### `customers`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| customer_code | text | NOT NULL | — | Unique customer code |
| customer_name | text | NOT NULL | — | Registered business name |
| trade_name | text | NULL | — | — |
| customer_type | text | NOT NULL | 'business' | CHECK IN ('individual','business','government') |
| tin | text | NULL | — | TIN (required for VAT customers) |
| vat_status | text | NOT NULL | 'vat' | CHECK IN ('vat','non_vat','exempt','zero_rated','government') |
| payment_terms_id | uuid | NULL | — | FK → payment_terms.id |
| ar_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| sales_account_id | uuid | NULL | — | FK → chart_of_accounts.id (default revenue account) |
| ewt_subject | boolean | NOT NULL | false | Subject to EWT on receipts |
| ewt_code_id | uuid | NULL | — | FK → ewt_codes.id (default) |
| currency_id | uuid | NOT NULL | — | FK → currencies.id (default PHP) |
| is_active | boolean | NOT NULL | true | — |
| import_batch_id | uuid | NULL | — | FK → import_batches.id |
| *+ standard audit columns* | | | | |

**Constraints:** `UNIQUE(company_id, customer_code)`

---

### `customer_tax_profiles`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| customer_id | uuid | NOT NULL | — | FK → customers.id |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| tin | text | NOT NULL | — | Customer TIN |
| bir_registered_address | text | NULL | — | — |
| bir_rdo_code | text | NULL | — | — |
| vat_registration_no | text | NULL | — | — |
| is_ewt_agent | boolean | NOT NULL | false | Customer is EWT withholding agent |
| default_ewt_atc_id | uuid | NULL | — | FK → atc_codes.id |
| effective_date | date | NOT NULL | — | — |
| *+ standard audit columns* | | | | |

---

### `suppliers`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| supplier_code | text | NOT NULL | — | Unique supplier code |
| supplier_name | text | NOT NULL | — | Registered business name |
| trade_name | text | NULL | — | — |
| supplier_type | text | NOT NULL | 'business' | CHECK IN ('individual','business','government') |
| tin | text | NULL | — | TIN (required for 2307) |
| vat_status | text | NOT NULL | 'vat' | CHECK IN ('vat','non_vat','exempt','zero_rated','government') |
| payment_terms_id | uuid | NULL | — | FK → payment_terms.id |
| ap_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| expense_account_id | uuid | NULL | — | FK → chart_of_accounts.id (default) |
| ewt_subject | boolean | NOT NULL | true | Subject to EWT on payments |
| ewt_code_id | uuid | NULL | — | FK → ewt_codes.id (default) |
| currency_id | uuid | NOT NULL | — | FK → currencies.id |
| is_active | boolean | NOT NULL | true | — |
| import_batch_id | uuid | NULL | — | FK → import_batches.id |
| *+ standard audit columns* | | | | |

---

### `payment_terms`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| code | text | NOT NULL | — | 'NET30','COD','CIA', etc. |
| name | text | NOT NULL | — | — |
| due_days | integer | NOT NULL | 0 | Days until due (0 = COD) |
| discount_days | integer | NULL | — | Days to qualify for early payment discount |
| discount_percent | numeric(10,6) | NULL | — | Early payment discount % |
| is_active | boolean | NOT NULL | true | — |
| *+ standard audit columns* | | | | |

---

### `items`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| item_code | text | NOT NULL | — | Unique item code |
| item_name | text | NOT NULL | — | — |
| description | text | NULL | — | — |
| item_category_id | uuid | NULL | — | FK → item_categories.id |
| base_uom_id | uuid | NOT NULL | — | FK → units_of_measure.id |
| item_type | text | NOT NULL | 'inventory' | CHECK IN ('inventory','non_inventory','service','fixed_asset') |
| vat_code_id | uuid | NULL | — | FK → vat_codes.id (sales VAT) |
| purchase_vat_code_id | uuid | NULL | — | FK → vat_codes.id (purchase VAT) |
| ewt_code_id | uuid | NULL | — | FK → ewt_codes.id (if EWT-subject) |
| sales_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| cogs_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| inventory_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| purchase_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| standard_cost | numeric(18,4) | NULL | — | Standard cost for valuation |
| standard_price | numeric(18,4) | NULL | — | Default selling price |
| is_tracked | boolean | NOT NULL | true | Track inventory quantity |
| is_active | boolean | NOT NULL | true | — |
| import_batch_id | uuid | NULL | — | FK → import_batches.id |
| *+ standard audit columns* | | | | |

---

### `warehouses`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| branch_id | uuid | NOT NULL | — | FK → branches.id |
| code | text | NOT NULL | — | Warehouse code |
| name | text | NOT NULL | — | — |
| address | text | NULL | — | Physical location |
| is_default | boolean | NOT NULL | false | Default warehouse for branch |
| is_active | boolean | NOT NULL | true | — |
| *+ standard audit columns* | | | | |

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
| customer_tin | text | NULL | — | Snapshot for compliance |
| customer_address | text | NULL | — | Snapshot |
| sales_order_id | uuid | NULL | — | FK → sales_orders.id |
| delivery_receipt_id | uuid | NULL | — | FK → delivery_receipts.id |
| due_date | date | NULL | — | Payment due date |
| payment_terms_id | uuid | NULL | — | FK → payment_terms.id |
| is_vat_inclusive | boolean | NOT NULL | false | Whether prices include VAT |
| vat_reg_no | text | NULL | — | Company VAT reg (from company setup) |
| invoice_type | text | NOT NULL | 'regular' | CHECK IN ('regular','vat_official','non_vat') |
| atp_usage_id | uuid | NULL | — | FK → atp_usage_logs.id |
| journal_entry_id | uuid | NULL | — | FK → journal_entries.id (set on post) |
| *+ standard audit columns* | | | | |

**Indexes:** `idx_si_company_date`, `idx_si_customer`, `idx_si_status`, `idx_si_fiscal_period`

---

### `sales_invoice_lines`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| sales_invoice_id | uuid | NOT NULL | — | FK → sales_invoices.id |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| line_no | integer | NOT NULL | — | Line sequence |
| item_id | uuid | NULL | — | FK → items.id (NULL for free-text) |
| service_id | uuid | NULL | — | FK → services.id |
| description | text | NOT NULL | — | Line description (snapshot) |
| quantity | numeric(18,4) | NOT NULL | — | — |
| uom_id | uuid | NOT NULL | — | FK → units_of_measure.id |
| unit_price | numeric(18,4) | NOT NULL | — | — |
| discount_percent | numeric(10,6) | NOT NULL | 0 | — |
| discount_amount | numeric(18,4) | NOT NULL | 0 | — |
| net_amount | numeric(18,4) | NOT NULL | — | After discount |
| vat_code_id | uuid | NULL | — | FK → vat_codes.id |
| vat_rate | numeric(10,6) | NOT NULL | 0 | Snapshot of rate |
| vat_amount | numeric(18,4) | NOT NULL | 0 | — |
| total_amount | numeric(18,4) | NOT NULL | — | Net + VAT |
| ewt_code_id | uuid | NULL | — | FK → ewt_codes.id (if subject) |
| ewt_rate | numeric(10,6) | NOT NULL | 0 | Snapshot |
| ewt_amount | numeric(18,4) | NOT NULL | 0 | — |
| revenue_account_id | uuid | NULL | — | FK → chart_of_accounts.id |
| warehouse_id | uuid | NULL | — | FK → warehouses.id |
| *+ standard audit columns* | | | | |

---

### `receipts`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| *+ standard dimension columns* | | | | |
| *+ standard transaction header columns* | | | | |
| customer_id | uuid | NOT NULL | — | FK → customers.id |
| customer_name | text | NOT NULL | — | Snapshot |
| customer_tin | text | NULL | — | Snapshot |
| payment_method | text | NOT NULL | — | CHECK IN ('cash','check','bank_transfer','online') |
| check_no | text | NULL | — | If payment_method = 'check' |
| check_date | date | NULL | — | — |
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
| receipt_id | uuid | NOT NULL | — | FK → receipts.id |
| company_id | uuid | NOT NULL | — | — |
| line_no | integer | NOT NULL | — | — |
| applied_to_type | text | NOT NULL | — | CHECK IN ('sales_invoice','debit_memo','advance') |
| applied_to_id | uuid | NULL | — | FK → source document |
| applied_amount | numeric(18,4) | NOT NULL | — | Amount applied |
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
| supplier_tin | text | NULL | — | Snapshot for compliance |
| supplier_address | text | NULL | — | Snapshot |
| supplier_invoice_no | text | NULL | — | Supplier's own invoice number |
| supplier_invoice_date | date | NULL | — | Date on supplier's invoice |
| receiving_report_id | uuid | NULL | — | FK → receiving_reports.id |
| purchase_order_id | uuid | NULL | — | FK → purchase_orders.id |
| due_date | date | NULL | — | — |
| payment_terms_id | uuid | NULL | — | FK → payment_terms.id |
| is_vat_inclusive | boolean | NOT NULL | false | — |
| journal_entry_id | uuid | NULL | — | FK → journal_entries.id |
| *+ standard audit columns* | | | | |

---

### `vendor_bill_lines`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| vendor_bill_id | uuid | NOT NULL | — | FK → vendor_bills.id |
| company_id | uuid | NOT NULL | — | — |
| line_no | integer | NOT NULL | — | — |
| item_id | uuid | NULL | — | FK → items.id |
| service_id | uuid | NULL | — | FK → services.id |
| description | text | NOT NULL | — | — |
| quantity | numeric(18,4) | NOT NULL | — | — |
| uom_id | uuid | NOT NULL | — | FK → units_of_measure.id |
| unit_cost | numeric(18,4) | NOT NULL | — | — |
| net_amount | numeric(18,4) | NOT NULL | — | — |
| input_vat_code_id | uuid | NULL | — | FK → vat_codes.id |
| input_vat_rate | numeric(10,6) | NOT NULL | 0 | Snapshot |
| input_vat_amount | numeric(18,4) | NOT NULL | 0 | — |
| total_amount | numeric(18,4) | NOT NULL | — | — |
| ewt_code_id | uuid | NULL | — | FK → ewt_codes.id |
| ewt_atc_id | uuid | NULL | — | FK → atc_codes.id |
| ewt_rate | numeric(10,6) | NOT NULL | 0 | — |
| ewt_amount | numeric(18,4) | NOT NULL | 0 | — |
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
| check_no | text | NULL | — | — |
| check_date | date | NULL | — | — |
| bank_account_id | uuid | NULL | — | FK → company_bank_accounts.id |
| net_of_ewt_amount | numeric(18,4) | NOT NULL | 0 | Amount actually paid (after EWT) |
| journal_entry_id | uuid | NULL | — | FK → journal_entries.id |
| *+ standard audit columns* | | | | |

---

### `payment_voucher_lines`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| payment_voucher_id | uuid | NOT NULL | — | FK → payment_vouchers.id |
| company_id | uuid | NOT NULL | — | — |
| line_no | integer | NOT NULL | — | — |
| applied_to_type | text | NOT NULL | — | CHECK IN ('vendor_bill','debit_memo','advance') |
| applied_to_id | uuid | NULL | — | FK → source document |
| gross_amount | numeric(18,4) | NOT NULL | — | Amount before EWT |
| ewt_amount | numeric(18,4) | NOT NULL | 0 | EWT withheld this line |
| ewt_atc_id | uuid | NULL | — | FK → atc_codes.id |
| net_amount | numeric(18,4) | NOT NULL | — | Amount paid |
| discount_taken | numeric(18,4) | NOT NULL | 0 | — |

---

## SECTION 7: ACCOUNTING — JOURNAL ENTRIES

### `journal_entries`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| *+ standard dimension columns* | | | | |
| document_no | text | NOT NULL | — | JE number |
| document_date | date | NOT NULL | — | — |
| posting_date | date | NOT NULL | — | — |
| fiscal_year_id | uuid | NOT NULL | — | FK → fiscal_years.id |
| fiscal_period_id | uuid | NOT NULL | — | FK → fiscal_periods.id |
| je_type | text | NOT NULL | — | 'manual','system','reversal','opening','recurring' |
| source_document_type | text | NULL | — | 'sales_invoice','vendor_bill', etc. |
| source_document_id | uuid | NULL | — | FK to source |
| description | text | NOT NULL | — | — |
| total_debit | numeric(18,4) | NOT NULL | 0 | Must equal total_credit |
| total_credit | numeric(18,4) | NOT NULL | 0 | — |
| status | text | NOT NULL | 'draft' | CHECK IN ('draft','posted','reversed') |
| is_auto_generated | boolean | NOT NULL | false | True if system-generated from posting |
| reversal_of_je_id | uuid | NULL | — | FK → journal_entries.id |
| reversed_by_je_id | uuid | NULL | — | FK → journal_entries.id |
| posted_at | timestamptz | NULL | — | — |
| posted_by | uuid | NULL | — | FK → profiles.id |
| *+ standard audit columns* | | | | |

**Constraint:** `CHECK(total_debit = total_credit)` when status = 'posted'

---

### `journal_lines`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| journal_entry_id | uuid | NOT NULL | — | FK → journal_entries.id |
| company_id | uuid | NOT NULL | — | — |
| line_no | integer | NOT NULL | — | — |
| account_id | uuid | NOT NULL | — | FK → chart_of_accounts.id |
| branch_id | uuid | NULL | — | FK → branches.id |
| department_id | uuid | NULL | — | FK → departments.id |
| cost_center_id | uuid | NULL | — | FK → cost_centers.id |
| debit_amount | numeric(18,4) | NOT NULL | 0 | — |
| credit_amount | numeric(18,4) | NOT NULL | 0 | — |
| currency_id | uuid | NOT NULL | — | FK → currencies.id |
| exchange_rate | numeric(10,6) | NOT NULL | 1 | — |
| functional_debit | numeric(18,4) | NOT NULL | 0 | In PHP |
| functional_credit | numeric(18,4) | NOT NULL | 0 | In PHP |
| description | text | NULL | — | Line narration |
| party_type | text | NULL | — | 'customer','supplier' |
| party_id | uuid | NULL | — | FK to customer or supplier |
| *+ standard audit columns* | | | | |

**Constraint:** `CHECK(debit_amount = 0 OR credit_amount = 0)` — one side only per line  
**Index:** `idx_jl_je_id`, `idx_jl_account_id`, `idx_jl_company_period`

---

### `gl_balances`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | — |
| account_id | uuid | NOT NULL | — | FK → chart_of_accounts.id |
| branch_id | uuid | NULL | — | — |
| fiscal_period_id | uuid | NOT NULL | — | FK → fiscal_periods.id |
| opening_debit | numeric(18,4) | NOT NULL | 0 | — |
| opening_credit | numeric(18,4) | NOT NULL | 0 | — |
| period_debit | numeric(18,4) | NOT NULL | 0 | — |
| period_credit | numeric(18,4) | NOT NULL | 0 | — |
| closing_debit | numeric(18,4) | NOT NULL | 0 | — |
| closing_credit | numeric(18,4) | NOT NULL | 0 | — |
| updated_at | timestamptz | NOT NULL | now() | — |

**Unique:** `(company_id, account_id, branch_id, fiscal_period_id)`

---

## SECTION 8: COMPLIANCE

### `vat_entries`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | — |
| branch_id | uuid | NULL | — | — |
| fiscal_period_id | uuid | NOT NULL | — | FK → fiscal_periods.id |
| transaction_date | date | NOT NULL | — | — |
| document_type | text | NOT NULL | — | 'sales_invoice','vendor_bill', etc. |
| document_id | uuid | NOT NULL | — | FK to source document |
| document_no | text | NOT NULL | — | Snapshot |
| line_id | uuid | NOT NULL | — | FK to source document line |
| party_type | text | NOT NULL | — | CHECK IN ('customer','supplier') |
| party_id | uuid | NOT NULL | — | FK to customer/supplier |
| party_name | text | NOT NULL | — | Snapshot |
| party_tin | text | NULL | — | Snapshot — CRITICAL for SLSP |
| vat_type | text | NOT NULL | — | CHECK IN ('output','input') |
| vat_code_id | uuid | NOT NULL | — | FK → vat_codes.id |
| vat_classification | text | NOT NULL | — | CHECK IN ('vatable','zero_rated','exempt') |
| taxable_amount | numeric(18,4) | NOT NULL | 0 | — |
| vat_amount | numeric(18,4) | NOT NULL | 0 | — |
| total_amount | numeric(18,4) | NOT NULL | 0 | — |

**Immutable.** Never updated after creation.  
**Index:** `idx_vat_entries_company_period`, `idx_vat_entries_type`

---

### `ewt_entries`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | — |
| branch_id | uuid | NULL | — | — |
| fiscal_period_id | uuid | NOT NULL | — | — |
| transaction_date | date | NOT NULL | — | — |
| document_type | text | NOT NULL | — | 'vendor_bill','payment_voucher','cash_purchase' |
| document_id | uuid | NOT NULL | — | FK to source |
| document_no | text | NOT NULL | — | Snapshot |
| supplier_id | uuid | NOT NULL | — | FK → suppliers.id |
| supplier_name | text | NOT NULL | — | Snapshot |
| supplier_tin | text | NOT NULL | — | CRITICAL for 2307/QAP |
| supplier_address | text | NULL | — | Snapshot |
| atc_id | uuid | NOT NULL | — | FK → atc_codes.id |
| atc_code | text | NOT NULL | — | Snapshot |
| ewt_base_amount | numeric(18,4) | NOT NULL | 0 | Amount subject to EWT |
| ewt_rate | numeric(10,6) | NOT NULL | 0 | Rate snapshot |
| ewt_amount | numeric(18,4) | NOT NULL | 0 | Amount withheld |
| quarter | integer | NOT NULL | — | 1–4 |
| year | integer | NOT NULL | — | Calendar year |
| certificate_no_2307 | text | NULL | — | Assigned 2307 certificate number |

---

### `certificates_2307_issued`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | — |
| supplier_id | uuid | NOT NULL | — | FK → suppliers.id |
| supplier_name | text | NOT NULL | — | Snapshot |
| supplier_tin | text | NOT NULL | — | Snapshot |
| quarter | integer | NOT NULL | — | 1–4 |
| year | integer | NOT NULL | — | — |
| date_issued | date | NOT NULL | — | — |
| certificate_no | text | NOT NULL | — | Certificate number |
| total_income_payments | numeric(18,4) | NOT NULL | 0 | — |
| total_ewt_withheld | numeric(18,4) | NOT NULL | 0 | — |
| atc_breakdown | jsonb | NOT NULL | '[]' | Per-ATC amounts for 2307 lines |
| ewt_period_summary_id | uuid | NULL | — | FK → ewt_period_summaries.id |
| generated_at | timestamptz | NOT NULL | now() | — |
| generated_by | uuid | NOT NULL | — | FK → profiles.id |

---

### `certificates_2307_received`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | — |
| customer_id | uuid | NOT NULL | — | FK → customers.id |
| customer_name | text | NOT NULL | — | Snapshot |
| customer_tin | text | NOT NULL | — | Snapshot |
| receipt_id | uuid | NULL | — | FK → receipts.id |
| quarter | integer | NOT NULL | — | — |
| year | integer | NOT NULL | — | — |
| certificate_no | text | NOT NULL | — | Received cert number |
| income_payment_amount | numeric(18,4) | NOT NULL | 0 | — |
| ewt_withheld_amount | numeric(18,4) | NOT NULL | 0 | — |
| atc_code | text | NOT NULL | — | — |
| date_received | date | NOT NULL | — | — |
| *+ standard audit columns* | | | | |

---

## SECTION 9: AUDIT

### `audit_logs`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NULL | — | NULL for system-level events |
| user_id | uuid | NULL | — | FK → profiles.id |
| event_type | text | NOT NULL | — | 'create','update','delete','post','void','login','export', etc. |
| table_name | text | NOT NULL | — | Source table |
| record_id | uuid | NULL | — | Source record PK |
| document_no | text | NULL | — | For quick reference |
| description | text | NOT NULL | — | Human-readable event description |
| ip_address | inet | NULL | — | Client IP |
| user_agent | text | NULL | — | Browser/device info |
| occurred_at | timestamptz | NOT NULL | now() | — |
| session_id | text | NULL | — | Auth session ID |
| metadata | jsonb | NULL | — | Additional context |

**Immutable. No updates or deletes allowed.**  
**Index:** `idx_audit_company_date`, `idx_audit_table_record`, `idx_audit_user`

---

### `field_change_history`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NULL | — | — |
| table_name | text | NOT NULL | — | Table where change occurred |
| record_id | uuid | NOT NULL | — | PK of changed record |
| field_name | text | NOT NULL | — | Column name that changed |
| old_value | text | NULL | — | Cast to text |
| new_value | text | NULL | — | Cast to text |
| changed_by | uuid | NOT NULL | — | FK → profiles.id |
| changed_at | timestamptz | NOT NULL | now() | — |
| audit_log_id | uuid | NULL | — | FK → audit_logs.id |

---

### `document_void_register`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | — |
| document_type | text | NOT NULL | — | 'sales_invoice','receipt', etc. |
| document_id | uuid | NOT NULL | — | — |
| document_no | text | NOT NULL | — | — |
| document_date | date | NOT NULL | — | — |
| original_amount | numeric(18,4) | NOT NULL | — | — |
| void_reason | text | NOT NULL | — | — |
| voided_at | timestamptz | NOT NULL | now() | — |
| voided_by | uuid | NOT NULL | — | FK → profiles.id |
| reversal_je_id | uuid | NULL | — | FK → journal_entries.id |

---

## SECTION 10: IMPORT / EXPORT

### `import_batches`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NOT NULL | — | — |
| import_type | text | NOT NULL | — | 'customers','suppliers','items','opening_balances', etc. |
| file_name | text | NOT NULL | — | Original uploaded filename |
| file_url | text | NOT NULL | — | Supabase Storage URL |
| total_rows | integer | NOT NULL | 0 | — |
| valid_rows | integer | NOT NULL | 0 | — |
| error_rows | integer | NOT NULL | 0 | — |
| imported_rows | integer | NOT NULL | 0 | — |
| status | text | NOT NULL | 'pending' | CHECK IN ('pending','validating','valid','invalid','importing','completed','failed') |
| started_at | timestamptz | NULL | — | — |
| completed_at | timestamptz | NULL | — | — |
| *+ standard audit columns* | | | | |

---

### `import_rows`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| import_batch_id | uuid | NOT NULL | — | FK → import_batches.id |
| row_number | integer | NOT NULL | — | Row in source file |
| raw_data | jsonb | NOT NULL | — | Original row as JSON |
| mapped_data | jsonb | NULL | — | After field mapping |
| status | text | NOT NULL | 'pending' | CHECK IN ('pending','valid','invalid','imported','skipped') |
| created_record_id | uuid | NULL | — | PK of created record if successful |
| created_record_type | text | NULL | — | Table name |

---

### `import_validation_errors`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| import_row_id | uuid | NOT NULL | — | FK → import_rows.id |
| field_name | text | NOT NULL | — | Field with error |
| error_code | text | NOT NULL | — | 'required','invalid_format','not_found', etc. |
| error_message | text | NOT NULL | — | Human-readable message |
| value_provided | text | NULL | — | What the user gave |

---

## SECTION 11: SECURITY

### `profiles`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | — | FK → auth.users.id (PK) |
| first_name | text | NOT NULL | — | — |
| last_name | text | NOT NULL | — | — |
| display_name | text | NULL | — | — |
| email | text | NOT NULL | — | Mirror of auth.users.email |
| phone | text | NULL | — | — |
| avatar_url | text | NULL | — | — |
| is_active | boolean | NOT NULL | true | — |
| last_login_at | timestamptz | NULL | — | — |
| *+ standard audit columns* | | | | |

---

### `roles`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| company_id | uuid | NULL | — | NULL = system role, set = company-specific |
| code | text | NOT NULL | — | 'admin','accountant','cashier','viewer', etc. |
| name | text | NOT NULL | — | — |
| description | text | NULL | — | — |
| is_system_role | boolean | NOT NULL | false | Cannot be deleted |
| *+ standard audit columns* | | | | |

---

### `permissions`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| module | text | NOT NULL | — | 'sales','purchasing','accounting', etc. |
| resource | text | NOT NULL | — | 'sales_invoices','journal_entries', etc. |
| action | text | NOT NULL | — | 'view','create','edit','delete','post','void','approve','export' |
| code | text | NOT NULL | — | e.g. 'sales.invoices.post' |
| description | text | NULL | — | — |

**Constraint:** `UNIQUE(code)`

---

### `user_company_access`
| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| id | uuid | NOT NULL | gen_random_uuid() | PK |
| user_id | uuid | NOT NULL | — | FK → profiles.id |
| company_id | uuid | NOT NULL | — | FK → companies.id |
| is_company_admin | boolean | NOT NULL | false | Admin for this company |
| *+ standard audit columns* | | | | |

**Constraint:** `UNIQUE(user_id, company_id)`

---

## Open Decisions on Column Specifications

| # | Question | Affected Tables |
|---|---|---|
| OD-CS-01 | Store TIN with or without dashes? Validate format at DB or app level? | customers, suppliers, companies, vat_entries, ewt_entries |
| OD-CS-02 | `jsonb` for `atc_breakdown` in 2307 — acceptable or normalize to separate table? | certificates_2307_issued |
| OD-CS-03 | Inventory cost layers: store unit_cost per layer or compute on query? | inventory_cost_layers |
| OD-CS-04 | GL balance updates: trigger-based or application-level? | gl_balances |
| OD-CS-05 | Should `document_no` be generated before or after save (DRAFT)? | all transaction tables |
