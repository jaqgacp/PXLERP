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

## v3 Architecture Review Changes Applied

- **COA FS Mapping Architecture Decision**: `chart_of_accounts` expanded with structured FS mapping columns (`fs_section`, `fs_group`, `fs_sort_order`, `cash_flow_category`). Financial statements generated programmatically from these columns — not from hardcoded account ranges. See doc 03 Section 3 for full column specs.
- **Income Tax Architecture**: Added income tax computation support tables (`income_tax_computation_lines`, `nolco_tracking`). ITR form selection driven by `company_compliance_profiles.income_tax_regime`. COA accounts tagged with `is_mcit_gross_income` and `is_osd_gross_revenue` flags.
- **vat_direction / vat_classification separation**: All transaction line tables now carry two separate columns. `vat_direction` = 'output' or 'input' only. `vat_classification` = 'vatable', 'zero_rated', 'exempt', 'government', 'capital_goods', 'services'. Posting engine routes to different GL accounts based on `vat_classification`.
- **Posting Rule Sets versioning**: `posting_rule_sets.effective_from/effective_to` added per Principle 11. Historical documents use the rule set effective on their `document_date`.
- **system_account_config expanded**: Added PERCENTAGE_TAX_PAYABLE, FWT_PAYABLE, INCOME_TAX_PAYABLE keys.
- **customer_tax_profiles versioned**: Now supports multiple rows per customer with effective_from/effective_to, same pattern as `company_compliance_profiles`.
- **companies.tax_type / business_type marked deprecated**: Superseded by `company_compliance_profiles`. Retained for backward-compat only.

## v3 Remaining Open Decisions

| OD# | Decision | Recommended |
|---|---|---|
| OD-V3-ARCH-01 | Phase 1: Generate FS from COA `fs_section` tags or maintain a separate `fs_report_sections` master table? | COA tags only for Phase 1. Separate master table in Phase 2 for custom FS layouts. |
| OD-V3-ARCH-02 | Capital goods input VAT amortization (>PHP 1M rule): handled in Phase 1 or deferred? | Phase 1: flag at entry, compute at filing. Monthly amortization JE in Phase 2. |
| OD-V3-ARCH-03 | `companies.tax_type` and `business_type` — remove now or keep as shadow copy synced from compliance_profiles? | Keep synced for Phase 1 to avoid breaking app-layer code; remove in Phase 2 cleanup. |

## v3 Cross-Document Consistency Validation

- Doc 01 architecture principles → Doc 03 column specs: all 7 v3 gap areas reconciled ✓
- Doc 02 table inventory: updated to ~202 tables, MODULE 30 added ✓
- Doc 06 posting engine: `posting_rule_sets` versioned, `system_account_config` expanded ✓
- Doc 03, 06, 09 (security): `income_tax_computation_lines` and `nolco_tracking` need RLS policies (see doc 09 for required additions)
- Doc 10 checklist: v3 checklist items to be added per review findings

---

## Changes Applied (v2 → v2.1) — Principle Alignment

- Added Section 5.5: Compliance Profile & Feature Settings Design (Principles 1, 2, 6, 7)
- Added Percentage Tax (2551Q) flow to Section 8 Tax Lifecycle Design (Principle 20)
- Added FWT (1601FQ) flow to Section 8 (Principle 20)
- Updated Compliance Readiness Summary (Section 15) to include 2551Q, 1601FQ, ITR rows
- Added `income_tax_regime` as a distinct driver per Principle 3 Driver 2
- Customer/Supplier tax classifications expanded per Principle 5 (GOVERNMENT, PEZA, BOI, FOREIGN_ENTITY)

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

## 5.5 Compliance Profile & Feature Settings Design

### Compliance Profile — Principle 6

`company_compliance_profiles` is the single source of truth for a company's tax and regulatory configuration. It is versioned (effective_from / effective_to) and drives all compliance behavior.

```
company_compliance_profiles
  ├── taxpayer_type         ('vat' | 'non_vat')              → Drives VAT vs Percentage Tax
  ├── income_tax_regime     ('corporate' | 'individual' | 'partnership' | 'cooperative')
  ├── legal_type            ('sole_proprietor' | 'regular_corporation' | 'opc' | 'partnership' | 'cooperative')
  ├── withholding_agent_status ('registered' | 'not_registered')
  ├── rdo_code              (Revenue District Office)
  ├── bir_registered_at     (date of original BIR registration)
  ├── effective_from        (when this profile takes effect)
  ├── effective_to          (NULL = current)
  └── filing_obligations[]  (array: '2550m','2551q','1601eq','1601fq',etc.)
```

This allows a company that transitions from NON-VAT to VAT-registered to maintain historical compliance accuracy per Principle 11.

### Feature Settings — Principle 7

`company_feature_settings` stores per-company module visibility flags. These control the UI only — they never affect accounting or tax logic.

```
company_feature_settings
  ├── inventory_enabled       boolean (shows/hides Inventory module)
  ├── fixed_assets_enabled    boolean (shows/hides Fixed Assets module)
  ├── petty_cash_enabled      boolean (shows/hides Petty Cash module)
  ├── bank_recon_enabled      boolean (shows/hides Bank Reconciliation module)
  └── budgeting_enabled       boolean (shows/hides Budget module)
```

### Six Business Drivers — Principle 3

| Driver | Source | Affects |
|---|---|---|
| Taxpayer Type | `company_compliance_profiles.taxpayer_type` | VAT vs PT on transactions, dashboards, menus |
| Income Tax Regime | `company_compliance_profiles.income_tax_regime` | ITR form type (1701Q vs 1702Q), MCIT, OSD |
| Legal Type | `company_compliance_profiles.legal_type` | Company setup, registration, compliance reminders |
| Enabled Features | `company_feature_settings.*_enabled` | Menu visibility only |
| Transaction Classification | `vat_entries.vat_classification` | Transaction-level VAT/PT/exempt treatment |
| User Security Context | `user_roles`, `role_permissions` | Access, visibility, posting rights |

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

### Percentage Tax / 2551Q Flow

For NON-VAT companies, Percentage Tax (OTC: 3% of gross receipts) is computed from sales transactions instead of VAT.

```
Sales Invoice / Cash Sales (NON-VAT company)
        │
        ├── percentage_tax_entries (per period, per ATC code)
        │
        └── percentage_tax_period_summaries (aggregated by period)
                │
                └── BIR Form 2551Q (Quarterly Percentage Tax Return)
```

> Percentage Tax is NOT computed per line the same way VAT is. It is computed on total gross receipts per period. `percentage_tax_entries` aggregate from source transactions.

### FWT / 1601FQ Flow

Final Withholding Tax (FWT) applies to passive income, royalties, dividends, and certain professional fees (WF-series ATC codes). It is tracked separately from EWT.

```
Sales Invoice / Vendor Bill / Payment (FWT-subject items)
        │
        ├── fwt_entries (per transaction, WF-series ATC)
        │
        ├── certificates_2306 (per payee, per quarter)
        │
        └── fwt_remittances_1601fq (1601FQ quarterly remittance filing)
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
| 2551Q | `percentage_tax_entries` → `percentage_tax_period_summaries` → form output |
| 1601FQ | `fwt_entries` → `fwt_remittances_1601fq` → period aggregation |
| ITR (Corporate) | `itr_working_papers` → Book-to-tax → 1702Q / 1702RT |
| ITR (Individual) | `itr_working_papers` → Book-to-tax → 1701Q / 1701 |

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
