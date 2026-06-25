import { authManager } from '../auth/auth-manager.js';

const supabase = authManager.supabase;

document.addEventListener('DOMContentLoaded', () => {
  initForm();
});

async function initForm() {
  const btnSave = document.getElementById('btn-save');
  const btnSaveNew = document.getElementById('btn-save-new');
  const authStatusEl = document.getElementById('auth-status');

  // Verify Active Company Context using our new helper!
  try {
    const companyId = authManager.requireActiveCompany();
    const company = authManager.getActiveCompany();
    authStatusEl.style.backgroundColor = '#d4edda';
    authStatusEl.style.borderColor = '#c3e6cb';
    authStatusEl.style.color = '#155724';
    authStatusEl.textContent = `Active Company: ${company.name || company.code} (ID: ${companyId})`;
  } catch (err) {
    authStatusEl.style.backgroundColor = '#f8d7da';
    authStatusEl.style.borderColor = '#f5c6cb';
    authStatusEl.style.color = '#721c24';
    authStatusEl.textContent = 'Action Blocked: No Active Company Selected.';
    btnSave.disabled = true;
    btnSaveNew.disabled = true;
    return;
  }

  btnSave.addEventListener('click', () => saveFiscalYear(false));
  btnSaveNew.addEventListener('click', () => saveFiscalYear(true));
}

async function saveFiscalYear(isSaveAndNew) {
  const form = document.getElementById('fy-create-form');
  if (!form.reportValidity()) {
    return;
  }

  const errorEl = document.getElementById('form-error');
  errorEl.style.display = 'none';
  setButtonsDisabled(true);

  try {
    const user = authManager.getCurrentUser();
    if (!user) throw new Error("Not signed in.");

    // Retrieve active company id for insert scoping
    const companyId = authManager.requireActiveCompany();

    const payload = {
      company_id: companyId,
      year_code: document.getElementById('year_code').value.trim(),
      date_from: document.getElementById('date_from').value,
      date_to: document.getElementById('date_to').value,
      is_current: document.getElementById('is_current').checked,
      status: 'open',
      created_by: user.id
    };

    if (new Date(payload.date_from) >= new Date(payload.date_to)) {
      throw new Error("Date To must be greater than Date From.");
    }

    const { data, error } = await supabase
      .from('fiscal_years')
      .insert([payload]);

    if (error) throw error;

    if (isSaveAndNew) {
      form.reset();
      setButtonsDisabled(false);
    } else {
      window.location.hash = '#/setup/fiscal-years';
    }

  } catch (err) {
    console.error('Save error:', err);
    showError(err.message || 'Error saving Fiscal Year');
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
