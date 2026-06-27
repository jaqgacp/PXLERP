// -----------------------------------------------------------------------------
// PXL ERP - Company List JS
// -----------------------------------------------------------------------------

import { ErpListHelper, escapeHTML } from '../shared/erp-list-helper.js';

export async function init() {
  const helper = new ErpListHelper({
    tableId: '#company-grid-body',
    tableName: 'companies',
    entityName: 'companies',
    requireActiveCompany: false, // Companies are universal
    searchInputId: '#company-search',
    columns: [
      { key: 'code', label: 'Code', sortable: true, searchable: true, renderer: (val) => `<strong>${escapeHTML(val)}</strong>` },
      { key: 'name', label: 'Name', sortable: true, searchable: true },
      { key: 'trade_name', label: 'Trade Name', sortable: true, searchable: true },
      { key: 'full_tin', label: 'TIN', sortable: true, searchable: true },
      { key: 'tax_type', label: 'Tax Type', sortable: true, searchable: false },
      { key: 'business_type', label: 'Business Type', sortable: true, searchable: false },
      { key: 'rdo_code', label: 'RDO Code', sortable: true, searchable: true },
      { 
        key: 'is_active', 
        label: 'Active', 
        sortable: true, 
        searchable: false,
        renderer: (val) => `
          <span class="erp-badge ${val ? 'erp-badge-success' : 'erp-badge-inactive'}">
            ${val ? 'Active' : 'Inactive'}
          </span>
        `
      },
      { 
        key: 'created_at', 
        label: 'Created At', 
        sortable: true, 
        searchable: false,
        renderer: (val) => val ? new Date(val).toLocaleDateString() : ''
      }
    ],
    rowActions: (company) => `
      <a href="#/setup/company-setup/view?id=${company.id}" class="erp-action-btn erp-action-btn-view" title="View Details">View</a>
      <a href="#/setup/company-setup/edit?id=${company.id}" class="erp-action-btn erp-action-btn-edit" title="Edit Company">Edit</a>
    `
  });

  await helper.load();
}

// In case this is run outside the router module execution pattern, auto-init
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
