# Documentation Audit

## Objective
To ensure documentation reflects the TRUE state of the codebase and architecture. Superseded AI plans or dual-architecture documents must be removed.

## Current State
- `docs/architecture/ERP_TOOLBAR_STANDARD.md` (Accurate)
- `docs/qa/COMPANY_LIST_ERPLISTHELPER_QA.md` (Accurate)
- `docs/architecture/certification/*` (New, Accurate)

## Findings
- Several old artifact files from earlier chat prompts remain in the AI's internal scratchpad memory. While not in the github repo, the conceptual knowledge is somewhat fragmented.
- The `docs/` folder in the repository is generally well-maintained and structured thanks to prior certification phases.

## Mandate
- Never keep two documents describing different approaches. If a new approach (e.g. `ErpListHelper 2.0`) supersedes an old approach (`SetupListHelper`), the old approach documentation MUST be deleted or explicitly marked as `[DEPRECATED]`.
