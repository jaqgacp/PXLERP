# Lookup Framework Standard (Design)

## 1. Problem
Currently, relationships are mocked or use basic HTML `<select>`. This fails catastrophically for ERP tables that contain 1,000+ rows (e.g. Items, Customers, Chart of Accounts).

## 2. Requirement
A single, reusable **Generic Lookup Framework** (`ErpLookupHelper`) must be designed and implemented before continuing with transactional models.

## 3. Specifications
The framework must support:
- **Modal Lookup:** A pop-up grid offering pagination and search exactly like `ErpListHelper`.
- **Searchable Dropdown (Typeahead):** Inline input that executes `.ilike()` debounced searches as the user types.
- **Server-Side Search & Pagination:** Must not download the whole table.
- **Active Company Filtering:** Automatically append `company_id = active_company`.
- **Keyboard Navigation:** Arrow keys up/down, Enter to select.

**Do not implement every lookup manually.** Implement the framework component, then declare lookups via config.
