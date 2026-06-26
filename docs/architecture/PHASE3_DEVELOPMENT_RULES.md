# Phase 3 Development Rules

**Date:** June 26, 2026

## Objective
To strictly govern the execution of the Phase 3 Master Data build-out. These rules ensure absolute adherence to the architectural foundation and prevent technical debt accumulation.

## Core Rules

1. **No New Framework Redesign**
   - The ERP Form, ERP List, and SPA Router frameworks are FROZEN. No modifications to `erp-form.css`, `erp-list.css`, `erp-form-helper.js`, or `setup-list-helper.js` are allowed without explicit Product Owner approval.

2. **Company is the Golden Reference**
   - Every module must visually and operationally match the density, typography, and professional aesthetic of the Company module. 

3. **Build One Module at a Time**
   - Multitasking leads to fragmented architecture. Complete one entity end-to-end (List, View, Create, Edit) before beginning the next. Follow the `MASTER_DATA_BUILD_ORDER.md` strictly.

4. **Product Owner QA Checkpoint**
   - Every module must pass manual Product Owner QA before it can be considered Golden Certified and before the next module begins.

5. **Mandatory Browser QA**
   - Do not assume code works because it compiles. Do not assume behavior by reading code. Every change must be verified in the running browser environment (List rendering, Routing, Save logic).

6. **No Architecture Shortcuts**
   - Every module must implement the full standard lifecycle (`init()` function, RLS security, Database constraints, Golden UI).

7. **No Breaking Changes**
   - Migrations must be additive or cleanly backward compatible where possible. Do not break existing data flows.

8. **No Duplicated Business Logic**
   - Rely on Database Triggers/Functions for core rules, and Framework Helpers for UI interactions. 

9. **Compliance First**
   - Ensure the entity schema adequately captures the data required for Philippine compliance (TIN, RDO, ATC, etc.) as defined in the `COMPLIANCE_COVERAGE_MATRIX.md`.

10. **Accounting First**
    - The ERP is built for accountants. Prioritize data accuracy, audit trails (`created_at`, `created_by`, `deleted_at`), and dense information display over flashy visual trends.

11. **Long-Term Maintainability over Speed**
    - Take the time to implement correctly. The architecture built today must survive the next 10 years of feature expansion.
