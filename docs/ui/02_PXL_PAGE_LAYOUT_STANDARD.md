# PXL ERP — Page Layout Standard

## Universal Page Layout

Every workspace follows this exact vertical sequence. No deviations.

```
┌─────────────────────────────────────────────────────────┐
│ Breadcrumb                                               │
│ Home › Module › Category › Workspace                    │
├─────────────────────────────────────────────────────────┤
│ Page Header                                              │
│ [Icon] Page Title                                        │
│ Short description — one line max                         │
│ Meta: Period | Company | Branch | Record Count | Status  │
├─────────────────────────────────────────────────────────┤
│ Toolbar (sticky)                                         │
│ [+ New] [⬆ Import] [⬇ Export] [Generate] [✓ Approve]   │
├─────────────────────────────────────────────────────────┤
│ Filter Bar                                               │
│ Search | Company | Branch | Period | Status | Advanced ▼ │
├─────────────────────────────────────────────────────────┤
│ Data Grid                                                │
│ ☐ | Doc # | Date | Party | Amount | Status | By | ⋯    │
│ ─────────────────────────────────────────────────────   │
│ [row]                                                    │
│ [row]                                                    │
│     OR                                                   │
│ Empty State (no records found)                           │
├─────────────────────────────────────────────────────────┤
│ Pagination                                               │
│ N records  ‹ Prev  [1]  [2]  Next ›                     │
└─────────────────────────────────────────────────────────┘
```

## Module Landing Page Layout

Module landings (`#/sales`, `#/accounting`, etc.) use a simplified layout:

```
Breadcrumb
Page Title + Description
Quick Access grid (cards to top workspaces)
Blueprint notice (Phase 1 only)
```

## Page Header

Every workspace header must include:

| Element         | Example                    | Required |
|-----------------|----------------------------|----------|
| Page Title      | Sales Invoices             | Yes      |
| Description     | One sentence purpose       | Yes      |
| Period chip     | June 2026                  | Yes      |
| Company chip    | PXL Demo Corp.             | Yes      |
| Branch chip     | Main                       | Yes      |
| Record Count    | 0 records                  | Yes      |
| Status chip     | Blueprint / Live           | Yes      |

## Breadcrumb Rules

- Always starts with clickable `Home`
- Every segment is clickable except the last (current page = bold)
- Format: `Home › Module › Category › Workspace`
- Never show more than 4 levels

## Spacing Rhythm

| Element          | Top spacing |
|------------------|-------------|
| Breadcrumb       | 0           |
| Page Title       | 4px below breadcrumb |
| Meta row         | 6px below title |
| Toolbar          | 18px below meta |
| Filter Bar       | 0 below toolbar |
| Grid             | 12px below filter |
| Pagination       | 10px below grid |

## Content Width

- Max content width: unrestricted (fills available area)
- Side padding: 36px left/right
- Bottom padding: 80px (clears status bar)

## Right Panel (future standard)

Preference is slide-in right panel over popup modals. Keeps user in context of the list.

```
[List View] ──→ click row ──→ [List View + Right Panel]
                              (not a separate page)
```
