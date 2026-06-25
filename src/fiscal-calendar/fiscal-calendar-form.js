// -----------------------------------------------------------------------------
// PXL ERP - Fiscal Calendar Form JS
// -----------------------------------------------------------------------------
import { authManager } from '../auth/auth-manager.js';
import { ErpFormHelper, Toast } from '../shared/erp-form-helper.js';

const supabase = authManager.supabase;

const formHelper = new ErpFormHelper({
    moduleName: 'Fiscal Period',
    listRoute: '#/setup/fiscal-calendar',
    
    onInit: async (mode) => {
      // Setup Quarter auto-calculation
      const periodNumEl = document.getElementById('period_number');
      const quarterEl = document.getElementById('quarter');
      periodNumEl.addEventListener('input', () => {
        const val = parseInt(periodNumEl.value, 10);
        if (!isNaN(val) && val >= 1 && val <= 12) {
          quarterEl.value = Math.ceil(val / 3);
        } else {
          quarterEl.value = '';
        }
      });

      // Load Fiscal Years for dropdown scoped by active company
      const companyId = authManager.requireActiveCompany();
      const fySelect = document.getElementById('fiscal_year_id');
      try {
        const { data, error } = await supabase
          .from('fiscal_years')
          .select('id, year_code')
          .eq('company_id', companyId)
          .order('year_code', { ascending: false });

        if (error) throw error;

        fySelect.innerHTML = '<option value="">Select Fiscal Year...</option>';
        data.forEach(fy => {
          const opt = document.createElement('option');
          opt.value = fy.id;
          opt.textContent = fy.year_code;
          fySelect.appendChild(opt);
        });
      } catch (err) {
        console.error('Failed to load fiscal years:', err);
        fySelect.innerHTML = '<option value="">Error loading</option>';
        Toast.error('Failed to load fiscal years.');
      }

      if (mode === 'create') {
        document.getElementById('status').value = 'open';
      }
    },
    
    onLoad: async () => {
      const urlParams = new URLSearchParams(window.location.hash.split('?')[1]);
      const id = urlParams.get('id');
      if (!id) throw new Error('No Fiscal Period ID provided in URL.');
      
      const companyId = authManager.getActiveCompanyId();
      if (!companyId) throw new Error('No active company selected.');

      const { data, error } = await supabase
        .from('fiscal_periods')
        .select('*')
        .eq('id', id)
        .eq('company_id', companyId)
        .single();

      if (error) throw error;
      if (!data) throw new Error('Fiscal Period not found or access denied.');

      document.getElementById('fiscal_year_id').value = data.fiscal_year_id || '';
      document.getElementById('period_number').value = data.period_number || '';
      document.getElementById('period_name').value = data.period_name || '';
      document.getElementById('quarter').value = data.quarter || '';
      document.getElementById('date_from').value = data.date_from || '';
      document.getElementById('date_to').value = data.date_to || '';
      document.getElementById('status').value = data.status || 'open';

      document.getElementById('erp-form').dataset.id = id;
    },
    
    buildPayload: () => {
      const payload = {
        fiscal_year_id: document.getElementById('fiscal_year_id').value,
        period_number: parseInt(document.getElementById('period_number').value, 10),
        period_name: document.getElementById('period_name').value.trim(),
        quarter: parseInt(document.getElementById('quarter').value, 10),
        date_from: document.getElementById('date_from').value,
        date_to: document.getElementById('date_to').value,
        status: document.getElementById('status').value
      };

      if (new Date(payload.date_from) >= new Date(payload.date_to)) {
        throw new Error("Date To must be greater than Date From.");
      }

      return payload;
    },
    
    onSave: async (payload, isNew) => {
      const user = authManager.getCurrentUser();
      if (!user) throw new Error("Not signed in.");
      const companyId = authManager.requireActiveCompany();

      if (isNew) {
        payload.company_id = companyId;
        payload.created_by = user.id;

        const { error } = await supabase.from('fiscal_periods').insert([payload]);
        if (error) throw error;
      } else {
        const id = document.getElementById('erp-form').dataset.id;
        if (!id) throw new Error("Missing ID for update.");

        payload.updated_by = user.id;
        payload.updated_at = new Date().toISOString();

        const { error } = await supabase
          .from('fiscal_periods')
          .update(payload)
          .eq('id', id)
          .eq('company_id', companyId);

        if (error) throw error;
      }
    }
  });

  formHelper.init();
