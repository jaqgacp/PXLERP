-- MIGRATION 018B: ADAPTIVE WORKSPACE & FEATURE CATALOG
-- Scope: 12 Tables establishing the canonical feature definitions and workspace metadata.
-- Status: Implements the "No Hardcoding" and "Adaptive Workspace" mandate.

-- 1. THE CANONICAL FEATURE CATALOG
CREATE TABLE IF NOT EXISTS public.feature_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feature_key TEXT UNIQUE NOT NULL,
    feature_name TEXT NOT NULL,
    description TEXT,
    module_group TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. WORKSPACE METADATA (SYSTEM LEVEL)
CREATE TABLE IF NOT EXISTS public.workspace_modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_key TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    icon_name TEXT,
    display_order INT NOT NULL,
    required_feature_id UUID REFERENCES public.feature_definitions(id),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workspace_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id UUID REFERENCES public.workspace_modules(id) ON DELETE CASCADE,
    category_key TEXT NOT NULL,
    display_name TEXT NOT NULL,
    display_order INT NOT NULL,
    required_feature_id UUID REFERENCES public.feature_definitions(id),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workspace_pages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES public.workspace_categories(id) ON DELETE CASCADE,
    page_key TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    route_path TEXT NOT NULL,
    display_order INT NOT NULL,
    required_feature_id UUID REFERENCES public.feature_definitions(id),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workspace_dashboards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES public.workspace_categories(id) ON DELETE CASCADE,
    dashboard_key TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    display_order INT NOT NULL,
    required_feature_id UUID REFERENCES public.feature_definitions(id),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.dashboard_widgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dashboard_id UUID REFERENCES public.workspace_dashboards(id) ON DELETE CASCADE,
    widget_key TEXT NOT NULL,
    component_name TEXT NOT NULL,
    default_size JSONB NOT NULL,
    required_feature_id UUID REFERENCES public.feature_definitions(id),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workspace_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES public.workspace_categories(id) ON DELETE CASCADE,
    report_key TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    report_url TEXT NOT NULL,
    display_order INT NOT NULL,
    required_feature_id UUID REFERENCES public.feature_definitions(id),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. WORKSPACE CONFIGURATION
CREATE TABLE IF NOT EXISTS public.workspace_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    workspace_name TEXT NOT NULL,
    description TEXT,
    is_default BOOLEAN DEFAULT false,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.workspace_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID REFERENCES public.workspace_definitions(id) ON DELETE CASCADE,
    item_type TEXT NOT NULL CHECK (item_type IN ('module', 'category', 'page', 'dashboard', 'report')),
    item_id UUID NOT NULL, -- Logical FK to corresponding workspace_* table
    is_visible BOOLEAN DEFAULT true,
    custom_display_order INT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. VISIBILITY AND ASSIGNMENTS
CREATE TABLE IF NOT EXISTS public.company_feature_visibility (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    feature_id UUID REFERENCES public.feature_definitions(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT true,
    enabled_by UUID REFERENCES auth.users(id),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(company_id, feature_id)
);

CREATE TABLE IF NOT EXISTS public.role_workspace_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    role_id UUID REFERENCES public.roles(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES public.workspace_definitions(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(role_id, workspace_id)
);

CREATE TABLE IF NOT EXISTS public.user_workspace_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID REFERENCES public.companies(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    workspace_id UUID REFERENCES public.workspace_definitions(id) ON DELETE CASCADE,
    preferences_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, workspace_id)
);

-- INDEXES
CREATE INDEX IF NOT EXISTS idx_workspace_def_company ON public.workspace_definitions(company_id);
CREATE INDEX IF NOT EXISTS idx_company_feature_vis ON public.company_feature_visibility(company_id);

-- ENABLE RLS
ALTER TABLE public.feature_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_dashboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dashboard_widgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_feature_visibility ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_workspace_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_workspace_preferences ENABLE ROW LEVEL SECURITY;
