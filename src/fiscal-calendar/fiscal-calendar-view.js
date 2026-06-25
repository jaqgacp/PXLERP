import { authManager } from '../auth/auth-manager.js';

const supabase = authManager.supabase;

document.addEventListener('DOMContentLoaded', () => {
  initForm();
});

async function initForm() {
  try {
    authManager.requireActiveCompany();
  } catch (err) {
    const btnEdit = document.getElementById('btn-edit');
    if (btnEdit) btnEdit.disabled = true;
    showError('No active company selected.');
    return;
  }

  const urlParams = new URLSearchParams(window.location.hash.split('?')[1]);
  const fpId = urlParams.get('id');

  if (!fpId) {
    showError('No Fiscal Period ID provided.');
    return;
  }

  const btnEdit = document.getElementById('btn-edit');
  btnEdit.addEventListener('click', () => {
    window.location.hash = '#/setup/fiscal-calendar/edit?id=' + fpId;
  });

  await loadFiscalPeriod(fpId);
}

async function loadFiscalPeriod(id) {
  const companyId = authManager.getActiveCompanyId();
  try {
    const { data, error } = await supabase
      .from('fiscal_periods')
      .select('*, fiscal_years(year_code)')
      .eq('id', id)
      .eq('company_id', companyId)
      .single();

    if (error) throw error;
    if (!data) throw new Error('Fiscal Period not found or access denied.');

    document.getElementById('fiscal_year_code').value = data.fiscal_years?.year_code || '';
    document.getElementById('period_number').value = data.period_number || '';
    document.getElementById('period_name').value = data.period_name || '';
    document.getElementById('quarter').value = data.quarter || '';
    document.getElementById('date_from').value = data.date_from || '';
    document.getElementById('date_to').value = data.date_to || '';
    document.getElementById('status').value = data.status || '';

  } catch (err) {
    console.error('Load error:', err);
    showError('Failed to load fiscal period details: ' + err.message);
  }
}

function showError(msg) {
  const errorEl = document.getElementById('form-error');
  errorEl.textContent = msg;
  errorEl.style.display = 'block';
}
