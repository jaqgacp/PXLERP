# PXL ERP — Complete Table Inventory
**Version:** 2.0 — Revised for Implementation Readiness
**Total Tables:** ~210
**Status:** For CPA and Developer Review

Legend:
- **Type:** master | transaction | ledger | setup | audit | bridge | output | config | notification
- **RLS:** Row-Level Security required
- **Audit:** Field-change audit trail required (`field_change_history` trigger)
- **Soft Delete:** `deleted_at` soft delete supported
- **Immutable:** Record is immutable after posting (trigger enforced)
- **Volume:** low (<1K rows) | medium (1K–100K) | high (100K+)

---

## Changes Applied (v1 → v2)

- Added MODULE 24: NOTIFICATIONS (3 tables)
- Added MODULE 25: DOCUMENT TEMPLATES & GENERATED OUTPUT (3 tables)
- Added MODULE 26: BUDGET (2 tables)
- Added MODULE 27: PERIOD CLOSE (2 tables)
- Added MODULE 28: PARTY DUPLICATE MANAGEMENT (2 tables)
- Added `system_alerts` to MODULE 20: AUDIT & CAS
- Added `inventory_cost_layer_consumption` to MODULE 14: INVENTORY
- Added `bank_statement_lines` to MODULE 13: BANK
- Added `attachment_versions` to MODULE 21: ATTACHMENTS
- Added `posting_batches` and `posting_errors` — renamed `posting_rules` → `posting_rule_sets` for consistency with doc 06
- Renamed `export_batches` → `export_jobs` for consistency with doc 08
- Added `subledger_close_certifications` to MODULE 27
- Added `duplicate_tin_flags` to MODULE 28
- Clarified Cash Sales and Cash Purchases as separate transaction headers

---

## MODULE 1: SECURITY & IDENTITY

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 1 | `profiles` | Extended user profile linked to auth.users | master | ✅ | ✅ | ✅ | ❌ | low |
| 2 | `roles` | System and custom roles | setup | ✅ | ✅ | ✅ | ❌ | low |
| 3 | `permissions` | Granular permission codes | setup | ✅ | ✅ | ❌ | ✅ | low |
| 4 | `role_permissions` | Role → Permission mapping | bridge | ✅ | ✅ | ✅ | ❌ | low |
| 5 | `user_roles` | User → Role mapping per company | bridge | ✅ | ✅ | ✅ | ❌ | low |
| 6 | `user_company_access` | User access to companies | bridge | ✅ | ✅ | ✅ | ❌ | low |
| 7 | `user_branch_access` | User access to branches | bridge | ✅ | ✅ | ✅ | ❌ | low |
| 8 | `user_department_access` | User access to departments (optional fine-grained) | bridge | ✅ | ✅ | ✅ | ❌ | low |

---

## MODULE 2: ORGANIZATION SETUP

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 9 | `companies` | Company master record | master | ✅ | ✅ | ✅ | ❌ | low |
| 10 | `branches` | Branch under company | master | ✅ | ✅ | ✅ | ❌ | low |
| 11 | `departments` | Department under branch | master | ✅ | ✅ | ✅ | ❌ | low |
| 12 | `cost_centers` | Cost center under department | master | ✅ | ✅ | ✅ | ❌ | low |
| 13 | `cas_registrations` | BIR CAS accreditation records | setup | ✅ | ✅ | ❌ | ✅ | low |
| 14 | `company_bank_accounts` | Company bank accounts | master | ✅ | ✅ | ✅ | ❌ | low |

---

## MODULE 3: SYSTEM CONTROLS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 15 | `number_series` | Document numbering series per type | setup | ✅ | ✅ | ❌ | ❌ | low |
| 16 | `number_series_atp` | ATP (Authority to Print) records per series | setup | ✅ | ✅ | ❌ | ✅ | low |
| 17 | `atp_usage_logs` | Every document number allocated | audit | ✅ | ❌ | ❌ | ✅ | high |
| 18 | `approval_matrix` | Approval rules per document type | setup | ✅ | ✅ | ✅ | ❌ | low |
| 19 | `approval_matrix_steps` | Sequential/parallel approval steps | setup | ✅ | ✅ | ✅ | ❌ | low |
| 20 | `document_controls` | Status/posting/void/reversal controls per doc type | config | ✅ | ✅ | ❌ | ❌ | low |
| 21 | `validation_rules` | Business validation rules per doc type | config | ✅ | ✅ | ✅ | ❌ | low |
| 22 | `system_parameters` | Global system configuration values | config | ✅ | ✅ | ❌ | ❌ | low |

---

## MODULE 4: ACCOUNTING SETUP

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 23 | `fiscal_years` | Fiscal year definition | setup | ✅ | ✅ | ❌ | ❌ | low |
| 24 | `fiscal_periods` | Monthly/quarterly periods per fiscal year | setup | ✅ | ✅ | ❌ | ❌ | low |
| 25 | `fiscal_locks` | Period lock records — prevents posting | setup | ✅ | ✅ | ❌ | ✅ | low |
| 26 | `chart_of_accounts` | Chart of accounts per company | master | ✅ | ✅ | ✅ | ❌ | medium |
| 27 | `account_types` | Account type definitions (Asset, Liability, etc.) | setup | ✅ | ❌ | ❌ | ✅ | low |
| 28 | `currencies` | Currency master (PHP, USD, etc.) | master | ✅ | ✅ | ✅ | ❌ | low |
| 29 | `exchange_rates` | Exchange rate history | master | ✅ | ✅ | ❌ | ✅ | medium |
| 30 | `opening_balance_entries` | Opening balances per account/branch pre-posting | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 31 | `financial_statement_mappings` | COA → FS line item mapping | setup | ✅ | ✅ | ✅ | ❌ | low |
| 32 | `system_account_config` | Semantic account key → GL account mapping | config | ✅ | ✅ | ✅ | ❌ | low |

---

## MODULE 5: TAX SETUP

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 33 | `bir_form_configurations` | BIR form setup and filing periods | config | ✅ | ✅ | ✅ | ❌ | low |
| 34 | `tax_codes` | General tax code master | master | ✅ | ✅ | ✅ | ❌ | low |
| 35 | `vat_codes` | VAT type codes (VAT, Zero-rated, Exempt) | master | ✅ | ✅ | ✅ | ❌ | low |
| 36 | `ewt_codes` | Expanded withholding tax codes | master | ✅ | ✅ | ✅ | ❌ | low |
| 37 | `atc_codes` | BIR ATC code master (WC000, WI000, etc.) | master | ✅ | ✅ | ✅ | ❌ | low |
| 38 | `tax_calendar` | BIR filing deadlines per form/period | config | ✅ | ✅ | ✅ | ❌ | low |

---

## MODULE 6: MASTER DATA — PARTIES

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 39 | `customers` | Customer master | master | ✅ | ✅ | ✅ | ❌ | medium |
| 40 | `customer_addresses` | Customer address records (billing, shipping) | master | ✅ | ✅ | ✅ | ❌ | medium |
| 41 | `customer_contacts` | Customer contact persons | master | ✅ | ✅ | ✅ | ❌ | medium |
| 42 | `customer_tax_profiles` | Customer TIN, VAT status, 2307 defaults | master | ✅ | ✅ | ✅ | ❌ | medium |
| 43 | `customer_credit_profiles` | Credit limit, terms, current exposure | master | ✅ | ✅ | ✅ | ❌ | medium |
| 44 | `suppliers` | Supplier master | master | ✅ | ✅ | ✅ | ❌ | medium |
| 45 | `supplier_addresses` | Supplier address records | master | ✅ | ✅ | ✅ | ❌ | medium |
| 46 | `supplier_contacts` | Supplier contact persons | master | ✅ | ✅ | ✅ | ❌ | medium |
| 47 | `supplier_tax_profiles` | Supplier TIN, VAT status, EWT defaults | master | ✅ | ✅ | ✅ | ❌ | medium |
| 48 | `supplier_bank_details` | Supplier bank accounts for payment | master | ✅ | ✅ | ✅ | ❌ | medium |
| 49 | `personnel` | Employee lite records (not payroll; for approver names) | master | ✅ | ✅ | ✅ | ❌ | medium |
| 50 | `payment_terms` | Shared payment terms (Net 30, COD, CIA, etc.) | master | ✅ | ✅ | ✅ | ❌ | low |

---

## MODULE 7: MASTER DATA — ITEMS & SERVICES

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 51 | `item_categories` | Hierarchical item categories | master | ✅ | ✅ | ✅ | ❌ | low |
| 52 | `units_of_measure` | UOM master (pc, kg, liter, box) | master | ✅ | ✅ | ✅ | ❌ | low |
| 53 | `uom_conversions` | UOM conversion factors | master | ✅ | ✅ | ✅ | ❌ | low |
| 54 | `items` | Inventory item master | master | ✅ | ✅ | ✅ | ❌ | medium |
| 55 | `item_prices` | Item price list by date/customer group | master | ✅ | ✅ | ✅ | ❌ | medium |
| 56 | `services` | Service master (non-inventory line items) | master | ✅ | ✅ | ✅ | ❌ | medium |

---

## MODULE 8: INVENTORY MASTER

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 57 | `warehouses` | Warehouse / storage location master | master | ✅ | ✅ | ✅ | ❌ | low |
| 58 | `warehouse_stock_settings` | Min/max stock, reorder points per item/warehouse | config | ✅ | ✅ | ✅ | ❌ | medium |
| 59 | `inventory_balances` | Current on-hand quantity per item/warehouse | ledger | ✅ | ❌ | ❌ | ❌ | high |
| 60 | `inventory_cost_layers` | FIFO cost layers per item/warehouse | ledger | ✅ | ❌ | ❌ | ✅ | high |

---

## MODULE 9: SALES — CYCLE

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 61 | `quotations` | Sales quotation header | transaction | ✅ | ✅ | ✅ | ❌ | medium |
| 62 | `quotation_lines` | Quotation line items | transaction | ✅ | ✅ | ✅ | ❌ | high |
| 63 | `sales_orders` | Sales order header | transaction | ✅ | ✅ | ✅ | ❌ | high |
| 64 | `sales_order_lines` | Sales order line items | transaction | ✅ | ✅ | ✅ | ❌ | high |
| 65 | `delivery_receipts` | Delivery receipt header (internal delivery document) | transaction | ✅ | ✅ | ✅ | ❌ | high |
| 66 | `delivery_receipt_lines` | Delivery receipt line items | transaction | ✅ | ✅ | ✅ | ❌ | high |

---

## MODULE 10: SALES — TRANSACTIONS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 67 | `sales_invoices` | Sales invoice header (AR) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 68 | `sales_invoice_lines` | Sales invoice line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 69 | `cash_sales` | Cash sale header — no AR; immediate cash collection | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 70 | `cash_sale_lines` | Cash sale line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 71 | `receipts` | Official receipt header (AR collection against invoice) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 72 | `receipt_lines` | Receipt application lines (which invoices paid) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 73 | `sales_credit_memos` | Credit memo header (sales returns/adjustments) | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 74 | `sales_credit_memo_lines` | Credit memo line items | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 75 | `sales_debit_memos` | Debit memo header (additional charges to customer) | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 76 | `sales_debit_memo_lines` | Debit memo line items | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 77 | `customer_returns` | Customer return header (for inventory reversal) | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 78 | `customer_return_lines` | Customer return line items | transaction | ✅ | ✅ | ❌ | ✅ | medium |

---

## MODULE 11: PURCHASING — TRANSACTIONS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 79 | `purchase_orders` | Purchase order header | transaction | ✅ | ✅ | ✅ | ❌ | high |
| 80 | `purchase_order_lines` | Purchase order line items | transaction | ✅ | ✅ | ✅ | ❌ | high |
| 81 | `receiving_reports` | Goods receipt header (from supplier) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 82 | `receiving_report_lines` | Goods receipt line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 83 | `vendor_bills` | Vendor bill / purchase invoice header (AP) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 84 | `vendor_bill_lines` | Vendor bill line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 85 | `cash_purchases` | Cash purchase header — no AP; immediate cash payment | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 86 | `cash_purchase_lines` | Cash purchase line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 87 | `payment_vouchers` | Payment voucher header (AP payment) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 88 | `payment_voucher_lines` | Payment application (which bills paid) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 89 | `vendor_credits` | Vendor credit note header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 90 | `vendor_credit_lines` | Vendor credit note lines | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 91 | `supplier_debit_memos` | Debit memo to supplier header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 92 | `supplier_debit_memo_lines` | Debit memo to supplier lines | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 93 | `purchase_returns` | Purchase return header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 94 | `purchase_return_lines` | Purchase return line items | transaction | ✅ | ✅ | ❌ | ✅ | medium |

---

## MODULE 12: PETTY CASH

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 95 | `petty_cash_funds` | Petty cash fund setup per branch | master | ✅ | ✅ | ✅ | ❌ | low |
| 96 | `petty_cash_vouchers` | Individual petty cash disbursement header | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 97 | `petty_cash_voucher_lines` | Petty cash disbursement expense lines | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 98 | `petty_cash_replenishments` | Replenishment request and check | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 99 | `petty_cash_count_sheets` | Physical cash count record | transaction | ✅ | ✅ | ❌ | ✅ | low |
| 100 | `petty_cash_count_lines` | Denomination breakdown of cash count | transaction | ✅ | ✅ | ❌ | ✅ | low |

---

## MODULE 13: BANK

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 101 | `bank_fund_transfers` | Fund transfer between bank accounts | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 102 | `inter_branch_transfers` | Fund transfer between branches | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 103 | `bank_adjustments` | Bank debit/credit memos and bank charges | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 104 | `bank_reconciliations` | Bank reconciliation header per account per period | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 105 | `bank_reconciliation_lines` | Individual reconciling items | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 106 | `bank_statement_lines` | Imported bank statement lines for reconciliation | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 107 | `outstanding_checks` | Outstanding check register | ledger | ✅ | ✅ | ❌ | ❌ | medium |
| 108 | `deposits_in_transit` | Deposits not yet cleared in bank | ledger | ✅ | ✅ | ❌ | ❌ | medium |

---

## MODULE 14: INVENTORY — TRANSACTIONS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 109 | `stock_adjustments` | Inventory adjustment header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 110 | `stock_adjustment_lines` | Adjustment line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 111 | `stock_transfers` | Inter-warehouse transfer header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 112 | `stock_transfer_lines` | Transfer line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 113 | `goods_issues` | Internal goods issue header (for production, etc.) | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 114 | `goods_issue_lines` | Goods issue line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 115 | `physical_count_entries` | Physical count session header | transaction | ✅ | ✅ | ❌ | ✅ | low |
| 116 | `physical_count_lines` | Per-item count lines | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 117 | `inventory_movements` | Unified inventory movement ledger (all sources) | ledger | ✅ | ❌ | ❌ | ✅ | high |
| 118 | `inventory_cost_layer_consumption` | FIFO consumption records (links OUT movement to cost layers) | ledger | ✅ | ❌ | ❌ | ✅ | high |

---

## MODULE 15: FIXED ASSETS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 119 | `asset_categories` | Fixed asset category (Land, Building, Equipment) | master | ✅ | ✅ | ✅ | ❌ | low |
| 120 | `depreciation_profiles` | Depreciation method, rate, useful life | master | ✅ | ✅ | ✅ | ❌ | low |
| 121 | `fixed_assets` | Fixed asset register | master | ✅ | ✅ | ✅ | ❌ | medium |
| 122 | `asset_depreciation_schedules` | Pre-computed depreciation schedule per asset | ledger | ✅ | ❌ | ❌ | ✅ | high |
| 123 | `asset_acquisitions` | Asset acquisition transactions | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 124 | `depreciation_runs` | Depreciation run batch header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 125 | `depreciation_run_lines` | Per-asset depreciation computed | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 126 | `asset_disposals` | Asset disposal transactions | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 127 | `asset_transfers` | Asset transfer between branch/department | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 128 | `asset_impairments` | Asset impairment write-down | transaction | ✅ | ✅ | ❌ | ✅ | medium |

---

## MODULE 16: ACCOUNTING

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 129 | `journal_entries` | Journal entry header | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 130 | `journal_lines` | Journal entry debit/credit lines | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 131 | `subsidiary_ledger_entries` | AR/AP/Inventory/FA subsidiary ledger | ledger | ✅ | ❌ | ❌ | ✅ | high |
| 132 | `recurring_journal_templates` | Template for recurring JEs | master | ✅ | ✅ | ✅ | ❌ | low |
| 133 | `recurring_journal_template_lines` | Lines of recurring JE template | master | ✅ | ✅ | ✅ | ❌ | low |
| 134 | `gl_balances` | Running GL balance per account/period/branch | ledger | ✅ | ❌ | ❌ | ❌ | high |
| 135 | `document_relationships` | Links source docs to JEs and downstream docs | bridge | ✅ | ❌ | ❌ | ✅ | high |
| 136 | `posting_rule_sets` | Posting rule header per transaction type | config | ✅ | ✅ | ✅ | ❌ | low |
| 137 | `posting_rule_lines` | DR/CR lines per posting rule set | config | ✅ | ✅ | ✅ | ❌ | low |
| 138 | `posting_batches` | Batch posting session (for bulk posting) | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 139 | `posting_errors` | Errors encountered during posting | audit | ✅ | ❌ | ❌ | ✅ | medium |

---

## MODULE 17: COMPLIANCE — VAT

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 140 | `vat_entries` | VAT entry per invoice/bill/cash sale/cash purchase line | ledger | ✅ | ❌ | ❌ | ✅ | high |
| 141 | `vat_period_summaries` | Aggregated VAT per period | output | ✅ | ❌ | ❌ | ✅ | medium |
| 142 | `vat_return_filings` | VAT return filing records (2550M/2550Q) | transaction | ✅ | ✅ | ❌ | ✅ | low |
| 143 | `slsp_exports` | SLSP export batch records | output | ✅ | ✅ | ❌ | ✅ | low |
| 144 | `relief_exports` | RELIEF export batch records | output | ✅ | ✅ | ❌ | ✅ | low |

---

## MODULE 18: COMPLIANCE — WITHHOLDING TAX

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 145 | `ewt_entries` | EWT entry per vendor bill/payment/cash purchase line | ledger | ✅ | ❌ | ❌ | ✅ | high |
| 146 | `fwt_entries` | Final withholding tax entries (WF-series ATC codes) | ledger | ✅ | ❌ | ❌ | ✅ | medium |
| 147 | `certificates_2307_issued` | 2307 certificates issued to suppliers | output | ✅ | ✅ | ❌ | ✅ | medium |
| 148 | `certificates_2307_received` | 2307 certificates received from customers | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 149 | `certificates_2306` | 2306 final withholding certificates | output | ✅ | ✅ | ❌ | ✅ | low |
| 150 | `ewt_remittances_1601eq` | 1601EQ quarterly remittance filing | transaction | ✅ | ✅ | ❌ | ✅ | low |
| 151 | `qap_exports` | QAP export batch records | output | ✅ | ✅ | ❌ | ✅ | low |
| 152 | `sawt_exports` | SAWT export batch records | output | ✅ | ✅ | ❌ | ✅ | low |
| 153 | `ewt_period_summaries` | Aggregated EWT per ATC per period | output | ✅ | ❌ | ❌ | ✅ | medium |

---

## MODULE 19: COMPLIANCE — INCOME TAX

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 154 | `itr_working_papers` | ITR working paper per period | output | ✅ | ✅ | ❌ | ✅ | low |
| 155 | `book_tax_reconciliations` | Book-to-tax reconciliation per year | output | ✅ | ✅ | ❌ | ✅ | low |
| 156 | `mcit_computations` | Minimum Corporate Income Tax computation | output | ✅ | ✅ | ❌ | ✅ | low |
| 157 | `nolco_schedules` | Net Operating Loss Carryover schedule | master | ✅ | ✅ | ✅ | ❌ | low |
| 158 | `tax_credits_schedules` | Tax credits schedule per year | master | ✅ | ✅ | ✅ | ❌ | low |

---

## MODULE 20: AUDIT & CAS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 159 | `audit_logs` | System-wide audit event log | audit | ✅ | ❌ | ❌ | ✅ | high |
| 160 | `field_change_history` | Before/after field values per field change | audit | ✅ | ❌ | ❌ | ✅ | high |
| 161 | `user_activity_logs` | Login, logout, report access, export, print | audit | ✅ | ❌ | ❌ | ✅ | high |
| 162 | `system_parameter_logs` | System configuration changes | audit | ✅ | ❌ | ❌ | ✅ | low |
| 163 | `document_void_register` | All voided documents register | audit | ✅ | ❌ | ❌ | ✅ | medium |
| 164 | `dat_generation_logs` | CAS DAT file generation history | audit | ✅ | ❌ | ❌ | ✅ | low |
| 165 | `export_history` | All report/data export history | audit | ✅ | ❌ | ❌ | ✅ | medium |
| 166 | `system_alerts` | System-generated alerts (ATP nearing limit, gap detected) | audit | ✅ | ❌ | ❌ | ❌ | low |

---

## MODULE 21: ATTACHMENTS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 167 | `attachments` | Attachment metadata (file in Supabase Storage) | master | ✅ | ✅ | ✅ | ❌ | high |
| 168 | `attachment_versions` | Version history for replaced attachments | audit | ✅ | ❌ | ❌ | ✅ | medium |

> Note: `entity_type` + `entity_id` polymorphic reference on `attachments` replaces the previous `document_attachments` bridge table. The `attachments` table is self-contained.

---

## MODULE 22: WORKFLOW & APPROVALS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 169 | `approval_requests` | Approval request per document | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 170 | `approval_actions` | Approve / reject / return / escalate actions | transaction | ✅ | ✅ | ❌ | ✅ | high |

---

## MODULE 23: IMPORT / EXPORT

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 171 | `import_batches` | Import batch session | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 172 | `import_rows` | Individual rows per import batch | transaction | ✅ | ❌ | ❌ | ✅ | high |
| 173 | `import_validation_errors` | Validation errors per import row | audit | ✅ | ❌ | ❌ | ✅ | high |
| 174 | `import_templates` | Reusable import field mapping templates | master | ✅ | ✅ | ✅ | ❌ | low |
| 175 | `export_jobs` | Async export/report generation jobs | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 176 | `generated_report_files` | Stored generated report files metadata | output | ✅ | ✅ | ❌ | ✅ | medium |

---

## MODULE 24: NOTIFICATIONS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 177 | `notification_templates` | Message templates per event type | setup | ✅ | ✅ | ✅ | ❌ | low |
| 178 | `notifications` | One record per recipient per triggered event | notification | ✅ | ❌ | ❌ | ❌ | high |
| 179 | `notification_delivery_logs` | Delivery attempt log per channel per notification | audit | ✅ | ❌ | ❌ | ✅ | high |

---

## MODULE 25: DOCUMENT TEMPLATES & GENERATED OUTPUT

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 180 | `document_templates` | HTML/PDF template per document type per company | setup | ✅ | ✅ | ✅ | ❌ | low |
| 181 | `generated_documents` | Metadata for generated PDF/printable documents | output | ✅ | ✅ | ❌ | ✅ | high |
| 182 | `generated_document_versions` | Version history for regenerated documents | audit | ✅ | ❌ | ❌ | ✅ | medium |

---

## MODULE 26: BUDGET

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 183 | `budgets` | Budget header per fiscal year per company | master | ✅ | ✅ | ✅ | ❌ | low |
| 184 | `budget_lines` | Budget amount per account per period | master | ✅ | ✅ | ✅ | ❌ | medium |

---

## MODULE 27: PERIOD CLOSE

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 185 | `period_close_checklists` | Period close checklist header per period | transaction | ✅ | ✅ | ❌ | ✅ | low |
| 186 | `period_close_tasks` | Individual close tasks per checklist | transaction | ✅ | ✅ | ❌ | ✅ | low |
| 187 | `subledger_close_certifications` | Subledger agrees to GL certification per period | transaction | ✅ | ✅ | ❌ | ✅ | low |

---

## MODULE 28: PARTY DUPLICATE MANAGEMENT

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 188 | `duplicate_tin_flags` | Flags potential TIN duplicates for review | audit | ✅ | ✅ | ✅ | ❌ | low |
| 189 | `party_merge_logs` | Records completed party merges (duplicate resolution) | audit | ✅ | ❌ | ❌ | ✅ | low |

---

## Summary by Module

| Module | Table Count |
|---|---|
| Security & Identity | 8 |
| Organization Setup | 6 |
| System Controls | 8 |
| Accounting Setup | 10 |
| Tax Setup | 6 |
| Master Data — Parties | 12 |
| Master Data — Items & Services | 6 |
| Inventory Master | 4 |
| Sales Cycle | 6 |
| Sales Transactions | 12 |
| Purchasing Transactions | 16 |
| Petty Cash | 6 |
| Bank | 8 |
| Inventory Transactions | 10 |
| Fixed Assets | 10 |
| Accounting | 11 |
| Compliance — VAT | 5 |
| Compliance — EWT | 9 |
| Compliance — Income Tax | 5 |
| Audit & CAS | 8 |
| Attachments | 2 |
| Workflow & Approvals | 2 |
| Import / Export | 6 |
| Notifications | 3 |
| Document Templates & Output | 3 |
| Budget | 2 |
| Period Close | 3 |
| Party Duplicate Management | 2 |
| **TOTAL** | **~189** |

---

## Open Decisions Remaining

| # | Question | Owner |
|---|---|---|
| OD-09 | `petty_cash_voucher_lines` — should EWT on petty cash be captured here or only on replenishment payment voucher? | CPA Lead |
| OD-10 | `bank_statement_lines` — import from CSV only, or support direct bank API integration in Phase 1? | Business Lead |
| OD-11 | `budget_lines` — track budget at department level or account level only for Phase 1? | CPA Lead |
| OD-12 | `notifications` — in-app only for Phase 1, or include email from launch? | Business Lead |

## Implementation Notes

- `cash_sales` and `cash_purchases` are full first-class transaction types; they have their own posting rule sets and their own number series
- `inventory_cost_layer_consumption` is written by the posting engine when inventory is reduced; it is NOT written by the application layer
- `bank_statement_lines` supports future bank reconciliation auto-matching
- `subsidiary_ledger_entries` was in doc 06 but not in v1 of this inventory — now added to Module 16
- `system_account_config` was in doc 06 but not in v1 inventory — now added to Module 4 (Accounting Setup)
- `posting_rule_sets` replaces the v1 name `posting_rules` for consistency with doc 06
