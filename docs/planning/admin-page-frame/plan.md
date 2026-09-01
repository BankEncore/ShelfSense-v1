# Admin Page Frame Program — Plan

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Proposed.** Slice 0 evidence incomplete. **No implementation authority.**

Companions: [slice-0.md](slice-0.md), [change-allowlist.md](change-allowlist.md), [test-matrix.md](test-matrix.md), [UDS-5](../ux-design-system/uds-5-plan.md), [ux-conventions.md](../../ux-conventions.md).

## Two decisions

1. ShelfSense needs a shared Admin page-frame contract.
2. ShelfSense does not yet authorize a page-by-page restyle.

## Goal

Give administrative pages one enforceable composition layer between the global shell and feature views: semantic width modes, a predictable region order, and orchestration of existing shared partials — without replacing Warm Parchment, ActionButtonHelper, UDS-5 primitives, or the Ops and Register shells.

## Deliverable (authorized program)

> Adjustment Reasons and the shared Admin page-frame API use intentional width and a consistent region order, while unmigrated pages keep today’s `72rem` `.app-content` behavior, and no unrelated family is restyled.

## UDS-5.5 policy amendment

UDS-5.5 recorded standing **feature-led adoption**: existing screens adopt primitives when the feature that owns them is next in scope; do not sweep unrelated templates in a UDS PR.

This program supersedes that rule only for establishing the shared page-frame API, semantic width modes, and the bounded reference migrations explicitly authorized here. It does not authorize a general restyle of unrelated templates. After the frame gate passes, existing surfaces adopt the frame through separately approved family or feature slices. Feature-led adoption remains authoritative for domain-specific composition, action semantics, and other visual changes.

| Change | Authority |
|---|---|
| Shared frame and width infrastructure | Admin Page Frame Program |
| Explicit reference migrations | Bounded program slice (Slice 1: Adjustment Reasons only) |
| Remaining view adoption | Later feature or separately approved family slice |

## Locked decisions

1. **Unmigrated default stays `72rem`.** `.app-content` must not become `wide` globally. Pages that have not opted into the frame keep today’s computed width. Making `wide` the authenticated default is a post–Slice 1 decision, not a Slice 1 implication.

2. **`admin/page` orchestrates existing partials.** The frame owns region order and width. It renders `shared/breadcrumbs` and `shared/page_header`. It does not introduce a second page-header, a second breadcrumb implementation, alternative data-table markup, new form-section semantics, or a new technical-details component.

   ```text
   admin/page
   ├── renders shared/breadcrumbs
   ├── renders shared/page_header
   ├── provides page-tools region
   └── yields page body
   ```

3. **Width escape is opt-in on the Admin layout.** Nested yield inside `.app-content` cannot exceed `--content-max` (`72rem`) today. Slice 0 must record the mechanism (`content_for`, a `main` modifier, or an equivalent explicit slot). Do not use `100vw` or negative margins to punch out of the container. Ops `.ops-content` stays untouched.

4. **Slice 1 production set is Adjustment Reasons only.** `index`, `show`, `new`, `edit`, and `_form`. Users, Customers, Products, and Store are Slice 0 evidence surfaces and Slice 1 **non-regression** surfaces, not migrations.

5. **Disposable fixture only if needed.** If Adjustment Reasons cannot exercise `wide`, `workspace`, or the tools region, Slice 1 may add a test-only fixture or a route that Slice 1 closeout retires. Do not repeat `GET /admin/uds5_composition_prototype`. Do not wrap Product to prove missing regions.

6. **Fully consumes the frame** means a migrated page uses `admin/page` for identity, breadcrumbs, width, and body. It does not mean adding metric strips, tools, or technical details the flow does not already have.

7. **No fourth wrapper generation.** A page is either unmigrated (today’s assembly) or fully consumes the accepted frame. Migrated pages must not also carry local page-level `max-width`, a second `h1`, or a parallel header.

8. **Closeout gate after Slice 1** before any further adoption, including Product consuming the frame.

## Canonical width modes

Views that opt in select a width mode through the page-frame API. They do not add arbitrary page-level `max-width` declarations.

| Page state | Width behavior |
|---|---|
| Unmigrated page | Existing `72rem` `.app-content` behavior |
| Migrated ordinary page | Explicit `standard`, probably equivalent to the current `72rem` |
| Migrated short page | Explicit `narrow` |
| Migrated data-heavy page | Explicit `wide` |
| Migrated management/comparison page | Explicit `workspace` |

| Mode | Intended use | Initial contract (provisional rem values) |
|---|---|---|
| `narrow` | Sign-in, selection, confirmation, short configuration forms | `min(100% - gutters, 44rem)` |
| `standard` | Ordinary record pages and simple CRUD | `min(100% - gutters, 72rem)` |
| `wide` | Searchable indexes, records with related collections, long configuration | `min(100% - gutters, 90rem)` |
| `workspace` | Hubs, comparisons, reconciliation, management workspaces | Full available width with bounded responsive gutters |

Exact maximums are provisional until Slice 0 viewport evidence. Semantic modes are the contract; rem values may be tuned before Slice 1 locks them.

## Page families

Contracts below describe the grammar. They do not authorize migrating those families.

### Index

Find, assess, and enter a collection or create a new record.

Breadcrumbs → page header + create action → filter/search tools when present → optional result summary → table or collection → pagination when present.

- Prefer `wide` for migrated indexes; unmigrated indexes stay at `72rem` until they opt in.
- Place multi-control filters inside one tools surface.
- Distinguish an empty collection from an empty filtered result.
- Keep tabular data tabular and horizontally scrollable.
- Keep create as the page-level primary action.
- Do not place a second page title inside the result surface.

### Record

Understand one entity, its state, and available actions.

Breadcrumbs → identity header + status + actions → optional key metrics → primary information panels → related records or activity → technical details.

- Choose `standard` for simple records and `wide` for related collections.
- Split long definition lists by user-meaningful subject.
- Use a metric strip only when a few facts materially orient the user.
- Keep UUID, lock version, and timestamps subordinate.
- Show activity/history as a distinct region, not inside technical details.

### Form

Create or edit one entity safely.

Breadcrumbs → page header → error summary → grouped form sections → action area.

- Short forms use `narrow`; long forms use `standard` or `wide` with responsive grids.
- Every field belongs to a named section when the form is more than a few fields.
- Related fields may share a row; unrelated fields do not merely fill horizontal space.
- Errors remain linked to fields; submitted values remain visible.
- Cancel returns to show for edit and index for create.
- Sticky footers are opt-in for long forms, not automatic.

### Hub

Assess an area and choose the next work item. **Not a Slice 1 target.** See [adoption-outlook.md](adoption-outlook.md).

### Workflow/review

Complete a bounded consequential or comparative task. **Not a Slice 1 target** except insofar as Adjustment Reasons create/edit is an ordinary form, not a consequence workflow.

## Region order

```text
Admin page
├── Navigation context
│   └── Breadcrumbs, when the page is below a top-level destination
├── Page identity
│   ├── Optional eyebrow
│   ├── Title
│   ├── Optional subtitle and metadata
│   ├── Optional status
│   └── Primary page actions
├── Optional page tools
│   ├── Search
│   ├── Filters
│   └── View controls
└── Page body
    ├── Primary task or record content
    ├── Optional supporting content
    └── Subordinate technical details
```

Proposed structural class names (provisional until Slice 1): `.admin-page`, `.admin-page__context`, `.admin-page__header`, `.admin-page__tools`, `.admin-page__body`. Optional composition primitives: `.section-stack`, `.cluster`, `.content-grid` and modifiers. These are layout primitives, not domain components.

## Canvas and surface rules

| Content | Default treatment |
|---|---|
| Breadcrumbs | Canvas |
| Page header | Canvas |
| One simple search control | Canvas or tools region |
| Multi-control filters | Padded surface |
| Data table | Flush surface when a boundary aids grouping |
| Named record panel | Padded surface |
| Long undifferentiated definition list | Prohibited target state |
| Empty state | Replaces primary result surface |
| Technical metadata | Collapsed subordinate region |
| Every ordinary section | No automatic surface |

Adjacent surfaces must express distinct semantic regions. A surface may not be added solely to repair inconsistent vertical margins.

## Authorized slices

### Slice 0 — Inventory, evidence, and contract

No production changes. See [slice-0.md](slice-0.md).

Deliverables: live-route/view reconciliation; rendered evidence; locked page families and width semantics; locked region order and canvas/surface rules; page-frame API decision; width-escape mechanism; exact Slice 1 allowlist; policy amendment (this document); test inventory.

### Slice 1 — Foundation and reference gate

Production scope remains bounded. **Do not start until Slice 0 is complete.**

Likely scope (provisional; lock in [change-allowlist.md](change-allowlist.md) at Slice 0 closeout):

- application layout opt-in width hook only
- one `admin/page` layout partial that orchestrates existing shared partials
- minimal helper support if the API requires it
- narrowly scoped Admin composition CSS (no Ops, POS, or print selector changes)
- tests for the frame
- Adjustment Reasons index/show/new/edit
- optional disposable fixture for width modes Adjustment Reasons cannot exercise

Non-regression: observe Users, Customers, Products, and Store without migrating them.

### Closeout gate (after Slice 1)

Decide whether the frame is accepted; whether Product should consume it in a separately approved compatibility slice; whether width and region semantics need correction; whether the next adoption is feature-led or an explicitly bounded family slice. Do not begin [adoption-outlook.md](adoption-outlook.md) work from this packet.

## Principles

1. **Standardize composition, not domain content.** The page frame decides placement and responsive behavior; features decide the facts and controls in each region.
2. **Use width intentionally.** Wide screens should support wide tables; prose and short forms retain readable measure.
3. **Keep the canvas quiet.** Breadcrumbs and page identity belong on the canvas. Surfaces indicate meaningful grouping.
4. **Preserve behavior.** Presentation slices must not change queries, lifecycle commands, authorization, routing, persisted values, or domain consequences.
5. **Keep work modes distinct.** Admin, Ops, and Register may share tokens and low-level controls without sharing page composition.
6. **Do not create a fourth generation.** Migrated pages consume the frame; unmigrated pages stay as they are.

## Non-goals

- Persistent sidebar navigation or Cmd/Ctrl+K (UDS-7)
- Staff history composition (UDS-6)
- Changes to navigation information architecture
- Client-side Admin navigation or Hotwire adoption
- Card-based mobile replacement for semantic tables
- Redesign of Register or purchasing Ops
- Redesign of printed receipts/reports
- Reporting-domain definitions or new financial calculations
- Controller/query refactors solely to make a layout easier
- Universal use of metric strips, dashboards, sidebars, or sticky footers
- Home landing-purpose redesign
- Stylesheet extraction into separate CSS files
- Migrating Users, Customers, Products, Store, hubs, or workflows in Slice 1

## Existing layout authority

| Shell | Source | Program treatment |
|---|---|---|
| Administrative | `app/views/layouts/application.html.erb` | In scope for opt-in page-frame and width-mode changes |
| Purchasing Ops | `app/views/layouts/ops.html.erb` | Preserve as a separate operational shell |
| Register | `app/views/layouts/pos.html.erb` plus `pos/shell/frame` | Locked out except stylesheet-ownership inventory during Slice 0 |

The layout currently ends composition at `.app-content`. Feature views independently compose everything below it. That missing layer is this program’s target.
