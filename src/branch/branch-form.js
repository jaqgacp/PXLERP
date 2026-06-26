// -----------------------------------------------------------------------------
// PXL ERP - Branch Form
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';
import { ErpFormHelper, Toast } from '../shared/erp-form-helper.js';

const supabase = authManager.supabase;
let currentRecordId = null;
let companyBaseTin = '';

export async function init() {
  const urlParams = new URLSearchParams(window.location.hash.split('?')[1]);
  currentRecordId = urlParams.get('id');

  const helper = new ErpFormHelper({
    moduleName: 'Branch',
    listRoute: '#/setup/branch-setup',
    onInit: async (mode) => {
      const tinSuffixInput = document.getElementById('tin_suffix');
      const fullTinInput = document.getElementById('full_tin');

      tinSuffixInput.addEventListener('input', () => {
        if (companyBaseTin) {
          fullTinInput.value = tinSuffixInput.value ? `${companyBaseTin}-${tinSuffixInput.value}` : companyBaseTin;
        }
      });

      if (mode === 'view' || mode === 'edit') {
        document.getElementById('section-system-info').classList.remove('erp-hidden');
      }

      const activeCompanyId = authManager.getActiveCompanyId();
      if (!activeCompanyId) {
        Toast.error("No active company selected. Please select a company from the top navigation.");
        if (document.getElementById('btn-save')) document.getElementById('btn-save').disabled = true;
        if (document.getElementById('btn-save-new')) document.getElementById('btn-save-new').disabled = true;
        return;
      }

      const { data: comp } = await supabase
        .from('companies')
        .select('base_tin')
        .eq('id', activeCompanyId)
        .single();
        
      if (comp && comp.base_tin) {
        companyBaseTin = comp.base_tin;
      } else {
        fullTinInput.placeholder = "Company Base TIN is missing";
      }
    },
    onLoad: async () => {
      if (!currentRecordId) throw new Error("No record ID provided");
      
      const activeCompanyId = authManager.getActiveCompanyId();
      if (!activeCompanyId) {
        const formFields = document.getElementById('erp-form-fields');
        if (formFields) {
          formFields.innerHTML = `
            <div style="padding: 60px 20px; text-align: center;">
              <div style="font-size: 34px; margin-bottom: 12px; opacity: 0.8;">🏢</div>
              <div style="font-size: 15px; font-weight: 700; color: var(--ns-dark); margin-bottom: 6px;">Action Blocked</div>
              <div style="font-size: 13px; color: var(--ns-dark);">Please select a company to view or edit this branch.</div>
            </div>
          `;
        }
        throw new Error("No active company selected. Action blocked.");
      }

      const { data, error } = await supabase
        .from('branches')
        .select('*')
        .eq('id', currentRecordId)
        .eq('company_id', activeCompanyId)
        .single();
        
      if (error || !data) {
        throw new Error("Branch not found or you do not have access within the active company.");
      }

      document.getElementById('code').value = data.code || '';
      document.getElementById('name').value = data.name || '';
      document.getElementById('short_name').value = data.short_name || '';
      document.getElementById('is_head_office').value = data.is_head_office ? 'true' : 'false';
      document.getElementById('bir_registered').value = data.bir_registered ? 'true' : 'false';
      document.getElementById('is_active').checked = data.is_active;
      
      document.getElementById('tin_suffix').value = data.tin_suffix || '';
      document.getElementById('rdo_code').value = data.rdo_code || '';
      document.getElementById('line_of_business').value = data.line_of_business || '';
      document.getElementById('ptu_cas_no').value = data.ptu_cas_no || '';
      document.getElementById('ptu_cas_date_issued').value = data.ptu_cas_date_issued || '';
      
      document.getElementById('address').value = data.address || '';
      document.getElementById('zip_code').value = data.zip_code || '';
      document.getElementById('contact_person').value = data.contact_person || '';
      document.getElementById('phone').value = data.phone || '';
      document.getElementById('email').value = data.email || '';

      if (data.created_at) document.getElementById('created_at').value = new Date(data.created_at).toLocaleString();
      if (data.updated_at) document.getElementById('updated_at').value = new Date(data.updated_at).toLocaleString();
      if (data.created_by) document.getElementById('created_by').value = data.created_by;
      if (data.updated_by) document.getElementById('updated_by').value = data.updated_by;

      const fullTinInput = document.getElementById('full_tin');
      if (companyBaseTin) {
         fullTinInput.value = data.tin_suffix ? `${companyBaseTin}-${data.tin_suffix}` : companyBaseTin;
      }
    },
    buildPayload: () => {
      const payload = {
        code: document.getElementById('code').value.trim(),
        name: document.getElementById('name').value.trim(),
        short_name: document.getElementById('short_name').value.trim() || null,
        is_head_office: document.getElementById('is_head_office').value === 'true',
        bir_registered: document.getElementById('bir_registered').value === 'true',
        is_active: document.getElementById('is_active').checked,
        
        tin_suffix: document.getElementById('tin_suffix').value.trim() || null,
        rdo_code: document.getElementById('rdo_code').value.trim() || null,
        line_of_business: document.getElementById('line_of_business').value.trim() || null,
        ptu_cas_no: document.getElementById('ptu_cas_no').value.trim() || null,
        ptu_cas_date_issued: document.getElementById('ptu_cas_date_issued').value || null,
        
        address: document.getElementById('address').value.trim() || null,
        zip_code: document.getElementById('zip_code').value.trim() || null,
        contact_person: document.getElementById('contact_person').value.trim() || null,
        phone: document.getElementById('phone').value.trim() || null,
        email: document.getElementById('email').value.trim() || null,
      };
      return payload;
    },
    onSave: async (payload, isNew) => {
      const activeCompanyId = authManager.getActiveCompanyId();
      if (!activeCompanyId) throw new Error("Active company is missing.");
      
      const user = authManager.getCurrentUser();
      if (!user) throw new Error("No authenticated user.");

      if (isNew) {
        payload.company_id = activeCompanyId;
        payload.created_by = user.id;
        
        const { error } = await supabase
          .from('branches')
          .insert([payload]);
        if (error) throw error;
      } else {
        payload.updated_by = user.id;
        payload.updated_at = new Date().toISOString();
        
        const { error } = await supabase
          .from('branches')
          .update(payload)
          .eq('id', currentRecordId)
          .eq('company_id', activeCompanyId);
        if (error) throw error;
      }
    }
  });

  await helper.init();
}
