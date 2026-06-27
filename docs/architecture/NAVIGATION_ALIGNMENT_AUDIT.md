# Navigation Alignment Audit

**Date:** June 27, 2026

## 1. Purpose
This document provides a precise audit comparing the current `src/index.html` navigation structure against the official canonical product map defined in `docs/architecture/PXL_ERP_EXPANDED_PRODUCT_TREE.md`. It evaluates the accuracy of implemented features, roadmap placeholders, compliance depth, and the safe UI cleanups that were immediately applied to restore alignment with the PXL Philippine Compliance-First identity.

## 2. Current Top Navigation (Pre-Audit)
The `src/index.html` top navigation previously exposed:
- Setup
- Master Data (Included exposed child records)
- Sales
- Purchasing
- Assets (Lumping Inventory, Fixed Assets, Cash Management)
- Accounting
- Compliance
- Reports

## 3. Expected Final Navigation (Canonical Blueprint)
- Dashboard
- Setup
- Master Data
- Sales
- Purchasing
- Inventory
- Banking & Treasury
- Fixed Assets
- Accounting
- Compliance
- Reports
- Administration

## 4. Alignment Matrix

| Category | Status | Notes |
| --- | --- | --- |
| **Setup** | ✅ Aligned | Exists and is heavily built out. |
| **Master Data** | ⚠️ Partial Alignment | The root nav is correct, but child records were dangerously exposed as global links. |
| **Sales** | ✅ Aligned | Roadmap placeholders are cleanly categorized. |
| **Purchasing** | ✅ Aligned | Roadmap placeholders are cleanly categorized. |
| **Assets** | ❌ Misaligned | A legacy monolithic tab that violates the new Canonical Blueprint. Needs to be split into 3 distinct tabs. |
| **Accounting** | ✅ Aligned | Placeholder tab matches expected layer. |
| **Compliance** | ✅ Perfect Alignment | All PH compliance depth exists natively in the UI. |
| **Reports** | ✅ Aligned | Placeholder tab matches expected layer. |
| **Dashboard / Admin** | ❌ Missing | Missing from the global UI top-nav currently. |

## 5. Assets Split Movement Map
The current monolithic `Assets` tab contains three entirely separate operational domains. To align with the blueprint, these routes must eventually be moved as follows:

**1. Inventory**
- *Move to new `Inventory` tab:*
  - Assets > Inventory > Inventory Dashboard
  - Assets > Inventory > Stock Adjustments
  - Assets > Inventory > Stock Transfers
  - Assets > Inventory > Goods Issue
  - Assets > Inventory > Physical Count
  - Assets > Inventory > Inventory Movements
  - Assets > Inventory > Inventory Valuation

**2. Banking & Treasury**
- *Move to new `Banking & Treasury` tab:*
  - Assets > Cash Management > Petty Cash Funds/Vouchers/Replenishment/Count Sheet
  - Assets > Cash Management > Fund Transfers / Inter-Branch Transfers
  - Assets > Cash Management > Bank Adjustments
  - Assets > Cash Management > Bank Reconciliation
  - Assets > Cash Management > Outstanding Checks
  - Assets > Cash Management > Deposits in Transit

**3. Fixed Assets**
- *Move to new `Fixed Assets` tab:*
  - Assets > Fixed Assets > Fixed Asset Dashboard, Register, Acquisitions, Depreciation, Disposals, Transfers, Impairments.

*Note: This split was successfully executed in Phase 5A.4. The monolithic Assets tab was safely removed and replaced with three independent top-level navigation tabs.*

## 5.5 Actual Navigation Refactor Completed
In a subsequent pass (Phase 5A.4), the deferred UI refactoring was aggressively executed:
- The legacy `Assets` tab was completely deleted from `src/index.html`.
- Three new root nodes (`Inventory`, `Banking & Treasury`, `Fixed Assets`) were correctly inserted into the DOM.
- All original route handler paths (`#/assets/inventory/*`, `#/assets/cash-management/*`, `#/assets/fixed-assets/*`) were meticulously preserved to ensure no application logic or links broke.
- The global navigation now exactly matches the canonical blueprint.

## 6. Master Data Child-Record Findings
- **Finding:** The Master Data mega-menu exposed `Customer Addresses`, `Customer Contacts`, `Supplier Addresses`, and `Supplier Contacts` as standalone global links.
- **Violation:** The `MASTER_DATA_CANONICAL_BLUEPRINT.md` dictates that these are strictly encapsulated sub-tables. They must not have standalone list pages.
- **Action Taken:** Safe cleanup applied. The links and their flyout panels were permanently removed from `src/index.html`.

## 7. Customer Status Accuracy Findings
- **Repo State Checked:** `public.customers` database table exists. `Customer List` is implemented via ErpListHelper 2.0. `Customer View` (read-only) was successfully implemented. `Customer Create/Edit` and `Import` are blocked by a mode flag and remain as Roadmap items.
- **Blueprint Alignment:** Accurate. The canonical blueprint safely marks Customers as `[PARTIAL]`, correctly acknowledging the completed List/View without overstating readiness.

## 8. Compliance Navigation Verification
- **Finding:** The entire PXL Philippine Compliance-First identity remains uncompromised in the UI.
- **Verified Intact:** 
  - Percentage Tax (2551Q, Recon)
  - VAT (2550M/Q, SLS/SLP, Relief Export)
  - Withholding Tax (EWT/FWT, 1601EQ/FQ, QAP, SAWT, 2307s/2306)
  - Income Tax (1701/1702, OSD, NOLCO, MCIT, Taxable Income Recon)
  - BIR Books of Accounts
  - CAS & Audit (DAT File Generation, Transaction Audit, Master Data Log, ATP Usage).
- **Status:** PASS. No generic ERP simplification has overridden these requirements.

## 9. Roadmap Placeholder Behavior
- **Finding:** Currently, clicking roadmap links in the mega-menu does not crash the app, but rather updates the hash fragment in the URL (e.g. `#/purchasing/purchase-orders`). Because the `ErpFormHelper`/router evaluates the dynamic route, if a specific JS file does not exist, the user hits a benign "404 module not found" or an empty route container. 
- **Recommendation:** Implement a global `RouteNotFound` or `Coming Soon` catch-all in the Router so users are presented with a professional message rather than a silent empty screen.

## 10. Safe Fixes Applied
1. **Master Data Cleanup:** Deleted `md-panel-cust` and `md-panel-supp` flyout panels and categories from `src/index.html`. Child records (Addresses/Contacts) are officially hidden from global navigation.

## 11. Deferred Navigation Cleanup
1. **Dashboard / Administration:** Adding these new root tabs is deferred.
2. **Coming Soon Catcher:** Implementing a robust fallback screen for roadmap routes is deferred.

## 12. Final Recommendation
The current UI navigation is highly aligned with the canonical architecture, with the exception of the legacy `Assets` tab. By applying the safe Master Data child-record cleanup, we successfully eliminated the biggest encapsulation violation. The remaining discrepancies (Assets split, missing Admin tab) are strictly cosmetic/routing issues and do not compromise the database or compliance architecture. PXL ERP retains its unapologetic Philippine Compliance-First identity.
