// -----------------------------------------------------------------------------
// PXL ERP - Company Create JS
// -----------------------------------------------------------------------------

import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const SUPABASE_URL = 'http://127.0.0.1:54321';
const SUPABASE_ANON_KEY = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

document.addEventListener('DOMContentLoaded', () => {
  initForm();
});

async function initForm() {
  const btnSave = document.getElementById('btn-save');
  const btnSaveNew = document.getElementById('btn-save-new');
  const statusEl = document.getElementById('page-status');

  statusEl.textContent = 'Loading form dependencies...';

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
    // 1. Get a valid user profile ID for created_by
    const { data: profiles, error: profileErr } = await supabase
      .from('profiles')
      .select('id')
      .limit(1);

    if (profileErr) throw profileErr;
    if (!profiles || profiles.length === 0) {
      throw new Error("No user profiles found in the database. Cannot set 'created_by'. Please seed a user profile first.");
    }

    const createdBy = profiles[0].id;

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
    const { data, error } = await supabase
      .from('companies')
      .insert([payload]);

    if (error) throw error;

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
