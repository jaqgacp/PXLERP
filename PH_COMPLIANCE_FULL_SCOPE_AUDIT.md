# PXL ERP - PH Compliance Full Scope Audit

Pre-Migration 018 Tax Foundation Validation

Repository: PXLERP
Branch reviewed: main
Latest commit reviewed: 5b1bc8deda33193eb411b2922a0ad79285fa667c
Audit mode: Planning and architecture validation only
Output status: No SQL, migration, UI, CRUD, backlog, or decision-log changes

## 1. Executive Summary

PXL ERP already has a strong Phase 1 compliance foundation for ordinary Philippine SME and accounting-firm workflows. The existing architecture and migrations cover core VAT, percentage tax, expanded withholding tax, final withholding tax, certificates 2307 and 2306, income tax computation, NOLCO, tax credits, CAS registration, DAT/export history, posting traceability, audit trail, generated documents, attachments, and company-scoped RLS.

However, from a full Philippine compliance scope perspective, Migration 018 should not proceed exactly as currently designed. The current foundation still relies on fixed form-code checks, incomplete taxpayer obligation modeling, missing payment/remittance evidence, missing amendment lineage, incomplete revised VAT 2550Q support, missing MCIT carry-forward tracking, incomplete income tax form variants, and no normalized rule layer for taxpayer obligations and filing due dates.

The issue is not that PXL needs every possible Philippine tax module in Phase 1. The issue is that the architecture has declared broad Phase 1 support for VAT, NON-VAT, withholding, income tax, multiple taxpayer types, books/CAS, generated reports, and filing readiness. Those areas need a small set of database-backed compliance metadata and evidence tables before the foundation is frozen.

Readiness from PH compliance perspective:

| Area | Score | Assessment |
|---|---:|---|
| Entity and taxpayer setup | 78/100 | Good base, but accounting method, branch RDO/book registration, professional/mixed-income classification, and exemption evidence need hardening. |
| VAT and percentage tax | 76/100 | Core entries exist, but revised 2550Q fields, VAT carryover/deferred/disallowed input VAT, and payment evidence are incomplete. |
| Withholding tax | 82/100 | EWT/FWT entries, certificates, QAP, and SAWT are strong, but 1604E/1604F annual filing status and payment/evidence handling need backing. |
| Income tax | 68/100 | ITR computation exists, but 1701A, 1702-EX, 1702-MX, MCIT carry-forward, prior overpayment handling, and amendment lineage are incomplete. |
| CAS/books/audit evidence | 75/100 | Audit and generated-document foundation is strong; book registration records are missing. |
| Configurability/no hardcoding | 62/100 | Tax codes are configurable, but form definitions, obligation rules, due-date rules, and tax treatment rules remain too hardcoded. |
| Supabase/RLS readiness | 80/100 | Existing RLS pattern is strong; new compliance tables must be company-scoped and filed returns must be immutable. |
| Overall PH compliance readiness | 73/100 | Strong but not freeze-ready for full Phase 1 compliance claims. |

Final PH compliance decision: NO-GO for Migration 018 as currently scoped.

Migration 018 can become GO if it is updated to include the database-backed compliance foundation listed in Sections 11 to 13, or if the owner formally narrows Phase 1 compliance scope and records exclusions for the unsupported forms/taxpayer cases.

## 2. Official Sources Reviewed

The review used official BIR sources and project-local architecture/migration files. Official sources reviewed:

| Source | Compliance area reviewed | Relevance to PXL |
|---|---|---|
| [BIR Forms page](https://www.bir.gov.ph/bir-forms) | Current official form categories | Confirms the BIR form universe PXL must classify as required, configurable, or excluded. |
| [BIR Downloadables page](https://www.bir.gov.ph/Downloadables) | Alphalist, RELIEF, MAP, SAWT tools/specs | Confirms that machine-readable submissions and validation outputs need traceable export jobs and acknowledgements. |
| [BIR Form 2550Q April 2024](https://bir-cdn.bir.gov.ph/BIR/pdf/2550Q%20%20April%202024%20ENCS_Final.pdf) | Quarterly VAT return | Confirms revised VAT fields for uncollected receivables, recovered receivables, input VAT carryover, capital goods deferral, exempt attribution, unpaid payables, penalties, and payment evidence. |
| [RMC 52-2023](https://bir-cdn.bir.gov.ph/local/pdf/RMC%20No.%2052-2023.pdf) | Optional monthly VAT return 2550M | Confirms quarterly VAT is mandatory while monthly VAT filing remains optional. |
| [RMC 68-2024 Digest](https://bir-cdn.bir.gov.ph/BIR/pdf/RMC%20No.%2068-2024%20Digest.pdf) | Revised 2550Q under EOPT | Confirms new 2550Q fields for uncollected receivables and unpaid payables. |
| [BIR Form 2551Q guide](https://bir-cdn.bir.gov.ph/local/pdf/2551Q_%20Jan%202018%20Guide.pdf) | Percentage tax | Confirms NON-VAT percentage tax filing requirements and tax base handling. |
| [BIR Form 1601-EQ guide](https://bir-cdn.bir.gov.ph/local/pdf/1601-EQ%20Guide%20Jan%202018.pdf) | Quarterly EWT remittance | Confirms withholding agent obligations, quarter filing, proof of payment, branch-code context, penalties, and QAP attachment. |
| [BIR Form 1601-FQ](https://bir-cdn.bir.gov.ph/local/pdf/1601-FQ%202020%20final.pdf) | Quarterly FWT remittance | Confirms final withholding return structure, amended return, remittances, penalties, and treaty/special-law fields. |
| [BIR Form 1604E](https://bir-cdn.bir.gov.ph/local/pdf/1604E%20Jan%202018%20ENCS%20Final2.pdf) | Annual EWT information return | Confirms annual information return requirements for creditable withholding. |
| BIR Form 1604F from BIR Forms index | Annual FWT information return | Confirms an annual FWT information return must be treated separately from quarterly 1601-FQ. |
| [BIR Form 2307](https://bir-cdn.bir.gov.ph/local/pdf/2307%20Jan%202018%20ENCS%20v3.pdf) | Certificate of creditable tax withheld | Confirms payor/payee identity, TIN, address, ATC, income payment, and tax withheld requirements. |
| [BIR Form 2306](https://bir-cdn.bir.gov.ph/local/pdf/2306%20Jan%202018%20ENCS%20v4.pdf) | Certificate of final tax withheld | Confirms final tax certificate details, final income tax, fringe benefit categories, business tax withholding, ATC schedules, and payor/payee data. |
| [BIR Form 1701A](https://bir-cdn.bir.gov.ph/local/pdf/1701A%20Jan%202018%20v5%20with%20rates.pdf) | Annual ITR for individuals purely business/profession | Confirms OSD and 8 percent individual filing path not represented by existing ITR form checks. |
| [BIR Form 1702-RT](https://bir-cdn.bir.gov.ph/local/pdf/1702-RT%20Jan%202018%20ENCS%20Final%20v3.pdf) | Regular corporate ITR | Confirms ordinary non-individual income tax path. |
| [BIR Form 1702-EX](https://bir-cdn.bir.gov.ph/local/pdf/1702-EX%20Jan%202018%20ENCS%20v2.pdf) | Exempt corporation/non-individual ITR | Confirms exempt/special-law taxpayers require separate ITR treatment and relief/exemption metadata. |
| [BIR Form 1702-MX](https://bir-cdn.bir.gov.ph/local/pdf/1702-MX%20Jan%202018%20ENCS%20Final%20with%20OSDv2.pdf) | Mixed/special-rate non-individual ITR | Confirms special-rate/multiple-rate non-individual taxpayers need separate ITR support. |
| [BIR Form 0605](https://bir-cdn.bir.gov.ph/local/pdf/0605version1999_09.02.2022_copy.pdf) | Payment form for voluntary, deficiency, penalties, second installment, advance/tax deposit payments | Confirms payment/remittance evidence must be tracked separately from computed returns. |
| [BIR CAS/CBA registration service](https://www.bir.gov.ph/BIRCC-RDO-External-Service-23) | CAS/computerized books registration | Confirms CAS registration and component readiness are compliance artifacts. |
| [BIR books registration service](https://www.bir.gov.ph/BIRCC-RDO-External-Service-17) | Books of accounts registration | Confirms books registration must be tracked separately from CAS registration. |
| [RMC 5-2021](https://bir-cdn.bir.gov.ph/local/pdf/RMC%20No.%205-2021%20%281%29.pdf) | Simplified CAS/CBA registration | Confirms CAS/CBA registration evidence should be captured. |
| [RMC 3-2023](https://bir-cdn.bir.gov.ph/local/pdf/RMC%20No.%203-2023.pdf) | Online registration of books | Confirms book registration evidence such as QR stamp/registration details should be captured. |
| [BIR Form 2000](https://bir-cdn.bir.gov.ph/local/pdf/2000-DST%20Jan%202018%20final.pdf) | Monthly documentary stamp tax | Used to determine that DST should be formally excluded unless Phase 1 includes DST-triggering instruments. |
| [BIR Form 2000-OT](https://bir-cdn.bir.gov.ph/local/pdf/2000-OT%20January%202018%20ENCS%20v3.pdf) | One-time DST transactions | Used to determine that DST is not supported by current ordinary ERP transaction scope. |
| [BIR Form 1603Q](https://bir-cdn.bir.gov.ph/local/pdf/1603Q%20Jan%202018%20final.pdf) | Fringe benefits tax | Used to determine that FBT should be excluded unless payroll/fringe benefit modules are added. |
| [RMC 20-2026](https://bir-cdn.bir.gov.ph/BIR/pdf/RMC%2020-2026.pdf) | 2025 annual income tax return availability | Confirms current BIR eServices treatment of annual income tax forms, including 1701/1701A/1702 variants. |

Project-local sources reviewed:

- `PH_TAX_ARCHITECTURE_GAP_REPORT.md`
- `MIGRATION_018_DESIGN_PLAN.md`
- `MIGRATION_018_IMPLEMENTATION_SPEC.md`
- `PRINCIPLES_MASTER_INDEX.md`
- `docs/principles/*`
- `docs/architecture/02_COMPLETE_TABLE_INVENTORY.md`
- `docs/architecture/03_TABLE_COLUMN_SPECIFICATIONS.md`
- `docs/architecture/05_COMPLIANCE_DATA_CAPTURE_MAP.md`
- `docs/architecture/06_POSTING_ENGINE_TABLE_DESIGN.md`
- `docs/architecture/08_IMPORT_EXPORT_TABLE_DESIGN.md`
- `docs/architecture/09_SECURITY_RLS_DESIGN.md`
- `SUPABASE_FINAL_REVIEW_BACKLOG.md`
- `supabase/SUPABASE_DECISIONS.md`
- `supabase/migrations/001_extensions.sql` through `supabase/migrations/017g_compliance_policies.sql`

## 3. Entity/Taxpayer Coverage Matrix

| Entity/taxpayer case | Required tax drivers | Existing support | Gap | Phase 1 disposition |
|---|---|---|---|---|
| Sole proprietor | Individual legal type, TIN, RDO, VAT/NON-VAT, 8 percent or graduated income tax, OSD/itemized, business/profession source, branch code, books/CAS | `companies`, `company_compliance_profiles`, `fiscal_years`, `tax_calendar`, `income_tax_return_filings` | 1701A not supported in ITR form checks; no explicit individual source classification; no accounting method; no books registration table | Required if PXL supports sole proprietors in Phase 1. Add fields/form metadata before freeze. |
| Regular corporation | Corporate legal type, TIN/RDO, VAT/NON-VAT, fiscal year, MCIT, NOLCO, tax credits, books/CAS | Strong support through company setup, GL, ITR computation, NOLCO, tax credits | MCIT carry-forward table missing; payment evidence and amendment lineage missing | Required and mostly supported, but not freeze-ready. |
| OPC | Corporate taxpayer behavior with single-person corporate identity | Covered as corporation through legal type/profile | No OPC-specific blocker found | Required if offered, can use corporation path. |
| Partnership | Partnership/GPP classification, income tax form, withholding/tax profile | Legal type and compliance profile support; 1702-EX official form includes GPP path | Documentation must clarify ordinary partnership vs GPP/exempt handling; form checks incomplete | Required only with explicit supported partnership types. |
| Cooperative | Cooperative legal type and possible exempt/special treatment | Legal type exists in profile | Architecture previously marks cooperative as out of Phase 1 in places, while non-negotiable user scope asks for it | Requires owner decision: support via 1702-EX/special profile, or formally exclude from Phase 1. |
| Professional | Individual taxpayer, business/profession income, 1701A/1701Q, 8 percent/OSD/graduated, EWT received | Personnel, services, customers/suppliers, 2307 received, ITR computation | No explicit professional taxpayer flag/source classification; 1701A missing | Required if sole-professional clients are Phase 1. Add profile fields/form metadata. |
| VAT taxpayer | VAT status, VAT codes, VAT returns, sales/purchase VAT classification, SLS/SLP/RELIEF | `vat_codes`, `vat_entries`, `vat_period_summaries`, `vat_return_filings`, `slsp_exports`, `relief_exports` | Revised 2550Q VAT fields incomplete; input VAT carryover/deferred/disallowed treatment incomplete | Required. Add VAT hardening before freeze. |
| NON-VAT taxpayer | NON-VAT profile, percentage tax codes, 2551Q, exemptions | `company_compliance_profiles`, `percentage_tax_codes`, `percentage_tax_entries`, `percentage_tax_return_filings` | 8 percent vs percentage tax obligation not modeled as configurable rule; payment evidence incomplete | Required. Add obligation rules/payment evidence. |
| Mixed income/business income | Source classification, form variant, 1701/1701A selection, 8 percent eligibility | `income_tax_regime`, `deduction_method` partially support | No source-type field; no configurable obligation rule to select 1701 vs 1701A | Required only if mixed-income individuals are Phase 1. Otherwise formally exclude. |
| Withholding agent | WA status, EWT/FWT remittance, certificates, annual returns | `withholding_agent_status`, EWT/FWT entries/remittances, 2307/2306, QAP/SAWT | 1604E/1604F annual filing records missing; payment evidence incomplete | Required if PXL supports withholding agent companies. |
| Non-withholding agent | Ability to disable WHT forms and hide workflows | `withholding_agent_status` supports classification | Missing obligation rules that drive form visibility and filing calendar | Required. Add `taxpayer_obligation_rules`. |
| Government customer/payor | Government classification, VAT withholding, special handling | `party_special_class`, VAT government classification, 2307 support | Not all government VAT withholding paths are fully modeled | Required only for ordinary government customers/vendors; complex substituted filing can be configured later if formalized. |
| PEZA/BOI/IPA/special-law party | Exemption/special-law evidence, effective dates, special rate/tax relief | `party_special_class`, some form fields, planned attachments | No certificate/evidence table; no special-rate company ITR support unless 1702-EX/MX added | Support as party classification now; company-as-IPA/special-rate taxpayer needs explicit Phase 1 decision. |
| Foreign payee/customer | Foreign address, treaty/special-law, FWT/ATC | Supplier/customer fields and FWT entries partially support | Treaty relief evidence and nonresident-specific profile fields are thin | Support basic foreign payee/customer; exclude complex treaty relief until rule/evidence tables exist. |
| Branch operations | Branch TIN suffix, branch address, branch scope | `branches.tin_suffix`, `branches.bir_registered`, branch-scoped transactions | Branch RDO/code details are not complete; separate branch filing behavior needs rule support | Add branch RDO/compliance fields if branch-level filing is Phase 1. |
| Accounting firm multi-client | Multi-company, user-company access, RLS | Strong support through companies, roles, RLS helpers | No compliance-specific blocker | Supported. |
| Large company department access | Departments, cost centers, RLS helpers, roles | Strong base | Tax setup access must remain permission-scoped | Supported with RLS policy completion. |

## 4. BIR Form Coverage Matrix

| Form/output | Who files/when required | Frequency | Existing PXL support | Missing backing | Phase 1 disposition |
|---|---|---:|---|---|---|
| 2550M | VAT-registered persons that optionally file monthly VAT | Optional monthly | `bir_form_configurations` and `tax_calendar` include 2550M | Must be optional, not mandatory; due-date rules need configurability | Configurable optional form. |
| 2550Q | VAT taxpayers and persons required to register as VAT | Quarterly | `vat_entries`, `vat_period_summaries`, `vat_return_filings` | Revised 2024 fields for uncollected receivables, recovered receivables, unpaid payables, settled payables, input VAT carryover/deferral/attribution; payment evidence | Required. Migration 018 scope should change. |
| 2551Q | NON-VAT percentage taxpayers | Quarterly | `percentage_tax_entries`, `percentage_tax_period_summaries`, `percentage_tax_return_filings` | 8 percent option exclusion/eligibility not rule-driven; payment evidence and penalties thin | Required for NON-VAT. Add rule/payment hardening. |
| 1601EQ | Withholding agents/payors for creditable withholding | Quarterly | `ewt_entries`, `ewt_period_summaries`, `ewt_remittances_1601eq`, QAP | Payment evidence table missing; filing amendment chain missing | Required. Add payment/amendment support. |
| 1601FQ | Withholding agents/payors for final withholding | Quarterly | `fwt_entries`, `fwt_remittances_1601fq`, 2306 | Payment evidence and annual 1604F handling missing | Required if FWT is Phase 1. |
| 1604E | Withholding agents with annual EWT reporting | Annual | Form code appears in setup/calendar; QAP and EWT data can feed it | No annual filing table/status, generated file linkage, or filing proof | Required if EWT Phase 1 is claimed. Add annual withholding return table. |
| 1604F | Withholding agents with annual FWT reporting | Annual | FWT entries/remittances exist | No form code in CHECK lists; no annual FWT filing table/status | Required if FWT Phase 1 is claimed. Add annual withholding return table/form metadata. |
| 2307 issued | Payors issuing creditable withholding certificates | Per certificate/period | `certificates_2307_issued` | Needs generated document/attachment linkage from planned 018 | Required and mostly supported. |
| 2307 received | Payees receiving creditable withholding certificates | Per certificate/period | `certificates_2307_received`, `tax_credits_schedules` | Credit matching/payment evidence needs hardening | Required and mostly supported. |
| 2306 | Final tax withheld certificate | Per certificate/period | `certificates_2306_issued`, FWT entries | FBT/business tax categories should be excluded or explicitly supported | Required for FWT; FBT scope should be excluded. |
| SAWT | Summary alphalist of withholding tax | Filing attachment/export | `sawt_exports` | Acknowledgement/proof should link to attachment/export history | Required with 2307 received. |
| QAP | Quarterly alphalist of payees | Filing attachment/export | `qap_exports` | Acknowledgement/proof should link to attachment/export history | Required with 1601EQ. |
| SLSP/SLS/SLP | Summary lists for VAT sales/purchases | Periodic submission/export | `slsp_exports` | Importation summary/listing not supported; export acknowledgement needs attachment linkage | Required for ordinary SLS/SLP; importations can be excluded unless import purchasing is Phase 1. |
| RELIEF | VAT sales/purchases/importation data submission | Export/submission support | `relief_exports` | Importation detail support limited; acknowledgement linkage needed | Required if RELIEF output is claimed; importation detail optional/excluded. |
| 1701Q | Individual quarterly ITR | Quarterly | `income_tax_return_filings` includes 1701Q | Individual source classification and payment evidence missing | Required for sole proprietor/professional clients. |
| 1701 | Annual ITR for individuals, including mixed income | Annual | `income_tax_return_filings` includes 1701 | Mixed-income/source classification missing | Required only if mixed-income supported. Otherwise explicit exclusion needed. |
| 1701A | Annual ITR for individuals purely business/profession under OSD/8 percent | Annual | Not present in form-code checks | Missing form variant and obligation mapping | Required if sole proprietors/professionals are Phase 1. Add. |
| 1702Q | Corporate quarterly ITR | Quarterly | `income_tax_return_filings` includes 1702Q | MCIT carry-forward/payment evidence missing | Required. |
| 1702RT | Regular corporate annual ITR | Annual | `income_tax_return_filings` includes 1702RT | Payment evidence and amendment lineage missing | Required. |
| 1702-EX | Exempt corporation/non-individual ITR | Annual | Not present in form-code checks | Exempt/special-law company profile and form support missing | Required only if cooperative/exempt/GPP/special entities are supported. |
| 1702-MX | Mixed/special-rate non-individual ITR | Annual | Not present in form-code checks | Special/multiple-rate company support missing | Required only if special-rate/mixed corporations are supported. |
| 0605 | Payment form for voluntary, deficiency, penalties, second installment, advance/tax deposit payments | As needed | No generic payment/remittance table | Missing evidence, reference number, payment type, tax type, period, and attachment linkage | Required as payment evidence model for Phase 1 returns. |
| Books of accounts | Registered books for taxpayers | Registration/renewal as applicable | `cas_registrations` only partially covers CAS | No `book_registration_records` for book type, registration channel, QR stamp/ACCN, period, evidence | Required for CAS/books readiness claim. |
| DAT/CAS exports | CAS audit/export support | As requested/periodic | Planned `dat_generation_logs`, `export_history`, `generated_report_files`; existing audit logs | Needs RLS and immutable export evidence | Required and planned in Migration 018. |
| 2000/2000-OT | Documentary stamp tax | Monthly or one-time | No DST module/tables | No DST taxable document model | Exclude from Phase 1 unless loan/share/real-estate/instrument modules are added. |
| 1603Q | Fringe benefits tax | Quarterly | No payroll/fringe benefit module | No fringe benefit master/transaction data | Exclude from Phase 1 unless payroll/fringe-benefit expenses are added. |
| 1601C/1604C/2316 | Compensation withholding | Monthly/annual/certificate | No payroll module | No employee compensation payroll basis | Exclude from Phase 1. |
| Local business tax/LGU/RBELT | LGU/local compliance | Local schedule | No LGU compliance module | Not a BIR ordinary tax return workflow | Exclude from Phase 1 unless LGU compliance is approved. |

## 5. Tax Type Coverage Matrix

| Tax type | Existing support | Gap | Required disposition |
|---|---|---|---|
| Output VAT | Sales/cash sales/invoices/returns feed `vat_entries` and `vat_period_summaries` | Revised 2550Q uncollected/recovered receivable fields are not database-backed | Add VAT timing/adjustment backing. |
| Input VAT | Vendor bills/cash purchases feed input VAT | Deferred capital goods, unpaid payables, settled payables, disallowed/exempt-attributed input VAT are incomplete | Add input VAT category/timing/adjustment fields or table. |
| VAT exempt sales | VAT classifications exist | Exempt attribution to input VAT is not fully backed | Add VAT adjustment support. |
| Zero-rated sales | VAT classifications exist | Proof/evidence for zero-rated/exempt/special cases missing | Add tax exemption/evidence table or require attachments linked to transactions. |
| Government sales/VAT withholding | Government classification exists | Government VAT withholding and substituted filing paths need explicit rules | Support ordinary government classification; complex substituted filing can be deferred by owner decision. |
| Deferred input VAT | Partially represented through VAT summary categories | No durable schedule/category table | Add backing if PXL claims 2550Q completion. |
| Disallowed input VAT | Not fully represented | No durable field/table | Add backing. |
| VAT carryover | Partial via summary totals | No explicit carryover chain | Add carryover fields/schedule. |
| Percentage tax | `percentage_tax_entries`, summaries, filings | 8 percent vs percentage tax obligation not rule-driven; payments missing | Add obligation rules/payment evidence. |
| Expanded withholding tax | Strong EWT entries, summaries, remittances, 2307 | Annual 1604E filing and payment/evidence gap | Add annual filing/payment backing. |
| Final withholding tax | Strong FWT entries, remittances, 2306 | 1604F filing and FBT category scope unresolved | Add annual filing backing; exclude FBT unless payroll added. |
| Creditable withholding tax | 2307 received and tax credits schedule exist | Matching to ITR credits and prior payments needs hardening | Add tax filing payments/credits refinements. |
| Income tax | ITR filings, computation runs, lines, book-tax reconciliation | Form variants, MCIT carry-forward, payment evidence, amendment chain missing | Add hardening before freeze. |
| MCIT | MCIT current amount appears in computation runs | No MCIT carry-forward ledger/schedule | Add `mcit_credit_tracking`. |
| MCIT carry-forward | Not backed | Missing table | Add before full corporate ITR freeze. |
| NOLCO | `nolco_tracking` exists | Remaining amount invariant/open cleanup; expiration/application trace needs verification | Existing table is acceptable with cleanup. |
| Tax credits | `tax_credits_schedules` exists | Credit type list incomplete for prior-year excess and MCIT carry-forward; no generic payment evidence | Add columns/check values or normalize through payment/credit schedule. |
| Prior period overpayments | Partial in `tax_credits_schedules` | Naming and year/return source lineage incomplete | Add source filing/payment references. |
| Penalties/surcharge/interest/compromise | Some filing tables include penalty fields | Not consistent across all filing/payment forms | Prefer generic `tax_filing_payments` with penalties/payment references. |
| Documentary stamp tax | Not supported | No taxable instrument model | Explicitly exclude unless approved. |
| Fringe benefits tax | Not supported except 2306 lists categories | No payroll/fringe benefit source data | Explicitly exclude unless approved. |
| Local business tax | Not supported | Not BIR ordinary return workflow | Explicitly exclude unless approved. |

## 6. Master Data Capture Requirements

| Master data area | Required capture | Existing tables/fields | Gap | Required action |
|---|---|---|---|---|
| Company tax profile | Legal type, taxpayer type, income tax regime, deduction method, withholding agent status, RDO, registration data, effective dates | `companies`, `company_compliance_profiles` | Missing accounting method, taxpayer size/classification, professional/source classification, explicit fiscal/calendar filing type | Add columns or profile fields. |
| Company registration | TIN, registered name, registered address, RDO, SEC/DTI registration | `companies` | Branch-specific RDO/book data thin | Add branch compliance fields if branch-level filing is needed. |
| Branch tax profile | Branch code/TIN suffix, branch address, branch filing behavior | `branches.tin_suffix`, `branches.bir_registered` | No branch RDO code; no branch compliance profile | Add `branches.rdo_code` or formal exclusion for branch-level filing. |
| Books registration | Book type, registration channel, QR stamp/ACCN, period, status, evidence | None dedicated | `cas_registrations` is not enough | Add `book_registration_records`. |
| CAS registration | System/component registration evidence | `cas_registrations` | Needs generated document/attachment linkage from 018 | Planned support is acceptable. |
| Customer tax profile | TIN, registered name/address, VAT status, RDO, default ATC/EWT, effective dates | `customers`, `customer_tax_profiles`, `customer_credit_profiles` | Tax exemption/special-law certificate/evidence not structured | Add exemption/evidence table or transaction attachment policy. |
| Supplier tax profile | TIN, registered name/address, VAT status, RDO, default ATC/EWT, bank details | `suppliers`, `supplier_tax_profiles`, `supplier_bank_details` | Tax exemption/special-law certificate/evidence not structured | Add exemption/evidence table or formal attachment linkage. |
| Items/services | VAT classification, sales/purchase tax defaults, service/inventory type | `items`, `services`, tax code defaults in transaction lines | Some tax treatment remains engine/app logic | Add tax applicability rules if no hardcoded tax logic is required. |
| ATC/tax codes | Effective-dated code/rate setup | `atc_codes`, `tax_codes`, `vat_codes`, `percentage_tax_codes`, `ewt_codes`, `fwt_codes` | Good base; form associations and obligation logic are not normalized | Add form and obligation metadata. |
| Document series | ATP/number series, branch/company scoping | `number_series`, `number_series_atp`, `atp_usage_logs`, `document_controls` | Strong | No blocker. |
| Attachments/evidence | Proof of filing/payment/certificates | Planned in Migration 018; some existing FK placeholders | Needs RLS and immutable linkage to filings | Keep in Migration 018 and extend to tax payment/evidence tables. |

## 7. Transaction Data Capture Requirements

| Transaction area | Required tax capture | Existing support | Gap | Required action |
|---|---|---|---|---|
| Sales invoices/cash sales | VAT class, output VAT, inclusive/exclusive, customer snapshot, document number, ATP usage, branch/period | Strong support in sales migrations and `vat_entries` | Revised 2550Q output VAT timing for uncollected/recovered receivables missing | Add VAT timing/adjustment backing. |
| Receipts | Collection evidence, VAT timing if EOPT relevant, withholding received | Receipts and receipt lines exist | Tax timing linkage to revised VAT fields not explicit | Add VAT timing rules/fields where required. |
| Sales credit/debit memos and returns | VAT reversal/adjustment, source reference, posted status | Existing documents and relationships | Return/amendment impact to filed tax periods must be controlled | RLS/immutability and amendment logic must protect filed periods. |
| Purchases/vendor bills/cash purchases | Input VAT, EWT/FWT, ATC, supplier snapshot, invoice/OR details | Strong support in purchasing migrations and withholding tables | Unpaid payables/settled payables, disallowed/deferred input VAT, exemption proof missing | Add VAT adjustment/category backing and evidence policy. |
| Payments/payment vouchers | Withholding remittance basis, payment proof | Payment vouchers exist; remittance tables exist | Generic tax payment evidence missing | Add `tax_filing_payments`. |
| Petty cash/expenses | VAT/EWT capture on expense lines, attachment evidence | Petty cash voucher lines exist | Tax line extraction and source proofs need verification | App logic can extract if line fields exist; evidence must be attached. |
| Journal entries | Tax adjustments, source references, audit trail | GL/journal entries and posting trace exist | Manual tax adjustments need reason/source/evidence controls | Use compliance adjustment records or require attachment/reason fields. |
| Inventory/fixed assets | Capital goods input VAT, depreciation/tax deductions | Inventory and fixed assets exist | Capital goods VAT deferral schedule not fully backed | Add VAT capital goods/deferred input support if in Phase 1. |
| Amendments/reversals | Amended return, previous return/payment, reversal reference | Document relationships exist | Tax filing amendment table missing | Add `tax_filing_amendments`. |
| Filing/payment | Payment method, bank/ROR/reference, amount, date, attachment | Some return tables have paid amounts/status | No unified evidence model | Add `tax_filing_payments`. |

## 8. Tax Engine Configurability Review

### Existing Configurability Strengths

- `company_compliance_profiles` provides effective-dated taxpayer type, income tax regime, deduction method, withholding agent status, legal type, RDO, and filing obligations.
- `atc_codes`, `tax_codes`, `vat_codes`, `percentage_tax_codes`, `ewt_codes`, and `fwt_codes` provide versioned tax/code setup.
- `bir_form_configurations` and `tax_calendar` provide early BIR form and filing calendar setup.
- `validation_rules`, `posting_rules`, `posting_rule_sets`, and `posting_rule_lines` support configurable validation/posting behavior.
- `number_series`, `number_series_atp`, and `document_controls` support compliant document numbering and ATP traceability.
- `feature_definitions` and adaptive workspace metadata planned in Migration 018 will help hide/show forms and reports.

### Configurability Gaps

| Gap | Why it matters | Required database backing |
|---|---|---|
| No normalized BIR form catalog | Current form support is spread across CHECK constraints and company-level config. BIR form changes would require SQL/code changes. | Add `tax_form_definitions`. |
| No taxpayer obligation rule table | VAT/NON-VAT, WA/non-WA, legal type, deduction method, 8 percent, exempt/special entities need form obligations that are setup-driven. | Add `taxpayer_obligation_rules`. |
| No configurable due-date/frequency rules | Filing due dates should be changed by configuration, not code, where practical. | Add `tax_filing_due_rules` or include robust due rule fields in `tax_form_definitions`. |
| No tax treatment/applicability rule layer | Some tax decisions would become backend hardcoding, especially for exemption/special class, VAT, EWT/FWT, 8 percent/percentage tax, and form selection. | Add minimal `tax_rule_sets`, `tax_rule_conditions`, `tax_rule_results`, or a smaller `tax_applicability_rules` model. |
| No unified filing payment/evidence model | Returns and remittances need proof of filing/payment, references, payment methods, amounts, and attachments. | Add `tax_filing_payments`. |
| No amendment lineage table | Amended returns must trace original and prior filings. | Add `tax_filing_amendments`. |
| No books registration record | CAS registration is not the same as books of accounts registration. | Add `book_registration_records`. |

### Configurability Conclusion

The current tax engine is configurable at the code/rate level, but not yet configurable at the obligation/form/rule level. That is not acceptable under the project rule of no hardcoded tax logic. Migration 018 should add a small, normalized compliance rule foundation before CRUD begins.

## 9. Existing Tables That Support Requirements

Existing tables already supporting PH compliance requirements:

| Requirement area | Existing tables |
|---|---|
| Company/taxpayer setup | `companies`, `branches`, `company_compliance_profiles`, `company_feature_settings`, `fiscal_years`, `fiscal_periods`, `fiscal_locks` |
| CAS and document control | `cas_registrations`, `number_series`, `number_series_atp`, `atp_usage_logs`, `document_controls` |
| Tax setup | `bir_form_configurations`, `atc_codes`, `tax_codes`, `vat_codes`, `percentage_tax_codes`, `ewt_codes`, `fwt_codes`, `tax_calendar` |
| Customer/supplier tax profile | `customers`, `customer_tax_profiles`, `customer_addresses`, `customer_contacts`, `suppliers`, `supplier_tax_profiles`, `supplier_addresses`, `supplier_contacts` |
| Sales tax source data | `sales_invoices`, `sales_invoice_lines`, `cash_sales`, `cash_sale_lines`, `sales_credit_memos`, `sales_credit_memo_lines`, `sales_debit_memos`, `sales_debit_memo_lines`, `customer_returns`, `customer_return_lines`, `receipts`, `receipt_lines` |
| Purchase tax source data | `vendor_bills`, `vendor_bill_lines`, `cash_purchases`, `cash_purchase_lines`, `payment_vouchers`, `payment_voucher_lines`, `vendor_credits`, `vendor_credit_lines`, `supplier_debit_memos`, `supplier_debit_memo_lines`, `purchase_returns`, `purchase_return_lines` |
| VAT | `vat_entries`, `vat_period_summaries`, `vat_return_filings`, `slsp_exports`, `relief_exports` |
| EWT | `ewt_entries`, `ewt_period_summaries`, `ewt_remittances_1601eq`, `certificates_2307_issued`, `certificates_2307_received`, `qap_exports`, `sawt_exports` |
| FWT | `fwt_entries`, `fwt_remittances_1601fq`, `certificates_2306_issued` |
| Percentage tax | `percentage_tax_entries`, `percentage_tax_period_summaries`, `percentage_tax_return_filings` |
| Income tax | `income_tax_return_filings`, `itr_computation_runs`, `income_tax_computation_lines`, `book_tax_reconciliations`, `tax_credits_schedules`, `nolco_tracking` |
| GL/posting traceability | `posting_batches`, `posting_errors`, `journal_entries`, `journal_lines`, `gl_balances`, `subsidiary_ledger_entries`, `document_relationships` |
| Audit/security | `profiles`, `roles`, `permissions`, `role_permissions`, `user_roles`, `user_company_access`, `user_branch_access`, `user_department_access`, RLS policies through 017G |

## 10. Planned Migration 018 Tables That Support Requirements

Migration 018 design and implementation specifications plan the following foundation areas that help PH compliance:

| Planned Migration 018 area | Compliance value |
|---|---|
| `feature_definitions` | Enables feature visibility and compliance feature gating without hardcoded keys. |
| Adaptive workspace tables | Allows forms/reports/dashboards to be enabled, hidden, disabled, or role-assigned from metadata. |
| `attachments` | Required for filing proof, payment proof, tax certificates, exemption evidence, and CAS/books evidence. |
| `generated_document_files` and `generated_report_files` | Required for BIR form PDFs, DAT files, certificates, and audit packages. |
| `export_jobs`, `import_jobs`, and related history/log tables | Required for QAP, SAWT, SLSP, RELIEF, DAT, and audit exports. |
| `audit_events` and `field_change_history` | Required for tax setup changes, filed-return immutability, and CAS audit trail. |
| `document_void_register` | Required for CAS/audit traceability of voided documents. |
| RLS and missing-policy cleanup | Required to protect compliance data by company, role, and service-owned processing. |

These planned tables are necessary but not sufficient for full PH tax compliance readiness. They need the tax-specific additions listed in Sections 11 to 13.

## 11. Missing Tables, If Any

The following tables are recommended before PH compliance foundation freeze. These are not UI features; they are database-backed controls needed to prevent hardcoded tax logic or incomplete filing evidence.

| Priority | Recommended table | Why database-backed | Minimum purpose |
|---|---|---|---|
| Critical | `tax_form_definitions` | BIR form support should not be locked inside CHECK constraints or backend constants. | Canonical BIR form catalog with form code, form name, tax type, filing frequency, effective dates, active flag, payment requirement, information-return flag, output type, and due-rule link. |
| Critical | `taxpayer_obligation_rules` | Form obligations depend on taxpayer type, VAT status, legal type, withholding agent status, income tax regime, deduction method, and effective dates. | Determines required, optional, excluded, and hidden forms/workflows per company profile. |
| High | `tax_filing_due_rules` | Due dates/frequencies change through regulation and should be setup-driven where practical. | Stores due-date formula, filing frequency, period basis, weekend/holiday handling flag, and effective dates. |
| Critical | `tax_filing_payments` | Filed returns/remittances need payment evidence, reference numbers, bank/ROR details, penalties, and attachments. | Generic payment/remittance proof table for VAT, percentage tax, withholding, income tax, and 0605-style payments. |
| Critical | `tax_filing_amendments` | Amended returns must trace original filing, prior payment, reason, and approval. | Immutable amendment lineage table for all filing tables. |
| High | `tax_applicability_rules` or `tax_rule_sets` family | Tax treatment selection cannot depend on hardcoded backend rules if the constitution says no hardcoded tax logic. | Effective-dated rules for tax applicability, form selection, VAT/percentage/EWT/FWT behavior, and special cases. |
| High | `tax_rule_conditions` | Needed only if a normalized rule-set family is chosen. | Stores predicates such as taxpayer type, legal type, VAT status, party class, item/service category, transaction type, amount thresholds, and date basis. |
| High | `tax_rule_results` | Needed only if a normalized rule-set family is chosen. | Stores selected tax code, ATC code, form requirement, filing obligation, or tax treatment output. |
| High | `tax_exemption_certificates` or `party_tax_exemption_certificates` | Zero-rated/exempt/special-law treatment should be evidenced and effective-dated, not only flagged. | Captures certificate type, issuing authority, certificate/reference number, party, effective dates, tax treatment, and attachment. |
| High | `mcit_credit_tracking` | MCIT carry-forward is not the same as current MCIT computation. It needs a schedule/ledger. | Tracks MCIT paid, source year, application, expiration, remaining balance, and related ITR filing. |
| High | `book_registration_records` | BIR books registration is separate from CAS registration. | Captures book type, registration date, registration channel, QR stamp/ACCN/permit data, period, status, branch/company, and attachment. |
| Medium | `withholding_annual_return_filings` | 1604E and 1604F are annual information returns distinct from quarterly remittances. | Tracks annual EWT/FWT return status, year, generated file/report, proof, amendment status, and source remittances. |
| Medium | `vat_adjustment_schedules` | Revised VAT returns require carryover/deferral/disallowed/unpaid-payable/uncollected-receivable tracking. | Stores VAT adjustment category, source transaction, period, amount, remaining balance, and filing linkage. |

Possible smaller alternative:

- Use a single `tax_applicability_rules` table instead of the three-table `tax_rule_sets` family for Phase 1.
- Use generic `tax_filing_payments` plus `tax_form_definitions` instead of separate 0605 tables.
- Use generic `tax_exemption_certificates` for customer, supplier, and company exemption evidence.

## 12. Missing Columns, If Any

Recommended columns or field additions before PH compliance freeze:

| Table | Recommended column/field | Reason |
|---|---|---|
| `company_compliance_profiles` | `accounting_method` | Required to distinguish cash, accrual, or approved hybrid basis where relevant. |
| `company_compliance_profiles` | `individual_income_source_type` | Needed for sole proprietor/professional/mixed-income form selection. |
| `company_compliance_profiles` | `taxpayer_size_classification` | BIR forms such as 2550Q include taxpayer classification; may affect filing/admin handling. |
| `company_compliance_profiles` | `business_activity_type` or `professional_status` | Needed to support professional taxpayers without guessing from services/personnel records. |
| `company_compliance_profiles` | `special_tax_relief_flag` and `special_tax_relief_basis` if not normalized elsewhere | Needed for special-law/treaty/IPA/exempt cases unless captured by certificate/rule tables. |
| `branches` | `rdo_code` | Branch-specific registered address/RDO handling may be needed for branch filings. |
| `branches` | `branch_tin` or explicit full TIN derivation rule | `tin_suffix` exists; generated documents may need a full branch TIN display. |
| `bir_form_configurations` | Replace or supplement fixed `form_code` CHECK with FK to `tax_form_definitions` | Prevents schema change every time a BIR form variant is added. |
| `tax_calendar` | `tax_form_definition_id` | Avoids fixed form-code dependency. |
| `tax_calendar` | `period_year`, `period_quarter`, `period_month`, `period_start_date`, `period_end_date` | `period_covered` free text is not enough for reliable filing computations. |
| `income_tax_return_filings` | Form support for `1701A`, `1702EX`, `1702MX` through FK or expanded check | Required if those taxpayer types are in Phase 1. |
| `income_tax_return_filings` | `amended_from_filing_id` only if no separate amendment table is added | Amendment lineage must be database-backed. Prefer separate table. |
| `income_tax_return_filings` | `overpayment_disposition` if not already present | Needed for carryover/refund/TCC treatment. |
| `tax_credits_schedules` | Add credit types for `prior_year_excess`, `mcit_carryforward`, and payment-derived credits | Current credit-type list is too narrow for corporate/individual ITR completeness. |
| `vat_entries` | `input_vat_category` | Needed for domestic purchase, services by non-resident, importations, capital goods, exempt attribution, unpaid payables, etc. |
| `vat_entries` | `vat_timing_status` | Needed for uncollected receivables, recovered receivables, unpaid payables, settled payables. |
| `vat_entries` | `is_creditable_input_vat` | Needed to distinguish allowable/disallowed/deferred input VAT. |
| `vat_period_summaries` | `input_vat_carried_over_previous`, `input_vat_deferred_previous`, `input_vat_deferred_next`, `input_vat_disallowed`, `input_vat_unpaid_payables`, `input_vat_settled_payables` | Required for revised 2550Q completeness. |
| `vat_period_summaries` | `output_vat_uncollected_receivables`, `output_vat_recovered_receivables` | Required for revised 2550Q completeness. |
| `percentage_tax_return_filings` | Penalty/payment linkage fields if generic payment table is not added | Payment evidence and penalties must be traceable. |
| `ewt_remittances_1601eq` and `fwt_remittances_1601fq` | Filing payment reference if generic payment table is not added | Prefer generic `tax_filing_payments`. |
| `certificates_2307_issued`, `certificates_2307_received`, `certificates_2306_issued` | Generated document and attachment references if not already planned | Required to trace issued/received certificates to rendered evidence. |

## 13. Recommended Configurable Rule Tables, If Any

Recommended minimal rule foundation:

| Table | Required? | Purpose | Notes |
|---|---|---|---|
| `tax_form_definitions` | Yes | Canonical BIR form metadata | This should replace hardcoded form-code lists. |
| `taxpayer_obligation_rules` | Yes | Determines forms/workflows required by taxpayer profile | Drives UI visibility, tax calendar, and compliance dashboard. |
| `tax_filing_due_rules` | Yes | Effective-dated due-date/frequency calculation metadata | Can be referenced by form definitions and calendar generation. |
| `tax_applicability_rules` | Recommended | Single-table lightweight rule model for Phase 1 | Good smaller alternative to full rule engine. |
| `tax_rule_sets` | Conditional | Parent table for normalized tax rule engine | Use only if PXL wants a fully normalized rule family now. |
| `tax_rule_conditions` | Conditional | Predicate table for rule sets | Avoid if a single lightweight matrix is enough. |
| `tax_rule_results` | Conditional | Output/action table for rule sets | Avoid if a single lightweight matrix is enough. |
| `deduction_method_rules` | Not separate if included in `taxpayer_obligation_rules` | OSD/itemized/8 percent eligibility | Avoid extra table unless deduction rules become complex. |
| `filing_frequency_rules` | Not separate if included in `tax_filing_due_rules` | Filing frequency | Avoid duplicate table. |

Recommendation: for Phase 1, add `tax_form_definitions`, `taxpayer_obligation_rules`, `tax_filing_due_rules`, and either one lightweight `tax_applicability_rules` table or the three-table rule-set family. Do not add both unless a clear normalization requirement is documented.

## 14. Items Safe To Handle In Application Logic

The following can be handled in backend/application logic if the source facts and audit evidence are database-backed:

- Computing due dates from `tax_filing_due_rules`.
- Generating BIR form PDFs from filing tables and `tax_form_definitions`.
- Generating QAP, SAWT, SLSP, RELIEF, DAT, and audit package files from source tables and export jobs.
- Rendering company-specific compliance dashboards from `taxpayer_obligation_rules`.
- Deriving tax calendar rows from company profile and obligation rules.
- Producing workbook/PDF layouts for CPA review.
- Calculating totals from immutable source entries for draft returns.
- Validating whether a user can see a form/page/report using feature/workspace metadata.
- Detecting missing attachments or incomplete filing proof from table state.
- Computing display-only full branch TIN if the base company TIN and branch suffix are stored reliably.

## 15. Items That Must Be Database-Backed

The following must not live only in application code:

- BIR form definitions and active/inactive form variants.
- Taxpayer obligations by legal type, taxpayer type, income tax regime, VAT status, withholding status, deduction method, and effective date.
- Filing frequency and due-date rules.
- Tax treatment/applicability decisions where the system selects VAT, percentage tax, EWT, FWT, exemption, zero-rating, or form obligations.
- Company compliance profile changes and effective dates.
- Tax code, ATC, VAT, EWT, FWT, and percentage tax code definitions/rates.
- Filed return status, filed date, filing channel, confirmation/reference numbers, and immutable filing package.
- Payment/remittance proof, bank/ROR/payment reference, payment method, penalties, and attachments.
- Amendment lineage and reason.
- MCIT carry-forward and application.
- NOLCO source/application/expiration/remaining balance.
- VAT carryover, deferred/disallowed input VAT, unpaid payable, settled payable, uncollected receivable, and recovered receivable adjustments.
- 2307/2306 generated certificate records and received certificate evidence.
- Book registration and CAS/CBA registration evidence.
- Export job history and acknowledgements for QAP, SAWT, SLSP, RELIEF, and DAT.
- RLS-scoped ownership and service-role-only computation outputs.

## 16. Items Explicitly Out Of Phase 1 Scope

Recommended owner decision wording for exclusions:

1. Compensation withholding tax, BIR Forms 1601C, 1604C, and 2316 are excluded from Phase 1 because payroll and employee compensation tax computation are not part of the current Phase 1 ERP foundation.
2. Fringe benefits tax and BIR Form 1603Q are excluded from Phase 1 unless payroll/fringe-benefit compensation processing is approved as a Phase 1 module. Ordinary final withholding certificates may still support 2306 for non-payroll final tax transactions.
3. Documentary stamp tax and BIR Forms 2000 and 2000-OT are excluded from Phase 1 unless PXL adds taxable instruments such as loans, shares, leases, insurance instruments, real property transfers, or other DST-triggering documents.
4. Local business tax, LGU filings, and RBELT-style local compliance are excluded from Phase 1 because they are not ordinary BIR return workflows and require a separate LGU compliance model.
5. Excise tax is excluded from Phase 1 because no excisable goods module exists.
6. Estate tax, donor's tax, capital gains tax, and one-time transfer taxes are excluded from Phase 1 because the current ERP scope does not include those taxpayer workflows.
7. Importation-specific VAT/customs workflows are excluded unless import purchasing/customs landed cost is approved. Ordinary purchase VAT remains in scope.
8. Treaty-relief, nonresident special-rate, and IPA incentive computations beyond storing effective-dated evidence are excluded unless owner approves special-taxpayer company support.
9. Cooperative/exempt/special-law company ITR support must be either approved through 1702-EX/special profile handling or formally excluded despite the broad entity list.

## 17. Documentation Contradictions Found

| Contradiction | Evidence | Impact | Required resolution |
|---|---|---|---|
| Broad user scope includes cooperative and professionals, while current architecture treats some special/exempt cases as limited/out of scope | Non-negotiable compliance scope vs existing ITR/form support | Developers may either overbuild or underbuild taxpayer profile and form logic | Owner must decide which entity types are actually Phase 1. |
| Existing form-code checks omit `1701A`, `1702EX`, `1702MX`, `1604F`, and `0605`, while Phase 1 claims broad taxpayer/form support | Migrations 005/015 and requested audit scope | Migration would freeze an incomplete form universe | Add `tax_form_definitions` or explicitly exclude omitted forms. |
| Current VAT tables do not fully match revised 2550Q April 2024 data needs | BIR 2550Q/RMC 68-2024 vs `vat_entries`/`vat_period_summaries` | VAT return generation can be wrong or incomplete | Add VAT adjustment/timing backing. |
| Existing tax credit documentation has historically referenced 2306/FWT as income tax credits in some places, while final withholding is generally not ordinary creditable withholding | Prior architecture discussion and current distinction | ITR credits may be overstated if 2306 is treated like 2307 | Keep 2306 separate from creditable tax schedule unless a specific legal case is configured. |
| `tax_calendar.period_covered` is free text while reports and filings require structured periods | Migration 005 | Filing automation and calendar generation may be unreliable | Add structured period fields/rules. |
| CAS registration exists but books registration is also required | `cas_registrations` vs BIR books registration sources | CAS/books readiness claim is incomplete | Add `book_registration_records` or clarify scope. |
| Migration 018 design currently solves adaptive workspace and audit artifacts but not tax obligation/rule metadata | Migration 018 specs vs compliance principles | No-hardcoded-tax-logic principle is not fully satisfied | Add rule/form/obligation tables. |

## 18. Supabase/RLS Implications

Required RLS/security treatment for new or hardened compliance objects:

| Object group | RLS requirement |
|---|---|
| Global tax metadata such as `tax_form_definitions` | Authenticated read-only policy; setup/admin-only mutation through privileged roles or service role. |
| Company-specific obligation rules and tax configurations | Company-scoped SELECT/INSERT/UPDATE by permission; no DELETE for authenticated users. |
| Tax filings and remittances | Company-scoped SELECT; insert/update only while draft/open; no authenticated update after filed/amended/voided/locked status. |
| Tax payment/evidence records | Company-scoped SELECT/INSERT; updates only before filing lock; no DELETE. |
| Tax filing amendments | Append-only or service/admin controlled; original filing immutable. |
| Tax computation outputs | Prefer service-owned insert/update; ordinary authenticated users can read by company and permission. |
| VAT adjustment schedules and MCIT/NOLCO schedules | Service-owned mutation where generated by posting/filing engine; manual adjustments require approval/audit. |
| Attachments and generated files | Company-scoped and linked to parent objects; no orphaned cross-company access. |
| Books/CAS registration records | Company/branch-scoped; restricted setup/compliance permissions. |
| Rule/config changes | Must create audit history; ordinary users must not mutate effective-dated tax setup without permission. |
| Frontend access | Never expose service role to frontend; all privileged computation/finalization must run server-side. |

Additional RLS policy requirement:

- Do not rely only on `company_id = ANY(auth.user_company_ids())` for tax setup mutation. Use specific permissions such as compliance setup, tax filing prepare, tax filing approve/file, tax payment record, tax export generate, and tax audit view where exact permission codes exist or are approved.

## 19. Recommended Change To Migration 018 Scope

Migration 018 should change before SQL implementation.

Current planned split:

- 018A missing documented tables
- 018B feature catalog + adaptive workspace tables
- 018C RLS policies for new tables + 12 no-policy tables
- 018D immutability/security cleanup
- 018E clean verification

Recommended revised split:

| Migration | Recommended scope |
|---|---|
| 018A | Existing missing documented Phase 1 tables from reconciliation. |
| 018B | Feature catalog and adaptive workspace tables, including `feature_definitions`. |
| 018C | PH compliance metadata and evidence hardening: `tax_form_definitions`, `taxpayer_obligation_rules`, `tax_filing_due_rules`, `tax_filing_payments`, `tax_filing_amendments`, `tax_exemption_certificates`, `mcit_credit_tracking`, `book_registration_records`, annual withholding filing support, and VAT adjustment backing as approved. |
| 018D | RLS policies for all new 018 tables plus the existing 12 no-policy tables. |
| 018E | Immutability, service-owned tax computation output protections, filed-return guards, amendment guards, and line/status cleanup. |
| 018F | Verification queries for 219 plus any approved compliance-hardening tables, no ghost tables, no missing RLS, no missing policy coverage, no hardcoded form constraints where metadata is required. |

If the owner does not want to increase Migration 018 table count, the alternative is to formally narrow Phase 1 compliance scope:

- Only ordinary VAT/NON-VAT SME support.
- Only 2550Q, 2551Q, 1601EQ, 1601FQ, 2307, 2306, QAP, SAWT, SLS/SLP/RELIEF, 1701Q, 1701, 1702Q, and 1702RT.
- Exclude 1701A, 1702-EX, 1702-MX, 1604E, 1604F, 0605 evidence automation, DST, FBT, compensation withholding, LGU/local taxes, importation VAT details, and special-law/exempt company taxpayers.

That narrowed scope would contradict the current broad compliance objective unless recorded as an owner decision.

## 20. Final GO / NO-GO For Migration 018 From PH Compliance Perspective

Final decision: NO-GO for Migration 018 as currently scoped.

Reason:

Migration 018 currently solves important foundation, adaptive workspace, RLS, audit, import/export, attachment, and generated document gaps. It does not yet solve the PH tax compliance metadata and evidence layer needed to satisfy the project rules:

- No hardcoded tax logic.
- Tax rules must be configurable.
- BIR changes must be handled by setup/configuration where practical.
- Tax treatment must be effective-dated.
- Filed returns must be immutable.
- Amendments must be traceable.
- Payments/remittances must have evidence.
- All tax decisions must be explainable.

Minimum requirements to change this to GO:

1. Add a normalized BIR form catalog or formally narrow form scope.
2. Add taxpayer obligation rules so form/workflow requirements are not hardcoded.
3. Add due-date/frequency rules or equivalent configurable metadata.
4. Add tax filing payment/remittance evidence.
5. Add amendment lineage.
6. Add MCIT carry-forward tracking.
7. Add revised 2550Q VAT adjustment/carryover backing.
8. Add book registration records.
9. Add 1701A, 1702-EX, 1702-MX, 1604F, 0605, and 1604E/1604F annual return handling if those forms remain Phase 1.
10. Record explicit exclusions for DST, FBT, compensation withholding, local business tax, excise, transfer taxes, complex treaty relief, importation-specific VAT, and unsupported special-taxpayer regimes.

Recommended owner action:

- Approve a focused compliance-hardening addition to Migration 018 before SQL starts.
- Do not start CRUD/UI for tax, accounting, sales, purchasing, or compliance screens until this foundation is reconciled.

Final statement:

PXL PH COMPLIANCE FOUNDATION IS STRONG BUT NOT YET FREEZE-READY. MIGRATION 018 SHOULD BE UPDATED BEFORE IMPLEMENTATION.
