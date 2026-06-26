# PXL ERP Framework Freeze Architecture

**Date:** June 26, 2026
**Status:** FROZEN (Product Owner Approval Required for Modifications)

## Objective
To ensure PXL ERP maintains a stable, enterprise-grade architecture, the core UI and logic frameworks are officially frozen. Every future Master Data module must strictly utilize these reusable components to guarantee identical behavior, UX, compliance, and browser compatibility across the platform. 

Any modifications to the files listed below require explicit Product Owner approval.

---

## 1. ERP Form Framework

The standard interface for data entry, validation, and CRUD lifecycles.

**Framework Files:**
- `src/css/erp-form.css`
- `src/shared/erp-form-helper.js`

**Responsibilities:**
- **View/Edit/Create Lifecycle:** Managed through `ErpFormHelper.determineMode()` which parses the router URL to safely lock, unlock, and configure form inputs.
- **Validation Framework:** Enforces standard input validation and required fields before allowing submission.
- **Toast Framework:** Standardized success/error notifications displayed securely on the UI.
- **Dirty Form Detection:** Flags unsaved changes and prevents accidental navigation loss.
- **Toolbar Behavior:** Uniform Save, Save & New, Cancel, and Edit button transitions tied strictly to the active mode.

---

## 2. ERP List Framework

The standard interface for displaying, filtering, and navigating master data and transaction records.

**Framework Files:**
- `src/css/erp-list.css`
- `src/shared/setup-list-helper.js`

**Responsibilities:**
- **Data Rendering:** Dynamically generates standardized table rows using a provided `renderRow` callback.
- **State Management:** Predictable, professional UI handling for Loading states (⏳), Empty states (📭), and Error states (⚠️).
- **Pagination:** Tracks and displays row counts automatically.
- **Active Company Support:** Optional strict isolation of data via `requireActiveCompany`. If enabled and no company is selected, a professional blocking state (🏢) is enforced, stopping unauthorized data fetching.
- **Search Behavior:** Standardized filter layouts ready for advanced query hooks.

---

## 3. SPA Framework

The single-page application engine that drives module navigation and lifecycle execution.

**Framework Files:**
- `src/index.html` (Router Logic)
- `src/auth/auth-manager.js` (Identity & Session)

**Responsibilities:**
- **Router Lifecycle:** Intercepts URL hash changes, parses the path, and dynamically fetches raw HTML templates.
- **init()/mount() Pattern:** Dynamically imports the module script and explicitly awaits `module.init()` or `module.mount()` for controlled execution.
- **Legacy Fallback:** If modern hooks are absent, the router dispatches a synthetic `DOMContentLoaded` event to support older code without breaking.
- **Cache Busting:** Automatically appends timestamp parameters (`?t=`) to HTML and JS fetches to guarantee fresh assets.

---

## 4. Development Rules

### Allowed Extension Points
- Developers may pass custom `fetchData` and `renderRow` callbacks to `SetupListHelper`.
- Developers may utilize `ErpFormHelper` hooks to manage complex module-specific business logic (e.g., relational saves).
- Modifying `index.html` is permitted **only** for adding new Navigation links/flyouts when registering a new business module.

### Forbidden Modifications
- Do **NOT** modify `.css` framework files to fix a visual bug in a single module. Report the framework gap instead.
- Do **NOT** alter the core DOM element IDs expected by the helpers (e.g., `#erp-form`, `#toast-container`).
- Do **NOT** bypass `SetupListHelper` to write a custom table fetching loop for a standard list view.
- Do **NOT** bypass `ErpFormHelper` to write custom Supabase insert/update logic for a standard form view.

### Module Developer Checklist
1. Review the Golden Reference (Company module) UI and code patterns before starting.
2. If building a List: Initialize `SetupListHelper` inside an exported `async function init()`.
3. If building a Form: Instantiate `ErpFormHelper` and configure the Supabase table name and object mapping.
4. If building a company-dependent module: Pass `requireActiveCompany: true` to the list helper to enforce strict isolation.
5. Rely 100% on the framework for all loading states, error handling, toolbars, and validation.
