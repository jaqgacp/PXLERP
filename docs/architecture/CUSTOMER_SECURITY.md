# Customer Security Blueprint

## 1. Row Level Security (RLS)
The database must mathematically prevent tenant data leakage. 
```sql
CREATE POLICY "Users can only view customers in their active company" 
ON public.customers 
FOR SELECT USING (
  company_id IN (
    SELECT company_id FROM public.user_company_access WHERE user_id = auth.uid()
  )
);
```
Sub-tables (`customer_addresses`, `customer_contacts`) will inherit this security via a JOIN condition to the parent `customers` table in their RLS policies.

## 2. Inactive Handling (Soft Delete)
- **Policy:** Hard deletion (`DELETE FROM customers`) is strictly forbidden by application logic and database triggers if any related transaction (e.g. Sales Invoice) exists.
- **Implementation:** Deactivating a customer sets `is_active = false`. Lookups (`ErpLookupHelper`) will append `.eq('is_active', true)` to their queries, preventing new transactions against inactive customers, while preserving historical referential integrity.

## 3. Merge Handling (Future Concept)
Enterprise systems inevitably face duplicated customers. 
- **Requirement:** A "Merge Customers" utility will be required later. It must remap all foreign keys (Invoices, Receipts, Addresses) from the `source_id` to the `target_id`, then soft-delete the `source_id`.

## 4. Audit Policy
- **Immutability of History:** Every table features `created_by` and `updated_by` mapped directly to the `profiles` table.
- **Future Audit Log:** Trigger-based auditing will eventually mirror all `UPDATE` payloads into a JSONB `audit_logs` table, maintaining a chronological history of changes to critical fields like `credit_limit`.
