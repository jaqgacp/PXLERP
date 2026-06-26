// -----------------------------------------------------------------------------
// PXL ERP - CSV Parser Utility
// -----------------------------------------------------------------------------

export class CsvParser {
  /**
   * Parses raw CSV text into an array of objects based on the header row.
   * Supports quoted values, commas within quotes, and trims all headers/values.
   */
  static parse(csvText) {
    const rows = [];
    let currentRow = [];
    let currentCell = '';
    let insideQuotes = false;

    // Normalize newlines to \n
    const text = csvText.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

    for (let i = 0; i < text.length; i++) {
      const char = text[i];
      const nextChar = text[i + 1];

      if (char === '"') {
        if (insideQuotes && nextChar === '"') {
          // Escaped quote (e.g. "")
          currentCell += '"';
          i++; // Skip the next quote
        } else {
          // Toggle quote state
          insideQuotes = !insideQuotes;
        }
      } else if (char === ',' && !insideQuotes) {
        currentRow.push(currentCell.trim());
        currentCell = '';
      } else if (char === '\n' && !insideQuotes) {
        currentRow.push(currentCell.trim());
        // Only push row if it contains at least one non-empty value
        if (currentRow.some(cell => cell !== '')) {
          rows.push(currentRow);
        }
        currentRow = [];
        currentCell = '';
      } else {
        currentCell += char;
      }
    }

    // Push the very last cell/row if the file doesn't end with a newline
    if (currentCell !== '' || currentRow.length > 0) {
      currentRow.push(currentCell.trim());
      if (currentRow.some(cell => cell !== '')) {
        rows.push(currentRow);
      }
    }

    if (rows.length === 0) {
      return { headers: [], data: [] };
    }

    const headers = rows[0].map(h => h.trim());
    const data = [];

    for (let i = 1; i < rows.length; i++) {
      const row = rows[i];
      const rowObject = {};
      
      for (let j = 0; j < headers.length; j++) {
        const header = headers[j];
        if (!header) continue;
        
        rowObject[header] = (row[j] !== undefined && row[j] !== null) ? row[j].trim() : '';
      }
      data.push(rowObject);
    }

    return { headers, data };
  }

  /**
   * Standardized boolean parser for the ERP Import Framework.
   * Accepts Yes/No, TRUE/FALSE, Y/N, 1/0.
   */
  static parseBoolean(value) {
    if (value === null || value === undefined || value === '') return null;
    const lower = value.toString().toLowerCase().trim();
    if (['yes', 'true', 'y', '1'].includes(lower)) return true;
    if (['no', 'false', 'n', '0'].includes(lower)) return false;
    return null; // Signals invalid boolean
  }

  /**
   * Standardized date validator. Prefers YYYY-MM-DD.
   * Returns a YYYY-MM-DD string if valid, or 'INVALID_DATE' if invalid.
   */
  static parseDate(value) {
    if (!value) return null;
    const trimmed = value.trim();
    
    // First, test for exact YYYY-MM-DD
    const isoRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (isoRegex.test(trimmed)) {
      const d = new Date(trimmed);
      if (!isNaN(d.getTime())) return trimmed;
    }
    
    // Fallback: try standard Date parsing if it's a valid string format
    const d = new Date(trimmed);
    if (!isNaN(d.getTime())) {
      return d.toISOString().split('T')[0];
    }
    
    return 'INVALID_DATE';
  }
}
