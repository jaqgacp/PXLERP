# ErpLookupHelper Framework

## 1. Purpose
The `ErpLookupHelper` is a reusable UI and backend-integration component designed to facilitate scalable foreign key selection across PXL ERP. It replaces traditional HTML `<select>` elements, which are unsuitable for Master Data lists containing thousands of rows.

## 2. Why Selects Are Not Enough
Standard `<select>` fields:
1. Cannot lazy-load or paginate data securely.
2. Cause massive N+1 or payload size issues when loading 50,000 Chart of Account entries.
3. Lack robust search capabilities (typeahead is browser-dependent).
4. Cannot easily enforce `active_company` scoping seamlessly.

## 3. Lookup API
To initialize a lookup field on a form, developers simply provide the display input ID and the hidden input ID. The helper takes care of injecting the required modal DOM and CSS globally.

```javascript
const currencyLookup = new ErpLookupHelper({
  inputId: 'currency_display',       // The visible, clickable readonly input
  hiddenInputId: 'currency_id',      // The hidden input that stores the UUID
  tableName: 'currencies',
  valueField: 'id',
  displayField: 'code',
  searchColumns: ['code', 'name'],
  columns: [
    { key: 'code', label: 'Code' },
    { key: 'name', label: 'Name' }
  ],
  pageSize: 10,
  requireActiveCompany: false,       // Automatically filters by user's active company context
  staticFilters: [                   // Always appended to the query
    { col: 'is_active', op: 'eq', val: true }
  ]
});
```

## 4. Active Company Scoping
If `requireActiveCompany: true` is set, the helper automatically intercepts the query and appends `.eq('company_id', authManager.getActiveCompanyId())`. This guarantees users cannot select Master Data belonging to a tenant they are not actively operating in.

## 5. Security Considerations
- **XSS Safety:** The helper maps database results explicitly using `escapeHTML()` on all custom table rendering. User input in the search bar is passed securely to PostgREST via `.ilike()`, preventing SQL injection.
- **Form Data Validation:** The helper emits a standard `change` event on the hidden input, ensuring it is picked up by `ErpFormHelper` serialization securely. 

## 6. Performance Considerations
- **Debouncing:** Keyboard search input is debounced to 300ms to prevent database thrashing on rapid typing.
- **Server-Side Pagination:** `.range(from, to)` ensures that the browser never holds more than `pageSize` records in memory at once.
- **CSS Injection:** The modal CSS is injected only once into the `<head>` globally, avoiding style bloat or duplication across modules.

## 7. Future Use Cases & Examples

### Branch Lookup
```javascript
new ErpLookupHelper({
  inputId: 'branch_display',
  hiddenInputId: 'branch_id',
  tableName: 'branches',
  valueField: 'id',
  displayField: 'name',
  searchColumns: ['code', 'name'],
  columns: [
    { key: 'code', label: 'Code' },
    { key: 'name', label: 'Name' },
    { key: 'tin_suffix', label: 'TIN Suffix' }
  ],
  requireActiveCompany: true
});
```

### Chart of Accounts Lookup
```javascript
new ErpLookupHelper({
  inputId: 'account_display',
  hiddenInputId: 'account_id',
  tableName: 'accounts',
  valueField: 'id',
  displayField: 'account_number',
  searchColumns: ['account_number', 'account_name'],
  columns: [
    { key: 'account_number', label: 'Account No.' },
    { key: 'account_name', label: 'Account Name' }
  ],
  requireActiveCompany: true
});
```
