// -----------------------------------------------------------------------------
// PXL ERP - Erp Lookup Helper
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';

const supabase = authManager.supabase;

function escapeHTML(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// Inject minimal CSS required for the modal if not present
function injectLookupCSS() {
  if (document.getElementById('erp-lookup-css')) return;
  const style = document.createElement('style');
  style.id = 'erp-lookup-css';
  style.textContent = `
    .erp-lookup-modal-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(15, 23, 42, 0.4);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 10000;
      opacity: 0;
      visibility: hidden;
      transition: opacity 0.2s ease, visibility 0.2s ease;
    }
    .erp-lookup-modal-overlay.active {
      opacity: 1;
      visibility: visible;
    }
    .erp-lookup-modal {
      background: #ffffff;
      border-radius: 8px;
      width: 600px;
      max-width: 95vw;
      max-height: 85vh;
      display: flex;
      flex-direction: column;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
      overflow: hidden;
    }
    .erp-lookup-header {
      padding: 1rem 1.5rem;
      border-bottom: 1px solid #e2e8f0;
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: #f8fafc;
    }
    .erp-lookup-title {
      font-weight: 600;
      color: #0f172a;
      font-size: 1.125rem;
      margin: 0;
    }
    .erp-lookup-close-btn {
      background: none;
      border: none;
      font-size: 1.5rem;
      color: #64748b;
      cursor: pointer;
      line-height: 1;
      padding: 0;
    }
    .erp-lookup-close-btn:hover {
      color: #0f172a;
    }
    .erp-lookup-body {
      padding: 1.5rem;
      display: flex;
      flex-direction: column;
      gap: 1rem;
      flex: 1;
      overflow: hidden;
    }
    .erp-lookup-search-input {
      width: 100%;
      padding: 0.5rem 0.75rem;
      border: 1px solid #cbd5e1;
      border-radius: 4px;
      font-size: 0.875rem;
    }
    .erp-lookup-search-input:focus {
      outline: none;
      border-color: #3b82f6;
      box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
    }
    .erp-lookup-table-container {
      flex: 1;
      overflow-y: auto;
      border: 1px solid #e2e8f0;
      border-radius: 4px;
    }
    .erp-lookup-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.875rem;
    }
    .erp-lookup-table th, .erp-lookup-table td {
      padding: 0.75rem 1rem;
      text-align: left;
      border-bottom: 1px solid #e2e8f0;
    }
    .erp-lookup-table th {
      background: #f1f5f9;
      font-weight: 600;
      color: #334155;
      position: sticky;
      top: 0;
      z-index: 1;
    }
    .erp-lookup-table tbody tr {
      cursor: pointer;
      transition: background 0.15s ease;
    }
    .erp-lookup-table tbody tr:hover,
    .erp-lookup-table tbody tr.focused {
      background: #f1f5f9;
    }
    .erp-lookup-footer {
      padding: 1rem 1.5rem;
      border-top: 1px solid #e2e8f0;
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: #f8fafc;
    }
    .erp-lookup-pagination-info {
      font-size: 0.875rem;
      color: #64748b;
    }
    .erp-lookup-pagination-controls {
      display: flex;
      gap: 0.5rem;
    }
    .erp-lookup-btn {
      padding: 0.375rem 0.75rem;
      border: 1px solid #cbd5e1;
      background: #ffffff;
      border-radius: 4px;
      font-size: 0.875rem;
      cursor: pointer;
      color: #334155;
    }
    .erp-lookup-btn:hover:not(:disabled) {
      background: #f1f5f9;
    }
    .erp-lookup-btn:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }
    .erp-lookup-input-wrapper {
      position: relative;
      display: inline-block;
      width: 100%;
    }
    .erp-lookup-display-input {
      width: 100%;
      padding-right: 2rem;
      cursor: pointer;
      background-color: #f8fafc !important;
    }
    .erp-lookup-clear-btn {
      position: absolute;
      right: 0.5rem;
      top: 50%;
      transform: translateY(-50%);
      background: none;
      border: none;
      color: #94a3b8;
      cursor: pointer;
      font-size: 1.25rem;
      line-height: 1;
      display: none;
    }
    .erp-lookup-clear-btn:hover {
      color: #ef4444;
    }
  `;
  document.head.appendChild(style);
}

export class ErpLookupHelper {
  constructor(config) {
    this.inputId = config.inputId;
    this.hiddenInputId = config.hiddenInputId;
    this.tableName = config.tableName;
    this.valueField = config.valueField || 'id';
    this.displayField = config.displayField || 'name';
    this.searchColumns = config.searchColumns || [];
    this.columns = config.columns || [];
    this.pageSize = config.pageSize || 10;
    this.requireActiveCompany = config.requireActiveCompany || false;
    this.staticFilters = config.staticFilters || []; // e.g. [{ col: 'is_active', op: 'eq', val: true }]
    this.title = config.title || `Select ${this.tableName}`;

    this.currentPage = 1;
    this.searchTerm = '';
    this.focusedRowIndex = -1;
    this.records = [];

    injectLookupCSS();
    this._initInputs();
  }

  _initInputs() {
    this.displayInput = document.getElementById(this.inputId);
    this.hiddenInput = document.getElementById(this.hiddenInputId);

    if (!this.displayInput || !this.hiddenInput) {
      return;
    }

    this.displayInput.readOnly = true;
    this.displayInput.classList.add('erp-lookup-display-input');
    
    // Wrap input to add clear button
    const wrapper = document.createElement('div');
    wrapper.className = 'erp-lookup-input-wrapper';
    this.displayInput.parentNode.insertBefore(wrapper, this.displayInput);
    wrapper.appendChild(this.displayInput);

    this.clearBtn = document.createElement('button');
    this.clearBtn.className = 'erp-lookup-clear-btn';
    this.clearBtn.innerHTML = '&times;';
    this.clearBtn.type = 'button';
    wrapper.appendChild(this.clearBtn);

    // Initial check for clear button visibility
    this._toggleClearBtn();

    this.displayInput.addEventListener('click', () => this.openModal());
    this.clearBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      this.clearSelection();
    });

    // Listen to manual programmatic changes on hidden input
    this.hiddenInput.addEventListener('change', () => this._toggleClearBtn());
  }

  _toggleClearBtn() {
    if (this.hiddenInput && this.hiddenInput.value) {
      this.clearBtn.style.display = 'block';
    } else {
      this.clearBtn.style.display = 'none';
    }
  }

  clearSelection() {
    if (this.hiddenInput) {
      this.hiddenInput.value = '';
      this.hiddenInput.dispatchEvent(new Event('change', { bubbles: true }));
    }
    if (this.displayInput) {
      this.displayInput.value = '';
    }
    this._toggleClearBtn();
  }

  openModal() {
    this.currentPage = 1;
    this.searchTerm = '';
    this._buildModal();
    this._loadData();
    
    // Give focus to search after transition
    setTimeout(() => {
      if (this.searchInput) this.searchInput.focus();
    }, 50);
  }

  closeModal() {
    if (this.overlay && this.overlay.parentNode) {
      this.overlay.classList.remove('active');
      setTimeout(() => {
        if (this.overlay.parentNode) {
          this.overlay.parentNode.removeChild(this.overlay);
        }
        this.overlay = null;
      }, 200);
    }
  }

  _buildModal() {
    this.overlay = document.createElement('div');
    this.overlay.className = 'erp-lookup-modal-overlay';
    
    const modal = document.createElement('div');
    modal.className = 'erp-lookup-modal';
    
    // Stop clicks inside modal from closing it
    modal.addEventListener('click', (e) => e.stopPropagation());
    // Close on overlay click
    this.overlay.addEventListener('click', () => this.closeModal());

    // Header
    const header = document.createElement('div');
    header.className = 'erp-lookup-header';
    header.innerHTML = `
      <h2 class="erp-lookup-title">${escapeHTML(this.title)}</h2>
      <button class="erp-lookup-close-btn" type="button">&times;</button>
    `;
    header.querySelector('.erp-lookup-close-btn').addEventListener('click', () => this.closeModal());

    // Body
    const body = document.createElement('div');
    body.className = 'erp-lookup-body';
    
    this.searchInput = document.createElement('input');
    this.searchInput.type = 'text';
    this.searchInput.className = 'erp-lookup-search-input';
    this.searchInput.placeholder = 'Search...';
    
    let debounceTimer;
    this.searchInput.addEventListener('input', () => {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        this.searchTerm = this.searchInput.value.trim();
        this.currentPage = 1;
        this._loadData();
      }, 300);
    });
    
    // Keyboard Navigation
    this.searchInput.addEventListener('keydown', (e) => this._handleKeydown(e));

    const tableContainer = document.createElement('div');
    tableContainer.className = 'erp-lookup-table-container';
    
    this.table = document.createElement('table');
    this.table.className = 'erp-lookup-table';
    
    const thead = document.createElement('thead');
    const theadRow = document.createElement('tr');
    this.columns.forEach(col => {
      const th = document.createElement('th');
      th.textContent = col.label;
      theadRow.appendChild(th);
    });
    thead.appendChild(theadRow);
    this.table.appendChild(thead);
    
    this.tbody = document.createElement('tbody');
    this.table.appendChild(this.tbody);
    
    tableContainer.appendChild(this.table);
    
    body.appendChild(this.searchInput);
    body.appendChild(tableContainer);

    // Footer
    const footer = document.createElement('div');
    footer.className = 'erp-lookup-footer';
    
    this.pageInfo = document.createElement('div');
    this.pageInfo.className = 'erp-lookup-pagination-info';
    this.pageInfo.textContent = 'Loading...';
    
    const controls = document.createElement('div');
    controls.className = 'erp-lookup-pagination-controls';
    
    this.prevBtn = document.createElement('button');
    this.prevBtn.type = 'button';
    this.prevBtn.className = 'erp-lookup-btn';
    this.prevBtn.textContent = 'Previous';
    this.prevBtn.disabled = true;
    this.prevBtn.addEventListener('click', () => {
      if (this.currentPage > 1) {
        this.currentPage--;
        this._loadData();
      }
    });

    this.nextBtn = document.createElement('button');
    this.nextBtn.type = 'button';
    this.nextBtn.className = 'erp-lookup-btn';
    this.nextBtn.textContent = 'Next';
    this.nextBtn.disabled = true;
    this.nextBtn.addEventListener('click', () => {
      this.currentPage++;
      this._loadData();
    });
    
    controls.appendChild(this.prevBtn);
    controls.appendChild(this.nextBtn);
    
    footer.appendChild(this.pageInfo);
    footer.appendChild(controls);

    modal.appendChild(header);
    modal.appendChild(body);
    modal.appendChild(footer);
    this.overlay.appendChild(modal);
    
    document.body.appendChild(this.overlay);
    
    // Trigger CSS transition
    requestAnimationFrame(() => {
      this.overlay.classList.add('active');
    });
  }

  _handleKeydown(e) {
    const rowCount = this.records.length;
    if (rowCount === 0) return;

    if (e.key === 'ArrowDown') {
      e.preventDefault();
      this.focusedRowIndex = (this.focusedRowIndex + 1) % rowCount;
      this._updateRowFocus();
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      this.focusedRowIndex = this.focusedRowIndex <= 0 ? rowCount - 1 : this.focusedRowIndex - 1;
      this._updateRowFocus();
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (this.focusedRowIndex >= 0 && this.focusedRowIndex < rowCount) {
        this.selectRecord(this.records[this.focusedRowIndex]);
      }
    } else if (e.key === 'Escape') {
      e.preventDefault();
      this.closeModal();
    }
  }

  _updateRowFocus() {
    const rows = this.tbody.querySelectorAll('tr');
    rows.forEach((row, idx) => {
      if (idx === this.focusedRowIndex) {
        row.classList.add('focused');
        row.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
      } else {
        row.classList.remove('focused');
      }
    });
  }

  async _loadData() {
    this._renderState('Loading...', 'text-muted');
    this.prevBtn.disabled = true;
    this.nextBtn.disabled = true;
    this.records = [];
    this.focusedRowIndex = -1;

    try {
      let selectFields = this.columns.map(c => c.key);
      if (!selectFields.includes(this.valueField)) selectFields.push(this.valueField);
      if (!selectFields.includes(this.displayField)) selectFields.push(this.displayField);

      let query = supabase
        .from(this.tableName)
        .select(selectFields.join(', '), { count: 'exact' });

      if (this.requireActiveCompany) {
        const activeCompanyId = authManager.getActiveCompanyId();
        if (activeCompanyId) {
          query = query.eq('company_id', activeCompanyId);
        }
      }

      if (this.staticFilters && this.staticFilters.length > 0) {
        this.staticFilters.forEach(f => {
          if (f.op === 'eq') query = query.eq(f.col, f.val);
          // Can add other operators if needed later
        });
      }

      if (this.searchTerm && this.searchColumns.length > 0) {
        const orFilter = this.searchColumns.map(col => `${col}.ilike.%${this.searchTerm}%`).join(',');
        query = query.or(orFilter);
      }

      // Default sort by display field if sortable
      query = query.order(this.displayField, { ascending: true });

      const from = (this.currentPage - 1) * this.pageSize;
      const to = from + this.pageSize - 1;
      query = query.range(from, to);

      const { data, count, error } = await query;
      
      if (error) throw error;

      this.records = data || [];
      
      if (this.records.length === 0) {
        this._renderState('No records found.', 'text-muted');
        this._updatePaginationUI(0);
        return;
      }

      this.tbody.innerHTML = '';
      this.records.forEach((item, index) => {
        const tr = document.createElement('tr');
        
        let rowHtml = '';
        this.columns.forEach(col => {
          let val = item[col.key];
          if (col.renderer) {
            val = col.renderer(val, item);
          } else {
            val = escapeHTML(val);
          }
          rowHtml += `<td>${val}</td>`;
        });
        
        tr.innerHTML = rowHtml;
        tr.addEventListener('click', () => this.selectRecord(item));
        tr.addEventListener('mouseenter', () => {
          this.focusedRowIndex = index;
          this._updateRowFocus();
        });
        
        this.tbody.appendChild(tr);
      });

      this._updatePaginationUI(count);
      
      // Auto-focus first row
      this.focusedRowIndex = 0;
      this._updateRowFocus();

    } catch (err) {
      this._renderState(`Error: ${escapeHTML(err.message)}`, 'text-error');
    }
  }

  _renderState(text) {
    this.tbody.innerHTML = `<tr>
      <td colspan="${this.columns.length}" style="text-align: center; color: #64748b;">
        ${text}
      </td>
    </tr>`;
  }

  _updatePaginationUI(totalCount) {
    const maxPage = Math.ceil(totalCount / this.pageSize) || 1;
    this.pageInfo.textContent = `Page ${this.currentPage} of ${maxPage} (${totalCount} record${totalCount !== 1 ? 's' : ''})`;
    
    this.prevBtn.disabled = this.currentPage <= 1;
    this.nextBtn.disabled = this.currentPage >= maxPage || maxPage === 0;
  }

  selectRecord(item) {
    if (this.hiddenInput) {
      this.hiddenInput.value = item[this.valueField];
      // Dispatch change event so framework (like ErpFormHelper) knows it updated
      this.hiddenInput.dispatchEvent(new Event('change', { bubbles: true }));
    }
    
    if (this.displayInput) {
      // Evaluate if display field contains multiple keys or simple mapping
      // For now, assume it's a single key. Advanced formatting can be handled in future.
      this.displayInput.value = item[this.displayField] || '';
    }
    
    this._toggleClearBtn();
    this.closeModal();
  }
}
