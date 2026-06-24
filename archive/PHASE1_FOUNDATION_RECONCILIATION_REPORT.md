> [!WARNING]
> **STATUS: SUPERSEDED**
> DO NOT USE AS IMPLEMENTATION SOURCE
> Canonical Source: FOUNDATION_FREEZE_REPORT.md
# PXL ERP - Final Phase 1 Foundation Reconciliation Report

Reviewed repository: `PXLERP`  
Reviewed branch: `main`  
Reviewed commit: `3002759b3fcd9560a53be01d95015b61ddb66562`  
Report date: 2026-06-24  
Scope: architecture, documentation, database design, migrations, RLS, navigation philosophy, and system capabilities.

This report is documentation-only. It does not create Migration 018, SQL, CRUD, UI, backlog edits, decision-log edits, or architecture edits.

## 1. Executive Summary

Phase 1 is not ready for CRUD/UI implementation.

The current foundation is strong for the migrated accounting, sales, purchasing, assets, GL, posting, compliance, setup, and master-data tables. However, the current state still fails the owner's final Phase 1 rule: Phase 1 is not split into Phase 1A and Phase 1B. Therefore, active foundation tables cannot be silently deferred.

The earlier `FOUNDATION_CLEANUP_PLAN.md` recommended a Phase 1A/Phase 1B boundary. That recommendation is superseded by the project owner's non-negotiable rule in this audit: all required Phase 1 foundation tables must exist before CRUD/UI continues.

Final reconciliation result:

- Canonical documented active tables: 207
- Migrated tables through 017G: 178
- Documented active tables missing from migrations: 29
- Undocumented migrated tables: 0, when Doc02 canonical registry and Doc03 are both considered
- Migrated tables with RLS enabled: 178/178
- Migrated tables with no 017 policy coverage: 12
- Additional adaptive-workspace foundation tables recommended before Migration 018: 11

Final recommendation:

Migration 018 should be a foundation reconciliation migration, not CRUD. It should complete the 29 missing documented Phase 1 tables, add adaptive-workspace metadata tables, enable RLS/policies for all new tables, add missing policies for the 12 migrated no-policy tables, and fix known policy integrity gaps before CRUD/UI begins.

## 2. Current Documented Table Count

Source of truth:

- `docs/architecture/02_COMPLETE_TABLE_INVENTORY.md`
- `docs/architecture/03_TABLE_COLUMN_SPECIFICATIONS.md`
- `docs/architecture/10_REVIEW_CHECKLIST.md`

Current documented count:

| Category | Count | Notes |
|---|---:|---|
| Canonical active Phase 1 tables | 207 | Doc02 registry and Doc03 state all 207 active tables have specs. |
| Removed tables | 3 | `financial_statement_mappings`, `mcit_computations`, `nolco_schedules`. |
| Total numbered slots before new adaptive-workspace additions | 210 | 207 active + 3 removed. |

Important reconciliation note:

`payment_term_lines` is not listed in the first Doc02 module grid, but it is active in the Doc02 canonical registry and specified in Doc03 Section 21. It is therefore documented and not an undocumented migrated table.

## 3. Current Migrated Table Count

Migrations reviewed:

- `001_extensions.sql` through `017g_compliance_policies.sql`

Current migrated count:

| Category | Count | Notes |
|---|---:|---|
| Tables created by migrations 001-017G | 178 | Static extraction from `CREATE TABLE public.*`. |
| Migrated tables with RLS enabled | 178 | No migrated table is missing RLS enablement. |
| Migrated tables with 017 policy coverage | 166 | 12 migrated tables remain RLS deny-all for authenticated users. |
| Migrated tables without documentation | 0 | `payment_term_lines` is documented in Doc02 registry/Doc03. |

## 4. Missing Documented Tables

Because Phase 1 is not split, all 29 active documented tables below are required before Migration 018 is considered complete unless the project owner formally removes them from Phase 1.

| Table | Module | Architecture Reference | Created? | RLS? | Policy? | Phase 1 Decision | Notes |
|---|---|---|---|---|---|---|---|
| `audit_logs` | Audit/CAS | Doc02 #159, Doc03, Doc07 | No | No | No | REQUIRED BEFORE MIGRATION 018 | CAS and audit event backbone. |
| `field_change_history` | Audit/CAS | Doc02 #160, Doc03, Doc07 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for field-level audit of BIR-reportable records. |
| `user_activity_logs` | Audit/CAS | Doc02 #161, Doc03, Doc07 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for login, report, export, print, and access traceability. |
| `system_parameter_logs` | Audit/CAS | Doc02 #162, Doc03, Doc07 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required to audit configuration changes. |
| `document_void_register` | Audit/CAS | Doc02 #163, Doc03, Doc07 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for BIR-traceable voids. |
| `dat_generation_logs` | Audit/CAS | Doc02 #164, Doc03, Doc07 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for DAT file generation traceability. |
| `export_history` | Audit/CAS | Doc02 #165, Doc03, Doc07 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for report/data export accountability. |
| `system_alerts` | Audit/CAS | Doc02 #166, Doc03, Doc07, Doc09 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for admin/controller operational alerts. |
| `attachments` | Attachments | Doc02 #167, Doc03, Doc08 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for evidence files and deferred FK wiring. |
| `attachment_versions` | Attachments | Doc02 #168, Doc03, Doc08 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for evidence version tracking. |
| `approval_requests` | Workflow/Approvals | Doc02 #169, Doc03 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for active approval workflow instances. |
| `approval_actions` | Workflow/Approvals | Doc02 #170, Doc03 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for approval action history. |
| `import_batches` | Import/Export | Doc02 #171, Doc03, Doc08 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for import traceability and deferred FK targets. |
| `import_rows` | Import/Export | Doc02 #172, Doc03, Doc08 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for row-level import results. |
| `import_validation_errors` | Import/Export | Doc02 #173, Doc03, Doc08 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for import error auditability. |
| `import_templates` | Import/Export | Doc02 #174, Doc03, Doc08 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Active in Phase 1 docs even if save/load behavior is limited. |
| `export_jobs` | Import/Export | Doc02 #175, Doc03, Doc08 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for async exports/reports and unified compliance export pattern. |
| `generated_report_files` | Import/Export | Doc02 #176, Doc03, Doc08 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for generated report file metadata. |
| `notification_templates` | Notifications | Doc02 #177, Doc03, Doc09 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for approval/system notification patterns. |
| `notifications` | Notifications | Doc02 #178, Doc03, Doc09 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for in-app notification delivery. |
| `notification_delivery_logs` | Notifications | Doc02 #179, Doc03 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for notification delivery traceability. |
| `document_templates` | Document Output | Doc02 #180, Doc03 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for generated document configuration. |
| `generated_documents` | Document Output | Doc02 #181, Doc03 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for persisted generated document records. |
| `generated_document_versions` | Document Output | Doc02 #182, Doc03 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Active in Phase 1 docs; required unless owner removes it. |
| `period_close_checklists` | Period Close | Doc02 #185, Doc03 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Active Phase 1 process-control table. |
| `period_close_tasks` | Period Close | Doc02 #186, Doc03 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Active Phase 1 close task table. |
| `subledger_close_certifications` | Period Close | Doc02 #187, Doc03 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for subledger close evidence. |
| `duplicate_tin_flags` | Party Duplicate Management | Doc02 #188, Doc03 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for duplicate party/TIN quality controls. |
| `party_merge_logs` | Party Duplicate Management | Doc02 #189, Doc03 | No | No | No | REQUIRED BEFORE MIGRATION 018 | Required for auditable party merges. |

## 5. Undocumented Migrated Tables

No undocumented migrated tables were found when the architecture set is read as a whole.

| Table | Finding | Decision |
|---|---|---|
| `payment_term_lines` | Created in `006_master_data.sql`; not visible in the initial Doc02 module grid, but listed as active in the Doc02 canonical registry and specified in Doc03. | DOCUMENTATION UPDATE only: make it visible in the module grid later so future reviewers do not flag it as undocumented. |

## 6. Recommended Additional Phase 1 Tables

The current 207-table architecture does not fully satisfy Adaptive Workspace Principle #15 as stated by the owner. `company_feature_settings` is useful but too coarse: it has fixed boolean flags for a few modules and does not define categories, pages, dashboards, reports, workspaces, role-visible workspace bundles, or user preferences.

The smallest clean adaptive-workspace foundation should add these tables before Migration 018 is finalized:

| Proposed Table | Purpose | Phase 1 Decision | Reason |
|---|---|---|---|
| `workspace_modules` | Registry of modules shown by the application. | REQUIRED BEFORE MIGRATION 018 | Modules must be metadata-driven, not hardcoded. |
| `workspace_categories` | Registry of navigation categories within modules. | REQUIRED BEFORE MIGRATION 018 | Categories must be admin/config-driven. |
| `workspace_pages` | Registry of routeable pages, component keys, required permissions, and required feature keys. | REQUIRED BEFORE MIGRATION 018 | Pages must hide automatically when feature/permission conditions fail. |
| `workspace_dashboards` | Registry of dashboards. | REQUIRED BEFORE MIGRATION 018 | Dashboard visibility is a stated non-negotiable capability. |
| `workspace_reports` | Registry of reports and report routes/export types. | REQUIRED BEFORE MIGRATION 018 | Report visibility must be configurable and permission-aware. |
| `dashboard_widgets` | Registry of dashboard widgets/cards. | REQUIRED BEFORE MIGRATION 018 | User dashboard customization cannot be cleanly implemented if widgets are hardcoded. |
| `workspace_definitions` | Named workspaces such as Owner, Accountant, Inventory Specialist, or Bookkeeper without hardcoding role lists. | REQUIRED BEFORE MIGRATION 018 | Role-based workspace examples require configurable bundles. |
| `workspace_items` | Ordered items within a workspace: pages, dashboards, reports, or module shortcuts. | REQUIRED BEFORE MIGRATION 018 | Workspaces need configurable contents. |
| `company_feature_visibility` | Per-company visibility overrides by item type and item id; child/detail layer for `company_feature_settings`. | REQUIRED BEFORE MIGRATION 018 | Existing booleans cannot scale to pages/reports/dashboards/workspaces. |
| `role_workspace_assignments` | Assigns workspaces to roles without hardcoded role names. | REQUIRED BEFORE MIGRATION 018 | Supports role-based workspaces without static role lists. |
| `user_workspace_preferences` | User hide/favorite/pin/layout preferences, always subordinate to security and company visibility. | REQUIRED BEFORE MIGRATION 018 | Required for user preferences without overriding permissions. |

Design guardrails for these tables:

- They must not grant security by themselves.
- Final visibility must be the intersection of company feature visibility, role permissions, and user preferences.
- User preferences may hide, favorite, pin, or arrange items, but cannot reveal a page/report/dashboard blocked by company feature settings or role permissions.
- They should be system-seeded but admin-configurable where the owner expects configurability.
- They should avoid hardcoded role lists; roles remain configurable through `roles`, `permissions`, `role_permissions`, and `user_roles`.

## 7. Capability Gaps

| Capability | Current Status | Gap | Required Action |
|---|---|---|---|
| Accounting integrity | Partial | Core tables exist, but line immutability and service-owned mutable fields remain exposed through broad UPDATE policies. | Fix parent-status RLS guards and service-owned field protection before CRUD. |
| Posting engine | Partial | Posting support exists, but source line mutation after posting can corrupt generated entries. | Add parent-status guards or remove user UPDATE on immutable lines. |
| Auditability | Not complete | Audit/CAS tables are documented but missing. | Implement Audit/CAS tables in Migration 018 scope. |
| CAS readiness | Not complete | `cas_registrations` exists but has no policy; Audit/CAS tables are missing. | Add policy for `cas_registrations`; implement CAS audit tables. |
| PH compliance | Partial | VAT/EWT/FWT/PT/ITR tables exist, but export logs, generated files, audit logs, and filed-status guards are incomplete. | Implement export/generated-file/audit tables and filing immutability. |
| Attachments/evidence | Missing | Attachment tables are documented but not migrated. | Implement `attachments` and `attachment_versions`. |
| Import/export | Missing | Import/export tables are documented but not migrated. | Implement import/export table group and deferred FK wiring. |
| Generated documents | Missing | Generated document tables are documented but not migrated. | Implement document template/output table group. |
| Notifications | Missing | Notification tables are documented but not migrated. | Implement notification table group. |
| Workflow approvals | Partial | Approval matrix exists; request/action history is missing; `approval_matrix_steps` has no policy. | Implement approval request/action tables and add step policies. |
| Reporting | Partial | Core report data exists, but report registry, report visibility, export jobs, and generated files are missing. | Implement report/export metadata and adaptive workspace report registry. |
| Adaptive workspace | Not complete | Static UI shell exists; no metadata tables for modules/categories/pages/dashboards/reports/workspaces/user preferences. | Add adaptive workspace tables. |
| Feature toggles | Partial | `company_feature_settings` exists but only has fixed booleans and no RLS policy. | Add policy and granular visibility metadata. |
| Role visibility | Partial | Role/permission model exists, but no page/report/dashboard/workspace mapping exists. | Add workspace metadata with required permission codes and role-workspace assignments. |
| User preferences | Missing | No preference table exists. | Add `user_workspace_preferences`. |
| Setup/configuration | Partial | Setup tables exist; 12 important setup/config tables lack policies. | Add final setup/config RLS policies. |
| Stability and traceability | Partial | Migration chain is static-reviewed only; no clean DB apply recorded in this audit. | Run clean Supabase/PostgreSQL migration verification. |

## 8. Adaptive Workspace Readiness

Status: NOT READY.

What exists:

- `company_feature_settings`
- `roles`
- `permissions`
- `role_permissions`
- `user_roles`
- `user_company_access`
- `user_branch_access`
- `user_department_access`
- Current `index.html` static navigation shell

What is missing:

- Module registry
- Category registry
- Page registry
- Dashboard registry
- Report registry
- Workspace registry
- Workspace item ordering
- Company-level granular visibility rules
- Role-to-workspace assignments
- User hide/favorite/pin/dashboard-layout preferences

Assessment:

The current UI looks professional and should be preserved visually. The issue is not visual design. The issue is that the current navigation is hardcoded in `index.html`, while the owner's principle requires the future application to build visibility from configuration.

The current `company_feature_settings` table is not enough because it only controls a few fixed module flags. It does not cover categories, pages, dashboards, reports, or workspaces, and adding a new boolean column for every future module would be high maintenance.

## 9. Approval Workflow Readiness

Status: PARTIAL, NOT COMPLETE.

Supported today:

- `approval_matrix`
- `approval_matrix_steps`
- `roles`
- `permissions`
- `role_permissions`
- `user_roles`
- `personnel`
- `document_controls`

Missing:

- `approval_requests`
- `approval_actions`
- RLS policies for `approval_matrix_steps`
- Notification tables required by Doc10 for approval UX

Capability result:

| Requirement | Status | Reason |
|---|---|---|
| Preparer | Partial | Can be represented by created_by/user roles, but no approval request lifecycle. |
| Reviewer | Partial | Matrix steps can identify roles/users, but no request/action state. |
| Approver | Partial | Matrix steps exist, but no approval action history. |
| Approval matrix | Implemented | `approval_matrix` exists and has policies. |
| Approval steps | Schema implemented, policy missing | `approval_matrix_steps` exists but has no 017 policy. |
| Approval requests | Missing | `approval_requests` not migrated. |
| Approval action history | Missing | `approval_actions` not migrated. |
| Configurable approval routing | Partial | Matrix + steps model exists, but runtime request/action tables are absent. |
| Admin-maintained approval rules | Partial | Depends on adding policies for `approval_matrix_steps`. |

## 10. Company Feature Toggle Readiness

Status: PARTIAL, NOT COMPLETE.

What exists:

- `company_feature_settings` with fixed booleans:
  - `inventory_enabled`
  - `fixed_assets_enabled`
  - `petty_cash_enabled`
  - `bank_recon_enabled`
  - `budgeting_enabled`

Gaps:

- No RLS policy for `company_feature_settings`, so authenticated users cannot reliably read feature settings under RLS.
- No flags/metadata for compliance, reports, dashboards, workspaces, pages, or categories.
- Existing fixed booleans are not scalable for a low-maintenance ERP.
- Disabled modules cannot automatically disappear unless the UI has a data-driven registry to evaluate.

Required action:

Keep `company_feature_settings`, add its policies, and add a granular metadata/visibility layer such as `company_feature_visibility` tied to workspace registry tables.

## 11. Role Visibility Readiness

Status: PARTIAL.

What exists:

- Role tables are flexible enough to avoid hardcoded role lists.
- Permissions can express resource/action security.
- User-company/branch/department access supports scoping.

What is missing:

- No mapping from pages/reports/dashboards/workspaces to permission codes.
- No role-to-workspace assignment table.
- No UI metadata layer to compute visible menus from permissions.

Required action:

Add workspace metadata tables where every page, report, dashboard, and workspace item declares required permission and feature keys. Role visibility should be derived from `role_permissions`, not hardcoded role names.

## 12. User Preference Readiness

Status: MISSING.

The current architecture has no table for:

- Hiding pages
- Favoriting pages
- Pinning workspaces
- Customizing dashboard layout
- Storing per-company user workspace preferences

Required action:

Add `user_workspace_preferences` or an equivalent table before CRUD/UI starts. It must never override security. It may only reduce or arrange what the user is already allowed to see.

## 13. Final Required Phase 1 Table List

Final target if the owner accepts this reconciliation:

| Group | Count | Decision |
|---|---:|---|
| Existing canonical active tables | 207 | Required Phase 1 source of truth. |
| Already migrated from canonical set | 178 | Keep. |
| Missing from canonical set | 29 | Required in Migration 018 scope. |
| New adaptive-workspace tables recommended by this audit | 11 | Required before CRUD/UI because of Principle #15. |
| Removed tables | 3 | Do not create. |

Final required active Phase 1 table target:

207 current canonical active tables + 11 adaptive-workspace tables = 218 active Phase 1 foundation tables.

The 11 recommended adaptive-workspace additions should be added to architecture documentation before or as part of the Migration 018 planning package. Until they are accepted, they are REQUIRED BEFORE MIGRATION 018 from this audit's standpoint, but they also require architecture documentation updates because they are new tables.

## 14. Proposed Migration 018 Scope

Migration 018 should be named and scoped as a final foundation reconciliation migration. It should not be CRUD, UI, seed data, views, cron jobs, or business feature implementation.

Recommended scope:

1. Create the 29 missing active documented Phase 1 tables.
2. Add the 11 adaptive-workspace metadata tables, after project owner acceptance.
3. Enable RLS on every new table.
4. Add policies for every new table.
5. Add policies for the 12 migrated no-policy tables:
   - `approval_matrix_steps`
   - `atp_usage_logs`
   - `cas_registrations`
   - `chart_of_accounts`
   - `company_bank_accounts`
   - `company_compliance_profiles`
   - `company_feature_settings`
   - `document_controls`
   - `exchange_rates`
   - `fiscal_locks`
   - `system_parameters`
   - `user_department_access`
6. Fix parent-status immutability gaps for line/non-status transaction tables.
7. Protect service-owned mutable fields from authenticated direct UPDATE.
8. Add compliance filing-status guards for filed rows.
9. Wire deferred FKs only where both source and target tables now exist.
10. Include verification queries as comments.

Migration 018 should be reviewed as the real Phase 1 database foundation completion point.

## 15. Risks If Skipped

| Skipped Item | Risk |
|---|---|
| Missing 29 documented tables | Developers build UI against non-existent tables, or compliance/audit/import/export/document/notification workflows are redesigned under pressure. |
| Adaptive workspace metadata | UI hardcodes module/page/report/dashboard visibility, violating the owner's low-maintenance principle and making future modules expensive to support. |
| `company_feature_settings` RLS policy | The future UI cannot safely read feature settings for module visibility. |
| Role/page/report/workspace mapping | Role-based workspaces become hardcoded role lists instead of configurable permissions. |
| User preferences table | User customization either does not exist or gets stored ad hoc outside the database contract. |
| Approval request/action tables | Approval workflow cannot produce reliable request lifecycle or action history. |
| Audit/CAS tables | CAS readiness and BIR audit traceability are incomplete. |
| Import/export and generated file tables | BIR exports, generated reports, import traceability, and deferred FK wiring remain incomplete. |
| Line immutability RLS cleanup | Authenticated users may mutate posted lines directly through Supabase APIs. |
| Service-owned field protection | Users may alter balances, quantities, schedule status, or generated journal links that should only be engine-owned. |
| Clean database verification | Migration syntax/order/RLS failures may appear after CRUD work has already been built. |

## 16. Final Recommendation

Do not start CRUD or UI implementation yet.

Do not create a business-feature Migration 018.

Create Migration 018 only as a final Phase 1 foundation reconciliation package after the project owner accepts the adaptive-workspace table additions.

Minimum required before CRUD/UI:

1. Implement the 29 missing active documented tables.
2. Add the 11 adaptive-workspace foundation tables or obtain an explicit owner decision rejecting them.
3. Add RLS/policies for all new tables.
4. Add RLS policies for the 12 existing no-policy tables.
5. Fix line immutability and service-owned mutable field exposure.
6. Add filed-status guards for compliance filing tables.
7. Run a clean database migration test.

Final decision from this audit:

PHASE 1 FOUNDATION IS NOT RECONCILED YET.

## Final Decision Matrix

| Finding / Table Group | Classification | Required Action |
|---|---|---|
| 178 migrated documented tables | ALREADY IMPLEMENTED | Keep; continue policy cleanup where listed. |
| 29 missing documented active tables | REQUIRED BEFORE MIGRATION 018 | Create in Migration 018 foundation scope unless owner formally removes from Phase 1. |
| `payment_term_lines` documentation placement | DOCUMENTATION UPDATE | Add to the Doc02 module grid later; it is already in registry/Doc03 and migrated. |
| 12 migrated no-policy tables | ALREADY IMPLEMENTED | Add policies before CRUD; include in Migration 018 cleanup scope. |
| `financial_statement_mappings` | DOCUMENTATION UPDATE | Keep removed; do not create. |
| `mcit_computations` | DOCUMENTATION UPDATE | Keep removed; do not create. |
| `nolco_schedules` | DOCUMENTATION UPDATE | Keep removed; do not create. |
| Reserved slots #193-#198 | DOCUMENTATION UPDATE | Keep retired; do not create separate compliance run/file tables. |
| 11 adaptive-workspace metadata tables | REQUIRED BEFORE MIGRATION 018 | Add to architecture and Migration 018 scope unless owner explicitly rejects Principle #15 database support. |
| Accounting-firm client grouping table | NEEDS PROJECT OWNER DECISION | Existing `companies`, `user_company_access`, roles, and permissions can support base accounting-firm work. Add a firm-client portfolio table only if owner needs firm-level portfolio management beyond multi-company access. |

## Appendix A - Inventory Reconciliation Rollup

| Inventory Area | Documented Active | Migrated | Missing | RLS Enabled For Migrated | Policy Status |
|---|---:|---:|---:|---:|---|
| Security & Identity | 8 | 8 | 0 | Enabled | `user_department_access` has no policy. |
| Organization Setup | 8 | 8 | 0 | Enabled | `cas_registrations`, `company_bank_accounts`, `company_compliance_profiles`, `company_feature_settings` have no policies. |
| System Controls | 8 | 8 | 0 | Enabled | `approval_matrix_steps`, `atp_usage_logs`, `document_controls`, `system_parameters` have no policies. |
| Accounting Setup | 9 active | 9 | 0 | Enabled | `chart_of_accounts`, `exchange_rates`, `fiscal_locks` have no policies. |
| Tax Setup | 8 | 8 | 0 | Enabled | Policies added in 017A/017G. |
| Master Data - Parties | 13 including `payment_term_lines` | 13 | 0 | Enabled | Policies added in 017C. |
| Master Data - Items & Services | 6 | 6 | 0 | Enabled | Policies added in 017C. |
| Inventory Master | 4 | 4 | 0 | Enabled | Policies added in 017C/017E. |
| Sales Cycle | 6 | 6 | 0 | Enabled | Policies added in 017D, but line immutability needs cleanup. |
| Sales Transactions | 12 | 12 | 0 | Enabled | Policies added in 017D, but line immutability needs cleanup. |
| Purchasing Transactions | 16 | 16 | 0 | Enabled | Policies added in 017D, but line immutability and engine-owned fields need cleanup. |
| Petty Cash | 6 | 6 | 0 | Enabled | Policies added in 017E, but engine-owned fund balance needs cleanup. |
| Bank | 8 | 8 | 0 | Enabled | Policies added in 017E. |
| Inventory Transactions | 10 | 10 | 0 | Enabled | Policies added in 017E, but line immutability needs cleanup. |
| Fixed Assets | 10 | 10 | 0 | Enabled | Policies added in 017E, but service-owned asset values need cleanup. |
| Accounting / GL | 11 | 11 | 0 | Enabled | Policies added in 017F. |
| Compliance - VAT | 5 | 5 | 0 | Enabled | Policies added in 017G; filed-status guard still needed. |
| Compliance - Withholding Tax | 10 | 10 | 0 | Enabled | Policies added in 017G; filed-status guard still needed. |
| Compliance - Income Tax | 4 active | 4 | 0 | Enabled | Policies added in 017G; filed-status guard still needed. |
| Compliance - Percentage Tax | 3 | 3 | 0 | Enabled | Policies added in 017G; filed-status guard still needed. |
| Income Tax Computation Support | 2 | 2 | 0 | Enabled | Policies added in 017G. |
| Accounting Schedules | 9 | 9 | 0 | Enabled | Policies added in 017F; service-owned schedule fields need cleanup. |
| Audit & CAS | 8 | 0 | 8 | Not applicable | Required before Migration 018. |
| Attachments | 2 | 0 | 2 | Not applicable | Required before Migration 018. |
| Workflow & Approvals | 2 | 0 | 2 | Not applicable | Required before Migration 018. |
| Import / Export | 6 | 0 | 6 | Not applicable | Required before Migration 018. |
| Notifications | 3 | 0 | 3 | Not applicable | Required before Migration 018. |
| Document Templates & Generated Output | 3 | 0 | 3 | Not applicable | Required before Migration 018. |
| Budget | 2 | 2 | 0 | Enabled | Policies added in 017F. |
| Period Close | 3 | 0 | 3 | Not applicable | Required before Migration 018. |
| Party Duplicate Management | 2 | 0 | 2 | Not applicable | Required before Migration 018. |
| Adaptive Workspace metadata | 11 recommended new | 0 | 11 | Not applicable | Required before Migration 018 by owner Principle #15. |

