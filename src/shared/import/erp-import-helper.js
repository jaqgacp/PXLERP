// -----------------------------------------------------------------------------
// PXL ERP - Import Framework Helper
// -----------------------------------------------------------------------------
import { authManager } from '../../auth/auth-manager.js';
import { Toast } from '../erp-form-helper.js';
import { CsvParser } from './csv-parser.js';

const supabase = authManager.supabase;

export class ErpImportHelper {
  constructor(config) {
    this.config = config;
    this.fileInput = null;
    this.parsedRows = [];
    this.validRows = [];
    this.invalidRows = [];
    
    if (!document.getElementById('erp-import-css')) {
      const link = document.createElement('link');
      link.id = 'erp-import-css';
      link.rel = 'stylesheet';
      link.href = 'src/shared/import/import-preview.css';
      document.head.appendChild(link);
    }
  }

  generateTemplate() {
    const headers = Object.keys(this.config.columnMapping);
    return headers.join(',') + '\n';
  }

  downloadTemplate() {
    const csvContent = this.generateTemplate();
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', `${this.config.entityName.replace(/\s+/g, '_')}_Import_Template.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  openFilePicker() {
    if (this.config.activeCompanyRequired) {
      if (!authManager.getActiveCompanyId()) {
        Toast.error("No active company selected. Action blocked.");
        return;
      }
    }

    if (!this.fileInput) {
      this.fileInput = document.createElement('input');
      this.fileInput.type = 'file';
      this.fileInput.accept = '.csv';
      this.fileInput.style.display = 'none';
      this.fileInput.onchange = (e) => this.handleFileSelected(e);
      document.body.appendChild(this.fileInput);
    }
    this.fileInput.value = '';
    this.fileInput.click();
  }

  async handleFileSelected(e) {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = async (evt) => {
      const text = evt.target.result;
      await this.parseFile(text);
    };
    reader.readAsText(file);
  }

  async parseFile(csvText) {
    const { headers, data } = CsvParser.parse(csvText);
    if (!headers || headers.length === 0) {
      Toast.error("CSV file is empty or has no headers.");
      return;
    }
    
    const expectedHeaders = Object.keys(this.config.columnMapping);
    const requiredDbCols = this.config.requiredColumns || [];
    const missingHeaders = [];
    
    for (const h of expectedHeaders) {
       const dbCol = this.config.columnMapping[h];
       if (requiredDbCols.includes(dbCol) && !headers.includes(h)) {
         missingHeaders.push(h);
       }
    }

    if (missingHeaders.length > 0) {
      Toast.error(`Missing required columns: ${missingHeaders.join(', ')}`);
      return;
    }

    await this.validateRows(data, headers);
  }

  async validateRows(data, originalHeaders) {
    this.validRows = [];
    this.invalidRows = [];
    this.parsedRows = [];

    const activeCompanyId = this.config.activeCompanyRequired ? authManager.getActiveCompanyId() : null;

    const tempParsed = [];
    for (let i = 0; i < data.length; i++) {
      const csvRow = data[i];
      const dbRow = {};
      const errors = [];

      for (const [csvHeader, dbCol] of Object.entries(this.config.columnMapping)) {
        let val = csvRow[csvHeader];
        if (val === undefined) val = '';
        dbRow[dbCol] = val;
      }

      for (const req of (this.config.requiredColumns || [])) {
        if (dbRow[req] === undefined || dbRow[req] === '') {
          errors.push(`'${Object.keys(this.config.columnMapping).find(k => this.config.columnMapping[k] === req)}' is required.`);
        }
      }

      if (this.config.validators) {
        for (const [col, validatorFn] of Object.entries(this.config.validators)) {
          if (dbRow[col] !== undefined && dbRow[col] !== '') {
            const res = validatorFn(dbRow[col]);
            if (res !== true) {
              errors.push(`'${Object.keys(this.config.columnMapping).find(k => this.config.columnMapping[k] === col)}': ${res}`);
            }
          }
        }
      }

      tempParsed.push({
        index: i + 1,
        original: csvRow,
        mapped: dbRow,
        errors
      });
    }

    let dbDuplicates = [];
    if (this.config.duplicateCheckFields && this.config.duplicateCheckFields.length > 0) {
      const otherFields = this.config.duplicateCheckFields.filter(f => f !== 'company_id');
      
      if (otherFields.length === 1 && activeCompanyId) {
        const checkField = otherFields[0];
        const valuesToCheck = tempParsed.filter(r => r.mapped[checkField]).map(r => r.mapped[checkField]);
        if (valuesToCheck.length > 0) {
           const { data: dupes } = await supabase
             .from(this.config.tableName)
             .select(checkField)
             .eq('company_id', activeCompanyId)
             .in(checkField, valuesToCheck);
           if (dupes) {
             dbDuplicates = dupes.map(d => d[checkField]);
           }
        }
      }
    }

    const seenValues = new Set();
    const otherField = this.config.duplicateCheckFields?.find(f => f !== 'company_id');

    for (const row of tempParsed) {
      if (otherField && row.mapped[otherField]) {
        if (seenValues.has(row.mapped[otherField])) {
          row.errors.push(`Duplicate '${otherField}' found within the CSV file.`);
        } else {
          seenValues.add(row.mapped[otherField]);
        }
      }

      if (otherField && dbDuplicates.includes(row.mapped[otherField])) {
        row.errors.push(`Record with this '${otherField}' already exists in the database.`);
      }

      if (row.errors.length === 0) {
        if (this.config.transformRow) {
           try {
             row.mapped = this.config.transformRow(row.mapped);
           } catch(e) {
             row.errors.push("Failed to transform row: " + e.message);
           }
        }
      }

      this.parsedRows.push(row);
      if (row.errors.length === 0) {
        this.validRows.push(row);
      } else {
        this.invalidRows.push(row);
      }
    }

    await this.renderPreview(originalHeaders);
  }

  async renderPreview(headers) {
    if (!document.getElementById('erp-import-overlay')) {
      const resp = await fetch('src/shared/import/import-preview.html');
      const html = await resp.text();
      const div = document.createElement('div');
      div.innerHTML = html;
      document.body.appendChild(div.firstElementChild);
    }

    const overlay = document.getElementById('erp-import-overlay');
    document.getElementById('erp-import-title').textContent = `Import Preview: ${this.config.entityName}`;
    
    document.getElementById('erp-import-total').textContent = this.parsedRows.length;
    document.getElementById('erp-import-valid').textContent = this.validRows.length;
    document.getElementById('erp-import-invalid').textContent = this.invalidRows.length;

    const btnConfirm = document.getElementById('erp-import-confirm');
    btnConfirm.disabled = this.validRows.length === 0;

    const thead = document.getElementById('erp-import-thead');
    thead.innerHTML = `<tr>
      <th>Row</th>
      <th>Status</th>
      ${headers.map(h => `<th>${this.escapeHTML(h)}</th>`).join('')}
    </tr>`;

    const tbody = document.getElementById('erp-import-tbody');
    let rowsHtml = '';
    
    for (const row of this.parsedRows) {
      const statusClass = row.errors.length > 0 ? 'invalid' : 'valid';
      const statusText = row.errors.length > 0 ? 'Invalid' : 'Valid';
      
      let cells = '';
      for (const h of headers) {
        cells += `<td>${this.escapeHTML(row.original[h] || '')}</td>`;
      }
      
      let errorHtml = '';
      if (row.errors.length > 0) {
        errorHtml = row.errors.map(err => `<span class="erp-import-error-cell">• ${this.escapeHTML(err)}</span>`).join('');
      }

      rowsHtml += `
        <tr class="row-${statusClass}">
          <td>${row.index}</td>
          <td>
            <span class="erp-import-status-badge ${statusClass}">${statusText}</span>
            ${errorHtml}
          </td>
          ${cells}
        </tr>
      `;
    }
    
    tbody.innerHTML = rowsHtml;

    document.getElementById('erp-import-close').onclick = () => this.closePreview();
    document.getElementById('erp-import-cancel').onclick = () => this.closePreview();
    btnConfirm.onclick = () => this.confirmImport();

    requestAnimationFrame(() => {
      overlay.classList.add('show');
    });
  }

  closePreview() {
    const overlay = document.getElementById('erp-import-overlay');
    if (overlay) {
      overlay.classList.remove('show');
      setTimeout(() => overlay.remove(), 200);
    }
    if (this.fileInput) {
      this.fileInput.value = '';
    }
  }

  async confirmImport() {
    const btn = document.getElementById('erp-import-confirm');
    btn.disabled = true;
    btn.textContent = 'Importing...';

    const activeCompanyId = this.config.activeCompanyRequired ? authManager.getActiveCompanyId() : null;
    const user = authManager.getCurrentUser();

    if (!user) {
      Toast.error("User not authenticated.");
      btn.disabled = false;
      btn.textContent = 'Confirm Import';
      return;
    }

    const payloads = this.validRows.map(r => {
      const payload = { ...r.mapped };
      if (activeCompanyId) payload.company_id = activeCompanyId;
      payload.created_by = user.id;
      return payload;
    });

    try {
      const { error } = await supabase
        .from(this.config.tableName)
        .insert(payloads);

      if (error) throw error;

      Toast.success(`Successfully imported ${payloads.length} ${this.config.entityName}(s).`);
      this.closePreview();
      
      // Call standard load on current list page to refresh
      window.location.reload(); 
    } catch (err) {
      console.error(err);
      Toast.error(`Import failed: ${err.message}`);
      btn.disabled = false;
      btn.textContent = 'Confirm Import';
    }
  }

  escapeHTML(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }
}
