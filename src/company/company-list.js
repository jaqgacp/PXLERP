// -----------------------------------------------------------------------------
// PXL ERP - Company List JS
// -----------------------------------------------------------------------------

import { supabase, SetupListHelper, escapeHTML } from '../shared/setup-list-helper.js';

const helper = new SetupListHelper({
  tableId: '#company-grid-body',
  entityName: 'companies',
  colSpan: 10,
  fetchData: async () => {
    const { data, error } = await supabase
      .from('companies')
      .select('id, code, name, trade_name, tin, tax_type, business_type, rdo_code, is_active, created_at')
      .order('code', { ascending: true });
    if (error) throw error;
    return data;
  },
  renderRow: (company) => `
    <td><strong>${escapeHTML(company.code || '')}</strong></td>
    <td>${escapeHTML(company.name || '')}</td>
    <td>${escapeHTML(company.trade_name || '')}</td>
    <td>${escapeHTML(company.tin || '')}</td>
    <td>${escapeHTML(company.tax_type || '')}</td>
    <td>${escapeHTML(company.business_type || '')}</td>
    <td>${escapeHTML(company.rdo_code || '')}</td>
    <td>
      <span class="erp-badge ${company.is_active ? 'erp-badge-success' : 'erp-badge-inactive'}">
        ${company.is_active ? 'Active' : 'Inactive'}
      </span>
    </td>
    <td>${company.created_at ? new Date(company.created_at).toLocaleDateString() : ''}</td>
    <td>
      <a href="#/setup/company-setup/view?id=${company.id}" class="erp-action-btn erp-action-btn-view" title="View Details">View</a>
      <a href="#/setup/company-setup/edit?id=${company.id}" class="erp-action-btn erp-action-btn-edit" title="Edit Company">Edit</a>
    </td>
  `
});

helper.load();
