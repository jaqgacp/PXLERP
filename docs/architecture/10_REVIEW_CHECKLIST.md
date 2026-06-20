# PXL ERP — Pre-Implementation Review Checklist
**Version:** 2.0 — Revised for Implementation Readiness
**Status:** For CPA and Developer Review
**Sign-off Required Before:** SQL migration authoring begins

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
| 3.1 | Account type hierarchy (Asset, Liability, Equity, Revenue, Expense, Contra) confirmed | CPA Lead | [ ] | |
| 3.2 | Normal balance side per account type defined | CPA Lead | [ ] | |
| 3.3 | Parent-child account hierarchy (self-referencing) confirmed | CPA Lead | [ ] | |
| 3.4 | Account used as control accounts (AR, AP, VAT, EWT) defined in `system_account_config` | CPA Lead | [ ] | |
| 3.5 | System-seeded account types and default COA template reviewed | CPA Lead | [ ] | |

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
| 4.8 | 2306 (final withholding) separate from 2307 confirmed — `certificates_2306_issued` table | CPA Lead | [ ] | |
| 4.9 | QAP monthly breakdown (M1, M2, M3) per (payee_tin, atc_code) confirmed using `ewt_entries` snapshots | CPA Lead | [ ] | |
| 4.10 | SLSP — buyer TIN required on sales invoices (validation rule at posting) confirmed | CPA Lead | [ ] | |
| 4.11 | RELIEF — seller TIN required on vendor bills (validation rule at posting) confirmed | CPA Lead | [ ] | |
| 4.12 | `payee_tin` denormalized on `ewt_entries` (snapshot at time of transaction, never updated) confirmed | CPA Lead | [ ] | |
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
| 20.6 | Cash Purchases posting: DR Inventory/Expense + DR Input VAT / CR Cash (net of EWT) + DR EWT Payable confirmed | CPA Lead | [ ] | |
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
| 23.3 | `certificates_2306` generated per payee per quarter from `fwt_entries` confirmed | CPA Lead | [ ] | |
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

**Once all items in Sections 1–25 are marked `[x]` or `[N/A]`, and all Open Decisions in Section 13 are resolved, SQL migration authoring may begin.**

*Next step after sign-off: `11_SQL_MIGRATIONS.md` — create all Supabase migration files in order.*
