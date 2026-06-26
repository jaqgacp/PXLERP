// -----------------------------------------------------------------------------
// PXL ERP - Branch List JS
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';
import { SetupListHelper, escapeHTML } from '../shared/setup-list-helper.js';

export async function init() {
  const supabase = authManager.supabase;
  
  const helper = new SetupListHelper({
    tableId: '#branch-grid-body',
    entityName: 'branches',
    colSpan: 9,
    requireActiveCompany: true,
    activeCompanyMessage: 'Please select a company to view its branches.',
    fetchData: async (activeCompanyId) => {
      const { data, error } = await supabase
        .from('branches')
        .select('id, code, name, short_name, address, tin_suffix, bir_registered, is_head_office, is_active, created_at')
        .eq('company_id', activeCompanyId)
        .order('code', { ascending: true });
      if (error) throw error;
      return data;
    },
    renderRow: (branch) => {
      const statusBadge = branch.is_active 
        ? '<span class="status status-approved">Active</span>'
        : '<span class="status status-void">Inactive</span>';
        
      const headOfficeBadge = branch.is_head_office 
        ? '<span class="status status-posted">HQ</span>'
        : '';
        
      const addressText = branch.address ? branch.address : (branch.short_name ? `(${branch.short_name})` : '');

      return `
        <td>${escapeHTML(branch.code || '')}</td>
        <td><strong>${escapeHTML(branch.name || '')}</strong> ${headOfficeBadge}</td>
        <td><span class="text-muted" style="font-size:11px">${escapeHTML(addressText)}</span></td>
        <td>${escapeHTML(branch.tin_suffix || '')}</td>
        <td>${branch.bir_registered ? 'Yes' : 'No'}</td>
        <td>${branch.is_head_office ? 'Yes' : 'No'}</td>
        <td>${statusBadge}</td>
        <td><span class="text-muted" style="font-size:11px">${branch.created_at ? new Date(branch.created_at).toLocaleDateString() : ''}</span></td>
        <td>
          <a class="doc-link" href="#/setup/branch-setup/view?id=${branch.id}">View</a>
          <span class="toolbar-sep"></span>
          <a class="doc-link" href="#/setup/branch-setup/edit?id=${branch.id}">Edit</a>
        </td>
      `;
    }
  });

  await helper.load();
}
