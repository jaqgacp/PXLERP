# UI Framework Architectural Audit

## Executive Summary
The target UI for PXL ERP must emulate mature, high-density enterprise software (NetSuite, Business Central, SAP Business One, Oracle Fusion). It is designed for accounting and operations professionals who spend 8-10 hours a day inside the system. The objective is maximum information density without sacrificing readability, utilizing a predictable, muted visual hierarchy.

The recent Golden Reference updates to the Company module set the baseline. This audit reviews the framework's capability to scale this design across all future modules.

---

## 1. Information Density & Typography
**Current State:** 
The Company module successfully implemented high-density data fields. Form elements are compact. 
**Recommendations:**
* **Typography:** Stick strictly to system fonts (`"Segoe UI", Arial, sans-serif`) to eliminate web-font loading lag and maintain an OS-native feel. Keep base font size to `11px - 13px` for data grids and form inputs.
* **White Space:** Margins and padding should remain minimal. Decorative whitespace must be eliminated. Sections should be grouped logically by thin borders or very subtle background shading (e.g., `#f4f8fc`), not by massive gaps.

## 2. Forms & Layouts (Golden Standard)
**Current State:** 
The `.erp-grid` system drives the two-column or multi-column flow.
**Recommendations:**
* **Scalability:** The framework must evolve to support:
  * **Tabs:** Heavy transaction documents (Sales Orders) require tabs (e.g., Line Items, Shipping, Billing, Accounting, Custom Fields).
  * **Master-Detail (Header-Line) Grids:** Forms must support embedding editable data grids directly within the form for line items.
* **Read-Only / View States:** Inputs correctly use `readonly` and `disabled`, but visually they must look like flat text with subtle borders rather than locked input boxes to improve readability in View mode.

## 3. Lists and Tables
**Current State:** 
The `.grid-table` class provides a clean, muted table style. 
**Recommendations:**
* **Headers:** Column headers must remain sticky on long scrolls.
* **Alignment:** Strict enforcement of alignment rules:
  * Text / IDs / Names -> Left Aligned
  * Dates -> Center Aligned
  * Numbers / Currency -> Right Aligned
* **Density:** Row padding should be kept to `4px - 6px` vertically to maximize rows visible above the fold. 

## 4. Navigation & Toolbars
**Current State:** 
The Mega Dropdown and top navbar are functional and professional.
**Recommendations:**
* **Toolbar Standardization:** Every module must have a predictable toolbar located in the exact same upper-right or top-left position.
  * Primary Action (Save, Post) = Solid Button
  * Secondary Actions (Cancel, Void, Print) = Outlined/Ghost Button
* **Icons:** As established in the Company module, emojis must be permanently banned from production UI elements (action buttons). If icons are necessary, utilize a unified, minimalist SVG icon set (e.g., Lucide or Phosphor icons) in a monochrome palette.

## 5. Visual Hierarchy & Colors
**Current State:** 
Utilizes a muted blue/navy color palette (`--ns-dark`, `--ns-accent`).
**Recommendations:**
* The ERP should rarely use color. 
* Red should *only* mean Error or Void/Delete.
* Green should *only* mean Success or Posted.
* Yellow/Orange should *only* mean Warning or Draft.
* All other UI elements should rely on grayscale or the primary navy brand color.
