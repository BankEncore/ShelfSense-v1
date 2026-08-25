# UDS-5 user stories

Status: **Proposed** (5.0–5.3 complete on `uds-5-administrative-composition`; 5.0 gate Passed; later slices outlined)

Thin stories mapped to GitHub issues [#44](https://github.com/BankEncore/ShelfSense-v1/issues/44)–[#50](https://github.com/BankEncore/ShelfSense-v1/issues/50). Do not file these as additional issues. Authority: [uds-5-plan.md](uds-5-plan.md).

---

## UDS-5.0 — Packet, labels, and compact-nav gate

### US-UDS-5.0-1 — Establish UDS-5 authority

As an implementer, I need a program packet so later slices cite one plan instead of GitHub issue text.

**Acceptance**

- [x] `uds-5-plan.md` and this file exist and state branch/merge sequencing
- [x] UDS README, program-plan, roadmap, planning README, and ux-conventions point at UDS-5
- [x] Shared exclusions and the 5.2 locked boundary are recorded
- [x] No production header or Product template changes in this slice

### US-UDS-5.0-2 — Label mockup regions

As a reviewer, I need each inspirational region labelled Proposed or Inspirational/deferred so UDS-5 does not copy the sidebar or Cmd+K.

**Acceptance**

- [x] Product mockup: sidebar, espresso topbar, and Cmd/Ctrl+K are Inspirational/deferred (UDS-7)
- [x] Product mockup: identity header, metric strip, panels, table hierarchy, sectioned form, and serif titles are Proposed for UDS-5
- [x] Receipt mockup: investigation layout is Proposed for UDS-6; printed receipt stays locked
- [x] Palette mockup: token swatches are Implemented (UDS-1); espresso shell samples stay deferred

### US-UDS-5.0-3 — Record Product and header baselines

As a reviewer, I need Chromium observations so 5.1–5.4 can be compared against today’s screens.

**Acceptance**

- [x] Structured observations at 390×844, 768×1024, and 1440×900
- [x] Surfaces: production header; Product index; Product show with/without cover; long title; large variant collection; Product edit with validation errors; catalog search; bibliographic review
- [x] Observations live in [uds-5.0-gate-evidence.md](uds-5.0-gate-evidence.md)

### US-UDS-5.0-4 — Dual compact-nav prototype gate

As a reviewer, I need to compare expanded nav with compact disclosures and an optional area row using the live catalog.

**Acceptance**

- [x] Disposable signed-in route renders `variant=expanded|disclosures|area_row`
- [x] All three variants emit the same destination hrefs for a given user and store
- [x] `as_controller` simulates current destination without changing `NavigationCatalog`
- [x] Native `<details>` keep every destination in the DOM with JavaScript disabled
- [x] Profiles A/B with and without current store match UDS-4.1 visibility
- [x] Keyboard, 320px, 200%/400% zoom, and header-height comparison are recorded
- [x] Pass or allowed fail is recorded; 5.3 is not blocked on a fail

---

## UDS-5.1 — Typography and composition primitives

### US-UDS-5.1-1 — Package type roles and primitives

As an implementer, I need reusable type and composition primitives so Product slices do not set `font-family` per template.

**Acceptance**

- [x] Local Source Serif 4 (no CDN); `--font-serif` and `--font-mono`; `--font-receipt` remains distinct
- [x] Role-based type with per-role line height
- [x] Serif limited to approved display roles via tokens/role classes
- [x] `.surface` has one documented meaning plus a compatibility modifier
- [x] Page-header, form-section, metric-strip, table-hierarchy, and admin-form footer prototype as listed in [#45](https://github.com/BankEncore/ShelfSense-v1/issues/45)
- [x] Existing domain/workflow tests unchanged and passing

---

## UDS-5.2 — Compact administrative navigation presentation

### US-UDS-5.2-1 — Ship compact presentation of the existing catalog

As a staff user, I need the existing grouped destinations in compact header form after the 5.0 gate passes.

**Acceptance**

- [x] 5.0 gate has a recorded passing compact pattern, or an explicit keep-expanded decision
- [x] Allowlist only: layout, `_admin_primary_nav.html.erb`, CSS, tests, docs
- [x] Locked boundary in [uds-5-plan.md](uds-5-plan.md) is honored
- [x] Every destination remains reachable with JavaScript disabled
- [x] Light chrome only
- [x] Disposable 5.0 route retired when production presentation ships (or in 5.5 if expanded is kept)

---

## UDS-5.3 — Product index and details

### US-UDS-5.3-1 — Compose index and show

As a merchandiser, I need Product index and details to use the UDS-5 primitives without new queries or operational-column confusion.

**Acceptance**

- [x] Index: composed header, filter grouping, table hierarchy
- [x] Show: identity header, metric strip, identity and publication panels
- [x] Cover remains a thumbnail
- [x] No new audit queries
- [x] Existing domain/workflow tests unchanged and passing

---

## UDS-5.4A — Catalog search and form

### US-UDS-5.4A-1 — Compose search and the product form

As a merchandiser, I need catalog search and the product form to use sectioned composition without behavior changes.

**Acceptance**

- [ ] Search header, query grouping, and result table hierarchy
- [ ] Sectioned form with related-field grids and sticky admin-form actions
- [ ] Params, ranking, and validation unchanged

---

## UDS-5.4B — Bibliographic review presentation

### US-UDS-5.4B-1 — Compose comparison layout only

As a merchandiser, I need current vs candidate vs selected fields grouped by family without changing apply behavior.

**Acceptance**

- [ ] Comparison layout only
- [ ] ApplyCandidate, provenance, and concurrency tests frozen
- [ ] Existing domain/workflow tests unchanged and passing

---

## UDS-5.5 — Evidence and closeout

### US-UDS-5.5-1 — Record evidence and standing adoption

As a reviewer, I need serif and composition decisions written down so later features adopt primitives without a UDS sweep.

**Acceptance**

- [ ] Serif adopt / adjust / reject with evidence
- [ ] Matrix and conventions updated for the Product family and compact nav
- [ ] Standing feature-led adoption rule in `ux-conventions.md` and `ux-adoption-template.md`
- [ ] Print non-regression recorded

---

## Cross-cutting review

### US-UDS-5-R1 — Shells remain distinct

- [ ] Administrative composition does not fold ops or Register into the admin shell
- [ ] Printed receipt selectors remain frozen
- [ ] UDS-7 sidebar/search is not scheduled
