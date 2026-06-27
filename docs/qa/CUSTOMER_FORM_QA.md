# Customer Create & Edit QA Report

**Date:** June 27, 2026

## 1. Purpose
Verify the implementation of Customer Create (New Mode) and Customer Edit (Edit Mode) within Phase 5E, using the existing Phase 5D read-only architectural foundation. Ensure data integrity, accurate lookups, strict RLS enforcement, and appropriate field validations without building any subgrids or importing yet.

## 2. Routes Tested
- `#/master-data/customers/new`
- `#/master-data/customers/edit?id=<customer_id>`
- `#/master-data/customers/view?id=<customer_id>` (Regression)

## 3. New Mode Test
- **Action:** Open `#/master-data/customers/new`. Fill out required fields (Code, Name, Entity Type, Tax Type) and select an active Currency and Branch via the ErpLookupHelper modals.
- **Expected:** Save button visible. System Information section hidden. Fields editable. Success creates a new record and redirects to View mode.
- **Result:** **PASS**. The form builds a clean payload, fetches the `company_id` directly from `authManager.getActiveCompanyId()`, and inserts perfectly into `public.customers`.

## 4. Edit Mode Test
- **Action:** Open `#/master-data/customers/edit?id=<valid_id>`. Modify Trade Name and Tax Type. Click Save.
- **Expected:** Save button visible. System Information section visible (if applicable in edit) or fields populated. Record updates correctly and redirects to View mode.
- **Result:** **PASS**. The form strictly updates the specific record by ID, injecting `updated_at`. RLS prevents cross-company modifications.

## 5. View Mode Regression
- **Action:** Open `#/master-data/customers/view?id=<valid_id>`.
- **Expected:** Strictly read-only. Lookups disabled (no clear button). Print button appears. Save buttons hidden.
- **Result:** **PASS**. ErpFormHelper locks fields correctly. ErpLookupHelper clears buttons are stripped.

## 6. Lookup Tests
- **Currency:** Uses `ErpLookupHelper` to fetch from `currencies`. Universal access (no active company requirement).
- **Branch:** Uses `ErpLookupHelper` to fetch from `branches`. Scoped specifically to the `requireActiveCompany: true` flag to prevent mixing branches.
- **Result:** **PASS**. Both lookups populate ID locally and display string properly.

## 7. Validation Tests
- Client-side validation relies on HTML5 `required` attributes and a safety check inside `buildPayload()` for core identity fields (Code, Registered Name, Tax Type, Entity Type).
- TIN dynamically concatenates `tin` and `tin_branch_code` into `full_tin`.
- **Result:** **PASS**.

## 8. Duplicate Code Test
- **Action:** Attempt to create a Customer with an existing code within the same company.
- **Expected:** Graceful error.
- **Result:** **PASS**. Catches Supabase `23505` unique constraint violation and displays: "A customer with this Code already exists."

## 9. Active Company Test
- **Action:** Attempt to save with no active company context.
- **Expected:** "Please select an active company first."
- **Result:** **PASS**. Blocked securely before network request.

## 10. RLS/Access Test
- **Result:** **PASS**. RLS safely blocks cross-tenant access.

## 11. Redirect Behavior
- **Result:** **PASS**. Successful saves consistently push to `#/master-data/customers/view?id=<id>`.

## 12. Regression Checklist
- [x] Customer List still works
- [x] Customer View still works
- [x] Customer New opens
- [x] Customer Edit opens
- [x] Company List still works
- [x] Branch List still works
- [x] Currency List still works
- [x] Navigation split remains intact
- [x] Compliance navigation remains intact
- [x] No console errors

## 13. Final Result
**[ PASS ]** The Phase 5E Customer Create/Edit implementation completely fulfills the requirements utilizing the existing certified framework.
