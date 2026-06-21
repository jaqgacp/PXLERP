# PXL ERP — Architecture Principles
**Version:** 4.0 — Canonical Release
**Status:** v4.0 — DATABASE FREEZE CANDIDATE. Pending human sign-off (see Doc10 Sections 47–53).

---

## Purpose

This document defines the non-negotiable architectural principles of PXL ERP.

All future decisions involving:

- Blueprint
- UI/UX
- Database Design
- Supabase Architecture
- Security
- Compliance
- Posting Engine
- Reporting
- Audit Trail
- Import/Export
- Integrations
- Automation

must follow these principles.

If a future design conflicts with these principles, these principles take precedence.

These principles are the constitutional foundation of PXL ERP.

---

## PRINCIPLE 1 — RELEVANCE-FIRST ERP

Users should only see:

- modules they use
- reports applicable to them
- compliance obligations they have
- actions they are authorized to perform
- setup options relevant to their company profile

The ERP should adapt to the company. The company should not adapt to the ERP.

### VAT Company

**Show:**
- VAT Dashboard
- VAT Reports
- VAT Returns
- VAT Reconciliation
- Output VAT Review
- Input VAT Review

**Hide:**
- Percentage Tax Dashboard
- 2551Q Workflows

---

### NON-VAT Company

**Show:**
- Percentage Tax Dashboard
- 2551Q Workflows
- Percentage Tax Reports

**Hide:**
- VAT Dashboard
- VAT Returns
- VAT Working Papers

---

### Sole Proprietor

**Show:**
- Individual income tax workflows

**Hide:**
- MCIT
- Corporate tax schedules

---

### Corporation / OPC

**Show:**
- MCIT
- Corporate tax schedules
- Corporate compliance dashboards

---

### Company Without Inventory

**Hide:**
- Warehouses
- Stock Transfers
- Inventory Valuation
- Inventory Ledger

---

### Company Without Fixed Assets

**Hide:**
- Asset Register
- Depreciation Run
- Asset Disposal

---

### User Without Posting Rights

**Hide:**
- Post
- Reverse
- Fiscal Lock
- Reopen Period

**Principle:** Only show what is relevant.

---

## PRINCIPLE 2 — ONE DATABASE, CONFIGURABLE BEHAVIOR

PXL must never create separate systems for:

- VAT companies
- NON-VAT companies
- Service businesses
- Trading businesses
- Multi-branch businesses
- Inventory businesses

There must be one architecture.

Behavior must be driven by:

- `company_compliance_profiles`
- `company_feature_settings`
- user roles
- permissions
- transaction classifications
- posting rules
- validation rules

**Principle:** Configuration, not duplication.

---

## PRINCIPLE 3 — SEPARATE BUSINESS DRIVERS

Never mix unrelated business concepts.

PXL uses independent business drivers.

---

### Driver 1 — Company Taxpayer Type

Determines VAT vs Percentage Tax behavior.

**Values:** `VAT` | `NON_VAT`

**Affects:**
- Sales
- Purchasing
- Compliance
- Reports
- Posting Rules
- Dashboards

---

### Driver 2 — Income Tax Regime

Determines income tax treatment.

**Values:** `CORPORATE` | `INDIVIDUAL` | `PARTNERSHIP` | `COOPERATIVE`

**Affects:**
- Income Tax Dashboard
- Quarterly ITR
- Annual ITR
- MCIT
- OSD
- NOLCO
- Book-to-Tax
- Tax Credits

---

### Driver 3 — Legal Type

Determines legal structure.

**Values:** `SOLE_PROPRIETOR` | `REGULAR_CORPORATION` | `OPC` | `PARTNERSHIP` | `COOPERATIVE`

**Affects:**
- Company Setup
- Registration Requirements
- Compliance Reminders
- Company Profile

---

### Driver 4 — Enabled Features

**Examples:** Inventory | Fixed Assets | Petty Cash | Bank Reconciliation | Budgeting

**Affects:**
- Menus
- Dashboards
- Navigation
- Reports

---

### Driver 5 — Transaction Tax Classification

Determines transaction-level tax treatment.

**Values:** `VATABLE` | `ZERO_RATED` | `EXEMPT` | `NON_VAT`

**Affects:**
- VAT
- Percentage Tax
- Compliance
- Reports
- Posting

> ZERO_RATED and EXEMPT are transaction classifications. They are not automatically company classifications.

---

### Driver 6 — User Security Context

Determines access.

**Values:** Role | Permission | Company Access | Branch Access | Department Access

**Affects:**
- Visibility
- Edit Rights
- Approval Rights
- Posting Rights

---

## PRINCIPLE 4 — COMPANY SCOPE MUST STAY FOCUSED

Phase 1 supports:

**Company Taxpayer Types:**
- VAT
- NON_VAT

**Company Legal Types:**
- SOLE_PROPRIETOR
- REGULAR_CORPORATION
- OPC
- PARTNERSHIP
- COOPERATIVE

**Out of Scope:**
- Government Entities
- PEZA Entities
- BOI Entities
- Foreign Entities

**Principle:** Master the core PH private-sector market first.

---

## PRINCIPLE 5 — CUSTOMER AND SUPPLIER SCOPE IS BROADER

Even though PXL does not target Government, PEZA, BOI, or Foreign entities as clients, users may transact with them.

Customer and Supplier classifications may include:

- VAT
- NON_VAT
- EXEMPT
- GOVERNMENT
- PEZA
- BOI
- FOREIGN_ENTITY

**Principle:** Company scope and transaction scope are different.

---

## PRINCIPLE 6 — COMPLIANCE PROFILE DRIVES COMPLIANCE

Compliance behavior must come from `company_compliance_profiles`.

Contents include:

- `taxpayer_type`
- `legal_type`
- `income_tax_regime`
- `withholding_agent_status`
- filing obligations
- RDO
- registration dates
- effective dates

Compliance logic must not be hardcoded in UI.

**Principle:** Compliance must be configurable, versioned, and auditable.

---

## PRINCIPLE 7 — FEATURE SETTINGS DRIVE VISIBILITY ONLY

`company_feature_settings` may control:

- Inventory
- Fixed Assets
- Petty Cash
- Bank Reconciliation
- Budgeting

Feature settings must never determine:

- VAT treatment
- Tax treatment
- Accounting treatment
- Posting behavior

**Principle:** Visibility settings are not accounting rules.

---

## PRINCIPLE 8 — TABLES FIRST, UI SECOND

Before UI implementation:

- Every menu must map to tables
- Every table must have columns
- Every table must have relationships
- Every posting path must be documented
- Every compliance output must be mapped

**Principle:** UI follows architecture. Never the reverse.

---

## PRINCIPLE 9 — COMPLETE DATA CAPTURE

Transactions must capture everything required for:

- Accounting
- Compliance
- Audit
- Reporting
- Reversals
- Traceability

Reports must not reconstruct missing information.

**Principle:** Capture once. Reuse forever.

Standard transaction columns that must be present where applicable:

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

---

## PRINCIPLE 10 — SNAPSHOT CRITICAL COMPLIANCE DATA

Transactions must preserve compliance snapshots at time of transaction.

Examples:

- TIN
- Registered Name
- Registered Address
- VAT Status
- ATC
- Tax Rate
- Currency Rate
- Company Registration Data

Changing master data must never alter historical compliance documents.

**Principle:** Compliance documents must remain historically correct.

---

## PRINCIPLE 11 — EFFECTIVE-DATE VERSIONING

PXL must preserve historical configurations.

Examples:

- VAT rate changes
- Percentage Tax rate changes
- EWT rate changes
- ATC changes
- Posting rule changes
- Compliance profile changes
- Financial statement mappings

Transactions must use the configuration effective on the transaction date.

**Principle:** History must remain historically accurate.

---

## PRINCIPLE 12 — POSTING MUST BE RULE-BASED

All accounting entries must originate from:

- `posting_rule_sets`
- `posting_rule_lines`

Posting must be:

- Balanced
- Traceable
- Repeatable
- Auditable
- Idempotent
- Blocked if the fiscal period is closed or locked

Every posting must link:

- Source Document
- Journal Entry
- Journal Lines
- Posting Rule
- Audit Trail

**Principle:** No hidden accounting logic.

---

## PRINCIPLE 13 — POSTED TRANSACTIONS ARE IMMUTABLE

Posted transactions must never be edited.

Corrections must occur through:

- Reversal
- Credit Memo
- Debit Memo
- Adjustment Entry
- Void Process

**Principle:** No silent modifications after posting.

---

## PRINCIPLE 14 — COMPLIANCE MUST BE TRACEABLE

Every compliance report must trace back to source transactions.

| Compliance Output | Source Chain |
|---|---|
| VAT Return | VAT Entries → Invoice Lines → Source Documents |
| 2551Q | Percentage Tax Entries → Source Documents |
| SLSP | Sales Invoices / Cash Sales |
| RELIEF | Vendor Bills / Cash Purchases |
| QAP | EWT Entries → Payee / ATC |
| SAWT | 2307 Received → Receipts → Source Documents |
| 1601EQ | EWT Entries → Period Aggregation |
| CAS Books | Posted Journal Entries → Source Documents |

**Principle:** Every compliance figure must be explainable.

---

## PRINCIPLE 15 — AUDIT TRAIL IS NON-NEGOTIABLE

PXL requires three levels of audit:

### Record-Level Audit
- `created_by`
- `updated_by`
- `deleted_by`

### Field-Level Audit
- `old_value`
- `new_value`
- field name, table name, changed_by, changed_at

### Event-Level Audit
- Login / logout
- Approval actions
- Posting
- Reversal
- Export
- Print
- Generated documents
- Period close / lock

**Principle:** Anything affecting accounting, compliance, or security must be auditable.

---

## PRINCIPLE 16 — IMPORT IS A FIRST-CLASS FEATURE

Bulk onboarding must be supported for:

- Customers
- Suppliers
- Items
- Services
- Chart of Accounts
- Branches
- Departments
- Cost Centers
- Opening Balances
- Fixed Assets
- Inventory Openings
- Payment Terms
- ATC Codes
- Warehouses

**Principle:** ERP onboarding must be practical and scalable.

---

## PRINCIPLE 17 — ASYNCHRONOUS BULK PROCESSING

Large operations must run asynchronously.

Examples:

- Bulk Imports
- DAT Generation
- SAWT Generation
- SLSP Generation
- RELIEF Generation
- Report Exports
- Depreciation Runs
- Inventory Revaluations

Users should submit jobs and monitor progress. The UI must provide live feedback via job status.

**Principle:** Long-running processes must never block the system.

---

## PRINCIPLE 18 — REPORTS ARE OUTPUTS, NOT SOURCES OF TRUTH

Sources of truth:

- Transactions
- Ledgers
- Compliance Entries
- Journal Entries

Reports are outputs derived from these sources. Reports must not create independent accounting truth.

**Principle:** One accounting truth.

---

## PRINCIPLE 19 — BLUEPRINT, TABLES, AND DOCUMENTATION MUST MATCH

The following must always agree:

- Blueprint
- Table Inventory
- Column Specifications
- Relationship Map
- Compliance Map
- Posting Design
- Audit Design
- Import/Export Design
- Security Design

**Principle:** Documentation inconsistency is an architecture defect.

---

## PRINCIPLE 20 — PH COMPLIANCE FIRST

PXL's primary competitive advantage is Philippine tax and regulatory compliance.

Prioritize these before non-essential ERP features:

| Form / Report | Description |
|---|---|
| VAT — 2550M / 2550Q | Monthly/Quarterly VAT Return |
| Percentage Tax — 2551Q | Quarterly Percentage Tax Return |
| EWT — 1601EQ | Quarterly Expanded Withholding Tax |
| FWT — 1601FQ | Quarterly Final Withholding Tax |
| Annual EWT — 1604E | Annual Alphalist of Payees |
| 2307 | Certificate of Creditable Tax Withheld |
| 2306 | Certificate of Final Tax Withheld |
| SAWT | Summary Alphalist of Withholding Tax |
| QAP | Quarterly Alphalist of Payees |
| SLSP | Summary List of Sales and Purchases |
| RELIEF | Reconciliation of Listings for Enforcement |
| Books of Accounts | BIR-required books |
| CAS | Computerized Accounting System audit requirements |

**Principle:** Compliance first.

---

## PRINCIPLE 21 — PERFORMANCE BY DESIGN

Performance must be considered during architecture design, not after.

Requirements:

- `company_id` on all operational tables (RLS hot path)
- Indexed foreign keys on all join columns
- Optimized RLS helper functions (`auth.user_company_ids()` must be indexed)
- Efficient joins — no unnecessary cross-joins
- Scalable audit architecture (insert-only, partitioned if needed)
- Async processing for high-volume operations (see Principle 17)

**Principle:** Performance is an architecture responsibility.

---

## PRINCIPLE 22 — DESIGN FOR SUPABASE

Architecture must respect Supabase/PostgreSQL platform realities:

- PostgreSQL constraints and triggers
- Row Level Security (RLS)
- Supabase Edge Functions (posting engine, compliance exports)
- Supabase Storage (attachments, generated documents, DAT files)
- Supabase Realtime (approval events, notifications, job status)
- `auth.users` integration (never duplicate user management)
- Migrations (one schema, forward-only)
- Service role safety (never expose to client)

**Principle:** Design for the actual platform.

---

## PRINCIPLE 23 — AVOID OVERENGINEERING

Do not build in Phase 1:

- Payroll
- POS
- CRM
- HRMS
- Manufacturing
- Government ERP
- PEZA ERP
- BOI ERP
- Foreign Entity ERP
- Multi-currency / FX revaluation
- Budget approval workflows
- Project costing
- Inter-company transactions

**Principle:** Stay focused. Build the core well before expanding.

---

## PRINCIPLE 24 — NO FINAL WITHOUT REVIEW

Nothing is final until:

- Open decisions are resolved
- Blueprint is aligned with tables
- Tables are aligned with columns
- Relationships are complete and consistent
- Posting is mapped for every transaction type
- Compliance is mapped to source fields
- Audit trail is mapped
- RLS is designed for every table
- UI visibility drivers are mapped to configuration

**Principle:** Slow review now prevents expensive redesign later.

---

## FINAL RULE

Whenever Claude, Codex, Lovable, ChatGPT, Cursor, or any future developer works on PXL ERP:

**Read this document first.**

Every design decision must be validated against these principles before implementation begins.

Any proposal that conflicts with these principles must either:

1. Justify the exception explicitly, or
2. Be revised to align with these principles.

There are no silent exceptions.
