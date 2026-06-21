# PXL ERP — Audit and CAS Table Design
**Version:** 4.0 — Canonical Release
**Status:** v4.0 — DATABASE FREEZE CANDIDATE. Pending human sign-off (see Doc10 Sections 47–53).

---

## Resolved Architectural Decisions

| Decision | Resolution |
|---|---|
| `COA_FS_MAPPING_CHANGED` — `metadata` jsonb or `field_change_history`? | Use `field_change_history`. When `chart_of_accounts` FS mapping columns change (`fs_section`, `fs_group`, `fs_sort_order`, `cash_flow_category`), the standard field_change_history trigger fires and captures old/new per-field. `audit_logs` receives a single event `COA_FS_MAPPING_CHANGED` with `entity_type='chart_of_accounts'` and `entity_id=coa.id`. No duplication in `metadata` jsonb. |
| `ITR_COMPUTATION_RUN_CREATED` — `entity_id` = run or filing? | `entity_id = itr_computation_runs.id`. The run is the primary audit entity. `metadata` jsonb includes `{ "itr_filing_id": "uuid" }` for cross-reference to the parent `income_tax_return_filings` record. Consistent with `AMORTIZATION_RUN_COMPLETED` pattern. |
| `system_alerts` on Supabase Realtime? | Yes. `system_alerts` is added to the Supabase Realtime publication list (confirmed in Doc09 Section 6). Admins and controllers subscribed to `system_alerts` receive live ATP gap alerts and low-stock alerts without polling. RLS ensures only company_admin and controller roles see their company's alerts. |
| `user_activity_logs` partitioned by month? | Phase 1: single table with composite index `(company_id, occurred_at DESC)`. No partitioning in Phase 1. Phase 2: if table exceeds 10M rows per company per year, add monthly range partitioning by `occurred_at`. Partitioning can be added with `ATTACH PARTITION` without recreating the table. |

---

## Implementation Notes

- `audit_logs`, `field_change_history`, `atp_usage_logs`, `document_void_register` are insert-only. The application role must have INSERT but NOT UPDATE or DELETE on these tables.
- `number_series.current_number` is updated via `SELECT FOR UPDATE` to prevent race conditions in concurrent document creation.
- `system_alerts` is the output table for the nightly pg_cron ATP gap detection job. It is readable by company admins and controllers.
- The field_change_history trigger must skip `gl_balances`, `audit_logs`, `field_change_history` itself, and notification delivery tables to prevent trigger loops.
- Approval audit tables (`approval_requests`, `approval_actions`) have Supabase Realtime enabled.

---

## 1. Overview

BIR CAS (Computerized Accounting System) accreditation mandates a complete, tamper-evident audit trail. This document covers all tables that implement the three-layer audit architecture and CAS compliance logging.

**Three Layers:**
1. **Record-level** — `created_by`, `updated_by`, `deleted_by` on every operational table
2. **Field-level** — `field_change_history` captures before/after values on every field change
3. **Event-level** — `audit_logs` and `user_activity_logs` capture every significant action

---

## 2. Event Audit Log

### `audit_logs`
> Column spec: See Doc03 Section 41 (`audit_logs`). This document retains the authoritative event type list below. **No RLS update or delete policies. Insert-only.**

### Event Type Values

| Event Type | Description |
|---|---|
| `DOCUMENT_CREATED` | New document created |
| `DOCUMENT_SUBMITTED` | Submitted for approval |
| `DOCUMENT_APPROVED` | Approved by approver |
| `DOCUMENT_REJECTED` | Rejected by approver |
| `DOCUMENT_POSTED` | Posted (journal entries created) |
| `DOCUMENT_VOIDED` | Document voided |
| `DOCUMENT_REVERSED` | Document reversed |
| `DOCUMENT_PRINTED` | Document printed/exported to PDF |
| `CASH_SALE_POSTED` | Cash sale posted (DR Cash / CR Revenue + Output VAT) |
| `CASH_PURCHASE_POSTED` | Cash purchase posted (DR Inventory/Expense + Input VAT / CR Cash) |
| `RECORD_CREATED` | Master data record created |
| `RECORD_UPDATED` | Master data record updated |
| `RECORD_DELETED` | Soft delete applied |
| `RECORD_RESTORED` | Soft delete reversed |
| `BULK_IMPORT_STARTED` | Import batch initiated |
| `BULK_IMPORT_COMPLETED` | Import batch completed |
| `BULK_IMPORT_ROLLED_BACK` | Import batch rolled back (soft delete) |
| `PERIOD_CLOSED` | Fiscal period closed |
| `PERIOD_LOCKED` | Fiscal period locked |
| `PERIOD_UNLOCKED` | Fiscal period unlocked (exceptional) |
| `PERIOD_CLOSE_STARTED` | Period close checklist created |
| `PERIOD_CLOSE_TASK_COMPLETED` | A period close task marked COMPLETED |
| `PERIOD_CLOSE_CERTIFIED` | Subledger close certified |
| `DAT_FILE_GENERATED` | CAS DAT file exported |
| `COMPLIANCE_REPORT_GENERATED` | BIR report generated |
| `GENERATED_DOCUMENT_CREATED` | PDF document generated (invoice, receipt, 2307) |
| `DOCUMENT_TEMPLATE_PUBLISHED` | Document template activated |
| `NOTIFICATION_SENT` | Notification dispatched to delivery channel |
| `NOTIFICATION_FAILED` | Notification delivery failed |
| `PARTY_MERGED` | Customer/supplier records merged (duplicate TIN) |
| `DUPLICATE_TIN_FLAGGED` | Duplicate TIN warning raised |
| `PARTY_SPECIAL_CLASS_CHANGED` | customers/suppliers.party_special_class changed (affects VAT routing) |
| `COA_FS_MAPPING_CHANGED` | fs_section/fs_group/fs_sort_order/cash_flow_category changed on a COA account |
| `AMORTIZATION_SCHEDULE_CREATED` | New amortization schedule created |
| `AMORTIZATION_RUN_COMPLETED` | Amortization run batch completed |
| `AMORTIZATION_ENTRY_CREATED` | Individual amortization JE generated |
| `REVENUE_RECOGNITION_SCHEDULE_CREATED` | New revenue recognition schedule created |
| `REVENUE_RECOGNITION_RUN_COMPLETED` | Revenue recognition run batch completed |
| `REVENUE_RECOGNITION_ENTRY_CREATED` | Individual revenue recognition JE generated |
| `AUTO_REVERSAL_RUN_COMPLETED` | Auto reversal batch run completed |
| `AUTO_REVERSAL_CREATED` | Individual auto-reversal JE generated |
| `RECURRING_JE_GENERATED` | Journal entry generated from recurring template |
| `ITR_COMPUTATION_RUN_CREATED` | New itr_computation_runs record created |
| `NOLCO_UPDATED` | nolco_tracking record updated (applied amount or expiry changed) |
| `BOOK_TAX_RECONCILIATION_COMPLETED` | book_tax_reconciliations finalized for a computation run |
| `POSTING_RULE_VERSIONED` | posting_rule_sets effective_from/effective_to versioned (new version created) |
| `USER_ASSIGNED_ROLE` | Role assigned to user |
| `USER_ROLE_REMOVED` | Role removed from user |
| `APPROVAL_MATRIX_CHANGED` | Approval matrix modified |
| `POSTING_RULE_CHANGED` | Posting rule set modified |
| `COMPLIANCE_PROFILE_CHANGED` | Company compliance profile updated (e.g., taxpayer type changed from NON-VAT to VAT) |
| `FEATURE_SETTING_CHANGED` | Company feature settings updated (module visibility changed) |
| `PERCENTAGE_TAX_RETURN_FILED` | 2551Q filed |
| `FWT_REMITTANCE_FILED` | 1601FQ filed |
| `INCOME_TAX_RETURN_FILED` | ITR filed (1701Q/1701/1702Q/1702RT) |
| `SYSTEM_CONFIG_CHANGED` | System account config changed |

---

## 3. Field Change History

### `field_change_history`
Captures before/after values for every field modified on audited tables. Immutable.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `table_name` | text | NOT NULL | PostgreSQL table name |
| `record_id` | uuid | NOT NULL | PK of the changed record |
| `field_name` | text | NOT NULL | Column name that changed |
| `old_value` | text | NULL | Serialized old value (NULL if new record) |
| `new_value` | text | NULL | Serialized new value (NULL if deleted) |
| `change_type` | text | CHECK IN ('insert','update','delete'), NOT NULL | **[v3.6 fix: lowercase per architecture convention]** |
| `changed_by` | uuid | FK auth.users, NOT NULL | |
| `changed_at` | timestamptz | NOT NULL DEFAULT now() | |
| `operation_id` | uuid | NULL | Groups all field changes from a single save operation |

**Implementation:** PostgreSQL trigger on every audited table. Trigger fires AFTER UPDATE/INSERT/DELETE, iterates over NEW vs OLD columns, inserts one row per changed field.

**Audited tables:** All master data tables, all transaction header tables, all config tables.

**Excluded from auditing:** `audit_logs`, `field_change_history` itself, `gl_balances`, `notification_delivery_logs`, `user_activity_logs`.

---

## 4. User Activity Log

### `user_activity_logs`
Records every user session event and sensitive action.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `user_id` | uuid | FK auth.users, NOT NULL | |
| `company_id` | uuid | FK companies, NULL | NULL for login events before company selection |
| `activity_type` | text | NOT NULL | See below |
| `description` | text | NOT NULL | |
| `ip_address` | inet | NULL | |
| `user_agent` | text | NULL | |
| `session_id` | text | NULL | |
| `occurred_at` | timestamptz | NOT NULL DEFAULT now() | |
| `metadata` | jsonb | NULL | e.g., report name, filter params, export row count |

### Activity Types

| Type | Description |
|---|---|
| `LOGIN_SUCCESS` | Successful login |
| `LOGIN_FAILED` | Failed login attempt |
| `LOGOUT` | User logged out |
| `SESSION_EXPIRED` | Session timed out |
| `COMPANY_SWITCHED` | User switched active company |
| `BRANCH_SWITCHED` | User switched active branch |
| `REPORT_VIEWED` | Financial report accessed |
| `REPORT_EXPORTED` | Report exported (PDF, Excel, CSV) |
| `DOCUMENT_PRINTED` | Document printed |
| `DATA_EXPORTED` | Bulk data export |
| `COMPLIANCE_REPORT_EXPORTED` | BIR compliance form exported |
| `DAT_FILE_DOWNLOADED` | CAS DAT file downloaded |
| `SETTINGS_CHANGED` | User changed own settings |
| `PASSWORD_CHANGED` | Password changed |
| `MFA_ENABLED` | MFA configured |
| `MFA_DISABLED` | MFA removed |

---

## 5. Document Void Register

### `document_void_register`
Permanent record of every voided document. Cannot be deleted or updated.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `document_type` | text | NOT NULL | |
| `document_id` | uuid | NOT NULL | FK to source document |
| `document_no` | text | NOT NULL | Denormalized |
| `original_amount` | numeric(18,4) | NOT NULL | Total amount of voided document |
| `original_date` | date | NOT NULL | Original document date |
| `void_date` | date | NOT NULL | Date of void |
| `void_reason` | text | NOT NULL | Required |
| `voided_by` | uuid | FK auth.users, NOT NULL | |
| `voided_at` | timestamptz | NOT NULL DEFAULT now() | |
| `reversal_journal_entry_id` | uuid | FK journal_entries, NULL | JE created to reverse |
| `approved_by` | uuid | FK auth.users, NULL | If void requires approval |
| `approved_at` | timestamptz | NULL | |

---

## 6. Document Number Series Tables

### `number_series`
Tracks ATP-compliant document series. Canonical definition is here in doc 07.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `branch_id` | uuid | FK branches, NULL | NULL = company-wide |
| `document_type` | text | NOT NULL | 'sales_invoice' \| 'official_receipt' \| 'purchase_order' \| 'delivery_order' \| 'journal_entry' \| 'cash_sale' \| 'cash_purchase' \| 'credit_memo' \| 'debit_memo' \| 'payment_voucher' \| 'petty_cash_voucher' |
| `series_prefix` | text | NOT NULL | e.g., 'SI-2025-' |
| `padding_length` | integer | NOT NULL DEFAULT 6 | Zero-padding for sequential number |
| `current_number` | bigint | NOT NULL DEFAULT 0 | Last used number |
| `max_number` | bigint | NOT NULL | ATP series limit |
| `is_active` | boolean | NOT NULL DEFAULT true | |
| `atp_reference_no` | text | NULL | BIR ATP reference |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |
| `created_by` | uuid | FK auth.users | |

### `number_series_atp`
One record per ATP grant per series.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `number_series_id` | uuid | FK number_series, NOT NULL | |
| `atp_reference_no` | text | NOT NULL | BIR-issued ATP reference |
| `series_start` | bigint | NOT NULL | |
| `series_end` | bigint | NOT NULL | |
| `valid_from` | date | NOT NULL | |
| `valid_until` | date | NULL | |
| `printer_name` | text | NULL | BIR-accredited printer |
| `print_date` | date | NULL | Date of printing |
| `is_active` | boolean | NOT NULL DEFAULT true | |

### `atp_usage_logs`
Every document number allocated from a series. Immutable.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `number_series_id` | uuid | FK number_series, NOT NULL | |
| `atp_id` | uuid | FK number_series_atp, NOT NULL | |
| `allocated_number` | bigint | NOT NULL | Raw number allocated |
| `formatted_number` | text | NOT NULL | e.g., 'SI-2025-000123' |
| `document_type` | text | NOT NULL | |
| `document_id` | uuid | NOT NULL | FK to the document |
| `allocated_by` | uuid | FK auth.users, NOT NULL | |
| `allocated_at` | timestamptz | NOT NULL DEFAULT now() | |
| `is_voided` | boolean | NOT NULL DEFAULT false | True if document was voided — number is consumed, NOT reused |

**Immutable. No update, no delete.**

---

## 7. CAS-Specific Tables

### `cas_registrations`
> Column spec: See Doc03 Section 1 (`cas_registrations`). Tracks BIR CAS accreditation per company — cas_number, accreditation_date, valid_until, covered_modules, bir_rdo_code.

> Note: `field_change_history` records reference `audit_logs` via the `operation_id` column — they are linked by the same UUID grouping all field changes from a single save operation, not by a direct FK.

---

### `dat_generation_logs`
> **v3.2 Canonical Name Fix:** Previously called `dat_file_generation_logs` in this doc. Canonical name is `dat_generation_logs` per Doc 02 registry. All references updated.

CAS requirement: every DAT file export must be logged permanently.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `dat_type` | text | CHECK IN ('gl','sl','sls','pur','inv'), NOT NULL | BIR CAS DAT file type — lowercase internal value **[v3.6 fix: was uppercase; CHECK constraint uses lowercase per architecture convention]** |
| `period_from` | date | NOT NULL | |
| `period_to` | date | NOT NULL | |
| `fiscal_year_id` | uuid | FK fiscal_years, NULL | |
| `generated_by` | uuid | FK auth.users, NOT NULL | |
| `generated_at` | timestamptz | NOT NULL DEFAULT now() | |
| `record_count` | integer | NOT NULL | Number of records in file |
| `file_size_bytes` | bigint | NULL | |
| `file_hash_sha256` | text | NULL | SHA-256 hash of generated file for integrity verification |
| `storage_path` | text | NULL | Supabase Storage path |
| `download_count` | integer | NOT NULL DEFAULT 0 | How many times downloaded |
| `last_downloaded_at` | timestamptz | NULL | |
| `last_downloaded_by` | uuid | FK auth.users, NULL | |

**No delete policy. Immutable.**

---

### `system_alerts`
Stores automated system alerts generated by scheduled jobs.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `alert_type` | text | NOT NULL | CHECK IN ('atp_series_near_limit','atp_gap_detected','period_close_overdue','import_failed','export_failed','recurring_je_failed') |
| `severity` | text | CHECK IN ('info','warning','error','critical'), NOT NULL | |
| `title` | text | NOT NULL | Short alert title |
| `message` | text | NOT NULL | Full alert details |
| `entity_type` | text | NULL | Affected entity table (e.g., 'number_series') |
| `entity_id` | uuid | NULL | Affected entity ID |
| `metadata` | jsonb | NULL | e.g., gap start/end numbers, series_id |
| `is_resolved` | boolean | NOT NULL DEFAULT false | |
| `resolved_at` | timestamptz | NULL | |
| `resolved_by` | uuid | FK auth.users, NULL | |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |
| `acknowledged_at` | timestamptz | NULL | When user dismissed the alert |
| `acknowledged_by` | uuid | FK auth.users, NULL | |

---

## 8. Approval Audit Tables

### `approval_requests`
Supabase Realtime enabled.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `document_type` | text | NOT NULL | |
| `document_id` | uuid | NOT NULL | |
| `approval_matrix_id` | uuid | FK approval_matrix, NOT NULL | |
| `requested_by` | uuid | FK auth.users, NOT NULL | |
| `requested_at` | timestamptz | NOT NULL DEFAULT now() | |
| `status` | text | CHECK IN ('pending','approved','rejected','cancelled') | |
| `completed_at` | timestamptz | NULL | |
| `current_step` | integer | NOT NULL DEFAULT 1 | |

### `approval_actions`
Immutable. Supabase Realtime enabled.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `approval_request_id` | uuid | FK approval_requests, NOT NULL | |
| `step_number` | integer | NOT NULL | |
| `action` | text | CHECK IN ('approved','rejected','returned','escalated') | |
| `acted_by` | uuid | FK auth.users, NOT NULL | |
| `acted_at` | timestamptz | NOT NULL DEFAULT now() | |
| `comments` | text | NULL | |
| `delegate_of` | uuid | FK auth.users, NULL | If acting on behalf of |

**Immutable. No update, no delete.**

---

## 9. Audit Implementation Notes

### Trigger Design
Every audited table gets two triggers:
1. **`{table}_audit_trigger`** — fires AFTER INSERT/UPDATE/DELETE, writes to `field_change_history`
2. **`{table}_immutability_trigger`** — fires BEFORE UPDATE/DELETE, raises exception if `status IN ('posted','voided','reversed')` **[v3.6 fix: was 'POSTED' uppercase; see trigger function below for canonical lowercase values]**

### Immutability Enforcement
```sql
CREATE OR REPLACE FUNCTION enforce_posted_immutability()
RETURNS trigger AS $$
BEGIN
  IF OLD.status IN ('posted', 'voided', 'reversed') THEN
    RAISE EXCEPTION 'Cannot modify a posted/voided/reversed document: %', OLD.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### Sequence Gap Detection
A scheduled Supabase pg_cron job runs nightly:
- Checks `atp_usage_logs` for gaps in `allocated_number` per `number_series_id`
- Inserts a row into `system_alerts` (alert_type='atp_gap_detected', severity='critical') if gap found **[v3.6 fix: lowercase per system_alerts CHECK constraints]**
- Required for CAS audit compliance
- Also checks when `number_series.current_number` exceeds 80% of `max_number` → inserts `system_alerts` (alert_type='atp_series_near_limit', severity='warning') **[v3.6 fix: lowercase]**
