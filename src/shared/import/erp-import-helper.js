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
    this.originalFileName = null;
    this.fileSizeBytes = null;
    
    if (!document.getElementById('erp-import-css')) {
      const link = document.createElement('link');
      link.id = 'erp-import-css';
      link.rel = 'stylesheet';
      link.href = new URL('./import-preview.css', import.meta.url).href;
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

    this.originalFileName = file.name;
    this.fileSizeBytes = file.size;

    const reader = new FileReader();
    reader.onload = async (evt) => {
      try {
        const text = evt.target.result;
        await this.parseFile(text);
      } catch (err) {
        console.error("Import Framework Error:", err);
        Toast.error("Import failed: " + err.message);
        alert("Import Framework Error: " + err.message);
      } finally {
        if (this.fileInput) {
          this.fileInput.value = '';
        }
      }
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

  normalizeForDatabase(row) {
    const normalized = {};
    for (const [key, value] of Object.entries(row)) {
      if (value === undefined || value === null) {
        normalized[key] = null;
        continue;
      }
      
      if (typeof value === 'string') {
        const trimmed = value.trim();
        if (trimmed === '') {
          normalized[key] = null;
          continue;
        }

        // Date detection (YYYY-MM-DD)
        const isoRegex = /^\d{4}-\d{2}-\d{2}$/;
        if (isoRegex.test(trimmed)) {
          const d = new Date(trimmed);
          if (!isNaN(d.getTime())) {
            normalized[key] = trimmed;
            continue;
          }
        }
        
        // Boolean detection (Strict set via CsvParser)
        const boolVal = CsvParser.parseBoolean(trimmed);
        if (boolVal !== null) {
          normalized[key] = boolVal;
          continue;
        }
        
        // Numeric detection (Optional: be careful not to cast strings like "00001" to 1)
        // We will leave numeric-looking strings that might be codes (like "00001") as strings 
        // to prevent data loss. Only true numbers (if passed) are preserved.
        
        normalized[key] = trimmed;
      } else {
        // If it's already a number or boolean
        normalized[key] = value;
      }
    }
    return normalized;
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

      // Framework Normalization (BEFORE validation)
      const normalizedRow = this.normalizeForDatabase(dbRow);

      if (this.config.validators) {
        for (const [col, validatorFn] of Object.entries(this.config.validators)) {
          if (normalizedRow[col] !== null && normalizedRow[col] !== undefined && normalizedRow[col] !== '') {
            const res = validatorFn(normalizedRow[col]);
            if (res !== true) {
              errors.push(`'${Object.keys(this.config.columnMapping).find(k => this.config.columnMapping[k] === col)}': ${res}`);
            }
          }
        }
      }

      // Temporary Lifecycle Trace Log (First Row Only)
      if (i === 0) {
         console.log("--- ERP Import Framework Lifecycle Trace (Row 1) ---");
         console.log("1. CSV Raw / Parsed:", csvRow);
         console.log("2. Mapped:", dbRow);
         console.log("3. Normalized:", normalizedRow);
         console.log("4. Errors:", errors);
      }

      tempParsed.push({
        index: i + 1,
        original: csvRow,
        mapped: normalizedRow,
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
      const htmlUrl = new URL('./import-preview.html', import.meta.url).href;
      const resp = await fetch(htmlUrl);
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

    const startTime = performance.now();
    
    // Generate deterministic batch number: IMP-YYYYMMDD-HHMMSS
    const now = new Date();
    const dateStr = now.toISOString().split('T')[0].replace(/-/g, '');
    const timeStr = now.toISOString().split('T')[1].split('.')[0].replace(/:/g, '');
    const batchNo = `IMP-${dateStr}-${timeStr}`;

    let batchId = null;

    try {
      // 1. Create the Import Batch Record FIRST
      const { data: batchData, error: batchError } = await supabase
        .from('import_batches')
        .insert([{
          batch_no: batchNo,
          entity_name: this.config.entityName || 'Unknown',
          company_id: activeCompanyId,
          imported_by: user.id,
          status: 'pending',
          original_filename: this.originalFileName,
          file_size_bytes: this.fileSizeBytes,
          total_rows: this.parsedRows.length,
          valid_rows: this.validRows.length,
          invalid_rows: this.invalidRows.length,
          source_type: 'csv'
        }])
        .select('id')
        .single();

      if (batchError || !batchData) {
        throw new Error(`Failed to create import batch: ${batchError?.message || 'Unknown error'}`);
      }
      
      batchId = batchData.id;

      // 2. Prepare Payloads with import_batch_id
      const payloads = this.validRows.map(r => {
        let payload = { ...r.mapped };
        if (activeCompanyId) payload.company_id = activeCompanyId;
        payload.created_by = user.id;
        payload.import_batch_id = batchId;
        return payload;
      });

      if (payloads.length > 0) {
        console.log(`5. Final DB Payload (Row 1 for Batch ${batchNo}):`, payloads[0]);
      }

      // 3. Insert Valid Rows
      if (payloads.length > 0) {
        const { data, error } = await supabase
          .from(this.config.tableName)
          .insert(payloads)
          .select();

        if (error) {
          throw error;
        }
        
        console.log("6. Database Response (First Row Inserted):", data && data.length > 0 ? data[0] : null);
      }

      const durationMs = Math.round(performance.now() - startTime);

      // 4. Update Batch as Completed
      await supabase
        .from('import_batches')
        .update({
          status: 'completed',
          inserted_rows: payloads.length,
          failed_rows: 0,
          duration_ms: durationMs,
          completed_at: new Date().toISOString()
        })
        .eq('id', batchId);

      Toast.success(`Successfully imported ${payloads.length} record(s) in Batch ${batchNo}.`);
      
      // Update UI
      const titleEl = document.getElementById('erp-import-title');
      if (titleEl) {
        titleEl.textContent = `Import Complete (Batch: ${batchNo})`;
      }
      
      const tbody = document.getElementById('erp-import-tbody');
      if (tbody) {
         tbody.innerHTML = `<tr><td colspan="100%" style="text-align:center; padding: 20px;">
           <h3>Import Successful</h3>
           <p><strong>Batch No:</strong> ${batchNo}</p>
           <p><strong>${payloads.length}</strong> records were successfully inserted into the database.</p>
           <p><strong>${this.invalidRows.length}</strong> records were rejected during validation.</p>
           <button id="erp-import-success-close" style="margin-top: 15px; padding: 8px 16px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer;">Close & Refresh</button>
         </td></tr>`;
         
         document.getElementById('erp-import-success-close').onclick = () => {
           window.location.reload();
         };
      }
      
      btn.style.display = 'none';
      window.dispatchEvent(new CustomEvent('erp-import-success'));

    } catch (error) {
      console.error("Supabase Insert Error:", error);
      
      if (batchId) {
        // Mark batch as failed
        await supabase
          .from('import_batches')
          .update({
            status: 'failed',
            failed_rows: this.validRows.length,
            error_summary: { message: error.message, details: error.details || null },
            duration_ms: Math.round(performance.now() - startTime),
            completed_at: new Date().toISOString()
          })
          .eq('id', batchId);
      }

      Toast.error("Import failed during database insert: " + error.message);
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
