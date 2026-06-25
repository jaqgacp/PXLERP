// -----------------------------------------------------------------------------
// PXL ERP - Company Edit JS
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';

const supabase = authManager.supabase;
let currentCompanyId = null;

document.addEventListener('DOMContentLoaded', () => {
  initForm();
});

async function initForm() {
  const urlParams = new URLSearchParams(window.location.hash.split('?')[1]);
  currentCompanyId = urlParams.get('id');

  if (!currentCompanyId) {
    showError('No company ID provided.');
    return;
  }

  const btnSave = document.getElementById('btn-save');
  const authStatusEl = document.getElementById('auth-status');

  if (!authManager.isAuthenticated()) {
    authStatusEl.style.backgroundColor = '#f8d7da';
    authStatusEl.style.borderColor = '#f5c6cb';
    authStatusEl.style.color = '#721c24';
    authStatusEl.textContent = 'Not signed in — company save disabled';
    btnSave.disabled = true;
  } else {
    const user = authManager.getCurrentUser();
    authStatusEl.style.backgroundColor = '#d4edda';
    authStatusEl.style.borderColor = '#c3e6cb';
    authStatusEl.style.color = '#155724';
    authStatusEl.textContent = 'Signed in as: ' + (user.email || user.id);
  }

  btnSave.addEventListener('click', () => saveCompany());

  await loadCurrencies();
  await loadCompany(currentCompanyId);
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
    showError('Failed to load currencies: ' + err.message);
  }
}

async function loadCompany(id) {
  const statusEl = document.getElementById('page-status');
  try {
    const { data, error } = await supabase
      .from('companies')
      .select('*')
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
    
    document.getElementById('functional_currency_id').value = data.functional_currency_id || '';
    document.getElementById('fiscal_year_start_month').value = data.fiscal_year_start_month || '';
    document.getElementById('is_active').checked = data.is_active;

    statusEl.textContent = 'Ready';
  } catch (err) {
    console.error('Load error:', err);
    showError('Failed to load company details: ' + err.message);
    statusEl.textContent = 'Error loading data.';
  }
}

async function saveCompany() {
  const form = document.getElementById('company-edit-form');
  if (!form.reportValidity()) {
    return;
  }

  const errorEl = document.getElementById('form-error');
  const statusEl = document.getElementById('page-status');
  
  errorEl.style.display = 'none';
  statusEl.textContent = 'Saving...';
  setButtonsDisabled(true);

  try {
    const user = authManager.getCurrentUser();
    if (!user) {
      throw new Error("Cannot save company because no authenticated user is available.");
    }

    const updatedBy = user.id;

    // 2. Build payload
    const payload = {
      code: document.getElementById('code').value.trim(),
      name: document.getElementById('name').value.trim(),
      trade_name: document.getElementById('trade_name').value.trim() || null,
      business_type: document.getElementById('business_type').value,
      industry_classification: document.getElementById('industry_classification').value.trim() || null,
      logo_url: document.getElementById('logo_url').value.trim() || null,
      tin: document.getElementById('tin').value.trim(),
      tax_type: document.getElementById('tax_type').value,
      rdo_code: document.getElementById('rdo_code').value.trim() || null,
      sec_registration_no: document.getElementById('sec_registration_no').value.trim() || null,
      dti_registration_no: document.getElementById('dti_registration_no').value.trim() || null,
      bir_registered_address: document.getElementById('bir_registered_address').value.trim(),
      functional_currency_id: document.getElementById('functional_currency_id').value,
      fiscal_year_start_month: parseInt(document.getElementById('fiscal_year_start_month').value, 10),
      is_active: document.getElementById('is_active').checked,
      updated_by: updatedBy,
      updated_at: new Date().toISOString()
    };

    // 3. Update public.companies
    const { error } = await supabase
      .from('companies')
      .update(payload)
      .eq('id', currentCompanyId);

    if (error) throw error;

    statusEl.textContent = 'Saved successfully.';

    // Navigate back to list
    window.location.hash = '#/setup/company-setup';

  } catch (err) {
    console.error('Save error:', err);
    showError(err.message);
    statusEl.textContent = 'Save failed.';
    setButtonsDisabled(false);
  }
}

function showError(msg) {
  const errorEl = document.getElementById('form-error');
  errorEl.textContent = msg;
  errorEl.style.display = 'block';
}

function setButtonsDisabled(disabled) {
  document.getElementById('btn-save').disabled = disabled;
}
