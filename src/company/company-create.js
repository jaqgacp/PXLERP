// -----------------------------------------------------------------------------
// PXL ERP - Company Create JS
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';

const supabase = authManager.supabase;

document.addEventListener('DOMContentLoaded', () => {
  initForm();
});

async function initForm() {
  const btnSave = document.getElementById('btn-save');
  const btnSaveNew = document.getElementById('btn-save-new');
  const statusEl = document.getElementById('page-status');
  const authStatusEl = document.getElementById('auth-status');

  statusEl.textContent = 'Loading form dependencies...';

  // We rely on route protection now, but let's keep the banner as requested.
  if (!authManager.isAuthenticated()) {
    authStatusEl.style.backgroundColor = '#f8d7da';
    authStatusEl.style.borderColor = '#f5c6cb';
    authStatusEl.style.color = '#721c24';
    authStatusEl.textContent = 'Not signed in — company save disabled';
    btnSave.disabled = true;
    btnSaveNew.disabled = true;
  } else {
    const user = authManager.getCurrentUser();
    authStatusEl.style.backgroundColor = '#d4edda';
    authStatusEl.style.borderColor = '#c3e6cb';
    authStatusEl.style.color = '#155724';
    authStatusEl.textContent = 'Signed in as: ' + (user.email || user.id);
  }

  // Load currencies for the dropdown
  await loadCurrencies();

  btnSave.addEventListener('click', () => saveCompany(false));
  btnSaveNew.addEventListener('click', () => saveCompany(true));

  statusEl.textContent = 'Ready';
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
      showError('Create or seed Currency first before creating Company.');
      select.innerHTML = '<option value="">No currencies found</option>';
      setButtonsDisabled(true);
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
    showError('Failed to load currencies: ' + err.message);
  }
}

async function saveCompany(isSaveAndNew) {
  const form = document.getElementById('company-create-form');
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

    const createdBy = user.id;

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
      created_by: createdBy
    };

    // 3. Insert into public.companies
    const { data: newCompany, error } = await supabase
      .from('companies')
      .insert([payload])
      .select('id')
      .single();

    if (error) throw error;

    // 4. Insert into public.user_company_access
    const ucaPayload = {
      user_id: createdBy,
      company_id: newCompany.id,
      is_company_admin: true,
      granted_by: createdBy
    };
    
    const { error: ucaError } = await supabase
      .from('user_company_access')
      .insert([ucaPayload]);

    if (ucaError) {
      throw new Error("Company was created but access granting failed: " + ucaError.message);
    }

    // 5. Refresh Company Context and UI Selector
    if (typeof authManager.refreshCompanyContext === 'function') {
      await authManager.refreshCompanyContext();
      
      // Auto-set as active company if none was selected
      if (!authManager.getActiveCompanyId()) {
        authManager.setActiveCompany(newCompany.id);
      }
      
      // Update topbar directly instead of triggering a hashchange (which causes re-render)
      if (typeof window.updateAuthUI === 'function') {
        window.updateAuthUI();
      }
    }

    statusEl.textContent = 'Saved successfully.';

    if (isSaveAndNew) {
      form.reset();
      setButtonsDisabled(false);
      statusEl.textContent = 'Ready for next company.';
    } else {
      // Navigate back to list
      window.location.hash = '#/setup/company-setup';
    }

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
  document.getElementById('btn-save-new').disabled = disabled;
}
