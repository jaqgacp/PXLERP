-- ---------------------------------------------------------------------------
-- Phase 2E Branch Compliance Fields Additive Migration
-- ---------------------------------------------------------------------------

ALTER TABLE public.branches
    ADD COLUMN short_name text NULL,
    ADD COLUMN zip_code text NULL,
    ADD COLUMN rdo_code text NULL,
    ADD COLUMN contact_person text NULL,
    ADD COLUMN phone text NULL,
    ADD COLUMN email text NULL,
    ADD COLUMN ptu_cas_no text NULL,
    ADD COLUMN ptu_cas_date_issued date NULL,
    ADD COLUMN line_of_business text NULL;

COMMENT ON COLUMN public.branches.short_name IS 'Compact name for dense reporting and UI dropdowns.';
COMMENT ON COLUMN public.branches.zip_code IS 'Required for branch-level 2307, DAT, and Alphalist generation.';
COMMENT ON COLUMN public.branches.rdo_code IS 'RDO Code if branch reports to a different RDO than the Head Office.';
