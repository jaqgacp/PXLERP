-- =============================================================================
-- Migration: 20260626000003_company_create_rpc.sql
-- Description: Transactional RPC for Company Creation
-- =============================================================================

CREATE OR REPLACE FUNCTION public.create_company(payload JSONB)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_company_id UUID;
  v_uid UUID;
BEGIN
  -- 1. Ensure authenticated user
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 2. Force created_by to be the authenticated user
  payload := payload || jsonb_build_object('created_by', v_uid);

  -- 3. Insert into companies explicitly defining columns to avoid generated columns like full_tin
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
    fiscal_year_start_month, is_active, created_by, logo_url
  FROM jsonb_populate_record(null::public.companies, payload)
  RETURNING id INTO v_new_company_id;

  -- 4. Automatically grant access to the creator as company admin
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

  RETURN v_new_company_id;
END;
$$;
