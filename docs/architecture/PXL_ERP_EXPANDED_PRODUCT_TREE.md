# PXL ERP Expanded Product Tree

**Date:** June 27, 2026

## 1. Purpose
This document provides the actual expanded canonical PXL ERP blueprint tree based on the committed repository state, the `PXL_ERP_CANONICAL_BLUEPRINT.md`, and the unwavering Philippine Compliance-First vision. It visually unpacks the product map into its granular features, establishing the final required UI structure, identifying implementation gaps, and ensuring no compliance or operational depth is accidentally lost.

## 2. Status Legend
- `[DONE]` Implemented and usable
- `[PARTIAL]` Partially implemented
- `[ARCH]` Architecture/design exists only (Database schemas or blueprints)
- `[ROADMAP]` Planned future module (No schema or code yet)
- `[HIDDEN]` Should not appear in current UI yet
- `[REVIEW]` Needs ownership/navigation review

---

## 3. Expanded Canonical Product Tree

```text
PXL ERP
│
├─ 1. Foundation / Platform (Layer 0)
│  ├─ Authentication [DONE]
│  ├─ Multi-company / Multi-tenant [DONE]
│  ├─ Active Company Context [DONE]
│  ├─ Role-Based Access Control [ARCH]
│  ├─ Audit Trail [PARTIAL]
│  ├─ Import Framework [DONE]
│  ├─ Lookup Framework [DONE]
│  ├─ List Framework (ErpListHelper 2.0) [DONE]
│  ├─ Form Framework (ErpFormHelper) [DONE]
│  ├─ Company Bootstrap [DONE]
│  ├─ Seed Data [DONE]
│  ├─ Documentation Standards [DONE]
│  ├─ Toolbar Standard [DONE]
│  └─ Navigation Standard [DONE]
│
├─ 2. Setup / Configuration (Layer 1)
│  ├─ Organization
│  │  ├─ Company Setup [DONE]
│  │  ├─ Branch Setup [DONE]
│  │  ├─ Department [DONE]
│  │  ├─ Cost Center [DONE]
│  │  └─ Projects / Jobs [ROADMAP]
│  │
│  ├─ Accounting Setup
│  │  ├─ Fiscal Years [DONE]
│  │  ├─ Fiscal Calendar [DONE]
│  │  ├─ Currency [DONE]
│  │  └─ Exchange Rates [ROADMAP]
│  │
│  ├─ Document Controls
│  │  ├─ Number Series [PARTIAL]
│  │  ├─ Approval Matrix [ROADMAP]
│  │  ├─ Validation Rules [ROADMAP]
│  │  └─ Document Templates [ROADMAP]
│  │
│  ├─ Tax & Compliance Setup
│  │  ├─ Tax Setup [ARCH]
│  │  └─ CAS / PTU / ATP Setup [ARCH]
│  │
│  └─ System Admin
│     ├─ Users / Roles [PARTIAL]
│     └─ System Parameters [ROADMAP]
│
├─ 3. Master Data (Layer 2)
│  ├─ Parties
│  │  ├─ Customers [PARTIAL]
│  │  │  ├─ Customer Addresses [HIDDEN]
│  │  │  └─ Customer Contacts [HIDDEN]
│  │  ├─ Suppliers [ARCH]
│  │  │  ├─ Supplier Addresses [HIDDEN]
│  │  │  └─ Supplier Contacts [HIDDEN]
│  │  ├─ Employees (Lite) [ROADMAP]
│  │  └─ Payment Terms [ARCH]
│  │
│  ├─ Item Master
│  │  ├─ Items [ARCH]
│  │  ├─ Item Categories [ARCH]
│  │  └─ Units of Measure [ARCH]
│  │
│  ├─ Inventory Setup
│  │  └─ Warehouses [ARCH]
│  │
│  ├─ Banking Setup
│  │  └─ Banks [ROADMAP]
│  │
│  └─ Accounting Setup
│     └─ Chart of Accounts [ARCH]
│
├─ 4. Sales / AR (Layer 3)
│  ├─ Transactions
│  │  ├─ Quotations [ROADMAP]
│  │  ├─ Sales Orders [ROADMAP]
│  │  ├─ Delivery Receipts [ROADMAP]
│  │  ├─ Sales Invoices [ROADMAP]
│  │  ├─ Cash Sales [ROADMAP]
│  │  ├─ Credit Memos [ROADMAP]
│  │  ├─ Debit Memos [ROADMAP]
│  │  ├─ Customer Returns [ROADMAP]
│  │  └─ Receipts / Collections [ROADMAP]
│  │
│  ├─ Receivables
│  │  ├─ Customer Ledger [ROADMAP]
│  │  ├─ AR Aging [ROADMAP]
│  │  └─ Statement of Account [ROADMAP]
│  │
│  ├─ Registers
│  │  └─ Sales Registers [ROADMAP]
│  │
│  └─ Tax Review
│     ├─ Output VAT Review [ROADMAP]
│     ├─ Percentage Tax Review [ROADMAP]
│     ├─ 2307 Received Review [ROADMAP]
│     └─ SLS [ROADMAP]
│
├─ 5. Purchasing / AP (Layer 3)
│  ├─ Transactions
│  │  ├─ Purchase Requests [ROADMAP]
│  │  ├─ Purchase Orders [ROADMAP]
│  │  ├─ Receiving Reports [ROADMAP]
│  │  ├─ Vendor Bills [ROADMAP]
│  │  ├─ Cash Purchases [ROADMAP]
│  │  ├─ Payment Vouchers [ROADMAP]
│  │  ├─ Vendor Credits [ROADMAP]
│  │  ├─ Debit Memos to Suppliers [ROADMAP]
│  │  └─ Purchase Returns [ROADMAP]
│  │
│  ├─ Payables
│  │  ├─ Supplier Ledger [ROADMAP]
│  │  ├─ AP Aging [ROADMAP]
│  │  └─ Payment Monitoring [ROADMAP]
│  │
│  ├─ Registers
│  │  └─ Purchase Registers [ROADMAP]
│  │
│  └─ Tax Review
│     ├─ Input VAT Review [ROADMAP]
│     ├─ EWT Summary [ROADMAP]
│     ├─ 2307 Issued Review [ROADMAP]
│     └─ SLP [ROADMAP]
│
├─ 6. Inventory (Layer 3)
│  ├─ Operations
│  │  ├─ Inventory Dashboard [ROADMAP]
│  │  ├─ Physical Count [ROADMAP]
│  │  └─ Inventory Movements [ROADMAP]
│  │
│  ├─ Transactions
│  │  ├─ Stock Adjustments [ROADMAP]
│  │  ├─ Stock Transfers [ROADMAP]
│  │  └─ Goods Issue [ROADMAP]
│  │
│  └─ Costing & Ledger
│     ├─ Inventory Valuation [ROADMAP]
│     ├─ Costing [ROADMAP]
│     └─ Stock Ledger [ROADMAP]
│
├─ 7. Banking / Treasury (Layer 3)
│  ├─ Cash Operations
│  │  ├─ Cash Receipts [ROADMAP]
│  │  ├─ Cash Disbursements [ROADMAP]
│  │  ├─ Bank Deposits [ROADMAP]
│  │  ├─ Fund Transfers [ROADMAP]
│  │  └─ Inter-Branch Transfers [ROADMAP]
│  │
│  └─ Reconciliation
│     ├─ Bank Adjustments [ROADMAP]
│     ├─ Bank Reconciliation [ROADMAP]
│     ├─ Outstanding Checks [ROADMAP]
│     ├─ Deposits in Transit [ROADMAP]
│     ├─ Cash Position [ROADMAP]
│     └─ Check Monitoring [ROADMAP]
│
├─ 8. Fixed Assets (Layer 3)
│  ├─ Setup
│  │  ├─ Asset Categories [ROADMAP]
│  │  └─ Depreciation Profiles [ROADMAP]
│  │
│  ├─ Operations
│  │  ├─ Fixed Asset Dashboard [ROADMAP]
│  │  ├─ Asset Register [ROADMAP]
│  │  ├─ Asset Acquisition [ROADMAP]
│  │  ├─ Depreciation [ROADMAP]
│  │  ├─ Disposal [ROADMAP]
│  │  ├─ Transfer [ROADMAP]
│  │  └─ Impairment [ROADMAP]
│
├─ 9. Accounting Core (Layer 4)
│  ├─ Journals & Engine
│  │  ├─ Journal Entries [ARCH]
│  │  ├─ Recurring Journal Templates [ROADMAP]
│  │  └─ Posting Engine [ARCH]
│  │
│  ├─ Ledgers & Schedules
│  │  ├─ General Ledger [ARCH]
│  │  ├─ Account Detail Ledger [ROADMAP]
│  │  ├─ Trial Balance [ROADMAP]
│  │  ├─ Customer Ledger Accounting View [ROADMAP]
│  │  ├─ Supplier Ledger Accounting View [ROADMAP]
│  │  ├─ Control Account Reconciliation [ROADMAP]
│  │  ├─ Amortization Schedules [ROADMAP]
│  │  └─ Revenue Recognition Schedules [ROADMAP]
│  │
│  ├─ Period Management
│  │  ├─ Period Closing [ARCH]
│  │  ├─ Fiscal Locks [ARCH]
│  │  ├─ Posting Review [ROADMAP]
│  │  └─ Reversal Review [ROADMAP]
│  │
│  └─ Outputs
│     └─ Financial Statements [ROADMAP]
│
├─ 10. Philippine Compliance Engine (Layer 5)
│  ├─ Percentage Tax
│  │  ├─ PT Dashboard [ROADMAP]
│  │  ├─ PT Working Papers [ROADMAP]
│  │  ├─ 2551Q [ROADMAP]
│  │  ├─ PT Reconciliation [ROADMAP]
│  │  ├─ PT Summary Register [ROADMAP]
│  │  ├─ Percentage Tax Codes [ARCH]
│  │  └─ 8% / Non-VAT taxpayer considerations [ROADMAP]
│  │
│  ├─ VAT
│  │  ├─ VAT Dashboard [ROADMAP]
│  │  ├─ VAT Working Papers [ROADMAP]
│  │  ├─ Output VAT Summary [ROADMAP]
│  │  ├─ Input VAT Summary [ROADMAP]
│  │  ├─ VAT Reconciliation [ROADMAP]
│  │  ├─ 2550M [ROADMAP]
│  │  ├─ 2550Q [ROADMAP]
│  │  ├─ SLS [ROADMAP]
│  │  ├─ SLP [ROADMAP]
│  │  ├─ SLSP Export [ROADMAP]
│  │  └─ RELIEF / DAT Export [ROADMAP]
│  │
│  ├─ Withholding Tax
│  │  ├─ WT Dashboard [ROADMAP]
│  │  ├─ EWT Working Papers [ROADMAP]
│  │  ├─ EWT Payable Summary [ROADMAP]
│  │  ├─ EWT Receivable Summary [ROADMAP]
│  │  ├─ ATC Summary [ROADMAP]
│  │  ├─ 1601EQ Working Papers [ROADMAP]
│  │  ├─ 1601EQ [ROADMAP]
│  │  ├─ QAP [ROADMAP]
│  │  ├─ SAWT [ROADMAP]
│  │  ├─ 2307 Issued [ROADMAP]
│  │  ├─ 2307 Received [ROADMAP]
│  │  ├─ 2306 [ROADMAP]
│  │  ├─ FWT Working Papers [ROADMAP]
│  │  ├─ 1601FQ Working Papers [ROADMAP]
│  │  └─ 1601FQ [ROADMAP]
│  │
│  ├─ Income Tax
│  │  ├─ Income Tax Dashboard [ROADMAP]
│  │  ├─ Taxable Income Computation [ROADMAP]
│  │  ├─ Book-to-Tax Reconciliation [ROADMAP]
│  │  ├─ OSD Computation [ROADMAP]
│  │  ├─ NOLCO Schedule [ROADMAP]
│  │  ├─ Tax Credits Schedule [ROADMAP]
│  │  ├─ 1701Q [ROADMAP]
│  │  ├─ 1701 [ROADMAP]
│  │  ├─ 1702Q [ROADMAP]
│  │  ├─ 1702RT [ROADMAP]
│  │  └─ MCIT Computation [ROADMAP]
│  │
│  ├─ Books of Accounts
│  │  ├─ Books Dashboard [ROADMAP]
│  │  ├─ General Journal [ROADMAP]
│  │  ├─ General Ledger Book [ROADMAP]
│  │  ├─ Cash Receipts Book [ROADMAP]
│  │  ├─ Cash Disbursements Book [ROADMAP]
│  │  ├─ Sales Journal [ROADMAP]
│  │  ├─ Cash Sales Journal [ROADMAP]
│  │  ├─ Purchase Journal [ROADMAP]
│  │  ├─ Cash Purchases Journal [ROADMAP]
│  │  ├─ AR Subsidiary Ledger [ROADMAP]
│  │  ├─ AP Subsidiary Ledger [ROADMAP]
│  │  ├─ Inventory Subsidiary Ledger [ROADMAP]
│  │  └─ Fixed Asset Register [ROADMAP]
│  │
│  └─ CAS / Audit
│     ├─ CAS Dashboard [ROADMAP]
│     ├─ Transaction Audit Log [ROADMAP]
│     ├─ Master Data Change Log [ROADMAP]
│     ├─ System Parameter Logs [ROADMAP]
│     ├─ User Activity Log [ROADMAP]
│     ├─ Attachment Register [ROADMAP]
│     ├─ Void Register [ROADMAP]
│     ├─ ATP Usage Log [ROADMAP]
│     ├─ DAT File Generation [ROADMAP]
│     ├─ CAS Audit Report [ROADMAP]
│     └─ Export History [ROADMAP]
│
├─ 11. Reports / Analytics (Layer 6)
│  ├─ Financial Statements [ROADMAP]
│  ├─ Trial Balance Reports [ROADMAP]
│  ├─ Tax Reports [ROADMAP]
│  ├─ Sales Reports [ROADMAP]
│  ├─ Purchase Reports [ROADMAP]
│  ├─ Inventory Reports [ROADMAP]
│  ├─ AR/AP Reports [ROADMAP]
│  ├─ Management Reports [ROADMAP]
│  ├─ Executive Dashboard [ROADMAP]
│  └─ Audit Reports [ROADMAP]
│
├─ 12. Administration / Security
│  ├─ Users [PARTIAL]
│  ├─ Roles [ARCH]
│  ├─ Permissions [ARCH]
│  ├─ Company Access [DONE]
│  ├─ Import History [PARTIAL]
│  ├─ Audit Logs [PARTIAL]
│  └─ System Settings [ROADMAP]
│
└─ 13. Future Modules (Layer 7)
   ├─ Payroll Compliance [ROADMAP]
   ├─ POS Integration [ROADMAP]
   ├─ CRM [ROADMAP]
   ├─ Employee Portal [ROADMAP]
   ├─ Client Portal [ROADMAP]
   ├─ AI Assistant [ROADMAP]
   ├─ Document OCR [ROADMAP]
   └─ Mobile App [ROADMAP]
```

---

## 4. Final User Navigation Tree

This is exactly how the global top navigation sidebar (`src/index.html`) must ultimately look to users, removing redundancies and correctly encapsulating child records.

```text
1. Dashboard
2. Setup
3. Master Data
4. Sales
5. Purchasing
6. Inventory
7. Banking & Treasury
8. Fixed Assets
9. Accounting
10. Compliance
11. Reports
12. Administration
```

---

## 5. Implementation Status Matrix

| Module | Status | Exists in DB? | Exists in UI? | Should appear in nav now? | Notes |
| ------ | ------ | ------------- | ------------- | ------------------------- | ----- |
| **Setup** (Company, Branch, Currency, Fiscal) | `[DONE]` | Yes | Yes | **Yes** | Fully operational. |
| **Setup** (Document Controls, Approvals) | `[ROADMAP]` | No | Placeholder | **Yes** (as roadmap) | UI exists but endpoints deferred. |
| **Master Data** (Customers) | `[PARTIAL]` | Yes | Yes (List/View) | **Yes** | Active module. Needs Edit/Import. |
| **Master Data** (Suppliers, Items) | `[ARCH]` | No | Placeholder | **Yes** (as roadmap) | Next in build order. |
| **Master Data** (Customer Addresses/Contacts) | `[ARCH]` | Yes | Global Link | **NO** (`[HIDDEN]`) | Must be child records inside Customer Form. |
| **Master Data** (Supplier Addresses/Contacts) | `[ARCH]` | No | Global Link | **NO** (`[HIDDEN]`) | Must be child records inside Supplier Form. |
| **Sales** | `[ROADMAP]` | No | Placeholder | **Yes** (as roadmap) | |
| **Purchasing** | `[ROADMAP]` | No | Placeholder | **Yes** (as roadmap) | |
| **Inventory** | `[ROADMAP]` | No | Placeholder | **Yes** (as roadmap) | Successfully split from legacy Assets tab. |
| **Banking & Treasury** | `[ROADMAP]` | No | Placeholder | **Yes** (as roadmap) | Successfully split from legacy Assets tab. |
| **Fixed Assets** | `[ROADMAP]` | No | Placeholder | **Yes** (as roadmap) | Successfully split from legacy Assets tab. |
| **Accounting** | `[ARCH]` | Yes (Core tables)| Placeholder | **Yes** (as roadmap) | Posting engine logic documented heavily. |
| **Compliance** | `[ARCH]` | No | Placeholder | **Yes** (as roadmap) | Unmatched theoretical depth. Awaiting engine. |
| **Reports** | `[ROADMAP]` | No | Placeholder | **Yes** (as roadmap) | |
| **Administration** | `[PARTIAL]` | Yes | No | **Yes** | Needed for user/role management. |

---

## 6. Navigation Cleanup Recommendations

To adhere to this expanded blueprint, the following immediate changes to the UI (`src/index.html`) are mandated:

1. **Split the "Assets" Tab:** The legacy `Assets` navigation item lumps Cash Management, Inventory, and Fixed Assets together. This must be refactored into three distinct root nodes: `Inventory`, `Banking & Treasury`, and `Fixed Assets`.
2. **Hide Child Records from Global Navigation:** `Customer Addresses`, `Customer Contacts`, `Supplier Addresses`, and `Supplier Contacts` must be removed from the Master Data mega-menu. They are encapsulated sub-tables and should only be accessed via their parent's Form view.
3. **No Fake Actions:** Any link pointing to a `[ROADMAP]` feature must safely render a "Coming Soon" or "Roadmap" screen, not an empty or broken page.

---

## 7. Final Confirmation

1. **PH Compliance Identity Preserved:** The deep structural integration of the Philippine Compliance Engine (Percentage Tax, VAT, Withholding, Income Tax, Books, CAS) has been preserved and elevated as a non-negotiable Layer 5 priority.
2. **Percentage Tax Present:** Explicitly mapped and included with dashboards, 2551Q, and reconciliations.
3. **Assets Split Documented:** The mandate to split "Assets" into Inventory, Banking, and Fixed Assets is codified.
4. **Customer Child Records Encapsulated:** Explicitly marked as `[HIDDEN]` in the global navigation and required to be sub-forms.
