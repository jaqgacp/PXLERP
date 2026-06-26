# Module Build Guidelines

## Pre-Requisites
Before writing any code for a new module in PXL ERP, the following steps must be completed:
1. **Schema Review:** Inspect the Supabase database schema for the entity. Ensure `company_id` exists. Ensure audit columns exist. Verify the foreign key relationships.
2. **Missing Fields:** Determine if the schema lacks any fields required for Philippine compliance (e.g., specific TINs, ATC codes). Report gaps to the architect *before* proceeding.
3. **Golden Reference Familiarity:** Review the `Company` module (the Golden Reference) to understand the expected layout, density, and styling standards.

---

## 1. Directory Structure
Every module must be contained within its own feature folder inside `src/`.
```
src/
└── feature-name/
    ├── feature-list.js
    ├── feature-list.html
    ├── feature-form.js
    ├── feature-create.html
    ├── feature-edit.html
    └── feature-view.html
```
*Note: In the future, HTML structures will be generalized by `ErpForm` and `ErpDataGrid`, eliminating the need for redundant HTML files.*

## 2. Service Layer (Data Access)
Do not write Supabase queries in your UI files.
Create a Service file (e.g., `src/services/FeatureService.js`).
```javascript
import { authManager } from '../auth/auth-manager.js';

export class FeatureService {
  static get supabase() { return authManager.supabase; }
  
  static async getAll() {
    const { data, error } = await this.supabase.from('feature').select('*');
    if (error) throw error;
    return data;
  }
}
```

## 3. List View Implementation
* Build the list using the standard `ErpDataGrid` (or `SetupListHelper` for legacy compatibility during transition).
* Do not use emojis in action buttons. Use simple text (`View`, `Edit`).
* Ensure columns align correctly (Text left, Dates center, Numbers right).
* Format date and currency fields natively (e.g., `Intl.NumberFormat`).

## 4. Form Implementation (Create/Edit/View)
* Group fields logically using `<fieldset class="erp-section">`.
* Use `<div class="erp-grid">` to manage layout columns.
* For fields that span across the grid, use `<div class="erp-field erp-field-wide">`.
* Inputs must be marked with `.erp-required` on the `<label>` and the `required` attribute on the `<input>`.
* Map data to/from the DOM cleanly. 
* In **View Mode**, ensure inputs use `readonly disabled` attributes. They should look like flat text, not interactive fields.

## 5. Security & Isolation
* Ensure `company_id` is automatically injected into the payload during creation, utilizing `get_active_company_id()`.
* Test that users from Company A cannot see data from Company B (RLS verification).

## 6. Product Owner QA
Submit the module for Product Owner QA. The module is not "Done" until the UI, UX, functionality, and data integrity have been manually verified in the browser.
