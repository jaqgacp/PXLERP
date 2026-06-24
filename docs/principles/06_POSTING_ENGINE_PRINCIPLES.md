# PXL ERP Posting Engine Principles

Version: PXL Constitution v1.0
Status: Canonical governing principles
Scope: Posting rules, journals, ledgers, accounting events, reversals, allocations, fiscal locks, and posting traceability

## Purpose

This document defines the permanent posting engine principles for PXL ERP. The posting engine protects accounting correctness and must be deterministic, auditable, and rule-based.

## Core Posting Principles

### 1. Posting Is Centralized

All accounting entries must be created through the posting engine or approved service-layer posting routines. Modules must not write ledger entries directly.

### 2. Posting Is Rule-Based

Posting behavior must come from configured posting rule sets and posting rule lines, not hidden code paths. Rules must define source events, account selection, debit and credit logic, dimensions, and effective periods.

### 3. Every Posting Has A Source

Each journal entry and ledger movement must trace back to a source document, source table, source record, posting event, posting rule, and user or service action.

### 4. Postings Must Balance

The posting engine must enforce balanced debit and credit entries before finalizing journal output. Unbalanced postings must fail.

### 5. Posting Must Be Idempotent

Retrying a posting operation must not create duplicate accounting entries. The engine must detect existing postings for the same source and event where appropriate.

### 6. Posted Documents Are Immutable

Once a document is posted, ordinary users must not edit posted accounting fields. Corrections must use reversal, credit memo, debit memo, adjustment, void, or other documented accounting workflows.

### 7. Reversal Is Traceable

Reversals must create traceable accounting records linked to the original source and original journal. They must not silently delete or overwrite the original posting.

### 8. Fiscal Locks Are Enforced

Posting, reversal, adjustment, and amendment operations must respect fiscal year and fiscal period locks. Locked periods require authorized workflows.

### 9. Approval And Posting Are Separate Gates

Approval confirms business authorization. Posting creates accounting effect. The system must not assume one automatically replaces the other unless the workflow explicitly says so.

### 10. Service Role Owns Posting Effects

Posting-generated fields, ledger balances, inventory costing effects, depreciation effects, allocation fields, and compliance posting status must be written by trusted service logic, not ordinary client updates.

### 11. Posting Must Respect Dimensions

Company, branch, department, cost center, project, customer, supplier, item, bank, asset, and tax dimensions must be captured where required for reporting, compliance, and audit.

### 12. Source Snapshots Must Be Preserved

Posting must use the correct source facts as of the transaction date, including tax profile, rates, accounts, posting rules, document numbers, and compliance identifiers.

### 13. Preview Is Not Posting

A posting preview may help users understand expected accounting entries, but only the posting service creates official journals and ledger records.

### 14. Posting Errors Must Be Explainable

Posting failures must produce actionable errors that identify missing rules, invalid accounts, unbalanced lines, locked periods, invalid statuses, missing dimensions, or permission failures.

### 15. No Hidden Journals

All accounting-impacting entries must appear in the journal and ledger traceability model. Hidden adjustments or code-only balances are not allowed.

### 16. Reports Must Trace To Posting

Trial balance, general ledger, financial statements, tax reports, and management reports must be able to drill back to posting output and original source documents.

### 17. Posting Tests Are Required

Each posting workflow must have tests for debit and credit correctness, status transitions, reversal behavior, lock handling, duplicate prevention, RLS boundary, and report traceability.
