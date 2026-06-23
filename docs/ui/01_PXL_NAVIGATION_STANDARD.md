# PXL ERP — Navigation Standard

## Four-Level Hierarchy

```
Level 1   Business Module
Level 2   Business Category
Level 3   Workspace / Screen
Level 4   Actions (NEVER in navigation)
```

## Level 1 — Business Modules (fixed, top nav)

| Module      | Icon | Route         |
|-------------|------|---------------|
| Setup       | ⚙️   | `#/setup`     |
| Master Data | 🗂️   | `#/master-data` |
| Sales       | 🛒   | `#/sales`     |
| Purchasing  | 🏪   | `#/purchasing` |
| Assets      | 💼   | `#/assets`    |
| Accounting  | 📒   | `#/accounting` |
| Compliance  | 📑   | `#/compliance` |
| Reports     | 📊   | `#/reports`   |

This list is **frozen**. New features plug into existing modules. A new top-level module requires explicit architecture review.

## Level 2 — Business Categories

Each module exposes categories on hover. Categories group related workspaces. They do not navigate directly to pages — they reveal the Level 3 list.

### Sales Categories
Transactions · Sales Cycle · Receivables · Tax Review · Registers

### Purchasing Categories
Transactions · Payables · Tax Review · Registers

### Assets Categories
Cash Management · Inventory · Fixed Assets

### Accounting Categories
Journal Entries · Ledgers · Subsidiary Ledgers · Schedules · Period Management

### Compliance Categories
Percentage Tax · VAT · Withholding Tax · Income Tax · BIR Books · Audit & CAS

### Reports Categories
Financial Statements · Trial Balance · Tax Reports · Aging Reports · Bank Reports · Inventory Reports · Fixed Asset Reports · Management Reports · Transaction Registers · Audit Reports

### Setup Categories
Organization · System Controls · Document & Validation · Accounting Setup · Tax Setup

### Master Data Categories
Parties · Customer Profile · Supplier Profile · Items & Services · Inventory Master · Shared

## Level 3 — Workspaces

Actual pages. Each workspace is a named screen where accountants perform work. Examples:
- `Sales Invoice` — create and manage sales invoices
- `Journal Entry` — create and post manual journals
- `VAT Working Papers` — prepare VAT returns
- `Trial Balance` — view account balances

## Level 4 — Actions

Actions live **inside** workspaces. They must never appear in navigation menus.

| Action     | Where it lives            |
|------------|---------------------------|
| New        | Toolbar                   |
| Import     | Toolbar                   |
| Export     | Toolbar                   |
| Approve    | Toolbar or Row Actions    |
| Post       | Toolbar or Row Actions    |
| Print      | Toolbar or Row Actions    |
| Reverse    | Row Actions               |
| Void       | Row Actions               |
| Audit Trail| Row Actions               |

## Navigation Technical Rules

- All modules use the same `flyout-wrap / flyout-cats / flyout-panels` HTML pattern.
- No module may use a one-off navigation style.
- Navigation must be driven from one shared config object (`MODULE_PAGES`).
- Every breadcrumb: `Home › Module › Category › Workspace`
- Every breadcrumb level must be clickable and navigable.
- Future pages must plug into `Module → Category → Workspace`. Do not bypass.
