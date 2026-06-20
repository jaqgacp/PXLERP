# PXL ERP — Complete Table Inventory
**Version:** 1.0  
**Total Tables:** ~175  
**Status:** For CPA and Developer Review

Legend:
- **Type:** master | transaction | ledger | setup | audit | bridge | output | config
- **RLS:** Row-Level Security required
- **Audit:** Field-change audit trail required
- **Soft Delete:** `deleted_at` soft delete allowed
- **Immutable:** Record is immutable after posting
- **Volume:** low (<1K rows) | medium (1K–100K) | high (100K+)

---

## MODULE 1: SECURITY & IDENTITY

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 1 | `profiles` | Extended user profile linked to auth.users | master | ✅ | ✅ | ✅ | ❌ | low |
| 2 | `roles` | System and custom roles | setup | ✅ | ✅ | ✅ | ❌ | low |
| 3 | `permissions` | Granular permission codes | setup | ✅ | ✅ | ❌ | ✅ | low |
| 4 | `role_permissions` | Role → Permission mapping | bridge | ✅ | ✅ | ✅ | ❌ | low |
| 5 | `user_roles` | User → Role mapping | bridge | ✅ | ✅ | ✅ | ❌ | low |
| 6 | `user_company_access` | User access to companies | bridge | ✅ | ✅ | ✅ | ❌ | low |
| 7 | `user_branch_access` | User access to branches | bridge | ✅ | ✅ | ✅ | ❌ | low |
| 8 | `user_department_access` | User access to departments | bridge | ✅ | ✅ | ✅ | ❌ | low |

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
| 17 | `approval_matrix` | Approval rules per document type | setup | ✅ | ✅ | ✅ | ❌ | low |
| 18 | `approval_matrix_steps` | Sequential approval steps per matrix | setup | ✅ | ✅ | ✅ | ❌ | low |
| 19 | `document_controls` | Status/posting/void/reversal controls | config | ✅ | ✅ | ❌ | ❌ | low |
| 20 | `validation_rules` | Business validation rules per doc type | config | ✅ | ✅ | ✅ | ❌ | low |
| 21 | `system_parameters` | Global system configuration values | config | ✅ | ✅ | ❌ | ❌ | low |

---

## MODULE 4: ACCOUNTING SETUP

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 22 | `fiscal_years` | Fiscal year definition | setup | ✅ | ✅ | ❌ | ❌ | low |
| 23 | `fiscal_periods` | Monthly/quarterly periods per fiscal year | setup | ✅ | ✅ | ❌ | ❌ | low |
| 24 | `fiscal_locks` | Period lock records | setup | ✅ | ✅ | ❌ | ✅ | low |
| 25 | `chart_of_accounts` | Chart of accounts per company | master | ✅ | ✅ | ✅ | ❌ | medium |
| 26 | `account_types` | Account type definitions (Asset, Liability, etc.) | setup | ✅ | ❌ | ❌ | ✅ | low |
| 27 | `currencies` | Currency master (PHP, USD, etc.) | master | ✅ | ✅ | ✅ | ❌ | low |
| 28 | `exchange_rates` | Exchange rate history | master | ✅ | ✅ | ❌ | ✅ | medium |
| 29 | `opening_balances` | Opening balances per account | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 30 | `financial_statement_mappings` | COA → FS line item mapping | setup | ✅ | ✅ | ✅ | ❌ | low |
| 31 | `gl_posting_configurations` | Which accounts receive which posting types | config | ✅ | ✅ | ✅ | ❌ | low |

---

## MODULE 5: TAX SETUP

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 32 | `bir_form_configurations` | BIR form setup and filing periods | config | ✅ | ✅ | ✅ | ❌ | low |
| 33 | `tax_codes` | General tax code master | master | ✅ | ✅ | ✅ | ❌ | low |
| 34 | `vat_codes` | VAT type codes (VAT, Zero-rated, Exempt) | master | ✅ | ✅ | ✅ | ❌ | low |
| 35 | `ewt_codes` | Expanded withholding tax codes | master | ✅ | ✅ | ✅ | ❌ | low |
| 36 | `atc_codes` | BIR ATC code master (WC000, WI000, etc.) | master | ✅ | ✅ | ✅ | ❌ | low |
| 37 | `tax_calendar` | Filing deadlines per form/period | config | ✅ | ✅ | ✅ | ❌ | low |

---

## MODULE 6: MASTER DATA — PARTIES

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 38 | `customers` | Customer master | master | ✅ | ✅ | ✅ | ❌ | medium |
| 39 | `customer_addresses` | Customer address records (billing, shipping) | master | ✅ | ✅ | ✅ | ❌ | medium |
| 40 | `customer_contacts` | Customer contact persons | master | ✅ | ✅ | ✅ | ❌ | medium |
| 41 | `customer_tax_profiles` | Customer TIN, VAT status, 2307 defaults | master | ✅ | ✅ | ✅ | ❌ | medium |
| 42 | `customer_credit_profiles` | Credit limit, terms, current exposure | master | ✅ | ✅ | ✅ | ❌ | medium |
| 43 | `suppliers` | Supplier master | master | ✅ | ✅ | ✅ | ❌ | medium |
| 44 | `supplier_addresses` | Supplier address records | master | ✅ | ✅ | ✅ | ❌ | medium |
| 45 | `supplier_contacts` | Supplier contact persons | master | ✅ | ✅ | ✅ | ❌ | medium |
| 46 | `supplier_tax_profiles` | Supplier TIN, VAT status, EWT defaults | master | ✅ | ✅ | ✅ | ❌ | medium |
| 47 | `supplier_bank_details` | Supplier bank accounts for payment | master | ✅ | ✅ | ✅ | ❌ | medium |
| 48 | `personnel` | Employee lite records (not payroll) | master | ✅ | ✅ | ✅ | ❌ | medium |
| 49 | `payment_terms` | Shared payment terms (Net 30, COD, etc.) | master | ✅ | ✅ | ✅ | ❌ | low |

---

## MODULE 7: MASTER DATA — ITEMS & SERVICES

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 50 | `item_categories` | Hierarchical item categories | master | ✅ | ✅ | ✅ | ❌ | low |
| 51 | `units_of_measure` | UOM master (pc, kg, liter, box) | master | ✅ | ✅ | ✅ | ❌ | low |
| 52 | `uom_conversions` | UOM conversion factors | master | ✅ | ✅ | ✅ | ❌ | low |
| 53 | `items` | Inventory item master | master | ✅ | ✅ | ✅ | ❌ | medium |
| 54 | `item_prices` | Item price list by date/customer group | master | ✅ | ✅ | ✅ | ❌ | medium |
| 55 | `services` | Service master (non-inventory) | master | ✅ | ✅ | ✅ | ❌ | medium |

---

## MODULE 8: INVENTORY MASTER

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 56 | `warehouses` | Warehouse / storage location master | master | ✅ | ✅ | ✅ | ❌ | low |
| 57 | `warehouse_stock_settings` | Min/max stock, reorder points per item/warehouse | config | ✅ | ✅ | ✅ | ❌ | medium |
| 58 | `inventory_balances` | Current on-hand quantity per item/warehouse | ledger | ✅ | ❌ | ❌ | ❌ | high |
| 59 | `inventory_cost_layers` | FIFO cost layers per item/warehouse | ledger | ✅ | ❌ | ❌ | ✅ | high |

---

## MODULE 9: SALES — CYCLE

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 60 | `quotations` | Sales quotation header | transaction | ✅ | ✅ | ✅ | ❌ | medium |
| 61 | `quotation_lines` | Quotation line items | transaction | ✅ | ✅ | ✅ | ❌ | high |
| 62 | `sales_orders` | Sales order header | transaction | ✅ | ✅ | ✅ | ❌ | high |
| 63 | `sales_order_lines` | Sales order line items | transaction | ✅ | ✅ | ✅ | ❌ | high |
| 64 | `delivery_receipts` | Delivery receipt header | transaction | ✅ | ✅ | ✅ | ❌ | high |
| 65 | `delivery_receipt_lines` | Delivery receipt line items | transaction | ✅ | ✅ | ✅ | ❌ | high |

---

## MODULE 10: SALES — TRANSACTIONS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 66 | `sales_invoices` | Sales invoice header (AR) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 67 | `sales_invoice_lines` | Sales invoice line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 68 | `cash_sales` | Cash sales header (no AR) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 69 | `cash_sale_lines` | Cash sale line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 70 | `receipts` | Official receipt header (AR collection) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 71 | `receipt_lines` | Receipt application lines (which invoices paid) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 72 | `sales_credit_memos` | Credit memo header (sales returns/adjustments) | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 73 | `sales_credit_memo_lines` | Credit memo line items | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 74 | `sales_debit_memos` | Debit memo header (additional charges to customer) | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 75 | `sales_debit_memo_lines` | Debit memo line items | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 76 | `customer_returns` | Customer return header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 77 | `customer_return_lines` | Customer return line items | transaction | ✅ | ✅ | ❌ | ✅ | medium |

---

## MODULE 11: PURCHASING — TRANSACTIONS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 78 | `purchase_orders` | Purchase order header | transaction | ✅ | ✅ | ✅ | ❌ | high |
| 79 | `purchase_order_lines` | Purchase order line items | transaction | ✅ | ✅ | ✅ | ❌ | high |
| 80 | `receiving_reports` | Goods receipt header | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 81 | `receiving_report_lines` | Goods receipt line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 82 | `vendor_bills` | Vendor bill / purchase invoice header (AP) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 83 | `vendor_bill_lines` | Vendor bill line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 84 | `cash_purchases` | Cash purchase header (no AP) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 85 | `cash_purchase_lines` | Cash purchase line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 86 | `payment_vouchers` | Payment voucher header (AP payment) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 87 | `payment_voucher_lines` | Payment application (which bills paid) | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 88 | `vendor_credits` | Vendor credit note header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 89 | `vendor_credit_lines` | Vendor credit note lines | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 90 | `supplier_debit_memos` | Debit memo to supplier header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 91 | `supplier_debit_memo_lines` | Debit memo to supplier lines | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 92 | `purchase_returns` | Purchase return header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 93 | `purchase_return_lines` | Purchase return line items | transaction | ✅ | ✅ | ❌ | ✅ | medium |

---

## MODULE 12: PETTY CASH

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 94 | `petty_cash_funds` | Petty cash fund setup per branch | master | ✅ | ✅ | ✅ | ❌ | low |
| 95 | `petty_cash_vouchers` | Individual petty cash disbursement | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 96 | `petty_cash_replenishments` | Replenishment request and check | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 97 | `petty_cash_count_sheets` | Physical cash count record | transaction | ✅ | ✅ | ❌ | ✅ | low |
| 98 | `petty_cash_count_lines` | Denomination breakdown of cash count | transaction | ✅ | ✅ | ❌ | ✅ | low |

---

## MODULE 13: BANK

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 99 | `bank_fund_transfers` | Fund transfer between bank accounts | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 100 | `inter_branch_transfers` | Fund transfer between branches | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 101 | `bank_adjustments` | Bank debit/credit memos and charges | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 102 | `bank_reconciliations` | Bank reconciliation header per period | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 103 | `bank_reconciliation_lines` | Individual reconciling items | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 104 | `outstanding_checks` | Outstanding check register | ledger | ✅ | ✅ | ❌ | ❌ | medium |
| 105 | `deposits_in_transit` | Deposits not yet cleared in bank | ledger | ✅ | ✅ | ❌ | ❌ | medium |

---

## MODULE 14: INVENTORY — TRANSACTIONS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 106 | `stock_adjustments` | Inventory adjustment header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 107 | `stock_adjustment_lines` | Adjustment line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 108 | `stock_transfers` | Inter-warehouse transfer header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 109 | `stock_transfer_lines` | Transfer line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 110 | `goods_issues` | Internal goods issue header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 111 | `goods_issue_lines` | Goods issue line items | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 112 | `physical_count_entries` | Physical count session header | transaction | ✅ | ✅ | ❌ | ✅ | low |
| 113 | `physical_count_lines` | Per-item count lines | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 114 | `inventory_movements` | Unified inventory movement ledger (all sources) | ledger | ✅ | ❌ | ❌ | ✅ | high |

---

## MODULE 15: FIXED ASSETS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 115 | `asset_categories` | Fixed asset category (Land, Building, Equipment) | master | ✅ | ✅ | ✅ | ❌ | low |
| 116 | `depreciation_profiles` | Depreciation method, rate, useful life | master | ✅ | ✅ | ✅ | ❌ | low |
| 117 | `fixed_assets` | Fixed asset register | master | ✅ | ✅ | ✅ | ❌ | medium |
| 118 | `asset_acquisitions` | Asset acquisition transactions | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 119 | `depreciation_runs` | Depreciation run batch header | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 120 | `depreciation_run_lines` | Per-asset depreciation computed | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 121 | `asset_disposals` | Asset disposal transactions | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 122 | `asset_transfers` | Asset transfer between branch/department | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 123 | `asset_impairments` | Asset impairment write-down | transaction | ✅ | ✅ | ❌ | ✅ | medium |

---

## MODULE 16: ACCOUNTING

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 124 | `journal_entries` | Journal entry header | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 125 | `journal_lines` | Journal entry debit/credit lines | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 126 | `recurring_journal_templates` | Template for recurring JEs | master | ✅ | ✅ | ✅ | ❌ | low |
| 127 | `recurring_journal_template_lines` | Lines of recurring JE template | master | ✅ | ✅ | ✅ | ❌ | low |
| 128 | `gl_balances` | Running GL balance per account/period | ledger | ✅ | ❌ | ❌ | ❌ | high |
| 129 | `document_relationships` | Links source docs to JEs and downstream docs | bridge | ✅ | ❌ | ❌ | ✅ | high |
| 130 | `posting_rules` | Posting rule header per doc type | config | ✅ | ✅ | ✅ | ❌ | low |
| 131 | `posting_rule_lines` | DR/CR lines per posting rule | config | ✅ | ✅ | ✅ | ❌ | low |
| 132 | `posting_batches` | Batch posting session | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 133 | `posting_errors` | Errors encountered during posting | audit | ✅ | ❌ | ❌ | ✅ | medium |

---

## MODULE 17: COMPLIANCE — VAT

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 134 | `vat_entries` | VAT entry per invoice/bill line | ledger | ✅ | ❌ | ❌ | ✅ | high |
| 135 | `vat_period_summaries` | Aggregated VAT per period | output | ✅ | ❌ | ❌ | ✅ | medium |
| 136 | `vat_return_filings` | VAT return filing records (2550M/2550Q) | transaction | ✅ | ✅ | ❌ | ✅ | low |
| 137 | `slsp_exports` | SLSP export batch records | output | ✅ | ✅ | ❌ | ✅ | low |
| 138 | `relief_exports` | RELIEF export batch records | output | ✅ | ✅ | ❌ | ✅ | low |

---

## MODULE 18: COMPLIANCE — WITHHOLDING TAX

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 139 | `ewt_entries` | EWT entry per vendor bill/payment line | ledger | ✅ | ❌ | ❌ | ✅ | high |
| 140 | `fwt_entries` | Final withholding tax entries | ledger | ✅ | ❌ | ❌ | ✅ | medium |
| 141 | `certificates_2307_issued` | 2307 certificates issued to suppliers | output | ✅ | ✅ | ❌ | ✅ | medium |
| 142 | `certificates_2307_received` | 2307 certificates received from customers | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 143 | `certificates_2306` | 2306 final withholding certificates | output | ✅ | ✅ | ❌ | ✅ | low |
| 144 | `ewt_remittances_1601eq` | 1601EQ quarterly remittance filing | transaction | ✅ | ✅ | ❌ | ✅ | low |
| 145 | `qap_exports` | QAP export batch records | output | ✅ | ✅ | ❌ | ✅ | low |
| 146 | `sawt_exports` | SAWT export batch records | output | ✅ | ✅ | ❌ | ✅ | low |
| 147 | `ewt_period_summaries` | Aggregated EWT per ATC per period | output | ✅ | ❌ | ❌ | ✅ | medium |

---

## MODULE 19: COMPLIANCE — INCOME TAX

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 148 | `itr_working_papers` | ITR working paper per period | output | ✅ | ✅ | ❌ | ✅ | low |
| 149 | `book_tax_reconciliations` | Book-to-tax reconciliation per year | output | ✅ | ✅ | ❌ | ✅ | low |
| 150 | `mcit_computations` | MCIT computation records | output | ✅ | ✅ | ❌ | ✅ | low |
| 151 | `nolco_schedules` | Net Operating Loss Carryover schedule | master | ✅ | ✅ | ✅ | ❌ | low |
| 152 | `tax_credits_schedules` | Tax credits schedule per year | master | ✅ | ✅ | ✅ | ❌ | low |

---

## MODULE 20: AUDIT & CAS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 153 | `audit_logs` | System-wide audit event log | audit | ✅ | ❌ | ❌ | ✅ | high |
| 154 | `field_change_history` | Before/after field values | audit | ✅ | ❌ | ❌ | ✅ | high |
| 155 | `user_activity_logs` | Login, logout, report access, export | audit | ✅ | ❌ | ❌ | ✅ | high |
| 156 | `system_parameter_logs` | System configuration changes | audit | ✅ | ❌ | ❌ | ✅ | low |
| 157 | `document_void_register` | All voided documents register | audit | ✅ | ❌ | ❌ | ✅ | medium |
| 158 | `atp_usage_logs` | ATP number usage tracking | audit | ✅ | ❌ | ❌ | ✅ | high |
| 159 | `dat_generation_logs` | DAT file generation history | audit | ✅ | ❌ | ❌ | ✅ | low |
| 160 | `export_history` | All report/data exports | audit | ✅ | ❌ | ❌ | ✅ | medium |

---

## MODULE 21: ATTACHMENTS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 161 | `attachments` | Attachment metadata (file in Supabase Storage) | master | ✅ | ✅ | ✅ | ❌ | high |
| 162 | `document_attachments` | Links attachments to any source document | bridge | ✅ | ✅ | ✅ | ❌ | high |

---

## MODULE 22: WORKFLOW & APPROVALS

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 163 | `approval_requests` | Approval request per document | transaction | ✅ | ✅ | ❌ | ✅ | high |
| 164 | `approval_actions` | Approve / reject / return actions | transaction | ✅ | ✅ | ❌ | ✅ | high |

---

## MODULE 23: IMPORT / EXPORT

| # | Table Name | Purpose | Type | RLS | Audit | Soft Delete | Immutable | Volume |
|---|---|---|---|---|---|---|---|---|
| 165 | `import_batches` | Import batch session | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 166 | `import_rows` | Individual rows per import batch | transaction | ✅ | ❌ | ❌ | ✅ | high |
| 167 | `import_validation_errors` | Validation errors per import row | audit | ✅ | ❌ | ❌ | ✅ | high |
| 168 | `import_templates` | Reusable import field mapping templates | master | ✅ | ✅ | ✅ | ❌ | low |
| 169 | `export_batches` | Export batch session | transaction | ✅ | ✅ | ❌ | ✅ | medium |
| 170 | `generated_report_files` | Stored generated report files | output | ✅ | ✅ | ❌ | ✅ | medium |

---

## Summary by Module

| Module | Table Count |
|---|---|
| Security & Identity | 8 |
| Organization Setup | 6 |
| System Controls | 7 |
| Accounting Setup | 10 |
| Tax Setup | 6 |
| Master Data — Parties | 12 |
| Master Data — Items & Services | 6 |
| Inventory Master | 4 |
| Sales Cycle | 6 |
| Sales Transactions | 12 |
| Purchasing Transactions | 16 |
| Petty Cash | 5 |
| Bank | 7 |
| Inventory Transactions | 9 |
| Fixed Assets | 9 |
| Accounting | 9 |
| Compliance — VAT | 5 |
| Compliance — EWT | 9 |
| Compliance — Income Tax | 5 |
| Audit & CAS | 8 |
| Attachments | 2 |
| Workflow & Approvals | 2 |
| Import / Export | 6 |
| **TOTAL** | **~170** |
