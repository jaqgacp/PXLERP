import { supabase, SetupListHelper, escapeHTML } from '../shared/setup-list-helper.js';
import { authManager } from '../auth/auth-manager.js';

document.addEventListener('DOMContentLoaded', async () => {
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
    renderRow: (fy) => `
      <td>${escapeHTML(fy.year_code || '')}</td>
      <td>${escapeHTML(fy.date_from || '')}</td>
      <td>${escapeHTML(fy.date_to || '')}</td>
      <td>${fy.is_current ? 'Yes' : 'No'}</td>
      <td>${escapeHTML(fy.status || '')}</td>
      <td>${fy.created_at ? new Date(fy.created_at).toLocaleDateString() : ''}</td>
      <td>
        <a href="#/setup/fiscal-years/view?id=${fy.id}">View</a> |
        <a href="#/setup/fiscal-years/edit?id=${fy.id}">Edit</a>
      </td>
    `
  });

  await helper.load();
});
