# Phase 3: ERP Platform Architecture Freeze

## Goal Description
The objective of Phase 3 is to elevate PXL ERP from a modular prototype into an enterprise-grade platform. Before writing new Master Data modules (Branch, Department, Cost Center) or Transaction modules (Sales, Purchasing), we must eliminate structural technical debt in the JavaScript layer and establish strict architectural patterns. This ensures that the next 5 years of development—covering millions of transactions and complex Philippine compliance requirements—can scale efficiently without requiring massive rewrites.

I have completed the requested comprehensive architectural audit. 

## The Audit Deliverables
I have generated the following 9 strategic documents. Please review them in the artifacts directory:
1. [ERP_FRAMEWORK_AUDIT.md](file:///C:/Users/Jeric%20Art%20Gumacal/.gemini/antigravity/brain/8a7a9c19-1473-4240-9343-597c0b40cdd8/ERP_FRAMEWORK_AUDIT.md)
2. [DATABASE_ARCHITECTURE_AUDIT.md](file:///C:/Users/Jeric%20Art%20Gumacal/.gemini/antigravity/brain/8a7a9c19-1473-4240-9343-597c0b40cdd8/DATABASE_ARCHITECTURE_AUDIT.md)
3. [MASTER_DATA_AUDIT.md](file:///C:/Users/Jeric%20Art%20Gumacal/.gemini/antigravity/brain/8a7a9c19-1473-4240-9343-597c0b40cdd8/MASTER_DATA_AUDIT.md)
4. [UI_FRAMEWORK_AUDIT.md](file:///C:/Users/Jeric%20Art%20Gumacal/.gemini/antigravity/brain/8a7a9c19-1473-4240-9343-597c0b40cdd8/UI_FRAMEWORK_AUDIT.md)
5. [COMPLIANCE_ARCHITECTURE_AUDIT.md](file:///C:/Users/Jeric%20Art%20Gumacal/.gemini/antigravity/brain/8a7a9c19-1473-4240-9343-597c0b40cdd8/COMPLIANCE_ARCHITECTURE_AUDIT.md)
6. [TECHNICAL_DEBT.md](file:///C:/Users/Jeric%20Art%20Gumacal/.gemini/antigravity/brain/8a7a9c19-1473-4240-9343-597c0b40cdd8/TECHNICAL_DEBT.md)
7. [FRAMEWORK_REFACTOR_PLAN.md](file:///C:/Users/Jeric%20Art%20Gumacal/.gemini/antigravity/brain/8a7a9c19-1473-4240-9343-597c0b40cdd8/FRAMEWORK_REFACTOR_PLAN.md)
8. [DEVELOPMENT_STANDARDS.md](file:///C:/Users/Jeric%20Art%20Gumacal/.gemini/antigravity/brain/8a7a9c19-1473-4240-9343-597c0b40cdd8/DEVELOPMENT_STANDARDS.md)
9. [MODULE_BUILD_GUIDELINES.md](file:///C:/Users/Jeric%20Art%20Gumacal/.gemini/antigravity/brain/8a7a9c19-1473-4240-9343-597c0b40cdd8/MODULE_BUILD_GUIDELINES.md)

## User Review Required

> [!WARNING]
> **JavaScript Core Refactor Strategy**
> As detailed in `TECHNICAL_DEBT.md` and `FRAMEWORK_REFACTOR_PLAN.md`, continuing to build modules using raw DOM string concatenation (`SetupListHelper`, `ErpFormHelper`) and direct Supabase calls will paralyze our velocity.
> 
> I propose an immediate **Stage 1 Refactor** (under-the-hood):
> 1. Creating a `services/` layer (e.g. `CompanyService.js`) to decouple Supabase from UI logic.
> 2. Developing an `ErpDataGrid` vanilla JS class to replace `SetupListHelper` for all lists (the foundation for the Future Report Builder).
> 3. Developing an `ErpForm` vanilla JS class to replace `ErpFormHelper`, enabling automatic DOM-to-JSON serialization without manual `document.getElementById` mapping.
> 4. Rearchitecting the SPA Router to use `mount()` and `unmount()` lifecycle hooks, eliminating the fake `DOMContentLoaded` pattern.

## Open Questions

> [!IMPORTANT]
> **Approval to Proceed with the Framework Refactor**
> Are you aligned with the architecture assessments in the documents? Should I proceed with implementing the **Stage 1 Refactor** on the core framework and migrating the existing `Company` module over to it to prove its stability?

## Proposed Changes

If approved, the execution phase will involve:

### `src/services/`
#### [NEW] `BaseService.js`
#### [NEW] `CompanyService.js`

### `src/components/`
#### [NEW] `ErpDataGrid.js`
#### [NEW] `ErpForm.js`

### `src/js/`
#### [MODIFY] `router.js` (Implement standard lifecycle hooks instead of fake DOMContentLoaded)

### `src/company/`
#### [MODIFY] `company-list.js` (Refactor to use `CompanyService` and `ErpDataGrid`)
#### [MODIFY] `company-create.js` (Refactor to use `CompanyService` and `ErpForm`)
#### [MODIFY] `company-edit.js`
#### [MODIFY] `company-view.js`

## Verification Plan

### Manual Verification
1. I will manually test the router in the browser to ensure no flickering or script execution failures occur.
2. The Company List, Create, Edit, and View forms must function identically to the Golden Reference, but utilizing the newly decoupled architecture.
3. Verify that database records are successfully saved and fetched using the new Service layer without breaking RLS rules.
