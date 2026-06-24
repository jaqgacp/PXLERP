# PXL ERP Principles Master Index

Version: PXL Constitution v1.0
Status: Canonical governing index
Scope: Governing principles for PXL ERP Phase 1 foundation and later implementation

## Purpose

This index is the entry point for the PXL ERP Constitution. It consolidates the permanent architecture, UI, database, Supabase, security, posting, reporting, compliance, workspace, and development principles that govern implementation.

The goal is to remove ambiguity before Migration 018 and all later CRUD, backend, UI, report, and test work.

## Scope

These principles apply to:

- Architecture and product decisions.
- Database design and migrations.
- Supabase, RLS, and service-role boundaries.
- Backend services and Edge Functions.
- UI, navigation, workspace metadata, dashboards, and reports.
- Posting, accounting, compliance, audit, import, export, and generated documents.
- Tests, user documentation, release review, and future module expansion.

## Constitution Documents

| Document | Purpose |
| --- | --- |
| `docs/principles/01_ARCHITECTURE_PRINCIPLES.md` | Overall product and system architecture rules. |
| `docs/principles/02_UI_PRINCIPLES.md` | UI, navigation, workspace, grid, form, dashboard, and action behavior. |
| `docs/principles/03_DATABASE_PRINCIPLES.md` | Table, relationship, naming, migration, and verification rules. |
| `docs/principles/04_SUPABASE_PRINCIPLES.md` | Supabase, PostgreSQL, Edge Function, Storage, Realtime, and migration rules. |
| `docs/principles/05_SECURITY_RLS_PRINCIPLES.md` | Authentication, authorization, feature visibility, workspace visibility, RLS, and security cleanup. |
| `docs/principles/06_POSTING_ENGINE_PRINCIPLES.md` | Posting rule, journal, ledger, reversal, fiscal lock, and accounting traceability rules. |
| `docs/principles/07_REPORTING_PRINCIPLES.md` | Reports, dashboards, generated documents, exports, drilldown, and report visibility. |
| `docs/principles/08_COMPLIANCE_PRINCIPLES.md` | Philippine compliance, CAS readiness, filing, tax snapshots, and regulatory traceability. |
| `docs/principles/09_WORKSPACE_PRINCIPLES.md` | Adaptive Workspace, feature catalog, modules, pages, reports, widgets, workspaces, roles, and preferences. |
| `docs/principles/10_DEVELOPMENT_PRINCIPLES.md` | Implementation workflow, traceability chain, review gates, tests, documentation, and release discipline. |

## Governing Rule

When there is a conflict:

1. Newer explicit owner decisions control older decisions.
2. This Constitution controls older review notes, temporary audit comments, and superseded planning language.
3. Architecture documents remain canonical for detailed table and module specifications unless updated by owner decision or this Constitution.
4. Migration files are historical implementation records and must not be rewritten after merge.
5. Implementation cannot proceed when any required traceability link is missing or contradictory.

## Owner Decisions Incorporated

### Decision 016: Final Phase 1 Foundation Target Before Feature Catalog

Decision 016 recorded that:

- Phase 1 is not split into Phase 1A and Phase 1B.
- All documented active Phase 1 tables are required for Phase 1.
- The 29 missing documented tables must be created before CRUD and UI expansion continue.
- Adaptive Workspace is non-negotiable for Phase 1 foundation.
- No hardcoded roles, menus, dashboards, approval flows, or feature visibility are allowed.
- The full requirement traceability chain is mandatory.

### Decision 017: Normalized Feature Catalog

Decision 017 recorded that:

- Adaptive Workspace remains non-negotiable.
- Feature visibility must be relational, not text-key-only.
- `feature_definitions` is approved as a Phase 1 foundation table.
- Final Phase 1 active table target is 219 active tables.
- `feature_definitions` is the canonical feature catalog for modules, pages, dashboards, reports, widgets, workspaces, and company feature visibility.
- Workspace records must use `required_feature_id` where feature gating is needed.
- `company_feature_visibility` must reference `feature_definitions.id`.
- `company_feature_settings` may remain as high-level company setup flags, but it is not the canonical feature catalog.
- No hardcoded feature keys are allowed in backend, UI, or RLS logic.
- Future modules must be added through feature and workspace metadata, not new hardcoded columns.

## Key Cross References

| Source | Use |
| --- | --- |
| `docs/architecture/00_PXL_ARCHITECTURE_PRINCIPLES.md` | Original architecture principle source. |
| `docs/architecture/01_DATABASE_ARCHITECTURE_OVERVIEW.md` | Database architecture overview. |
| `docs/architecture/02_COMPLETE_TABLE_INVENTORY.md` | Canonical table inventory baseline. |
| `docs/architecture/03_TABLE_COLUMN_SPECIFICATIONS.md` | Canonical column specifications. |
| `docs/architecture/04_RELATIONSHIP_MAP.md` | Relationship and dependency map. |
| `docs/architecture/05_COMPLIANCE_DATA_CAPTURE_MAP.md` | Compliance data capture and traceability. |
| `docs/architecture/06_POSTING_ENGINE_TABLE_DESIGN.md` | Posting engine table and behavior design. |
| `docs/architecture/07_AUDIT_AND_CAS_TABLE_DESIGN.md` | Audit and CAS requirements. |
| `docs/architecture/08_IMPORT_EXPORT_TABLE_DESIGN.md` | Import, export, and generated document design. |
| `docs/architecture/09_SECURITY_RLS_DESIGN.md` | Security and RLS design. |
| `docs/architecture/10_REVIEW_CHECKLIST.md` | Review and freeze checklist. |
| `docs/ui/` | Detailed UI layout, toolbar, grid, action, traceability, and audit standards. |
| `supabase/SUPABASE_DECISIONS.md` | Owner decisions and architectural decision records. |
| `SUPABASE_FINAL_REVIEW_BACKLOG.md` | Known foundation backlog and blocker tracking. |
| `PHASE1_FOUNDATION_RECONCILIATION_REPORT.md` | Phase 1 reconciliation and target validation. |
| `FOUNDATION_CERTIFICATION_REPORT.md` | Foundation certification findings and known gaps. |
| `MIGRATION_018_DESIGN_PLAN.md` | Migration 018 design plan for 219-table target. |
| `MIGRATION_018_IMPLEMENTATION_SPEC.md` | Migration 018 implementation blueprint. |

## Canonical Terminology

| Term | Canonical Meaning |
| --- | --- |
| Feature Definition | A row in `feature_definitions`; the canonical feature catalog entry. |
| Feature Visibility | Whether a feature is available to a company through feature catalog and company visibility records. |
| Company Feature Settings | High-level company setup flags; not the canonical feature catalog. |
| Workspace Module | Metadata record for a top-level module visible through Adaptive Workspace. |
| Workspace Category | Metadata grouping for pages, dashboards, reports, and workspace items. |
| Workspace Page | Metadata entry for a page or screen destination. |
| Workspace Dashboard | Metadata entry for a dashboard. |
| Dashboard Widget | Metadata entry for a dashboard component. |
| Workspace Report | Metadata entry for a report destination or report launch item. |
| Workspace Definition | A curated user experience made from workspace metadata. |
| Workspace Item | A normalized item included in a workspace definition. |
| Role Workspace Assignment | Assignment of workspace defaults to roles. |
| User Workspace Preference | User personalization that can hide, pin, sort, or arrange only allowed items. |
| Permission | Authorization to perform an action. |
| RLS | Database row-level security and the final database access gate. |
| Service Role | Trusted server-only Supabase role for privileged operations. |
| Edge Function | Trusted server-side execution path for privileged business operations. |
| Posting | Service-controlled creation of accounting entries from source records and posting rules. |
| Compliance Snapshot | Stored transaction-time compliance facts preserved for audit and reporting. |

## Global Implementation Checklist

Before a feature is implemented, confirm:

- Business requirement is documented.
- Architecture document covers the feature.
- Database table or documented table family exists.
- Migration creates or modifies the required database objects.
- RLS policy is defined and verified.
- Backend service or Edge Function path is defined where needed.
- UI form, page, dashboard, or report entry is metadata-driven where applicable.
- Posting behavior is defined or marked not applicable.
- Report behavior is defined or marked not applicable.
- Test scenario exists.
- User documentation impact is known.

## Global Non-Negotiables

- No hardcoded roles.
- No hardcoded menus.
- No hardcoded dashboards.
- No hardcoded approval flows.
- No hardcoded feature visibility.
- No hardcoded report lists.
- No client-side service role.
- No hidden ledger writes.
- No casual edits to posted, filed, locked, reversed, voided, cancelled, or completed records.
- No CRUD or UI expansion before foundation, RLS, and security cleanup are ready.

## Final Phase 1 Foundation Target

The current Phase 1 foundation target is 219 active tables.

This target is the basis for Migration 018 planning and verification. Any change to this target requires an explicit owner decision and corresponding updates to the table inventory, design plan, migration plan, backlog, and this Constitution.
