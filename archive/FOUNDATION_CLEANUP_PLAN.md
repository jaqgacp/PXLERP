> [!WARNING]
> **STATUS: SUPERSEDED**
> DO NOT USE AS IMPLEMENTATION SOURCE
> Canonical Source: FOUNDATION_FREEZE_REPORT.md
# PXL ERP - Foundation Cleanup Plan

Source reviewed: `FOUNDATION_CERTIFICATION_REPORT.md`  
Plan date: 2026-06-23  
Scope: planning/documentation only; no code, migration, architecture, backlog, decision-log, UI, or feature changes.

# Executive Summary

The certification report shows a strong implemented foundation, but it is not yet clean enough for CRUD because security and immutability gaps remain. The smallest clean foundation for initial CRUD is not "all 207 documented tables." It is the current 178-table core plus final RLS cleanup, transaction immutability cleanup, service-owned field protection, clean migration verification, and an explicit phase boundary for tables that are not needed by first CRUD screens.

The 29 missing Doc02/Doc03 tables are not all objectively required before CRUD. They are mostly cross-cutting or later workflow modules: Audit/CAS, attachments, workflow approvals, import/export, notifications, generated documents, period close, and party duplicate management. They become blockers only if they remain marked as active Phase 1 database-freeze tables. The clean recommendation is to formally move them into Phase 1B, pre-production, pre-compliance, or Phase 2 buckets unless a specific CRUD workflow needs them immediately.

Recommended foundation boundary:

- Phase 1A CRUD foundation: existing migrated core tables, final RLS cleanup, line immutability cleanup, service-owned field protection, and clean database migration test.
- Phase 1B pre-production/compliance: Audit/CAS, export logs, generated documents, attachment storage contracts, and period-close support.
- Later workflow modules: notifications, duplicate-party management, full approval action history, and bulk import/export management if not required by the first CRUD build.

# MUST FIX BEFORE CRUD

| Finding | Reason | Recommended Action | Priority | Estimated Impact |
|---|---|---|---|---|
| 12 implemented RLS-enabled tables have no policies: `approval_matrix_steps`, `atp_usage_logs`, `cas_registrations`, `chart_of_accounts`, `company_bank_accounts`, `company_compliance_profiles`, `company_feature_settings`, `document_controls`, `exchange_rates`, `fiscal_locks`, `system_parameters`, `user_department_access`. | RLS is enabled, so authenticated users get deny-all. Core screens for chart of accounts, compliance setup, feature settings, bank accounts, and document controls will fail or be forced into unsafe service-role access. | Add a final RLS cleanup migration with explicit SELECT and carefully scoped INSERT/UPDATE policies where appropriate. Keep true logs or system-owned tables SELECT-only if they should not be user-mutated. | P0 | High. Unblocks setup, security, accounting, compliance configuration, and first CRUD screens. |
| Transaction line/non-status tables have company-scoped UPDATE policies without parent status guards. | Lines do not carry their own status, so current policies cannot stop edits after a parent document is posted, voided, reversed, cancelled, or completed. | Replace broad line UPDATE policies with parent-path guarded policies, or remove authenticated UPDATE on immutable line tables. Draft-editable lines must check parent status. | P0 | High. Prevents direct API mutation of posted accounting, tax, purchasing, sales, petty cash, and inventory detail rows. |
| Service-owned mutable fields remain writable through broad table UPDATE policies. | Fields such as received/billed quantities, current balances, accumulated depreciation, NBV, schedule status, and generated journal links are engine-owned state. Broad user UPDATE can corrupt balances and processing status. | Protect these fields before exposing CRUD. Use a tested pattern: service-role-only update path, policy split by table/state, Edge Function writes, or column-level privileges after Supabase testing. | P0 | High. Prevents users from altering values that should only be changed by posting, receiving, depreciation, amortization, or recognition engines. |
| Compliance filing UPDATE policies do not check `filing_status`. | Filed VAT/EWT/FWT/PT/ITR snapshots should not be directly editable through ordinary authenticated UPDATE. | Add filing-status guards so filed rows are immutable, or require controlled amendment/reversal service-role actions. | P1 | Medium to high. Prevents accidental or direct mutation of filed compliance records. |
| Clean PostgreSQL/Supabase migration run has not been executed. | Static review found no obvious syntax blockers, but the certification report confirms `psql` was unavailable. Syntax, ordering, RLS, function, and policy problems can still appear only during a clean apply. | Run migrations 001 through 017G plus the cleanup migrations on an empty Supabase/PostgreSQL database before CRUD starts. | P0 | High. Confirms the database can actually be created from zero and avoids building UI on an unverified migration chain. |

# SAFE TO DEFER

| Finding | Reason | Recommended Action | Priority | Estimated Impact |
|---|---|---|---|---|
| Audit/CAS tables are missing: `audit_logs`, `field_change_history`, `user_activity_logs`, `system_parameter_logs`, `document_void_register`, `dat_generation_logs`, `export_history`, `system_alerts`. | These are not required to render basic setup/master/transaction draft CRUD, but they are required before production posting, compliance export, CAS audit trail, DAT generation logging, and void-register workflows. | Defer from initial CRUD only if formally moved to Phase 1B/pre-production. Implement before any production-like posting, compliance export, or CAS workflow is exposed. | P1 | Medium for CRUD, high before production/compliance. |
| Attachment tables are missing: `attachments`, `attachment_versions`. | File upload is useful but not required for first CRUD if screens do not expose attachment behavior and deferred FKs remain unwired. | Defer until the attachment feature is scheduled. Keep any attachment-dependent UI hidden until the tables and storage policy exist. | P2 | Low to medium. Allows CRUD to start, but blocks document evidence upload. |
| Workflow approval history tables are missing: `approval_requests`, `approval_actions`. | Basic CRUD can begin with document statuses and role permissions, provided formal approval routing is not exposed. | Defer until approval workflow is implemented. Do not build screens that promise approval request/action audit history before these tables exist. | P2 | Medium. Blocks formal approval workflows, not basic CRUD. |
| Import/export tables are missing: `import_batches`, `import_rows`, `import_validation_errors`, `import_templates`, `export_jobs`, `generated_report_files`. | Bulk import/export and generated report tracking are separate workflow surfaces. Existing import-batch columns can remain structurally present without FK wiring until this module exists. | Defer from CRUD, then implement before bulk import, BIR export job management, generated report files, or deferred FK wiring. | P2 | Medium. Blocks import/export/report job features, not ordinary row CRUD. |
| Notification tables are missing: `notification_templates`, `notifications`, `notification_delivery_logs`. | Notifications are not required for database CRUD if the first release can operate without in-app/email delivery history. | Defer to a notification module. Avoid UI badges, delivery logs, or automated notification promises until implemented. | P3 | Low for CRUD. |
| Document template/output tables are missing: `document_templates`, `generated_documents`, `generated_document_versions`. | CRUD can store source transactions without generated PDF/version history if document-generation workflows remain deferred. | Defer until printable/document-output workflows are in scope. Implement before generated invoices, vouchers, forms, or document-version audit trails are exposed. | P2 | Medium. Blocks generated document output, not source CRUD. |
| Period close support tables are missing: `period_close_checklists`, `period_close_tasks`, `subledger_close_certifications`. | First CRUD can proceed before month-end close workflow exists, as long as close screens are not exposed. | Defer until close process implementation. Implement before period-close operations, close task tracking, or subledger certification are enabled. | P2 | Medium. Blocks close workflow, not daily CRUD. |
| Party duplicate management tables are missing: `duplicate_tin_flags`, `party_merge_logs`. | Duplicate detection and merge audit are data-quality workflows, not required to create basic customer/supplier records if validation remains simpler. | Defer until duplicate management is in scope. Use basic TIN uniqueness/validation already present or application checks in the interim. | P3 | Low to medium. Blocks controlled merge history, not basic master data CRUD. |
| `profiles.deleted_by` is missing. | Soft-delete actor tracking is useful but not required if profile deletion is disabled or handled administratively during first CRUD. | Keep tracked as a later cleanup unless profile deletion is exposed. If profile deletion is in first CRUD, add it before that screen ships. | P2 | Low unless user/profile deletion is in scope. |
| ATC WC/WI/WF series validation remains application-enforced. | This is a validation hardening item rather than a table or RLS blocker. | Keep application validation until a DB-level validation task is scheduled. | P3 | Low for CRUD, medium for tax setup accuracy if app validation is weak. |
| Tax-calendar period-format CHECK remains deferred. | Period format can be validated by application logic during initial CRUD. | Keep deferred if app validation is explicit; add DB CHECK before production compliance workflows if needed. | P3 | Low to medium. |
| UOM inverse-pair automation remains deferred. | UOM conversion maintenance can start with app-level validation and manual review. | Defer DB automation; require app validation or admin review for UOM conversion CRUD. | P3 | Low to medium. |
| Personnel-to-auth user link remains deferred. | Personnel master data can exist without every employee being an authenticated user. | Defer until HR-user account linkage is needed. | P3 | Low. |
| Inter-branch same-company trigger remains deferred. | App logic can prevent invalid branch pairings during first CRUD. | Defer trigger if branch transfer screens enforce same-company validation. | P2 | Medium if transfer CRUD is exposed early. |
| Bank-statement polymorphic reference validation remains deferred. | Reconciliation can start with controlled references if the UI restricts selectable targets. | Defer DB trigger; enforce valid target references in reconciliation UI/service layer until DB hardening. | P2 | Medium for bank reconciliation accuracy. |
| Generated annual 1604E/F tables are deferred. | The report accepts quarterly records as Phase 1 source if annual generation is derived later. | Keep deferred unless annual 1604E/F persistence is required by first compliance workflow. | P3 | Low for CRUD, medium for annual compliance reporting. |
| Parent-path policy performance optimization is deferred. | Low-volume child policies are acceptable for initial correctness; performance tuning is not a CRUD blocker. | Defer until load testing shows a real bottleneck. | P3 | Low. |

# DOCUMENTATION CLEANUP

| Finding | Reason | Recommended Action | Priority | Estimated Impact |
|---|---|---|---|---|
| Doc02/Doc03 define 207 active tables, but migrations create 178; 29 active tables are missing. | Special review conclusion: the missing 29 are not all required for the first CRUD foundation. The blocker is the documentation contract, not the immediate absence of every table. | Update architecture freeze documents later to clearly label these tables as Phase 1B, pre-production, pre-compliance, or Phase 2. If any table is kept as Phase 1A active, migrate it before CRUD. | P0 | High. Prevents Claude, Codex, or a developer from building against non-existent "active" tables or treating deferred modules as freeze blockers. |
| The Phase 1 boundary is ambiguous for Audit/CAS, import/export, generated documents, attachments, approvals, notifications, period close, and duplicate-party management. | The certification report mixes core CRUD blockers with later workflow dependencies. | Add a table-by-table release boundary in the architecture set when architecture edits are allowed. | P0 | High. Creates a clean implementation map and reduces repeated audit churn. |
| Stale deferred-FK comment on `chart_of_accounts.import_batch_id` points to Migration 010 instead of the later import/export migration. | Migration 010 is inventory; this can mislead the next migration author. | Correct or explicitly document the correct future import/export migration target when cleanup edits are allowed. | P2 | Low to medium. Prevents wrong assumptions during import/export FK wiring. |
| Comment cleanup is needed for `approval_matrix.approval_type`, `validation_rules.severity`, and selected purchasing adjustment journal-entry FK comments. | The report identifies comment drift that can confuse implementers even if schema behavior is intact. | Clean comments in a documentation/comment-only pass or track exact fixes in backlog. | P3 | Low. Reduces implementation ambiguity. |
| `fixed_assets.status` wording remains reconciled by decision rather than schema. | The report says the Doc03 boolean pattern is accepted, but wording elsewhere can continue causing false blockers. | Ensure the architecture docs consistently refer to `is_active` and `is_disposed` instead of implying a missing `status` column. | P3 | Low. Prevents repeat audit noise. |

# BACKLOG / DECISION LOG CLEANUP

| Finding | Reason | Recommended Action | Priority | Estimated Impact |
|---|---|---|---|---|
| Backlog is stale after 017A-017G. | Items implemented by RLS migrations remain OPEN or unclear. | Mark `M-005-1`, `M-010-1`, `M-010-3`, `M-013-2`, `M-013-3`, and `M-015-1` as resolved or accepted-stricter with exact migration references. | P1 | Medium. Prevents repeated rework and false blockers. |
| Service-owned mutable field backlog items must remain open. | The report confirms broad UPDATE exposure still exists. | Keep `M-008-2`, `M-009-1`, `M-011-3`, `L-011-1`, and `M-014-1` open until the protection pattern is implemented and tested. | P1 | High. Keeps real data-integrity risks visible. |
| Backlog lacks explicit items for the final cleanup blockers. | Future work can be missed if it only lives in the certification report. | Add backlog items for 12 no-policy tables, line parent-status guards, compliance filing-status guards, stale FK comment, and the 29-table phase boundary. | P1 | High. Converts audit findings into executable cleanup tasks. |
| Decision log lacks final 017 RLS batching outcome and remaining cleanup boundary. | Future reviewers need to know what 017A-017G did and what remains deliberately out of scope. | Add a decision summarizing the 017A-017G RLS split, completed scope, and cleanup boundary. | P1 | Medium. Keeps later Claude/Codex runs oriented. |
| Decision 002 references the older helper pattern instead of `auth.user_company_ids()`. | The implemented helper pattern changed during RLS work. | Update Decision 002 when decision-log edits are allowed. | P2 | Medium. Prevents future policies from using an obsolete helper model. |
| Decision 007 does not reflect that `inventory_cost_layers` is SELECT-only in 017E. | The implemented security posture is stricter than the older decision text. | Update Decision 007 to match 017E. | P2 | Low to medium. Prevents accidental policy widening later. |
| No decision exists for parent-status enforcement on line-table RLS. | This is now a core security/accounting requirement before CRUD. | Add a decision requiring parent-path guards or no authenticated UPDATE for line tables without their own status. | P1 | High. Establishes a durable rule for future RLS migrations. |
| Decision-log footer still says last updated at Migration 016. | The footer is stale after 017A-017G. | Update the footer when decision-log cleanup is allowed. | P3 | Low. Improves trust in the log. |

# Recommended Cleanup Order

1. Decide the Phase 1A CRUD boundary for the 29 missing tables. The recommended answer is: do not implement all 29 before CRUD; formally defer them unless a first CRUD workflow needs one directly.
2. Create the final RLS cleanup migration for the 12 implemented tables with no policy.
3. Fix transaction line immutability by adding parent-status guards or removing authenticated UPDATE where lines should be immutable.
4. Protect service-owned mutable fields and processing state from direct authenticated UPDATE.
5. Add compliance filing-status immutability before compliance CRUD.
6. Run a clean Supabase/PostgreSQL migration test from 001 through all cleanup migrations.
7. Update backlog and decision log so the cleanup boundary is visible to the next implementation agent.
8. Start CRUD only for modules whose tables and RLS policies are covered by the cleaned foundation.
9. Implement deferred modules in smaller batches only when their workflows become active: Audit/CAS, attachments, workflow approvals, import/export, generated documents, notifications, period close, and duplicate-party management.

# Foundation Readiness After Cleanup

Current readiness from the certification report remains below CRUD threshold because RLS and immutability blockers are real.

After the MUST FIX BEFORE CRUD items are closed and the documentation/backlog/decision cleanup is recorded, the foundation can become a clean Phase 1A CRUD foundation for setup, master data, transactions, accounting, assets, GL, and compliance tables already migrated.

The foundation should not be treated as production posting/compliance ready until Audit/CAS, export logging, generated document evidence, and any required attachment workflows are implemented or explicitly removed from the launch scope.

If the project chooses to keep all 207 Doc02/Doc03 tables inside the immediate Phase 1 database freeze, then the 29 missing tables remain migration blockers. If the project accepts the recommended Phase 1A/Phase 1B boundary, CRUD can proceed after the security and integrity cleanup without waiting for all 29 future-workflow tables.

