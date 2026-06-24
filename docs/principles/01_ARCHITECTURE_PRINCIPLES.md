# PXL ERP Architecture Principles

Version: PXL Constitution v1.0
Status: Canonical governing principles
Scope: All PXL ERP architecture, database, backend, UI, reporting, compliance, and migration work

## Purpose

This document defines the permanent architecture principles for PXL ERP. It consolidates the original architecture documents, owner decisions, foundation reviews, and Migration 018 planning into one durable rule set.

When this document conflicts with older planning notes, this document controls unless a newer owner decision explicitly supersedes it.

## Core Architecture Principles

### 1. Relevance First

PXL ERP must fit Philippine business operations first. The system must avoid generic enterprise complexity unless it directly supports Phase 1 requirements, Philippine compliance, reliable accounting, or low-maintenance operation.

### 2. Low Maintenance By Design

The system must reduce long-term maintenance effort. New behavior should be added through configuration, metadata, rules, and rows before adding hardcoded logic or new columns.

### 3. Stable And Trustworthy

Accounting, compliance, posting, audit, and reporting behavior must be predictable. A user must be able to trace how data entered the system, how it was posted, who approved it, what changed, and how it appeared in reports.

### 4. One Database, Configurable Behavior

PXL ERP uses one shared product database design. Company-specific behavior must be controlled through setup, feature catalog records, compliance profiles, permissions, posting rules, approval rules, workspace metadata, and other configuration records.

### 5. No Hardcoded Business Logic

The system must not hardcode roles, menus, dashboards, approval flows, feature visibility, tax behavior, report availability, or workflow routing in application code. Business behavior belongs in database-backed configuration and documented rules.

### 6. Tables First, UI Second

Every business capability must be represented correctly in the architecture and database before the UI is built. UI work cannot invent business rules that are absent from the architecture, schema, RLS policy, backend service, posting engine, report contract, test case, and user documentation chain.

### 7. Complete Requirement Traceability

Every feature must follow this chain:

Business Requirement -> Architecture Document -> Database Table -> Migration -> RLS Policy -> Backend Service -> UI Form -> Posting Engine -> Report -> Test Scenario -> User Documentation

If a required link is missing, implementation must stop until the link is defined or formally declared not applicable.

### 8. PH Compliance First

Philippine compliance is a core architecture requirement, not an optional add-on. VAT, EWT, FWT, percentage tax, income tax support, SLSP, RELIEF, QAP, SAWT, certificates, books, generated documents, and CAS readiness must be traceable to source transactions.

### 9. Multi-Company Ready

The architecture must support multiple companies in one installation. Operational records must be company scoped unless they are true global reference data or explicitly documented as system scoped.

### 10. Multi-Branch Ready

The architecture must support companies with one branch, many branches, or department-based operations. Branch and department dimensions must be available where operationally relevant without forcing unnecessary complexity on small businesses.

### 11. Small Business And Firm Friendly

The same architecture must support:

- A small business with one bookkeeper.
- An accounting firm handling multiple client companies.
- A larger company using departments, branches, approvals, and role-based access.

The difference must come from setup and workspace configuration, not separate products.

### 12. Adaptive Workspace Is Non-Negotiable

Navigation, dashboards, reports, widgets, pages, and workspace visibility must be metadata-driven. The Adaptive Workspace model is part of Phase 1 foundation and cannot depend on hardcoded menu arrays or fixed boolean feature columns.

### 13. Feature Catalog Is Canonical

`feature_definitions` is the canonical feature catalog. It governs modules, pages, dashboards, reports, widgets, workspaces, company feature visibility, and future feature expansion.

`company_feature_settings` may remain as high-level company setup flags, but it must not be the only feature catalog and must not replace `feature_definitions`.

### 14. Configuration Before Code

When a new module, page, dashboard, report, approval route, workspace, or feature is needed, the first design question is which metadata or setup records should represent it. Code should consume configuration; it should not become the configuration.

### 15. Audit Is Non-Negotiable

Every meaningful business event must be auditable. The system must record who performed the action, when it happened, what changed, and how the record relates to source documents, postings, reports, attachments, and generated compliance output.

### 16. Posting Is Rule-Based

Accounting postings must come from posting rules and service-controlled posting logic. No module may directly write hidden journals, bypass posting rules, or create ledger entries that cannot be traced back to a source record.

### 17. Posted Records Are Immutable

Posted, filed, locked, voided, reversed, cancelled, or completed business records must not be edited casually. Corrections must use controlled reversal, adjustment, credit, debit, amendment, or voiding workflows.

### 18. Reports Are Outputs, Not Sources Of Truth

Reports, dashboards, exports, generated documents, and compliance files are outputs derived from governed source tables. They must not become the primary accounting truth.

### 19. Effective Dates And Snapshots Are Required

Tax rules, compliance profiles, posting rules, document layouts, prices, terms, and other time-sensitive business rules must be versioned or snapshotted where historical accuracy matters.

### 20. Import And Export Are First-Class

Imports, exports, generated documents, and machine-readable compliance files must be traceable, auditable, and recoverable. Bulk processes must have job records, error records, and source mapping where applicable.

### 21. Security And RLS First

Security must be designed before CRUD. RLS, role permissions, company visibility, branch access, workspace assignment, and service-role boundaries must be defined before user-facing data entry begins.

### 22. Supabase Reality

The architecture must respect Supabase constraints and strengths: PostgreSQL-first design, RLS-first access, Edge Functions for privileged server operations, storage metadata for files, forward-only migrations, and clean environment verification.

### 23. Performance By Design

Core relationships, tenant filters, posting paths, report paths, and import paths must have appropriate keys and indexes. Performance work must support real business correctness, not premature optimization.

### 24. Avoid Overengineering

The architecture must be complete enough for Phase 1 but not inflated with speculative enterprise features. Optional future modules must be enabled by metadata and clean extension points, not implemented before they are required.

### 25. No Final Without Review

Foundation, schema, RLS, posting, compliance, UI, and report contracts must pass review before being treated as frozen. A release candidate is only ready when documentation, migrations, policies, tests, and implementation behavior agree.
