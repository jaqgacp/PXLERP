# Framework Refactor Plan (Phase 3)

## Objective
Transition the PXL ERP JavaScript frontend from a rapid-prototype architecture to a scalable, enterprise-grade framework capable of supporting Master Data, Transactions, and Reports uniformly, without adopting heavy third-party frameworks like React or Vue (to maintain our lightweight Vanilla JS philosophy).

---

## 1. The Component Model (Vanilla JS Web Components)
**Plan:** Migrate UI building blocks away from raw HTML string concatenation into reusable Vanilla JS classes (or native Web Components).
* **`ErpDataGrid`**: A single, robust list component replacing `SetupListHelper`. Must support pagination, sorting, column definitions, and data injection natively. (Future Report Builder foundation).
* **`ErpForm`**: A headless form state manager. It will handle serialization (DOM to JSON), deserialization (JSON to DOM), and native validation, decoupling these tasks from the UI shell.

## 2. The Service Layer (Data Access Objects)
**Plan:** Centralize all Supabase calls.
* Create a `services/` directory.
* `CompanyService.js`, `BranchService.js`, `TaxService.js`.
* UI modules will call `await CompanyService.getAll()` instead of `supabase.from('companies').select(...)`.
* This allows us to transparently inject Redis caching or LocalStorage caching in the future without touching UI code.

## 3. Router Lifecycle Overhaul
**Plan:** Remove the fake `DOMContentLoaded` pattern.
* The router will expect every route's JS file to export:
  ```javascript
  export async function mount(container) { ... }
  export async function unmount() { ... }
  ```
* The router will clear the container, call `unmount()` on the old module, dynamically import the new module, and call `mount(containerEl)`.

## 4. The Future Report Builder Architecture
**Plan:** Do not build bespoke list pages.
* Every list page (e.g., Company List, Customer List) will simply instantiate the `ErpDataGrid` class.
* We define columns via JSON configuration:
  ```javascript
  const columns = [
    { field: 'code', label: 'Code', width: '100px', sortable: true },
    { field: 'name', label: 'Company Name', flex: 1, filterable: true }
  ];
  ```
* The grid will automatically render the table, headers, and pagination controls. 

## 5. The Future Transaction Framework (Header-Line Pattern)
**Plan:** Design a framework specifically for Documents (Sales Invoices, Journal Entries).
* A transaction form consists of a **Header** (Date, Customer, Status) and **Lines** (Item, Quantity, Price, Tax).
* The framework must support binding an array of line items to an editable `<ErpDataGrid>`.
* It must support automatic recalculation of Totals (Subtotal, VAT, EWT, Net) whenever a line changes.

## 6. Execution Strategy for Refactoring
To avoid breaking the Golden Reference (Company module), the refactor will occur in stages:
1. **Stage 1 (Under the Hood):** Build the Service Layer and Router Lifecycle. Migrate `company-list.js` and `company-create.js` to use them.
2. **Stage 2 (Grid Component):** Build the `ErpDataGrid` class. Refactor `company-list.js` to use it instead of `SetupListHelper`.
3. **Stage 3 (Form Component):** Build the `ErpForm` data binder. Refactor the Company forms to remove manual `document.getElementById` calls.
4. **Stage 4 (Rollout):** Once the framework is proven on the Company module, freeze the framework. Then build Branch, Department, and Cost Center using the newly minted framework.
