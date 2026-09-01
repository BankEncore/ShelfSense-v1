# Admin Page Frame Program — Plan

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Accepted.** Slice 0 complete. Slice 1 **Implemented on `apf-development`** (PR [#133](https://github.com/BankEncore/ShelfSense-v1/pull/133)). [Customer core](customer-core.md) **Accepted** (not yet implemented). Not on `main` until this sprint’s closeout merge. Further family adoption beyond Customer core is not authorized.

Companions: [choices.md](choices.md), [slice-0.md](slice-0.md), [change-allowlist.md](change-allowlist.md), [test-matrix.md](test-matrix.md), [UDS-5](../ux-design-system/uds-5-plan.md), [ux-conventions.md](../../ux-conventions.md).

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

Slice 0 choices APF-001–APF-008 are recorded in [choices.md](choices.md). Summary:

1. **Unmigrated default stays `72rem`.** Do not change `:root --content-max`. `.app-content` must not become `wide` globally. Making `wide` the authenticated default is a later recorded choice (APF-003).

2. **`admin/shared/page` orchestrates existing partials** (APF-001). The frame owns region order and width. It renders `shared/breadcrumbs` and `shared/page_header`. Empty optional regions are omitted (APF-005). It does not replace form section, data table, empty state, definition list, or technical details.

   ```text
   admin/shared/page
   ├── renders shared/breadcrumbs
   ├── renders shared/page_header
   ├── optional page-tools region (omit if unused)
   └── yields page body
   ```

3. **Width escape is a modifier on `main.app-content`** (APF-002). A helper invoked from the page partial `content_for`s a validated class; the application layout applies it. No `100vw`, negative margins, transforms, or inner wrapper wider than `.app-content`. Ops `.ops-content` stays untouched.

4. **Slice 1 production set is Adjustment Reasons only** (APF-004). Index/show `standard`; new/edit `narrow`. `_form` does not declare width. Users, Customers, Products, and Store are non-regression surfaces.

5. **No disposable fixture** (APF-004). The helper still accepts `wide` and `workspace`. Do not wrap Product.

6. **Fully consumes the frame** means a migrated page uses `admin/shared/page` for identity, breadcrumbs, width, and body. It does not mean adding metric strips, tools, or technical details the flow does not already have.

7. **No fourth wrapper generation.** A page is either unmigrated or fully consumes the accepted frame. Migrated pages must not also carry local page-level `max-width`, a second `h1`, or a parallel header.

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

Semantic modes are locked (APF-003). Rem measurements stay provisional. `standard` resolves to 72rem in Slice 1. Finalizing `wide` / `workspace` rem values or changing the inherited default requires a later recorded choice.

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

Optional empty regions are omitted rather than rendered as empty wrappers (APF-005). Structural class names (Slice 1): `.admin-page`, `.admin-page__context`, `.admin-page__header`, `.admin-page__tools`, `.admin-page__body`. Optional composition primitives (`.section-stack`, `.cluster`, `.content-grid`) were not introduced in Slice 1.

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

**Complete.** No production changes. See [slice-0.md](slice-0.md), [slice-0-evidence.md](slice-0-evidence.md), [choices.md](choices.md).

### Slice 1 — Foundation and reference gate

**Implemented on `apf-development`** (PR [#133](https://github.com/BankEncore/ShelfSense-v1/pull/133)). Not on `main`. See [slice-1.md](slice-1.md) and [change-allowlist.md](change-allowlist.md).

- `application.html.erb` applies the width capture with `class_names` onto `main.app-content`
- `admin/shared/page` orchestrates existing shared partials
- `AdminPageHelper` validates all four modes with a single-use capture; production call sites use `standard` / `narrow`
- narrowly scoped Admin composition CSS (no Ops, POS, or print selector changes; `--content-max` unchanged; `--standard` uses `var(--content-max)`)
- tests for the frame, including an unmigrated page with no modifier
- Adjustment Reasons index/show (`standard`) and new/edit (`narrow`); `_form` is frozen

No disposable fixture. Non-regression: Users, Customers, Products, and Store without migrating them.

### Closeout gate (after Slice 1)

**Complete.** The frame is accepted for Adjustment Reasons on `apf-development` (PR [#133](https://github.com/BankEncore/ShelfSense-v1/pull/133)), not on `main`. Product consuming the frame is a **separately approved** later slice, not leftover Slice 1 work. Width rem values for `wide` / `workspace` remain provisional (APF-003). [customer-core.md](customer-core.md) is **Accepted**; implement it on `apf-development`, then merge that branch to `main` and retire it. Do not add another family to `apf-development`. Do not begin [adoption-outlook.md](adoption-outlook.md) work from this packet.

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
