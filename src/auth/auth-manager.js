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
    this.permissions = null;
    this.companyContext = null;
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

      // 2. Load company context
      const { data: companies, error: compErr } = await this.supabase
        .from('user_company_access')
        .select('company_id, is_company_admin')
        .eq('user_id', this.currentUser.id);
        
      if (compErr) {
        console.error('Error loading company context:', compErr);
      } else {
        this.companyContext = companies || [];
      }

      // 3. Load permissions
      const { data: roles, error: rolesErr } = await this.supabase
        .from('user_roles')
        .select('company_id, role_id')
        .eq('user_id', this.currentUser.id);
        
      if (rolesErr) {
        console.error('Error loading permissions:', rolesErr);
      } else {
        this.permissions = roles || [];
      }

    } catch (err) {
      console.error('AuthManager profile load error:', err);
    }
  }

  clearState() {
    this.session = null;
    this.currentUser = null;
    this.currentProfile = null;
    this.permissions = null;
    this.companyContext = null;
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

  async signInWithPassword(email, password) {
    return await this.supabase.auth.signInWithPassword({ email, password });
  }

  async signOut() {
    return await this.supabase.auth.signOut();
  }
}

// Export singleton
export const authManager = new AuthManager();
