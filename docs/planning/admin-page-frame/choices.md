# Admin Page Frame Program — Slice 0 choices

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Accepted.** Slice 0 complete. Slice 1 authorized only within [change-allowlist.md](change-allowlist.md).

These choices close the remaining Slice 0 contract questions. They do not authorize a general restyle. Evidence: [slice-0-evidence.md](slice-0-evidence.md). Authority: [plan.md](plan.md).

## Choice APF-001 — Page-frame API

**Accepted.**

Migrated Admin pages use `admin/shared/page` as the sole public page-frame composition API (`app/views/admin/shared/_page.html.erb`). The partial accepts explicit locals, renders the existing `shared/breadcrumbs` and `shared/page_header` partials, provides optional tools and required body regions, and yields feature-owned content.

A narrowly scoped helper (`app/helpers/admin_page_helper.rb`) validates the semantic width value and communicates the corresponding `.app-content` modifier to the application layout through `content_for`. `content_for` is internal width plumbing, not a second page composition API. Views must not set the width capture directly.

The helper is invoked from the page partial at the start of the nested render so the capture exists before `application.html.erb` reads it (same order as `content_for :title`). Do not call the helper from the layout after `yield`.

The helper accepts all four semantic modes (`narrow`, `standard`, `wide`, `workspace`). Slice 1 production call sites use only `standard` and `narrow` (APF-002).

The page frame does not replace or fork breadcrumbs, page header, form section, data table, empty state, definition list, or technical-details primitives.

## Choice APF-002 — Width escape

**Accepted.**

Unmigrated Admin pages retain the current `.app-content` behavior and its `--content-max: 72rem` ceiling. Do not change `--content-max` on `:root`. Default `.app-content` stays `min(100% - 2rem, 72rem)`. Width modifiers on the same `main.app-content` element override max-width for opted-in pages only.

A migrated page selects one validated semantic width through the page-frame API. `application.html.erb` applies the resulting modifier directly to `.app-content`. Width modifiers may change the centered content width but must not use `100vw`, negative-margin breakout, transforms, or a wrapper wider than its `.app-content` parent.

This contract applies only to the administrative application layout. The Ops and Register layouts are unchanged.

Slice 1 widths:

| Surface | Width |
|---|---|
| Adjustment Reasons index | `standard` |
| Adjustment Reason show | `standard` |
| New Adjustment Reason | `narrow` |
| Edit Adjustment Reason | `narrow` |

`_form` is body content of new/edit. It does not declare a page width.

## Choice APF-003 — Width values

**Accepted** with provisional measurements.

The `narrow`, `standard`, `wide`, and `workspace` semantic modes are locked. Their final rem measurements remain provisional pending implementation evidence. `standard` continues to resolve to the existing 72rem administrative ceiling during Slice 1.

Changing the inherited default or finalizing `wide` and `workspace` measurements requires a later recorded choice. It is not authorized by Slice 1.

## Choice APF-004 — Reference implementation

**Accepted.**

Slice 1 uses the Adjustment Reasons index/show/new/edit flow as its only production reference family. `_form` is included as the shared body of new/edit. No disposable fixture is created.

Users, Customers, Products, Store show, Home, hubs, history, reporting, purchasing Ops, and Register may provide Slice 0 evidence or non-regression coverage but are not Slice 1 migration targets.

## Choice APF-005 — Region order

**Accepted** as written in [plan.md](plan.md).

The canonical order is navigation context, page identity, optional page tools, and page body. Technical details remain subordinate within or after the body. Optional empty regions are omitted rather than rendered as empty wrappers (Adjustment Reasons must not emit an empty tools region).

Slice 1 may refine class names but may not change region ownership or order without reopening this choice.

## Choice APF-006 — Canvas and surface rules

**Accepted** as written in [plan.md](plan.md).

Breadcrumbs and page identity remain on the canvas. Surfaces indicate meaningful content or control grouping and are not added solely to repair spacing. Tables may use a flush surface, multi-control filters may use a padded tools surface, and technical details remain subordinate.

Slice 1 may tune spacing and border values but may not introduce a surface-around-every-section treatment.

## Choice APF-007 — Inventory widths

**Accepted** as provisional.

The inventory’s “likely width” values in [slice-0.md](slice-0.md) are planning hypotheses and do not grant implementation authority. Only the four Adjustment Reasons assignments in APF-002 are locked for Slice 1.

Every later production migration requires a separately accepted width assignment and change allowlist.

## Choice APF-008 — Evidence gate

**Accepted.**

The completed CSS geometry analysis in [slice-0-evidence.md](slice-0-evidence.md) is sufficient for the Slice 0 width gate, consistent with the UDS-5.0 fallback used when headed Chromium could not reach the development server.

Headed Chromium captures at 1920, 1440, 1280, 200% zoom, and 768 remain useful optional sign-off evidence. Their absence does not block Slice 1 unless the CSS geometry analysis exposes an unresolved width or overflow question.

Slice 0 does not require every inventory flow to be rendered at every viewport.
