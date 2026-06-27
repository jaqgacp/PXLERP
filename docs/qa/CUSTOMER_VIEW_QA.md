# CUSTOMER VIEW QA

## 1. Purpose
Verify the Customer View page properly implements `ErpFormHelper` in read-only mode, correctly retrieves nested lookup values via Supabase joins, handles empty/not-found states securely, and explicitly blocks create/edit actions per Phase 5D constraints.

## 2. Route Tested
- `#/master-data/customers/view?id=<uuid>`

## 3. Data Loading Test
- `ErpFormHelper` successfully fetches data using `onLoad` override.
- Tested `created_by` and `updated_by` parsing (displays user's `display_name` or `first_name last_name`, fallback to UUID if missing).

## 4. Missing ID Test
- If no `?id=` parameter is provided in the URL, the form renders a professional block:
  - **Result**: "Error - Customer ID is required."

## 5. Not Found / Access Denied Test
- If a user enters a fake UUID, or a UUID belonging to another company (blocked by RLS):
  - **Result**: Data fetch fails and form renders: "Access Denied / Not Found - Customer record not found or access denied."

## 6. Lookup Display Test
- **Currency**: `default_currency_display` retrieves joined `currencies(code, name)`.
- **Branch**: `default_branch_display` retrieves joined `branches(code, name)`.
- **Fallback**: Gracefully falls back to raw UUID if the join fails or relationship is null.

## 7. Read-Only Verification
- `ErpFormHelper` automatically applies `readonly` and `disabled` attributes because it detects `mode === 'view'`.
- Verified UI does not display "Save" or "Save & New" buttons.

## 8. Action Button Verification
- Back button correctly navigates to the list.
- Edit button is rendered but when clicked navigates to `#/master-data/customers/edit?id=<uuid>`, which immediately displays the "Not Available" Phase 5D block.
- Print button is dynamically appended to the toolbar and invokes `window.print()`.

## 9. Regression Checklist
- [x] Customer List still works.
- [x] Customer List View action opens Customer View.
- [x] Company List still works.
- [x] Branch List still works.
- [x] Currency List still works.
- [x] Company Functional Currency lookup still works.
- [x] No console errors upon loading or rejecting a record.

## 10. Pass/Fail Result
**[ PASS ]** The Phase 5D Customer View correctly renders the blueprint as a read-only form while strictly preventing database mutations.
