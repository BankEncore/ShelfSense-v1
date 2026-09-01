# Admin Page Frame — Customer core (choice packet)

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Implemented on `apf-development`** (PR [#136](https://github.com/BankEncore/ShelfSense-v1/pull/136)). Not a numbered APF-2–6 slice and not UDS-6, UDS-7, or UDS-8. Not on `main` until the sprint closeout merge of `apf-development`.

**Integration:** After acceptance, implement on a dedicated feature branch and open a PR into `apf-development`, the temporary integration branch for this bounded APF sprint.

After Customer core is accepted and validated, merge `apf-development` to `main` before beginning or authorizing another Admin family. Do not add another family to `apf-development`. Retire the integration branch after it merges to `main`.

Status progression: Proposed → Accepted → Implemented on `apf-development` → Implemented on `main` → integration branch retired.

Companions: [README.md](README.md), [plan.md](plan.md), [choices.md](choices.md) (APF-001–APF-008), [slice-1.md](slice-1.md), [change-allowlist.md](change-allowlist.md), [adoption-outlook.md](adoption-outlook.md).

This packet is the next bounded **reference family** after Slice 1. It does not authorize the Index or Record family sweeps in [adoption-outlook.md](adoption-outlook.md). It does not authorize Product consuming the frame.

## Why this family

Customers already have breadcrumbs, a page header, a two-control GET filter form, a data table with empty-vs-filtered copy, and a show record with aliases, stored value, merge entry, and related requests. That is a meaningful test of the frame’s tools region and of complex record preservation, without being a hub or a UDS-5 Product clone.

Slice 0 inventory ([slice-0.md](slice-0.md)): index `wide`; show `wide/workspace`; new/edit `standard`; merge `workspace`. Evidence ([slice-0-evidence.md](slice-0-evidence.md)): four index columns fit in 72rem; tools-region grouping helps more than width; filters sit on the canvas instead of a padded tools surface (APF-006). No 1440/1920 show captures exist. This packet therefore does not use `wide`.

## Locked choices (CC-001–CC-008)

These choices are the packet. Accepting the packet accepts all eight. Reopening any one requires a documentation change in the same PR (or a preceding docs PR) and an explicit callout in review.

### CC-001 — Surfaces

**Accepted.** Production templates only:

```text
app/views/admin/customers/index.html.erb
app/views/admin/customers/show.html.erb
app/views/admin/customers/new.html.erb
app/views/admin/customers/edit.html.erb
```

Each wraps `render layout: "admin/shared/page"` with the width and regions below. Views continue to set `content_for :title` themselves. Views must not set the width `content_for`.

**Excluded (must not change):**

| Surface | Disposition |
|---|---|
| `app/views/admin/customers/merge_review.html.erb` | Deferred. Later `workspace` candidate; not this packet |
| `app/views/admin/customer_requests/**` | Out of scope |
| Stored-value **workflow** templates (`stored_value_adjustments/new`, `stored_value_transfers/new`, gift-card association/adjust) | Out of scope. Existing Customer show sections stay as **body** content. Do not change Adjust / Add store credit / Add trade credit / Transfer credit command destinations or parameters |
| `app/views/admin/customers/_form.html.erb` | Frozen (CC-006) |
| `app/controllers/admin/customers_controller.rb` | Frozen |

The merge-into GET form on Customer show remains body content. It continues to navigate to `merge_review`. This packet does not restyle that destination.

### CC-002 — Widths

**Accepted.**

| Surface | Width |
|---|---|
| Customers index | `standard` |
| Customer show | `standard` |
| New customer | `standard` |
| Edit customer | `standard` |

Customer core validates frame adoption and the first production tools-region consumer. It does not use `wide` merely to exercise the provisional token.

Customer show may change to `wide` before implementation only if rendered evidence at 1440 and 1920 demonstrates a material scanning or overflow benefit. That change requires a recorded CC-002 amendment.

`wide` remains available for a later surface whose information density or table geometry materially requires it. Merge review stays unmigrated; `workspace` is not authorized here.

### CC-003 — Provisional `wide` measurement (does not reopen APF-003)

**Accepted.** This packet introduces **no** production `wide` call site. Leave `--admin-content-wide: 90rem` untouched. Do not change `:root --content-max` or introduce a second wide token.

Changing `90rem` requires an explicit APF-003 reopening recorded in [choices.md](choices.md). Silent tuning in the Customer PR is forbidden.

### CC-004 — Tools (index filters)

**Accepted.** Capture the existing GET filter form into the page-frame `tools:` local.

The existing GET filter form is captured into `tools:` and receives `class: "filters surface customer-filters"`. The form itself is the padded surface; do not add an extra `.surface` wrapper around it.

Preserve:

- `form_with url: admin_customers_path, method: :get`
- Params `q` and `lifecycle` (labels Search / Show; options Canonical customers, All including merged aliases, Merged aliases only)
- Submit control (“Search”)
- Empty-collection copy vs empty-filter copy (`No customers yet` / `No matching customers` and their bodies)
- Table columns Name, Email, Phone, Status and current cell contents (including matched-former-record annotation)

Do **not** copy Product composition: no `product-filters`, no `form-field--grow`, no flush `surface--flush` around the table unless a later packet reopens those. The index table stays in the body as `shared/data_table` (same as Adjustment Reasons). Do not add a new global tools-surface primitive.

Header “New customer” remains a page-header action gated on `customers.manage`.

### CC-005 — Show composition

**Accepted.** Frame adoption only: breadcrumbs, page header (existing title, lifecycle badge, Edit / Deactivate / Reactivate), body.

No content grid, metric strip, Product panel composition, or new show-page primitive is authorized. Existing show sections remain in their current source order inside `.admin-page__body`.

Selecting `wide` for Customer show, if later accepted, does not authorize rearranging those sections into columns. Any structural show-page composition requires a separate accepted choice.

Do not extract show sections into new shared primitives.

### CC-006 — Frozen `_form`

**Accepted.** [`_form.html.erb`](../../../app/views/admin/customers/_form.html.erb) stays frozen. New/edit wrap the frame around `render "form"`. Name no inner change in this packet.

Protect with assertions, not incidental edits. The form has no address, receipt-preference, or lifecycle/status fields. Assert the fields that exist:

- `given_name`, `family_name`, `display_name`, `email`, `phone`, `preferred_contact_method`, `notes`
- duplicate-suggestion block and `acknowledge_duplicates` on 422
- `lock_version`, `return_to` (when present), `idempotency_key`
- submit labels “Create Customer” / “Save Changes”
- Cancel → index (new) or show (edit)
- retained values after ordinary validation failure and after duplicate detection

Do not duplicate domain behavior already covered by `customers_admin_test`. 422 redisplay of new/edit must still render the frame around the unchanged form.

### CC-007 — Presentation only

**Accepted.** No controller, query, pagination, filter-param, authorization, lifecycle-command, routing, or persisted-value changes. `customers_admin_test` is frozen: do not rewrite it to make the frame pass. Add new composition/system tests instead.

Shared primitives (`shared/breadcrumbs`, `shared/page_header`, `shared/data_table`, `shared/empty_state`, `shared/definition_list`, `shared/form_errors`) keep their semantics. Ops, Register, print, and `Admin::NavigationCatalog` stay frozen.

### CC-008 — Tests

**Accepted.** New tests plus frozen regressions:

```text
test/integration/admin_customer_page_frame_test.rb
test/system/admin_customers_composition_test.rb
```

| Layer | Asserts |
|---|---|
| Request | One `.admin-page` on migrated Customer pages; index/show/new/edit `main.app-content.app-content--standard`; tools present on index only; `form.filters.surface.customer-filters` inside `.admin-page__tools`; filtered GET retains `q` and `lifecycle`; empty-vs-filtered copy; matched-former-record annotation; table columns unchanged; merge-review transition from the show form; unmigrated Users and `merge_review` have no width modifier and no `.admin-page`; frozen `_form` contract including 422 retain and “Possible duplicates”; scoped CSS selector present without token changes |
| System | `assert_layout_usable` at 320 and 1280@200% on index, show, new, and edit. Index preserves intentional table scrolling. Show retains lifecycle, merge, stored-value, gift-card, and request regions without page-level overflow or clipped actions. New/edit retain reachable Cancel and submit actions. At 1920, Customer index used width matches Adjustment Reasons index and unmigrated Users within 1px; all ≤ 72rem |

Always run, do not rewrite:

```sh
./dev/rails-docker bin/rails test \
  test/helpers/admin_page_helper_test.rb \
  test/views/admin_page_partial_test.rb \
  test/integration/admin_page_frame_test.rb \
  test/system/admin_adjustment_reasons_composition_test.rb \
  test/integration/customers_admin_test.rb \
  test/system/admin_product_composition_test.rb \
  test/system/admin_grouped_navigation_test.rb
```

Full `./dev/rails-docker bin/ci` before handoff.

## Writable files (after this packet is Accepted)

### Production

```text
app/views/admin/customers/index.html.erb
app/views/admin/customers/show.html.erb
app/views/admin/customers/new.html.erb
app/views/admin/customers/edit.html.erb
app/assets/stylesheets/application.css
```

`application.css` may change only to add:

1. the Customer-scoped `.admin-page__tools > .customer-filters` spacing rule
2. the `.admin-page .definition-list` overflow fix required by the Customer show 320px viewport gate (same pattern as the Slice 1 checkbox fix)

Do not change global `.filters`, `.surface`, `.admin-page__tools`, width tokens, or other frame selectors.

```css
.admin-page__tools > .customer-filters {
  margin-bottom: 0;
}

.admin-page .definition-list {
  grid-template-columns: minmax(0, 12rem) minmax(0, 1fr);
}

.admin-page .definition-list dd {
  min-width: 0;
  overflow-wrap: anywhere;
}
```

### Frozen

```text
app/views/admin/customers/_form.html.erb
app/views/admin/customers/merge_review.html.erb
app/controllers/admin/customers_controller.rb
app/views/admin/customer_requests/**
```

### Tests

```text
test/integration/admin_customer_page_frame_test.rb
test/system/admin_customers_composition_test.rb
```

### Documentation

```text
docs/planning/admin-page-frame/customer-core.md
docs/planning/admin-page-frame/README.md
docs/planning/admin-page-frame/plan.md
docs/planning/roadmap.md
docs/planning/ux-design-system/migration-matrix.md
docs/github-workflow.md
```

Status after the implementation PR: **Implemented on `apf-development`**. Status after the sprint closeout merge: **Implemented on `main`**; retire `apf-development`.

## Forbidden

- `merge_review.html.erb`; `admin/customer_requests/**`; stored-value workflow templates and commands
- Editing `_form.html.erb` or `customers_controller.rb` (or other Customer domain services)
- Rewriting `test/integration/customers_admin_test.rb`
- Copying Product index/show composition onto Customer show
- Authorizing `workspace` or changing `--admin-content-wide`
- Using `wide` to exercise the provisional token
- Expanding into Users, Products, Stores, or any other family
- Treating this packet as APF-2 or as [adoption-outlook.md](adoption-outlook.md) authority
- Adding another family to `apf-development`

## Implementation bar

- [x] Four listed templates consume `admin/shared/page` at `standard`
- [x] Index tools capture preserves `q`, `lifecycle`, empty-vs-filtered copy, and table contents
- [x] Filter form is `filters surface customer-filters` with no extra wrapper; `_form` and `merge_review` untouched
- [x] Show has no Product content-grid/panels; sections stay in current source order
- [x] New tests green; frozen `customers_admin_test`, Product, nav, Adjustment Reasons, and shared frame suites green
- [x] `assert_layout_usable` on index, show, new, and edit; 1920 standard-vs-Users comparison
- [x] Roadmap/packet status: Implemented on `apf-development` (cite the implementation PR)
- [ ] After validation: merge `apf-development` to `main` and retire the branch

Handoff `./dev/rails-docker bin/ci`: RuboCop, bundler-audit, importmap audit, Brakeman, `bin/rails test` (0 failures), seeds, and `bin/rails test:system` (**163 runs, 1732 assertions**, 0 failures) passed in 16m34s.

## Does not reopen

- Slice 1 Adjustment Reasons contracts
- APF-001 page-frame API (Customer consumes it)
- APF-003 rem values (this packet does not introduce production `wide`)
- UDS-5 Product as a template to copy
- UDS-6 / UDS-7
- Register workspace, Ops, print
- Stored-value redemption or adjust authorization policy
