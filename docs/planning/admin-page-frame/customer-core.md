# Admin Page Frame — Customer core (choice packet)

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Proposed.** Not implementation authority until Accepted. Not a numbered APF-2–6 slice and not UDS-6, UDS-7, or UDS-8.

**Integration:** After acceptance, implement on a feature branch and open a PR into `apf-development`. Do not target `main`. Do not merge `apf-development` to `main` as part of this packet.

Companions: [README.md](README.md), [plan.md](plan.md), [choices.md](choices.md) (APF-001–APF-008), [slice-1.md](slice-1.md), [change-allowlist.md](change-allowlist.md), [adoption-outlook.md](adoption-outlook.md).

This packet is the next bounded **reference family** after Slice 1. It does not authorize the Index or Record family sweeps in [adoption-outlook.md](adoption-outlook.md). It does not authorize Product consuming the frame.

## Why this family

Customers already have breadcrumbs, a page header, a two-control GET filter form, a data table with empty-vs-filtered copy, and a show record with aliases, stored value, merge entry, and related requests. That is a real `wide` candidate without being a hub or a UDS-5 Product clone.

Slice 0 inventory ([slice-0.md](slice-0.md)): index `wide`; show `wide/workspace`; new/edit `standard`; merge `workspace`. Evidence ([slice-0-evidence.md](slice-0-evidence.md)): four index columns fit in 72rem; tools-region grouping helps more than width; filters sit on the canvas instead of a padded tools surface (APF-006).

## Locked choices (CC-001–CC-008)

These choices are the packet. Accepting the packet accepts all eight. Reopening any one requires a documentation change in the same PR (or a preceding docs PR) and an explicit callout in review.

### CC-001 — Surfaces

**Proposed lock.** Production templates only:

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

The merge-into GET form on Customer show remains body content. It continues to navigate to `merge_review`. This packet does not restyle that destination.

### CC-002 — Widths

**Proposed lock.**

| Surface | Width |
|---|---|
| Customers index | `wide` |
| Customer show | `wide` |
| New customer | `standard` |
| Edit customer | `standard` |

Show is `wide`, not `workspace`. Merge review stays unmigrated; `workspace` is not authorized here.

New/edit are `standard`, not Slice 1’s `narrow`. The Customer form is longer than Adjustment Reasons and can redisplay a duplicate-suggestions panel; `--form-max: 40rem` still bounds field measure inside `standard`.

### CC-003 — Provisional `wide` measurement (does not reopen APF-003)

**Proposed lock.** This is the first production `wide` call site. It uses the Slice 1 token `--admin-content-wide: 90rem` as-is. This packet does **not** finalize that rem value, change `:root --content-max`, or introduce a second wide token.

Changing `90rem` requires an explicit APF-003 reopening recorded in [choices.md](choices.md). Silent tuning in the Customer PR is forbidden.

### CC-004 — Tools (index filters)

**Proposed lock.** Capture the existing GET filter form into the page-frame `tools:` local.

Preserve:

- `form_with url: admin_customers_path, method: :get`
- Params `q` and `lifecycle` (labels Search / Show; options Canonical customers, All including merged aliases, Merged aliases only)
- Submit control (“Search”)
- Empty-collection copy vs empty-filter copy (`No customers yet` / `No matching customers` and their bodies)
- Table columns Name, Email, Phone, Status and current cell contents (including matched-former-record annotation)

**Surface treatment:** wrap that form in a padded `.surface` inside `.admin-page__tools`. Keep `class: "filters"` on the form. Do **not** capture-only (leaving `.filters` on the canvas or as an unsurfaced tools child). APF-006 assigns multi-control filters a padded surface; Slice 0 recorded that this index currently misses that rule.

Do **not** copy Product composition: no `product-filters`, no `form-field--grow`, no flush `surface--flush` around the table unless a later packet reopens those. The index table stays in the body as `shared/data_table` (same as Adjustment Reasons). Do not add a new global tools-surface primitive.

Header “New customer” remains a page-header action gated on `customers.manage`.

### CC-005 — Show composition

**Proposed lock.** Frame adoption only: breadcrumbs, page header (existing title, lifecycle badge, Edit / Deactivate / Reactivate), body.

Keep current stacked sections as body content (merged-alias notice, identity definition list, merged aliases table, merge-into form, stored-value accounts and activity, associated gift cards, recent requests, back link). Do not introduce Product-like `.content-grid`, `.product-panels`, `.metric-strip`, or cover treatments. Default is **no** unless a later accepted packet says otherwise.

Do not extract show sections into new shared primitives.

### CC-006 — Frozen `_form`

**Proposed lock.** [`_form.html.erb`](../../../app/views/admin/customers/_form.html.erb) stays frozen. New/edit wrap the frame around `render "form"`. Name no inner change in this packet.

Protect with assertions, not incidental edits. Duplicate-suggestions checkbox, `lock_version`, `return_to`, `idempotency_key`, and Cancel targets stay as they are. 422 redisplay of new/edit must still render the frame around the unchanged form.

### CC-007 — Presentation only

**Proposed lock.** No controller, query, pagination, filter-param, authorization, lifecycle-command, routing, or persisted-value changes. `customers_admin_test` is frozen: do not rewrite it to make the frame pass. Add new composition/system tests instead.

Shared primitives (`shared/breadcrumbs`, `shared/page_header`, `shared/data_table`, `shared/empty_state`, `shared/definition_list`, `shared/form_errors`) keep their semantics. Ops, Register, print, and `Admin::NavigationCatalog` stay frozen.

### CC-008 — Tests

**Proposed lock.** New tests plus frozen regressions:

```text
test/integration/admin_customer_page_frame_test.rb
test/system/admin_customers_composition_test.rb
```

| Layer | Asserts |
|---|---|
| Request | One `.admin-page` on migrated Customer pages; index/show `main.app-content.app-content--wide`; new/edit `app-content--standard`; tools present on index only; `q` / `lifecycle` fields inside `.admin-page__tools`; unmigrated Users and `merge_review` have no width modifier; frozen `_form` contract (422 duplicate redisplay still contains “Possible duplicates”) |
| System | `assert_layout_usable` at 320 and 1280@200% zoom on index (`wide`, tools, `.table-scroll`) and new/edit (`standard`, Cancel). At 1920: unmigrated Users and Adjustment Reasons index remain ≤ 72rem and match each other; Customer index used width is greater than Users and ≤ `90rem` used width + 1px |

Always run, do not rewrite:

```sh
./dev/rails-docker bin/rails test \
  test/integration/customers_admin_test.rb \
  test/system/admin_product_composition_test.rb \
  test/system/admin_grouped_navigation_test.rb \
  test/system/admin_adjustment_reasons_composition_test.rb
```

Full `./dev/rails-docker bin/ci` before handoff.

## Writable files (after this packet is Accepted)

### Production

```text
app/views/admin/customers/index.html.erb
app/views/admin/customers/show.html.erb
app/views/admin/customers/new.html.erb
app/views/admin/customers/edit.html.erb
```

CSS: only if a Customer-scoped rule is required to keep the padded tools surface from double-margin with `.filters { margin-bottom }`. Prefer a local adjustment under `.admin-page__tools`, not a global `.filters` change. Do not change `:root --content-max` or `--admin-content-wide`.

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
```

Status pointers after implementation: **Implemented on `apf-development`**, not on `main`.

## Forbidden

- `merge_review.html.erb`; `admin/customer_requests/**`; stored-value workflow templates and commands
- Editing `_form.html.erb` or `customers_controller.rb` (or other Customer domain services)
- Rewriting `test/integration/customers_admin_test.rb`
- Copying Product index/show composition onto Customer show
- Authorizing `workspace` or changing `--admin-content-wide`
- Expanding into Users, Products, Stores, or any other family
- Treating this packet as APF-2 or as [adoption-outlook.md](adoption-outlook.md) authority
- Merging to `main`

## Acceptance bar (this docs packet)

- [ ] Packet Accepted (status line in this file and the program README)
- [ ] CC-001–CC-008 unchanged except by explicit review callout
- [ ] No production Customer view changes in the acceptance PR unless that PR is the later implementation

## Implementation bar (later PR, after Accepted)

- [ ] Four listed templates consume `admin/shared/page` with CC-002 widths
- [ ] Index tools capture preserves `q`, `lifecycle`, empty-vs-filtered copy, and table contents
- [ ] Tools use a padded `.surface`; `_form` and `merge_review` untouched
- [ ] Show has no Product content-grid/panels
- [ ] New tests green; frozen `customers_admin_test`, Product, nav, and Adjustment Reasons system suites green
- [ ] `assert_layout_usable` on index and new/edit; 1920 wide-vs-standard comparison
- [ ] Roadmap/packet status: Implemented on `apf-development` (cite the implementation PR)

## Does not reopen

- Slice 1 Adjustment Reasons contracts
- APF-001 page-frame API (Customer consumes it)
- APF-003 rem values (CC-003 uses the provisional `90rem` token)
- UDS-5 Product as a template to copy
- UDS-6 / UDS-7
- Register workspace, Ops, print
- Stored-value redemption or adjust authorization policy
