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

**Backlog:** M-010-1 tracks the RLS guard requirement.

**Final status:** RESOLVED — implemented in Migration 010.

---

*Last updated: Migration 010 pre-commit pass*
