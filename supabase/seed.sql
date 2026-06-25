-- =============================================================================
-- PXL ERP - LOCAL DEV SEED ONLY
-- =============================================================================
-- DO NOT DEPLOY TO PRODUCTION. 
-- This seeds an initial auth user, super admin profile, and base currency
-- to resolve the bootstrap paradox for local development.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Seed Local Auth User
-- Email: admin@local.dev
-- Password: password123
INSERT INTO auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'admin@local.dev',
  crypt('password123', gen_salt('bf')),
  now(),
  now(),
  now(),
  '',
  '',
  '',
  ''
) ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (
  id,
  user_id,
  provider_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000000',
  '{"sub":"00000000-0000-0000-0000-000000000000","email":"admin@local.dev"}',
  'email',
  now(),
  now(),
  now()
) ON CONFLICT (id) DO NOTHING;

-- 2. Seed Super Admin Profile
INSERT INTO public.profiles (
  id,
  first_name,
  last_name,
  display_name,
  is_super_admin,
  is_active
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'Local',
  'Admin',
  'Local Admin (DEV ONLY)',
  true,
  true
) ON CONFLICT (id) DO NOTHING;

-- 3. Seed Base Currency (PHP)
INSERT INTO public.currencies (
  id,
  code,
  name,
  symbol,
  is_base_currency,
  is_active,
  created_by
) VALUES (
  '11111111-1111-1111-1111-111111111111',
  'PHP',
  'Philippine Peso',
  '₱',
  true,
  true,
  '00000000-0000-0000-0000-000000000000'
) ON CONFLICT (id) DO NOTHING;
