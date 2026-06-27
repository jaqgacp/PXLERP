-- =============================================================================
-- PXL ERP - Phase 5B: Customer Master Foundation
-- =============================================================================
-- Tables: customers (altered), customer_addresses (recreated), customer_contacts (recreated)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. customers (ALTER existing from 006_master_data.sql)
-- ---------------------------------------------------------------------------

-- Drop old constraints and indexes
ALTER TABLE public.customers DROP CONSTRAINT IF EXISTS ck_customers_type;
ALTER TABLE public.customers DROP CONSTRAINT IF EXISTS ck_customers_vat_reg;
ALTER TABLE public.customers DROP CONSTRAINT IF EXISTS ck_customers_special_class;
ALTER TABLE public.customers DROP CONSTRAINT IF EXISTS ck_customers_credit_limit;
DROP INDEX IF EXISTS uq_customers_company_code;

-- Rename existing columns to match Phase 5B standard
ALTER TABLE public.customers RENAME COLUMN customer_code TO code;
ALTER TABLE public.customers RENAME COLUMN customer_name TO registered_name;
ALTER TABLE public.customers RENAME COLUMN vat_registration_status TO tax_type;
ALTER TABLE public.customers RENAME COLUMN currency_id TO default_currency_id;
ALTER TABLE public.customers RENAME COLUMN ar_account_id TO default_ar_account_id;
ALTER TABLE public.customers RENAME COLUMN sales_account_id TO default_sales_account_id;

-- Drop obsolete columns that conflict with new naming or are being flattened
ALTER TABLE public.customers DROP COLUMN IF EXISTS party_special_class;
ALTER TABLE public.customers DROP COLUMN IF EXISTS customer_type;

-- Add new columns for Phase 5B
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS entity_type text NOT NULL DEFAULT 'corporation' CHECK (entity_type IN ('corporation', 'individual', 'government', 'foreign'));
ALTER TABLE public.customers ALTER COLUMN entity_type DROP DEFAULT;

ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS customer_type text;

ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS tin_branch_code text;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS is_government boolean DEFAULT false;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS is_peza boolean DEFAULT false;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS is_boi boolean DEFAULT false;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS is_foreign boolean DEFAULT false;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS bir_registered_address text;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS default_branch_id uuid REFERENCES public.branches(id);
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS credit_hold boolean DEFAULT false;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS payment_terms_text text;

-- Remove old/deferred columns from 006
ALTER TABLE public.customers DROP COLUMN IF EXISTS payment_terms_id;
ALTER TABLE public.customers DROP COLUMN IF EXISTS is_ewt_agent;
ALTER TABLE public.customers DROP COLUMN IF EXISTS default_ewt_atc_id;

-- Re-apply correct constraints
ALTER TABLE public.customers ADD CONSTRAINT ck_customers_tax_type CHECK (tax_type IN ('vat', 'non_vat', 'exempt', 'zero_rated', 'foreign'));
ALTER TABLE public.customers ADD CONSTRAINT uq_customers_company_id UNIQUE (company_id, id);

-- Indexes for customers
CREATE UNIQUE INDEX customers_company_code_idx ON public.customers (company_id, code) WHERE deleted_at IS NULL;
CREATE INDEX customers_company_id_idx ON public.customers (company_id);
CREATE INDEX customers_registered_name_idx ON public.customers (registered_name);
CREATE INDEX customers_tin_idx ON public.customers (tin);
CREATE INDEX customers_is_active_idx ON public.customers (is_active);
CREATE INDEX IF NOT EXISTS customers_import_batch_id_idx ON public.customers (import_batch_id);

-- ---------------------------------------------------------------------------
-- 2. customer_addresses
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS public.customer_addresses CASCADE;
CREATE TABLE public.customer_addresses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.companies(id),
    customer_id uuid NOT NULL REFERENCES public.customers(id),
    address_type text NOT NULL CHECK (address_type IN ('billing', 'shipping', 'registered', 'other')),
    
    address_line1 text NOT NULL,
    address_line2 text,
    barangay text,
    city text,
    province text,
    region text,
    country text DEFAULT 'Philippines',
    zip_code text,
    
    is_default boolean DEFAULT false,
    is_active boolean DEFAULT true,
    import_batch_id uuid REFERENCES public.import_batches(id),
    
    created_at timestamptz DEFAULT now(),
    created_by uuid REFERENCES public.profiles(id),
    updated_at timestamptz,
    updated_by uuid REFERENCES public.profiles(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES public.profiles(id),

    -- Enforce that address belongs to the same company as the customer
    CONSTRAINT fk_customer_addresses_customer_company FOREIGN KEY (company_id, customer_id) REFERENCES public.customers(company_id, id)
);

CREATE INDEX customer_addresses_company_id_idx ON public.customer_addresses (company_id);
CREATE INDEX customer_addresses_customer_id_idx ON public.customer_addresses (customer_id);
CREATE INDEX customer_addresses_is_active_idx ON public.customer_addresses (is_active);
CREATE INDEX customer_addresses_import_batch_id_idx ON public.customer_addresses (import_batch_id);

-- ---------------------------------------------------------------------------
-- 3. customer_contacts
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS public.customer_contacts CASCADE;
CREATE TABLE public.customer_contacts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.companies(id),
    customer_id uuid NOT NULL REFERENCES public.customers(id),
    
    contact_name text NOT NULL,
    title text,
    department text,
    phone text,
    mobile text,
    email text,
    
    is_primary boolean DEFAULT false,
    is_billing_contact boolean DEFAULT false,
    is_active boolean DEFAULT true,
    import_batch_id uuid REFERENCES public.import_batches(id),
    
    created_at timestamptz DEFAULT now(),
    created_by uuid REFERENCES public.profiles(id),
    updated_at timestamptz,
    updated_by uuid REFERENCES public.profiles(id),
    deleted_at timestamptz,
    deleted_by uuid REFERENCES public.profiles(id),

    -- Enforce that contact belongs to the same company as the customer
    CONSTRAINT fk_customer_contacts_customer_company FOREIGN KEY (company_id, customer_id) REFERENCES public.customers(company_id, id)
);

CREATE INDEX customer_contacts_company_id_idx ON public.customer_contacts (company_id);
CREATE INDEX customer_contacts_customer_id_idx ON public.customer_contacts (customer_id);
CREATE INDEX customer_contacts_is_active_idx ON public.customer_contacts (is_active);
CREATE INDEX customer_contacts_import_batch_id_idx ON public.customer_contacts (import_batch_id);

-- =============================================================================
-- ROW LEVEL SECURITY (Policies dropped first to allow idempotent re-creation)
-- =============================================================================
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_contacts ENABLE ROW LEVEL SECURITY;

-- Clean up old 017c policies if they exist to avoid collision
DROP POLICY IF EXISTS customers_017c_select_company_or_super_admin ON public.customers;
DROP POLICY IF EXISTS customers_017c_insert_company_or_super_admin ON public.customers;
DROP POLICY IF EXISTS customers_017c_update_company_or_super_admin ON public.customers;

DROP POLICY IF EXISTS customers_select_company_or_super_admin ON public.customers;
DROP POLICY IF EXISTS customers_insert_company_or_super_admin ON public.customers;
DROP POLICY IF EXISTS customers_update_company_or_super_admin ON public.customers;

CREATE POLICY customers_select_company_or_super_admin ON public.customers FOR SELECT TO authenticated
USING (public.is_super_admin() OR company_id = ANY(public.user_company_ids()));

CREATE POLICY customers_insert_company_or_super_admin ON public.customers FOR INSERT TO authenticated
WITH CHECK (public.is_super_admin() OR company_id = ANY(public.user_company_ids()));

CREATE POLICY customers_update_company_or_super_admin ON public.customers FOR UPDATE TO authenticated
USING (public.is_super_admin() OR company_id = ANY(public.user_company_ids()));

-- Policies for customer_addresses
CREATE POLICY customer_addresses_select_company_or_super_admin ON public.customer_addresses FOR SELECT TO authenticated
USING (public.is_super_admin() OR company_id = ANY(public.user_company_ids()));

CREATE POLICY customer_addresses_insert_company_or_super_admin ON public.customer_addresses FOR INSERT TO authenticated
WITH CHECK (public.is_super_admin() OR company_id = ANY(public.user_company_ids()));

CREATE POLICY customer_addresses_update_company_or_super_admin ON public.customer_addresses FOR UPDATE TO authenticated
USING (public.is_super_admin() OR company_id = ANY(public.user_company_ids()));

-- Policies for customer_contacts
CREATE POLICY customer_contacts_select_company_or_super_admin ON public.customer_contacts FOR SELECT TO authenticated
USING (public.is_super_admin() OR company_id = ANY(public.user_company_ids()));

CREATE POLICY customer_contacts_insert_company_or_super_admin ON public.customer_contacts FOR INSERT TO authenticated
WITH CHECK (public.is_super_admin() OR company_id = ANY(public.user_company_ids()));

CREATE POLICY customer_contacts_update_company_or_super_admin ON public.customer_contacts FOR UPDATE TO authenticated
USING (public.is_super_admin() OR company_id = ANY(public.user_company_ids()));

-- =============================================================================
-- GRANTS
-- =============================================================================
GRANT SELECT, INSERT, UPDATE ON public.customers TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.customers TO service_role;

GRANT SELECT, INSERT, UPDATE ON public.customer_addresses TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.customer_addresses TO service_role;

GRANT SELECT, INSERT, UPDATE ON public.customer_contacts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.customer_contacts TO service_role;
