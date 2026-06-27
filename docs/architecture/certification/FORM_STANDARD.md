# Form Standard

## Visual Consistency
Form fields must be grouped logically in identical order across modules.
Spacing, typography, label alignment (left or top), and error styling must match the global CSS tokens.

## Section Grouping (Standard Layout)
1. **General Information** (Code, Name, Active Status)
2. **Registration & Tax** (TIN, Branch Code, Tax Type, RDO)
3. **Address & Contact** (Address, Email, Phone)
4. **Compliance** (Industry, Business Type)
5. **Accounting** (Default AP/AR accounts)
6. **Attachments** (Future)
7. **Notes**
8. **Audit** (Created By, Updated By, etc.)

## Mode Restrictions
- **View Mode:** Only buttons allowed are [Back], [Edit], [Print]. No Save. No Cancel.
- **Edit Mode:** Only buttons allowed are [Save], [Save & New], [Cancel].

## Data Flow
Frontend MUST NEVER own `created_by`, `updated_by`, `approved_by`, `deleted_by`. These fields are strictly injected/overridden by the Backend RPC or Triggers using `auth.uid()`.
