# Phase 3 Stage 1: Company Regression QA

**Date:** June 26, 2026
**Scope:** Verify that Framework Refactoring Commits A, B, and C did not break the Company module Golden Reference or legacy modules.

## QA Checklist & Results

| Status | Test Case | Notes |
| :---: | :--- | :--- |
| ✅ | 1. Company List loads | `DOMContentLoaded` fallback in router operates flawlessly for legacy `SetupListHelper`. |
| ✅ | 2. Company List View button works | Router correctly navigates and fetches `form.html` and script. |
| ✅ | 3. Company List Edit button works | Router accurately resolves `#/setup/company-setup/edit`. |
| ✅ | 4. Company New loads | Form loads via standard SPA router fallback. |
| ✅ | 5. Company Create saves successfully | `ErpFormHelper` logic unchanged. Save API persists correctly. |
| ✅ | 6. Company Save & New works | Form resets securely after successful insert. |
| ✅ | 7. Company Edit loads existing data | Object mapping from DB populates form predictably. |
| ✅ | 8. Company Edit saves changes | Updates hit Supabase effectively with correct payload. |
| ✅ | 9. Company View loads and is read-only | Form loads safely, inputs disabled via `determineMode()`. |
| ✅ | 10. Active Company selector still works | NavBar interactions unaffected by router updates. |
| ✅ | 11. Currency List still loads using `init()` lifecycle | Modern `init()` route explicitly hit bypassing fallback. |
| ✅ | 12. Other legacy modules still load via fallback | Tested sample Setup modules. |
| ✅ | 13. Browser console has no new errors | Clean console output during transitions. |

## Conclusion
**PASS**. No bugs were introduced during the Stage 1 router and list helper refactoring. 
The SPA router safely handles both legacy (`DOMContentLoaded`) and modern (`init()`) module lifecycles. `SetupListHelper` safely skips the scoping step for components that do not pass `requireActiveCompany: true`. The Company module maintains its Golden Certification status.
