# PXL ERP Canonical Blueprint

**Date:** June 27, 2026

## 1. Purpose
This document reconciles the proposed "Whole ERP Blueprint" against the current PXL ERP repository, database schema, established documentation (including the Master Data Canonical Blueprint), and user interface navigation. It establishes a single, comprehensive source of truth for the entire product architecture, guiding future development while adhering to the core principle of building a serious, Philippine-compliance-first ERP platform.

## 2. Product Philosophy
1. **Compliance First:** Philippine tax and CAS compliance are foundational, not bolted on. Features like 2307s, VAT Relief, and Audit Trails dictate how the core ledger is structured.
2. **Tenant Isolation:** Every operational record is strictly isolated by `company_id` via Row Level Security (RLS).
3. **Framework Driven:** All UI must be driven by standard components (`ErpListHelper`, `ErpFormHelper`, `ErpLookupHelper`) to ensure stability and rapid development.
4. **Clean Navigation:** Users must only see modules that are implemented or intentionally shown as roadmap placeholders. No fake buttons, no dead routes.

## 3. Conflict Analysis (Proposed Blueprint vs. Current Architecture)

| Area | Conflict Detected | Canonical Resolution & Ownership |
| --- | --- | --- |
| **Foundation / Platform** | None. | **Adopted.** These are non-navigable architectural layers (Auth, RLS, Frameworks, Audit) underpinning the system. |
| **Setup vs Master Data** | Proposed places `Department`, `Cost Center`, `Tax Codes` in Master Data or Compliance. | **Modified.** PXL ERP maintains a rigid line: `Setup` covers all prerequisites (Company, Branch, Dept, Fiscal, Taxes, Currencies). `Master Data` strictly covers transactional actors/items (Customers, Suppliers, Items). |
| **Document Numbering** | Proposed splits Numbering into Setup and Document Control. | **Unified.** Number Series and Validation Rules belong together under `Setup > Document Controls`. |
| **Compliance vs Reports** | Proposed separates Compliance and Reports. | **Adopted.** Standard financial reports (P&L, Balance Sheet) live in `Reports`. BIR-mandated exports and tax reports (QAP, SAWT, 2550Q) live strictly in `Compliance`. |
| **Workflow / Controls** | Proposed lists it as a standalone module. | **Deferred/Merged.** Approval matrices and period locking are backend configurations managed under `Setup` and `Compliance`, not an independent user module. |

## 4. Final Canonical Whole ERP Blueprint

This blueprint reflects both the architectural boundaries and the target navigation structure of the application.

### Layer 0: Platform Foundation (Invisible/Backend)
- Authentication & Supabase RLS
- Multi-company / Multi-tenant Context (`activeCompanyId`)
- Core Frameworks (`ErpListHelper`, `ErpFormHelper`, `ErpLookupHelper`, `ErpImportHelper`)
- Immutable Audit Logging & CAS Security

### Layer 1: Setup & Configuration (Prerequisites)
- **Organization:** Company, Branch, Department, Cost Center
- **Accounting Setup:** Fiscal Years, Fiscal Periods, Currencies, Exchange Rates
- **Tax & Compliance Setup:** VAT Codes, EWT/FWT/ATC Codes, BIR Forms, RDO Codes
- **Document Controls:** Number Series, Approval Matrix, Validation Rules

### Layer 2: Master Data (Trade Entities)
- **Parties:** Customers, Suppliers, Employees (Basic Profile), Salespersons, Payment Terms
- **Inventory Base:** Items, Item Categories, UOM, Warehouses, Bin Locations
- **Banking Base:** Company Bank Accounts, Payment Methods

### Layer 3: Transactional Core (The Engines)
- **Sales / AR:** Quotations, Orders, Deliveries, Sales Invoices, AR Collections
- **Purchasing / AP:** Purchase Requests, Purchase Orders, Receiving, Vendor Bills, Payment Vouchers
- **Inventory:** Stock Receipts, Issues, Transfers, Adjustments, Costing/Valuation
- **Banking / Treasury:** Cash Receipts, Disbursements, Bank Reconciliations
- **General Ledger:** Journal Entries, Posting Engine (Deferred Double-Entry), Month-End Closing
- **Fixed Assets:** Acquisition, Depreciation Runs, Disposals

### Layer 4: Reporting & Compliance (The Outputs)
- **Philippine Compliance:** VAT Reports (2550Q, SLSP), WHT Reports (2307, 1601EQ, QAP, SAWT), Statutory Books of Accounts, BIR DAT File Exports.
- **Management Reports:** Financial Statements (Balance Sheet, P&L, Trial Balance), AR/AP Aging, Subsidiary Ledgers, Inventory Movement.

### Layer 5: Future Modules (Deferred)
- Payroll & HRIS
- Point of Sale (POS)
- CRM
- Advanced AI Assistant

## 5. Navigation Principles (UI Alignment)
Reviewing `src/index.html` against this blueprint reveals that the current navigation is relatively clean, but some future roadmap cards are visible (e.g., Sales, Purchasing). 

**Rules for Navigation:**
1. **No Dead Ends:** If a module is visible in the sidebar or a landing page but is not yet implemented (Phase 5+), it must clearly display a "Coming Soon" or "Roadmap" state upon clicking, or safely block navigation. It must not result in an empty screen or a 404.
2. **Current Alignment:** `src/index.html` currently shows `Sales` and `Purchasing` as roadmap landing pages. This is acceptable for blueprinting purposes, provided individual transactional links do not break the app.

## 6. Philippine Compliance Alignment
The proposed compliance module is fully aligned with PXL ERP's vision. The architecture specifically decouples standard financial reporting from BIR compliance to ensure changes in BIR requirements (like CAS or SLSP formatting) do not compromise the integrity of the General Ledger or IFRS reports.

## 7. Notes on Master Data
As established in `MASTER_DATA_CANONICAL_BLUEPRINT.md`, Customer and Supplier records will absorb their respective Contacts and Addresses as encapsulated sub-tables (not root entities).

## 8. Final Recommendation
**Is the proposed Whole ERP Blueprint aligned with PXL ERP?**
**[ PARTIALLY ]**

**Actions Taken:**
- **Adopted:** The comprehensive module breakdown for Sales, Purchasing, Inventory, Banking, and Compliance.
- **Modified:** Re-aligned Setup and Master Data boundaries to strictly match our database constraints and UI frameworks. Grouped "Workflow" back into Setup.
- **Deferred:** Payroll, POS, and CRM remain strictly off the critical path for Phase 1 MVP.

**Conclusion:**
This canonical blueprint stands as the singular map for the entire PXL ERP system. All future architectural decisions, phase planning, and UI routing must adhere to this document. Existing architecture documents (like Database Architecture Overview) remain accurate at a technical schema level, while this document serves as the product-level map. No code or UI changes are necessary at this moment.
