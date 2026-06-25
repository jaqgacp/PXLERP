// -----------------------------------------------------------------------------
// PXL ERP - Currency List JS
// -----------------------------------------------------------------------------

import { supabase, SetupListHelper, escapeHTML } from '../shared/setup-list-helper.js';

document.addEventListener('DOMContentLoaded', () => {
  const helper = new SetupListHelper({
    tableId: '#currency-grid-body',
    entityName: 'currencies',
    colSpan: 7,
    fetchData: async () => {
      const { data, error } = await supabase
        .from('currencies')
        .select('code, name, symbol, is_base_currency, is_active, created_at')
        .order('code', { ascending: true });
      if (error) throw error;
      return data;
    },
    renderRow: (currency) => `
      <td>${escapeHTML(currency.code || '')}</td>
      <td>${escapeHTML(currency.name || '')}</td>
      <td>${escapeHTML(currency.symbol || '')}</td>
      <td>${currency.is_base_currency ? 'Yes' : 'No'}</td>
      <td>${currency.is_active ? 'Yes' : 'No'}</td>
      <td>${currency.created_at ? new Date(currency.created_at).toLocaleDateString() : ''}</td>
      <td>
        <a href="#" onclick="alert('View placeholder'); return false;">View</a> |
        <a href="#" onclick="alert('Edit placeholder'); return false;">Edit</a> |
        <a href="#" onclick="alert('Audit Trail placeholder'); return false;">Audit Trail</a>
      </td>
    `
  });

  helper.load();
});
