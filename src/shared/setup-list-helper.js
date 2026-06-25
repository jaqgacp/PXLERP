// -----------------------------------------------------------------------------
// PXL ERP - Reusable Setup List Helper
// -----------------------------------------------------------------------------

import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

// Local Development Supabase Configuration
const SUPABASE_URL = 'http://127.0.0.1:54321';
// TODO: Replace with actual local anon key from `supabase start`
const SUPABASE_ANON_KEY = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

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
    const tbody = document.querySelector(this.tableId) || document.querySelector('tbody');
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
