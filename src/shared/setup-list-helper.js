// -----------------------------------------------------------------------------
// PXL ERP - Setup List Helper
// -----------------------------------------------------------------------------

import { authManager } from '../auth/auth-manager.js';

export const supabase = authManager.supabase;

export function escapeHTML(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

export class SetupListHelper {
  constructor({ tableId, entityName, colSpan, fetchData, renderRow }) {
    this.tableId = tableId;
    this.entityName = entityName;
    this.colSpan = colSpan;
    this.fetchData = fetchData;
    this.renderRow = renderRow;
  }

  async load() {
    const tbody = document.querySelector(this.tableId);
    if (!tbody) return;

    // 1. Loading State
    tbody.innerHTML = `<tr><td colspan="${this.colSpan}" class="text-center text-muted">Loading ${this.entityName}...</td></tr>`;

    try {
      // 2. Fetch data
      const data = await this.fetchData();

      // 3. Empty State
      if (!data || data.length === 0) {
        tbody.innerHTML = `<tr><td colspan="${this.colSpan}" class="text-center text-muted">No ${this.entityName} found.</td></tr>`;
        this.updatePaginationInfo(0);
        return;
      }

      // 4. Display Real Rows
      tbody.innerHTML = '';
      data.forEach(item => {
        const tr = document.createElement('tr');
        tr.innerHTML = this.renderRow(item);
        tbody.appendChild(tr);
      });

      this.updatePaginationInfo(data.length);

    } catch (err) {
      // 5. Error State
      console.error(`Error loading ${this.entityName}:`, err);
      tbody.innerHTML = `<tr><td colspan="${this.colSpan}" class="text-center text-danger" style="color: red;">Error loading data: ${escapeHTML(err.message)}</td></tr>`;
    }
  }

  updatePaginationInfo(count) {
    const pgInfo = document.getElementById('pg-info');
    if (pgInfo) {
      pgInfo.textContent = `${count} record${count !== 1 ? 's' : ''}`;
    }
  }
}
