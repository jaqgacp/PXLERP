# PXL ERP — Data Grid Standard

## Universal Column Order

Every list page uses this column order as the base. Screens may add domain-specific columns between Party and Amount.

```
☐ | Doc # | Date | Party | [domain columns] | Amount | Status | Created By | Actions
```

| Position | Column      | Fixed | Notes                              |
|----------|-------------|-------|------------------------------------|
| 1        | Checkbox    | Yes   | Always first                       |
| 2        | Document #  | Yes   | Clickable, opens View panel        |
| 3        | Date        | Yes   | Transaction/document date          |
| 4        | Party       | Yes   | Customer or Supplier name          |
| …        | Domain cols | No    | Screen-specific (e.g. Description) |
| N-3      | Amount      | Yes   | Right-aligned, formatted           |
| N-2      | Status      | Yes   | Status chip                        |
| N-1      | Created By  | Yes   | User who created the record        |
| N        | Actions     | Yes   | Always last — row action menu      |

## Row Actions Order

Row action menu items follow this fixed order:

1. View
2. Edit
3. Duplicate
4. ─ separator ─
5. Approve
6. Post
7. Reverse
8. Void
9. ─ separator ─
10. Print
11. Attachments
12. Audit Trail

Omit actions not applicable to the screen. Never reorder the ones that remain.

## Grid Behavior

| Behavior          | Standard                                |
|-------------------|-----------------------------------------|
| Row hover         | Light blue highlight (`#eef4fb`)        |
| Row click         | Opens right panel (future) / View page  |
| Doc # click       | Opens View — same as row click          |
| Column sort       | Click header to sort asc/desc           |
| Multi-select      | Via checkbox column                     |
| Bulk actions      | Appear in toolbar when rows selected    |
| Empty state       | Always show empty state component       |

## Pagination

- Default page size: 25 rows
- Options: 25, 50, 100
- Format: `N records · Page X of Y · ‹ Prev [pages] Next ›`
- Pagination always visible — never hide when 0 records

## Amount Formatting

- All amounts: Philippine Peso (₱) with 2 decimal places
- Negative amounts: parentheses format `(₱1,234.56)` — never minus sign
- Right-aligned always

## Status Chips

| Status    | Background | Text color  | Border      |
|-----------|------------|-------------|-------------|
| Draft     | `#f0f4f8`  | `#5a7a96`   | `#c8d8e8`   |
| Approved  | `#e8f5e8`  | `#2d7a2d`   | `#b8d8b8`   |
| Posted    | `#e8f0fb`  | `#1f3a5f`   | `#b8c8e8`   |
| Void      | `#fdf0f0`  | `#8b2020`   | `#e8c0c0`   |
| Cancelled | `#f8f4e8`  | `#7a5a20`   | `#e8d8a8`   |

Status text is uppercase, 10px, bold. Never use colored backgrounds that obscure readability.

## Filter Bar Standard

Filters appear in a single row bar, always in this order:

```
Search  |  Company  |  Branch  |  Period  |  Status  |  Advanced Filters ▼
```

| Filter           | Type     | Default          |
|------------------|----------|------------------|
| Search           | Text     | Placeholder text |
| Company          | Select   | All Companies    |
| Branch           | Select   | All Branches     |
| Period           | Select   | Current period   |
| Status           | Select   | All Status       |
| Advanced Filters | Expand   | Collapsed        |

Filters never move between screens. Never add filters inside the grid header.

## Empty State

When the grid has no records, show an inline empty state (inside the tbody):

```
[Module Icon]
No [Document Type] found.
[description line]
[+ New Button]  [⬆ Import]  [📖 Documentation]
```

Never show a blank table. The empty state is the CTA to create the first record.
