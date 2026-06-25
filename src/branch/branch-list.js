// -----------------------------------------------------------------------------
// PXL ERP - Branch List JS
// -----------------------------------------------------------------------------

// Import Supabase client from CDN (Requires configuration)
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

// Local Development Supabase Configuration
const SUPABASE_URL = 'http://127.0.0.1:54321';
// TODO: Replace with actual local anon key from `supabase start`
const SUPABASE_ANON_KEY = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH'; // Same as company list

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

document.addEventListener('DOMContentLoaded', () => {
  loadBranches();
});

async function loadBranches() {
  const tbody = document.querySelector('#branch-grid-body') || document.querySelector('tbody');
  if (!tbody) return;

  // 1. Loading State
  tbody.innerHTML = '<tr><td colspan="9" class="text-center text-muted">Loading branches...</td></tr>';

  try {
    // 2. Fetch from public.branches using anon client
    const { data: branches, error } = await supabase
      .from('branches')
      .select('code, name, address, tin_suffix, bir_registered, is_head_office, is_active, created_at')
      .order('code', { ascending: true });

    if (error) throw error;

    // 3. Empty State
    if (!branches || branches.length === 0) {
      tbody.innerHTML = '<tr><td colspan="9" class="text-center text-muted">No branches found.</td></tr>';
      updatePaginationInfo(0);
      return;
    }

    // 4. Display Real Rows
    tbody.innerHTML = '';
    branches.forEach(branch => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${escapeHTML(branch.code || '')}</td>
        <td>${escapeHTML(branch.name || '')}</td>
        <td>${escapeHTML(branch.address || '')}</td>
        <td>${escapeHTML(branch.tin_suffix || '')}</td>
        <td>${branch.bir_registered ? 'Yes' : 'No'}</td>
        <td>${branch.is_head_office ? 'Yes' : 'No'}</td>
        <td>${branch.is_active ? 'Yes' : 'No'}</td>
        <td>${branch.created_at ? new Date(branch.created_at).toLocaleDateString() : ''}</td>
        <td>
          <a href="#" onclick="alert('View placeholder'); return false;">View</a> |
          <a href="#" onclick="alert('Edit placeholder'); return false;">Edit</a> |
          <a href="#" onclick="alert('Audit Trail placeholder'); return false;">Audit Trail</a>
        </td>
      `;
      tbody.appendChild(tr);
    });

    updatePaginationInfo(branches.length);

  } catch (err) {
    // 5. Error State
    console.error('Error loading branches:', err);
    tbody.innerHTML = `<tr><td colspan="9" class="text-center text-danger" style="color: red;">Error loading data: ${escapeHTML(err.message)}</td></tr>`;
  }
}

function updatePaginationInfo(count) {
  const pgInfo = document.getElementById('pg-info'); // Reusing existing ID if it matches list.html
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
