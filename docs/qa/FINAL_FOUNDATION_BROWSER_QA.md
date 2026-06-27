# Final Foundation Browser QA

## 1. Overview
This is the final QA executed before transitioning from Phase 4 (Framework Fortification) to Phase 5 (Customer Master). 
It confirms that all legacy systems have been purged, all frameworks are locked in, and the UI remains completely intact and compliant.

## 2. Browser Verification Checklist
- [x] **1. Login:** The authentication state restores correctly upon refresh, redirecting to the Setup dashboard.
- [x] **2. Active Company Switch:** Intercepts list rendering. Changing the company instantly refreshes dependent list endpoints.
- [x] **3. Company List:** Renders securely with `ErpListHelper 2.0`. Pagination and server search operate flawlessly.
- [x] **4. Company Create:** `ErpFormHelper` intercepts submission correctly, persisting `company_id`.
- [x] **5. Company View:** Inputs are read-only. Lookups remain disabled to prevent rogue data alteration.
- [x] **6. Company Edit:** Inputs hydrate correctly. Saving updates the underlying record without throwing RLS exceptions.
- [x] **7. Branch List:** Dynamically isolated to the active company. Sorting functions correctly on all joined columns.
- [x] **8. Branch Create/Edit/View:** `ErpFormHelper` enforces active company assignment flawlessly on new records.
- [x] **9. Branch Import:** `ErpImportHelper` downloads the correct CSV schema, validates booleans server-side, tracks batches, and auto-refreshes the Branch List.
- [x] **10. Currency List:** Globally visible (`requireActiveCompany: false`). Search and pagination behave securely.
- [x] **11. Fiscal Years:** Correctly isolates `company_id`. No placeholder buttons remain.
- [x] **12. Fiscal Calendar:** Joined filtering works using the `staticFilters` expansion on `ErpListHelper`.
- [x] **13. Department List:** Scopes correctly. All placeholder toolbars successfully removed.
- [x] **14. Cost Center List:** Scopes correctly. Cleaned of any non-functional mockups.
- [x] **15. Company Functional Currency Lookup:** `ErpLookupHelper` opens securely, debounces search correctly across the `currencies` table, and maps the `id` perfectly to the hidden `<input>`.
- [x] **16. No Console Errors:** Total absence of `console.log`, `alert(`, and unhandled promise rejections across all loaded SPA routes.

## 3. Pass/Fail Decision
- **Result:** **[ PASS ]**
- The foundation is structurally and visually sound.
