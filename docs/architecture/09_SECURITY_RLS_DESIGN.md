# PXL ERP — Security & RLS Design
**Version:** 1.0 — Blueprint Locked  
**Status:** For CPA and Developer Review

---

## 1. Overview

PXL ERP uses Supabase's built-in Row Level Security (RLS) as the primary tenant isolation mechanism. Every operational table with `company_id` has RLS policies that restrict access to rows belonging to companies the authenticated user is authorized to access.

---

## 2. Security Tables

### `profiles`
Extended user profile linked to `auth.users`.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK, FK auth.users | Same UUID as auth.users |
| `full_name` | text | NOT NULL | |
| `display_name` | text | NULL | |
| `avatar_url` | text | NULL | Supabase Storage path |
| `phone` | text | NULL | |
| `job_title` | text | NULL | |
| `is_active` | boolean | NOT NULL DEFAULT true | |
| `is_super_admin` | boolean | NOT NULL DEFAULT false | Platform-level admin (not company admin) |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |
| `updated_at` | timestamptz | | |
| `last_login_at` | timestamptz | NULL | |
| `timezone` | text | NOT NULL DEFAULT 'Asia/Manila' | |
| `locale` | text | NOT NULL DEFAULT 'en-PH' | |

---

### `user_company_access`
Which companies a user can access and their role within each company.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `user_id` | uuid | FK auth.users, NOT NULL | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `is_company_admin` | boolean | NOT NULL DEFAULT false | Can manage company settings |
| `is_active` | boolean | NOT NULL DEFAULT true | |
| `granted_by` | uuid | FK auth.users, NOT NULL | |
| `granted_at` | timestamptz | NOT NULL DEFAULT now() | |
| `revoked_at` | timestamptz | NULL | |
| `revoked_by` | uuid | FK auth.users, NULL | |

UNIQUE: `(user_id, company_id)`

---

### `user_branch_access`
Which branches within a company a user can access.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `user_id` | uuid | FK auth.users, NOT NULL | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `branch_id` | uuid | FK branches, NOT NULL | |
| `is_active` | boolean | NOT NULL DEFAULT true | |
| `granted_by` | uuid | FK auth.users, NOT NULL | |
| `granted_at` | timestamptz | NOT NULL DEFAULT now() | |

UNIQUE: `(user_id, branch_id)`

---

### `roles`
Role definitions per company (company-specific roles + system roles).

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `company_id` | uuid | FK companies, NULL | NULL = system-wide role |
| `role_code` | text | NOT NULL | e.g., 'ACCOUNTANT', 'AP_CLERK', 'APPROVER' |
| `role_name` | text | NOT NULL | Display name |
| `description` | text | NULL | |
| `is_system` | boolean | NOT NULL DEFAULT false | System roles cannot be deleted |
| `is_active` | boolean | NOT NULL DEFAULT true | |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |
| `created_by` | uuid | FK auth.users, NULL | |

---

### `permissions`
Granular permission definitions.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `permission_code` | text | UNIQUE, NOT NULL | e.g., 'sales_invoice.create', 'gl.post', 'vat.export' |
| `module` | text | NOT NULL | e.g., 'sales', 'purchasing', 'accounting', 'compliance' |
| `action` | text | NOT NULL | 'view' \| 'create' \| 'edit' \| 'delete' \| 'approve' \| 'post' \| 'void' \| 'export' \| 'admin' |
| `resource` | text | NOT NULL | e.g., 'sales_invoice', 'journal_entry', 'vat_report' |
| `description` | text | NOT NULL | |

---

### `role_permissions`
Which permissions each role has.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `role_id` | uuid | FK roles, NOT NULL | |
| `permission_id` | uuid | FK permissions, NOT NULL | |
| `granted_at` | timestamptz | NOT NULL DEFAULT now() | |
| `granted_by` | uuid | FK auth.users, NOT NULL | |

UNIQUE: `(role_id, permission_id)`

---

### `user_roles`
Role assignments per user per company.

| Column | Type | Constraint | Description |
|---|---|---|---|
| `id` | uuid | PK | |
| `user_id` | uuid | FK auth.users, NOT NULL | |
| `role_id` | uuid | FK roles, NOT NULL | |
| `company_id` | uuid | FK companies, NOT NULL | |
| `branch_id` | uuid | FK branches, NULL | NULL = applies to all branches |
| `granted_by` | uuid | FK auth.users, NOT NULL | |
| `granted_at` | timestamptz | NOT NULL DEFAULT now() | |
| `expires_at` | timestamptz | NULL | Temporary role grants |
| `revoked_at` | timestamptz | NULL | |
| `revoked_by` | uuid | FK auth.users, NULL | |
| `is_active` | boolean | NOT NULL DEFAULT true | |

UNIQUE active: `(user_id, role_id, company_id, branch_id)` where `is_active = true`

---

## 3. RLS Policy Design

### Core Helper Functions

```sql
-- Returns company_ids the current user has access to
CREATE OR REPLACE FUNCTION auth.user_company_ids()
RETURNS uuid[] LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT ARRAY(
    SELECT company_id FROM user_company_access
    WHERE user_id = auth.uid()
      AND is_active = true
      AND revoked_at IS NULL
  );
$$;

-- Returns branch_ids the current user has access to
CREATE OR REPLACE FUNCTION auth.user_branch_ids()
RETURNS uuid[] LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT ARRAY(
    SELECT branch_id FROM user_branch_access
    WHERE user_id = auth.uid()
      AND is_active = true
  );
$$;

-- Checks if user has a specific permission in a company
CREATE OR REPLACE FUNCTION auth.has_permission(p_permission_code text, p_company_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1
    FROM user_roles ur
    JOIN role_permissions rp ON rp.role_id = ur.role_id
    JOIN permissions p ON p.id = rp.permission_id
    WHERE ur.user_id = auth.uid()
      AND ur.company_id = p_company_id
      AND ur.is_active = true
      AND (ur.expires_at IS NULL OR ur.expires_at > now())
      AND p.permission_code = p_permission_code
  );
$$;
```

---

### Standard RLS Policy Template

Applied to every table with `company_id`:

```sql
-- Enable RLS
ALTER TABLE {table_name} ENABLE ROW LEVEL SECURITY;

-- SELECT: user must have access to the company
CREATE POLICY "{table_name}_select" ON {table_name}
  FOR SELECT USING (
    company_id = ANY(auth.user_company_ids())
  );

-- INSERT: user must have access to the company + permission check
CREATE POLICY "{table_name}_insert" ON {table_name}
  FOR INSERT WITH CHECK (
    company_id = ANY(auth.user_company_ids())
    AND auth.has_permission('{module}.{resource}.create', company_id)
  );

-- UPDATE: company access + permission + not immutable
CREATE POLICY "{table_name}_update" ON {table_name}
  FOR UPDATE USING (
    company_id = ANY(auth.user_company_ids())
  ) WITH CHECK (
    company_id = ANY(auth.user_company_ids())
    AND auth.has_permission('{module}.{resource}.edit', company_id)
  );

-- DELETE: soft delete only (no hard delete via RLS)
-- Hard delete is blocked by REVOKE DELETE on all app roles
```

---

### Special RLS Policies

#### Audit Tables (Insert-Only)

```sql
-- audit_logs, field_change_history, atp_usage_logs:
-- SELECT: yes (users can read logs for their companies)
-- INSERT: yes (via trigger / edge function using service role)
-- UPDATE: no
-- DELETE: no
```

#### Immutable Posted Documents

```sql
-- Additional policy on posted documents (sales_invoices, vendor_bills, etc.):
CREATE POLICY "{table_name}_no_update_if_posted" ON {table_name}
  FOR UPDATE USING (
    status != 'POSTED'
    AND status != 'VOIDED'
    AND status != 'REVERSED'
  );
```

#### Journal Entries (Auto-Posted Only)

```sql
-- journal_entries UPDATE restricted to status transition only:
-- Posting engine uses service role to write journal entries
-- Application users may only view, not insert/update directly
-- Manual JEs go through the journal_entries UI which calls the posting edge function
```

#### GL Balances (Service Role Only)

```sql
-- gl_balances: application users have SELECT only
-- All writes done by posting engine via service role
```

---

## 4. Permission Matrix (Reference)

| Permission Code | Who Needs It |
|---|---|
| `sales_invoice.view` | AR Clerk, Accountant, Auditor |
| `sales_invoice.create` | AR Clerk, Sales |
| `sales_invoice.edit` | AR Clerk (DRAFT only) |
| `sales_invoice.post` | Accountant, Controller |
| `sales_invoice.void` | Controller, CFO |
| `vendor_bill.view` | AP Clerk, Accountant, Auditor |
| `vendor_bill.create` | AP Clerk, Purchasing |
| `vendor_bill.post` | Accountant, Controller |
| `payment_voucher.approve` | Approver, CFO |
| `journal_entry.create` | Accountant |
| `journal_entry.post` | Controller |
| `gl.view` | Accountant, Controller, Auditor |
| `gl.close_period` | Controller |
| `compliance.vat.export` | Tax Accountant, Controller |
| `compliance.ewt.export` | Tax Accountant, Controller |
| `compliance.dat.generate` | Controller, CAS Admin |
| `settings.users.manage` | Company Admin |
| `settings.roles.manage` | Company Admin |
| `settings.coa.manage` | Controller |
| `settings.approval.manage` | Company Admin, Controller |
| `import.execute` | Company Admin, Controller |
| `audit.view` | Auditor, Company Admin |

---

## 5. System Roles (Seeded)

| Role Code | Description | Key Permissions |
|---|---|---|
| `COMPANY_ADMIN` | Company administrator | All settings, user management |
| `CONTROLLER` | Financial controller | Post, close periods, compliance exports |
| `ACCOUNTANT` | General accountant | Create/post JEs, view all GL |
| `AR_CLERK` | Accounts receivable | Sales invoices, receipts |
| `AP_CLERK` | Accounts payable | Vendor bills, payment vouchers |
| `PURCHASING` | Purchasing officer | Purchase orders, goods receipts |
| `SALES` | Sales officer | Sales orders, delivery orders |
| `APPROVER` | Document approver | Approve workflow items |
| `INVENTORY_CLERK` | Inventory | Adjustments, stock transfers |
| `AUDITOR` | Read-only auditor | View all, audit logs |
| `TAX_ACCOUNTANT` | Tax compliance | All compliance exports |

---

## 6. Supabase-Specific Notes

| Feature | Configuration |
|---|---|
| **Service Role** | Used by Edge Functions for posting engine, import engine, compliance exports. Never exposed to client. |
| **Anon Role** | No access to any operational table. Only public company registration flow. |
| **Auth JWT** | `auth.uid()` used in all RLS policies. Company/branch IDs looked up from access tables, not stored in JWT claims. |
| **Realtime** | Enabled only on: `approval_requests`, `approval_actions`, `export_jobs`, `import_batches`. Not enabled on ledger/audit tables. |
| **MFA** | Supabase Auth MFA (TOTP) — enabled for COMPANY_ADMIN and CONTROLLER roles. |

---

## 7. Data Isolation Guarantees

1. **Company isolation**: Every SELECT, INSERT, UPDATE, DELETE on operational tables requires `company_id IN (user_company_ids())`.
2. **Branch filtering**: UI and reports additionally filter by `user_branch_ids()` where applicable.
3. **No cross-company reads**: Helper function `auth.user_company_ids()` returns only explicitly granted companies.
4. **Super admin access**: `profiles.is_super_admin = true` bypasses company RLS for platform administration only. Super admin cannot post transactions.
5. **Posted document immutability**: Enforced at both trigger level (raises exception) and RLS level (UPDATE policy excludes posted rows).
6. **Audit table integrity**: `audit_logs` and `field_change_history` are written only by service role via triggers and Edge Functions. Application users have SELECT only.
