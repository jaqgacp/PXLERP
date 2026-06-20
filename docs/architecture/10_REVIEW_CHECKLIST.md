# PXL ERP — Pre-Implementation Review Checklist
**Version:** 3.1 — Normalization Pass
**Status:** v3.1 — Normalization In Progress — Not Yet Migration-Approved
**Sign-off Required Before:** SQL migration authoring begins

---

## v3 Architecture Review Changes Applied (Round 1)

- Added Section 26: Chart of Accounts FS Mapping (v3)
- Added Section 27: account_types Expansion (v3)
- Added Section 28: vat_direction / vat_classification Split on Line Tables (v3)
- Added Section 29: Posting Engine — versioning and system_account_config completeness (v3)
- Added Section 30: Income Tax Computation Support Tables (v3)
- Updated sign-off block to reference Sections 1–30
- Updated Section 3 (COA) to include v3 checklist items
- Updated Section 4 (Tax Compliance) to include vat_classification items

## v3 Architecture Review Changes Applied (Enhancement Round — Accounting Schedules)

- Added Section 35: Amortization Schedule System (4 tables, 4-table traceability pattern)
- Added Section 36: Revenue Recognition Schedule System (4 tables, same pattern)
- Added Section 37: Auto Reversal System (1 run table + columns on journal_entries)
- Updated sign-off block to reference Sections 1–37
- Accrual Schedules explicitly documented as NOT added (Principle 23 — use recurring templates instead)

## v3 Architecture Review Changes Applied (Round 2 — Structural Fixes)

- Added Section 31: Party Classification Split (customers/suppliers.vat_status split into vat_registration_status + party_special_class)
- Added Section 32: Income Tax Table Overlap Resolution (itr_working_papers renamed, mcit_computations and nolco_schedules removed)
- Added Section 33: Doc 03 Coverage Gap — Cross-Reference Index resolution
- Added Section 34: COA Mapping Architecture decision (embedded fields only, Phase 1)
- Updated sign-off block to reference Sections 1–34
- Status corrected: "v3 In Review — Not Yet Approved for Database Freeze" (was prematurely "Gaps Resolved")

## v3 Cross-Document Consistency Validation

- All gaps identified in v3 Round 1 and Round 2 reviews are now tracked as checklist items in Sections 26–34
- Open Decisions from v3 review are listed in each document's respective "v3 Remaining Open Decisions" section
- No items marked [x] in this checklist until all document owners perform their review; [!] items in v3 sections flag previously-resolved gaps

---

## Changes Applied (v1 → v2)

- Added Section 15: Notifications checklist
- Added Section 16: Document Templates & Generated Output checklist
- Added Section 17: Budget Tables checklist
- Added Section 18: Period Close Process checklist
- Added Section 19: Party Duplicate Management checklist
- Added Section 20: Cash Sales & Cash Purchases design confirmation checklist
- Added OD-08 through OD-20 to Section 13 Open Decisions
- Updated Section 4: Tax Compliance — aligned with `vat_direction` + `vat_classification` v2 column naming
- Updated Section 12: Import & Export — expanded to include Setup and Master Data import types
- Updated Section 10: Audit & CAS — added `system_alerts` checklist item
- Updated Section 11: Security & RLS — added notification permissions, `system_alerts` RLS
- All resolved Open Decisions (OD-01 through OD-08) marked confirmed

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
| 1.10 | `document_no` (not `document_number`) as standard column name confirmed | DB Architect | [ ] | |
| 1.11 | `document_date` (not `invoice_date`, `bill_date`, `entry_date`) as standard date column confirmed | DB Architect | [ ] | |
| 1.12 | `tin` (not `bir_tin`) on all master tables confirmed | DB Architect | [ ] | |

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
| 3.1 | Account type hierarchy (Asset, Liability, Equity, Revenue, Cost of Sales, Expense, Other Income, Other Expense, Contra variants) confirmed — **v3: expanded from v2** | CPA Lead | [!] | v3 expansion in Section 27 |
| 3.2 | Normal balance side per account type defined | CPA Lead | [ ] | |
| 3.3 | Parent-child account hierarchy (self-referencing) confirmed | CPA Lead | [ ] | |
| 3.4 | Control accounts (AR, AP, VAT, EWT, PT, FWT, Income Tax) defined BOTH in `system_account_config` AND tagged via `control_account_type` on COA — **v3: COA must carry the tag** | CPA Lead | [!] | v3 gap resolved |
| 3.5 | System-seeded account types and default COA template reviewed with full v3 columns | CPA Lead | [ ] | |
| 3.6 | FS mapping strategy confirmed: `fs_section` + `fs_group` + `fs_sort_order` drives FS generation — no hardcoded account ranges — **v3 addition** | CPA Lead / ERP Architect | [!] | v3 gap resolved |
| 3.7 | Cash flow classification per account confirmed: `cash_flow_category` and `is_cash_equivalent` reviewed | CPA Lead | [ ] | |

---

## SECTION 4: Tax Compliance

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 4.1 | VAT classification split: `vat_direction` (OUTPUT/INPUT) + `vat_classification` (VATABLE/ZERO_RATED/EXEMPT/GOVERNMENT/CAPITAL_GOODS/SERVICES) confirmed | CPA Lead | [ ] | |
| 4.2 | `vat_entries` table design reviewed — one row per taxable line, `net_amount` column (not `base_amount`) | CPA Lead | [ ] | |
| 4.3 | `vat_period_summaries` aggregation logic reviewed (not `vat_summary_period`) | CPA Lead | [ ] | |
| 4.4 | EWT ATC code master list reviewed and confirmed complete for Phase 1 | CPA Lead | [ ] | |
| 4.5 | `ewt_entries` — one row per (line × ATC code), column `ewt_base_amount` (not `tax_base_amount`) confirmed | CPA Lead | [ ] | |
| 4.6 | 2307 issued: per (supplier, ATC, quarter) certificate confirmed; `is_issued`, `issued_at`, `generated_document_id` columns added | CPA Lead | [ ] | |
| 4.7 | 2307 received: per (customer, ATC, quarter) confirmed | CPA Lead | [ ] | |
| 4.8 | 2306 (final withholding) separate from 2307 confirmed — `certificates_2306_issued` table — **v3.1: renamed** | CPA Lead | [!] | BLOCKER 3 resolved |
| 4.9 | QAP monthly breakdown (M1, M2, M3) per (payee_tin, atc_code) confirmed using `ewt_entries` snapshots | CPA Lead | [ ] | |
| 4.10 | SLSP — buyer TIN required on sales invoices (validation rule at posting) confirmed | CPA Lead | [ ] | |
| 4.11 | RELIEF — seller TIN required on vendor bills (validation rule at posting) confirmed | CPA Lead | [ ] | |
| 4.12 | `payee_tin` denormalized on `ewt_entries` (snapshot at time of transaction, never updated) confirmed — **v3.1: column renamed from `supplier_tin`** | CPA Lead | [!] | BLOCKER 4 resolved |
| 4.13 | `customer_tin` and `supplier_tin` denormalized on `vat_entries` (snapshot) confirmed | CPA Lead | [ ] | |
| 4.14 | Cash Sales contribute to Output VAT, SLSP, and Cash Sales Book confirmed | CPA Lead | [ ] | |
| 4.15 | Cash Purchases contribute to Input VAT, RELIEF, and Cash Purchases Book confirmed | CPA Lead | [ ] | |
| 4.16 | EWT on Cash Purchases captured at time of purchase (not at payment) confirmed | CPA Lead | [ ] | |

---

## SECTION 5: Document Numbering & ATP

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 5.1 | `number_series` with `SELECT FOR UPDATE` for race-condition prevention confirmed | DB Architect | [ ] | |
| 5.2 | ATP tracking: `number_series_atp` + `atp_usage_logs` tables confirmed | CPA Lead | [ ] | |
| 5.3 | Gap detection for sequential numbering (CAS requirement): nightly pg_cron → `system_alerts` confirmed | DB Architect | [ ] | |
| 5.4 | All BIR-reportable document types have their own number series confirmed; `cash_sale` and `cash_purchase` added | CPA Lead | [ ] | |
| 5.5 | Void does NOT reuse voided document number confirmed (`atp_usage_logs.is_voided = true`) | CPA Lead | [ ] | |

---

## SECTION 6: Posting Engine

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 6.1 | Posting rule sets defined for all transaction types including `cash_sale` and `cash_purchase` | CPA Lead | [ ] | |
| 6.2 | `system_account_config` keys defined for all semantic accounts | CPA Lead | [ ] | |
| 6.3 | Journal entry balance check (`SUM(DR) = SUM(CR)`) before commit confirmed | DB Architect | [ ] | |
| 6.4 | Fiscal period open check before posting confirmed | DB Architect | [ ] | |
| 6.5 | GL balance upsert strategy confirmed (OD-02 resolved: `gl_balances` table with INSERT ... ON CONFLICT DO UPDATE) | DB Architect | [ ] | |
| 6.6 | Subsidiary ledger update within same posting transaction confirmed | DB Architect | [ ] | |
| 6.7 | Cash Sales do NOT create `subsidiary_ledger_entries` (no AR) confirmed | CPA Lead | [ ] | |
| 6.8 | Cash Purchases do NOT create `subsidiary_ledger_entries` (no AP) confirmed | CPA Lead | [ ] | |
| 6.9 | Reversal creates mirror journal entry with opposite DR/CR confirmed | CPA Lead | [ ] | |
| 6.10 | Recurring journal generation logic reviewed (MONTHLY, QUARTERLY, ANNUALLY — OD-07) | CPA Lead | [ ] | |
| 6.11 | Posting engine implemented as Supabase Edge Function (service role, not DB function) confirmed | DB Architect | [ ] | |
| 6.12 | Notification dispatch after posting is async (fire-and-forget, does not block transaction) confirmed | DB Architect | [ ] | |

---

## SECTION 7: Inventory

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 7.1 | FIFO costing method for Phase 1 confirmed (OD-05) | CPA Lead | [ ] | |
| 7.2 | `inventory_cost_layers` — one layer per goods receipt line confirmed | CPA Lead | [ ] | |
| 7.3 | `inventory_cost_layer_consumption` tracks FIFO depletion confirmed | DB Architect | [ ] | |
| 7.4 | Inventory movement creates journal entry via posting engine confirmed | CPA Lead | [ ] | |
| 7.5 | Physical count / variance journal entry flow reviewed | CPA Lead | [ ] | |
| 7.6 | Cash Sales reduce inventory (same as Sales Invoice) confirmed | CPA Lead | [ ] | |
| 7.7 | Cash Purchases increase inventory (same as Vendor Bill for goods) confirmed | CPA Lead | [ ] | |

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
| 9.4 | Escalation: `escalate_after_hours` + `escalate_to_user_id` on `approval_matrix_steps` confirmed | Business Lead | [ ] | |
| 9.5 | Posting blocked until fully approved confirmed | DB Architect | [ ] | |
| 9.6 | Realtime notification on approval events confirmed (`approval_requests` + `approval_actions` on Realtime) | DB Architect | [ ] | |

---

## SECTION 10: Audit & CAS

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 10.1 | `audit_logs` insert-only (no update, no delete) confirmed | DB Architect | [ ] | |
| 10.2 | `field_change_history` trigger design reviewed — excludes `gl_balances`, `audit_logs`, delivery logs | DB Architect | [ ] | |
| 10.3 | `document_void_register` immutable confirmed | CPA Lead | [ ] | |
| 10.4 | `dat_file_generation_logs` immutable with SHA-256 file hash confirmed | DB Architect | [ ] | |
| 10.5 | `cas_registrations` stores CAS accreditation per company confirmed | CPA Lead | [ ] | |
| 10.6 | Posted document immutability trigger reviewed (`status IN ('POSTED','VOIDED','REVERSED')`) | DB Architect | [ ] | |
| 10.7 | User activity log events enumerated and complete | Business Lead | [ ] | |
| 10.8 | `system_alerts` table defined for ATP gap alerts and other automated system alerts | DB Architect | [ ] | |
| 10.9 | Nightly pg_cron job for ATP gap detection → `system_alerts` confirmed | DB Architect | [ ] | |
| 10.10 | New audit event types for v2 added: `CASH_SALE_POSTED`, `CASH_PURCHASE_POSTED`, `PERIOD_CLOSE_*`, `PARTY_MERGED`, `NOTIFICATION_SENT` | Business Lead | [ ] | |

---

## SECTION 11: Security & RLS

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 11.1 | `auth.user_company_ids()` helper function approach confirmed; index on `user_company_access(user_id, is_active, revoked_at)` | DB Architect | [ ] | |
| 11.2 | `auth.has_permission()` helper approach confirmed | DB Architect | [ ] | |
| 11.3 | Service role used by Edge Functions (never client-side) confirmed | DB Architect | [ ] | |
| 11.4 | Hard delete REVOKE'd on all app roles confirmed | DB Architect | [ ] | |
| 11.5 | System role list (11 roles) reviewed and sufficient for Phase 1 | Business Lead | [ ] | |
| 11.6 | Permission code naming convention (`module.resource.action`) confirmed | DB Architect | [ ] | |
| 11.7 | Realtime enabled on: `approval_requests`, `approval_actions`, `export_jobs`, `import_batches`, `notifications`, `system_alerts` | DB Architect | [ ] | |
| 11.8 | MFA required for COMPANY_ADMIN and CONTROLLER confirmed | Business Lead | [ ] | |
| 11.9 | `notifications` RLS: users see own notifications only; Company Admin sees all | DB Architect | [ ] | |
| 11.10 | `system_alerts` RLS: visible to COMPANY_ADMIN and CONTROLLER only | DB Architect | [ ] | |
| 11.11 | `profiles.first_name` + `profiles.last_name` (not `full_name`) confirmed; computed `full_name` expression documented | DB Architect | [ ] | |

---

## SECTION 12: Import & Export

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 12.1 | Two-pass import (validate then import) confirmed | DB Architect | [ ] | |
| 12.2 | `import_batch_id` on all bulk-created records confirmed (master data + transactional) | DB Architect | [ ] | |
| 12.3 | Import rollback via soft delete (not hard delete) confirmed; posted JEs excluded | DB Architect | [ ] | |
| 12.4 | Opening balance flow: `opening_balance_entries` → posted JE confirmed | CPA Lead | [ ] | |
| 12.5 | DAT file export types enumerated and sufficient for CAS filing | CPA Lead | [ ] | |
| 12.6 | Setup module import types confirmed: `payment_terms`, `atc_codes`, `tax_codes`, `warehouses`, `units_of_measure`, `approval_matrix` | Business Lead | [ ] | |
| 12.7 | Master data import types confirmed: `customers`, `suppliers`, `items`, `price_lists`, `bank_accounts` | Business Lead | [ ] | |
| 12.8 | `export_jobs` table name confirmed (not `export_batches`) | DB Architect | [ ] | |
| 12.9 | `attachment_versions` table confirmed for re-upload history | DB Architect | [ ] | |
| 12.10 | `file_hash_sha256` on `attachments` for integrity verification confirmed | DB Architect | [ ] | |

---

## SECTION 13: Open Decisions — Final Answers Required

All open decisions must be resolved before SQL migrations begin.

| OD # | Question | Recommendation | Owner | Status |
|---|---|---|---|---|
| OD-01 | PostgreSQL ENUM or text + CHECK for status fields? | **text + CHECK** — migration flexibility | DB Architect | [x] Resolved |
| OD-02 | Materialized view for GL balance vs. running total column? | **`gl_balances` table** with upsert on posting | DB Architect | [x] Resolved |
| OD-03 | Multi-currency: functional currency always PHP for Phase 1? | **Yes** — FX in Phase 2 | CPA Lead | [x] Resolved |
| OD-04 | Approval matrix: parallel vs. sequential per document type? | **Both** supported via `approval_type` column | Business Lead | [x] Resolved |
| OD-05 | Inventory valuation: FIFO only for Phase 1? | **Yes** — Weighted Average in Phase 2 | CPA Lead | [x] Resolved |
| OD-06 | Opening balances: per account or per account/branch? | **Per account/branch** for full branch P&L | CPA Lead | [x] Resolved |
| OD-07 | Recurring journal frequency: daily/weekly/monthly only? | **Monthly + Quarterly + Annually** for Phase 1 | CPA Lead | [x] Resolved |
| OD-08 | Cash Sales / Cash Purchases: separate headers or shortcuts? | **Separate transaction headers** — no AR/AP created | CPA Lead | [x] Resolved |
| OD-09 | `document_relationships` link notification events to source docs? | Phase 2 consideration | DB Architect | [ ] |
| OD-10 | `generated_documents` link to `export_jobs` when PDF produced via export? | Decide before Edge Function implementation | DB Architect | [ ] |
| OD-11 | `slsp_entries` and `relief_entries`: materialized tables or computed at export? | **Computed at export time** via Edge Function; no table for Phase 1 | CPA Lead | [ ] |
| OD-12 | `compliance_report_runs` track BIR submission status? | Phase 2 — Phase 1 is generation only | CPA Lead | [ ] |
| OD-13 | Does posting engine write `vat_entries` and `ewt_entries`, or does the document save step? | **Document save step** writes them; posting engine reads them | DB Architect | [ ] |
| OD-14 | Recurring journal template lines: fixed amounts only or percentage of account balance? | **Fixed amounts only** for Phase 1 | CPA Lead | [ ] |
| OD-15 | `system_alerts` on Supabase Realtime? | **Yes** — add to Realtime list | DB Architect | [ ] |
| OD-16 | Partition `user_activity_logs` by month? | **Phase 2** — single table with index for Phase 1 | DB Architect | [ ] |
| OD-17 | Attachment storage: single shared bucket or per-company bucket? | **Single shared bucket** with `company_id/entity_type/entity_id/` path | DB Architect | [ ] |
| OD-18 | Save column mapping template per import_type? | **Phase 2** — Phase 1: per-batch column_mapping in jsonb | DB Architect | [ ] |
| OD-19 | `system_alerts` RLS: restrict to COMPANY_ADMIN and CONTROLLER? | **Yes** | DB Architect | [ ] |
| OD-20 | `notifications` RLS: user sees own notifications only? | **Yes** | DB Architect | [ ] |

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
| 14.8 | Report definitions / Dashboard widgets / KPI tables — OUT OF SCOPE for Phase 1 | Confirmed |
| 14.9 | Budget approval workflow — OUT OF SCOPE for Phase 1 (budget is entry-only, no workflow) | Confirmed |
| 14.10 | Project budgets — OUT OF SCOPE for Phase 1 | Confirmed |
| 14.11 | `party_identity_links` and `customer_supplier_links` — OUT OF SCOPE for Phase 1 (use `duplicate_tin_flags` + `party_merge_logs` only) | Confirmed |

---

## SECTION 15: Notifications

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 15.1 | `notification_templates` table — one template per event_type per company confirmed | DB Architect | [ ] | |
| 15.2 | `notifications` table — one record per recipient per event confirmed | DB Architect | [ ] | |
| 15.3 | `notification_delivery_logs` — one record per delivery channel per notification confirmed | DB Architect | [ ] | |
| 15.4 | Delivery channels: `in_app` (Supabase Realtime) + `email` (Edge Function → SMTP) for Phase 1 | Business Lead | [ ] | |
| 15.5 | Notification dispatch is async fire-and-forget — failure does NOT roll back the triggering transaction confirmed | DB Architect | [ ] | |
| 15.6 | Realtime enabled on `notifications` table confirmed | DB Architect | [ ] | |
| 15.7 | RLS on `notifications`: user sees own records only; company admin sees all confirmed | DB Architect | [ ] | |

---

## SECTION 16: Document Templates & Generated Output

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 16.1 | `document_templates` table — one template per doc_type per company confirmed | Business Lead | [ ] | |
| 16.2 | Template format: HTML/Handlebars confirmed | DB Architect | [ ] | |
| 16.3 | `generated_documents` table — one record per generated PDF/file confirmed | DB Architect | [ ] | |
| 16.4 | `generated_document_versions` table — version history per generated document confirmed | DB Architect | [ ] | |
| 16.5 | `file_hash_sha256` on `generated_documents` for integrity verification confirmed | DB Architect | [ ] | |
| 16.6 | Generated documents stored in Supabase Storage; metadata row retained permanently after storage cleanup confirmed | DB Architect | [ ] | |
| 16.7 | `certificates_2307_issued.generated_document_id` → FK to `generated_documents` confirmed | CPA Lead | [ ] | |

---

## SECTION 17: Budget Tables

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 17.1 | `budgets` table: header per company per fiscal year confirmed | Business Lead | [ ] | |
| 17.2 | `budget_lines` table: one line per account per period per branch confirmed | CPA Lead | [ ] | |
| 17.3 | No budget approval workflow for Phase 1 confirmed | Business Lead | [ ] | |
| 17.4 | Budget vs. actual variance computed at report time (no persistent variance table) confirmed | CPA Lead | [ ] | |
| 17.5 | `budget_version` integer column on `budgets` for version tracking (no separate `budget_versions` table for Phase 1) confirmed | DB Architect | [ ] | |

---

## SECTION 18: Period Close Process

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 18.1 | `period_close_checklists` table: one per company per fiscal period confirmed | CPA Lead | [ ] | |
| 18.2 | `period_close_tasks` table: one per checklist item (seeded from 10 standard tasks) confirmed | CPA Lead | [ ] | |
| 18.3 | 10 standard period close tasks seeded per period reviewed and approved by CPA Lead | CPA Lead | [ ] | |
| 18.4 | `subledger_close_certifications` table: certifying AR/AP/Inventory subledgers agree to GL confirmed | CPA Lead | [ ] | |
| 18.5 | Period cannot be LOCKED until all mandatory tasks are COMPLETED or WAIVED confirmed | CPA Lead | [ ] | |
| 18.6 | `WAIVED` status tasks require a waive_reason and waived_by to be populated confirmed | CPA Lead | [ ] | |
| 18.7 | Period close does NOT automatically lock period — controller manually locks via `fiscal_locks` after checklist complete confirmed | DB Architect | [ ] | |

---

## SECTION 19: Party Duplicate Management

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 19.1 | `duplicate_tin_flags` raised as WARNING (not block) when TIN matches existing customer or supplier record confirmed | CPA Lead | [ ] | |
| 19.2 | System allows same TIN on both a customer and supplier record (related entities) confirmed | CPA Lead | [ ] | |
| 19.3 | `party_merge_logs` records every merge operation: retired record → canonical record confirmed | DB Architect | [ ] | |
| 19.4 | After merge, retired record is soft-deleted; all historical transactions remain linked to original ID (not re-linked) confirmed | CPA Lead | [ ] | |
| 19.5 | New transactions after merge must use canonical record ID confirmed | DB Architect | [ ] | |

---

## SECTION 20: Cash Sales & Cash Purchases Design

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 20.1 | Cash Sales are separate transaction headers (`cash_sales` + `cash_sale_lines`) — NOT shortcuts to Invoice + Receipt confirmed (OD-08) | CPA Lead | [ ] | |
| 20.2 | Cash Purchases are separate transaction headers (`cash_purchases` + `cash_purchase_lines`) — NOT shortcuts to Vendor Bill + Payment Voucher confirmed | CPA Lead | [ ] | |
| 20.3 | Cash Sales do NOT create AR entries in `subsidiary_ledger_entries` confirmed | CPA Lead | [ ] | |
| 20.4 | Cash Purchases do NOT create AP entries in `subsidiary_ledger_entries` confirmed | CPA Lead | [ ] | |
| 20.5 | Cash Sales posting: DR Cash / CR Revenue + CR Output VAT confirmed | CPA Lead | [ ] | |
| 20.6 | Cash Purchases posting confirmed: DR Inventory/Expense (gross_amount) + DR Input VAT / CR Cash (net_payable_amount = gross + vat - ewt) + **CR EWT Payable** (liability) — **v3.1: DR corrected to CR** | CPA Lead | [!] | BLOCKER 2 resolved |
| 20.7 | Cash Sales reduce inventory for stocked items (same as Sales Invoice) confirmed | CPA Lead | [ ] | |
| 20.8 | Cash Purchases increase inventory for goods items (same as Vendor Bill) confirmed | CPA Lead | [ ] | |
| 20.9 | EWT on Cash Purchases captured at `cash_purchase_lines` level (not deferred to a payment voucher) confirmed | CPA Lead | [ ] | |
| 20.10 | Cash Sales and Cash Purchases have their own `number_series` document type confirmed | CPA Lead | [ ] | |
| 20.11 | Cash Sales official receipts use OR series; Cash Purchases use their own series confirmed | CPA Lead | [ ] | |
| 20.12 | Both Cash Sales and Cash Purchases included in SLSP/RELIEF and VAT returns confirmed | CPA Lead | [ ] | |

---

---

## SECTION 21: Compliance Profile & Feature Settings

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 21.1 | `company_compliance_profiles` table designed with effective_from/effective_to for version history confirmed (Principle 11) | DB Architect | [ ] | |
| 21.2 | `taxpayer_type` on compliance profile drives VAT vs Percentage Tax behavior confirmed (Principle 6) | CPA Lead | [ ] | |
| 21.3 | `income_tax_regime` on compliance profile drives ITR form code (1701Q/1701 for individual; 1702Q/1702RT for corporate) confirmed (Principle 3 Driver 2) | CPA Lead | [ ] | |
| 21.4 | `legal_type` on compliance profile drives registration requirements confirmed (Principle 3 Driver 3) | CPA Lead | [ ] | |
| 21.5 | Compliance profile lookup at posting time uses effective_from/effective_to range confirmed (Principle 11) | DB Architect | [ ] | |
| 21.6 | `company_feature_settings` has exactly one row per company (UNIQUE constraint) confirmed (Principle 7) | DB Architect | [ ] | |
| 21.7 | Feature settings control UI visibility ONLY — no effect on accounting or posting confirmed (Principle 7) | CPA Lead | [ ] | |
| 21.8 | Compliance profile changes generate `COMPLIANCE_PROFILE_CHANGED` audit event (Principle 15) | DB Architect | [ ] | |

---

## SECTION 22: Percentage Tax (NON-VAT Companies)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 22.1 | `percentage_tax_entries` created by posting engine only — not by application layer confirmed | DB Architect | [ ] | |
| 22.2 | Posting engine checks `company_compliance_profiles.taxpayer_type` at post time confirmed | DB Architect | [ ] | |
| 22.3 | `percentage_tax_period_summaries` — one row per company per fiscal period (UNIQUE constraint) confirmed | DB Architect | [ ] | |
| 22.4 | 2551Q links to `percentage_tax_period_summaries` confirmed | CPA Lead | [ ] | |
| 22.5 | VAT Dashboard only shows for VAT companies; PT Dashboard only shows for NON-VAT companies (Principle 1) confirmed | Business Lead | [ ] | |
| 22.6 | Companies switching from NON-VAT to VAT use effective_from — historical PT entries unchanged (Principle 11) confirmed | CPA Lead | [ ] | |

---

## SECTION 23: FWT / 1601FQ

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 23.1 | `fwt_entries` for WF-series ATC codes only — separate from EWT (WC/WI series) confirmed | CPA Lead | [ ] | |
| 23.2 | `fwt_remittances_1601fq` separate table — separate BIR form from 1601EQ confirmed | CPA Lead | [ ] | |
| 23.3 | `certificates_2306_issued` generated per payee per quarter from `fwt_entries` confirmed — **v3.1: renamed** from `certificates_2306` | CPA Lead | [!] | BLOCKER 3 resolved |
| 23.4 | WF-series ATC codes in `atc_codes` confirmed | CPA Lead | [ ] | |

---

## SECTION 24: Income Tax Regime & ITR Filing

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 24.1 | `income_tax_regime` on `company_compliance_profiles` determines ITR form code confirmed | CPA Lead | [ ] | |
| 24.2 | `income_tax_return_filings.form_code` validated against income_tax_regime (1701Q/1701 vs 1702Q/1702RT) confirmed | CPA Lead | [ ] | |
| 24.3 | MCIT Computation only applicable for corporate / OPC confirmed | CPA Lead | [ ] | |
| 24.4 | Income Tax Dashboard shows relevant ITR form per income_tax_regime (Principle 1) confirmed | Business Lead | [ ] | |

---

## SECTION 25: Customer & Supplier Broader Tax Classification

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 25.1 | `customers.vat_status` and `suppliers.vat_status` CHECK includes 'government', 'peza', 'boi', 'foreign_entity' confirmed (Principle 5) | CPA Lead | [ ] | |
| 25.2 | PXL does not target these entities as company clients (Principle 4) but supports transacting with them confirmed | CPA Lead | [ ] | |
| 25.3 | TIN snapshots at posting capture vat_status correctly for SLSP/RELIEF confirmed (Principle 10) | CPA Lead | [ ] | |

---

## SIGN-OFF BLOCK

| Role | Name | Signature | Date |
|---|---|---|---|
| CPA Lead / Senior PH Accountant | | | |
| DB Architect / Supabase Expert | | | |
| Business Lead / Product Owner | | | |
| Project Lead | | | |

---

---

## SECTION 26: Chart of Accounts — FS Mapping & Tax Classification (v3)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 26.1 | `chart_of_accounts.fs_section` — 10-value enum confirmed: current_assets, non_current_assets, current_liabilities, non_current_liabilities, equity, revenue, cost_of_sales, operating_expenses, other_income, other_expenses | CPA Lead | [!] | v3 gap resolved — was missing entirely |
| 26.2 | `chart_of_accounts.fs_group` — free-text sub-group label confirmed (e.g., 'cash_and_equivalents','trade_receivables') for grouping on FS | CPA Lead | [ ] | |
| 26.3 | `chart_of_accounts.fs_sort_order` — integer sort within fs_group confirmed | DB Architect | [ ] | |
| 26.4 | `chart_of_accounts.cash_flow_category` CHECK IN ('operating','investing','financing') — confirmed NULL for accounts not on direct cash flow | CPA Lead | [ ] | |
| 26.5 | `chart_of_accounts.control_account_type` — 9-value enum confirmed; app-layer posting prevention for control accounts confirmed for Phase 1 | DB Architect | [!] | v3 gap resolved — control accounts were only in system_account_config, not on COA itself |
| 26.6 | `chart_of_accounts.is_mcit_gross_income` — tagging convention confirmed with CPA: which revenue accounts form MCIT gross income base? | CPA Lead / Tax Consultant | [ ] | Requires explicit list of qualifying accounts |
| 26.7 | `chart_of_accounts.is_osd_gross_revenue` — tagging convention confirmed: which accounts form OSD 40% computation base? | CPA Lead / Tax Consultant | [ ] | |
| 26.8 | `chart_of_accounts.tax_deductibility` CHECK IN ('fully_deductible','partially_deductible','non_deductible','not_applicable') — reviewed by Tax Consultant | Tax Consultant | [ ] | |
| 26.9 | Default COA seed template reviewed and updated with fs_section, fs_group, fs_sort_order, cash_flow_category values for all seeded accounts | CPA Lead | [ ] | |

---

## SECTION 27: account_types Expansion (v3)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 27.1 | `account_types.code` expanded: added 'cost_of_sales','other_income','other_expense','contra_liability','contra_equity' — confirmed with CPA | CPA Lead | [!] | v3 gap resolved — P&L sub-sections were missing |
| 27.2 | `account_types.fs_category` expanded: 'cost_of_sales_section','other_income_expense_section' — confirmed maps to correct FS section | CPA Lead | [ ] | |
| 27.3 | All existing seeded accounts re-assigned to correct expanded account_type (cost_of_sales vs expense, other_income vs revenue, etc.) | CPA Lead | [ ] | |
| 27.4 | Normal balance side confirmed for each new account_type: cost_of_sales=debit, other_income=credit, other_expense=debit, contra_liability=debit, contra_equity=debit | CPA Lead | [ ] | |

---

## SECTION 28: vat_direction / vat_classification Split on Line Tables (v3)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 28.1 | `sales_invoice_lines.vat_direction` now CHECK IN ('output') only — confirmed; classification moved to `vat_classification` | CPA Lead | [!] | v3 gap resolved — was mixing direction+classification |
| 28.2 | `sales_invoice_lines.vat_classification` CHECK IN ('vatable','zero_rated','exempt','government') — confirmed complete for sales transactions | CPA Lead | [ ] | |
| 28.3 | `cash_sale_lines.vat_direction` and `vat_classification` — same pattern confirmed | CPA Lead | [!] | v3 gap resolved |
| 28.4 | `vendor_bill_lines.vat_direction` now CHECK IN ('input') only — confirmed | CPA Lead | [!] | v3 gap resolved |
| 28.5 | `vendor_bill_lines.vat_classification` CHECK IN ('vatable','zero_rated','exempt','capital_goods','services') — confirmed; 'capital_goods' triggers PHP 1M threshold check | CPA Lead / Tax Consultant | [ ] | |
| 28.6 | `cash_purchase_lines.vat_direction` and `vat_classification` — same pattern confirmed | CPA Lead | [!] | v3 gap resolved |
| 28.7 | Posting engine routing logic confirmed: capital_goods → INPUT_VAT_CAPITAL_GOODS; services → INPUT_VAT (or INPUT_VAT_DEFERRED); vatable → INPUT_VAT | DB Architect | [ ] | |
| 28.8 | `vat_entries` table `vat_classification` CHECK IN ('vatable','zero_rated','exempt','government') — confirmed consistent with sales line tables (capital_goods is purchase-only classification, not in vat_entries) | CPA Lead | [ ] | |

---

## SECTION 29: Posting Engine — Versioning & System Account Config (v3)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 29.1 | `posting_rule_sets.effective_from` and `effective_to` added — confirmed per Principle 11 | DB Architect | [!] | v3 gap resolved — Principle 11 violation fixed |
| 29.2 | Historical transaction posting uses rule set effective on `document_date` — confirmed in posting engine logic | DB Architect | [ ] | |
| 29.3 | `system_account_config` key `PERCENTAGE_TAX_PAYABLE` added — company setup wizard prompts for this when `taxpayer_type = 'non_vat'` | DB Architect | [!] | v3 gap resolved |
| 29.4 | `system_account_config` key `FWT_PAYABLE` added — required when company has FWT obligations in `filing_obligations` | DB Architect | [!] | v3 gap resolved |
| 29.5 | `system_account_config` key `INCOME_TAX_PAYABLE` added — required for quarterly/annual income tax posting | DB Architect | [!] | v3 gap resolved |
| 29.6 | Posting engine abort behavior confirmed: missing required `system_account_config` key causes abort with clear error message (not silent failure) | DB Architect | [ ] | |
| 29.7 | `company_compliance_profiles.filing_obligations` array drives which `system_account_config` keys are required at setup | CPA Lead | [ ] | |

---

## SECTION 30: Income Tax Computation Support (v3)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 30.1 | `income_tax_computation_lines` table design reviewed — on-demand population per ITR computation run, idempotent | CPA Lead / DB Architect | [ ] | |
| 30.2 | ITR form selection logic confirmed: income_tax_regime='corporate' → 1702Q/1702RT; 'individual' → 1701Q/1701; subject to MCIT flag | CPA Lead / Tax Consultant | [ ] | |
| 30.3 | MCIT computation: `is_mcit_gross_income = true` accounts on COA form gross income base; 2% × gross income vs regular tax; whichever is higher is the tax due | Tax Consultant | [ ] | |
| 30.4 | OSD computation: `is_osd_gross_revenue = true` accounts on COA form gross revenue base; 40% × gross revenue = deductible expenses under OSD | Tax Consultant | [ ] | |
| 30.5 | `nolco_tracking` reviewed: only applicable for itemized deduction taxpayers; OSD users cannot carry over losses | Tax Consultant | [ ] | |
| 30.6 | NOLCO 3-year carry-over enforcement: `applied_fy1_amount + applied_fy2_amount + applied_fy3_amount ≤ nolco_amount` constraint confirmed | CPA Lead | [ ] | |
| 30.7 | Quarterly income tax: `income_tax_computation_lines` used per quarter filing; annual computation uses same table with fiscal_year scope | CPA Lead | [ ] | |
| 30.8 | 2307 received from customers (certificates_2307_received) — confirmed as creditable tax reducing income_tax_payable | CPA Lead / Tax Consultant | [ ] | |
| 30.9 | RLS on `income_tax_computation_lines` and `nolco_tracking` reviewed per doc 09 v3 additions | DB Architect | [ ] | |

---

---

## SECTION 31: Party Classification Split (v3 Round 2)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 31.1 | `customers.vat_status` RENAMED to `vat_registration_status` CHECK IN ('vat','non_vat') — confirmed; 'government','peza','boi','foreign_entity' moved out | CPA Lead | [!] | v3 Round 2 resolved |
| 31.2 | `customers.party_special_class` NEW COLUMN NULL CHECK IN ('government','peza','boi','foreign_entity') — confirmed | CPA Lead / DB Architect | [!] | v3 Round 2 resolved |
| 31.3 | Same split applied to `suppliers` — confirmed | DB Architect | [!] | v3 Round 2 resolved |
| 31.4 | Transaction line tables (`sales_invoice_lines`, `cash_sale_lines`) — 'government' REMOVED from `vat_classification` CHECK — confirmed | DB Architect | [!] | v3 Round 2 resolved |
| 31.5 | `vat_entries.vat_classification = 'government'` DERIVED at posting from `party_special_class` — posting engine updated | DB Architect | [ ] | Needs implementation verification |
| 31.6 | PEZA and BOI party_special_class → zero-rated vat_classification routing rule confirmed | Tax Consultant / CPA Lead | [ ] | |
| 31.7 | `party.special_class.manage` permission added to RLS design (doc 09 v3 Round 2) — requires CONTROLLER_ROLE | DB Architect | [ ] | |
| 31.8 | `PARTY_SPECIAL_CLASS_CHANGED` audit event type added to doc 07 v3 Round 2 — confirmed | CPA Lead | [!] | v3 Round 2 resolved |

---

## SECTION 32: Income Tax Table Overlap Resolution (v3 Round 2)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 32.1 | `itr_working_papers` (#154) RENAMED to `itr_computation_runs` — confirmed in doc 02, doc 03, doc 04, doc 05 | DB Architect | [!] | v3 Round 2 resolved |
| 32.2 | `mcit_computations` (#156) REMOVED — MCIT now in `itr_computation_runs.mcit_amount` + `income_tax_computation_lines` (is_mcit_gross_income flag) | CPA Lead | [!] | v3 Round 2 resolved |
| 32.3 | `nolco_schedules` (#157) REMOVED — replaced by `nolco_tracking` in MODULE 30 | CPA Lead | [!] | v3 Round 2 resolved |
| 32.4 | `income_tax_computation_lines.computation_run_id` FK → `itr_computation_runs.id` (changed from `itr_filing_id`) — confirmed in doc 03 § 20 | DB Architect | [!] | v3 Round 2 resolved |
| 32.5 | `income_tax_return_filings.itr_computation_run_id` FK → `itr_computation_runs.id` (changed from itr_working_paper_id) — confirmed in doc 03 § 19 | DB Architect | [!] | v3 Round 2 resolved |
| 32.6 | `book_tax_reconciliations` column spec added to doc 03 § 20 | CPA Lead | [!] | v3 Round 2 resolved |
| 32.7 | `tax_credits_schedules` column spec added to doc 03 § 20 | CPA Lead | [!] | v3 Round 2 resolved |
| 32.8 | ITR computation audit events (`ITR_COMPUTATION_RUN_CREATED`, `BOOK_TAX_RECONCILIATION_COMPLETED`, `NOLCO_UPDATED`) added to doc 07 v3 Round 2 | DB Architect | [!] | v3 Round 2 resolved |

---

## SECTION 33: Doc 03 Coverage Gap — Cross-Reference Index (v3 Round 2)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 33.1 | Section 21 Cross-Reference Index added to doc 03 — maps all ~200 inventory tables to spec location | DB Architect | [!] | v3 Round 2 resolved |
| 33.2 | Tables marked SPEC REQUIRED in Section 22 cross-reference (~14 tables) — must be specced before migration | DB Architect | [ ] | Blocked: Phase 2 sprint required |
| 33.3 | Abbreviated specs added to doc 03 § 21 for critical reference tables: currencies, payment_terms, payment_term_lines, vat_codes, atc_codes, items | DB Architect | [!] | v3 Round 2 resolved |
| 33.4 | `exchange_rates` table — currently SPEC REQUIRED; needed before multi-currency transactions can be specced | DB Architect | [ ] | Open |
| 33.5 | `debit_memos` / `debit_memo_lines` — currently SPEC REQUIRED; needed for purchase return flows | CPA Lead | [ ] | Open |

---

## SECTION 34: COA Mapping Architecture (v3 Round 2)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 34.1 | Phase 1 decision confirmed: COA-embedded FS fields ONLY — no separate `financial_statement_mappings` or `cash_flow_mapping_rules` tables | DB Architect | [!] | v3 Round 2 resolved |
| 34.2 | `chart_of_accounts` FS fields confirmed: `fs_section`, `fs_group`, `fs_sort_order`, `cash_flow_category` | CPA Lead | [ ] | Needs CPA sign-off on field values |
| 34.3 | `coa_fs_mapping` bulk import type added to doc 08 for batch updating FS fields | DB Architect | [!] | v3 Round 2 resolved |
| 34.4 | `income_tax_mappings` bulk import type added to doc 08 for batch updating is_mcit_gross_income/is_osd_gross_revenue | CPA Lead | [!] | v3 Round 2 resolved |
| 34.5 | `COA_FS_MAPPING_CHANGED` audit event type added to doc 07 | DB Architect | [!] | v3 Round 2 resolved |

---

---

## SECTION 35: Amortization Schedule System (Enhancement Round)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 35.1 | `amortization_schedules` table design reviewed — 4-table pattern confirmed (header + lines + runs + run_details) for full traceability per Principles 9 and 12 | DB Architect | [!] | Enhancement Round — justified by Principle 9 |
| 35.2 | `amortization_schedule_lines` pre-computed on schedule creation — confirmed; allows user to preview and verify before any run executes | CPA Lead | [ ] | |
| 35.3 | Amortization run generates JE with `je_type = 'amortization'` and `amortization_run_detail_id` → full traceability to source schedule line | DB Architect | [!] | Traceability chain complete |
| 35.4 | Amortization JE is posted directly (no separate posting_rule_set) — DR expense_account / CR prepaid_account per schedule — confirmed | CPA Lead | [ ] | |
| 35.5 | `amortization_schedules.source_document_id` links back to originating vendor_bill or cash_purchase — confirmed | CPA Lead | [ ] | |
| 35.6 | `amortization_schedule_lines.status` transitions: pending → processed (success) or skipped (period closed) — confirmed | DB Architect | [ ] | |
| 35.7 | Month-end closing checklist must include "Run Amortization" step before period close | CPA Lead | [ ] | |
| 35.8 | BIR implication: prepaid expense deductible in period consumed (not paid) — confirmed; amortization schedule enforces this timing | Tax Consultant | [ ] | |

---

## SECTION 36: Revenue Recognition Schedule System (Enhancement Round)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 36.1 | `revenue_recognition_schedules` table design reviewed — same 4-table pattern as amortization | DB Architect | [!] | Enhancement Round |
| 36.2 | Recognition run generates JE with `je_type = 'revenue_recognition'` and `revenue_recognition_run_detail_id` — traceability complete | DB Architect | [!] | Traceability chain complete |
| 36.3 | Revenue recognition JE: DR deferred_revenue_account / CR revenue_account per schedule — confirmed | CPA Lead | [ ] | |
| 36.4 | `revenue_recognition_schedules.source_document_id` links to originating sales_invoice or cash_sale — confirmed | CPA Lead | [ ] | |
| 36.5 | Revenue recognition affects VAT output? Clarify: VAT is recognized at billing (on the invoice), NOT at monthly recognition | Tax Consultant | [ ] | Open question |
| 36.6 | Month-end closing checklist must include "Run Revenue Recognition" step before period close | CPA Lead | [ ] | |
| 36.7 | PFRS 15 (Revenue from Contracts with Customers) — does this satisfy Phase 1 PH GAAP requirements? | CPA Lead / Tax Consultant | [ ] | Straight-line only in Phase 1 |

---

## SECTION 37: Auto Reversal System (Enhancement Round)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 37.1 | Auto-reversal columns added to `journal_entries`: `auto_reversal_flag`, `auto_reversal_date`, `auto_reversal_run_id`, `is_auto_reversal` — confirmed | DB Architect | [!] | Enhancement Round |
| 37.2 | `accrual_schedules` NOT added — accruals handled by recurring_journal_templates with `auto_reverse = true` — confirmed no duplicate tables needed (Principle 23) | DB Architect | [!] | Principle 23 compliance ✓ |
| 37.3 | `recurring_journal_templates.auto_reverse` flag — if true, generated JEs have `auto_reversal_flag = true` and `auto_reversal_date = document_date + auto_reversal_days_offset` | DB Architect | [!] | Enhancement Round |
| 37.4 | `auto_reversal_runs` table reviewed — batch processing header; one run per period per company | DB Architect | [!] | Enhancement Round |
| 37.5 | Auto-reversal JE creates mirrored lines (all DR/CR swapped) — confirmed | CPA Lead | [ ] | |
| 37.6 | Auto-reversal cannot process if target period is CLOSED — run aborts the individual line (not the entire batch) | DB Architect | [ ] | |
| 37.7 | `RECURRING_JE_GENERATED`, `AUTO_REVERSAL_CREATED`, `AUTO_REVERSAL_RUN_COMPLETED` audit events added to doc 07 — confirmed | DB Architect | [!] | Enhancement Round |
| 37.8 | Period-end workflow must clarify order: (1) Run Amortization, (2) Run Revenue Recognition, (3) Run Recurring JEs (including accruals), (4) Close Period, (5) Run Auto-Reversals (at start of NEXT period) | CPA Lead | [ ] | Open — needs explicit ordering |

---

---

## SECTION 38: BLOCKER 2 — EWT Payable Posting Correction (v3.1)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 38.1 | Cash Purchase EWT posting corrected in doc 06: `CR: EWT Payable` (not DR) — confirmed | CPA Lead | [!] | v3.1 normalization resolved |
| 38.2 | Cash Purchase posting formula confirmed: `net_payable_amount = gross_amount + vat_amount - ewt_amount` | CPA Lead | [!] | v3.1 normalization resolved |
| 38.3 | EWT Payable is a **liability** (credit-normal balance) — company owes withheld amount to BIR | CPA Lead | [!] | CPA standard — no ambiguity |
| 38.4 | All posting examples in all architecture docs reviewed for DR/CR correctness | DB Architect | [ ] | Verify in doc 05 compliance map |

---

## SECTION 39: BLOCKER 3 — Canonical Table Name Registry (v3.1)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 39.1 | `financial_statement_mappings` (#31) confirmed REMOVED — COA embedded fields replace it | DB Architect | [!] | v3.1 normalization resolved |
| 39.2 | `certificates_2306` RENAMED to `certificates_2306_issued` (#149) — confirmed in doc 02 Canonical Registry | CPA Lead | [!] | v3.1 normalization resolved |
| 39.3 | `receipts` (#71) — canonical name confirmed KEEP as-is (Official Receipts issued to customers for AR collection) | CPA Lead | [!] | v3.1 resolved |
| 39.4 | `payment_vouchers` (#87) — canonical name confirmed KEEP as-is (AP payments to suppliers) | CPA Lead | [!] | v3.1 resolved |
| 39.5 | `journal_lines` (#130) — canonical name confirmed KEEP as-is | DB Architect | [!] | v3.1 resolved |
| 39.6 | Canonical Table Name Registry section added to doc 02 — 207 ACTIVE + 3 REMOVED tables | DB Architect | [!] | v3.1 normalization resolved |
| 39.7 | Naming convention documented: `_issued` suffix on certificate output tables; `_entries` on compliance ledger tables; `_runs` on batch headers; `_lines` on line-item tables | DB Architect | [!] | v3.1 normalization resolved |
| 39.8 | All migration scripts must use canonical names from doc 02 registry — no deviations | DB Architect | [ ] | Must be validated in migration authoring |

---

## SECTION 40: BLOCKER 4 — EWT/FWT Party Field Normalization (v3.1)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 40.1 | Decision: `ewt_entries` and `fwt_entries` remain as **separate tables** — not merged into a unified withholding table | CPA Lead | [!] | v3.1 — separate tables confirmed; BIR forms are separate (1601EQ vs 1601FQ) |
| 40.2 | `ewt_entries` party field columns RENAMED: `supplier_tin` → `payee_tin`, `supplier_name` → `payee_registered_name` | DB Architect | [!] | v3.1 normalization resolved |
| 40.3 | Standard party snapshot columns on `ewt_entries`: `payee_id uuid NULL`, `payee_type CHECK IN ('supplier','customer')`, `payee_tin text`, `payee_registered_name text`, `payee_registered_address text NULL` | CPA Lead / DB Architect | [!] | v3.1 normalization resolved |
| 40.4 | Same standard party snapshot columns applied to `fwt_entries` — consistent interface | DB Architect | [!] | v3.1 normalization resolved |
| 40.5 | Index updated: `idx_ewt_entries_payee_tin ON ewt_entries(company_id, payee_tin)` — replaces old `idx_ewt_entries_supplier_tin` | DB Architect | [!] | v3.1 normalization resolved — doc 09 updated |
| 40.6 | `payee_id` is nullable (snapshot-first) — historical transactions without party master records still supported | DB Architect | [ ] | Confirm in migration script |
| 40.7 | `payee_type = 'customer'` on `ewt_entries` — valid for customer EWT (e.g., CWT on rents received) | CPA Lead | [ ] | Confirm PH use cases with CPA |

---

## SECTION 41: BLOCKER 5 — Cross-Reference Index Rebuilt (v3.1)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 41.1 | Cross-reference index in doc 03 Section 22 rebuilt with exact counts — no approximations | DB Architect | [!] | v3.1 normalization task |
| 41.2 | All 207 active tables account for full column specs in doc 03 (Sections 1–44) — no SPEC REQUIRED placeholders remaining | DB Architect | [ ] | Pending doc 03 agent completion |
| 41.3 | Cross-reference index states exact table count: 207 active, 3 removed | DB Architect | [ ] | Pending doc 03 agent completion |
| 41.4 | Tables with specs in doc 09 Section 2 (security tables) cross-referenced from doc 03 | DB Architect | [!] | v3.1 normalization resolved |

---

## SECTION 42: BLOCKER 6 — Branch Access Security Boundary Decision (v3.1)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 42.1 | **Decision: Option A selected for Phase 1** — company-level RLS only; branch is a UI/query filter, not a hard RLS security boundary | DB Architect / Business Lead | [!] | v3.1 normalization resolved — doc 09 updated |
| 42.2 | Branch filtering in application queries uses `auth.user_branch_ids()` in WHERE clause — confirmed | DB Architect | [!] | v3.1 resolved |
| 42.3 | Branch-level access enforcement at Edge Function layer confirmed for: period close, CAS DAT export, approval routing | DB Architect | [ ] | Must be implemented in Edge Functions |
| 42.4 | Phase 2 upgrade path to Option B documented in doc 09 — no schema changes required, policy changes only | DB Architect | [!] | v3.1 resolved |
| 42.5 | `user_branch_access` table confirmed as configuration table for both Phase 1 (UI filtering) and Phase 2 (RLS enforcement) | DB Architect | [!] | v3.1 resolved |

---

## SECTION 43: BLOCKER 7 — UI Mockup as Prototype (v3.1)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 43.1 | `index.html` in repository root formally documented as VISUAL PROTOTYPE ONLY in doc 01 | Business Lead / DB Architect | [!] | v3.1 normalization resolved |
| 43.2 | Architecture decisions derived from mockup module groupings are documented in docs 02–10 — mockup is NOT the source of truth | DB Architect | [!] | v3.1 resolved |
| 43.3 | Mockup will be replaced by actual application UI during development sprints — confirmed | Business Lead | [ ] | Stakeholder awareness needed |
| 43.4 | No column names, business logic, or BIR form configurations should be derived from the mockup | CPA Lead | [!] | v3.1 resolved |

---

## SECTION 44: All Column Specs Complete (v3.1 — BLOCKER 1)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 44.1 | All 207 active tables have full column specifications in doc 03 — no SPEC REQUIRED entries | DB Architect | [ ] | Pending doc 03 agent completion |
| 44.2 | Sections 24–44 added to doc 03 covering ~114 previously unspecced tables | DB Architect | [ ] | Pending doc 03 agent completion |
| 44.3 | All specs follow standard format: column name, type, null/not null, default, description | DB Architect | [ ] | Pending doc 03 agent completion |
| 44.4 | Standard audit columns documented once in doc 03 Standard Column Sets and referenced by all applicable tables | DB Architect | [!] | Already in doc 03 |
| 44.5 | Standard transaction header columns documented once and referenced — no copy-paste duplication | DB Architect | [!] | Already in doc 03 |
| 44.6 | Money columns: `numeric(18,4)` verified across all new specs | CPA Lead | [ ] | Pending spec review |
| 44.7 | Rate columns: `numeric(10,6)` verified across all new specs | DB Architect | [ ] | Pending spec review |

---

## SECTION 45: Version Normalization (v3.1)

| # | Item | Owner | Status | Comments |
|---|---|---|---|---|
| 45.1 | All 10 architecture documents updated to version 3.1 | DB Architect | [!] | v3.1 normalization resolved |
| 45.2 | All 10 documents show consistent status: "v3.1 — Normalization In Progress — Not Yet Migration-Approved" | DB Architect | [!] | v3.1 normalization resolved |
| 45.3 | No document states "Gaps Resolved" or "v3 In Review" as current status | DB Architect | [!] | v3.1 normalization resolved — all statuses corrected |
| 45.4 | Migration authoring gate confirmed: ALL sign-off items in this checklist must be `[x]` or `[N/A]` before SQL migrations begin | DB Architect / Project Lead | [ ] | Not yet — normalization pass in progress |

---

**Once all items in Sections 1–45 are marked `[x]` or `[N/A]`, and all Open Decisions across all documents are resolved or explicitly deferred, SQL migration authoring may begin.**

*Next step after sign-off: `11_SQL_MIGRATIONS.md` — create all Supabase migration files in order.*
