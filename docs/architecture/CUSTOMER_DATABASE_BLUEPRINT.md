# Customer Database Blueprint

## 1. Core Table: `customers`
Stores the singular identity and unified financial defaults of the customer.

```sql
CREATE TABLE public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id),
    code TEXT NOT NULL, -- e.g., "CUST-0001"
    
    -- Identity
    entity_type TEXT NOT NULL CHECK (entity_type IN ('Corporate', 'Individual', 'Government')),
    registered_name TEXT NOT NULL,
    trade_name TEXT,
    first_name TEXT, -- Null if Corporate
    last_name TEXT,  -- Null if Corporate
    
    -- Tax & Compliance
    tin TEXT,
    tin_suffix TEXT,
    tax_type TEXT NOT NULL CHECK (tax_type IN ('VAT', 'Non-VAT', 'Zero-Rated', 'Exempt')),
    classification TEXT, -- e.g., PEZA, BOI, Regular
    
    -- Financial Defaults
    currency_id UUID REFERENCES public.currencies(id),
    default_ar_account_id UUID REFERENCES public.chart_of_accounts(id),
    default_sales_account_id UUID REFERENCES public.chart_of_accounts(id),
    
    -- DEFERRED TO LATER PHASES (Tables do not exist yet)
    -- payment_term_id UUID REFERENCES public.payment_terms(id),
    -- tax_code_id UUID REFERENCES public.tax_codes(id),
    -- customer_group_id UUID REFERENCES public.customer_groups(id),
    -- industry_id UUID REFERENCES public.industries(id),
    -- salesperson_id UUID REFERENCES public.employees(id),
    
    -- Credit Management
    credit_limit NUMERIC(15,5) DEFAULT 0,
    credit_hold BOOLEAN DEFAULT false,
    
    -- System & Audit
    import_batch_id UUID,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID NOT NULL REFERENCES public.profiles(id),
    updated_at TIMESTAMPTZ,
    updated_by UUID REFERENCES public.profiles(id)
);
```

## 2. Sub-Table: `customer_addresses`
Allows a customer to have multiple shipping and billing addresses. By keeping this strongly typed to `customers`, we maintain perfect referential integrity.

```sql
CREATE TABLE public.customer_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    address_type TEXT NOT NULL CHECK (address_type IN ('Billing', 'Shipping', 'Both')),
    is_default BOOLEAN DEFAULT false,
    
    attention_to TEXT,
    street_address TEXT NOT NULL,
    barangay TEXT,
    city TEXT NOT NULL,
    province TEXT,
    zip_code TEXT,
    country TEXT DEFAULT 'Philippines',
    
    created_at TIMESTAMPTZ DEFAULT now()
);
```

## 3. Sub-Table: `customer_contacts`
Allows a customer to have multiple distinct human contacts.

```sql
CREATE TABLE public.customer_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    contact_type TEXT CHECK (contact_type IN ('Primary', 'Accounting', 'Purchasing', 'Executive', 'Other')),
    is_default BOOLEAN DEFAULT false,
    
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    job_title TEXT,
    email TEXT,
    phone TEXT,
    mobile TEXT,
    
    created_at TIMESTAMPTZ DEFAULT now()
);
```

## 4. Sub-Table: `customer_attachments` (Future hook)
For storing BIR 2303, DTI Permits, SEC Registrations.

```sql
CREATE TABLE public.customer_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
    document_type TEXT NOT NULL, -- e.g., 'BIR 2303', 'SEC Certificate'
    file_url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);
```
