# Customer Lookup Usage

## 1. Overview
The Customer Master acts as a heavy consumer of the `ErpLookupHelper` framework. Rather than utilizing `<select>` boxes which break when tables exceed 500 rows, all relational data will be mapped via modal-driven lookups.

## 2. Implemented Lookups (Phase 5B)
| Target Table | Lookup Name | Purpose in Customer Master |
|--------------|-------------|----------------------------|
| `currencies` | Default Currency | Sets the default billing currency for AR invoices. |
| `chart_of_accounts` | Default AR Account | Tells the Posting Engine where to debit receivables. |
| `chart_of_accounts` | Default Sales Account | Tells the Posting Engine where to credit revenue. |

## 3. Future Lookups (Post-Phase 5)
| Target Table | Lookup Name | Purpose in Customer Master |
|--------------|-------------|----------------------------|
| `payment_terms`| Payment Terms | Automatically calculates due dates on sales orders. |
| `tax_codes` | Default Tax Code | Overrides standard VAT rates for specific customers. |
| `employees` | Salesperson | Attributes revenue to specific sales reps for commissions. |
| `customer_groups` | Customer Group | Categorizes customers for aggregated sales reporting. |
| `industries` | Industry | Categorizes customers for demographic analysis. |
| `warehouses` | Default Shipping Warehouse | Sets which warehouse fulfills this customer's orders by default. |
| `price_lists` | Price List | Assigns specific tier pricing (e.g. Wholesale vs Retail). |
| `shipping_methods` | Default Carrier | Specifies LBC, J&T, etc. |
