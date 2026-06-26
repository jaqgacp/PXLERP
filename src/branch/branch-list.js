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
        ? '<span class="erp-badge erp-badge-success">Active</span>'
        : '<span class="erp-badge erp-badge-inactive">Inactive</span>';
        
      const headOfficeBadge = branch.is_head_office 
        ? '<span class="erp-badge">HQ</span>'
        : '';
        
      const addressText = branch.address ? branch.address : (branch.short_name ? `(${branch.short_name})` : '');

      return `
        <td>${escapeHTML(branch.code || '')}</td>
        <td><strong>${escapeHTML(branch.name || '')}</strong> ${headOfficeBadge}</td>
        <td>${escapeHTML(addressText)}</td>
        <td>${escapeHTML(branch.tin_suffix || '')}</td>
        <td>${branch.bir_registered ? 'Yes' : 'No'}</td>
        <td>${branch.is_head_office ? 'Yes' : 'No'}</td>
        <td>${statusBadge}</td>
        <td>${branch.created_at ? new Date(branch.created_at).toLocaleDateString() : ''}</td>
        <td>
          <a href="#/setup/branch-setup/view?id=${branch.id}" class="erp-action-btn erp-action-btn-view" title="View Details">View</a>
          <a href="#/setup/branch-setup/edit?id=${branch.id}" class="erp-action-btn erp-action-btn-edit" title="Edit Branch">Edit</a>
        </td>
      `;
    }
  });

  await helper.load();
}
