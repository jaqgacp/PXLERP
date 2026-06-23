# PXL ERP — Traceability Standard

## The PXL Audit Chain

Every financial transaction in PXL ERP must be traceable from source document to BIR report. This is a core design requirement, not a feature.

```
Source Document
    ↓
Posting Rules (system-applied)
    ↓
Journal Entry (auto-generated)
    ↓
General Ledger
    ↓
Trial Balance
    ↓
Financial Statements
    ↓
Tax Return (2550M, 1702RT, etc.)
    ↓
BIR Report / DAT File
```

Every link in this chain must be navigable. A user must be able to start from a BIR report line and click back to the source document that created it.

## Traceability Panel (Future Feature)

Each posted document will expose a Traceability Panel showing the full chain:

```
Sales Invoice SI-2026-001234
──────────────────────────────
Source:   SI-2026-001234
          Customer: ABC Corp.
          Date: June 15, 2026
          Amount: ₱56,000.00
          ↓
Journal:  JE-2026-005678
          Debit  1100·AR  ₱56,000
          Credit 4010·Sales ₱50,000
          Credit 2140·VAT  ₱6,000
          ↓
Ledger:   Account 4010 — June 2026 activity
          ↓
TB Line:  4010 · Sales Revenue  ₱1,234,567
          ↓
FS:       Income Statement — Net Revenue
          ↓
Tax:      2550Q — Output VAT Base ₱50,000
          ↓
SLSP:     SLS Line — SI-2026-001234
```

## Traceability Rules

1. Every posting creates a journal entry — no direct ledger writes
2. Journal entries must reference the source document number
3. Reversal entries must reference both the original JE and the source document
4. Void does not delete — it creates a void record with audit metadata
5. All status changes are logged with: user, timestamp, old status, new status, reason

## Audit Trail

Every workspace must expose an Audit Trail row action:

**Audit Trail panel shows:**
- Created by, created at
- Each status change: who, when, from, to, reason
- Each field edit (for Draft documents): field name, old value, new value, user, timestamp
- Posting event: JE number, date, posted by
- Attachment additions/removals

## CAS Compliance

PXL's traceability standard is designed to satisfy BIR CAS (Computer Assisted Accounting System) requirements:

- Full audit trail of all transactions
- No gaps in document numbering
- All voids documented with reason
- DAT file generation covers all required books
- Export history tracked per generation

See `docs/architecture/07_AUDIT_AND_CAS_TABLE_DESIGN.md` for database-level audit design.
