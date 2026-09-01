# Admin Page Frame Program — Change allowlist

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Proposed.** Slice 0 evidence incomplete. **No implementation authority.**

Expanding this allowlist requires a documentation change in the same PR (or a preceding docs PR) and an explicit callout in review. “Shared CSS cleanup” is not implicit scope.

Slice 1 rows below are **provisional**. They are not executable until [slice-0.md](slice-0.md) is complete and this file’s Slice 1 table is locked against [slice-0-evidence.md](slice-0-evidence.md).

## Frozen contracts (must not change behavior)

| Contract | Examples |
|---|---|
| Navigation catalog | `Admin::NavigationCatalog` membership, predicates, labels, groups |
| Admin chrome membership | `shared/_admin_primary_nav` destination set |
| Domain | Controllers, queries, pagination, filter params, lifecycle commands, authorization |
| Ops | `ops.html.erb`, `.ops-content`, shortcuts, dirty-form, Escape-cancel |
| Register | POS layout, shell, keyboard, Turbo, Stimulus |
| Print | `.pos-receipt__print*`, thermal content, report print |
| Shared primitives (semantics) | Replace neither `shared/breadcrumbs`, `shared/page_header`, `shared/data_table`, `shared/form_section`, nor `shared/technical_details` |

## Slice 0 — Packet and evidence (authorized)

| Allowed | Forbidden |
|---|---|
| `docs/planning/admin-page-frame/**` | Application code, CSS, views, helpers, routes |
| Pointers listed in the packet README (roadmap, planning README, UDS README, program-plan, ux-conventions, ux-adoption-template, migration-matrix, docs/README) | Rewriting UDS-5 closeout as if this program had shipped |
| `docs/drafts/administrative-ux-revamp/` stub pointing here | New Admin destinations or fixtures |

## Slice 1 — Foundation (provisional; not executable yet)

Lock this table at Slice 0 closeout. Paths may be refined then; expanding beyond Adjustment Reasons is not a refinement.

| Allowed | Forbidden |
|---|---|
| `app/views/layouts/application.html.erb` — opt-in width hook only (`content_for` / `main` modifier / equivalent). Default remains `72rem` | Changing `.app-content` default max-width for unmigrated pages; touching `ops.html.erb` or `pos.html.erb` |
| New `app/views/layouts/admin/_page.html.erb` (or equivalent path recorded at lock) that renders `shared/breadcrumbs` and `shared/page_header` | A second page-header or breadcrumb implementation |
| Minimal helper support if the chosen API requires it | Helpers that change domain or money/authorization behavior |
| New Admin page-frame selectors in `application.css` (`.admin-page*` and named composition primitives). No Ops, POS, or print selector changes | Restyling `.ops-*`, `.pos-*`, `@media print`, or `.pos-receipt__print*` |
| `app/views/admin/adjustment_reasons/{index,show,new,edit,_form}.html.erb` | `admin/users/**`, `admin/customers/**`, `admin/products/**`, `admin/stores/**`, and every other family |
| New composition tests for the frame and Adjustment Reasons (request/view/system as listed in [test-matrix.md](test-matrix.md)) | Rewriting frozen Product, customer, store, or navigation workflow assertions |
| Optional disposable fixture: test-only render or a route named in this table at lock, retired in Slice 1 closeout | Standing `GET /admin/uds5_composition_prototype`-style destination; wrapping Product to prove width modes |

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
