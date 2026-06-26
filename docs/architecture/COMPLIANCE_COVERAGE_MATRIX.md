# Compliance Coverage Matrix

**Date:** June 26, 2026

## Objective
To ensure PXL ERP is genuinely "Philippine Compliance-First," no compliance report should ever require manual typing or spreadsheet gymnastics. The data must flow naturally from Master Data setups into Transactions, and ultimately into the BIR Reports and DAT files.

This matrix maps each major Philippine compliance requirement to the Master Data entities that supply its raw information.

## Coverage Matrix

| Compliance Requirement | Primary Master Data Sources | Transactional Sources |
| :--- | :--- | :--- |
| **2550Q (Quarterly Value-Added Tax Return)** | Company, Branch, Customer, Vendor, VAT Code, Tax Calendar | Sales Invoices, Receipts, Vendor Bills, Vendor Payments |
| **2307 (Certificate of Creditable Tax Withheld at Source)** | Company, Customer, Vendor, EWT Code, ATC Code, Signatory/Contact | Payments (for payables), Receipts (for receivables) |
| **SLSP (Summary List of Sales and Purchases)** | Company, Customer (TIN/Address), Vendor (TIN/Address), VAT Code, Item | Sales Invoices, Vendor Bills, Debit/Credit Memos |
| **1601EQ / 1601FQ (Quarterly Withholding Tax Returns)** | Company, Vendor, EWT Code, FWT Code, ATC Code | Vendor Bills, Payment Vouchers |
| **SAWT (Summary Alphalist of Withholding Taxes)** | Company, Customer, EWT Code, ATC Code | Sales Invoices, Collections |
| **QAP (Quarterly Alphalist of Payees)** | Company, Vendor, EWT Code, ATC Code | Vendor Bills, Disbursements |
| **DAT Files (CAS Requirement)** | Company, Branch, Chart of Accounts, Customer, Vendor, Tax Code, Item | General Ledger, Sales Journal, Purchase Journal, Cash Receipts, Disbursements |
| **Books of Accounts (General Ledger, Journals)** | Company, Chart of Accounts, Branch | Posting Engine (All transactions) |
| **1702Q / 1702RT (Corporate Income Tax Returns)** | Company, Branch, Chart of Accounts (Income/Expense classification) | General Ledger (Trial Balance) |

## Master Data Rule of Thumb
If a piece of information is required on a BIR form (e.g., RDO Code, 13-digit TIN, Registered Name vs Trade Name, ZIP Code), it **must** be captured at the Master Data level. Transactions will simply capture the `id` of the Master Data, and the reporting engine will join the required compliance fields on demand.
