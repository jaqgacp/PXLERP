# Customer Import Blueprint

## 1. Overview
The Customer Master will utilize the existing `ErpImportHelper` architecture. Because customers have multiple sub-tables (addresses, contacts), the initial import will focus strictly on the `customers` core table to establish the master records. Sub-table imports (e.g., Customer Addresses Import) will be distinct templates.

## 2. Columns & Mapping
| CSV Header | Database Column | Type | Validation / Default |
|------------|-----------------|------|----------------------|
| Customer Code | `code` | string | Required, unique per company. |
| Entity Type | `entity_type` | enum | Required (Corporate, Individual). |
| Registered Name | `registered_name`| string | Required. |
| Trade Name | `trade_name` | string | Optional. |
| TIN | `tin` | string | Optional. RegEx: `^\d{3}-\d{3}-\d{3}-\d{3}$` (if present) |
| TIN Suffix | `tin_suffix` | string | Optional. RegEx: `^\d{5}$` (if present) |
| Tax Type | `tax_type` | enum | Required (VAT, Non-VAT, Zero-Rated, Exempt) |
| Classification | `classification`| string | Optional. |
| Credit Limit | `credit_limit` | number | Optional. Defaults to 0. |

## 3. Lookup Resolution During Import
Standard import templates map raw text. Foreign keys (e.g., `currency_id`, `payment_term_id`) are notoriously difficult to import via UUID. 
**Blueprint Decision:** In Phase 5A, the Customer Import will *not* attempt to resolve text names to UUIDs for financial lookups. Users will import core data and mass-update financial defaults via the UI later, OR we will implement a backend resolution trigger for specific text columns like "Currency Code".

## 4. Duplicate Detection & Validation
- **Duplicate Check:** `['company_id', 'code']` and `['company_id', 'registered_name']`.
- **Batch Tracking:** The `ErpImportHelper` will automatically generate a UUID for the import session and append it to the `import_batch_id` column for audit and rollback capabilities.
- **Rollback:** Fully supported via `DELETE FROM customers WHERE import_batch_id = ?`.
