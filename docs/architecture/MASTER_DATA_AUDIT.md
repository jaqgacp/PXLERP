# Master Data Architectural Audit

## Executive Summary
Master Data is the Single Source of Truth for PXL ERP. Following the "Capture Once, Reuse Forever" mandate, the Master Data layer must be robust enough to satisfy the needs of Accounting, Treasury, Compliance, and reporting, without forcing users to re-encode details across modules.

This audit evaluates the current Master Data tables against enterprise standards (NetSuite, SAP Business One).

---

## 1. Companies & Branches (Golden Reference)
**Status:** Highly robust and future-proof.
**Findings:**
* The separation of `base_tin` (Company) and `branch_code` (Branch) perfectly aligns with Philippine Compliance requirements.
* Detailed fields for PTU/CAS No., industry classification, and RDO codes are excellent for generating accurate BIR forms (1601EQ, 2550Q, 1702).
* **Missing element:** Historical address tracking. If a Branch moves, we must retain the old address for historical reprints of Invoices. The transaction tables must snapshot the address at the time of posting.

## 2. Departments & Cost Centers
**Status:** Requires structural review.
**Findings:**
* Departments often reflect organizational hierarchy, while Cost Centers reflect financial tracking. 
* **Missing elements for future-proofing:**
  * **Hierarchy:** Both need a `parent_id` to support nested reporting (e.g., Marketing -> Digital Marketing).
  * **Manager Assignment:** Linking a Cost Center to an Employee ID or User ID for approval routing (Approval Matrix integration).

## 3. Currencies & Exchange Rates
**Status:** Requires structural review.
**Findings:**
* Base currency is defined at the Company level. 
* **Missing elements:** A dedicated `exchange_rates` table is necessary to track daily or period-average rates for multi-currency transactions. Future AI can automatically fetch these from the BSP.

## 4. Fiscal Years & Periods
**Status:** Future-proof.
**Findings:**
* The separation of Fiscal Year and Fiscal Periods (12 or 13 periods) is standard enterprise practice. 
* Period locking mechanisms (allowing AR to be locked while GL remains open for adjustments) must be enforced at the Period level, utilizing granular status flags (e.g., `is_ar_closed`, `is_ap_closed`, `is_gl_closed`) instead of a single `is_closed` boolean.

## 5. Users, Roles, and Permissions
**Status:** Basic setup.
**Findings:**
* Relying heavily on Supabase Auth.
* Enterprise ERPs require highly granular Role-Based Access Control (RBAC). 
* **Future need:** The permissions matrix must support Contextual Data Access (e.g., User A can create Invoices for Branch X, but only view Invoices for Branch Y). Simple boolean permissions per role are insufficient for a 1,000+ employee deployment.

## 6. Number Series
**Status:** Requires advanced structural review.
**Findings:**
* The `number_series` configuration must support:
  * **Prefix / Suffix mapping** (e.g., `INV-2026-0001`).
  * **Branch isolation** (Branch A uses a different sequence than Branch B for Sales Invoices).
  * **Reset frequency** (Continuous, Annual reset, Monthly reset).
  * **BIR compliance:** Official Receipts (OR) and Sales Invoices (SI) usually require sequential integrity and cannot have gaps. The system must lock a number sequence to prevent gap generation upon transaction rollback.

## 7. Approval Matrix
**Status:** Conceptual.
**Findings:**
* Must be decoupled from hardcoded logic. 
* Needs to support condition-based routing (e.g., "If PO Amount > 50,000 PHP, require CFO Approval, else require Manager Approval"). 
* Should integrate with the `departments` and `cost_centers` manager assignments.
