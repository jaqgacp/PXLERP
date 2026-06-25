// -----------------------------------------------------------------------------
// PXL ERP - Cost Center List JS
// -----------------------------------------------------------------------------

import { supabase, SetupListHelper, escapeHTML } from '../shared/setup-list-helper.js';

document.addEventListener('DOMContentLoaded', () => {
  const helper = new SetupListHelper({
    tableId: '#costcenter-grid-body',
    entityName: 'cost centers',
    colSpan: 6,
    fetchData: async () => {
      const { data, error } = await supabase
        .from('cost_centers')
        .select('code, name, department_id, is_active, created_at')
        .order('code', { ascending: true });
      if (error) throw error;
      return data;
    },
    renderRow: (costCenter) => `
      <td>${escapeHTML(costCenter.code || '')}</td>
      <td>${escapeHTML(costCenter.name || '')}</td>
      <td>${escapeHTML(costCenter.department_id || '')}</td>
      <td>${costCenter.is_active ? 'Yes' : 'No'}</td>
      <td>${costCenter.created_at ? new Date(costCenter.created_at).toLocaleDateString() : ''}</td>
      <td>
        <a href="#" onclick="alert('View placeholder'); return false;">View</a> |
        <a href="#" onclick="alert('Edit placeholder'); return false;">Edit</a> |
        <a href="#" onclick="alert('Audit Trail placeholder'); return false;">Audit Trail</a>
      </td>
    `
  });

  helper.load();
});
