# PXL Philippine Compliance-First Decision

**Date:** June 27, 2026

## 1. Core Identity
PXL ERP is **not** a generic ERP with optional Philippine localization.
PXL ERP is a **Philippine Compliance-First Accounting ERP**.

Accounting, posting, audit trail, and Philippine statutory compliance are first-class architecture concerns.
Every transaction must eventually support downstream accounting, tax, books of accounts, audit trail, and BIR compliance output.

## 2. Non-Negotiable Architecture Principles
1. **Philippine compliance is first-class.** The architecture revolves around satisfying the BIR's strict requirements for CAS, taxation, and statutory books.
2. **Every transaction must trace** to a journal, ledger, tax impact, audit trail, and compliance output.
3. **Books of Accounts are legal outputs, not ordinary reports.** The General Ledger, Cash Receipts Book, Cash Disbursements Book, Sales Journal, and Purchase Journal must meet BIR formats.
4. **Tax codes are compliance architecture**, not merely dropdown values or accounting reference data. They dictate the flow into the Philippine Compliance Engine.
5. **Percentage Tax must not be removed or hidden.** It is a primary tax regime alongside VAT and must be fully supported.
6. **BIR CAS readiness must influence design from day one.** Immutability, audit logs, and period locking are non-negotiable.
7. **Setup defines rules; transactions generate facts; posting records accounting; compliance validates and exports.** This is the invariant data lifecycle.
8. **No generic ERP simplification may override Philippine requirements.** If a generic design conflicts with a BIR requirement, the BIR requirement wins.
9. **UI must be clean and must not expose fake actions.** Work-in-progress or roadmap items must be clearly marked or disabled.
10. **Documentation must remain one source of truth.** The canonical blueprints must reflect this compliance-first identity without dilution.

## 3. Tax Code Ownership
Tax codes may be configured from the UI under `Setup > Tax Setup`, but architecturally they belong to the **Philippine Compliance Engine**.

**Required Relationship:**
- Setup defines tax rules.
- Sales and Purchasing produce tax data.
- Posting Engine records tax/accounting impact.
- Compliance Engine validates, reconciles, and exports.
- Reports display results.
