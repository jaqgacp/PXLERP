# PXL ERP — Foundation Freeze Report

**Status:** CANONICAL IMPLEMENTATION SOURCE
**Target:** Migration 018 / Phase 1 Foundation Freeze

> [!IMPORTANT]
> This is the **single source of truth** for the Phase 1 Foundation Freeze. All previous architectural reviews, cleanup plans, and gap reports are superseded by this document.

---

## 1. Executive Summary

PXL ERP is preparing for the final database foundation freeze (Migration 018) before commencing frontend UI and CRUD implementation.

The foundation provides a highly scalable, multi-branch, RLS-secured ERP architecture with deep, native support for Philippine (BIR) tax compliance, automated posting engines, and an adaptive workspace.

Migration 018 is the final reconciliation step. It must complete the table inventory, establish the canonical feature catalog, and enforce all security immutability policies.

---

## 2. Owner Decisions (Final)

The following decisions are absolute and govern all development:

1. **Phase 1 is NOT split.** There is no Phase 1A or 1B. All required foundation tables must exist before CRUD begins.
2. **219 Active Tables.** The final Phase 1 database target is exactly 219 active tables.
3. **Adaptive Workspace is Mandatory.** The system must adapt dynamically to the user and company context.
4. **Canonical Feature Catalog.** `feature_definitions` is the single source of truth for all features.
5. **No Hardcoding.** Roles, menus, pages, dashboards, reports, approval flows, feature visibility, tax logic, and workspace definitions must be entirely data-driven, never hardcoded.
6. **Strict Traceability.** The path from Business Requirement → Architecture Document → Database Table → Migration → RLS Policy → Backend Service → UI Form → Posting Engine → Report → Test Scenario → User Documentation must be unbroken.

---

## 3. Project Philosophy

**Simple + Complete**
The architecture aims for conceptual simplicity while providing absolute completeness for enterprise and compliance requirements.

- **Data-Driven Configuration:** Setup defines behavior. Code executes the setup.
- **Immutable History:** Posted transactions, filed taxes, and audit logs are sacred.
- **Zero-Trust RLS:** Security is enforced at the PostgreSQL Row Level Security layer. If the policy denies it, the UI cannot bypass it.

---

## 4. Current Status

- **Migrated Tables (001–017G):** 178
- **Documented Target:** 219
- **Gap:** 41 tables (29 missing core tables + 12 adaptive workspace tables)
- **RLS Status:** Enabled on all 178 tables. 12 tables currently lack policies.

---

## 5. Final Phase 1 Scope & Migration 018

Migration 018 must execute the following to achieve Foundation Freeze:

### A. Core Missing Tables (29 Tables)
Implement the missing canonical tables to support:
- **Audit & CAS:** `audit_logs`, `field_change_history`, `user_activity_logs`, `system_parameter_logs`, `document_void_register`, `dat_generation_logs`, `export_history`, `system_alerts`
- **Attachments:** `attachments`, `attachment_versions`
- **Workflow Approvals:** `approval_requests`, `approval_actions`
- **Import/Export:** `import_batches`, `import_rows`, `import_validation_errors`, `import_templates`, `export_jobs`, `generated_report_files`
- **Notifications:** `notification_templates`, `notifications`, `notification_delivery_logs`
- **Document Output:** `document_templates`, `generated_documents`, `generated_document_versions`
- **Period Close:** `period_close_checklists`, `period_close_tasks`, `subledger_close_certifications`
- **Party Management:** `duplicate_tin_flags`, `party_merge_logs`

### B. Adaptive Workspace & Feature Catalog (12 Tables)
Implement the relational feature management structure:
- `feature_definitions` (The Core Catalog)
- `workspace_modules`, `workspace_categories`, `workspace_pages`, `workspace_dashboards`, `workspace_reports`, `dashboard_widgets`, `workspace_definitions`, `workspace_items`
- `company_feature_visibility`, `role_workspace_assignments`, `user_workspace_preferences`

### C. Security & RLS Completion
1. Apply explicit SELECT/INSERT/UPDATE/DELETE policies to the new 41 tables.
2. Apply missing policies to the 12 existing migrated tables (`approval_matrix_steps`, `chart_of_accounts`, `company_compliance_profiles`, etc.).
3. **Enforce Immutability:** Add parent-status guards to line tables (preventing edits on posted documents). Protect service-owned fields (`received_qty`, `current_outstanding`) from authenticated user updates. Lock compliance filing rows based on `filing_status`.

---

## 6. Assessments

### PH Compliance Assessment
PXL ERP has a best-in-class foundation for Philippine BIR compliance. It natively handles Company Tax Profiles, VAT (2550M/Q, Relief, SLSP), Percentage Tax (2551Q), Withholding (EWT/FWT, 1601EQ/FQ, 2307/2306, QAP/SAWT), and Income Tax concepts.
*Requirement for M018:* Ensure `field_change_history` and `document_void_register` are created to fulfill CAS audit requirements.

### Accounting Assessment
The multi-branch chart of accounts, fiscal year/period management, and dual-entry GL foundation are solid.
*Requirement for M018:* Secure the posting engine outputs. Ensure `subledger_close_certifications` is implemented.

### RLS Assessment
The company-scoped, role-based access control paradigm is functioning.
*Requirement for M018:* Finalize all policy gaps. A user must only see what their `company_id`, `branch_id`, and `role_id` permit.

---

## 7. Known Risks & Checklist

**Known Risks:**
- **Feature Visibility Complexity:** Implementing the 12-table Adaptive Workspace requires strict backend adherence. UI components must check relational feature flags, not hardcoded strings.
- **Performance of RLS:** Deeply nested RLS checks (e.g., verifying a document's status to allow updating a line item) can cause performance hits if not properly indexed.

**Foundation Freeze Checklist:**
- [ ] M018 executed on a clean, empty PostgreSQL database successfully.
- [ ] Exactly 219 active tables exist.
- [ ] `feature_definitions` is populated and governs UI layout.
- [ ] All 219 tables have RLS enabled.
- [ ] No authenticated user can edit a posted transaction line.
- [ ] No authenticated user can edit a filed tax return.

---

## 8. Final Verdict

**GO FOR MIGRATION 018.**

Implementation of Migration 018 may proceed strictly according to this document. No CRUD or UI logic may be built until Migration 018 is merged and verified.

---

## 9. Canonical References

*Use these links to navigate the detailed architectural specs (once placed in the repository structure).*

- [Complete Table Inventory](docs/architecture/02_COMPLETE_TABLE_INVENTORY.md)
- [Table Column Specifications](docs/architecture/03_TABLE_COLUMN_SPECIFICATIONS.md)
- [Security & RLS Design](docs/architecture/09_SECURITY_RLS_DESIGN.md)
- [Master Principles Index](PRINCIPLES_MASTER_INDEX.md)
