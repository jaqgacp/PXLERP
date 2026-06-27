# CUSTOMER LIST QA

## 1. Purpose
Verify the Customer List page correctly implements the ErpListHelper 2.0 framework, integrates with the `customers` table, scopes data correctly by the active company, and supports standard pagination, searching, and sorting without any forms or extra modules.

## 2. Route Tested
- `#/master-data/customers` correctly navigates to the Customer List.

## 3. Active Company Test
- **Blocked State**: When no active company is selected, the list shows the blocking message: "Please select a company to view customers."
- **Scoped Data**: When a company is selected, only customers belonging to `company_id = activeCompanyId` are fetched (enforced via Supabase RLS and `ErpListHelper` query).

## 4. Search Test
- Implemented `searchable: true` on `code`, `registered_name`, `trade_name`, and `tin`.
- Tested the search box to verify server-side filtering via `ErpListHelper 2.0`.

## 5. Sort Test
- Clicking on table headers (Code, Registered Name, Trade Name, Entity Type, Tax Type, Active) triggers server-side sort.
- Arrows update in the UI according to ascending/descending state.

## 6. Pagination Test
- Default pagination limits via `ErpListHelper` applied.
- Next/Prev buttons correctly disable at boundaries.
- Pagination info string updates correctly (e.g., "Showing 1 to 10 of 20 entries").

## 7. Row Action Test
- **View Action**: Hyperlinks to `#/master-data/customers/view?id=UUID`
- **Edit Action**: Hyperlinks to `#/master-data/customers/edit?id=UUID`

## 8. Toolbar Verification
- New button navigates to `#/master-data/customers/new`.
- Export and Print buttons present as placeholders.
- No Import, Download Template, Generate, or Approve buttons exist.
- No inline styles, emojis, or console logs in HTML/JS.

## 9. Regression Checklist
- [x] Company List
- [x] Branch List
- [x] Currency List
- [x] Fiscal Lists
- [x] Department List
- [x] Cost Center List
- [x] Company Functional Currency Lookup
- [x] Branch Import

## 10. Pass/Fail Result
**[ PASS ]** The Phase 5C Customer List UI was implemented strictly following standard ERP components. No database or other modules were modified.
