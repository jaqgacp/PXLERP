# PXL ERP — Security & RLS Design
**Version:** 2.0 — Revised for Implementation Readiness
**Status:** For CPA and Developer Review

---

## Changes Applied (v1 → v2)

- Fixed `profiles.full_name` → `profiles.first_name` + `profiles.last_name` (v2 column standard; virtual `full_name` can be computed)
- Added notification-related permissions to permission matrix: `notifications.view`, `notifications.manage`
- Added `system_alerts.view` permission
- Added `document_template.manage` permission for controllers
- Added `cash_sales.*` and `cash_purchases.*` permissions (new transaction types)
- Updated Supabase Realtime list: added `notifications` and `system_alerts` (ATP gap alerts)
- Added `NOTIFICATIONS` section to permission matrix
- Added `CASH_TRANSACTIONS` section to permission matrix
- Added `TAX_ACCOUNTANT` role: clarified it can manage compliance exports and generate 2307s
- Aligned role descriptions with 11 system-seeded roles confirmed in v2
- Added `export_jobs` and `import_batches` to Realtime list (were referenced in doc 01 but not explicit here)

---

## Open Decisions Remaining

| OD # | Question | Status |
|---|---|---|
| OD-19 | Should `system_alerts` have its own RLS policy scoped to COMPANY_ADMIN and CONTROLLER roles only? | Recommended: Yes. Regular users should not see ATP gap alerts. Confirm before RLS migration. |
| OD-20 | Should `notifications` RLS allow users to only SELECT their own notifications (recipient = auth.uid())? | Recommended: Yes — user can only see their own notifications. Company admins can see all. |

---

## Implementation Notes

- `auth.user_company_ids()` is on the hot path of every RLS policy — it must be indexed on `user_company_access(user_id, is_active, revoked_at)`.
- `auth.has_permission()` adds one sub-query per DML check. For high-volume tables, consider caching permission lookups in the JWT claim (Phase 2) or using role-check triggers in Edge Functions instead.
- Service role is used by all Edge Functions (posting engine, import engine, notification dispatch, compliance exports). The service role key must NEVER be exposed to the client.
- Super admin (`profiles.is_super_admin = true`) bypasses company RLS for platform-level administration only. Super admins cannot post transactions.
- Hard DELETE is REVOKE'd on all app roles. Only the service role via migrations can hard-delete, and only for cleanup of test data.

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
| `first_name` | text | NOT NULL | |
| `last_name` | text | NOT NULL | |
| `display_name` | text | NULL | Optional nickname/alias |
| `avatar_url` | text | NULL | Supabase Storage path |
| `phone` | text | NULL | |
| `job_title` | text | NULL | |
| `is_active` | boolean | NOT NULL DEFAULT true | |
| `is_super_admin` | boolean | NOT NULL DEFAULT false | Platform-level admin (not company admin) |
| `created_at` | timestamptz | NOT NULL DEFAULT now() | |
| `updated_at` | timestamptz | NULL | |
| `last_login_at` | timestamptz | NULL | |
| `timezone` | text | NOT NULL DEFAULT 'Asia/Manila' | |
| `locale` | text | NOT NULL DEFAULT 'en-PH' | |

> `full_name` is a computed expression `first_name || ' ' || last_name` — not a stored column.

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
-- audit_logs, field_change_history, atp_usage_logs, document_void_register:
-- SELECT: yes (users can read logs for their companies)
-- INSERT: yes (via trigger / edge function using service role)
-- UPDATE: no
-- DELETE: no
```

#### Immutable Posted Documents

```sql
-- Additional policy on posted documents (sales_invoices, vendor_bills, cash_sales, cash_purchases, etc.):
CREATE POLICY "{table_name}_no_update_if_posted" ON {table_name}
  FOR UPDATE USING (
    status NOT IN ('POSTED', 'VOIDED', 'REVERSED')
  );
```

#### Journal Entries (Service Role Only for Writes)

```sql
-- journal_entries: application users may only view, not insert/update directly
-- Manual JEs go through the journal_entry UI which calls the posting edge function
-- Posting engine uses service role to write journal entries
```

#### GL Balances (Service Role Only)

```sql
-- gl_balances: application users have SELECT only
-- All writes done by posting engine via service role
```

#### Notifications (Own Records Only)

```sql
-- notifications: user can only SELECT rows where recipient_user_id = auth.uid()
-- Company admins can SELECT all notifications for their company
CREATE POLICY "notifications_select_own" ON notifications
  FOR SELECT USING (
    recipient_user_id = auth.uid()
    OR (
      company_id = ANY(auth.user_company_ids())
      AND auth.has_permission('notifications.manage', company_id)
    )
  );
```

#### System Alerts (Admin/Controller Only)

```sql
-- system_alerts: visible only to COMPANY_ADMIN and CONTROLLER roles
CREATE POLICY "system_alerts_select" ON system_alerts
  FOR SELECT USING (
    company_id = ANY(auth.user_company_ids())
    AND (
      auth.has_permission('system_alerts.view', company_id)
    )
  );
```

---

## 4. Permission Matrix (Reference)

### Sales & Cash Transactions

| Permission Code | Who Needs It |
|---|---|
| `sales_invoice.view` | AR Clerk, Accountant, Auditor |
| `sales_invoice.create` | AR Clerk, Sales |
| `sales_invoice.edit` | AR Clerk (DRAFT only) |
| `sales_invoice.post` | Accountant, Controller |
| `sales_invoice.void` | Controller |
| `cash_sale.create` | AR Clerk, Sales |
| `cash_sale.post` | Accountant, Controller |
| `cash_sale.void` | Controller |

### Purchasing & Cash Purchases

| Permission Code | Who Needs It |
|---|---|
| `vendor_bill.view` | AP Clerk, Accountant, Auditor |
| `vendor_bill.create` | AP Clerk, Purchasing |
| `vendor_bill.post` | Accountant, Controller |
| `cash_purchase.create` | AP Clerk, Purchasing |
| `cash_purchase.post` | Accountant, Controller |
| `cash_purchase.void` | Controller |
| `payment_voucher.approve` | Approver, Controller |

### Accounting & GL

| Permission Code | Who Needs It |
|---|---|
| `journal_entry.create` | Accountant |
| `journal_entry.post` | Controller |
| `gl.view` | Accountant, Controller, Auditor |
| `gl.close_period` | Controller |

### Compliance & Tax

| Permission Code | Who Needs It |
|---|---|
| `compliance.vat.export` | Tax Accountant, Controller |
| `compliance.ewt.export` | Tax Accountant, Controller |
| `compliance.dat.generate` | Controller |
| `compliance.2307.generate` | Tax Accountant, Controller |
| `compliance.1601eq.file` | Tax Accountant, Controller |

### Settings & Admin

| Permission Code | Who Needs It |
|---|---|
| `settings.users.manage` | Company Admin |
| `settings.roles.manage` | Company Admin |
| `settings.coa.manage` | Controller |
| `settings.approval.manage` | Company Admin, Controller |
| `settings.document_templates.manage` | Controller |
| `import.execute` | Company Admin, Controller |
| `audit.view` | Auditor, Company Admin |

### Notifications & Alerts

| Permission Code | Who Needs It |
|---|---|
| `notifications.view` | All authenticated users (own notifications) |
| `notifications.manage` | Company Admin (all notifications) |
| `system_alerts.view` | Company Admin, Controller |

---

## 5. System Roles (Seeded)

| Role Code | Description | Key Permissions |
|---|---|---|
| `COMPANY_ADMIN` | Company administrator | All settings, user management, system alerts |
| `CONTROLLER` | Financial controller | Post, close periods, compliance exports, document templates |
| `ACCOUNTANT` | General accountant | Create/post JEs, view all GL |
| `AR_CLERK` | Accounts receivable | Sales invoices, cash sales, receipts |
| `AP_CLERK` | Accounts payable | Vendor bills, cash purchases, payment vouchers |
| `PURCHASING` | Purchasing officer | Purchase orders, goods receipts |
| `SALES` | Sales officer | Sales orders, delivery orders, cash sales (create) |
| `APPROVER` | Document approver | Approve workflow items |
| `INVENTORY_CLERK` | Inventory | Adjustments, stock transfers |
| `AUDITOR` | Read-only auditor | View all, audit logs |
| `TAX_ACCOUNTANT` | Tax compliance | All compliance exports, generate 2307, 1601EQ filing |

---

## 6. Supabase-Specific Notes

| Feature | Configuration |
|---|---|
| **Service Role** | Used by Edge Functions for posting engine, import engine, compliance exports, notification dispatch. Never exposed to client. |
| **Anon Role** | No access to any operational table. Only public company registration flow. |
| **Auth JWT** | `auth.uid()` used in all RLS policies. Company/branch IDs looked up from access tables, not stored in JWT claims. |
| **Realtime** | Enabled on: `approval_requests`, `approval_actions`, `export_jobs`, `import_batches`, `notifications`, `system_alerts`. NOT enabled on ledger, audit, or compliance tables. |
| **MFA** | Supabase Auth MFA (TOTP) — required for COMPANY_ADMIN and CONTROLLER roles. |

---

## 7. Data Isolation Guarantees

1. **Company isolation**: Every SELECT, INSERT, UPDATE, DELETE on operational tables requires `company_id IN (user_company_ids())`.
2. **Branch filtering**: UI and reports additionally filter by `user_branch_ids()` where applicable.
3. **No cross-company reads**: Helper function `auth.user_company_ids()` returns only explicitly granted companies.
4. **Super admin access**: `profiles.is_super_admin = true` bypasses company RLS for platform administration only. Super admin cannot post transactions.
5. **Posted document immutability**: Enforced at both trigger level (raises exception) and RLS level (UPDATE policy excludes posted/voided/reversed rows).
6. **Audit table integrity**: `audit_logs` and `field_change_history` are written only by service role via triggers and Edge Functions. Application users have SELECT only.
7. **Notification isolation**: Users can only read their own notifications. Company admins with `notifications.manage` can read all.
8. **Cash Sales / Cash Purchases**: Same RLS pattern as sales_invoices and vendor_bills — `company_id` scoped, `has_permission` checked on INSERT.
