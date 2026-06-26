// -----------------------------------------------------------------------------
// PXL ERP - Branch List JS
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';
import { SetupListHelper, escapeHTML } from '../shared/setup-list-helper.js';
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
        // The value is already normalized by the framework. We just need to check if it's a valid date string.
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
