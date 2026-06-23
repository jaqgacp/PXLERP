# PXL ERP — Design System

## Color Palette

### Brand Colors

| Token          | Value     | Usage                              |
|----------------|-----------|------------------------------------|
| `--ns-dark`    | `#1f3a5f` | Primary navy — nav, headings, buttons |
| `--ns-darker`  | `#162b47` | Top bar, status bar backgrounds    |
| `--ns-accent`  | `#e8a020` | Gold accent — active states, highlights |
| `--ns-hover`   | `#254a78` | Nav hover, active nav state        |
| `--ns-sub`     | `#2d5a8e` | Secondary blue elements            |
| `--ns-border`  | `#3a6ea8` | Nav border colors                  |
| `--ns-text`    | `#e8eef5` | Nav text (on dark backgrounds)     |
| `--ns-muted`   | `#9ab3cc` | Secondary text, labels             |

### Dropdown / Content Colors

| Token         | Value     | Usage                              |
|---------------|-----------|------------------------------------|
| `--dd-bg`     | `#ffffff` | Dropdown and card backgrounds      |
| `--dd-border` | `#c8d8e8` | Dropdown border                    |
| `--dd-head`   | `#1f3a5f` | Dropdown section headers           |
| `--dd-item`   | `#1a1a2e` | Dropdown item text                 |
| `--dd-hover`  | `#eef4fb` | Row and item hover background      |
| `--dd-cat`    | `#6b8faa` | Dropdown sub-category labels       |
| `--content-bg`| `#f0f4f8` | Page content area background       |

### Status Colors

| Status    | Background | Text      | Border    |
|-----------|------------|-----------|-----------|
| Draft     | `#f0f4f8`  | `#5a7a96` | `#c8d8e8` |
| Approved  | `#e8f5e8`  | `#2d7a2d` | `#b8d8b8` |
| Posted    | `#e8f0fb`  | `#1f3a5f` | `#b8c8e8` |
| Void      | `#fdf0f0`  | `#8b2020` | `#e8c0c0` |
| Cancelled | `#f8f4e8`  | `#7a5a20` | `#e8d8a8` |

## Typography

| Element         | Size | Weight | Color        |
|-----------------|------|--------|--------------|
| Page title      | 22px | 700    | `#1f3a5f`    |
| Section head    | 11px | 700    | `#1f3a5f`    |
| Body text       | 13px | 400    | `#5a7a96`    |
| Grid header     | 11px | 700    | `#1f3a5f`    |
| Grid row        | 12px | 400    | `#2a3a50`    |
| Breadcrumb      | 11px | 400    | `#7a9bb5`    |
| Status chip     | 10px | 700    | varies       |
| Nav label       | 12px | 600    | `#e8eef5`    |
| Dropdown item   | 12px | 400    | `#1a1a2e`    |

Font family: `"Segoe UI", Arial, sans-serif`

## Component Library

### Defined Components (Phase 1)

| Component         | CSS class(es)            | Description                        |
|-------------------|--------------------------|------------------------------------|
| NavItem           | `.nav-item`              | Top-level nav module               |
| FlyoutWrap        | `.flyout-wrap`           | 2-level flyout container           |
| FlyoutCats        | `.flyout-cats`           | Category list (left side)          |
| FlyoutPanels      | `.flyout-panels`         | Item panels (right side)           |
| FlyoutCat         | `.flyout-cat`            | Individual category row            |
| FlyoutPanel       | `.flyout-panel`          | Item list for one category         |
| DropdownItem      | `.dd-item`               | Individual nav link                |
| SubHead           | `.dd-sub-head`           | Label within a panel               |
| ModuleCard        | `.module-card`           | Dashboard module card              |
| QuickCard         | `.quick-card`            | Module landing quick-access card   |
| SectionHead       | `.section-head`          | Section label                      |
| Breadcrumb        | `.breadcrumb`            | Breadcrumb bar                     |
| PageTitle         | `.page-title`            | H1-level page title                |
| PageSubtitle      | `.page-subtitle`         | Description line                   |
| WsMeta            | `.ws-meta`               | Workspace header chips row         |
| WsMetaChip        | `.ws-meta-chip`          | Individual context chip            |
| Toolbar           | `.toolbar`               | Button toolbar                     |
| BtnPrimary        | `.btn.btn-primary`       | Primary action button              |
| BtnSecondary      | `.btn.btn-secondary`     | Secondary action button            |
| ToolbarSep        | `.toolbar-sep`           | Vertical divider in toolbar        |
| FilterBar         | `.filter-bar`            | Filter row                         |
| GridWrap          | `.grid-wrap`             | Table container                    |
| GridTable         | `.grid-table`            | Data table                         |
| StatusChip        | `.status`                | Base status chip                   |
| EmptyState        | `.empty-state`           | No-records display                 |
| Pagination        | `.pagination`            | Page navigation row                |
| PlaceholderBox    | `.placeholder-box`       | Legacy blueprint notice (phase 1)  |
| StatusBar         | `.status-bar`            | Smart footer                       |

### Planned Components (Phase 2)

| Component         | Purpose                              |
|-------------------|--------------------------------------|
| RightPanel        | Slide-in record view panel           |
| ConfirmDialog     | Void/reverse confirmation modal      |
| PostingPreview    | Debit/credit preview before posting  |
| TraceabilityPanel | Full audit chain viewer              |
| GlobalSearch      | Multi-entity instant search          |
| RecentHistory     | Last-visited records dropdown        |
| FavoritesBar      | Pinned workspace shortcuts           |
| NotificationBell  | System alerts (period lock, approvals)|

## Spacing

| Token         | Value   |
|---------------|---------|
| Content padding (sides) | 36px |
| Content padding (top) | 28px |
| Content padding (bottom) | 80px (clears status bar) |
| Card gap | 14px |
| Quick card gap | 10px |
| Section head top margin | 24px |

## Shadows

| Context         | Value                                   |
|-----------------|-----------------------------------------|
| Dropdown        | `0 8px 24px rgba(0,0,0,.18)`           |
| Card hover      | `0 4px 16px rgba(31,58,95,.12)`        |
| Quick card hover| `0 2px 10px rgba(31,58,95,.10)`        |
| Grid wrap       | none (border only)                     |
