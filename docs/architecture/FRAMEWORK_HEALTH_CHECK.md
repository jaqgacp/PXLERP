# Framework Health Check

**Date:** June 26, 2026

## Objective
This document outlines the remaining technical debt within the ERP UI and logic framework. Findings are ranked by priority. These issues must be addressed carefully to ensure the long-term maintainability of the repository.

## Findings

### Critical
1. **String-based HTML Rendering in `SetupListHelper`**
   - *Issue:* Building table rows via raw template strings (`renderRow: () => '<td>...</td>'`) is prone to XSS vulnerabilities and difficult to maintain for complex interactive components (e.g., inline edits, dropdowns).
   - *Recommendation:* Migrate to a lightweight virtual DOM, Web Components, or a robust templating engine (like lit-html) in Phase 4.

### High
2. **Manual DOM-to-Object Binding in `ErpFormHelper`**
   - *Issue:* `ErpFormHelper.getFormData()` relies heavily on `document.querySelectorAll('[name]')` and manual mapping. This lacks a reactive state and is brittle if DOM IDs change.
   - *Recommendation:* Implement a reactive Form State Manager that separates the UI presentation from the data payload.

### Medium
3. **Legacy Lifecycle Hooks**
   - *Issue:* Many existing setup modules rely on the synthetic `DOMContentLoaded` dispatch fallback in the SPA router.
   - *Recommendation:* Progressively migrate every module to use the explicit `export async function init()` pattern established in Stage 1.
4. **CSS Duplication**
   - *Issue:* There is semantic overlap between `erp-form.css` and `erp-list.css` (e.g., button styles, common margins).
   - *Recommendation:* Abstract common design tokens into a `base.css` or `theme.css` file to strictly adhere to DRY principles.

### Low
5. **Missing API Service Layer**
   - *Issue:* Direct `supabase.from('...').select()` calls are hardcoded into UI components (`SetupListHelper`, `ErpFormHelper`).
   - *Recommendation:* Decouple Supabase by introducing an abstracted API Service Layer (e.g., `MasterDataService.getBranches()`) to centralize caching, error handling, and business logic.
6. **Validation Inconsistencies**
   - *Issue:* UI validation currently relies mostly on native HTML5 constraints, which vary slightly by browser and are difficult to style uniformly.
   - *Recommendation:* Introduce a centralized schema-based validation utility (e.g., similar to Zod or Yup) that runs before the database call.
