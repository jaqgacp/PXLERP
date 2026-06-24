-- MIGRATION 018D: IMMUTABILITY GUARDS
-- Scope: Immutability triggers to prevent editing of posted documents, service fields, and filed taxes.
-- Status: Implements "Immutable History" philosophy.

-- 1. POSTED DOCUMENT PROTECTION FUNCTION
CREATE OR REPLACE FUNCTION public.fn_prevent_posted_modification()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IN ('posted', 'cancelled', 'voided') THEN
        RAISE EXCEPTION 'Immutability Violation: Cannot modify a document that is %.', OLD.status;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach to standard transaction tables (assuming standard naming conventions from 007-013)
DO $$
DECLARE
    tbl text;
    doc_tables text[] := ARRAY[
        'sales_invoices', 'purchase_orders', 'journal_entries', 
        'inventory_adjustments', 'fixed_asset_disposals'
    ];
BEGIN
    FOREACH tbl IN ARRAY doc_tables
    LOOP
        -- Check if table exists before adding trigger (safe guard)
        IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = tbl) THEN
            EXECUTE format('
                CREATE TRIGGER trg_prevent_posted_mod_%I
                BEFORE UPDATE OR DELETE ON public.%I
                FOR EACH ROW
                EXECUTE FUNCTION public.fn_prevent_posted_modification();
            ', tbl, tbl);
        END IF;
    END LOOP;
END $$;


-- 2. FILED TAX PROTECTION FUNCTION
CREATE OR REPLACE FUNCTION public.fn_prevent_filed_tax_modification()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.filing_status IN ('filed', 'accepted') THEN
        RAISE EXCEPTION 'Compliance Violation: Cannot modify a tax record that has been filed.';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach to compliance tables
DO $$
DECLARE
    tbl text;
    tax_tables text[] := ARRAY[
        'tax_return_filings', 'withholding_tax_certificates'
    ];
BEGIN
    FOREACH tbl IN ARRAY tax_tables
    LOOP
        IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = tbl) THEN
            EXECUTE format('
                CREATE TRIGGER trg_prevent_filed_mod_%I
                BEFORE UPDATE OR DELETE ON public.%I
                FOR EACH ROW
                EXECUTE FUNCTION public.fn_prevent_filed_tax_modification();
            ', tbl, tbl);
        END IF;
    END LOOP;
END $$;


-- 3. SERVICE-OWNED FIELD PROTECTION
-- For simplicity at the database foundation level without knowing exact application service roles,
-- we enforce a trigger that prevents updates to fields like "received_qty" or "current_outstanding"
-- if the role is not 'service_role'.
CREATE OR REPLACE FUNCTION public.fn_protect_service_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- If the executing role is an authenticated UI user, prevent changing service fields
    IF auth.role() = 'authenticated' THEN
        -- Example logic for a specific table (e.g., purchase_order_lines)
        IF TG_TABLE_NAME = 'purchase_order_lines' THEN
            IF NEW.received_qty IS DISTINCT FROM OLD.received_qty THEN
                RAISE EXCEPTION 'Security Violation: Cannot manually update received_qty. Must be updated by receiving service.';
            END IF;
        END IF;
        
        -- Example logic for accounts receivable (e.g., sales_invoices)
        IF TG_TABLE_NAME = 'sales_invoices' THEN
            IF NEW.amount_paid IS DISTINCT FROM OLD.amount_paid THEN
                RAISE EXCEPTION 'Security Violation: Cannot manually update amount_paid. Must be updated by payment service.';
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach to relevant line tables
DO $$
DECLARE
    tbl text;
    line_tables text[] := ARRAY[
        'purchase_order_lines', 'sales_invoices'
    ];
BEGIN
    FOREACH tbl IN ARRAY line_tables
    LOOP
        IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = tbl) THEN
            EXECUTE format('
                CREATE TRIGGER trg_protect_service_fields_%I
                BEFORE UPDATE ON public.%I
                FOR EACH ROW
                EXECUTE FUNCTION public.fn_protect_service_fields();
            ', tbl, tbl);
        END IF;
    END LOOP;
END $$;
