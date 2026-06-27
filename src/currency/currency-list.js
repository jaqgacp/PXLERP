// -----------------------------------------------------------------------------
// PXL ERP - Currency List JS
// -----------------------------------------------------------------------------

import { ErpListHelper, escapeHTML } from '../shared/erp-list-helper.js';

export async function init() {
  const helper = new ErpListHelper({
    tableId: '#currency-grid-body',
    tableName: 'currencies',
    entityName: 'currencies',
    requireActiveCompany: false,
    columns: [
      { key: 'code', label: 'Code', sortable: true, searchable: true },
      { key: 'name', label: 'Name', sortable: true, searchable: true },
      { key: 'symbol', label: 'Symbol', sortable: false, searchable: false },
      { 
        key: 'is_base_currency', 
        label: 'Base Currency', 
        sortable: true, 
        searchable: false,
        renderer: (val) => val ? 'Yes' : 'No'
      },
      { 
        key: 'is_active', 
        label: 'Active', 
        sortable: true, 
        searchable: false,
        renderer: (val) => val ? 'Yes' : 'No'
      },
      { 
        key: 'created_at', 
        label: 'Created At', 
        sortable: true, 
        searchable: false,
        renderer: (val) => val ? new Date(val).toLocaleDateString() : ''
      }
    ],
    rowActions: (currency) => `
      <a href="#/setup/currency-setup/view?id=${currency.id}">View</a> |
      <a href="#/setup/currency-setup/edit?id=${currency.id}">Edit</a> |
      <a href="#" onclick="alert('Audit Trail placeholder'); return false;">Audit Trail</a>
    `
  });

  await helper.load();
}
