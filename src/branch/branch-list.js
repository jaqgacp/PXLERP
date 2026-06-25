// -----------------------------------------------------------------------------
// PXL ERP - Branch List JS
// -----------------------------------------------------------------------------

import { supabase, SetupListHelper, escapeHTML } from '../shared/setup-list-helper.js';

document.addEventListener('DOMContentLoaded', () => {
  const helper = new SetupListHelper({
    tableId: '#branch-grid-body',
    entityName: 'branches',
    colSpan: 9,
    fetchData: async () => {
      const { data, error } = await supabase
        .from('branches')
        .select('code, name, address, tin_suffix, bir_registered, is_head_office, is_active, created_at')
        .order('code', { ascending: true });
      if (error) throw error;
      return data;
    },
    renderRow: (branch) => `
      <td>${escapeHTML(branch.code || '')}</td>
      <td>${escapeHTML(branch.name || '')}</td>
      <td>${escapeHTML(branch.address || '')}</td>
      <td>${escapeHTML(branch.tin_suffix || '')}</td>
      <td>${branch.bir_registered ? 'Yes' : 'No'}</td>
      <td>${branch.is_head_office ? 'Yes' : 'No'}</td>
      <td>${branch.is_active ? 'Yes' : 'No'}</td>
      <td>${branch.created_at ? new Date(branch.created_at).toLocaleDateString() : ''}</td>
      <td>
        <a href="#" onclick="alert('View placeholder'); return false;">View</a> |
        <a href="#" onclick="alert('Edit placeholder'); return false;">Edit</a> |
        <a href="#" onclick="alert('Audit Trail placeholder'); return false;">Audit Trail</a>
      </td>
    `
  });

  helper.load();
});
