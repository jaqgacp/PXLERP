# PXL ERP UI Principles

Version: PXL Constitution v1.0
Status: Canonical governing principles
Scope: Navigation, pages, workspaces, forms, grids, dashboards, reports, and user actions

## Purpose

This document defines the permanent UI principles for PXL ERP. The UI must preserve the professional operating feel already approved while shifting visibility and navigation control to the Adaptive Workspace foundation.

## Core UI Philosophy

### 1. Professional Daily-Use Tool

PXL ERP is an accountant and business operator workspace, not a marketing site. It should feel stable, quiet, structured, fast, and trustworthy.

The UI may look polished and modern, but it must never sacrifice clarity, density, traceability, or repeated-use efficiency.

### 2. Preserve The Approved Visual Direction

The existing professional UI direction should be preserved. Content, labels, metadata, and visibility rules may change, but the visual language should remain clean, serious, and business-first.

### 3. Adaptive Workspace Drives Navigation

Navigation must be generated from workspace metadata. Hardcoded menus, modules, dashboards, reports, widgets, or role-specific navigation lists are not allowed as the long-term architecture.

Top-level modules may appear stable to users, but their source must be `workspace_modules` and related metadata, not static frontend arrays.

### 4. Visibility Is Not Permission

UI visibility and data permission are different layers:

- Feature catalog and company visibility decide whether a capability can appear.
- Permissions decide whether a user can perform an action.
- Workspace assignment decides what the user sees in their workspace.
- User preference can hide, pin, order, or personalize allowed items.
- RLS enforces database access regardless of UI state.

User preferences must never grant access.

### 5. No Hardcoded UI Behavior For Business Rules

The UI must not hardcode role names, feature keys, approval routes, report lists, dashboards, or module availability. It should render records returned by governed metadata and services.

### 6. Consistent Page Anatomy

Operational pages should follow a consistent structure:

Breadcrumb -> Page Header -> Toolbar -> Filter Bar -> Data Grid Or Form -> Pagination Or Footer -> Status And Traceability Area

This structure may be adapted for dashboards and reports, but users should not relearn basic navigation per module.

### 7. Toolbar Order Is Stable

Where applicable, primary toolbar actions follow the standard order:

New -> Import -> Export -> Generate -> Approve -> Print

Unavailable actions should be hidden or disabled based on status, permissions, and feature visibility.

### 8. Row Action Order Is Stable

Where applicable, row actions follow the standard order:

View -> Edit -> Duplicate -> Approve -> Post -> Reverse -> Void -> Print -> Attachments -> Audit Trail

Delete is not a normal business action and must not appear for governed accounting records.

### 9. Grids Must Be Predictable

Data grids must support scanning, filtering, sorting, status recognition, traceability, and consistent action placement. Grids should not become decorative cards when users need comparison and repeated work.

### 10. Forms Must Respect Lifecycle

Forms must show valid actions based on document status, permission, posting state, lock state, compliance filing state, and approval state. The UI must not invite users to edit records that the backend must reject.

### 11. Traceability Is Always Available

Users must be able to move from a transaction to its source, attachments, approval history, posting result, ledger entries, reports, tax outputs, generated documents, and audit trail where applicable.

### 12. Dashboard Data Must Be Explainable

Dashboard numbers must drill to reports or source records. No dashboard widget should display an accounting or compliance number that cannot be reconciled.

### 13. Small Business Mode Must Be Simple

A small business with one bookkeeper must be able to use PXL ERP without navigating enterprise complexity. This is achieved through workspace configuration and feature visibility, not a separate simplified product.

### 14. Accounting Firm Mode Must Be Multi-Client

An accounting firm must be able to switch or manage multiple client companies through governed company access. UI design must make company context clear and prevent accidental cross-company work.

### 15. Larger Company Mode Must Support Departments

Large companies must be able to expose branch, department, cost center, approval, and role-based workspaces without code changes.

### 16. Status Language Must Be Canonical

Document statuses, posting statuses, approval statuses, filing statuses, and import/export statuses must use canonical backend values. UI labels may be friendly, but they must map cleanly to documented status values.

### 17. Audit And CAS Are Built In

Audit visibility and CAS readiness are not special modes. The UI must make audit trail access, generated document traceability, and compliance history available wherever required.

### 18. Accessibility And Keyboard Efficiency Matter

The UI must support efficient keyboard use, clear focus, readable contrast, predictable tab order, and layouts that work on practical desktop and mobile widths.

### 19. UI Cannot Bypass Services

The frontend must call backend services or Edge Functions for privileged operations such as posting, filing, imports, generation, and approval transitions. Client code must not write protected fields directly.

### 20. UI Implementation Must Follow The Traceability Chain

A UI page is ready only when its business requirement, architecture, table, migration, RLS policy, backend service, posting behavior, report contract, test scenario, and user documentation are aligned or formally marked not applicable.
