// -----------------------------------------------------------------------------
// PXL ERP - Auth Manager
// -----------------------------------------------------------------------------
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const SUPABASE_URL = 'http://127.0.0.1:54321';
const SUPABASE_ANON_KEY = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';

class AuthManager {
  constructor() {
    this.supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    this.session = null;
    this.currentUser = null;
    this.currentProfile = null;
    this.roleContext = null;
    this.companyContext = null;
    this.activeCompanyId = null;
    this.initialized = false;
  }

  async initialize() {
    if (this.initialized) return;

    // Restore session
    const { data: { session }, error } = await this.supabase.auth.getSession();
    if (error) {
      console.error('Error fetching session:', error);
    }
    
    this.session = session;
    this.currentUser = session?.user || null;

    if (this.currentUser) {
      await this.loadUserProfile();
    }

    // Listen to auth changes
    this.supabase.auth.onAuthStateChange(async (event, session) => {
      this.session = session;
      this.currentUser = session?.user || null;
      
      if (event === 'SIGNED_IN') {
        await this.loadUserProfile();
        window.location.reload();
      } else if (event === 'SIGNED_OUT') {
        this.clearState();
        window.location.hash = '#/login';
      }
    });

    this.initialized = true;
  }

  async loadUserProfile() {
    if (!this.currentUser) return;

    try {
      // 1. Load profile
      const { data: profile, error: profileErr } = await this.supabase
        .from('profiles')
        .select('*')
        .eq('id', this.currentUser.id)
        .single();
        
      if (profileErr && profileErr.code !== 'PGRST116') {
        console.error('Error loading profile:', profileErr);
      }
      this.currentProfile = profile || null;

      // 2. Load company context (directly from companies table to leverage RLS naturally)
      const { data: companies, error: compErr } = await this.supabase
        .from('companies')
        .select('id, code, name');
        
      if (compErr) {
        console.error('Error loading company context:', compErr);
        this.companyContext = [];
      } else {
        this.companyContext = companies || [];
      }

      // 3. Load role context
      const { data: roles, error: rolesErr } = await this.supabase
        .from('user_roles')
        .select('company_id, role_id')
        .eq('user_id', this.currentUser.id);
        
      if (rolesErr) {
        console.error('Error loading role context:', rolesErr);
      } else {
        this.roleContext = roles || [];
      }

      this.restoreActiveCompany();

    } catch (err) {
      console.error('AuthManager profile load error:', err);
    }
  }

  restoreActiveCompany() {
    if (!this.companyContext || this.companyContext.length === 0) {
      this.activeCompanyId = null;
      localStorage.removeItem('pxl_active_company_id');
      return;
    }

    const savedId = localStorage.getItem('pxl_active_company_id');
    const isValid = this.companyContext.some(c => c.id === savedId);

    if (isValid) {
      this.activeCompanyId = savedId;
    } else if (this.companyContext.length === 1) {
      this.activeCompanyId = this.companyContext[0].id;
      localStorage.setItem('pxl_active_company_id', this.activeCompanyId);
    } else {
      this.activeCompanyId = null;
      localStorage.removeItem('pxl_active_company_id');
    }
  }

  async refreshCompanyContext() {
    try {
      const { data: companies, error: compErr } = await this.supabase
        .from('companies')
        .select('id, code, name');
        
      if (compErr) {
        console.error('Error refreshing company context:', compErr);
      } else {
        this.companyContext = companies || [];
      }
    } catch (err) {
      console.error('AuthManager company context refresh error:', err);
    }
  }

  setActiveCompany(companyId) {
    if (!companyId) {
      this.activeCompanyId = null;
      localStorage.removeItem('pxl_active_company_id');
      return;
    }

    const isValid = this.companyContext?.some(c => c.id === companyId);
    if (!isValid) {
      console.warn('Attempted to set an invalid active company ID:', companyId);
      return;
    }

    this.activeCompanyId = companyId;
    localStorage.setItem('pxl_active_company_id', companyId);
  }

  getActiveCompanyId() {
    return this.activeCompanyId;
  }

  getActiveCompany() {
    if (!this.activeCompanyId || !this.companyContext) return null;
    return this.companyContext.find(c => c.id === this.activeCompanyId) || null;
  }

  requireActiveCompany() {
    const id = this.getActiveCompanyId();
    if (!id) {
      alert('Action blocked: No active company selected. Please select a company from the top navigation menu before proceeding.');
      throw new Error('No active company selected. Action blocked.');
    }
    return id;
  }

  clearState() {
    this.session = null;
    this.currentUser = null;
    this.currentProfile = null;
    this.roleContext = null;
    this.companyContext = null;
    this.activeCompanyId = null;
    localStorage.removeItem('pxl_active_company_id');
  }

  isAuthenticated() {
    return !!this.session;
  }

  getCurrentUser() {
    return this.currentUser;
  }

  getCurrentProfile() {
    return this.currentProfile;
  }

  getCompanyContext() {
    return this.companyContext;
  }

  getRoleContext() {
    return this.roleContext;
  }

  async signInWithPassword(email, password) {
    return await this.supabase.auth.signInWithPassword({ email, password });
  }

  async signOut() {
    return await this.supabase.auth.signOut();
  }
}

// Export singleton
export const authManager = new AuthManager();
