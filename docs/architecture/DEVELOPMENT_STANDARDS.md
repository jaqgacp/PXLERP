# PXL ERP Development Standards

## 1. Core Philosophy
* **Enterprise First:** PXL ERP is not a lightweight CRUD application. It is an enterprise compliance engine. Code must be written with the assumption that it will handle millions of rows and strict audit requirements.
* **Encode Once, Consume Everywhere:** Master data must be comprehensive enough that transaction modules never need to ask the user to type redundant information (like addresses, TINs, or tax types).
* **Golden Reference:** The Company module serves as the Golden Reference. All future modules must inherit its design patterns, density, and professional UI behavior.

## 2. UI / UX Standards
* **Typography & Density:** Keep UI compact. Avoid oversized fonts, huge padding, or excessive whitespace. Use system fonts.
* **No Emojis:** Do not use emojis in the production UI (e.g., inside action buttons or table headers). If an icon is strictly necessary, use a minimalist SVG.
* **Forms:** Organize forms into logical `<fieldset>` sections. Use `.erp-grid` for multi-column layouts. Ensure mandatory fields are clearly marked with `.erp-required`. 
* **Read-Only States:** Do not merely disable input fields. Inputs in a 'View' state must look like flat text with subtle borders to improve readability.

## 3. JavaScript Architecture Standards
* **No Inline Event Listeners:** Do not use `onclick=""` in HTML (except for top-level global navigation if absolutely necessary). Use `addEventListener` inside the module's lifecycle hooks.
* **Service Layer Mandate:** UI files must *never* call the Supabase client directly. All database access must be routed through a Service Class (e.g., `BranchService.js`).
* **Router Lifecycle:** Every JS module must export an `init()` or `mount()` function. Do not rely on synthetic `DOMContentLoaded` events.

## 4. Database Architecture Standards
* **Tenant Isolation:** Every table related to a specific entity must contain a `company_id`. RLS policies must enforce `company_id = get_active_company_id()`.
* **Immutability:** Transaction tables (Invoices, Journals) must *never* be hard-deleted or updated after posting. They must be Voided or Reversed.
* **Soft Deletion:** Master Data records can be disabled using an `is_active` boolean.
* **Audit Columns:** Every table must include `created_at`, `updated_at`, `created_by`, `updated_by`. Triggers must handle `updated_at`.
* **Historical Accuracy:** Transaction tables must copy/snapshot master data fields (like Customer Name and TIN) at the time of entry to ensure historical reprints remain accurate even if the master record changes later.

## 5. Definition of Done
A module is **NOT COMPLETE** because the code compiles or the migration succeeds. It is complete **ONLY AFTER**:
1. Browser QA passes manually.
2. The UI matches the Golden Reference density and layout.
3. CRUD operations are fully functional against the real database.
4. RLS policies accurately restrict data.
5. The Product Owner provides explicit Golden Certification.
