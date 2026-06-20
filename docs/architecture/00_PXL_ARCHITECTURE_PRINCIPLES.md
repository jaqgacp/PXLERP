# PXL ERP — Architecture Principles
**Version:** 1.0 — Blueprint Locked
**Status:** Active — All decisions must reference this document

---

## Purpose

This document defines the non-negotiable design principles of PXL ERP.

All blueprint, database, UI/UX, compliance, posting engine, and implementation decisions must follow these principles.

---

## 1. Relevance-First User Experience

Users should only see the modules, menus, reports, dashboards, fields, and actions that are relevant to their company setup, role, permissions, and compliance profile.

Examples:

- A Non-VAT company should not see VAT returns as active workflows.
- A VAT company should see VAT dashboards, VAT reports, and VAT validation.
- A sole proprietor should not see corporate-only tax features such as MCIT if not applicable.
- A corporation should see corporate income tax features when applicable.
- A company without inventory enabled should not see inventory workflows.
- A user without posting permission should not see posting actions.

**Principle:** Do not overwhelm the user with irrelevant ERP complexity.

---

## 2. One Database, Configurable Behavior

PXL should not create separate systems for VAT, Non-VAT, service, trading, branch-based, or inventory-based clients.

Use one database architecture.

Behavior should be driven by:

- `company_compliance_profiles`
- `company_feature_settings`
- user roles and permissions
- transaction classifications
- posting rule sets
- validation rules

**Principle:** Different client behavior should come from configuration, not duplicated systems.

---

## 3. Company Scope Must Stay Focused

PXL Phase 1 targets normal Philippine private-sector businesses only.

**Supported company taxpayer types:**
- VAT
- NON_VAT

**Supported company legal types:**
- SOLE_PROPRIETOR
- REGULAR_CORPORATION
- OPC
- PARTNERSHIP
- COOPERATIVE

**Out of scope as client/company profiles:**
- GOVERNMENT
- PEZA
- BOI
- FOREIGN_ENTITY

**Principle:** Do not overbuild company/client scope before the core market is stable.

---

## 4. Customer/Supplier Scope Is Broader Than Company Scope

Even if PXL does not target Government, PEZA, BOI, or Foreign entities as client companies, PXL users may transact with those parties.

Therefore customer and supplier tax profiles may support:

- VAT
- NON_VAT
- EXEMPT
- GOVERNMENT
- PEZA
- BOI
- FOREIGN_ENTITY

**Principle:** Company scope is narrow. Party transaction classification must be broad enough for real-world PH transactions.

---

## 5. Separate Legal Type, Taxpayer Type, and Income Tax Regime

Do not mix legal form, VAT status, and income tax treatment.

These are separate drivers:

**`legal_type`:**
- SOLE_PROPRIETOR
- REGULAR_CORPORATION
- OPC
- PARTNERSHIP
- COOPERATIVE

**`taxpayer_type`:**
- VAT
- NON_VAT

**`income_tax_regime`:**
- CORPORATE
- INDIVIDUAL
- PARTNERSHIP
- COOPERATIVE

Examples:
- OPC → `legal_type` OPC, `income_tax_regime` CORPORATE
- Sole Proprietor → `legal_type` SOLE_PROPRIETOR, `income_tax_regime` INDIVIDUAL
- Regular Corporation → `legal_type` REGULAR_CORPORATION, `income_tax_regime` CORPORATE

**Principle:** Correct tax behavior requires separate classification dimensions.

---

## 6. Compliance Profile Drives Compliance Logic

Compliance behavior should be driven by `company_compliance_profiles`, not hardcoded UI assumptions.

`company_compliance_profiles` should determine:

- VAT or Non-VAT treatment
- percentage tax applicability
- income tax regime
- withholding agent status
- RDO
- filing obligations
- effective dates

**Principle:** Compliance settings must be versioned, auditable, and effective-date aware.

---

## 7. Feature Settings Drive Visibility, Not Accounting Logic

`company_feature_settings` may control visibility of optional modules such as:

- Inventory
- Fixed Assets
- Petty Cash
- Bank Reconciliation
- Budgeting
- Cash Sales
- Cash Purchases

But feature settings must not override accounting or tax logic.

Example:
- VAT logic comes from compliance profile.
- Inventory visibility comes from feature settings.
- Permissions come from roles/RLS.

**Principle:** Visibility settings are not accounting rules.

---

## 8. Transaction Tables Must Capture Complete Source Data

Every transaction must preserve source details needed for:

- accounting
- tax compliance
- audit
- reporting
- reversal
- traceability

Transaction tables must include, where applicable:

| Column | Purpose |
|---|---|
| `document_no` | BIR-traceable document number |
| `document_date` | Date of the transaction |
| `posting_date` | Date posted to GL |
| `fiscal_year_id` | FK to fiscal calendar |
| `fiscal_period_id` | FK to fiscal period |
| `company_id` | Tenant isolation |
| `branch_id` | Branch dimension |
| `department_id` | Department dimension |
| `cost_center_id` | Cost center dimension |
| `currency_id` | Currency (PHP for Phase 1) |
| `exchange_rate` | Rate at transaction time |
| `subtotal_amount` | Amount before tax |
| `vat_amount` | VAT computed |
| `withholding_amount` | EWT deducted |
| `total_amount` | Final amount |
| `status` | Document lifecycle state |
| `posted_at` | Timestamp when posted |
| `posted_by` | Who posted |
| `voided_at` | Timestamp when voided |
| `voided_by` | Who voided |
| `source_document_id` | FK to originating document |
| `source_document_type` | Table name of originating document |

**Principle:** Capture complete data at the source. Reports should not require guessing later.

---

## 9. Transaction Tax Classification Is Separate From Company Taxpayer Type

Company taxpayer type determines whether the company is VAT or Non-VAT.

Transaction tax classification determines how each line is treated.

`transaction_tax_classification` should support:

- VATABLE
- ZERO_RATED
- EXEMPT
- NON_VAT

**Principle:** A company can have different transaction classifications. Do not oversimplify tax treatment.

---

## 10. Posting Must Be Rule-Based and Traceable

All automatic journal entries must come from `posting_rule_sets` and `posting_rule_lines`.

Posting must be:

- balanced
- traceable
- repeatable
- auditable
- idempotent
- blocked if the fiscal period is closed or locked

Every posted transaction must link to:

- `journal_entries`
- `journal_lines`
- source document
- posting rule set
- audit log

**Principle:** No hidden accounting logic.

---

## 11. Posted Transactions Are Immutable

Posted transactions must not be edited or deleted.

Corrections must be done through:

- reversal
- credit memo
- debit memo
- void process
- adjustment journal entry

**Principle:** No silent edits after posting.

---

## 12. Every Compliance Output Must Have Source Traceability

Every compliance report or export must trace back to source transactions.

| Compliance Output | Source Chain |
|---|---|
| VAT Return | `vat_entries` → sales/purchase lines |
| SLSP | `sales_invoices` / `cash_sales` |
| RELIEF | `vendor_bills` / `cash_purchases` |
| QAP | `ewt_entries` |
| SAWT | `certificates_2307_received` |
| 1601EQ | `ewt_entries` |
| 2551Q | percentage tax entries |
| CAS Books | posted journal entries and source documents |

**Principle:** Compliance must be explainable down to the document line level.

---

## 13. Audit Trail Is Non-Negotiable

PXL must maintain auditability at three levels:

1. **Record-level** — audit columns (`created_by`, `updated_by`, `deleted_by`) on every table
2. **Field-level** — `field_change_history` captures before/after per field
3. **Event-level** — `audit_logs` and `user_activity_logs` capture every significant action

Audit must cover:

- master data changes
- setup changes
- tax profile changes
- posting rule changes
- document status changes
- approvals
- posting
- voiding
- reversals
- exports
- generated documents
- login/session activity

**Principle:** If it affects accounting, compliance, security, or reporting, it must be auditable.

---

## 14. Import and Bulk Creation Are First-Class Requirements

Setup and master data must support import/bulk creation, not only one-by-one CRUD.

Import must support:

- chart of accounts
- customers
- suppliers
- items
- services
- branches
- departments
- cost centers
- opening balances
- inventory opening
- fixed asset opening
- tax setup
- payment terms

**Principle:** MSME onboarding must be practical and scalable.

---

## 15. Reports Are Outputs, Not Separate Truths

Reports must derive from source transactions, ledgers, compliance entries, and generated output tables.

Reports should not create independent accounting truth.

**Principle:** There must be one source of accounting truth.

---

## 16. Tables Must Be Designed Before UI

UI must follow data architecture.

Do not build UI first and force tables to fit later.

Before implementation:

- every menu item must map to tables or computed views
- every table must have columns
- every table must have relationships
- every posting path must be defined
- every compliance output must be mapped

**Principle:** Tables first. UI second.

---

## 17. Blueprint and Database Must Stay Aligned

The blueprint, table inventory, column specifications, relationship map, compliance map, posting design, audit design, import/export design, and security design must agree.

No table should exist in one document and be missing in another.

**Principle:** Documentation inconsistency is an architecture bug.

---

## 18. Avoid Overengineering, But Do Not Under-Capture

Do not build modules outside Phase 1 scope.

**Out of scope for Phase 1:**
- Payroll
- POS
- Full Manufacturing
- CRM
- HRMS
- PEZA/BOI/Government client support
- Foreign entity client support

But do not under-capture data required for:

- accounting
- PH compliance
- audit
- reporting
- future migration

**Principle:** Keep scope focused, but make the data model complete.

---

## 19. Supabase Must Be Treated as the Core Platform

Architecture must respect Supabase/PostgreSQL realities:

- Row Level Security
- Edge Functions
- Storage
- Realtime
- service role safety
- indexing
- constraints
- triggers
- migrations
- `auth.users` integration

**Principle:** Design for the actual platform, not an abstract ERP.

---

## 20. Finality Requires Review Discipline

No document should be marked final unless:

- open decisions are resolved
- blueprint is aligned with tables
- tables are aligned with columns
- relationships are complete
- posting is mapped
- compliance is mapped
- audit is mapped
- RLS is mapped
- UI visibility drivers are mapped

**Principle:** Slow review now prevents painful rebuilds later.
