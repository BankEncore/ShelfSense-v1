# Admin Page Frame — Product Detail Recomposition

**Status:** **Superseded.** Do not implement from this draft.

Authority is the amended [product-show.md](../../planning/admin-page-frame/product-show.md) packet (full-width document at `wide` / 90rem; no persistent rail). The suggestions accepted for that amendment include: variants above description; no Phosphor/tooltips/description clamp; no creator/subject search links; batched `Inventory::Availability` for Available; identity strip = identifiers + cover only; existing timestamp helpers; type rollups retired; forms frozen; row labels remain Order stock / Request.

---

The remainder is historical proposed structure.

## 1. Purpose

Recompose the Admin Product detail page for the 90vw Admin page frame after testing showed that a persistent main-column/right-rail layout did not provide enough usable space for the Product variants table.

The revised page is a full-width record document. Individual regions may use internal columns, but the page must not have a persistent supporting rail. The operational variants table receives the full available page width.

## 2. Goals

- Make Product identity and catalog facts easy to scan.
- Give the variants table sufficient horizontal space within the 90vw frame.
- Put variant-specific purchasing and customer-request actions on the applicable variant row.
- Present bibliographic, external-source, technical, and audit information with clear hierarchy.
- Use existing APF and shared primitives wherever they already own behavior or presentation.
- Preserve all existing authorization, Product lifecycle, inventory, purchasing, customer-request, Hotwire, and audit behavior.
- Remain usable at 320px and at 200% browser zoom without page-level horizontal overflow.

## 3. Non-goals

This work does not authorize:

- changes to Product, ProductVariant, inventory, purchasing, customer-request, or audit domain semantics;
- a new page-frame primitive for two-column pages;
- Product index or Product search redesign;
- changes to bibliographic review or catalog-search workflows;
- changes to Product new/edit forms unless separately authorized;
- new “available on order” calculations;
- copying this Product-specific composition to other Admin record families;
- navigation, sidebar, command-search, Register, or Ops changes.

## 4. Page-frame contract

Product show consumes `admin/shared/page` using the accepted Product width mode backed by the 90vw frame.

APF continues to own:

1. breadcrumbs;
2. page header;
3. page-level actions;
4. outer width and responsive gutters;
5. ordered page regions.

Product show owns the composition inside the frame body.

### Locked body rule

Product show may use multiple columns inside an individual region, but it must not use a persistent page-level sidebar. Operational tables receive the full frame width. Editorial and supporting information follow the primary record content in document order.

## 5. Region order

Render regions in this order:

1. Shared breadcrumbs
2. Shared page header
3. Product identity strip
4. Catalog details
5. Description, when present
6. Variants
7. Creators and subjects, when present
8. External data disclosure, when applicable
9. Technical details disclosure
10. Recent activity disclosure, when authorized and events exist

The DOM order must match the visual order at every viewport.

## 6. Shared page header

Render the existing shared breadcrumbs and `shared/page_header` through `admin/shared/page`.

### Header content

- Eyebrow: `Product`
- Title: Product `name`
- Subtitle: Product `subtitle`, when present
- Creator credits: truncated according to the existing contributor-credit behavior, when present
- Status: current Product lifecycle status
- Breadcrumbs: Home → Products → Product name

### Header actions

Retain existing authorization and lifecycle gates for:

- Edit
- Discontinue
- Reactivate
- Delete draft

Remove `Order stock` and `Create customer request` from the page header. These are variant-specific operations and belong on qualifying variant rows.

The cover thumbnail may appear in the identity region. It must not be inserted into the page-header action collection.

## 7. Product identity strip

Render a compact, full-width identity region immediately below the page header.

Display the following populated values:

| Label | Source | Notes |
|---|---|---|
| ShelfSense ID | `primary_identifier` | Primary business identifier |
| ISBN / EAN / UPC | `industry_identifier` | Omit when blank |
| Lookup code | `lookup_code` | Retain the existing shared-lookup warning |
| Merchandise category | `merchandise_category` | Link with the existing category helper when permitted |
| Format | `product_form.name` | Omit when blank |

The cover thumbnail, when available, may sit at the end of this region on large screens and must reflow without forcing horizontal overflow.

Do not label `primary_identifier` as `Product ID`. Reserve `Record ID` for the database UUID shown under Technical details.

## 8. Catalog details

Render one quiet, full-width definition region using existing definition-list primitives where practical. Do not split the information into multiple card-like panels.

At large widths, the region may use up to three internal columns. At constrained widths, it must reflow to two columns and then one column.

Omit blank values rather than rendering empty rows.

### Field mapping

| Stored field or association | Display label | Display behavior |
|---|---|---|
| `list_price_cents` | List price | Format as currency |
| `brand_name` | Publisher / brand | Do not imply every Product is a book publisher record |
| `imprint` | Imprint | Plain text |
| `merchandise_category` | Merchandise category | Display category name; link with existing helper |
| `product_form` | Format | Display format name |
| `product_model` | Edition / model | Plain text |
| `language_code` | Language | Translate a recognized code to its full language name; fall back safely to the stored value |
| `page_count` | Page count | Numeric |
| `release_date` | Release date | Format using the application date convention |
| `release_date_approximate` | — | Append `Approximate` to Release date when true; do not render a separate row |
| `series_name` | Series | Plain text |
| `series_position` | Series position | Plain text or numeric as stored |
| `variant_option_name_1` | Variant option 1 label | Omit when blank |
| `variant_option_name_2` | Variant option 2 label | Omit when blank |
| `status` | — | Display in the page header; do not repeat in Catalog details |
| `binding_legacy` | — | Do not display |

Do not duplicate title, subtitle, creators, ShelfSense ID, industry identifier, lookup code, or status in this region.

## 9. Description

Render Description as a full-width editorial region below Catalog details when `description` is present.

- Preserve safe paragraph formatting.
- Do not constrain Description to a narrow rail.
- Do not truncate short descriptions.
- If the rendered description exceeds the agreed threshold, initially clamp it to approximately six lines and provide a native button labeled `Show full description`.
- The reveal button must use `aria-expanded` and change to `Show less` while expanded.
- The complete description must remain available without hover.

If a robust line-clamp/reveal implementation would add disproportionate behavior to this slice, render the complete description and defer truncation. Do not use a fixed-height clipping implementation that can hide content without a usable control.

## 10. Variants

Variants are the primary operational region and receive the full page width.

Retain:

- the existing `New variant` authorization gate;
- the existing empty-state meaning;
- links to variant records;
- inventory-display authorization and store gates;
- stock-orderability and customer-requestability domain predicates;
- the current-store explanation when actions require a store and none is selected.

### Columns

Render the following columns:

| Column | Content | Behavior |
|---|---|---|
| Type / status | Variant-type icon and lifecycle-status icon | Compact; accessible text required |
| Name | Variant name linked to its record | Primary text column |
| SKU | Variant SKU | Identifier column; do not wrap where avoidable |
| Class | Merchandise class label | Flexible text column |
| Price | Regular price | Currency; numeric alignment |
| Available | Current available-on-hand quantity | Only when inventory display is enabled |
| On hand | Current on-hand quantity | Only when inventory display is enabled |
| On order | Open quantity on sent purchase orders | Only when inventory display is enabled |
| Actions | `Order` and/or `Request` | Render only when at least one action family is authorized |

Where table support permits, group `Available`, `On hand`, and `On order` under an `Inventory` spanning header. A grouped header is optional if it would require replacing the shared table primitive in this slice.

### Inventory definitions

- **Available:** use the existing authoritative availability calculation for the selected store. Do not derive a second availability formula in the view.
- **On hand:** use the existing inventory-balance projection.
- **On order:** sum `PurchaseOrderLine#open_quantity` for the current store’s sent purchase orders, preserving the accepted branch behavior. Draft purchase orders do not contribute. Used variants contribute zero where the domain prohibits purchase ordering.
- Non-inventory variants display an em dash for inventory quantities that do not apply.

### Deferred quantity

Do not render `Available on order` in this implementation.

That term requires an authoritative rule for subtracting inbound quantities committed to special orders, customer requests, or other allocations. It may be added only after the domain meaning, source data, and tests are separately accepted.

### Variant icons

Use Phosphor icons with these mappings:

| Meaning | Icon |
|---|---|
| Standard variant | `sparkle` |
| Used variant | `arrows-counter-clockwise` |
| Active | `check-circle` |
| Draft | `hourglass` |
| Discontinued | `prohibit` |

Use the application’s actual lifecycle vocabulary: `draft`, `active`, and `discontinued`. Do not introduce `pending` or `inactive` labels.

Each icon must have:

- an accessible expansion available to assistive technology;
- a tooltip for sighted users;
- meaning that does not depend on color;
- a stable mapping across Product surfaces.

The combined cell must expose an accessible label such as `Standard; active`. Tooltip text is supplementary and must not be the only accessible label.

Do not add an icon library through an unreviewed CDN. Add or reuse Phosphor through the application’s asset/dependency strategy and apply the same helper consistently.

### Variant actions

- Render `Order` only when the user is authorized, a current store exists, and `stock_orderable_variant?` returns true.
- Render `Request` only when the user is authorized, a current store exists, and `customer_requestable_variant?` returns true.
- Use short, visible text links or compact established action controls.
- Do not render misleading disabled actions.
- When neither action applies, render an empty cell or em dash according to the shared table convention.

## 11. Creators and subjects

When either collection is present, render Creators and Subjects after Variants as peer sections. They may sit in two columns on large screens and must stack in DOM order on constrained screens.

### Creators

- Display creator name and role.
- Link the creator name to Product search for that creator.
- Use an exact creator filter only if Product search supports one.
- If only general search exists, use the existing query parameter and do not visually claim that it is an exact filter.

### Subjects

- Display the human-readable subject heading.
- Link each heading to Product search for that subject.
- Use an exact subject filter only if Product search supports one.

All generated query parameters must use normal Rails path helpers and escaping.

## 12. External data disclosure

Render a collapsed disclosure when external bibliographic provenance exists or the refresh workflow is available.

Prefer the existing disclosure/accordion primitive. If none exists, use semantic `<details>` and `<summary>` rather than custom disclosure JavaScript.

### Fields

| Source | Label | Display behavior |
|---|---|---|
| `bibliographic_provider` | External data provider | Normalize for presentation, such as `ISBNdb`, without changing stored data |
| `bibliographic_fetched_at` | External data retrieved at | Format as `dd MMM yy, h:mm` using the application timezone convention |
| `bibliographic_applied_at` | External data refreshed at | Format as `dd MMM yy, h:mm` using the application timezone convention |
| provider key, when useful | External provider key | Omit if it does not help staff identify the source record |

Keep `Review bibliographic update` within this disclosure when the current authorization and identifier gates permit it. Preserve the existing review-before-apply behavior.

## 13. Technical details disclosure

Render collapsed by default using the existing `shared/technical_details` primitive if it supports the required disclosure behavior.

| Label | Source |
|---|---|
| Record ID | Product database UUID (`id`) |
| Created at | `created_at` |
| Updated at | `updated_at` |
| Lock version | `lock_version` |

Format timestamps as `dd MMM yy, h:mm` using the application timezone convention.

Do not expose database association IDs such as `merchandise_category_id` or `product_form_id`; display their associated names in Catalog details.

## 14. Recent activity disclosure

Render only when the user may view audit events and recent events are present.

- Collapsed by default.
- Summary label: `Recent activity · N events`.
- Render events as a table rather than a raw list.

| Column | Content |
|---|---|
| When | Formatted occurrence timestamp |
| Activity | Humanized action |
| Result | Humanized outcome |
| Staff member | Actor label |

Humanize controlled audit actions consistently—for example, `products.update` becomes `Product updated`. Preserve a route to the full filtered audit-event view when authorized.

Do not change audit recording or authorization behavior in this work.

## 15. Responsive behavior

### Large viewports

- Use the accepted 90vw Product frame.
- Catalog details may use three columns.
- Creators and Subjects may use two columns.
- Variants use the full frame width.

### Constrained viewports and 200% zoom

- The identity strip wraps without clipping.
- Catalog details reduce to two columns and then one.
- Creators and Subjects stack.
- Disclosures remain full width.
- Header actions wrap through the existing shared-header behavior.
- The page itself must not horizontally scroll.
- The variants table may use the existing bounded responsive-table overflow behavior when its semantic columns cannot fit.
- Essential row actions must remain keyboard reachable and must not require hover.

### 320px

- All regions remain readable in document order.
- No content overlaps or clips.
- The variants table’s horizontal overflow, if required, is contained to its table wrapper.
- Description reveal and all disclosures remain operable.

## 16. Canvas and surface rules

- Treat the APF body as the page canvas.
- Do not put an enclosing border or card around the entire Product record.
- Use one quiet surface for Catalog details only if an existing shared surface is required.
- Do not create separate cards for every field group.
- The variants table remains a bounded operational surface.
- Creators, Subjects, Description, and disclosures use spacing and dividers before additional card chrome.
- Do not restore the removed Product metric strip.

## 17. Accessibility requirements

- Preserve semantic heading order.
- Preserve DOM order when visual columns collapse.
- All icon-only meaning has accessible text.
- Tooltips supplement rather than replace accessible names.
- Disclosure controls expose expanded/collapsed state.
- Description reveal exposes `aria-expanded` and an accurate visible label.
- Table headers correctly identify numeric and grouped columns.
- Numeric inventory and currency values are aligned consistently.
- Links and controls have visible keyboard focus through existing shared styles.
- No information depends only on color, hover, or pointer input.
- Touch targets follow the existing Admin control-size contract.

## 18. Implementation boundaries

Expected production files include:

```text
app/views/admin/products/show.html.erb
app/controllers/admin/products_controller.rb
app/assets/stylesheets/application.css
app/helpers/application_helper.rb              # only if an existing helper is the correct icon/formatting owner
app/helpers/admin/products_helper.rb            # if Product-specific presentation helpers already live here or are introduced by convention
```

Prefer extracting focused Product show partials when they materially improve readability, for example:

```text
app/views/admin/products/_identity_strip.html.erb
app/views/admin/products/_catalog_details.html.erb
app/views/admin/products/_variants_table.html.erb
app/views/admin/products/_external_data.html.erb
app/views/admin/products/_recent_activity.html.erb
```

Do not create a generic shared partial solely because Product uses a pattern once. Promote a primitive only after another family demonstrates the same semantic requirement.

Controller changes remain presentation loaders only. Do not move domain calculations into ERB.

## 19. Test requirements

### Integration/view composition

Cover at minimum:

- APF wide/90vw modifier is present.
- Breadcrumb and shared page-header regions render in the accepted order.
- Identity labels use `ShelfSense ID` and `ISBN / EAN / UPC`.
- UUID appears only as `Record ID` under Technical details.
- Blank catalog fields are omitted.
- approximate release date is represented once.
- `binding_legacy` is not displayed.
- Product lifecycle actions retain permission and status gates.
- Order and Request do not appear in the page header.
- External data and Technical details are collapsed disclosures.
- Recent activity is absent without permission or events.

### Variant composition

Cover at minimum:

- standard/used and draft/active/discontinued icon mappings;
- accessible type/status expansions;
- Product variant record links;
- currency formatting;
- available, on-hand, and on-order values;
- inventory columns omitted when inventory display is unauthorized or no store is selected;
- non-inventory quantity presentation;
- sent purchase orders contribute to On order and drafts do not;
- Used is not offered `Order`;
- `Order` and `Request` follow existing predicates and permissions;
- no `Available on order` column is rendered.

### Links

Cover creator and subject links using the exact supported Product search parameters. Assert safe URL encoding for punctuation and non-ASCII names.

### System/layout gates

Exercise Product show with representative populated data at:

- 1920 × 1080;
- 1440px width;
- 1280 × 720 at 200% zoom;
- 768px width;
- 320 × 568.

At each required gate, assert the existing layout-usable contract. Specifically verify:

- no page-level horizontal overflow;
- table overflow is bounded when required;
- page-header actions remain reachable;
- Description reveal is keyboard operable when present;
- External data, Technical details, and Recent activity disclosures are keyboard operable;
- variant `Order` and `Request` actions remain reachable;
- creators and subjects stack in document order.

### Regression suite

Run the existing APF helper, page partial, Product composition, grouped-navigation, and representative Product form tests in addition to the full CI suite.

## 20. Acceptance criteria

This work is complete when:

1. Product show uses the accepted 90vw APF frame without a persistent right rail.
2. The variants table receives the full body width.
3. Product identity, catalog details, and supporting metadata follow the locked region order.
4. Product and variant lifecycle language matches the domain (`draft`, `active`, `discontinued`).
5. Type and status icons are accessible and have consistent tooltips.
6. Row-level Order and Request actions follow existing permissions and predicates.
7. `Available`, `On hand`, and `On order` use authoritative existing calculations.
8. `Available on order` is not presented without a separately accepted domain contract.
9. External data, Technical details, and Recent activity are collapsed, semantic disclosures.
10. Creator and Subject links use supported Product search behavior.
11. The page passes the specified responsive and zoom gates without page-level horizontal overflow.
12. No Product, inventory, purchasing, customer-request, audit, navigation, Register, or Ops behavior changes outside the authorized presentation loaders.

## 21. Follow-up decisions not required for implementation

The following may be evaluated after the recomposed page is rendered:

- whether the Description reveal threshold should be line-based or character-based;
- whether the shared data-table primitive should gain grouped column headers;
- whether creator and subject searches warrant exact structured filters;
- whether `Available on order` should be defined as a domain quantity;
- whether the Product-specific icon mappings should later become shared merchandise conventions.

These follow-ups must not block the base recomposition unless implementation evidence exposes an accessibility or correctness defect.
