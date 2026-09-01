# Admin Page Frame Program — User stories

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Accepted.** Slice 0 complete. Slice 1 **Implemented on `apf-development`**.

Thin stories for later GitHub issues. Authority: [plan.md](plan.md), [choices.md](choices.md).

---

## Slice 0 — Inventory, evidence, and contract

**Complete.**

### US-APF-0-1 — Establish program authority

As an implementer, I need a program packet so later slices cite one plan instead of the superseded draft.

**Acceptance**

- [x] `docs/planning/admin-page-frame/` exists with README, plan, choices, slice-0, evidence, allowlist, stories, test-matrix, and adoption-outlook
- [x] Status is Accepted; Slice 0 complete; Slice 1 allowlisted
- [x] UDS-5.5 policy amendment uses the three-row authority table
- [x] Cross-links from roadmap, planning README, UDS README, program-plan, ux-conventions, ux-adoption-template, migration-matrix, and docs/README
- [x] The drafts file is a stub pointing here
- [x] No production CSS, view, or route changes in Slice 0

### US-APF-0-2 — Reconcile inventory to live routes

As a reviewer, I need every user-facing administrative flow matched to a live route so Slice 1 cannot expand silently.

**Acceptance**

- [x] [slice-0.md](slice-0.md) inventory checked against the repository
- [x] Extras, missing templates, and renamed paths recorded in [slice-0-evidence.md](slice-0-evidence.md)
- [x] Home remains deferred; audit/history remain coordinated with UDS-6
- [x] No production changes

### US-APF-0-3 — Record viewport evidence

As a reviewer, I need observations of the evidence set so width modes are not guessed in Slice 1.

**Acceptance**

- [x] Users index, Customers index, Products index, Adjustment Reason show/form, and Store show observed via CSS geometry and templates (APF-008)
- [x] Observations live in [slice-0-evidence.md](slice-0-evidence.md)
- [x] Unmigrated `72rem` default confirmed
- [x] No production changes

### US-APF-0-4 — Lock Slice 1 API and allowlist

As an implementer, I need the page-frame API, width-escape mechanism, and file list before writing `admin/shared/page`.

**Acceptance**

- [x] API shape recorded (APF-001): `admin/shared/page` orchestrates breadcrumbs and page header
- [x] Width-escape recorded (APF-002): modifier on `main.app-content`; no `100vw`; Ops untouched
- [x] Fixture: none (APF-004)
- [x] [change-allowlist.md](change-allowlist.md) Slice 1 table locked
- [x] APF-001–APF-008 recorded in [choices.md](choices.md)
- [x] No production changes

---

## Slice 1 — Foundation and Adjustment Reasons

Authorized within the locked allowlist. **Complete.**

### US-APF-1-1 — Ship the orchestrating page frame

As a staff user on Adjustment Reasons, I need the page to declare a semantic width and follow the canonical region order without a second header implementation.

**Acceptance**

- [x] `admin/shared/page` renders `shared/breadcrumbs` and `shared/page_header`
- [x] Width helper runs from the page partial; layout reads `content_for` onto `main.app-content`
- [x] Unmigrated pages keep `72rem` `.app-content` behavior (no modifier class; `:root --content-max` unchanged)
- [x] Helper accepts `narrow` / `standard` / `wide` / `workspace`; production call sites use `standard` / `narrow` only
- [x] Empty tools region is omitted
- [x] No Ops, Register, print, or NavigationCatalog changes
- [x] Frozen suites in [test-matrix.md](test-matrix.md) pass without rewritten workflow assertions

### US-APF-1-2 — Migrate Adjustment Reasons through the frame

As a staff user, I need Adjustment Reasons index, show, new, and edit to fully consume the accepted frame.

**Acceptance**

- [x] Index/show/new/edit go through `admin/shared/page` for identity, breadcrumbs, width, and body
- [x] Index and show use `standard`; new and edit use `narrow`; `_form` does not declare width
- [x] No metric strip, tools region, or technical-details block is added solely for completeness
- [x] Create/edit submit the same parameters and redisplay validation as today
- [x] Deactivate/reactivate and system-protected behavior unchanged
- [x] New composition tests cover the frame on this flow

### US-APF-1-3 — Non-regression on evidence surfaces

As a reviewer, I need Users, Customers, Products, and Store to look and behave as they do today except for any unavoidable shared-CSS impact documented in the PR.

**Acceptance**

- [x] Those templates are not migrated
- [x] An unmigrated page has no `.app-content--*` width modifier
- [x] Product composition tests, customer admin, store admin, and grouped-nav tests pass
- [x] Viewport spot-check recorded for those surfaces
- [x] No disposable fixture exists

### US-APF-1-4 — Closeout gate

As a maintainer, I need an explicit stop so family migration does not start from leftover Slice 1 energy.

**Acceptance**

- [x] Frame accepted or defects recorded
- [x] Product-consuming-the-frame is a separately approved slice or explicitly deferred
- [x] Next adoption is recorded as feature-led or a later bounded family packet
- [x] [adoption-outlook.md](adoption-outlook.md) is still marked not authorized
