# Master Data Build Order

**Date:** June 26, 2026

## Objective
This document defines the strict sequential order in which Master Data modules must be developed. Adhering to this build order ensures that foundational entities are constructed first, providing a stable baseline for dependent modules and preventing costly schema refactors later.

## Official Development Sequence

1. **Branch**
   - *Rationale:* The primary operational and compliance identity below Company. Nearly every other entity (Warehouses, Departments, Cost Centers, Transactions) must be scoped to a Branch.
2. **Department**
   - *Rationale:* Represents the organizational hierarchy within a Branch. Required for grouping Employees and Cost Centers.
3. **Position**
   - *Rationale:* Job titles and roles. Prerequisite for assigning Employees to Departments.
4. **Cost Center**
   - *Rationale:* Financial tracking segments. Depends directly on Branch and Department structures.
5. **Warehouse**
   - *Rationale:* Physical locations for inventory. Must be scoped to a specific Branch.
6. **Location**
   - *Rationale:* Bins or specific areas within a Warehouse. Depends on Warehouse.
7. **Unit of Measure**
   - *Rationale:* Global setup required before defining Items or Services.
8. **Currency**
   - *Rationale:* Global setup required for Pricing, Customers, Vendors, and the Chart of Accounts.
9. **Payment Terms**
   - *Rationale:* Shared Master Data required before onboarding Customers and Vendors.
10. **Customer**
    - *Rationale:* External party for Sales. Requires Payment Terms, Currencies, and Branches (for default assignment).
11. **Vendor**
    - *Rationale:* External party for Purchasing. Similar prerequisites as Customer.
12. **Contact**
    - *Rationale:* Specific individuals tied to Customers or Vendors. Depends on the parent entity.
13. **Employee (basic)**
    - *Rationale:* Internal personnel. Requires Department and Position to be fully established.
14. **Tax Codes**
    - *Rationale:* The compliance foundation (VAT, EWT, FWT, ATC) required for both Sales and Purchasing. Must be set up before standardizing the Chart of Accounts.
15. **Chart of Accounts (COA)**
    - *Rationale:* The ultimate destination for all financial transactions. COA design relies heavily on how Tax Codes, Cost Centers, and Currencies are mapped.

## Rule of Progression
A module from this list cannot begin development until the preceding module has been marked **Golden Certified** by the Product Owner.
