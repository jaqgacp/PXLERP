# PXL ERP Workspace Principles

Version: PXL Constitution v1.0
Status: Canonical governing principles
Scope: Adaptive Workspace, feature catalog, navigation, pages, dashboards, reports, widgets, role workspaces, and user preferences

## Purpose

This document defines the permanent Adaptive Workspace principles for PXL ERP. It replaces older fixed-menu assumptions with a normalized, metadata-driven workspace model.

## Core Workspace Principles

### 1. Adaptive Workspace Is Phase 1 Foundation

Adaptive Workspace is not a future enhancement. It is required for Phase 1 because PXL ERP must serve small businesses, accounting firms, owners, and larger companies without separate code paths.

### 2. Feature Catalog Is The Root

`feature_definitions` is the canonical feature catalog for workspace visibility. It supports current and future modules, pages, dashboards, reports, widgets, workspaces, and company feature visibility without adding new boolean columns.

### 3. Workspace Metadata Is Relational

Workspace records must reference features by `required_feature_id` where feature gating is needed. Free-text feature keys must not be the governing relationship.

### 4. Company Feature Visibility References Features

`company_feature_visibility` must reference `feature_definitions.id`. It decides which approved features are available to a company.

### 5. Conceptual Workspace Flow

The visible UI is produced through this governance chain:

Feature Definition -> Workspace Module -> Workspace Category -> Workspace Page -> Dashboard -> Widget -> Report -> Workspace Definition -> Role Workspace Assignment -> User Workspace Preference -> Visible UI

This is a governance chain, not a requirement that every record physically owns the next record. Pages, dashboards, reports, widgets, and workspace items may have their own normalized relationships.

### 6. No Hardcoded Navigation

Modules, categories, pages, dashboards, widgets, reports, workspace definitions, role-specific menus, company-specific menus, and user-specific menus must not be hardcoded in frontend arrays.

### 7. Workspace Modules Are Metadata

Top-level modules must come from `workspace_modules`. Adding a future module should require approved architecture and metadata insertion, not frontend restructuring.

### 8. Workspace Categories Organize Work

Categories group pages, dashboards, reports, and tasks in a way that helps users work. Categories must be metadata-driven and sortable.

### 9. Workspace Pages Are Entry Points

Pages represent operational destinations such as setup pages, transaction lists, master data screens, report launchers, dashboards, or workflow queues.

### 10. Dashboards And Widgets Are Metadata

Dashboards and widgets must be registered metadata with feature gating, permissions, placement, sorting, and report or source traceability.

### 11. Reports Are Workspace Items

Reports must be discoverable through workspace metadata and controlled by feature visibility, permissions, and RLS. Report lists must not be hardcoded.

### 12. Workspace Definitions Represent User Experiences

A workspace definition describes a curated working environment, such as owner view, bookkeeper view, accounting firm client view, sales operations, purchasing operations, inventory operations, or compliance view.

### 13. Role Workspace Assignment Controls Defaults

Roles may be assigned workspace definitions. This provides default workspace visibility without hardcoding role names into UI code.

### 14. User Preferences Personalize Only Allowed Items

User preferences may pin, hide, sort, collapse, or arrange items the user is already allowed to see. Preferences must not expand access.

### 15. Small Business Must Be Simple

Small companies can receive a compact workspace by assigning fewer modules, pages, reports, and dashboards. This must not require a separate codebase.

### 16. Accounting Firms Must Be Multi-Client

Accounting firm users must operate across client companies through governed company access and workspace assignment. Company context must be explicit.

### 17. Owners Need Dashboard-First Access

Owners may receive dashboard-oriented workspaces with drilldown to reports and records. This must still respect permissions and RLS.

### 18. Large Companies Need Department-Aware Workspaces

Larger companies may expose department, branch, approval, cost center, and operational workspaces through metadata and role assignment.

### 19. Future Modules Must Fit The Model

Future modules must be added by feature and workspace metadata, architecture updates, migrations, RLS, services, UI pages, reports, tests, and documentation. They must not require refactoring the foundation.

### 20. Workspace Tests Are Required

Workspace implementation must be tested for company feature visibility, role assignment, permission boundaries, user preferences, hidden features, disabled features, and RLS-backed data access.
