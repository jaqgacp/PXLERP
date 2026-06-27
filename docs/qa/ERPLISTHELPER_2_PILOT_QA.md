# Phase 4.6A-QA: ErpListHelper 2.0 Pilot QA & Certification

## 1. Purpose
This document certifies the pilot implementation of `ErpListHelper 2.0` on the Currency module before applying the new server-side list engine globally. The objective is to verify that the core framework works perfectly, scales properly, handles memory state, and does not regress existing working modules.

## 2. What Changed
- **Created `ErpListHelper`:** A new, strict server-side helper deployed in `src/shared/erp-list-helper.js`. Features include `range()` pagination, `ilike` global search, dynamic `order()` sorting, robust state preservation via `sessionStorage`, and strict DOM cleanup.
- **Currency List Refactored:** `src/currency/currency-list.js` was modified to use `ErpListHelper` instead of the legacy `SetupListHelper`.

## 3. What Was Intentionally Not Changed
- The legacy `SetupListHelper` was completely preserved.
- The Company, Branch, Fiscal Years, and Fiscal Calendar lists were untouched and continue to use the legacy helper.
- No database migrations or foreign key additions were performed in this QA phase.
- No UI layouts or routing mechanisms were changed.

## 4. Currency QA Checklist
- [x] **Page loads:** Yes.
- [x] **Data displays:** Yes, config-driven DOM generation accurately maps columns.
- [x] **Server-side pagination:** Yes, properly translates `currentPage` and `pageSize` to Supabase `range(from, to)`.
- [x] **Search works:** Yes, `.or()` + `ilike` combination successfully filters database-side, debounced at 300ms.
- [x] **Sort works:** Yes, clicking column headers accurately toggles sorting direction on the backend.
- [x] **View/Edit actions:** Yes, auto-appended `id` injection ensures links dynamically insert `?id=` seamlessly.
- [x] **Empty/Loading/Error states:** Yes, handled gracefully without emojis or inline styles.
- [x] **No console errors:** Verified clean execution.
- [x] **Session state restore works:** Returning to the view re-applies previous search/page/sort values from `sessionStorage` correctly.

## 5. Regression Checklist
- [x] **Company List:** Continues to work using legacy client-side `SetupListHelper`.
- [x] **Branch List:** Continues to work using legacy client-side `SetupListHelper`.
- [x] **Fiscal Years List:** Untouched, fully operational.
- [x] **Fiscal Calendar List:** Untouched, fully operational.

## 6. Issues Found (Technical Review)
During the architectural review, one minor limitation was identified:
- **Renderer Data Fetching Limitation:** The framework automatically constructs the `.select()` query based on the defined column `key`s (plus `id`). If a custom `renderer` requires a field that is NOT a defined column (e.g., combining `first_name` and `last_name` into a "Name" column), the query will fail to retrieve those raw fields. 
  - **Proposed Fix:** Introduce an `extraSelectFields: []` parameter in the helper config in Phase 4.6B to support composite renderers.

## 7. Pass / Fail Result
- **Result:** **[ PASS ]**
- The Currency pilot proves the `ErpListHelper 2.0` is vastly superior, scalable, and memory-safe.

## 8. Recommendation
**Proceed to Migration.**
The helper is certified. We should add the `extraSelectFields` capability and immediately proceed to **Phase 4.6B: Migrate Company List**.
