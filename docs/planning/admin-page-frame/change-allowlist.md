# Admin Page Frame Program — Change allowlist

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Accepted.** Slice 0 complete. Slice 1 **locked** below. Expanding this allowlist requires a documentation change in the same PR (or a preceding docs PR) and an explicit callout in review. “Shared CSS cleanup” is not implicit scope.

Choices: [choices.md](choices.md) (APF-001–APF-008).

## Frozen contracts (must not change behavior)

| Contract | Examples |
|---|---|
| Navigation catalog | `Admin::NavigationCatalog` membership, predicates, labels, groups |
| Admin chrome membership | `shared/_admin_primary_nav` destination set |
| Domain | Controllers, queries, pagination, filter params, lifecycle commands, authorization |
| Ops | `ops.html.erb`, `.ops-content`, shortcuts, dirty-form, Escape-cancel |
| Register | POS layout, shell, keyboard, Turbo, Stimulus |
| Print | `.pos-receipt__print*`, thermal content, report print |
| Shared primitives (semantics) | Replace neither `shared/breadcrumbs`, `shared/page_header`, `shared/data_table`, `shared/form_section`, `shared/empty_state`, `shared/definition_list`, nor `shared/technical_details` |
| `:root --content-max` | Remains `72rem`. Modifiers on `.app-content` override opted-in pages only |

## Slice 0 — Packet and evidence (complete)

| Allowed | Forbidden |
|---|---|
| `docs/planning/admin-page-frame/**` | Application code in the Slice 0 closeout |
| Pointers listed in the packet README | Rewriting UDS-5 closeout as if Slice 1 had shipped |
| `docs/drafts/administrative-ux-revamp/` stub pointing here | New Admin destinations or fixtures |

## Slice 1 — Foundation (locked)

| Allowed | Forbidden |
|---|---|
| `app/views/layouts/application.html.erb` — read `content_for` width capture onto `main.app-content` class list. Default remains `app-content` with today’s `72rem` rule | Changing `:root --content-max`; changing `.app-content` default max-width for unmigrated pages; calling the width helper from the layout after `yield`; touching `ops.html.erb` or `pos.html.erb` |
| New `app/views/admin/shared/_page.html.erb` (`render layout: "admin/shared/page"`) that renders `shared/breadcrumbs` and `shared/page_header`, optional tools, required body; omits empty regions | A second page-header or breadcrumb implementation; empty `.admin-page__tools` (or equivalent) when tools are absent |
| `app/helpers/admin_page_helper.rb` — validate `narrow` / `standard` / `wide` / `workspace`; `content_for` the layout modifier. Invoked only from the page partial | Helpers that change domain or money/authorization behavior; views setting the width `content_for` directly |
| New Admin page-frame selectors in `application.css`: `.admin-page*` and `.app-content--narrow` / `--standard` / `--wide` / `--workspace`. No Ops, POS, or print selector changes | Restyling `.ops-*`, `.pos-*`, `@media print`, or `.pos-receipt__print*`; `100vw`, negative-margin breakout, transforms, or a wrapper wider than `.app-content` |
| `app/views/admin/adjustment_reasons/{index,show,new,edit,_form}.html.erb` — index/show `standard`; new/edit `narrow`; `_form` does not declare width | `admin/users/**`, `admin/customers/**`, `admin/products/**`, `admin/stores/**`, and every other family |
| New composition tests for the frame and Adjustment Reasons ([test-matrix.md](test-matrix.md)), including an unmigrated page with no width modifier | Rewriting frozen Product, customer, store, or navigation workflow assertions; disposable prototype routes or wrapping Product |

## Explicitly out of scope (all slices of this packet)

| Path / area | Reason |
|---|---|
| Product, Users, Customers, Store templates | Evidence and non-regression only |
| Home | Deferred product decision |
| Audit events, inventory history | UDS-6 |
| Purchasing hub, cash store day, merge review | Later validation; not Slice 1 |
| `Admin::NavigationCatalog` / view-model | Membership frozen |
| Ops and Register layouts | Distinct shells |
| Print templates and print CSS | Locked contracts |
| Stylesheet file split (`admin.css`, `ops.css`, …) | Separate maintenance program |
| Disposable composition fixture | APF-004: none |
