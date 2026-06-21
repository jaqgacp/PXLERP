# PXL ERP — Compliance Data Capture Map
**Version:** 3.3 — Brutal Audit Fix Pass
**Status:** v3.3 — Brutal Audit Fix Pass Applied. Freeze pending Section 47 sign-off.

---

## v3 Architecture Review Changes Applied

- **`companies.name`**: All references to `companies.registered_name` corrected to `companies.name`. The canonical column in `companies` is `name` (see doc 03 § 1).
- **Government sales routing**: `vat_classification = 'GOVERNMENT'` on `vat_entries` is DERIVED at posting from `customers.party_special_class = 'government'`. It is NOT stored on `sales_invoice_lines` or `cash_sale_lines`. Transaction lines only store ('vatable','zero_rated','exempt').
- **Party VAT registration**: `customer_is_vat_registered` is NOT a stored column. At posting, the engine reads `customers.vat_registration_status` ('vat'|'non_vat') to populate `vat_entries` records. Remove `customer_is_vat_registered` references from compliance map — use `vat_entries.vat_classification` filter directly.
- **Income tax table rename**: `itr_working_papers` → `itr_computation_runs`; `mcit_computations` REMOVED; `nolco_schedules` REMOVED. ITR compliance chain updated in Section 12c.
- **vat_classification casing**: All values lowercase in database — 'vatable', 'zero_rated', 'exempt', 'government'. Prior versions used uppercase. Corrected throughout.

## v3 Cross-Document Consistency

- `vat_entries.vat_classification` CHECK IN ('vatable','zero_rated','exempt','government') ✓
- `sales_invoice_lines.vat_classification` CHECK IN ('vatable','zero_rated','exempt') — 'government' NOT on lines ✓
- `customers.vat_registration_status` CHECK IN ('vat','non_vat') — party_special_class is separate ✓
- `companies.name` (not `registered_name`) ✓

---

## Changes Applied (v2 → v2.1) — Principle Alignment

- Added Section 12a: Percentage Tax / 2551Q Data Capture Map (Principle 20)
- Added Section 12b: Final Withholding Tax / 1601FQ Data Capture Map (Principle 20)
- Added Section 12c: Income Tax Return (ITR) Data Capture Map (split by income_tax_regime per Principle 3)
- Updated `compliance_report_runs.report_type` to include '2551Q' and '1601FQ'
- Updated Compliance Readiness Checklist (Section 12) with 2551Q, 1601FQ, ITR rows

## Changes Applied (v1 → v2)

- Fixed `bir_tin` → `tin` on all master tables (`companies`, `customers`, `suppliers`)
- Fixed `document_number` → `document_no` on all transaction headers
- Fixed `invoice_date` / `bill_date` → `document_date` on all transaction headers
- Fixed `base_amount` → `net_amount` in `vat_entries`
- Fixed `tax_base_amount` → `ewt_base_amount` in `ewt_entries`
- Fixed `vat_type` → split into `vat_direction` (OUTPUT/INPUT) + `vat_classification` (VATABLE/ZERO_RATED/EXEMPT/GOVERNMENT)
- Fixed `vat_summary_period` → `vat_period_summaries`
- Fixed `ewt_remittance` → `ewt_remittances_1601eq`
- Added Cash Sales and Cash Purchases to VAT capture map (Section 2, 3)
- Added Cash Sales Book and Cash Purchases Book (Section 9)
- Added compliance output generation tables: `compliance_report_runs`, `compliance_export_files` (Section 13)
- Aligned `ewt_entries` field names with doc 03 column specifications
- Added `party_tin` snapshot clarification throughout
- Updated `certificates_2307_issued` table to include `is_issued`, `issued_at`, `generated_document_id`
- Updated QAP to reference `ewt_remittances_1601eq`

---

## Open Decisions — Resolved (v3.2)

| OD # | Question | Decision | Resolved |
|---|---|---|---|
| OD-11 | Should `slsp_records` and `relief_exports` be materialized tables or computed views? | **Computed at export time** via Edge Function. `slsp_records` and `relief_exports` store per-record data for the export batch; no separate summary tables. Ghost names `slsp_entries`, `slsp_summary`, `relief_entries`, `relief_summary` removed from all docs. | v3.2 ✅ |
| OD-12 | Should `compliance_report_runs` track BIR submission status (submitted, accepted, rejected)? | **Phase 2 only** — Phase 1 is generation only. No blocking impact on freeze. | v3.2 ✅ |
| **OD-13** | **Does posting engine write `vat_entries` and `ewt_entries`, or does the document save step?** | **POSTING ENGINE writes all immutable compliance entries.** Document save step computes and stores draft preview fields on the source document only (e.g., `total_vat_amount`, `total_ewt_amount`). The posting engine (Doc 06 Section 7, Step 11) writes final, immutable `vat_entries`, `ewt_entries`, `fwt_entries`, `percentage_tax_entries` within the same transaction as journal_entries. Draft/preview entries are deleted before INSERT on first post. Voids and reversals write reversal entries (negative amounts) — never silent UPDATE or DELETE. | v3.2 ✅ |

---

## Implementation Notes

- All `{party}_tin` snapshot columns (`customer_tin`, `supplier_tin`, `payee_tin`) on compliance tables must be populated at document posting time. They must NOT be updated if the master TIN changes later — they are point-in-time snapshots.
- Cash Sales contribute to Output VAT and SLSP. They are included in all VAT-related compliance outputs identically to Sales Invoices.
- Cash Purchases contribute to Input VAT and RELIEF. They are included in all VAT-related compliance outputs identically to Vendor Bills.
- EWT on Cash Purchases is captured at transaction time (`cash_purchase_lines` → `ewt_entries`), not at payment time.
- All compliance forms reference `companies.tin` (not `bir_tin`) per v2 naming convention.

---

## 1. Overview

This document maps every Philippine BIR compliance output to the specific database fields required to generate it. Each compliance form or report lists: the source tables, required fields, computation logic, and BIR filing reference.

---

## 2. VAT — BIR Form 2550M / 2550Q

### Output: Monthly/Quarterly VAT Return

| BIR Field | Source Table | Source Column | Notes |
|---|---|---|---|
| TIN of taxpayer | `companies` | `tin` | Format: 999-999-999-999 |
| Registered name | `companies` | `name` | As per BIR COR |
| Taxable period | `fiscal_periods` | `start_date`, `end_date` | |
| Sales to VAT-reg customers | `vat_entries` | `net_amount WHERE vat_direction='output' AND vat_classification='vatable'` + join `customers.vat_registration_status='vat'` | |
| Sales to non-VAT customers | `vat_entries` | `net_amount WHERE vat_direction='output' AND vat_classification='vatable'` + join `customers.vat_registration_status='non_vat'` | |
| Zero-rated sales | `vat_entries` | `net_amount WHERE vat_direction='output' AND vat_classification='zero_rated'` | |
| VAT-exempt sales | `vat_entries` | `net_amount WHERE vat_direction='output' AND vat_classification='exempt'` | |
| Government sales | `vat_entries` | `net_amount WHERE vat_direction='output' AND vat_classification='government'` | Derived at posting from customers.party_special_class='government' |
| Output VAT | `vat_entries` | `SUM(vat_amount) WHERE vat_direction='output'` | |
| Input VAT from purchases | `vat_entries` | `SUM(vat_amount) WHERE vat_direction='input'` | |
| Input VAT carried over | `vat_period_summaries` | `input_vat_carryover` | From prior period |
| VAT payable / creditable | computed | OUTPUT VAT - INPUT VAT | Per BIR formula |

### Required Fields on Source Documents

**`sales_invoices`**
- `customer_id` → join to `customers.tin`, `customers.vat_registration_status` CHECK IN ('vat','non_vat') — **[E-3 fix: customer_tax_profiles.is_vat_registered was removed; use customers.vat_registration_status directly]**
- `document_date` → determines period
- `is_vat_inclusive` → affects net amount computation

**`sales_invoice_lines`**
- `vat_direction` — 'output'
- `vat_classification` — 'vatable' | 'zero_rated' | 'exempt' (stored on lines; 'government' only in vat_entries, derived at posting from party_special_class)
- `net_amount` — amount before VAT
- `vat_amount` — 12% of net_amount (or 0 for zero/exempt)
- `account_id` → revenue account

**`cash_sales`** (contributes to Output VAT identically to sales_invoices)
- `customer_id` → optional; may be walk-in
- `document_date` → determines period
- `customer_tin` → snapshot at transaction time (required for SLSP if transaction above threshold)

**`cash_sale_lines`**
- `vat_direction` — 'output'
- `vat_classification` — 'vatable' | 'zero_rated' | 'exempt' (stored on lines; 'government' only in vat_entries, derived at posting from party_special_class)
- `net_amount`, `vat_amount`

**`vendor_bill_lines`**
- `vat_direction` — 'input'
- `vat_classification` — 'vatable' | 'capital_goods' | 'services'
- `net_amount`, `vat_amount`
- `supplier_id` → join to `suppliers.tin`, `suppliers.vat_registration_status` CHECK IN ('vat','non_vat') — **[E-3 fix: supplier_tax_profiles.is_vat_registered removed]**

**`cash_purchase_lines`** (contributes to Input VAT identically to vendor_bill_lines)
- `vat_direction` — 'input'
- `vat_classification` — 'vatable' | 'capital_goods' | 'services'
- `net_amount`, `vat_amount`
- `supplier_tin` → snapshot at transaction time

---

## 3. SLSP — Summary List of Sales/Purchases

### Output: SLSP (Sales) — Quarterly

| SLSP Column | Source Table | Source Column |
|---|---|---|
| Buyer TIN | `customers` | `tin` (joined) or `customer_tin` (snapshot on `vat_entries`) |
| Buyer name | `customers` | `name` |
| Invoice/receipt number | `sales_invoices` / `cash_sales` | `document_no` |
| Invoice/receipt date | `sales_invoices` / `cash_sales` | `document_date` |
| Taxable amount | `vat_entries` | `SUM(net_amount) WHERE vat_classification='vatable'` |
| VAT amount | `vat_entries` | `SUM(vat_amount)` |
| Exempt amount | `vat_entries` | `SUM(net_amount) WHERE vat_classification='exempt'` |
| Zero-rated amount | `vat_entries` | `SUM(net_amount) WHERE vat_classification='zero_rated'` |
| Total amount | computed | taxable + vat + exempt + zero-rated |

Source documents: `sales_invoices` AND `cash_sales` (both contribute to SLSP)

### Output: SLSP (Purchases) / RELIEF — Quarterly

| RELIEF Column | Source Table | Source Column |
|---|---|---|
| Seller TIN | `suppliers` | `tin` (joined) or `supplier_tin` (snapshot on `vat_entries`) |
| Seller name | `suppliers` | `name` |
| Invoice number | `vendor_bills` / `cash_purchases` | `document_no` |
| Invoice date | `vendor_bills` / `cash_purchases` | `document_date` |
| Taxable amount | `vat_entries` | `SUM(net_amount) WHERE vat_direction='input' AND vat_classification='vatable'` |
| Input VAT amount | `vat_entries` | `SUM(vat_amount)` |
| Classification | `vat_entries` | `vat_classification` ('vatable'/'capital_goods'/'services') |

Source documents: `vendor_bills` AND `cash_purchases` (both contribute to RELIEF)

### Conditions
- Only POSTED documents included
- `customers.tin` and `suppliers.tin` must be non-null on SLSP-reportable transactions; validation enforced at posting
- `customer_tin` and `supplier_tin` are denormalized snapshots on `vat_entries` — used for SLSP export without joining master tables (TIN may change on master after transaction)

---

## 4. EWT — BIR Form 1601EQ (Quarterly EWT Return)

### Output: 1601EQ

| 1601EQ Field | Source Table | Source Column |
|---|---|---|
| TIN of withholding agent | `companies` | `tin` |
| Quarter covered | `fiscal_periods` | `quarter_number`, `fiscal_year_id` |
| ATC code | `ewt_entries` | `atc_code` |
| Tax base | `ewt_entries` | `SUM(ewt_base_amount) GROUP BY atc_code` |
| Tax rate | `atc_codes` | `ewt_rate` |
| Tax withheld | `ewt_entries` | `SUM(ewt_amount) GROUP BY atc_code` |
| Penalties | `ewt_remittances_1601eq` | `penalty_amount` (if late) |
| Total tax due | computed | |

### Required Fields on `ewt_entries`

| Column | Description |
|---|---|
| `atc_code` | e.g., WC010, WC158, WI010 |
| `ewt_base_amount` | Gross income subject to withholding |
| `ewt_rate` | Rate applied (from ATC master at time of transaction) |
| `ewt_amount` | ewt_base_amount × ewt_rate |
| `payee_id` | FK → suppliers.id |
| `payee_tin` | Denormalized from supplier at time of transaction (snapshot) |
| `payee_name` | Denormalized supplier name (snapshot) |
| `document_date` | Transaction date |
| `source_document_type` | 'vendor_bill' \| 'payment_voucher' \| 'petty_cash_voucher' \| 'cash_purchase' |
| `source_document_id` | FK to the source document |
| `fiscal_period_id` | FK → fiscal_periods.id |

---

## 5. BIR Form 2307 — Certificate of Creditable Tax Withheld at Source

### Output: 2307 Issued (to supplier)

| 2307 Field | Source Table | Source Column |
|---|---|---|
| Withholding agent TIN | `companies` | `tin` |
| Withholding agent name | `companies` | `name` |
| Payee TIN | `certificates_2307_issued` | `payee_tin` (snapshot) |
| Payee name | `certificates_2307_issued` | `payee_name` (snapshot) |
| Payee address | `certificates_2307_issued` | `payee_address` (snapshot) |
| Quarter | `certificates_2307_issued` | `quarter_number`, `year` |
| ATC code | `certificates_2307_issued` | `atc_code` |
| Income payment per month | `ewt_entries` | `SUM(ewt_base_amount) GROUP BY month_number` |
| Tax withheld per month | `ewt_entries` | `SUM(ewt_amount) GROUP BY month_number` |
| Total income payment | computed | |
| Total tax withheld | computed | |

### `certificates_2307_issued` Table (Full Spec)

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `company_id` | uuid FK companies | |
| `supplier_id` | uuid FK suppliers | |
| `payee_tin` | text | Snapshot at certificate generation time |
| `payee_name` | text | Snapshot |
| `payee_address` | text | Snapshot |
| `atc_code` | text | |
| `quarter_number` | integer | 1–4 |
| `year` | integer | Calendar year |
| `fiscal_period_id` | uuid FK fiscal_periods | Quarter end period |
| `certificate_no` | text | Sequential per company |
| `total_base_amount` | numeric(18,4) | Sum of ewt_base_amount for the quarter |
| `total_ewt_amount` | numeric(18,4) | Sum of ewt_amount for the quarter |
| `month_1_base` | numeric(18,4) | Month 1 of quarter |
| `month_1_ewt` | numeric(18,4) | |
| `month_2_base` | numeric(18,4) | |
| `month_2_ewt` | numeric(18,4) | |
| `month_3_base` | numeric(18,4) | |
| `month_3_ewt` | numeric(18,4) | |
| `is_issued` | boolean | Whether physically given to supplier |
| `issued_at` | timestamptz | When issued |
| `issued_to` | text | Name/designation of recipient |
| `generated_document_id` | uuid FK generated_documents | PDF stored in Supabase Storage |
| `created_at` | timestamptz | |
| `created_by` | uuid FK auth.users | |

---

## 6. BIR Form 2307 Received (from customers)

### Output: Input to Annual Income Tax Return (Tax Credits)

| Field | Source Table | Source Column |
|---|---|---|
| Customer TIN | `certificates_2307_received` | `customer_tin` (snapshot) |
| Customer name | `certificates_2307_received` | `customer_name` (snapshot) |
| Quarter | `certificates_2307_received` | `quarter_number`, `year` |
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
| Payee TIN | `fwt_entries` | `payee_tin` (snapshot) |
| Payee name | `fwt_entries` | `payee_registered_name` (snapshot) |
| ATC code | `fwt_entries` | Final tax ATC codes (WF-series) |
| Income payment | `fwt_entries` | `fwt_base_amount` |
| Final tax withheld | `fwt_entries` | `fwt_amount` |

> **IMPORTANT:** 2306 is generated from `fwt_entries` (Final Withholding Tax — WF-series ATC), NOT from `ewt_entries` (EWT/creditable — WC/WI-series). FWT is a FINAL tax; the payee cannot use it as a creditable tax against income tax. This is the key distinction from 2307.
- Stored in `certificates_2306_issued` (parallel structure to `certificates_2307_issued`)

---

## 8. QAP — Quarterly Alphalist of Payees

### Output: DAT file for BIR submission with 1601EQ

| QAP Column | Source | Notes |
|---|---|---|
| Payee sequence no. | computed | Sequential per QAP |
| Payee TIN | `ewt_entries` | `payee_tin` (snapshot — do NOT join to current supplier) |
| Payee name | `ewt_entries` | `payee_name` (snapshot) |
| ATC code | `ewt_entries` | `atc_code` |
| Tax base (M1, M2, M3) | `ewt_entries` | Grouped by month within quarter using `document_date` |
| EWT amount (M1, M2, M3) | `ewt_entries` | Grouped by month |
| Total tax base | computed | |
| Total EWT | computed | |

- Grouped by: (payee_tin, atc_code)
- Include ALL suppliers withheld from in the quarter, even if 2307 not yet issued
- Source documents: `vendor_bills`, `payment_vouchers`, `petty_cash_vouchers`, `cash_purchases`

---

## 9. BIR Books of Accounts

### General Journal
Source: `journal_entries` + `journal_lines`

| BIR Field | Column |
|---|---|
| Date | `journal_entries.document_date` |
| Reference | `journal_entries.document_no` |
| Description | `journal_entries.description` |
| Account | `chart_of_accounts.account_code`, `account_name` |
| Debit | `journal_lines.debit_amount` |
| Credit | `journal_lines.credit_amount` |

### General Ledger
Source: `journal_lines` filtered per account, sorted by date

| BIR Field | Column |
|---|---|
| Date | `journal_entries.document_date` |
| Reference | `journal_entries.document_no` |
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

### Cash Sales Book
Source: `cash_sales` + `cash_sale_lines` + `vat_entries`

| BIR Field | Column |
|---|---|
| Date | `cash_sales.document_date` |
| OR Number | `cash_sales.document_no` |
| Customer TIN | `cash_sales.customer_tin` (snapshot) or `customers.tin` |
| Taxable Sales | `SUM(cash_sale_lines.net_amount WHERE vat_classification='vatable')` |
| VAT | `SUM(vat_entries.vat_amount)` |
| Zero-rated | `SUM(cash_sale_lines.net_amount WHERE vat_classification='zero_rated')` |
| Exempt | `SUM(cash_sale_lines.net_amount WHERE vat_classification='exempt')` |
| Total | computed |

### Cash Purchases Book
Source: `cash_purchases` + `cash_purchase_lines` + `vat_entries` + `ewt_entries`

| BIR Field | Column |
|---|---|
| Date | `cash_purchases.document_date` |
| Reference No. | `cash_purchases.document_no` |
| Supplier TIN | `cash_purchases.supplier_tin` (snapshot) or `suppliers.tin` |
| Taxable Purchases | `SUM(cash_purchase_lines.net_amount WHERE vat_classification='vatable')` |
| Input VAT | `SUM(vat_entries.vat_amount WHERE vat_direction='input')` |
| EWT | `SUM(ewt_entries.ewt_amount)` |
| Total | computed |

---

## 10. BIR CAS (Computerized Accounting System) Audit Requirements

### DAT File Generation

| DAT File | Source | Tables Involved |
|---|---|---|
| GL DAT | General Ledger | `journal_entries`, `journal_lines`, `chart_of_accounts` |
| SL DAT | Subsidiary Ledger | `subsidiary_ledger_entries`, `customers`, `suppliers` |
| SLS DAT | Sales Summary | `sales_invoices`, `cash_sales`, `vat_entries` |
| PUR DAT | Purchases Summary | `vendor_bills`, `cash_purchases`, `vat_entries` |
| INV DAT | Inventory Movement | `inventory_movements`, `inventory_cost_layers` |

### CAS Audit Trail Requirements

| Requirement | Implementation |
|---|---|
| Sequential numbering, no gaps | `number_series` with nightly gap detection via `atp_usage_logs` |
| No modification after posting | RLS immutability policy + `enforce_posted_immutability()` trigger |
| Complete audit trail | `audit_logs` + `field_change_history` |
| ATP tracking | `number_series_atp` + `atp_usage_logs` |
| DAT file log | `dat_generation_logs` records every export with SHA-256 hash |
| User action log | `user_activity_logs` records every login, export, print |

---

## 11. ATP (Authority to Print) Tracking

| Field | Table | Purpose |
|---|---|---|
| ATP number | `number_series_atp.atp_reference_no` | BIR-issued ATP per series |
| Series from | `number_series_atp.series_start` | First allowed number |
| Series to | `number_series_atp.series_end` | Last allowed number |
| Expiry date | `number_series_atp.valid_until` | ATP validity |
| Usage log | `atp_usage_logs` | Every document number assigned (immutable) |

- When `number_series.current_number` approaches `max_number`, system generates `system_alerts` record
- ATP log is immutable — no soft delete, no update

---

## 12. Compliance Readiness Checklist

| Form / Report | Tables Driving It | Key Fields |
|---|---|---|
| 2550M / 2550Q | `vat_entries`, `vat_period_summaries` | vat_direction, vat_classification, net_amount, vat_amount, fiscal_period_id |
| 2551Q | `percentage_tax_entries`, `percentage_tax_period_summaries` | gross_receipts_amount, pt_rate, pt_amount, fiscal_period_id |
| 1601FQ | `fwt_entries`, `fwt_remittances_1601fq` | atc_code (WF-series), fwt_amount, payee_tin, fiscal_period_id |
| ITR (Individual) | `income_tax_return_filings`, `itr_computation_runs`, `income_tax_computation_lines` | form_code='1701Q'/'1701', taxable_income, income_tax_due |
| ITR (Corporate) | `income_tax_return_filings`, `itr_computation_runs`, `income_tax_computation_lines` | form_code='1702Q'/'1702RT', mcit_amount (in itr_computation_runs), income_tax_due |
| SLSP (Sales) | `sales_invoices`, `cash_sales`, `customers`, `vat_entries` | customer_tin (snapshot), document_date, amounts |
| SLSP (Purchases) / RELIEF | `vendor_bills`, `cash_purchases`, `suppliers`, `vat_entries` | supplier_tin (snapshot), document_date, amounts |
| 1601EQ | `ewt_entries`, `ewt_remittances_1601eq` | atc_code, ewt_amount, fiscal_period_id |
| 2307 Issued | `certificates_2307_issued`, `ewt_entries` | payee_tin (snapshot), quarterly totals |
| 2307 Received | `certificates_2307_received` | customer_tin (snapshot), quarterly totals |
| 2306 | `certificates_2306_issued`, `fwt_entries` | payee_tin (snapshot), final tax — source is fwt_entries (WF-series), NOT ewt_entries |
| QAP | `ewt_entries` | payee_tin (snapshot), per-payee per-ATC monthly breakdown |
| SAWT | `certificates_2307_received` | Customer alphalist |
| BIR Books | `journal_entries`, `journal_lines` | All posted entries |
| Cash Sales Book | `cash_sales`, `cash_sale_lines`, `vat_entries` | document_date, customer_tin, amounts |
| Cash Purchases Book | `cash_purchases`, `cash_purchase_lines`, `vat_entries`, `ewt_entries` | document_date, supplier_tin, amounts |
| CAS DAT Files | All transaction tables | Full data export |
| 1604E | `ewt_entries` (annual) | Annual alphalist of payees |

---

---

## 12a. Percentage Tax / 2551Q Data Capture

Applies only when `company_compliance_profiles.taxpayer_type = 'non_vat'`.

| Field Required on 2551Q | Source Table | Column |
|---|---|---|
| Taxpayer TIN | `company_compliance_profiles` → `companies` | `companies.tin` (snapshot at filing) |
| Registered Name | `companies` | `name` |
| RDO Code | `company_compliance_profiles` | `rdo_code` |
| Quarter Covered | `percentage_tax_return_filings` | `quarter`, `quarter_date_from`, `quarter_date_to` |
| Gross Receipts | `percentage_tax_period_summaries` | `gross_receipts_total` |
| PT Rate | `percentage_tax_entries` | `pt_rate` |
| PT Due | `percentage_tax_period_summaries` | `pt_amount_total` |

Source transactions: `sales_invoices` and `cash_sales` where the company's taxpayer_type = 'non_vat' at the time of posting.

---

## 12b. Final Withholding Tax / 1601FQ Data Capture

Applies to transactions with WF-series ATC codes (dividends, royalties, final interest, etc.).

| Field Required on 1601FQ | Source Table | Column |
|---|---|---|
| Taxpayer TIN | `companies` | `tin` (snapshot) |
| Withholding Agent Name | `companies` | `name` |
| Quarter Covered | `fwt_remittances_1601fq` | `quarter`, dates |
| Total FWT | `fwt_remittances_1601fq` | `fwt_amount_total` |
| Per-Payee Breakdown | `fwt_entries` → `certificates_2306_issued` | payee_tin (snapshot), fwt_amount |

Key difference from EWT: FWT is final — payees cannot claim these as creditable taxes. EWT (1601EQ) is creditable by the payee.

---

## 12c. Income Tax Return (ITR) Data Capture

ITR form is determined by `company_compliance_profiles.income_tax_regime`:

| income_tax_regime | Quarterly ITR | Annual ITR | MCIT Applies? |
|---|---|---|---|
| `individual` | 1701Q | 1701 | No |
| `corporate` | 1702Q | 1702RT | Yes |
| `partnership` | 1702Q | 1702RT | No |
| `cooperative` | Special (out of scope for Phase 1) | — | — |

| Field Required on ITR | Source Table | Column |
|---|---|---|
| Taxpayer TIN | `companies` | `tin` |
| Taxable Income | `itr_computation_runs` | `taxable_income_amount` (derived from gl_balances via income_tax_computation_lines — includes effects of amortization and revenue recognition JEs already posted to GL) |
| Income Tax Due | `income_tax_return_filings` | `income_tax_due` |
| MCIT (if higher) | `itr_computation_runs` | `mcit_amount` (higher of regular tax or 2%/1% × gross_income_amount) |
| Tax Credits (2307) | `tax_credits_schedules` | from `certificates_2307_received` |
| Net Tax Payable | `income_tax_return_filings` | `income_tax_payable` |

---

### Amortization and Deferred Revenue — ITR Impact

Amortization and revenue recognition JEs post to GL like any other journal entry. Their compliance impact is indirect:
- **Prepaid amortization**: DR Expense each period → reduces taxable income in the correct period (timing of deductibility)
- **Deferred revenue recognition**: CR Revenue each period → recognizes income in the correct period (timing of taxable income)
- `income_tax_computation_lines` reads from `gl_balances` which already reflects these posted JEs — no special mapping needed
- **BIR note**: Prepaid expenses are deductible in the period consumed, not the period paid. Amortization schedules enforce this. For cash-basis taxpayers in Phase 1, this distinction is important.

---

## 13. Compliance Output Generation Tables

> **E-1 fix (v3.3):** `compliance_report_runs` and `compliance_export_files` are NOT canonical table names. They were removed from Doc02 in favor of the unified async job architecture. Canonical tables:
>
> - **`export_jobs`** (#189 in Doc02) — tracks every async compliance report generation request. Column spec: See Doc03 Section 44 and Doc08 Section 4. Compliance reports are requested via `export_jobs.export_type` values such as `'vat_2550m'`, `'ewt_1601eq'`, `'pt_2551q'`, `'slsp_sales'`, etc.
>
> - **`generated_report_files`** (#190 in Doc02) — stores metadata for generated report files persisted beyond the export job lifetime. Column spec: See Doc03 Section 44. Field `is_compliance_filing = true` marks BIR submission files.
>
> The link between an `export_jobs` record and its output file(s) is via `generated_report_files.export_job_id → export_jobs.id`. No direct FK to a `compliance_report_runs` table exists — that table has been removed.
