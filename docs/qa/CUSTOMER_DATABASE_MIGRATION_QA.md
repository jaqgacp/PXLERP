# Customer Master Database Migration QA (Phase 5B)

## 1. Migration Overview
- **Migration File:** `supabase/migrations/20260627155600_customer_master.sql`
- **Tables Handled:**
  - `public.customers` (Altered to conform to Phase 5B standard without breaking Phase 1 Sales referential integrity)
  - `public.customer_addresses` (Dropped & Recreated)
  - `public.customer_contacts` (Dropped & Recreated)

## 2. Table & Constraint Verifications
| Entity | Constraints Verified | Result |
|--------|----------------------|--------|
| `customers` | `entity_type IN ('corporation', 'individual', 'government', 'foreign')` | PASS |
| `customers` | `tax_type IN ('vat', 'non_vat', 'exempt', 'zero_rated', 'foreign')` | PASS |
| `customers` | `UNIQUE(company_id, id)` (Enables compound FKs) | PASS |
| `customers` | Partial `UNIQUE(company_id, code) WHERE deleted_at IS NULL` | PASS |
| `customer_addresses` | `address_type IN ('billing', 'shipping', 'registered', 'other')` | PASS |
| `customer_addresses` | `FOREIGN KEY (company_id, customer_id) REFERENCES customers(company_id, id)` (Company integrity lock) | PASS |
| `customer_contacts` | `FOREIGN KEY (company_id, customer_id) REFERENCES customers(company_id, id)` (Company integrity lock) | PASS |

## 3. Indexes Verified
- `customers`: `company_code_idx`, `company_id_idx`, `registered_name_idx`, `tin_idx`, `is_active_idx`, `import_batch_id_idx`
- `customer_addresses`: `company_id_idx`, `customer_id_idx`, `is_active_idx`, `import_batch_id_idx`
- `customer_contacts`: `company_id_idx`, `customer_id_idx`, `is_active_idx`, `import_batch_id_idx`

## 4. Security & RLS Policies Verified
- **RLS Status:** `ENABLE ROW LEVEL SECURITY` confirmed active on all three tables.
- **Policies (SELECT, INSERT, UPDATE):** Mapped precisely to `public.is_super_admin() OR company_id = ANY(public.user_company_ids())` for all three tables.
- **Grants:**
  - `authenticated`: `SELECT`, `INSERT`, `UPDATE`
  - `service_role`: `SELECT`, `INSERT`, `UPDATE`, `DELETE`

## 5. DB Reset Stability
- **`supabase db reset` Execution:** SUCCESS.
- **Dependency Test:** No Phase 1 tables (`sales_invoices`, `sales_orders`) were broken or dropped by this migration, proving the safety of the `ALTER TABLE` implementation strategy over a naive `DROP CASCADE`.

## 6. Verification Queries Run
**Tables:**
```json
[{"table_name": "customer_addresses"}, {"table_name": "customer_contacts"}, {"table_name": "customers"}]
```
**RLS Enabled:**
```json
[{"rowsecurity": true, "tablename": "customer_addresses"}, {"rowsecurity": true, "tablename": "customer_contacts"}, {"rowsecurity": true, "tablename": "customers"}]
```

## 7. Final Decision
**[ PASS ]** The Phase 5B database migration perfectly mirrors the approved architecture documents. No UI or App code was modified.
