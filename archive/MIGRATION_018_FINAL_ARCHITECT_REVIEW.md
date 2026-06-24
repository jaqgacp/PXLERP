> [!WARNING]
> **STATUS: SUPERSEDED**
> DO NOT USE AS IMPLEMENTATION SOURCE
> Canonical Source: FOUNDATION_FREEZE_REPORT.md
# MIGRATION 018 FINAL ARCHITECT REVIEW

Repository: PXLERP  
Branch reviewed: main  
Review mode: pre-implementation architecture validation only  
Reviewed commit: f439f0a959770c673e8a27fe4807005041efe242  
Review date: 2026-06-24

## 1. Executive Summary

Migration 018 is not ready for SQL implementation.

The foundation is close, but there is one objective architecture blocker: the adaptive workspace and feature-visibility design still has no normalized feature catalog. The current plan depends on `required_feature_key` text fields and the existing `company_feature_settings` fixed boolean columns. That breaks the owner's non-negotiable rules for no hardcoded values, setup-driven configuration, future module enablement without refactoring, and complete traceability.

The 29 missing documented Phase 1 tables are justified by the owner decision and the canonical architecture set. The 11 adaptive-workspace tables are also justified conceptually. No redundant table is proven. However, the final 218-table target is not stable until the feature-definition gap is resolved.

Final decision: NO-GO for Migration 018 implementation.

## 2. Architecture Score

Score: 82 / 100

The ERP foundation is coherent across company, branch, accounting, compliance, RLS, audit, import/export, generated documents, and reporting. The score is capped because adaptive workspace feature visibility is still not fully modeled as canonical data.

## 3. Stability Score

Score: 84 / 100

The existing migration sequence and reconciliation plan are stable enough to proceed after the configuration gap is fixed. The current risk is not broad schema instability; it is one unresolved foundation concept that would propagate into UI, backend, RLS, reporting, tests, and user documentation.

## 4. Maintainability Score

Score: 76 / 100

Most tables follow repeatable company-scoped, audit-ready patterns. Maintainability is reduced because feature enablement is still partially encoded as fixed columns and text keys instead of a normalized setup registry.

## 5. Low-Maintenance Score

Score: 72 / 100

The adaptive workspace is intended to reduce future maintenance. Without a feature catalog, every new module or feature risks requiring new columns, hardcoded string handling, or special-case backend/UI logic.

## 6. Trustworthiness Score

Score: 84 / 100

Accounting, compliance, audit, and posting traceability are mostly trustworthy once the 29 documented tables and missing RLS policies are implemented. Trust is capped because feature visibility cannot yet be independently validated against a canonical feature table.

## 7. Scalability Score

Score: 78 / 100

The company/branch/security/posting model can scale across small businesses, accounting firms, and larger companies. Future module scalability is blocked by the missing feature-definition layer.

## 8. Missing Tables

### BLOCKER M018-01: Missing normalized feature catalog

Finding: Migration 018 design has no canonical table for feature definitions.

Evidence:

- `company_feature_settings` has fixed booleans for `inventory_enabled`, `fixed_assets_enabled`, `petty_cash_enabled`, `bank_recon_enabled`, and `budgeting_enabled`.
- The reconciliation report states that fixed booleans do not cover categories, pages, dashboards, reports, workspaces, or future modules.
- `MIGRATION_018_DESIGN_PLAN.md` proposes `required_feature_key` on `workspace_pages`, `workspace_dashboards`, and `workspace_reports`, then says to keep it text-based only if feature keys are sourced from `company_feature_settings` columns.

Reason:

There is no database parent for feature keys. A developer implementing Migration 018 would have to rely on hardcoded strings or existing fixed boolean columns. That contradicts the owner decision that roles, menus, dashboards, approval flows, and feature visibility must not be hardcoded.

Impact:

- Future modules cannot be enabled without refactoring feature columns or hardcoded key logic.
- Workspace pages, dashboards, reports, and widgets cannot FK to a canonical feature.
- RLS and backend services cannot validate feature visibility against database-owned configuration.
- Tests and user documentation cannot define a complete feature visibility matrix from data.
- The final 218-table target is not validated.

Required correction before SQL:

Add an owner-approved normalized feature-definition table, or revise the approved adaptive-workspace table set so one table clearly acts as the canonical feature registry without mixing global registry data with per-company visibility state. The architecture must then decide whether the final Phase 1 table target becomes 219, or whether one of the approved 11 adaptive tables is replaced by the feature registry.

## 9. Redundant Tables

No objectively redundant tables were found.

`company_feature_settings` and `company_feature_visibility` overlap conceptually, but they are not redundant until the feature model is finalized. The unresolved issue is missing canonical ownership and relationships, not a proven duplicate table.

## 10. Missing Relationships

### BLOCKER M018-02: Feature-dependent workspace records have no FK-backed feature parent

Finding: Workspace metadata can declare feature requirements, but those requirements are not relationally tied to canonical feature records.

Required relationships before SQL:

- `workspace_pages.required_feature_id` or equivalent FK to the canonical feature registry.
- `workspace_dashboards.required_feature_id` or equivalent FK to the canonical feature registry.
- `workspace_reports.required_feature_id` or equivalent FK to the canonical feature registry.
- `dashboard_widgets.required_feature_id` if widgets can be feature-gated.
- `company_feature_visibility.feature_id` or equivalent relationship if company feature enablement is controlled at feature level.

The existing exact-one-target pattern for workspace items and company visibility is acceptable only if it is enforced with CHECK constraints and real FKs to module/category/page/dashboard/report/workspace targets.

## 11. Missing Configuration Tables

### BLOCKER M018-03: Feature configuration is not fully setup-driven

Missing configuration table: normalized feature catalog, such as `feature_definitions`.

Minimum responsibility:

- Store canonical feature code/name/description.
- Tie the feature to module or workspace metadata where applicable.
- Define active/system/default behavior without adding new columns per feature.
- Provide the DB-owned parent for company visibility, workspace filtering, report filtering, and UI menu gating.

Without this table or an approved equivalent, the architecture still relies on hardcoded feature keys.

## 12. Missing Audit Points

No separate audit table is missing beyond the already planned 29 documented tables.

However, the feature-visibility audit point is incomplete until feature definitions exist. `field_change_history`, `audit_logs`, and `user_activity_logs` can track changes only after the changed object is a real canonical object. A text-only feature key is not enough for reliable audit traceability.

## 13. Missing Posting Traceability

No additional posting traceability table was found.

The planned 29 missing documented tables and existing posting tables cover approval, audit, import/export, document generation, period close, subledger certification, schedules, journal entries, and generated files. The open blocker is not posting table coverage.

Guardrail:

Feature settings must remain UI/report/workspace visibility controls only. They must not disable accounting, tax, inventory, or posting logic.

## 14. Missing Report Traceability

Report traceability is incomplete only where report visibility depends on feature keys.

`workspace_reports`, `export_jobs`, and `generated_report_files` provide the correct report registry and output traceability direction. The missing feature catalog prevents `workspace_reports.required_feature_key` from being validated relationally, audited cleanly, and tested from setup data.

## 15. Final 218 Table Validation

### 29 missing documented tables

Validated as required for the current owner-approved Phase 1 boundary.

These tables are justified by Doc02, Doc03, Doc07, Doc08, Doc09, the reconciliation report, the backlog, and Decision 016. They should remain in the Migration 018 scope unless the owner reverses the "all 207 documented active tables are Phase 1" decision.

### 11 adaptive-workspace tables

Conceptually validated.

The following approved adaptive tables are needed for metadata-driven navigation, reports, dashboards, workspaces, company visibility, role workspace assignment, and user preferences:

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

### Final numeric target

Not validated.

The current formula is:

207 documented active tables + 11 adaptive-workspace tables = 218 active Phase 1 tables.

That formula misses the normalized feature catalog required by the same owner principles. The project must either:

- approve one additional table, likely making the Phase 1 foundation target 219, or
- replace/redefine one approved adaptive table so it cleanly acts as the feature catalog without weakening company-specific visibility.

Until that decision is made, the 218-table target is not architecturally frozen.

### Operating model validation

- One-bookkeeper small business: Supported after the feature catalog fix.
- Accounting firm with multiple clients: Supported through multi-company access after the feature catalog fix.
- Larger company with department-based reporting/access needs: Supported by company, branch, department, cost center, role, permission, and department-access structures, assuming current architecture continues to enforce department filtering at service/UI/report layer rather than broad DB RLS.
- Future modules without refactoring: Not supported until the feature catalog is normalized.

### Traceability chain validation

The mandatory traceability chain breaks here:

Business Requirement: no hardcoded feature visibility and future modules without refactoring.

Architecture Document: Decision 016 and the reconciliation report require setup-driven feature/workspace visibility.

Database Table: missing normalized feature catalog.

Migration: Migration 018 cannot create FK-backed feature references using the current design.

RLS Policy: policies cannot validate feature visibility against canonical feature rows.

Backend Service: services would have to hardcode feature keys or inspect fixed boolean columns.

UI Form: adaptive menus, dashboards, reports, and workspaces would not be fully setup-driven.

Posting Engine: not directly broken, but feature switches remain at risk of being misinterpreted unless canonical semantics are stored in setup data.

Report: report visibility cannot be traced to a canonical feature record.

Test Scenario: tests cannot exhaustively validate feature visibility from database setup alone.

User Documentation: documentation cannot define a durable feature enablement matrix without canonical feature records.

## 16. GO / NO-GO Decision for Migration 018

NO-GO for Migration 018 implementation.

Do not write Migration 018 SQL yet.

Required pre-implementation decision:

Resolve the normalized feature catalog gap and refreeze the final Phase 1 table target before implementation begins.

