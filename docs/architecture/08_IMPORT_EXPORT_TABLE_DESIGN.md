# PXL ERP — Import & Export Table Design
**Version:** 3.8 — Implementation Contract Completion Pass
**Status:** v3.8 — Import and export contracts complete. Not Yet Migration-Approved — pending Sections 47–53 sign-off.

---

## v3 Architecture Review Changes Applied

- **New import types added**: `coa_fs_mapping`, `income_tax_mappings`, `party_special_class` — see Import Types table below.
- **`itr_working_papers` export**: Renamed to `itr_computation_runs` in export_jobs export_type list.
- **`mcit_computations` export**: REMOVED (subsumed into `itr_computation_runs` record; no separate export).
- **`nolco_schedules` export**: REMOVED; replaced by `nolco_tracking` export type.
- **Party classification import**: `party_special_class` bulk import allows updating customers/suppliers.party_special_class in batch — needed for companies migrating from systems where government/PEZA customers were not separately flagged.

## v3 Open Decisions — ALL RESOLVED (v3.7)

| OD# | Decision | **RESOLUTION** |
|---|---|---|
| OD-08-V3-01 | `coa_fs_mapping` import — partial update or always overwrite? | **RESOLVED v3.7:** Always overwrite with explicit confirmation prompt. The import UI must display a "This will overwrite all existing FS mapping classifications for your COA. Proceed?" warning before import begins. Always overwrite (not merge) ensures the imported CPA-approved template is applied cleanly without old stale values mixing in. Developer: on import execution, run `UPDATE chart_of_accounts SET fs_section=?, fs_group=?, fs_sort_order=?, cash_flow_category=? WHERE company_id=? AND account_code=?` for each row. |
| OD-08-V3-02 | `income_tax_mappings` import — require CPA review flag? | **RESOLVED v3.7:** Yes. The import_type `income_tax_mappings` (updates `is_mcit_gross_income`, `is_osd_gross_revenue`, `tax_deductibility` on COA) requires the caller to have role `CONTROLLER` or `COMPANY_ADMIN`. The Edge Function checks this before processing. Developer: `IF auth.uid() NOT IN (SELECT user_id FROM user_roles WHERE company_id=? AND role IN ('controller','company_admin')) THEN ABORT`. |

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

## Open Decisions — ALL RESOLVED (v3.7)

| OD # | Question | **RESOLUTION** |
|---|---|---|
| OD-17 | Single bucket or per-company bucket for attachments? | **RESOLVED v3.7:** Single shared Supabase Storage bucket named `erp-attachments` with path structure `{company_id}/{entity_type}/{entity_id}/{filename}`. Supabase Storage RLS policies restrict download to authenticated users whose `company_id` matches the path prefix. Developer: `attachments.storage_path = '{company_id}/{entity_type}/{entity_id}/{uuid}_{original_filename}'`. The storage bucket name is `erp-attachments`. RLS policy: `USING (auth.uid() IN (SELECT user_id FROM user_company_access WHERE company_id = (storage.foldername(name))[1]::uuid))`. |
| OD-18 | Save import column mapping templates? | **RESOLVED v3.7:** Phase 2. In Phase 1, `import_batches.column_mapping jsonb` stores the mapping used for each individual import. The user must re-map columns on each import. The `import_templates` table (#174) exists in the schema but the column mapping save/load feature is Phase 2. Developer: `import_templates` table may be created in Phase 1 migration but the UI save/load feature is deferred. |

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
| `file_format` | text | CHECK IN ('csv','xlsx','json') | **[v3.6 fix: lowercase per architecture convention; matches Doc03 §15]** |
| `total_rows` | integer | NOT NULL DEFAULT 0 | Rows in file |
| `processed_rows` | integer | NOT NULL DEFAULT 0 | Rows attempted |
| `success_rows` | integer | NOT NULL DEFAULT 0 | Rows successfully imported |
| `error_rows` | integer | NOT NULL DEFAULT 0 | Rows with errors |
| `skipped_rows` | integer | NOT NULL DEFAULT 0 | Rows skipped (duplicates, etc.) |
| `status` | text | CHECK IN ('pending','validating','validated','importing','completed','failed','rolled_back') | |
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
| `compliance_profile` | Setup | `company_compliance_profiles` |
| `feature_settings` | Setup | `company_feature_settings` |
| `chart_of_accounts` | Setup | `chart_of_accounts` |
| `payment_terms` | Setup | `payment_terms`, `payment_term_lines` |
| `atc_codes` | Setup | `atc_codes` |
| `tax_codes` | Setup | `tax_codes` (VAT classification master) |
| `warehouses` | Setup | `warehouses` — `warehouse_locations` is Phase 2 only |
| `units_of_measure` | Setup | `units_of_measure` |
| `approval_matrix` | Setup | `approval_matrix`, `approval_matrix_steps` |
| `customers` | Master Data | `customers`, `customer_tax_profiles`, `customer_addresses` |
| `suppliers` | Master Data | `suppliers`, `supplier_tax_profiles`, `supplier_addresses` |
| `items` | Master Data | `items`, `uom_conversions` (UOM conversion ratios via `units_of_measure`) **[v3.6 fix: `item_units_of_measure` was ghost name; canonical bridge table is `uom_conversions` #53]** |
| `item_prices` | Master Data | `item_prices` (#46) — **[F-2 fix: was `price_lists`→`item_price_lists`, both were ghost names]** |
| `bank_accounts` | Master Data | `company_bank_accounts` |
| `opening_balances` | Opening | `opening_balance_entries` → `journal_entries` |
| `ar_opening` | Opening | `subsidiary_ledger_entries` (AR), customer outstanding invoices |
| `ap_opening` | Opening | `subsidiary_ledger_entries` (AP), supplier outstanding bills |
| `inventory_opening` | Opening | `inventory_cost_layers`, `inventory_movements` |
| `fixed_assets_opening` | Opening | `fixed_assets`, `asset_depreciation_schedules` **[v3.6 fix: `asset_depreciation_schedule` was ghost name (missing plural 's'); canonical: `asset_depreciation_schedules` #122]** |
| `coa_fs_mapping` | Setup (v3) | `chart_of_accounts` — bulk update fs_section, fs_group, fs_sort_order, cash_flow_category fields |
| `income_tax_mappings` | Setup (v3) | `chart_of_accounts` — bulk update is_mcit_gross_income, is_osd_gross_revenue, tax_deductibility fields |
| `party_special_class` | Master Data (v3) | `customers`, `suppliers` — bulk set party_special_class (government/peza/boi/foreign_entity) |
| `nolco_tracking` | Compliance (v3) | `nolco_tracking` — import historical NOLCO balances from prior years |
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
| `status` | text | CHECK IN ('pending','valid','invalid','imported','skipped','rolled_back') | — **['error' corrected to 'invalid' to match Doc03 §15 canonical spec]** |
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
| `severity` | text | CHECK IN ('error','warning'), NOT NULL DEFAULT 'error' | 'warning' rows can still import **[v3.6 fix: lowercase per architecture convention; matches Doc03 §15]** |
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
| `balance_type` | text | CHECK IN ('debit','credit'), NOT NULL | Normal balance side |
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
| `format` | text | CHECK IN ('pdf','xlsx','csv','dat','json') | |
| `status` | text | CHECK IN ('queued','processing','completed','failed') | |
| `requested_by` | uuid | FK auth.users, NOT NULL | |
| `requested_at` | timestamptz | NOT NULL DEFAULT now() | |
| `started_at` | timestamptz | NULL | |
| `completed_at` | timestamptz | NULL | |
| `storage_path` | text | NULL | Supabase Storage path when done |
| `file_size_bytes` | bigint | NULL | |
| `record_count` | integer | NULL | |
| `error_message` | text | NULL | |
| `expires_at` | timestamptz | NULL | When to auto-delete from storage |

> **F-3 fix:** `compliance_report_run_id` column removed — `compliance_report_runs` is not a canonical table (#189 `export_jobs` replaced it). Compliance report exports are identified by `export_jobs.export_type` (e.g., `'vat_2550m'`, `'ewt_1601eq'`) and linked to their output files via `generated_report_files.export_job_id`. No separate compliance_report_run_id FK exists.

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
| `pt_2551q` | BIR Form 2551Q (Percentage Tax — NON-VAT companies only) |
| `fwt_1601fq` | BIR Form 1601FQ (Final Withholding Tax) |
| `itr_1701q` | BIR Form 1701Q (Quarterly ITR — Individual / Sole Proprietor) |
| `itr_1701` | BIR Form 1701 (Annual ITR — Individual / Sole Proprietor) |
| `itr_1702q` | BIR Form 1702Q (Quarterly ITR — Corporate / OPC / Partnership) |
| `itr_1702rt` | BIR Form 1702RT (Annual ITR — Corporate / OPC / Partnership) |
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
`sales_invoices` | `vendor_bills` | `receipts` | `payment_vouchers` | `cash_sales` | `cash_purchases` | `journal_entries` | `petty_cash_vouchers` | `purchase_orders` | `receiving_reports` | `bank_reconciliations` | `fixed_assets` | `customers` | `suppliers`

> **F-1 fix:** `official_receipts` → `receipts` (#71); `disbursement_vouchers` → `payment_vouchers` (#87). Ghost names removed.

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
2. Edge Function creates import_batches record (status='pending')
3. Edge Function reads file, creates import_rows (status='pending')
4. VALIDATION PASS:
   a. For each row: validate required fields, formats, references
   b. Create import_validation_errors for failures
   c. Update import_rows.status = 'valid' | 'invalid'
   d. Update import_batches.status = 'validated'
   e. Update counts: total_rows, error_rows, success_rows
5. User reviews validation results
6. User approves import (all-or-nothing for valid rows; error rows are skipped)
7. IMPORT PASS:
   a. For each valid row: create target record(s)
   b. Set created_record_id on import_rows
   c. Set import_batch_id on created records
   d. Update import_rows.status = 'imported'
   e. Update import_batches.status = 'completed'
8. Audit log: BULK_IMPORT_COMPLETED
9. Notify initiator: import completed (row counts, error summary)
```

### Rollback

- Only available for imports where no records have been posted
- Sets `deleted_at` on all records with matching `import_batch_id`
- Updates `import_batches.status = 'rolled_back'` **[v3.6 fix: lowercase]**
- Creates `audit_logs` entry (event_type='BULK_IMPORT_ROLLED_BACK')
- Opening balance journal entries that have been POSTED cannot be rolled back via batch — require manual reversal JE
