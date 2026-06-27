# Customer Master Architecture

## 1. Overall Philosophy
The Customer Master in PXL ERP is the **Golden Reference** for all future entity frameworks (Suppliers, Employees, Warehouses, Banks). It represents the foundation of the Order-to-Cash (O2C) lifecycle. 

This architecture rejects the simplistic "flat table" approach found in basic CRUD apps. Instead, it mirrors enterprise systems (SAP, NetSuite, Dynamics) by adopting a **Composed Entity** model. A customer is not just a name; it is a financial, logistical, and compliance profile aggregated into a single operational concept.

## 2. The Composed Entity Model
A Customer consists of:
- **Core Identity:** Legal name, trade name, structural type (Individual vs. Corporate).
- **Compliance & Tax Profile:** TIN, VAT status, BIR classification (PEZA, BOI, Government).
- **Financial Profile:** Default currency, AR accounts, credit limits, payment terms.
- **Logistical Profile:** Unlimited addresses (Bill-To, Ship-To).
- **Communication Profile:** Unlimited contacts (Accounting, Procurement, Executive).

By separating these domains into dedicated tables (e.g., `customer_addresses`, `customer_contacts`), we ensure horizontal scalability. When a customer adds 50 retail branches, the system scales without altering the core customer record.

## 3. Philippine Compliance First
PXL ERP is explicitly designed for Philippine taxation and BIR CAS (Computerized Accounting System) compliance. 
The Customer Master anticipates:
- **EWT (Expanded Withholding Tax):** Differentiating Corporate vs. Individual entities dictates EWT rates.
- **VAT Computations:** Distinguishing between VAT, Zero-Rated (PEZA), and Exempt.
- **Relief / Alpha Lists:** Capturing exact Registered Names, TINs, and branch codes (TIN suffixes) exactly as the BIR requires for SLSP and QAP.

## 4. Audit & History Considerations
Enterprise ERPs require stringent audit trails.
- **Immutability of IDs:** UUIDs are used to prevent breaking transactions when a customer's name changes.
- **Soft Deletion:** Customers cannot be hard-deleted if transactions exist. They are marked `is_active = false`.
- **System Timestamps:** `created_at`, `created_by`, `updated_at`, `updated_by` are enforced on every table.

## 5. Future Extensibility
The architecture explicitly leaves hooks for future modules:
- **CRM Integration:** Lead tracking, opportunities.
- **E-Commerce:** Web storefront customer linking.
- **Project Accounting:** Defaulting projects to specific customers.
- **Multi-Subsidiary / Multi-Branch:** Allowing a customer to be shared globally or restricted to a specific branch.
