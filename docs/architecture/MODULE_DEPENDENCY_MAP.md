# Module Dependency Map

**Date:** June 26, 2026

## Objective
This document maps the architectural dependencies across the entire PXL ERP system. Understanding these relationships is critical to prevent circular dependencies and to ensure that foundational data exists before dependent records are created.

## Core Hierarchy

```mermaid
graph TD
    Company --> Branch
    Branch --> Department
    Department --> Employee
    Branch --> CostCenter
    Branch --> Warehouse
    Warehouse --> Location
```

## External Parties

```mermaid
graph TD
    PaymentTerms --> Customer
    Currency --> Customer
    Customer --> Contact
    Customer --> Sales
    
    PaymentTerms --> Vendor
    Currency --> Vendor
    Vendor --> Contact
    Vendor --> Purchasing
```

## Inventory & Items

```mermaid
graph TD
    UOM --> Item
    ItemCategory --> Item
    TaxCode --> Item
    Item --> Inventory
    Warehouse --> Inventory
    Item --> Sales
    Item --> Purchasing
```

## Financials & Compliance

```mermaid
graph TD
    Currency --> ChartOfAccounts
    TaxCode --> ChartOfAccounts
    CostCenter --> ChartOfAccounts
    
    ChartOfAccounts --> PostingEngine
    Sales --> PostingEngine
    Purchasing --> PostingEngine
    Inventory --> PostingEngine
    
    PostingEngine --> FinancialStatements
    PostingEngine --> ComplianceReports
```

## Full System Overview

- **Company** is the root node of the entire ERP.
- **Branch** is the primary operational hub.
- **Chart of Accounts** and **Tax Codes** are the ultimate downstream receivers of all transactional data.
- **Posting Engine** serves as the central clearinghouse bridging operational modules (Sales, Purchasing, Inventory) to the General Ledger.
