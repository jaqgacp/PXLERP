// -----------------------------------------------------------------------------
// PXL ERP - Branch List JS
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';
import { ErpListHelper, escapeHTML } from '../shared/erp-list-helper.js';
import { ErpImportHelper } from '../shared/import/erp-import-helper.js';
import { CsvParser } from '../shared/import/csv-parser.js';

export async function init() {
  const supabase = authManager.supabase;

  const importHelper = new ErpImportHelper({
    entityName: 'Branch',
    tableName: 'branches',
    activeCompanyRequired: true,
    requiredColumns: ['code', 'name'],
    optionalColumns: [
      'short_name', 'tin_suffix', 'bir_registered', 'is_head_office', 'is_active',
      'rdo_code', 'line_of_business', 'ptu_cas_no', 'ptu_cas_date_issued',
      'address', 'zip_code', 'contact_person', 'phone', 'email'
    ],
    duplicateCheckFields: ['company_id', 'code'],
    columnMapping: {
      'Branch Code': 'code',
      'Branch Name': 'name',
      'Short Name': 'short_name',
      'TIN Suffix': 'tin_suffix',
      'BIR Registered': 'bir_registered',
      'Head Office': 'is_head_office',
      'Active': 'is_active',
      'RDO Code': 'rdo_code',
      'Line of Business': 'line_of_business',
      'PTU/CAS No': 'ptu_cas_no',
      'PTU/CAS Date Issued': 'ptu_cas_date_issued',
      'Address': 'address',
      'Zip Code': 'zip_code',
      'Contact Person': 'contact_person',
      'Phone': 'phone',
      'Email': 'email'
    },
    validators: {
      'tin_suffix': (val) => {
        if (!val) return true;
        return /^\d{5}$/.test(val) || 'TIN Suffix must be exactly 5 digits.';
      },
      'bir_registered': (val) => {
        if (val === null || val === undefined || val === '') return true;
        if (typeof val === 'boolean') return true;
        return CsvParser.parseBoolean(val) !== null || 'Invalid boolean value (Yes/No, TRUE/FALSE, Y/N, 1/0).';
      },
      'is_head_office': (val) => {
        if (val === null || val === undefined || val === '') return true;
        if (typeof val === 'boolean') return true;
        return CsvParser.parseBoolean(val) !== null || 'Invalid boolean value.';
      },
      'is_active': (val) => {
        if (val === null || val === undefined || val === '') return true;
        if (typeof val === 'boolean') return true;
        return CsvParser.parseBoolean(val) !== null || 'Invalid boolean value.';
      },
      'ptu_cas_date_issued': (val) => {
        if (!val) return true;
        const isoRegex = /^\d{4}-\d{2}-\d{2}$/;
        return isoRegex.test(val) || 'Date must be valid (YYYY-MM-DD).';
      }
    }
  });

  const btnDownload = document.getElementById('btn-download-template');
  if (btnDownload) {
    btnDownload.addEventListener('click', () => {
      importHelper.downloadTemplate();
    });
  }

  const btnImport = document.getElementById('btn-import');
  if (btnImport) {
    btnImport.onclick = () => {
      importHelper.openFilePicker();
    };
  }
  
  const helper = new ErpListHelper({
    tableId: '#branch-grid-body',
    tableName: 'branches',
    entityName: 'branches',
    searchInputId: '#branch-search',
    requireActiveCompany: true,
    activeCompanyMessage: 'Please select a company to view its branches.',
    extraSelectFields: ['short_name'],
    columns: [
      { key: 'code', label: 'Code', sortable: true, searchable: true },
      { key: 'name', label: 'Name', sortable: true, searchable: true, renderer: (val, item) => {
          const headOfficeBadge = item.is_head_office ? '<span class="erp-badge">HQ</span>' : '';
          return `<strong>${escapeHTML(val || '')}</strong> ${headOfficeBadge}`;
      }},
      { key: 'address', label: 'Address', sortable: true, searchable: true, renderer: (val, item) => {
          return escapeHTML(val ? val : (item.short_name ? `(${item.short_name})` : ''));
      }},
      { key: 'tin_suffix', label: 'TIN Suffix', sortable: true, searchable: true },
      { key: 'bir_registered', label: 'BIR Registered', sortable: true, searchable: false, renderer: val => val ? 'Yes' : 'No' },
      { key: 'is_head_office', label: 'Head Office', sortable: true, searchable: false, renderer: val => val ? 'Yes' : 'No' },
      { key: 'is_active', label: 'Active', sortable: true, searchable: false, renderer: val => {
          return val 
            ? '<span class="erp-badge erp-badge-success">Active</span>'
            : '<span class="erp-badge erp-badge-inactive">Inactive</span>';
      }},
      { key: 'created_at', label: 'Created At', sortable: true, searchable: false, renderer: val => val ? new Date(val).toLocaleDateString() : '' }
    ],
    rowActions: (branch) => `
      <a href="#/setup/branch-setup/view?id=${branch.id}" class="erp-action-btn erp-action-btn-view" title="View Details">View</a>
      <a href="#/setup/branch-setup/edit?id=${branch.id}" class="erp-action-btn erp-action-btn-edit" title="Edit Branch">Edit</a>
    `
  });

  // Re-bind load to import helper so it refreshes list on success
  importHelper.onSuccess = () => helper.load();

  await helper.load();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
