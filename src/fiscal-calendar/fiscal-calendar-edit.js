import { authManager } from '../auth/auth-manager.js';

const supabase = authManager.supabase;

document.addEventListener('DOMContentLoaded', () => {
  initForm();
});

async function initForm() {
  try {
    authManager.requireActiveCompany();
  } catch (err) {
    setButtonsDisabled(true);
    showError('No active company selected.');
    return;
  }

  const urlParams = new URLSearchParams(window.location.hash.split('?')[1]);
  const fpId = urlParams.get('id');

  if (!fpId) {
    showError('No Fiscal Period ID provided.');
    return;
  }

  const btnSave = document.getElementById('btn-save');
  btnSave.addEventListener('click', () => updateFiscalPeriod(fpId));

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

  await loadFiscalPeriod(fpId);
}

async function loadFiscalPeriod(id) {
  const companyId = authManager.getActiveCompanyId();
  try {
    const { data, error } = await supabase
      .from('fiscal_periods')
      .select('*')
      .eq('id', id)
      .eq('company_id', companyId)
      .single();

    if (error) throw error;
    if (!data) throw new Error('Fiscal Period not found or access denied.');

    await loadFiscalYears(companyId, data.fiscal_year_id);

    document.getElementById('period_number').value = data.period_number || '';
    document.getElementById('period_name').value = data.period_name || '';
    document.getElementById('quarter').value = data.quarter || '';
    document.getElementById('date_from').value = data.date_from || '';
    document.getElementById('date_to').value = data.date_to || '';
    document.getElementById('status').value = data.status || 'open';

  } catch (err) {
    console.error('Load error:', err);
    showError('Failed to load fiscal period details: ' + err.message);
    setButtonsDisabled(true);
  }
}

async function loadFiscalYears(companyId, selectedId) {
  const select = document.getElementById('fiscal_year_id');
  try {
    const { data, error } = await supabase
      .from('fiscal_years')
      .select('id, year_code')
      .eq('company_id', companyId)
      .order('year_code', { ascending: false });

    if (error) throw error;

    if (!data || data.length === 0) {
      showError('No fiscal years found.');
      select.innerHTML = '<option value="">No Fiscal Years found</option>';
      return;
    }

    select.innerHTML = '<option value="">Select Fiscal Year...</option>';
    data.forEach(fy => {
      const opt = document.createElement('option');
      opt.value = fy.id;
      opt.textContent = fy.year_code;
      if (fy.id === selectedId) opt.selected = true;
      select.appendChild(opt);
    });
  } catch (err) {
    console.error('Failed to load fiscal years', err);
    select.innerHTML = '<option value="">Error loading</option>';
  }
}

async function updateFiscalPeriod(id) {
  const form = document.getElementById('fp-edit-form');
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
      fiscal_year_id: document.getElementById('fiscal_year_id').value,
      period_number: parseInt(document.getElementById('period_number').value, 10),
      period_name: document.getElementById('period_name').value.trim(),
      date_from: document.getElementById('date_from').value,
      date_to: document.getElementById('date_to').value,
      quarter: parseInt(document.getElementById('quarter').value, 10),
      status: document.getElementById('status').value,
      updated_by: user.id,
      updated_at: new Date().toISOString()
    };

    if (new Date(payload.date_from) >= new Date(payload.date_to)) {
      throw new Error("Date To must be greater than Date From.");
    }

    const { error } = await supabase
      .from('fiscal_periods')
      .update(payload)
      .eq('id', id)
      .eq('company_id', companyId);

    if (error) throw error;

    window.location.hash = '#/setup/fiscal-calendar';

  } catch (err) {
    console.error('Save error:', err);
    showError(err.message || 'Error updating Fiscal Period');
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
