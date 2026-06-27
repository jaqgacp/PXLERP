# ERP Toolbar Standard

## 1. Purpose
The PXL ERP Toolbar Standard ensures that every list page presents a clean, professional, and permission-aware interface to the user. This standard enforces the rule that **only applicable, implemented, and permitted actions** are shown to the user.

## 2. Why Fake Buttons are Forbidden
In an enterprise ERP, displaying buttons for features that are not yet implemented (e.g., "Generate" or "Approve") or displaying placeholder buttons (e.g., `onclick="alert('Not implemented yet')"`) degrades user trust. It creates an impression of an incomplete, amateur system. A clean interface with three working buttons is infinitely superior to a cluttered interface with seven broken ones.

## 3. Common Actions
These actions are globally understood and can be included on almost any Master Data or Transaction list, **provided they are fully implemented**:
- **New** (`btn-primary`): Opens the creation form.
- **Import**: Opens the import batch modal.
- **Export**: Exports the current filtered list to CSV/Excel.
- **Download Template**: Downloads the CSV template for imports.
- **Print**: Opens a printable view of the list.
- **Refresh**: Reloads the list from the server.

## 4. Conditional Actions
These actions are domain-specific and must ONLY appear if the current module natively supports the workflow:
- **Generate**: E.g., Generate Amortization Schedule.
- **Approve**: E.g., Approve Journal Entry, Approve PO.
- **Post**: E.g., Post to General Ledger.
- **Void / Reverse**: E.g., Void Check, Reverse Journal.
- **Lock / Unlock**: E.g., Lock Fiscal Period.
- **Submit**: E.g., Submit for Approval.
- **Archive**: E.g., Soft delete.

## 5. Module-Specific Toolbar Configuration
Future iterations of the ERP List Helper should drive toolbar generation via configuration rather than raw HTML, ensuring consistency:
```javascript
toolbarActions: [
  { key: 'new', label: '+ New Company', class: 'btn-primary', action: () => window.location.hash = '#/setup/company-setup/new' },
  { key: 'export', label: 'Export', class: 'btn-secondary', action: exportFn },
  { key: 'print', label: 'Print', class: 'btn-secondary', action: printFn }
]
```

## 6. Permission-Aware Future Design
As the RBAC (Role-Based Access Control) framework matures, the toolbar configuration will intercept the user's permissions (e.g., `has_permission('company.export')`) and automatically omit the button from the DOM if the permission returns false. This prevents unauthorized users from even seeing restricted actions.

## 7. Current Toolbar Matrix (Phase 4.6B)

| Module | New | Import | Export | Print | Download Template | Generate | Approve |
|---|---|---|---|---|---|---|---|
| **Company** | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Branch** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| **Currency** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Fiscal Years** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Fiscal Calendar**| ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

*(✅ = Displayed, ❌ = Hidden/Removed)*
