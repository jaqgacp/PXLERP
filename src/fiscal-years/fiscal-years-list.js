import { authManager } from '../auth/auth-manager.js';
import { ErpListHelper, escapeHTML } from '../shared/erp-list-helper.js';

export async function init() {
  const helper = new ErpListHelper({
    tableId: '#fiscal-years-grid-body',
    tableName: 'fiscal_years',
    entityName: 'fiscal_years',
    searchInputId: '#fiscal-years-search',
    requireActiveCompany: true,
    activeCompanyMessage: 'Please select a company to view its fiscal years.',
    columns: [
      { key: 'year_code', label: 'Year Code', sortable: true, searchable: true, renderer: val => `<strong>${escapeHTML(val || '')}</strong>` },
      { key: 'date_from', label: 'From Date', sortable: true, searchable: true },
      { key: 'date_to', label: 'To Date', sortable: true, searchable: true },
      { key: 'is_current', label: 'Current', sortable: true, searchable: false, renderer: val => val ? '<span class="erp-badge erp-badge-success">Yes</span>' : '<span class="erp-badge erp-badge-inactive">No</span>' },
      { key: 'status', label: 'Status', sortable: true, searchable: true, renderer: val => {
          let statusClass = 'erp-badge-inactive';
          if (val === 'Open') statusClass = 'erp-badge-success';
          return `<span class="erp-badge ${statusClass}">${escapeHTML(val || '')}</span>`;
      }},
      { key: 'created_at', label: 'Created At', sortable: true, searchable: false, renderer: val => val ? new Date(val).toLocaleDateString() : '' }
    ],
    rowActions: (fy) => `
      <a href="#/setup/fiscal-years/view?id=${fy.id}" class="erp-action-btn erp-action-btn-view" title="View Details">View</a>
      <a href="#/setup/fiscal-years/edit?id=${fy.id}" class="erp-action-btn erp-action-btn-edit" title="Edit Fiscal Year">Edit</a>
    `
  });

  await helper.load();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
