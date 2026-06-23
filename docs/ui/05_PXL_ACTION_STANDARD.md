# PXL ERP — Action Standard

## Action Placement Rules

Actions belong inside workspaces. They must never appear in navigation. This is a hard rule.

| Action Type      | Lives in         | Never in          |
|------------------|------------------|-------------------|
| New, Import      | Toolbar          | Nav menu          |
| Export, Print    | Toolbar          | Nav menu          |
| Approve, Post    | Toolbar + Row    | Nav menu          |
| View, Edit       | Row Actions      | Toolbar           |
| Reverse, Void    | Row Actions      | Toolbar           |
| Audit Trail      | Row Actions      | Toolbar           |
| Delete           | NEVER (hard DELETE revoked) | —     |

## Document Lifecycle Actions

Each document type follows a defined workflow. Actions only appear when the document is in a state where that action is valid.

### Standard Transaction Lifecycle

```
[Draft] → Approve → [Approved] → Post → [Posted]
                                    ↓
                                  Reverse → [Reversal JE]
[Draft] → Void → [Void]
[Approved] → Void → [Void]
```

### State-Action Matrix

| Current Status | Available Actions                        |
|----------------|------------------------------------------|
| Draft          | Edit, Approve, Void, Print               |
| Approved       | Post, Void, Print, Duplicate             |
| Posted         | View, Reverse, Print, Attachments, Audit |
| Void           | View, Print, Audit Trail                 |

## Approval Actions

- **Approve** button: only visible for users with approve permission on that module
- **Post** button: only visible for users with post permission
- Approval actions trigger an audit log entry (who, when, from status, to status)
- Approval is irreversible without a Void or Reversal

## Destructive Actions (Void / Reverse)

- Void and Reverse must show a **confirmation dialog** before executing
- Confirmation must state:
  - Document number
  - What will happen (e.g., "This will create a reversing journal entry")
  - Reason field (required for audit trail)
- Bulk void/reverse: not allowed without explicit confirmation per document

## Print / Export Actions

- Print opens a print-ready view or PDF download — same window, no popup
- Export generates a CSV/Excel file — immediate download
- Both actions are always available regardless of document status

## Future: Posting Preview

Before a Post action executes, show a posting preview:

```
Posting Preview for [Document #]
─────────────────────────────────
Debit    1010 · Cash                   ₱10,000.00
Credit   4010 · Sales Revenue                     ₱8,929.00
Credit   2140 · Output VAT Payable                ₱1,071.00
─────────────────────────────────
Total Debit   ₱10,000.00   Total Credit ₱10,000.00   ✓ Balanced

[Confirm & Post]  [Cancel]
```

This is a Phase 2 feature. Do not implement until the posting engine is connected.

## Global Search

The top search bar must support multi-entity search:

| Entity          | Search by                        |
|-----------------|----------------------------------|
| Customer        | Name, TIN                        |
| Supplier        | Name, TIN                        |
| Sales Invoice   | Invoice #, OR #                  |
| Purchase Order  | PO #                             |
| Journal Entry   | JE #, reference                  |
| Account         | Account code, account name       |
| Report          | Report name                      |

Search results grouped by entity type. Clicking a result navigates to that record.

## Favorites & Recent History

Future Phase 2 features:

**Recent** (header): last 5 visited workspaces with record numbers  
**Favorites** (pinned): user-pinned workspaces, persisted per session

Both are UI-layer only — no backend storage required in Phase 1.
