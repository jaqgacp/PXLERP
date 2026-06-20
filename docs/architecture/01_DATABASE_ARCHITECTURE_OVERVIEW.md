# PXL ERP — Database Architecture Overview
**Version:** 1.0 — Blueprint Locked  
**Prepared by:** PXL Database Architecture Team  
**Status:** For CPA and Developer Review

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

### How Corrections Work

```
Original Invoice (POSTED, immutable)
        │
        └──► Credit Memo (POSTED) — reverses the invoice
                  │
                  └──► New Corrected Invoice (POSTED)
```

Source links are maintained via `reversed_by_document_id` and `source_document_id`.

---

## 5. Posting Engine Design

### Core Concept: Deferred Double-Entry

Transactions are captured in their **source form** (invoice, receipt, voucher) first. Posting converts them to **journal entries** following **posting rules** defined per transaction type and account.

```
Source Document (e.g., Sales Invoice)
        │
        ▼
  Posting Rules Engine
        │
        ▼
  journal_entries (header)
        │
        ▼
  journal_lines (DR/CR lines)
        │
        ├──► gl_balances (running balances per account/period)
        └──► subsidiary_ledgers (AR, AP, inventory movement)
```

### Posting Rules

Each transaction type maps to a `posting_rule` which defines:
- Which accounts to debit/credit
- How to compute amounts (subtotal, VAT, withholding)
- Which subsidiary ledger to update
- Whether to create compliance entries (VAT, EWT)

### Fiscal Period Enforcement

All posted entries carry `fiscal_year_id` and `fiscal_period_id`. Period locks (`fiscal_locks`) prevent posting to closed periods. This is a hard constraint enforced at the database level via CHECK constraints and trigger guards.

---

## 6. Document Numbering Design

### ATP Compliance

BIR requires pre-numbered official receipts and invoices. PXL implements:

```
number_series  (defines series per doc type per company/branch)
       │
       ├── series_prefix
       ├── current_number
       ├── max_number  (ATP limit)
       └── atp_reference_no
```

ATP usage is logged in `atp_usage_logs` for CAS audit.

Numbers are allocated with `SELECT FOR UPDATE` to prevent race conditions in concurrent environments.

---

## 7. Tax Lifecycle Design

### VAT Flow

```
Sales Invoice / Cash Sales
        │
        ├── output_vat_entries (per line)
        │
        └── vat_summary_period (aggregated by period)
                │
                └── BIR Form 2550M / 2550Q
                        │
                        └── SLSP / RELIEF export
```

### EWT / 2307 Flow

```
Vendor Bill / Payment Voucher
        │
        ├── ewt_entries (per line, per ATC code)
        │
        ├── 2307_issued (per supplier, per quarter)
        │
        └── ewt_remittance (1601EQ filing)
                │
                ├── QAP (Quarterly Alphalist of Payees)
                └── SAWT (Summary of Alphalist of Withholding Tax)
```

### 2307 Received (from customers withholding from us)

```
Receipt / Payment received
        │
        └── 2307_received (per customer, per quarter)
                │
                └── Tax Credits Schedule (income tax)
```

---

## 8. Approval Workflow Design

### Matrix-Based Approval

```
approval_matrix (defines who approves what, at what amount threshold)
        │
        └── approval_requests (per document)
                │
                ├── approval_steps (sequential or parallel)
                └── approval_actions (approved / rejected / returned)
```

### Workflow Rules
- Documents with approval requirements cannot be posted until fully approved
- Rejections return document to DRAFT
- Escalation rules can be defined by amount threshold and approver absence

---

## 9. Compliance Readiness Summary

| Requirement | Design Support |
|---|---|
| VAT 2550M / 2550Q | `vat_entries` → period aggregation → form output |
| SLSP | `sales_invoice_lines` + VAT data + TIN |
| RELIEF | `vendor_bill_lines` + input VAT + TIN |
| 1601EQ | `ewt_entries` → period aggregation |
| QAP | `ewt_entries` → alphalist by ATC + payee TIN |
| SAWT | `2307_received` → alphalist |
| 2307 Issued | `ewt_entries` → per supplier certificate |
| 2307 Received | `2307_received` → per customer certificate |
| BIR Books | Derived from `journal_entries` + `journal_lines` |
| CAS Audit | `audit_logs` + `field_change_history` + `dat_file_generation_logs` |

---

## 10. Import / Bulk Upload Design

### Why This Matters at Setup

MSME companies migrating to PXL ERP may have:
- Hundreds of customers and suppliers
- Existing chart of accounts
- Opening balances
- Historical inventory

PXL supports bulk import via:
```
import_batches → import_rows → import_validation_errors
```

Every bulk-created record carries `import_batch_id` for traceability.

---

## 11. Naming Conventions

| Convention | Rule |
|---|---|
| Table names | `snake_case`, plural nouns |
| Column names | `snake_case` |
| Primary keys | `id uuid DEFAULT gen_random_uuid()` |
| Foreign keys | `{referenced_table_singular}_id` |
| Timestamps | `timestamptz` |
| Money | `numeric(18,4)` — 4 decimal places for peso/centavo precision |
| Rates / percentages | `numeric(10,6)` |
| Status enums | `text` with CHECK constraint (avoids migration pain vs. PG enums) |
| Flags | `boolean` with NOT NULL DEFAULT |
| Soft delete | `deleted_at timestamptz NULL` |

---

## 12. Supabase-Specific Decisions

| Feature | Usage |
|---|---|
| **RLS** | Enabled on all tables with `company_id`. Policy: `auth.uid()` must have access to that `company_id` via `user_company_access` |
| **Realtime** | Enable on approval tables and document status tables only |
| **Storage** | Supabase Storage for attachments; `attachments` table stores metadata only |
| **Edge Functions** | Posting engine, number allocation, compliance report generation |
| **Database Functions** | Period validation, balance computation, posting triggers |
| **Views** | GL balances, AR aging, AP aging — materialized where performance requires |

---

## Open Decisions

| # | Question | Impact | Owner |
|---|---|---|---|
| OD-01 | Use PostgreSQL ENUM or text + CHECK for status fields? | Migration flexibility | DB Architect |
| OD-02 | Materialized views for GL balance vs. running total column? | Performance at scale | DB Architect |
| OD-03 | Multi-currency: functional currency always PHP? | FX revaluation complexity | CPA Lead |
| OD-04 | Approval matrix: parallel vs. sequential per document type? | Workflow design | Business Lead |
| OD-05 | Inventory valuation method: FIFO only for Phase 1? | Cost computation complexity | CPA Lead |
| OD-06 | Opening balances: per account or per account/branch? | Reporting granularity | CPA Lead |
| OD-07 | Recurring journal frequency: daily/weekly/monthly only? | Template complexity | CPA Lead |
