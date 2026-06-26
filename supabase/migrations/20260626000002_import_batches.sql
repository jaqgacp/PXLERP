-- =============================================================================
-- Migration: 20260626000002_import_batches.sql
-- Description: Phase 4 ERP Import History & Rollback Framework
-- =============================================================================

-- 1. Replace existing stub tables from 018a
DROP TABLE IF EXISTS public.import_validation_errors CASCADE;
DROP TABLE IF EXISTS public.import_rows CASCADE;
DROP TABLE IF EXISTS public.import_batches CASCADE;

-- 2. Create import_batches table
CREATE TABLE public.import_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_no TEXT NOT NULL UNIQUE,
    entity_name TEXT NOT NULL,
    company_id UUID NULL REFERENCES public.companies(id),
    imported_by UUID NOT NULL REFERENCES auth.users(id),
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    original_filename TEXT NULL,
    file_size_bytes INTEGER NULL,
    duration_ms INTEGER NULL,
    total_rows INTEGER DEFAULT 0,
    valid_rows INTEGER DEFAULT 0,
    invalid_rows INTEGER DEFAULT 0,
    inserted_rows INTEGER DEFAULT 0,
    failed_rows INTEGER DEFAULT 0,
    error_summary JSONB NULL,
    warning_summary JSONB NULL,
    source_type TEXT DEFAULT 'csv',
    rollback_at TIMESTAMP WITH TIME ZONE NULL,
    rollback_by UUID NULL REFERENCES auth.users(id),
    rollback_reason TEXT NULL,
    remarks TEXT NULL,

    CONSTRAINT chk_import_batches_status CHECK (
        status IN (
            'pending',
            'validating',
            'completed',
            'failed',
            'rolled_back',
            'partially_imported'
        )
    )
);

-- 2. Indexes for performance and history lookup
CREATE INDEX idx_import_batches_company_id ON public.import_batches(company_id);
CREATE INDEX idx_import_batches_imported_by ON public.import_batches(imported_by);
CREATE INDEX idx_import_batches_status ON public.import_batches(status);
CREATE INDEX idx_import_batches_entity_name ON public.import_batches(entity_name);
CREATE INDEX idx_import_batches_started_at ON public.import_batches(started_at);

-- 3. Grants (Consistent with 018f_grant_access.sql but explicitly omitting/revoking DELETE for authenticated)
-- 018f_grant_access sets default privileges to include DELETE, so we must explicitly REVOKE it here.
REVOKE DELETE ON public.import_batches FROM authenticated;
GRANT SELECT, INSERT, UPDATE ON public.import_batches TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.import_batches TO service_role;

-- 4. RLS Policies
ALTER TABLE public.import_batches ENABLE ROW LEVEL SECURITY;

-- 4.1 SELECT Policy
CREATE POLICY "Users can view company import batches"
ON public.import_batches FOR SELECT
TO authenticated
USING (
    company_id = ANY(public.user_company_ids())
    OR public.is_super_admin()
);

-- 4.2 INSERT Policy
CREATE POLICY "Users can insert their own import batches"
ON public.import_batches FOR INSERT
TO authenticated
WITH CHECK (
    imported_by = auth.uid()
    AND (
        company_id = ANY(public.user_company_ids())
        OR public.is_super_admin()
    )
);

-- 4.3 UPDATE Policy
CREATE POLICY "Users can update their own import batches"
ON public.import_batches FOR UPDATE
TO authenticated
USING (
    imported_by = auth.uid()
    OR public.is_super_admin()
)
WITH CHECK (
    imported_by = auth.uid()
    OR public.is_super_admin()
);

-- Note: No DELETE policy is created for authenticated users.

-- 5. Link imported records back to their source batch in module tables
-- Adding to branches (No CASCADE)
ALTER TABLE public.branches 
ADD COLUMN import_batch_id UUID NULL REFERENCES public.import_batches(id);
