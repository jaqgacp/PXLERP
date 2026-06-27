// -----------------------------------------------------------------------------
// PXL ERP - Customer List JS
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';
import { ErpListHelper, escapeHTML } from '../shared/erp-list-helper.js';

export async function init() {
  const supabase = authManager.supabase;

  // Currently we only have Export and Print mapped in UI, but no specific action logic yet.
  // We can hook up Export/Print to future endpoints or standard ERP grid actions.

  const helper = new ErpListHelper({
    tableId: '#customer-grid-body',
    tableName: 'customers',
    entityName: 'customers',
    searchInputId: '#customer-search',
    requireActiveCompany: true,
    activeCompanyMessage: 'Please select a company to view customers.',
    extraSelectFields: [],
    columns: [
      { key: 'code', label: 'Code', sortable: true, searchable: true },
      { key: 'registered_name', label: 'Registered Name', sortable: true, searchable: true, renderer: (val) => {
          return `<strong>${escapeHTML(val || '')}</strong>`;
      }},
      { key: 'trade_name', label: 'Trade Name', sortable: true, searchable: true, renderer: (val) => escapeHTML(val || '') },
      { key: 'entity_type', label: 'Entity Type', sortable: true, searchable: false, renderer: (val) => {
          if (!val) return '';
          // capitalize first letter
          return escapeHTML(val.charAt(0).toUpperCase() + val.slice(1));
      }},
      { key: 'tax_type', label: 'Tax Type', sortable: true, searchable: false, renderer: (val) => {
          if (!val) return '';
          // simple formatting for tax type (e.g. non_vat -> Non VAT)
          return escapeHTML(val.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase()));
      }},
      { key: 'tin', label: 'TIN', sortable: false, searchable: true, renderer: (val) => escapeHTML(val || '') },
      { key: 'is_active', label: 'Active', sortable: true, searchable: false, renderer: val => {
          return val 
            ? '<span class="erp-badge erp-badge-success">Active</span>'
            : '<span class="erp-badge erp-badge-inactive">Inactive</span>';
      }},
      { key: 'credit_hold', label: 'Credit Hold', sortable: false, searchable: false, renderer: val => {
          return val
            ? '<span class="erp-badge erp-badge-danger">On Hold</span>'
            : '';
      }}
    ],
    rowActions: (customer) => `
      <a href="#/master-data/customers/view?id=${customer.id}" class="erp-action-btn erp-action-btn-view" title="View Details">View</a>
      <a href="#/master-data/customers/edit?id=${customer.id}" class="erp-action-btn erp-action-btn-edit" title="Edit Customer">Edit</a>
    `
  });

  await helper.load();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
