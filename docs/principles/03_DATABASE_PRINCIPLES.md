# PXL ERP Database Principles

Version: PXL Constitution v1.0
Status: Canonical governing principles
Scope: Tables, columns, constraints, relationships, naming, migrations, and database verification

## Purpose

This document defines the permanent database principles for PXL ERP. The database is the foundation of accounting correctness, compliance traceability, security, and low-maintenance configuration.

## Core Database Principles

### 1. The Database Is The Contract

The database schema must reflect the approved architecture. Developers must not infer missing business concepts from UI screens, old drafts, or code behavior.

### 2. Phase 1 Active Table Target

The current Phase 1 active table target is 219 active tables after owner approval of `feature_definitions`.

This target includes:

- All documented active Phase 1 business tables.
- The 29 missing documented Phase 1 tables.
- The 11 Adaptive Workspace metadata tables.
- The `feature_definitions` canonical feature catalog table.

### 3. One Canonical Table Per Business Concept

Each business concept must have one canonical table or documented table family. Duplicate active specifications are not allowed.

### 4. Company Scope Is Explicit

Operational tables must include `company_id` unless they are true global reference tables, system metadata, or documented child tables whose tenant scope is inherited through a required parent.

### 5. Branch Scope Is Applied Where Operationally Relevant

Branch scope must be present where branch operations, inventory, cash, bank, sales, purchasing, fixed assets, approvals, reporting, or compliance need branch-level separation.

### 6. Global Tables Are Rare

Global tables must be true shared reference data, such as currencies, account types, permissions, or tax reference codes. A table must not be global merely because it is convenient.

### 7. Relationships Must Be Real

Foreign keys must be used where the parent record is known and stable. Deferred foreign keys are acceptable only when there is a documented reason, such as polymorphic source references or staged foundation reconciliation.

### 8. Polymorphic References Must Be Intentional

Polymorphic fields such as source type and source id may be used only for governed traceability patterns. They must not replace known foreign keys where the parent table is known.

### 9. Naming Must Be Canonical

Table names, column names, enum values, status fields, permission codes, and feature codes must follow documented naming rules. Ad hoc aliases create implementation risk.

### 10. Audit Columns Are Standard

Business tables must include standard audit columns unless they are immutable append-only records or documented exceptions. Audit fields must support accountability, change history, and forensic review.

### 11. Soft Deletion Is Preferred For Business Data

Business data should not be physically deleted by normal application users. Deactivation, cancellation, voiding, reversal, archiving, or soft deletion should be used according to the record type.

### 12. Posted And Filed Data Is Protected

Posted transactions, ledger entries, filed compliance records, completed valuation records, and locked-period data must be protected by constraints, policies, service logic, or controlled workflows.

### 13. Service-Owned Fields Must Be Protected

Fields produced by posting, inventory costing, compliance generation, approvals, import jobs, or other system services must not be directly mutable by ordinary authenticated users.

### 14. Effective Dating And Versioning Must Preserve History

Tax rules, compliance profiles, posting rules, document templates, price lists, terms, and other time-sensitive data must support historical reconstruction.

### 15. Snapshot Critical Compliance Data

Transactions must preserve compliance-sensitive facts at the time of transaction. Later master data changes must not rewrite historical tax, address, registration, rate, or document facts.

### 16. Index For Tenant And Posting Paths

Tenant filters, foreign keys, document lookup fields, posting traceability paths, import job paths, report filters, and compliance queries must have appropriate indexes.

### 17. Constraints Carry Business Truth

Database constraints should enforce stable invariants such as required relationships, unique document numbering within scope, nonnegative quantities where required, and valid date ranges.

### 18. Migrations Are Forward-Only

Schema changes must be delivered through committed migrations. Production changes must not be made manually outside the migration chain.

### 19. Earlier Migrations Are Historical

After merge, previous migrations must not be rewritten. Corrections must be made through new forward migrations unless the project owner explicitly authorizes a history rewrite before deployment.

### 20. Verification Queries Are Required

Every foundation migration must include or be paired with verification queries that confirm expected tables, constraints, indexes, RLS state, policies, and known exceptions.

### 21. Clean Database Compatibility

The full migration chain must be runnable on a clean database. A migration that only works because of local manual state is not acceptable.

### 22. Metadata Tables Are Foundation Tables

Feature catalog, workspace metadata, report metadata, dashboard metadata, role workspace assignment, company feature visibility, and user preferences are first-class foundation tables, not UI conveniences.

### 23. Database Design Must Support Future Modules

Future modules must be addable through metadata, setup, relationships, and documented extension points without refactoring Phase 1 core accounting, compliance, security, or workspace design.
