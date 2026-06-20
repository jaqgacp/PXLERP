# PXL ERP — Database Architecture Overview
**Version:** 2.0 — Revised for Implementation Readiness
**Prepared by:** PXL Database Architecture Team
**Status:** For CPA and Developer Review

---

## Changes Applied (v1 → v2)

- Added Cash Sales / Cash Purchases architectural decision (OD-08, now resolved)
- Added Notification System design section
- Added Document Template and Generated Output design section
- Added Period Close Process design section
- Added Budget tables design section
- Added Party Duplicate / TIN Conflict handling section
- Standardized column name conventions (see Section 11)
- Resolved OD-01 through OD-07 with recommended defaults
- Expanded Supabase-Specific Decisions section

---

## 1. Design Philosophy

PXL ERP is built on **Philippine compliance-first** principles. Every design decision is evaluated against three questions:

1. Will this support accurate BIR compliance reporting?
2. Is this auditable and immutable after posting?
3. Does this scale for multi-company, multi-branch MSME operations?

---

## 2. Multi-Tenant Structure

### Model: Shared Schema, Row-Level Isolation

All companies share the same PostgreSQL schema. Tenant isolation is enforced at the **row level** via `company_id` on every operational table, backed by **Supabase Row Level Security (RLS)**.

```
supabase_auth.users
       │
       ▼
  user_company_access  ──►  companies
       │                        │
       ▼                        ▼
  user_branch_access  ──►  branches  ──►  departments  ──►  cost_centers
```

### Why Shared Schema?
- MSME target market: companies are small, schema-per-tenant is operationally expensive
- Simplifies migrations — one schema to update
- Supabase RLS handles isolation cleanly
- Cross-company reporting possible at admin level without JOINs across schemas

### Company Hierarchy

```
companies
  └── branches
        └── departments
              └── cost_centers
```

Every transaction carries up to four dimension keys:
`company_id`, `branch_id`, `department_id`, `cost_center_id`

These enable branch P&L, department reports, and cost center allocation without denormalization.

---

## 3. Auditability Design

### Principle: Nothing Disappears

PXL ERP never hard-deletes operational records. All deletions are soft-deletes (`deleted_at`, `deleted_by`). Posted transactions become **immutable** — corrections are done only via reversal documents.

### Three Layers of Audit

| Layer | Mechanism | Scope |
|---|---|---|
| **Record-level** | `created_by`, `updated_by`, `deleted_by` on every table | Who touched this record |
| **Field-level** | `field_change_history` table | Before/after every field change |
| **Event-level** | `audit_logs` + `user_activity_logs` | Every login, export, print, void |

### CAS Audit Readiness

BIR CAS (Computerized Accounting System) accreditation requires:
- Complete transaction audit trail
- No ability to modify posted entries
- Sequential document numbering with no gaps
- DAT file generation capability
- ATP (Authority to Print) tracking

Every design decision supports these requirements.

---

## 4. Immutability Rules

### Document Lifecycle States

```
DRAFT → SUBMITTED → APPROVED → POSTED → (VOIDED | REVERSED)
```

| State | Editable? | Deletable? | Notes |
|---|---|---|---|
| DRAFT | ✅ Yes | ✅ Yes (soft) | Before submission |
| SUBMITTED | ❌ No | ❌ No | Awaiting approval |
| APPROVED | ❌ No | ❌ No | Approved, not yet posted |
| POSTED | ❌ No | ❌ No | Immutable. Journal entries created |
| VOIDED | ❌ No | ❌ No | Void creates reversal JE |
| REVERSED | ❌ No | ❌ No | Reversed by another document |
| CANCELLED | ✅ Soft delete | ✅ Soft delete | DRAFT only; no JE created |

> **Note:** CANCELLED applies only to documents that were never POSTED (e.g., a Purchase Order cancelled before goods receipt). It is a soft delete, not a reversal.

### How Corrections Work

```
Original Invoice (POSTED, immutable)
        │
        └──► Credit Memo (POSTED) — reverses the invoice
                  │
                  └──► New Corrected Invoice (POSTED)
```

Source links are maintained via `reversed_by_doc_id` and `source_document_id`.

---

## 5. Posting Engine Design

### Core Concept: Deferred Double-Entry

Transactions are captured in their **source form** (invoice, receipt, voucher) first. Posting converts them to **journal entries** following **posting rules** defined per transaction type and account.

```
Source Document (e.g., Sales Invoice)
        │
        ▼
  Posting Rules Engine (Edge Function)
        │
        ▼
  journal_entries (header)
        │
        ▼
  journal_lines (DR/CR lines)
        │
        ├──► gl_balances (running balances per account/period)
        ├──► subsidiary_ledger_entries (AR, AP, inventory movement)
        └──► notifications (approvers, document owner)
```

### Posting Rules

Each transaction type maps to a `posting_rule_set` which defines:
- Which accounts to debit/credit
- How to compute amounts (subtotal, VAT, withholding)
- Which subsidiary ledger to update
- Whether to create compliance entries (VAT, EWT)

### Fiscal Period Enforcement

All posted entries carry `fiscal_year_id` and `fiscal_period_id`. Period locks (`fiscal_locks`) prevent posting to closed periods. This is a hard constraint enforced at the database level via trigger guards.

---

## 6. Cash Sales and Cash Purchases — Design Decision (OD-08 RESOLVED)

### Decision: Separate Transaction Headers — Not AR/AP Shortcuts

**Cash Sales** (`cash_sales` + `cash_sale_lines`) and **Cash Purchases** (`cash_purchases` + `cash_purchase_lines`) are **independent transaction types** with their own document headers and posting rules. They do **not** create an underlying Sales Invoice or Vendor Bill.

### Rationale

| Concern | Decision |
|---|---|
| BIR compliance | Cash Sales generate output VAT entries and official receipts. Cash Purchases generate input VAT entries and EWT entries. Both are fully compliant. |
| AR/AP ledger | Cash Sales do NOT create an AR entry. Cash Purchases do NOT create an AP entry. Immediate payment is assumed. |
| Inventory | Cash Sales reduce inventory (same as Sales Invoice). Cash Purchases increase inventory (same as Vendor Bill for goods). |
| Official Receipts | Cash Sales use the same `number_series` as Receipts (official receipt series). |
| EWT on Cash Purchases | Cash Purchases subject to EWT create `ewt_entries` at time of transaction, not deferred to payment. |

### Posting Rules

**Cash Sale posting:**
```
DR: Cash / Bank (amount received)
CR: Revenue Account (subtotal)
CR: Output VAT Payable (vat_amount)
```

**Cash Purchase posting (goods):**
```
DR: Inventory / Expense Account (net_amount)
DR: Input VAT (vat_amount)
CR: Cash / Bank (gross_amount - ewt_amount)
DR: EWT Payable (ewt_amount)   [if EWT-subject]
```

---

## 7. Document Numbering Design

### ATP Compliance

BIR requires pre-numbered official receipts and invoices. PXL implements:

```
number_series  (defines series per doc type per company/branch)
       │
       ├── series_code
       ├── prefix
       ├── current_number
       ├── max_number  (ATP limit)
       └── (FK) number_series_atp
```

ATP usage is logged in `atp_usage_logs` for CAS audit.

Numbers are allocated with `SELECT FOR UPDATE` to prevent race conditions in concurrent environments.

Document numbers are assigned at **DRAFT** time and held. If a document is cancelled/soft-deleted, the number is logged as voided in `atp_usage_logs` but NOT reassigned.

---

## 8. Tax Lifecycle Design

### VAT Flow

```
Sales Invoice / Cash Sales
        │
        ├── vat_entries (per line, output VAT)
        │
        └── vat_period_summaries (aggregated by period)
                │
                └── BIR Form 2550M / 2550Q
                        │
                        └── SLSP / RELIEF export
```

### EWT / 2307 Flow

```
Vendor Bill / Cash Purchase / Payment Voucher / Petty Cash Voucher
        │
        ├── ewt_entries (per line, per ATC code)
        │
        ├── certificates_2307_issued (per supplier, per quarter)
        │
        └── ewt_remittances_1601eq (1601EQ filing)
                │
                ├── QAP (Quarterly Alphalist of Payees)
                └── SAWT (Summary of Alphalist of Withholding Tax)
```

### 2307 Received (from customers withholding from us)

```
Receipt / payment received
        │
        └── certificates_2307_received (per customer, per quarter)
                │
                └── Tax Credits Schedule (income tax)
```

---

## 9. Approval Workflow Design

### Matrix-Based Approval

```
approval_matrix (defines who approves what, at what amount threshold)
        │
        └── approval_matrix_steps (sequential/parallel/any_one)
                │
        approval_requests (per document)
                │
                ├── approval_actions (approved / rejected / returned / escalated)
                └── notifications (sent to approver on each step)
```

### Workflow Rules
- Documents with approval requirements cannot be posted until fully approved
- Rejections return document to DRAFT
- Escalation rules can be defined by amount threshold and approver absence
- Notifications are sent on: submission, approval, rejection, escalation, posting

---

## 10. Notification System Design

Notifications inform users of actions required or completed without requiring them to poll the UI.

```
notification_templates (defines message per event type)
        │
        ▼
notifications (one per recipient per event)
        │
        ▼
notification_delivery_logs (one per delivery channel per notification)
```

### Delivery Channels
- **In-app**: Supabase Realtime push to browser session
- **Email**: Supabase Edge Function → SMTP / Resend / SendGrid
- Future: SMS, mobile push (Phase 2)

### Triggered By
- Document submitted for approval → notify approvers
- Document approved/rejected → notify requestor
- Document posted → notify owner
- ATP series nearing limit → notify company admin
- Period close pending → notify controller
- Import completed/failed → notify initiator
- Export job completed → notify requestor

---

## 11. Document Template and Generated Output Design

PXL generates printable documents (invoices, receipts, vouchers, 2307 certificates). These are produced on-demand and cached in Supabase Storage.

```
document_templates (HTML/PDF template per document type per company)
        │
        ▼
generated_documents (one record per generated file)
        │
        └── generated_document_versions (version history)
```

### Key Rules
- Templates are company-configurable (logo, address, footer)
- Generated files are stored in Supabase Storage
- SHA-256 hash stored for integrity verification
- CAS-reportable outputs (DAT files) use `dat_generation_logs`, not `generated_documents`

---

## 12. Period Close Process Design

```
period_close_checklists (one per company per fiscal period)
        │
        └── period_close_tasks (one task per checklist item)
                │
                ├── assigned_to → profiles
                ├── completed_by → profiles
                └── status: PENDING | IN_PROGRESS | COMPLETED | WAIVED
```

### Standard Close Tasks (system-seeded per period)
1. Bank reconciliation certified
2. AR subsidiary ledger agrees to GL
3. AP subsidiary ledger agrees to GL
4. Inventory count reconciled
5. Prepaid expenses amortized
6. Accruals booked
7. Depreciation run completed
8. VAT summary reviewed
9. EWT entries reviewed
10. Trial balance reviewed and signed off

Period cannot be LOCKED until all mandatory tasks are COMPLETED or WAIVED.

---

## 13. Budget Tables Design (Phase 1 — Basic)

```
budgets (header: budget name, fiscal year, version)
        │
        └── budget_lines (one per account per period)
```

### Phase 1 Scope
- Annual budget per company per fiscal year
- Account-level detail (COA)
- Budget vs actual variance in reports
- No workflow/approval on budget for Phase 1
- No project budgets for Phase 1

---

## 14. Party Duplicate / TIN Conflict Handling

In Philippine compliance, TIN uniquely identifies a taxpayer. Duplicate TIN entries across customers/suppliers must be tracked.

```
party_merge_logs (records when two customer or supplier records are merged)
        │
        ├── source_party_type, source_party_id (the duplicate to be retired)
        └── target_party_type, target_party_id (the canonical record to keep)
```

### Design Rules
- System warns (does not block) when a TIN is entered that already exists on another customer or supplier record
- `duplicate_tin_flags` records are created for review
- A company can have the same TIN as both a customer and a supplier (common for related entities)
- After merge, the retired record is soft-deleted; all transactions re-link to the canonical record via `party_merge_logs`

---

## 15. Compliance Readiness Summary

| Requirement | Design Support |
|---|---|
| VAT 2550M / 2550Q | `vat_entries` → `vat_period_summaries` → form output |
| SLSP | `sales_invoice_lines` + VAT data + TIN snapshot |
| RELIEF | `vendor_bill_lines` + input VAT + TIN snapshot |
| 1601EQ | `ewt_entries` → `ewt_remittances_1601eq` → period aggregation |
| QAP | `ewt_entries` → alphalist by ATC + payee TIN |
| SAWT | `certificates_2307_received` → alphalist |
| 2307 Issued | `ewt_entries` → `certificates_2307_issued` per supplier |
| 2307 Received | `certificates_2307_received` per customer |
| BIR Books | Derived from `journal_entries` + `journal_lines` |
| CAS Audit | `audit_logs` + `field_change_history` + `dat_generation_logs` |
| Cash Sales Book | `cash_sales` + `vat_entries` |
| Cash Purchases Book | `cash_purchases` + `vat_entries` + `ewt_entries` |

---

## 16. Import / Bulk Upload Design

### Scope: All Setup and Master Data Modules

MSME companies migrating to PXL ERP may have:
- Existing chart of accounts
- Hundreds of customers and suppliers (with TIN data)
- Existing item master
- Payment terms, ATC codes, tax codes
- Opening balances per account/branch
- Historical AR/AP balances
- Existing inventory stock and cost layers

PXL supports bulk import via:
```
import_batches → import_rows → import_validation_errors
```

Every bulk-created record carries `import_batch_id` for traceability and rollback.

**Import types include all Setup and Master Data tables**, not only transactional data. See Document 08 for the full list.

---

## 17. Naming Conventions

| Convention | Rule |
|---|---|
| Table names | `snake_case`, plural nouns |
| Column names | `snake_case` |
| Primary keys | `id uuid DEFAULT gen_random_uuid()` |
| Foreign keys | `{referenced_table_singular}_id` |
| Timestamps | `timestamptz` |
| Money | `numeric(18,4)` — 4 decimal places for peso/centavo precision |
| Rates / percentages | `numeric(10,6)` |
| Status enums | `text` with CHECK constraint (OD-01 resolved: avoids migration pain vs. PG enums) |
| Flags | `boolean` NOT NULL with DEFAULT |
| Soft delete | `deleted_at timestamptz NULL` |
| TIN columns | `tin` on master tables; `{party}_tin` as snapshot on ledger/compliance tables |
| Document number | `document_no` on all transaction headers |
| Document date | `document_date` on all transaction headers |
| Posting date | `posting_date` on all transaction headers (set when posted) |

---

## 18. Supabase-Specific Decisions

| Feature | Usage |
|---|---|
| **RLS** | Enabled on all tables with `company_id`. Policy: `auth.uid()` must have access via `user_company_access`. Helper functions in `auth` schema. |
| **Realtime** | Enabled only on: `approval_requests`, `approval_actions`, `export_jobs`, `import_batches`, `notifications`. NOT on ledger, audit, or compliance tables. |
| **Storage** | Supabase Storage for attachments and generated documents. Tables store metadata and `storage_path` only. |
| **Edge Functions** | Posting engine, number allocation, compliance report generation, notification dispatch, import/export jobs |
| **Database Functions** | Period validation, `auth.user_company_ids()`, `auth.user_branch_ids()`, `auth.has_permission()`, immutability triggers, audit triggers |
| **Views** | AR aging, AP aging, inventory valuation, trial balance — computed views. `gl_balances` is a table, not a view (OD-02 resolved). |
| **Cron Jobs** | Supabase pg_cron: nightly ATP gap detection, recurring journal generation, notification cleanup |

---

## Open Decisions — Resolved

| OD # | Question | Resolution |
|---|---|---|
| OD-01 | ENUM or text + CHECK? | **text + CHECK** — migration flexibility wins |
| OD-02 | GL balance: materialized view or table? | **`gl_balances` table** with upsert on every posting |
| OD-03 | Multi-currency Phase 1? | **PHP only** — FX in Phase 2 |
| OD-04 | Approval: parallel vs sequential? | **Both** — `approval_type` column on `approval_matrix` |
| OD-05 | Inventory: FIFO only? | **FIFO only** — Weighted Average in Phase 2 |
| OD-06 | Opening balances per account or account/branch? | **Per account + branch** — full branch P&L required |
| OD-07 | Recurring journal frequency? | **Monthly + Quarterly + Annually** for Phase 1 |
| OD-08 | Cash Sales / Cash Purchases: separate headers or shortcuts? | **Separate transaction headers** — see Section 6 |

---

## Implementation Notes

- All Edge Functions must run in a single database transaction for posting, import, and number allocation
- `auth.user_company_ids()` must be indexed — call is on the hot path of every RLS policy
- `gl_balances` upsert is `INSERT ... ON CONFLICT DO UPDATE` — must be atomic within posting transaction
- Period close cannot lock until `period_close_tasks` are all COMPLETED or WAIVED
- Notification dispatch is async (fire-and-forget) — failure does not roll back the triggering transaction
- Generated documents are soft-deleted after 90 days from Supabase Storage; the metadata row in `generated_documents` is retained permanently
