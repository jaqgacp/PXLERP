// -----------------------------------------------------------------------------
// PXL ERP - Department List JS
// -----------------------------------------------------------------------------

import { ErpListHelper, escapeHTML } from '../shared/erp-list-helper.js';

export async function init() {
  const helper = new ErpListHelper({
    tableId: '#department-grid-body',
    tableName: 'departments',
    entityName: 'departments',
    searchInputId: '#department-search',
    requireActiveCompany: true,
    activeCompanyMessage: 'Please select a company to view its departments.',
    columns: [
      { key: 'code', label: 'Code', sortable: true, searchable: true },
      { key: 'name', label: 'Name', sortable: true, searchable: true },
      { key: 'branch_id', label: 'Branch ID', sortable: true, searchable: true },
      { key: 'parent_department_id', label: 'Parent Dept ID', sortable: true, searchable: false },
      { key: 'is_active', label: 'Active', sortable: true, searchable: false, renderer: val => {
          return val 
            ? '<span class="erp-badge erp-badge-success">Active</span>'
            : '<span class="erp-badge erp-badge-inactive">Inactive</span>';
      }},
      { key: 'created_at', label: 'Created At', sortable: true, searchable: false, renderer: val => val ? new Date(val).toLocaleDateString() : '' }
    ],
    rowActions: (dept) => `
      <a href="#/setup/department-setup/view?id=${dept.id}" class="erp-action-btn erp-action-btn-view" title="View Details">View</a>
      <a href="#/setup/department-setup/edit?id=${dept.id}" class="erp-action-btn erp-action-btn-edit" title="Edit Department">Edit</a>
    `
  });

  await helper.load();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
