# PXL ERP Security And RLS Principles

Version: PXL Constitution v1.0
Status: Canonical governing principles
Scope: Authentication, authorization, RLS, permissions, roles, feature visibility, workspace visibility, and security cleanup

## Purpose

This document defines the permanent security and RLS principles for PXL ERP. Security must be correct before CRUD and UI expansion.

## Core Security Principles

### 1. Security Has Layers

Security must not rely on one mechanism. PXL ERP uses authentication, company access, branch access, roles, permissions, feature visibility, workspace assignment, user preference, RLS, service checks, audit logs, and immutable status rules.

### 2. Authentication Is Identity Only

A signed-in user is not automatically authorized to see or modify business data. Authorization must be proven through access records, permissions, visibility metadata, and RLS.

### 3. RLS Is The Final Database Gate

The UI and backend may hide unavailable records, but RLS must still prevent unauthorized database reads and writes.

### 4. Company Access Is The Primary Tenant Boundary

Company-scoped records must normally be accessible only when `company_id` is included in the authenticated user's allowed company set or the user is a super admin.

### 5. Branch Access Applies Where Required

Branch access must be enforced where branch-level security is required by architecture. Where branch is a reporting or operational dimension rather than a strict tenant boundary, this must be documented.

### 6. Super Admin Access Is Exceptional

Super admin logic must be explicit, auditable, and limited to trusted users. It must not be used as a shortcut for normal user permission design.

### 7. Permissions Control Actions

Permissions decide whether a user can perform an action such as view, create, update, approve, post, reverse, void, import, export, print, or generate. Permissions must not be confused with feature visibility.

### 8. Feature Visibility Controls Availability

`feature_definitions` and company feature visibility decide whether a capability is available for a company. Feature visibility does not grant record access by itself.

### 9. Workspace Assignment Controls Presentation

Workspace assignment controls which allowed pages, dashboards, reports, widgets, and workspaces appear to a user or role. It does not bypass permissions or RLS.

### 10. User Preference Never Grants Access

User preferences may hide, pin, sort, group, or arrange allowed items. They must never expose a feature, record, module, report, dashboard, or action that permissions and feature visibility do not allow.

### 11. Final UI Visibility Formula

A UI item is visible only when all applicable gates pass:

Feature definition is active -> Company feature visibility allows it -> Role or user permission allows it -> Workspace assignment includes it -> User preference has not hidden it -> RLS and backend checks permit the underlying data

### 12. RLS Policies Must Be Simple

Policies should use canonical helper functions and clear table patterns:

- Global read-only reference data.
- Company-scoped data.
- Parent-path scoped child data.
- Service-owned data.
- Super admin exceptions.

### 13. No Recursive RLS

RLS policies and helper functions must avoid recursion. Access helper functions must work even when RLS is enabled on access tables.

### 14. No Broad Business Policies

Company-scoped or business tables must not use broad authenticated access. Policies must always reflect scope, status, or service ownership.

### 15. No DELETE By Default

DELETE policies must not be created for governed business tables unless explicitly required. Void, reverse, cancel, archive, deactivate, or soft delete patterns are preferred.

### 16. Immutable Status Guard

Records in posted, voided, reversed, cancelled, completed, filed, locked, or equivalent final states must not be updated by ordinary authenticated policies.

### 17. Lines Follow Their Header Or Company Scope

Line tables with `company_id` use company scope. Line tables without `company_id` must use parent-path scope through their header table.

### 18. Service-Owned Fields Need Protection

Fields maintained by posting, inventory costing, payment allocation, bank reconciliation, depreciation, compliance generation, import jobs, or other services must be protected from ordinary user updates.

### 19. Filed Compliance Data Is Protected

Compliance records that have been filed, submitted, generated, exported, or locked must require controlled amendment or reversal workflows.

### 20. Security Decisions Must Be Auditable

Role assignment, company access, branch access, permission grants, workspace assignments, feature visibility changes, and super admin changes must be auditable.

### 21. RLS Must Be Verified Before CRUD

CRUD work must not proceed for a module until table RLS, policies, service-owned fields, status guards, and known exceptions are reviewed and verified.
