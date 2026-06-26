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

  -- 3. Insert into companies
  INSERT INTO public.companies
  SELECT * FROM jsonb_populate_record(null::public.companies, payload)
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
