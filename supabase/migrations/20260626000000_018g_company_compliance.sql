-- Migration: 018g_company_compliance.sql
-- Description: Add Philippine compliance fields to the companies table, maintaining backward compatibility with existing 'tin'.

-- 1. Add new compliance fields and TIN architecture (without dropping/renaming existing tin)
ALTER TABLE public.companies
  ADD COLUMN base_tin text,
  ADD COLUMN branch_code text DEFAULT '00000',
  ADD COLUMN full_tin text GENERATED ALWAYS AS (
    CASE WHEN base_tin IS NOT NULL AND branch_code IS NOT NULL 
         THEN base_tin || '-' || branch_code 
         ELSE NULL END
  ) STORED,

  ADD COLUMN zip_code text,
  ADD COLUMN cda_registration_no text,
  ADD COLUMN registration_date date,
  ADD COLUMN bir_registration_date date,
  
  ADD COLUMN line_of_business text,
  ADD COLUMN psic_code text,
  
  ADD COLUMN contact_person text,
  ADD COLUMN phone text,
  ADD COLUMN mobile_no text,
  ADD COLUMN email text,
  ADD COLUMN website text,
  
  ADD COLUMN signatory_name text,
  ADD COLUMN signatory_title text,
  ADD COLUMN signatory_tin text,
  
  ADD COLUMN is_withholding_agent boolean NOT NULL DEFAULT false,
  ADD COLUMN is_large_taxpayer boolean NOT NULL DEFAULT false,
  ADD COLUMN is_peza_registered boolean NOT NULL DEFAULT false,
  ADD COLUMN is_boi_registered boolean NOT NULL DEFAULT false,
  ADD COLUMN is_bmbes_registered boolean NOT NULL DEFAULT false,
  
  ADD COLUMN ptu_cas_no text,
  ADD COLUMN ptu_cas_date_issued date,
  ADD COLUMN accounting_method text DEFAULT 'Accrual',
  ADD COLUMN inventory_costing_method text DEFAULT 'Weighted Average';

-- 2. Backfill base_tin and branch_code from existing tin
-- The seed data uses '123-456-789-000'. We extract the base (first 11 chars) and default branch to '00000' to match the new 5-digit BIR requirement.
UPDATE public.companies 
SET 
    base_tin = SUBSTRING(tin FROM 1 FOR 11),
    branch_code = '00000';
