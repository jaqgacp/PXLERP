# PXL ERP — Database Architecture Overview
**Version:** 3.1 — Normalization Pass
**Prepared by:** PXL Database Architecture Team
**Status:** v3.1 — Normalization In Progress — Not Yet Migration-Approved

---

## UI Mockup — Prototype Disclaimer (v3.1 — BLOCKER 7 RESOLVED)

> **The `index.html` file in the repository root is a VISUAL PROTOTYPE ONLY.**
>
> It is a navigation mockup used to validate module organization, dropdown structure, and feature groupings with stakeholders. It is NOT:
> - A functional application
> - A representation of final UI design, color scheme, or component library
> - Evidence that backend features are implemented
> - A deliverable in itself
>
> **Architecture decisions based on the mockup:** The mockup confirms the module groupings used in this architecture document set. The Accounting dropdown structure (Journal Entries, Schedules, Period Management groups) reflects the architectural decisions in docs 02–10. The mockup will be replaced by actual application UI during development sprints.
>
> **Do not use the mockup as a source of truth for:** column names, business logic, workflow steps, BIR form configurations, or any technical specification. Use docs 02–10 for those.

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

### A. COA FS Mapping — Architecture Decision (RESOLVED)

**Decision: Phase 1 uses COA-embedded fields only. No separate mapping tables.**

Fields added to `chart_of_accounts`:
- `fs_section` — 10-value enum covering all FS statement sections
- `fs_group` — sub-group label within section (e.g., 'cash_and_equivalents')
- `fs_sort_order` — display ordering within fs_group
- `cash_flow_category` — ('operating','investing','financing'), NULL if not on direct CF

**Not included in Phase 1 (deferred to Phase 2):**
- `financial_statement_mappings` table — custom FS layouts for multi-GAAP
- `cash_flow_mapping_rules` table — indirect method cash flow computation rules
- `account_tax_mappings` table — replaced by inline COA flags (is_mcit_gross_income, is_osd_gross_revenue, tax_deductibility)

**Rationale:** MSME clients need standard PFRS for SMEs layouts. COA-embedded fields are sufficient for BS, P&L, SOCE generation without runtime joins to a separate mapping table. Phase 2 can add mapping tables if multi-GAAP or custom layouts are needed.

### B. Company Taxpayer Type — RESOLVED

**Canonical source:** `company_compliance_profiles.taxpayer_type` CHECK IN ('vat','non_vat')

`companies.tax_type` CHECK changed from ('vat','non_vat','**exempt**') to ('vat','non_vat'). **'exempt' is not a taxpayer type — it is a transaction-level VAT classification.** A company with exempt income is still either VAT-registered (files 2550 but discloses exempt sales) or non-VAT (files 2551Q). There is no 'exempt' taxpayer type under the NIRC.

`companies.tax_type` is retained as a deprecated shadow column synced from compliance_profiles. Removal planned for Phase 2.

### C. Party Classification vs Transaction VAT Classification — RESOLVED

**Separation of concerns:**

| Concept | Column | Table | Values |
|---|---|---|---|
| Customer VAT registration | `vat_registration_status` (v3: renamed from `vat_status`) | `customers` | 'vat', 'non_vat' |
| Customer special entity type | `party_special_class` (v3: new column) | `customers` | 'government', 'peza', 'boi', 'foreign_entity', NULL |
| Supplier VAT registration | `vat_registration_status` | `suppliers` | 'vat', 'non_vat' |
| Supplier special entity type | `party_special_class` | `suppliers` | same |
| Transaction tax treatment on sales lines | `vat_classification` | `sales_invoice_lines`, `cash_sale_lines` | 'vatable', 'zero_rated', 'exempt' |
| Transaction tax treatment on purchase lines | `vat_classification` | `vendor_bill_lines`, `cash_purchase_lines` | 'vatable', 'zero_rated', 'exempt', 'capital_goods', 'services' |
| Compliance reporting category | `vat_classification` | `vat_entries` | 'vatable', 'zero_rated', 'exempt', **'government'** |

**Why 'government' appears only in `vat_entries`:** BIR Form 2550M/2550Q has a specific disclosure line for "Sales to Government." Government sales are still vatable (12%), but the BIR requires them disclosed separately. When the posting engine creates a `vat_entry` for a vatable sale to a customer with `party_special_class = 'government'`, it automatically sets `vat_entries.vat_classification = 'government'`. The transaction line itself uses 'vatable' — the system derives the reporting category.

### D. Income Tax Table Overlaps — RESOLVED

**Canonical table set for income tax (consolidated from Module 19 + Module 30):**

| # | Table | Role | Status |
|---|---|---|---|
| 158a | `income_tax_return_filings` | ITR filing header per form per period | KEEP |
| 154 | `itr_computation_runs` (renamed from `itr_working_papers`) | Computation run header — when computed, by whom, status (draft/final) | RENAME |
| 199 | `income_tax_computation_lines` | Per-account GL breakdown per computation run | KEEP |
| 155 | `book_tax_reconciliations` | Summary book-to-tax reconciliation per fiscal year | KEEP |
| 200 | `nolco_tracking` | NOLCO balance and 3-year application tracking (canonical) | KEEP |
| 158 | `tax_credits_schedules` | Creditable taxes per year (2307 received, CWT on VAT, prior overpayment) | KEEP |
| **156** | **`mcit_computations`** | **REMOVE** — MCIT is computed from `income_tax_computation_lines` WHERE `is_mcit_gross_income = true`; no separate table needed | **REMOVED** |
| **157** | **`nolco_schedules`** | **REMOVE** — Replaced by `nolco_tracking` (#200) | **REMOVED** |

`itr_computation_runs` links to `income_tax_return_filings` (many runs per filing, for recomputation), and has `income_tax_computation_lines` as its detail lines.

### E. Other v3 Changes

### F. Phase 1 vs Phase 2 Feature Scope — Explicit Decision Record (v3.6)

> **Added to address Codex finding: architecture docs must explicitly state Phase 1 vs Phase 2 for all non-trivial feature areas.**

| Feature Area | Tables (Doc02 #) | Phase Decision | Rationale |
|---|---|---|---|
| Amortization Schedules | `amortization_schedules`, `_lines`, `_runs`, `_run_details` (#201–204) | **Phase 1** | Required for prepaid expense amortization (prepaid rent, insurance, software) — standard accounting requirement |
| Revenue Recognition Schedules | `revenue_recognition_schedules`, `_lines`, `_runs`, `_run_details` (#205–208) | **Phase 1** | Required for BIR-compliant deferred revenue treatment on multi-period service contracts and annual retainers |
| Auto Reversal | `auto_reversal_runs` (#209) + `journal_entries` flag columns | **Phase 1** | Needed for accrual entries posted with next-period auto-reversal (standard accrual accounting) |
| Budgets | `budgets`, `budget_lines` (#183–184) | **Phase 1** | Budget vs. actual variance analysis — core ERP feature for management reporting |
| Period Close Checklist | `period_close_checklists`, `period_close_tasks` (#185–186) | **Phase 1** | Ensures systematic period-end process before fiscal period lock |
| Generated Document Versions | `generated_document_versions` (#182) | **Phase 1** | Required for audit trail of document regeneration (BIR CAS compliance) |
| 1604E Annual EWT Summary | No separate filing table — derivable from `ewt_entries` | **Phase 2** | Annual aggregate derivable from quarterly 1601EQ data; export-only in Phase 2 |
| 1604F Annual FWT Summary | No separate filing table — derivable from `fwt_entries` | **Phase 2** | Same rationale as 1604E |
| Financial Statement Mapping Table | ~~`financial_statement_mappings`~~ **REMOVED** | **REMOVED** | Replaced by COA-embedded `fs_section`, `fs_group`, `fs_sort_order`. **UI label must NOT say "Financial Statement Mappings." Use "COA Classification Setup" or "FS Mapping (COA)".** |
| Warehouse Locations | ~~`warehouse_locations`~~ | **Phase 2** | Not needed for Phase 1 inventory; `warehouses` table suffices for bin-less stock tracking |
| Price Lists (multi-tier) | ~~`price_lists`~~ → canonical: `item_prices` (#55) | **Phase 1 — `item_prices` only** | `item_prices` handles Phase 1 pricing. Ghost name `price_lists` removed from all docs. Multi-tier price list management is Phase 2. |

- `posting_rule_sets.effective_from/effective_to` added (Principle 11)
- `system_account_config` keys expanded: PERCENTAGE_TAX_PAYABLE, FWT_PAYABLE, INCOME_TAX_PAYABLE
- `customer_tax_profiles` and `supplier_tax_profiles` now versioned with effective_from/effective_to
- All line tables: `vat_direction` + `vat_classification` now separate columns

## v3 Open Decisions — ALL RESOLVED (v3.7)

| OD# | Decision | **RESOLUTION** |
|---|---|---|
| OD-V3-ARCH-01 | Capital goods input VAT amortization (>PHP 1M): Phase 1 or Phase 2? | **RESOLVED v3.7:** Phase 1: classify to `INPUT_VAT_CAPITAL_GOODS` at posting time; accountant computes monthly amortization manually on 2550M. Phase 2: add recurring JE generator. See Doc06 OD-PE-03 resolution. |
| OD-V3-ARCH-02 | `companies.tax_type` shadow column: auto-trigger or manual? | **RESOLVED v3.7:** Auto-trigger. A PostgreSQL AFTER INSERT OR UPDATE trigger on `company_compliance_profiles` fires when a new profile row is inserted or `taxpayer_type` is updated. Trigger logic: `UPDATE companies SET tax_type = NEW.taxpayer_type WHERE id = NEW.company_id`. This keeps `companies.tax_type` in sync without application-layer coordination. Trigger name: `sync_companies_tax_type_from_compliance_profile`. `companies.tax_type` remains a DEPRECATED shadow column and will be removed in Phase 2 once all queries use `company_compliance_profiles` directly. |
| OD-V3-ARCH-03 | `itr_computation_runs` — how many per filing, is final locked? | **RESOLVED v3.7:** Multiple runs allowed per `income_tax_return_filings.id`. `is_final=true` marks the run used for actual filing — does NOT hard-lock. Accountant may set `is_final=false` on the previous run and create a new final run for amendments. Partial unique index `WHERE is_final=true` on `(company_id, income_tax_return_filing_id)` ensures exactly one final run per filing at any time. See also OD-V3-T2 in Doc02. |
| OD-V3-ARCH-04 | Doc 03 spec coverage gap (~120 tables unspecced) | **RESOLVED (v3.4):** Doc 03 Sections 24–44 add specs for all previously uncovered tables. Section 22 cross-reference index covers all 207 active tables. Total spec coverage = 207/207. |

## v3 Cross-Document Consistency Validation

- Doc 02 income tax module: `mcit_computations` (#156) and `nolco_schedules` (#157) marked REMOVED; table count adjusted ✓
- Doc 02 customers/suppliers module: `vat_status` note updated to reflect `vat_registration_status` + `party_special_class` split ✓
- Doc 03: `companies.tax_type` CHECK corrected; `customers/suppliers.vat_status` renamed and split; `vat_entries.vat_classification` note for 'government' derivation added ✓
- Doc 05: compliance map updated to reference `party_special_class` for government sales categorization ✓
- Doc 06: posting engine updated to route based on `party_special_class` at post time ✓
- Doc 07: new audit events added for income tax computation runs and party classification changes ✓
- Doc 08: import types updated for COA FS mapping fields and income tax mapping fields ✓
- **RESOLVED (v3.4+):** Doc 03 now has full column specs for all 207 active tables — directly in Doc 03 Sections 1–44 or cross-referenced via the Section 22 index. OD-V3-ARCH-04 is RESOLVED. Spec coverage = 207/207.

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
DR: Input VAT (input_vat_amount)
CR: Cash / Bank (net_amount + input_vat_amount - ewt_amount)
CR: EWT Payable (ewt_amount)   [if EWT-subject]  ← liability, credited
```
Column reference: `net_amount` = cost before VAT; `input_vat_amount` = VAT portion; `total_amount` = net_amount + input_vat_amount.

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
        ├── certificates_2306_issued (per payee, per quarter)
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
| ITR (Corporate) | `itr_computation_runs` → Book-to-tax → 1702Q / 1702RT |
| ITR (Individual) | `itr_computation_runs` → Book-to-tax → 1701Q / 1701 |

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

---

## 19. Income Tax Implementation Guide — Phase 1 (v3.7)

> **Purpose:** A senior developer must be able to implement the entire income tax module without asking a CPA or architect a single question. This section provides that complete specification.

### Setup Requirements

The following setup data must be present before income tax computation can run:

| Setup Item | Table | Required Values |
|---|---|---|
| Compliance profile | `company_compliance_profiles` | `income_tax_regime` ('corporate','individual','partnership','cooperative'), `deduction_method` ('itemized','osd','eight_percent'), `legal_type` |
| COA classification | `chart_of_accounts` | `is_mcit_gross_income`, `is_osd_gross_revenue`, `tax_deductibility` on all accounts |
| NOLCO tracking | `nolco_tracking` | Existing NOLCO carry-forward balances from prior years (opening balance import) |
| Tax credits | `tax_credits_schedules` | Prior year excess income tax credits, creditable withholding tax 2307 certificates received |

### Deduction Method Behavior

| Method | `deduction_method` value | Computation Rule | Who Can Use |
|---|---|---|---|
| Itemized Deduction | `'itemized'` | Taxable Income = Gross Revenue − Cost of Sales − Allowable Operating Expenses (per `tax_deductibility` COA tag). Non-deductible expenses must be added back. | All income_tax_regime values |
| Optional Standard Deduction (OSD) | `'osd'` | Taxable Income = Gross Revenue − 40% of Gross Revenue (gross revenue per `is_osd_gross_revenue` COA tags). No itemized expenses deducted. Simpler but higher tax for expense-heavy businesses. | Corporate and individual only |
| 8% Gross Receipts Tax | `'eight_percent'` | Income Tax = 8% × Gross Receipts (≤ PHP 3M threshold). No deductions applied. Replaces regular income tax AND percentage tax. | Individuals only (`income_tax_regime='individual'`) |

### MCIT (Minimum Corporate Income Tax)

- MCIT applies only to `income_tax_regime='corporate'` companies in their 4th year of operation and beyond.
- MCIT rate: 2% of Gross Income (per `is_mcit_gross_income` COA tags).
- BIR Rule: Pay the HIGHER of Regular Corporate Tax (30% of taxable income) or MCIT (2% of gross income).
- Computation: `itr_computation_runs` engine computes both; the ITR line `income_tax_due` = MAX(regular_income_tax, mcit_amount).
- MCIT Carry-Forward: If MCIT > Regular Tax in a given year, the excess MCIT is tracked in `income_tax_computation_lines` with `line_type='mcit_carry_forward'` and can be credited against Regular Tax in the next 3 years when Regular Tax > MCIT.

### NOLCO (Net Operating Loss Carry-Over)

- NOLCO applies to `income_tax_regime='corporate'` and `'individual'` (not cooperative or partnership using OSD).
- A Net Operating Loss (taxable income < 0) from a given year can be carried forward and deducted in subsequent years (up to 3 years carry-forward period; currently 5 years for COVID-affected periods — CPA to confirm current BIR regulation).
- Storage: `nolco_tracking` table — one row per loss year per company, tracking `original_loss_amount`, `utilized_amount`, `remaining_balance`, `expiry_year`.
- Computation: At ITR run time, the engine reads `nolco_tracking WHERE remaining_balance > 0 AND expiry_year >= current_year` and deducts available NOLCO from current year taxable income (up to the taxable income amount — NOLCO cannot create a new loss).
- Posting impact: No GL posting for NOLCO utilization. NOLCO is a tax computation line only — it reduces `income_tax_due` but does not create a journal entry. The `nolco_tracking.utilized_amount` is updated after the run is marked `is_final=true`.

### Tax Credits

- Creditable Withholding Tax (CWT) credits: From `certificates_2307_received` (BIR Form 2307 from customers who withheld EWT from payments to us). These reduce income tax due.
- `tax_credits_schedules` links to `certificates_2307_received` (FK `certificate_2307_id`). Total CWT credit = SUM of all 2307 credits for the year.
- Prior year excess credits: From `tax_credits_schedules` with `credit_type='prior_year_excess'`. These carry forward if not fully utilized.
- Computation: `income_tax_due_after_credits = income_tax_due - total_cwt_credits - prior_year_excess_credits`. If result < 0, the excess is carried to next year.

### Book-to-Tax Reconciliation

- `book_tax_reconciliations` + `book_tax_reconciliation_lines`: One reconciliation per fiscal year per company.
- Each line represents one reconciling item between book income and taxable income. Examples:
  - Non-deductible entertainment expense (ADD BACK to book income)
  - Tax-exempt income (DEDUCT from book income)  
  - NOLCO utilization (DEDUCT)
  - Timing differences (depreciation rate difference book vs tax)
- This is the Schedule 2 of BIR Form 1702-MX (mandatory for corporations using itemized deductions).
- Developer: `book_tax_reconciliation_lines.adjustment_type CHECK IN ('add_back','deduction')` — developer must confirm this CHECK is in Doc03 Section 20; if missing, add it.

### ITR Computation Run Flow

```
1. User initiates ITR run for fiscal_year_id
2. Engine creates itr_computation_runs record (status='processing')
3. DELETE income_tax_computation_lines WHERE computation_run_id = (new run id) [idempotency]
4. READ company_compliance_profiles (effective on fiscal_year end date)
5. READ gl_balances aggregated per account per year (all periods for fiscal_year_id)
6. COMPUTE gross_revenue = SUM(gl_balances) WHERE coa.is_osd_gross_revenue=true (if OSD) OR coa.is_mcit_gross_income=true (if MCIT)
7. COMPUTE taxable_income per deduction_method:
   - 'itemized': gross_revenue - cost_of_sales - allowable_expenses (tax_deductibility IN ('fully_deductible','partially_deductible'))
   - 'osd': gross_revenue - (gross_revenue × 0.40)
   - 'eight_percent': gross_receipts × 0.08 (this IS the income_tax_due — no further steps 8-9)
8. APPLY NOLCO: taxable_income = MAX(0, taxable_income - available_nolco)
9. COMPUTE income_tax_due: 
   - corporate: MAX(taxable_income × 0.25, gross_income × 0.02)  [Regular CIT vs MCIT]
   - individual/partnership: per graduated table (Phil BIR TRAIN Law rates)
10. APPLY tax_credits: income_tax_due_after_credits = income_tax_due - cwt_credits - prior_excess
11. INSERT income_tax_computation_lines (one per computation component)
12. UPDATE itr_computation_runs (status='completed', taxable_income=, income_tax_due=, income_tax_due_after_credits=)
13. SNAPSHOT: itr_computation_runs.regime_snapshot = current income_tax_regime, deduction_method_snapshot = current deduction_method
```

### Income Tax GL Posting

Income tax is posted as a journal entry (manually by the accountant or via a JE-type='manual' entry):
```
DR: Income Tax Expense (P&L account)       = income_tax_due
CR: Income Tax Payable (FROM_SYSTEM_CONFIG 'INCOME_TAX_PAYABLE')  = income_tax_due
```
This is NOT auto-posted by the computation engine. The accountant reviews the `itr_computation_runs` result and manually creates this JE in the period before filing.

### Cooperative Income Tax Regime

- `income_tax_regime='cooperative'` is included in the CHECK constraint but is **out of scope for Phase 1**.
- If a cooperative company is onboarded, the setup wizard must reject or warn: "Cooperative income tax computation is not supported in Phase 1. Contact support."
- The posting engine will abort for cooperatives if income tax computation is triggered.

---

## 20. Report Generation Contract — Financial Statements (v3.7)

> **Purpose:** Every financial report must have a documented generation algorithm. A developer must be able to build any report without asking: "How does this calculate?" This section provides that contract.

### Balance Sheet

**Source tables:** `gl_balances`, `chart_of_accounts`, `account_types`, `fiscal_periods`

**Algorithm:**
```
1. SELECT gl_balances WHERE company_id=? AND fiscal_period_id IN (all periods up to target period)
   GROUP BY account_id, SUM(period_debit - period_credit) AS net_movement
2. JOIN chart_of_accounts ON account_id
3. JOIN account_types ON account_type_id
4. Running balance = opening_balance (from prior periods) + SUM(net_movement for current year periods)
5. GROUP BY coa.fs_section, coa.fs_group, ORDER BY coa.fs_sort_order
6. Balance Sheet sections:
   ASSETS = fs_section IN ('current_assets','non_current_assets')
   LIABILITIES = fs_section IN ('current_liabilities','non_current_liabilities')
   EQUITY = fs_section = 'equity'
7. VERIFY: Total Assets = Total Liabilities + Total Equity (accounting equation check)
```

**Normal balance rule:** Asset and Expense accounts have normal_balance='debit' — a positive net (debit > credit) is a positive balance. Liability, Equity, and Revenue accounts have normal_balance='credit' — a positive net (credit > debit) is a positive balance.

**Retained Earnings:** Closed prior-year P&L is accumulated in the Retained Earnings account (FROM_SYSTEM_CONFIG 'RETAINED_EARNINGS') via the year-end closing JE. Current-year net income is NOT in Retained Earnings until year-end close — it appears as the sum of Revenue − Expenses from the current fiscal year's P&L.

---

### Income Statement (Profit & Loss)

**Source tables:** `gl_balances`, `chart_of_accounts`, `account_types`, `fiscal_periods`

**Algorithm:**
```
1. SELECT gl_balances WHERE company_id=? AND fiscal_period_id IN (periods within target date range)
   GROUP BY account_id, SUM(period_debit - period_credit) AS net_movement
2. FILTER: account_type IN ('revenue','cost_of_sales','expense','other_income','other_expense','contra_revenue','contra_expense')
3. GROUP BY coa.fs_section, coa.fs_group, ORDER BY coa.fs_sort_order
4. P&L Structure:
   Revenue = fs_section='revenue' (credit normal — show positive if cr > dr)
   Less: Sales Returns = fs_section for contra_revenue (deduct)
   NET REVENUE = Revenue - Contra Revenue
   Less: Cost of Sales = fs_section='cost_of_sales' (debit normal)
   GROSS PROFIT = Net Revenue - Cost of Sales
   Less: Operating Expenses = fs_section='operating_expenses' (debit normal)
   OPERATING INCOME = Gross Profit - Operating Expenses
   Add: Other Income = fs_section='other_income' (credit normal)
   Less: Other Expenses = fs_section='other_expenses' (debit normal)
   NET INCOME BEFORE TAX = Operating Income + Other Income - Other Expenses
   Less: Income Tax Expense (account tagged in COA)
   NET INCOME AFTER TAX
```

---

### Trial Balance

**Source tables:** `gl_balances`, `chart_of_accounts`

**Algorithm:**
```
1. SELECT account_id, SUM(period_debit) AS total_debit, SUM(period_credit) AS total_credit
   FROM gl_balances WHERE company_id=? AND fiscal_period_id IN (target periods)
   GROUP BY account_id
2. JOIN chart_of_accounts: account_code, account_name, account_type
3. ORDER BY account_code ASC
4. VERIFY: SUM(total_debit) = SUM(total_credit) — if not equal, posting engine has a bug (impossible if posting engine enforces balanced JEs)
```

**Columns:** Account Code | Account Name | Account Type | Debit Total | Credit Total

---

### General Ledger (Account Ledger)

**Source tables:** `journal_entries`, `journal_lines`, `chart_of_accounts`, `fiscal_periods`

**Algorithm:**
```
1. SELECT journal_lines WHERE company_id=? AND account_id=? AND journal_entry.document_date BETWEEN ? AND ?
2. JOIN journal_entries ON journal_entry_id
3. ORDER BY journal_entries.document_date ASC, journal_entries.created_at ASC
4. Running balance computed in application layer (cumulative DR - CR from opening balance)
5. Opening balance = SUM(gl_balances for all prior periods for this account)
```

**Columns:** Date | Document No | Reference | Description | Debit | Credit | Running Balance

---

### Cash Flow Statement

**Phase 1 method:** Indirect method (from Net Income, adjust for non-cash items and working capital changes).

**Algorithm:**
```
OPERATING ACTIVITIES:
  Start: Net Income (from P&L)
  Add back: Depreciation (journal_lines where account.account_type='contra_asset' — accumulated depreciation)
  Add back: Amortization (journal_lines from je_type='amortization')
  Adjust: Changes in Working Capital:
    - Increase in AR = negative (cash not yet received)
    - Decrease in AR = positive
    - Increase in Inventory = negative
    - Increase in AP = positive (cash not yet paid)
    Source: difference in gl_balances for AR_CONTROL, AP_CONTROL, INVENTORY_CONTROL between periods

INVESTING ACTIVITIES:
  Cash paid for assets = journal_lines where account.cash_flow_category='investing' AND entry_side='credit'
  Proceeds from disposal = journal_lines where account.cash_flow_category='investing' AND entry_side='debit'

FINANCING ACTIVITIES:
  Cash from loans = journal_lines where account.cash_flow_category='financing' AND entry_side='credit'
  Loan repayments = journal_lines where account.cash_flow_category='financing' AND entry_side='debit'

NET CHANGE IN CASH = Operating + Investing + Financing
OPENING CASH = SUM(gl_balances WHERE coa.is_cash_equivalent=true) at prior period end
CLOSING CASH = Opening Cash + Net Change
```

**Note:** The `cash_flow_category` on `chart_of_accounts` and `is_cash_equivalent` flag are the only inputs. Accuracy depends on CPA-reviewed COA seed template correctly tagging all cash-flow-impacting accounts.

---

### AR Aging Report

**Source tables:** `subsidiary_ledger_entries`, `customers`, `sales_invoices`

**Algorithm:**
```
1. SELECT subsidiary_ledger_entries WHERE company_id=? AND ledger_type='ar' AND is_open=true
2. JOIN sales_invoices ON document_id to get due_date
3. Aging bucket = report_date - due_date:
   Current = due_date >= report_date (not yet due)
   1-30 days = due_date between report_date-30 and report_date-1
   31-60 days = due_date between report_date-60 and report_date-31
   61-90 days = due_date between report_date-90 and report_date-61
   Over 90 days = due_date < report_date-90
4. GROUP BY customer_id, aging_bucket
```

---

### AP Aging Report

Same algorithm as AR Aging but: `ledger_type='ap'`, join to `vendor_bills` for due_date.

---

### Customer Ledger

**Source tables:** `subsidiary_ledger_entries`, `customers`, `document_relationships`

```
1. SELECT subsidiary_ledger_entries WHERE company_id=? AND ledger_type='ar' AND customer_id=?
2. ORDER BY created_at ASC
3. Running balance: DR (invoice) increases balance; CR (receipt/credit memo) decreases balance
4. Show each document: Date | Document Type | Document No | Debit | Credit | Balance
```

---

### Supplier Ledger

Same as Customer Ledger but `ledger_type='ap'`, supplier_id filter.

---

### VAT Report (2550M / 2550Q)

**Source tables:** `vat_entries`, `vat_period_summaries`

```
OUTPUT VAT:
  SELECT SUM(base_amount), SUM(vat_amount)
  FROM vat_entries WHERE company_id=? AND tax_period_id=? AND vat_direction='output'
  GROUP BY vat_classification
  → 'vatable' sales → Box 10 (2550M)
  → 'zero_rated' → Box 11
  → 'government' → Box 12 (government sales with 5% CWT)
  → 'exempt' → Box 13

INPUT VAT:
  SELECT SUM(base_amount), SUM(vat_amount)
  FROM vat_entries WHERE vat_direction='input'
  GROUP BY vat_classification
  → 'vatable' → deductible input VAT
  → 'capital_goods' → deductible (subject to 60-month rule if >1M)
  → 'services' → deductible input VAT
  
VAT PAYABLE = Total Output VAT - Total Deductible Input VAT
```

---

### EWT Report (1601EQ / BIR Alphalist)

**Source tables:** `ewt_entries`, `ewt_period_summaries`, `atc_codes`

```
1. SELECT ewt_entries WHERE company_id=? AND tax_period_id=? 
   GROUP BY ewt_atc_id, payee_tin
   SUM(ewt_base_amount), SUM(ewt_amount)
2. JOIN atc_codes ON ewt_atc_id
3. Group by ATC for 1601EQ schedule
4. Payee detail = alphalist (payee_name, payee_tin, ewt_amount per payee)
```

---

### Taxable Income Computation Report

**Source:** `itr_computation_runs`, `income_tax_computation_lines`, `book_tax_reconciliations`, `book_tax_reconciliation_lines`

This report is a printout of the ITR computation run. Layout:
```
Gross Revenue per Books:                    [from income_tax_computation_lines where line_type='gross_revenue']
Less: Non-taxable Income:                   [line_type='non_taxable_income']
Gross Revenue per BIR:
Less: Cost of Sales / OSD / 40%:           [line_type='cost_of_sales' or 'osd_deduction']
Less: Operating Expenses (Itemized):        [line_type='allowable_expense', grouped by expense category]
Net Income per Books:
Add: Non-deductible items (Book-to-Tax):   [book_tax_reconciliation_lines where adjustment_type='add_back']
Less: Tax-exempt items:                    [book_tax_reconciliation_lines where adjustment_type='deduction']
Net Income per BIR:
Less: NOLCO (if any):                      [line_type='nolco_deduction']
TAXABLE INCOME:
Income Tax Rate:                            25% (corporate) / graduated (individual)
REGULAR INCOME TAX:
MCIT (if applicable):                       2% × Gross Income
INCOME TAX DUE:                            MAX(Regular, MCIT) or 8% gross receipts
Less: CWT Credits (2307):                  [tax_credits_schedules]
Less: Prior Year Excess Credits:           [tax_credits_schedules]
INCOME TAX STILL DUE AND PAYABLE:
```
