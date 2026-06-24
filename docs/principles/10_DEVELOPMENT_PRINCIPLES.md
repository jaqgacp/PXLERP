# PXL ERP Development Principles

Version: PXL Constitution v1.0
Status: Canonical governing principles
Scope: Product decisions, implementation workflow, migrations, services, UI, tests, documentation, and release gates

## Purpose

This document defines how PXL ERP work must be designed, implemented, reviewed, and released. It exists to prevent skipped details, undocumented assumptions, and drift between architecture, database, UI, and compliance behavior.

## Core Development Principles

### 1. Follow The Traceability Chain

Every feature must follow this chain:

Business Requirement -> Architecture Document -> Database Table -> Migration -> RLS Policy -> Backend Service -> UI Form -> Posting Engine -> Report -> Test Scenario -> User Documentation

If a link is not applicable, the reason must be explicit.

### 2. Do Not Start From UI Alone

A screen request is not enough to create a feature. The underlying business rule, data model, security model, service behavior, report effect, and documentation impact must be known.

### 3. Do Not Start From SQL Alone

A table request is not enough to create a feature. The business requirement, architecture purpose, RLS behavior, backend service, UI use, report need, and test scenario must be known.

### 4. Owner Decisions Are Binding

Recorded owner decisions are part of the project contract. If an implementation conflicts with an owner decision, the owner decision controls until explicitly superseded.

### 5. No Phase 1 Split

Phase 1 is not split into Phase 1A and Phase 1B. The approved Phase 1 foundation target must be completed before CRUD and UI expansion continue.

### 6. Foundation Before CRUD

CRUD, UI forms, backend services, and workflow screens must not proceed until foundation reconciliation, table creation, RLS policies, security cleanup, and verification pass for the relevant module.

### 7. Forward-Only Migrations

Committed migrations are historical. Fixes must be made through new migrations unless the owner explicitly authorizes rewriting history before deployment.

### 8. Keep Changes Scoped

Work must modify only the files required by the task. Architecture changes, migrations, UI changes, backlog updates, and decision log updates must not be mixed unless the task requires them.

### 9. No Silent Assumptions

If a required table, relationship, status, permission, feature, posting rule, report, or compliance behavior is missing, the gap must be recorded. Developers must not invent hidden behavior.

### 10. Prefer Configuration

Before adding code branches, ask whether the behavior belongs in setup, feature definitions, workspace metadata, posting rules, approval rules, tax setup, report metadata, or permissions.

### 11. Tests Match Risk

Accounting, compliance, RLS, posting, import/export, generated documents, and workspace visibility need tests or verification scenarios proportional to their risk.

### 12. Review Objective Blockers First

Reviews should focus on blockers that would cause wrong accounting, wrong compliance, failed migrations, wrong access, contradictory documentation, missing traceability, or implementation drift.

### 13. Documentation Is A Deliverable

Architecture, decisions, backlog, migration notes, user documentation, and report definitions must stay aligned with implementation. Documentation is not optional afterthought.

### 14. No Hardcoded Values

Hardcoded roles, menus, dashboards, approval routes, feature keys, tax behavior, report lists, posting accounts, and company-specific behavior are not allowed when configuration can represent the rule.

### 15. Security Is Implemented Before Exposure

Do not expose CRUD or UI flows for a table until RLS, permissions, service boundaries, immutable status rules, and audit behavior are defined.

### 16. Posting And Compliance Require Service Boundaries

Posting, filing, generating official documents, import finalization, inventory costing, depreciation, and service-owned mutations must go through trusted backend or Edge Function paths.

### 17. Release Gates Are Real

A release candidate must pass architecture, database, security, accounting, compliance, documentation, and implementation review before being treated as ready.

### 18. Verification Must Be Repeatable

A reviewer must be able to run clear checks to verify table counts, migrations, RLS, policies, constraints, status guards, known exceptions, and readiness state.

### 19. Keep The System Human-Operable

Implementation choices must keep the product understandable to small business users, bookkeepers, accounting firms, owners, and auditors. Complexity must be hidden through setup and workspaces, not ignored.

### 20. Stop When The Contract Breaks

If the architecture, database, RLS, backend, UI, posting engine, report, test, or documentation layer contradicts another layer, stop and reconcile before building further.
