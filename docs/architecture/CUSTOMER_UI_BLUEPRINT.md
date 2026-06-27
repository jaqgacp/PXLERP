# Customer UI Blueprint

## 1. UX Philosophy
Enterprise ERP entities contain massive amounts of data. Displaying 50 fields on a single scrolling page overwhelms the user. 
The Customer Master UI must utilize a **Tabbed Interface** inside the `ErpFormHelper`.

## 2. Layout Structure

### Header (Persistent)
- **Customer Code:** [CUST-0001]
- **Customer Name:** [Acme Corporation]
- **Status Badge:** [Active / Inactive]
- **Alert Banner:** [On Credit Hold] (Conditional)

### Tabs
#### Tab 1: General
- Entity Type (Radio: Corporate / Individual)
- Registered Name
- Trade Name (DBA)
- Customer Group (Lookup)
- Industry (Lookup)

#### Tab 2: Tax & Compliance
- TIN (Format: 000-000-000)
- TIN Suffix (Format: 00000)
- Tax Type (Select: VAT, Non-VAT, Zero-Rated, Exempt)
- Classification (Select: Regular, PEZA, BOI, Government)
- Default Tax Code (Lookup)

#### Tab 3: Financial & Accounting
- Default Currency (Lookup)
- Payment Terms (Lookup)
- Default AR Account (Lookup - COA)
- Default Sales Account (Lookup - COA)

#### Tab 4: Credit & Sales
- Salesperson (Lookup - Employee)
- Credit Limit (Numeric)
- Credit Hold (Checkbox)

#### Tab 5: Addresses (Sub-Grid)
- An inline `ErpListHelper` table showing addresses.
- "Add Address" button opening a modal.
- Columns: Type, Address, City, Default.

#### Tab 6: Contacts (Sub-Grid)
- An inline `ErpListHelper` table showing contacts.
- "Add Contact" button opening a modal.
- Columns: Name, Title, Email, Phone, Primary.

## 3. Workflow Considerations
- **Creation Flow:** When the user clicks "New", only Tab 1 and Tab 2 are exposed or required. The user saves the core record first.
- **Edit Flow:** Upon saving, the URL updates to Edit Mode. Tabs 5 and 6 (Addresses/Contacts) become active, allowing sub-records to be inserted with the newly generated `customer_id`.
- **View Flow:** All inputs disabled. Lookups hide their search icons. Sub-grids disable their "Add" buttons.
