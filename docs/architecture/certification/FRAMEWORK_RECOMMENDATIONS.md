# Framework Recommendations

1. **Generic Lookup Framework Implementation (Blocker)**
   - **Why:** Every Master Data and Transaction module depends heavily on foreign keys. Native `<select>` inputs cannot handle thousands of rows (e.g. Customers selecting Branches, Items selecting Tax Codes).
   - **Recommendation:** Build `erp-lookup-helper.js` implementing a modal-based or dropdown-based search that fetches results server-side using `.ilike()`.

2. **Column Chooser & Density Control (Enhancement)**
   - **Why:** Enterprise ERPs like SAP and Dynamics 365 allow users to tailor grids to their specific monitor constraints. 
   - **Recommendation:** Build this natively into `ErpListHelper 2.0` and store preferences in `localStorage` per module/user.

3. **Status Bar Implementation (Enhancement)**
   - **Why:** Provides clear UX context.
   - **Recommendation:** Append to `ErpListHelper` logic.

4. **UI Layout Boilerplate Reduction (Enhancement)**
   - **Why:** HTML is highly duplicated across modules.
   - **Recommendation:** Consider a Web Component or Template injection strategy for standard Grid/Toolbar structures.
