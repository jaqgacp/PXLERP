import { authManager } from '../auth/auth-manager.js';

const supabase = authManager.supabase;

document.addEventListener('DOMContentLoaded', () => {
  initForm();
});

async function initForm() {
  const btnSave = document.getElementById('btn-save');
  const btnSaveNew = document.getElementById('btn-save-new');
  const authStatusEl = document.getElementById('auth-status');

  let companyId;
  try {
    companyId = authManager.requireActiveCompany();
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

  await loadFiscalYears(companyId);

  // Auto-calculate quarter based on period number
  const periodNumberInput = document.getElementById('period_number');
  const quarterInput = document.getElementById('quarter');
  periodNumberInput.addEventListener('input', () => {
    const p = parseInt(periodNumberInput.value, 10);
    if (p >= 1 && p <= 12) {
      quarterInput.value = Math.ceil(p / 3);
    } else {
      quarterInput.value = '';
    }
  });

  btnSave.addEventListener('click', () => saveFiscalPeriod(false));
  btnSaveNew.addEventListener('click', () => saveFiscalPeriod(true));
}

async function loadFiscalYears(companyId) {
  const select = document.getElementById('fiscal_year_id');
  try {
    const { data, error } = await supabase
      .from('fiscal_years')
      .select('id, year_code')
      .eq('company_id', companyId)
      .order('year_code', { ascending: false });

    if (error) throw error;

    if (!data || data.length === 0) {
      showError('No fiscal years found. Please create one first.');
      select.innerHTML = '<option value="">No Fiscal Years found</option>';
      setButtonsDisabled(true);
      return;
    }

    select.innerHTML = '<option value="">Select Fiscal Year...</option>';
    data.forEach(fy => {
      const opt = document.createElement('option');
      opt.value = fy.id;
      opt.textContent = fy.year_code;
      select.appendChild(opt);
    });
  } catch (err) {
    console.error('Failed to load fiscal years', err);
    select.innerHTML = '<option value="">Error loading</option>';
    showError('Failed to load fiscal years: ' + err.message);
  }
}

async function saveFiscalPeriod(isSaveAndNew) {
  const form = document.getElementById('fp-create-form');
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
      company_id: companyId,
      fiscal_year_id: document.getElementById('fiscal_year_id').value,
      period_number: parseInt(document.getElementById('period_number').value, 10),
      period_name: document.getElementById('period_name').value.trim(),
      date_from: document.getElementById('date_from').value,
      date_to: document.getElementById('date_to').value,
      quarter: parseInt(document.getElementById('quarter').value, 10),
      status: 'open',
      created_by: user.id
    };

    if (new Date(payload.date_from) >= new Date(payload.date_to)) {
      throw new Error("Date To must be greater than Date From.");
    }

    const { error } = await supabase
      .from('fiscal_periods')
      .insert([payload]);

    if (error) throw error;

    if (isSaveAndNew) {
      form.reset();
      setButtonsDisabled(false);
    } else {
      window.location.hash = '#/setup/fiscal-calendar';
    }

  } catch (err) {
    console.error('Save error:', err);
    showError(err.message || 'Error saving Fiscal Period');
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
