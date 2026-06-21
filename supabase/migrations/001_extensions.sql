-- =============================================================================
-- PXL ERP — Migration 001: Extensions
-- =============================================================================
-- Architecture Reference : v4.0 Database Freeze (commit ee93937 / tag v4.0-database-freeze)
-- PostgreSQL Version      : 16
-- Supabase Compatible     : Yes
-- Idempotent              : Yes (CREATE EXTENSION IF NOT EXISTS)
-- Depends On              : Nothing (first migration)
-- Must Run Before         : 002_enums.sql, and all subsequent migrations
-- =============================================================================
--
-- OVERVIEW
-- --------
-- This migration enables all PostgreSQL extensions required by PXL ERP.
-- No tables, functions, triggers, or RLS policies are created here.
-- Extensions are installed into the `extensions` schema (Supabase convention)
-- so that they do not pollute the public schema namespace.
--
-- EXTENSION INVENTORY
-- -------------------
--  pgcrypto         — gen_random_uuid() for all PK defaults; crypt() functions
--  uuid-ossp        — uuid_generate_v4() compatibility alias used in some
--                     Supabase client libraries; also uuid_nil(), uuid_ns_dns()
--  citext           — Case-insensitive text; used for email columns on profiles
--                     and case-insensitive unique indexes (e.g. company code,
--                     customer code) without per-query LOWER() overhead
--  btree_gist       — Required for EXCLUDE USING GIST constraints on daterange
--                     columns; used to enforce effective-date non-overlap on
--                     company_compliance_profiles, customer_tax_profiles,
--                     supplier_tax_profiles, posting_rule_sets, system_account_config
--                     (Doc03 §1 Effective-Date Non-Overlap Rule; Doc03 §29)
--  pg_cron          — Supabase-managed scheduler for nightly background jobs:
--                       · recurring_journal_generator  (daily 00:05)
--                       · auto_reversal_processor      (daily 00:10)
--                       · atp_gap_detector             (nightly 02:00)
--                       · notification_cleanup         (nightly 03:00)
--                       · amortization_runner          (monthly)
--                       · revenue_recognition_runner   (monthly)
--                       · depreciation_runner          (monthly)
--                       · income_tax_computation       (on-demand)
--                     (Doc06 §14 — Background Jobs)
--  pg_trgm          — Trigram similarity indexes for customer/supplier name
--                     fuzzy search (used by the customer autocomplete on
--                     sales_invoice and vendor_bill entry forms)
--  unaccent         — Strip accents from text before trigram indexing;
--                     ensures "Jose" matches "José" in search
--
-- SCHEMAS
-- -------
-- All extensions are created in the `extensions` schema (Supabase default).
-- The `public` search_path includes `extensions` via Supabase platform config.
-- No custom application schema is introduced in Phase 1; all tables live in
-- `public` following Supabase's recommended single-schema MSME deployment.
--
-- =============================================================================

-- Supabase creates the `extensions` schema automatically; this is a safety guard.
CREATE SCHEMA IF NOT EXISTS extensions;

-- ---------------------------------------------------------------------------
-- 1. pgcrypto
--    Provides gen_random_uuid() used as DEFAULT on every PK column.
--    Also provides crypt() / gen_salt() for any future password hashing needs
--    (though Supabase Auth handles authentication passwords — this covers
--    application-level PIN or token generation if needed).
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto
    SCHEMA extensions;

-- Make gen_random_uuid() available in public schema without schema-qualifying.
-- Supabase does this by default but we make it explicit for local dev parity.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp"
    SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- 2. citext
--    Case-insensitive text domain. Used for:
--      · profiles.email         — uniqueness check must be case-insensitive
--      · atc_codes.atc_code     — BIR codes are case-insensitive in practice
--    IMPORTANT: citext columns still require explicit LOWER() in non-Postgres
--    drivers that do not recognise the type. Application layer must normalise
--    to lowercase on INSERT for portability.
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS citext
    SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- 3. btree_gist
--    Extends GiST to support B-tree-comparable types (int, text, uuid, date).
--    Required for EXCLUDE USING GIST constraints that combine a uuid column
--    (company_id / customer_id / supplier_id) with a daterange column to
--    prevent overlapping effective-date rows.
--
--    Tables that will use this (created in later migrations):
--      · company_compliance_profiles  — EXCLUDE USING GIST (company_id WITH =, daterange(effective_from, effective_to, '[)') WITH &&)
--      · customer_tax_profiles        — same pattern
--      · supplier_tax_profiles        — same pattern
--      · posting_rule_sets            — same pattern (transaction_type + effective dates)
--      · system_account_config        — same pattern (company_id + config_key + effective dates)
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS btree_gist
    SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- 4. pg_cron
--    Supabase-managed extension for scheduled SQL jobs.
--    NOTE: On Supabase Cloud, pg_cron must be enabled in the project Dashboard
--    under Database → Extensions before this migration runs. On local Supabase
--    CLI dev stacks it is enabled by default in supabase/config.toml.
--    Actual cron job registrations are in a dedicated cron migration (future).
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_cron
    SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- 5. pg_trgm
--    Trigram indexes for fast ILIKE / similarity search on text columns.
--    Used by:
--      · customers.customer_name      — autocomplete on transaction forms
--      · suppliers.supplier_name      — autocomplete on vendor bill entry
--      · chart_of_accounts.account_name — account picker search
--    GIN trigram indexes are created in the table migration files.
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_trgm
    SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- 6. unaccent
--    Text search dictionary that removes diacritical marks before indexing.
--    Used together with pg_trgm so that "Jose" finds "José".
--    An immutable wrapper function `f_unaccent(text)` will be created in
--    the table migrations to support expression indexes:
--      CREATE INDEX ... ON customers USING GIN (f_unaccent(customer_name) gin_trgm_ops);
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS unaccent
    SCHEMA extensions;

-- =============================================================================
-- VERIFICATION
-- (Run these queries after applying this migration to confirm all extensions
--  are present and loaded into the correct schema.)
-- =============================================================================
--
-- SELECT extname, nspname AS schema
-- FROM   pg_extension e
-- JOIN   pg_namespace n ON n.oid = e.extnamespace
-- WHERE  extname IN (
--            'pgcrypto','uuid-ossp','citext',
--            'btree_gist','pg_cron','pg_trgm','unaccent'
--        )
-- ORDER  BY extname;
--
-- Expected rows: 7 rows, all with schema = 'extensions'
--
-- Quick function check:
-- SELECT gen_random_uuid();         -- should return a UUID
-- SELECT uuid_generate_v4();        -- should return a UUID
-- SELECT 'HELLO'::extensions.citext = 'hello';  -- should return true
--
-- =============================================================================

-- =============================================================================
-- ROLLBACK NOTES
-- =============================================================================
-- Extensions can be dropped with DROP EXTENSION IF EXISTS <name> CASCADE.
-- CASCADE will drop all dependent objects (indexes, columns typed citext, etc.)
-- Do NOT drop extensions in a live environment without first removing all
-- dependent columns and indexes. In practice, extensions are never rolled back
-- in production — this migration is a one-way gate.
--
-- For local dev reset: supabase db reset  (rebuilds from scratch)
-- =============================================================================

-- =============================================================================
-- EXPECTED OBJECTS CREATED
-- =============================================================================
-- Schema  : extensions (1, if not already present)
-- Extensions installed : 7
--   1. pgcrypto
--   2. uuid-ossp
--   3. citext
--   4. btree_gist
--   5. pg_cron
--   6. pg_trgm
--   7. unaccent
-- Tables  : 0
-- Functions : 0
-- Triggers  : 0
-- Indexes   : 0
-- =============================================================================
