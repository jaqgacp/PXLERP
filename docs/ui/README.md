# PXL ERP — UI Standards Documentation

This folder contains the canonical UI/UX standards for PXL ERP.

All new UI development must conform to these standards before implementation.

## Document Index

| File | Title | Description |
|------|-------|-------------|
| [00_PXL_UI_PRINCIPLES.md](00_PXL_UI_PRINCIPLES.md) | UI Principles | The seven design principles and philosophy |
| [01_PXL_NAVIGATION_STANDARD.md](01_PXL_NAVIGATION_STANDARD.md) | Navigation Standard | 4-level nav hierarchy, module/category map |
| [02_PXL_PAGE_LAYOUT_STANDARD.md](02_PXL_PAGE_LAYOUT_STANDARD.md) | Page Layout Standard | Universal page structure for every workspace |
| [03_PXL_TOOLBAR_STANDARD.md](03_PXL_TOOLBAR_STANDARD.md) | Toolbar Standard | Fixed button order, styles, behavior |
| [04_PXL_GRID_STANDARD.md](04_PXL_GRID_STANDARD.md) | Grid Standard | Column order, row actions, status chips, filters |
| [05_PXL_ACTION_STANDARD.md](05_PXL_ACTION_STANDARD.md) | Action Standard | Where actions live, lifecycle, audit |
| [06_PXL_TRACEABILITY_STANDARD.md](06_PXL_TRACEABILITY_STANDARD.md) | Traceability Standard | Source → Ledger → FS → BIR chain |
| [07_PXL_AUDIT_STANDARD.md](07_PXL_AUDIT_STANDARD.md) | Audit Standard | What gets audited, immutability, CAS |
| [08_PXL_DESIGN_SYSTEM.md](08_PXL_DESIGN_SYSTEM.md) | Design System | Colors, typography, spacing, component library |

## Architecture Note

Database architecture documentation lives in `docs/architecture/` (read-only after v4.0 freeze).  
UI standards live here in `docs/ui/` and are updated as the frontend evolves.

## Standards Status

| Standard          | Status    | Implemented in         |
|-------------------|-----------|------------------------|
| Navigation (4-level flyout) | ✅ Live | `index.html` nav |
| Universal Page Layout | ✅ Live | `renderPlaceholder()` |
| Toolbar | ✅ Live (shell) | `renderPlaceholder()` |
| Filter Bar | ✅ Live (shell) | `renderPlaceholder()` |
| Data Grid | ✅ Live (shell) | `renderPlaceholder()` |
| Status Chips | ✅ CSS defined | `index.html` styles |
| Empty State | ✅ Live | `renderPlaceholder()` |
| Smart Footer | ✅ Live | `#status-bar` |
| Breadcrumb | ✅ Live | `buildBreadcrumbFromPath()` |
| Right Panel | 🔲 Phase 2 | — |
| Posting Preview | 🔲 Phase 2 | — |
| Traceability Panel | 🔲 Phase 2 | — |
| Global Search | 🔲 Phase 2 | — |
| Favorites / Recent | 🔲 Phase 2 | — |
