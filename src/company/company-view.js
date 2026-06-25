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
    document.getElementById('business_type').value = data.business_type || '';
    document.getElementById('industry_classification').value = data.industry_classification || '';
    document.getElementById('logo_url').value = data.logo_url || '';
    document.getElementById('tin').value = data.tin || '';
    document.getElementById('tax_type').value = data.tax_type || '';
    document.getElementById('rdo_code').value = data.rdo_code || '';
    document.getElementById('sec_registration_no').value = data.sec_registration_no || '';
    document.getElementById('dti_registration_no').value = data.dti_registration_no || '';
    document.getElementById('bir_registered_address').value = data.bir_registered_address || '';
    
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
