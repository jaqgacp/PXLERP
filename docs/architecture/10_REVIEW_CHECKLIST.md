# PXL ERP — Pre-Implementation Review Checklist
**Version:** 1.0 — Blueprint Locked  
**Status:** For CPA and Developer Review  
**Sign-off Required Before:** SQL migration authoring begins

---

## HOW TO USE THIS CHECKLIST

Each item requires explicit sign-off from the responsible party before proceeding to the SQL migration phase. Mark each item:
- `[ ]` Not reviewed
- `[x]` Reviewed and approved
- `[!]` Reviewed — change required (note in Comments column)
- `[N/A]` Not applicable

---

## SECTION 1: Architecture Fundamentals

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 1.1 | Multi-tenant shared schema design confirmed (not schema-per-tenant) | DB Architect | [ ] | |
| 1.2 | RLS via `company_id` on all operational tables confirmed | DB Architect | [ ] | |
| 1.3 | UUID primary keys on all tables confirmed | DB Architect | [ ] | |
| 1.4 | `numeric(18,4)` for all monetary amounts confirmed | CPA Lead | [ ] | |
| 1.5 | `numeric(10,6)` for all rates and percentages confirmed | CPA Lead | [ ] | |
| 1.6 | `timestamptz` for all timestamps confirmed | DB Architect | [ ] | |
| 1.7 | Soft delete (`deleted_at`, `deleted_by`) on all master data confirmed | DB Architect | [ ] | |
| 1.8 | No hard deletes on any posted transaction table confirmed | CPA Lead | [ ] | |
| 1.9 | Functional currency = PHP for Phase 1 confirmed (OD-03) | CPA Lead | [ ] | |

---

## SECTION 2: Company Hierarchy

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 2.1 | Four dimension levels confirmed: company → branch → department → cost_center | Business Lead | [ ] | |
| 2.2 | Every transaction carries all four dimension FKs confirmed | DB Architect | [ ] | |
| 2.3 | GL balances tracked per account + period + branch confirmed (OD-06) | CPA Lead | [ ] | |

---

## SECTION 3: Chart of Accounts

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 3.1 | Account type hierarchy (Asset, Liability, Equity, Revenue, Expense, Contra) confirmed | CPA Lead | [ ] | |
| 3.2 | Normal balance side per account type defined | CPA Lead | [ ] | |
| 3.3 | Parent-child account hierarchy (self-referencing) confirmed | CPA Lead | [ ] | |
| 3.4 | Account used as control accounts (AR, AP, VAT, EWT) defined in `system_account_config` | CPA Lead | [ ] | |
| 3.5 | System-seeded account types and default COA template reviewed | CPA Lead | [ ] | |

---

## SECTION 4: Tax Compliance

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 4.1 | VAT types captured: OUTPUT, INPUT, ZERO_RATED, EXEMPT, GOVERNMENT, INPUT_DEFERRED, CAPITAL_GOODS | CPA Lead | [ ] | |
| 4.2 | `vat_entries` table design reviewed — one row per taxable line | CPA Lead | [ ] | |
| 4.3 | `vat_summary_period` aggregation logic reviewed | CPA Lead | [ ] | |
| 4.4 | EWT ATC code master list reviewed and confirmed complete for Phase 1 | CPA Lead | [ ] | |
| 4.5 | `ewt_entries` — one row per (line × ATC code) confirmed | CPA Lead | [ ] | |
| 4.6 | 2307 issued: per (supplier, ATC, quarter) certificate confirmed | CPA Lead | [ ] | |
| 4.7 | 2307 received: per (customer, ATC, quarter) confirmed | CPA Lead | [ ] | |
| 4.8 | 2306 (final withholding) separate from 2307 confirmed | CPA Lead | [ ] | |
| 4.9 | QAP monthly breakdown (M1, M2, M3) per (payee, ATC) confirmed | CPA Lead | [ ] | |
| 4.10 | SLSP — buyer TIN required on sales invoices (validation rule) confirmed | CPA Lead | [ ] | |
| 4.11 | RELIEF — seller TIN required on vendor bills (validation rule) confirmed | CPA Lead | [ ] | |
| 4.12 | `payee_tin` denormalized on `ewt_entries` (snapshot at time of transaction) confirmed | CPA Lead | [ ] | |

---

## SECTION 5: Document Numbering & ATP

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 5.1 | `number_series` with `SELECT FOR UPDATE` for race-condition prevention confirmed | DB Architect | [ ] | |
| 5.2 | ATP tracking: `number_series_atp` + `atp_usage_logs` tables confirmed | CPA Lead | [ ] | |
| 5.3 | Gap detection for sequential numbering (CAS requirement) confirmed | DB Architect | [ ] | |
| 5.4 | All BIR-reportable document types have their own number series confirmed | CPA Lead | [ ] | |
| 5.5 | Void does NOT reuse voided document number confirmed | CPA Lead | [ ] | |

---

## SECTION 6: Posting Engine

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 6.1 | Posting rule sets defined for all transaction types | CPA Lead | [ ] | |
| 6.2 | `system_account_config` keys defined for all semantic accounts | CPA Lead | [ ] | |
| 6.3 | Journal entry balance check (`SUM(DR) = SUM(CR)`) before commit confirmed | DB Architect | [ ] | |
| 6.4 | Fiscal period open check before posting confirmed | DB Architect | [ ] | |
| 6.5 | GL balance upsert strategy confirmed (OD-02 resolved) | DB Architect | [ ] | |
| 6.6 | Subsidiary ledger update within same posting transaction confirmed | DB Architect | [ ] | |
| 6.7 | Reversal creates mirror journal entry with opposite DR/CR confirmed | CPA Lead | [ ] | |
| 6.8 | Recurring journal generation logic reviewed | CPA Lead | [ ] | |
| 6.9 | Posting engine implemented as Supabase Edge Function (not DB function) confirmed | DB Architect | [ ] | |

---

## SECTION 7: Inventory

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 7.1 | FIFO costing method for Phase 1 confirmed (OD-05) | CPA Lead | [ ] | |
| 7.2 | `inventory_cost_layers` — one layer per goods receipt line confirmed | CPA Lead | [ ] | |
| 7.3 | `inventory_cost_layer_consumption` tracks FIFO depletion confirmed | DB Architect | [ ] | |
| 7.4 | Inventory movement creates journal entry via posting engine confirmed | CPA Lead | [ ] | |
| 7.5 | Physical count / variance journal entry flow reviewed | CPA Lead | [ ] | |

---

## SECTION 8: Fixed Assets

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 8.1 | Depreciation methods to support in Phase 1: SL, DB, SYD | CPA Lead | [ ] | |
| 8.2 | Depreciation schedule pre-computed at acquisition confirmed | CPA Lead | [ ] | |
| 8.3 | Monthly depreciation run → auto journal entry confirmed | DB Architect | [ ] | |
| 8.4 | Asset disposal: gain/loss computation and JE confirmed | CPA Lead | [ ] | |
| 8.5 | Accumulated depreciation account per asset category configured | CPA Lead | [ ] | |

---

## SECTION 9: Approval Workflow

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 9.1 | Approval matrix types: SEQUENTIAL, PARALLEL, ANY_ONE confirmed | Business Lead | [ ] | |
| 9.2 | Amount threshold triggers in approval matrix confirmed | Business Lead | [ ] | |
| 9.3 | Rejection returns document to DRAFT (not CANCELLED) confirmed | Business Lead | [ ] | |
| 9.4 | Escalation rules design reviewed (OD-04) | Business Lead | [ ] | |
| 9.5 | Posting blocked until fully approved confirmed | DB Architect | [ ] | |
| 9.6 | Realtime notification on approval events confirmed | DB Architect | [ ] | |

---

## SECTION 10: Audit & CAS

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 10.1 | `audit_logs` insert-only (no update, no delete) confirmed | DB Architect | [ ] | |
| 10.2 | `field_change_history` trigger design reviewed | DB Architect | [ ] | |
| 10.3 | `document_void_register` immutable confirmed | CPA Lead | [ ] | |
| 10.4 | `dat_file_generation_logs` immutable with file hash confirmed | DB Architect | [ ] | |
| 10.5 | CAS accreditation number stored in `cas_registrations` confirmed | CPA Lead | [ ] | |
| 10.6 | Posted document immutability trigger reviewed | DB Architect | [ ] | |
| 10.7 | User activity log events enumerated and complete | Business Lead | [ ] | |

---

## SECTION 11: Security & RLS

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 11.1 | `auth.user_company_ids()` helper function approach confirmed | DB Architect | [ ] | |
| 11.2 | `auth.has_permission()` helper approach confirmed | DB Architect | [ ] | |
| 11.3 | Service role used by Edge Functions (never client-side) confirmed | DB Architect | [ ] | |
| 11.4 | Hard delete REVOKE'd on all app roles confirmed | DB Architect | [ ] | |
| 11.5 | System role list (11 roles) reviewed and sufficient for Phase 1 | Business Lead | [ ] | |
| 11.6 | Permission code naming convention (`module.resource.action`) confirmed | DB Architect | [ ] | |
| 11.7 | Realtime enabled only on approval and job tables confirmed | DB Architect | [ ] | |
| 11.8 | MFA required for COMPANY_ADMIN and CONTROLLER confirmed | Business Lead | [ ] | |

---

## SECTION 12: Import & Export

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 12.1 | Two-pass import (validate then import) confirmed | DB Architect | [ ] | |
| 12.2 | `import_batch_id` on all bulk-created records confirmed | DB Architect | [ ] | |
| 12.3 | Import rollback via soft delete (not hard delete) confirmed | DB Architect | [ ] | |
| 12.4 | Opening balance flow: `opening_balance_entries` → posted JE confirmed | CPA Lead | [ ] | |
| 12.5 | DAT file export types enumerated and sufficient for CAS filing | CPA Lead | [ ] | |

---

## SECTION 13: Open Decisions — Final Answers Required

All open decisions from Document 01 must be resolved before SQL migrations begin.

| OD # | Question | Decision | Owner | Status |
|---|---|---|---|---|
| OD-01 | PostgreSQL ENUM or text + CHECK for status fields? | Recommended: text + CHECK (migration flexibility) | DB Architect | [ ] |
| OD-02 | Materialized view for GL balance vs. running total column? | Recommended: `gl_balances` table with upsert on posting | DB Architect | [ ] |
| OD-03 | Multi-currency: functional currency always PHP for Phase 1? | Recommended: Yes — FX in Phase 2 | CPA Lead | [ ] |
| OD-04 | Approval matrix: parallel vs. sequential per document type? | Recommended: Both supported via `approval_type` column | Business Lead | [ ] |
| OD-05 | Inventory valuation: FIFO only for Phase 1? | Recommended: Yes — Weighted Average in Phase 2 | CPA Lead | [ ] |
| OD-06 | Opening balances: per account or per account/branch? | Recommended: Per account/branch for full branch P&L | CPA Lead | [ ] |
| OD-07 | Recurring journal frequency: daily/weekly/monthly only? | Recommended: Monthly + Quarterly + Annually for Phase 1 | CPA Lead | [ ] |

---

## SECTION 14: Scope Confirmation

| # | Item | Status |
|---|---|---|
| 14.1 | Payroll module — OUT OF SCOPE for Phase 1 | Confirmed |
| 14.2 | POS module — OUT OF SCOPE for Phase 1 | Confirmed |
| 14.3 | Multi-currency / FX revaluation — OUT OF SCOPE for Phase 1 | Confirmed |
| 14.4 | Weighted Average / Standard Cost inventory — OUT OF SCOPE for Phase 1 | Confirmed |
| 14.5 | HR module — OUT OF SCOPE for Phase 1 | Confirmed |
| 14.6 | Loan / Amortization module — OUT OF SCOPE for Phase 1 | Confirmed |
| 14.7 | Inter-company transactions — OUT OF SCOPE for Phase 1 | Confirmed |

---

## SIGN-OFF BLOCK

| Role | Name | Signature | Date |
|---|---|---|---|
| CPA Lead / Senior PH Accountant | | | |
| DB Architect / Supabase Expert | | | |
| Business Lead / Product Owner | | | |
| Project Lead | | | |

---

**Once all items in Sections 1–13 are marked `[x]` or `[N/A]`, and all Open Decisions in Section 13 are resolved, SQL migration authoring may begin.**

*Next step after sign-off: `11_SQL_MIGRATIONS.md` — create all Supabase migration files in order.*
