# List Standard

## ErpListHelper Standard
The `ErpListHelper` engine MUST handle the following entirely server-side via Supabase:
- **Pagination:** `.range(from, to)`
- **Search:** `.ilike()` driven off `searchable: true` column flags.
- **Sort:** `.order(col, asc)` toggled via header clicks.
- **State Management:** Session storage using `erpListState_[tableName]` preserving list state upon returning from views.

## Future Framework Features (To be Implemented)
- **Column Chooser:** Users select visible columns (persisted per user/module).
- **Density:** 'Comfortable' vs 'Compact' padding modes.
- **Refresh:** Manual reload integration.
- **Status Bar:** Total records, active filters, last refreshed timestamp.
