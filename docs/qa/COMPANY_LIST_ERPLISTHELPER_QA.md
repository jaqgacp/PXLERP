# Phase 4.6B QA: Company List ErpListHelper 2.0 Migration

## 1. Company List Migration Checklist
- [x] Company List Javascript successfully migrated to `ErpListHelper 2.0`.
- [x] `SetupListHelper` fully retired from the Company module.
- [x] Full TIN (`full_tin`) successfully exposed in the grid view.
- [x] Active badge rendered dynamically without inline styles.
- [x] Config-driven columns strictly mapped to table headers.
- [x] No database schema modifications performed.
- [x] No changes made to `company-form.js`.

## 2. Search Test
- [x] Global search (`ilike`) successfully filters Companies by `code`, `name`, `trade_name`, and `full_tin`, debounced to 300ms.

## 3. Sort Test
- [x] Clicking table headers (`Code`, `Name`, `Trade Name`, `TIN`) toggles `.order()` on the Supabase backend and reflects `[ASC]` or `[DESC]` visually on the frontend.

## 4. Pagination Test
- [x] `ErpListHelper` `.pagination button` / `.erp-list-pagination-controls button` selectors accurately locate Prev/Next buttons.
- [x] Next/Prev increment the `currentPage` and apply `.range(from, to)` to the query seamlessly.

## 5. View/Edit Test
- [x] "View" action dynamically populates `?id=${company.id}` and routes to read-only form.
- [x] "Edit" action dynamically populates `?id=${company.id}` and routes to edit form.

## 6. Toolbar Cleanup Test
- [x] **Company List:** Only "New", "Export", and "Print" are visible.
- [x] **Branch List:** "Generate" and "Approve" buttons successfully removed from HTML.
- [x] **Currency List:** Only "New" is visible.

## 7. Regression Check
- [x] **Branch:** `branch-list.js` continues to operate successfully on the legacy `SetupListHelper`.
- [x] **Currency:** `currency-list.js` continues to operate on `ErpListHelper 2.0`.
- [x] **Fiscal Years / Calendar:** Loading unchanged and operational.

## 8. Pass / Fail
- **Result:** **[ PASS ]**
- The Company list migration demonstrates that `ErpListHelper 2.0` is robust enough to handle the Golden Reference module without data leaks or UX regressions.
