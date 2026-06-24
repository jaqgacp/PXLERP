# PXL ERP

A modern, highly scalable, multi-branch ERP system built on PostgreSQL and Supabase. PXL ERP is designed from the ground up for strict data immutability, automated accounting, and deep Philippine (BIR) tax compliance.

## 🚀 Project Vision

PXL ERP transforms complex enterprise resource planning into an elegant, automated, and strictly governed process. It eliminates hardcoded logic, embraces data-driven adaptive workspaces, and ensures that every business requirement is traceable down to the database row-level security policy.

## 🧠 Product Philosophy

**Simple + Complete**
- **No Hardcoding:** Roles, menus, pages, dashboards, approval flows, feature visibility, and tax logic are purely data-driven.
- **Adaptive Workspace:** The system dynamically adjusts its UI and features based on the company's compliance profile and user permissions.
- **Absolute Immutability:** Posted transactions, filed taxes, and audit trails cannot be altered. The database Row Level Security (RLS) acts as the final, unbreakable authority.
- **Compliance First:** Built natively to handle Philippine CAS (Computerized Accounting System) requirements, VAT, Withholding Taxes, and BIR forms out-of-the-box.

## 🏢 Target Market & Supported Entities

PXL ERP is designed for:
- Small to Medium Enterprises (SMEs)
- Accounting Firms managing multiple clients
- Multi-branch corporations

**Supported Transactions:**
- General Ledger & Journal Entries
- Sales & Receivables
- Purchasing & Payables
- Inventory & Warehousing
- Fixed Asset Management & Depreciation
- Petty Cash & Bank Reconciliation
- Complete Tax Compliance Reporting

---

## 📊 Current Repository Status

**Status: PREPARING FOR FOUNDATION FREEZE**

The project is currently finalizing its database architecture before beginning Frontend UI and CRUD development.

- **Current Active Table Target:** 219 Tables
- **Current Migrated Tables:** 178 Tables
- **Migration Status:** Implementing Migration 018 (Final Foundation Reconciliation)
- **RLS Status:** Enabled across all tables; policies undergoing final lockdown.

---

## 📚 Documentation Structure

Our documentation is strictly organized to act as the single source of truth.

```text
/
├── README.md                           # You are here
├── FOUNDATION_FREEZE_REPORT.md         # Canonical project status & M018 scope
├── PRINCIPLES_MASTER_INDEX.md          # Index of all architectural rules
├── docs/
│   ├── principles/                     # Core guiding principles (01-10)
│   ├── architecture/                   # Database & system specs (Doc00-Doc10)
│   ├── ui/                             # UI & Design System standards
│   └── matrices/                       # Traceability matrices
└── archive/                            # Superseded historical reports
```

---

## 🛠️ Where New Developers Start

Welcome to the team. To understand PXL ERP, you only need to read three documents in this exact order:

1. **[README.md](README.md)** - Project overview.
2. **[PRINCIPLES_MASTER_INDEX.md](PRINCIPLES_MASTER_INDEX.md)** - The rules that govern how we write code.
3. **[FOUNDATION_FREEZE_REPORT.md](FOUNDATION_FREEZE_REPORT.md)** - What we are building right now.

> [!WARNING]  
> **Do not trust historical audit reports in the `/archive` folder.** Always refer to the `FOUNDATION_FREEZE_REPORT.md` and the `docs/architecture` folder for canonical truth.

---

## 🔄 Implementation Workflow

We strictly enforce **Business Requirement Traceability**. No code is written without a clear path:

`Business Requirement` ➡️ `Architecture Doc` ➡️ `Database Table` ➡️ `Migration` ➡️ `RLS Policy` ➡️ `Backend Service` ➡️ `UI Form` ➡️ `Posting Engine` ➡️ `Report` ➡️ `Test Scenario` ➡️ `User Documentation`

If you are modifying the database, you must update the corresponding Architecture Document first.
