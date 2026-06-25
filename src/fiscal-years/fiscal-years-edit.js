import { authManager } from '../auth/auth-manager.js';

const supabase = authManager.supabase;

document.addEventListener('DOMContentLoaded', () => {
  initForm();
});

async function initForm() {
  // Ensure Active Company Context
  try {
    authManager.requireActiveCompany();
  } catch (err) {
    setButtonsDisabled(true);
    showError('No active company selected.');
    return;
  }

  const urlParams = new URLSearchParams(window.location.hash.split('?')[1]);
  const fyId = urlParams.get('id');

  if (!fyId) {
    showError('No Fiscal Year ID provided.');
    return;
  }

  const btnSave = document.getElementById('btn-save');
  btnSave.addEventListener('click', () => updateFiscalYear(fyId));

  await loadFiscalYear(fyId);
}

async function loadFiscalYear(id) {
  const companyId = authManager.getActiveCompanyId();
  try {
    const { data, error } = await supabase
      .from('fiscal_years')
      .select('*')
      .eq('id', id)
      .eq('company_id', companyId)
      .single();

    if (error) throw error;
    if (!data) throw new Error('Fiscal Year not found or access denied.');

    document.getElementById('year_code').value = data.year_code || '';
    document.getElementById('date_from').value = data.date_from || '';
    document.getElementById('date_to').value = data.date_to || '';
    document.getElementById('is_current').checked = data.is_current;
    document.getElementById('status').value = data.status || 'open';

  } catch (err) {
    console.error('Load error:', err);
    showError('Failed to load fiscal year details: ' + err.message);
    setButtonsDisabled(true);
  }
}

async function updateFiscalYear(id) {
  const form = document.getElementById('fy-edit-form');
  if (!form.reportValidity()) {
    return;
  }

  const errorEl = document.getElementById('form-error');
  errorEl.style.display = 'none';
  setButtonsDisabled(true);

  try {
    const user = authManager.getCurrentUser();
    if (!user) throw new Error("Not signed in.");

    const companyId = authManager.requireActiveCompany();

    const payload = {
      year_code: document.getElementById('year_code').value.trim(),
      date_from: document.getElementById('date_from').value,
      date_to: document.getElementById('date_to').value,
      is_current: document.getElementById('is_current').checked,
      status: document.getElementById('status').value,
      updated_by: user.id,
      updated_at: new Date().toISOString()
    };

    if (new Date(payload.date_from) >= new Date(payload.date_to)) {
      throw new Error("Date To must be greater than Date From.");
    }

    const { error } = await supabase
      .from('fiscal_years')
      .update(payload)
      .eq('id', id)
      .eq('company_id', companyId);

    if (error) throw error;

    window.location.hash = '#/setup/fiscal-years';

  } catch (err) {
    console.error('Save error:', err);
    showError(err.message || 'Error updating Fiscal Year');
    setButtonsDisabled(false);
  }
}

function showError(msg) {
  const errorEl = document.getElementById('form-error');
  errorEl.textContent = msg;
  errorEl.style.display = 'block';
}

function setButtonsDisabled(disabled) {
  const btnSave = document.getElementById('btn-save');
  if (btnSave) btnSave.disabled = disabled;
}
