# PXL ERP — UI Principles

## Philosophy

PXL ERP is not built to impress. It is built to be used — daily, reliably, by accountants who value predictability over novelty.

The target experience is:
- **Oracle NetSuite** — structured, consistent, role-aware
- **Microsoft Dynamics** — enterprise grid behavior, stable layouts
- **SAP Business One** — traceable, auditable, compliance-first

## The Seven Principles

### 1. Documentation is the source of truth
Every standard lives in `docs/`. When behavior is uncertain, consult the standard. When the standard is absent, write it before implementing.

### 2. Navigation finds workspaces — it does not perform actions
The top nav is for orientation, not transaction entry. Actions (New, Post, Approve, Void) belong inside workspaces, not in menus.

### 3. Every page follows the same layout
Breadcrumb → Page Header → Toolbar → Filter Bar → Data Grid → Pagination → Status Footer. No page invents its own structure.

### 4. Every action appears in the same place
Toolbar order is fixed: **New → Import → Export → Generate → Approve → Print**. Row actions order is fixed: **View → Edit → Duplicate → Approve → Post → Reverse → Void → Print → Attachments → Audit Trail**.

### 5. Every data grid behaves the same
Column order, sort behavior, pagination, row actions, and status chips are identical across all list views.

### 6. Every transaction is traceable
Source Document → Posting Rules → Journal Entry → Ledger → Trial Balance → Financial Statements → Tax Return → BIR Report. Every link in this chain must be navigable.

### 7. Every screen minimizes clicks
Daily-use actions (New Invoice, New JE) are one click from the module landing. Drill-down flows are linear and reversible via breadcrumb.

## What PXL Is NOT

- Not a flashy SaaS dashboard
- Not optimized for first impressions over daily use
- Not designed for screenshots — designed for accountants

## Design Targets

| Attribute         | Target                              |
|-------------------|-------------------------------------|
| Consistency       | Every page feels from the same system |
| Predictability    | No surprises in layout or behavior  |
| Traceability      | Every number links back to its source |
| Auditability      | Every change is logged and visible  |
| Training cost     | Learn once, apply everywhere        |
| Performance       | Fast for daily accounting workflows |
