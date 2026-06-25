// -----------------------------------------------------------------------------
// PXL ERP - Company View JS
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';

const supabase = authManager.supabase;

initForm();

async function initForm() {
  const urlParams = new URLSearchParams(window.location.hash.split('?')[1]);
  const companyId = urlParams.get('id');

  if (!companyId) {
    showError('No company ID provided.');
    return;
  }

  const btnEdit = document.getElementById('btn-edit');
  btnEdit.addEventListener('click', () => {
    window.location.hash = '#/setup/company-setup/edit?id=' + companyId;
  });

  await loadCompany(companyId);
}

async function loadCompany(id) {
  const statusEl = document.getElementById('page-status');
  try {
    const { data, error } = await supabase
      .from('companies')
      .select('*, currencies(code)')
      .eq('id', id)
      .single();

    if (error) throw error;
    if (!data) throw new Error('Company not found.');

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

    document.getElementById('functional_currency_id').value = data.currencies?.code || data.functional_currency_id;
    document.getElementById('fiscal_year_start_month').value = data.fiscal_year_start_month || '';
    document.getElementById('is_active').checked = data.is_active;

    statusEl.textContent = 'Ready';
  } catch (err) {
    console.error('Load error:', err);
    showError('Failed to load company details: ' + err.message);
    statusEl.textContent = 'Error loading data.';
  }
}

function showError(msg) {
  const errorEl = document.getElementById('form-error');
  errorEl.textContent = msg;
  errorEl.style.display = 'block';
}
