# PXL ERP — Relationship Map
**Version:** 1.0 — Blueprint Locked  
**Status:** For CPA and Developer Review

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
        └── atp_usage_logs (many)
```

### Approval
```
approval_matrix (1)
  └── approval_matrix_steps (many)
        
approval_requests (1)
  ├── approval_matrix
  ├── [any source document]
  └── approval_actions (many)
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
  ├── customer_tax_profiles (1:1)
  ├── customer_addresses (many)
  ├── customer_contacts (many)
  └── customer_credit_terms ──► payment_terms
```

### Supplier
```
suppliers (1)
  ├── supplier_tax_profiles (1:1)
  ├── supplier_addresses (many)
  ├── supplier_contacts (many)
  └── supplier_payment_terms ──► payment_terms
```

### Item / Inventory
```
item_categories (1)
  └── items (many)
        ├── item_units_of_measure (many) ──► units_of_measure
        ├── item_warehouse_stock (many) ──► warehouses
        └── item_price_lists (many) ──► price_lists
              
warehouses (1)
  └── warehouse_locations (many)
```

### Fixed Assets
```
asset_categories (1)
  └── fixed_assets (many)
        └── asset_depreciation_schedule (many)
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
              │     │     └── vat_entries (output VAT applied)
              │     └── certificates_2307_received (many)
              │           └── chart_of_accounts (tax credit account)
              └── document_relationships (many, bidirectional)
```

### Sales Return
```
sales_invoices (original, POSTED)
  └── credit_memos (reversal document)
        └── credit_memo_lines
              └── vat_entries (negative VAT)
```

### Delivery
```
sales_orders (1)
  └── delivery_orders (many)
        └── delivery_order_lines (many)
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
              │     └── vat_entries (input VAT)
              │           └── ewt_entries (many, per ATC)
              └── payment_vouchers (many, via bill_id)
                    ├── payment_voucher_lines (many)
                    │     └── ewt_entries (EWT deducted on payment)
                    └── certificates_2307_issued (many)
                          └── [supplier TIN, ATC, quarter]
```

### Goods Receipt
```
purchase_orders (1)
  └── goods_receipts (many)
        └── goods_receipt_lines (many)
              └── inventory_movements (IN)
                    └── inventory_cost_layers (FIFO)
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

```
company_bank_accounts (1)
  ├── bank_deposits (many)
  │     └── bank_deposit_lines (many)
  │           └── receipts (applied)
  ├── bank_withdrawals (many)
  │     └── payment_vouchers (applied)
  ├── bank_transfers (many)
  │     ├── company_bank_accounts (source)
  │     └── company_bank_accounts (destination)
  └── bank_reconciliations (many)
        └── bank_reconciliation_lines (many)
              ├── bank_statements_lines (imported)
              └── [matched transaction: receipt | payment_voucher | journal_entry]
```

---

## 8. Inventory Relationships

```
inventory_movements (1)
  ├── items
  ├── warehouses
  ├── [source: goods_receipt | delivery_order | adjustment | transfer]
  └── inventory_cost_layers (many, FIFO)
        └── inventory_cost_layer_consumption (many)
              └── inventory_movements (consumption reference)

inventory_adjustments (1)
  └── inventory_adjustment_lines (many)
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
  ├── asset_depreciation_schedule (many)
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
  │  journal_entries (manual) | petty_cash_vouchers | bank_deposits
  │  bank_withdrawals | inventory_adjustments | depreciation_runs
  │
  ▼
posting_rules (1)
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
              ├── [ar_ledger | ap_ledger | inventory_ledger | fixed_asset_ledger]
              └── [customer | supplier | item | fixed_asset] (entity ref)
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
  └── relationship_type (e.g., 'BILLED_FROM', 'REVERSED_BY', 'PAID_BY')
```

---

## 11. Compliance Relationships

### VAT Chain

```
sales_invoice_lines / vendor_bill_lines
  └── vat_entries (1:1 per taxable line)
        └── vat_summary_period (aggregated per period)
              └── [BIR Form 2550M input | SLSP line | RELIEF line]
```

### EWT Chain

```
vendor_bill_lines / payment_voucher_lines
  └── ewt_entries (many per line, one per ATC code)
        ├── certificates_2307_issued (quarterly aggregate per supplier)
        │     └── [2307 PDF generation]
        └── ewt_remittance (1601EQ filing per period)
              ├── qap_entries (quarterly alphalist)
              └── sawt_entries (summary alphalist)
```

### 2307 Received Chain

```
receipts / payment_vouchers_received
  └── certificates_2307_received (per customer, per quarter)
        └── tax_credits_schedule (income tax return input)
              └── [SAWT export]
```

### SLSP / RELIEF Chain

```
sales_invoice_lines + customer TIN + vat_entries
  └── slsp_entries (per invoice, per period)
        └── slsp_summary (period totals)

vendor_bill_lines + supplier TIN + vat_entries
  └── relief_entries (per bill, per period)
        └── relief_summary (period totals)
```

---

## 12. Audit Trail Relationships

```
[Any table row change]
  └── field_change_history
        ├── table_name
        ├── record_id
        ├── field_name
        ├── old_value
        ├── new_value
        └── changed_by ──► auth.users

[Any user action]
  └── audit_logs
        ├── event_type
        ├── entity_type
        ├── entity_id
        └── performed_by ──► auth.users

[Any document voided]
  └── document_void_register
        ├── [source document ref]
        ├── void_reason
        ├── voided_by
        └── journal_entries (reversal JE generated)
```

---

## 13. Import Relationships

```
import_batches (1)
  ├── import_rows (many)
  │     └── import_validation_errors (many)
  └── [created records carry import_batch_id]
        examples: customers, suppliers, items, chart_of_accounts
                  opening_balance_entries, inventory_opening_stock
```

---

## 14. Many-to-Many Bridge Tables Summary

| Bridge Table | Left Side | Right Side | Purpose |
|---|---|---|---|
| `user_company_access` | auth.users | companies | Which companies a user can access |
| `user_branch_access` | auth.users | branches | Which branches a user can access |
| `user_roles` | auth.users | roles | Role assignments per user |
| `role_permissions` | roles | permissions | Which permissions each role has |
| `item_units_of_measure` | items | units_of_measure | UOM conversions per item |
| `item_price_lists` | items | price_lists | Pricing per item per list |
| `approval_matrix_steps` | approval_matrix | auth.users/roles | Approver assignments |
| `bank_reconciliation_lines` | bank_reconciliations | transactions | Matched/unmatched lines |
| `document_relationships` | documents | documents | Cross-document traceability |
| `qap_entries` | ewt_remittance | suppliers | Per-payee alphalist entries |
| `sawt_entries` | tax_filing | customers | Summary alphalist of WHT |

---

## 15. Key Constraints

- Every `journal_entries` record must have `SUM(journal_lines.debit_amount) = SUM(journal_lines.credit_amount)` — enforced by posting engine before commit
- Every `fiscal_period_id` on posted entries must reference an OPEN period in `fiscal_locks` — enforced by trigger
- `number_series.current_number` must never exceed `max_number` (ATP limit) — enforced by series allocation function
- `deleted_at` on parent records does NOT cascade — child records remain for audit; application layer filters
- `reversed_by_document_id` on source documents must reference a POSTED reversal document — enforced by posting engine
