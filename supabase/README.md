# PXL ERP — Supabase SQL Migrations

**Architecture Version:** 4.0 — Database Freeze  
**Tag:** v4.0-database-freeze  
**Status:** Phase 1 Implementation — Migration Authoring In Progress

---

## Purpose

This directory contains all production SQL for the PXL ERP Supabase/PostgreSQL database.  
The architecture is **frozen**. Migrations implement the frozen contract exactly — no deviations.

**Source of truth:** `docs/architecture/03_TABLE_COLUMN_SPECIFICATIONS.md`  
**Do not modify architecture documents** while migrations are being authored.

---

## Directory Structure

```
supabase/
├── migrations/          # Numbered SQL migration files (apply in sequence)
├── seed/                # Reference data (currencies, account types, ATC codes, roles, permissions)
├── functions/           # Supabase Edge Functions (posting engine, import engine, notifications)
├── views/               # Reporting views (AR aging, GL summary, SLSP, QAP)
├── policies/            # RLS policies (applied after table creation)
├── tests/               # pgTAP SQL unit tests
└── README.md            # This file
```

---

## Prerequisites

Before running any migration:

1. Supabase project created (Cloud or local CLI)
2. `pg_cron` extension enabled in Supabase Dashboard → Database → Extensions  
   (Cloud only — local CLI enables it automatically via `supabase/config.toml`)
3. Supabase CLI installed: `npm install -g supabase`
4. Local dev: `supabase start` to bring up the local stack

---

## Execution Order

Migrations **must** be applied strictly in sequence. Each migration depends on the previous.

| File | Description | Depends On |
|---|---|---|
| `001_extensions.sql` | PostgreSQL extensions | Nothing |
| `002_enums.sql` | All CHECK constraint domain values as named enums | 001 |
| `003_core_setup.sql` | Organization, system controls, accounting setup, currencies | 002 |
| `004_master_data.sql` | Customers, suppliers, items, payment terms, warehouses | 003 |
| `005_transactions.sql` | Sales, purchases, receipts, payments, journal entries | 004 |
| `006_tax_compliance.sql` | VAT entries, EWT, BIR filing tables, SLSP, QAP | 005 |
| `007_inventory.sql` | Inventory balances, movements, cost layers, physical count | 005 |
| `008_fixed_assets.sql` | Asset register, depreciation schedules, disposals | 005 |
| `009_audit_cas.sql` | Audit logs, field change history, number series, ATP, CAS | 003 |
| `010_import_export.sql` | Import batches, rows, errors, export jobs, attachments | 003 |
| `011_posting_engine.sql` | Posting rule sets, rule lines, system account config | 003 |
| `012_schedules.sql` | Amortization, revenue recognition, auto-reversal | 005 |
| `013_approval_workflow.sql` | Approval matrix, requests, actions | 003 |
| `014_notifications.sql` | Notifications, system alerts, notification templates | 003 |
| `015_security_access.sql` | Profiles, roles, permissions, user_company_access | 003 |
| `016_rls_policies.sql` | All Row Level Security policies | 015 |
| `017_rls_functions.sql` | auth.user_company_ids(), auth.has_permission() | 015 |
| `018_indexes.sql` | All secondary indexes (non-PK, non-unique) | 003–015 |
| `019_triggers.sql` | Immutability triggers, sync triggers, audit triggers | 003–015 |
| `020_seed_reference.sql` | Currencies, account types, ATC codes, roles, permissions | 015 |
| `021_cron_jobs.sql` | pg_cron job registrations | 001, 019 |

> **STOP AFTER EACH MIGRATION.** Review before proceeding to the next.  
> Each migration is independently committable and reversible (see Rollback Notes in each file).

---

## Applying Migrations

### Local Development (Supabase CLI)

```bash
# Start local Supabase stack
supabase start

# Apply all migrations
supabase db push

# Or apply one at a time for review
psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -f supabase/migrations/001_extensions.sql
```

### Supabase Cloud

```bash
# Link to your project
supabase link --project-ref <your-project-ref>

# Push migrations
supabase db push
```

### Manual (psql)

```bash
psql $DATABASE_URL -f supabase/migrations/001_extensions.sql
```

---

## Naming Conventions

All migration files follow Supabase's format:
- `YYYYMMDDHHMMSS_description.sql` — for Supabase CLI managed migrations  
- `NNN_description.sql` — for manual/reviewed sequence (used here during Phase 1 authoring)

During Phase 1 authoring, files use the `NNN_` prefix. Before production deployment, rename to Supabase timestamp format using:
```bash
supabase migration new <description>
```

---

## Architecture Reference

| Document | Scope |
|---|---|
| `docs/architecture/00_PXL_ARCHITECTURE_PRINCIPLES.md` | Non-negotiable principles |
| `docs/architecture/01_DATABASE_ARCHITECTURE_OVERVIEW.md` | Key decisions, phase scope |
| `docs/architecture/02_COMPLETE_TABLE_INVENTORY.md` | All 207 active tables (slots 1–209, 3 REMOVED) |
| `docs/architecture/03_TABLE_COLUMN_SPECIFICATIONS.md` | **Canonical column specs — source of truth** |
| `docs/architecture/06_POSTING_ENGINE_TABLE_DESIGN.md` | Posting rules, system account config |
| `docs/architecture/07_AUDIT_AND_CAS_TABLE_DESIGN.md` | Audit logs, number series, CAS |
| `docs/architecture/08_IMPORT_EXPORT_TABLE_DESIGN.md` | Import/export, attachments |
| `docs/architecture/09_SECURITY_RLS_DESIGN.md` | RLS patterns, helper functions |

---

## Key Constraints

- Money columns: `numeric(18,4)`
- Rate columns: `numeric(10,6)`
- All timestamps: `timestamptz`
- All PKs: `uuid DEFAULT gen_random_uuid()`
- All status CHECK values: **lowercase** (exception: `system_account_config.config_key` and `chart_of_accounts.control_account_type` are UPPERCASE — system constants)
- Hard DELETE is REVOKE'd on all app roles
- Service role key must NEVER be exposed to the client
- `profiles.is_super_admin = true` bypasses company RLS for platform administration only

---

## Current Status

| Migration | Status |
|---|---|
| `001_extensions.sql` | ✅ Authored — pending review |
| `002_enums.sql` | ⏳ Pending |
| `003_core_setup.sql` | ⏳ Pending |
| `004+` | ⏳ Pending |
