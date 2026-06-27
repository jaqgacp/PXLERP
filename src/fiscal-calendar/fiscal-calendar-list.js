import { authManager } from '../auth/auth-manager.js';
import { ErpListHelper, escapeHTML, supabase } from '../shared/erp-list-helper.js';

export async function init() {
  const companyId = authManager.getActiveCompanyId();

  const helper = new ErpListHelper({
    tableId: '#fiscal-calendar-grid-body',
    tableName: 'fiscal_periods',
    entityName: 'fiscal_periods',
    searchInputId: '#fiscal-calendar-search',
    requireActiveCompany: true,
    activeCompanyMessage: 'Please select a company to view its fiscal calendar.',
    extraSelectFields: ['fiscal_years(year_code)'],
    columns: [
      { key: 'fiscal_years.year_code', label: 'Year', sortable: false, searchable: false, renderer: (val, item) => `<strong>${escapeHTML(item.fiscal_years?.year_code || '')}</strong>` },
      { key: 'period_number', label: 'Period', sortable: true, searchable: true },
      { key: 'period_name', label: 'Period Name', sortable: true, searchable: true },
      { key: 'date_from', label: 'From Date', sortable: true, searchable: true },
      { key: 'date_to', label: 'To Date', sortable: true, searchable: true },
      { key: 'quarter', label: 'Quarter', sortable: true, searchable: true, renderer: val => `Q${escapeHTML(val?.toString() || '')}` },
      { key: 'status', label: 'Status', sortable: true, searchable: true, renderer: val => {
          let statusClass = 'erp-badge-inactive';
          if (val === 'Open') statusClass = 'erp-badge-success';
          return `<span class="erp-badge ${statusClass}">${escapeHTML(val || '')}</span>`;
      }}
    ],
    rowActions: (fp) => `
      <a href="#/setup/fiscal-calendar/view?id=${fp.id}" class="erp-action-btn erp-action-btn-view" title="View Details">View</a>
      <a href="#/setup/fiscal-calendar/edit?id=${fp.id}" class="erp-action-btn erp-action-btn-edit" title="Edit Period">Edit</a>
    `
  });

  // Load filter dropdown
  const filterSelect = document.getElementById('fiscal-year-filter');
  if (companyId && filterSelect) {
    const { data: fyData } = await supabase
      .from('fiscal_years')
      .select('id, year_code')
      .eq('company_id', companyId)
      .order('year_code', { ascending: false });

    if (fyData) {
      fyData.forEach(fy => {
        const opt = document.createElement('option');
        opt.value = fy.id;
        opt.textContent = fy.year_code;
        filterSelect.appendChild(opt);
      });
    }

    filterSelect.addEventListener('change', () => {
      const val = filterSelect.value;
      if (val) {
        helper.staticFilters = [{ col: 'fiscal_year_id', op: 'eq', val: val }];
      } else {
        helper.staticFilters = [];
      }
      helper.currentPage = 1;
      helper.load();
    });
  }

  await helper.load();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
