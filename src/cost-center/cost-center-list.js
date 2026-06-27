// -----------------------------------------------------------------------------
// PXL ERP - Cost Center List JS
// -----------------------------------------------------------------------------

import { ErpListHelper, escapeHTML } from '../shared/erp-list-helper.js';

export async function init() {
  const helper = new ErpListHelper({
    tableId: '#costcenter-grid-body',
    tableName: 'cost_centers',
    entityName: 'cost_centers',
    searchInputId: '#costcenter-search',
    requireActiveCompany: true,
    activeCompanyMessage: 'Please select a company to view its cost centers.',
    columns: [
      { key: 'code', label: 'Code', sortable: true, searchable: true },
      { key: 'name', label: 'Name', sortable: true, searchable: true },
      { key: 'department_id', label: 'Department ID', sortable: true, searchable: true },
      { key: 'is_active', label: 'Active', sortable: true, searchable: false, renderer: val => {
          return val 
            ? '<span class="erp-badge erp-badge-success">Active</span>'
            : '<span class="erp-badge erp-badge-inactive">Inactive</span>';
      }},
      { key: 'created_at', label: 'Created At', sortable: true, searchable: false, renderer: val => val ? new Date(val).toLocaleDateString() : '' }
    ],
    rowActions: (cc) => `
      <a href="#/setup/cost-center-setup/view?id=${cc.id}" class="erp-action-btn erp-action-btn-view" title="View Details">View</a>
      <a href="#/setup/cost-center-setup/edit?id=${cc.id}" class="erp-action-btn erp-action-btn-edit" title="Edit Cost Center">Edit</a>
    `
  });

  await helper.load();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
