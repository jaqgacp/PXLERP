> [!WARNING]
> **STATUS: SUPERSEDED**
> DO NOT USE AS IMPLEMENTATION SOURCE
> Canonical Source: FOUNDATION_FREEZE_REPORT.md
# PXL ERP - Foundation Certification Report

Reviewed branch: `main`
Reviewed commit: `434fcd2c0a256db4e464e690b2cf12b8cc1fc88d`
Review mode: final RLS + architecture alignment foundation audit
Report date: 2026-06-23

## Executive Verdict

NOT APPROVED - FOUNDATION CLEANUP REQUIRED BEFORE CRUD

The implemented database foundation is strong in the areas already migrated: the core accounting, sales, purchasing, assets, GL, posting support, and compliance schemas are materially present; all 178 implemented tables have RLS enabled; Migration 016 resolved the known pre-RLS critical blockers; and RLS helper functions follow the required Supabase-safe `SECURITY DEFINER` + explicit `search_path` pattern.

However, the foundation cannot be certified before CRUD because objective blockers remain:

1. Doc02/Doc03 define 207 active tables, but migrations 001-017G create only 178. The 29 missing active tables are not recorded as an accepted database-freeze deferral set.
2. 12 implemented, RLS-enabled tables have no 017 policy, so authenticated CRUD will be blocked by deny-all on core setup/config tables.
3. Several transaction line/non-status tables have broad company-scoped UPDATE policies with no parent status guard, so RLS does not enforce the posted-document immutability model.

## Scores

| Area | Score | Basis |
|---|---:|---|
| Architecture alignment | 72/100 | Implemented tables map to Doc02/Doc03, but 29 active architecture tables are absent from migrations. |
| Migration score | 76/100 | Migration ordering is mostly clean; 178 created tables and 0 undocumented extra tables. Missing later active modules block freeze. |
| PostgreSQL validity score | 84/100 | Static review found no obvious syntax blockers; `psql` was unavailable for a clean-db dry run. |
| Supabase compatibility score | 82/100 | RLS helpers are safe; all implemented tables have RLS enabled; policy gaps remain. |
| Security/RLS score | 64/100 | No DELETE policies, global lookup READ policies are isolated, but 12 tables lack policies and line immutability is not enforced. |
| Accounting foundation score | 81/100 | Core accounting structure exists; service-owned mutable fields and line immutability still need cleanup. |
| Compliance foundation score | 78/100 | VAT/EWT/FWT/PT/ITR tables exist; audit/export/document-output dependency tables are missing. |
| Traceability score | 70/100 | Source document -> JE -> GL -> compliance is mostly traceable; audit/export/generated-document chains are incomplete. |
| Maintainability score | 79/100 | Decisions/backlog are useful but stale after 017A-017G and have wrong deferral comments. |
| ERP readiness score | 68/100 | Not ready for CRUD until table and RLS blockers are closed. |

## Evidence Summary

| Check | Result |
|---|---|
| Doc02 active tables | 207 |
| Migration-created tables through 017G | 178 |
| Undocumented extra migration tables | 0 |
| Active Doc02 tables missing from migrations | 29 |
| Implemented tables with RLS enabled | 178/178 |
| Implemented tables referenced by 017 policies | 167/178 |
| Implemented RLS-enabled tables without policy | 12 |
| DELETE policies in 017A-017G | 0 |
| `USING (true)` policies | 4, all in 017A global lookup tables only: `account_types`, `currencies`, `permissions`, `atc_codes` |
| Live PostgreSQL dry run | Not run; `psql` is not installed in this environment |

## A. Critical Issues

### C-017H-1 - 29 active architecture tables are not implemented

Severity: CRITICAL

Files:
- `docs/architecture/02_COMPLETE_TABLE_INVENTORY.md`
- `docs/architecture/03_TABLE_COLUMN_SPECIFICATIONS.md`
- `supabase/migrations/001_extensions.sql` through `017g_compliance_policies.sql`

Reason:
Doc02 states 207 active tables. Static migration extraction found 178 created tables and 0 undocumented extra tables. The missing 29 are active architecture tables, not removed tables.

Impact:
A clean database from migrations 001-017G does not implement the frozen architecture. CRUD, reporting, import/export, attachments, audit/CAS, workflow, notifications, generated documents, and period-close workflows cannot be built against the documented contract. Deferred FKs to `attachments`, `generated_documents`, and `export_jobs` also cannot be wired yet.

Required Fix:
Before CRUD, either implement the missing active tables in planned migrations or formally mark them as intentionally deferred in Doc02/Doc03/Doc10/backlog with a release boundary. If they remain active Phase 1 tables, they must be migrated.

### C-017H-2 - 12 implemented RLS-enabled tables have no policies

Severity: CRITICAL

Files:
- `supabase/migrations/016_pre_rls_security_constraints_patch.sql`
- `supabase/migrations/017a_rls_foundation.sql` through `017g_compliance_policies.sql`
- `docs/architecture/09_SECURITY_RLS_DESIGN.md`

Tables:
`approval_matrix_steps`, `atp_usage_logs`, `cas_registrations`, `chart_of_accounts`, `company_bank_accounts`, `company_compliance_profiles`, `company_feature_settings`, `document_controls`, `exchange_rates`, `fiscal_locks`, `system_parameters`, `user_department_access`

Reason:
All 12 tables have RLS enabled, but no 017 policy references them. With Supabase RLS, authenticated application users get deny-all unless a policy exists.

Impact:
This is secure by default, but CRUD cannot use these tables. The most damaging misses are `chart_of_accounts`, `company_compliance_profiles`, and `company_feature_settings`, because they drive posting, reporting, tax behavior, and module visibility.

Required Fix:
Create a final RLS cleanup migration before CRUD that adds explicit policies for these 12 tables, following Doc09. Include SELECT and carefully gated INSERT/UPDATE where appropriate. Keep audit/immutable rows SELECT-only if needed.

### C-017H-3 - RLS does not enforce posted-document immutability for many line tables

Severity: CRITICAL

Files:
- `supabase/migrations/017d_sales_purchasing_policies.sql`
- `supabase/migrations/017e_assets_policies.sql`
- `docs/architecture/00_PXL_ARCHITECTURE_PRINCIPLES.md`
- `docs/architecture/09_SECURITY_RLS_DESIGN.md`

Reason:
017D and 017E give company-scoped UPDATE policies to line/non-status tables. Static block parsing confirmed these line tables do not carry a `status` column. Their policies therefore cannot deny edits after the parent header is posted, voided, reversed, cancelled, or completed.

Examples:
`sales_invoice_lines`, `cash_sale_lines`, `receipt_lines`, `vendor_bill_lines`, `cash_purchase_lines`, `payment_voucher_lines`, `purchase_order_lines`, `petty_cash_voucher_lines`, `stock_adjustment_lines`, `stock_transfer_lines`, `goods_issue_lines`, `physical_count_lines`

Impact:
An authenticated user with company access could directly update line rows through the Supabase API after posting unless the application layer prevents every path. That contradicts Principle 13 and can corrupt accounting, tax snapshots, inventory, and audit trails.

Required Fix:
Before CRUD, either remove authenticated UPDATE policies from immutable line tables or replace them with parent-path policies that check the parent header status. For draft-editable lines, updates must be allowed only while the parent is editable.

## B. High Issues

### H-017H-1 - Service-owned mutable columns remain writable through broad table UPDATE policies

Affected backlog items:
`M-008-2`, `M-009-1`, `M-011-3`, `L-011-1`, `M-014-1`

Reason:
Earlier instructions deferred column-level GRANT/REVOKE, but the current RLS policy layer still allows broad table UPDATE on some tables containing service-owned mutable values.

Examples:
- `purchase_order_lines.received_qty`, `purchase_order_lines.billed_qty`
- `petty_cash_funds.current_balance`
- `fixed_assets.accumulated_depreciation`, `fixed_assets.net_book_value`
- `asset_depreciation_schedules.status`
- `amortization_schedule_lines.status`, `journal_entry_id`
- `revenue_recognition_schedule_lines.status`, `journal_entry_id`

Impact:
Users can alter engine-owned balances or processing state unless application code catches every path. This can corrupt purchasing fulfillment, petty cash fund balances, fixed asset NBV, and schedule execution.

Required Fix:
Before CRUD, add service-role-only protection for engine-owned mutable fields. If column privileges are still deferred, split editable user fields from engine-owned tables at policy level or move updates behind Edge Functions.

### H-017H-2 - Audit/CAS tables are missing while compliance navigation and architecture expect them

Affected missing tables:
`audit_logs`, `field_change_history`, `user_activity_logs`, `system_parameter_logs`, `document_void_register`, `dat_generation_logs`, `export_history`, `system_alerts`

Impact:
The database cannot yet satisfy CAS auditability, DAT generation logging, void register traceability, field-change audit, or system alert workflows.

Required Fix:
Implement Audit/CAS migration before compliance CRUD and before any production-like posting workflow.

### H-017H-3 - Import/export/document output dependency tables are missing

Affected missing tables:
`import_batches`, `import_rows`, `import_validation_errors`, `import_templates`, `export_jobs`, `generated_report_files`, `document_templates`, `generated_documents`, `generated_document_versions`

Impact:
Columns already present in migrated tables refer conceptually to these tables, but their FK targets do not exist yet. Report generation, generated PDFs, BIR export jobs, and import traceability cannot be implemented from the current database.

Required Fix:
Implement import/export and document-output migrations, then wire deferred FKs.

## C. Medium Issues

### M-017H-1 - Backlog is stale after 017A-017G

Several backlog items remain OPEN even though 017A-017G partially or fully addressed them:
- `M-005-1` - `atc_codes` special RLS is implemented as stricter service-role-only writes in 017A.
- `M-010-1` - `inventory_cost_layers` is SELECT-only in 017E.
- `M-010-3` - `inventory_balances` is SELECT-only in 017E.
- `M-013-2` - `gl_balances` is SELECT-only in 017F.
- `M-013-3` - `subsidiary_ledger_entries` is SELECT-only in 017F.
- `M-015-1` - VAT/EWT/FWT/PT compliance ledgers are SELECT-only in 017G.

Required Fix:
Update backlog statuses to RESOLVED or PARTIALLY RESOLVED with exact migration references.

### M-017H-2 - Stale deferred-FK comment on `chart_of_accounts.import_batch_id`

File:
`supabase/migrations/004_core_setup.sql`

Reason:
The comment says the FK to `import_batches(id)` is deferred to Migration 010. Migration 010 is inventory, not import/export. Later migrations consistently refer to Migration 023 for `import_batches`.

Impact:
This can mislead the next migration author or reviewer.

Required Fix:
Correct the comment in a cleanup migration/comment patch or document it in the backlog. The FK target itself is still valid once `import_batches` exists.

### M-017H-3 - Compliance filing UPDATE policies do not check filing status

Files:
- `supabase/migrations/017g_compliance_policies.sql`
- `supabase/migrations/015_compliance.sql`

Reason:
User-managed compliance filing tables have UPDATE policies by company/permission, but tables with `filing_status` do not block direct edits when status is `filed`.

Impact:
Filed VAT, EWT, FWT, percentage tax, and ITR filing snapshots can be changed unless the application blocks them.

Required Fix:
Before compliance CRUD, add filing-status guards or route amendments through controlled service-role actions.

## D. Low Issues

1. `profiles` still lacks `deleted_by`; tracked as backlog `M-2`.
2. Several application-enforced invariants remain open: ATC series validation, tax-calendar period format, UOM inverse pairs, bank-statement match validity, inter-branch same-company validation.
3. Some comments need cleanup: `approval_matrix.approval_type`, `validation_rules.severity`, and journal-entry FK comments for selected purchasing adjustment tables.
4. `psql` is unavailable locally, so syntax was not verified by applying migrations to an empty PostgreSQL database in this audit.

## E. Architecture Mismatches

| Area | Finding | Severity |
|---|---|---|
| Active table count | Doc02/Doc03 active table count is 207; migrations create 178. | CRITICAL |
| RLS design | Doc09 examples include `company_compliance_profiles` and `company_feature_settings`, but neither has a policy. | CRITICAL |
| Immutability | Line-table UPDATE policies do not enforce parent status. | CRITICAL |
| Deferred FK comments | `chart_of_accounts.import_batch_id` points to the wrong future migration number. | MEDIUM |
| Backlog state | Some items resolved by 017A-017G are still OPEN. | MEDIUM |

## F. Missing Tables / Intentionally Deferred Tables

### Missing active Doc02 tables

Audit/CAS:
`audit_logs`, `field_change_history`, `user_activity_logs`, `system_parameter_logs`, `document_void_register`, `dat_generation_logs`, `export_history`, `system_alerts`

Attachments:
`attachments`, `attachment_versions`

Workflow/Approvals:
`approval_requests`, `approval_actions`

Import/Export:
`import_batches`, `import_rows`, `import_validation_errors`, `import_templates`, `export_jobs`, `generated_report_files`

Notifications:
`notification_templates`, `notifications`, `notification_delivery_logs`

Document Templates / Generated Output:
`document_templates`, `generated_documents`, `generated_document_versions`

Period Close:
`period_close_checklists`, `period_close_tasks`, `subledger_close_certifications`

Party Duplicate Management:
`duplicate_tin_flags`, `party_merge_logs`

### Intentionally removed / reserved tables

These are documented and are not blockers:
`financial_statement_mappings`, `mcit_computations`, `nolco_schedules`, and reserved slots `#193-#198`.

## G. Missing Columns / Intentionally Deferred Columns

Known missing or deferred items:
- `profiles.deleted_by` is missing and tracked in backlog `M-2`.
- FK targets to `attachments`, `generated_documents`, and `export_jobs` are deferred until their modules exist.
- `chart_of_accounts.import_batch_id` and other `import_batch_id` columns are structurally present but FK wiring awaits `import_batches`.
- `fixed_assets.status` is not present; decision log accepts the Doc03 boolean pattern (`is_active`, `is_disposed`) and backlog tracks Doc06 wording reconciliation.

No undocumented extra migration tables were found.

## H. RLS Findings

PASS:
- 178/178 implemented tables have RLS enabled.
- No DELETE policies exist in 017A-017G.
- Global lookup READ policies are limited to `account_types`, `currencies`, `permissions`, and `atc_codes`.
- Service-role-only ledgers/outputs in 017E, 017F, and 017G use SELECT-only patterns.
- Helper functions use `SECURITY DEFINER`, `STABLE`, and explicit `search_path`.

FAIL:
- 12 implemented tables have no policy.
- Many line tables have UPDATE without parent-status immutability checks.
- Some engine-owned mutable fields remain writable through table-level UPDATE policies.
- Compliance filing rows can be updated after filing status unless application logic blocks it.

## I. Supabase Compatibility Findings

PASS:
- RLS enablement model is compatible with Supabase.
- Service role bypass assumption is correct for Supabase.
- Helper functions avoid RLS recursion by using SECURITY DEFINER and schema-qualified references.
- No unsupported column-level GRANT/REVOKE patterns were introduced in 017A-017G.

RISK:
- A clean-database migration run was not executed because `psql` is unavailable in this environment.
- Missing policies cause deny-all behavior on 12 implemented tables; this is safe but not CRUD-ready.
- Missing import/export/document/audit tables prevent wiring deferred FKs and storage/report features.

## J. Backlog Corrections Needed

Update backlog for completed RLS work:
- Mark `M-005-1` as RESOLVED or ACCEPTED STRICTER in 017A.
- Mark `M-010-1`, `M-010-3`, `M-013-2`, `M-013-3`, and `M-015-1` as RESOLVED where SELECT-only service-role patterns now exist.
- Keep `M-008-2`, `M-009-1`, `M-011-3`, `L-011-1`, and `M-014-1` OPEN because broad UPDATE policies still expose service-owned mutable state.

Add backlog items for:
- 29 active Doc02 tables missing from migrations.
- 12 implemented RLS-enabled tables without policies.
- Parent-status RLS guard missing on line/non-status transaction tables.
- Stale `chart_of_accounts.import_batch_id` deferral comment.
- Filing-status update guard for compliance filing tables.

## K. Decision Log Corrections Needed

1. Add a decision for the final 017 RLS batching outcome and the remaining cleanup boundary.
2. Update Decision 002 to reflect the implemented helper pattern: `auth.user_company_ids()` rather than `current_company_id()`.
3. Update Decision 007 to note that `inventory_cost_layers` is now SELECT-only for authenticated users in 017E.
4. Add a decision on parent-status enforcement for line-table RLS before CRUD.
5. Update the log footer; it still says last updated at Migration 016.

## L. Items That Must Be Fixed Before CRUD

1. Implement or explicitly defer the 29 missing active Doc02 tables.
2. Add RLS policies for the 12 implemented tables with no policy.
3. Fix parent-status immutability for transaction line/non-status tables.
4. Protect service-owned mutable columns and processing state from authenticated direct UPDATE.
5. Implement Audit/CAS tables before posting or compliance workflows are exposed.
6. Implement Import/Export and Document Output tables before export/report/attachment/document CRUD.
7. Update backlog and decision log so future readers do not repeat resolved debates or miss open blockers.
8. Run migrations 001-017G plus cleanup on a clean PostgreSQL/Supabase database.

## M. Items Safe To Defer

These are safe to defer if explicitly tracked and enforced in application code:
- UOM inverse pair automation.
- Tax-calendar period format DB CHECK.
- ATC WC/WI/WF series DB trigger.
- Personnel-to-auth user link.
- Inter-branch same-company trigger.
- Bank-statement polymorphic reference trigger.
- Generated annual 1604E/F tables, if quarterly records remain the Phase 1 source.
- Performance optimization of parent-path policies for low-volume child tables.

## N. Final Recommendation

Do not start CRUD yet.

Recommended cleanup sequence:

1. Create an RLS cleanup migration for the 12 missing-policy tables.
2. Add parent-status guarded UPDATE policies or remove UPDATE from immutable line tables.
3. Close service-owned mutable field exposure.
4. Decide whether Modules 20-28 are required before CRUD. If yes, implement them next. If no, update Doc02/Doc03/Doc10 and backlog to formally defer them.
5. Update backlog and decision log.
6. Run a clean Supabase migration test.

Final status:

NOT APPROVED - FOUNDATION CLEANUP REQUIRED BEFORE CRUD

