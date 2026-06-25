// -----------------------------------------------------------------------------
// PXL ERP - Fiscal Years Form JS
// -----------------------------------------------------------------------------
import { authManager } from '../auth/auth-manager.js';
import { ErpFormHelper } from '../shared/erp-form-helper.js';

const supabase = authManager.supabase;

const formHelper = new ErpFormHelper({
    moduleName: 'Fiscal Year',
    listRoute: '#/setup/fiscal-years',
    
    onInit: async (mode) => {
      // Any extra initialization
      if (mode === 'create') {
        document.getElementById('status').value = 'open';
      }
    },
    
    onLoad: async () => {
      const urlParams = new URLSearchParams(window.location.hash.split('?')[1]);
      const id = urlParams.get('id');
      if (!id) throw new Error('No Fiscal Year ID provided in URL.');
      
      const companyId = authManager.getActiveCompanyId();
      if (!companyId) throw new Error('No active company selected.');

      const { data, error } = await supabase
        .from('fiscal_years')
        .select('*')
        .eq('id', id)
        .eq('company_id', companyId)
        .single();

      if (error) throw error;
      if (!data) throw new Error('Fiscal Year not found or access denied.');

      // Populate fields
      document.getElementById('year_code').value = data.year_code || '';
      document.getElementById('date_from').value = data.date_from || '';
      document.getElementById('date_to').value = data.date_to || '';
      document.getElementById('is_current').checked = data.is_current;
      document.getElementById('status').value = data.status || 'open';

      // Attach original ID for update payload
      document.getElementById('erp-form').dataset.id = id;
    },
    
    buildPayload: () => {
      const payload = {
        year_code: document.getElementById('year_code').value.trim(),
        date_from: document.getElementById('date_from').value,
        date_to: document.getElementById('date_to').value,
        is_current: document.getElementById('is_current').checked,
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

        const { error } = await supabase.from('fiscal_years').insert([payload]);
        if (error) throw error;
      } else {
        const id = document.getElementById('erp-form').dataset.id;
        if (!id) throw new Error("Missing ID for update.");

        payload.updated_by = user.id;
        payload.updated_at = new Date().toISOString();

        const { error } = await supabase
          .from('fiscal_years')
          .update(payload)
          .eq('id', id)
          .eq('company_id', companyId);

        if (error) throw error;
      }
    }
  });

  formHelper.init();
