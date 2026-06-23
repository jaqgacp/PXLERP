# PXL ERP — Toolbar Standard

## Fixed Toolbar Order

Toolbar buttons always appear in this exact sequence. Never alphabetical. Never reordered per screen.

```
[+ New]  [⬆ Import]  [⬇ Export]  [⚙ Generate]  [✓ Approve]  [🖨 Print]
  PRIMARY   SECONDARY   SECONDARY    SECONDARY      SECONDARY   SECONDARY
```

| Position | Button   | Style     | When visible              |
|----------|----------|-----------|---------------------------|
| 1        | New      | Primary   | Always (if create allowed)|
| 2        | Import   | Secondary | Always                    |
| 3        | Export   | Secondary | Always                    |
| ─sep─    | ─        | Divider   | Before approval actions   |
| 4        | Generate | Secondary | Compliance / batch screens|
| 5        | Approve  | Secondary | Screens with approval flow|
| 6        | Print    | Secondary | Always                    |

## Button Styles

```css
/* Primary — New */
.btn-primary { background: #1f3a5f; color: #fff; }

/* Secondary — all others */
.btn-secondary { background: #fff; color: #1f3a5f; border: 1px solid #c8d8e8; }
```

## Toolbar Behavior

- Toolbar is **sticky** — stays visible when grid scrolls
- Buttons are **disabled** (not hidden) when the action is not available
- Disabled state: reduced opacity, no cursor
- No tooltips on enabled buttons — labels are self-explanatory
- Tooltips acceptable on disabled buttons to explain why disabled

## Context-Specific Buttons

Some screens add buttons after the standard set, separated by a divider:

| Screen            | Extra buttons                       |
|-------------------|-------------------------------------|
| Bank Reconciliation | Reconcile, Finalize               |
| Period Closing    | Lock Period, Generate Closing Entry |
| VAT Working Papers| Compute VAT, File Return            |
| Depreciation      | Run Depreciation                    |
| Physical Count    | Finalize Count                      |

Extra buttons always go **after** the Print button, separated by a divider. They never move the standard buttons.

## What NOT to Put in the Toolbar

- Row-level actions (View, Edit, Void, Reverse) → belongs in row Actions column
- Navigation links → belongs in nav
- Filter controls → belongs in Filter Bar
- Status toggles → belongs in Filter Bar
