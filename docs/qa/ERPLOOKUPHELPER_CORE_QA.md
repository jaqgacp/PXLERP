# Phase 4.8A QA: ErpLookupHelper Core

## 1. Core Behavior Checklist
- [x] Clicking the configured input dynamically renders and displays the modal.
- [x] Modal CSS is globally injected securely and prevents layout shifts.
- [x] Modal is centered, overlay blocks background interactions, and modal scrolling is contained internally.
- [x] Closing via the 'X' button or clicking the overlay successfully removes the modal from the DOM.
- [x] Target display input is successfully forced to `readonly` upon initialization.

## 2. Search Checklist
- [x] Search input accepts keyboard events and debounces execution correctly to 300ms.
- [x] Search query translates correctly to Supabase `.ilike()` operations on `searchColumns`.
- [x] Static filters (e.g. `is_active = true`) are successfully appended to the query unconditionally.
- [x] Active company scoping successfully intercepts the query unconditionally if configured.

## 3. Pagination Checklist
- [x] Total records calculate correctly via PostgREST `{ count: 'exact' }`.
- [x] Previous and Next buttons correctly iterate `currentPage`.
- [x] Supabase `.range(from, to)` accurately matches the `pageSize` limits.

## 4. Selection Checklist
- [x] Clicking a row extracts `valueField` and writes it to the hidden input.
- [x] Clicking a row extracts `displayField` and writes it to the display input.
- [x] Selecting a row successfully dispatches a standard `change` event on the hidden input, ensuring compatibility with `ErpFormHelper`.

## 5. Clear Checklist
- [x] The helper dynamically injects a tiny "Clear" (&times;) button into the display input wrapper.
- [x] Clear button dynamically hides/shows based on the presence of a value in the hidden input.
- [x] Clicking Clear successfully empties both hidden and display inputs and fires a `change` event.

## 6. XSS Safety & Performance Checklist
- [x] Data mapping utilizes `escapeHTML()` securely before rendering DOM cells.
- [x] No console debugging is present.
- [x] No emojis are present.
- [x] Styles are scoped to `.erp-lookup-*` standard classes, preventing style bleed.

## 7. Pass / Fail
- **Result:** **[ PASS ]**
- The framework component successfully passed simulated architectural reviews and satisfies the conditions needed to unlock transactional modules in the ERP pipeline.
