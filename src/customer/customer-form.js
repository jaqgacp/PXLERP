// -----------------------------------------------------------------------------
// PXL ERP - Customer Form (View Mode Only)
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';
import { ErpFormHelper } from '../shared/erp-form-helper.js';

const supabase = authManager.supabase;
let currentRecordId = null;

export async function init() {
  const urlParams = new URLSearchParams(window.location.hash.split('?')[1]);
  currentRecordId = urlParams.get('id');

  const helper = new ErpFormHelper({
    moduleName: 'Customer',
    tableName: 'customers',
    listRoute: '#/master-data/customers',
    
    onInit: async (mode) => {
      // Phase 5D constraint: Block anything other than View mode
      if (mode !== 'view') {
        const formFields = document.getElementById('erp-form-fields');
        if (formFields) {
          formFields.innerHTML = `
            <div class="erp-error-state">
              <h3>Not Available</h3>
              <p>Customer Create and Edit functionalities are not yet available (Phase 5D restriction).</p>
            </div>
          `;
        }
        if (document.getElementById('btn-save')) document.getElementById('btn-save').style.display = 'none';
        if (document.getElementById('btn-save-new')) document.getElementById('btn-save-new').style.display = 'none';
        return;
      }
      
      if (!currentRecordId) {
        const formFields = document.getElementById('erp-form-fields');
        if (formFields) {
          formFields.innerHTML = `
            <div class="erp-error-state">
              <h3>Error</h3>
              <p>Customer ID is required.</p>
            </div>
          `;
        }
        return;
      }

      // Add Print button dynamically if in view mode
      const toolbar = document.querySelector('.erp-form-toolbar');
      if (toolbar && !document.getElementById('btn-print')) {
        const btnPrint = document.createElement('button');
        btnPrint.id = 'btn-print';
        btnPrint.className = 'btn';
        btnPrint.textContent = 'Print';
        btnPrint.onclick = () => window.print();
        toolbar.appendChild(btnPrint);
      }
    },

    onLoad: async () => {
      if (!currentRecordId) throw new Error("Customer ID is required.");

      // Custom join to get lookup display values
      const { data, error } = await supabase
        .from('customers')
        .select(`
          *,
          currencies:default_currency_id ( code, name ),
          branches:default_branch_id ( code, name ),
          created_profile:created_by ( display_name, first_name, last_name ),
          updated_profile:updated_by ( display_name, first_name, last_name )
        `)
        .eq('id', currentRecordId)
        .single();

      if (error || !data) {
        const formFields = document.getElementById('erp-form-fields');
        if (formFields) {
          formFields.innerHTML = `
            <div class="erp-error-state">
              <h3>Access Denied / Not Found</h3>
              <p>Customer record not found or access denied.</p>
            </div>
          `;
        }
        throw new Error("Customer record not found or access denied.");
      }

      // Populate custom display fields
      const displayData = { ...data };
      
      // Lookups
      if (data.currencies) {
        displayData.default_currency_display = `${data.currencies.code} - ${data.currencies.name}`;
      } else if (data.default_currency_id) {
        displayData.default_currency_display = data.default_currency_id; // fallback
      }

      if (data.branches) {
        displayData.default_branch_display = `${data.branches.code} - ${data.branches.name}`;
      } else if (data.default_branch_id) {
        displayData.default_branch_display = data.default_branch_id; // fallback
      }
      
      // Audit
      if (data.created_profile) {
        displayData.created_by = data.created_profile.display_name || `${data.created_profile.first_name} ${data.created_profile.last_name}`;
      } else if (data.created_by) {
        displayData.created_by = data.created_by; // fallback UUID
      }

      if (data.updated_profile) {
        displayData.updated_by = data.updated_profile.display_name || `${data.updated_profile.first_name} ${data.updated_profile.last_name}`;
      } else if (data.updated_by) {
        displayData.updated_by = data.updated_by; // fallback UUID
      }
      
      if (data.created_at) displayData.created_at = new Date(data.created_at).toLocaleString();
      if (data.updated_at) displayData.updated_at = new Date(data.updated_at).toLocaleString();

      return displayData;
    },

    onSave: async (formData) => {
      // Blocked by Phase 5D constraints
      throw new Error("Saving is currently disabled for Phase 5D.");
    }
  });

  await helper.init();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
