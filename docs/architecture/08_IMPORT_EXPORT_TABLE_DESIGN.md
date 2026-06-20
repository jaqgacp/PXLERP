# PXL ERP — Import & Export Table Design
**Version:** 1.0 — Blueprint Locked  
**Status:** For CPA and Developer Review

---

## 1. Overview

MSME companies migrating to PXL ERP need to bulk-import:
- Chart of accounts
- Customers and suppliers
- Items and inventory
- Opening balances
- Historical AR/AP balances

Every bulk-created record carries `import_batch_id` for full traceability and rollback support.

---

## 2. Import Tables

### `import_batches`
Header record for every import operation.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `batch_name` | text | NOT NULL | User-provided label |
| `import_type` | text | NOT NULL | See import types below |
| `source_filename` | text | NULL | Original uploaded filename |
| `storage_path` | text | NULL | Supabase Storage path of uploaded file |
| `file_format` | text | CHECK IN ('CSV','XLSX','JSON') | |
| `total_rows` | integer | NOT NULL DEFAULT 0 | Rows in file |
| `processed_rows` | integer | NOT NULL DEFAULT 0 | Rows attempted |
| `success_rows` | integer | NOT NULL DEFAULT 0 | Rows successfully imported |
| `error_rows` | integer | NOT NULL DEFAULT 0 | Rows with errors |
| `skipped_rows` | integer | NOT NULL DEFAULT 0 | Rows skipped (duplicates, etc.) |
| `status` | text | CHECK IN ('PENDING','VALIDATING','VALIDATED','IMPORTING','COMPLETED','FAILED','ROLLED_BACK') | |
| `validation_completed_at` | timestamptz | NULL | |
| `import_started_at` | timestamptz | NULL | |
| `import_completed_at` | timestamptz | NULL | |
| `rolled_back_at` | timestamptz | NULL | |
| `rolled_back_by` | uuid | FK auth.users, NULL | |
| `rollback_reason` | text | NULL | |
| `column_mapping` | jsonb | NULL | Maps file columns to DB columns |
| `import_options` | jsonb | NULL | e.g., skip_duplicates, update_existing |
| `created_by` | uuid | FK auth.users, NOT NULL | |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |
| `notes` | text | NULL | |

### Import Types

| import_type | Target Tables |
|---|---|
| `chart_of_accounts` | `chart_of_accounts` |
| `customers` | `customers`, `customer_tax_profiles`, `customer_addresses` |
| `suppliers` | `suppliers`, `supplier_tax_profiles`, `supplier_addresses` |
| `items` | `items`, `item_units_of_measure` |
| `opening_balances` | `opening_balance_entries` → `journal_entries` |
| `ar_opening` | `customers`, `subsidiary_ledger_entries` (AR) |
| `ap_opening` | `suppliers`, `subsidiary_ledger_entries` (AP) |
| `inventory_opening` | `items`, `inventory_cost_layers`, `inventory_movements` |
| `fixed_assets_opening` | `fixed_assets`, `asset_depreciation_schedule` |
| `employees` | `employees` (if HR module in scope) |
| `price_lists` | `item_price_lists` |
| `bank_accounts` | `company_bank_accounts` |

---

### `import_rows`
One record per row in the import file.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `batch_id` | uuid | FK import_batches, NOT NULL | |
| `row_number` | integer | NOT NULL | Row number in source file (1-based) |
| `raw_data` | jsonb | NOT NULL | Original row data as key-value |
| `mapped_data` | jsonb | NULL | After column mapping applied |
| `status` | text | CHECK IN ('PENDING','VALID','ERROR','IMPORTED','SKIPPED','ROLLED_BACK') | |
| `created_record_id` | uuid | NULL | UUID of the record created by this row |
| `created_record_type` | text | NULL | Table name of created record |
| `error_count` | integer | NOT NULL DEFAULT 0 | |
| `processed_at` | timestamptz | NULL | |

---

### `import_validation_errors`
All validation errors per import row.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `batch_id` | uuid | FK import_batches, NOT NULL | |
| `row_id` | uuid | FK import_rows, NOT NULL | |
| `row_number` | integer | NOT NULL | Denormalized for quick display |
| `field_name` | text | NOT NULL | Column with the error |
| `raw_value` | text | NULL | Value that caused the error |
| `error_code` | text | NOT NULL | Machine-readable error code |
| `error_message` | text | NOT NULL | Human-readable description |
| `severity` | text | CHECK IN ('ERROR','WARNING'), NOT NULL DEFAULT 'ERROR' | WARNING rows can still import |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |

### Common Error Codes

| Code | Description |
|---|---|
| `REQUIRED_MISSING` | Required field is blank |
| `INVALID_FORMAT` | Field doesn't match expected format |
| `INVALID_TIN` | TIN format invalid (PH: 999-999-999-000) |
| `DUPLICATE_CODE` | Record with same code already exists |
| `PARENT_NOT_FOUND` | Referenced parent record doesn't exist |
| `ACCOUNT_NOT_FOUND` | GL account code not in COA |
| `AMOUNT_INVALID` | Amount is negative or non-numeric |
| `DATE_INVALID` | Date format invalid |
| `PERIOD_CLOSED` | Transaction date falls in closed period |
| `TIN_MISMATCH` | TIN already registered to a different name |
| `UOM_NOT_FOUND` | Unit of measure not in master list |
| `EXCEEDS_MAX_LENGTH` | Text exceeds maximum allowed length |

---

## 3. Opening Balance Tables

### `opening_balance_entries`
Stores opening balances before they are converted to journal entries.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `branch_id` | uuid | FK branches, NULL | |
| `account_id` | uuid | FK chart_of_accounts, NOT NULL | |
| `fiscal_year_id` | uuid | FK fiscal_years, NOT NULL | First fiscal year |
| `balance_type` | text | CHECK IN ('DEBIT','CREDIT'), NOT NULL | Normal balance side |
| `amount` | numeric(18,4) | NOT NULL | |
| `notes` | text | NULL | |
| `import_batch_id` | uuid | FK import_batches, NULL | |
| `posted_journal_entry_id` | uuid | FK journal_entries, NULL | Set when posted |
| `is_posted` | boolean | NOT NULL DEFAULT false | |
| `created_by` | uuid | FK auth.users | |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |

---

## 4. Export / Report Generation Tables

### `export_jobs`
Tracks asynchronous report/export generation jobs.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `export_type` | text | NOT NULL | See export types below |
| `parameters` | jsonb | NOT NULL | Filter params: date range, accounts, etc. |
| `format` | text | CHECK IN ('PDF','XLSX','CSV','DAT','JSON') | |
| `status` | text | CHECK IN ('QUEUED','PROCESSING','COMPLETED','FAILED') | |
| `requested_by` | uuid | FK auth.users, NOT NULL | |
| `requested_at` | timestamptz | NOT NULL DEFAULT now() | |
| `started_at` | timestamptz | NULL | |
| `completed_at` | timestamptz | NULL | |
| `storage_path` | text | NULL | Supabase Storage path when done |
| `file_size_bytes` | bigint | NULL | |
| `record_count` | integer | NULL | |
| `error_message` | text | NULL | |
| `expires_at` | timestamptz | NULL | When to auto-delete from storage |

### Export Types

| export_type | Description |
|---|---|
| `trial_balance` | Trial Balance report |
| `balance_sheet` | Balance Sheet |
| `income_statement` | Income Statement / P&L |
| `general_ledger` | GL detail per account |
| `general_journal` | All journal entries |
| `ar_aging` | AR Aging Report |
| `ap_aging` | AP Aging Report |
| `cash_receipts_book` | BIR Book: Cash Receipts |
| `cash_disbursements_book` | BIR Book: Cash Disbursements |
| `sales_book` | BIR Book: Sales |
| `purchases_book` | BIR Book: Purchases |
| `vat_2550m` | BIR Form 2550M |
| `vat_2550q` | BIR Form 2550Q |
| `slsp_sales` | SLSP (Sales) quarterly |
| `slsp_purchases` | SLSP (Purchases) / RELIEF |
| `ewt_1601eq` | BIR Form 1601EQ |
| `qap` | QAP DAT file |
| `sawt` | SAWT |
| `2307_issued` | Batch 2307 certificates |
| `2307_received` | 2307 received summary |
| `dat_gl` | CAS DAT File: GL |
| `dat_sl` | CAS DAT File: SL |
| `dat_sls` | CAS DAT File: Sales |
| `dat_pur` | CAS DAT File: Purchases |
| `dat_inv` | CAS DAT File: Inventory |
| `inventory_valuation` | Inventory Valuation Report |
| `fixed_asset_schedule` | Fixed Asset Lapsing Schedule |

---

## 5. Attachment Tables

### `attachments`
Metadata for all uploaded files (Supabase Storage holds the actual files).

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `entity_type` | text | NOT NULL | Table name of related record |
| `entity_id` | uuid | NOT NULL | PK of related record |
| `file_name` | text | NOT NULL | Original filename |
| `file_size_bytes` | bigint | NOT NULL | |
| `mime_type` | text | NOT NULL | |
| `storage_bucket` | text | NOT NULL | Supabase Storage bucket name |
| `storage_path` | text | NOT NULL | Path within bucket |
| `description` | text | NULL | User-provided label |
| `is_primary` | boolean | NOT NULL DEFAULT false | Primary/thumbnail attachment |
| `uploaded_by` | uuid | FK auth.users, NOT NULL | |
| `uploaded_at` | timestamptz | NOT NULL DEFAULT now() | |
| `deleted_at` | timestamptz | NULL | Soft delete |
| `deleted_by` | uuid | FK auth.users, NULL | |

Supported entity types: `sales_invoices`, `vendor_bills`, `receipts`, `payment_vouchers`, `journal_entries`, `petty_cash_vouchers`, `purchase_orders`, `goods_receipts`, `bank_reconciliations`, `fixed_assets`

---

## 6. Import Process Flow

```
1. User uploads file → Supabase Storage
2. Edge Function creates import_batches record (status='PENDING')
3. Edge Function reads file, creates import_rows (status='PENDING')
4. VALIDATION PASS:
   a. For each row: validate required fields, formats, references
   b. Create import_validation_errors for failures
   c. Update import_rows.status = 'VALID' | 'ERROR'
   d. Update import_batches.status = 'VALIDATED'
   e. Update counts: total_rows, error_rows, success_rows
5. User reviews validation results
6. User approves import
7. IMPORT PASS:
   a. For each VALID row: create target record(s)
   b. Set created_record_id on import_rows
   c. Set import_batch_id on created records
   d. Update import_rows.status = 'IMPORTED'
   e. Update import_batches.status = 'COMPLETED'
8. Audit log: BULK_IMPORT_COMPLETED
```

### Rollback
- Only available for imports that have NOT been posted
- Sets `deleted_at` on all records with matching `import_batch_id`
- Updates `import_batches.status = 'ROLLED_BACK'`
- Creates audit log entry
