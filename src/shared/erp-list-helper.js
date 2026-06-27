// -----------------------------------------------------------------------------
// PXL ERP - Erp List Helper 2.0 (Server-Side)
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';

export const supabase = authManager.supabase;

export function escapeHTML(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

export class ErpListHelper {
  constructor(config) {
    this.tableId = config.tableId || '#grid-body';
    this.tableName = config.tableName;
    this.entityName = config.entityName;
    
    // [{ key: 'code', label: 'Code', sortable: true, searchable: true, renderer: (val, row) => val }]
    this.columns = config.columns || []; 
    this.extraSelectFields = config.extraSelectFields || [];
    this.staticFilters = config.staticFilters || [];
    
    this.requireActiveCompany = config.requireActiveCompany || false;
    this.activeCompanyMessage = config.activeCompanyMessage || 'Please select a company to view these records.';
    this.rowActions = config.rowActions || null; 
    
    this.searchInputId = config.searchInputId || '#currency-search'; // default fallback for compatibility
    if (config.searchInputId) this.searchInputId = config.searchInputId;

    this.prevBtnId = config.prevBtnId || '.pagination button:first-child, .erp-list-pagination-controls button:first-child';
    this.nextBtnId = config.nextBtnId || '.pagination button:last-child, .erp-list-pagination-controls button:last-child';
    this.pageInfoId = config.pageInfoId || '#pg-info';

    this.pageSize = config.pageSize || 10;
    this.currentPage = 1;
    this.searchTerm = '';
    this.sortColumn = config.defaultSortColumn || 'created_at';
    this.sortAscending = config.defaultSortAscending !== undefined ? config.defaultSortAscending : false;

    this.colSpan = this.columns.length + (this.rowActions ? 1 : 0);
    
    this._loadState();
    this._initDOM();
  }

  _initDOM() {
    this.tbody = document.querySelector(this.tableId);
    this.searchInput = document.querySelector(this.searchInputId);
    this.prevBtn = document.querySelector(this.prevBtnId);
    this.nextBtn = document.querySelector(this.nextBtnId);
    this.pageInfo = document.querySelector(this.pageInfoId);

    if (this.searchInput) {
      this.searchInput.value = this.searchTerm;
      this.searchInput.addEventListener('input', this._debounce(() => {
        this.searchTerm = this.searchInput.value.trim();
        this.currentPage = 1;
        this.load();
      }, 300));
    }

    if (this.prevBtn) {
      this.prevBtn.addEventListener('click', () => {
        if (this.currentPage > 1) {
          this.currentPage--;
          this.load();
        }
      });
    }

    if (this.nextBtn) {
      this.nextBtn.addEventListener('click', () => {
        this.currentPage++;
        this.load();
      });
    }

    this._renderHeaders();
  }

  _debounce(func, timeout = 300){
    let timer;
    return (...args) => {
      clearTimeout(timer);
      timer = setTimeout(() => { func.apply(this, args); }, timeout);
    };
  }

  _renderHeaders() {
    const table = this.tbody ? this.tbody.closest('table') : null;
    if (!table) return;
    
    const thead = table.querySelector('thead tr');
    if (!thead) return;

    thead.innerHTML = '';
    
    this.columns.forEach(col => {
      const th = document.createElement('th');
      th.textContent = col.label;
      if (col.sortable) {
        th.classList.add('sortable');
        if (this.sortColumn === col.key) {
          th.textContent += this.sortAscending ? ' [ASC]' : ' [DESC]';
        }
        th.addEventListener('click', () => {
          if (this.sortColumn === col.key) {
            this.sortAscending = !this.sortAscending;
          } else {
            this.sortColumn = col.key;
            this.sortAscending = true;
          }
          this.currentPage = 1;
          this._renderHeaders();
          this.load();
        });
      }
      thead.appendChild(th);
    });

    if (this.rowActions) {
      const th = document.createElement('th');
      th.textContent = 'Actions';
      thead.appendChild(th);
    }
  }

  _saveState() {
    const state = {
      page: this.currentPage,
      search: this.searchTerm,
      sortCol: this.sortColumn,
      sortAsc: this.sortAscending
    };
    sessionStorage.setItem(`erpListState_${this.tableName}`, JSON.stringify(state));
  }

  _loadState() {
    const stateStr = sessionStorage.getItem(`erpListState_${this.tableName}`);
    if (stateStr) {
      try {
        const state = JSON.parse(stateStr);
        this.currentPage = state.page || 1;
        this.searchTerm = state.search || '';
        this.sortColumn = state.sortCol || this.sortColumn;
        this.sortAscending = state.sortAsc !== undefined ? state.sortAsc : this.sortAscending;
      } catch (e) {
        // ignore
      }
    }
  }

  async load() {
    if (!this.tbody) return;

    let activeCompanyId = null;
    if (this.requireActiveCompany) {
      activeCompanyId = authManager.getActiveCompanyId();
      if (!activeCompanyId) {
        this._renderState(this.activeCompanyMessage, 'text-muted');
        this._updatePaginationUI(0);
        return;
      }
    }

    this._saveState();
    this._renderState(`Loading ${this.entityName}...`, 'text-muted');

    try {
      // Prepare select query
      let selectFields = this.columns.map(c => c.key);
      if (!selectFields.includes('id')) {
        selectFields.push('id');
      }
      if (this.extraSelectFields) {
        this.extraSelectFields.forEach(field => {
          if (!selectFields.includes(field)) {
            selectFields.push(field);
          }
        });
      }

      let query = supabase
        .from(this.tableName)
        .select(selectFields.join(', '), { count: 'exact' });

      if (this.requireActiveCompany && activeCompanyId) {
        query = query.eq('company_id', activeCompanyId);
      }

      if (this.staticFilters && this.staticFilters.length > 0) {
        this.staticFilters.forEach(f => {
          if (f.op === 'eq') query = query.eq(f.col, f.val);
        });
      }

      if (this.searchTerm) {
        const searchCols = this.columns.filter(c => c.searchable).map(c => c.key);
        if (searchCols.length > 0) {
          const orFilter = searchCols.map(col => `${col}.ilike.%${this.searchTerm}%`).join(',');
          query = query.or(orFilter);
        }
      }

      if (this.sortColumn) {
        query = query.order(this.sortColumn, { ascending: this.sortAscending });
      }

      const from = (this.currentPage - 1) * this.pageSize;
      const to = from + this.pageSize - 1;
      query = query.range(from, to);

      const { data, count, error } = await query;
      
      if (error) throw error;

      if (!data || data.length === 0) {
        this._renderState(`No ${this.entityName} found.`, 'text-muted');
        this._updatePaginationUI(0);
        return;
      }

      this.tbody.innerHTML = '';
      data.forEach(item => {
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

        if (this.rowActions) {
          rowHtml += `<td>${this.rowActions(item)}</td>`;
        }
        
        tr.innerHTML = rowHtml;
        this.tbody.appendChild(tr);
      });

      this._updatePaginationUI(count);

    } catch (err) {
      // No console.error allowed based on user request: "No console debugging"
      this._renderState(`Error loading data: ${escapeHTML(err.message)}`, 'text-error');
    }
  }

  _renderState(text, cssClass = '') {
    this.tbody.innerHTML = `<tr>
      <td colspan="${this.colSpan}" class="erp-list-state-cell ${cssClass}">
        ${text}
      </td>
    </tr>`;
  }

  _updatePaginationUI(totalCount) {
    if (this.pageInfo) {
      const maxPage = Math.ceil(totalCount / this.pageSize) || 1;
      this.pageInfo.textContent = `Page ${this.currentPage} of ${maxPage} (${totalCount} record${totalCount !== 1 ? 's' : ''})`;
      
      if (this.prevBtn) {
        this.prevBtn.disabled = this.currentPage <= 1;
      }
      if (this.nextBtn) {
        this.nextBtn.disabled = this.currentPage >= maxPage || maxPage === 0;
      }
    }
  }
}
