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

## 3. Required Columns vs Optional Columns
The configuration for each module will explicitly separate:
- **Required Columns**: Checked during the initial parsing phase. If a required column is empty or missing, the row immediately fails validation.
- **Optional Columns**: Processed if provided. The parser will inject `null` or a predefined default value when these columns are omitted.

## 4. Row Validation Strategy
Row validation occurs **client-side** before any database calls are made, and is presented in a preview modal:
1. **Type Checking**: Ensures dates, booleans, and numbers are correctly formatted.
2. **Business Rules**: Module-specific logic (e.g., verifying `tin_suffix` follows a specific numeric pattern).
3. **Database Constraints (Pre-check)**: Ensuring string lengths do not exceed database limits.
4. **Relational Checks**: (Future/Advanced) Validating if a foreign key (like `department_id`) actually exists.

## 5. Duplicate Handling
Duplicate handling prevents dirty data:
- **Duplicate Check Fields**: Config specifies fields (like `code` or `short_name`) that must be unique.
- **Intra-file Duplication**: The parser checks if there are duplicate values within the CSV itself.
- **Database Duplication**: Before inserting, the helper performs a pre-flight query against the database (scoped to the active company) to identify if records with matching unique fields already exist. Duplicate rows are flagged as errors and excluded or require user remediation.

## 6. Error Reporting Format
Rows that fail validation are strictly isolated. The preview screen categorizes rows into:
- **Valid Rows**: Ready for import.
- **Invalid Rows**: Cannot be imported.
Errors are mapped to the exact row index and column, for instance: `Row 4, Column 'code': Must be alphanumeric.`

## 7. Preview Screen Behavior
A shared import modal/screen acts as the gatekeeper:
1. **Upload Phase**: User selects the CSV.
2. **Analysis Phase**: Parses the file and runs validations.
3. **Preview Phase**: Displays a paginated or scrollable table of the data, highlighting valid vs. invalid rows.
4. **Confirmation**: The user must explicitly click "Confirm Import" which only inserts the valid rows, or they must fix the CSV and re-upload.

## 8. Rollback Strategy
Since PostgREST via Supabase JS does not natively support long-running client-side transactions with rollback capabilities, we will rely on:
- **Batch Inserts**: `.insert([...validRows])` acts as a single atomic operation in Supabase. If one row fails at the database level, the entire batch fails and rolls back automatically.
- **Idempotency**: Because we perform extensive pre-flight duplication checks, the batch is highly likely to succeed.

## 9. Audit Trail Expectations
All imported records will follow standard entity audit rules:
- `created_at` and `updated_at` timestamps are handled automatically.
- `created_by` and `updated_by` are appended via the authenticated user's ID at runtime.
- Bulk imports could optionally log an entry in a system-wide `import_logs` table for tracking large data movements.

## 10. Security/RLS Expectations
- **Row Level Security (RLS)**: The standard Supabase RLS policies remain in effect. Bulk inserts are executed under the authenticated user's context. 
- **Spoofing Prevention**: The `company_id` and `created_by` are strictly injected by the `ErpImportHelper` on the frontend before submitting to the Supabase client. The CSV must not provide these.

## 11. Active Company Context
If a module requires an active company context (e.g., Branch, Department):
- The `ErpImportHelper` will read `authManager.getActiveCompanyId()`.
- If missing, the import UI blocks completely.
- When transforming valid rows for insertion, `company_id` is automatically appended to each row's payload.

## 12. Module-Specific Import Configs
Each module defines an import config object, passed to the framework:
```javascript
{
  entityName: 'Branch',
  tableName: 'branches',
  activeCompanyRequired: true,
  requiredColumns: ['code', 'name'],
  optionalColumns: ['short_name', 'address', 'tin_suffix', 'bir_registered', 'is_head_office', 'is_active'],
  duplicateCheckFields: ['code'],
  columnMapping: {
    'Branch Code': 'code',
    'Branch Name': 'name',
    'Address': 'address'
  },
  validators: {
    'code': (val) => /^[A-Z0-9]+$/.test(val) || 'Code must be alphanumeric uppercase'
  },
  transformRow: (row) => {
    row.is_active = row.is_active === 'Yes';
    return row;
  }
}
```
