> [!WARNING]
> **STATUS: SUPERSEDED**
> DO NOT USE AS IMPLEMENTATION SOURCE
> Canonical Source: FOUNDATION_FREEZE_REPORT.md
# MIGRATION 018 IMPLEMENTATION SPECIFICATION

Repository: `PXLERP`
Branch reviewed: `main`
Reviewed commit: `54c7213559936618ae31841531f3264a8646cb6b`
Spec date: 2026-06-24
Mode: planning/specification only. No SQL, migration file, UI, CRUD, backend logic, backlog edit, decision-log edit, or architecture edit is implemented by this document.

## Executive Summary

Migration 018 is the Phase 1 foundation freeze preparation package. It must complete the database foundation before CRUD or UI work continues.

Current controlling decisions:

- Decision 016: all 207 documented active Phase 1 tables are required.
- Decision 016: the 29 missing documented tables must be created before CRUD/UI.
- Decision 016: Adaptive Workspace is non-negotiable.
- Decision 017: `feature_definitions` is approved as the canonical feature catalog.
- Decision 017: final Phase 1 active table target is 219 tables.
- Decision 017: feature visibility must be relational, not text-key-only.

Implementation verdict:

Migration 018 architecture is now complete enough to begin SQL implementation, provided the SQL follows this specification and remains split into reviewable files.

Migration 018 implementation may begin.

## 1. Final Implementation Order

### 018A - Missing Foundation Tables

Purpose:

Create the 29 missing documented Phase 1 tables from the frozen architecture set.

Scope:

- Audit/CAS
- Attachments
- Workflow/Approvals
- Import/Export
- Notifications
- Document Templates and Generated Output
- Period Close
- Party Duplicate Management

Why first:

These tables are canonical Phase 1 tables already documented in Doc02/Doc03/Doc07/Doc08. They are also FK targets for existing deferred relationships such as `import_batches`, `attachments`, `generated_documents`, and `export_jobs`. Creating them first closes the largest foundation gap and lets later migrations wire RLS and deferred FKs against real tables.

### 018B - Feature Catalog + Adaptive Workspace

Purpose:

Create `feature_definitions` and the 11 approved adaptive-workspace metadata tables.

Scope:

- `feature_definitions`
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

Why second:

Adaptive Workspace depends on the feature catalog to avoid free-text feature keys and fixed boolean expansion. It should be created after the core missing foundation tables but before policy work so RLS can cover all new tables in one policy pass.

### 018C - RLS Policies

Purpose:

Enable and complete RLS for all 41 new Migration 018 tables and the 12 existing RLS-enabled tables with no policies.

Scope:

- Policies for all 29 missing documented tables.
- Policies for `feature_definitions`.
- Policies for the 11 adaptive-workspace tables.
- Policies for existing no-policy tables:
  `approval_matrix_steps`, `atp_usage_logs`, `cas_registrations`, `chart_of_accounts`, `company_bank_accounts`, `company_compliance_profiles`, `company_feature_settings`, `document_controls`, `exchange_rates`, `fiscal_locks`, `system_parameters`, `user_department_access`.

Why third:

RLS policy work should happen after all new table names and FKs exist. Keeping it separate prevents policy review from being buried inside table-creation SQL.

### 018D - Security + Immutability Cleanup

Purpose:

Close the pre-CRUD security gaps found by the foundation review.

Scope:

- Parent-status guards for line tables.
- Service-owned mutable field protection.
- Filed-status guards for compliance filing tables.
- No authenticated DELETE policies unless explicitly documented.

Why fourth:

This cleanup depends on earlier 017 policies and the new 018 policy layer. It is safer to do after 018C so reviewers can compare old and new policy behavior directly.

### 018E - Verification

Purpose:

Provide final database checks for table count, table existence, RLS enablement, policy coverage, FK wiring, feature-catalog wiring, broad-policy detection, DELETE policy detection, and compliance immutability.

Why last:

Verification should run only after all tables, FKs, RLS policies, and cleanup changes exist. It is the foundation freeze gate.

## 2. Table Creation Order

All new tables below are ordered parent-first. No circular dependency blocks table creation.

| Seq | Table | Module | Dependencies | FK parents | FK children |
|---:|---|---|---|---|---|
| 1 | `audit_logs` | Audit/CAS | Existing company/user context | `companies`, `profiles` | `field_change_history` |
| 2 | `user_activity_logs` | Audit/CAS | Existing company/user context | `companies` nullable, `profiles` | None |
| 3 | `system_parameter_logs` | Audit/CAS | Existing company/user context | `companies`, `profiles` | None |
| 4 | `document_void_register` | Audit/CAS | Existing company/user/posting context | `companies`, `profiles`, optional `journal_entries` | None |
| 5 | `dat_generation_logs` | Audit/CAS | Existing fiscal year context | `companies`, `fiscal_years`, `profiles` | None |
| 6 | `export_history` | Audit/CAS | Existing fiscal period context | `companies`, `fiscal_periods`, `profiles` | None |
| 7 | `system_alerts` | Audit/CAS | Existing company/user context | `companies`, `profiles` | None |
| 8 | `attachments` | Attachments | Existing company context; polymorphic source | `companies` | `attachment_versions`; existing deferred attachment FKs |
| 9 | `approval_requests` | Workflow/Approvals | Existing approval matrix and requester context | `companies`, `approval_matrix`, `profiles` | `approval_actions` |
| 10 | `import_batches` | Import/Export | Existing company/user context | `companies`, `profiles` | `import_rows`, `import_validation_errors`; existing deferred `import_batch_id` FKs |
| 11 | `import_templates` | Import/Export | Existing company context | `companies` | None |
| 12 | `export_jobs` | Import/Export | Existing company/branch/user context | `companies`, `branches`, `profiles` | `generated_report_files`, `generated_documents`; existing deferred export FKs |
| 13 | `notification_templates` | Notifications | Existing company context | `companies` | `notifications` |
| 14 | `document_templates` | Document Output | Existing company context | `companies` | `generated_documents` |
| 15 | `period_close_checklists` | Period Close | Existing fiscal period context | `companies`, `fiscal_periods`, `profiles` | `period_close_tasks` |
| 16 | `subledger_close_certifications` | Period Close | Existing fiscal period/user context | `companies`, `fiscal_periods`, `profiles` | None |
| 17 | `duplicate_tin_flags` | Party Duplicate Management | Existing company/user context | `companies`, `profiles` | None |
| 18 | `party_merge_logs` | Party Duplicate Management | Existing company/user context; polymorphic parties | `companies`, `profiles` | None |
| 19 | `field_change_history` | Audit/CAS | Parent audit event exists | `companies`, `profiles`, `audit_logs` | None |
| 20 | `attachment_versions` | Attachments | Parent attachment exists | `companies`, `attachments`, `profiles` | None |
| 21 | `approval_actions` | Workflow/Approvals | Parent approval request exists | `companies`, `approval_requests`, `profiles` | None |
| 22 | `import_rows` | Import/Export | Parent import batch exists | `companies`, `import_batches` | `import_validation_errors` |
| 23 | `generated_report_files` | Import/Export | Parent export job exists | `companies`, `export_jobs`, `profiles` | None |
| 24 | `notifications` | Notifications | Notification template optional; recipient exists | `companies`, `profiles`, optional `notification_templates` | `notification_delivery_logs` |
| 25 | `generated_documents` | Document Output | Template/export context exists | `companies`, `document_templates`, optional `export_jobs`, `profiles` | `generated_document_versions`; existing deferred generated document FKs |
| 26 | `period_close_tasks` | Period Close | Parent close checklist exists | `companies`, `period_close_checklists`, `profiles` | Optional application linkage to `subledger_close_certifications` |
| 27 | `import_validation_errors` | Import/Export | Parent batch and row exist | `companies`, `import_batches`, `import_rows` | None |
| 28 | `notification_delivery_logs` | Notifications | Parent notification exists | `companies`, `notifications` | None |
| 29 | `generated_document_versions` | Document Output | Parent generated document exists | `companies`, `generated_documents`, `profiles` | None |
| 30 | `workspace_modules` | Feature Catalog / Adaptive Workspace | None | None or existing system metadata only | `feature_definitions`, `workspace_categories`, `workspace_pages`, `workspace_dashboards`, `workspace_reports`, `workspace_items`, `company_feature_visibility`, `user_workspace_preferences` |
| 31 | `feature_definitions` | Feature Catalog / Adaptive Workspace | `workspace_modules` exists for optional module link | Optional `workspace_modules`, self via nullable `parent_feature_id` | `workspace_pages`, `workspace_dashboards`, `workspace_reports`, `dashboard_widgets`, `workspace_definitions`, `company_feature_visibility` |
| 32 | `workspace_categories` | Adaptive Workspace | Parent module exists | `workspace_modules` | `workspace_pages`, `workspace_dashboards`, `workspace_reports`, `workspace_items`, `company_feature_visibility`, `user_workspace_preferences` |
| 33 | `workspace_definitions` | Adaptive Workspace | Feature catalog exists for optional feature gate | Optional `companies`, optional `feature_definitions` | `workspace_items`, `role_workspace_assignments`, `company_feature_visibility`, `user_workspace_preferences` |
| 34 | `workspace_pages` | Adaptive Workspace | Module/category/permission/feature parents exist | `workspace_modules`, `workspace_categories`, optional `permissions`, optional `feature_definitions` | `workspace_items`, `company_feature_visibility`, `user_workspace_preferences` |
| 35 | `workspace_dashboards` | Adaptive Workspace | Module/category/permission/feature parents exist | `workspace_modules`, `workspace_categories`, optional `permissions`, optional `feature_definitions` | `dashboard_widgets`, `workspace_items`, `company_feature_visibility`, `user_workspace_preferences` |
| 36 | `workspace_reports` | Adaptive Workspace | Module/category/permission/feature parents exist | `workspace_modules`, `workspace_categories`, optional `permissions`, optional `feature_definitions` | `workspace_items`, `company_feature_visibility`, `user_workspace_preferences` |
| 37 | `dashboard_widgets` | Adaptive Workspace | Parent dashboard exists | `workspace_dashboards`, optional `permissions`, optional `feature_definitions` | `company_feature_visibility`, `user_workspace_preferences` if widget preferences are enabled |
| 38 | `workspace_items` | Adaptive Workspace | Workspace and target metadata exist | `workspace_definitions`; exactly one target FK to module/category/page/dashboard/report | None |
| 39 | `company_feature_visibility` | Adaptive Workspace | Feature and target metadata exist | `companies`, `feature_definitions`; optional exact-one target FK | None |
| 40 | `role_workspace_assignments` | Adaptive Workspace | Role and workspace exist | `companies`, `roles`, `workspace_definitions` | None |
| 41 | `user_workspace_preferences` | Adaptive Workspace | User/company and target metadata exist | `companies`, `profiles`; optional exact-one target FK | None |

### Circular Dependency Check

No blocking circular dependencies exist.

- `feature_definitions.parent_feature_id` is a nullable self-reference and does not require another table.
- `workspace_definitions.required_feature_id` depends on `feature_definitions`; `feature_definitions` does not depend on `workspace_definitions`.
- `company_feature_visibility` depends on `feature_definitions` and workspace targets; no workspace target depends on `company_feature_visibility`.
- `generated_documents` depends on `document_templates` and optional `export_jobs`; `export_jobs` does not depend on `generated_documents`.
- Polymorphic references remain intentionally unenforced by FK and do not create cycles.

## 3. Feature Catalog Review

`feature_definitions` is approved and required.

Required columns:

- `feature_code`
- `feature_name`
- `description`
- `feature_group`
- `parent_feature_id`
- `module_id`
- `is_system`
- `is_active`
- `default_enabled`
- `sort_order`
- standard audit columns

Capability validation:

| Requirement | Result | Basis |
|---|---|---|
| Future modules | Supported | New modules can insert `workspace_modules` and `feature_definitions` rows. |
| Future reports | Supported | `workspace_reports.required_feature_id` links reports to canonical feature rows. |
| Future dashboards | Supported | `workspace_dashboards.required_feature_id` links dashboards to canonical feature rows. |
| Future widgets | Supported | `dashboard_widgets.required_feature_id` links widgets to canonical feature rows. |
| Future workspaces | Supported | `workspace_definitions.required_feature_id` can gate workspaces. |
| Company visibility | Supported | `company_feature_visibility.feature_id` references `feature_definitions.id`. |
| Role visibility | Supported | Role visibility is derived from `roles`, `role_permissions`, and `role_workspace_assignments`; no hardcoded role list is required. |
| User preferences | Supported | `user_workspace_preferences` can only reduce or arrange visible items after feature/company/role checks pass. |
| No new boolean columns | Supported | Future features are added as rows, not as new `*_enabled` columns. |

Implementation improvements to preserve:

- Add uniqueness on `feature_code` among active system/global features.
- Keep `parent_feature_id` nullable and self-referential.
- Keep `module_id` nullable so cross-module features can exist.
- Treat `default_enabled` as a default only; company-specific enablement belongs in `company_feature_visibility`.
- Do not use free-text `required_feature_key` in backend, UI, or RLS logic.
- Keep `company_feature_settings` as high-level setup flags only; it is not the canonical feature catalog.

No feature-catalog blocker remains after Decision 017.

## 4. Adaptive Workspace Review

Navigation can be fully metadata-driven if the implementation follows this spec.

| No-hardcode rule | Validation |
|---|---|
| No hardcoded modules | `workspace_modules` is the module registry. |
| No hardcoded categories | `workspace_categories` is the category registry. |
| No hardcoded pages | `workspace_pages` is the routeable page registry. |
| No hardcoded reports | `workspace_reports` is the report registry. |
| No hardcoded dashboards | `workspace_dashboards` is the dashboard registry. |
| No hardcoded widgets | `dashboard_widgets` is the widget registry. |
| No hardcoded workspaces | `workspace_definitions` and `workspace_items` define workspaces and contents. |
| No hardcoded feature visibility | `feature_definitions` plus `company_feature_visibility` define feature visibility. |
| No hardcoded role visibility | `roles`, `role_permissions`, and `role_workspace_assignments` define role visibility. |
| No hardcoded approval routing | Existing `approval_matrix` and `approval_matrix_steps`, plus new `approval_requests` and `approval_actions`, define approval routing and runtime history. |

Remaining hardcoded architecture:

- The current frontend shell may still contain static navigation, but it is not the canonical future implementation contract.
- Existing architecture docs still contain historical references to `company_feature_settings.*_enabled` flags. Decision 017 supersedes those references for Adaptive Workspace. These flags may remain as high-level setup flags but must not become the only feature catalog.

No remaining hardcoded-architecture blocker exists for Migration 018 SQL if `feature_definitions`, `required_feature_id`, and `company_feature_visibility.feature_id` are implemented.

## 5. Requirement Traceability Review

Traceability chain:

Business Requirement -> Architecture -> Table -> Migration -> RLS -> Backend -> UI -> Posting -> Report -> Test -> Documentation.

### Table Group Traceability

| Table group | Business requirement | Architecture source | Table layer | Migration layer | RLS layer | Backend/UI/Posting/Report/Test/Docs status |
|---|---|---|---|---|---|---|
| Audit/CAS | CAS auditability, field changes, voids, DAT/export accountability, system alerts | Doc02, Doc03, Doc07 | 8 tables in 018A | Create in 018A | Policies in 018C | Downstream services, screens, reports, tests, and user docs must use these as audit source of truth. |
| Attachments | Evidence files and version history | Doc02, Doc03, Doc08 | 2 tables in 018A | Create in 018A | Policies in 018C | Backend storage service and UI attachment panels must use these metadata records. |
| Workflow/Approvals | Runtime approval lifecycle and immutable action history | Doc02, Doc03, Doc07, Doc09 | 2 tables in 018A | Create in 018A | Policies in 018C | Backend approval service and UI approval inbox must use request/action records. |
| Import/Export | Import traceability, async export jobs, generated report files | Doc02, Doc03, Doc08 | 6 tables in 018A | Create in 018A | Policies in 018C | Import/export services, report job UI, tests, and docs must use these records. |
| Notifications | Approval/system notification delivery | Doc02, Doc03, Doc09, Doc10 | 3 tables in 018A | Create in 018A | Policies in 018C | Notification service and UI notification center must use these rows. |
| Document output | Templates, generated documents, document versions | Doc02, Doc03, Doc08 | 3 tables in 018A | Create in 018A | Policies in 018C | Document generation service, UI print/download, report exports, tests, and docs must use these rows. |
| Period close | Period-close process control and subledger certification | Doc02, Doc03 | 3 tables in 018A | Create in 018A | Policies in 018C | Close service, controller UI, close reports, tests, and docs must use these records. |
| Party duplicate management | Duplicate TIN flags and merge audit history | Doc02, Doc03 | 2 tables in 018A | Create in 018A | Policies in 018C | Party merge service, data quality UI, reports, tests, and docs must use these records. |
| Feature catalog | Canonical feature identity and future enablement | Decision 017, design plan | `feature_definitions` in 018B | Create in 018B | Policies in 018C | Backend, UI, RLS checks, reports, tests, and docs must resolve feature visibility through this table. |
| Adaptive workspace | Metadata-driven navigation, reports, dashboards, widgets, workspaces, visibility, preferences | Decision 016, Decision 017, design plan | 11 tables in 018B | Create in 018B | Policies in 018C | Backend workspace service and UI navigation must use metadata, not hardcoded lists. |
| Security cleanup | Prevent direct mutation of posted lines, service-owned fields, and filed compliance rows | Principles, Doc09, certification report | Existing tables | Cleanup in 018D | Policy/privilege cleanup in 018D | Backend services must preserve service-owned writes; tests must prove direct API mutation is blocked. |
| Verification | Foundation freeze confidence | Design plan, backlog | All tables and policies | Verification in 018E | Verification in 018E | Test evidence must be retained before CRUD/UI starts. |

Missing traceability links:

- No architecture blocker remains.
- Backend services, UI forms, posting integration, reports, tests, and user documentation are not yet implemented, but that is expected after database foundation freeze.
- The requirement for those downstream artifacts is now traceable to concrete tables and planned Migration 018 files.

## 6. Low Maintenance Review

### Review Result

No low-maintenance blocker remains if Migration 018 follows the split and table contracts in this spec.

| Principle | Result | Notes |
|---|---|---|
| Configurable | Pass | Workspace, feature, role, report, dashboard, and visibility behavior are metadata-driven. |
| No hardcoded values | Pass | Feature gates use `feature_definitions.id`; roles use role/permission tables. |
| Multi-company | Pass | Company-scoped tables include `company_id`; global metadata is filtered through company visibility. |
| Multi-branch | Pass | Branch-specific behavior is supported through existing branches/access and target tables where branch is relevant. Global workspace metadata remains branch-neutral by design. |
| RLS compatible | Pass | Every new table must have RLS enabled and policies in 018C. |
| Audit friendly | Pass | Standard audit columns plus `audit_logs` and `field_change_history` provide audit structure. |
| Posting traceable | Pass | Approval, generated document, audit, import/export, close, and cleanup tables preserve posting evidence and immutability. |
| Report traceable | Pass | `workspace_reports`, `export_jobs`, `generated_report_files`, and audit/export logs provide report traceability. |
| Can be hidden | Pass | Workspace and feature visibility can hide UI/report/dashboard/workspace surfaces. Control tables remain available for compliance even if their UI surfaces are hidden. |
| Can be disabled | Pass | `feature_definitions.is_active`, `default_enabled`, and `company_feature_visibility` support disablement without new columns. |
| Can be enabled later without refactoring | Pass | New features are inserted as feature/workspace metadata rows. |

Violations:

- None blocking.

Guardrails:

- Do not add new boolean columns for future modules.
- Do not store feature visibility only in `company_feature_settings`.
- Do not use free-text feature keys as the runtime visibility contract.
- Do not allow user preferences to grant access.
- Do not expose authenticated UPDATE on posted lines, engine-owned fields, or filed compliance rows.

## 7. Final Foundation Gate

Question:

Is Migration 018 architecture now complete enough to begin SQL implementation?

Answer:

YES.

The previous NO-GO blocker was the missing normalized feature catalog. Decision 017 approved `feature_definitions`, the Migration 018 design plan now includes it, feature visibility is relational, and the final Phase 1 target is 219 active tables.

Migration 018 implementation may begin.

Conditions for implementation:

- Follow the 018A to 018E split exactly.
- Create only the planned foundation tables and policies.
- Do not create CRUD, UI, seed data, views, cron jobs, or backend services in Migration 018.
- Keep polymorphic references intentionally unenforced unless the architecture already declares a real FK.
- Keep service-owned writes behind service role, Edge Functions, or tested privilege hardening.
- Do not start CRUD/UI until 018E verification passes.

## Appendix A - 018A Scope Checklist

- Create 29 missing documented Phase 1 tables.
- Add parent-child FKs among those tables.
- Wire existing deferred FKs where targets now exist:
  - `import_batches`
  - `attachments`
  - `generated_documents`
  - `export_jobs`
- Enable RLS on the 29 tables.
- Avoid broad policies in this file if policies are handled in 018C.

## Appendix B - 018B Scope Checklist

- Create `workspace_modules`.
- Create `feature_definitions`.
- Create the 11 adaptive-workspace metadata tables.
- Use `required_feature_id` instead of `required_feature_key`.
- Add `company_feature_visibility.feature_id`.
- Add exact-one-target CHECK constraints for polymorphic workspace target patterns where real FKs are used.
- Enable RLS on all 12 tables.

## Appendix C - 018C Scope Checklist

- Add RLS policies for all 41 new tables.
- Add RLS policies for the 12 existing no-policy tables.
- Use authenticated read for appropriate global/system metadata.
- Use company-scoped access for company rows.
- Use own-user policies for user preferences and personal notifications.
- Do not create authenticated DELETE policies unless explicitly required.
- Do not use broad `USING (true)` outside true global lookup/system metadata cases.

## Appendix D - 018D Scope Checklist

- Replace broad line UPDATE policies with parent-status-guarded policies.
- Remove authenticated UPDATE from line/runtime tables that should be immutable.
- Protect service-owned mutable fields.
- Add filed-status guards on compliance filing tables.
- Verify service role remains able to perform posting and compliance workflows.

## Appendix E - 018E Scope Checklist

- Verify final public base table count is 219.
- Verify all 41 Migration 018 tables exist.
- Verify all public tables have RLS enabled.
- Verify policies exist for all 41 new tables.
- Verify policies exist for the 12 existing no-policy tables.
- Verify feature gating is FK-backed through `feature_definitions`.
- Verify `company_feature_visibility.feature_id` exists and is enforced.
- Verify no unintended DELETE policies exist.
- Verify broad global policies are limited to approved metadata/lookup cases.
- Verify deferred FKs to `import_batches`, `attachments`, `generated_documents`, and `export_jobs` are wired.
- Verify compliance filed rows cannot be updated by ordinary authenticated policies.
- Verify line table updates are parent-status guarded or removed.

