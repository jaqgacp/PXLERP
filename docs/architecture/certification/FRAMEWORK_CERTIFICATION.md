# Framework Certification

This document covers the broad architectural certification of the PXL ERP foundation prior to Master Data expansion.

## 1. ErpListHelper 2.0 Evaluation
- **Server-Side Pagination:** Verified working via `.range()`. Limits over-fetching.
- **Searching:** Configurable `ilike` implemented accurately.
- **Sorting:** Configurable `.order()` implemented accurately.
- **State Persistence:** Verified via `sessionStorage`. Users maintain their state returning from Edit forms.
- **Missing Framework Features:** Column Chooser, Density Toggle, and Refresh Buttons do not exist yet. These are standard in SAP/NetSuite and vital for enterprise user experience.

## 2. Generic Page Framework
- Currently, lists and forms are heavily boilerplate-driven (`company-list.js`, `branch-list.js`, `company-form.js`). We rely on `ErpFormHelper` and `ErpListHelper` effectively, but the HTML itself (tables, standard toolbars) is duplicated manually across HTML files.

## 3. Generic Lookup Framework
- **Status:** Non-existent. We do not have a generic lookup component. Creating Customer, Supplier, and Items will require looking up Currencies, Tax Codes, Warehouses, and Departments. Doing this manually via standard `<select>` dropdowns is fatal for datasets over 500 rows. A modal/debounce-search lookup framework is missing.

## 4. Security & Tenant Isolation
- `user_company_access` ensures isolation via RLS correctly.
- `bootstrap_company` established a safe RPC pattern, but this pattern is not yet fully documented/enforced for all future updates and soft deletes.
