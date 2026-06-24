# PXL ERP Reporting Principles

Version: PXL Constitution v1.0
Status: Canonical governing principles
Scope: Operational reports, financial reports, dashboards, exports, generated documents, compliance files, and report visibility

## Purpose

This document defines the permanent reporting principles for PXL ERP. Reports must be trusted outputs that users can reconcile to source data.

## Core Reporting Principles

### 1. Reports Are Outputs

Reports, dashboards, widgets, exports, and generated documents derive from governed source records. They must not become independent sources of accounting truth.

### 2. Every Number Must Be Traceable

A report amount must trace to source transactions, posting rules, journal entries, ledger entries, tax records, or compliance records as applicable.

### 3. Drilldown Is A Requirement

Financial, tax, audit, and management reports must support drilldown paths from summary to detail. The user must be able to explain where a number came from.

### 4. Report Definitions Are Metadata

Report availability, grouping, placement, feature gating, workspace inclusion, and role assignment must be metadata-driven through the feature catalog and workspace/report tables.

### 5. No Hardcoded Report Menus

The UI must not hardcode report lists per role, module, company, or user. Report visibility must come from feature visibility, workspace metadata, permissions, and user preference.

### 6. Dashboards Must Be Reconciled

Dashboard widgets that show financial, inventory, tax, cash, sales, purchasing, or compliance values must reconcile to reports or source records.

### 7. Generated Documents Are Governed Outputs

Invoices, receipts, forms, certificates, tax files, export files, and other generated documents must have metadata, status, owner, generation time, source references, file hash where applicable, and audit trail.

### 8. Export History Matters

Exports must be traceable to user, time, source filters, file type, record count, and generated file metadata where applicable.

### 9. Filed Reports Are Protected

Reports or compliance outputs that have been filed, submitted, locked, or officially used must not be silently regenerated as if they were unchanged. Amendments must be traceable.

### 10. Report Security Follows Data Security

A report must not reveal records the user cannot access through RLS and permissions. Aggregates must also respect company and branch access rules.

### 11. Report Labels Must Match Canonical Terms

Report names, column labels, status labels, tax labels, and document labels must align with architecture and database terminology.

### 12. Reports Must Respect Periods

Financial and tax reports must respect fiscal years, fiscal periods, lock dates, filing periods, and effective-dated rules.

### 13. Compliance Reports Must Match PH Rules

Philippine compliance reports must follow the approved compliance profile, tax setup, withholding setup, filing status, and required source snapshots.

### 14. Report Performance Must Be Designed

High-use report paths must have appropriate indexes, summary strategy, or service design. Performance improvements must not bypass source traceability.

### 15. Report Tests Are Required

Report implementation must include tests or verification scenarios for source reconciliation, permission boundaries, period filters, status filters, exported output, and drilldown links.

### 16. Reports Must Be Documented

Each report must have a documented purpose, source tables, filters, security behavior, calculation rules, drilldown path, and expected user documentation.
