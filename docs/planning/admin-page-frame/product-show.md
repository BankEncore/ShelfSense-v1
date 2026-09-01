# Admin Page Frame — Product show (choice packet)

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Accepted.** Implementation targets `main` on a feature branch. Not a numbered APF-2–6 slice and not UDS-6, UDS-7, or UDS-8.

Companions: [README.md](README.md), [plan.md](plan.md), [choices.md](choices.md) (APF-001–APF-008), [customer-core.md](customer-core.md), [adoption-outlook.md](adoption-outlook.md).

This packet authorizes Product show/new/edit/`_form` to consume `admin/shared/page` and rework show composition toward the Product detail wireframe. It does not authorize Product index, bibliographic review, catalog search, or copying this two-column grammar onto other families.

## Why this family

Product is the composed UDS-5 reference record. The wireframe needs a denser bibliographic grid, a right rail (availability / description / subjects / creators), a variants table with on-hand and on-order, and `wide` page width. Customer core intentionally refused that grammar; this packet accepts it for Product only.

## Locked choices (PS-001–PS-008)

### PS-001 — Surfaces

**Accepted.** Writable production:

```text
app/views/admin/products/show.html.erb
app/views/admin/products/new.html.erb
app/views/admin/products/edit.html.erb
app/views/admin/products/_form.html.erb
app/assets/stylesheets/application.css
app/controllers/admin/products_controller.rb
```

Controller changes are limited to show presentation loaders (on-order hashes / type rollups). No create/update/discontinue/reactivate semantics changes.

**Excluded:**

| Surface | Disposition |
|---|---|
| `app/views/admin/products/index.html.erb` | Out of scope |
| `bibliographic_review*` | Out of scope |
| `admin/product_catalog_searches/**` | Out of scope |
| Product variant show/edit | Out of scope |
| `Admin::NavigationCatalog` | Frozen |

### PS-002 — Widths

**Accepted.**

| Surface | Width |
|---|---|
| Product show | `wide` |
| New product | `wide` |
| Edit product | `wide` |

Uses provisional `--admin-content-wide: 90rem`. Does **not** reopen APF-003. Does not change `:root --content-max`.

### PS-003 — Show body grammar

**Accepted.** Consume `admin/shared/page` at `wide`. Region order:

1. Frame: breadcrumbs (Home → Products → name), page header (eyebrow Product, title, creator subtitle with “and N more” when truncated, identifier metadata, status, actions), optional cover placed in body masthead adjacent to identity chrome
2. Body two-column (`.product-columns` at `min-width: 56rem`):
   - **Main:** bibliographic definition grid; variants table; technical details; demoted recent activity (after technical details, not the rail)
   - **Rail:** type availability (Standard/Used × on hand / on order); description; subjects; creators

**Replacements vs prior UDS-5.3 show:**

| Prior | Disposition |
|---|---|
| `.metric-strip` | Removed from primary composition |
| Separate Identity / Publication panels | One bibliographic grid |
| Description in left panels | Right rail |
| Subjects in publication dl | Right-rail list |
| Creators only in subtitle | Header credits **and** right-rail list |
| Recent activity as rail | Demoted below technical details |
| Refresh bibliographic | Compact header action or small main-column control |

Breadcrumbs stay Home → Products → Product name (category remains in the bibliographic grid).

### PS-004 — Variants table

**Accepted.** Primary columns: Type, SKU, Name, Class, Price, On hand, On order (inventory columns only when `@show_inventory`). Retain Status and a trailing Actions column for Order stock / Request when permitted. Empty state unchanged in meaning.

### PS-005 — On-order

**Accepted.**

- Per-variant on-order = sum of `PurchaseOrderLine#open_quantity` for the current store’s **`sent`** purchase orders (exclude `draft`).
- Prefer Phase 7 open-qty over the weaker variant-show `Order.requested_quantity` sum.
- Type rollup: Standard aggregates open qty; Used contributes 0 (cannot be PO’d).
- On-hand by type is a presentation rollup of existing balances.
- When inventory display is off or no store: omit inventory columns and availability quantities (same gate as today’s `@show_inventory`).

### PS-006 — Forms

**Accepted.** Wrap new/edit in `admin/shared/page` at `wide`. Restyle `_form` section titles/order to align with show groups (Identity, Identifiers, Publication/contributors/subjects, Cover, Classification, Pricing, Lifecycle). Keep sticky footer, possible-matches / create-confirmation on new, and candidate hidden fields. Do **not** put the show availability rail on the form.

### PS-007 — Presentation vs domain

**Accepted.** No lifecycle/permission/catalog-search changes. Composition tests may be rewritten to the new grammar. Domain product tests must stay green without being rewritten solely to pass layout.

### PS-008 — Tests

**Accepted.**

```text
test/integration/admin_product_composition_test.rb
test/system/admin_product_composition_test.rb
test/integration/admin_product_page_frame_test.rb   # optional dedicated frame assertions
```

| Layer | Asserts |
|---|---|
| Request | Show/new/edit use `.admin-page` and `app-content--wide`; no `.metric-strip`; rail regions present; bibliographic grid; variants columns; on-order when inventory on + sent PO fixture; index still unmigrated (no width modifier) |
| System | `assert_layout_usable` at 320 and 1280@200% on show/new/edit; 1920 show used width > Users/standard and ≤ 90rem |

Always run: shared frame suite, Customer composition system test, Adjustment Reasons composition system test. Full `./dev/rails-docker bin/ci` before handoff.

## Forbidden

- Migrating index, bibliographic review, or catalog search
- Raising `--admin-content-wide` or `:root --content-max`
- Copying Product two-column show onto Customer or other families
- Counting `draft` POs as on-order without a recorded amendment
- Dropping Order stock / Request actions from the variants table when the actor is authorized

## Implementation bar

- [x] Packet Accepted and pointers updated
- [x] Show consumes frame at `wide` with wireframe regions
- [x] On-order from `sent` PO open quantity
- [x] New/edit/`_form` share chrome; no show rail on forms
- [x] Composition/system tests green; `bin/ci` green
