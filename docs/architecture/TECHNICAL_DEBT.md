# Technical Debt Audit

## Executive Summary
Phase 1 and Phase 2 successfully laid out the visual Golden Reference and database schema for PXL ERP. However, the rapid prototyping introduced significant technical debt in the JavaScript layer. If left unaddressed, this debt will cause development velocity to grind to a halt when building complex transaction modules (e.g., Sales Orders, Journal Entries).

---

## 1. Direct Database Coupling (No Service Layer)
**The Debt:** 
Currently, every UI module (e.g., `company-list.js`, `company-edit.js`) calls the Supabase client directly (`supabase.from('table').select(...)`). 
**The Impact:** 
* If a database column name changes, we must hunt down every UI file that queries it.
* We cannot easily inject a caching layer (e.g., caching the Chart of Accounts so it isn't fetched every time the dropdown is opened).
* **Fix Required:** Introduce a Data Access Object (DAO) or Service Layer pattern (e.g., `CompanyService.getById(id)`).

## 2. Manual DOM Data Binding
**The Debt:** 
Form files manually extract data using `document.getElementById('field').value` and populate data using the reverse.
**The Impact:** 
* A form with 40 fields requires 80 lines of repetitive, error-prone boilerplate code just to read/write data. 
* This scales horribly for transaction forms that contain dynamic arrays of line items.
* **Fix Required:** Introduce a lightweight vanilla JS data-binding utility or form serialization helper that maps an object to `name` or `id` attributes automatically.

## 3. String-Based HTML Rendering
**The Debt:** 
`SetupListHelper` and `ErpFormHelper` generate complex UI components by concatenating massive HTML strings using template literals.
**The Impact:** 
* Prone to XSS vulnerabilities (if `escapeHTML` is missed on a single variable).
* Extremely difficult to attach dynamic event listeners to elements rendered as strings (e.g., adding a click handler to a dynamically generated button inside a table row requires event delegation on the `<tbody>`).
* **Fix Required:** Transition to programmatic DOM creation (e.g., `document.createElement`) or adopt a standardized web component / template architecture for reusable components (like Data Grids).

## 4. Synthetic Router Lifecycle
**The Debt:** 
The SPA router relies on dispatching a fake `DOMContentLoaded` event to trigger scripts imported dynamically.
**The Impact:** 
* Modules cannot gracefully unmount, clear their intervals, or detach event listeners when navigating away. This causes silent memory leaks and duplicate event firing in long-lived browser sessions.
* **Fix Required:** Migrate all modules to export standard lifecycle hooks (`mount()`, `unmount()`) that the router orchestrates.

## 5. Form Helper Rigidity
**The Debt:** 
`ErpFormHelper` assumes exactly one form per page and hardcodes the toolbar layout and breadcrumbs.
**The Impact:** 
* It is impossible to render a modal form on top of a list, or a sub-form inside a parent form, using the current helper.
* **Fix Required:** Decouple the form state machine from the UI shell rendering.
