# PH Tax Architecture Gap Report

Repository: PXLERP
Branch reviewed: main
Review type: Pre-Migration 018 PH tax validation
Mode: Documentation audit only. No SQL, migration, UI, backend, or CRUD changes.

## Executive Summary

PXL ERP already has a strong Philippine tax foundation. The current architecture and migrations cover the major Phase 1 tax families: company compliance profile, VAT, percentage tax, EWT, FWT, 2307 issued and received, 2306 issued, QAP, SAWT, SLSP, RELIEF, income tax computation, MCIT calculation, NOLCO, tax credits, tax calendar, filing records, RLS policy coverage, and planned CAS/export/document evidence tables in Migration 018.

However, the current foundation is not fully ready for detailed PH tax freeze as written. The main gaps are not broad missing tax modules. They are specific database-backed gaps that would affect tax accuracy, legal traceability, or implementation consistency:

1. MCIT is in scope, but MCIT carry-forward balance tracking is not actually database-backed.
2. Filing payment/remittance evidence is not normalized across tax returns.
3. VAT carryover, deferred/disallowed input VAT, and input VAT reporting categories are only partially represented.
4. Tax filing amendment history is represented only by status/audit concepts, not a tax filing amendment relationship.
5. ITR form-code support is too narrow unless 1701A, 1702-EX, and 1702-MX are explicitly out of Phase 1 scope.
6. `tax_calendar.period_covered` remains free text and is already documented as an open risk.
7. Some tax documentation still contains contradictions or outdated statements that could mislead implementers.

From a PH tax perspective, Migration 018 should proceed only after its scope is updated or the owner explicitly records exclusions for the items above.

## External PH Tax Baseline Used

This audit used the repository as the primary source and checked current BIR references only to avoid freezing outdated tax assumptions:

- [BIR RMC No. 52-2023](https://bir-cdn.bir.gov.ph/local/pdf/RMC%20No.%2052-2023.pdf) clarifies optional monthly VAT filing using 2550M and quarterly 2550Q filing requirements.
- [BIR Form 2550Q April 2024](https://bir-cdn.bir.gov.ph/BIR/pdf/2550Q%20%20April%202024%20ENCS_Final.pdf) is the current quarterly VAT return reference.
- [BIR Form 2551Q](https://bir-cdn.bir.gov.ph/local/pdf/2551Q%20Jan%202018%20ENCS%20final%20rev%203_copy.pdf) is the quarterly percentage tax return reference.
- [BIR Form 1601EQ guidelines](https://efps.bir.gov.ph/efps-war/EFPSWeb_war/forms2018Version/1601EQ/1601eq_guidelines.html) and [BIR Form 1601FQ](https://bir-cdn.bir.gov.ph/local/pdf/1601-FQ%202020%20final.pdf) confirm quarterly EWT/FWT remittance families.
- [BIR Form 2307](https://bir-cdn.bir.gov.ph/local/pdf/2307%20Jan%202018%20ENCS%20v3.pdf) and [BIR Form 2306](https://bir-cdn.bir.gov.ph/local/pdf/2306%20Jan%202018%20ENCS%20v4.pdf) confirm separate creditable and final withholding certificate treatment.
- [BIR Form 1702Q](https://bir-cdn.bir.gov.ph/local/pdf/1702Q%202018ENCS%20final2.pdf) includes MCIT and prior-year excess MCIT credit concepts.

## Current Readiness Score

Overall PH tax architecture readiness: 78 / 100

| Area | Score | Assessment |
| --- | ---: | --- |
| Company tax profile | 90 | Strong. Core profile fields exist and are effective-dated. |
| Transaction tax classification | 84 | Good line-level VAT/EWT support, with immutable entry generation expected at posting. |
| VAT | 74 | Core VAT exists, but carryover/deferred/disallowed input VAT needs stronger database backing. |
| Percentage tax | 86 | Good Phase 1 coverage for non-VAT PT entries, summaries, and 2551Q filing. |
| Withholding tax | 86 | Strong EWT/FWT/2307/2306/QAP/SAWT coverage with known ATC validation caveat. |
| Income tax | 70 | Good computation foundation, but MCIT carry-forward and ITR form variants are incomplete. |
| Tax calendar and filing | 68 | Filing records exist, but payment/remittance proof and structured periods need hardening. |
| Audit / CAS | 82 | Strong after Migration 018 creates audit, void, DAT, attachment, export, and generated document tables. |
| Supabase / RLS | 80 | Good direction; Migration 018D must finish filed-row and service-owned-field protection. |

## What Is Already Supported

### Company Tax Profile

Supported through `company_compliance_profiles`, `companies`, and `cas_registrations`:

- Legal type.
- Taxpayer type: VAT / non-VAT.
- Income tax regime.
- Deduction method: itemized, OSD, eight percent.
- Withholding agent status.
- RDO code.
- BIR registration date.
- Filing obligations.
- Effective dating.
- CAS registration details.

Important implementation rule: tax engines must read `company_compliance_profiles` as the compliance source of truth. Legacy columns on `companies` such as `tax_type` and `business_type` are retained but documented as deprecated in favor of the compliance profile.

### Transaction Tax Classification

Supported across sales, cash sales, purchases, cash purchases, petty cash, master data, and immutable compliance entries:

- VATable, zero-rated, exempt, and government VAT handling.
- Input/output VAT direction.
- Tax inclusive and tax exclusive document flags.
- EWT ATC and amount capture on purchase/cash purchase/petty cash lines.
- Customer and supplier tax profile snapshots.
- Party TIN, name, and address snapshots in compliance entries.
- Posting-engine ownership of final tax entries.

### VAT

Supported tables:

- `vat_entries`
- `vat_period_summaries`
- `vat_return_filings`
- `slsp_exports`
- `relief_exports`
- VAT code setup through `vat_codes`
- VAT control accounts through `chart_of_accounts.vat_account_type`
- VAT line classifications on sales and purchasing lines

Supported outputs:

- Output VAT.
- Input VAT.
- VATable sales.
- Zero-rated sales.
- Exempt sales.
- Government sales.
- SLSP sales and purchases.
- RELIEF export tracking.
- 2550M / 2550Q filing records.

### Percentage Tax

Supported tables:

- `percentage_tax_codes`
- `percentage_tax_entries`
- `percentage_tax_period_summaries`
- `percentage_tax_return_filings`

Supported outputs:

- Non-VAT percentage tax entries.
- Gross receipts base.
- Percentage tax due.
- 2551Q filing record.
- Export-job linkage planned in Migration 018.

### Withholding Tax

Supported tables:

- `atc_codes`
- `ewt_codes`
- `fwt_codes`
- `ewt_entries`
- `ewt_period_summaries`
- `ewt_remittances_1601eq`
- `fwt_entries`
- `fwt_remittances_1601fq`
- `certificates_2307_issued`
- `certificates_2307_received`
- `certificates_2306_issued`
- `qap_exports`
- `sawt_exports`

Supported outputs:

- EWT.
- FWT.
- 2307 issued.
- 2307 received.
- 2306 issued.
- 1601EQ.
- 1601FQ.
- QAP.
- SAWT.
- Payee TIN/name/address snapshots.

### Income Tax

Supported tables:

- `income_tax_return_filings`
- `itr_computation_runs`
- `income_tax_computation_lines`
- `book_tax_reconciliations`
- `tax_credits_schedules`
- `nolco_tracking`
- Income tax mapping fields on `chart_of_accounts`

Supported concepts:

- Corporate ITR.
- Individual ITR.
- Quarterly and annual filing records.
- Itemized deduction.
- OSD.
- Eight percent method for individual non-VAT taxpayers.
- Non-deductible and partially deductible expense tagging.
- Book-to-tax reconciliation.
- NOLCO tracking.
- Creditable withholding tax through received 2307.
- MCIT calculation amount in computation runs.

### Tax Calendar / Filing

Supported tables:

- `bir_form_configurations`
- `tax_calendar`
- Filing tables for VAT, EWT, FWT, percentage tax, and income tax.

Supported concepts:

- Filing obligations.
- Due date and extended due date.
- Filing status.
- Filed date / filed timestamp.
- BIR confirmation number.
- Export job linkage planned in Migration 018.

### Audit / CAS

Supported or planned:

- `cas_registrations`
- `number_series`
- `number_series_atp`
- `atp_usage_logs`
- `document_controls`
- Migration 018 planned `audit_logs`
- Migration 018 planned `field_change_history`
- Migration 018 planned `document_void_register`
- Migration 018 planned `dat_generation_logs`
- Migration 018 planned `export_history`
- Migration 018 planned `attachments`
- Migration 018 planned `generated_documents`
- Migration 018 planned `generated_report_files`

### Supabase Readiness

Supported or planned:

- RLS helper functions in 017A.
- Tax setup and compliance policies in 017G.
- SELECT-only pattern for service-owned compliance ledger tables.
- Compliance filing permissions such as `compliance.2307.generate`, `compliance.1601eq.file`, `compliance.1601fq.file`, `compliance.2551q.file`, and `compliance.itr.file`.
- Migration 018D planned filed-status guards.
- Migration 018D planned service-owned mutable field protection.
- Migration 018E planned verification.

## What Is Partially Supported

### VAT Carryover And Deferred/Disallowed Input VAT

The design partially supports VAT categories through:

- Purchase line `vat_classification` values such as `capital_goods` and `services`.
- COA `vat_account_type` values such as `input_vat_deferred` and `input_vat_capital_goods`.
- `vat_period_summaries.total_capital_goods_vat` and `total_services_vat`.

The gap is that `vat_entries` does not preserve a separate input VAT reporting category for capital goods, services, deferred input VAT, disallowed input VAT, or carryover. `vat_entries.vat_classification` only allows `vatable`, `zero_rated`, `exempt`, and `government`.

Impact: VAT summaries can be computed from source lines, but the immutable VAT ledger does not fully preserve the input VAT reporting basis. That weakens VAT reconciliation and 2550Q auditability.

### 2550M / 2550Q Handling

The schema allows both `2550M` and `2550Q`, but current BIR guidance makes 2550M optional while 2550Q remains the core quarterly VAT return. The architecture should not treat monthly VAT filing as mandatory by default.

Impact: not a table blocker, but setup defaults and validation must reflect optional 2550M behavior.

### Income Tax Form Variants

The current ITR form code support is limited to:

- `1701Q`
- `1701`
- `1702Q`
- `1702RT`

This is enough for regular individual and regular corporate flows only if Phase 1 explicitly excludes other annual ITR variants. It does not explicitly support:

- `1701A`
- `1702EX`
- `1702MX`

Impact: if exempt corporations, mixed/special-rate corporations, or simplified individual filing variants are in Phase 1, the current form-code model is incomplete.

### Tax Calendar Structure

`tax_calendar.period_covered` is free text. The backlog already documents this as an open risk.

Impact: application validation can reduce risk, but filing lookup and due-date generation are safer with structured period fields.

### Filing Amendment History

Filing tables have `filing_status` values including `draft`, `filed`, and `amended`. Migration 018 will add audit and generated document history, but there is no tax-specific amendment relationship such as original filing, amendment sequence, amended filing, amendment reason, and proof attachment.

Impact: generic audit logs may show changes, but they do not provide a clean filing amendment chain for BIR review.

## What Is Missing

### 1. MCIT Carry-Forward Tracking

Severity: HIGH

Existing support:

- `income_tax_return_filings.mcit_amount`
- `itr_computation_runs.mcit_amount`
- COA `is_mcit_gross_income`

Missing support:

- No table tracks excess MCIT over regular corporate income tax by source year.
- No balance table tracks original MCIT excess, used amount, remaining amount, expiry, and application to later years.
- `tax_credits_schedules` does not include an MCIT carry-forward credit type.

Impact:

Corporate ITR support can compute current MCIT but cannot reliably carry forward and apply excess MCIT credits. That can make corporate income tax payable wrong.

Required fix:

Add a database-backed MCIT carry-forward structure or explicitly exclude MCIT carry-forward from Phase 1 despite MCIT being otherwise in scope.

Recommended table:

- `mcit_credit_tracking`

Recommended minimum fields:

- `company_id`
- `source_fiscal_year_id`
- `regular_income_tax_amount`
- `mcit_amount`
- `excess_mcit_amount`
- `applied_year_1_amount`
- `applied_year_2_amount`
- `applied_year_3_amount`
- `remaining_balance`
- `expiry_fiscal_year_id` or derived expiry basis
- `is_expired`
- standard audit columns

### 2. Tax Filing Payment / Remittance Evidence

Severity: HIGH

Existing support:

- Filing tables store filing status, filing date/timestamp, confirmation number, and some amount totals.
- `export_jobs`, `generated_report_files`, `attachments`, and `generated_documents` are planned in Migration 018.

Missing support:

- No normalized payment/remittance table exists for VAT, EWT, FWT, percentage tax, or income tax filings.
- No consistent place stores payment method, bank/agency, payment reference, paid amount, paid date, proof attachment, and allocation to a filing.

Impact:

The system can record that a return was filed, but cannot consistently prove and reconcile tax payment/remittance. This breaks the requested tax calendar/filing requirement for payment/remittance tracking and proof of filing/payment attachments.

Required fix:

Add one generic tax filing payment table, or add consistent payment fields and attachment linkage to every filing/remittance table. The generic table is cleaner and lower maintenance.

Recommended table:

- `tax_filing_payments`

Recommended minimum fields:

- `company_id`
- `form_code`
- `filing_table`
- `filing_id`
- `fiscal_year_id`
- `fiscal_period_id`
- `quarter`
- `payment_date`
- `paid_amount`
- `payment_method`
- `bank_or_agency`
- `reference_no`
- `confirmation_no`
- `attachment_id`
- `journal_entry_id` or `payment_voucher_id` if paid through accounting
- standard audit columns

### 3. VAT Ledger Reporting Category

Severity: MEDIUM-HIGH

Existing support:

- Source purchase lines capture `capital_goods` and `services`.
- COA can identify input VAT deferred and input VAT capital goods.
- `vat_period_summaries` has capital goods and services summary fields.

Missing support:

- `vat_entries` does not snapshot the source input VAT reporting category.
- No field distinguishes ordinary input VAT, capital goods input VAT, services input VAT, deferred input VAT, disallowed input VAT, or carryover basis on the immutable VAT entry.

Impact:

VAT reconciliation depends on joins back to source transaction lines and application rules instead of the immutable VAT ledger. If the source line changes or the relationship is ambiguous, VAT reports can drift.

Required fix:

Add VAT ledger fields that preserve input VAT reporting category at posting time.

Recommended columns:

- `vat_entries.input_vat_category` nullable, with values such as `ordinary_goods`, `capital_goods`, `services`, `deferred`, `disallowed`
- `vat_entries.is_creditable_input_vat`
- `vat_entries.creditable_period_id` nullable, if deferred crediting is used
- `vat_period_summaries.input_vat_carryover`
- `vat_period_summaries.deferred_input_vat`
- `vat_period_summaries.disallowed_input_vat`
- `vat_period_summaries.creditable_input_vat`

If Phase 1 intentionally handles deferred/disallowed input VAT manually, record that exclusion explicitly.

### 4. Tax Filing Amendment Chain

Severity: MEDIUM

Existing support:

- Filing status includes `amended`.
- Migration 018 plans audit logs, field history, attachments, generated document versions, and export history.

Missing support:

- No tax-specific amendment chain links an amended filing to the original filed return.
- No amendment sequence, reason, amendment date, or proof attachment pattern is defined.

Impact:

Audit logs can show edits but do not create a clean BIR-facing amendment history.

Recommended table:

- `tax_filing_amendments`

Recommended minimum fields:

- `company_id`
- `form_code`
- `original_filing_table`
- `original_filing_id`
- `amended_filing_table`
- `amended_filing_id`
- `amendment_sequence`
- `amendment_reason`
- `amended_at`
- `amended_by`
- `attachment_id`
- `generated_document_id`

### 5. ITR Form Variant Scope

Severity: MEDIUM

Existing support:

- `1701Q`
- `1701`
- `1702Q`
- `1702RT`

Missing or not explicit:

- `1701A`
- `1702EX`
- `1702MX`
- Clear rules for individual mixed-income filer support.
- Clear owner decision that exempt/special/mixed corporate ITR variants are outside Phase 1.

Impact:

If PXL allows onboarding companies requiring these forms, the system may generate or classify ITR filings incorrectly.

Required fix:

Either expand `income_tax_return_filings.form_code` and related configuration, or record a formal Phase 1 exclusion.

Recommended columns or changes:

- Extend allowed `form_code` values if in scope.
- Add `income_tax_form_variant` or equivalent if form selection cannot be derived safely from `income_tax_regime` alone.
- Add individual income source classification if mixed-income individual support is in scope.

### 6. Structured Tax Calendar Periods

Severity: MEDIUM

Existing support:

- `tax_calendar.form_code`
- `tax_calendar.period_covered`
- `tax_calendar.due_date`
- `tax_calendar.extended_due_date`
- `tax_calendar.is_filed`

Missing support:

- Structured period year/month/quarter fields.
- Period start and period end dates.

Impact:

Free-text periods can break due-date lookup, uniqueness, and automation.

Recommended columns:

- `period_year`
- `period_month`
- `period_quarter`
- `period_start_date`
- `period_end_date`

### 7. Documentation Contradictions To Clean Up

Severity: MEDIUM

Found contradictions:

- Some documentation implies `vat_entries.vat_classification` can carry `capital_goods` and `services`, while the migration and canonical comments restrict `vat_entries` to `vatable`, `zero_rated`, `exempt`, and `government`.
- `docs/architecture/01_DATABASE_ARCHITECTURE_OVERVIEW.md` describes MCIT carry-forward through `income_tax_computation_lines` using a `line_type`, but the table does not have a `line_type` column and no MCIT carry-forward balance table exists.
- `tax_credits_schedules` uses `prior_quarter_overpayment` in migrations, while some prose refers to prior-year excess credits.
- `docs/architecture/04_RELATIONSHIP_MAP.md` refers to `tax_credits_schedules` as 2307/2306 credits, but 2306/FWT is correctly excluded elsewhere because FWT is final and not creditable.

Impact:

A developer could implement the wrong tax logic by following the wrong document.

Required fix:

Clean documentation before or during the Migration 018 scope update. Do not let the contradictions survive into SQL implementation.

## Tables Already Existing

### Setup And Profile

- `companies`
- `company_compliance_profiles`
- `cas_registrations`
- `bir_form_configurations`
- `atc_codes`
- `tax_codes`
- `vat_codes`
- `percentage_tax_codes`
- `ewt_codes`
- `fwt_codes`
- `tax_calendar`
- `system_account_config`
- `chart_of_accounts`

### Master Data Tax Profiles

- `customers`
- `customer_tax_profiles`
- `suppliers`
- `supplier_tax_profiles`
- `items`
- `services`

### Transaction Tax Sources

- `sales_invoices`
- `sales_invoice_lines`
- `cash_sales`
- `cash_sale_lines`
- `vendor_bills`
- `vendor_bill_lines`
- `cash_purchases`
- `cash_purchase_lines`
- `petty_cash_vouchers`
- `petty_cash_voucher_lines`
- `receipts`
- `receipt_lines`
- `payment_vouchers`
- `payment_voucher_lines`

### Compliance Tax Tables

- `vat_entries`
- `vat_period_summaries`
- `vat_return_filings`
- `slsp_exports`
- `relief_exports`
- `certificates_2307_issued`
- `certificates_2307_received`
- `ewt_entries`
- `ewt_period_summaries`
- `ewt_remittances_1601eq`
- `fwt_entries`
- `certificates_2306_issued`
- `fwt_remittances_1601fq`
- `qap_exports`
- `sawt_exports`
- `percentage_tax_entries`
- `percentage_tax_period_summaries`
- `percentage_tax_return_filings`
- `income_tax_return_filings`
- `itr_computation_runs`
- `income_tax_computation_lines`
- `book_tax_reconciliations`
- `tax_credits_schedules`
- `nolco_tracking`

## Tables Planned In Migration 018

Migration 018 planned tables that materially affect PH tax readiness:

### Audit / CAS

- `audit_logs`
- `field_change_history`
- `user_activity_logs`
- `system_parameter_logs`
- `document_void_register`
- `dat_generation_logs`
- `export_history`
- `system_alerts`

### Attachments And Evidence

- `attachments`
- `attachment_versions`

### Import / Export And Generated Files

- `import_batches`
- `import_rows`
- `import_validation_errors`
- `import_templates`
- `export_jobs`
- `generated_report_files`

### Document Output

- `document_templates`
- `generated_documents`
- `generated_document_versions`

### Workflow, Period Close, And Workspace

- `approval_requests`
- `approval_actions`
- `period_close_checklists`
- `period_close_tasks`
- `subledger_close_certifications`
- `feature_definitions`
- 11 Adaptive Workspace metadata tables

These planned tables are relevant to PH tax because they close proof, audit, generated-output, export, DAT, approval, attachment, and visibility gaps.

## Recommended Additional Tables

### Required Before PH Tax Freeze

1. `tax_filing_payments`
   - Purpose: normalized tax payment/remittance tracking for all tax filing families.
   - Reason: required for payment/remittance tracking and proof of filing/payment.

2. `mcit_credit_tracking`
   - Purpose: track excess MCIT carry-forward by source year, application year, remaining balance, and expiry.
   - Reason: MCIT is already in scope; without carry-forward tracking, corporate income tax payable can be wrong.

### Strongly Recommended Before CRUD

3. `tax_filing_amendments`
   - Purpose: tax-specific amendment chain across VAT, withholding, percentage tax, and income tax filings.
   - Reason: filing status alone does not preserve a clean BIR-facing amendment history.

## Recommended Additional Columns

### VAT

- `vat_entries.input_vat_category`
- `vat_entries.is_creditable_input_vat`
- `vat_entries.creditable_period_id`
- `vat_period_summaries.input_vat_carryover`
- `vat_period_summaries.deferred_input_vat`
- `vat_period_summaries.disallowed_input_vat`
- `vat_period_summaries.creditable_input_vat`

### Tax Calendar

- `tax_calendar.period_year`
- `tax_calendar.period_month`
- `tax_calendar.period_quarter`
- `tax_calendar.period_start_date`
- `tax_calendar.period_end_date`

### Income Tax

Either:

- Expand `income_tax_return_filings.form_code` to include applicable Phase 1 form variants.

Or:

- Record explicit exclusions for unsupported form variants.

If expanded, consider:

- `income_tax_return_filings.income_tax_form_variant`
- `company_compliance_profiles.individual_income_source_type` if mixed-income individual support is in scope

## Items Safe To Handle In Application Logic

These can remain application/service validations if they are explicitly tested:

- EWT/FWT ATC series validation against `atc_codes.code` prefixes.
- TIN formatting with or without dashes.
- Effective-date non-overlap checks for compliance profiles and tax profiles.
- Eight percent eligibility threshold checks, because thresholds can change.
- Mapping current BIR form defaults from setup records.
- Deciding whether a VAT taxpayer opts into optional 2550M filing.
- UI display of friendly tax labels.
- Warnings for cooperative income tax if explicitly out of Phase 1.

## Items That Must Be Database-Backed

These must not live only in UI or transient service memory:

- Company compliance profiles and effective dates.
- Tax code setup and ATC references.
- Transaction tax snapshots.
- Immutable VAT/EWT/FWT/percentage tax entries.
- Filing records and filing statuses.
- Payment/remittance proof and allocation to filings.
- MCIT carry-forward balances.
- NOLCO balances.
- Tax credit schedules.
- Generated compliance files and documents.
- Attachments used as filing/payment evidence.
- DAT/export logs.
- Filed-return immutability and amendment history.
- Audit trail and field history.
- RLS and service-owned write restrictions.

## Whether Migration 018 Scope Should Change

Yes. From a PH tax perspective, the current Migration 018 scope should be updated before SQL implementation.

Recommended change:

Keep the planned 018A to 018E structure, but add a PH tax hardening scope before final verification. This can be inside 018D if kept small, or split into a dedicated 018F before verification.

Minimum added scope:

1. Add `tax_filing_payments`.
2. Add `mcit_credit_tracking`.
3. Add VAT ledger and VAT summary fields for carryover/deferred/disallowed/input VAT reporting categories, or record a formal Phase 1 exclusion.
4. Add structured `tax_calendar` period fields, or upgrade the existing v5.0 backlog proposal into Migration 018 if tax automation is required before CRUD.
5. Add tax filing amendment chain support, either through `tax_filing_amendments` or equivalent fields.
6. Expand ITR form-code support or record owner-approved exclusions.
7. Clean tax documentation contradictions before SQL work begins.

## GO / NO-GO For Migration 018 From PH Tax Perspective

NO-GO for the current Migration 018 scope as written.

This is not a rejection of the overall architecture. The existing tax foundation is broad and mostly correct. The NO-GO is specific: Migration 018 should not start SQL implementation until the PH tax gaps above are either added to scope or formally excluded by owner decision.

If the owner approves these scope changes, Migration 018 can proceed with high confidence.
