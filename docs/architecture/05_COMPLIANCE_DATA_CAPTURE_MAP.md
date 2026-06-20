# PXL ERP — Compliance Data Capture Map
**Version:** 1.0 — Blueprint Locked  
**Status:** For CPA and Developer Review

---

## 1. Overview

This document maps every Philippine BIR compliance output to the specific database fields required to generate it. Each compliance form or report lists: the source tables, required fields, computation logic, and BIR filing reference.

---

## 2. VAT — BIR Form 2550M / 2550Q

### Output: Monthly/Quarterly VAT Return

| BIR Field | Source Table | Source Column | Notes |
|---|---|---|---|
| TIN of taxpayer | `companies` | `bir_tin` | Format: 999-999-999-999 |
| Registered name | `companies` | `registered_name` | As per BIR COR |
| Taxable period | `fiscal_periods` | `period_start`, `period_end` | |
| Sales to VAT-reg customers | `vat_entries` | `base_amount WHERE vat_type='OUTPUT' AND customer_vat_reg=true` | |
| Sales to non-VAT customers | `vat_entries` | `base_amount WHERE vat_type='OUTPUT' AND customer_vat_reg=false` | |
| Zero-rated sales | `vat_entries` | `base_amount WHERE vat_type='ZERO_RATED'` | |
| VAT-exempt sales | `vat_entries` | `base_amount WHERE vat_type='EXEMPT'` | |
| Output VAT | `vat_entries` | `vat_amount WHERE vat_type='OUTPUT'` | Sum |
| Input VAT from purchases | `vat_entries` | `vat_amount WHERE vat_type='INPUT'` | Sum |
| Input VAT carried over | `vat_summary_period` | `input_vat_carryover` | From prior period |
| VAT payable / creditable | computed | OUTPUT VAT - INPUT VAT | Per BIR formula |

### Required Fields on Source Documents

**`sales_invoices`**
- `customer_id` → join to `customers.bir_tin`, `customers.is_vat_registered`
- `invoice_date` → determines period
- `is_vat_inclusive` → affects base amount computation

**`sales_invoice_lines`**
- `vat_type` — ENUM: OUTPUT | ZERO_RATED | EXEMPT | GOVERNMENT
- `base_amount` — amount before VAT
- `vat_amount` — 12% of base_amount (or 0 for zero/exempt)
- `account_id` → revenue account

**`vendor_bill_lines`**
- `vat_type` — ENUM: INPUT | INPUT_DEFERRED | CAPITAL_GOODS | SERVICES
- `base_amount`
- `vat_amount`
- `supplier_id` → join to `suppliers.bir_tin`, `suppliers.is_vat_registered`

---

## 3. SLSP — Summary List of Sales/Purchases

### Output: SLSP (Sales) — Quarterly

| SLSP Column | Source Table | Source Column |
|---|---|---|
| Buyer TIN | `customers` | `bir_tin` |
| Buyer name | `customers` | `registered_name` |
| Invoice number | `sales_invoices` | `document_number` |
| Invoice date | `sales_invoices` | `invoice_date` |
| Taxable amount | `sales_invoice_lines` | `SUM(base_amount) WHERE vat_type='OUTPUT'` |
| VAT amount | `sales_invoice_lines` | `SUM(vat_amount)` |
| Exempt amount | `sales_invoice_lines` | `SUM(base_amount) WHERE vat_type='EXEMPT'` |
| Zero-rated amount | `sales_invoice_lines` | `SUM(base_amount) WHERE vat_type='ZERO_RATED'` |
| Total amount | computed | taxable + vat + exempt + zero-rated |

### Output: SLSP (Purchases) / RELIEF — Quarterly

| RELIEF Column | Source Table | Source Column |
|---|---|---|
| Seller TIN | `suppliers` | `bir_tin` |
| Seller name | `suppliers` | `registered_name` |
| Invoice number | `vendor_bills` | `document_number` |
| Invoice date | `vendor_bills` | `bill_date` |
| Taxable amount | `vendor_bill_lines` | `SUM(base_amount) WHERE vat_type LIKE 'INPUT%'` |
| Input VAT amount | `vendor_bill_lines` | `SUM(vat_amount)` |
| Classification | `vendor_bill_lines` | `vat_type` (GOODS/SERVICES/CAPITAL) |

### Conditions
- Only POSTED documents included
- Minimum transaction threshold: per BIR rules (currently ≥ PHP 1 for all; special rules for buyer aggregation below PHP threshold)
- `customers.bir_tin` and `suppliers.bir_tin` must be non-null; validation enforced at document posting

---

## 4. EWT — BIR Form 1601EQ (Quarterly EWT Return)

### Output: 1601EQ

| 1601EQ Field | Source Table | Source Column |
|---|---|---|
| TIN of withholding agent | `companies` | `bir_tin` |
| Quarter covered | `fiscal_periods` | `quarter_number`, `fiscal_year` |
| ATC code | `ewt_entries` | `atc_code` |
| Tax base | `ewt_entries` | `SUM(tax_base_amount) GROUP BY atc_code` |
| Tax rate | `ewt_atc_rates` | `rate` |
| Tax withheld | `ewt_entries` | `SUM(ewt_amount) GROUP BY atc_code` |
| Penalties | `ewt_remittance` | `penalty_amount` (if late) |
| Total tax due | computed | |

### Required Fields on `ewt_entries`
- `atc_code` — e.g., WC010, WC158, WI010
- `tax_base_amount` — gross income subject to withholding
- `ewt_rate` — rate applied (from ATC master)
- `ewt_amount` — tax_base_amount × ewt_rate
- `payee_id` → `suppliers.id`
- `payee_tin` — denormalized from supplier at time of transaction (snapshot)
- `transaction_date`
- `source_document_type` — 'vendor_bill' | 'payment_voucher' | 'petty_cash_voucher'
- `source_document_id`
- `period_id` → `fiscal_periods.id`

---

## 5. BIR Form 2307 — Certificate of Creditable Tax Withheld at Source

### Output: 2307 Issued (to supplier)

| 2307 Field | Source Table | Source Column |
|---|---|---|
| Withholding agent TIN | `companies` | `bir_tin` |
| Withholding agent name | `companies` | `registered_name` |
| Payee TIN | `suppliers` | `bir_tin` |
| Payee name | `suppliers` | `registered_name` |
| Payee address | `suppliers` | `address_line1`, `city`, `province` |
| Quarter | `certificates_2307_issued` | `quarter`, `year` |
| ATC code | `certificates_2307_issued` | `atc_code` |
| Income payment per month | `ewt_entries` | `SUM(tax_base_amount) GROUP BY month` |
| Tax withheld per month | `ewt_entries` | `SUM(ewt_amount) GROUP BY month` |
| Total income payment | computed | |
| Total tax withheld | computed | |

### `certificates_2307_issued` Table
- One record per (supplier, ATC, quarter, year)
- Computed from `ewt_entries` at quarter-close
- `certificate_number` — sequential per company
- `issued_date`
- `is_issued` boolean
- `issued_to_supplier_at` timestamptz

---

## 6. BIR Form 2307 Received (from customers)

### Output: Input to Annual Income Tax Return (Tax Credits)

| Field | Source Table | Source Column |
|---|---|---|
| Customer TIN | `customers` | `bir_tin` |
| Customer name | `customers` | `registered_name` |
| Quarter | `certificates_2307_received` | `quarter`, `year` |
| ATC code | `certificates_2307_received` | `atc_code` |
| Income payment | `certificates_2307_received` | `income_payment_amount` |
| Tax withheld | `certificates_2307_received` | `tax_withheld_amount` |
| Date received | `certificates_2307_received` | `received_date` |
| Applied to receipt | `certificates_2307_received` | `receipt_id` |

### SAWT (Summary Alphalist of Withholding Tax)
Derived from `certificates_2307_received` per quarter:
- Group by (customer_tin, atc_code)
- Sum income_payment_amount, tax_withheld_amount

---

## 7. BIR Form 2306 — Certificate of Final Tax Withheld

| Field | Source Table | Notes |
|---|---|---|
| Payee TIN | `suppliers` | `bir_tin` |
| Payee name | `suppliers` | `registered_name` |
| ATC code | `ewt_entries` | Final tax ATC codes (WF-series) |
| Income payment | `ewt_entries` | `tax_base_amount` |
| Final tax withheld | `ewt_entries` | `ewt_amount` |

- Separate certificate from 2307; generated from `ewt_entries` where ATC is a FINAL tax code
- Stored in `certificates_2306_issued` (parallel to `certificates_2307_issued`)

---

## 8. QAP — Quarterly Alphalist of Payees

### Output: DAT file for BIR submission with 1601EQ

| QAP Column | Source | Notes |
|---|---|---|
| Payee sequence no. | computed | Sequential per QAP |
| Payee TIN | `suppliers.bir_tin` | |
| Payee name | `suppliers.registered_name` | |
| ATC code | `ewt_entries.atc_code` | |
| Tax base (M1, M2, M3) | `ewt_entries` | Grouped by month within quarter |
| EWT amount (M1, M2, M3) | `ewt_entries` | |
| Total tax base | computed | |
| Total EWT | computed | |

- Grouped by: (supplier_tin, atc_code)
- Must include ALL suppliers withheld from in the quarter, even if certificate not yet issued

---

## 9. BIR Books of Accounts

### General Journal
Source: `journal_entries` + `journal_lines`

| BIR Field | Column |
|---|---|
| Date | `journal_entries.entry_date` |
| Reference | `journal_entries.document_number` |
| Description | `journal_entries.description` |
| Account | `chart_of_accounts.account_code`, `account_name` |
| Debit | `journal_lines.debit_amount` |
| Credit | `journal_lines.credit_amount` |

### General Ledger
Source: `journal_lines` filtered per account, sorted by date

| BIR Field | Column |
|---|---|
| Date | `journal_entries.entry_date` |
| Reference | `journal_entries.document_number` |
| Debit | `journal_lines.debit_amount` |
| Credit | `journal_lines.credit_amount` |
| Balance | computed running total |

### Cash Receipts Book
Source: `journal_lines` where account = cash/bank, debit side, joined to `receipts`

### Cash Disbursements Book
Source: `journal_lines` where account = cash/bank, credit side, joined to `payment_vouchers`

### Sales Book
Source: `sales_invoices` + `sales_invoice_lines` + `vat_entries`

### Purchases Book
Source: `vendor_bills` + `vendor_bill_lines` + `vat_entries`

---

## 10. BIR CAS (Computerized Accounting System) Audit Requirements

### DAT File Generation

| DAT File | Source | Tables Involved |
|---|---|---|
| GL DAT | General Ledger | `journal_entries`, `journal_lines`, `chart_of_accounts` |
| SL DAT | Subsidiary Ledger | `subsidiary_ledger_entries`, `customers`, `suppliers` |
| SLS DAT | Sales Summary | `sales_invoices`, `vat_entries` |
| PUR DAT | Purchases Summary | `vendor_bills`, `vat_entries` |
| INV DAT | Inventory Movement | `inventory_movements`, `inventory_cost_layers` |

### CAS Audit Trail Requirements

| Requirement | Implementation |
|---|---|
| Sequential numbering, no gaps | `number_series` with gap detection trigger |
| No modification after posting | RLS + application-level immutability check |
| Complete audit trail | `audit_logs` + `field_change_history` |
| ATP tracking | `number_series_atp` + `atp_usage_logs` |
| DAT file log | `dat_file_generation_logs` records every export |
| User action log | `user_activity_logs` records every login, export, print |

### `dat_file_generation_logs` Table
- `id`, `company_id`
- `dat_type` — GL | SL | SLS | PUR | INV
- `period_from`, `period_to`
- `generated_by` → `auth.users`
- `generated_at` timestamptz
- `file_hash` — SHA256 of generated file for integrity
- `record_count`
- `storage_path` — Supabase Storage reference

---

## 11. ATP (Authority to Print) Tracking

| Field | Table | Purpose |
|---|---|---|
| ATP number | `number_series_atp.atp_reference_no` | BIR-issued ATP per series |
| Series from | `number_series_atp.series_start` | First allowed number |
| Series to | `number_series_atp.series_end` | Last allowed number |
| Expiry date | `number_series_atp.valid_until` | ATP validity |
| Usage log | `atp_usage_logs` | Every document number assigned |

- When `number_series.current_number` approaches `max_number`, system generates alert
- ATP log is immutable — no soft delete

---

## 12. Compliance Readiness Checklist

| Form / Report | Tables Driving It | Key Fields |
|---|---|---|
| 2550M / 2550Q | `vat_entries`, `vat_summary_period` | vat_type, base_amount, vat_amount, period_id |
| SLSP (Sales) | `sales_invoices`, `customers`, `vat_entries` | customer TIN, invoice_date, amounts |
| SLSP (Purchases) / RELIEF | `vendor_bills`, `suppliers`, `vat_entries` | supplier TIN, bill_date, amounts |
| 1601EQ | `ewt_entries`, `ewt_remittance` | atc_code, ewt_amount, period |
| 2307 Issued | `certificates_2307_issued`, `ewt_entries` | supplier TIN, quarterly totals |
| 2307 Received | `certificates_2307_received` | customer TIN, quarterly totals |
| 2306 | `certificates_2306_issued`, `ewt_entries` (final) | supplier TIN, final tax |
| QAP | `ewt_entries`, `suppliers` | Per-payee per-ATC monthly breakdown |
| SAWT | `certificates_2307_received` | Customer alphalist |
| BIR Books | `journal_entries`, `journal_lines` | All posted entries |
| CAS DAT Files | All transaction tables | Full data export |
| 1604E | `ewt_entries` annual | Annual alphalist of payees |
