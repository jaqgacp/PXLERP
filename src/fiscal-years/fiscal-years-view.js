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
    const btnEdit = document.getElementById('btn-edit');
    if (btnEdit) btnEdit.disabled = true;
    showError('No active company selected.');
    return;
  }

  const urlParams = new URLSearchParams(window.location.hash.split('?')[1]);
  const fyId = urlParams.get('id');

  if (!fyId) {
    showError('No Fiscal Year ID provided.');
    return;
  }

  const btnEdit = document.getElementById('btn-edit');
  btnEdit.addEventListener('click', () => {
    window.location.hash = '#/setup/fiscal-years/edit?id=' + fyId;
  });

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
    document.getElementById('status').value = data.status || '';

  } catch (err) {
    console.error('Load error:', err);
    showError('Failed to load fiscal year details: ' + err.message);
  }
}

function showError(msg) {
  const errorEl = document.getElementById('form-error');
  errorEl.textContent = msg;
  errorEl.style.display = 'block';
}
