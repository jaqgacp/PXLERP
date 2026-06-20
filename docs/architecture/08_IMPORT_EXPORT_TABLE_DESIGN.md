# PXL ERP — Import & Export Table Design
**Version:** 2.0 — Revised for Implementation Readiness
**Status:** For CPA and Developer Review

---

## Changes Applied (v1 → v2)

- Expanded `import_type` list to include all Setup and Master Data modules (payment_terms, approval_matrix, atc_codes, warehouses, units_of_measure, etc.) — not only transactional data
- Added `attachment_versions` full table specification (new in v2)
- Added `file_hash_sha256` to `attachments` table
- Confirmed `export_jobs` table name (was `export_batches` in v1 doc 02 — now consistent across all docs)
- Added `cash_sale` and `cash_purchase` to export types (new transaction types in v2)
- Added compliance output export types: `compliance_report_run_id` link on export_jobs
- Added `import_batch_id` column reference note: all master data tables carry this column
- Added `EMPLOYEES` import type marked as OUT OF SCOPE for Phase 1

---

## Open Decisions Remaining

| OD # | Question | Status |
|---|---|---|
| OD-17 | Should attachment storage use a single bucket per company or a single shared bucket with folder-based separation? | Recommended: single shared bucket with `company_id/entity_type/entity_id/` path structure. Confirm before Supabase Storage setup. |
| OD-18 | Should the import template (column mapping) be saved per import_type so users don't re-map columns on every import? | Recommended: Yes — store as `import_column_templates` table (Phase 2). Phase 1: column_mapping stored per batch. |

---

## Implementation Notes

- Every record created by a bulk import must carry `import_batch_id`. This is the only reliable rollback mechanism (soft-delete all records with matching `import_batch_id`).
- Import rollback is available only for records that have NOT been posted. Posted journal entries from opening balance imports cannot be rolled back via batch — they require a manual reversal JE.
- `attachment_versions` allows re-upload of the same attachment (e.g., corrected invoice scan). The latest version is `is_current = true`; previous versions are retained.
- `export_jobs` uses Supabase Realtime so the user gets live progress feedback. The generated file is stored in Supabase Storage; the download link is generated on-demand with a signed URL.

---

## 1. Overview

MSME companies migrating to PXL ERP need to bulk-import setup data, master data, and opening balances. Every bulk-created record carries `import_batch_id` for full traceability and rollback support.

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

| import_type | Category | Target Tables |
|---|---|---|
| `chart_of_accounts` | Setup | `chart_of_accounts` |
| `payment_terms` | Setup | `payment_terms`, `payment_term_lines` |
| `atc_codes` | Setup | `atc_codes` |
| `tax_codes` | Setup | `tax_codes` (VAT classification master) |
| `warehouses` | Setup | `warehouses`, `warehouse_locations` |
| `units_of_measure` | Setup | `units_of_measure` |
| `approval_matrix` | Setup | `approval_matrix`, `approval_matrix_steps` |
| `customers` | Master Data | `customers`, `customer_tax_profiles`, `customer_addresses` |
| `suppliers` | Master Data | `suppliers`, `supplier_tax_profiles`, `supplier_addresses` |
| `items` | Master Data | `items`, `item_units_of_measure` |
| `price_lists` | Master Data | `item_price_lists` |
| `bank_accounts` | Master Data | `company_bank_accounts` |
| `opening_balances` | Opening | `opening_balance_entries` → `journal_entries` |
| `ar_opening` | Opening | `subsidiary_ledger_entries` (AR), customer outstanding invoices |
| `ap_opening` | Opening | `subsidiary_ledger_entries` (AP), supplier outstanding bills |
| `inventory_opening` | Opening | `inventory_cost_layers`, `inventory_movements` |
| `fixed_assets_opening` | Opening | `fixed_assets`, `asset_depreciation_schedule` |
| `employees` | OUT OF SCOPE | Phase 1 — HR module excluded |

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
| `WAREHOUSE_NOT_FOUND` | Warehouse code not in master list |
| `ATC_NOT_FOUND` | ATC code not in atc_codes master list |
| `PAYMENT_TERMS_NOT_FOUND` | Payment terms code not in master list |

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
| `created_by` | uuid | FK auth.users, NOT NULL | |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |

---

## 4. Export / Report Generation Tables

### `export_jobs`
Tracks asynchronous report/export generation jobs. Supabase Realtime enabled.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `export_type` | text | NOT NULL | See export types below |
| `parameters` | jsonb | NOT NULL | Filter params: date range, accounts, branches, etc. |
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
| `compliance_report_run_id` | uuid | FK compliance_report_runs, NULL | Set when export is a compliance form |

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
| `cash_sales_book` | BIR Book: Cash Sales |
| `cash_purchases_book` | BIR Book: Cash Purchases |
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
| `budget_vs_actual` | Budget vs Actual Variance Report |

---

## 5. Attachment Tables

### `attachments`
Metadata for all uploaded files. Supabase Storage holds the actual files.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `entity_type` | text | NOT NULL | Table name of related record (polymorphic) |
| `entity_id` | uuid | NOT NULL | PK of related record |
| `file_name` | text | NOT NULL | Original filename |
| `file_size_bytes` | bigint | NOT NULL | |
| `mime_type` | text | NOT NULL | |
| `storage_bucket` | text | NOT NULL | Supabase Storage bucket name |
| `storage_path` | text | NOT NULL | Path within bucket |
| `file_hash_sha256` | text | NULL | SHA-256 checksum of uploaded file |
| `description` | text | NULL | User-provided label |
| `is_primary` | boolean | NOT NULL DEFAULT false | Primary/featured attachment |
| `current_version_id` | uuid | FK attachment_versions, NULL | Points to the current version |
| `uploaded_by` | uuid | FK auth.users, NOT NULL | |
| `uploaded_at` | timestamptz | NOT NULL DEFAULT now() | |
| `deleted_at` | timestamptz | NULL | Soft delete |
| `deleted_by` | uuid | FK auth.users, NULL | |

**Supported entity types:**
`sales_invoices` | `vendor_bills` | `receipts` | `payment_vouchers` | `cash_sales` | `cash_purchases` | `journal_entries` | `petty_cash_vouchers` | `purchase_orders` | `goods_receipts` | `bank_reconciliations` | `fixed_assets` | `customers` | `suppliers`

---

### `attachment_versions`
Version history for re-uploaded attachments.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `attachment_id` | uuid | FK attachments, NOT NULL | |
| `version_number` | integer | NOT NULL | Sequential, starts at 1 |
| `file_name` | text | NOT NULL | Filename for this version |
| `file_size_bytes` | bigint | NOT NULL | |
| `mime_type` | text | NOT NULL | |
| `storage_path` | text | NOT NULL | Supabase Storage path for this version |
| `file_hash_sha256` | text | NULL | SHA-256 checksum of this version |
| `is_current` | boolean | NOT NULL DEFAULT true | Only one version is current per attachment |
| `uploaded_by` | uuid | FK auth.users, NOT NULL | |
| `uploaded_at` | timestamptz | NOT NULL DEFAULT now() | |
| `upload_reason` | text | NULL | Why this version was uploaded |

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
6. User approves import (all-or-nothing for VALID rows; ERROR rows are skipped)
7. IMPORT PASS:
   a. For each VALID row: create target record(s)
   b. Set created_record_id on import_rows
   c. Set import_batch_id on created records
   d. Update import_rows.status = 'IMPORTED'
   e. Update import_batches.status = 'COMPLETED'
8. Audit log: BULK_IMPORT_COMPLETED
9. Notify initiator: import completed (row counts, error summary)
```

### Rollback

- Only available for imports where no records have been posted
- Sets `deleted_at` on all records with matching `import_batch_id`
- Updates `import_batches.status = 'ROLLED_BACK'`
- Creates `audit_logs` entry (event_type='BULK_IMPORT_ROLLED_BACK')
- Opening balance journal entries that have been POSTED cannot be rolled back via batch — require manual reversal JE
