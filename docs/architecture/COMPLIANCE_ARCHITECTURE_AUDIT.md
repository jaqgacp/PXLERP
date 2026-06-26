# Compliance Architecture Audit

## Executive Summary
Philippine compliance is the primary differentiator for PXL ERP. The architecture must natively support BIR requirements (CAS, VAT, Withholding Taxes, SLSP/SAWT, Books of Accounts) without requiring external spreadsheets or brittle workarounds. The existing database migrations (e.g., `005_tax_setup.sql` and `015_compliance.sql`) establish a solid foundation by separating tax entries from general ledger entries.

---

## 1. Tax Ledger Architecture
**Current Strategy:** 
The database uses distinct tables for `vat_entries`, `ewt_entries`, `fwt_entries`, etc., rather than forcing tax reporting to rely solely on parsing General Ledger (GL) accounts.
**Audit Finding:** 
* This is the **correct architectural pattern**. Extracting SLSP (Summary List of Sales and Purchases) or QAP (Alphalist) from raw GL lines is notoriously error-prone. By persisting structured tax entries at the moment a transaction is posted, the system captures the exact Base Amount, Tax Rate, ATC Code, and associated TIN required for generation of DAT files.
* **Risk:** The posting engine (to be designed) must guarantee ACID compliance. A Sales Invoice must post to the Sub-ledger (AR), the General Ledger, and the Tax Ledger (`vat_entries`) in a single database transaction. If one fails, all must roll back.

## 2. Document Number Integrity (CAS Requirement)
**Current Strategy:**
System relies on auto-incrementing or custom number series.
**Audit Finding:**
* The BIR strictly prohibits gaps in Official Receipts (OR), Sales Invoices (SI), and Journal Vouchers (JV). 
* The architecture must ensure that once a document number is fetched from the `number_series` table, it is permanently consumed. 
* If a transaction is cancelled mid-creation or voided after posting, the document number must remain assigned to a "Voided" record. Hard deletes of numbered transactions must be physically prevented at the database level (enforced via `018d_immutability_guards.sql`).

## 3. Reversal Entries vs. Deletion
**Current Strategy:**
Immutability guards prevent row deletion.
**Audit Finding:**
* The framework must support a standardized "Reversal" mechanism. If an accountant makes an error on a posted Journal Entry, they cannot edit it. The system must generate a reversing entry (swapping Debits and Credits) and link it to the original document (`reversed_by_doc_id`). 
* This leaves a perfect audit trail for BIR examiners.

## 4. Books of Accounts (CAS)
**Current Strategy:**
GL tables exist.
**Audit Finding:**
* For CAS (Computerized Accounting System) compliance, the system must generate the six mandatory books: General Ledger, General Journal, Sales Journal, Purchase Journal, Cash Receipts Journal, Cash Disbursements Journal.
* **Architecture Need:** The system needs a robust tagging mechanism on Journal Entries to classify them automatically into the correct subsidiary journal (e.g., `source_module = 'sales_invoice'` -> Sales Journal).

## 5. Period Locking
**Current Strategy:**
Fiscal periods exist.
**Audit Finding:**
* A simple boolean `is_closed` for a month is insufficient. The architecture must support granular locking:
  1. Soft Lock (Warn users but allow entry).
  2. Module Lock (Lock Accounts Payable on the 5th, but leave General Ledger open for adjusting entries until the 10th).
  3. Hard Lock (Closed period; strictly no entries allowed).
