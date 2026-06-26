# Database Architecture Audit

## Executive Summary
The PXL ERP database schema (currently managed through 31 Supabase migrations up to `018g`) lays a strong, normalized foundation for a multi-entity Philippine-compliance ERP. The architecture correctly separates Master Data, Sales, Purchasing, Inventory, Fixed Assets, Accounting, and Compliance domains.

However, to support future scale (5+ years, 10,000+ companies, millions of transactions, AI readiness), several structural patterns must be hardened *before* building transaction engines.

---

## 1. Tenant Isolation & Company Context
**Current Implementation:** 
Most tables utilize a `company_id` column. Row Level Security (RLS) policies enforce `company_id = get_active_company_id()` utilizing Supabase session variables or custom JWT claims.
**Risks & Recommendations:**
* **Cross-Company Consolidation:** Hard isolation prevents a single user from running a consolidated AR report across 5 branches/companies simultaneously without bypassing RLS or executing multiple queries.
* **Shared Master Data:** Currently, Items, Item Categories, and Chart of Accounts appear to require per-company duplication or cross-company linking. A `shared` tenant concept (e.g., `company_id IS NULL` for global templates) should be explicitly modeled if needed.

## 2. Audit Trails & Immutability
**Current Implementation:** 
Standard `created_at`, `updated_at`, `created_by`, `updated_by` columns exist.
**Risks & Recommendations:**
* **Trigger Consistency:** `updated_at` must be strictly enforced via database triggers on *every* table, rather than relying on the frontend or API to supply the current timestamp.
* **Transaction Immutability:** Financial records (Journal Entries, Invoices) require a strict Append-Only / Reversal pattern. `018d_immutability_guards.sql` introduces guards, which is excellent, but we must ensure `voiding` a document creates a reversal entry rather than physically deleting or merely updating a status.
* **Change Data Capture (CDC):** For enterprise auditability, an `audit_logs` table (or leveraging Supabase pgAudit/Realtime CDC) is necessary to track *what* fields changed (Old Value -> New Value) for critical Master Data (e.g., changing a supplier's Bank Account).

## 3. Soft Delete Implementation
**Current Implementation:**
Relies on an `is_active` boolean for Master Data.
**Risks & Recommendations:**
* This is sufficient for Master Data (disabling a Branch). 
* However, transactions should *never* have a soft delete. They must be Voided.
* Ensure no `ON DELETE CASCADE` rules exist that could wipe out historical financial data if a parent record is accidentally deleted by a superadmin.

## 4. Foreign Keys and Indexes
**Current Implementation:**
Foreign keys are well-defined.
**Risks & Recommendations:**
* **Indexing Strategy:** Foreign keys are not automatically indexed in PostgreSQL. We must explicitly index `company_id`, `branch_id`, `customer_id`, `vendor_id`, `item_id`, and date fields (like `posting_date`, `document_date`) across all transaction tables, or performance will degrade severely at 1 million+ rows.

## 5. Compliance & Reporting Readiness
**Current Implementation:**
Strict columns for `base_tin`, `branch_code`, `rdo_code`, `tax_type`.
**Risks & Recommendations:**
* **Historical Accuracy:** If a Customer changes their TIN or Address in 2028, a Sales Invoice printed from 2026 must show the *old* TIN and Address. 
* **Snapshotting:** Transaction tables (Invoices, POs) must snapshot the Master Data fields (Customer Name, TIN, Address) at the time of posting. Relying purely on a JOIN to `customers` will alter historical documents, violating BIR/CAS requirements.

## 6. AI Readiness
**Current Implementation:**
Highly normalized relational data.
**Risks & Recommendations:**
* AI models struggle with complex 10-table joins. We should plan to build Materialized Views or regular Views (e.g., `vw_sales_analysis`, `vw_expense_trends`) that flatten transaction data into a denormalized semantic layer for LLMs to query easily.
