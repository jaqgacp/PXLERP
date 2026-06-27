# Phase 4.8C QA: Branch List Migration to ErpListHelper 2.0

## 1. Purpose
This document certifies the successful migration of the Branch List module to `ErpListHelper 2.0`, while confirming that the Import Framework logic and company isolation layers were completely preserved.

## 2. Migration Summary
- **Module:** Branch List (`src/branch/branch-list.js`)
- **Old Strategy:** `SetupListHelper` fetching the entire active company dataset into memory.
- **New Strategy:** `ErpListHelper 2.0` managing `.range()` and `.ilike()` operations on the Supabase backend.
- **Framework Upgrade:** Added `extraSelectFields` to `ErpListHelper` to allow fetching background data (e.g., `short_name`) required for complex custom renderers.

## 3. Core ErpListHelper QA Checklist
- [x] **Active Company Scoping:** Tested. The list enforces `requireActiveCompany = true`. If the user has no company selected, it correctly halts and displays "Please select a company to view its branches."
- [x] **Search:** Debounced `ilike` operations successfully query across Code, Name, Address, and TIN Suffix.
- [x] **Sort:** Header clicks successfully trigger ascending/descending sorts via database `.order()`.
- [x] **Pagination:** Translates correctly to Supabase ranges, dynamically disabling Next/Prev limits based on {count: exact}.
- [x] **View/Edit Actions:** UUID injection behaves flawlessly.

## 4. Import & Export Regression Test
- [x] **Import CSV Button:** Opens the `ErpImportHelper` file picker correctly.
- [x] **Download Template:** Executes correctly, returning a CSV shaped for the Branch model.
- [x] **Post-Import Refresh:** Configured `importHelper.onSuccess = () => helper.load()` to instantly reload the paginated dataset after successful insert batches.

## 5. UI Standardization
- [x] "Generate" and "Approve" buttons had already been safely excised in Phase 4.6B.
- [x] Renderers gracefully parse booleans and format status badges using standard `erp-badge` classes (No inline styles, no emojis).
- [x] No console errors trigger across the lifecycle.

## 6. Global Regression Checklist
- [x] Company List functionality is preserved.
- [x] Currency List functionality is preserved.
- [x] Fiscal Years and Fiscal Calendar (still on SetupListHelper) load flawlessly.

## 7. Pass / Fail Result
- **Result:** **[ PASS ]**
- The migration validates that complex transactional arrays and import-heavy tables can confidently rely on `ErpListHelper 2.0`.
