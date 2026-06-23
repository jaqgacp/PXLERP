# PXL ERP — Supabase Database Decision Log

**Purpose:** Record implementation decisions so the same issues are not repeatedly debated.
All decisions are final for v4.0 database freeze unless explicitly superseded.

---

## Decision 001 — Dual Credit Limit: `customers.credit_limit` vs `customer_credit_profiles.credit_limit`

**Problem:**
`customers.credit_limit` and `customer_credit_profiles.credit_limit` are two columns that
represent the same business concept (the maximum credit extended to a customer). Without a
defined semantic contract these will diverge in production.

**Decision:**
Maintain both columns with a defined semantic contract:
- `customers.credit_limit` — user-entered setup default captured at customer onboarding time.
- `customer_credit_profiles.credit_limit` — the **authoritative, AR-managed** credit limit after
  onboarding. The posting engine and AR module read and write this value only.

At customer creation, the application layer must seed `customer_credit_profiles.credit_limit`
from `customers.credit_limit`. After that point `customers.credit_limit` is a historical
reference and is not updated.

**Reason:**
The architecture is frozen at v4.0. Removing `customers.credit_limit` requires a column drop
which is a non-additive schema change prohibited during the freeze. The semantic contract
eliminates runtime ambiguity without modifying SQL.

**RLS / Application implication:**
Application must enforce the seeding rule. No DB-level constraint enforces parity.

**Final status:** OPEN — semantic contract documented here and in SQL COMMENT on both columns.

**Future Proposal:** v4.1-002 — Remove `customers.credit_limit` and make
`customer_credit_profiles.credit_limit` the single source of truth.

---

## Decision 002 — `payment_term_lines` Has No `company_id`

**Problem:**
`payment_term_lines` does not carry a `company_id` column. The RLS pattern used across PXL ERP
anchors row-level access via `company_id`. For line tables without `company_id`, the RLS policy
in Migration 017 must perform a correlated subquery join through the parent `payment_terms`
table on every row check, which has measurable overhead at scale.

**Decision:**
Accept the current schema without `company_id` on `payment_term_lines` for Phase 1.
Migration 017 RLS must use: `EXISTS (SELECT 1 FROM payment_terms pt WHERE pt.id = payment_term_lines.payment_term_id AND pt.company_id = current_company_id())`.

**Reason:**
Adding `company_id` to `payment_term_lines` would be a denormalization that changes the
table's contract. The architecture is frozen. The RLS join overhead at the scale of payment
term lines (typically low row count — dozens per company) is acceptable for Phase 1.

**RLS implication:**
Migration 017 author must implement the correlated subquery pattern. A future migration may
add `company_id` as a denormalized RLS anchor if profiling shows the subquery is too costly.

**Final status:** OPEN — backlog item H-006-2. Evaluate during FINAL REVIEW PASS.

---

## Decision 003 — EWT/FWT ATC Series Validation (DB CHECK vs Application Layer)

**Problem:**
BIR rules require:
- `ewt_codes` rows must reference ATC codes in the WC- or WI-series only (Expanded Withholding Tax).
- `fwt_codes` rows must reference ATC codes in the WF-series only (Final Withholding Tax).

A DB-level `CHECK` constraint cannot enforce this because the ATC code lives in the
`atc_codes` table; CHECK constraints cannot join across tables in PostgreSQL.
A trigger could enforce this but is out of scope for Phase 1 schema migration (triggers
belong in a dedicated trigger migration).

**Decision:**
Do NOT add a DB-level CHECK constraint or trigger in Migration 005.
Application layer MUST validate the ATC series membership before INSERT:
- For `ewt_codes`: verify `atc_codes.code LIKE 'WC%' OR atc_codes.code LIKE 'WI%'`
- For `fwt_codes`: verify `atc_codes.code LIKE 'WF%'`

A COMMENT has been added to both tables documenting this requirement.

**Reason:**
PostgreSQL CHECK constraints are single-table only. Cross-table enforcement requires a
trigger. Trigger migrations are deferred to a dedicated migration to keep each migration
small and reviewable. Application-layer validation is the correct Phase 1 pattern.

**Application validation requirement:**
The API route / service layer that creates `ewt_codes` or `fwt_codes` rows must
validate the ATC series before persisting. This is a BIR compliance requirement —
misclassification causes incorrect 1601EQ/1601FQ returns.

**Final status:** OPEN (APPLICATION VALIDATION REQUIRED) — backlog item M-006-2.

---

## Decision 004 — `tax_calendar.period_covered` Free Text Format

**Problem:**
`tax_calendar.period_covered` is a `text NOT NULL` column. BIR filing periods span
monthly, quarterly, and annual frequencies. Without a defined format the UNIQUE constraint
on `(company_id, form_code, period_covered)` can be defeated by inconsistent entry
(e.g., `'Jan 2025'` vs `'January 2025'` vs `'2025-01'` would create duplicate logical periods
as three distinct rows).

**Decision:**
Accept `text` type with a strict mandatory format enforced at the application layer.

**Required format:**
| Frequency | Format | Example |
|---|---|---|
| Monthly | `YYYY-MM` | `2025-01`, `2025-12` |
| Quarterly | `YYYY-Q1`, `YYYY-Q2`, `YYYY-Q3`, `YYYY-Q4` | `2025-Q1` |
| Annual | `YYYY` | `2025` |

No other formats are permitted. The application input widget must enforce this.

A COMMENT has been added to `tax_calendar.period_covered` documenting the required format.

**Application validation requirement:**
Input forms and import validators must reject any `period_covered` that does not match
the pattern `^[0-9]{4}(-[0-9]{2}|-Q[1-4])?$`.

**Final status:** OPEN (APP ENFORCEMENT) — backlog item L-005-1.

**Future Proposal:** v5.0-001 — Replace `period_covered text` with structured columns
`period_year integer`, `period_month integer NULL`, `period_quarter integer NULL`.

---

## Decision 005 — `personnel` Has No `user_id` FK to `auth.users`

**Problem:**
The `personnel` table stores employee lite records used for approver name resolution
(approval matrix, document sign-off). However, there is no link between a `personnel`
record and a Supabase `auth.users` / `profiles` record. This means:
- Approval notification emails cannot be routed to system users automatically.
- The posting engine cannot verify that the listed approver is an active authenticated user.
- HR sync (e.g., from an HRIS) cannot map personnel to login accounts.

**Decision:**
Do NOT add `user_id` FK to `auth.users` on `personnel` in Phase 1 (Migration 006).
The column is intentionally absent. `personnel` serves as a lightweight name registry
that can be maintained without requiring a Supabase auth account for every employee.

**Reason:**
Phase 1 scope is core accounting cycle. Authentication integration for personnel is a
separate workstream. Adding an optional FK now introduces a dependency on the auth
provisioning workflow before personnel records can be entered, which blocks early data
entry and onboarding.

**Deferral:**
Future Proposal v4.1-001: Add `user_id uuid NULL REFERENCES auth.users(id)` to
`personnel` to optionally link records to system login accounts. NULL = no linked user.

**Final status:** OPEN — Future Proposal v4.1-001. Deferred post-Phase 1.

---

---

## Decision 006 — EWT on Petty Cash: Captured at Voucher Line Level (OD-09)

**Problem:**
Petty cash payments may be subject to Expanded Withholding Tax (e.g., professional fees paid
from the petty cash fund). Two possible capture points exist:
1. At the `petty_cash_voucher_line` level (when the expense is recorded).
2. At the `petty_cash_replenishments` level (when the fund is replenished via payment voucher).

**Decision:**
EWT is captured at `petty_cash_voucher_line` level — NOT at the replenishment payment voucher.
Columns `ewt_atc_id` and `ewt_amount` are on `petty_cash_voucher_lines`.
The replenishment `payment_voucher` does NOT re-capture EWT.

**Reason:**
This mirrors the treatment of `cash_purchase_lines` (EWT at the expense line, not at the
payment). The posting engine writes `ewt_entries` when the petty cash voucher is posted.
At replenishment time, the AP/EWT liability is already recorded; the payment voucher merely
settles the replenishment fund transfer. Re-capturing EWT on the payment voucher would cause
double-booking of EWT liability and double-counting in 1601EQ and QAP.

This is an **OPEN/RESOLVED architectural decision** from Doc02 Section OD-09:
*"EWT on petty cash — captured at voucher or at replenishment? RESOLVED v3.7: Captured at
petty_cash_voucher line level."*

**Application implication:**
The posting engine must:
1. Write `ewt_entries` from `petty_cash_voucher_lines.ewt_atc_id/ewt_amount` at voucher post.
2. NOT generate EWT entries from the linked `payment_vouchers` on replenishment.
The QAP and 1601EQ sourcing logic must include `petty_cash_voucher_lines` as an EWT source.

**Final status:** RESOLVED — implemented in Migration 009.

---

## Decision 007 — `inventory_cost_layers` Partial Mutability

**Problem:**
Doc02 marks `inventory_cost_layers` as Immutable=YES. However, Doc03 defines `remaining_quantity`
and `is_exhausted` as columns that are updated by the posting engine on each FIFO consumption event.
These two sources are in apparent conflict.

**Decision:**
Implement the **partial mutability pattern**:
- The row itself is append-only: rows are never deleted and `original_quantity`, `unit_cost`,
  and `total_cost` are never modified after creation.
- `remaining_quantity` and `is_exhausted` ARE updated by the posting engine (service role) atomically
  with each `inventory_cost_layer_consumption` insert.

This matches the intent of Doc02's "Immutable" classification (no row deletion; no cost revision)
while satisfying Doc03's operational requirement that the posting engine track FIFO layer depletion.

**Reason:**
Enterprise FIFO costing requires the layer row to be the authoritative remaining-quantity record.
Recomputing remaining_quantity from consumption rows on every query would be prohibitively expensive
at scale. The partial mutability pattern is the standard approach used by NetSuite, SAP Business One,
and Microsoft Dynamics for cost layer tracking.

**RLS / Application implication:**
Migration 017 RLS must RESTRICT UPDATE on `remaining_quantity` and `is_exhausted` to service role
only. App-layer roles must not be able to write these columns directly.

**Backlog:** M-010-1 tracks the RLS guard requirement. RLS ENABLE is confirmed applied to
`inventory_cost_layers` in Migration 010 (that migration already called ENABLE ROW LEVEL SECURITY).
The service-role write-only guard via RLS POLICY is pending Migration 017.

**Clarification (Migration 016):** The cost layer partial mutability pattern is accepted.
`ENABLE ROW LEVEL SECURITY` on `inventory_cost_layers` was already present in Migration 010.
The service-role-only WRITE guard (POLICY layer) is the remaining work — tracked in backlog M-010-1
and to be implemented in Migration 017. Decision 007 remains RESOLVED at the schema level.

**Final status:** RESOLVED — implemented in Migration 010. RLS POLICY guard deferred to Migration 017.

---

## Decision 008 — `fixed_assets` Boolean Flags vs Doc06 Status Enum

**Problem:**
Doc03 §24 specifies `fixed_assets.is_active boolean` and `fixed_assets.is_disposed boolean`.
Doc06 §Asset Acquisition Posting references `fixed_assets.status` text column transitioning
from `'pending'` to `'active'` to `'disposed'`. These two sources are in conflict.

**Decision:**
Implement the **Doc03 boolean pattern** (`is_active`, `is_disposed`) as specified in the
column specification document. Doc03 is the authoritative column spec source.

The posting engine (Doc06) reference to `fixed_assets.status` is interpreted as shorthand
for the combined boolean state:
- pending  → `is_active = false AND is_disposed = false` (asset record created, not yet activated)
- active   → `is_active = true AND is_disposed = false`
- disposed → `is_disposed = true`

**Reason:**
Doc03 is the Column Specifications document and takes precedence for column definitions.
Adding a text `status` column that duplicates the boolean flags would create two sources
of truth for the same state and violate the freeze rule against redesigning tables.

**Application implication:**
The posting engine must use the boolean flags for state transitions:
- Asset activation: SET is_active = true
- Disposal posting: SET is_disposed = true, is_active = false

**Backlog:** M-011-2 tracks this for FINAL REVIEW PASS reconciliation.

**Final status:** RESOLVED — boolean pattern implemented in Migration 011.

---

## Decision 009 — Migration 011 Incorrect FK Deferral to chart_of_accounts

**Problem:**
Migration 011 (fixed_assets) declared the following columns as plain `uuid NOT NULL` (without FK
constraints) with comments stating the FK would be "added in Migration 012":
- `asset_categories.depreciation_expense_account_id`
- `fixed_assets.asset_account_id`
- `fixed_assets.depreciation_account_id`
- `fixed_assets.accumulated_depreciation_account_id`
- `asset_disposals.disposal_account_id`

However, `chart_of_accounts` already exists from Migration 004. These FKs could have been
added inline in Migration 011. The deferral was an error.

**Decision:**
Add the missing FK constraints as ALTER TABLE ... ADD CONSTRAINT statements in Migration 012.
Do NOT modify Migration 011 (ONE migration = ONE commit = ONE review — no retroactive edits).

**Resolution:**
Migration 012 Section 1 adds all 5 FK constraints via ALTER TABLE.
Backlog item M-011-1 documents the Doc03/Doc06 discrepancy for `depreciation_expense_account_id`
and its FINAL REVIEW PASS resolution requirement.

**Final status:** RESOLVED — FK constraints added in Migration 012 Section 1.

---

## Decision 010 — posting_rule_sets and posting_rule_lines in Migration 012 (not 013)

**Problem:**
`posting_rule_sets` and `posting_rule_lines` are listed in Module 16 (Accounting) in Doc02.
The question is whether they belong in Migration 012 (COA foundation) or Migration 013 (GL/JE).

**Decision:**
`posting_rule_sets` and `posting_rule_lines` are **COA-dependent configuration tables**
and belong in Migration 012. They are not GL-runtime tables:
- `posting_rule_lines.fixed_account_id → chart_of_accounts.id` (direct COA dependency)
- They define which accounts the posting engine uses; they do NOT store JE data
- They are seeded at company setup alongside system_account_config

The GL-runtime tables (`journal_entries`, `journal_lines`, `gl_balances`,
`subsidiary_ledger_entries`, `document_relationships`, `posting_batches`, `posting_errors`)
belong in Migration 013.

**Final status:** RESOLVED — posting_rule_sets/lines in Migration 012.

---

---

## Decision 011 — `document_relationships.relationship_type` Combined Superset (Doc03 + Doc06)

**Problem:**
Doc03 §document_relationships defines `relationship_type` CHECK IN:
`('generated_journal','reversed_by','paid_by','credit_applied','receipt_applied','generated_from')`

Doc06 (Posting Engine) references additional relationship_type values:
`('billed_from','delivered_from','received_from','applied_to','replenished_by')`
and also uses `'reversed_by'` and `'paid_by'` (overlap with Doc03).

The two sources have different value sets; neither is a subset of the other.

**Decision:**
Use the **combined superset** of all 11 distinct values from both documents:
- From Doc03: `generated_journal`, `reversed_by`, `paid_by`, `credit_applied`, `receipt_applied`, `generated_from`
- From Doc06 (additional): `billed_from`, `delivered_from`, `received_from`, `applied_to`, `replenished_by`

Doc03 column names are used (`source_entity_type`/`source_entity_id`/`target_entity_type`/`target_entity_id`)
as Doc03 is the canonical column specification source.

**Reason:**
The posting engine (Doc06) is the primary writer of document_relationships rows. Omitting
Doc06 relationship types would mean the posting engine cannot record doc-to-doc linkage for
PO→Invoice, Invoice→DR, and Petty Cash→Replenishment flows. The superset satisfies both
sources without contradiction. Unused values have zero runtime cost.

**Backlog:** L-013-1 tracks FINAL REVIEW PASS verification of all 11 values.

**Final status:** RESOLVED — combined superset implemented in Migration 013.

---

---

## Decision 012 — Migration 014 Scope: Module 31 Tables Only

**Problem:**
The task brief for Migration 014 asked for "posting engine support tables not already
created." All Module 16 posting-engine runtime tables were created in Migrations 012/013:
posting_rule_sets, posting_rule_lines (012), and posting_batches, posting_errors,
journal_entries, journal_lines, gl_balances, subsidiary_ledger_entries,
document_relationships, recurring_journal_templates, recurring_journal_template_lines (013).
The question was whether any additional posting-engine tables remained.

**Decision:**
Migration 014 creates Module 31 (Accounting Schedules) tables only.
No new Module 16 tables are required.

Module 31 is the canonical set of posting-engine support tables remaining:
- amortization_schedules / amortization_schedule_lines (prepaid expense amortization)
- amortization_runs / amortization_run_details (run execution + traceability)
- revenue_recognition_schedules / revenue_recognition_schedule_lines (deferred revenue)
- revenue_recognition_runs / revenue_recognition_run_details (run execution + traceability)
- auto_reversal_runs (auto-reversal batch header)

Migration 014 also wires the three deferred FKs on journal_entries that were left as plain
uuid NULL in Migration 013 with comment "deferred to Module 31 migration":
- journal_entries.auto_reversal_run_id → auto_reversal_runs.id
- journal_entries.amortization_run_detail_id → amortization_run_details.id
- journal_entries.revenue_recognition_run_detail_id → revenue_recognition_run_details.id

**Final status:** RESOLVED — implemented in Migration 014.

---

## Decision 013 — Migration 015 Circular FK: income_tax_return_filings ↔ itr_computation_runs

**Problem:**
`income_tax_return_filings.itr_computation_run_id → itr_computation_runs.id` and
`itr_computation_runs.itr_filing_id → income_tax_return_filings.id` create a circular
FK dependency. Both tables must be in the same migration (Module 19). PostgreSQL does
not allow two tables to reference each other in the same CREATE TABLE block.

**Decision:**
Create `income_tax_return_filings` first with `itr_computation_run_id` as plain
`uuid NULL` (no FK constraint). Then create `itr_computation_runs` with FK to
`income_tax_return_filings`. Then wire the deferred FK via `ALTER TABLE
income_tax_return_filings ADD CONSTRAINT fk_itrf_itr_computation_run`.

The semantic meaning: `itr_computation_run_id` on `income_tax_return_filings` points
to the LATEST computation run. This is set by the application on each new run
(run_sequence 1, 2, 3…). Application must enforce it always points to the latest run.

**Final status:** RESOLVED — within-migration circular FK resolved via ALTER TABLE
in Section 25 of Migration 015.

---

---

## Decision 014 — inventory_movements entity_type: customer_return and purchase_return (M-010-2 Escalation)

**Problem:**
`inventory_movements.entity_type` CHECK (frozen per Doc03) did not include `'customer_return'`
or `'purchase_return'`. Both document types from Migrations 007/008 generate inventory IN/OUT
movements via the posting engine (sales returns generate IN; purchase returns generate OUT).
Without these values in the CHECK, the posting engine would fail with a CHECK violation on
every return document post.

**Decision:**
Escalate backlog item M-010-2 from MEDIUM to **PRE-POSTING BLOCKER** and resolve in
Migration 016 (pre-RLS patch) rather than waiting for FINAL REVIEW PASS.

The two new values are added to the CHECK constraint:
- `'customer_return'` — sales return / customer return from Migration 007
- `'purchase_return'` — purchase return from Migration 008

Doc03 omission is treated as a documentation gap in the frozen spec, not a design intent.
The posting engine design is the authoritative source for entity_type values.

**Method:**
`ALTER TABLE inventory_movements DROP CONSTRAINT ck_im_entity_type;`
`ALTER TABLE inventory_movements ADD CONSTRAINT ck_im_entity_type CHECK (...extended list...);`

**Final status:** RESOLVED — Migration 016 Section 14.

---

## Decision 015 — Pre-RLS Security Patch Scope (Migration 016)

**Problem:**
Codex audit identified that:
1. `ENABLE ROW LEVEL SECURITY` was absent from all 32 Migration 004 tables, `payment_term_lines`
   (Migration 006), and all tables in Migrations 013/014/015 (42 tables).
2. Multiple NULL-branch uniqueness gaps in `number_series`, `system_account_config`, `user_roles`.
3. Missing `role_code` uniqueness on `roles`.
4. Missing code uniqueness on `departments` and `cost_centers`.
5. Missing CAS and ATP guards.

**Decision:**
Create Migration 016 as a pure remediation migration (no new tables). All fixes are additive:
`ENABLE ROW LEVEL SECURITY`, new partial unique indexes, new CHECK constraints. No column
additions, no table redesigns, no posting logic changes.

This migration runs BEFORE Migration 017 (RLS Policies). With RLS enabled but no policies,
tables default to DENY-ALL for non-owners — this is acceptable in a development environment
and correct for production (service role bypasses RLS regardless of policy state).

**Final status:** RESOLVED — Migration 016.

---

## Decision 016 - Owner Decision: Final Phase 1 Table Target and Adaptive Workspace Scope

**Problem:**
`PHASE1_FOUNDATION_RECONCILIATION_REPORT.md` found that the current migration set creates
178 tables while the canonical Phase 1 architecture documents define 207 active tables.
It also found that Adaptive Workspace Principle #15 cannot be satisfied by the existing
fixed `company_feature_settings` booleans alone because visibility must be configuration-driven
for modules, categories, pages, dashboards, reports, workspaces, and user preferences.

**Owner decision:**
Phase 1 will NOT be split into Phase 1A / Phase 1B.

All 207 documented active tables are required for Phase 1. The 29 documented active tables
missing from migrations must be created before CRUD or UI implementation continues.

Adaptive Workspace is non-negotiable for the Phase 1 foundation. The following 11
adaptive-workspace metadata tables are approved for Phase 1:
- `workspace_modules`
- `workspace_categories`
- `workspace_pages`
- `workspace_dashboards`
- `workspace_reports`
- `dashboard_widgets`
- `workspace_definitions`
- `workspace_items`
- `company_feature_visibility`
- `role_workspace_assignments`
- `user_workspace_preferences`

Final Phase 1 active table target: **218 tables**.

No hardcoded roles, menus, dashboards, approval flows, or feature visibility are allowed.
Visibility and workspace behavior must be driven by company feature settings, role permissions,
and user preferences.

Every feature must follow the complete traceability chain:
Business Requirement -> Architecture Document -> Database Table -> Migration -> RLS Policy ->
Backend Service -> UI Form -> Posting Engine -> Report -> Test Scenario -> User Documentation.

**Migration implication:**
Migration 018 must be a foundation reconciliation migration before CRUD/UI. Its planned scope is:
1. Create the 29 missing documented Phase 1 tables.
2. Create the 11 approved adaptive-workspace metadata tables.
3. Enable RLS and create policies for every new table.
4. Add policies for the 12 existing migrated tables that currently have RLS enabled but no policy.
5. Include remaining foundation security cleanup required before CRUD, including line immutability,
   service-owned mutable field protection, and filed-status guards where applicable.

**CRUD / UI implication:**
CRUD and UI implementation are blocked until the Phase 1 foundation reconciliation is complete.

**Backlog:**
Tracked by `C-018-1`, `C-018-2`, `C-018-3`, and `C-018-4` in
`SUPABASE_FINAL_REVIEW_BACKLOG.md`.

**Final status:** OWNER DECISION RECORDED - required before Migration 018 implementation.

---

*Last updated: Owner Decision Record before Migration 018 - Final Phase 1 Table Target*
