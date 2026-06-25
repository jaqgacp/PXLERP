// -----------------------------------------------------------------------------
// PXL ERP - Department List JS
// -----------------------------------------------------------------------------

import { supabase, SetupListHelper, escapeHTML } from '../shared/setup-list-helper.js';

document.addEventListener('DOMContentLoaded', () => {
  const helper = new SetupListHelper({
    tableId: '#department-grid-body',
    entityName: 'departments',
    colSpan: 7,
    fetchData: async () => {
      const { data, error } = await supabase
        .from('departments')
        .select('code, name, branch_id, parent_department_id, is_active, created_at')
        .order('code', { ascending: true });
      if (error) throw error;
      return data;
    },
    renderRow: (department) => `
      <td>${escapeHTML(department.code || '')}</td>
      <td>${escapeHTML(department.name || '')}</td>
      <td>${escapeHTML(department.branch_id || '')}</td>
      <td>${escapeHTML(department.parent_department_id || '')}</td>
      <td>${department.is_active ? 'Yes' : 'No'}</td>
      <td>${department.created_at ? new Date(department.created_at).toLocaleDateString() : ''}</td>
      <td>
        <a href="#" onclick="alert('View placeholder'); return false;">View</a> |
        <a href="#" onclick="alert('Edit placeholder'); return false;">Edit</a> |
        <a href="#" onclick="alert('Audit Trail placeholder'); return false;">Audit Trail</a>
      </td>
    `
  });

  helper.load();
});
