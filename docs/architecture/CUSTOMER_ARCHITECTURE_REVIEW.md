# Customer Architecture Review (Phase 5A.1)

## 1. Executive Summary
The Customer Master architecture underwent a strict review against the existing PXL ERP framework (`004_core_setup.sql`), the `ErpFormHelper`/`ErpListHelper` standards, and Philippine tax realities. The underlying composed-entity design (separating core data, addresses, and contacts) perfectly mirrors enterprise expectations (SAP, NetSuite) while maintaining strict tenant isolation (`company_id`).

## 2. Approved Parts
- **Composed Entity Model:** The separation of `customers`, `customer_addresses`, and `customer_contacts` is approved. It avoids horizontal database bloat and ensures relational purity.
- **Philippine Compliance Strategy:** The baseline fields (`entity_type`, `tin`, `tin_suffix`, `tax_type`, `classification`) provide a fully compliant foundation capable of supporting BIR Form 2307, EWT scaling, and VAT mapping later.
- **Framework Synergy:** Heavy reliance on `ErpListHelper 2.0`, `ErpFormHelper`, and `ErpLookupHelper` adheres to the established Golden Template standard.

## 3. Required Revisions (Completed)
During the review, the following critical architecture errors were identified and **corrected in the blueprints**:
- **Premature Dependencies:** The initial blueprint proposed foreign keys (`payment_term_id`, `tax_code_id`, `salesperson_id`, `customer_group_id`, `industry_id`) mapping to tables that do not exist yet. Building these now violates the mandate. These have been **deferred** in the blueprint.
- **Missing Audit Hook:** The initial `customers` table missed `import_batch_id`. This is critical for `ErpImportHelper` traceability and has been **added**.

## 4. Deferred Items
The following will NOT be built in Phase 5B:
- **Tax Codes, Payment Terms, Salespersons, Customer Groups, Industries** (Deferred to subsequent Master Data phases).
- Customer Attachments (BIR 2303 / SEC uploads).
- Complex CRM features, merge utilities, and credit approval workflows.
- Customer Bank Accounts.

## 5. Phase 5B Minimum Implementation Scope
We require only the foundational entity capable of accepting sales invoices later:
- The core `customers` table (Identity, Tax Profile, limited Financial Defaults).
- `customer_addresses` table (Billing/Shipping locations).
- `customer_contacts` table (Key personnel).

## 6. Tables Approved for Implementation
1. `public.customers`
2. `public.customer_addresses`
3. `public.customer_contacts`

## 7. Fields Approved for Implementation
Core primitives, plus safe foreign keys:
- `company_id` (REFERENCES `companies`)
- `currency_id` (REFERENCES `currencies`)
- `default_ar_account_id` (REFERENCES `chart_of_accounts`)
- `default_sales_account_id` (REFERENCES `chart_of_accounts`)
*(Note: No other foreign keys are permitted).*

## 8. Lookups Approved for Implementation
- Default Currency (`currencies`)
- Default AR Account (`chart_of_accounts`)
- Default Sales Account (`chart_of_accounts`)

## 9. Security & RLS Plan
- All 3 tables must map to `company_id` either directly (`customers`) or via JOINs in RLS (`customer_addresses`, `customer_contacts`).
- `created_by` / `updated_by` are strictly backend-enforced.
- Soft delete (`is_active`) is required; hard deletes are forbidden.

## 10. Import Plan
- The `ErpImportHelper` will target the core `customers` table only. Sub-tables (Addresses/Contacts) will be managed via the UI in Phase 5B.
- `import_batch_id` must be tracked for rollback capability.

## 11. UI Plan
- **ErpFormHelper Tabbed Design:** Prevents overwhelming users.
- **Progressive Disclosure:** Tab 5 (Addresses) and Tab 6 (Contacts) must be hidden or disabled during "Create" mode, unlocking only in "Edit" mode after the parent `customer_id` exists.

## 12. Risks
- Delaying the `tax_code_id` means standard VAT calculations will rely entirely on the `tax_type` enum (VAT, Non-VAT, Exempt) for now. This is sufficient for early implementation but must be addressed before the Posting Engine is built.

## 13. Final Decision
**[ APPROVED FOR MIGRATION ]**
The blueprints have been scrubbed of non-existent dependencies and perfectly aligned with Phase 5B constraints. We are cleared to proceed with Database Migration implementation.
