# Customer Field Justification

## Core Identity Fields
| Field | Purpose | Required | Future Usage | Who Uses It | Deferrable? |
|-------|---------|----------|--------------|-------------|-------------|
| `code` | Unique human-readable identifier (e.g. CUST-0001). | Yes | Autonumber generation. | Everyone | No |
| `entity_type` | Corporate vs Individual. | Yes | Drives EWT tax rate logic and naming format. | Accounting, BIR | No |
| `registered_name` | The exact SEC/DTI registered name. | Yes (if Corp) | BIR Relief/Alpha Lists (SLSP). | Tax Accountant | No |
| `trade_name` | Doing Business As (DBA) name for invoices. | No | Invoice printing. | AR, Sales | No |
| `first_name` / `last_name` | Individual identity. | Yes (if Indv) | Form 2307, Alpha Lists. | Tax Accountant | No |

## Tax & Compliance Fields
| Field | Purpose | Required | Future Usage | Who Uses It | Deferrable? |
|-------|---------|----------|--------------|-------------|-------------|
| `tin` | Taxpayer Identification Number. | No (Walk-ins) | CAS Audit, SLSP. | Accounting | No |
| `tin_suffix` | Branch Code (usually 00000). | No | BIR Data Files. | Accounting | No |
| `tax_type` | VAT, Non-VAT, Exempt, Zero-Rated. | Yes | Automatically drives invoice tax computations. | AR, System | No |
| `classification` | PEZA, BOI, Gov. | No | Reporting and Zero-Rated justifications. | Tax Accountant | Yes |

## Financial Default Fields
| Field | Purpose | Required | Future Usage | Who Uses It | Deferrable? |
|-------|---------|----------|--------------|-------------|-------------|
| `currency_id` | Billing currency default. | No | Multi-currency AR. | Sales, AR | Yes |
| `payment_term_id` | Due date calculation. | No | AR Aging computations. | Credit Manager | Yes |
| `default_ar_account_id` | Specific AR ledger mapping. | No | Posting Engine. | Financial Controller| Yes |
| `default_sales_account_id`| Specific income mapping. | No | Item/Customer matrix posting. | Controller | Yes |
| `tax_code_id` | Specific tax override. | No | Complex tax setups. | Accounting | Yes |

## Credit Management Fields
| Field | Purpose | Required | Future Usage | Who Uses It | Deferrable? |
|-------|---------|----------|--------------|-------------|-------------|
| `credit_limit` | Max outstanding AR allowed. | No | Sales Order blocking. | Credit Manager | Yes |
| `credit_hold` | Manually freeze account. | No | Stop order fulfillment. | Credit Manager | Yes |

## Organizational Fields
| Field | Purpose | Required | Future Usage | Who Uses It | Deferrable? |
|-------|---------|----------|--------------|-------------|-------------|
| `customer_group_id` | Hierarchical rollups/pricing. | No | Discount matrixes. | Sales Manager | Yes |
| `salesperson_id` | Commission tracking. | No | Payroll integrations. | Sales Manager | Yes |
