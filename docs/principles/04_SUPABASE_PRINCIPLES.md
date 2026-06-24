# PXL ERP Supabase Principles

Version: PXL Constitution v1.0
Status: Canonical governing principles
Scope: Supabase, PostgreSQL, RLS, Edge Functions, storage, realtime, migrations, and environment operations

## Purpose

This document defines how PXL ERP uses Supabase. Supabase is not only hosting; it is part of the security, database, migration, storage, and service architecture.

## Core Supabase Principles

### 1. PostgreSQL First

PXL ERP must rely on PostgreSQL tables, constraints, relationships, functions, indexes, RLS, and transactions for core integrity. Application code must not compensate for avoidable database ambiguity.

### 2. RLS Is Default

All application tables must have row level security enabled unless there is a documented technical reason. Policies must be explicit, simple, and testable.

### 3. Client Code Uses User Context

Frontend code must operate under the authenticated user's context. It must not use the service role key or bypass RLS.

### 4. Service Role Is Server Only

The service role may be used only in trusted server-side contexts such as Edge Functions, controlled jobs, and migration or maintenance operations. It must never be exposed to the browser.

### 5. Edge Functions Handle Privileged Operations

Posting, compliance filing, generated document creation, import finalization, service-owned field updates, and other privileged actions must go through trusted server-side functions.

### 6. Helper Functions Must Be Safe

RLS helper functions must be schema-qualified, stable where appropriate, use explicit `search_path`, avoid recursive policy dependencies, and work even when RLS is enabled on access tables.

### 7. Policies Must Prefer Clear Patterns

Policy design should prefer simple company scope, parent-path scope, global read-only scope, service-only scope, and documented exceptions. Complex repeated `EXISTS` clauses should be avoided when helper functions already represent the rule.

### 8. No Broad Authenticated Access

`USING (true)` is allowed only for true global read-only reference tables where authenticated users may read shared reference data. It must not be used for company-scoped or business records.

### 9. No Delete By Default

Authenticated application users should not receive DELETE policies for governed business records unless an architecture document explicitly requires it.

### 10. Storage Holds Files, Database Holds Metadata

Attachments, generated documents, import files, export files, and compliance files belong in Supabase Storage or equivalent file storage. The database must store metadata, hashes, ownership, traceability, status, and access rules.

### 11. Realtime Is Selective

Realtime should be used for events such as approvals, notifications, job status, and collaborative visibility where useful. Ledger, audit, compliance, and high-volume accounting data should not depend on realtime behavior.

### 12. Auth Is Not Authorization

Supabase Auth identifies the user. Authorization comes from profiles, company access, branch access, roles, permissions, feature visibility, workspace assignments, RLS policies, and service checks.

### 13. Secrets Stay Out Of Code

Keys, service credentials, tax credentials, integration secrets, and environment-specific values must be stored in secure environment configuration. They must not be committed.

### 14. Migrations Are The Deployment Unit

All schema, RLS, function, index, and constraint changes must be delivered through migrations. A Supabase project must be reproducible from the migration chain.

### 15. Verification Must Be Database-Level

Supabase readiness must be verified through database queries, not only visual inspection of the dashboard. Checks must confirm tables, policies, RLS state, indexes, constraints, functions, and expected counts.

### 16. Environment Differences Must Be Documented

Local, staging, and production environments must use the same migration logic. Any environment-specific setting must be explicit and reproducible.

### 17. Functions Must Not Hide Business Rules

Database functions and Edge Functions may implement business rules, but those rules must be documented in architecture, posting, compliance, security, or workflow specifications.

### 18. Clean Failure Is Required

Privileged operations must fail with clear errors when permissions, periods, statuses, locks, feature visibility, or compliance conditions are invalid. Silent partial success is not acceptable.
