# PXL ERP Canonical Blueprint

**Date:** June 27, 2026

## 1. Product Identity
PXL ERP is **not** a generic ERP with optional Philippine localization.
PXL ERP is a **Philippine Compliance-First Accounting ERP**.

Accounting, posting, audit trail, and Philippine statutory compliance are first-class architecture concerns.
Every transaction must eventually support downstream accounting, tax, books of accounts, audit trail, and BIR compliance output.

## 2. PXL Non-Negotiable Architecture Principles
1. **Philippine compliance is first-class.**
2. **Every transaction must trace to journal, ledger, tax impact, audit trail, and compliance output.**
3. **Books of Accounts are legal outputs, not ordinary reports.**
4. **Tax codes are compliance architecture, not merely dropdown values.**
5. **Percentage Tax must not be removed or hidden.**
6. **BIR CAS readiness must influence design from day one.**
7. **Setup defines rules; transactions generate facts; posting records accounting; compliance validates and exports.**
8. **No generic ERP simplification may override Philippine requirements.**
9. **UI must be clean and must not expose fake actions.**
10. **Documentation must remain one source of truth.**

## 3. Final Canonical Whole ERP Blueprint

### Layer 0 — Platform Foundation
- Authentication, RLS, multi-company, active company, framework helpers, audit logging, import framework, lookup framework, list framework, form framework.

### Layer 1 — Setup & Configuration
- Company Setup, Branch Setup, Fiscal Calendar, Currencies, Exchange Rates, Number Series, Users/Roles, Approval Matrix, Validation Rules, Document Templates, System Parameters.

### Layer 2 — Master Data
- Customers, Suppliers, Items, Chart of Accounts, Warehouses, Banks, Projects, Departments, Cost Centers, and other business reference entities.

### Layer 3 — Transactions
- Sales, Purchasing, Inventory, Banking/Treasury, General Ledger, Fixed Assets.

### Layer 4 — Posting & Accounting Core
- Posting Engine, Journal Entries, General Ledger, Subsidiary Ledgers, Trial Balance, Closing Entries, Retained Earnings, Financial Statements.

### Layer 5 — Philippine Compliance Engine
*This is first-class. It is not merely reports or setup. It covers the full lifecycle of tax and audit generation.*

#### Percentage Tax
- Percentage Tax setup, Percentage Tax codes, Percentage Tax working papers, 2551Q, Percentage Tax reconciliation, Percentage Tax summary register, 8% / Non-VAT taxpayer considerations for future.

#### VAT
- VAT setup, VAT codes, VAT dashboard, VAT working papers, Output VAT summary, Input VAT summary, VAT reconciliation, 2550Q, SLS, SLP, SLSP export, RELIEF / DAT export if applicable.

#### Withholding Tax
- EWT codes, FWT codes, ATC codes, EWT working papers, EWT payable, EWT receivable, ATC summary, 1601EQ, 1601FQ, QAP, SAWT, 2307 issued, 2307 received, 2306, Final withholding tax schedules.

#### Income Tax
- Taxable income computation, Book-to-tax reconciliation, OSD computation, NOLCO schedule, Tax credits schedule, 1701Q / 1701, 1702Q / 1702RT, MCIT computation.

#### Books of Accounts
- General Journal, General Ledger Book, Cash Receipts Book, Cash Disbursements Book, Sales Journal, Cash Sales Journal, Purchase Journal, Cash Purchases Journal, AR Subsidiary Ledger, AP Subsidiary Ledger, Inventory Subsidiary Ledger, Fixed Asset Register.

#### CAS / Audit
- Transaction Audit Log, Master Data Change Log, System Parameter Logs, User Activity Log, Attachment Register, Void Register, ATP Usage Log, DAT File Generation, CAS Audit Report, Export History.

### Layer 6 — Reports & Analytics
- Management reports, operational reports, dashboards, financial analytics.

### Layer 7 — Future Extensions
- Payroll Compliance, POS integration, CRM, portals, AI assistant, OCR, mobile app.

## 4. Tax Code Ownership
Tax codes may be configured from the UI under `Setup > Tax Setup`, but architecturally they belong to the **Philippine Compliance Engine**.

**Required Relationship:**
- Setup defines tax rules.
- Sales and Purchasing produce tax data.
- Posting Engine records tax/accounting impact.
- Compliance Engine validates, reconciles, and exports.
- Reports display results.

## 5. Navigation Principles (UI Alignment)
- Implemented pages may be normal clickable pages.
- Roadmap pages may exist only if clearly treated as roadmap/placeholder.
- No fake action buttons.
- No fake transactional workflows.
- No UI pretending unimplemented compliance outputs are already working.

## 6. Implementation Status (Reconciliation with Database)
- **Implemented / Foundation:** Layer 0 and Setup entities (Company, Branch, Dept, Cost Center, Currency, Fiscal Setup).
- **In Progress (Phase 5):** Master Data (Customers, Suppliers, Items).
- **Architecture Designed but Unimplemented:** Layer 4 (Posting Core), Layer 5 (Compliance Engine full pipeline).
- **Future / Deferred:** Layer 3 (Transactions), Layer 6, Layer 7.
