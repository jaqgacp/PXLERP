# PXL ERP — Supabase Final Review Backlog

**Status:** Active — items accumulate here until the FINAL SUPABASE REVIEW PASS after all migrations are complete.

**Review discipline:** Do NOT fix items in this backlog while building forward migrations. All items are resolved together in the final review pass using Codex + a senior database architect.

**Column definitions:**
- **ID** — sequential identifier
- **Migration** — the migration file containing the affected table
- **Severity** — CRITICAL / HIGH / MEDIUM / LOW
- **Description** — what the problem is and why it matters
- **Status** — OPEN / RESOLVED / ACCEPTED-AS-IS
- **Resolution Strategy** — how it will be fixed (or why it is accepted)

---

## Backlog Items

| ID | Migration | Severity | Table(s) | Description | Status | Resolution Strategy |
|---|---|---|---|---|---|---|
| C-1 | 004 | CRITICAL | `number_series` | Partial unique index `uq_number_series_active` on `(company_id, branch_id, series_type) WHERE is_active = true` does NOT prevent two active company-wide rows (branch_id IS NULL) of the same series_type. NULL != NULL in PostgreSQL unique indexes. | OPEN | Add two separate partial unique indexes: one WHERE branch_id IS NULL and one WHERE branch_id IS NOT NULL, both scoped to is_active = true and deleted_at IS NULL. |
| C-2 | 004 | CRITICAL | `system_account_config` | `UNIQUE(company_id, config_key, branch_id, effective_from)` — NULL branch_id does not prevent duplicate company-wide configs for the same key + effective_from. | OPEN | Add separate partial unique: one WHERE branch_id IS NULL, one WHERE branch_id IS NOT NULL. |
| C-3 | 004 | CRITICAL | `user_roles` | Partial unique `uq_user_roles_active` on `(user_id, role_id, company_id, branch_id) WHERE is_active = true` — branch_id IS NULL path not enforced. A user could hold the same company-level role twice while active. | OPEN | Same two-index NULL-branch pattern. |
| C-4 | 004 | CRITICAL | `roles` | No uniqueness constraint on `role_code`. Two roles with the same code can coexist (even within the same company). Role lookup by code is ambiguous. | OPEN | Add partial unique index: `UNIQUE(company_id, role_code) WHERE deleted_at IS NULL` and `UNIQUE(role_code) WHERE company_id IS NULL AND deleted_at IS NULL` for system roles. |
| H-1 | 004 | HIGH | `departments` | Missing `UNIQUE(company_id, code)`. Duplicate department codes allowed within a company. | OPEN | Add partial unique index `ON departments (company_id, code) WHERE deleted_at IS NULL`. |
| H-2 | 004 | HIGH | `cost_centers` | Missing `UNIQUE(company_id, code)`. Duplicate cost center codes allowed. | OPEN | Add partial unique index `ON cost_centers (company_id, code) WHERE deleted_at IS NULL`. |
| H-3 | 004 | HIGH | `approval_matrix` | Comment says "approval_type: majority (requires all approvers)" — but enum `pxl_approval_type` has `any_one`, not `majority`. Comment describes wrong semantics. | OPEN | Update COMMENT ON COLUMN approval_matrix.approval_type to accurately describe `sequential`, `parallel`, `any_one`. |
| H-006-1 | 006 | HIGH | `customers`, `customer_credit_profiles` | `customers.credit_limit` and `customer_credit_profiles.credit_limit` are two sources of truth for the same business fact. They will diverge in production. | OPEN | Document semantic contract: `customers.credit_limit` is the setup default; `customer_credit_profiles.credit_limit` is the authoritative AR-managed value. Seed credit_profiles.credit_limit from customers.credit_limit at customer creation. Consider removing customers.credit_limit in v5.0. |
| H-006-2 | 006 | HIGH | `payment_term_lines` | No `company_id` on payment_term_lines. RLS in Migration 017 will require a correlated subquery join through `payment_terms` on every row check. Measurable overhead at scale. | OPEN | During FINAL REVIEW PASS: evaluate adding `company_id uuid NOT NULL REFERENCES companies(id)` to `payment_term_lines` as a denormalized RLS anchor. |
| M-1 | 004 | MEDIUM | `validation_rules` | Comment on `severity` column mentions 'info' — but enum `pxl_validation_severity` only has `error` and `warning`. 'info' does not exist. | OPEN | Correct COMMENT to remove mention of 'info'. |
| M-2 | 004 | MEDIUM | `profiles` | Missing `deleted_by uuid NULL REFERENCES profiles(id)` column. Doc02 marks profiles as Soft Delete=YES. All other soft-delete tables have deleted_by. | OPEN | ADD COLUMN `deleted_by uuid NULL REFERENCES public.profiles(id)` during FINAL REVIEW PASS. |
| M-3 | 004 | MEDIUM | `cas_registrations` | Missing date CHECK (date_valid_to > date_issued) and missing UNIQUE(company_id, cas_permit_no). Two registrations with the same permit number can coexist. | OPEN | Add CHECK and partial unique index in FINAL REVIEW PASS. |
| M-4 | 004 | MEDIUM | `number_series_atp` | Missing `UNIQUE(company_id, atp_no)`. Duplicate ATP numbers allowed within a company — violates BIR ATP uniqueness requirement. | OPEN | Add partial unique index `ON number_series_atp (company_id, atp_no) WHERE deleted_at IS NULL`. |
| M-006-1 | 006 | MEDIUM | `item_prices` | **RESOLVED IN PLACE** — partial unique index `uq_item_prices_active` added for active prices per (company_id, item_id, price_list_name, min_quantity, COALESCE(customer_group,'')). Historical overlap (effective_to IS NOT NULL) remains app-layer responsibility. | RESOLVED | Partial unique index added in Migration 006. Historical overlap tracking is application-layer concern. |
| M-006-2 | 006 | MEDIUM | `ewt_codes`, `fwt_codes` | DB-level enforcement of ATC series membership (WC/WI for EWT, WF for FWT) is impossible without a trigger. Misclassification causes incorrect BIR returns. | OPEN — APPLICATION VALIDATION REQUIRED | Comment added to both tables. Application layer must validate `atc_codes.code LIKE 'WC%' OR 'WI%'` before inserting into ewt_codes, and `LIKE 'WF%'` before inserting into fwt_codes. |
| M-006-3 | 006 | MEDIUM | `warehouse_stock_settings` | **RESOLVED IN PLACE** — CHECK constraint `ck_wss_ordering` added: `max_quantity = 0 OR (min_quantity <= reorder_point AND reorder_point <= max_quantity)`. | RESOLVED | CHECK constraint added in Migration 006. |
| M-006-4 | 006 | MEDIUM | `customer_credit_profiles` | `current_outstanding` must only be written by the AR posting engine (service role). No DB-level guard in Phase 1. | OPEN | COMMENT added to column. RLS Migration 017 must add RESTRICTIVE policy or REVOKE UPDATE on this column from non-service roles. |
| M-005-1 | 005 | MEDIUM | `atc_codes` | Global table without company_id; standard company-scoped RLS does not apply. Special RLS handling required. | OPEN | COMMENT added to table. Migration 017 must implement: SELECT = authenticated, INSERT/UPDATE/DELETE = service role or is_super_admin. |
| L-1 | 004 | LOW | `number_series` | Missing `CHECK(next_sequence <= max_value)`. A number series can exceed its defined max without warning. | OPEN | Add CHECK constraint. Evaluate whether trigger-based enforcement is needed (max_value can change). |
| L-2 | 004 | LOW | `fiscal_years` | `is_current` enforced by partial unique index — but Doc03 Principle 7 specifies a trigger to auto-unset the previous current year. Index prevents two current=true but does not auto-toggle. | OPEN | In Migration 017 (functions) or a dedicated trigger migration: add trigger to auto-set old is_current=false when new is_current=true is inserted. |
| L-006-1 | 006 | LOW | `uom_conversions` | No enforcement of bidirectional conversion pairs. If BOX→PC exists, PC→BOX is NOT automatically created. | OPEN — APPLICATION RESPONSIBILITY | COMMENT added to table. Application layer must create inverse conversion row when defining a UOM pair. |
| L-006-2 | 006 | LOW | `warehouses` | `uq_warehouses_branch_default` partial unique correctly enforces one default per (company_id, branch_id). | RESOLVED — NO ACTION | Verified correct in Foundation Gate review. |
| L-006-3 | 006 | LOW | `personnel` | No link between `personnel` and `auth.users`/`profiles`. Approval notification emails cannot be routed to system users. | OPEN — FUTURE PROPOSAL v4.1 | Future Proposal v4.1: add `user_id uuid NULL REFERENCES auth.users(id)` to personnel to optionally link records to system logins. Deferred post-Phase 1. |
| L-005-1 | 005 | LOW | `tax_calendar` | `period_covered text NOT NULL` is free-form. Inconsistent entry ('Jan 2025' vs 'January 2025') breaks UNIQUE constraint and calendar lookups. | OPEN — APP ENFORCEMENT | COMMENT added specifying mandatory formats: Monthly=YYYY-MM, Quarterly=YYYY-Q1, Annual=YYYY. Application layer must enforce at input. Consider adding CHECK(period_covered ~ '^[0-9]{4}(-[0-9]{2}|-Q[1-4])?$') in FINAL REVIEW PASS. |

---

## Summary Counts

| Severity | Count | Resolved | Open |
|---|---|---|---|
| CRITICAL | 4 | 0 | 4 |
| HIGH | 4 | 0 | 4 |
| MEDIUM | 9 | 3 | 6 |
| LOW | 6 | 1 | 5 |
| **TOTAL** | **23** | **4** | **19** |

---

## Future Proposals (out of scope for Phase 1)

| ID | Description |
|---|---|
| v4.1-001 | `personnel.user_id` FK to `auth.users` for approval notification routing |
| v4.1-002 | Remove `customers.credit_limit` and make `customer_credit_profiles.credit_limit` the single source of truth |
| v5.0-001 | Structured `period_year`/`period_month`/`period_quarter` columns replacing `tax_calendar.period_covered` free text |

---

*Last updated: Migration 007 pre-development pass*
