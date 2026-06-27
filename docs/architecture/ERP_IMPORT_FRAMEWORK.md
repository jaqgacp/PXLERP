# PXL ERP - Master Data Import Framework Architecture

## 1. Import Architecture Overview
The ERP Import Framework provides a unified, reusable, and robust strategy for bulk-inserting records via CSV for all Master Data modules. Instead of disparate implementations, a single `ErpImportHelper` will handle the parsing, validation, duplicate checking, and database transactions for CSV uploads. 

Each module will instantiate the framework by defining a **module-specific import configuration**, passing its schema rules, required columns, and active company context requirements. 

## 2. CSV Template Standard
All templates must adhere to strict structural constraints:
- **Encoding**: UTF-8 without BOM.
- **Header Row**: The first row must strictly contain the column names as defined in the module's `columnMapping`.
- **Delimiters**: Standard comma `,` delimiter. Double quotes `"` to encapsulate fields containing commas.
- **Standard Columns**: If the entity is company-scoped, `company_id` is automatically injected at runtime; the user must not include it in the template to prevent unauthorized data spoofing.

Each import-enabled module must support a **Download CSV Template** capability to provide users with a pre-formatted structure.

## 3. Import Workflow
The import process explicitly prevents blind data ingestion. The flow must be:
- **Step 1**: Download template (user gets a blank CSV with headers).
- **Step 2**: User fills CSV.
- **Step 3**: Upload CSV.
- **Step 4**: Parse CSV.
- **Step 5**: Preview rows (shows all parsed data in a UI table).
- **Step 6**: Validate rows.
- **Step 7**: Show row-level errors in the preview.
- **Step 8**: User confirms import.
- **Step 9**: Insert valid rows.
- **Step 10**: Show success/failure summary.

## 4. Row Validation Strategy
Row validation occurs **client-side** before any database calls are made, and is presented in a preview modal:
1. **Type Checking**: Ensures data conforms to the required types.
2. **Boolean Parsing**: Acceptable truthy values: `Yes`, `TRUE`, `Y`, `1`. Acceptable falsy values: `No`, `FALSE`, `N`, `0` (case-insensitive).
3. **Date Parsing**: Prefer `YYYY-MM-DD`. If invalid or unparseable, mark the row invalid.
4. **Business Rules**: Module-specific logic (e.g., verifying `tin_suffix` follows a 5-digit numeric pattern like `00000`).
5. **Database Constraints (Pre-check)**: Ensuring string lengths do not exceed database limits.

## 5. Duplicate Handling
Duplicate handling prevents dirty data:
- **Duplicate Check Fields**: Config specifies fields (like `code` or `short_name`) that must be unique. If the module is scoped by company, the duplicate check must evaluate `company_id + unique_field` (e.g. `company_id + code`).
- **Intra-file Duplication**: The parser checks if there are duplicate values within the CSV itself.
- **Database Duplication**: Before inserting, the helper performs a pre-flight query against the database (scoped to the active company) to identify if records with matching unique fields already exist. Duplicate rows are flagged as errors and excluded or require user remediation.

## 6. Error Reporting Format
Rows that fail validation are strictly isolated. The preview screen categorizes rows into:
- **Valid Rows**: Ready for import.
- **Invalid Rows**: Cannot be imported.
Errors are mapped to the exact row index and column, for instance: `Row 4, Column 'Branch Code': Must be alphanumeric.`

## 7. Preview Screen Behavior
A shared import modal/screen acts as the gatekeeper:
1. Displays a paginated or scrollable table of the data.
2. Highlights valid vs. invalid rows.
3. Provides a final "Confirm Import" button that only inserts the valid rows.

## 8. Import Batch Lifecycle
Every import becomes a tracked business event via an `import_batches` table.
1. Download Template -> Fill CSV -> Upload -> Parse -> Normalize -> Validate -> Preview.
2. User clicks Confirm.
3. **Create Batch**: The framework generates an `import_batches` record (Status: `pending`), capturing metadata like `original_filename` and `total_rows`.
4. **Insert Data**: The payload is augmented with `import_batch_id` and inserted into the target table.
5. **Update Batch**: If successful, status changes to `completed` with duration metrics. If failed, status changes to `failed` with an `error_summary`.

## 9. Rollback Strategy
The framework supports safe rollbacks mapped via a secure internal registry (`entity_name` -> `table_name` -> `rollback_strategy`), never trusting client-provided table names.
- **Production Mode (Soft Delete)**: The preferred strategy. Executes an `UPDATE target_table SET deleted_at = now(), deleted_by = current_user WHERE import_batch_id = ? AND deleted_at IS NULL`.
- **Development Mode (Hard Delete)**: Executes `DELETE FROM target_table WHERE import_batch_id = ?`. This requires explicit config override and UI confirmation.
- **Audit Preservation**: Rollbacks update the batch status to `rolled_back` and track `rollback_at`, `rollback_by`, and `rollback_reason`. The `import_batches` ledger is never deleted.

## 10. Audit Trail Expectations
All imported records will follow standard entity audit rules:
- `import_batches` serves as an immutable ledger documenting *who* imported *what*, *when*, and the outcome (valid/invalid counts, errors).
- This ledger enables future AI analysis of data ingestion velocity and error rates.
- Row-Level Security ensures users can only view batches for companies they have access to. Global imports require Admin/Super Admin privileges.

## 11. Security/RLS Expectations
- **Row Level Security (RLS)**: Standard Supabase RLS policies govern inserts. `import_batches` enforces strict viewing rights based on `company_id`.
- **Spoofing Prevention**: The `company_id`, `created_by`, and `import_batch_id` are strictly injected by the `ErpImportHelper` on the frontend before submitting to the Supabase client. The CSV must not provide these.

## 12. Active Company Context
If a module requires an active company context (e.g., Branch):
- The `ErpImportHelper` will read `authManager.getActiveCompanyId()`.
- If missing, the import UI blocks completely.
- When transforming valid rows for insertion, `company_id` is automatically appended to each row's payload.

## 13. Module-Specific Import Configs
Each module defines an import config object, passed to the framework. Modules must contain ZERO custom import logic beyond defining this schema:
```javascript
{
  entityName: 'Branch',
  tableName: 'branches',
  activeCompanyRequired: true,
  requiredColumns: ['code', 'name'],
  optionalColumns: ['short_name', 'tin_suffix', 'address'], // ... plus others
  duplicateCheckFields: ['company_id', 'code'], // ensures composite unique constraint is respected
  columnMapping: {
    'Branch Code': 'code',
    'Branch Name': 'name',
    'Address': 'address'
  },
  validators: {
    'code': (val) => /^[A-Z0-9]+$/.test(val) || 'Code must be alphanumeric uppercase'
  }
}
```
