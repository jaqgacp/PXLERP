// -----------------------------------------------------------------------------
// PXL ERP - Company Create JS
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';

const supabase = authManager.supabase;

initForm();

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

    // Get TIN components
    const baseTin = document.getElementById('base_tin').value.trim();
    const branchCode = document.getElementById('branch_code').value.trim() || '00000';
    const legacyTin = baseTin + '-' + branchCode;

    // 2. Build payload
    const payload = {
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
