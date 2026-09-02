# Admin Page Frame — Product show (choice packet)

**Program name:** Admin Page Frame Program (not UDS-6, UDS-7, or UDS-8)

**Status:** **Accepted** (amended). Implementation on feature branch `APF-product-show-wireframe` (PR targeting `main`). Not a numbered APF-2–6 slice and not UDS-6, UDS-7, or UDS-8.

Companions: [README.md](README.md), [plan.md](plan.md), [choices.md](choices.md) (APF-001–APF-008), [customer-core.md](customer-core.md), [adoption-outlook.md](adoption-outlook.md).

This packet authorizes Product show/new/edit/`_form` to consume `admin/shared/page` at `wide`. It does not authorize Product index, bibliographic review, catalog search, or copying this composition onto other families.

A persistent two-column show rail was tried and rejected: it did not leave enough usable width for the variants table. **PS-003, PS-004, PS-005, and PS-008 are amended** to a full-width record document. Internal columns may exist inside a quiet region; the page must not have a persistent supporting rail.

## Why this family

Product is the composed UDS-5 reference record. Show needs identity, catalog facts, and a variants table with store-scoped inventory columns inside `wide` (provisional **90rem**, not 90vw). Customer core intentionally refused Product’s dense grammar; this packet accepts Product-only composition, now as a stacked document rather than a rail.

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

Controller changes are limited to show presentation loaders (on-order and available-quantity hashes). No create/update/discontinue/reactivate semantics changes. Type rollups are not loaded.

**Excluded:**

| Surface | Disposition |
|---|---|
| `app/views/admin/products/index.html.erb` | Out of scope |
| `bibliographic_review*` | Out of scope |
| `admin/product_catalog_searches/**` | Out of scope |
| Product variant show/edit | Out of scope |
| `Admin::NavigationCatalog` | Frozen |

This amendment does not restyle new/edit/`_form` further. Those surfaces remain as already wrapped at `wide`.

### PS-002 — Widths

**Accepted** (unchanged).

| Surface | Width |
|---|---|
| Product show | `wide` |
| New product | `wide` |
| Edit product | `wide` |

Uses provisional `--admin-content-wide: 90rem`. Does **not** reopen APF-003. Does not change `:root --content-max`. Does not use `workspace`, `90vw`, or viewport breakout. If the variants table cannot fit every column, it uses bounded `.table-scroll` overflow.

### PS-003 — Show body grammar

**Accepted (amended).** Consume `admin/shared/page` at `wide`. No persistent page-level sidebar or `.product-rail`. DOM order matches visual order.

1. Frame: breadcrumbs (Home → Products → name); page header (eyebrow Product, title, product subtitle when present, truncated creator credits in metadata, status, lifecycle actions only)
2. Identity strip: cover thumbnail when present (not in header actions); ShelfSense ID; ISBN / EAN / UPC; lookup code with the existing shared-lookup warning
3. Catalog details: one quiet definition region (internal columns allowed; not separate cards)
4. Variants (full body width)
5. Description, when present (full text; no clamp in this slice)
6. Creators and subjects, when present (peer sections; two columns at large widths, stacked in DOM order when constrained). Names are text, not Product-index search links
7. External data disclosure, when provenance exists or refresh is available
8. Technical details disclosure
9. Recent activity disclosure, when authorized and events exist

**Replacements vs the withdrawn rail grammar:**

| Withdrawn | Disposition |
|---|---|
| Persistent right rail | Removed |
| Type availability rollup table | Removed; per-variant columns replace it |
| Description in the rail | Full-width region after variants |
| Subjects / creators in the rail | Peer sections after description; truncated credits remain in the header |
| Cover in header actions | Identity strip only |
| Header Order stock / Create customer request | Removed; row actions remain |
| Refresh bibliographic as a primary control | Collapsed external-data disclosure |
| `.metric-strip` | Still absent |

Category and format live in Catalog details only, not in the identity strip. Status lives in the header only. `binding_legacy` is not displayed. Language shows the stored code. Timestamps use existing `format_timestamp` / `format_date`.

Do not introduce an icon library, tooltip primitive, Phosphor, description line-clamp, or Hotwire/Stimulus on this surface.

### PS-004 — Variants table

**Accepted (amended).** Columns: Type (text), SKU, Name (link), Status (`status_badge`), Class, Price, Available, On hand, On order (inventory columns only when `@show_inventory`), trailing Actions with **Order stock** / **Request** when permitted. Empty state unchanged in meaning.

Do not add `Available on order`. Do not replace Type/Status with icons. Grouped Inventory spanning headers are deferred until `shared/data_table` supports them.

### PS-005 — Inventory columns

**Accepted (amended).**

- **On hand:** existing inventory-balance projection for the current store.
- **On order:** sum of `PurchaseOrderLine#open_quantity` for the current store’s **`sent`** purchase orders (exclude `draft`). Used contributes 0 (cannot be PO’d). Prefer Phase 7 open-qty over the weaker variant-show `Order.requested_quantity` sum.
- **Available:** `Inventory::Availability.available` (on-hand minus reserved standard-quantity customer-request allocations), loaded in batch in the controller. Do not recompute in ERB.
- Non-inventory variants display an em dash for inventory quantities that do not apply.
- When inventory display is off or no store: omit inventory columns (same gate as `@show_inventory`).
- Product-level Standard/Used type rollups are **not** shown.

### PS-006 — Forms

**Accepted** (unchanged). Wrap new/edit in `admin/shared/page` at `wide`. Keep `_form` section titles/order, sticky footer, possible-matches / create-confirmation on new, and candidate hidden fields. Do not put a show rail or identity-strip/catalog document on the form. This amendment does not restyle the form again.

### PS-007 — Presentation vs domain

**Accepted** (unchanged). No lifecycle/permission/catalog-search changes. Composition tests may be rewritten to the new grammar. Domain product tests must stay green without being rewritten solely to pass layout.

### PS-008 — Tests

**Accepted (amended).**

```text
test/integration/admin_product_composition_test.rb
test/system/admin_product_composition_test.rb
test/integration/admin_product_page_frame_test.rb
```

| Layer | Asserts |
|---|---|
| Request | Show/new/edit use `.admin-page` and `app-content--wide`; no `.metric-strip`; no `.product-rail`; identity strip labels ShelfSense ID; catalog details; variants full width with Type/Status text/badge; Available/On hand/On order when inventory on; sent PO on-order; draft PO excluded; Order stock / Request absent from the page header; index still unmigrated |
| System | `assert_layout_usable` at 320 and 1280@200% on show/new/edit; 1920 show used width > Users/standard and ≤ 90rem |

Always run: shared frame suite, Customer composition system test, Adjustment Reasons composition system test. Full `./dev/rails-docker bin/ci` before handoff.

## Forbidden

- Migrating index, bibliographic review, or catalog search
- Raising `--admin-content-wide`, using `90vw` / `workspace`, or changing `:root --content-max`
- Restoring a persistent Product show rail or copying this document onto other families
- Counting `draft` POs as on-order without a recorded amendment
- Dropping Order stock / Request from the variants table when the actor is authorized
- Phosphor/CDN icons, tooltip-only meaning, description clamp, or creator/subject search links
- Restyling new/edit/`_form` in this amendment

## Implementation bar

- [x] Packet Accepted and pointers updated
- [x] Show is a full-width document at `wide` with no rail
- [x] On-order from `sent` PO open quantity
- [x] Available from batched `Inventory::Availability`
- [x] New/edit/`_form` share chrome; this amendment does not restyle them
- [x] Composition/system tests green; `bin/ci` green
