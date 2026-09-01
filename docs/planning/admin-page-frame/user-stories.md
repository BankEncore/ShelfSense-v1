# Admin Page Frame Program — User stories

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Proposed.** Slice 0 evidence incomplete. **No implementation authority.**

Thin stories for later GitHub issues. Do not file these as issues solely because this file exists. Authority: [plan.md](plan.md).

---

## Slice 0 — Inventory, evidence, and contract

### US-APF-0-1 — Establish program authority

As an implementer, I need a program packet so later slices cite one plan instead of the superseded draft.

**Acceptance**

- [ ] `docs/planning/admin-page-frame/` exists with README, plan, slice-0, evidence stub, allowlist, stories, test-matrix, and adoption-outlook
- [ ] Status is Proposed; Slice 0 evidence incomplete; no implementation authority
- [ ] UDS-5.5 policy amendment uses the three-row authority table
- [ ] Cross-links from roadmap, planning README, UDS README, program-plan, ux-conventions, ux-adoption-template, migration-matrix, and docs/README
- [ ] The drafts file is a stub pointing here
- [ ] No production CSS, view, or route changes

### US-APF-0-2 — Reconcile inventory to live routes

As a reviewer, I need every user-facing administrative flow matched to a live route so Slice 1 cannot expand silently.

**Acceptance**

- [ ] [slice-0.md](slice-0.md) inventory checked against the repository
- [ ] Extras, missing templates, and renamed paths recorded in [slice-0-evidence.md](slice-0-evidence.md)
- [ ] Home remains deferred; audit/history remain coordinated with UDS-6
- [ ] No production changes

### US-APF-0-3 — Record viewport evidence

As a reviewer, I need Chromium observations of the evidence set so width modes are not guessed in Slice 1.

**Acceptance**

- [ ] Users index, Customers index, Products index, Adjustment Reason show/form, and Store show observed at 1920×1080, 1440×900, 1280×720, 200% at 1280, and 768px
- [ ] Observations live in [slice-0-evidence.md](slice-0-evidence.md)
- [ ] Unmigrated `72rem` default is confirmed or an explicit defect is recorded
- [ ] No production changes

### US-APF-0-4 — Lock Slice 1 API and allowlist

As an implementer, I need the page-frame API, width-escape mechanism, and file list before writing `admin/page`.

**Acceptance**

- [ ] API shape recorded (layout partial / `content_for` / combination) and it orchestrates existing breadcrumbs and page header
- [ ] Width-escape mechanism recorded; no `100vw` punch-out; Ops `.ops-content` untouched
- [ ] Fixture needed or not needed is recorded, with retirement if needed
- [ ] [change-allowlist.md](change-allowlist.md) Slice 1 table locked
- [ ] Open decisions that still block Slice 1 are none, or explicitly deferred without blocking the foundation
- [ ] No production changes

---

## Slice 1 — Foundation and Adjustment Reasons

Do not start these stories until Slice 0 acceptance is checked.

### US-APF-1-1 — Ship the orchestrating page frame

As a staff user on Adjustment Reasons, I need the page to declare a semantic width and follow the canonical region order without a second header implementation.

**Acceptance**

- [ ] `admin/page` renders `shared/breadcrumbs` and `shared/page_header`
- [ ] Unmigrated pages keep `72rem` `.app-content` behavior
- [ ] Opted-in pages select `narrow` / `standard` / `wide` / `workspace` through the locked API
- [ ] No Ops, Register, print, or NavigationCatalog changes
- [ ] Frozen suites in [test-matrix.md](test-matrix.md) pass without rewritten workflow assertions

### US-APF-1-2 — Migrate Adjustment Reasons through the frame

As a staff user, I need Adjustment Reasons index, show, new, and edit to fully consume the accepted frame.

**Acceptance**

- [ ] Those five templates go through `admin/page` for identity, breadcrumbs, width, and body
- [ ] No metric strip or technical-details block is added solely for completeness
- [ ] Create/edit submit the same parameters and redisplay validation as today
- [ ] Deactivate/reactivate and system-protected behavior unchanged
- [ ] New composition tests cover the frame on this flow

### US-APF-1-3 — Non-regression on evidence surfaces

As a reviewer, I need Users, Customers, Products, and Store to look and behave as they do today except for any unavoidable shared-CSS impact documented in the PR.

**Acceptance**

- [ ] Those templates are not migrated
- [ ] Product composition tests, customer admin, store admin, and grouped-nav tests pass
- [ ] Viewport spot-check recorded for those surfaces
- [ ] Any disposable fixture is retired or scheduled in Slice 1 closeout with no standing extra Admin destination

### US-APF-1-4 — Closeout gate

As a maintainer, I need an explicit stop so family migration does not start from leftover Slice 1 energy.

**Acceptance**

- [ ] Frame accepted or defects recorded
- [ ] Product-consuming-the-frame is a separately approved slice or explicitly deferred
- [ ] Next adoption is recorded as feature-led or a later bounded family packet
- [ ] [adoption-outlook.md](adoption-outlook.md) is still marked not authorized
