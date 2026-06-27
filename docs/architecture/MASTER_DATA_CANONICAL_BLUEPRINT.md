# Canonical Master Data Blueprint

**Date:** June 27, 2026

## 1. Purpose
This document reconciles the proposed external Master Data blueprint against the existing PXL ERP architecture. It establishes a single canonical source of truth for the classification, ownership, and build order of all foundational entities, ensuring alignment with Philippine compliance and the system's robust tenant-isolation (RLS) architecture.

## 2. Existing vs. Proposed Blueprint Summary

**Existing PXL ERP Architecture (`MASTER_DATA_BUILD_ORDER.md`, `src/index.html`):**
- Strictly separates "Setup" (Configuration & Reference Data) from "Master Data" (Trade Entities).
- Enforces a rigid, cascading build order (Branch → Department → Cost Center → Warehouse → Currencies → Payment Terms → Customer → Vendor → COA).
- Tax and Compliance are independent setup pillars, not buried under Accounting.

**Proposed Blueprint:**
- Groups all 10 areas (Organization, Parties, Accounting, Sales, Purchasing, Inventory, Banking, Compliance, Document Control, Reference) under a monolithic "MASTER DATA" umbrella.
- Redundantly classifies `Warehouse` under both Organization and Inventory.
- Promotes child entities (`Contact Persons`, `Address Book`) to root modules.

## 3. Conflict Analysis

| Area / Entity | Existing Blueprint | Proposed Blueprint | Conflict? | Resolution / Recommendation |
| --- | --- | --- | --- | --- |
| **Warehouse & Location** | Master Data (Sequential) | Organization AND Inventory | **YES** | **Inventory.** Warehouses and bins are operational inventory constructs. They are scoped to Branches (Organization), but their ownership belongs to the Inventory domain. |
| **Setup vs Master Data** | Split | Unified | **YES** | **Split.** PXL ERP maintains a strict UI and architectural boundary between System Configuration/Setup (Company, Branch, Taxes) and Master Data (Customers, Suppliers, Items). |
| **Contact Persons / Address Book** | Child Tables | Root Entities | **YES** | **Child Tables.** Contacts and Addresses have no independent existence outside of a Customer, Supplier, or Employee. They remain sub-tables, not root master data modules. |
| **Employee & Salesperson** | Parties / Setup | Parties | **NO** | **Parties.** Basic Employee records are necessary for User linking and Salespersons. Full HR/Payroll attributes remain deferred. |
| **Tax Codes & Compliance** | Tax Setup / Compliance | Accounting & Compliance | **YES** | **Compliance.** VAT, EWT, FWT, ATC, and PTU/CAS must be grouped strictly under Compliance/Tax Setup, completely independent of the Chart of Accounts. |
| **Number Series** | Setup / Global | Document Control / Banking | **YES** | **Document Control.** Number Series governs all module sequences globally and belongs strictly to Document Control / Setup. |
| **Payment Terms** | Master Data | Accounting | **YES** | **Master Data.** Payment terms are commercial rules governing AR/AP and belong in Master Data alongside Customers and Suppliers. |

## 4. Final Canonical Blueprint

The blueprint is strictly partitioned into **System Setup & Configuration** (prerequisites) and **Master Data** (transactional actors/items).

### PART A: System Setup & Configuration (Prerequisites)
1. **Organization**
   - Company (Root)
   - Branch (Operational Node)
   - Department (Hierarchical Node)
   - Cost Center (Financial Node)
2. **Compliance & Tax Setup**
   - VAT Codes & Taxpayer Classifications
   - EWT / FWT / ATC Codes
   - BIR Forms & RDO Codes
   - CAS / PTU Registrations
3. **Accounting & Financial Setup**
   - Fiscal Years & Periods
   - Currencies & Exchange Rates
   - Chart of Accounts & Account Groups
4. **Document Control**
   - Global Number Series
   - Approval Matrix & Validation Rules

### PART B: Master Data (Trade Entities)
5. **Parties (Commercial & Internal)**
   - Payment Terms (Shared commercial rule)
   - Customer (Includes Addresses & Contacts)
   - Supplier / Vendor (Includes Addresses, Contacts, & Banks)
   - Employee (Basic identity) & Salesperson
6. **Inventory & Items**
   - Units of Measure (UOM) & Conversions
   - Item Categories & Groups
   - Items & Services
   - Warehouse (Scoped to Branch) & Bin Locations
7. **Banking / Treasury**
   - Company Bank Accounts
   - Payment / Collection Methods

### PART C: System Reference (Seed Data)
8. **Global Reference**
   - Countries, Regions, Provinces, Cities
   - PSIC Codes, Industries, Banks

## 5. Ownership Rules & Module Design Guidelines

1. **Entity Sovereignty:** Master data entities must not cross domains. A `Warehouse` belongs to Inventory, not Organization.
2. **Sub-table Encapsulation:** `customer_addresses` and `customer_contacts` must be managed exclusively through the Customer module. They will not have standalone list pages.
3. **Golden Dependency Chain:** You cannot build a Customer without first having Payment Terms and Currencies. You cannot build a Chart of Accounts without first establishing Tax Codes and Cost Centers.
4. **Philippine Compliance First:** TINs, Branch Codes, Tax Types (VAT/Non-VAT), and Government/PEZA flags are mandatory attributes on Party masters, not optional extensions.

## 6. Build Order Adjustments
The existing `MASTER_DATA_BUILD_ORDER.md` remains the **authoritative sequence** for development. The canonical blueprint above categorizes the modules, but the *build execution* must follow the established sequential dependency graph to guarantee RLS and foreign key integrity.

## 7. Final Recommendation
**Is the proposed blueprint aligned with the current PXL ERP architecture?**
**[ PARTIALLY ]**

The proposed blueprint correctly identifies the necessary ERP entities but categorizes them incorrectly for PXL ERP's architecture. By attempting to flatten "Setup" into "Master Data", treating child tables as root entities, and duplicating `Warehouse`, it violates our strict dependency and ownership rules. 

**Conclusion:** The Canonical Blueprint documented here supersedes the external proposal, retaining the exact tables required but correctly applying PXL ERP's architectural boundaries. No database schemas or migrations need to be altered as our current trajectory is fully aligned with this canonical model.
