# PXL ERP — Audit Standard

## Audit Philosophy

PXL ERP is a compliance-first system. Everything that happens must be recorded, and everything recorded must be inspectable. This is not optional.

## What Gets Audited

| Event                    | Audit record includes                       |
|--------------------------|---------------------------------------------|
| Record created           | User, timestamp, initial values             |
| Record edited (Draft)    | User, timestamp, field, old value, new value |
| Status changed           | User, timestamp, from status, to status, reason |
| Record posted            | User, timestamp, JE number generated        |
| Record reversed          | User, timestamp, original JE, reversal JE, reason |
| Record voided            | User, timestamp, reason                     |
| Master data changed      | User, timestamp, entity, field, old, new    |
| User login               | User, timestamp, IP (if available)          |
| Setup/config changed     | User, timestamp, setting, old, new          |
| ATP number used          | Document, timestamp, serial assigned        |
| DAT file generated       | User, timestamp, period, file hash          |
| Period locked/unlocked   | User, timestamp, period, action             |

## Audit Trail UI Location

Every workspace that shows a document has an **Audit Trail** option in the row Actions menu (last position).

Clicking opens a right-side panel (or modal in Phase 1) showing the full history chronologically, newest first.

## Immutability Rules

| Operation | Allowed                                      |
|-----------|----------------------------------------------|
| Delete    | NEVER — hard DELETE is revoked at DB level   |
| Edit      | Draft status only                            |
| Void      | Draft and Approved only (not Posted)         |
| Reverse   | Posted only — creates a new reversal document |

## Audit Reports

Audit reports are available in the Compliance › Audit & CAS module:

| Report                  | Description                                      |
|-------------------------|--------------------------------------------------|
| Transaction Audit Log   | All posting and status change events             |
| Master Data Change Log  | All changes to customers, suppliers, items, COA  |
| System Parameter Logs   | Setup and configuration change history           |
| User Activity Log       | Login/logout and action history per user         |
| Void Register           | All voided documents with reasons                |
| ATP Usage Log           | Authority to Print serial number assignments     |
| DAT Generation History  | CAS export file history with timestamps          |
| CAS Audit Report        | Summary report for BIR CAS compliance            |

## CAS-Specific Requirements

BIR Computerized Accounting System requirements mandate:

1. No gaps in document numbering (ATP-controlled series)
2. All voids recorded with official reasons
3. Audit trail exportable as DAT file in BIR-prescribed format
4. Minimum 10-year retention of transaction records
5. System parameter changes logged (tax codes, rates, COA)

The UI must surface these requirements clearly. CAS compliance is not a separate mode — it is the default behavior.

## Status Bar (Smart Footer)

The persistent status bar shows environment context on every page:

```
Company: [name]  Period: [month year]  Branch: [name]  User: [name]  PXL ERP v2.0
```

This is an audit aid — every accountant knows exactly which company and period they are working in at all times.
