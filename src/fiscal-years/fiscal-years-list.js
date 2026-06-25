import { supabase, SetupListHelper, escapeHTML } from '../shared/setup-list-helper.js';
import { authManager } from '../auth/auth-manager.js';

const helper = new SetupListHelper({
  tableId: '#fiscal-years-grid-body',
  entityName: 'fiscal_years',
  colSpan: 7,
  fetchData: async () => {
    // 1. Ensure Active Company
    let companyId;
    try {
      companyId = authManager.requireActiveCompany();
    } catch(err) {
      return [];
    }

    // 2. Fetch scoped to company
    const { data, error } = await supabase
      .from('fiscal_years')
      .select('id, year_code, date_from, date_to, is_current, status, created_at')
      .eq('company_id', companyId)
      .order('date_from', { ascending: false });
    if (error) throw error;
    return data;
  },
  renderRow: (fy) => {
    const isCurrentBadge = fy.is_current ? '<span class="erp-badge erp-badge-success">Yes</span>' : '<span class="erp-badge erp-badge-inactive">No</span>';
    let statusClass = 'erp-badge-inactive';
    if (fy.status === 'Open') statusClass = 'erp-badge-success';
    const statusBadge = `<span class="erp-badge ${statusClass}">${escapeHTML(fy.status || '')}</span>`;

    return `
      <td><strong>${escapeHTML(fy.year_code || '')}</strong></td>
      <td>${escapeHTML(fy.date_from || '')}</td>
      <td>${escapeHTML(fy.date_to || '')}</td>
      <td>${isCurrentBadge}</td>
      <td>${statusBadge}</td>
      <td>${fy.created_at ? new Date(fy.created_at).toLocaleDateString() : ''}</td>
      <td>
        <a href="#/setup/fiscal-years/view?id=${fy.id}" class="erp-action-btn erp-action-btn-view" title="View Details">👁️ View</a>
        <a href="#/setup/fiscal-years/edit?id=${fy.id}" class="erp-action-btn erp-action-btn-edit" title="Edit Fiscal Year">✏️ Edit</a>
      </td>
    `;
  }
});

await helper.load();
