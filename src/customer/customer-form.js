// -----------------------------------------------------------------------------
// PXL ERP - Customer Form (View Mode Only)
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';
import { ErpFormHelper, Toast } from '../shared/erp-form-helper.js';
import { ErpLookupHelper } from '../shared/erp-lookup-helper.js';

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
      // Lookups
      new ErpLookupHelper({
        inputId: 'default_currency_display',
        hiddenInputId: 'default_currency_id',
        tableName: 'currencies',
        valueField: 'id',
        displayField: 'code',
        searchColumns: ['code', 'name'],
        columns: [
          { key: 'code', label: 'Code' },
          { key: 'name', label: 'Name' }
        ],
        pageSize: 10,
        requireActiveCompany: false,
        staticFilters: [
          { col: 'is_active', op: 'eq', val: true }
        ]
      });

      new ErpLookupHelper({
        inputId: 'default_branch_display',
        hiddenInputId: 'default_branch_id',
        tableName: 'branches',
        valueField: 'id',
        displayField: 'code',
        searchColumns: ['code', 'name'],
        columns: [
          { key: 'code', label: 'Code' },
          { key: 'name', label: 'Name' }
        ],
        pageSize: 10,
        requireActiveCompany: true,
        staticFilters: [
          { col: 'is_active', op: 'eq', val: true }
        ]
      });

      // Live TIN formatting
      const tinInput = document.getElementById('tin');
      const branchCodeInput = document.getElementById('tin_branch_code');
      const fullTinInput = document.getElementById('full_tin');

      const updateFullTin = () => {
        if (!tinInput || !branchCodeInput || !fullTinInput) return;
        const base = tinInput.value.trim();
        const branch = branchCodeInput.value.trim();
        if (base) {
          fullTinInput.value = base + '-' + (branch || '00000');
        } else {
          fullTinInput.value = '';
        }
      };

      if (tinInput) tinInput.addEventListener('input', updateFullTin);
      if (branchCodeInput) branchCodeInput.addEventListener('input', updateFullTin);

      if (mode === 'view') {
        // Disable lookup clears
        ['default_currency_display', 'default_branch_display'].forEach(id => {
          const el = document.getElementById(id);
          if (el) {
            const clone = el.cloneNode(true);
            el.parentNode.replaceChild(clone, el);
            const clearBtn = clone.parentNode.querySelector('.erp-lookup-clear-btn');
            if (clearBtn) clearBtn.style.display = 'none';
          }
        });

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
      } else if (mode === 'new') {
        // Hide System Info
        const fieldsets = document.querySelectorAll('.erp-section');
        fieldsets.forEach(fs => {
          const legend = fs.querySelector('legend');
          if (legend && legend.textContent.includes('System Information')) {
            fs.style.display = 'none';
          }
        });
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

    buildPayload: () => {
      const code = document.getElementById('code').value.trim();
      const registeredName = document.getElementById('registered_name').value.trim();
      if (!code || !registeredName) {
        throw new Error('Customer Code and Registered Name are required.');
      }
      
      const payload = {
        code: code,
        registered_name: registeredName,
        trade_name: document.getElementById('trade_name').value.trim() || null,
        entity_type: document.getElementById('entity_type').value,
        customer_type: document.getElementById('customer_type').value.trim() || null,
        is_active: document.getElementById('is_active').checked,

        tin: document.getElementById('tin').value.trim() || null,
        tin_branch_code: document.getElementById('tin_branch_code').value.trim() || '00000',
        full_tin: document.getElementById('full_tin').value.trim() || null,
        tax_type: document.getElementById('tax_type').value,
        is_government: document.getElementById('is_government').checked,
        is_peza: document.getElementById('is_peza').checked,
        is_boi: document.getElementById('is_boi').checked,
        is_foreign: document.getElementById('is_foreign').checked,
        bir_registered_address: document.getElementById('bir_registered_address').value.trim() || null,

        default_currency_id: document.getElementById('default_currency_id').value || null,
        default_branch_id: document.getElementById('default_branch_id').value || null,
        credit_limit: parseFloat(document.getElementById('credit_limit').value) || 0,
        payment_terms_text: document.getElementById('payment_terms_text').value.trim() || null,
        credit_hold: document.getElementById('credit_hold').checked
      };

      if (!payload.entity_type) throw new Error('Entity Type is required.');
      if (!payload.tax_type) throw new Error('Tax Type is required.');

      return payload;
    },

    onSave: async (payload, isNew) => {
      const activeCompanyId = authManager.getActiveCompanyId();
      if (!activeCompanyId) throw new Error("Please select an active company first.");

      if (isNew) {
        payload.company_id = activeCompanyId;
        
        const { data, error } = await supabase
          .from('customers')
          .insert(payload)
          .select('id')
          .single();
          
        if (error) {
          if (error.code === '23505') throw new Error("A customer with this Code already exists.");
          throw error;
        }
        
        Toast.success("Customer created successfully.");
        window.location.hash = `#/master-data/customers/view?id=${data.id}`;
      } else {
        const { error } = await supabase
          .from('customers')
          .update(payload)
          .eq('id', currentRecordId)
          .eq('company_id', activeCompanyId);
          
        if (error) {
          if (error.code === '23505') throw new Error("A customer with this Code already exists.");
          throw error;
        }
        
        Toast.success("Customer updated successfully.");
        window.location.hash = `#/master-data/customers/view?id=${currentRecordId}`;
      }
      return true;
    }
  });

  await helper.init();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
