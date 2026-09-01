# Admin Page Frame Program — Change allowlist

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Accepted.** Slice 0 complete. Slice 1 **Implemented on `main`**. Expanding this allowlist requires a documentation change in the same PR (or a preceding docs PR) and an explicit callout in review. “Shared CSS cleanup” is not implicit scope.

Choices: [choices.md](choices.md) (APF-001–APF-008). Completion: [slice-1.md](slice-1.md).

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
| Adjustment Reasons `_form` | [`_form.html.erb`](../../../app/views/admin/adjustment_reasons/_form.html.erb) is frozen; protect with assertions, not incidental edits |

## Slice 0 — Packet and evidence (complete)

| Allowed | Forbidden |
|---|---|
| `docs/planning/admin-page-frame/**` | Application code in the Slice 0 closeout |
| Pointers listed in the packet README | Rewriting UDS-5 closeout as if Slice 1 had shipped |
| `docs/drafts/administrative-ux-revamp/` stub pointing here | New Admin destinations or fixtures |

## Slice 1 — Foundation (implemented)

### Writable production files

```text
app/helpers/admin_page_helper.rb
app/views/layouts/application.html.erb
app/views/admin/shared/_page.html.erb
app/assets/stylesheets/application.css
app/views/admin/adjustment_reasons/index.html.erb
app/views/admin/adjustment_reasons/show.html.erb
app/views/admin/adjustment_reasons/new.html.erb
app/views/admin/adjustment_reasons/edit.html.erb
```

Layout: `class_names("app-content", content_for(:admin_page_width))`. Default remains `app-content` with today’s `72rem` rule. Helper is single-use; invoked only from the page partial. CSS: `.admin-page*` and `.app-content--narrow` / `--standard` / `--wide` / `--workspace`. `--standard` uses `var(--content-max)`. Do not change `:root --content-max`.

Index/show `standard`; new/edit `narrow`. `_form` does not declare width and is **not** writable.

### Writable tests

```text
test/helpers/admin_page_helper_test.rb
test/views/admin_page_partial_test.rb
test/integration/admin_page_frame_test.rb
test/system/admin_adjustment_reasons_composition_test.rb
```

### Writable documentation

```text
docs/planning/admin-page-frame/README.md
docs/planning/admin-page-frame/plan.md
docs/planning/admin-page-frame/choices.md
docs/planning/admin-page-frame/change-allowlist.md
docs/planning/admin-page-frame/test-matrix.md
docs/planning/admin-page-frame/user-stories.md
docs/planning/admin-page-frame/slice-1.md
docs/ux-conventions.md
docs/planning/ux-design-system/migration-matrix.md
docs/README.md
docs/drafts/administrative-ux-revamp/shelvesense-admin-page-frame-slice-0.md
docs/planning/README.md
docs/planning/roadmap.md
docs/planning/ux-design-system/README.md
docs/planning/ux-design-system/program-plan.md
docs/planning/ux-design-system/ux-adoption-template.md
docs/github-workflow.md
```

Status/pointer files so indexes match Slice 1 **Implemented on `main`**. They do not expand production scope.

### Forbidden

- Changing `:root --content-max`; changing `.app-content` default max-width for unmigrated pages; calling the width helper from the layout after `yield`
- Touching `ops.html.erb` or `pos.html.erb`
- A second page-header or breadcrumb implementation; empty `.admin-page__tools` when tools are absent
- Views setting the width `content_for` directly
- Restyling `.ops-*`, `.pos-*`, `@media print`, or `.pos-receipt__print*`; `100vw`, negative-margin breakout, transforms
- `admin/users/**`, `admin/customers/**`, `admin/products/**`, `admin/stores/**`, and every other family
- Editing `_form.html.erb` or `adjustment_reasons_controller.rb`
- Rewriting frozen Product, customer, store, or navigation workflow assertions; disposable prototype routes or wrapping Product

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
