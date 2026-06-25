import { supabase, SetupListHelper, escapeHTML } from '../shared/setup-list-helper.js';
import { authManager } from '../auth/auth-manager.js';

document.addEventListener('DOMContentLoaded', async () => {
  let companyId;
  try {
    companyId = authManager.requireActiveCompany();
  } catch(err) {
    return;
  }

  const helper = new SetupListHelper({
    tableId: '#fiscal-calendar-grid-body',
    entityName: 'fiscal_periods',
    colSpan: 8,
    fetchData: async () => {
      let query = supabase
        .from('fiscal_periods')
        .select(`
          id, period_number, period_name, date_from, date_to, quarter, status,
          fiscal_years(year_code)
        `)
        .eq('company_id', companyId)
        .order('date_from', { ascending: false });

      const filterId = document.getElementById('fiscal-year-filter').value;
      if (filterId) {
        query = query.eq('fiscal_year_id', filterId);
      }

      const { data, error } = await query;
      if (error) throw error;
      return data;
    },
    renderRow: (fp) => `
      <td>${escapeHTML(fp.fiscal_years?.year_code || '')}</td>
      <td>${escapeHTML(fp.period_number?.toString() || '')}</td>
      <td>${escapeHTML(fp.period_name || '')}</td>
      <td>${escapeHTML(fp.date_from || '')}</td>
      <td>${escapeHTML(fp.date_to || '')}</td>
      <td>Q${escapeHTML(fp.quarter?.toString() || '')}</td>
      <td>${escapeHTML(fp.status || '')}</td>
      <td>
        <a href="#/setup/fiscal-calendar/view?id=${fp.id}">View</a> |
        <a href="#/setup/fiscal-calendar/edit?id=${fp.id}">Edit</a>
      </td>
    `
  });

  // Load filter dropdown
  const filterSelect = document.getElementById('fiscal-year-filter');
  const { data: fyData } = await supabase
    .from('fiscal_years')
    .select('id, year_code')
    .eq('company_id', companyId)
    .order('year_code', { ascending: false });

  if (fyData) {
    fyData.forEach(fy => {
      const opt = document.createElement('option');
      opt.value = fy.id;
      opt.textContent = fy.year_code;
      filterSelect.appendChild(opt);
    });
  }

  filterSelect.addEventListener('change', () => helper.load());

  await helper.load();
});
