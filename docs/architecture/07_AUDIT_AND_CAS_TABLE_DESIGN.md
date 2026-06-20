# PXL ERP — Audit and CAS Table Design
**Version:** 1.0 — Blueprint Locked  
**Status:** For CPA and Developer Review

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
Immutable log of every system event. No soft delete. No update allowed.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `event_type` | text | NOT NULL | See event type enum below |
| `entity_type` | text | NOT NULL | Table name of affected record |
| `entity_id` | uuid | NOT NULL | ID of affected record |
| `entity_number` | text | NULL | Human-readable doc number (denormalized for readability) |
| `description` | text | NOT NULL | Human-readable description |
| `old_status` | text | NULL | Previous status (for status changes) |
| `new_status` | text | NULL | New status |
| `performed_by` | uuid | FK auth.users, NOT NULL | |
| `performed_at` | timestamptz | NOT NULL DEFAULT now() | |
| `ip_address` | inet | NULL | Client IP (captured by Edge Function) |
| `user_agent` | text | NULL | Browser/client user agent |
| `session_id` | text | NULL | Auth session ID |
| `branch_id` | uuid | FK branches, NULL | |
| `metadata` | jsonb | NULL | Additional context (e.g., filter params for exports) |

**No RLS update or delete policies on this table. Insert-only.**

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
| `RECORD_CREATED` | Master data record created |
| `RECORD_UPDATED` | Master data record updated |
| `RECORD_DELETED` | Soft delete applied |
| `RECORD_RESTORED` | Soft delete reversed |
| `BULK_IMPORT_STARTED` | Import batch initiated |
| `BULK_IMPORT_COMPLETED` | Import batch completed |
| `PERIOD_CLOSED` | Fiscal period closed |
| `PERIOD_LOCKED` | Fiscal period locked |
| `PERIOD_UNLOCKED` | Fiscal period unlocked (exceptional) |
| `DAT_FILE_GENERATED` | CAS DAT file exported |
| `COMPLIANCE_REPORT_GENERATED` | BIR report generated |
| `USER_ASSIGNED_ROLE` | Role assigned to user |
| `USER_ROLE_REMOVED` | Role removed from user |
| `APPROVAL_MATRIX_CHANGED` | Approval matrix modified |
| `POSTING_RULE_CHANGED` | Posting rule modified |
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
| `change_type` | text | CHECK IN ('INSERT','UPDATE','DELETE'), NOT NULL | |
| `changed_by` | uuid | FK auth.users, NOT NULL | |
| `changed_at` | timestamptz | NOT NULL DEFAULT now() | |
| `operation_id` | uuid | NULL | Groups all field changes from a single save operation |

**Implementation:** PostgreSQL trigger on every audited table. Trigger fires AFTER UPDATE/INSERT/DELETE, iterates over NEW vs OLD columns, inserts one row per changed field.

**Audited tables:** All master data tables, all transaction header tables, all config tables. NOT audited: `audit_logs`, `field_change_history` itself, `gl_balances` (ledger only).

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
| `SETTINGS_CHANGED` | User changed own settings |
| `PASSWORD_CHANGED` | Password changed |
| `MFA_ENABLED` | MFA configured |
| `MFA_DISABLED` | MFA removed |

---

## 5. Document Void Register

### `document_void_register`
Permanent record of every voided document. Cannot be deleted.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `document_type` | text | NOT NULL | |
| `document_id` | uuid | NOT NULL | FK to source document |
| `document_number` | text | NOT NULL | Denormalized |
| `original_amount` | numeric(18,4) | NOT NULL | Total amount of voided document |
| `original_date` | date | NOT NULL | Original document date |
| `void_date` | date | NOT NULL | Date of void |
| `void_reason` | text | NOT NULL | Required |
| `voided_by` | uuid | FK auth.users, NOT NULL | |
| `voided_at` | timestamptz | NOT NULL DEFAULT now() | |
| `reversal_journal_entry_id` | uuid | FK journal_entries, NULL | JE created to reverse the void |
| `approved_by` | uuid | FK auth.users, NULL | If void requires approval |
| `approved_at` | timestamptz | NULL | |

---

## 6. CAS-Specific Tables

### `cas_registrations`
Tracks CAS accreditation per company.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `cas_number` | text | NOT NULL | BIR-issued CAS accreditation number |
| `accreditation_date` | date | NOT NULL | |
| `valid_until` | date | NULL | |
| `covered_modules` | text[] | NOT NULL | e.g., ['GL','AR','AP','INV'] |
| `bir_rdo_code` | text | NOT NULL | Revenue District Office code |
| `bir_form_submitted` | text | NULL | BIR form used for CAS (e.g., '1900') |
| `is_active` | boolean | NOT NULL DEFAULT true | |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |
| `created_by` | uuid | FK auth.users | |

---

### `dat_file_generation_logs`
CAS requirement: every DAT file export must be logged permanently.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `dat_type` | text | NOT NULL | 'GL' \| 'SL' \| 'SLS' \| 'PUR' \| 'INV' |
| `period_from` | date | NOT NULL | |
| `period_to` | date | NOT NULL | |
| `fiscal_year_id` | uuid | FK fiscal_years, NULL | |
| `generated_by` | uuid | FK auth.users, NOT NULL | |
| `generated_at` | timestamptz | NOT NULL DEFAULT now() | |
| `record_count` | integer | NOT NULL | Number of records in file |
| `file_size_bytes` | bigint | NULL | |
| `file_hash_sha256` | text | NULL | Hash of generated file for integrity verification |
| `storage_path` | text | NULL | Supabase Storage path |
| `download_count` | integer | NOT NULL DEFAULT 0 | How many times downloaded |
| `last_downloaded_at` | timestamptz | NULL | |
| `last_downloaded_by` | uuid | FK auth.users, NULL | |

**No delete policy. Immutable.**

---

### `number_series`
Tracks ATP-compliant document series.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `branch_id` | uuid | FK branches, NULL | NULL = company-wide |
| `document_type` | text | NOT NULL | 'sales_invoice' \| 'official_receipt' \| 'purchase_order' \| 'delivery_order' \| 'journal_entry' \| etc. |
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
| `company_id` | uuid | FK companies | |
| `number_series_id` | uuid | FK number_series | |
| `atp_reference_no` | text | NOT NULL | |
| `series_start` | bigint | NOT NULL | |
| `series_end` | bigint | NOT NULL | |
| `valid_from` | date | NOT NULL | |
| `valid_until` | date | NULL | |
| `printer_name` | text | NULL | BIR-accredited printer |
| `print_date` | date | NULL | Date of printing |
| `is_active` | boolean | NOT NULL DEFAULT true | |

### `atp_usage_logs`
Every document number allocated from a series.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies | |
| `number_series_id` | uuid | FK number_series | |
| `atp_id` | uuid | FK number_series_atp | |
| `allocated_number` | bigint | NOT NULL | Raw number |
| `formatted_number` | text | NOT NULL | e.g., 'SI-2025-000123' |
| `document_type` | text | NOT NULL | |
| `document_id` | uuid | NOT NULL | |
| `allocated_by` | uuid | FK auth.users | |
| `allocated_at` | timestamptz | NOT NULL DEFAULT now() | |
| `is_voided` | boolean | NOT NULL DEFAULT false | True if document was voided (number still consumed) |

**Immutable. No update, no delete.**

---

## 7. Approval Audit Tables

### `approval_requests`

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies | |
| `document_type` | text | NOT NULL | |
| `document_id` | uuid | NOT NULL | |
| `approval_matrix_id` | uuid | FK approval_matrix | |
| `requested_by` | uuid | FK auth.users | |
| `requested_at` | timestamptz | NOT NULL DEFAULT now() | |
| `status` | text | CHECK IN ('PENDING','APPROVED','REJECTED','CANCELLED') | |
| `completed_at` | timestamptz | NULL | |
| `current_step` | integer | NOT NULL DEFAULT 1 | |

### `approval_actions`

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies | |
| `approval_request_id` | uuid | FK approval_requests | |
| `step_number` | integer | NOT NULL | |
| `action` | text | CHECK IN ('APPROVED','REJECTED','RETURNED','ESCALATED') | |
| `acted_by` | uuid | FK auth.users | |
| `acted_at` | timestamptz | NOT NULL DEFAULT now() | |
| `comments` | text | NULL | |
| `delegate_of` | uuid | FK auth.users, NULL | If acting on behalf of |

**Immutable. No update, no delete.**

---

## 8. Audit Implementation Notes

### Trigger Design
Every audited table gets two triggers:
1. **`{table}_audit_trigger`** — fires AFTER INSERT/UPDATE/DELETE, writes to `field_change_history`
2. **`{table}_immutability_trigger`** — fires BEFORE UPDATE/DELETE, raises exception if `status = 'POSTED'`

### Immutability Enforcement
```sql
CREATE OR REPLACE FUNCTION enforce_posted_immutability()
RETURNS trigger AS $$
BEGIN
  IF OLD.status = 'POSTED' THEN
    RAISE EXCEPTION 'Cannot modify a posted document: %', OLD.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### Sequence Gap Detection
A scheduled Supabase Edge Function runs nightly:
- Checks `atp_usage_logs` for gaps in `allocated_number` per `number_series_id`
- Writes alert to `system_alerts` table if gap found
- Required for CAS audit compliance
