-- =============================================================================
-- PXL ERP - OFFICIAL DEVELOPMENT SEED (GOLDEN DATASET)
-- =============================================================================
-- DO NOT DEPLOY TO PRODUCTION. 
-- This seeds an initial auth user, super admin profile, the PXL Demo Company,
-- Branches, and Fiscal Calendar.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    v_admin_id uuid;
    v_base_currency_id uuid := '11111111-1111-1111-1111-111111111111';
    v_company_id uuid;
    v_role_id uuid;
    v_fiscal_year_id uuid;
    i integer;
    v_date_from date;
    v_date_to date;
BEGIN
    -- ==========================================
    -- 1. AUTH USER & IDENTITY
    -- ==========================================
    SELECT id INTO v_admin_id FROM auth.users WHERE email = 'admin@local.dev';

    IF v_admin_id IS NULL THEN
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

    -- ==========================================
    -- 2. ADMIN PROFILE
    -- ==========================================
    INSERT INTO public.profiles (
        id, first_name, last_name, display_name, is_super_admin, is_active
    ) VALUES (
        v_admin_id, 'Local', 'Admin', 'Local Admin (DEV ONLY)', true, true
    ) ON CONFLICT (id) DO UPDATE SET is_super_admin = true, is_active = true;

    -- ==========================================
    -- 3. CURRENCY (PHP)
    -- ==========================================
    INSERT INTO public.currencies (
        id, code, name, symbol, is_base_currency, is_active, created_by
    ) VALUES (
        v_base_currency_id, 'PHP', 'Philippine Peso', '₱', true, true, v_admin_id
    ) ON CONFLICT (id) DO UPDATE SET created_by = v_admin_id;

    -- ==========================================
    -- 4. GOLDEN REFERENCE COMPANY (PXL)
    -- ==========================================
    SELECT id INTO v_company_id FROM public.companies WHERE code = 'PXL';
    IF v_company_id IS NULL THEN
        v_company_id := gen_random_uuid();
        INSERT INTO public.companies (
            id, code, name, trade_name, tin, base_tin, branch_code, bir_registered_address, tax_type, business_type, functional_currency_id, is_active, created_by
        ) VALUES (
            v_company_id, 'PXL', 'PXL Business Solutions Inc.', 'PXL ERP', '123-456-789-00000', '123-456-789', '00000', 'Makati City, Metro Manila, Philippines', 'vat', 'corporation', v_base_currency_id, true, v_admin_id
        );
    END IF;

    -- ==========================================
    -- 5. COMPANY ACCESS & ROLES
    -- ==========================================
    IF NOT EXISTS (SELECT 1 FROM public.user_company_access WHERE user_id = v_admin_id AND company_id = v_company_id) THEN
        INSERT INTO public.user_company_access (
            user_id, company_id, is_company_admin, granted_by
        ) VALUES (
            v_admin_id, v_company_id, true, v_admin_id
        );
    END IF;

    SELECT id INTO v_role_id FROM public.roles WHERE role_code = 'SUPER_ADMIN';
    IF v_role_id IS NULL THEN
        v_role_id := gen_random_uuid();
        INSERT INTO public.roles (
            id, role_code, role_name, description, is_system, created_by
        ) VALUES (
            v_role_id, 'SUPER_ADMIN', 'Super Admin Role', 'System-wide super admin access', true, v_admin_id
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = v_admin_id AND role_id = v_role_id AND company_id = v_company_id) THEN
        INSERT INTO public.user_roles (
            user_id, role_id, company_id, granted_by
        ) VALUES (
            v_admin_id, v_role_id, v_company_id, v_admin_id
        );
    END IF;

    -- ==========================================
    -- 6. BRANCHES
    -- ==========================================
    -- Head Office
    IF NOT EXISTS (SELECT 1 FROM public.branches WHERE company_id = v_company_id AND code = 'MAIN') THEN
        INSERT INTO public.branches (
            company_id, code, name, address, tin_suffix, bir_registered, is_head_office, is_active, created_by,
            rdo_code, contact_person, phone, email, line_of_business
        ) VALUES (
            v_company_id, 'MAIN', 'Head Office', 'Ayala Ave, Makati City', '00000', true, true, true, v_admin_id,
            '050', 'Juan Dela Cruz', '02-8123-4567', 'admin@pxl.local', 'Software Development'
        );
    END IF;

    -- Makati Branch
    IF NOT EXISTS (SELECT 1 FROM public.branches WHERE company_id = v_company_id AND code = 'MKT') THEN
        INSERT INTO public.branches (
            company_id, code, name, address, tin_suffix, bir_registered, is_head_office, is_active, created_by,
            rdo_code, contact_person, phone, email, line_of_business
        ) VALUES (
            v_company_id, 'MKT', 'Makati Branch', 'Salcedo Village, Makati City', '00001', true, false, true, v_admin_id,
            '050', 'Maria Clara', '02-8765-4321', 'makati@pxl.local', 'Sales & Consulting'
        );
    END IF;

    -- Cebu Branch
    IF NOT EXISTS (SELECT 1 FROM public.branches WHERE company_id = v_company_id AND code = 'CEB') THEN
        INSERT INTO public.branches (
            company_id, code, name, address, tin_suffix, bir_registered, is_head_office, is_active, created_by,
            rdo_code, contact_person, phone, email, line_of_business
        ) VALUES (
            v_company_id, 'CEB', 'Cebu Branch', 'Cebu IT Park, Cebu City', '00002', true, false, true, v_admin_id,
            '081', 'Lapu Lapu', '032-234-5678', 'cebu@pxl.local', 'Regional Operations'
        );
    END IF;

    -- Davao Branch
    IF NOT EXISTS (SELECT 1 FROM public.branches WHERE company_id = v_company_id AND code = 'DVO') THEN
        INSERT INTO public.branches (
            company_id, code, name, address, tin_suffix, bir_registered, is_head_office, is_active, created_by,
            rdo_code, contact_person, phone, email, line_of_business
        ) VALUES (
            v_company_id, 'DVO', 'Davao Branch', 'SM Lanang, Davao City', '00003', true, false, true, v_admin_id,
            '113', 'Jose Rizal', '082-345-6789', 'davao@pxl.local', 'Customer Support'
        );
    END IF;

    -- BGC Satellite Office
    IF NOT EXISTS (SELECT 1 FROM public.branches WHERE company_id = v_company_id AND code = 'BGC') THEN
        INSERT INTO public.branches (
            company_id, code, name, address, tin_suffix, bir_registered, is_head_office, is_active, created_by,
            rdo_code, contact_person, phone, email, line_of_business
        ) VALUES (
            v_company_id, 'BGC', 'BGC Satellite Office', 'Bonifacio Global City, Taguig', '00004', true, false, true, v_admin_id,
            '044', 'Andres Bonifacio', '02-8987-6543', 'bgc@pxl.local', 'Marketing'
        );
    END IF;

    -- ==========================================
    -- 7. FISCAL CALENDAR
    -- ==========================================
    SELECT id INTO v_fiscal_year_id FROM public.fiscal_years WHERE company_id = v_company_id AND year_code = '2026';
    
    IF v_fiscal_year_id IS NULL THEN
        v_fiscal_year_id := gen_random_uuid();
        
        INSERT INTO public.fiscal_years (
            id, company_id, year_code, date_from, date_to, is_current, status, created_by
        ) VALUES (
            v_fiscal_year_id, v_company_id, '2026', '2026-01-01', '2026-12-31', true, 'open', v_admin_id
        );

        -- Generate 12 Fiscal Periods
        FOR i IN 1..12 LOOP
            v_date_from := make_date(2026, i, 1);
            v_date_to := (v_date_from + interval '1 month' - interval '1 day')::date;
            
            INSERT INTO public.fiscal_periods (
                company_id, fiscal_year_id, period_number, period_name, date_from, date_to, quarter, status, created_by
            ) VALUES (
                v_company_id, v_fiscal_year_id, i, to_char(v_date_from, 'FMMonth') || ' 2026', v_date_from, v_date_to,
                CASE 
                    WHEN i BETWEEN 1 AND 3 THEN 1
                    WHEN i BETWEEN 4 AND 6 THEN 2
                    WHEN i BETWEEN 7 AND 9 THEN 3
                    ELSE 4
                END,
                'open', v_admin_id
            );
        END LOOP;
    END IF;

END $$;
