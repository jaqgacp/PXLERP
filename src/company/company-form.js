// -----------------------------------------------------------------------------
// PXL ERP - Unified Company Form
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';
import { ErpFormHelper, Toast } from '../shared/erp-form-helper.js';

const supabase = authManager.supabase;
let currentRecordId = null;

export async function init() {
  const urlParams = new URLSearchParams(window.location.hash.split('?')[1]);
  currentRecordId = urlParams.get('id');

  const helper = new ErpFormHelper({
    moduleName: 'Company',
    listRoute: '#/setup/company-setup',
    onInit: async (mode) => {
      await loadCurrencies();

      // Live update for Full TIN
      const baseTinInput = document.getElementById('base_tin');
      const branchCodeInput = document.getElementById('branch_code');
      const fullTinInput = document.getElementById('full_tin');

      const updateFullTin = () => {
        const base = baseTinInput.value.trim();
        const branch = branchCodeInput.value.trim();
        if (base) {
          fullTinInput.value = base + '-' + (branch || '00000');
        } else {
          fullTinInput.value = '';
        }
      };

      baseTinInput.addEventListener('input', updateFullTin);
      branchCodeInput.addEventListener('input', updateFullTin);
    },
    
    onLoad: async () => {
      if (!currentRecordId) throw new Error('No company ID provided.');

      const { data, error } = await supabase
        .from('companies')
        .select('*')
        .eq('id', currentRecordId)
        .single();

      if (error) throw error;
      if (!data) throw new Error('Company not found.');

      // Map data to fields
      document.getElementById('code').value = data.code || '';
      document.getElementById('name').value = data.name || '';
      document.getElementById('trade_name').value = data.trade_name || '';
      
      document.getElementById('base_tin').value = data.base_tin || '';
      document.getElementById('branch_code').value = data.branch_code || '00000';
      document.getElementById('full_tin').value = data.full_tin || '';

      document.getElementById('tax_type').value = data.tax_type || '';
      document.getElementById('business_type').value = data.business_type || '';
      document.getElementById('rdo_code').value = data.rdo_code || '';
      
      document.getElementById('bir_registration_date').value = data.bir_registration_date || '';
      document.getElementById('sec_registration_no').value = data.sec_registration_no || '';
      document.getElementById('dti_registration_no').value = data.dti_registration_no || '';
      document.getElementById('cda_registration_no').value = data.cda_registration_no || '';
      document.getElementById('registration_date').value = data.registration_date || '';
      
      document.getElementById('line_of_business').value = data.line_of_business || '';
      document.getElementById('psic_code').value = data.psic_code || '';
      document.getElementById('industry_classification').value = data.industry_classification || '';

      document.getElementById('bir_registered_address').value = data.bir_registered_address || '';
      document.getElementById('zip_code').value = data.zip_code || '';
      document.getElementById('contact_person').value = data.contact_person || '';
      document.getElementById('phone').value = data.phone || '';
      document.getElementById('mobile_no').value = data.mobile_no || '';
      document.getElementById('email').value = data.email || '';
      document.getElementById('website').value = data.website || '';

      document.getElementById('is_withholding_agent').checked = data.is_withholding_agent || false;
      document.getElementById('is_large_taxpayer').checked = data.is_large_taxpayer || false;
      document.getElementById('is_peza_registered').checked = data.is_peza_registered || false;
      document.getElementById('is_boi_registered').checked = data.is_boi_registered || false;
      document.getElementById('is_bmbes_registered').checked = data.is_bmbes_registered || false;

      document.getElementById('signatory_name').value = data.signatory_name || '';
      document.getElementById('signatory_title').value = data.signatory_title || '';
      document.getElementById('signatory_tin').value = data.signatory_tin || '';

      document.getElementById('ptu_cas_no').value = data.ptu_cas_no || '';
      document.getElementById('ptu_cas_date_issued').value = data.ptu_cas_date_issued || '';
      document.getElementById('accounting_method').value = data.accounting_method || 'Accrual';
      document.getElementById('inventory_costing_method').value = data.inventory_costing_method || 'Weighted Average';

      document.getElementById('functional_currency_id').value = data.functional_currency_id || '';
      document.getElementById('fiscal_year_start_month').value = data.fiscal_year_start_month || '';
      document.getElementById('is_active').checked = data.is_active;
    },

    buildPayload: () => {
      const baseTin = document.getElementById('base_tin').value.trim();
      const branchCode = document.getElementById('branch_code').value.trim() || '00000';
      const legacyTin = baseTin + '-' + branchCode;

      return {
        code: document.getElementById('code').value.trim(),
        name: document.getElementById('name').value.trim(),
        trade_name: document.getElementById('trade_name').value.trim() || null,
        
        base_tin: baseTin,
        branch_code: branchCode,
        tin: legacyTin, // Backward compatibility

        tax_type: document.getElementById('tax_type').value,
        business_type: document.getElementById('business_type').value,
        rdo_code: document.getElementById('rdo_code').value.trim() || null,
        
        bir_registration_date: document.getElementById('bir_registration_date').value || null,
        sec_registration_no: document.getElementById('sec_registration_no').value.trim() || null,
        dti_registration_no: document.getElementById('dti_registration_no').value.trim() || null,
        cda_registration_no: document.getElementById('cda_registration_no').value.trim() || null,
        registration_date: document.getElementById('registration_date').value || null,
        
        line_of_business: document.getElementById('line_of_business').value.trim() || null,
        psic_code: document.getElementById('psic_code').value.trim() || null,
        industry_classification: document.getElementById('industry_classification').value.trim() || null,

        bir_registered_address: document.getElementById('bir_registered_address').value.trim(),
        zip_code: document.getElementById('zip_code').value.trim(),
        contact_person: document.getElementById('contact_person').value.trim() || null,
        phone: document.getElementById('phone').value.trim(),
        mobile_no: document.getElementById('mobile_no').value.trim() || null,
        email: document.getElementById('email').value.trim(),
        website: document.getElementById('website').value.trim() || null,

        is_withholding_agent: document.getElementById('is_withholding_agent').checked,
        is_large_taxpayer: document.getElementById('is_large_taxpayer').checked,
        is_peza_registered: document.getElementById('is_peza_registered').checked,
        is_boi_registered: document.getElementById('is_boi_registered').checked,
        is_bmbes_registered: document.getElementById('is_bmbes_registered').checked,

        signatory_name: document.getElementById('signatory_name').value.trim(),
        signatory_title: document.getElementById('signatory_title').value.trim(),
        signatory_tin: document.getElementById('signatory_tin').value.trim(),

        ptu_cas_no: document.getElementById('ptu_cas_no').value.trim() || null,
        ptu_cas_date_issued: document.getElementById('ptu_cas_date_issued').value || null,
        accounting_method: document.getElementById('accounting_method').value,
        inventory_costing_method: document.getElementById('inventory_costing_method').value,

        functional_currency_id: document.getElementById('functional_currency_id').value,
        fiscal_year_start_month: parseInt(document.getElementById('fiscal_year_start_month').value, 10),
        is_active: document.getElementById('is_active').checked
      };
    },

    onSave: async (payload, isNew) => {
      const user = authManager.getCurrentUser();
      if (!user) throw new Error("Cannot save company because no authenticated user is available.");

      if (isNew) {
        payload.created_by = user.id;

        // Transactional Insert via RPC securely bootstraps the new tenant and user_company_access
        const { data: newCompanyId, error } = await supabase.rpc('create_company', { payload });
        
        if (error) throw new Error(error.message);
        if (!newCompanyId) throw new Error("Company creation failed: No ID returned.");

        currentRecordId = newCompanyId;

        // Auto-set as active company if none was selected
        if (!authManager.getActiveCompanyId()) {
          authManager.setActiveCompany(newCompanyId);
        }
      } else {
        payload.updated_by = user.id;
        payload.updated_at = new Date().toISOString();

        const { error } = await supabase
          .from('companies')
          .update(payload)
          .eq('id', currentRecordId);
        
        if (error) throw error;
      }

      // Refresh Company Context and UI Selector (in case name/code changed)
      if (typeof authManager.refreshCompanyContext === 'function') {
        await authManager.refreshCompanyContext();
        if (typeof window.updateAuthUI === 'function') {
          window.updateAuthUI();
        }
      }

      return true;
    }
  });

  await helper.init();
}

async function loadCurrencies() {
  const select = document.getElementById('functional_currency_id');
  try {
    const { data, error } = await supabase
      .from('currencies')
      .select('id, code, name')
      .eq('is_active', true)
      .order('code', { ascending: true });

    if (error) throw error;
    
    if (!data || data.length === 0) {
      Toast.warning('Create or seed Currency first before creating Company.');
      select.innerHTML = '<option value="">No currencies found</option>';
      return;
    }

    select.innerHTML = '<option value="">Select...</option>';
    data.forEach(c => {
      const opt = document.createElement('option');
      opt.value = c.id;
      opt.textContent = `${c.code} - ${c.name}`;
      select.appendChild(opt);
    });
  } catch (err) {
    console.error('Failed to load currencies', err);
    select.innerHTML = '<option value="">Error loading currencies</option>';
    Toast.error('Failed to load currencies: ' + err.message);
  }
}
