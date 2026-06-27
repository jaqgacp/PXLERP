-- =============================================================================
-- Migration: 20260626000003_company_bootstrap_rpc.sql
-- Description: Atomic RPC for Company Bootstrap
-- =============================================================================

CREATE OR REPLACE FUNCTION public.bootstrap_company(payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_company_id UUID;
  v_uid UUID;
  v_currency_id UUID;
  v_branch_code TEXT;
BEGIN
  -- 1. Ensure authenticated user
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 2. Validate Currency (ensure the frontend passed a valid one)
  v_currency_id := (payload->>'functional_currency_id')::UUID;
  IF v_currency_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.currencies WHERE id = v_currency_id) THEN
    RAISE EXCEPTION 'Invalid or missing functional currency';
  END IF;

  -- 3. Remove audit fields from payload so frontend cannot spoof them
  payload := payload - 'id' - 'created_by' - 'updated_by' - 'created_at' - 'updated_at' - 'deleted_by' - 'deleted_at' - 'full_tin';

  -- 4. Extract branch_code for the branch creation
  v_branch_code := COALESCE(payload->>'branch_code', '00000');

  -- 5. Insert into companies explicitly defining columns
  INSERT INTO public.companies (
    code, name, trade_name, base_tin, branch_code, tin, tax_type, business_type, 
    rdo_code, bir_registration_date, sec_registration_no, dti_registration_no, 
    cda_registration_no, registration_date, line_of_business, psic_code, 
    industry_classification, bir_registered_address, zip_code, contact_person, 
    phone, mobile_no, email, website, is_withholding_agent, is_large_taxpayer, 
    is_peza_registered, is_boi_registered, is_bmbes_registered, signatory_name, 
    signatory_title, signatory_tin, ptu_cas_no, ptu_cas_date_issued, 
    accounting_method, inventory_costing_method, functional_currency_id, 
    fiscal_year_start_month, is_active, created_by, logo_url
  )
  SELECT 
    code, name, trade_name, base_tin, branch_code, tin, tax_type, business_type, 
    rdo_code, bir_registration_date, sec_registration_no, dti_registration_no, 
    cda_registration_no, registration_date, line_of_business, psic_code, 
    industry_classification, bir_registered_address, zip_code, contact_person, 
    phone, mobile_no, email, website, is_withholding_agent, is_large_taxpayer, 
    is_peza_registered, is_boi_registered, is_bmbes_registered, signatory_name, 
    signatory_title, signatory_tin, ptu_cas_no, ptu_cas_date_issued, 
    accounting_method, inventory_costing_method, functional_currency_id, 
    fiscal_year_start_month, is_active, v_uid, logo_url
  FROM jsonb_populate_record(null::public.companies, payload)
  RETURNING id INTO v_new_company_id;

  -- 6. Automatically grant access to the creator as company admin
  INSERT INTO public.user_company_access (
    user_id,
    company_id,
    is_company_admin,
    granted_by
  ) VALUES (
    v_uid,
    v_new_company_id,
    true,
    v_uid
  );

  -- 7. Create default Head Office branch
  INSERT INTO public.branches (
    company_id,
    code,
    name,
    tin_suffix,
    is_head_office,
    bir_registered,
    is_active,
    created_by
  ) VALUES (
    v_new_company_id,
    'MAIN',
    'Head Office',
    v_branch_code,
    true,
    true,
    true,
    v_uid
  );

  RETURN v_new_company_id;
END;
$$;
