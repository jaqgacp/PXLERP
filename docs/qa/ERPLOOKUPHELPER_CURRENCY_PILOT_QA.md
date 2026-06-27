# Phase 4.8B QA: ErpLookupHelper Currency Pilot

## 1. Purpose
This document certifies the real-world pilot of the `ErpLookupHelper` component within the Company module, specifically replacing the traditional `<select>` field for Functional Currency.

## 2. Field Piloted
- **Module:** Company Form (Create, Edit, View modes)
- **Field:** Functional Currency (`functional_currency_id`)
- **Old Strategy:** `loadCurrencies()` fetching all currencies into a dropdown on mount.
- **New Strategy:** `ErpLookupHelper` dynamically opening a modal for server-side `.ilike()` search and pagination.

## 3. Screens Tested
- [x] Company Create
- [x] Company Edit
- [x] Company View

## 4. Expected Behavior Checklist
- [x] Functional Currency displays as a clickable text field (placeholder "Select currency...").
- [x] Clicking opens the modal successfully without page layout shifting.
- [x] Search successfully queries the Currency table via `ErpLookupHelper`.
- [x] Selecting a row successfully updates the `functional_currency_display` (e.g. PHP) and writes the UUID to `functional_currency_id`.
- [x] Clear button dynamically appears and correctly nullifies the value upon click.
- [x] **View Mode:** The lookup click listener is disabled. The input acts as standard readonly text.
- [x] **Edit Mode:** Existing Functional Currency is correctly fetched by utilizing a relational `select('*, currencies:functional_currency_id(code, name)')` join, populating the display field accurately.
- [x] Payload validation: The form successfully submits only the UUID (`functional_currency_id`), completely ignoring the display field. 

## 5. Security & Stability Checklist
- [x] No `full_tin` submitted to backend.
- [x] No audit fields submitted to backend.
- [x] No inline styles used.
- [x] No emojis used.
- [x] No console errors/warnings fired during full lifecycle (init -> click -> search -> select -> save).

## 6. Bugs Found / Actual Behavior
- None. The migration behaved seamlessly. 
- *Note:* In View mode, `cloneNode(true)` was utilized to securely strip the event listener attached by `ErpLookupHelper`, ensuring users cannot trigger the modal on a readonly record.

## 7. Pass / Fail Result
- **Result:** **[ PASS ]**
- The Currency pilot successfully demonstrates that the new generic lookup framework integrates securely with `ErpFormHelper` with zero database or RLS changes required.

## 8. Recommendation
**Proceed to Framework Migration.**
The `ErpLookupHelper` is officially certified for use. We can now comfortably scale to Customer, Supplier, and Item Master configurations.
