-- =============================================================================
-- PXL ERP - LOCAL DEV SEED ONLY
-- =============================================================================
-- DO NOT DEPLOY TO PRODUCTION. 
-- This seeds an initial auth user, super admin profile, default company,
-- and assigns the necessary roles to resolve the bootstrap paradox.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    v_admin_id uuid;
    v_base_currency_id uuid := '11111111-1111-1111-1111-111111111111';
    v_company_id uuid;
    v_role_id uuid;
BEGIN
    -- 1. AUTH USER
    -- Check if user already exists
    SELECT id INTO v_admin_id FROM auth.users WHERE email = 'admin@local.dev';

    IF v_admin_id IS NULL THEN
        -- Generate a real UUID instead of zero UUID
        v_admin_id := gen_random_uuid();
        
        INSERT INTO auth.users (
            id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
            created_at, updated_at, confirmation_token, recovery_token, email_change_token_new, email_change
        ) VALUES (
            v_admin_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'admin@local.dev', crypt('password123', gen_salt('bf')), now(), now(), now(), '', '', '', ''
        );

        INSERT INTO auth.identities (
            id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
        ) VALUES (
            v_admin_id, v_admin_id, v_admin_id,
            json_build_object('sub', v_admin_id, 'email', 'admin@local.dev')::jsonb,
            'email', now(), now(), now()
        );
    END IF;

    -- 2. PROFILE
    INSERT INTO public.profiles (
        id, first_name, last_name, display_name, is_super_admin, is_active
    ) VALUES (
        v_admin_id, 'Local', 'Admin', 'Local Admin (DEV ONLY)', true, true
    ) ON CONFLICT (id) DO UPDATE SET is_super_admin = true, is_active = true;

    -- 3. BASE CURRENCY (PHP)
    INSERT INTO public.currencies (
        id, code, name, symbol, is_base_currency, is_active, created_by
    ) VALUES (
        v_base_currency_id, 'PHP', 'Philippine Peso', '₱', true, true, v_admin_id
    ) ON CONFLICT (id) DO UPDATE SET created_by = v_admin_id;

    -- 4. DEFAULT COMPANY (HQ)
    SELECT id INTO v_company_id FROM public.companies WHERE code = 'HQ';
    IF v_company_id IS NULL THEN
        v_company_id := gen_random_uuid();
        INSERT INTO public.companies (
            id, code, name, tin, base_tin, branch_code, bir_registered_address, tax_type, business_type, functional_currency_id, created_by
        ) VALUES (
            v_company_id, 'HQ', 'Headquarters', '000-000-000-000', '000-000-000', '00000', 'Metro Manila, Philippines', 'vat', 'corporation', v_base_currency_id, v_admin_id
        );
    END IF;

    -- 5. USER COMPANY ACCESS
    IF NOT EXISTS (SELECT 1 FROM public.user_company_access WHERE user_id = v_admin_id AND company_id = v_company_id) THEN
        INSERT INTO public.user_company_access (
            user_id, company_id, is_company_admin, granted_by
        ) VALUES (
            v_admin_id, v_company_id, true, v_admin_id
        );
    END IF;

    -- 6. DEFAULT ROLE
    SELECT id INTO v_role_id FROM public.roles WHERE role_code = 'SUPER_ADMIN';
    IF v_role_id IS NULL THEN
        v_role_id := gen_random_uuid();
        INSERT INTO public.roles (
            id, role_code, role_name, description, is_system, created_by
        ) VALUES (
            v_role_id, 'SUPER_ADMIN', 'Super Admin Role', 'System-wide super admin access', true, v_admin_id
        );
    END IF;

    -- 7. USER ROLES
    IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = v_admin_id AND role_id = v_role_id AND company_id = v_company_id) THEN
        INSERT INTO public.user_roles (
            user_id, role_id, company_id, granted_by
        ) VALUES (
            v_admin_id, v_role_id, v_company_id, v_admin_id
        );
    END IF;

END $$;
