# ERP Framework Architectural Audit

## Executive Summary
The current frontend architecture (PXL ERP Phase 2) was designed for rapid prototyping and establishing a visual "Golden Reference." While it succeeds visually, the underlying JavaScript framework is highly coupled, monolithic, and insufficient for an enterprise application scaling to hundreds of modules and millions of transactions. 

To support the 5-year roadmap (Sales, Purchasing, Inventory, Fixed Assets), the core framework requires a structural refactor to decouple routing, rendering, state management, and component lifecycles.

---

## 1. SPA Router (`src/index.html`)
**Current State:**
A vanilla JavaScript hash-based router that intercepts URL changes, fetches raw HTML files, extracts the `<body>`, injects it into a container, and dynamically imports a corresponding JS file. It fires a synthetic `DOMContentLoaded` event to trigger script execution.

**Critical Weaknesses:**
* **Lifecycle Coupling:** Scripts rely on a fake `DOMContentLoaded` event. This prevents graceful tearing down (unmounting) of modules, leading to memory leaks and zombie event listeners.
* **Hardcoded Path Resolution:** Assumes strict 1:1 mapping between URLs and filesystem paths (e.g., `#/setup/branch-setup` maps to `./setup/branch-setup.js`).
* **Lack of State Management:** No ability to pass props/state between routes.
* **No Middleware/Guards:** Route guards (auth checking) happen *after* the page is rendered, causing UI flashing.

**Scalability Risk:** High.

---

## 2. ERP Form Framework (`ErpFormHelper`)
**Current State:**
A class-based helper that automates form rendering, loading states, and saving logic.

**Critical Weaknesses:**
* **Violates Single Responsibility:** `ErpFormHelper` hardcodes the entire UI shell (breadcrumbs, toolbars, containers) as a massive template string inside `renderShell()`.
* **Rigid DOM Binding:** Hardcoded to look for `#erp-form`, `#btn-save`, `#content`. You cannot have two forms on the same page.
* **No Extensibility:** Cannot easily support tabs, expandable sections, sub-lists (grids), or attachments without modifying the core helper.
* **Data Binding:** Relies on manual DOM extraction (`config.buildPayload()`). No automated two-way data binding or schema-driven payload generation.

**Scalability Risk:** High. Will break immediately upon introducing Transaction Forms (e.g., Sales Invoices with line items).

---

## 3. ERP List Framework (`SetupListHelper`)
**Current State:**
A simple class that fetches data via Supabase and loops over it to inject HTML strings into a table body.

**Critical Weaknesses:**
* **No Pagination / Server-Side Processing:** Fetches the entire dataset at once. Will crash the browser if a table has 100,000 rows.
* **String-Based Rendering:** Prone to XSS (mitigated manually via `escapeHTML`). String concatenation for complex UI is unmaintainable.
* **Lacks Advanced Features:** No built-in sorting, filtering, column chooser, or sticky headers.
* **Hardcoded UI:** Empty states and loading states are hardcoded strings.

**Scalability Risk:** Critical. Unusable for high-volume transaction lists.

---

## 4. Validation Engine (`ErpValidation`)
**Current State:**
Leverages native HTML5 Constraint Validation API (`el.validity`) and aggregates errors.

**Critical Weaknesses:**
* **DOM-Coupled:** Requires the DOM to validate. Cannot validate data objects before they are injected into the DOM.
* **No Cross-Field Validation:** Cannot easily validate "End Date must be after Start Date".
* **No Async Validation:** Cannot handle "Check if TIN already exists" naturally within the validation lifecycle.

**Scalability Risk:** Medium.

---

## 5. CSS Architecture
**Current State:**
Monolithic `erp-form.css` and `erp-list.css` files utilizing the `.erp-` prefix.

**Critical Weaknesses:**
* **Global Scope:** Styles bleed. Changing `.erp-field` affects every module.
* **Responsive Design:** Grid columns are hardcoded to fixed widths or basic `span 2`. Difficult to adapt for multi-column complex transaction forms.

**Scalability Risk:** Low, but maintenance overhead is High.
