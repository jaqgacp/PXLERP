# PXL ERP List Standard Architecture

## 1. Overview
The official list grid rendering framework for PXL ERP is **ErpListHelper 2.0**.
As of Phase 4.8E, the legacy `SetupListHelper` has been entirely purged and retired.

## 2. Core Directives
All future list/grid modules **MUST** adhere to the following architecture rules:

### A. Server-Side Pagination is Mandatory
- **Client-side full-table rendering is forbidden.**
- Never execute `.select()` without a bounded `.range()`. `ErpListHelper` natively intercepts and paginates payloads via Supabase ranges to guarantee O(1) memory payloads on the browser regardless of multi-million row datasets.

### B. Tenant Isolation (Company Scoping)
- Master data modules must evaluate if they are tenant-isolated (`company_id`).
- If so, they must pass `requireActiveCompany: true` to the config. The list helper will block DOM rendering if the active session company is null.

### C. Toolbar Integrity
- **The Toolbar must show only implemented actions.**
- Placing non-functioning UI buttons (e.g., "Generate", "Approve", "Import", "Export") purely as mockups is **strictly forbidden**. Every button rendered must be wired and functional.

### D. Stylistic Guardrails
- **No Inline Styles:** Use framework classes like `erp-badge`, `erp-badge-success`.
- **No Emojis:** UI text should be professional and clean.
- **No Console Debugging:** Production branches must never leak data into `console.log`.

## 3. Deprecation Notice
- `SetupListHelper` is officially dead.
- Do not reference, copy, or rebuild it.
- All new lists (e.g., Customer, Supplier, Item, Chart of Accounts, Journal Entries) must instantiate `ErpListHelper 2.0`.
