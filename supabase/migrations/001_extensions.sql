-- =============================================================================
-- PXL ERP — Migration 001: Extensions
-- =============================================================================
-- Release        : v4.0-database-freeze
-- Architecture   : docs/architecture/ (frozen — DO NOT MODIFY)
-- Commit         : ee93937 (sign-off) / 67f91cd (migration scaffold)
-- PostgreSQL     : 16
-- Supabase       : Compatible (see pg_cron note below)
-- Idempotent     : Yes — CREATE EXTENSION IF NOT EXISTS
-- Depends On     : Nothing (first migration)
-- Must Run Before: 002_enums.sql and all subsequent migrations
-- =============================================================================
--
-- OVERVIEW
-- --------
-- Enables all PostgreSQL extensions required by PXL ERP Phase 1.
-- No tables, columns, functions, triggers, or RLS policies are created here.
--
-- All extensions are installed into the `extensions` schema following Supabase
-- convention, EXCEPT pg_cron which manages its own schema (see item 4 below).
--
-- EXTENSION SET (6 + 1 special)
-- ──────────────────────────────
--  1. pgcrypto    — crypt(), gen_salt(), digest(); NOT the source of gen_random_uuid()
--                   on PG14+ (gen_random_uuid() is a built-in SQL function on PG14+).
--                   Kept because Supabase internal tooling and some Edge Function
--                   patterns use pgcrypto's crypt()/encode() for token generation.
--
--  2. uuid-ossp   — uuid_generate_v4(), uuid_nil(), uuid_generate_v1().
--                   KEPT despite PG16 built-in gen_random_uuid() because:
--                   (a) some PostgREST versions and ORMs reference uuid_generate_v4()
--                       by name in generated SQL; (b) zero runtime cost if unused.
--
--  3. citext      — Case-insensitive text type.
--                   Required columns: profiles.email (case-insensitive uniqueness).
--                   Installed in `extensions` schema; Supabase Cloud search_path
--                   is "$user", public, extensions — citext resolves unqualified.
--                   Local dev: confirm search_path includes `extensions`.
--
--  4. btree_gist  — Extends GiST indexes to support B-tree-comparable types
--                   (uuid, text, date). Required for EXCLUDE USING GIST constraints
--                   that enforce effective-date non-overlap on:
--                     · company_compliance_profiles  (Doc03 §1)
--                     · customer_tax_profiles        (Doc03 §4)
--                     · supplier_tax_profiles        (Doc03 §4)
--                     · posting_rule_sets            (Doc03 §9 / Doc06 §2)
--                     · system_account_config        (Doc03 §29)
--
--  5. pg_cron     — Supabase-managed scheduler. Required for all 8 Phase 1
--                   background jobs (Doc06 §14):
--                     · recurring_journal_generator  daily  00:05
--                     · auto_reversal_processor      daily  00:10
--                     · atp_gap_detector             nightly 02:00
--                     · notification_cleanup         nightly 03:00
--                     · amortization_runner          monthly
--                     · revenue_recognition_runner   monthly
--                     · depreciation_runner          monthly
--                     · income_tax_computation       on-demand trigger
--                   ⚠ SPECIAL: pg_cron ignores the SCHEMA parameter — it ALWAYS
--                   installs into its own `pg_cron` schema regardless of what is
--                   specified. The SCHEMA clause is therefore OMITTED here.
--                   ⚠ CLOUD REQUIREMENT: pg_cron must be enabled in Supabase
--                   Dashboard → Database → Extensions BEFORE this migration runs.
--                   The migration will fail with "extension not available" if not
--                   pre-enabled on Supabase Cloud. Local CLI enables it automatically.
--
--  6. pg_trgm     — Trigram similarity indexes for full-text-like search.
--                   Required for GIN indexes on (Doc06 §11, Doc03 §4, Doc03 §5):
--                     · customers.customer_name    (autocomplete on SI, cash_sale)
--                     · suppliers.supplier_name    (autocomplete on VB, cash_purchase)
--                     · chart_of_accounts.account_name (account picker)
--                   Without this extension, `USING GIN (col gin_trgm_ops)` in
--                   Migration 011 (indexes) is invalid SQL and will fail.
--
--  7. unaccent    — Strips diacritical marks from text before indexing.
--                   Required partner to pg_trgm: ensures "Pena" matches "Peña",
--                   "Jose" matches "José" — critical for Filipino business names.
--                   Migration 003 (shared_functions) creates the immutable wrapper:
--                     CREATE OR REPLACE FUNCTION f_unaccent(text) ...
--                   which is required by expression-based GIN indexes in Migration 011.
--
-- SCHEMAS NOTE
-- ────────────
-- Application tables: public schema (Supabase default — single-schema Phase 1)
-- Extensions: extensions schema (all except pg_cron which uses pg_cron schema)
-- Auth tables: auth schema (Supabase managed — never modified by migrations)
--
-- =============================================================================

-- ---------------------------------------------------------------------------
-- PRE-FLIGHT: pg_cron Cloud Enablement Check
-- ---------------------------------------------------------------------------
-- This RAISE NOTICE fires at migration run time and is visible in psql output,
-- Supabase migration logs, and CI pipeline stdout.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '======================================================';
    RAISE NOTICE 'PXL ERP Migration 001 — Extensions';
    RAISE NOTICE '------------------------------------------------------';
    RAISE NOTICE 'SUPABASE CLOUD ACTION REQUIRED:';
    RAISE NOTICE '  pg_cron must be enabled BEFORE this migration runs.';
    RAISE NOTICE '  Dashboard → Database → Extensions → pg_cron → Enable';
    RAISE NOTICE '  Local Supabase CLI: enabled automatically.';
    RAISE NOTICE '  If pg_cron is not enabled, this migration will fail';
    RAISE NOTICE '  at the CREATE EXTENSION pg_cron statement below.';
    RAISE NOTICE '======================================================';
END
$$;

-- ---------------------------------------------------------------------------
-- Safety guard: Supabase Cloud creates this schema on provisioning.
-- Required for local dev parity and CI pipelines that start from a blank DB.
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS extensions;

-- ---------------------------------------------------------------------------
-- 1. pgcrypto
--    Provides: crypt(), gen_salt(), digest(), encode(), decode(), hmac()
--    NOT the source of gen_random_uuid() on PG14+ — that is a built-in.
--    Kept for: Edge Function token hashing, future PIN/OTP use cases.
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto
    WITH SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- 2. uuid-ossp
--    Provides: uuid_generate_v4() (alias for gen_random_uuid()),
--              uuid_nil(), uuid_generate_v1(), uuid_generate_v3/v5()
--    Kept for: compatibility with PostgREST generated SQL, JS client internals,
--    and any seed/test scripts that reference uuid_generate_v4() by name.
--    Zero runtime overhead if uuid_generate_v4() is never called directly.
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp"
    WITH SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- 3. citext
--    Case-insensitive text type. Required for profiles.email uniqueness and
--    any case-insensitive UNIQUE indexes created in later migrations.
--    Supabase Cloud search_path: "$user", public, extensions
--    → citext resolves as an unqualified type name in table DDL.
--    Local dev: ensure search_path matches or qualify as extensions.citext.
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS citext
    WITH SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- 4. btree_gist
--    Extends GiST index operator classes to support B-tree-comparable types.
--    Required for EXCLUDE USING GIST constraints on effective-date tables.
--    Without this, creating those EXCLUDE constraints fails at Migration 004.
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS btree_gist
    WITH SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- 5. pg_cron  ⚠ SPECIAL — NO SCHEMA CLAUSE
--    pg_cron unconditionally uses its own `pg_cron` schema for all objects
--    (pg_cron.job, pg_cron.job_run_details). The SCHEMA parameter is ignored
--    by this extension regardless of what is specified; it is therefore omitted
--    to avoid misleading documentation in pg_extension catalog.
--
--    CLOUD: Must be pre-enabled in Dashboard. See NOTICE above.
--    LOCAL: Enabled automatically by supabase start.
--    JOBS:  Cron job INSERT statements are in Migration 021 (cron_jobs.sql),
--           not here. This statement only makes the extension available.
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ---------------------------------------------------------------------------
-- 6. pg_trgm  (Doc03 §4, §5; Doc06 §11)
--    GIN trigram operators for ILIKE-style fast search.
--    Enables: USING GIN (column gin_trgm_ops) index syntax.
--    Required by Migration 011 (indexes). Without it, index creation fails.
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_trgm
    WITH SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- 7. unaccent  (Doc03 §4, §5)
--    Accent-stripping text search dictionary.
--    The immutable wrapper function created in Migration 003:
--      CREATE OR REPLACE FUNCTION f_unaccent(text)
--      RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS
--      $$ SELECT extensions.unaccent('extensions.unaccent', $1) $$;
--    is required by expression GIN indexes in Migration 011.
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS unaccent
    WITH SCHEMA extensions;

-- =============================================================================
-- VERIFICATION QUERIES
-- Run after applying this migration.
-- =============================================================================
--
-- 1. Confirm all 7 extensions are registered:
--
--    SELECT extname,
--           nspname        AS installed_schema,
--           extversion     AS version
--    FROM   pg_extension e
--    JOIN   pg_namespace n ON n.oid = e.extnamespace
--    WHERE  extname IN (
--               'pgcrypto','uuid-ossp','citext',
--               'btree_gist','pg_cron','pg_trgm','unaccent'
--           )
--    ORDER  BY extname;
--
--    Expected: 7 rows
--    Expected schema: extensions — for all EXCEPT pg_cron (schema = pg_cron)
--
-- 2. Function smoke tests:
--
--    SELECT gen_random_uuid();           -- built-in PG16, no extension needed
--    SELECT extensions.uuid_generate_v4();      -- uuid-ossp
--    SELECT 'HELLO'::extensions.citext = 'hello';      -- citext; must be true
--    SELECT extensions.similarity('hello','helo');      -- pg_trgm
--    SELECT extensions.unaccent('José');                -- unaccent; must return 'Jose'
--
-- 3. Verify pg_cron schema (not extensions):
--
--    SELECT nspname FROM pg_namespace WHERE nspname = 'pg_cron';
--    -- Expected: 1 row 'pg_cron'
--
-- =============================================================================

-- =============================================================================
-- ROLLBACK NOTES
-- =============================================================================
-- Extensions are a one-way gate in production.
-- Dropping an extension with CASCADE removes all dependent columns, indexes,
-- and functions. Never drop extensions on a live database.
--
-- Development reset: supabase db reset
--   (re-applies all migrations from scratch on local stack)
--
-- If pg_cron was pre-enabled on Cloud and must be removed:
--   Disable in Dashboard → Database → Extensions (GUI only — no SQL needed).
-- =============================================================================

-- =============================================================================
-- EXPECTED OBJECTS CREATED
-- =============================================================================
--   Schema created   : extensions (idempotent — no-op if already exists)
--   Extensions       : 7
--       pgcrypto     → extensions schema
--       uuid-ossp    → extensions schema
--       citext       → extensions schema
--       btree_gist   → extensions schema
--       pg_cron      → pg_cron schema  (extension-managed, not configurable)
--       pg_trgm      → extensions schema
--       unaccent     → extensions schema
--   Tables           : 0
--   Functions        : 0
--   Triggers         : 0
--   Indexes          : 0
-- =============================================================================
