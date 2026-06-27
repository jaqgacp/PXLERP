# Company Bootstrap Flow — QA Guide

## 1. Purpose
This document provides the Quality Assurance checklist for the **Company Bootstrap Flow**. The goal of this flow is to atomically create the minimum required base operating environment for a new Company tenant in PXL ERP, preventing broken states during system initialization.

## 2. What `bootstrap_company` Does
When a user submits the Company Create form, the `bootstrap_company` RPC securely executes the following in a single transaction:
- Validates the authentication context (`auth.uid()`).
- Validates that the provided `functional_currency_id` exists.
- Strips any client-provided audit fields or generated columns (`id`, `created_by`, `updated_by`, `full_tin`, etc.) to prevent spoofing.
- Inserts the new Company into `public.companies`, assigning `created_by` natively on the backend.
- Grants immediate admin rights to the creator by inserting a record into `public.user_company_access`.
- Automatically derives the Branch TIN suffix from the company payload (defaults to `00000`).
- Inserts the default `MAIN` Head Office Branch into `public.branches`.
- Returns the new `company_id` to the frontend, which immediately routes the user to the Company View and switches the session context.

## 3. What It Intentionally Does NOT Do
To keep the bootstrap atomic and focused solely on tenancy, this flow intentionally defers accounting setup. It **does NOT** create:
- Fiscal Years
- Fiscal Periods
- Number Series
- Warehouses
- Departments
- Cost Centers

*Note: These domain-specific entities will be handled by a dedicated Setup Wizard or initialized via their respective modules at a later time.*

## 4. Browser QA Checklist
Please perform the following manual tests in the browser:

- [ ] Log in as a valid user.
- [ ] Open the **Company List**.
- [ ] Click **New** to open the Company creation form.
- [ ] Fill out the required fields and submit the form.
- [ ] Verify the new Company appears in the Company List.
- [ ] Verify the **Active Company Switcher** automatically updates.
- [ ] Verify the newly created company is currently active.
- [ ] Navigate to the **Branch List** and verify the default `MAIN` branch appears.
- [ ] Navigate back to **Company View** and ensure it loads successfully.
- [ ] Edit the company information and ensure **Company Edit** works correctly.
- [ ] Ensure all forms and lists load without throwing UI errors.
- [ ] Open Developer Tools (F12) and verify **no console errors** are present.

## 5. SQL Verification Queries
Run the following queries via `supabase db query` or a database client to verify data integrity:

### Verify Company Creation
```sql
SELECT id, code, name, created_by, is_active
FROM public.companies
ORDER BY created_at DESC
LIMIT 5;
```

### Verify User Access Grant
```sql
SELECT user_id, company_id, is_company_admin
FROM public.user_company_access
ORDER BY created_at DESC
LIMIT 5;
```

### Verify Head Office Branch Creation
```sql
SELECT company_id, code, name, tin_suffix, is_head_office
FROM public.branches
ORDER BY created_at DESC
LIMIT 5;
```

## 6. Known Limitations
- If the database lacks a base currency (e.g., PHP), the bootstrap will fail. The seed data currently initializes PHP, which is required for setup.
- The `user_company_access` table only maps the creator. Any additional users must be mapped manually or through future user administration modules.
- Since fiscal periods are not generated, financial transactions cannot be posted until the fiscal setup is completed.

## 7. Pass / Fail (Product Owner)
- **Tested By:** ___________________________
- **Date:** _______________________________
- **Result:** [ PASS ] / [ FAIL ]
- **Notes / Observations:**
