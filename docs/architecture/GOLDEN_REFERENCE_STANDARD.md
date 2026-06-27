# Master Data Golden Reference Standard

This document defines the absolute standard that all future Master Data modules (e.g., Supplier, Employee, Item, Bank Accounts, Warehouse) must follow. This pattern is based on the certified Customer Master implementation.

## 1. Architectural Boundaries
- **No Custom UI Frameworks:** All forms and lists MUST use `ErpFormHelper`, `ErpListHelper`, and `ErpLookupHelper`. Do not invent new UI wrappers.
- **Strict Mode Enforcement:** `new`, `edit`, and `view` modes must be handled elegantly.
- **Zero Fake UI:** No buttons, tabs, or subgrids may be present unless they are fully implemented and connected to a backend schema. (e.g., Addresses/Contacts must remain hidden until built).
- **Backend as Authority:** Audit fields (`created_at`, `created_by`, `updated_at`, `updated_by`) are strictly backend-owned. Never spoof them from the client.

## 2. Standard Master Data Files
A standard master data module requires exactly four files:
1. `[module]/list.html` - The grid shell.
2. `[module]/[module]-list.js` - `ErpListHelper` configuration.
3. `[module]/form.html` - The form shell using `<template id="erp-form-template">`.
4. `[module]/[module]-form.js` - `ErpFormHelper` implementation (`onInit`, `onLoad`, `buildPayload`, `onSave`).

## 3. Form Behavior (`ErpFormHelper`)
- **New Mode (`mode === 'create'`):**
  - System Information fields (Audit info) MUST be dynamically hidden.
  - Form must automatically inject `company_id` from `authManager.getActiveCompanyId()`.
- **View Mode (`mode === 'view'`):**
  - Completely read-only. Handled automatically by `ErpFormHelper.enforceReadOnly()`.
  - Lookups must be neutralized (Clear buttons hidden/disabled).
  - A `Print` button is dynamically injected into the toolbar.
- **Edit Mode (`mode === 'edit'`):**
  - Identifies the target record strictly by `currentRecordId`.
  - Protects cross-tenant updates by injecting `company_id` into the update clause.

## 4. Lookup Pattern (`ErpLookupHelper`)
- Lookups must use two inputs in HTML:
  ```html
  <input type="hidden" id="fk_id" name="fk_id">
  <input type="text" id="fk_display" name="fk_display" placeholder="Select..." readonly>
  ```
- Lookups must explicitly define `requireActiveCompany` based on their scope (e.g., `false` for Currencies, `true` for Branches/Warehouses).
- Lookups must restrict queries to active records (`is_active = true`).

## 5. Validation Pattern
- **HTML5 First:** Rely on HTML5 validation (`required`, `type="number"`, `min="0"`) for client-side enforcement.
- **Payload Safety Checks:** The `buildPayload()` function must execute final sanity checks for critical identity fields before allowing the payload to pass to `onSave()`.
- **Database Authority:** Handle unique constraints safely. Catch PostgREST error code `23505` and translate it into a clean "Code already exists" user toast. Do not expose technical stack traces.

## 6. Route/Navigation Safety
- **Route Naming:** Routes must strictly follow `#/<module-group>/<entity>/<action>?id=<uuid>`.
- **Navigation Purity:** Child records (e.g., Contacts, Addresses, Setup profiles) MUST NOT exist in global navigation. They must be encapsulated within the Master Form via subgrids (when implemented).

## 7. Required QA Artifact
- Every module must be accompanied by a `docs/qa/[MODULE]_QA.md` artifact covering Data Loading, Routing, View/Edit/New integrity, Lookup behavior, RLS checks, and Regression testing against related modules.
