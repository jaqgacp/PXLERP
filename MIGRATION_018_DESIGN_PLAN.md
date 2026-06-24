# PXL ERP - Migration 018 Design Plan

Repository: `PXLERP`  
Branch reviewed: `main`  
Pre-check commit reviewed: `fe4d633afc61a6d1fb5ae06fcccfe6d3d3e67e14`
Plan date: 2026-06-24  
Mode: design plan only. No SQL, migration file, UI, CRUD, backlog edit, or decision-log edit is implemented by this document.

## 1. Executive Summary

Migration 018 must be a Phase 1 foundation reconciliation migration. It must not introduce CRUD, UI, seed data, cron jobs, or feature implementation.

Owner Decisions 016 and 017 are now the controlling scope:

- Phase 1 is not split into 1A / 1B.
- All 207 documented active architecture tables are required.
- The 29 documented active tables missing from migrations must be created before CRUD/UI continues.
- Adaptive Workspace is non-negotiable.
- The 11 approved adaptive-workspace metadata tables are part of Phase 1.
- `feature_definitions` is approved as the canonical feature catalog.
- Final Phase 1 active table target is 219 tables.
- No hardcoded roles, menus, dashboards, approval flows, or feature visibility.

Migration 018 therefore has six jobs:

1. Create the 29 missing documented Phase 1 tables.
2. Create the 11 approved adaptive-workspace metadata tables.
3. Create `feature_definitions` as the canonical feature catalog.
4. Enable RLS and create policies for every new table.
5. Add policies for the 12 existing migrated tables with RLS enabled but no policy.
6. Close pre-CRUD foundation security gaps: line immutability, service-owned mutable fields, and filed compliance rows.

Because this is large, the recommended implementation approach is to split the actual work into 018A-018E. This plan does not implement that split.

## 2. Table Creation List Grouped By Module

### Audit & CAS - 8 Tables

| Table | Purpose | Primary dependencies | RLS posture |
|---|---|---|---|
| `audit_logs` | Event audit log for significant actions. | `companies`, `profiles` | Company-scoped SELECT; service-role or controlled app INSERT; no UPDATE/DELETE. |
| `field_change_history` | Field-level old/new value history. | `companies`, `profiles`, `audit_logs` | Company-scoped SELECT; service-role INSERT; no UPDATE/DELETE. |
| `user_activity_logs` | Login, logout, report, export, print, settings activity. | `companies` nullable, `profiles` | Own/user activity or admin SELECT; service/app INSERT; no UPDATE/DELETE. |
| `system_parameter_logs` | System parameter change history. | `companies`, `profiles` | Admin/controller SELECT; service/admin INSERT; no UPDATE/DELETE. |
| `document_void_register` | BIR-traceable void register. | `companies`, `profiles`, optional `journal_entries` | Company-scoped compliance SELECT; service/controller INSERT; no UPDATE/DELETE. |
| `dat_generation_logs` | DAT generation history. | `companies`, `fiscal_years`, `profiles` | Compliance SELECT; service INSERT; no UPDATE/DELETE. |
| `export_history` | Report/data export history. | `companies`, `fiscal_periods`, `profiles` | Company-scoped SELECT; service INSERT; no UPDATE/DELETE. |
| `system_alerts` | Admin/controller operational alerts. | `companies`, `profiles` | SELECT only to authorized users; service INSERT/UPDATE resolution; no DELETE. |

### Attachments - 2 Tables

| Table | Purpose | Primary dependencies | RLS posture |
|---|---|---|---|
| `attachments` | Metadata for files in Supabase Storage. | `companies`; polymorphic source entity | Company-scoped SELECT; controlled INSERT/UPDATE; no DELETE unless soft-delete exists in spec. |
| `attachment_versions` | Version history for replaced files. | `companies`, `attachments`, `profiles` | Company-scoped SELECT; service INSERT; no UPDATE/DELETE. |

### Workflow & Approvals - 2 Tables

| Table | Purpose | Primary dependencies | RLS posture |
|---|---|---|---|
| `approval_requests` | Runtime approval request lifecycle. | `companies`, `approval_matrix`, `profiles`; polymorphic document source | Company-scoped SELECT; controlled INSERT/UPDATE by approval permissions; no DELETE. |
| `approval_actions` | Approval action history. | `companies`, `approval_requests`, `profiles` | Company-scoped SELECT; INSERT-only for approver/service; no UPDATE/DELETE. |

### Import / Export - 6 Tables

| Table | Purpose | Primary dependencies | RLS posture |
|---|---|---|---|
| `import_batches` | Import batch header and status. | `companies`, `profiles` | Company-scoped SELECT; controlled INSERT/UPDATE; no DELETE. |
| `import_rows` | Row-level raw/mapped import data. | `companies`, `import_batches` | Company-scoped SELECT; service INSERT/UPDATE; no DELETE. |
| `import_validation_errors` | Row validation errors. | `companies`, `import_batches`, `import_rows` | Company-scoped SELECT; service INSERT; no UPDATE/DELETE. |
| `import_templates` | Reusable import mappings. | `companies` | Company-scoped SELECT; admin INSERT/UPDATE; no DELETE. |
| `export_jobs` | Async export/report generation jobs. | `companies`, `branches`, `profiles` | Company-scoped SELECT; controlled INSERT; service UPDATE status; no DELETE. |
| `generated_report_files` | Generated report file metadata. | `companies`, `export_jobs`, `profiles` | Company-scoped SELECT; service INSERT; no UPDATE/DELETE. |

### Notifications - 3 Tables

| Table | Purpose | Primary dependencies | RLS posture |
|---|---|---|---|
| `notification_templates` | In-app notification templates. | `companies` | Company-scoped SELECT; admin INSERT/UPDATE; no DELETE. |
| `notifications` | User notification rows. | `companies`, `profiles` | Recipient SELECT own; admins can manage; users may update own read state only. |
| `notification_delivery_logs` | Delivery status history. | `companies`, `notifications` | User/admin SELECT as allowed; service INSERT; no UPDATE/DELETE. |

### Document Templates & Generated Output - 3 Tables

| Table | Purpose | Primary dependencies | RLS posture |
|---|---|---|---|
| `document_templates` | Printable document templates. | `companies` | Company-scoped SELECT; admin INSERT/UPDATE; no DELETE. |
| `generated_documents` | Generated document metadata. | `companies`, `document_templates`, `export_jobs`, `profiles`; polymorphic source document | Company-scoped SELECT; service INSERT; no UPDATE/DELETE except expiry/status fields if present. |
| `generated_document_versions` | Regenerated document version history. | `companies`, `generated_documents`, `profiles` | Company-scoped SELECT; service INSERT; no UPDATE/DELETE. |

### Period Close - 3 Tables

| Table | Purpose | Primary dependencies | RLS posture |
|---|---|---|---|
| `period_close_checklists` | Close process header per fiscal period. | `companies`, `fiscal_periods`, `profiles` | Accounting/controller SELECT; controlled INSERT/UPDATE; no DELETE. |
| `period_close_tasks` | Close checklist tasks. | `companies`, `period_close_checklists`, `profiles` | Accounting/controller SELECT; controlled INSERT/UPDATE; no DELETE. |
| `subledger_close_certifications` | GL/subledger certification evidence. | `companies`, `fiscal_periods`, `profiles` | Controller/accounting SELECT; controlled INSERT; no UPDATE/DELETE after certification. |

### Party Duplicate Management - 2 Tables

| Table | Purpose | Primary dependencies | RLS posture |
|---|---|---|---|
| `duplicate_tin_flags` | Duplicate TIN flags for customer/supplier data quality. | `companies`, `profiles` | Company-scoped SELECT; service/admin INSERT/UPDATE resolution; no DELETE. |
| `party_merge_logs` | Auditable party merge history. | `companies`, `profiles`; polymorphic merged parties | Company-scoped SELECT; service INSERT; no UPDATE/DELETE. |

### Feature Catalog & Adaptive Workspace - 12 Tables

| Table | Purpose | Primary dependencies | RLS posture |
|---|---|---|---|
| `workspace_modules` | Registry of modules shown by the app. | None or system metadata | Global/company SELECT; super admin writes. |
| `feature_definitions` | Canonical feature catalog for modules, pages, dashboards, reports, widgets, workspaces, and company visibility. | `workspace_modules` for optional `module_id`; self for optional `parent_feature_id` | Authenticated SELECT; service/super admin INSERT/UPDATE; no authenticated DELETE. |
| `workspace_categories` | Navigation categories inside modules. | `workspace_modules` | SELECT to authenticated; super admin writes. |
| `workspace_pages` | Routeable pages, component keys, required permission and feature FKs. | `workspace_modules`, `workspace_categories`, `permissions`, `feature_definitions` | SELECT to authenticated; super admin writes. |
| `workspace_dashboards` | Dashboard registry. | `workspace_modules`, `workspace_categories`, `permissions`, `feature_definitions` | SELECT to authenticated; super admin writes. |
| `workspace_reports` | Report registry and report route/export metadata. | `workspace_modules`, `workspace_categories`, `permissions`, `feature_definitions` | SELECT to authenticated; super admin writes. |
| `dashboard_widgets` | Widget registry for dashboards. | `workspace_dashboards`, `permissions`, `feature_definitions` | SELECT to authenticated; super admin writes. |
| `workspace_definitions` | Named workspace bundles. | Optional `companies` for tenant custom workspace; optional `feature_definitions` when a workspace is feature-gated | System/company SELECT; super admin or company admin writes based on ownership. |
| `workspace_items` | Ordered page/dashboard/report/module shortcuts in a workspace. | `workspace_definitions` plus workspace content tables | SELECT to visible workspace; admin writes. |
| `company_feature_visibility` | Company-level feature visibility and optional visibility override by module/category/page/dashboard/report/widget/workspace. | `companies`, `feature_definitions`, plus workspace metadata tables | Company users SELECT; company admin writes. |
| `role_workspace_assignments` | Assign workspaces to roles without hardcoded roles. | `companies`, `roles`, `workspace_definitions` | Company admin SELECT/INSERT/UPDATE; no DELETE. |
| `user_workspace_preferences` | Hide/favorite/pin/layout preferences. | `companies`, `profiles`, workspace metadata tables | User can manage own preferences only; admins cannot use it to grant visibility. |

## 3. FK Dependency Order

Use parent-first order. Do not create child tables before parents.

1. Independent or existing-parent tables:
   - `audit_logs`
   - `user_activity_logs`
   - `system_parameter_logs`
   - `document_void_register`
   - `dat_generation_logs`
   - `export_history`
   - `system_alerts`
   - `attachments`
   - `approval_requests`
   - `import_batches`
   - `import_templates`
   - `export_jobs`
   - `notification_templates`
   - `document_templates`
   - `period_close_checklists`
   - `subledger_close_certifications`
   - `duplicate_tin_flags`
   - `party_merge_logs`
   - `workspace_modules`
2. Direct child tables:
   - `field_change_history` after `audit_logs`
   - `attachment_versions` after `attachments`
   - `approval_actions` after `approval_requests`
   - `import_rows` after `import_batches`
   - `generated_report_files` after `export_jobs`
   - `notifications` after `notification_templates` is available, although the template FK may be optional
   - `generated_documents` after `document_templates` and `export_jobs`
   - `period_close_tasks` after `period_close_checklists`
   - `workspace_categories` after `workspace_modules`
   - `feature_definitions` after `workspace_modules` when `module_id` is used; `parent_feature_id` is self-referential
   - `workspace_definitions` after `feature_definitions` when `required_feature_id` is used
3. Grandchild or registry-dependent tables:
   - `import_validation_errors` after `import_batches` and `import_rows`
   - `notification_delivery_logs` after `notifications`
   - `generated_document_versions` after `generated_documents`
   - `workspace_pages`, `workspace_dashboards`, `workspace_reports` after `workspace_modules`, `workspace_categories`, `permissions`, and `feature_definitions`
   - `dashboard_widgets` after `workspace_dashboards`, `permissions`, and `feature_definitions`
   - `workspace_items` after `workspace_definitions` and the workspace item target tables
   - `company_feature_visibility` after `feature_definitions` and workspace metadata tables
   - `role_workspace_assignments` after `roles` and `workspace_definitions`
   - `user_workspace_preferences` after workspace metadata tables and `profiles`
4. Existing deferred FK wiring after all parents exist:
   - `import_batch_id` FKs
   - `attachment_id` FKs
   - `generated_document_id` FKs
   - `export_job_id` FKs

## 4. FKs That Can Be Wired Now

All of the following can be wired in Migration 018 because both sides will exist after the new tables are created.

### New Table Internal FKs

- `field_change_history.audit_log_id -> audit_logs.id`
- `attachment_versions.attachment_id -> attachments.id`
- `approval_requests.approval_matrix_id -> approval_matrix.id`
- `approval_actions.approval_request_id -> approval_requests.id`
- `import_rows.import_batch_id -> import_batches.id`
- `import_validation_errors.import_batch_id -> import_batches.id`
- `import_validation_errors.import_row_id -> import_rows.id`
- `generated_report_files.export_job_id -> export_jobs.id`
- `notifications.recipient_user_id -> profiles.id`
- `notification_delivery_logs.notification_id -> notifications.id`
- `generated_documents.template_id -> document_templates.id`
- `generated_documents.export_job_id -> export_jobs.id`
- `generated_document_versions.generated_document_id -> generated_documents.id`
- `period_close_checklists.fiscal_period_id -> fiscal_periods.id`
- `period_close_tasks.checklist_id -> period_close_checklists.id`
- `subledger_close_certifications.fiscal_period_id -> fiscal_periods.id`
- `feature_definitions.module_id -> workspace_modules.id`
- `feature_definitions.parent_feature_id -> feature_definitions.id`
- `workspace_pages.required_feature_id -> feature_definitions.id`
- `workspace_dashboards.required_feature_id -> feature_definitions.id`
- `workspace_reports.required_feature_id -> feature_definitions.id`
- `dashboard_widgets.required_feature_id -> feature_definitions.id`
- `workspace_definitions.required_feature_id -> feature_definitions.id`
- `company_feature_visibility.feature_id -> feature_definitions.id`
- All `company_id -> companies.id` and user columns to `profiles.id`, where the source spec requires it.

### Existing Deferred FKs To `import_batches`

Wire existing `import_batch_id` columns to `import_batches.id` for:

- `chart_of_accounts`
- `payment_terms`
- `customers`
- `suppliers`
- `items`
- `quotations`
- `sales_orders`
- `delivery_receipts`
- `sales_invoices`
- `cash_sales`
- `receipts`
- `sales_credit_memos`
- `sales_debit_memos`
- `customer_returns`
- `purchase_orders`
- `receiving_reports`
- `vendor_bills`
- `cash_purchases`
- `payment_vouchers`
- `vendor_credits`
- `supplier_debit_memos`
- `purchase_returns`
- `petty_cash_vouchers`
- `petty_cash_replenishments`
- `bank_fund_transfers`
- `inter_branch_transfers`
- `bank_adjustments`
- `bank_reconciliations`
- `bank_statement_lines`
- `stock_adjustments`
- `stock_transfers`
- `goods_issues`
- `physical_count_entries`
- `asset_acquisitions`
- `asset_disposals`
- `asset_transfers`
- `asset_impairments`
- `opening_balance_entries`
- `posting_rule_sets`

### Existing Deferred FKs To Attachment, Document, And Export Tables

Wire:

- `certificates_2307_issued.generated_document_id -> generated_documents.id`
- `certificates_2307_received.attachment_id -> attachments.id`
- `certificates_2306_issued.generated_document_id -> generated_documents.id`
- `fwt_remittances_1601fq.export_job_id -> export_jobs.id`
- `percentage_tax_return_filings.export_job_id -> export_jobs.id`
- `income_tax_return_filings.export_job_id -> export_jobs.id`

## 5. FKs That Must Remain Deferred Or Intentionally Unenforced

These should not be forced into normal FK constraints in Migration 018 because they are intentionally polymorphic or external.

- `audit_logs.record_id` remains polymorphic by `table_name`.
- `attachments.entity_id` remains polymorphic by `entity_type`.
- `approval_requests.document_id` remains polymorphic by `document_type`.
- `document_void_register.document_id` remains polymorphic by `document_type`.
- `generated_documents.document_id` remains polymorphic by `document_type`.
- `notifications.entity_id` remains polymorphic by `entity_type`.
- `system_alerts.entity_id` remains polymorphic by `entity_type`.
- `import_rows.created_record_id` remains polymorphic by `created_record_type`.
- `duplicate_tin_flags.party_ids` remains an array of affected party IDs.
- `party_merge_logs.merged_from_id` and `merged_into_id` remain polymorphic across customers/suppliers unless the owner approves separate customer/supplier merge log tables.
- Supabase Storage object paths in `attachments`, `generated_documents`, and `generated_report_files` remain external storage references, not database FKs.

For adaptive workspace tables, prefer explicit nullable FK columns with a CHECK ensuring exactly one target instead of a generic `item_type/item_id` pair where practical. If a generic polymorphic design is chosen for flexibility, document that FK enforcement is intentionally deferred to application/service validation.

## 6. RLS Policy Strategy By Table Group

Common rules:

- Enable RLS on every new table.
- No authenticated DELETE policies unless explicitly required by the architecture.
- Use `public.is_super_admin()` for platform bypass where appropriate.
- Use `company_id = ANY(auth.user_company_ids())` for company-scoped rows.
- Use `auth.has_permission(permission_code, company_id)` only where a canonical permission exists or is approved with the adaptive workspace scope.
- Service-role-only writer tables should expose SELECT only to authenticated users and rely on service role bypass for writes.

| Group | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| Audit/CAS immutable logs | Company-scoped, narrowed to admin/controller/auditor where needed | Service role or controlled backend only | None | None |
| User activity logs | Own activity and admin/controller company activity | Service/backend; optionally own login event path | None | None |
| System alerts | `system_alerts.view` or admin/controller | Service role | Resolve/update by service or authorized admin only | None |
| Attachments | Company-scoped and permission-aware | Authorized company user/backend | Metadata update only while not locked; versioning creates child rows | None or soft-delete only if spec supports it |
| Approval runtime | Company-scoped plus participant visibility | Authorized requester/service | Request status by workflow service; no direct action edits | None |
| Approval actions | Company-scoped | Authorized approver/service | None | None |
| Import batches | Company-scoped | Users with import permission | Service updates status/counts; rollback permission for rollback fields | None |
| Import rows/errors | Company-scoped | Service role | Service role | None |
| Export jobs/files | Company-scoped | Users with export permission | Service role status/file update | None |
| Notifications | Recipient can read own; admins can read company | Service role | Recipient can mark own read; admins/service manage | None |
| Document templates | Company-scoped | Template admin | Template admin | None |
| Generated documents/versions | Company-scoped | Service role | Service role only if expiry/status metadata exists | None |
| Period close | Accounting/controller | Controller/accounting | Controller/accounting until closed/locked | None |
| Party duplicate | Admin/controller/accounting | Service/admin | Resolution fields only | None |
| Feature catalog system metadata | Authenticated read of active features; service/super admin can inspect all | Service/super admin | Service/super admin | None |
| Adaptive workspace system metadata | Authenticated read | Super admin | Super admin | None |
| Adaptive workspace company visibility | Company users read effective visibility | Company admin | Company admin | None |
| User workspace preferences | User reads own | User inserts own | User updates own | User may delete own preference only if soft-delete is not required |

## 7. Policies For The 12 Existing No-Policy Tables

| Table | Required policy design |
|---|---|
| `approval_matrix_steps` | Same company scope as `approval_matrix`; SELECT to company users; INSERT/UPDATE to approval-rule admins; no DELETE. |
| `atp_usage_logs` | SELECT company-scoped to authorized users; INSERT by service/document numbering path; UPDATE only for void marking by service; no DELETE. |
| `cas_registrations` | SELECT to company admins/controllers/compliance users; INSERT by compliance setup admin; immutable after insert except controlled active flag if architecture requires; no DELETE. |
| `chart_of_accounts` | SELECT to company users; INSERT/UPDATE to accounting setup admins/controllers; protect system/import-owned fields; no DELETE except soft-delete workflow if already documented. |
| `company_bank_accounts` | SELECT to company users with bank/accounting visibility; INSERT/UPDATE to setup admins; no DELETE. |
| `company_compliance_profiles` | SELECT to company users because it drives behavior; INSERT/UPDATE only with `settings.compliance_profile.manage`; no DELETE. |
| `company_feature_settings` | SELECT to company users because it drives high-level setup flags; INSERT/UPDATE only with `settings.feature_settings.manage`; no DELETE. This table is not the canonical feature catalog after Decision 017. |
| `document_controls` | SELECT to company users where needed by UI/service; INSERT/UPDATE to setup/admin users; no DELETE. |
| `exchange_rates` | SELECT to company users; prefer INSERT-only for new historical rates; UPDATE only to authorized accounting setup users before rate is used; no DELETE. |
| `fiscal_locks` | SELECT to company accounting users; INSERT/UPDATE unlock fields by controller/accounting close permission; no DELETE. |
| `system_parameters` | SELECT company-scoped; INSERT/UPDATE to admin; platform-owned `is_system=true` rows service/super-admin only; no DELETE. |
| `user_department_access` | User can view own department access; company access admins can SELECT/INSERT/UPDATE; no DELETE. |

## 8. Line Immutability Cleanup Strategy

Current issue: many line/non-status tables received company-scoped UPDATE policies in 017D/017E/017F. Because the line rows do not carry their own lifecycle status, RLS cannot stop updates after the parent document is posted, voided, reversed, cancelled, or completed.

Required design:

1. Drop broad line UPDATE policies from affected line tables.
2. Recreate UPDATE policies using parent-path checks.
3. `USING` and `WITH CHECK` must both verify:
   - user has company access or is super admin
   - parent row belongs to the user company
   - parent status is editable
4. Editable statuses should come from existing document controls where feasible; otherwise use the conservative static guard already used in 017D/017E: not in `posted`, `voided`, `reversed`, `cancelled`, `completed`.

Parent-path groups:

- Sales: `quotation_lines -> quotations`, `sales_order_lines -> sales_orders`, `delivery_receipt_lines -> delivery_receipts`, `sales_invoice_lines -> sales_invoices`, `cash_sale_lines -> cash_sales`, `receipt_lines -> receipts`, `sales_credit_memo_lines -> sales_credit_memos`, `sales_debit_memo_lines -> sales_debit_memos`, `customer_return_lines -> customer_returns`.
- Purchasing: `purchase_order_lines -> purchase_orders`, `receiving_report_lines -> receiving_reports`, `vendor_bill_lines -> vendor_bills`, `cash_purchase_lines -> cash_purchases`, `payment_voucher_lines -> payment_vouchers`, `vendor_credit_lines -> vendor_credits`, `supplier_debit_memo_lines -> supplier_debit_memos`, `purchase_return_lines -> purchase_returns`.
- Assets/inventory: `petty_cash_voucher_lines -> petty_cash_vouchers`, `bank_reconciliation_lines -> bank_reconciliations`, `stock_adjustment_lines -> stock_adjustments`, `stock_transfer_lines -> stock_transfers`, `goods_issue_lines -> goods_issues`, `physical_count_lines -> physical_count_entries`.
- Accounting setup/runtime: `budget_lines -> budgets`, `recurring_journal_template_lines -> recurring_journal_templates` if these remain user-editable after parent activation.

If a line table represents posted/engine output rather than user draft data, remove authenticated UPDATE entirely.

## 9. Service-Owned Mutable Field Protection Strategy

RLS is row-level, not column-level. A company-scoped UPDATE policy on a row still permits updates to every column on that row unless column privileges, service functions, or trigger checks prevent it.

Required protection targets:

- `customer_credit_profiles.current_outstanding`
- `purchase_order_lines.received_qty`
- `purchase_order_lines.billed_qty`
- `petty_cash_funds.current_balance`
- `inventory_cost_layers.remaining_quantity`
- `inventory_cost_layers.is_exhausted`
- `inventory_balances.quantity_available` and related balance quantities
- `fixed_assets.accumulated_depreciation`
- `fixed_assets.net_book_value`
- `asset_depreciation_schedules.status`
- `amortization_schedule_lines.status`
- `amortization_schedule_lines.journal_entry_id`
- `revenue_recognition_schedule_lines.status`
- `revenue_recognition_schedule_lines.journal_entry_id`
- `gl_balances`
- `subsidiary_ledger_entries`
- `vat_entries`, `ewt_entries`, `fwt_entries`, `percentage_tax_entries`

Recommended pattern:

1. For pure runtime/ledger tables, keep authenticated users SELECT-only. Service role remains writer.
2. For mixed editable tables, prefer column-level UPDATE privilege hardening after Supabase testing:
   - revoke authenticated UPDATE on service-owned columns
   - allow service role to update them
3. If column privileges are not approved, remove authenticated table UPDATE and route edits through Edge Functions that write only allowed user-editable columns.
4. Add verification queries that list policies and column privileges for every service-owned field.

## 10. Compliance Filed-Status Guard Strategy

Affected user-managed filing tables include:

- `vat_return_filings`
- `ewt_remittances_1601eq`
- `fwt_remittances_1601fq`
- `percentage_tax_return_filings`
- `income_tax_return_filings`

Current issue: 017G allows company/permission-scoped UPDATE without denying changes after `filing_status = 'filed'`.

Required design:

1. Replace filing-table UPDATE policies with filing-status guarded policies.
2. Permit normal UPDATE only while `filing_status = 'draft'`.
3. Treat `filed` as immutable.
4. Treat `amended` as controlled amendment workflow, not ordinary edit.
5. Use service-role or dedicated amendment Edge Function for valid amendment flows.
6. Add verification query to assert no authenticated UPDATE policy exists on filed rows.

## 11. Adaptive Workspace Table Design

Final visibility must be computed as:

`feature definition is active` AND `company feature visibility` AND `role permission visibility` AND `user preference visibility`

User preference can only reduce or arrange visibility. It must never grant access.

Decision 017 adds `feature_definitions` as the canonical feature catalog. Workspace
metadata must reference `feature_definitions.id` through `required_feature_id` wherever
feature gating is needed. Free-text `required_feature_key` is not allowed for backend,
UI, or RLS visibility logic.

Relationship rules:

- `feature_definitions` owns canonical feature identity. `feature_code` is a stable
  setup/import code, but runtime visibility should be resolved through relational rows
  and FKs, not hardcoded strings.
- `company_feature_settings` may remain as one-row high-level company setup flags for
  coarse setup behavior and backward compatibility. It is not the complete feature
  catalog and must not be the only visibility source.
- `company_feature_visibility` references `feature_definitions.id` and records
  company-level enablement/visibility for a feature, optionally narrowed to a module,
  category, page, dashboard, report, widget, or workspace target.
- Workspace metadata references `feature_definitions.id` through `required_feature_id`
  so pages, dashboards, reports, widgets, and feature-gated workspaces can be enabled
  later by inserting metadata rather than adding columns or hardcoded logic.

### Proposed Metadata Shape

| Table | Key columns to include |
|---|---|
| `workspace_modules` | `id`, `module_code`, `module_name`, `description`, `icon_key`, `sort_order`, `is_system`, `is_active`, audit columns |
| `feature_definitions` | `id`, `feature_code`, `feature_name`, `description`, `feature_group`, `parent_feature_id`, `module_id NULL`, `is_system`, `is_active`, `default_enabled`, `sort_order`, audit columns |
| `workspace_categories` | `id`, `module_id`, `category_code`, `category_name`, `sort_order`, `is_active`, audit columns |
| `workspace_pages` | `id`, `module_id`, `category_id`, `page_code`, `page_name`, `route_path`, `component_key`, `required_permission_id`, `required_feature_id`, `sort_order`, `is_active`, audit columns |
| `workspace_dashboards` | `id`, `module_id`, `category_id`, `dashboard_code`, `dashboard_name`, `route_path`, `required_permission_id`, `required_feature_id`, `is_active`, audit columns |
| `workspace_reports` | `id`, `module_id`, `category_id`, `report_code`, `report_name`, `route_path`, `export_type`, `required_permission_id`, `required_feature_id`, `is_active`, audit columns |
| `dashboard_widgets` | `id`, `dashboard_id`, `widget_code`, `widget_name`, `component_key`, `data_source_key`, `required_permission_id`, `required_feature_id`, `default_layout`, `sort_order`, `is_active`, audit columns |
| `workspace_definitions` | `id`, `company_id NULL`, `workspace_code`, `workspace_name`, `description`, `required_feature_id NULL`, `is_system`, `is_active`, audit columns |
| `workspace_items` | `id`, `workspace_id`, nullable target FKs for module/category/page/dashboard/report, `sort_order`, `is_default_visible`, audit columns |
| `company_feature_visibility` | `id`, `company_id`, `feature_id`, nullable target FKs for module/category/page/dashboard/report/widget/workspace, `visibility_status`, `effective_from`, `effective_to`, audit columns |
| `role_workspace_assignments` | `id`, `company_id`, `role_id`, `workspace_id`, `is_default`, `is_active`, audit columns |
| `user_workspace_preferences` | `id`, `company_id`, `user_id`, nullable target FKs, `preference_type`, `preference_value`, `sort_order`, `is_active`, audit columns |

### Design Rules

- Use stable codes (`module_code`, `page_code`, `report_code`) for application routing.
- Use FK to `permissions.id` where a page/dashboard/report requires a permission.
- Use FK to `feature_definitions.id` where a page/dashboard/report/widget/workspace requires a feature.
- Do not use free-text `required_feature_key` for feature gating.
- `company_feature_visibility.feature_id` must reference `feature_definitions.id`.
- Prefer nullable target FKs plus CHECK exactly-one-target over generic `item_type/item_id`.
- No hardcoded role names. Role behavior comes from `roles`, `role_permissions`, `user_roles`, and `role_workspace_assignments`.
- No hardcoded feature keys. Future modules are added by inserting `feature_definitions` and workspace metadata, not by adding new boolean columns.
- No hardcoded menus. Menus are workspace metadata filtered by feature definitions, company visibility, company setup settings where applicable, and permissions.
- No hardcoded dashboards/reports. Dashboards/reports are metadata records filtered by visibility.

## 12. Clean Verification Queries

These are verification query shapes for the migration author to include as comments or run manually. They are not implemented by this plan.

```sql
-- Expected final table count after Migration 018:
SELECT COUNT(*) AS public_table_count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE';
```

```sql
-- Confirm all 41 expected Migration 018 tables exist:
SELECT expected.table_name
FROM (VALUES
  ('audit_logs'), ('field_change_history'), ('user_activity_logs'),
  ('system_parameter_logs'), ('document_void_register'), ('dat_generation_logs'),
  ('export_history'), ('system_alerts'), ('attachments'), ('attachment_versions'),
  ('approval_requests'), ('approval_actions'), ('import_batches'), ('import_rows'),
  ('import_validation_errors'), ('import_templates'), ('export_jobs'),
  ('generated_report_files'), ('notification_templates'), ('notifications'),
  ('notification_delivery_logs'), ('document_templates'), ('generated_documents'),
  ('generated_document_versions'), ('period_close_checklists'), ('period_close_tasks'),
  ('subledger_close_certifications'), ('duplicate_tin_flags'), ('party_merge_logs'),
  ('workspace_modules'), ('feature_definitions'), ('workspace_categories'), ('workspace_pages'),
  ('workspace_dashboards'), ('workspace_reports'), ('dashboard_widgets'),
  ('workspace_definitions'), ('workspace_items'), ('company_feature_visibility'),
  ('role_workspace_assignments'), ('user_workspace_preferences')
) AS expected(table_name)
LEFT JOIN information_schema.tables t
  ON t.table_schema = 'public'
 AND t.table_name = expected.table_name
WHERE t.table_name IS NULL;
```

```sql
-- Confirm final Phase 1 active public table target is 219.
-- This assumes removed/deferred tables are not present in public as active base tables.
SELECT
  219 AS expected_public_base_table_count,
  COUNT(*) AS actual_public_base_table_count,
  COUNT(*) = 219 AS passed
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE';
```

```sql
-- Confirm RLS enabled on every public table:
SELECT c.relname
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relrowsecurity = false
ORDER BY c.relname;
```

```sql
-- Confirm feature gating is FK-backed, not free-text-key-only.
SELECT conrelid::regclass AS table_name, conname
FROM pg_constraint
WHERE contype = 'f'
  AND confrelid = 'public.feature_definitions'::regclass
  AND conrelid::regclass::text IN (
    'workspace_pages',
    'workspace_dashboards',
    'workspace_reports',
    'dashboard_widgets',
    'workspace_definitions',
    'company_feature_visibility'
  )
ORDER BY table_name::text, conname;
```

```sql
-- Confirm the 12 previously no-policy tables now have policies:
SELECT tablename, COUNT(*) AS policy_count
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'approval_matrix_steps', 'atp_usage_logs', 'cas_registrations',
    'chart_of_accounts', 'company_bank_accounts', 'company_compliance_profiles',
    'company_feature_settings', 'document_controls', 'exchange_rates',
    'fiscal_locks', 'system_parameters', 'user_department_access'
  )
GROUP BY tablename
ORDER BY tablename;
```

```sql
-- Confirm no DELETE policies unless explicitly approved:
SELECT tablename, policyname
FROM pg_policies
WHERE schemaname = 'public'
  AND cmd = 'DELETE'
ORDER BY tablename, policyname;
```

```sql
-- Confirm broad USING(true) policies are still limited to true global lookup tables:
SELECT tablename, policyname, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND qual = 'true'
ORDER BY tablename, policyname;
```

```sql
-- Confirm filed compliance rows cannot be updated by ordinary authenticated policies.
-- Reviewer must inspect qual/with_check for filing_status guards.
SELECT tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'vat_return_filings',
    'ewt_remittances_1601eq',
    'fwt_remittances_1601fq',
    'percentage_tax_return_filings',
    'income_tax_return_filings'
  )
  AND cmd = 'UPDATE';
```

```sql
-- Confirm deferred FKs were wired after parent tables were created:
SELECT conrelid::regclass AS table_name, conname
FROM pg_constraint
WHERE contype = 'f'
  AND confrelid IN (
    'public.import_batches'::regclass,
    'public.attachments'::regclass,
    'public.generated_documents'::regclass,
    'public.export_jobs'::regclass
  )
ORDER BY table_name::text, conname;
```

## 13. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Migration 018 becomes too large | Review quality drops; one failure blocks all reconciliation work. | Split into 018A-018E. |
| Feature catalog is not wired to workspace records | UI/RLS/backend may still hardcode feature keys. | Create `feature_definitions` and use `required_feature_id` / `feature_id` FKs. |
| Adaptive workspace tables are under-specified | UI may still hardcode visibility. | Approve table contracts before SQL. |
| RLS policies for new tables are broad | Users may see audit, export, notification, or workspace rows outside permitted scope. | Use least-privilege policy groups and verification queries. |
| Service-owned fields remain mutable | Accounting, inventory, asset, and compliance outputs can be corrupted. | Use SELECT-only runtime tables, column privileges, or service functions. |
| Parent-status guards are missed on lines | Posted documents can be mutated through direct API calls. | Replace broad line UPDATE policies with parent-path guards. |
| Existing deferred FKs are not wired | Import, attachment, generated-document, and export traceability remains incomplete. | Wire all now-available targets in 018. |
| Polymorphic references are mistaken for missing FKs | Migration author may over-constrain document/event references. | Keep polymorphic references intentionally app/service validated. |
| Permission codes are invented ad hoc | Future security model fragments. | Use existing Doc09 permissions or add permission definitions deliberately with the adaptive workspace scope. |

## 14. Recommended Split If Migration 018 Is Too Large

Migration 018 is large enough that splitting is strongly recommended for review quality.

Recommended split:

1. `018a_missing_foundation_tables.sql`
   - Create the 29 missing documented Phase 1 tables.
   - Wire parent-child FKs inside those 29 tables.
   - Wire existing deferred FKs to `import_batches`, `attachments`, `generated_documents`, and `export_jobs`.
   - Enable RLS on the 29 tables, but keep policies minimal or defer policies to 018C if needed.

2. `018b_feature_catalog_adaptive_workspace_tables.sql`
   - Create `feature_definitions`.
   - Create the 11 adaptive-workspace metadata tables.
   - Wire `required_feature_id` and `company_feature_visibility.feature_id` FKs to `feature_definitions`.
   - Add exact-one-target CHECK constraints where nullable target FK pattern is used.
   - Enable RLS.

3. `018c_rls_new_and_missing_policies.sql`
   - Add policies for all 41 new tables.
   - Add policies for the 12 existing no-policy tables.
   - Confirm no unintended DELETE policies and no broad global `USING (true)` policies.

4. `018d_immutability_security_cleanup.sql`
   - Replace broad line UPDATE policies with parent-status guarded policies.
   - Protect service-owned mutable fields.
   - Add filed-status guards for compliance filing tables.

5. `018e_foundation_verification.sql`
   - Add verification comments/queries.
   - Optionally add metadata comments and final integrity checks.
   - Run clean database apply and policy inspection.

Do not start CRUD/UI until all split parts are complete and verified.
