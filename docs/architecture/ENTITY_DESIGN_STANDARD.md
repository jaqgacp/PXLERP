# PXL ERP Entity Design Standard

**Date:** June 26, 2026
**Status:** FROZEN (Constitution for all Business Entities)

## Objective
This document defines the mandatory architectural standard for every business entity inside PXL ERP. It serves as the constitution for Master Data design to ensure absolute consistency, compliance, and maintainability.

---

## 1. Identity
Every entity table must possess the following minimum identity fields:
* `id`: UUID Primary Key (default `gen_random_uuid()`)
* `code`: Unique alphanumeric identifier (indexed)
* `name`: Full descriptive name
* `short_name`: Abbreviated name (where applicable, for dense UI)
* `description`: Optional text description
* `is_active`: Boolean flag (default `true`)

---

## 2. Ownership & Scoping
Entities must be explicitly scoped. Evaluate each new entity against these tiers:
* **Global**: Shared across all companies (e.g., Currencies, UOMs, ATC Codes). Use only for universally standard data.
* **Company Scoped**: Owned by a specific `company_id`. Must enforce RLS isolation (e.g., Chart of Accounts, Customers, Vendors).
* **Branch Scoped**: Owned by a specific `branch_id` within a company (e.g., Warehouses, Cash Registers).

---

## 3. Audit
Absolute immutability and traceability are required. Every entity must contain:
* `created_at`: Timestamp (default `now()`)
* `created_by`: UUID of the creating user
* `updated_at`: Timestamp (updated via trigger)
* `updated_by`: UUID of the updating user
* `deleted_at`: Timestamp (null by default)
* `deleted_by`: UUID of the deleting user

> [!CAUTION]
> **Soft delete only.** Never hard delete business data. Triggers must block `DELETE` statements and enforce `UPDATE deleted_at = now()`.

---

## 4. UI Standard
Every entity module must implement the standard 4-view lifecycle:
* **List View** (`#/module`)
* **Create View** (`#/module/new`)
* **Edit View** (`#/module/edit?id=...`)
* **Read-Only View** (`#/module/view?id=...`)

*Future Roadmap Requirements:* The architecture must leave room to support Clone, Archive, Merge, and Restore operations natively.

---

## 5. ERP List Standard
Lists must be rendered using `SetupListHelper` (or its designated successor) and must support:
* Search (Text-based filtering)
* Pagination (Server-side for large datasets)
* Sorting (By Code or Name as default)
* Data Export (CSV/Excel)
* Data Import (Bulk creation)

*Future Roadmap Requirements:* Architecture must not prevent dynamic column choosers, saved user views, report builders, and advanced composite filters.

---

## 6. ERP Form Standard
Every form must follow the Golden Reference (Company UI) principles:
* **Density First**: Compact inputs, minimal whitespace.
* **Typography over Icons**: Use clear, bold section headers instead of relying on decorative icons or colors.
* **Professional Aesthetics**: Neutral enterprise colors, no neon colors, no emojis, no startup-style floating cards or oversized shadows.
* **Ergonomics**: Optimized for accountants navigating via keyboard 8–10 hours a day.

---

## 7. Validation Standard
* **UI Layer**: Utilize HTML5 validation (`required`, `pattern`, `maxlength`) for immediate user feedback.
* **Database Layer**: Server/Database validation remains authoritative. Enforce constraints (e.g., `check`, `not null`) and triggers at the schema level. No duplicated arbitrary logic in the middle tier.

---

## 8. Security Standard
Never bypass Row-Level Security (RLS). Respect:
* Company access controls
* Branch access restrictions
* Granular user permissions
* *Future*: Approval workflows before record activation.

---

## 9. Compliance Standard
Master Data is the foundation of Philippine compliance. It must capture sufficient and accurate information to support:
* BIR Forms (e.g., 2550Q, 1702Q, 1601EQ)
* SLSP (Summary List of Sales and Purchases)
* SAWT & QAP
* DAT files (Computerized Accounting System requirements)
* Financial Statements & Audit Trails
* *Future*: AI-driven anomaly detection.

*Rule: We capture data once in Master Data and reuse it everywhere. Transactions should reference, not duplicate, compliance identities.*

---

## 10. Extensibility
Design entity schemas to support future horizontal extensions without breaking the core table:
* Attachments
* Notes & Comments
* Activity/Audit Logs
* Approval Workflows
* Tags
* Custom Fields (EAV or JSONB patterns)
