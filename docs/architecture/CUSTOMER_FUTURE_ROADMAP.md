# Customer Future Roadmap

## 1. Transactional Interconnectivity
The Customer Master is the anchor for the entire Sales lifecycle. In future phases, `customer_id` will be the primary foreign key on:
- **Quotations** -> **Sales Orders** -> **Delivery Receipts** -> **Sales Invoices**
- **Accounts Receivable Ledgers** -> **Customer Statements** -> **Aging Reports**

## 2. The Accounting Engine Link
Because the Customer Master defines `default_ar_account_id` and `default_sales_account_id`, the future **Posting Engine** will intercept sales invoices, locate the customer, and dynamically generate journal entries debiting the mapped AR account and crediting the mapped Sales account. 

## 3. Compliance Generation Link
During the generation of **Form 2307** or **SLSP / QAP** DAT files, the compliance engine will query the Customer Master to pull the exact `registered_name`, `tin`, and `tin_suffix`. Any typo in the Customer Master propagates directly into BIR penalties, emphasizing why strict field-level validation is required at the Master Data level.

## 4. Sub-Ledger vs General Ledger
Customers in PXL ERP act as **Sub-Ledgers**. The General Ledger handles aggregate AR. The Customer Master handles individual AR. 
Future collections modules will rely on `customer_id` to match incoming bank receipts against outstanding sales invoices.
