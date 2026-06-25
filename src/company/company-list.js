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
    <td>${escapeHTML(company.code || '')}</td>
    <td>${escapeHTML(company.name || '')}</td>
    <td>${escapeHTML(company.trade_name || '')}</td>
    <td>${escapeHTML(company.tin || '')}</td>
    <td>${escapeHTML(company.tax_type || '')}</td>
    <td>${escapeHTML(company.business_type || '')}</td>
    <td>${escapeHTML(company.rdo_code || '')}</td>
    <td>${company.is_active ? 'Yes' : 'No'}</td>
    <td>${company.created_at ? new Date(company.created_at).toLocaleDateString() : ''}</td>
    <td>
      <a href="#/setup/company-setup/view?id=${company.id}">View</a> |
      <a href="#/setup/company-setup/edit?id=${company.id}">Edit</a>
    </td>
  `
});

helper.load();
