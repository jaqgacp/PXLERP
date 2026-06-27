# Final Legacy List Migration QA

## 1. Purpose
This document certifies the successful migration of the final legacy modules (Department List and Cost Center List) to `ErpListHelper 2.0` and confirms the permanent retirement of `SetupListHelper`.

## 2. Department Migration Checklist
- [x] Migrated `department-list.js` to `ErpListHelper`.
- [x] Server-side pagination, sorting, and search enabled.
- [x] Cleaned up fake "Import", "Generate", "Approve" buttons from HTML toolbar.
- [x] Added `requireActiveCompany: true`.

## 3. Cost Center Migration Checklist
- [x] Migrated `cost-center-list.js` to `ErpListHelper`.
- [x] Server-side pagination, sorting, and search enabled.
- [x] Cleaned up fake "Import", "Generate", "Approve" buttons from HTML toolbar.
- [x] Added `requireActiveCompany: true`.

## 4. Schema Scoping Decision
- **Decision:** Both Department and Cost Center schemas natively utilize `company_id uuid NOT NULL REFERENCES public.companies(id)`.
- **Implementation:** Both lists pass `requireActiveCompany: true` to enforce tenant isolation at the list initialization tier.

## 5. Toolbar Verification
- Toolbars across both modules have been audited. They now only show "New", "Export", and "Print". All non-functioning boilerplate buttons have been deleted to enforce Product Trust.

## 6. Regression Checklist
- [x] Company List loads successfully.
- [x] Branch List loads successfully (Import framework verified intact).
- [x] Currency List loads successfully.
- [x] Fiscal Years & Calendar load successfully.
- [x] No console errors across the application.

## 7. SetupListHelper Reference Search Result
- **Command Used:** Repository-wide text search for `SetupListHelper` and `setup-list-helper.js`.
- **Result:** 0 active references remaining.

## 8. Retirement Decision
- **Action Taken:** `src/shared/setup-list-helper.js` has been permanently deleted from the repository.
- `ErpListHelper 2.0` is now the sole standard for PXL ERP list grids.

## 9. Pass/Fail Result
- **Result:** **[ PASS ]**
