// -----------------------------------------------------------------------------
// PXL ERP - Company List JS
// -----------------------------------------------------------------------------

// Import Supabase client from CDN (Requires configuration)
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

// Local Development Supabase Configuration
const SUPABASE_URL = 'http://127.0.0.1:54321';
// TODO: Replace with actual local anon key from `supabase start`
const SUPABASE_ANON_KEY = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

document.addEventListener('DOMContentLoaded', () => {
  loadCompanies();
});

async function loadCompanies() {
  const tbody = document.querySelector('#company-grid-body') || document.querySelector('tbody');
  if (!tbody) return;

  // 1. Loading State
  tbody.innerHTML = '<tr><td colspan="10" class="text-center text-muted">Loading companies...</td></tr>';

  try {
    // 2. Fetch from public.companies using anon client
    const { data: companies, error } = await supabase
      .from('companies')
      .select('code, name, trade_name, tin, tax_type, business_type, rdo_code, is_active, created_at')
      .order('code', { ascending: true });

    if (error) throw error;

    // 3. Empty State
    if (!companies || companies.length === 0) {
      tbody.innerHTML = '<tr><td colspan="10" class="text-center text-muted">No companies found.</td></tr>';
      updatePaginationInfo(0);
      return;
    }

    // 4. Display Real Rows
    tbody.innerHTML = '';
    companies.forEach(company => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><input type="checkbox"></td>
        <td>${escapeHTML(company.code || '')}</td>
        <td>${escapeHTML(company.name || '')}</td>
        <td>${escapeHTML(company.trade_name || '')}</td>
        <td>${escapeHTML(company.tin || '')}</td>
        <td>${escapeHTML(company.tax_type || '')}</td>
        <td>${escapeHTML(company.business_type || '')}</td>
        <td>${escapeHTML(company.rdo_code || '')}</td>
        <td>${company.is_active ? 'Yes' : 'No'}</td>
        <td>${company.created_at ? new Date(company.created_at).toLocaleDateString() : ''}</td>
        <td>
          <a href="#" onclick="alert('View placeholder'); return false;">View</a> |
          <a href="#" onclick="alert('Edit placeholder'); return false;">Edit</a> |
          <a href="#" onclick="alert('Audit Trail placeholder'); return false;">Audit Trail</a>
        </td>
      `;
      tbody.appendChild(tr);
    });

    updatePaginationInfo(companies.length);

  } catch (err) {
    // 5. Error State
    console.error('Error loading companies:', err);
    tbody.innerHTML = `<tr><td colspan="10" class="text-center text-danger" style="color: red;">Error loading data: ${escapeHTML(err.message)}</td></tr>`;
  }
}

function updatePaginationInfo(count) {
  const pgInfo = document.getElementById('pg-info');
  if (pgInfo) {
    pgInfo.textContent = `${count} record${count !== 1 ? 's' : ''}`;
  }
}

function escapeHTML(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
