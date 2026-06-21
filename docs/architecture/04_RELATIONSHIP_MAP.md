# PXL ERP — Relationship Map
**Version:** 3.2 — Brutal Audit Fix Pass
**Status:** v3.2 — Ghost Table Names Cleaned Up. Pending overall freeze gate.

## Ghost Table Name Cleanup (v3.2)

All non-canonical table names found in diagrams replaced with canonical names from Doc 02 registry:

| Ghost Name (removed) | Canonical Name (Doc 02 Registry) | Doc 02 Table # |
|---|---|---|
| `credit_memos` | `sales_credit_memos` | #73 |
| `credit_memo_lines` | `sales_credit_memo_lines` | #74 |
| `delivery_orders` | `delivery_receipts` | #65 |
| `delivery_order_lines` | `delivery_receipt_lines` | #66 |
| `goods_receipts` | `receiving_reports` | #81 |
| `goods_receipt_lines` | `receiving_report_lines` | #82 |
| `bank_deposits` | `receipts` (official receipts — AR collections) | #71 |
| `bank_deposit_lines` | `receipt_lines` | #72 |
| `bank_withdrawals` | `payment_vouchers` (AP payments) | #87 |
| `bank_withdrawal_lines` | `payment_voucher_lines` | #88 |
| `disbursement_vouchers` | `payment_vouchers` | #87 |
| `disbursement_voucher_lines` | `payment_voucher_lines` | #88 |
| `official_receipts` | `receipts` | #71 |
| `official_receipt_lines` | `receipt_lines` | #72 |
| `bank_transfers` | `bank_fund_transfers` | #101 |
| `slsp_entries` | `slsp_exports` (export batch records, computed at export) | #143 |
| `slsp_records` | `slsp_exports` | #143 |
| `slsp_summary` | *(removed — no such table)* | — |
| `relief_entries` | `relief_exports` | #144 |
| `relief_summary` | *(removed — no such table)* | — |
| `qap_entries` | `qap_exports` | #151 |
| `qap_records` | `qap_exports` | #151 |
| `sawt_entries` | `sawt_exports` | #152 |
| `sawt_records` | `sawt_exports` | #152 |
| `certificates_2306` | `certificates_2306_issued` | #149 |
| `inventory_adjustments` | `stock_adjustments` | #109 |
| `inventory_adjustment_lines` | `stock_adjustment_lines` | #110 |

---

## Changes Applied (v1 → v2)

- Updated posting engine references: `posting_rules` → `posting_rule_sets`
- Updated compliance references: `vat_summary_period` → `vat_period_summaries`
- Updated document number column: `document_number` → `document_no`
- Updated date column: `invoice_date`/`bill_date` → `document_date`
- Added Cash Sales and Cash Purchases relationship chains (OD-08 resolved)
- Added Notification relationship chain (Section 13)
- Added Document Template and Generated Output relationship chain (Section 14)
- Added Budget relationship chain (Section 15)
- Added Period Close relationship chain (Section 16)
- Added Party Duplicate Management relationship chain (Section 17)
- Added `inventory_cost_layer_consumption` to inventory section
- Added `bank_statement_lines` to bank reconciliation section
- Added `attachment_versions` to attachments section
- Added `system_alerts` to audit section
- Updated bridge table summary for all new tables
- Fixed `bank_statements_lines` → `bank_statement_lines` (singular table name)

## v3 Architecture Review Changes Applied (Enhancement Round)

- **Section 26: Amortization Schedule Chain** added
- **Section 27: Revenue Recognition Schedule Chain** added
- **Section 28: Auto Reversal Chain** added
- **journal_entries** chain updated — new FK columns (auto_reversal_run_id, amortization_run_detail_id, revenue_recognition_run_detail_id) reflected

## v3 Architecture Review Changes Applied (Round 2 — Structural Fixes)

- **Party classification chain updated**: Customer and supplier nodes now show `party_special_class` (government/peza/boi/foreign_entity) as separate from `vat_registration_status`. The posting engine reads `party_special_class` to set `vat_entries.vat_classification = 'government'` — this is NOT stored on transaction lines.
- **Income tax chain rewritten**: `itr_working_papers` → renamed `itr_computation_runs`. `mcit_computations` and `nolco_schedules` REMOVED (superseded). Canonical chain: `income_tax_return_filings` → `itr_computation_runs` → `income_tax_computation_lines` + `book_tax_reconciliations` + `nolco_tracking` + `tax_credits_schedules`.
- **COA mapping chain**: No separate mapping table chain. `chart_of_accounts` carries `fs_section`, `fs_group`, `fs_sort_order`, `cash_flow_category` directly. FS report generation reads COA directly.
- **companies.tax_type**: CHECK corrected to ('vat','non_vat'). Diagram nodes updated — 'exempt' removed.

## v3 Open Decisions

| OD# | Decision | Status |
|---|---|---|
| OD-04-V3-01 | `user_branch_access` table — is this still in scope for Phase 1 or deferred? | **RESOLVED** — `user_branch_access` is ACTIVE (#7 in Doc 02 registry). Phase 1 uses it for UI-layer branch filtering per Doc 09 Option A. No separate security boundary RLS needed Phase 1. |
| OD-04-V3-02 | `fwt_entries` — separate table or part of `ewt_entries` with a direction flag? | **RESOLVED** — Separate table confirmed: `fwt_entries` (#146 in Doc 02). WF-series ATC codes only. Separate from `ewt_entries` (#145) WC/WI-series. BIR requires separate 1601FQ form vs 1601EQ — separate tables are correct. |

---

## Changes Applied (v2 → v2.1) — Principle Alignment

- Added Section 22: Compliance Profile Chain (Principle 6)
- Added Section 23: Percentage Tax Chain (Principle 20)
- Added Section 24: FWT / 1601FQ Chain (Principle 20)
- Added Section 25: Income Tax Return Filing Chain

---

## Open Decisions Remaining

| OD # | Question | Status |
|---|---|---|
| OD-09 | Should `document_relationships` also link notification events to their source documents? | Unresolved — Phase 2 consideration |
| OD-10 | Should `generated_documents` link to `export_jobs` when a PDF is produced as part of an export? | Unresolved — decide before implementing Edge Functions |

---

## Implementation Notes

- Every new table added in v2 (cash_sales, notifications, document_templates, budgets, period_close, party_merge) carries `company_id` for RLS compliance.
- Cash Sales and Cash Purchases do NOT appear in the AR/AP ledger chains. They have their own posting paths directly to GL.
- Notification chains are async (fire-and-forget); they do not block or participate in posting transactions.
- Period close checklist is a separate management workflow; it does not alter the fiscal_locks table directly — the controller manually locks after all tasks are complete.

---

## 1. Core Hierarchy Relationships

### Company Structure
```
companies (1)
  └── branches (many)
        └── departments (many)
              └── cost_centers (many)
```

### User Access
```
auth.users (1)
  ├── profiles (1)
  ├── user_company_access (many) ──► companies
  └── user_branch_access (many) ──► branches
```

### Roles & Permissions
```
roles (many)
  └── role_permissions (bridge) ──► permissions
        
user_roles (bridge)
  ├── auth.users
  └── roles
```

---

## 2. Setup & Configuration Relationships

### Chart of Accounts
```
account_types (1)
  └── chart_of_accounts (many)
        └── chart_of_accounts (many, self-ref: parent_account_id)
```

### Number Series
```
number_series (1)
  └── number_series_atp (many)
        └── atp_usage_logs (many, immutable)
```

### Approval
```
approval_matrix (1)
  └── approval_matrix_steps (many)
        ├── auth.users (designated approver)
        └── roles (role-based approver)
        
approval_requests (1)
  ├── approval_matrix
  ├── [any source document]
  └── approval_actions (many, immutable)
        └── auth.users (approver)
```

### Fiscal Calendar
```
fiscal_years (1)
  └── fiscal_periods (many)
        └── fiscal_locks (1:1 per company/period)
```

### Payment Terms
```
payment_terms (1)
  └── payment_term_lines (many)
```

---

## 3. Master Data Relationships

### Customer
```
customers (1)
  ├── customer_tax_profiles (1:many — versioned by effective_from/effective_to; one active at any time WHERE effective_to IS NULL)
  ├── customer_addresses (many)
  └── customer_contacts (many)
```

### Supplier
```
suppliers (1)
  ├── supplier_tax_profiles (1:many — versioned by effective_from/effective_to; one active at any time WHERE effective_to IS NULL)
  ├── supplier_addresses (many)
  └── supplier_contacts (many)
```

### Item / Inventory
```
item_categories (1)
  └── items (many)
        ├── item_units_of_measure (bridge) ──► units_of_measure    ← canonical: units_of_measure #41
        ├── inventory_balances (many) ──► warehouses               ← canonical: inventory_balances (not item_warehouse_stock)
        └── item_prices (many, per price tier)                     ← canonical: item_prices #46 (price_lists = Phase 2)

warehouses (1)
  └── [warehouse_locations — Phase 2 only; not in Phase 1 table registry]
```

### Fixed Assets
```
asset_categories (1)
  └── fixed_assets (many)
        └── asset_depreciation_schedules (many)                    ← canonical: asset_depreciation_schedules (plural)
```

---

## 4. Sales Module Relationships

### Sales Order → Invoice → Receipt → 2307

```
customers (1)
  └── sales_orders (many)
        └── sales_invoices (many, via source_document_id)
              ├── sales_invoice_lines (many)
              │     ├── items
              │     ├── chart_of_accounts (revenue account)
              │     └── vat_entries (many)
              ├── receipts (many, via invoice_id)
              │     ├── receipt_lines (many)
              │     └── certificates_2307_received (many)
              │           └── generated_documents (PDF of 2307)
              └── document_relationships (many, bidirectional)
```

### Cash Sales (No AR Created)

```
customers (1, optional — cash sales may be walk-in)
  └── cash_sales (many)
        ├── cash_sale_lines (many)
        │     ├── items
        │     ├── chart_of_accounts (revenue account)
        │     └── vat_entries (output VAT)
        └── journal_entries (direct DR Cash / CR Revenue + Output VAT)
              — NO subsidiary_ledger_entries (AR) created
```

### Sales Return
```
sales_invoices (original, POSTED)
  └── sales_credit_memos (reversal document)          ← canonical: sales_credit_memos
        └── sales_credit_memo_lines
              └── vat_entries (negative VAT)
```

### Delivery
```
sales_orders (1)
  └── delivery_receipts (many)                        ← canonical: delivery_receipts (was: delivery_orders)
        └── delivery_receipt_lines (many)
              └── inventory_movements (OUT)
```

---

## 5. Purchasing Module Relationships

### Purchase Order → Vendor Bill → Payment Voucher → 2307 Issued

```
suppliers (1)
  └── purchase_orders (many)
        └── vendor_bills (many, via source_document_id)
              ├── vendor_bill_lines (many)
              │     ├── items
              │     ├── chart_of_accounts (expense/asset account)
              │     ├── vat_entries (input VAT)
              │     └── ewt_entries (many, per ATC)
              └── payment_vouchers (many, via bill_id)
                    ├── payment_voucher_lines (many)
                    │     └── ewt_entries (EWT deducted on payment)
                    └── certificates_2307_issued (many)
                          └── generated_documents (PDF of 2307)
```

### Cash Purchases (No AP Created)

```
suppliers (1, optional — cash purchases may be one-time vendor)
  └── cash_purchases (many)
        ├── cash_purchase_lines (many)
        │     ├── items
        │     ├── chart_of_accounts (expense/asset account)
        │     ├── vat_entries (input VAT)
        │     └── ewt_entries (EWT captured at time of purchase)
        └── journal_entries (direct DR Inventory/Expense + Input VAT / CR Cash - EWT)
              — NO subsidiary_ledger_entries (AP) created
```

### Goods Receipt
```
purchase_orders (1)
  └── receiving_reports (many)                        ← canonical: receiving_reports (was: goods_receipts)
        └── receiving_report_lines (many)
              └── inventory_movements (IN)
                    └── inventory_cost_layers (FIFO layer)
```

---

## 6. Petty Cash Relationships

```
petty_cash_funds (1)
  ├── petty_cash_vouchers (many)
  │     └── petty_cash_voucher_lines (many)
  │           ├── chart_of_accounts (expense account)
  │           └── ewt_entries (if withholding applies)
  └── petty_cash_replenishments (many)
        └── payment_vouchers (replenishment payment)
```

---

## 7. Bank & Cash Relationships

> **v3.2 Ghost Name Fix (revised v3.5):** `bank_deposits`, `bank_deposit_lines`, `bank_withdrawals`, `official_receipts`, `disbursement_vouchers` are NOT canonical table names. Canonical names per Doc 02: collections use `receipts` (#71) + `receipt_lines` (#72); disbursements use `payment_vouchers` (#87) + `payment_voucher_lines` (#88). Bank reconciliation matches posted transactions against imported `bank_statement_lines`.

```
company_bank_accounts (1)
  ├── receipts (many — official receipts for AR collections deposited)   ← canonical: receipts #71
  │     └── receipt_lines (many)                                          ← canonical: receipt_lines #72
  │           └── [customer | journal_entry reference]
  ├── payment_vouchers (many — AP payments drawn)                         ← canonical: payment_vouchers #87
  │     └── payment_voucher_lines (many)                                  ← canonical: payment_voucher_lines #88
  │           └── [supplier | journal_entry reference]
  ├── bank_fund_transfers (many — inter-account)                          ← canonical: bank_fund_transfers #101
  │     ├── company_bank_accounts (source)
  │     └── company_bank_accounts (destination)
  └── bank_reconciliations (many)
        └── bank_reconciliation_lines (many)
              ├── bank_statement_lines (imported bank statement)
              └── [matched transaction: receipt | payment_voucher | journal_entry]
```

---

## 8. Inventory Relationships

```
inventory_movements (1)
  ├── items
  ├── warehouses
  ├── [source: receiving_reports | delivery_receipts | stock_adjustments | stock_transfers | cash_sales | cash_purchases]
  └── inventory_cost_layers (many, FIFO)
        └── inventory_cost_layer_consumption (many)
              └── inventory_movements (consumption reference — which sale consumed which layer)

stock_adjustments (1)                                                     ← canonical: stock_adjustments #109
  └── stock_adjustment_lines (many)                                        ← canonical: stock_adjustment_lines #110
        ├── items
        └── inventory_movements (generated)

stock_transfers (1)
  └── stock_transfer_lines (many)
        ├── warehouses (source)
        ├── warehouses (destination)
        └── inventory_movements (OUT + IN pair)
```

---

## 9. Fixed Assets Relationships

```
fixed_assets (1)
  ├── asset_categories ──► chart_of_accounts (asset account)
  ├── asset_acquisitions (many)
  │     └── vendor_bills (source, via source_document_id)
  ├── asset_depreciation_schedules (many)
  │     └── depreciation_runs (many)
  │           └── journal_entries (auto-generated)
  └── asset_disposals (1:1 when disposed)
        └── journal_entries (disposal JE)
```

---

## 10. Posting Engine Relationships

### Source Document → Journal Entry

```
[Any Source Document]
  │  sales_invoices | vendor_bills | receipts | payment_vouchers
  │  cash_sales | cash_purchases | journal_entries (manual)
  │  petty_cash_vouchers | bank_fund_transfers | asset_acquisitions
  │  inventory_adjustments | depreciation_runs
  │
  ▼
posting_rule_sets (1)
  └── posting_rule_lines (many)
        └── chart_of_accounts (DR/CR account)
  │
  ▼
journal_entries (1)
  ├── fiscal_years
  ├── fiscal_periods
  └── journal_lines (many, always balanced)
        ├── chart_of_accounts (account)
        ├── [dimension: branch, department, cost_center]
        └── subsidiary_ledger_entries (many)
              ├── [AR | AP | INVENTORY | FIXED_ASSET]
              └── [customer | supplier | item | fixed_asset] (entity ref)
              — NOTE: cash_sales and cash_purchases do NOT generate subsidiary_ledger_entries
```

### GL Balance Update

```
journal_lines (posted)
  └── gl_balances (upsert: account + period + branch)
        └── [running debit, credit, net balance]
```

### Document Relationships Registry

```
document_relationships
  ├── source_document_type (e.g., 'sales_order')
  ├── source_document_id
  ├── target_document_type (e.g., 'sales_invoice')
  ├── target_document_id
  └── relationship_type CHECK IN ('billed_from','paid_by','reversed_by','delivered_from','received_from','applied_to','replenished_by') — all lowercase per Doc03 enum standard
```

---

## 11. Compliance Relationships

### VAT Chain

```
sales_invoice_lines / cash_sale_lines / vendor_bill_lines / cash_purchase_lines
  └── vat_entries (1:1 per taxable line)
        └── vat_period_summaries (aggregated per period)
              └── [BIR Form 2550M input | SLSP line | RELIEF line]
```

### EWT Chain

```
vendor_bill_lines / payment_voucher_lines / petty_cash_voucher_lines / cash_purchase_lines
  └── ewt_entries (many per line, one per ATC code)
        ├── certificates_2307_issued (quarterly aggregate per supplier)
        │     └── generated_documents (2307 PDF)
        └── ewt_remittances_1601eq (1601EQ filing per period)
              ├── qap_exports (quarterly alphalist export batch)   ← canonical: qap_exports #151 (was: qap_entries)
              └── sawt_exports (SAWT export batch records)         ← canonical: sawt_exports #152 (was: sawt_entries/sawt_records)
```

### 2307 Received Chain

```
receipts / payment_received
  └── certificates_2307_received (per customer, per quarter)
        └── generated_documents (2307 received PDF)
              └── [SAWT export]
```

### SLSP / RELIEF Chain

> **v3.2 Ghost Name Fix + OD-11 Decision (revised v3.5):** `slsp_entries`, `slsp_summary`, `slsp_records`, `relief_entries`, `relief_summary` are not canonical table names and do not exist. Per OD-11 (resolved): SLSP and RELIEF data is **computed at export time** from existing `vat_entries`, `sales_invoice_lines`, `vendor_bill_lines` snapshots — no persistent per-line table. Canonical names per Doc 02: `slsp_exports` (#143) and `relief_exports` (#144) store per-batch export records.

```
sales_invoice_lines + customer_tin (snapshot) + vat_entries
  └── [SLSP Edge Function — computed at export time]
        └── slsp_exports (export batch records)     ← canonical: slsp_exports #143 (was: slsp_entries/slsp_records)

vendor_bill_lines + supplier_tin (snapshot) + vat_entries
  └── [RELIEF Edge Function — computed at export time]
        └── relief_exports (export batch records)   ← canonical: relief_exports #144 (was: relief_entries)
```

### Cash Sales Book (BIR)

```
cash_sales + cash_sale_lines + vat_entries
  └── [BIR Cash Sales Book — source documents by date]
```

### Cash Purchases Book (BIR)

```
cash_purchases + cash_purchase_lines + vat_entries + ewt_entries
  └── [BIR Cash Purchases Book — source documents by date]
```

---

## 12. Audit Trail Relationships

```
[Any table row change]
  └── field_change_history (immutable)
        ├── table_name
        ├── record_id
        ├── field_name
        ├── old_value, new_value
        └── changed_by ──► auth.users

[Any user action]
  └── audit_logs (immutable)
        ├── event_type
        ├── entity_type, entity_id
        └── performed_by ──► auth.users

[Any document voided]
  └── document_void_register (immutable)
        ├── [source document ref]
        ├── void_reason, voided_by
        └── journal_entries (reversal JE generated)

[Any gap in number sequence]
  └── system_alerts
        └── [nightly pg_cron check via atp_usage_logs]
```

---

## 13. Notification Relationships

```
[System event: document submitted, approved, posted, rejected, ATP near limit, etc.]
  │
  ▼
notification_templates (1, per event_type per company)
  │
  ▼
notifications (1 per recipient per event)
  ├── profiles (recipient)
  ├── [source entity_type + entity_id]
  └── notification_delivery_logs (1 per delivery channel per notification)
        └── [channel: 'in_app' | 'email']
```

---

## 14. Document Template and Generated Output Relationships

```
document_templates (1 per doc_type per company)
  │
  ▼
generated_documents (1 per generated PDF/file)
  ├── [source: entity_type + entity_id → sales_invoices | receipts | certificates_2307_issued | etc.]
  ├── document_templates (template used)
  └── generated_document_versions (many, version history)
```

---

## 15. Budget Relationships

```
fiscal_years (1)
  └── budgets (many per company per year)
        └── budget_lines (many)
              ├── chart_of_accounts (account)
              ├── fiscal_periods (one line per period)
              └── branches (optional — branch-level budget)
```

---

## 16. Period Close Relationships

```
fiscal_periods (1)
  └── period_close_checklists (1 per company per period)
        └── period_close_tasks (many, seeded from standard task list)
              ├── profiles (assigned_to)
              ├── profiles (completed_by)
              └── subledger_close_certifications (optional — per task)
```

---

## 17. Party Duplicate Management Relationships

```
customers / suppliers
  └── duplicate_tin_flags (raised when TIN matches existing record)
        └── [source_party_id + target_party_id]

party_merge_logs (1 per merge operation)
  ├── source_party_type + source_party_id (retired record)
  └── target_party_type + target_party_id (canonical record)
```

---

## 18. Attachment Relationships

```
[Any source entity: sales_invoices | vendor_bills | receipts | payment_vouchers | etc.]
  └── attachments (many, polymorphic via entity_type + entity_id)
        ├── Supabase Storage (file_size_bytes, storage_bucket, storage_path, file_hash_sha256)
        └── attachment_versions (many — version history per attachment)
```

---

## 19. Import Relationships

```
import_batches (1)
  ├── import_rows (many)
  │     └── import_validation_errors (many)
  └── [created records carry import_batch_id]
        Setup: chart_of_accounts, payment_terms, atc_codes, tax_codes, approval_matrix, warehouses
        Master: customers, suppliers, items, item_prices, bank_accounts
        Opening: opening_balance_entries, inventory_cost_layers (opening stock), subsidiary_ledger_entries (AR/AP opening)
        Fixed Assets: fixed_assets, asset_depreciation_schedules
```

---

## 20. Many-to-Many Bridge Tables Summary

| Bridge Table | Left Side | Right Side | Purpose |
|---|---|---|---|
| `user_company_access` | auth.users | companies | Which companies a user can access |
| `user_branch_access` | auth.users | branches | Which branches a user can access |
| `user_roles` | auth.users | roles | Role assignments per user |
| `role_permissions` | roles | permissions | Which permissions each role has |
| `item_units_of_measure` | items | units_of_measure | UOM conversions per item |
| `item_price_lists` | items | price_lists | Pricing per item per list |
| `approval_matrix_steps` | approval_matrix | auth.users/roles | Approver assignments per step |
| `bank_reconciliation_lines` | bank_reconciliations | transactions | Matched/unmatched lines |
| `document_relationships` | documents | documents | Cross-document traceability |
| `qap_exports` | ewt_remittances_1601eq | suppliers | Per-payee alphalist entries — canonical: qap_exports #151 |
| `sawt_exports` | ewt_entries | customers | SAWT export batch records — canonical: sawt_exports #152 (was: sawt_records/sawt_entries) |

---

## 21. Key Constraints

- Every `journal_entries` record must have `SUM(journal_lines.debit_amount) = SUM(journal_lines.credit_amount)` — enforced by posting engine before commit
- Every `fiscal_period_id` on posted entries must reference an OPEN period in `fiscal_locks` — enforced by trigger
- `number_series.current_number` must never exceed `max_number` (ATP limit) — enforced by series allocation function
- `deleted_at` on parent records does NOT cascade — child records remain for audit; application layer filters
- `reversed_by_document_id` on source documents must reference a POSTED reversal document — enforced by posting engine
- Cash Sales and Cash Purchases must NOT create `subsidiary_ledger_entries` — enforced by posting rule sets for those transaction types
- `party_merge_logs` source record must be soft-deleted after merge — enforced by merge Edge Function

---

## 22. Compliance Profile Chain

```
companies (1)
  └── company_compliance_profiles (many — versioned by effective_from / effective_to)
        ├── taxpayer_type → drives VAT vs Percentage Tax behavior
        ├── income_tax_regime → drives ITR form (1701Q/1701 vs 1702Q/1702RT)
        └── legal_type → drives registration requirements and compliance reminders
```

Compliance profile lookup: always SELECT WHERE `company_id = ? AND effective_from <= document_date AND (effective_to IS NULL OR effective_to > document_date)`.

```
companies (1)
  └── company_feature_settings (1)
        ├── inventory_enabled → shows/hides Inventory module
        ├── fixed_assets_enabled → shows/hides Fixed Assets module
        ├── petty_cash_enabled → shows/hides Petty Cash module
        ├── bank_recon_enabled → shows/hides Bank Reconciliation module
        └── budgeting_enabled → shows/hides Budget module
```

---

## 23. Percentage Tax Chain (NON-VAT Companies)

```
sales_invoices / cash_sales (posted, company is NON-VAT)
        │
        ├── percentage_tax_entries (per transaction)
        │
        └── percentage_tax_period_summaries (aggregated per fiscal period)
                │
                └── percentage_tax_return_filings (2551Q — one per quarter)
                        │
                        └── export_jobs (2551Q DAT/PDF export)
```

---

## 24. FWT / 1601FQ Chain

```
vendor_bills / cash_purchases / payments (FWT-subject, WF-series ATC)
        │
        ├── fwt_entries (per transaction line)
        │
        ├── certificates_2306_issued (per payee, per quarter)  ← canonical: certificates_2306_issued (was: certificates_2306)
        │
        └── fwt_remittances_1601fq (1601FQ — one per quarter)
                │
                └── export_jobs (1601FQ export)
```

---

## 25. Income Tax Return Filing Chain (v3 — Updated)

```
income_tax_return_filings (1 per company per period)
  │   form_code: '1701Q'|'1701' (sole_proprietor/individual)
  │   form_code: '1702Q'|'1702RT' (corporation/OPC/partnership)
  │
  ├── itr_computation_runs (1+ per filing — on-demand computation)
  │     │
  │     ├── income_tax_computation_lines (per COA account, per run)
  │     │
  │     └── book_tax_reconciliations (reconciling items per run)
  │
  ├── nolco_tracking (1 per fiscal_year — carries forward across filings)
  │
  ├── tax_credits_schedules (2307/2306 credits applied to this filing)
  │
  └── export_jobs (ITR DAT/PDF export)

REMOVED (v3): itr_working_papers → replaced by itr_computation_runs
REMOVED (v3): mcit_computations → subsumed into itr_computation_runs.mcit_amount + income_tax_computation_lines (is_mcit_gross_income flag)
REMOVED (v3): nolco_schedules → replaced by nolco_tracking
```

---

## 26. Amortization Schedule Chain (Enhancement Round)

```
vendor_bills / cash_purchases (prepaid payment)
        │
        └── amortization_schedules (1 per prepaid item)
              │   prepaid_account_id → chart_of_accounts
              │   expense_account_id → chart_of_accounts
              │   source_document_id → vendor_bills or cash_purchases
              │
              └── amortization_schedule_lines (1 per period — pre-computed)
                    │
                    └── amortization_runs (batch header, 1 per period run)
                          │
                          └── amortization_run_details (1 per line per run)
                                │
                                └── journal_entries (je_type='amortization')
                                      │   amortization_run_detail_id → run_detail
                                      └── journal_lines → gl_balances

DR Prepaid Expense (on payment)
CR Cash / AP

Monthly amortization run:
DR [expense_account_id] — period_amount
CR [prepaid_account_id] — period_amount
```

---

## 27. Revenue Recognition Schedule Chain (Enhancement Round)

```
sales_invoices / cash_sales (advance billing)
        │
        └── revenue_recognition_schedules (1 per contract)
              │   deferred_revenue_account_id → chart_of_accounts
              │   revenue_account_id → chart_of_accounts
              │   source_document_id → sales_invoices or cash_sales
              │   customer_id → customers
              │
              └── revenue_recognition_schedule_lines (1 per period — pre-computed)
                    │
                    └── revenue_recognition_runs (batch header, 1 per period run)
                          │
                          └── revenue_recognition_run_details (1 per line per run)
                                │
                                └── journal_entries (je_type='revenue_recognition')
                                      │   revenue_recognition_run_detail_id → run_detail
                                      └── journal_lines → gl_balances

DR AR / Cash (on billing)
CR Deferred Revenue

Monthly recognition run:
DR [deferred_revenue_account_id] — period_amount
CR [revenue_account_id] — period_amount
```

---

## 28. Auto Reversal Chain (Enhancement Round)

```
journal_entries (original — auto_reversal_flag=true, auto_reversal_date set)
        │
        └── auto_reversal_runs (batch header, 1 per period)
              │
              └── journal_entries (is_auto_reversal=true)
                    │   reversal_of_je_id → original JE
                    │   auto_reversal_run_id → run
                    └── journal_lines (DR/CR swapped from original)

Accrual pattern (no accrual_schedules table needed):
  recurring_journal_templates (auto_reverse=true)
    → [Recurring Run] → journal_entries (auto_reversal_flag=true)
    → [Auto Reversal Run at next period start] → reversal journal_entries
```

---

### Customer Party Classification Chain (v3)

```
customers
  ├── vat_registration_status: 'vat' | 'non_vat'   (VAT registration only)
  └── party_special_class: NULL | 'government' | 'peza' | 'boi' | 'foreign_entity'

Posting engine reads party_special_class:
  └── if 'government' → vat_entries.vat_classification = 'government' (DERIVED, not stored on line)
```
